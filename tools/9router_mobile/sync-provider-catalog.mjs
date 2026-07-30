import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const upstreamArg = process.argv.indexOf('--upstream');
const UPSTREAM_ROOT = upstreamArg >= 0
  ? process.argv[upstreamArg + 1]
  : process.env.NINE_ROUTER_ROOT || 'D:/9router';
const REGISTRY_DIR = path.join(UPSTREAM_ROOT, 'open-sse/providers/registry');
const supportArg = process.argv.indexOf('--support');
const outputArg = process.argv.indexOf('--output');
const SUPPORT_FILE = supportArg >= 0
  ? process.argv[supportArg + 1]
  : './tools/9router_mobile/provider-support.json';
const OUTPUT_FILE = outputArg >= 0
  ? process.argv[outputArg + 1]
  : './android/app/src/main/assets/nodejs-project/provider_catalog.json';
const CHECK_ONLY = process.argv.includes('--check');
const LOCK_FILE = './tools/9router_mobile/upstream-lock.json';
const SUPPORTED_CATEGORIES = new Set(['oauth', 'free', 'freeTier', 'apikey']);
const DISPOSITIONS = new Set(['ready', 'candidate', 'remove', 'customOnly']);
const ANDROID_AUTH = new Set(['device', 'loopback', 'pkce', 'apiKey']);
const TRANSPORT_KINDS = new Set([
  'openaiChat',
  'anthropicMessages',
  'geminiContent',
  'ollamaChat',
  'openaiResponses',
  'customOpenAi',
  'githubCopilot',
  'geminiCli',
]);

