const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');

const mainPath = path.resolve(
  __dirname,
  '../../android/app/src/main/assets/nodejs-project/main.js',
);

function tempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'uit-router-runtime-'));
}

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function waitUntilReady(baseUrl, token, child) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    if (child.exitCode !== null) throw new Error(`core exited with ${child.exitCode}`);
    try {
      const response = await fetch(`${baseUrl}/health`, {
        headers: { authorization: `Bearer ${token}` },
      });
      if (response.ok) return;
    } catch (_) {
      // Core chưa listen.
    }
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error('core did not become ready');
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

test('provider create and activation persist schema v2 state', async (t) => {
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'runtime-test-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());

  await waitUntilReady(baseUrl, token, child);
  const createResponse = await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'openai-1',
    name: 'OpenAI',
    kind: 'openAiCompatible',
    presetId: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    modelId: 'gpt-4o-mini',
    apiKey: 'must-not-persist',
  });
  assert.equal(createResponse.status, 201);

  const activateResponse = await request(
    baseUrl,
    token,
    'PATCH',
    '/internal/providers/openai-1',
    { active: true },
  );
  assert.equal(activateResponse.status, 200);

  const providersResponse = await request(
    baseUrl,
    token,
    'GET',
    '/internal/providers',
  );
  assert.equal(providersResponse.status, 200);
  assert.deepEqual(await providersResponse.json(), [{
    id: 'openai-1',
    name: 'OpenAI',
    kind: 'openAiCompatible',
    presetId: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    modelId: 'gpt-4o-mini',
    systemPrompt: '',
    authMode: 'apiKey',
    active: true,
  }]);

  const raw = fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8');
  const state = JSON.parse(raw);
  assert.equal(state.schemaVersion, 2);
  assert.equal(state.connections[0].id, 'openai-1');
  assert.equal(state.connections[0].providerId, 'openai');
  assert.equal(state.activeRoute.connectionId, 'openai-1');
  assert.doesNotMatch(raw, /must-not-persist/);
});

test('quota refresh is honest when provider has no quota adapter', async (t) => {
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'quota-test-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());

  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'router-1',
    name: '9Router',
    kind: 'openAiCompatible',
    presetId: 'custom',
    baseUrl: 'http://127.0.0.1:20128/v1',
    modelId: 'gemini-flash-3-hermes',
    active: true,
  })).status, 201);

  const response = await request(
    baseUrl,
    token,
    'POST',
    '/internal/quota/router-1/refresh',
  );
  assert.equal(response.status, 501);
  assert.deepEqual(await response.json(), {
    status: 'unsupported',
    connectionId: 'router-1',
    providerId: 'custom',
    plan: null,
    fetchedAt: null,
    entries: [],
    message: 'Quota is not available for this provider',
  });

  const state = JSON.parse(
    fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8'),
  );
  assert.deepEqual(state.quota, {});
});

test('quota refresh keeps runtime and source credentials RAM-only', async (t) => {
  let receivedAuthorization;
  const upstream = require('node:http').createServer((request, response) => {
    receivedAuthorization = request.headers.authorization;
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({
      copilot_plan: 'individual',
      quota_snapshots: { chat: { entitlement: 100, remaining: 60, percent_remaining: 60 } },
    }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'quota-runtime-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
    env: { ...process.env, GITHUB_QUOTA_BASE_URL: `http://127.0.0.1:${upstream.address().port}` },
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  const runtimeSecret = 'copilot-runtime-sentinel';
  const sourceSecret = 'github-source-sentinel';
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'provider-github', name: 'GitHub Copilot', presetId: 'github',
    baseUrl: 'https://api.githubcopilot.com', modelId: 'gpt-5.4', active: true,
    apiKey: runtimeSecret, sourceToken: sourceSecret,
  })).status, 201);

  const refreshed = await request(
    baseUrl, token, 'POST', '/internal/quota/provider-github/refresh',
  );
  assert.equal(refreshed.status, 200);
  assert.equal(receivedAuthorization, `Bearer ${sourceSecret}`);
  const refreshedBody = await refreshed.json();
  assert.equal(refreshedBody.status, 'fresh');
  assert.equal(refreshedBody.entries[0].remainingPercent, 60);

  const providersText = await (
    await request(baseUrl, token, 'GET', '/internal/providers')
  ).text();
  const stateText = fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8');
  const logText = fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8');
  for (const text of [providersText, stateText, logText]) {
    assert.doesNotMatch(text, new RegExp(runtimeSecret));
    assert.doesNotMatch(text, new RegExp(sourceSecret));
  }
});

