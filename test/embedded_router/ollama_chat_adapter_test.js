'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  openAiToOllamaChat,
  ollamaChatResponseToOpenAi,
  createOllamaChatStreamTranslator,
} = require('../../android/app/src/main/assets/nodejs-project/ollama_chat_adapter');

test('converts OpenAI request to Ollama Chat request', () => {
  const req = openAiToOllamaChat(
    {
      messages: [{ role: 'user', content: 'hello' }],
      temperature: 0.7,
    },
    'llama3',
  );
  assert.equal(req.model, 'llama3');
  assert.deepEqual(req.messages, [{ role: 'user', content: 'hello' }]);
  assert.equal(req.options.temperature, 0.7);
});

test('converts Ollama Chat response to OpenAI format', () => {
  const res = ollamaChatResponseToOpenAi(
    {
      model: 'llama3',
      message: { role: 'assistant', content: 'hi there' },
      done: true,
      prompt_eval_count: 5,
      eval_count: 10,
    },
    'llama3',
  );
  assert.equal(res.choices[0].message.content, 'hi there');
  assert.equal(res.usage.prompt_tokens, 5);
  assert.equal(res.usage.completion_tokens, 10);
});

test('translates Ollama Chat JSON lines stream to OpenAI SSE chunks', () => {
  const translator = createOllamaChatStreamTranslator('llama3');
  const chunks1 = translator.push('{"model":"llama3","message":{"role":"assistant","content":"hello"},"done":false}\n');
  const chunks2 = translator.push('{"model":"llama3","message":{"content":" world"},"done":true,"prompt_eval_count":5,"eval_count":8}\n');
  const terminal = translator.finish();

  assert.equal(chunks1.length, 1);
  assert.match(chunks1[0], /"content":"hello"/);
  assert.equal(chunks2.length, 1);
  assert.match(chunks2[0], /"content":" world"/);
  assert.equal(terminal.usage.prompt_tokens, 5);
  assert.equal(terminal.usage.completion_tokens, 8);
});
