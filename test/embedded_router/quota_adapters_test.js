const test = require('node:test');
const assert = require('node:assert/strict');

const {
  fetchQuota,
  listGeminiModels,
} = require('../../android/app/src/main/assets/nodejs-project/quota_adapters');

function jsonResponse(status, body) {
  return new Response(typeof body === 'string' ? body : JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function parseDartQuotaSchema(payload) {
  assert.ok(['fresh', 'no_active_connection', 'unsupported', 'stale', 'error'].includes(payload.status));
  if (payload.status === 'fresh' || payload.status === 'stale') {
    assert.ok(Array.isArray(payload.entries));
  }
  for (const bucket of payload.entries || []) {
    assert.equal(typeof bucket.id, 'string');
    assert.equal(typeof bucket.label, 'string');
    assert.ok(bucket.remainingPercent == null || Number.isFinite(bucket.remainingPercent));
  }
  return payload;
}

test('Gemini quota reports only upstream percentage and reset without fake totals', async () => {
  let request;
  const result = await fetchQuota({
    connection: {
      id: 'provider-gemini-cli',
      providerId: 'gemini-cli',
      baseUrl: 'https://cloudcode-pa.googleapis.com/v1internal',
      projectId: 'cloud-project',
    },
    secrets: { runtimeToken: 'google-runtime' },
    fetchImpl: async (url, options) => {
      request = { url, options };
      return jsonResponse(200, {
        buckets: [
          {
            modelId: 'gemini-2.5-flash',
            remainingFraction: 0.76,
            resetTime: '2026-07-25T00:00:00Z',
          },
          {
            modelId: 'gemini-2.5-pro',
            remainingFraction: 0.25,
          },
        ],
      });
    },
    now: () => new Date('2026-07-24T12:00:00Z'),
  });

  assert.equal(request.url, 'https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota');
  assert.equal(request.options.headers.authorization, 'Bearer google-runtime');
  assert.deepEqual(JSON.parse(request.options.body), { project: 'cloud-project' });
  assert.deepEqual(parseDartQuotaSchema(result), {
    status: 'fresh',
    connectionId: 'provider-gemini-cli',
    providerId: 'gemini-cli',
    plan: null,
    fetchedAt: '2026-07-24T12:00:00.000Z',
    entries: [
      {
        id: 'gemini-2.5-flash',
        label: 'gemini-2.5-flash',
        used: null,
        total: null,
        remaining: null,
        remainingPercent: 76,
        unit: 'percent',
        resetAt: '2026-07-25T00:00:00.000Z',
        unlimited: false,
      },
      {
        id: 'gemini-2.5-pro',
        label: 'gemini-2.5-pro',
        used: null,
        total: null,
        remaining: null,
        remainingPercent: 25,
        unit: 'percent',
        resetAt: null,
        unlimited: false,
      },
    ],
  });
});

test('GitHub quota uses source OAuth token and keeps unknown numbers null', async () => {
  let authorization;
  const result = await fetchQuota({
    connection: {
      id: 'provider-github',
      providerId: 'github',
      baseUrl: 'https://api.githubcopilot.com',
    },
    secrets: {
      runtimeToken: 'copilot-runtime-must-not-be-used',
      sourceToken: 'github-source',
    },
    fetchImpl: async (url, options) => {
      assert.equal(url, 'https://api.github.com/copilot_internal/user');
      authorization = options.headers.authorization;
      assert.equal(options.headers.accept, 'application/json');
      assert.ok(options.headers['x-github-api-version']);
      return jsonResponse(200, {
        copilot_plan: 'individual',
        quota_snapshots: {
          chat: {
            entitlement: 300,
            remaining: 225,
            percent_remaining: 75,
            reset_date: '2026-08-01T00:00:00Z',
          },
          completions: { unlimited: true },
        },
      });
    },
    now: () => new Date('2026-07-24T12:00:00Z'),
  });

  assert.equal(authorization, 'Bearer github-source');
  assert.equal(result.plan, 'individual');
  parseDartQuotaSchema(result);
  assert.deepEqual(result.entries[0], {
    id: 'chat', label: 'chat', used: 75, total: 300, remaining: 225,
    remainingPercent: 75, unit: 'count',
    resetAt: '2026-08-01T00:00:00.000Z', unlimited: false,
  });
  assert.deepEqual(result.entries[1], {
    id: 'completions', label: 'completions', used: null, total: null,
    remaining: null, remainingPercent: null, unit: null, resetAt: null, unlimited: true,
  });
});

test('Gemini model listing shares quota retrieval and rejects malformed entries', async () => {
  const fetchImpl = async () => jsonResponse(200, {
    buckets: [{ modelId: 'gemini-live' }, { modelId: 'gemini-live' }, {}],
  });
  assert.deepEqual(await listGeminiModels({
    baseUrl: 'https://example.test/v1internal',
    projectId: 'project',
    runtimeToken: 'runtime',
    fetchImpl,
  }), ['gemini-live']);

  await assert.rejects(() => listGeminiModels({
    baseUrl: 'https://example.test/v1internal',
    projectId: 'project',
    runtimeToken: 'runtime',
    fetchImpl: async () => jsonResponse(200, 'not-json'),
  }), /malformed/);
});

test('quota failures are bounded and never include credentials', async () => {
  for (const status of [401, 429, 503]) {
    await assert.rejects(
      () => fetchQuota({
        connection: { id: 'github', providerId: 'github', baseUrl: 'https://example.test' },
        secrets: { sourceToken: 'secret-sentinel' },
        fetchImpl: async () => jsonResponse(status, { error: 'secret-sentinel' }),
      }),
      (error) => {
        assert.equal(error.statusCode, status);
        assert.doesNotMatch(String(error), /secret-sentinel/);
        return true;
      },
    );
  }

  await assert.rejects(() => fetchQuota({
    connection: { id: 'github', providerId: 'github', baseUrl: 'https://example.test' },
    secrets: { sourceToken: 'secret-sentinel' },
    fetchImpl: async () => jsonResponse(200, 'not-json'),
  }), /malformed/);

  await assert.rejects(() => fetchQuota({
    connection: { id: 'github', providerId: 'github', baseUrl: 'https://example.test' },
    secrets: { sourceToken: 'secret-sentinel' },
    timeoutMs: 10,
    fetchImpl: (_url, options) => new Promise((_resolve, reject) => {
      options.signal.addEventListener('abort', () => reject(options.signal.reason));
    }),
  }), /timed out/);
});

test('unsupported quota provider is explicit', async () => {
  await assert.rejects(
    () => fetchQuota({ connection: { id: 'x', providerId: 'openai' }, secrets: {} }),
    (error) => error.statusCode === 501 && error.code === 'unsupported',
  );
});

test('missing credentials and transport timeout map to supported error status', async () => {
  await assert.rejects(
    () => fetchQuota({ connection: { id: 'github', providerId: 'github' }, secrets: {} }),
    (error) => error.statusCode === 401 && error.quotaStatus === 'error',
  );
  await assert.rejects(
    () => fetchQuota({
      connection: { id: 'github', providerId: 'github' },
      secrets: { sourceToken: 'secret-sentinel' },
      timeoutMs: 5,
      fetchImpl: (_url, options) => new Promise((_resolve, reject) => {
        options.signal.addEventListener('abort', () => reject(options.signal.reason));
      }),
    }),
    (error) => error.statusCode === 504 && error.quotaStatus === 'error',
  );
});
