const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildEffectiveModels,
  resolveProviderModel,
} = require('../../android/app/src/main/assets/nodejs-project/provider_model_resolver');

const codex = {
  id: 'codex', alias: 'cx', passthroughModels: false,
  models: [{ id: 'review', upstreamModelId: 'base' }],
};
const other = { id: 'other', passthroughModels: false, models: [] };
const catalog = new Map([
  ['codex', codex], ['cx', codex], ['other', other],
]);
const connection = { id: 'conn', providerKey: 'codex', enabled: true };

test('canonical resolver routes trusted upstream ID', () => {
  assert.deepEqual(resolveProviderModel({ connection, rawModel: 'codex/review', catalog }), {
    connection, provider: catalog.get('codex'), canonicalModel: 'cx/review',
    modelId: 'review', upstreamModelId: 'base',
  });
});

test('canonical resolver fails closed before upstream', () => {
  assert.equal(resolveProviderModel({ connection, rawModel: 'other/gpt', catalog }).error, 409);
  assert.deepEqual(resolveProviderModel({
    connection, rawModel: 'missing/model', catalog,
  }), { error: 400, code: 'unknown_provider' });
  assert.equal(resolveProviderModel({ connection, rawModel: 'codex/missing', catalog }).error, 400);
  assert.equal(resolveProviderModel({
    connection, rawModel: 'codex/review', catalog,
    settings: { codex: { disabledModelIds: ['review'] } },
  }).code, 'model_disabled');
});

test('canonical resolver rejects disabled and unknown providers', () => {
  assert.equal(resolveProviderModel({
    connection: { ...connection, enabled: false }, rawModel: 'codex/review', catalog,
  }).code, 'connection_disabled');
  assert.equal(resolveProviderModel({
    connection: { ...connection, providerKey: 'missing' }, rawModel: 'missing/model', catalog,
  }).code, 'unknown_provider');
});

test('canonical resolver maps catalog aliases to provider identity', () => {
  const result = resolveProviderModel({ connection, rawModel: 'cx/review', catalog });
  assert.equal(result.canonicalModel, 'cx/review');
  assert.equal(result.upstreamModelId, 'base');
});

test('legacy bare model preserves explicitly requested model', () => {
  const result = resolveProviderModel({
    connection,
    rawModel: 'review',
    legacyModel: 'review',
    catalog,
  });
  assert.equal(result.modelId, 'review');
  assert.equal(resolveProviderModel({
    connection,
    rawModel: 'missing',
    legacyModel: 'review',
    catalog,
  }).code, 'unknown_model');
  assert.equal(resolveProviderModel({
    connection,
    rawModel: 'cx/missing',
    legacyModel: 'review',
    catalog,
  }).code, 'unknown_model');
});

test('exact routes reject bare legacy model IDs', () => {
  assert.deepEqual(resolveProviderModel({
    connection, rawModel: 'review', catalog, allowLegacyBare: false,
  }), { error: 400, code: 'invalid_model' });
});

test('effective models merge registry live and custom with registry metadata and disabled filter', () => {
  assert.deepEqual(buildEffectiveModels({
    definition: codex,
    settings: {
      customModels: [
        { id: 'review', name: 'Custom review', upstreamModelId: 'untrusted' },
        { id: 'private', name: 'Private', upstreamModelId: 'private-upstream' },
      ],
      disabledModelIds: ['gone'],
    },
    liveModels: [
      { id: 'review', name: 'Live review', upstreamModelId: 'untrusted-live' },
      { id: 'live', name: 'Live' },
      { id: 'gone', name: 'Gone' },
    ],
  }), [
    { id: 'review', upstreamModelId: 'base', name: 'Live review' },
    { id: 'live', name: 'Live' },
    { id: 'private', name: 'Private', upstreamModelId: 'private-upstream' },
  ]);
});

test('Ollama transport permits unknown live model IDs as passthrough', () => {
  const result = resolveProviderModel({
    connection: { ...connection, transportKind: 'ollamaChat' },
    rawModel: 'cx/runtime-only-model',
    catalog,
  });
  assert.equal(result.modelId, 'runtime-only-model');
  assert.equal(result.upstreamModelId, 'runtime-only-model');
});
