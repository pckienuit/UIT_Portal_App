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

test('translates Codex output_text deltas and completed Responses SSE stream', () => {
  const translator = createOpenAiResponsesSseTranslator('gpt-5.4');
  translator.push('data: {"type":"response.created","response":{"id":"resp_999"}}\n\n');
  const chunks = translator.push('data: {"type":"response.output_text.delta","delta":"Hello Codex"}\n\n');
  translator.push('data: {"type":"response.completed","response":{"usage":{"input_tokens":10,"output_tokens":20}}}\n\n');
  const terminal = translator.finish();

  assert.equal(chunks.length, 1);
  assert.match(chunks[0], /"content":"Hello Codex"/);
  assert.equal(terminal.usage.prompt_tokens, 10);
  assert.equal(terminal.usage.completion_tokens, 20);
  assert.deepEqual(terminal.output, ['data: [DONE]\n\n']);
});

test('translates failed and prematurely ended Responses streams to sanitized terminals', () => {
  const failed = createOpenAiResponsesSseTranslator('gpt-5.4');
  failed.push('data: {"type":"response.failed","response":{"error":{"message":"secret"}}}\n\n');
  assert.deepEqual(failed.finish().output, [
    'data: {"error":"upstream_response_failed"}\n\n',
    'data: [DONE]\n\n',
  ]);

  const incomplete = createOpenAiResponsesSseTranslator('gpt-5.4');
  incomplete.push('data: {"type":"response.output_text.delta","delta":"partial"}\n\n');
  assert.deepEqual(incomplete.finish().output, [
    'data: {"error":"upstream_stream_incomplete"}\n\n',
    'data: [DONE]\n\n',
  ]);
});
