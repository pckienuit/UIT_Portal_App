const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const catalogPath = path.join(
  root,
  'android/app/src/main/assets/nodejs-project/provider_catalog.json',
);

function loadCatalog() {
  return JSON.parse(fs.readFileSync(catalogPath, 'utf8')).providers;
}

test('generated provider catalog only contains supported LLM categories', () => {
  const providers = loadCatalog();
  const allowed = new Set(['oauth', 'free', 'freeTier', 'apikey']);

  assert.ok(providers.length > 0);
  assert.ok(providers.every((provider) => allowed.has(provider.category)));
});

test('generated provider ids are unique and unsupported entries explain why', () => {
  const providers = loadCatalog();
  const ids = providers.map((provider) => provider.id);

  assert.equal(new Set(ids).size, ids.length);
  assert.ok(
    providers
      .filter((provider) => !provider.mobileSupported)
      .every(
        (provider) =>
          typeof provider.unsupportedReason === 'string' &&
          provider.unsupportedReason.trim().length > 0,
      ),
  );
});

test('Android auth capabilities distinguish native, gateway, and desktop flows', () => {
  const providers = new Map(loadCatalog().map((provider) => [provider.id, provider]));

  assert.deepEqual(
    {
      androidAuth: providers.get('github').androidAuth,
      nativeStatus: providers.get('github').nativeStatus,
      tokenRefresh: providers.get('github').tokenRefresh,
    },
    { androidAuth: 'device', nativeStatus: 'ready', tokenRefresh: 'exchange' },
  );
  for (const id of ['antigravity', 'claude', 'codex']) {
    assert.equal(providers.get(id).androidAuth, 'gateway');
    assert.equal(providers.get(id).gatewayFallback, true);
    assert.equal(providers.get(id).nativeStatus, 'blocked');
    assert.equal(
      providers.get(id).nativeBlockReason,
      'public_client_registration_missing',
    );
  }
  assert.equal(providers.get('xai').androidAuth, 'apiKey');
  assert.equal(providers.get('xai').nativeStatus, 'ready');
  assert.equal(providers.get('cursor').androidAuth, 'unsupported');
  assert.equal(providers.get('cursor').gatewayFallback, false);
});

test('every catalog provider has a conservative Android auth capability', () => {
  const allowedAuth = new Set(['device', 'pkce', 'apiKey', 'gateway', 'unsupported']);
  const allowedStatus = new Set(['ready', 'experimental', 'blocked']);

  for (const provider of loadCatalog()) {
    assert.ok(allowedAuth.has(provider.androidAuth), provider.id);
    assert.ok(allowedStatus.has(provider.nativeStatus), provider.id);
    assert.equal(typeof provider.gatewayFallback, 'boolean', provider.id);
  }
});
