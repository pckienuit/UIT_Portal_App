class QuotaError extends Error {
  constructor(code, statusCode, message, quotaStatus = 'error') {
    super(message);
    this.name = 'QuotaError';
    this.code = code;
    this.statusCode = statusCode;
    this.quotaStatus = quotaStatus;
  }
}

function numberOrNull(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function dateOrNull(value) {
  if (typeof value !== 'string') return null;
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? null : date.toISOString();
}

async function fetchJson(url, options, fetchImpl, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(
    () => controller.abort(new QuotaError('timeout', 504, 'Quota request timed out', 'error')),
    timeoutMs,
  );
  try {
    let response;
    try {
      response = await fetchImpl(url, { ...options, signal: controller.signal });
    } catch (error) {
      if (controller.signal.aborted) throw controller.signal.reason;
      throw new QuotaError('upstream_unavailable', 502, 'Quota upstream unavailable', 'error');
    }
    if (!response.ok) {
      throw new QuotaError('upstream_http', response.status, `Quota upstream HTTP ${response.status}`);
    }
    try {
      return await response.json();
    } catch (_) {
      throw new QuotaError('malformed', 502, 'Quota payload malformed');
    }
  } finally {
    clearTimeout(timer);
  }
}

async function retrieveGeminiQuota({ baseUrl, projectId, runtimeToken, fetchImpl, timeoutMs }) {
  if (!runtimeToken || !projectId) {
    throw new QuotaError('missing_credential', 401, 'Quota credential unavailable', 'error');
  }
  const payload = await fetchJson(`${baseUrl}:retrieveUserQuota`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${runtimeToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ project: projectId }),
  }, fetchImpl, timeoutMs);
  if (!payload || !Array.isArray(payload.buckets)) {
    throw new QuotaError('malformed', 502, 'Quota payload malformed');
  }
  return payload;
}

function antigravityHeaders(runtimeToken, includeClient = false) {
  return {
    authorization: `Bearer ${runtimeToken}`,
    'content-type': 'application/json',
    'user-agent': 'antigravity/ide/2.1.1 darwin/arm64',
    ...(includeClient
      ? { 'x-client-name': 'antigravity', 'x-client-version': '2.1.1' }
      : {}),
  };
}

async function retrieveAntigravityModels({ baseUrl, projectId, runtimeToken, fetchImpl, timeoutMs }) {
  if (!runtimeToken) {
    throw new QuotaError('missing_credential', 401, 'Quota credential unavailable', 'error');
  }
  const codeAssist = await fetchJson(`${baseUrl}:loadCodeAssist`, {
    method: 'POST',
    headers: antigravityHeaders(runtimeToken),
    body: JSON.stringify({
      metadata: { ideType: 9, platform: 2, pluginType: 2 },
      mode: 1,
    }),
  }, fetchImpl, timeoutMs);
  const resolvedProject = typeof codeAssist?.cloudaicompanionProject === 'string'
    ? codeAssist.cloudaicompanionProject
    : projectId;
  const payload = await fetchJson(`${baseUrl}:fetchAvailableModels`, {
    method: 'POST',
    headers: antigravityHeaders(runtimeToken, true),
    body: JSON.stringify(resolvedProject ? { project: resolvedProject } : {}),
  }, fetchImpl, timeoutMs);
  if (!payload || typeof payload.models !== 'object' || Array.isArray(payload.models)) {
    throw new QuotaError('malformed', 502, 'Quota payload malformed');
  }
  return {
    payload,
    plan: typeof codeAssist?.currentTier?.name === 'string' ? codeAssist.currentTier.name : null,
  };
}

const CODEX_MODELS_URL = 'https://chatgpt.com/backend-api/codex/models?client_version=0.144.6';

