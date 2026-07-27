const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { timingSafeEqual, randomUUID } = require('node:crypto');
const { createStateStore } = require('./state_store');
const {
  buildEffectiveModels,
  parseCanonicalModel,
  resolveProviderModel,
} = require('./provider_model_resolver');
const { createSseUsageParser } = require('./sse_usage');
const { waitForDrainOrClose, writeWithBackpressure } = require('./stream_backpressure');
const { fetchQuota, listAntigravityModels, listCodexModels, listGeminiModels } = require('./quota_adapters');
const {
  openAiToGeminiCli,
  geminiResponseToOpenAi,
  createGeminiSseTranslator,
} = require('./gemini_cli_adapter');
const {
  openAiToAnthropic,
  anthropicResponseToOpenAi,
  createAnthropicSseTranslator,
} = require('./anthropic_messages_adapter');
const {
  openAiToGeminiContent,
  geminiContentResponseToOpenAi,
  createGeminiContentSseTranslator,
  buildGeminiContentUrl,
} = require('./gemini_content_adapter');
const {
  openAiToOllamaChat,
  ollamaChatResponseToOpenAi,
  createOllamaChatStreamTranslator,
} = require('./ollama_chat_adapter');
const {
  openAiToOpenAiResponses,
  openAiResponsesResponseToOpenAi,
  createOpenAiResponsesSseTranslator,
} = require('./openai_responses_adapter');

const [portArgument, token, dataDirArg] = process.argv.slice(2);
const port = Number(portArgument);
const providerCatalog = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'provider_catalog.json'), 'utf8'),
).providers;
const catalogByKey = new Map(providerCatalog.flatMap((provider) => [
  [provider.id, provider],
  ...(provider.alias ? [[provider.alias, provider]] : []),
]));

// Thiết lập file log
const DATA_DIR = dataDirArg || process.env.NODE_DATA_DIR || process.cwd();
const LOG_FILE = path.join(DATA_DIR, 'router_node.log');

function logToFile(msg, level = 'INFO') {
  const line = `[${new Date().toISOString()}] [${level}] ${msg}\n`;
  try {
    fs.appendFileSync(LOG_FILE, line, 'utf8');
  } catch (e) {
    // Không thể log
  }
}

// Redirect console logs
console.log = (...args) => logToFile(args.join(' '), 'INFO');
console.error = (...args) => logToFile(args.join(' '), 'ERROR');

logToFile(`Node.js Mobile runtime initialized on port ${port}`);

