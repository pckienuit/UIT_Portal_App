'use strict';

const { resolveProviderModel } = require('./provider_model_resolver');

function assert(condition, message) {
  if (!condition) {
    console.error('FAIL:', message);
    process.exit(1);
  }
  console.log('ok  ', message);
}

const connection = {
  id: 'ag-work',
  providerKey: 'ag',
  presetId: 'antigravity',
  enabled: true,
};
const catalog = new Map([
  ['ag', { id: 'antigravity', alias: 'ag', models: [], passthroughModels: false }],
]);

const result = resolveProviderModel({
  connection,
  rawModel: 'ag/unlisted-model',
  legacyModel: null,
  catalog,
  allowLegacyBare: false,
  allowUnknownModel: true,
});

assert(result.error === undefined, 'probe permits unlisted model without persistence');
assert(result.canonicalModel === 'ag/unlisted-model', 'probe keeps canonical model route');

console.log('\nAll provider_model_resolver assertions passed.');
