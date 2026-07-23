const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { timingSafeEqual, randomUUID } = require('node:crypto');
const { createStateStore } = require('./state_store');
const { createSseUsageParser } = require('./sse_usage');
const { waitForDrainOrClose } = require('./stream_backpressure');
const {
  openAiToGeminiCli,
  geminiResponseToOpenAi,
  createGeminiSseTranslator,
} = require('./gemini_cli_adapter');

const [portArgument, token, dataDirArg] = process.argv.slice(2);
const port = Number(portArgument);

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

  function toLegacyDb(state) {
    const activeConnectionId = state.activeRoute?.connectionId;
    return {
      providers: state.connections.map((connection) => ({
        id: connection.id,
        name: connection.displayName,
        kind: connection.mobileMetadata?.kind || 'openAiCompatible',
        presetId: connection.providerId,
        baseUrl: connection.mobileMetadata?.baseUrl || '',
        modelId: connection.modelId,
        systemPrompt: connection.mobileMetadata?.systemPrompt || '',
        ...(connection.mobileMetadata?.projectId
          ? { projectId: connection.mobileMetadata.projectId }
          : {}),
        authMode: connection.authMode || 'apiKey',
        active: connection.id === activeConnectionId,
        apiKey: runtimeSecrets.get(connection.id) || '',
      })),
      usage: state.usage,
      quota: state.quota,
    };
  }

  function toSchemaV2(db) {
    const timestamp = new Date().toISOString();
    const active = db.providers.find((provider) => provider.active);
    return {
      connections: db.providers.map((provider) => ({
        id: provider.id,
        providerId: provider.presetId || provider.id,
        displayName: provider.name,
        authMode: provider.authMode || 'apiKey',
        modelId: provider.modelId,
        enabled: true,
        mobileMetadata: {
          kind: provider.kind || 'openAiCompatible',
          baseUrl: provider.baseUrl,
          systemPrompt: provider.systemPrompt || '',
          projectId: provider.projectId || '',
        },
        createdAt: provider.createdAt || timestamp,
        updatedAt: timestamp,
      })),
      activeRoute: active
        ? { connectionId: active.id, modelId: active.modelId, local: false }
        : null,
      usage: db.usage,
      quota: db.quota,
    };
  }

  function loadDb() {
    return toLegacyDb(stateStore.load());
  }

  function saveDb(db) {
    for (const provider of db.providers) {
      if (provider.apiKey) runtimeSecrets.set(provider.id, provider.apiKey);
    }
    stateStore.save(toSchemaV2(db));
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
      const activeProvider =
        (requestedConnectionId && db.providers.find(p => p.id === requestedConnectionId)) ||
        db.providers.find(p => p.active) ||
        db.providers[0];
      if (!activeProvider) {
        return sendJson(response, 200, { data: [] });
      }
      if (activeProvider.presetId === 'gemini-cli' && activeProvider.apiKey && activeProvider.projectId) {
        try {
          const upstream = await fetch(`${activeProvider.baseUrl}:retrieveUserQuota`, {
            method: 'POST',
            headers: {
              'authorization': `Bearer ${activeProvider.apiKey}`,
              'content-type': 'application/json',
            },
            body: JSON.stringify({ project: activeProvider.projectId }),
          });
          if (!upstream.ok) {
            return sendJson(response, 502, { error: 'upstream_models_unavailable' });
          }
          const payload = await upstream.json();
          const ids = [...new Set(
            (Array.isArray(payload.buckets) ? payload.buckets : [])
              .map((bucket) => bucket?.modelId)
              .filter((id) => typeof id === 'string' && id.length > 0),
          )];
          return sendJson(response, 200, {
            data: ids.map((id) => ({ id, object: 'model', owned_by: 'gemini-cli' })),
          });
        } catch {
          return sendJson(response, 502, { error: 'upstream_models_unavailable' });
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
          response.writeHead(upstream.status, {
            'content-type': upstream.headers.get('content-type') || 'application/json',
          });
          response.end(payload);
          return;
        } catch {
          return sendJson(response, 502, { error: 'upstream_models_unavailable' });
        }
      }
      return sendJson(response, 200, {
        data: [
          { id: activeProvider.modelId, object: 'model', owned_by: activeProvider.id }
        ]
      });
    }

    if (request.method === 'POST' && url.pathname === '/v1/chat/completions') {
      try {
        const activeProvider = db.providers.find(p => p.active) || db.providers[0];
        if (!activeProvider) {
          return sendJson(response, 400, { error: 'No active provider connection configured' });
        }

        let body = await parseJsonBody(request);
        const requestedStream = body.stream === true;
        body.model = activeProvider.modelId;
        const isGeminiCli = activeProvider.presetId === 'gemini-cli';

        const headers = {
          'content-type': 'application/json',
        };
        if (isGeminiCli) {
          Object.assign(headers, {
            'accept': requestedStream ? 'text/event-stream' : 'application/json',
            'user-agent': `GeminiCLI/0.34.0/${activeProvider.modelId} (android; arm64)`,
            'x-goog-api-client': 'google-genai-sdk/1.41.0 gl-node/v22.19.0',
          });
          body = openAiToGeminiCli(body, activeProvider.modelId, activeProvider.projectId);
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
        if (customKey) {
          headers['authorization'] = `Bearer ${customKey}`;
        } else if (activeProvider.apiKey) {
          headers['authorization'] = `Bearer ${activeProvider.apiKey}`;
        }

        const startTime = Date.now();
        const targetUrl = isGeminiCli
          ? `${activeProvider.baseUrl}:${requestedStream ? 'streamGenerateContent?alt=sse' : 'generateContent'}`
          : `${activeProvider.baseUrl}/chat/completions`;

        if (requestedStream) {
          if (!isGeminiCli) {
            body.stream_options = { ...(body.stream_options || {}), include_usage: true };
          }
          const providerKey = customKey || activeProvider.apiKey;
          const upstreamResponse = await fetch(targetUrl, {
            method: 'POST',
            headers: {
              ...headers,
              ...(providerKey ? { authorization: `Bearer ${providerKey}` } : {})
            },
            body: JSON.stringify(body)
          });

          if (!upstreamResponse.ok) {
            const errorBody = Buffer.from(await upstreamResponse.arrayBuffer());
            try {
              const parsedError = JSON.parse(errorBody.toString('utf8'));
              const detail = parsedError.error || parsedError;
              const safeMessage = String(detail.message || '')
                .split(/\s+/)
                .join(' ')
                .replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]')
                .slice(0, 300);
              logToFile(
                `Upstream ${activeProvider.presetId || activeProvider.id} HTTP ${upstreamResponse.status}: ` +
                JSON.stringify({ code: detail.code, type: detail.type, message: safeMessage }),
                'ERROR',
              );
            } catch (_) {
              logToFile(`Upstream ${activeProvider.presetId || activeProvider.id} HTTP ${upstreamResponse.status}`, 'ERROR');
            }
            response.writeHead(upstreamResponse.status, {
              'content-type': upstreamResponse.headers.get('content-type') || 'application/json',
            });
            response.end(errorBody);
            db.usage.push({
              id: randomUUID(), timestamp: new Date().toISOString(),
              providerId: activeProvider.presetId || activeProvider.id,
              connectionId: activeProvider.id, modelId: activeProvider.modelId,
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

          const reader = upstreamResponse.body.getReader();
          const decoder = new TextDecoder();
          const usageParser = createSseUsageParser();
          const geminiTranslator = isGeminiCli
            ? createGeminiSseTranslator(activeProvider.modelId)
            : null;
          let downstreamOpen = true;
          const closeDownstream = () => {
            downstreamOpen = false;
            reader.cancel().catch(() => {});
          };
          response.once('close', closeDownstream);
          response.once('error', closeDownstream);

          try {
            while (downstreamOpen) {
              const { done, value } = await reader.read();
              if (done) break;
              const chunk = decoder.decode(value, { stream: true });
              if (geminiTranslator) {
                for (const translated of geminiTranslator.push(chunk)) {
                  if (!response.write(translated)) {
                    downstreamOpen = await waitForDrainOrClose(response);
                    if (!downstreamOpen) break;
                  }
                }
              } else {
                usageParser.push(chunk);
                if (!response.write(value)) {
                  downstreamOpen = await waitForDrainOrClose(response);
                }
              }
            }
          } finally {
            response.removeListener('close', closeDownstream);
            response.removeListener('error', closeDownstream);
            if (!downstreamOpen) await reader.cancel().catch(() => {});
          }
          if (!downstreamOpen) return;
          let usage;
          if (geminiTranslator) {
            const terminal = geminiTranslator.finish();
            for (const translated of terminal.output) response.write(translated);
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
            modelId: activeProvider.modelId,
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

          const upstreamData = await upstreamResponse.json();
          const resData = isGeminiCli && upstreamResponse.ok
            ? geminiResponseToOpenAi(upstreamData, activeProvider.modelId)
            : upstreamData;
          sendJson(response, upstreamResponse.status, resData);

          if (upstreamResponse.ok) {
            const usage = resData.usage || { prompt_tokens: 0, completion_tokens: 0 };
            db.usage.push({
              id: randomUUID(),
              timestamp: new Date().toISOString(),
              providerId: activeProvider.id,
              modelId: activeProvider.modelId,
              promptTokens: usage.prompt_tokens,
              completionTokens: usage.completion_tokens,
              cost: 0.0,
              latency: Date.now() - startTime
            });
            saveDb(db);
          }
          return;
        }
      } catch (e) {
        const safeMessage = String(e?.message || e)
          .split(/\s+/)
          .join(' ')
          .replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]')
          .slice(0, 300);
        logToFile(`Chat routing failed: ${safeMessage}`, 'ERROR');
        if (response.destroyed || response.writableEnded) return;
        if (response.headersSent) {
          response.destroy();
          return;
        }
        return sendJson(response, 500, { error: 'chat_routing_failed' });
      }
    }

    if (request.method === 'GET' && url.pathname === '/internal/providers') {
      return sendJson(response, 200, db.providers.map(({ apiKey, ...provider }) => provider));
    }

    if (request.method === 'POST' && url.pathname === '/internal/providers') {
      try {
        const data = await parseJsonBody(request);
        if (!data.id || !data.name || !data.baseUrl || !data.modelId) {
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
          baseUrl: data.baseUrl,
          modelId: data.modelId,
          systemPrompt: data.systemPrompt || '',
          authMode: data.authMode || 'apiKey',
          projectId: data.projectId || '',
          active: !!data.active,
          apiKey: data.apiKey || ''
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
        if (data.modelId !== undefined) provider.modelId = data.modelId;
        if (data.systemPrompt !== undefined) provider.systemPrompt = data.systemPrompt;
        if (data.projectId !== undefined) provider.projectId = data.projectId;
        if (data.apiKey !== undefined) provider.apiKey = data.apiKey;
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

    if (request.method === 'GET' && url.pathname === '/internal/quota') {
      const activeProvider = db.providers.find(p => p.active);
      if (!activeProvider) {
        return sendJson(response, 200, { status: 'no_active_connection' });
      }
      const snapshot = db.quota[activeProvider.id] || null;
      return sendJson(response, 200, { snapshot });
    }

    if (request.method === 'POST' && url.pathname.startsWith('/internal/quota/')) {
      const paths = url.pathname.split('/');
      const connectionId = paths[paths.length - 2];
      const provider = db.providers.find(p => p.id === connectionId);
      if (!provider) {
        return sendJson(response, 404, { error: 'Provider connection not found' });
      }

      return sendJson(response, 501, {
        status: 'unsupported',
        connectionId,
        error: 'Quota is not available for this provider'
      });
    }

    if (request.method === 'POST' && url.pathname === '/internal/reset') {
      const dbReset = {
        providers: [],
        usage: [],
        quota: {}
      };
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
