import fs from 'node:fs';
import path from 'node:path';

const UPSTREAM_ROOT = 'C:/Users/Chi Kien/AppData/Local/Temp/9router-reference-20260721-001540';
const REGISTRY_DIR = path.join(UPSTREAM_ROOT, 'open-sse/providers/registry');
const SUPPORT_FILE = './tools/9router_mobile/provider-support.json';
const OUTPUT_FILE = './android/app/src/main/assets/nodejs-project/provider_catalog.json';

function run() {
  if (!fs.existsSync(REGISTRY_DIR)) {
    console.error(`Upstream path not found: ${REGISTRY_DIR}`);
    process.exit(1);
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
    const category = catMatch ? catMatch[1] : 'custom';
    
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

    // Resolve support status
    let mobileSupported = false;
    let unsupportedReason = 'Not yet classified or media-only';

    if (support[category] && support[category][id]) {
      const sup = support[category][id];
      mobileSupported = sup.mobileSupported === true;
      unsupportedReason = sup.mobileSupported ? null : (sup.unsupportedReason || 'Desktop-only flow');
    } else {
      // Default fallback for custom or unclassified key/free providers
      if (category === 'apikey' || category === 'freeTier') {
        mobileSupported = true; // Key-based generally supported unless marked false
        unsupportedReason = null;
      }
    }

    // Collect capability flags
    const hasOAuth = content.includes('oauth:') || content.includes('hasOAuth');
    const hasUsage = content.includes('usage: true') || content.includes('features:');

    // Parse models list
    const models = [];
    const modelsBlockMatch = content.match(/\bmodels\s*:\s*\[([\s\S]*?)\]\s*(?:,|\n|})/);
    if (modelsBlockMatch) {
      const modelsStr = modelsBlockMatch[1];
      const modelRegex = /\{\s*id\s*:\s*["']([^"']+)["']\s*,\s*name\s*:\s*["']([^"']+)["']/g;
      let m;
      while ((m = modelRegex.exec(modelsStr)) !== null) {
        models.push({ id: m[1], name: m[2] });
      }
    }

    catalog.push({
      id,
      name: displayName,
      category,
      color,
      icon,
      mobileSupported,
      unsupportedReason,
      hasOAuth,
      quotaSupported: hasUsage,
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

  fs.mkdirSync(path.dirname(OUTPUT_FILE), { recursive: true });
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify({ providers: catalog }, null, 2), 'utf8');
  console.log(`Generated manifest catalog with ${catalog.length} items at ${OUTPUT_FILE}`);
}

run();
