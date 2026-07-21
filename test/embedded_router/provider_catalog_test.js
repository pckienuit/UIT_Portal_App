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
