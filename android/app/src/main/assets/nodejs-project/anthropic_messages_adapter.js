function textContent(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content
    .filter((block) => block?.type === 'text' && typeof block.text === 'string')
    .map((block) => block.text)
    .join('');
}

function parseToolArguments(value) {
  if (value && typeof value === 'object') return value;
  if (typeof value !== 'string' || !value) return {};
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function messageContent(message) {
  if (message.role === 'tool') {
    return [{
      type: 'tool_result',
      tool_use_id: message.tool_call_id,
      content: textContent(message.content),
    }];
  }
  if (message.role !== 'assistant' || !Array.isArray(message.tool_calls)) {
    return textContent(message.content);
  }
  const content = [];
  const text = textContent(message.content);
  if (text) content.push({ type: 'text', text });
  for (const call of message.tool_calls) {
    if (call?.type !== 'function' || !call.function?.name) continue;
    content.push({
      type: 'tool_use',
      id: call.id,
      name: call.function.name,
      input: parseToolArguments(call.function.arguments),
    });
  }
  return content;
}

function anthropicToolChoice(choice) {
  if (choice === 'auto') return { type: 'auto' };
  if (choice === 'required') return { type: 'any' };
  if (choice && typeof choice === 'object' && choice.type === 'function' && choice.function?.name) {
    return { type: 'tool', name: choice.function.name };
  }
  return null;
}

function openAiToAnthropic(body, model) {
  const system = [];
  const messages = [];
  for (const message of Array.isArray(body.messages) ? body.messages : []) {
    const content = textContent(message?.content);
    if (message?.role === 'system') {
      if (content) system.push(content);
    } else if (message?.role === 'user' || message?.role === 'assistant' || message?.role === 'tool') {
      messages.push({
        role: message.role === 'tool' ? 'user' : message.role,
        content: messageContent(message),
      });
    }
  }
  const completionLimit = Number.isInteger(body.max_completion_tokens)
    ? body.max_completion_tokens
    : body.max_tokens;
  const result = {
    model,
    ...(system.length ? { system: system.join('\n\n') } : {}),
    messages,
    max_tokens: Number.isInteger(completionLimit) ? completionLimit : 1024,
  };
  for (const key of ['temperature', 'top_p', 'top_k', 'metadata']) {
    if (body[key] !== undefined) result[key] = body[key];
  }
  if (typeof body.stop === 'string') result.stop_sequences = [body.stop];
  else if (Array.isArray(body.stop)) result.stop_sequences = body.stop;
  else if (Array.isArray(body.stop_sequences)) result.stop_sequences = body.stop_sequences;
  if (Array.isArray(body.tools) && body.tools.length) {
    result.tools = body.tools
      .filter((tool) => tool?.type === 'function' && tool.function?.name)
      .map((tool) => ({
        name: tool.function.name,
        ...(tool.function.description !== undefined
          ? { description: tool.function.description }
          : {}),
        input_schema: tool.function.parameters || { type: 'object', properties: {} },
      }));
  }
  const toolChoice = anthropicToolChoice(body.tool_choice);
  if (toolChoice) result.tool_choice = toolChoice;
  result.stream = body.stream === true;
  return result;
}

function finishReason(reason) {
  return reason === 'end_turn' || reason === 'stop_sequence' ? 'stop'
    : reason === 'max_tokens' ? 'length'
      : reason === 'tool_use' ? 'tool_calls'
        : reason || null;
}

function openAiToolCalls(content) {
  return (Array.isArray(content) ? content : [])
    .filter((block) => block?.type === 'tool_use' && block.name)
    .map((block) => ({
      id: block.id,
      type: 'function',
      function: { name: block.name, arguments: JSON.stringify(block.input || {}) },
    }));
}

function anthropicResponseToOpenAi(payload) {
  const promptTokens = payload?.usage?.input_tokens || 0;
  const completionTokens = payload?.usage?.output_tokens || 0;
  const toolCalls = openAiToolCalls(payload?.content);
  return {
    id: payload.id,
    object: 'chat.completion',
    model: payload.model,
    choices: [{
      index: 0,
      message: {
        role: 'assistant',
        content: textContent(payload.content),
        ...(toolCalls.length ? { tool_calls: toolCalls } : {}),
      },
      finish_reason: finishReason(payload.stop_reason),
    }],
    usage: {
      prompt_tokens: promptTokens,
      completion_tokens: completionTokens,
      total_tokens: promptTokens + completionTokens,
    },
  };
}

function createAnthropicSseTranslator(model) {
  let buffer = '';
  let id = 'anthropic-message';
  let promptTokens = 0;
  let completionTokens = 0;
  let emittedRole = false;

  function chunk(delta, finish = null) {
    return `data: ${JSON.stringify({
      id,
      object: 'chat.completion.chunk',
      model,
      choices: [{ index: 0, delta, finish_reason: finish }],
    })}\n\n`;
  }

  function roleChunk(output) {
    if (!emittedRole) {
      emittedRole = true;
      output.push(chunk({ role: 'assistant' }));
    }
  }

  function consume(event) {
    if (!event || typeof event.type !== 'string') return [];
    if (event.type === 'message_start') {
      id = event.message?.id || id;
      promptTokens = event.message?.usage?.input_tokens || 0;
      completionTokens = event.message?.usage?.output_tokens || 0;
      emittedRole = true;
      return [chunk({ role: 'assistant' })];
    }
    if (event.type === 'content_block_start' && event.content_block?.type === 'tool_use') {
      const output = [];
      roleChunk(output);
      output.push(chunk({ tool_calls: [{
        index: event.index,
        id: event.content_block.id,
        type: 'function',
        function: { name: event.content_block.name, arguments: '' },
      }] }));
      return output;
    }
    if (event.type === 'content_block_delta' && event.delta?.type === 'text_delta') {
      const output = [];
      roleChunk(output);
      output.push(chunk({ content: event.delta.text || '' }));
      return output;
    }
    if (event.type === 'content_block_delta' && event.delta?.type === 'input_json_delta') {
      const output = [];
      roleChunk(output);
      output.push(chunk({ tool_calls: [{
        index: event.index,
        function: { arguments: event.delta.partial_json || '' },
      }] }));
      return output;
    }
    if (event.type === 'message_delta') {
      completionTokens = event.usage?.output_tokens ?? completionTokens;
      return event.delta?.stop_reason
        ? [chunk({}, finishReason(event.delta.stop_reason))]
        : [];
    }
    return [];
  }

  return {
    push(input) {
      buffer += input;
      const output = [];
      let match;
      while ((match = /\r?\n\r?\n/.exec(buffer))) {
        const frame = buffer.slice(0, match.index).replace(/\r/g, '');
        buffer = buffer.slice(match.index + match[0].length);
        const data = frame.split('\n')
          .filter((line) => line.startsWith('data:'))
          .map((line) => line.slice(5).trimStart())
          .join('\n');
        if (!data || data === '[DONE]') continue;
        try { output.push(...consume(JSON.parse(data))); } catch (_) {}
      }
      return output;
    },
    finish() {
      return {
        output: ['data: [DONE]\n\n'],
        usage: {
          prompt_tokens: promptTokens,
          completion_tokens: completionTokens,
          total_tokens: promptTokens + completionTokens,
        },
      };
    },
  };
}

module.exports = {
  openAiToAnthropic,
  anthropicResponseToOpenAi,
  createAnthropicSseTranslator,
};
