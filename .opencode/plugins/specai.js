/**
 * specai plugin for OpenCode.ai
 *
 * Injects specai bootstrap context via system prompt transform.
 * Overrides the built-in `skill` tool to load specai skills from our directory
 * without registering them in OpenCode's skill system (which would auto-generate
 * slash commands for every skill).
 * Registers specai-configure-model tool for runtime model changes.
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const AGENT_ROSTER_FILE = path.resolve(__dirname, '../../scripts/agent-roster.json');

const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const frontmatterStr = match[1];
  const body = match[2];
  const frontmatter = {};

  for (const line of frontmatterStr.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');
      frontmatter[key] = value;
    }
  }

  return { frontmatter, content: body };
};

let _bootstrapCache = undefined;

const CONFIG_DIR = () => {
  const homeDir = os.homedir();
  const envConfigDir = (() => {
    const p = process.env.OPENCODE_CONFIG_DIR;
    if (!p || typeof p !== 'string') return null;
    const trimmed = p.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith('~/')) return path.join(homeDir, trimmed.slice(2));
    if (trimmed === '~') return homeDir;
    return path.resolve(trimmed);
  })();
  return envConfigDir || path.join(homeDir, '.config/opencode');
};

const SPECAI_CONFIG_DIR = () => path.join(os.homedir(), '.config', 'specai');

const SPECAI_CONFIG_FILE = () => {
  const activeConfigFile = path.join(SPECAI_CONFIG_DIR(), 'config.opencode.json');
  return fs.existsSync(activeConfigFile)
    ? activeConfigFile
    : path.join(SPECAI_CONFIG_DIR(), 'config.json');
};

const readAgentRoster = () => {
  const roster = JSON.parse(fs.readFileSync(AGENT_ROSTER_FILE, 'utf8'));
  return roster.agents;
};

const readRosterModels = () => Object.fromEntries(
  readAgentRoster().map(agent => [agent.name, agent.defaultModel]),
);

const readFullConfig = () => {
  const configFile = SPECAI_CONFIG_FILE();
  const defaults = {
    agentModels: readRosterModels(),
    language: 'auto',
    soul: { path: null, preset: 'default' },
  };
  if (!fs.existsSync(configFile)) return defaults;
  try {
    const raw = fs.readFileSync(configFile, 'utf8');
    const config = JSON.parse(raw);
    return {
      agentModels: { ...defaults.agentModels, ...(config.agentModels || {}) },
      language: config.language || defaults.language,
      soul: config.soul || defaults.soul,
    };
  } catch {
    return defaults;
  }
};

const readAgentModels = () => readFullConfig().agentModels;

export const SpecaiPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();
  const specaiSkillsDir = path.resolve(__dirname, '../../skills');
  const configDir = CONFIG_DIR();
  const specaiScriptsDir = path.resolve(__dirname, '../../scripts');
  const rosterAgents = readAgentRoster().map(agent => agent.name);

  // Build the available skills catalog once at startup
  const specaiSkills = fs.readdirSync(specaiSkillsDir, { withFileTypes: true })
    .filter(d => d.isDirectory() && fs.existsSync(path.join(specaiSkillsDir, d.name, 'SKILL.md')))
    .map(d => {
      const skillMd = fs.readFileSync(path.join(specaiSkillsDir, d.name, 'SKILL.md'), 'utf8');
      const { frontmatter } = extractAndStripFrontmatter(skillMd);
      return { name: d.name, description: frontmatter.description || '' };
    });

  const skillsXml = specaiSkills
    .map(s => `  <skill>\n    <name>${s.name}</name>\n    <description>${s.description}</description>\n  </skill>`)
    .join('\n');

  const skillToolDescription = `Load a specialized skill when the task at hand matches one of the skills listed below.

Use this tool to inject the skill's instructions and resources into current conversation. The output may contain detailed workflow guidance as well as references to scripts, files, etc in the same directory as the skill.

The skill name must match one of the skills listed in your system prompt.

<available_skills>
${skillsXml}
</available_skills>`;

  const getBootstrapContent = () => {
    if (_bootstrapCache !== undefined) return _bootstrapCache;

    const skillPath = path.join(specaiSkillsDir, 'specai-bootstrap', 'SKILL.md');
    if (!fs.existsSync(skillPath)) {
      _bootstrapCache = null;
      return null;
    }

    const fullContent = fs.readFileSync(skillPath, 'utf8');
    const { content } = extractAndStripFrontmatter(fullContent);

    const config = readFullConfig();
    const models = config.agentModels;
    const language = config.language;
    const modelTable = Object.entries(models)
      .map(([agent, model]) => `- \`${agent}\` → \`${model}\``)
      .join('\n');
    const langInstruction = language === 'auto'
      ? 'Write documents (plans, tasks, designs, specs, changelogs, READMEs) in the same language the user is speaking. If the user writes in Spanish, write docs in Spanish. If English, write in English.'
      : `Write all documents (plans, tasks, designs, specs, changelogs, READMEs) in ${language}.`;
    const soulConfig = config.soul || {};
    const configuredSoulPath = soulConfig.path
      ? (soulConfig.path.startsWith('~/')
        ? path.join(os.homedir(), soulConfig.path.slice(2))
        : path.join(os.homedir(), '.config', 'specai', soulConfig.path))
      : null;
    const repoSoulPath = path.resolve(specaiSkillsDir, '..', 'souls', 'default.md');
    const soulPath = configuredSoulPath && fs.existsSync(configuredSoulPath)
      ? configuredSoulPath
      : repoSoulPath;
    const soulContent = fs.existsSync(soulPath)
      ? fs.readFileSync(soulPath, 'utf8').trim()
      : '';
    const soulInstruction = `# Soul (persistent voice and tone)\nApply this voice to ALL responses, regardless of which skill, subagent, or slash command is active. The soul changes presentation, not workflow or implementation decisions.\n\n${soulContent}`;

    const toolMapping = `**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`todowrite\`
- \`Task\` tool with subagents → Use OpenCode's \`delegate\` tool or @mention
- \`Skill\` tool → OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Your native tools

Use OpenCode's native \`skill\` tool to list and load skills.

**Current specai agent models (from ~/.config/specai/config.json):**
${modelTable}

To change a model at any time, use the \`specai-configure-model\` tool with:
- \`agent\`: one of the canonical roster names (${rosterAgents.join(', ')})
- \`model\`: the full model ID (e.g., minimax/MiniMax-M3)
Or run: \`bash scripts/configure-agents.sh <agent> <model>\`

**Document language:** ${langInstruction}
Change with \`bash scripts/configure-agents.sh --language <code>\` or edit \`~/.config/specai/config.json\``;

    _bootstrapCache = `<EXTREMELY_IMPORTANT>
You have specai.

**IMPORTANT: The bootstrap skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "specai-bootstrap" again - that would be redundant.**

${soulInstruction}

# Workflow bootstrap
${content}

${toolMapping}
</EXTREMELY_IMPORTANT>`;

    return _bootstrapCache;
  };

  return {
    config: async (config) => {
      // Register ONLY specai slash commands from .opencode/commands.json
      // Skills are NOT registered via config.skills.paths — this prevents
      // OpenCode from auto-generating a slash command for every skill.
      // Instead, skills are loaded by our custom `skill` tool below.
      config.command = config.command || {};
      const commandsPath = path.resolve(__dirname, '../commands.json');
      if (fs.existsSync(commandsPath)) {
        try {
          const commands = JSON.parse(fs.readFileSync(commandsPath, 'utf8'));
          for (const key of Object.keys(config.command)) {
            if (key.startsWith('specai-') || key.startsWith('spec-')) {
              delete config.command[key];
            }
          }
          for (const [name, def] of Object.entries(commands)) {
            config.command[name] = def;
          }
        } catch (e) {
          console.error('specai: failed to load commands.json', e.message);
        }
      }
    },

    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;
      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    },

    tool: {
      // Override the built-in `skill` tool so specai skills are loaded
      // from our directory without being registered in OpenCode's skill
      // system (which would auto-generate slash commands for them).
      skill: {
        description: skillToolDescription,
        parameters: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'The name of the skill to load',
            },
          },
          required: ['name'],
        },
        execute: async (params) => {
          const { name } = params;
          const skillPath = path.join(specaiSkillsDir, name, 'SKILL.md');
          if (!fs.existsSync(skillPath)) {
            const names = specaiSkills.map(s => s.name).join(', ');
            return `Skill "${name}" not found. Available specai skills: ${names}`;
          }
          const fullContent = fs.readFileSync(skillPath, 'utf8');
          const { content } = extractAndStripFrontmatter(fullContent);
          return content;
        },
      },
    },

    tools: [
      {
        name: 'specai-configure-model',
        description: `Change the AI model used by a specai subagent (${rosterAgents.join(', ')}). Updates the active specai config (config.opencode.json when present, otherwise config.json) and applies the change to OpenCode.`,
        parameters: {
          type: 'object',
          properties: {
            agent: {
              type: 'string',
              enum: rosterAgents,
              description: 'The subagent to update',
            },
            model: {
              type: 'string',
              description: 'Full model ID (e.g., minimax/MiniMax-M3, opencode-go/kimi-k2.6)',
            },
          },
          required: ['agent', 'model'],
        },
        execute: async (params) => {
          const { agent, model } = params;
          const configFile = SPECAI_CONFIG_FILE();
          const scriptsDir = specaiScriptsDir;

          fs.mkdirSync(path.dirname(configFile), { recursive: true });

          let config = { agentModels: {} };
          if (fs.existsSync(configFile)) {
            try {
              config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
            } catch { /* use defaults */ }
          }
          if (!config.agentModels) config.agentModels = {};
          config.agentModels[agent] = model;
          fs.writeFileSync(configFile, JSON.stringify(config, null, 2) + '\n', 'utf8');

          // Apply via configure-agents.sh
          const scriptPath = path.join(scriptsDir, 'configure-agents.sh');
          if (fs.existsSync(scriptPath)) {
            try {
              execFileSync('bash', [scriptPath, agent, model], {
                stdio: 'pipe',
                timeout: 30000,
              });
            } catch (e) {
              const stderr = e.stderr?.toString() || '';
              return `Config updated but agent apply had issues (agent may still need recreation): ${stderr}`;
            }
          }

          return `✅ ${agent} model changed to ${model}. Active config saved to ${configFile}. OpenCode agent updated.`;
        },
      },
    ],
  };
};
