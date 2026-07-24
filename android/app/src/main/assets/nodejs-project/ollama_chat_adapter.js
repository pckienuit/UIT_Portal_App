'use strict';

function openAiToOllamaChat(body, model) {
  const messages = (body.messages || []).map((msg) => ({
    role: msg.role === 'assistant' ? 'assistant' : msg.role === 'system' ? 'system' : 'user',
    content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content),
  }));

  const options = {};
  if (body.temperature !== undefined) options.temperature = body.temperature;
  if (body.top_p !== undefined) options.top_p = body.top_p;

  return {
    model: model || body.model,
    messages,
    stream: body.stream === true,
    options,
  };
}

function ollamaChatResponseToOpenAi(payload, model) {
  const message = payload?.message || {};
  return {
    id: `chatcmpl-${Date.now()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model: payload?.model || model,
    choices: [
      {
        index: 0,
        message: {
          role: message.role || 'assistant',
          content: message.content || '',
        },
        finish_reason: payload?.done ? 'stop' : null,
      },
    ],
    usage: {
      prompt_tokens: payload?.prompt_eval_count || 0,
      completion_tokens: payload?.eval_count || 0,
      total_tokens: (payload?.prompt_eval_count || 0) + (payload?.eval_count || 0),
    },
  };
}

function createOllamaChatStreamTranslator(model) {
  let buffer = '';
  let id = `chatcmpl-${Date.now()}`;
  let sentRole = false;
  let usage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

  return {
    push(chunk) {
      buffer += chunk;
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      const output = [];

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        try {
          const parsed = JSON.parse(trimmed);
          if (parsed.prompt_eval_count || parsed.eval_count) {
            usage = {
              prompt_tokens: parsed.prompt_eval_count || 0,
              completion_tokens: parsed.eval_count || 0,
              total_tokens: (parsed.prompt_eval_count || 0) + (parsed.eval_count || 0),
            };
          }
          const content = parsed.message?.content || '';
          if (content || !sentRole) {
            const delta = {};
            if (!sentRole) {
              delta.role = 'assistant';
              sentRole = true;
            }
            if (content) delta.content = content;
            output.push(`data: ${JSON.stringify({
              id,
              object: 'chat.completion.chunk',
              created: Math.floor(Date.now() / 1000),
              model: parsed.model || model,
              choices: [{ index: 0, delta, finish_reason: parsed.done ? 'stop' : null }],
            })}\n\n`);
          }
        } catch (_) {}
      }
      return output;
    },
    finish() {
      const output = [];
      if (buffer.trim()) {
        try {
          const parsed = JSON.parse(buffer.trim());
          if (parsed.prompt_eval_count || parsed.eval_count) {
            usage = {
              prompt_tokens: parsed.prompt_eval_count || 0,
              completion_tokens: parsed.eval_count || 0,
              total_tokens: (parsed.prompt_eval_count || 0) + (parsed.eval_count || 0),
            };
          }
        } catch (_) {}
      }
      output.push(`data: [DONE]\n\n`);
      return { output, usage };
    },
  };
}

module.exports = {
  openAiToOllamaChat,
  ollamaChatResponseToOpenAi,
  createOllamaChatStreamTranslator,
};