async function listCodexModels({ runtimeToken, fetchImpl = fetch, timeoutMs = 10000 }) {
  if (!runtimeToken) {
    throw new QuotaError('missing_credential', 401, 'Model credential unavailable', 'error');
  }
  const payload = await fetchJson(CODEX_MODELS_URL, {
    method: 'GET',
    headers: {
      authorization: `Bearer ${runtimeToken}`,
      accept: 'application/json',
      originator: 'codex_cli_rs',
    },
  }, fetchImpl, timeoutMs);
  const rawModels = Array.isArray(payload)
    ? payload
    : (payload?.data || payload?.models || payload?.results || []);
  if (!Array.isArray(rawModels)) {
    throw new QuotaError('malformed', 502, 'Model payload malformed');
  }
  const models = [];
  const ids = new Set();
  for (const raw of rawModels) {
    const id = typeof raw === 'string' ? raw : raw?.id || raw?.slug || raw?.model || raw?.name;
    if (typeof id !== 'string' || !id.trim() || ids.has(id.trim())) continue;
    const normalizedId = id.trim();
    ids.add(normalizedId);
    const name = typeof raw === 'object' && typeof (raw.display_name || raw.displayName || raw.name) === 'string'
      ? (raw.display_name || raw.displayName || raw.name)
      : normalizedId;
    models.push({ id: normalizedId, name });
    if ((raw?.type || 'llm') !== 'image' && !normalizedId.toLowerCase().includes('embed')) {
      models.push({
        id: `${normalizedId}-review`,
        name: `${name} Review`,
        upstreamModelId: normalizedId,
        quotaFamily: 'review',
      });
    }
  }
  if (!models.length) throw new QuotaError('malformed', 502, 'Model payload malformed');
  return models;
}

function codexQuotaWindow(id, label, window) {
  if (!window || typeof window !== 'object') return null;
  const used = numberOrNull(window.used_percent ?? window.percent_used);
  if (used == null) return null;
  const clampedUsed = Math.max(0, Math.min(100, used));
  return {
    id,
    label,
    used: clampedUsed,
    total: 100,
    remaining: 100 - clampedUsed,
    remainingPercent: 100 - clampedUsed,
    unit: 'percent',
    resetAt: dateOrNull(window.reset_at ?? window.resets_at ?? window.resetAt),
    unlimited: false,
  };
}

function codexRateLimit(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return null;
  return payload.rate_limit && typeof payload.rate_limit === 'object'
    ? payload.rate_limit
    : payload;
}

function codexReviewRateLimit(payload) {
  if (payload?.code_review_rate_limit || payload?.review_rate_limit) {
    return payload.code_review_rate_limit || payload.review_rate_limit;
  }
  const byLimitId = payload?.rate_limits_by_limit_id;
  if (byLimitId && typeof byLimitId === 'object' && !Array.isArray(byLimitId)) {
    return byLimitId.code_review || byLimitId.codex_review || byLimitId.review || null;
  }
  const additional = Array.isArray(payload?.additional_rate_limits)
    ? payload.additional_rate_limits
    : [];
  return additional.find((entry) => String(
    entry?.limit_name || entry?.metered_feature || entry?.id || '',
  ).toLowerCase().includes('review')) || null;
}

function normalizeCodex(connection, payload, now) {
  const normal = codexRateLimit(
    payload.rate_limit || payload.rate_limits || payload.rate_limits_by_limit_id?.codex,
  );
  const review = codexRateLimit(codexReviewRateLimit(payload));
  const entries = [
    codexQuotaWindow('session', 'Session', normal?.primary_window || normal?.primary),
    codexQuotaWindow('weekly', 'Weekly', normal?.secondary_window || normal?.secondary),
    codexQuotaWindow('review_session', 'Review session', review?.primary_window || review?.primary),
    codexQuotaWindow('review_weekly', 'Review weekly', review?.secondary_window || review?.secondary),
  ].filter(Boolean);
  if (!entries.length) throw new QuotaError('malformed', 502, 'Quota payload malformed');
  return snapshot(
    connection,
    payload.plan_type || payload.summary?.plan || null,
    entries,
    now,
    'codex.backend-api/wham/usage',
  );
}

