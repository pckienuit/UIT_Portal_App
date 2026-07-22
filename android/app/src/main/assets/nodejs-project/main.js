const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { timingSafeEqual, randomUUID } = require('node:crypto');
const { createStateStore } = require('./state_store');

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

logToFile('Node.js Mobile runtime initialized with args: ' + process.argv.join(', '));

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
        authMode: 'apiKey',
        modelId: provider.modelId,
        enabled: true,
        mobileMetadata: {
          kind: provider.kind || 'openAiCompatible',
          baseUrl: provider.baseUrl,
          systemPrompt: provider.systemPrompt || '',
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
      const activeProvider = db.providers.find(p => p.active);
      if (!activeProvider) {
        return sendJson(response, 200, { data: [] });
      }
      return sendJson(response, 200, {
        data: [
          { id: activeProvider.modelId, object: 'model', owned_by: activeProvider.id }
        ]
      });
    }

    if (request.method === 'POST' && url.pathname === '/v1/chat/completions') {
      try {
        const activeProvider = db.providers.find(p => p.active);
        if (!activeProvider) {
          return sendJson(response, 400, { error: 'No active provider connection configured' });
        }

        const body = await parseJsonBody(request);
        body.model = activeProvider.modelId;

        const headers = {
          'content-type': 'application/json',
        };

        const customKey = request.headers['x-provider-key'];
        if (customKey) {
          headers['authorization'] = `Bearer ${customKey}`;
        } else if (activeProvider.apiKey) {
          headers['authorization'] = `Bearer ${activeProvider.apiKey}`;
        }

        const startTime = Date.now();
        const targetUrl = `${activeProvider.baseUrl}/chat/completions`;

        if (body.stream) {
          const upstreamResponse = await fetch(targetUrl, {
            method: 'POST',
            headers,
            body: JSON.stringify(body)
          });

          response.writeHead(upstreamResponse.status, {
            'content-type': 'text/event-stream',
            'cache-control': 'no-cache',
            'connection': 'keep-alive',
          });

          const reader = upstreamResponse.body.getReader();
          const decoder = new TextDecoder();

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            const chunk = decoder.decode(value, { stream: true });
            response.write(chunk);
          }
          response.end();

          db.usage.push({
            id: randomUUID(),
            timestamp: new Date().toISOString(),
            providerId: activeProvider.id,
            modelId: activeProvider.modelId,
            promptTokens: 0,
            completionTokens: 0,
            cost: 0.0,
            latency: Date.now() - startTime
          });
          saveDb(db);
          return;
        } else {
          const upstreamResponse = await fetch(targetUrl, {
            method: 'POST',
            headers,
            body: JSON.stringify(body)
          });

          const resData = await upstreamResponse.json();
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
        return sendJson(response, 500, { error: e.message });
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
