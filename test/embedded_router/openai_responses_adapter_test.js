'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  openAiToOpenAiResponses,
  openAiResponsesResponseToOpenAi,
  createOpenAiResponsesSseTranslator,
} = require('../../android/app/src/main/assets/nodejs-project/openai_responses_adapter');

test('converts OpenAI Chat request to OpenAI Responses input', () => {
  const req = openAiToOpenAiResponses(
    { messages: [{ role: 'user', content: 'hello codex' }] },
    'gpt-5.4',
  );
  assert.equal(req.model, 'gpt-5.4');
  assert.deepEqual(req.input, [{ role: 'user', content: 'hello codex' }]);
});

test('converts OpenAI Responses payload to OpenAI Chat Completions format', () => {
  const res = openAiResponsesResponseToOpenAi(
    {
      id: 'resp_123',
      model: 'gpt-5.4',
      output: [
        {
          type: 'message',
          content: [{ type: 'text', text: 'Hello from Codex' }],
        },
      ],
      usage: { input_tokens: 15, output_tokens: 25 },
    },
    'gpt-5.4',
  );
  assert.equal(res.choices[0].message.content, 'Hello from Codex');
  assert.equal(res.usage.prompt_tokens, 15);
  assert.equal(res.usage.completion_tokens, 25);
});

test('translates OpenAI Responses SSE stream to OpenAI SSE chunks', () => {
  const translator = createOpenAiResponsesSseTranslator('gpt-5.4');
  const chunks1 = translator.push('data: {"type":"response.created","response":{"id":"resp_999"}}\n\n');
  const chunks2 = translator.push('data: {"type":"response.text.delta","delta":"Hello "}\n\n');
  const chunks3 = translator.push('data: {"type":"response.text.delta","delta":"world"}\n\n');
  const chunks4 = translator.push('data: {"type":"response.completed","response":{"usage":{"input_tokens":10,"output_tokens":20}}}\n\n');
  const terminal = translator.finish();

  assert.equal(chunks2.length, 1);
  assert.match(chunks2[0], /"content":"Hello "/);
  assert.equal(chunks3.length, 1);
  assert.match(chunks3[0], /"content":"world"/);
  assert.equal(terminal.usage.prompt_tokens, 10);
  assert.equal(terminal.usage.completion_tokens, 20);
});
