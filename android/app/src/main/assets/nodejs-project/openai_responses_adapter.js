'use strict';

function openAiToOpenAiResponses(body, model) {
  const input = (body.messages || []).map((msg) => ({
    role: msg.role === 'assistant' ? 'assistant' : msg.role === 'system' ? 'system' : 'user',
    content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content),
  }));

  return {
    model: model || body.model,
    input,
    stream: body.stream === true,
  };
}

function openAiResponsesResponseToOpenAi(payload, model) {
  const response = payload?.response || payload || {};
  const output = response?.output || [];
  let content = '';
  for (const item of output) {
    if (item?.type === 'message' && item?.content) {
      for (const part of item.content) {
        if (part?.type === 'text' && part?.text) {
          content += part.text;
        }
      }
    }
  }

  const usage = response?.usage || {};
  return {
    id: `chatcmpl-${response?.id || Date.now()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model: response?.model || model,
    choices: [
      {
        index: 0,
        message: {
          role: 'assistant',
          content,
        },
        finish_reason: 'stop',
      },
    ],
    usage: {
      prompt_tokens: usage.input_tokens || usage.prompt_tokens || 0,
      completion_tokens: usage.output_tokens || usage.completion_tokens || 0,
      total_tokens: (usage.input_tokens || usage.prompt_tokens || 0) + (usage.output_tokens || usage.completion_tokens || 0),
    },
  };
}

function createOpenAiResponsesSseTranslator(model) {
  let buffer = '';
  let id = `chatcmpl-${Date.now()}`;
  let sentRole = false;
  let completed = false;
  let failed = false;
  let usage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

  return {
    push(chunk) {
      buffer += chunk;
      const frames = buffer.split('\n\n');
      buffer = frames.pop() || '';
      const output = [];

      for (const frame of frames) {
        const lines = frame.split('\n');
        let dataStr = '';
        for (const line of lines) {
          if (line.startsWith('data: ')) {
            dataStr += line.slice(6);
          }
        }
        if (!dataStr || dataStr === '[DONE]') continue;
        try {
          const parsed = JSON.parse(dataStr);
          if (parsed.type === 'response.created' && parsed.response?.id) {
            id = `chatcmpl-${parsed.response.id}`;
          }
          if (parsed.type === 'response.completed' && parsed.response?.usage) {
            completed = true;
            const u = parsed.response.usage;
            usage = {
              prompt_tokens: u.input_tokens || 0,
              completion_tokens: u.output_tokens || 0,
              total_tokens: (u.input_tokens || 0) + (u.output_tokens || 0),
            };
          }
          if (parsed.type === 'response.completed') completed = true;
          if (parsed.type === 'response.failed') failed = true;
          if (parsed.type === 'response.output_item.added' || parsed.type === 'response.content_part.added') {
            if (!sentRole) {
              output.push(`data: ${JSON.stringify({
                id,
                object: 'chat.completion.chunk',
                created: Math.floor(Date.now() / 1000),
                model,
                choices: [{ index: 0, delta: { role: 'assistant' }, finish_reason: null }],
              })}\n\n`);
              sentRole = true;
            }
          }
          if ((parsed.type === 'response.text.delta' || parsed.type === 'response.output_text.delta') && parsed.delta) {
            if (!sentRole) {
              sentRole = true;
            }
            output.push(`data: ${JSON.stringify({
              id,
              object: 'chat.completion.chunk',
              created: Math.floor(Date.now() / 1000),
              model,
              choices: [{ index: 0, delta: { content: parsed.delta }, finish_reason: null }],
            })}\n\n`);
          }
        } catch (_) {}
      }
      return output;
    },
    finish() {
      const output = [];
      if (failed) output.push('data: {"error":"upstream_response_failed"}\n\n');
      else if (!completed) output.push('data: {"error":"upstream_stream_incomplete"}\n\n');
      output.push('data: [DONE]\n\n');
      return { output, usage };
    },
  };
}

module.exports = {
  openAiToOpenAiResponses,
  openAiResponsesResponseToOpenAi,
  createOpenAiResponsesSseTranslator,
};