try {
  if (!Number.isInteger(port) || port < 1 || port > 65535 || !token) {
    throw new Error('Router core requires a valid port and internal bearer');
  }

  const stateStore = createStateStore({ dataDir: DATA_DIR });
  const runtimeSecrets = new Map();
  const refreshedModels = new Map();
  const refreshedQuota = new Set();

  const quotaSources = {
    'gemini-cli': 'gemini-cli.retrieveUserQuota',
    antigravity: 'antigravity.fetchAvailableModels',
    github: 'github.copilot_internal/user',
    openrouter: 'openrouter.auth/key',
    codex: 'codex.backend-api/wham/usage',
  };

  function quotaState(status, connection = null, details = {}) {
    return {
      status,
      connectionId: connection?.id || null,
      providerId: connection ? connection.presetId || connection.id : null,
      ...(details.source ? { source: details.source } : {}),
      plan: details.plan ?? null,
      fetchedAt: details.fetchedAt ?? null,
      entries: Array.isArray(details.entries) ? details.entries : [],
      message: details.message ?? null,
    };
  }

  function cachedQuotaFor(provider, db) {
    const snapshot = db.quota[provider.id];
    const providerId = provider.presetId || provider.id;
    if (!snapshot || snapshot.connectionId !== provider.id ||
        snapshot.providerId !== providerId ||
        snapshot.source !== quotaSources[providerId]) {
      if (snapshot) {
        delete db.quota[provider.id];
        saveDb(db);
      }
      return null;
    }
    return snapshot;
  }

  function toLegacyDb(state) {
    const activeConnectionId = state.activeRoute?.connectionId;
    return {
      providers: state.connections.map((connection) => ({
        id: connection.id,
        name: connection.displayName,
        kind: connection.mobileMetadata?.kind || 'openAiCompatible',
        presetId: connection.providerId || connection.providerKey,
        providerKey: connection.providerKey,
        baseUrl: connection.mobileMetadata?.baseUrl || '',
        systemPrompt: connection.mobileMetadata?.systemPrompt || '',
        ...(connection.mobileMetadata?.projectId
          ? { projectId: connection.mobileMetadata.projectId }
          : {}),
        ...(connection.mobileMetadata?.accountId
          ? { accountId: connection.mobileMetadata.accountId }
          : {}),
        ...(connection.mobileMetadata?.transportKind
          ? { transportKind: connection.mobileMetadata.transportKind }
          : {}),
        ...(connection.mobileMetadata?.chatUrl
          ? { chatUrl: connection.mobileMetadata.chatUrl }
          : {}),
        ...(connection.mobileMetadata?.modelsUrl
          ? { modelsUrl: connection.mobileMetadata.modelsUrl }
          : {}),
        ...(connection.mobileMetadata?.authHeader
          ? { authHeader: connection.mobileMetadata.authHeader }
          : {}),
        ...(connection.mobileMetadata?.authScheme !== undefined
          ? { authScheme: connection.mobileMetadata.authScheme }
          : {}),

        ...(connection.mobileMetadata?.staticHeaders &&
        Object.keys(connection.mobileMetadata.staticHeaders).length
          ? { staticHeaders: connection.mobileMetadata.staticHeaders }
          : {}),
        authMode: connection.authMode || 'apiKey',
        enabled: connection.enabled !== false,
        priority: connection.priority || 0,
        active: connection.id === activeConnectionId,
        apiKey: runtimeSecrets.get(connection.id)?.runtimeToken || '',
      })),
      modelSettings: state.modelSettings || {},
      usage: state.usage,
      quota: state.quota,
    };
  }

  function toSchemaV3(db) {
    const timestamp = new Date().toISOString();
    const active = db.providers.find((provider) => provider.active);
    const modelSettings = { ...(db.modelSettings || {}) };
    return {
      connections: db.providers.map((provider) => ({
        id: provider.id,
        providerId: provider.presetId || provider.id,
        providerKey: providerKeyFor(provider),
        displayName: provider.name,
        authMode: provider.authMode || 'apiKey',
        enabled: provider.enabled !== false,
        priority: Number.isFinite(provider.priority) ? provider.priority : 0,
        mobileMetadata: {
          kind: provider.kind || 'openAiCompatible',
          baseUrl: provider.baseUrl,
          systemPrompt: provider.systemPrompt || '',
          projectId: provider.projectId || '',
          accountId: provider.accountId || '',
          transportKind: provider.transportKind,
          chatUrl: provider.chatUrl,
          modelsUrl: provider.modelsUrl,
          authHeader: provider.authHeader,
          authScheme: provider.authScheme,

          staticHeaders: provider.staticHeaders && typeof provider.staticHeaders === 'object'
            ? provider.staticHeaders
            : {},
        },
        createdAt: provider.createdAt || timestamp,
        updatedAt: timestamp,
      })),
      activeRoute: active
        ? {
            connectionId: active.id,
            local: false,
          }
        : null,
      modelSettings,
      usage: db.usage,
      quota: db.quota,
    };
  }

  function loadDb() {
    const state = stateStore.load();
    let migrated = false;
    const remappedSettings = {};
    for (const [rawKey, settings] of Object.entries(state.modelSettings || {})) {
      if (rawKey === 'custom') {
        const customConnections = state.connections.filter(
          (connection) => connection.providerId === 'custom',
        );
        if (customConnections.length === 1) {
          remappedSettings[customConnections[0].id] = {
            customModels: [...(settings.customModels || [])],
            disabledModelIds: [...(settings.disabledModelIds || [])],
          };
        }
        // Multiple legacy custom endpoints share no safe routing identity.
        // Drop their shared settings rather than leaking them across routes.
        migrated = true;
        continue;
      }

      const definition = catalogByKey.get(rawKey);
      const providerKey = definition?.alias || definition?.id || rawKey;
      const target = remappedSettings[providerKey] || (remappedSettings[providerKey] = {
        customModels: [], disabledModelIds: [],
      });
      target.customModels.push(...(settings.customModels || []));
      target.disabledModelIds.push(...(settings.disabledModelIds || []));
      if (rawKey !== providerKey) migrated = true;
    }
    if (migrated) state.modelSettings = remappedSettings;
    for (const connection of state.connections) {
      const providerKey = providerKeyFor({
        id: connection.id,
        providerKey: connection.providerKey,
        presetId: connection.providerId,
      });
      if (connection.providerKey !== providerKey) {
        connection.providerKey = providerKey;
        migrated = true;
      }
    }
    return toLegacyDb(migrated ? stateStore.save(state) : state);
  }

  function saveDb(db) {
    for (const provider of db.providers) {
      const current = runtimeSecrets.get(provider.id) || {};
      const runtimeToken = provider.apiKey || current.runtimeToken;
      const sourceToken = provider.sourceToken || current.sourceToken;
      if (runtimeToken || sourceToken) {
        runtimeSecrets.set(provider.id, {
          runtimeToken: runtimeToken || null,
          sourceToken: sourceToken || null,
          secureMetadata: provider.secureMetadata || current.secureMetadata || null,
        });
      }
    }
    stateStore.save(toSchemaV3(db));
  }

  function hasValidBearer(request) {
    const value = request.headers.authorization;
    const expected = `Bearer ${token}`;
    if (typeof value !== 'string' || value.length !== expected.length) return false;
    return timingSafeEqual(Buffer.from(value), Buffer.from(expected));
  }

  function parseJsonBody(request) {
    return new Promise((resolve, reject) => {
      let body = '';
      request.on('data', chunk => { body += chunk; });
      request.on('end', () => {
        try {
          resolve(body ? JSON.parse(body) : {});
        } catch (e) {
          reject(e);
        }
      });
    });
  }

  function sendJson(response, statusCode, data) {
    response.writeHead(statusCode, { 'content-type': 'application/json' });
    response.end(JSON.stringify(data));
  }

  function sendSanitizedUpstreamError(response, upstreamResponse, _errorBody, provider) {
    logToFile(
      `Upstream ${provider.presetId || provider.id} HTTP ${upstreamResponse.status}`,
      'ERROR',
    );
    return sendJson(response, upstreamResponse.status, { error: 'upstream_request_failed' });
  }

  function providerAuthHeaders(provider) {
    if (!provider.apiKey) return {};
    const authHeader = provider.authHeader || 'Authorization';
    const authScheme = provider.authScheme === undefined || provider.authScheme === null
      ? 'Bearer'
      : provider.authScheme;
    return { [authHeader]: authScheme ? `${authScheme} ${provider.apiKey}` : provider.apiKey };
  }

  function ollamaUrl(provider, path) {
    return `${provider.baseUrl.replace(/\/$/, '')}${path}`;
  }


  function settingsForProvider(provider, db) {
    const definition = catalogByKey.get(provider.providerKey || provider.presetId || provider.id);
    const providerKey = definition?.alias || definition?.id || provider.providerKey || provider.presetId || provider.id;
    return db.modelSettings?.[providerKey] || {};
  }


  function providerKeyFor(provider) {
    if (provider.presetId === 'custom') return provider.id;
    const definition = catalogByKey.get(provider.providerKey || provider.presetId || provider.id);
    return definition?.alias || definition?.id || provider.providerKey || provider.presetId || provider.id;
  }

  function resolverCatalogFor(provider) {
    const providerKey = providerKeyFor(provider);
    if (catalogByKey.has(providerKey)) return catalogByKey;
    const custom = {
      id: providerKey,
      alias: providerKey,
      models: [],
      passthroughModels: true,
    };
    return new Map([...catalogByKey, [providerKey, custom]]);
  }

  function effectiveModelsFor(provider, db, liveModels = []) {
    const definition = catalogByKey.get(provider.providerKey || provider.presetId || provider.id) || {
      id: providerKeyFor(provider), alias: providerKeyFor(provider), models: [], passthroughModels: true,
    };
    return buildEffectiveModels({
      definition,
      settings: settingsForProvider(provider, db),
      liveModels,
    });
  }

  function serializeModels(provider, db, liveModels = []) {
    const providerKey = providerKeyFor(provider);
    return effectiveModelsFor(provider, db, liveModels).map((model) => ({
      id: `${providerKey}/${model.id}`,
      ...(typeof model.name === 'string' && model.name ? { name: model.name } : {}),
      object: 'model',
      owned_by: provider.id,
    }));
  }


  const server = http.createServer(async (request, response) => {
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');

    if (request.method === 'OPTIONS') {
      response.writeHead(200);
      response.end();
      return;
    }

    if (!hasValidBearer(request)) {
      return sendJson(response, 401, { error: 'unauthorized' });
    }

    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const db = loadDb();

    if (request.method === 'GET' && url.pathname === '/health') {
      return sendJson(response, 200, { status: 'ready', port });
    }

    if (request.method === 'GET' && url.pathname === '/v1/models') {
      const requestedConnectionId = url.searchParams.get('connectionId');
      const hasConnectionId = url.searchParams.has('connectionId');
      if (!hasConnectionId) {
        const listed = db.providers
          .filter((provider) => provider.enabled !== false)
          .flatMap((provider) => serializeModels(
            provider,
            db,
            refreshedModels.get(provider.id) || [],
          ));
        const seen = new Set();
        return sendJson(response, 200, {
          data: listed.filter((model) => !seen.has(model.id) && seen.add(model.id)),
        });
      }
      const activeProvider = hasConnectionId
        ? db.providers.find(p => p.id === requestedConnectionId)
        : db.providers.find(p => p.active) || db.providers[0];
      if (!activeProvider) {
        return sendJson(response, 200, { data: [] });
      }
      if (activeProvider.presetId === 'gemini-cli' && activeProvider.apiKey && activeProvider.projectId) {
        try {
          const ids = await listGeminiModels({
            baseUrl: activeProvider.baseUrl,
            projectId: activeProvider.projectId,
            runtimeToken: activeProvider.apiKey,
          });
          if (ids.length > 0) {
            return sendJson(response, 200, {
              data: serializeModels(activeProvider, db, ids),
            });
          }
        } catch {
          // fallback to configured models below
        }
      }
      if (activeProvider.presetId === 'codex' && activeProvider.apiKey) {
        try {
          const models = await listCodexModels({ runtimeToken: activeProvider.apiKey });
          if (models.length > 0) {
            refreshedModels.set(activeProvider.id, models);
            return sendJson(response, 200, {
              data: serializeModels(activeProvider, db, models),
            });
          }
        } catch (_) {
          // Static catalog remains usable when Codex discovery fails.
        }
      }
      if (activeProvider.presetId === 'antigravity') {
        if (!activeProvider.apiKey) {
          return sendJson(response, 502, { error: 'upstream_models_unavailable' });
        }
        try {
          const models = await listAntigravityModels({
            baseUrl: activeProvider.baseUrl,
            projectId: activeProvider.projectId,
            runtimeToken: activeProvider.apiKey,
            configuredModels: effectiveModelsFor(activeProvider, db),
          });
          if (models.length > 0) {
            return sendJson(response, 200, {
              data: serializeModels(activeProvider, db, models),
            });
          }
        } catch (error) {
          const statusCode = Number.isInteger(error?.statusCode) ? error.statusCode : 502;
          return sendJson(response, statusCode, { error: 'upstream_models_unavailable' });
        }
      }
      if (activeProvider.presetId === 'github' && activeProvider.apiKey) {
        try {
          const upstream = await fetch(`${activeProvider.baseUrl}/models`, {
            headers: {
              'authorization': `Bearer ${activeProvider.apiKey}`,
              'accept': 'application/json',
              'copilot-integration-id': 'vscode-chat',
              'editor-version': 'vscode/1.110.0',
              'editor-plugin-version': 'copilot-chat/0.38.0',
              'user-agent': 'GitHubCopilotChat/0.38.0',
              'x-github-api-version': '2025-04-01',
            },
          });
          const payload = Buffer.from(await upstream.arrayBuffer());
          if (upstream.ok) {
            const parsed = JSON.parse(payload.toString('utf8'));
            if (Array.isArray(parsed?.data) && parsed.data.every(
              (model) => model && typeof model.id === 'string' && model.id.trim(),
            )) {
              return sendJson(response, 200, { data: serializeModels(activeProvider, db, parsed.data) });
            }
          }
          response.writeHead(upstream.status, {
            'content-type': upstream.headers.get('content-type') || 'application/json',
          });
          response.end(payload);
          return;
        } catch {
          return sendJson(response, 502, { error: 'upstream_models_unavailable' });
        }
      }
      if (activeProvider.transportKind === 'ollamaChat') {
        try {
          const upstream = await fetch(ollamaUrl(activeProvider, '/api/tags'), {
            headers: { accept: 'application/json', ...providerAuthHeaders(activeProvider) },
          });
          if (upstream.ok) {
            const payload = await upstream.json();
            if (Array.isArray(payload?.models) && payload.models.every(
              (model) => model && typeof model.name === 'string' && model.name.trim(),
            )) {
              return sendJson(response, 200, {
                data: serializeModels(activeProvider, db, payload.models.map((model) => ({ id: model.name }))),
              });
            }
          }
        } catch (_) {}
      }
      if (activeProvider.modelsUrl) {
        try {
          const upstream = await fetch(activeProvider.modelsUrl, {
            headers: { accept: 'application/json', ...providerAuthHeaders(activeProvider) },
          });
          if (upstream.ok) {
            const payload = await upstream.json();
            if (Array.isArray(payload?.data) && payload.data.every(
              (model) => model && typeof model.id === 'string' && model.id.trim(),
            )) {
              return sendJson(response, 200, { data: serializeModels(activeProvider, db, payload.data) });
            }
          }
        } catch (_) {}
      }
      return sendJson(response, 200, {
        data: serializeModels(activeProvider, db),
      });
    }

    if (request.method === 'POST' && url.pathname === '/v1/chat/completions') {
      try {
        const requestedConnectionId = url.searchParams.get('connectionId');
        const hasConnectionId = url.searchParams.has('connectionId');
        let activeProvider = hasConnectionId
          ? db.providers.find(p => p.id === requestedConnectionId)
          : db.providers.find(p => p.active) || db.providers[0];
        if (hasConnectionId && !activeProvider) {
          return sendJson(response, hasConnectionId ? 404 : 400, {
            error: hasConnectionId
              ? 'Provider connection not found'
              : 'No active provider connection configured',
          });
        }

        let body = await parseJsonBody(request);
        const requestedModel = parseCanonicalModel(body.model);
        if (!hasConnectionId && requestedModel?.providerKey) {
          const requestedDefinition = catalogByKey.get(requestedModel.providerKey);
          const candidates = db.providers.filter((provider) => {
            if (provider.enabled === false) return false;
            const connectionKey = providerKeyFor(provider);
            const connectionDefinition = catalogByKey.get(connectionKey);
            return connectionKey === requestedModel.providerKey ||
              (requestedDefinition && connectionDefinition?.id === requestedDefinition.id);
          }).sort((a, b) => (a.priority || 0) - (b.priority || 0));
          if (!candidates.length) {
            return sendJson(response, 400, {
              error: requestedDefinition ? 'no_enabled_provider_connection' : 'unknown_provider',
            });
          }
          activeProvider = candidates[0];
        }
        if (!activeProvider) {
          return sendJson(response, 400, { error: 'No active provider connection configured' });
        }
        const requestedStream = body.stream === true || activeProvider.presetId === 'codex';
        const rawModel = typeof body.model === 'string' ? body.model.trim() : '';
        const resolved = resolveProviderModel({
          connection: activeProvider,
          rawModel,
          legacyModel: null,
          catalog: resolverCatalogFor(activeProvider),
          settings: db.modelSettings,
          liveModels: refreshedModels.get(activeProvider.id) || [],
          allowLegacyBare: !hasConnectionId,
        });
        if (resolved.error) return sendJson(response, resolved.error, { error: resolved.code });
        const isCodex = activeProvider.presetId === 'codex';
        const selectedModel = resolved.modelId;
        const upstreamModel = resolved.upstreamModelId;
        body.model = upstreamModel;
        const isGeminiCli = activeProvider.presetId === 'gemini-cli' || activeProvider.presetId === 'antigravity';
        const isAnthropicMessages = activeProvider.transportKind === 'anthropicMessages';
        const isGeminiContent = activeProvider.transportKind === 'geminiContent';
        const isOllamaChat = activeProvider.transportKind === 'ollamaChat';
        const isOpenAiResponses = activeProvider.transportKind === 'openaiResponses' || isCodex;

        const headers = {
          'content-type': 'application/json',
        };
        if (isGeminiCli) {
          const isAntigravityMode = activeProvider.presetId === 'antigravity';
          Object.assign(headers, {
            'accept': requestedStream ? 'text/event-stream' : 'application/json',
            'user-agent': isAntigravityMode ? `antigravity/ide/2.1.1 darwin/arm64` : `GeminiCLI/0.34.0/${selectedModel} (android; arm64)`,
            'x-goog-api-client': isAntigravityMode ? 'google-cloud-sdk vscode_cloudshelleditor/0.1' : 'google-genai-sdk/1.41.0 gl-node/v22.19.0',
          });
          if (isAntigravityMode) {
            headers['client-metadata'] = JSON.stringify({ ideType: 9, platform: 2, pluginType: 2 });
          }
          body = openAiToGeminiCli(body, selectedModel, activeProvider.projectId, isAntigravityMode);
        }
        if (isAnthropicMessages) {
          headers.accept = requestedStream ? 'text/event-stream' : 'application/json';
          headers['anthropic-version'] =
            activeProvider.staticHeaders?.['anthropic-version'] || '2023-06-01';
          body = openAiToAnthropic(body, selectedModel);
        }
        if (isGeminiContent) {
          headers.accept = requestedStream ? 'text/event-stream' : 'application/json';
          body = openAiToGeminiContent(body);
        }
        if (isOllamaChat) {
          body = openAiToOllamaChat(body, selectedModel);
        }
        if (isOpenAiResponses) {
          body = openAiToOpenAiResponses(body, upstreamModel, { isCodex });
          if (isCodex) body.stream = true;
        }

        if (isCodex) {
          Object.assign(headers, {
            accept: 'text/event-stream',
            'user-agent': 'codex_cli_rs/0.136.0',
            originator: 'codex_cli_rs',
            session_id: randomUUID(),
          });
          if (activeProvider.accountId) {
            headers['ChatGPT-Account-ID'] = activeProvider.accountId;
          }
        }

        if (activeProvider.presetId === 'github') {
          Object.assign(headers, {
            'accept': requestedStream ? 'text/event-stream' : 'application/json',
            'copilot-integration-id': 'vscode-chat',
            'editor-version': 'vscode/1.110.0',
            'editor-plugin-version': 'copilot-chat/0.38.0',
            'user-agent': 'GitHubCopilotChat/0.38.0',
            'openai-intent': 'conversation-panel',
            'x-github-api-version': '2025-04-01',
            'x-request-id': randomUUID(),
            'x-vscode-user-agent-library-version': 'electron-fetch',
            'x-initiator': 'user',
            'anthropic-version': '2023-06-01',
          });
        }

        const customKey = request.headers['x-provider-key'];
        const providerKey = customKey || activeProvider.apiKey;
        if (providerKey) {
          const authHeader = activeProvider.authHeader || 'Authorization';
          const authScheme = activeProvider.authScheme === undefined || activeProvider.authScheme === null
            ? 'Bearer'
            : activeProvider.authScheme;
          headers[authHeader] = authScheme ? `${authScheme} ${providerKey}` : providerKey;
        }

        const startTime = Date.now();
        const targetUrl = isGeminiCli
          ? `${activeProvider.baseUrl}:${requestedStream ? 'streamGenerateContent?alt=sse' : 'generateContent'}`
          : isGeminiContent
            ? buildGeminiContentUrl(activeProvider.baseUrl, selectedModel, requestedStream, providerKey)
            : isOllamaChat
              ? ollamaUrl(activeProvider, '/api/chat')
            : ['openaiChat', 'anthropicMessages', 'ollamaChat', 'openaiResponses'].includes(activeProvider.transportKind) && activeProvider.chatUrl
              ? activeProvider.chatUrl
              : `${activeProvider.baseUrl}/chat/completions`;

        if (requestedStream) {
          if (!isGeminiCli && !isAnthropicMessages && !isOpenAiResponses) {
            body.stream_options = { ...(body.stream_options || {}), include_usage: true };
          }
          const upstreamController = new AbortController();
          let downstreamOpen = true;
          let reader;
          let upstreamTimedOut = false;
          let streamWatchdog;
          const clearWatchdog = () => {
            if (streamWatchdog) clearTimeout(streamWatchdog);
            streamWatchdog = undefined;
          };
          const armWatchdog = () => {
            if (!isOllamaChat) return;
            clearWatchdog();
            const timeout = Math.max(10, Number(process.env.OLLAMA_STREAM_TIMEOUT_MS) || 15000);
            streamWatchdog = setTimeout(() => {
              upstreamTimedOut = true;
              upstreamController.abort();
            }, timeout);
          };
          const closeDownstream = () => {
            downstreamOpen = false;
            clearWatchdog();
            upstreamController.abort();
            reader?.cancel().catch(() => {});
          };
          response.once('close', closeDownstream);
          response.once('error', closeDownstream);
          armWatchdog();
          let upstreamResponse;
          try {
            upstreamResponse = await fetch(targetUrl, {
              method: 'POST',
              headers,
              body: JSON.stringify(body),
              signal: upstreamController.signal,
            });
          } catch (_) {
            clearWatchdog();
            response.removeListener('close', closeDownstream);
            response.removeListener('error', closeDownstream);
            if (!downstreamOpen) return;
            return sendJson(response, upstreamTimedOut ? 504 : 502, {
              error: upstreamTimedOut ? 'upstream_stream_timeout' : 'upstream_request_failed',
            });
          }
          clearWatchdog();

          if (!upstreamResponse.ok) {
            response.removeListener('close', closeDownstream);
            response.removeListener('error', closeDownstream);
            const errorBody = Buffer.from(await upstreamResponse.arrayBuffer());
            sendSanitizedUpstreamError(response, upstreamResponse, errorBody, activeProvider);
            db.usage.push({
              id: randomUUID(), timestamp: new Date().toISOString(),
              providerId: activeProvider.presetId || activeProvider.id,
              connectionId: activeProvider.id, modelId: resolved.canonicalModel,
              status: 'error', promptTokens: 0, completionTokens: 0,
              cachedTokens: 0, estimatedCost: 0.0,
              latencyMs: Date.now() - startTime
            });
            saveDb(db);
            return;
          }

          response.writeHead(upstreamResponse.status, {
            'content-type': 'text/event-stream',
            'cache-control': 'no-cache',
            'connection': 'keep-alive',
          });

          reader = upstreamResponse.body.getReader();
          armWatchdog();
          const decoder = new TextDecoder();
          const usageParser = createSseUsageParser();
          const geminiTranslator = isGeminiCli
            ? createGeminiSseTranslator(selectedModel)
            : null;
          const anthropicTranslator = isAnthropicMessages
            ? createAnthropicSseTranslator(selectedModel)
            : null;
          const geminiContentTranslator = isGeminiContent
            ? createGeminiContentSseTranslator(selectedModel)
            : null;
          const ollamaTranslator = isOllamaChat
            ? createOllamaChatStreamTranslator(selectedModel)
            : null;
          const openAiResponsesTranslator = isOpenAiResponses
            ? createOpenAiResponsesSseTranslator(selectedModel)
            : null;
          try {
            while (downstreamOpen) {
              const { done, value } = await reader.read();
              if (done) break;
              armWatchdog();
              const chunk = decoder.decode(value, { stream: true });
              if (geminiTranslator || anthropicTranslator || geminiContentTranslator || ollamaTranslator || openAiResponsesTranslator) {
                const translator = geminiTranslator || anthropicTranslator || geminiContentTranslator || ollamaTranslator || openAiResponsesTranslator;
                for (const translated of translator.push(chunk)) {
                  downstreamOpen = await writeWithBackpressure(response, translated);
                  if (!downstreamOpen) break;
                }
              } else {
                usageParser.push(chunk);
                if (!response.write(value)) {
                  downstreamOpen = await waitForDrainOrClose(response);
                }
              }
            }
          } catch (error) {
            if (downstreamOpen && upstreamTimedOut) {
              downstreamOpen = await writeWithBackpressure(
                response,
                'data: {"error":"upstream_stream_timeout"}\n\n',
              );
              if (downstreamOpen) {
                await writeWithBackpressure(response, 'data: [DONE]\n\n');
              }
              response.end();
              return;
            }
            throw error;
          } finally {
            clearWatchdog();
            response.removeListener('close', closeDownstream);
            response.removeListener('error', closeDownstream);
            if (!downstreamOpen) await reader.cancel().catch(() => {});
          }
          if (!downstreamOpen) return;
          let usage;
          if (geminiTranslator || anthropicTranslator || geminiContentTranslator || ollamaTranslator || openAiResponsesTranslator) {
            const translator = geminiTranslator || anthropicTranslator || geminiContentTranslator || ollamaTranslator || openAiResponsesTranslator;
            const terminal = translator.finish();
            for (const translated of terminal.output) {
              downstreamOpen = await writeWithBackpressure(response, translated);
              if (!downstreamOpen) break;
            }
            if (!downstreamOpen) return;
            usage = {
              promptTokens: terminal.usage.prompt_tokens,
              completionTokens: terminal.usage.completion_tokens,
              cachedTokens: 0,
            };
          } else {
            usageParser.push(decoder.decode());
            usage = usageParser.finish();
          }
          response.end();

          db.usage.push({
            id: randomUUID(),
            timestamp: new Date().toISOString(),
            providerId: activeProvider.presetId || activeProvider.id,
            connectionId: activeProvider.id,
            modelId: resolved.canonicalModel,
            status: upstreamResponse.ok ? 'success' : 'error',
            promptTokens: usage.promptTokens,
            completionTokens: usage.completionTokens,
            cachedTokens: usage.cachedTokens,
            estimatedCost: 0.0,
            latencyMs: Date.now() - startTime
          });
          saveDb(db);
          return;
        } else {
          const upstreamResponse = await fetch(targetUrl, {
            method: 'POST',
            headers,
            body: JSON.stringify(body)
          });

          const upstreamBody = Buffer.from(await upstreamResponse.arrayBuffer());
          if (!upstreamResponse.ok) {
            return sendSanitizedUpstreamError(
              response,
              upstreamResponse,
              upstreamBody,
              activeProvider,
            );
          }
          const upstreamData = JSON.parse(upstreamBody.toString('utf8'));
          const resData = isGeminiCli
            ? geminiResponseToOpenAi(upstreamData, selectedModel)
            : isAnthropicMessages
              ? anthropicResponseToOpenAi(upstreamData, selectedModel)
            : isGeminiContent
                ? geminiContentResponseToOpenAi(upstreamData, selectedModel)
                : isOllamaChat
                  ? ollamaChatResponseToOpenAi(upstreamData, selectedModel)
                  : isOpenAiResponses
                    ? openAiResponsesResponseToOpenAi(upstreamData, selectedModel)
                    : upstreamData;
          sendJson(response, upstreamResponse.status, resData);

          if (upstreamResponse.ok) {
            const usage = resData.usage || { prompt_tokens: 0, completion_tokens: 0 };
            db.usage.push({
              id: randomUUID(),
              timestamp: new Date().toISOString(),
              providerId: activeProvider.presetId || activeProvider.id,
              connectionId: activeProvider.id,
              modelId: resolved.canonicalModel,
              status: 'success',
              promptTokens: usage.prompt_tokens,
              completionTokens: usage.completion_tokens,
              cachedTokens: 0,
              estimatedCost: 0.0,
              latencyMs: Date.now() - startTime
            });
            saveDb(db);
          }
          return;
        }
      } catch (e) {
        // Error messages can embed upstream bodies or credentials. Log class only.
        const errorName = typeof e?.name === 'string' && /^[A-Za-z]+Error$/.test(e.name)
          ? e.name
          : 'Error';
        logToFile(`Chat routing failed: ${errorName}`, 'ERROR');
        if (response.destroyed || response.writableEnded) return;
        if (response.headersSent) {
          response.destroy();
          return;
        }
        return sendJson(response, 500, { error: 'chat_routing_failed' });
      }
    }

    if (request.method === 'GET' && url.pathname === '/internal/providers') {
      return sendJson(response, 200, db.providers.map((provider) => ({
        id: provider.id,
        providerId: provider.presetId,
        providerKey: provider.providerKey,
        displayName: provider.name,
        authMode: provider.authMode,
        enabled: provider.enabled !== false,
        priority: provider.priority || 0,
        mobileMetadata: {
          kind: provider.kind, baseUrl: provider.baseUrl, systemPrompt: provider.systemPrompt,
          projectId: provider.projectId, accountId: provider.accountId,
          transportKind: provider.transportKind, chatUrl: provider.chatUrl,
          modelsUrl: provider.modelsUrl, authHeader: provider.authHeader,
          authScheme: provider.authScheme, staticHeaders: provider.staticHeaders,
        },
      })));
    }

    if (url.pathname.startsWith('/internal/model-settings/')) {
      const rawProviderKey = decodeURIComponent(url.pathname.slice('/internal/model-settings/'.length));
      const definition = catalogByKey.get(rawProviderKey);
      const providerKey = definition?.alias || definition?.id || rawProviderKey;
      if (!definition && !db.providers.some((provider) => providerKeyFor(provider) === providerKey)) {
        return sendJson(response, 400, { error: 'unknown_provider' });
      }
      if (request.method === 'GET') return sendJson(response, 200, db.modelSettings?.[providerKey] || {
        customModels: [], disabledModelIds: [],
      });
      if (request.method === 'PUT') {
        try {
          const data = await parseJsonBody(request);
          db.modelSettings = {
            ...(db.modelSettings || {}),
            [providerKey]: {
              customModels: Array.isArray(data.customModels) ? data.customModels : [],
              disabledModelIds: Array.isArray(data.disabledModelIds) ? data.disabledModelIds : [],
            },
          };
          saveDb(db);
          return sendJson(response, 200, { success: true });
        } catch (_) {
          return sendJson(response, 400, { error: 'Invalid JSON' });
        }
      }
    }

    if (request.method === 'POST' && url.pathname === '/internal/providers') {
      try {
        const data = await parseJsonBody(request);
        if (!data.id || !data.name || !data.baseUrl) {
          return sendJson(response, 400, { error: 'Missing required fields' });
        }

        if (data.active) {
          db.providers.forEach(p => p.active = false);
        }

        db.providers.push({
          id: data.id,
          name: data.name,
          kind: data.kind || 'openAiCompatible',
          presetId: data.presetId || data.id,
          providerKey: providerKeyFor({
            id: data.id,
            providerKey: data.providerKey,
            presetId: data.presetId || data.id,
          }),
          baseUrl: data.baseUrl,
          systemPrompt: data.systemPrompt || '',
          authMode: data.authMode || 'apiKey',
          enabled: data.enabled !== false,
          priority: Number.isFinite(data.priority) ? data.priority : 0,
          projectId: data.projectId || '',
          accountId: data.accountId || '',
          transportKind: data.transportKind,
          chatUrl: data.chatUrl,
          modelsUrl: data.modelsUrl,
          authHeader: data.authHeader,
          authScheme: data.authScheme,

          staticHeaders: data.staticHeaders && typeof data.staticHeaders === 'object'
            ? data.staticHeaders
            : {},
          active: !!data.active,
          apiKey: data.apiKey || '',
          sourceToken: data.sourceToken || ''
        });

        saveDb(db);
        return sendJson(response, 201, { success: true });
      } catch (e) {
        return sendJson(response, 400, { error: 'Invalid JSON' });
      }
    }

    if (request.method === 'PATCH' && url.pathname.startsWith('/internal/providers/')) {
      const id = url.pathname.split('/').pop();
      const provider = db.providers.find(p => p.id === id);
      if (!provider) {
        return sendJson(response, 404, { error: 'Provider connection not found' });
      }

      try {
        const data = await parseJsonBody(request);
        if (data.name !== undefined) provider.name = data.name;
        if (data.baseUrl !== undefined) provider.baseUrl = data.baseUrl;
        if (data.enabled !== undefined) provider.enabled = data.enabled !== false;
        if (Number.isFinite(data.priority)) provider.priority = data.priority;
        if (data.systemPrompt !== undefined) provider.systemPrompt = data.systemPrompt;
        if (data.projectId !== undefined) provider.projectId = data.projectId;
        if (data.accountId !== undefined) provider.accountId = data.accountId;
        if (data.transportKind !== undefined) provider.transportKind = data.transportKind;
        if (data.chatUrl !== undefined) provider.chatUrl = data.chatUrl;
        if (data.modelsUrl !== undefined) provider.modelsUrl = data.modelsUrl;
        if (data.authHeader !== undefined) provider.authHeader = data.authHeader;
        if (data.authScheme !== undefined) provider.authScheme = data.authScheme;
        if (data.staticHeaders !== undefined) {
          provider.staticHeaders = data.staticHeaders && typeof data.staticHeaders === 'object'
            ? data.staticHeaders
            : {};
        }
        if (data.apiKey !== undefined) provider.apiKey = data.apiKey;
        if (data.sourceToken !== undefined) provider.sourceToken = data.sourceToken;
        if (data.active !== undefined) {
          provider.active = !!data.active;
          if (provider.active) {
            db.providers.forEach(p => { if (p.id !== id) p.active = false; });
          }
        }

        saveDb(db);
        return sendJson(response, 200, { success: true });
      } catch (e) {
        return sendJson(response, 400, { error: 'Invalid JSON' });
      }
    }

    if (request.method === 'DELETE' && url.pathname.startsWith('/internal/providers/')) {
      const id = url.pathname.split('/').pop();
      const index = db.providers.findIndex(p => p.id === id);
      if (index === -1) {
        return sendJson(response, 404, { error: 'Provider connection not found' });
      }

      db.providers.splice(index, 1);
      runtimeSecrets.delete(id);
      refreshedQuota.delete(id);
      delete db.quota[id];
      saveDb(db);
      return sendJson(response, 200, { success: true });
    }

    if (request.method === 'POST' && url.pathname.endsWith('/test')) {
      const paths = url.pathname.split('/');
      const id = paths[paths.length - 2];
      const provider = db.providers.find(p => p.id === id);
      if (!provider) {
        return sendJson(response, 404, { error: 'Provider connection not found' });
      }

      try {
        const headers = {
          'content-type': 'application/json',
        };
        const customKey = request.headers['x-provider-key'];
        if (customKey) {
          headers['x-provider-key'] = customKey;
        } else if (provider.apiKey) {
          headers['authorization'] = `Bearer ${provider.apiKey}`;
        }

        const res = await fetch(`${provider.baseUrl}/models`, { method: 'GET', headers });
        if (res.ok) {
          return sendJson(response, 200, { success: true });
        } else {
          return sendJson(response, res.status, { error: `Upstream error: ${res.statusText}` });
        }
      } catch (e) {
        return sendJson(response, 500, { error: e.message });
      }
    }

    if (request.method === 'GET' && url.pathname === '/internal/usage/stats') {
      return sendJson(response, 200, db.usage);
    }

    if (request.method === 'DELETE' && url.pathname === '/internal/usage') {
      db.usage = [];
      saveDb(db);
      return sendJson(response, 200, { success: true });
    }

    if (request.method === 'GET' && url.pathname.startsWith('/internal/quota')) {
      const connectionId = url.pathname.split('/')[3];
      const provider = connectionId
        ? db.providers.find(p => p.id === connectionId)
        : db.providers.find(p => p.active);
      if (!provider) {
        return sendJson(response, connectionId ? 404 : 200, connectionId
          ? quotaState('error', { id: connectionId }, { message: 'Provider connection not found' })
          : quotaState('no_active_connection'));
      }
      const snapshot = cachedQuotaFor(provider, db);
      if (!snapshot) return sendJson(response, 200, quotaState('unavailable', provider));
      return sendJson(response, 200, {
        ...snapshot,
        status: refreshedQuota.has(provider.id) ? 'fresh' : 'stale',
      });
    }

    if (request.method === 'POST' && url.pathname.startsWith('/internal/quota/')) {
      const paths = url.pathname.split('/');
      const connectionId = paths[paths.length - 2];
      const provider = db.providers.find(p => p.id === connectionId);
      if (!provider) {
        return sendJson(response, 404, { error: 'Provider connection not found' });
      }

      const cachedSnapshot = cachedQuotaFor(provider, db);
      try {
        const snapshot = await fetchQuota({
          connection: {
            id: provider.id,
            providerId: provider.presetId || provider.id,
            baseUrl: provider.baseUrl,
            projectId: provider.projectId,
            models: effectiveModelsFor(provider, db),
          },
          secrets: runtimeSecrets.get(provider.id) || {},
        });
        db.quota[connectionId] = snapshot;
        refreshedQuota.add(connectionId);
        saveDb(db);
        return sendJson(response, 200, snapshot);
      } catch (error) {
        const statusCode = Number.isInteger(error?.statusCode) ? error.statusCode : 502;
        if (cachedSnapshot) {
          return sendJson(response, 200, {
            ...cachedSnapshot,
            status: 'stale',
            message: error?.message || 'Quota unavailable',
          });
        }
        const quotaStatus = error?.code === 'unsupported' ? 'unsupported' : 'error';
        return sendJson(response, statusCode, quotaState(quotaStatus, provider, {
          message: error?.message || 'Quota unavailable',
        }));
      }
    }

    if (request.method === 'POST' && url.pathname === '/internal/reset') {
      const dbReset = {
        providers: [],
        usage: [],
        quota: {}
      };
      runtimeSecrets.clear();
      refreshedQuota.clear();
      saveDb(dbReset);
      return sendJson(response, 200, { success: true });
    }

    sendJson(response, 404, { error: 'not_found' });
  });

  server.listen({ host: '127.0.0.1', port }, () => {
    logToFile(`Embedded core listening on 127.0.0.1:${port}`);
  });
} catch (e) {
  logToFile('Fatal crash in Node process: ' + e.stack, 'ERROR');
}
