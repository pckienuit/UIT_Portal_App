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
  return snapshot(connection, payload.plan ?? null, entries, now);
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
  return snapshot(connection, payload.copilot_plan ?? null, buckets, now);
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

  return snapshot(connection, data.is_free_tier ? 'free_tier' : 'paid', entries, now);
}

function snapshot(connection, plan, entries, now) {
  return {
    status: 'fresh',
    connectionId: connection.id,
    providerId: connection.providerId,
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
  throw new QuotaError('unsupported', 501, 'Quota is not available for this provider');
}

module.exports = { fetchQuota, listGeminiModels, QuotaError };