async function listGeminiModels({ baseUrl, projectId, runtimeToken, fetchImpl = fetch, timeoutMs = 10000 }) {
  const payload = await retrieveGeminiQuota({
    baseUrl, projectId, runtimeToken, fetchImpl, timeoutMs,
  });
  return [...new Set(payload.buckets
    .map((bucket) => bucket?.modelId)
    .filter((id) => typeof id === 'string' && id.length > 0))];
}

function normalizeGemini(connection, payload, now) {
  const entries = payload.buckets
    .filter((bucket) => bucket && typeof bucket.modelId === 'string' && bucket.modelId)
    .map((bucket) => {
      const fraction = numberOrNull(bucket.remainingFraction);
      return {
        id: bucket.modelId,
        label: bucket.modelId,
        used: null,
        total: null,
        remaining: null,
        remainingPercent: fraction == null
          ? null
          : Math.max(0, Math.min(100, Math.round(fraction * 100))),
        unit: 'percent',
        resetAt: dateOrNull(bucket.resetTime),
        unlimited: false,
      };
    });
  if (entries.length === 0) throw new QuotaError('malformed', 502, 'Quota payload malformed');
  return snapshot(connection, payload.plan ?? null, entries, now, 'gemini-cli.retrieveUserQuota');
}

function antigravityModels(payload, configuredModels) {
  if (!Array.isArray(configuredModels) || configuredModels.length === 0) {
    throw new QuotaError('missing_allowlist', 502, 'Antigravity model allowlist unavailable');
  }
  const models = configuredModels
    .map((descriptor) => {
      const id = typeof descriptor === 'string' ? descriptor : descriptor?.id;
      const catalogName = typeof descriptor === 'object' ? descriptor?.name : null;
      const model = typeof id === 'string' ? payload.models[id] : null;
      if (!model || typeof model !== 'object' || model.isInternal === true || !model.quotaInfo) return null;
      return {
        id,
        name: typeof model.displayName === 'string' && model.displayName
          ? model.displayName
          : catalogName || id,
        quotaInfo: model.quotaInfo,
      };
    })
    .filter(Boolean);
  if (models.length === 0) throw new QuotaError('malformed', 502, 'Quota payload malformed');
  return models;
}

async function listAntigravityModels({ baseUrl, projectId, runtimeToken, configuredModels, fetchImpl = fetch, timeoutMs = 10000 }) {
  const result = await retrieveAntigravityModels({
    baseUrl, projectId, runtimeToken, fetchImpl, timeoutMs,
  });
  return antigravityModels(result.payload, configuredModels).map(({ id, name }) => ({ id, name }));
}

function normalizeAntigravity(connection, result, now) {
  const entries = antigravityModels(result.payload, connection.models).map(({ id, name, quotaInfo }) => {
    const fraction = numberOrNull(quotaInfo.remainingFraction);
    return {
      id,
      label: name,
      used: null,
      total: null,
      remaining: null,
      remainingPercent: fraction == null
        ? null
        : Math.max(0, Math.min(100, Math.round(fraction * 100))),
      unit: 'percent',
      resetAt: dateOrNull(quotaInfo.resetTime),
      unlimited: false,
    };
  });
  return snapshot(connection, result.plan, entries, now, 'antigravity.fetchAvailableModels');
}

function normalizeGithub(connection, payload, now) {
  if (!payload || !payload.quota_snapshots || typeof payload.quota_snapshots !== 'object') {
    throw new QuotaError('malformed', 502, 'Quota payload malformed');
  }
  const buckets = Object.entries(payload.quota_snapshots).map(([id, bucket]) => {
    const total = numberOrNull(bucket?.entitlement);
    const remaining = numberOrNull(bucket?.remaining);
    return {
      id,
      label: id,
      used: total != null && remaining != null ? Math.max(0, total - remaining) : null,
      total,
      remaining,
      remainingPercent: numberOrNull(bucket?.percent_remaining),
      unit: total != null || remaining != null ? 'count' : null,
      resetAt: dateOrNull(bucket?.reset_date),
      unlimited: bucket?.unlimited === true,
    };
  });
  if (buckets.length === 0) throw new QuotaError('malformed', 502, 'Quota payload malformed');
  return snapshot(connection, payload.copilot_plan ?? null, buckets, now, 'github.copilot_internal/user');
}