test('quota endpoint returns supported available, stale, error, and no-active states', async (t) => {
  let mode = 'success';
  const upstream = require('node:http').createServer((_request, response) => {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(mode === 'success'
      ? JSON.stringify({ quota_snapshots: {
          chat: { entitlement: 10, remaining: 4, percent_remaining: 40 },
        } })
      : '{malformed');
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'typed-quota-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
    env: { ...process.env, GITHUB_QUOTA_BASE_URL: `http://127.0.0.1:${upstream.address().port}` },
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.deepEqual(await (await request(baseUrl, token, 'GET', '/internal/quota')).json(), {
    status: 'no_active_connection', connectionId: null, providerId: null,
    plan: null, fetchedAt: null, entries: [], message: null,
  });
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'github-missing', name: 'GitHub', presetId: 'github',
    baseUrl: 'https://api.githubcopilot.com', modelId: 'model', active: true,
  })).status, 201);
  const neverFetched = await request(
    baseUrl, token, 'GET', '/internal/quota/github-missing',
  );
  assert.equal(neverFetched.status, 200);
  assert.deepEqual(await neverFetched.json(), {
    status: 'unavailable', connectionId: 'github-missing', providerId: 'github',
    plan: null, fetchedAt: null, entries: [], message: null,
  });
  const unavailable = await request(baseUrl, token, 'POST', '/internal/quota/github-missing/refresh');
  assert.equal(unavailable.status, 401);
  assert.equal((await unavailable.json()).status, 'error');
  assert.equal((await request(baseUrl, token, 'PATCH', '/internal/providers/github-missing', {
    sourceToken: 'typed-source-secret',
  })).status, 200);
  const fresh = await request(baseUrl, token, 'POST', '/internal/quota/github-missing/refresh');
  assert.equal((await fresh.json()).status, 'fresh');
  mode = 'malformed';
  const stale = await request(baseUrl, token, 'POST', '/internal/quota/github-missing/refresh');
  const staleBody = await stale.json();
  assert.equal(stale.status, 200);
  assert.equal(staleBody.status, 'stale');
  assert.equal(staleBody.entries[0].remainingPercent, 40);
  assert.doesNotMatch(JSON.stringify(staleBody), /typed-source-secret/);

  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'github-error', name: 'GitHub error', presetId: 'github',
    baseUrl: 'https://api.githubcopilot.com', modelId: 'model',
    sourceToken: 'other-secret', active: true,
  })).status, 201);
  const error = await request(baseUrl, token, 'POST', '/internal/quota/github-error/refresh');
  assert.equal(error.status, 502);
  assert.equal((await error.json()).status, 'error');
});

test('quota GET addresses each configured quota-capable connection, not active only', async (t) => {
  const upstream = require('node:http').createServer((_request, response) => {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({
      quota_snapshots: { chat: { entitlement: 10, remaining: 7, percent_remaining: 70 } },
    }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'per-connection-quota-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
    env: { ...process.env, GITHUB_QUOTA_BASE_URL: `http://127.0.0.1:${upstream.address().port}` },
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);

  for (const [id, active] of [['github-active', true], ['github-inactive', false]]) {
    assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
      id, name: id, presetId: 'github', baseUrl: 'https://api.githubcopilot.com',
      modelId: 'model', sourceToken: `source-${id}`, active,
    })).status, 201);
    assert.equal((await request(
      baseUrl, token, 'POST', `/internal/quota/${id}/refresh`,
    )).status, 200);
  }

  for (const id of ['github-active', 'github-inactive']) {
    const response = await request(baseUrl, token, 'GET', `/internal/quota/${id}`);
    assert.equal(response.status, 200);
    const snapshot = await response.json();
    assert.equal(snapshot.connectionId, id);
    assert.equal(snapshot.status, 'fresh');
  }
});

test('provider delete removes persisted quota snapshot', async (t) => {
  const dataDir = tempDir();
  fs.writeFileSync(path.join(dataDir, '9router_state.json'), JSON.stringify({
    schemaVersion: 2,
    connections: [{
      id: 'quota-provider',
      providerId: 'openai',
      displayName: 'Quota Provider',
      authMode: 'apiKey',
      modelId: 'model',
      enabled: true,
      mobileMetadata: { baseUrl: 'https://example.test/v1' },
    }],
    activeRoute: null,
    usage: [],
    quota: { 'quota-provider': { used: 10, total: 100 } },
  }));
  const port = await freePort();
  const token = 'delete-quota-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);

  assert.equal((await request(
    baseUrl,
    token,
    'DELETE',
    '/internal/providers/quota-provider',
  )).status, 200);
  const state = JSON.parse(
    fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8'),
  );
  assert.deepEqual(state.quota, {});
});

