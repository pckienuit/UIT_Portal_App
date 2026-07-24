'use strict';

const { randomUUID } = require('node:crypto');

const SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'OFF' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'OFF' },
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'OFF' },
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'OFF' },
  { category: 'HARM_CATEGORY_CIVIC_INTEGRITY', threshold: 'OFF' },
];

function textParts(content) {
  if (typeof content === 'string') return [{ text: content }];
  if (!Array.isArray(content)) return [];
  return content.flatMap((item) => {
    if (item?.type === 'text' && typeof item.text === 'string') return [{ text: item.text }];
    const url = item?.type === 'image_url' ? item.image_url?.url : null;
    const match = typeof url === 'string' && url.match(/^data:([^;,]+);base64,(.+)$/s);
    return match ? [{ inlineData: { mimeType: match[1], data: match[2] } }] : [];
  });
}

function openAiToGeminiCli(body, model, projectId, isAntigravity = false) {
  if (!projectId) throw new Error('Gemini CLI requires projectId');
  const contents = [];
  const system = [];
  for (const message of body.messages || []) {
    const parts = textParts(message.content);
    if (!parts.length) continue;
    if (message.role === 'system') system.push(...parts);
    else contents.push({ role: message.role === 'assistant' ? 'model' : 'user', parts });
  }
  const generationConfig = {};
  if (body.temperature !== undefined) generationConfig.temperature = body.temperature;
  if (body.top_p !== undefined) generationConfig.topP = body.top_p;
  if (body.max_tokens !== undefined) generationConfig.maxOutputTokens = body.max_tokens;
  
  const request = { contents, generationConfig };
  if (!isAntigravity) {
    request.safetySettings = SAFETY_SETTINGS;
  }
  if (system.length) request.systemInstruction = { role: 'user', parts: system };
  
  const envelope = {
    project: projectId,
    model,
    userAgent: isAntigravity ? 'antigravity' : 'gemini-cli',
    requestId: `agent-${randomUUID()}`,
    request,
  };
  
  if (isAntigravity) {
    envelope.requestType = 'agent';
  }
  
  return envelope;
}

function usageFrom(response) {
  const usage = response?.usageMetadata || {};
  return {
    prompt_tokens: Number(usage.promptTokenCount || 0),
    completion_tokens: Number(usage.candidatesTokenCount || 0),
    total_tokens: Number(usage.totalTokenCount || 0),
  };
}

function finishReason(value) {
  if (!value) return null;
  if (value === 'MAX_TOKENS') return 'length';
  if (value === 'STOP') return 'stop';
  return 'stop';
}

function geminiResponseToOpenAi(payload, model) {
  const response = payload?.response || payload;
  const candidate = response?.candidates?.[0] || {};
  const content = (candidate.content?.parts || [])
    .filter((part) => !part.thought && typeof part.text === 'string')
    .map((part) => part.text)
    .join('');
  return {
    id: `chatcmpl-${response?.responseId || randomUUID()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model: response?.modelVersion || model,
    choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: finishReason(candidate.finishReason) }],
    usage: usageFrom(response),
  };
}

function createGeminiSseTranslator(model) {
  let buffer = '';
  let id = `chatcmpl-${randomUUID()}`;
  let sentRole = false;
  let usage = usageFrom();
  const encode = (data) => `data: ${JSON.stringify(data)}\n\n`;
  function consume(line) {
    if (!line.startsWith('data:')) return [];
    const raw = line.slice(5).trim();
    if (!raw || raw === '[DONE]') return [];
    const payload = JSON.parse(raw);
    const response = payload.response || payload;
    if (response.responseId) id = `chatcmpl-${response.responseId}`;
    usage = usageFrom(response);
    const candidate = response.candidates?.[0] || {};
    const output = [];
    if (!sentRole) {
      sentRole = true;
      output.push(encode({ id, object: 'chat.completion.chunk', created: Math.floor(Date.now() / 1000), model, choices: [{ index: 0, delta: { role: 'assistant' }, finish_reason: null }] }));
    }
    for (const part of candidate.content?.parts || []) {
      if (!part.thought && typeof part.text === 'string' && part.text) {
        output.push(encode({ id, object: 'chat.completion.chunk', created: Math.floor(Date.now() / 1000), model, choices: [{ index: 0, delta: { content: part.text }, finish_reason: null }] }));
      }
    }
    if (candidate.finishReason) {
      output.push(encode({ id, object: 'chat.completion.chunk', created: Math.floor(Date.now() / 1000), model, choices: [{ index: 0, delta: {}, finish_reason: finishReason(candidate.finishReason) }], usage }));
    }
    return output;
  }
  return {
    push(chunk) {
      buffer += chunk;
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop() || '';
      return lines.flatMap(consume);
    },
    finish() {
      const output = buffer ? consume(buffer) : [];
      buffer = '';
      output.push('data: [DONE]\n\n');
      return { output, usage };
    },
  };
}

module.exports = { openAiToGeminiCli, geminiResponseToOpenAi, createGeminiSseTranslator };