function run() {
  if (!fs.existsSync(REGISTRY_DIR)) {
    console.error(`Upstream path not found: ${REGISTRY_DIR}`);
    process.exit(1);
  }

  const lock = JSON.parse(fs.readFileSync(LOCK_FILE, 'utf8'));
  const upstreamCommit = execFileSync(
    'git',
    ['-C', UPSTREAM_ROOT, 'rev-parse', 'HEAD'],
    { encoding: 'utf8' },
  ).trim();
  if (upstreamCommit !== lock.commit) {
    throw new Error(
      `Upstream lock mismatch: expected ${lock.commit}, found ${upstreamCommit}`,
    );
  }
  try {
    execFileSync(
      'git',
      ['-C', UPSTREAM_ROOT, 'diff', '--quiet', 'HEAD', '--', 'open-sse/providers/registry'],
    );
  } catch {
    throw new Error('Locked upstream provider registry has tracked modifications');
  }

  const support = JSON.parse(fs.readFileSync(SUPPORT_FILE, 'utf8'));
  const catalog = [];

  const files = fs.readdirSync(REGISTRY_DIR);
  for (const file of files) {
    if (!file.endsWith('.js') || file === 'index.js') continue;

    const filePath = path.join(REGISTRY_DIR, file);
    const content = fs.readFileSync(filePath, 'utf8');

    // Simple regex parsing
    const idMatch = content.match(/\bid\s*:\s*["']([^"']+)["']/);
    const nameMatch = content.match(/\bname\s*:\s*["']([^"']+)["']/);
    const catMatch = content.match(/\bcategory\s*:\s*["']([^"']+)["']/);
    const displayMatch = content.match(/\bdisplay\s*:\s*\{([^}]+)\}/s);

    if (!idMatch) continue;

    const id = idMatch[1];
    const alias = content.match(/\balias\s*:\s*["']([^"']+)["']/)?.[1] || null;
    const passthroughModels = /\bpassthroughModels\s*:\s*true\b/.test(content);
    const category = catMatch ? catMatch[1] : 'custom';
    if (!SUPPORTED_CATEGORIES.has(category)) continue;
    
    // Check if provider has LLM capability by parsing serviceKinds or display info
    const serviceKindsMatch = content.match(/\bserviceKinds\s*:\s*\[([^\]]+)\]/);
    let isLlm = true;
    if (serviceKindsMatch) {
      const kinds = serviceKindsMatch[1].split(',').map(s => s.replace(/["'\s]/g, ''));
      isLlm = kinds.includes('llm');
    }

    if (!isLlm) continue;

    // Get display details
    let displayName = nameMatch ? nameMatch[1] : id;
    let color = '#64748B';
    let icon = 'api';

    if (displayMatch) {
      const displayBlock = displayMatch[1];
      const displayNameMatch = displayBlock.match(/\bname\s*:\s*["']([^"']+)["']/);
      const displayColorMatch = displayBlock.match(/\bcolor\s*:\s*["']([^"']+)["']/);
      const displayIconMatch = displayBlock.match(/\bicon\s*:\s*["']([^"']+)["']/);

      if (displayNameMatch) displayName = displayNameMatch[1];
      if (displayColorMatch) color = displayColorMatch[1];
      if (displayIconMatch) icon = displayIconMatch[1];
    }

    const providerSupport = support[category]?.[id];
    if (!providerSupport) {
      throw new Error(`Unclassified provider: ${category}/${id}`);
    }
    if (!DISPOSITIONS.has(providerSupport.disposition)) {
      throw new Error(`Invalid disposition for ${category}/${id}`);
    }
    if (providerSupport.disposition === 'candidate' || providerSupport.disposition === 'remove') {
      if (typeof providerSupport.reason !== 'string' || !providerSupport.reason.trim()) {
        throw new Error(`Missing audit reason for ${category}/${id}`);
      }
    }
    if (providerSupport.disposition === 'remove') {
      continue;
    }
    // Candidate entries with complete descriptors remain available to the
    // loopback runtime for existing connections, but Flutter never exposes
    // them in the public Android provider picker.
    if (providerSupport.disposition === 'candidate' &&
        (!providerSupport.androidAuth ||
          !providerSupport.transportKind ||
          !providerSupport.chatUrl)) {
      continue;
    }
    if (!ANDROID_AUTH.has(providerSupport.androidAuth)) {
      throw new Error(`Invalid androidAuth for ${category}/${id}`);
    }
    if (!TRANSPORT_KINDS.has(providerSupport.transportKind)) {
      throw new Error(`Invalid transportKind for ${category}/${id}`);
    }
    if (typeof providerSupport.chatUrl !== 'string' || !providerSupport.chatUrl.trim()) {
      throw new Error(`Missing chatUrl for ${category}/${id}`);
    }
    const chatUrl = new URL(providerSupport.chatUrl);
    const isOllamaLocal = id === 'ollama-local';
    if ((!isOllamaLocal && chatUrl.protocol !== 'https:') ||
        (isOllamaLocal && chatUrl.protocol !== 'http:') ||
        chatUrl.username || chatUrl.password) {
      throw new Error(`Unsafe chatUrl for ${category}/${id}`);
    }
    for (const field of ['modelsUrl', 'defaultBaseUrl']) {
      const value = providerSupport[field];
      if (value == null) continue;
      const url = new URL(value);
      if ((!isOllamaLocal && url.protocol !== 'https:') ||
          (isOllamaLocal && url.protocol !== 'http:') ||
          url.username || url.password) {
        throw new Error(`Unsafe ${field} for ${category}/${id}`);
      }
    }

    // Collect capability flags
    const hasOAuth = content.includes('oauth:') || content.includes('hasOAuth');


    // Parse models list
    const models = [];
    const modelsBlockMatch = content.match(/\bmodels\s*:\s*\[([\s\S]*?)\]\s*(?:,|\n|})/);
    if (modelsBlockMatch) {
      const modelsStr = modelsBlockMatch[1];
      const modelRegex = /\{\s*id\s*:\s*["']([^"']+)["']\s*,\s*name\s*:\s*["']([^"']+)["'][\s\S]*?\}/g;
      let m;
      while ((m = modelRegex.exec(modelsStr)) !== null) {
        const idMatch = m[0].match(/\bid\s*:\s*["']([^"']+)["']/);
        const nameMatch = m[0].match(/\bname\s*:\s*["']([^"']+)["']/);
        const kindMatch = m[0].match(/\bkind\s*:\s*["']([^"']+)["']/);
        if (kindMatch && kindMatch[1] !== 'llm') continue;
        if (idMatch && nameMatch) {
          const upstreamModelId = m[0].match(/\bupstreamModelId\s*:\s*["']([^"']+)["']/)?.[1];
          const quotaFamily = m[0].match(/\bquotaFamily\s*:\s*["']([^"']+)["']/)?.[1];
          models.push({
            id: idMatch[1],
            name: nameMatch[1],
            ...(upstreamModelId ? { upstreamModelId } : {}),
            ...(quotaFamily ? { quotaFamily } : {}),
          });
        }
      }
      if (id === 'gemini-cli') {
        const preferred = ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.5-flash-lite'];
        models.sort((a, b) => {
          const idxA = preferred.indexOf(a.id);
          const idxB = preferred.indexOf(b.id);
          if (idxA !== -1 && idxB !== -1) return idxA - idxB;
          if (idxA !== -1) return -1;
          if (idxB !== -1) return 1;
          return 0;
        });
      }
    }

    catalog.push({
      id,
      alias,
      name: displayName,
      category,
      color,
      icon,
      disposition: providerSupport.disposition,
      mobileSupported: providerSupport.disposition !== 'candidate',
      unsupportedReason: providerSupport.disposition === 'candidate'
        ? providerSupport.reason
        : null,
      hasOAuth,
      quotaSupported: providerSupport.quotaAdapter != null,
      quotaAdapter: providerSupport.quotaAdapter || null,
      androidAuth: providerSupport.androidAuth,
      gatewayFallback: false,
      nativeStatus: providerSupport.nativeStatus || 'ready',
      nativeBlockReason: providerSupport.nativeBlockReason || null,
      tokenRefresh: providerSupport.tokenRefresh || 'none',
      defaultBaseUrl: providerSupport.defaultBaseUrl || null,
      transportKind: providerSupport.transportKind,
      chatUrl: providerSupport.chatUrl,
      modelsUrl: providerSupport.modelsUrl || null,
      authHeader: providerSupport.authHeader || null,
      authScheme: providerSupport.authScheme || null,
      requiredFields: providerSupport.requiredFields || [],
      staticHeaders: providerSupport.staticHeaders || {},
      passthroughModels,
      models,
    });
  }

  // Sort custom/oauth/free/freeTier/apikey and sort alphabetical by ID within categories
  catalog.sort((a, b) => {
    const categories = ['custom', 'oauth', 'free', 'freeTier', 'apikey'];
    const idxA = categories.indexOf(a.category);
    const idxB = categories.indexOf(b.category);
    if (idxA !== idxB) return idxA - idxB;
    return a.id.localeCompare(b.id);
  });

  const serialized = `${JSON.stringify({ providers: catalog }, null, 2)}\n`;
  if (CHECK_ONLY) {
    const current = fs.existsSync(OUTPUT_FILE)
      ? fs.readFileSync(OUTPUT_FILE, 'utf8')
      : '';
    if (current !== serialized) {
      console.error(`Generated catalog is stale: ${OUTPUT_FILE}`);
      process.exit(1);
    }
    console.log(`Catalog is current with ${catalog.length} providers`);
    return;
  }

  fs.mkdirSync(path.dirname(OUTPUT_FILE), { recursive: true });
  fs.writeFileSync(OUTPUT_FILE, serialized, 'utf8');
  console.log(`Generated manifest catalog with ${catalog.length} items at ${OUTPUT_FILE}`);
}

run();
