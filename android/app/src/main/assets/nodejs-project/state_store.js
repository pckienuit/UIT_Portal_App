const fs = require('node:fs');
const path = require('node:path');

const SCHEMA_VERSION = 3;
const MAX_USAGE_RECORDS = 2000;
const CONNECTION_FIELDS = [
  'id',
  'providerId',
  'providerKey',
  'displayName',
  'authMode',
  'enabled',
  'priority',
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
const QUOTA_FIELDS = [
  'status', 'connectionId', 'providerId', 'source', 'plan', 'fetchedAt', 'entries', 'message',
];
const QUOTA_BUCKET_FIELDS = [
  'id', 'label', 'used', 'total', 'remaining', 'remainingPercent', 'unit', 'resetAt', 'unlimited',
];

function pick(source, fields) {
  const result = {};
  for (const field of fields) {
    if (source[field] !== undefined) result[field] = source[field];
  }
  return result;
}

function normalizeQuota(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return {};
  const result = {};
  for (const [connectionId, value] of Object.entries(input)) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) continue;
    const quota = pick(value, QUOTA_FIELDS);
    quota.entries = Array.isArray(value.entries)
      ? value.entries
          .filter((entry) => entry && typeof entry === 'object' && !Array.isArray(entry))
          .map((entry) => pick(entry, QUOTA_BUCKET_FIELDS))
      : [];
    result[connectionId] = quota;
  }
  return result;
}

function normalizeId(value) {
  if (typeof value !== 'string') return null;
  const id = value.trim();
  return !id || id.length > 200 || /[\x00-\x1f\x7f]/.test(id) ? null : id;
}

function normalizeModelSettings(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return {};
  const result = {};
  for (const [providerKey, raw] of Object.entries(input)) {
    const key = normalizeId(providerKey);
    if (!key || !raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
    const custom = new Map();
    for (const model of Array.isArray(raw.customModels) ? raw.customModels : []) {
      const candidate = typeof model === 'string' ? { id: model } : model;
      const id = normalizeId(candidate?.id);
      if (id && !custom.has(id)) custom.set(id, { ...candidate, id });
    }
    const disabled = [...new Set((Array.isArray(raw.disabledModelIds) ? raw.disabledModelIds : [])
      .map(normalizeId).filter(Boolean))].sort();
    result[key] = { customModels: [...custom.values()], disabledModelIds: disabled };
  }
  return result;
}

function normalizeConnection(input) {
  const connection = pick(input, CONNECTION_FIELDS);
  const metadata = connection.mobileMetadata;
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    connection.mobileMetadata = {};
    return connection;
  }
  const cleanMetadata = { ...metadata };
  delete cleanMetadata.modelId;
  delete cleanMetadata.models;
  delete cleanMetadata.customModels;
  delete cleanMetadata.hiddenModelIds;
  connection.mobileMetadata = cleanMetadata;
  return connection;
}

function freshState(now) {
  return {
    schemaVersion: SCHEMA_VERSION,
    connections: [],
    modelSettings: {},
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
      ? input.connections.map(normalizeConnection)
      : [];
    const usage = Array.isArray(input.usage)
      ? input.usage.slice(-MAX_USAGE_RECORDS).map((item) => pick(item, USAGE_FIELDS))
      : [];
    return {
      schemaVersion: SCHEMA_VERSION,
      connections,
      modelSettings: normalizeModelSettings(input.modelSettings),
      activeRoute: input.activeRoute ?? null,
      usage,
      quota: normalizeQuota(input.quota),
      updatedAt: now().toISOString(),
    };
  }

  function migrateLegacy(input) {
    const providers = Array.isArray(input.providers) ? input.providers : [];
    const active = providers.find((provider) => provider.active);
    return {
      connections: providers.map((provider) => ({
        id: provider.id,
        providerId: provider.presetId || provider.id,
        providerKey: provider.presetId || provider.id,
        displayName: provider.name,
        authMode: 'apiKey',
        enabled: provider.enabled !== false,
        mobileMetadata: {
          kind: provider.kind || 'openAiCompatible',
          baseUrl: provider.baseUrl,
          systemPrompt: provider.systemPrompt || '',
        },
        createdAt: provider.createdAt,
        updatedAt: provider.updatedAt,
      })),
      activeRoute: active
        ? {
            connectionId: active.id,
            modelId: `${active.presetId || active.id}/${active.modelId}`,
            local: false,
          }
        : null,
      usage: input.usage,
      quota: input.quota,
    };
  }

  function migrateV2(input) {
    const grouped = {};
    const connections = Array.isArray(input.connections) ? input.connections : [];
    for (const connection of connections) {
      const providerKey = normalizeId(connection.providerKey || connection.providerId || connection.id);
      if (!providerKey) continue;
      const settings = grouped[providerKey] || (grouped[providerKey] = {
        customModels: [], disabledModelIds: [],
      });
      const metadata = connection.mobileMetadata || {};
      settings.customModels.push(...(Array.isArray(metadata.customModels) ? metadata.customModels : []));
      settings.disabledModelIds.push(...(Array.isArray(metadata.hiddenModelIds) ? metadata.hiddenModelIds : []));
    }
    return {
      ...input,
      connections: connections.map((connection) => {
        const metadata = { ...(connection.mobileMetadata || {}) };
        delete metadata.models;
        delete metadata.customModels;
        delete metadata.hiddenModelIds;
        const { modelId, ...rest } = connection;
        return {
          ...rest,
          providerKey: connection.providerKey || connection.providerId || connection.id,
          mobileMetadata: metadata,
        };
      }),
      modelSettings: grouped,
    };
  }

  function load() {
    if (!fs.existsSync(statePath)) return freshState(now);
    try {
      const parsed = JSON.parse(fs.readFileSync(statePath, 'utf8'));
      if (parsed.schemaVersion === SCHEMA_VERSION) {
        return normalize(parsed);
      }
      if (parsed.schemaVersion === 2) {
        return save(migrateV2(parsed));
      }
      if (Array.isArray(parsed.providers)) {
        return save(migrateLegacy(parsed));
      }
      throw new Error('unsupported schema');
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
