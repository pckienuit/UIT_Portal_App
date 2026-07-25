'use strict';

const { openAiToOpenAiResponses } = require('./openai_responses_adapter');

const baseBody = {
  messages: [
    { role: 'system', content: 'You are concise.' },
    { role: 'user', content: 'Hello' },
  ],
  stream: true,
};

function assert(cond, msg) {
  if (!cond) {
    console.error('FAIL:', msg);
    process.exit(1);
  }
  console.log('ok  ', msg);
}

// 1. Codex model must carry Codex-required Responses fields.
const codexOut = openAiToOpenAiResponses(
  { ...baseBody, reasoning_effort: 'medium' },
  'gpt-5.3-codex-high',
);
assert(codexOut.model === 'gpt-5.3-codex', 'codex: model suffix stripped');
assert(codexOut.store === false, 'codex: store=false');
assert(codexOut.reasoning && codexOut.reasoning.effort === 'medium',
  'codex: reasoning.effort forwarded');
assert(Array.isArray(codexOut.include) && codexOut.include.includes(
  'reasoning.encrypted_content'), 'codex: include reasoning.encrypted_content');
assert(typeof codexOut.prompt_cache_key === 'string' && codexOut.prompt_cache_key.length > 0,
  'codex: prompt_cache_key set');
assert(typeof codexOut.instructions === 'string' && codexOut.instructions.length > 0,
  'codex: default instructions injected');
assert(codexOut.stream === true, 'codex: stream flag carried');
assert(Array.isArray(codexOut.input) && codexOut.input[0].type === 'message',
  'codex: input items carry type=message');
assert(Array.isArray(codexOut.input[0].content) && codexOut.input[0].content[0].type === 'input_text',
  'codex: input content carries type=input_text');

// 2. Non-codex Responses transport must NOT inject Codex-only fields.
const genericOut = openAiToOpenAiResponses(
  { ...baseBody },
  'o3-mini',
);
assert(genericOut.model === 'o3-mini', 'generic: model preserved');
assert(genericOut.store === false, 'generic: store=false enforced');
assert(!('reasoning' in genericOut), 'generic: no reasoning leak');
assert(!('include' in genericOut), 'generic: no include leak');
assert(!('prompt_cache_key' in genericOut), 'generic: no prompt_cache_key leak');

// 3. Codex with explicit reasoning object should not be clobbered.
const codexWithReasoning = openAiToOpenAiResponses(
  {
    ...baseBody,
    reasoning: { effort: 'high', summary: 'concise' },
  },
  'gpt-5.3-codex',
);
assert(codexWithReasoning.reasoning.effort === 'high',
  'codex: explicit reasoning respected');
assert(codexWithReasoning.reasoning.summary === 'concise',
  'codex: explicit reasoning summary respected');

console.log('\nAll openai_responses_adapter assertions passed.');
