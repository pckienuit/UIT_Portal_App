const fs = require('node:fs');
const path = require('node:path');

const SCHEMA_VERSION = 2;
const MAX_USAGE_RECORDS = 2000;
const CONNECTION_FIELDS = [
  'id',
  'providerId',
  'displayName',
  'authMode',
  'modelId',
  'enabled',
  'mobileMetadata',
  'createdAt',
  'updatedAt',
];
const USAGE_FIELDS = [
  'id',
  'timestamp',
  'providerId',
  'connectionId',
  'modelId',
  'status',
  'promptTokens',
  'completionTokens',
  'cachedTokens',
  'estimatedCost',
  'latencyMs',
];

function pick(source, fields) {
  const result = {};
  for (const field of fields) {
    if (source[field] !== undefined) result[field] = source[field];
  }
  return result;
}

function freshState(now) {
  return {
    schemaVersion: SCHEMA_VERSION,
    connections: [],
    activeRoute: null,
    usage: [],
    quota: {},
    updatedAt: now().toISOString(),
  };
}

function createStateStore({ dataDir, now = () => new Date() }) {
  const statePath = path.join(dataDir, '9router_state.json');

  function normalize(input) {
    const connections = Array.isArray(input.connections)
      ? input.connections.map((item) => pick(item, CONNECTION_FIELDS))
      : [];
    const usage = Array.isArray(input.usage)
      ? input.usage.slice(-MAX_USAGE_RECORDS).map((item) => pick(item, USAGE_FIELDS))
      : [];
    return {
      schemaVersion: SCHEMA_VERSION,
      connections,
      activeRoute: input.activeRoute ?? null,
      usage,
      quota: input.quota && typeof input.quota === 'object' ? input.quota : {},
      updatedAt: now().toISOString(),
    };
  }

  function load() {
    if (!fs.existsSync(statePath)) return freshState(now);
    try {
      const parsed = JSON.parse(fs.readFileSync(statePath, 'utf8'));
      if (parsed.schemaVersion !== SCHEMA_VERSION) {
        throw new Error('unsupported schema');
      }
      return normalize(parsed);
    } catch (_) {
      const stamp = now().toISOString().replace(/[:.]/g, '-');
      fs.renameSync(statePath, `${statePath}.corrupt-${stamp}`);
      return freshState(now);
    }
  }

  function save(input) {
    fs.mkdirSync(dataDir, { recursive: true });
    const state = normalize(input);
    const tempPath = `${statePath}.tmp`;
    fs.writeFileSync(tempPath, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
    fs.renameSync(tempPath, statePath);
    return state;
  }

  return { load, save, statePath };
}

module.exports = { createStateStore, SCHEMA_VERSION, MAX_USAGE_RECORDS };
