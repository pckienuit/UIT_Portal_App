const MAX_BUFFER_CHARS = 64 * 1024;

function tokenCount(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

function createSseUsageParser() {
  let buffer = '';
  let usage = { promptTokens: 0, completionTokens: 0, cachedTokens: 0 };

  function parseEvent(event) {
    const data = event
      .split(/\r\n|\r|\n/)
      .filter((line) => line.startsWith('data:'))
      .map((line) => line.slice(5).trimStart())
      .join('\n');
    if (!data || data === '[DONE]') return;
    try {
      const parsed = JSON.parse(data);
      if (!parsed.usage) return;
      usage = {
        promptTokens: tokenCount(parsed.usage.prompt_tokens),
        completionTokens: tokenCount(parsed.usage.completion_tokens),
        cachedTokens: tokenCount(
          parsed.usage.prompt_tokens_details?.cached_tokens,
        ),
      };
    } catch (_) {
      // Ignore non-JSON provider events while preserving upstream bytes downstream.
    }
  }

  return {
    push(chunk) {
      buffer += chunk;
      const events = buffer.split(/(?:\r\n|\r|\n){2}/);
      buffer = events.pop() || '';
      events.forEach(parseEvent);
      if (buffer.length > MAX_BUFFER_CHARS) buffer = buffer.slice(-MAX_BUFFER_CHARS);
    },
    finish() {
      if (buffer) parseEvent(buffer);
      return usage;
    },
  };
}

module.exports = { createSseUsageParser };
