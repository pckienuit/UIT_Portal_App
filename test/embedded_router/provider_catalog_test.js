const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '../..');
const catalogPath = path.join(
  root,
  'android/app/src/main/assets/nodejs-project/provider_catalog.json',
);
const generatorPath = path.join(
  root,
  'tools/9router_mobile/sync-provider-catalog.mjs',
);
const supportPath = path.join(
  root,
  'tools/9router_mobile/provider-support.json',
);
const upstreamRoot = process.env.NINE_ROUTER_ROOT || 'D:/9router';

function loadCatalog() {
  return JSON.parse(fs.readFileSync(catalogPath, 'utf8')).providers;
}

function runGenerator(support, output) {
  return spawnSync(
    process.execPath,
    [
      generatorPath,
      '--upstream',
      upstreamRoot,
      '--support',
      support,
      '--output',
      output,
    ],
    { cwd: root, encoding: 'utf8' },
  );
}

test('generated provider catalog only contains supported LLM categories', () => {
  const providers = loadCatalog();
  const allowed = new Set(['oauth', 'free', 'freeTier', 'apikey']);

  assert.ok(providers.length > 0);
  assert.ok(providers.every((provider) => allowed.has(provider.category)));
});

test('generated catalog contains only explicitly actionable providers', () => {
  const providers = loadCatalog();
  const ids = providers.map((provider) => provider.id);
  const actionable = providers.filter((provider) => provider.mobileSupported);

  assert.equal(new Set(ids).size, ids.length);
  assert.ok(
    actionable.every((provider) =>
      ['ready', 'customOnly'].includes(provider.disposition),
    ),
  );
  assert.ok(actionable.every((provider) => provider.androidAuth));
  assert.ok(actionable.every((provider) => provider.transportKind));
  assert.ok(actionable.every((provider) => provider.chatUrl));
  assert.ok(
    providers
      .filter((provider) => !provider.mobileSupported)
      .every((provider) => provider.disposition === 'candidate'),
  );
  assert.ok(
    providers.every((provider) =>
      provider.models.every((model) => !model.id.includes('embedding')),
    ),
  );
});

test('generated catalog preserves upstream aliases and passthrough flags', () => {
  const byId = new Map(loadCatalog().map((provider) => [provider.id, provider]));

  assert.equal(byId.get('github').alias, 'gh');
  assert.equal(byId.get('codex').alias, 'cx');
  assert.equal(byId.get('openai').alias, 'openai');
  assert.equal(byId.get('openrouter').passthroughModels, true);
  assert.equal(byId.get('github').passthroughModels, false);
});

test('generated catalog hides runtime-only candidates from public Android UI', () => {
  const providers = new Map(loadCatalog().map((provider) => [provider.id, provider]));

  assert.deepEqual(
    {
      androidAuth: providers.get('github').androidAuth,
      nativeStatus: providers.get('github').nativeStatus,
      tokenRefresh: providers.get('github').tokenRefresh,
    },
    { androidAuth: 'device', nativeStatus: 'ready', tokenRefresh: 'exchange' },
  );
  for (const id of ['antigravity', 'gemini-cli']) {
    assert.equal(providers.get(id).disposition, 'candidate', id);
    assert.equal(providers.get(id).mobileSupported, false, id);
  }
  for (const id of ['claude', 'cursor', 'qwen', 'xai']) {
    assert.equal(providers.has(id), false, id);
  }
});

test('public Android catalog exposes only supported quota adapters', () => {
  const byId = new Map(loadCatalog().map((provider) => [provider.id, provider]));

  for (const id of ['codex', 'github', 'openrouter']) {
    assert.equal(byId.get(id).quotaSupported, true, id);
  }
  assert.equal(byId.get('codex').quotaAdapter, 'codex');
  for (const id of ['grok-cli', 'openai', 'deepseek', 'groq', 'mistral']) {
    assert.equal(byId.get(id).quotaSupported, false, id);
  }
});

test('straightforward OpenAI Chat candidates lock exact upstream descriptors', () => {
  const support = JSON.parse(fs.readFileSync(supportPath, 'utf8'));
  const expected = {
    openai: ['https://api.openai.com/v1/chat/completions', 'https://api.openai.com/v1/models'],
    deepseek: ['https://api.deepseek.com/chat/completions', 'https://api.deepseek.com/models'],
    groq: ['https://api.groq.com/openai/v1/chat/completions', 'https://api.groq.com/openai/v1/models'],
    mistral: ['https://api.mistral.ai/v1/chat/completions', 'https://api.mistral.ai/v1/models'],
    cerebras: ['https://api.cerebras.ai/v1/chat/completions', 'https://api.cerebras.ai/v1/models'],
  };

  for (const [id, [chatUrl, modelsUrl]] of Object.entries(expected)) {
    const provider = support.apikey[id];
    assert.equal(provider.disposition, 'ready', id);
    assert.equal(provider.transportKind, 'openaiChat', id);
    assert.equal(provider.chatUrl, chatUrl, id);
    assert.equal(provider.modelsUrl ?? null, modelsUrl, id);
    assert.equal(provider.authHeader, 'Authorization', id);
    assert.equal(provider.authScheme, 'Bearer', id);
    assert.doesNotMatch(provider.chatUrl, /\{[^}]+\}/, id);
  }
});

test('Anthropic candidate locks exact Messages descriptor but remains hidden', () => {
  const support = JSON.parse(fs.readFileSync(supportPath, 'utf8'));
  const anthropic = support.apikey.anthropic;

  assert.equal(anthropic.disposition, 'candidate');
  assert.equal(anthropic.transportKind, 'anthropicMessages');
  assert.equal(anthropic.chatUrl, 'https://api.anthropic.com/v1/messages');
  assert.equal(anthropic.modelsUrl, null);
  assert.equal(anthropic.authHeader, 'x-api-key');
  assert.equal(anthropic.authScheme, '');
  assert.deepEqual(anthropic.staticHeaders, {
    'anthropic-version': '2023-06-01',
  });
  const generated = loadCatalog().find((provider) => provider.id === 'anthropic');
  assert.equal(generated?.mobileSupported, false);
});

test('generator fails closed when an upstream LLM provider is unclassified', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'uit-catalog-'));
  const support = JSON.parse(fs.readFileSync(supportPath, 'utf8'));
  delete support.apikey.deepseek;
  const temporarySupport = path.join(directory, 'support.json');
  const temporaryOutput = path.join(directory, 'catalog.json');
  fs.writeFileSync(temporarySupport, JSON.stringify(support));

  try {
    const result = runGenerator(temporarySupport, temporaryOutput);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Unclassified provider: apikey\/deepseek/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('Codex catalog locks upstream Responses descriptor', () => {
  const support = JSON.parse(fs.readFileSync(supportPath, 'utf8'));
  const codex = support.oauth.codex;
  const generated = loadCatalog().find((provider) => provider.id === 'codex');

  assert.equal(codex.chatUrl, 'https://chatgpt.com/backend-api/codex/responses');
  assert.equal(codex.modelsUrl, null);
  assert.equal(generated.chatUrl, codex.chatUrl);
  assert.equal(generated.modelsUrl, null);
  assert.ok(generated.models.length > 0);
});