test('edit delete and reset preserve schema v2 semantics', async (t) => {
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'crud-test-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);

  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'provider-1',
    name: 'Before',
    baseUrl: 'https://example.com/v1',
    modelId: 'model-1',
    active: true,
    apiKey: 'secret-before',
  })).status, 201);
  assert.equal((await request(
    baseUrl,
    token,
    'PATCH',
    '/internal/providers/provider-1',
    { name: 'After', modelId: 'model-2', apiKey: 'secret-after' },
  )).status, 200);

  const statePath = path.join(dataDir, '9router_state.json');
  let raw = fs.readFileSync(statePath, 'utf8');
  let state = JSON.parse(raw);
  assert.equal(state.connections[0].displayName, 'After');
  assert.equal(state.connections[0].modelId, 'model-2');
  assert.doesNotMatch(raw, /secret-before|secret-after/);

  assert.equal((await request(
    baseUrl,
    token,
    'DELETE',
    '/internal/providers/provider-1',
  )).status, 200);
  state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  assert.deepEqual(state.connections, []);
  assert.equal(state.activeRoute, null);

  assert.equal((await request(baseUrl, token, 'POST', '/internal/reset')).status, 200);
  state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  assert.equal(state.schemaVersion, 2);
  assert.deepEqual(state.connections, []);
  assert.deepEqual(state.usage, []);
  assert.deepEqual(state.quota, {});
});

test('OAuth auth mode persists as metadata while token remains runtime-only', async (t) => {
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'oauth-test-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  const secret = 'oauth-runtime-secret';

  assert.equal(
    (await request(baseUrl, token, 'POST', '/internal/providers', {
      id: 'github-oauth',
      name: 'GitHub Copilot',
      kind: 'openAiCompatible',
      presetId: 'github',
      authMode: 'oauth',
      baseUrl: 'https://api.githubcopilot.com',
      modelId: 'gpt-5.4',
      apiKey: secret,
    })).status,
    201,
  );

  const stateText = fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8');
  const state = JSON.parse(stateText);
  assert.equal(state.connections[0].authMode, 'oauth');
  assert.doesNotMatch(stateText, new RegExp(secret));
});

test('Gemini CLI model listing uses live quota buckets', async (t) => {
  const upstream = require('node:http').createServer(async (request, response) => {
    assert.equal(request.url, '/v1internal:retrieveUserQuota');
    assert.match(request.headers.authorization, /^Bearer /);
    let raw = '';
    for await (const chunk of request) raw += chunk;
    assert.deepEqual(JSON.parse(raw), { project: 'cloud-project' });
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ buckets: [
      { modelId: 'gemini-live-model', remainingFraction: 1 },
      { modelId: 'gemini-live-model', remainingFraction: 0.5 },
      { remainingFraction: 1 },
    ] }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'gemini-models-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'gemini-provider', name: 'Gemini CLI', presetId: 'gemini-cli',
    baseUrl: `http://127.0.0.1:${upstream.address().port}/v1internal`,
    modelId: 'stale-model', projectId: 'cloud-project', apiKey: 'runtime-token', active: true,
  })).status, 201);
  const response = await request(baseUrl, token, 'GET', '/v1/models');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    data: [{ id: 'gemini-live-model', object: 'model', owned_by: 'gemini-cli' }],
  });
});

test('model listing targets requested connection instead of active fallback', async (t) => {
  let requestedProject = null;
  const upstream = require('node:http').createServer(async (request, response) => {
    let raw = '';
    for await (const chunk of request) raw += chunk;
    requestedProject = JSON.parse(raw).project;
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ buckets: [{ modelId: 'requested-model' }] }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'connection-models-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'active-provider', name: 'Active', presetId: 'generic',
    baseUrl: 'https://example.com/v1', modelId: 'active-model', active: true,
  })).status, 201);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'requested-provider', name: 'Gemini CLI', presetId: 'gemini-cli',
    baseUrl: `http://127.0.0.1:${upstream.address().port}/v1internal`,
    modelId: 'stale-model', projectId: 'requested-project', apiKey: 'runtime-token',
  })).status, 201);

  const response = await request(
    baseUrl,
    token,
    'GET',
    '/v1/models?connectionId=requested-provider',
  );
  assert.equal(response.status, 200);
  assert.equal(requestedProject, 'requested-project');
  assert.deepEqual(await response.json(), {
    data: [{ id: 'requested-model', object: 'model', owned_by: 'gemini-cli' }],
  });
});

