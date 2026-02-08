/**
 * domain-configs.ts
 *
 * Story 3.2: Domain Configuration Engine
 * Reads domain config JSON files from _shared/domain-configs/ at module init,
 * caches in a module-level Map for O(1) access on subsequent requests.
 *
 * Single source of truth: JSON files in _shared/domain-configs/.
 * DO NOT hardcode domain config data as TypeScript objects.
 */

// MARK: - Types

/** Full domain configuration matching the JSON schema */
export interface DomainConfig {
  id: string;
  name: string;
  description: string;
  systemPromptAddition: string;
  tone: string;
  methodology: string;
  personality: string;
  domainKeywords: string[];
  focusAreas: string[];
  enabled: boolean;
  guardrails?: string;
}

// MARK: - Hardcoded general fallback (used only if general.json is missing)

const GENERAL_FALLBACK: DomainConfig = {
  id: 'general',
  name: 'General Coaching',
  description: 'Broad personal coaching covering any topic',
  systemPromptAddition: '',
  tone: 'warm, supportive, curious',
  methodology: 'active listening, open-ended questions, reflective coaching',
  personality: 'empathetic coach who adapts to whatever the user needs',
  domainKeywords: [],
  focusAreas: [],
  enabled: true,
};

// MARK: - Module-level cache

const configCache = new Map<string, DomainConfig>();

// MARK: - Loading

/**
 * Load all domain config JSON files from _shared/domain-configs/.
 * Parses, validates, and caches in the module-level Map.
 * Called once at module import via top-level await.
 */
export async function loadDomainConfigs(): Promise<void> {
  configCache.clear();

  const configDir = new URL('./domain-configs/', import.meta.url).pathname;

  try {
    for await (const entry of Deno.readDir(configDir)) {
      if (!entry.isFile || !entry.name.endsWith('.json')) continue;

      try {
        const filePath = `${configDir}${entry.name}`;
        const text = await Deno.readTextFile(filePath);
        const config: DomainConfig = JSON.parse(text);

        if (!config.id || typeof config.id !== 'string') {
          console.warn(`Invalid domain config in ${entry.name}: missing or invalid id`);
          continue;
        }

        configCache.set(config.id, config);
      } catch (err) {
        console.warn(`Failed to load domain config ${entry.name}:`, err);
      }
    }
  } catch (err) {
    console.error('Failed to read domain-configs directory:', err);
  }

  // Ensure general fallback always exists
  if (!configCache.has('general')) {
    console.warn('No general.json found, using built-in fallback');
    configCache.set('general', GENERAL_FALLBACK);
  }
}

// MARK: - Public API

/**
 * Get the domain config for a given domain ID.
 * Returns general fallback if domain is unknown, disabled, or missing.
 */
export function getDomainConfig(domain: string): DomainConfig {
  const config = configCache.get(domain);
  if (config && config.enabled) {
    return config;
  }
  return configCache.get('general') ?? GENERAL_FALLBACK;
}

/**
 * Get domain keywords for a given domain ID.
 * Used by domain-router.ts for shift detection.
 * Returns empty array for unknown domains.
 */
export function getDomainKeywords(domain: string): string[] {
  const config = configCache.get(domain);
  if (config && config.enabled) {
    return config.domainKeywords;
  }
  return configCache.get('general')?.domainKeywords ?? [];
}

/**
 * Get all loaded domain configs.
 * Useful for testing and validation.
 */
export function getAllDomainConfigs(): Map<string, DomainConfig> {
  return new Map(configCache);
}

// MARK: - Auto-load at module import

await loadDomainConfigs();
