'use strict';

const CODEX_DEFAULT_INSTRUCTIONS =
  'You are an expert software engineer. Follow the user instructions carefully.';

const RESPONSES_API_ALLOWLIST = new Set([
  'model',
  'input',
  'instructions',
  'tools',
  'tool_choice',
  'stream',
  'store',
  'reasoning',
  'service_tier',
  'include',
  'prompt_cache_key',
  'client_metadata',
  'text',
]);

function openAiToOpenAiResponses(body, model) {
  let resolvedModel = model || body.model;
  const isCodex = resolvedModel && /codex/i.test(resolvedModel);

  let effortFromModel = null;
  if (isCodex) {
    const effortLevels = ['none', 'minimal', 'low', 'medium', 'high', 'xhigh'];
    for (const level of effortLevels) {
      if (resolvedModel.endsWith(`-${level}`)) {
        effortFromModel = level;
        resolvedModel = resolvedModel.replace(`-${level}`, '');
        break;
      }
    }
  }

  const input = [];
  let instructions = typeof body.instructions === 'string' ? body.instructions : '';
  let hasSystemMessage = instructions.trim().length > 0;

  for (const msg of body.messages || []) {
    const role = msg.role;
    let contentText = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);

    if (role === 'system') {
      if (!hasSystemMessage) {
        instructions = contentText;
        hasSystemMessage = true;
      } else {
        input.push({
          type: 'message',
          role: 'developer',
          content: [{ type: 'input_text', text: contentText }],
        });
      }
      continue;
    }

    if (role === 'user' || role === 'assistant') {
      const contentType = role === 'user' ? 'input_text' : 'output_text';
      input.push({
        type: 'message',
        role: role === 'assistant' ? 'assistant' : 'user',
        content: [{ type: contentType, text: contentText }],
      });
    }
  }

  if (input.length === 0) {
    input.push({
      type: 'message',
      role: 'user',
      content: [{ type: 'input_text', text: '...' }],
    });
  }

  const out = {
    model: resolvedModel,
    input,
    stream: body.stream === true,
    store: false,
  };

  if (instructions.trim()) {
    out.instructions = instructions;
  }

  if (isCodex) {
    out.store = false;
    if (!out.instructions || !out.instructions.trim()) {
      out.instructions = CODEX_DEFAULT_INSTRUCTIONS;
    }
    if (!body.reasoning) {
      let effort = typeof body.reasoning_effort === 'string' && body.reasoning_effort
        ? body.reasoning_effort
        : (effortFromModel || 'low');
      if (effort === 'max') effort = 'xhigh';
      out.reasoning = { effort, summary: 'auto' };
      out.include = ['reasoning.encrypted_content'];
    } else {
      out.reasoning = body.reasoning;
      if (out.reasoning.effort === 'max') out.reasoning.effort = 'xhigh';
      if (out.reasoning.effort && out.reasoning.effort !== 'none') {
        out.include = body.include || ['reasoning.encrypted_content'];
      }
    }
    delete body.reasoning_effort;
    out.prompt_cache_key = body.prompt_cache_key || `codex-${resolvedModel}`;

    // Clean disallowed keys
    for (const key of Object.keys(out)) {
      if (!RESPONSES_API_ALLOWLIST.has(key)) delete out[key];
    }
  }

  return out;
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