test('GitHub model listing proxies the live upstream catalog', async (t) => {
  const upstream = require('node:http').createServer((request, response) => {
    assert.equal(request.url, '/models');
    assert.equal(request.headers['copilot-integration-id'], 'vscode-chat');
    assert.match(request.headers.authorization, /^Bearer /);
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ data: [{ id: 'available-model' }] }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'models-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'github-provider',
    name: 'GitHub Copilot',
    presetId: 'github',
    baseUrl: `http://127.0.0.1:${upstream.address().port}`,
    modelId: 'retired-model',
    apiKey: 'runtime-token',
    active: true,
  })).status, 201);

  const response = await request(baseUrl, token, 'GET', '/v1/models');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { data: [{ id: 'available-model' }] });
});

test('GitHub model listing returns 502 when upstream is unavailable', async (t) => {
  const unavailablePort = await freePort();
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'models-unavailable-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'github-unavailable',
    name: 'GitHub Copilot',
    presetId: 'github',
    baseUrl: `http://127.0.0.1:${unavailablePort}`,
    modelId: 'gpt-5.4',
    apiKey: 'runtime-only-token',
    active: true,
  })).status, 201);

  const response = await request(baseUrl, token, 'GET', '/v1/models');
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'upstream_models_unavailable' });
  assert.equal(child.exitCode, null);
});

test('streaming request asks upstream for terminal usage', async (t) => {
  const upstream = require('node:http').createServer(async (request, response) => {
    let raw = '';
    for await (const chunk of request) raw += chunk;
    const body = JSON.parse(raw);
    assert.deepEqual(body.stream_options, { include_usage: true });
    assert.equal(request.headers['copilot-integration-id'], 'vscode-chat');
    assert.match(request.headers['editor-version'], /^vscode\//);
    assert.match(request.headers['editor-plugin-version'], /^copilot-chat\//);
    assert.match(request.headers['user-agent'], /^GitHubCopilotChat\//);
    assert.equal(request.headers['openai-intent'], 'conversation-panel');
    assert.ok(request.headers['x-github-api-version']);
    response.writeHead(200, { 'content-type': 'text/event-stream' });
    response.write('data: {"choices":[],"usage":{"prompt_tokens":7,"completion_tokens":2}}\n\n');
    response.end('data: [DONE]\n\n');
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'stream-usage-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  const upstreamPort = upstream.address().port;
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'stream-provider',
    name: 'Stream Provider',
    presetId: 'github',
    baseUrl: `http://127.0.0.1:${upstreamPort}`,
    modelId: 'stream-model',
    active: true,
  })).status, 201);

  const streamed = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    model: 'ignored',
    stream: true,
    messages: [{ role: 'user', content: 'hello' }],
  });
  assert.equal(streamed.status, 200);
  await streamed.text();
  const usageResponse = await request(baseUrl, token, 'GET', '/internal/usage/stats');
  const entries = await usageResponse.json();
  assert.equal(entries.at(-1).promptTokens, 7);
  assert.equal(entries.at(-1).completionTokens, 2);
});

test('Gemini CLI adapter wraps OpenAI requests and translates responses', () => {
  const {
    openAiToGeminiCli,
    geminiResponseToOpenAi,
    createGeminiSseTranslator,
  } = require('../../android/app/src/main/assets/nodejs-project/gemini_cli_adapter');
  const requestBody = openAiToGeminiCli({
    messages: [{ role: 'user', content: 'xin chào' }],
    max_tokens: 128,
  }, 'gemini-2.5-flash', 'project-1');
  assert.equal(requestBody.project, 'project-1');
  assert.equal(requestBody.request.contents[0].parts[0].text, 'xin chào');
  assert.equal(requestBody.request.generationConfig.maxOutputTokens, 128);

  const payload = { response: {
    responseId: 'response-1',
    modelVersion: 'gemini-2.5-flash',
    candidates: [{ content: { parts: [{ text: 'chào bạn' }] }, finishReason: 'STOP' }],
    usageMetadata: { promptTokenCount: 3, candidatesTokenCount: 2, totalTokenCount: 5 },
  } };
  const translated = geminiResponseToOpenAi(payload, 'gemini-2.5-flash');
  assert.equal(translated.choices[0].message.content, 'chào bạn');
  assert.equal(translated.usage.prompt_tokens, 3);

  const stream = createGeminiSseTranslator('gemini-2.5-flash');
  const chunks = stream.push(`data: ${JSON.stringify(payload)}\n\n`);
  const terminal = stream.finish();
  assert.match(chunks.join(''), /chào bạn/);
  assert.equal(terminal.usage.completion_tokens, 2);
  assert.equal(terminal.output.at(-1), 'data: [DONE]\n\n');
});

