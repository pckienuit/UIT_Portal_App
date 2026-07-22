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
    error: 'Quota is not available for this provider',
  });

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
