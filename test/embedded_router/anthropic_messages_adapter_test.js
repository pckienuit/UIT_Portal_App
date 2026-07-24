const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const http = require('node:http');
const { spawn } = require('node:child_process');

const fixture = JSON.parse(fs.readFileSync(
  path.join(__dirname, 'fixtures/anthropic_messages.json'),
  'utf8',
));
const {
  openAiToAnthropic,
  anthropicResponseToOpenAi,
  createAnthropicSseTranslator,
} = require('../../android/app/src/main/assets/nodejs-project/anthropic_messages_adapter');
const mainPath = path.resolve(
  __dirname,
  '../../android/app/src/main/assets/nodejs-project/main.js',
);
const mainSource = fs.readFileSync(mainPath, 'utf8');

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function coreRequest(baseUrl, token, method, pathname, body) {
  return fetch(`${baseUrl}${pathname}`, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function waitUntilReady(baseUrl, token, child) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    if (child.exitCode !== null) throw new Error(`core exited with ${child.exitCode}`);
    try {
      if ((await coreRequest(baseUrl, token, 'GET', '/health')).ok) return;
    } catch (_) {}
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error('core did not become ready');
}

test('converts OpenAI request fixture to Anthropic Messages', () => {
  assert.deepEqual(
    openAiToAnthropic(fixture.openAiRequest, 'claude-sonnet-4-20250514'),
    fixture.anthropicRequest,
  );
});

test('converts OpenAI completion limits, stops, tools, and tool messages', () => {
  const translated = openAiToAnthropic({
    messages: [
      { role: 'user', content: 'Weather?' },
      { role: 'assistant', content: 'Checking.', tool_calls: [{
        id: 'call_weather', type: 'function',
        function: { name: 'weather', arguments: '{"city":"Hanoi"}' },
      }] },
      { role: 'tool', tool_call_id: 'call_weather', content: '{"temp":30}' },
    ],
    max_tokens: 12, max_completion_tokens: 34, stop: ['END', 'STOP'],
    tools: [{ type: 'function', function: {
      name: 'weather', description: 'Current weather',
      parameters: { type: 'object', properties: { city: { type: 'string' } } },
    } }],
    tool_choice: { type: 'function', function: { name: 'weather' } },
  }, 'claude');
  assert.equal(translated.max_tokens, 34);
  assert.deepEqual(translated.stop_sequences, ['END', 'STOP']);
  assert.deepEqual(translated.tools, [{ name: 'weather', description: 'Current weather',
    input_schema: { type: 'object', properties: { city: { type: 'string' } } } }]);
  assert.deepEqual(translated.tool_choice, { type: 'tool', name: 'weather' });
  assert.deepEqual(translated.messages, [
    { role: 'user', content: 'Weather?' },
    { role: 'assistant', content: [
      { type: 'text', text: 'Checking.' },
      { type: 'tool_use', id: 'call_weather', name: 'weather', input: { city: 'Hanoi' } },
    ] },
    { role: 'user', content: [{ type: 'tool_result', tool_use_id: 'call_weather', content: '{"temp":30}' }] },
  ]);
  assert.deepEqual(openAiToAnthropic({
    messages: [], max_tokens: 9, stop: 'DONE', tool_choice: 'required', tools: [],
  }, 'claude'), {
    model: 'claude', messages: [], max_tokens: 9,
    stop_sequences: ['DONE'], tool_choice: { type: 'any' }, stream: false,
  });
});

test('converts Anthropic response fixture to OpenAI Chat Completions', () => {
  assert.deepEqual(
    anthropicResponseToOpenAi(fixture.anthropicResponse),
    fixture.openAiResponse,
  );
});

test('converts Anthropic tool use response to OpenAI tool calls', () => {
  const translated = anthropicResponseToOpenAi({
    id: 'msg_tool', model: 'claude', stop_reason: 'tool_use',
    content: [
      { type: 'text', text: 'Checking.' },
      { type: 'tool_use', id: 'toolu_1', name: 'weather', input: { city: 'Hanoi' } },
    ], usage: { input_tokens: 4, output_tokens: 3 },
  });
  assert.equal(translated.choices[0].finish_reason, 'tool_calls');
  assert.deepEqual(translated.choices[0].message, {
    role: 'assistant', content: 'Checking.',
    tool_calls: [{ id: 'toolu_1', type: 'function',
      function: { name: 'weather', arguments: '{"city":"Hanoi"}' } }],
  });
});

test('translates Anthropic SSE to OpenAI chunks and terminal usage', () => {
  const translator = createAnthropicSseTranslator('claude-sonnet-4-20250514');
  const midpoint = Math.floor(fixture.anthropicStream.length / 2);
  const output = [
    ...translator.push(fixture.anthropicStream.slice(0, midpoint)),
    ...translator.push(fixture.anthropicStream.slice(midpoint)),
  ];
  const terminal = translator.finish();
  output.push(...terminal.output);
  const text = output.join('');

  assert.match(text, /\"role\":\"assistant\"/);
  assert.match(text, /\"content\":\"Hello\"/);
  assert.match(text, /\"finish_reason\":\"stop\"/);
  assert.equal(output.at(-1), 'data: [DONE]\n\n');
  assert.deepEqual(terminal.usage, {
    prompt_tokens: 3,
    completion_tokens: 1,
    total_tokens: 4,
  });
});

test('accepts CRLF Anthropic SSE frames and emits OpenAI tool call deltas', () => {
  const translator = createAnthropicSseTranslator('claude');
  const input = [
    ['message_start', { type: 'message_start', message: { id: 'msg_crlf', usage: { input_tokens: 2, output_tokens: 0 } } }],
    ['content_block_start', { type: 'content_block_start', index: 1,
      content_block: { type: 'tool_use', id: 'toolu_crlf', name: 'weather', input: {} } }],
    ['content_block_delta', { type: 'content_block_delta', index: 1,
      delta: { type: 'input_json_delta', partial_json: '{"city":"Hanoi"}' } }],
    ['message_delta', { type: 'message_delta', delta: { stop_reason: 'tool_use' }, usage: { output_tokens: 3 } }],
  ].map(([name, data]) => `event: ${name}\r\ndata: ${JSON.stringify(data)}\r\n\r\n`).join('');
  const output = translator.push(input).map((frame) => JSON.parse(frame.slice(6))).map((chunk) => chunk.choices[0]);
  assert.deepEqual(output[1].delta.tool_calls, [{ index: 1, id: 'toolu_crlf', type: 'function',
    function: { name: 'weather', arguments: '' } }]);
  assert.deepEqual(output[2].delta.tool_calls, [{ index: 1, function: { arguments: '{"city":"Hanoi"}' } }]);
  assert.equal(output[3].finish_reason, 'tool_calls');
});

test('runtime aborts upstream fetch and backpressures every translated SSE write', () => {
  assert.match(mainSource, /const upstreamController = new AbortController\(\);[\s\S]*fetch\(targetUrl, \{[\s\S]*signal: upstreamController\.signal/);
  assert.match(mainSource, /const closeDownstream = \(\) => \{[\s\S]*upstreamController\.abort\(\)/);
  assert.doesNotMatch(mainSource, /for \(const translated of (?:translator\.push\(chunk\)|terminal\.output)\) response\.write/);
  assert.match(mainSource, /for \(const translated of terminal\.output\) \{[\s\S]*writeWithBackpressure\(response, translated\)/);
});

test('runtime routes exact Anthropic URL, headers, conversions, stream, fallback, and sanitized errors', async (t) => {
  const secret = 'anthropic-runtime-secret';
  let mode = 'plain';
  const received = [];
  const upstream = http.createServer(async (request, response) => {
    let raw = '';
    for await (const chunk of request) raw += chunk;
    received.push({ url: request.url, headers: request.headers, body: JSON.parse(raw) });
    if (mode === 'error') {
      response.writeHead(429, { 'content-type': 'text/html' });
      response.end(`<html>bad x-api-key ${secret}</html>`);
    } else if (mode === 'stream') {
      response.writeHead(200, { 'content-type': 'text/event-stream' });
      response.end(fixture.anthropicStream);
    } else {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify(fixture.anthropicResponse));
    }
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'uit-anthropic-runtime-'));
  const port = await freePort();
  const token = 'anthropic-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const chatUrl = `http://127.0.0.1:${upstream.address().port}/exact/v1/messages`;
  let child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await coreRequest(baseUrl, token, 'POST', '/internal/providers', {
    id: 'anthropic-1', name: 'Anthropic', presetId: 'anthropic',
    baseUrl: 'https://must-not-be-used.example', modelId: 'claude-sonnet-4-20250514',
    apiKey: secret, active: true, transportKind: 'anthropicMessages', chatUrl,
    authHeader: 'x-api-key', authScheme: '',
    staticHeaders: { 'anthropic-version': '2023-06-01' },
    models: [{ id: 'claude-sonnet-4-20250514', name: 'Claude Sonnet 4' }],
  })).status, 201);

  assert.equal((await coreRequest(baseUrl, token, 'PATCH', '/internal/providers/anthropic-1', {
    staticHeaders: { 'anthropic-version': '2024-01-01' },
  })).status, 200);
  child.kill();
  await new Promise((resolve) => child.once('exit', resolve));
  child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  await waitUntilReady(baseUrl, token, child);
  const reloaded = await coreRequest(baseUrl, token, 'GET', '/internal/providers');
  assert.deepEqual((await reloaded.json())[0].staticHeaders, {
    'anthropic-version': '2024-01-01',
  });
  assert.equal((await coreRequest(baseUrl, token, 'PATCH', '/internal/providers/anthropic-1', {
    apiKey: secret,
  })).status, 200);

  const models = await coreRequest(baseUrl, token, 'GET', '/v1/models');
  assert.deepEqual((await models.json()).data.map((model) => model.id), [
    'claude-sonnet-4-20250514',
  ]);
  const plain = await coreRequest(baseUrl, token, 'POST', '/v1/chat/completions', fixture.openAiRequest);
  assert.deepEqual(await plain.json(), fixture.openAiResponse);
  assert.equal(received[0].url, '/exact/v1/messages');
  assert.equal(received[0].headers['x-api-key'], secret);
  assert.equal(received[0].headers['anthropic-version'], '2024-01-01');
  assert.deepEqual(received[0].body, fixture.anthropicRequest);

  mode = 'stream';
  const streamed = await coreRequest(baseUrl, token, 'POST', '/v1/chat/completions', {
    ...fixture.openAiRequest, stream: true,
  });
  const streamText = await streamed.text();
  assert.match(streamText, /\"content\":\"Hello\"/);
  assert.match(streamText, /data: \[DONE\]/);

  mode = 'error';
  const failed = await coreRequest(baseUrl, token, 'POST', '/v1/chat/completions', fixture.openAiRequest);
  assert.equal(failed.status, 429);
  assert.deepEqual(await failed.json(), { error: 'upstream_request_failed' });
  for (const text of [
    fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8'),
    fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8'),
  ]) assert.doesNotMatch(text, new RegExp(secret));
});