test('Gemini CLI routes OpenAI chat through Cloud Code envelope', async (t) => {
  const upstream = require('node:http').createServer(async (request, response) => {
    assert.equal(request.url, '/v1internal:generateContent');
    assert.equal(request.headers.authorization, 'Bearer google-runtime-token');
    assert.match(request.headers['user-agent'], /^GeminiCLI\//);
    let raw = '';
    for await (const chunk of request) raw += chunk;
    const body = JSON.parse(raw);
    assert.equal(body.project, 'cloud-project');
    assert.equal(body.model, 'gemini-2.5-flash');
    assert.equal(body.request.contents[0].parts[0].text, 'hello');
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ response: {
      responseId: 'gemini-response',
      candidates: [{ content: { parts: [{ text: 'world' }] }, finishReason: 'STOP' }],
      usageMetadata: { promptTokenCount: 1, candidatesTokenCount: 1, totalTokenCount: 2 },
    } }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'gemini-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], {
    stdio: 'ignore',
  });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'gemini-native',
    name: 'Gemini CLI',
    presetId: 'gemini-cli',
    authMode: 'oauth',
    baseUrl: `http://127.0.0.1:${upstream.address().port}/v1internal`,
    modelId: 'gemini-2.5-flash',
    projectId: 'cloud-project',
    apiKey: 'google-runtime-token',
    active: true,
  })).status, 201);

  const result = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    model: 'ignored',
    stream: false,
    messages: [{ role: 'user', content: 'hello' }],
  });
  assert.equal(result.status, 200);
  const payload = await result.json();
  assert.equal(payload.choices[0].message.content, 'world');
  assert.equal(payload.usage.total_tokens, 2);
  const state = fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8');
  assert.doesNotMatch(state, /google-runtime-token/);
  assert.match(state, /cloud-project/);
});

test('OpenAI Chat descriptor uses exact URL, auth, stream modes, sanitized errors, and model fallback', async (t) => {
  const received = [];
  let mode = 'success';
  const secret = 'descriptor-secret-sentinel';
  const upstream = require('node:http').createServer(async (request, response) => {
    let raw = '';
    for await (const chunk of request) raw += chunk;
    const body = JSON.parse(raw);
    received.push({ url: request.url, authorization: request.headers.authorization, body });
    if (mode === 'error') {
      response.writeHead(401, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ error: { message: `bad Bearer ${secret}`, code: 'bad_key' } }));
      return;
    }
    if (body.stream) {
      response.writeHead(200, { 'content-type': 'text/event-stream' });
      response.end('data: {"choices":[],"usage":{"prompt_tokens":2,"completion_tokens":1}}\n\ndata: [DONE]\n\n');
      return;
    }
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ choices: [{ message: { content: 'ok' } }], usage: {} }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'descriptor-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const chatUrl = `http://127.0.0.1:${upstream.address().port}/locked/chat/completions`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'descriptor-provider', name: 'Descriptor Provider', presetId: 'openai',
    baseUrl: 'https://must-not-be-used.example/v1', modelId: 'catalog-fallback-model',
    apiKey: secret, active: true,
    transportKind: 'openaiChat', chatUrl,
    authHeader: 'Authorization', authScheme: 'Bearer', models: [],
  })).status, 201);

  const models = await request(baseUrl, token, 'GET', '/v1/models');
  assert.deepEqual(await models.json(), {
    data: [{ id: 'catalog-fallback-model', object: 'model', owned_by: 'descriptor-provider' }],
  });
  const plain = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    stream: false, messages: [{ role: 'user', content: 'plain' }],
  });
  assert.equal(plain.status, 200);
  const streamed = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    stream: true, messages: [{ role: 'user', content: 'stream' }],
  });
  assert.equal(streamed.status, 200);
  await streamed.text();
  assert.deepEqual(received.map((item) => item.url), [
    '/locked/chat/completions', '/locked/chat/completions',
  ]);
  assert.ok(received.every((item) => item.authorization === `Bearer ${secret}`));

  mode = 'error';
  const failed = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
    stream: false, messages: [{ role: 'user', content: 'fail' }],
  });
  assert.equal(failed.status, 401);
  assert.deepEqual(await failed.json(), { error: 'upstream_request_failed' });
  const log = fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8');
  assert.doesNotMatch(log, new RegExp(secret));
  assert.match(log, /Upstream openai HTTP 401/);
  assert.doesNotMatch(log, /Bearer\s+/i);
});

