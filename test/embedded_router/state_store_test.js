const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { createStateStore } = require('../../android/app/src/main/assets/nodejs-project/state_store');

function tempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'uit-router-state-'));
}

test('persists schema v2 metadata without credentials or chat content', () => {
  const dataDir = tempDir();
  const store = createStateStore({ dataDir, now: () => new Date('2026-07-21T00:00:00.000Z') });

  store.save({
    connections: [{
      id: 'conn-1',
      providerId: 'openai',
      displayName: 'OpenAI',
      authMode: 'apiKey',
      modelId: 'gpt-4o-mini',
      enabled: true,
      apiKey: 'sk-secret',
      accessToken: 'oauth-secret',
    }],
    activeRoute: { connectionId: 'conn-1', modelId: 'gpt-4o-mini', local: false },
    usage: [{
      id: 'usage-1',
      timestamp: '2026-07-21T00:00:00.000Z',
      providerId: 'openai',
      connectionId: 'conn-1',
      modelId: 'gpt-4o-mini',
      status: 'success',
      promptTokens: 10,
      completionTokens: 5,
      prompt: 'private prompt',
      response: 'private response',
    }],
    quota: {},
  });

  const raw = fs.readFileSync(path.join(dataDir, '9router_state.json'), 'utf8');
  assert.doesNotMatch(raw, /sk-secret|oauth-secret|private prompt|private response/);

  const state = JSON.parse(raw);
  assert.equal(state.schemaVersion, 2);
  assert.equal(state.connections[0].providerId, 'openai');
  assert.equal(state.connections[0].apiKey, undefined);
  assert.equal(state.usage[0].prompt, undefined);
  assert.equal(state.updatedAt, '2026-07-21T00:00:00.000Z');
});

test('quota normalization strips credential-like fields and malformed entries', () => {
  const dataDir = tempDir();
  const store = createStateStore({ dataDir });
  store.save({
    connections: [], activeRoute: null, usage: [],
    quota: {
      safe: {
        status: 'fresh', connectionId: 'safe', providerId: 'github',
        fetchedAt: '2026-07-24T00:00:00Z', apiKey: 'runtime-secret',
        sourceToken: 'source-secret', entries: [{
          id: 'chat', label: 'chat', used: 1, total: 2, remaining: 1,
          remainingPercent: 50, unit: 'count', resetAt: null, unlimited: false,
          accessToken: 'bucket-secret',
        }],
      },
      malformed: 'secret-string',
    },
  });
  const raw = fs.readFileSync(store.statePath, 'utf8');
  assert.doesNotMatch(raw, /runtime-secret|source-secret|bucket-secret|secret-string/);
  assert.equal(store.load().quota.safe.status, 'fresh');
  assert.equal(store.load().quota.safe.entries[0].remainingPercent, 50);
  assert.equal(store.load().quota.malformed, undefined);
});

test('persists quota source provenance without accepting credential fields', () => {
  const dataDir = tempDir();
  const store = createStateStore({ dataDir });
  store.save({
    connections: [], activeRoute: null, usage: [],
    quota: {
      antigravity: {
        status: 'fresh',
        connectionId: 'antigravity',
        providerId: 'antigravity',
        source: 'antigravity.fetchAvailableModels',
        entries: [],
      },
    },
  });

  assert.equal(
    store.load().quota.antigravity.source,
    'antigravity.fetchAvailableModels',
  );
});

test('backs up corrupt JSON before returning a fresh state', () => {
  const dataDir = tempDir();
  const statePath = path.join(dataDir, '9router_state.json');
  fs.writeFileSync(statePath, '{broken', 'utf8');
  const store = createStateStore({ dataDir, now: () => new Date('2026-07-21T01:02:03.000Z') });

  const state = store.load();

  assert.equal(state.schemaVersion, 2);
  assert.deepEqual(state.connections, []);
  assert.equal(fs.existsSync(statePath), false);
  const backups = fs.readdirSync(dataDir).filter((name) => name.startsWith('9router_state.json.corrupt-'));
  assert.equal(backups.length, 1);
  assert.equal(fs.readFileSync(path.join(dataDir, backups[0]), 'utf8'), '{broken');
});

test('caps retained usage details at 2000 newest records', () => {
  const dataDir = tempDir();
  const store = createStateStore({ dataDir });
  const usage = Array.from({ length: 2005 }, (_, index) => ({
    id: `usage-${index}`,
    timestamp: new Date(index * 1000).toISOString(),
    status: 'success',
  }));

  store.save({ connections: [], activeRoute: null, usage, quota: {} });
  const state = store.load();

  assert.equal(state.usage.length, 2000);
  assert.equal(state.usage[0].id, 'usage-5');
  assert.equal(state.usage.at(-1).id, 'usage-2004');
});

test('migrates legacy providers to connections without carrying api keys', () => {
  const dataDir = tempDir();
  const statePath = path.join(dataDir, '9router_state.json');
  fs.writeFileSync(
    statePath,
    JSON.stringify({
      providers: [{
        id: 'legacy-openai',
        name: 'OpenAI',
        presetId: 'openai',
        kind: 'openAiCompatible',
        baseUrl: 'https://api.openai.com/v1',
        modelId: 'gpt-4o-mini',
        active: true,
        apiKey: 'must-not-survive',
      }],
      usage: [],
      quota: {},
    }),
    'utf8',
  );
  const store = createStateStore({
    dataDir,
    now: () => new Date('2026-07-21T02:00:00.000Z'),
  });

  const state = store.load();

  assert.equal(state.schemaVersion, 2);
  assert.equal(state.connections[0].id, 'legacy-openai');
  assert.equal(state.connections[0].providerId, 'openai');
  assert.equal(state.connections[0].displayName, 'OpenAI');
  assert.equal(state.connections[0].authMode, 'apiKey');
  assert.deepEqual(state.connections[0].mobileMetadata, {
    kind: 'openAiCompatible',
    baseUrl: 'https://api.openai.com/v1',
    systemPrompt: '',
  });
  assert.deepEqual(state.activeRoute, {
    connectionId: 'legacy-openai',
    modelId: 'gpt-4o-mini',
    local: false,
  });
  assert.doesNotMatch(fs.readFileSync(statePath, 'utf8'), /must-not-survive/);
});
