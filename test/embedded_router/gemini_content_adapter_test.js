'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');

const root = path.join(__dirname, '../..');
const {
  openAiToGeminiContent,
  geminiContentResponseToOpenAi,
  createGeminiContentSseTranslator,
  buildGeminiContentUrl,
} = require('../../android/app/src/main/assets/nodejs-project/gemini_content_adapter');
const os = require('node:os');
const net = require('node:net');

function tempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'uit-gemini-content-'));
}

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function request(baseUrl, token, method, pathname, body) {
  return fetch(`${baseUrl}${pathname}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function waitUntilReady(baseUrl, token, child) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    if (child.exitCode !== null) throw new Error(`core exited with ${child.exitCode}`);
    try {
      const res = await request(baseUrl, token, 'GET', '/health');
      if (res.ok) return;
    } catch (_) {}
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error('core did not become ready');
}

const fixturePath = path.join(__dirname, '../fixtures/gemini_content.json');
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

test('converts OpenAI request fixture to Gemini Content request', () => {
  const converted = openAiToGeminiContent(fixture.openaiRequest);
  assert.deepEqual(converted, fixture.geminiRequest);
});

test('builds exact Gemini Content URLs with model and streaming mode', () => {
  const nonStreamUrl = buildGeminiContentUrl('https://generativelanguage.googleapis.com/v1beta/models', 'gemini-2.5-flash', false, 'my-key');
  assert.equal(
    nonStreamUrl,
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=my-key'
  );

  const streamUrl = buildGeminiContentUrl('https://generativelanguage.googleapis.com/v1beta/models', 'gemini-2.5-flash', true, null);
  assert.equal(
    streamUrl,
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse'
  );
});

test('converts Gemini Content response fixture to OpenAI Chat Completions', () => {
  const converted = geminiContentResponseToOpenAi(fixture.geminiResponse, 'gemini-2.5-flash');
  assert.equal(converted.object, 'chat.completion');
  assert.equal(converted.model, 'gemini-2.5-flash');
  assert.equal(converted.choices[0].message.content, fixture.openaiResponse.choices[0].message.content);
  assert.equal(converted.choices[0].finish_reason, 'stop');
  assert.deepEqual(converted.usage, fixture.openaiResponse.usage);
});

test('translates Gemini Content SSE frames to OpenAI chunks and terminal usage', () => {
  const translator = createGeminiContentSseTranslator('gemini-2.5-flash');
  const chunks = [];
  for (const frame of fixture.sseFrames) {
    chunks.push(...translator.push(frame));
  }
  const terminal = translator.finish();

  assert.ok(chunks.length >= 2);
  assert.equal(terminal.output[0], 'data: [DONE]\n\n');
  assert.deepEqual(terminal.usage, fixture.openaiResponse.usage);
});

test('runtime routes exact Gemini REST URL, key param, conversions, stream, fallback, and sanitized errors', async (t) => {
  const port = await freePort();
  const dataDir = tempDir();
  const token = 'gemini-content-test-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const secret = 'gemini-rest-secret';

  let received = [];
  let mode = 'success';
  const upstreamServer = require('node:http').createServer(async (req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    let bodyStr = '';
    for await (const chunk of req) bodyStr += chunk;
    received.push({
      url: req.url,
      keyParam: url.searchParams.get('key'),
      headerKey: req.headers['x-goog-api-key'],
      body: bodyStr ? JSON.parse(bodyStr) : null,
    });
    if (mode === 'error') {
      res.writeHead(403, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ error: { code: 403, message: `Invalid key ${secret}` } }));
    }
    if (url.pathname.includes('streamGenerateContent')) {
      res.writeHead(200, { 'content-type': 'text/event-stream' });
      res.write(`data: ${JSON.stringify({
        candidates: [{ content: { parts: [{ text: 'Gemini REST stream' }] } }],
        usageMetadata: { promptTokenCount: 12, candidatesTokenCount: 4 },
      })}\n\n`);
      return res.end();
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({
      candidates: [{ content: { parts: [{ text: 'Gemini REST reply' }], role: 'model' } }],
      usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 },
    }));
  });
  const upstreamPort = await freePort();
  await new Promise((resolve) => upstreamServer.listen(upstreamPort, '127.0.0.1', resolve));
  let child = spawn(
    process.execPath,
    [path.resolve(root, 'android/app/src/main/assets/nodejs-project/main.js'), String(port), token, dataDir],
    { stdio: 'ignore' },
  );
  t.after(() => {
    upstreamServer.close();
    child.kill();
  });
  await waitUntilReady(baseUrl, token, child);
  assert.equal(
    (await request(baseUrl, token, 'POST', '/internal/providers', {
      id: 'gemini-rest-1',
      name: 'Google Gemini REST',
      presetId: 'custom',
      baseUrl: `http://127.0.0.1:${upstreamPort}/v1beta`,
      apiKey: secret,
      active: true,
      transportKind: 'geminiContent',
      chatUrl: `http://127.0.0.1:${upstreamPort}/v1beta/models/gemini-2.5-flash:generateContent`,
      authHeader: 'x-goog-api-key',
      authScheme: '',
    })).status,
    201,
  );
  const nonStream = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    model: 'gemini-rest-1/gemini-2.5-flash',
    stream: false,
    messages: [{ role: 'user', content: 'hello' }],
  });
  if (nonStream.status !== 200) {
    console.log('NONSTREAM FAILED LOG:', fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8'));
  }
  assert.equal(nonStream.status, 200);
  const nonStreamData = await nonStream.json();
  assert.equal(nonStreamData.choices[0].message.content, 'Gemini REST reply');
  const streamRes = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    model: 'gemini-rest-1/gemini-2.5-flash',
    stream: true,
    messages: [{ role: 'user', content: 'hello stream' }],
  });
  assert.equal(streamRes.status, 200);
  const streamText = await streamRes.text();
  assert.match(streamText, /Gemini REST stream/);
  assert.equal(received[0].keyParam, secret);
  assert.equal(received[0].headerKey, secret);
  mode = 'error';
  const failed = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    model: 'gemini-rest-1/gemini-2.5-flash',
    stream: false,
    messages: [{ role: 'user', content: 'fail' }],
  });
  assert.equal(failed.status, 403);
  assert.deepEqual(await failed.json(), { error: 'upstream_request_failed' });
  const log = fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8');
  assert.doesNotMatch(log, new RegExp(secret));
});