test('Antigravity live models and quota never use Gemini CLI endpoint or catalog', async (t) => {
  const requests = [];
  const upstream = require('node:http').createServer((request, response) => {
    let body = '';
    request.on('data', (chunk) => { body += chunk; });
    request.on('end', () => {
      requests.push({ url: request.url, headers: request.headers, body });
      response.writeHead(200, { 'content-type': 'application/json' });
      if (request.url === '/v1internal:loadCodeAssist') {
        response.end(JSON.stringify({
          cloudaicompanionProject: 'account-antigravity-project',
          currentTier: { name: 'Antigravity Pro' },
        }));
        return;
      }
      response.end(JSON.stringify({
        models: {
          'claude-sonnet-4-6': {
            displayName: 'Claude Sonnet 4.6 (Thinking)',
            quotaInfo: { remainingFraction: 0.6, resetTime: '2026-07-25T00:00:00Z' },
          },
          'gemini-3-flash-agent': {
            displayName: 'Gemini 3.5 Flash (High)', quotaInfo: { remainingFraction: 1 },
          },
          experimental: { quotaInfo: { remainingFraction: 1 } },
          hidden: { isInternal: true, quotaInfo: { remainingFraction: 1 } },
        },
      }));
    });
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'antigravity-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  const runtimeSecret = 'antigravity-runtime-sentinel';
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'provider-gemini-cli', name: 'Gemini CLI', presetId: 'gemini-cli',
    baseUrl: `http://127.0.0.1:${upstream.address().port}/v1internal`,
    projectId: 'gemini-project', modelId: 'gemini-only', apiKey: 'gemini-runtime',
    models: [{ id: 'gemini-only', name: 'Gemini only' }], active: true,
  })).status, 201);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'provider-antigravity', name: 'Antigravity', presetId: 'antigravity',
    baseUrl: `http://127.0.0.1:${upstream.address().port}/v1internal`,
    projectId: 'ag-project', modelId: 'claude-sonnet-4-6', apiKey: runtimeSecret,
    models: [
      { id: 'claude-sonnet-4-6', name: 'Catalog Sonnet' },
      { id: 'gemini-3-flash-agent', name: 'Catalog Flash' },
      { id: 'catalog-only', name: 'Wrong catalog fallback' },
    ], active: false,
  })).status, 201);

  const models = await request(baseUrl, token, 'GET', '/v1/models?connectionId=provider-antigravity');
  assert.equal(models.status, 200);
  assert.deepEqual(await models.json(), { data: [
    { id: 'claude-sonnet-4-6', name: 'Claude Sonnet 4.6 (Thinking)', object: 'model', owned_by: 'antigravity' },
    { id: 'gemini-3-flash-agent', name: 'Gemini 3.5 Flash (High)', object: 'model', owned_by: 'antigravity' },
  ] });

  const quota = await request(baseUrl, token, 'POST', '/internal/quota/provider-antigravity/refresh');
  assert.equal(quota.status, 200);
  const quotaBody = await quota.json();
  assert.equal(quotaBody.providerId, 'antigravity');
  assert.deepEqual(quotaBody.entries.map((entry) => entry.id), ['claude-sonnet-4-6', 'gemini-3-flash-agent']);
  assert.equal(quotaBody.entries[0].label, 'Claude Sonnet 4.6 (Thinking)');
  assert.equal(quotaBody.entries[0].remainingPercent, 60);
  assert.equal(quotaBody.entries[0].used, null);
  assert.ok(requests.length >= 4);
  assert.ok(requests.every((item) => item.headers['user-agent'] === 'antigravity/ide/2.1.1 darwin/arm64'));
  assert.equal(
    requests.filter((item) => item.url === '/v1internal:loadCodeAssist').length,
    2,
  );
  const availableRequests = requests.filter(
    (item) => item.url === '/v1internal:fetchAvailableModels',
  );
  assert.equal(availableRequests.length, 2);
  assert.ok(availableRequests.every((item) => item.headers['x-client-name'] === 'antigravity'));
  assert.ok(availableRequests.every((item) => item.headers['x-client-version'] === '2.1.1'));
  assert.ok(availableRequests.every(
    (item) => JSON.parse(item.body).project === 'account-antigravity-project',
  ));

  const persisted = fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8');
  assert.doesNotMatch(persisted, new RegExp(runtimeSecret));
});

