const test = require('node:test');
const assert = require('node:assert/strict');
const { createSseUsageParser } = require('../../android/app/src/main/assets/nodejs-project/sse_usage');

test('parses terminal usage split across arbitrary network chunks', () => {
  const parser = createSseUsageParser();
  parser.push('data: {"choices":[{"delta":{"content":"hi"}}]}\n\nda');
  parser.push('ta: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":4,"prompt_tokens_details":{"cached_tokens":3}}}\n\n');
  parser.push('data: [DONE]\n\n');
  assert.deepEqual(parser.finish(), {
    promptTokens: 12,
    completionTokens: 4,
    cachedTokens: 3,
  });
});

test('returns zero usage when upstream omits terminal usage event', () => {
  const parser = createSseUsageParser();
  parser.push('data: {"choices":[{"delta":{"content":"hi"}}]}\n\n');
  assert.deepEqual(parser.finish(), {
    promptTokens: 0,
    completionTokens: 0,
    cachedTokens: 0,
  });
});

test('supports CR separators and rejects invalid token counts', () => {
  const parser = createSseUsageParser();
  parser.push('data: {"usage":{"prompt_tokens":9,"completion_tokens":-2}}\r\r');
  assert.deepEqual(parser.finish(), {
    promptTokens: 9,
    completionTokens: 0,
    cachedTokens: 0,
  });
});