function normalizeOpenRouter(connection, payload, now) {
  const data = payload?.data;
  if (!data || typeof data !== 'object') {
    throw new QuotaError('malformed', 502, 'Quota payload malformed');
  }
  const usage = numberOrNull(data.usage);
  const limit = numberOrNull(data.limit);
  const remaining = limit != null && usage != null ? Math.max(0, limit - usage) : null;
  const remainingPercent = limit != null && limit > 0 && remaining != null
    ? Math.max(0, Math.min(100, Math.round((remaining / limit) * 100)))
    : null;

  const entries = [
    {
      id: 'credits',
      label: data.label || 'OpenRouter Credits',
      used: usage,
      total: limit,
      remaining,
      remainingPercent,
      unit: 'usd',
      resetAt: null,
      unlimited: limit == null,
    },
  ];

  return snapshot(connection, data.is_free_tier ? 'free_tier' : 'paid', entries, now, 'openrouter.auth/key');
}

function snapshot(connection, plan, entries, now, source) {
  return {
    status: 'fresh',
    connectionId: connection.id,
    providerId: connection.providerId,
    source,
    plan,
    fetchedAt: now().toISOString(),
    entries,
  };
}

async function fetchQuota({
  connection,
  secrets,
  fetchImpl = fetch,
  timeoutMs = 10000,
  now = () => new Date(),
  githubBaseUrl = process.env.GITHUB_QUOTA_BASE_URL || 'https://api.github.com',
}) {
  if (connection.providerId === 'gemini-cli') {
    const payload = await retrieveGeminiQuota({
      baseUrl: connection.baseUrl,
      projectId: connection.projectId,
      runtimeToken: secrets.runtimeToken,
      fetchImpl,
      timeoutMs,
    });
    return normalizeGemini(connection, payload, now);
  }
  if (connection.providerId === 'antigravity') {
    const payload = await retrieveAntigravityModels({
      baseUrl: connection.baseUrl,
      projectId: connection.projectId,
      runtimeToken: secrets.runtimeToken,
      fetchImpl,
      timeoutMs,
    });
    return normalizeAntigravity(connection, payload, now);
  }
  if (connection.providerId === 'github') {
    if (!secrets.sourceToken) {
      throw new QuotaError('missing_credential', 401, 'Quota credential unavailable', 'error');
    }
    const payload = await fetchJson(`${githubBaseUrl}/copilot_internal/user`, {
      headers: {
        authorization: `Bearer ${secrets.sourceToken}`,
        accept: 'application/json',
        'user-agent': 'UIT-Portal-App',
        'x-github-api-version': '2022-11-28',
      },
    }, fetchImpl, timeoutMs);
    return normalizeGithub(connection, payload, now);
  }
  if (connection.providerId === 'openrouter') {
    const token = secrets.runtimeToken || secrets.sourceToken;
    if (!token) {
      throw new QuotaError('missing_credential', 401, 'Quota credential unavailable', 'error');
    }
    const payload = await fetchJson('https://openrouter.ai/api/v1/auth/key', {
      headers: {
        authorization: `Bearer ${token}`,
        accept: 'application/json',
      },
    }, fetchImpl, timeoutMs);
    return normalizeOpenRouter(connection, payload, now);
  }
  if (connection.providerId === 'codex') {
    if (!secrets.runtimeToken) {
      throw new QuotaError('missing_credential', 401, 'Quota credential unavailable', 'error');
    }
    const payload = await fetchJson(`${connection.baseUrl.replace(/\/$/, '')}/wham/usage`, {
      headers: {
        authorization: `Bearer ${secrets.runtimeToken}`,
        accept: 'application/json',
        originator: 'codex_cli_rs',
      },
    }, fetchImpl, timeoutMs);
    return normalizeCodex(connection, payload, now);
  }
  throw new QuotaError('unsupported', 501, 'Quota is not available for this provider');
}

module.exports = { fetchQuota, listAntigravityModels, listCodexModels, listGeminiModels, QuotaError };