test('Antigravity rejects legacy Gemini-shaped cache while Gemini cache remains addressable', async (t) => {
  const dataDir = tempDir();
  fs.writeFileSync(path.join(dataDir, '9router_state.json'), JSON.stringify({
    schemaVersion: 2,
    connections: [
      {
        id: 'provider-antigravity', providerId: 'antigravity', displayName: 'Antigravity',
        authMode: 'oauth', modelId: 'claude-sonnet-4-6', enabled: true,
        mobileMetadata: { baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal' },
      },
      {
        id: 'provider-gemini-cli', providerId: 'gemini-cli', displayName: 'Gemini CLI',
        authMode: 'oauth', modelId: 'gemini-2.5-flash', enabled: true,
        mobileMetadata: { baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal' },
      },
    ],
    activeRoute: { connectionId: 'provider-antigravity', modelId: 'claude-sonnet-4-6', local: false },
    usage: [],
    quota: {
      'provider-antigravity': {
        status: 'fresh', connectionId: 'provider-antigravity', providerId: 'antigravity',
        entries: [{ id: 'gemini-2.5-flash', label: 'Gemini bucket', remainingPercent: 50 }],
      },
      'provider-gemini-cli': {
        status: 'fresh', connectionId: 'provider-gemini-cli', providerId: 'gemini-cli',
        source: 'gemini-cli.retrieveUserQuota',
        entries: [{ id: 'gemini-2.5-flash', label: 'Gemini bucket', remainingPercent: 50 }],
      },
    },
  }), 'utf8');
  const port = await freePort();
  const token = 'quota-provenance-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);

  const antigravity = await request(baseUrl, token, 'GET', '/internal/quota/provider-antigravity');
  assert.equal(antigravity.status, 200);
  assert.deepEqual(await antigravity.json(), {
    status: 'unavailable', connectionId: 'provider-antigravity', providerId: 'antigravity',
    plan: null, fetchedAt: null, entries: [], message: null,
  });
  const gemini = await request(baseUrl, token, 'GET', '/internal/quota/provider-gemini-cli');
  assert.equal(gemini.status, 200);
  assert.equal((await gemini.json()).status, 'stale');

  const persisted = JSON.parse(fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8'));
  assert.equal(persisted.quota['provider-antigravity'], undefined);
  assert.equal(
    persisted.quota['provider-gemini-cli'].source,
    'gemini-cli.retrieveUserQuota',
  );
});

test('Antigravity model listing fails closed instead of returning configured models', async (t) => {
  const upstream = require('node:http').createServer((_request, response) => {
    response.writeHead(403, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'forbidden' }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'antigravity-fail-closed-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'provider-antigravity', name: 'Antigravity', presetId: 'antigravity',
    baseUrl: `http://127.0.0.1:${upstream.address().port}/v1internal`,
    projectId: 'ag-project', modelId: 'claude-sonnet-4-6', apiKey: 'runtime-secret', active: true,
    models: [{ id: 'catalog-only', name: 'Must not be presented as live' }],
  })).status, 201);

  const response = await request(baseUrl, token, 'GET', '/v1/models?connectionId=provider-antigravity');
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: 'upstream_models_unavailable' });
  const log = fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8');
  assert.doesNotMatch(log, /runtime-secret/);
});

test('OpenAI Chat model descriptor uses exact modelsUrl and auth', async (t) => {
  const secret = 'models-descriptor-secret';
  const upstream = require('node:http').createServer((request, response) => {
    assert.equal(request.url, '/locked/models');
    assert.equal(request.headers['x-api-key'], `Token ${secret}`);
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ data: [
      { id: 'live-model', object: 'model', owned_by: 'upstream' },
    ] }));
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'models-descriptor-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'models-descriptor', name: 'Models Descriptor', presetId: 'deepseek',
    baseUrl: 'https://must-not-be-used.example/v1', modelId: 'fallback-model',
    ['api' + 'Key']: secret, active: true, transportKind: 'openaiChat',
    modelsUrl: `http://127.0.0.1:${upstream.address().port}/locked/models`,
    authHeader: 'X-API-Key', authScheme: 'Token',
    models: [{ id: 'catalog-model', name: 'Catalog Model' }],
  })).status, 201);

  const response = await request(baseUrl, token, 'GET', '/v1/models');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { data: [
    { id: 'live-model', object: 'model', owned_by: 'upstream' },
  ] });
});

