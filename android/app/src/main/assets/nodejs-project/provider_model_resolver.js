function modelId(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function parseCanonicalModel(value) {
  const canonical = modelId(value);
  if (!canonical) return null;
  const slash = canonical.indexOf('/');
  if (slash < 0) return { providerKey: null, modelId: canonical, canonical: null };
  if (slash < 1 || slash === canonical.length - 1) return null;
  return { providerKey: canonical.slice(0, slash), modelId: canonical.slice(slash + 1), canonical };
}

function descriptor(value) {
  const candidate = typeof value === 'string' ? { id: value } : value;
  const id = modelId(candidate?.id);
  return id ? { ...candidate, id } : null;
}

function buildEffectiveModels({ definition, settings = {}, liveModels = [] }) {
  const disabled = new Set((settings.disabledModelIds || []).map(modelId).filter(Boolean));
  const models = new Map();
  const add = (raw, source) => {
    const candidate = descriptor(raw);
    if (!candidate) return;
    const current = models.get(candidate.id);
    if (!current) {
      models.set(candidate.id, candidate);
      return;
    }
    if (source === 'live') {
      models.set(candidate.id, {
        ...current,
        ...(candidate.name ? { name: candidate.name } : {}),
      });
    }
  };
  for (const model of definition.models || []) add(model, 'registry');
  for (const model of liveModels) add(model, 'live');
  for (const model of settings.customModels || []) add(model, 'custom');
  return [...models.values()].filter((model) => !disabled.has(model.id));
}

function resolveProviderModel({
  connection,
  rawModel,
  legacyModel,
  catalog,
  settings = {},
  liveModels = [],
  allowLegacyBare = true,
  allowUnknownModel = false,
}) {
  const requested = parseCanonicalModel(rawModel);
  if (!requested) return { error: 400, code: 'invalid_model' };
  if (!requested.providerKey && !allowLegacyBare) return { error: 400, code: 'invalid_model' };
  const connectionKey = connection.providerKey || connection.presetId || connection.providerId;
  const provider = catalog.get(connectionKey);
  if (!provider) return { error: 400, code: 'unknown_provider' };
  const providerKey = provider.alias || provider.id;
  if (connection.enabled === false) return { error: 400, code: 'connection_disabled' };
  if (requested.providerKey) {
    const requestedProvider = catalog.get(requested.providerKey);
    if (!requestedProvider) return { error: 400, code: 'unknown_provider' };
    if (requestedProvider.id !== provider.id) {
      return { error: 409, code: 'route_connection_mismatch' };
    }
  }
  const selectedModelId = requested.modelId || modelId(legacyModel);
  const providerSettings = settings[providerKey] || settings[connectionKey] || {};
  if ((providerSettings.disabledModelIds || []).includes(selectedModelId)) {
    return { error: 400, code: 'model_disabled' };
  }
  const models = buildEffectiveModels({
    definition: provider,
    settings: providerSettings,
    liveModels,
  });
  const descriptor = models.find((model) => model.id.trim() === selectedModelId);
  const passthrough = provider.passthroughModels || connection.transportKind === 'ollamaChat';
  if (!descriptor && !passthrough && !allowUnknownModel) {
    return { error: 400, code: 'unknown_model' };
  }
  return {
    connection,
    provider,
    canonicalModel: `${providerKey}/${selectedModelId}`,
    modelId: selectedModelId,
    upstreamModelId: descriptor?.upstreamModelId || selectedModelId,
  };
}

module.exports = { buildEffectiveModels, parseCanonicalModel, resolveProviderModel };