test('OpenAI Chat model descriptor falls back to catalog then configured model', async (t) => {
  let mode = 'malformed';
  const upstream = require('node:http').createServer((_request, response) => {
    if (mode === 'malformed') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end('{broken');
      return;
    }
    response.destroy();
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'models-fallback-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'models-fallback', name: 'Models Fallback', presetId: 'groq',
    baseUrl: 'https://unused.example/v1', modelId: 'configured-model',
    ['api' + 'Key']: 'fallback-secret', active: true,
    modelsUrl: `http://127.0.0.1:${upstream.address().port}/models`,
    authHeader: 'Authorization', authScheme: 'Bearer',
    models: [{ id: 'catalog-a', name: 'Catalog A' }, { id: 'catalog-b' }],
  })).status, 201);

  for (const expectedMode of ['malformed', 'unavailable']) {
    mode = expectedMode;
    const response = await request(baseUrl, token, 'GET', '/v1/models');
    assert.equal(response.status, 200, expectedMode);
    assert.deepEqual((await response.json()).data.map((model) => model.id), [
      'catalog-a', 'catalog-b',
    ], expectedMode);
  }

  assert.equal((await request(baseUrl, token, 'PATCH', '/internal/providers/models-fallback', {
    models: [],
  })).status, 200);
  const configured = await request(baseUrl, token, 'GET', '/v1/models');
  assert.equal(configured.status, 200);
  assert.deepEqual(await configured.json(), { data: [
    { id: 'configured-model', object: 'model', owned_by: 'models-fallback' },
  ] });
});

test('nonstream text and HTML upstream errors are sanitized with upstream status', async (t) => {
  let status = 429;
  const secret = 'html-error-secret';
  const upstream = require('node:http').createServer((_request, response) => {
    response.writeHead(status, { 'content-type': status === 429 ? 'text/plain' : 'text/html' });
    response.end(status === 429
      ? `rate limited Bearer ${secret}`
      : `<html>gateway failed Bearer ${secret}</html>`);
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => upstream.close());

  const dataDir = tempDir();
  const port = await freePort();
  const token = 'non-json-error-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'non-json-error', name: 'Non JSON Error', presetId: 'openai',
    baseUrl: 'https://unused.example/v1', modelId: 'model',
    ['api' + 'Key']: secret, active: true,
    transportKind: 'openaiChat',
    chatUrl: `http://127.0.0.1:${upstream.address().port}/chat`,
    authHeader: 'Authorization', authScheme: 'Bearer',
  })).status, 201);

  for (const upstreamStatus of [429, 503]) {
    status = upstreamStatus;
    const response = await request(baseUrl, token, 'POST', '/v1/chat/completions', {
      stream: false, messages: [{ role: 'user', content: 'fail' }],
    });
    assert.equal(response.status, upstreamStatus);
    assert.equal(response.headers.get('content-type'), 'application/json');
    assert.deepEqual(await response.json(), { error: 'upstream_request_failed' });
  }
  const log = fs.readFileSync(path.join(dataDir, 'router_node.log'), 'utf8');
  assert.doesNotMatch(log, new RegExp(secret));
});

test('provider PATCH persists corrected runtime descriptor and models', async (t) => {
  const dataDir = tempDir();
  const port = await freePort();
  const token = 'descriptor-patch-core-token';
  const baseUrl = `http://127.0.0.1:${port}`;
  const child = spawn(process.execPath, [mainPath, String(port), token, dataDir], { stdio: 'ignore' });
  t.after(() => child.kill());
  await waitUntilReady(baseUrl, token, child);
  assert.equal((await request(baseUrl, token, 'POST', '/internal/providers', {
    id: 'descriptor-patch', name: 'Descriptor Patch', presetId: 'openai',
    baseUrl: 'https://old.example/v1', modelId: 'old-model', active: true,
  })).status, 201);
  const corrected = {
    transportKind: 'openaiChat',
    chatUrl: 'https://correct.example/chat',
    modelsUrl: 'https://correct.example/models',
    authHeader: 'X-API-Key',
    authScheme: '',
    models: [{ id: 'correct-model', name: 'Correct Model' }],
  };
  assert.equal((await request(
    baseUrl, token, 'PATCH', '/internal/providers/descriptor-patch', corrected,
  )).status, 200);

  const providers = await (await request(baseUrl, token, 'GET', '/internal/providers')).json();
  assert.deepEqual(
    Object.fromEntries(Object.keys(corrected).map((key) => [key, providers[0][key]])),
    corrected,
  );
  const state = JSON.parse(fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8'));
  assert.deepEqual(
    Object.fromEntries(Object.keys(corrected).map((key) => [key, state.connections[0].mobileMetadata[key]])),
    corrected,
  );
});
