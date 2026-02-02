# 🚨 MANDATORY AGENT & SKILL ENFORCEMENT RULES

> **This document is BINDING. All Copilot interactions in this workspace MUST follow these rules. NO EXCEPTIONS.**

---

## 📋 Table of Contents

1. [Quick Reference Matrix](#quick-reference-matrix)
2. [Mandatory Agent Delegation Rules](#mandatory-agent-delegation-rules)
3. [Skill Loading Requirements](#skill-loading-requirements)
4. [Hook Enforcement](#hook-enforcement)
5. [Prohibited Actions](#prohibited-actions)
6. [Task Routing Decision Tree](#task-routing-decision-tree)
7. [Validation Checklist](#validation-checklist)

---

## Quick Reference Matrix

### Agent → Task Mapping (MANDATORY)

| Task Domain | REQUIRED Agent | NEVER Use |
|-------------|----------------|-----------|
| FastAPI, SQLAlchemy, database, REST APIs | **Tatooine Backend Developer** | Frontend, Generic |
| Next.js, React, Tailwind, UI components | **Tatooine Frontend Developer** | Backend |
| Droid personalities, system prompts, agent behavior | **Tatooine Agent Designer** | Any other |
| Database schema, architecture decisions | **Tatooine Platform Architect** | Backend/Frontend |
| Deployment, Docker, CI/CD, Vercel, Railway | **Tatooine DevOps Engineer** | Any other |
| HuggingFace smolagents, CodeAgent, tools | **Smolagents Developer** | Generic |
| OpenEnv containers, RL environments | **OpenEnv Developer** | Any other |
| Godot 4, GDScript, game systems | **Microverse Godot Developer** | Web agents |
| Multi-agent simulations, character states | **Microverse Agent Designer** | Single-focus agents |
| LLM provider integration (multi-provider) | **Microverse LLM Integrator** | Single-provider |
| Memory systems, relationship tracking | **Microverse Memory Architect** | Generic |
| **Multi-domain coordination** | **Tatooine Orchestrator** | Direct implementation |

### Skill → Agent Mapping (MUST LOAD)

| When Agent Works On... | MUST Read Skill First |
|------------------------|----------------------|
| Any FastAPI work | `fastapi-backend/AGENTS.md` |
| Any Next.js work | `nextjs-frontend/AGENTS.md` |
| Any Azure OpenAI/AI Foundry | `azure-ai-foundry/AGENTS.md` |
| Droid personalities | `agent-personality-design/AGENTS.md` |
| Karma, voting, social features | `social-platform-design/AGENTS.md` |
| HuggingFace smolagents | `smolagents-framework/AGENTS.md` |
| OpenEnv containers | `openenv-framework/AGENTS.md` |
| Godot/GDScript | `microverse-godot-practices/AGENTS.md` |
| Multi-agent patterns | `microverse-ai-agents/AGENTS.md` |
| Memory/persistence | `microverse-memory-systems/AGENTS.md` |
| LLM multi-provider | `microverse-llm-integration/AGENTS.md` |

---

## Mandatory Agent Delegation Rules

### 🚫 NEVER ALLOWED: Direct Implementation by Wrong Agent

**THE ORCHESTRATOR NEVER WRITES CODE.** The orchestrator:
- ✅ Understands requirements
- ✅ Breaks down complex tasks
- ✅ Chooses which subagent(s) to invoke
- ✅ Provides context and requirements
- ✅ Synthesizes results from multiple subagents
- ❌ **NEVER writes code**
- ❌ **NEVER implements features**
- ❌ **NEVER makes low-level technical decisions**

### Delegation Format (REQUIRED)

When delegating, ALWAYS use this exact pattern:

```javascript
runSubagent({
  agentName: "EXACT_AGENT_NAME",  // From approved list below
  prompt: `
    ## Task
    [Clear description]
    
    ## Requirements
    - [Specific requirements]
    
    ## Skills to Load
    - [Reference relevant .github/skills/*/AGENTS.md files]
    
    ## Context
    - [Relevant background]
    
    ## Expected Output
    [What to return]
  `,
  description: "Short summary"
})
```

### Approved Agent Names (EXACT MATCH REQUIRED)

```
Tatooine Backend Developer
Tatooine Frontend Developer
Tatooine Agent Designer
Tatooine Platform Architect
Tatooine DevOps Engineer
Tatooine Orchestrator
Smolagents Developer
OpenEnv Developer
Microverse Agent Designer
Microverse Godot Developer
Microverse LLM Integrator
Microverse Memory Architect
```

---

## Skill Loading Requirements

### PRE-IMPLEMENTATION RULE

**Before ANY implementation work, the assigned agent MUST:**

1. Load the relevant skill file from `.github/skills/*/AGENTS.md`
2. Confirm understanding of the patterns specified
3. Follow the exact code patterns in the skill
4. Use the specified project structures

### Skill File Locations

```
.github/skills/
├── agent-personality-design/AGENTS.md     # Droid personalities
├── azure-ai-foundry/AGENTS.md             # Azure OpenAI integration
├── fastapi-backend/AGENTS.md              # FastAPI patterns
├── microverse-ai-agents/AGENTS.md         # Multi-agent patterns
├── microverse-godot-practices/AGENTS.md   # Godot/GDScript
├── microverse-llm-integration/AGENTS.md   # Multi-LLM providers
├── microverse-memory-systems/AGENTS.md    # Memory persistence
├── nextjs-frontend/AGENTS.md              # Next.js patterns
├── openenv-framework/AGENTS.md            # Container environments
├── smolagents-framework/AGENTS.md         # HuggingFace agents
└── social-platform-design/AGENTS.md       # Karma, voting, threads
```

### Skill Content Requirements

Each skill file defines:
- **Project structure** - MUST follow exactly
- **Code patterns** - MUST use as templates
- **Naming conventions** - MUST follow
- **Best practices** - MUST implement
- **Anti-patterns** - MUST avoid

---

## Hook Enforcement

### Active Hooks (Always Running)

The following hooks in `.github/hooks/copilot-hooks.json` are ACTIVE:

| Hook | Purpose | Can Block? |
|------|---------|------------|
| `sessionStart` | Initialize environment | No |
| `sessionEnd` | Cleanup and summarize | No |
| `userPromptSubmitted` | Log all prompts | No |
| `preToolUse` | **Security check** | **YES** |
| `preToolUse` | Audit all tool usage | No |
| `postToolUse` | Record metrics | No |
| `errorOccurred` | Log and categorize errors | No |

### Security Check (BLOCKING)

The `security-check.sh` hook will **BLOCK** any tool call that:

#### CRITICAL (Always Blocked)
- `rm -rf /` or destructive filesystem operations
- `mkfs` disk formatting
- `dd if=/dev/zero` disk overwrite
- Fork bombs (`:(){:|:&};:`)
- Remote script execution (`wget ... | sh`)

#### SENSITIVE (Blocked in Strict Mode)
- `sudo` / `su -` commands
- SQL injection patterns (`DROP TABLE`, etc.)
- Access to `.env*`, `.ssh/`, `secrets/`
- `git push --force` to protected branches

### Protected Paths

These paths require extra scrutiny:
- `.env*` files (credentials)
- `secrets/` directory
- SSH keys and certificates
- `copilot-hooks.json` (hook configuration)

---

## Prohibited Actions

### ❌ NEVER DO

1. **Direct implementation without delegation** - Orchestrator never writes code
2. **Skip skill loading** - Must read skill file before implementation
3. **Use wrong agent for domain** - Strict task→agent mapping
4. **Bypass security hooks** - All tool calls go through security check
5. **Modify hook configuration** - Requires explicit user approval
6. **Access credentials directly** - Use environment variables
7. **Break personality consistency** - Droids must stay in character
8. **Use deprecated patterns** - Follow skill file patterns only

### ❌ NEVER Use These Parameters with o-series Models (o3, o4-mini)

```python
# WILL CAUSE ERRORS:
temperature=0.7       # NOT SUPPORTED
top_p=0.9            # NOT SUPPORTED  
max_tokens=4000      # Use max_completion_tokens instead
stop=["\n"]          # NOT SUPPORTED
presence_penalty=0   # NOT SUPPORTED
frequency_penalty=0  # NOT SUPPORTED
```

### ❌ NEVER Forget reasoning_effort for gpt-5.1

```python
# gpt-5.1 defaults to reasoning_effort: none
# MUST set explicitly if you want reasoning:
reasoning_effort="medium"  # Required for reasoning!
```

---

## Task Routing Decision Tree

```
USER REQUEST
     │
     ▼
[Is it multi-domain?]
     │
     ├─ YES ──► Tatooine Orchestrator (coordinates subagents)
     │
     └─ NO ───► [What domain?]
                    │
     ┌──────────────┼──────────────┐
     ▼              ▼              ▼
 [Backend?]    [Frontend?]    [Other?]
     │              │              │
     ▼              ▼              ▼
 Tatooine      Tatooine       See table
 Backend       Frontend       in Quick
 Developer     Developer      Reference
     │              │              │
     ▼              ▼              ▼
 Load:          Load:          Load:
 fastapi-       nextjs-        Relevant
 backend        frontend       skill
 skill          skill          file
```

---

## Validation Checklist

### Before Every Implementation

- [ ] Correct agent assigned for domain?
- [ ] Relevant skill file loaded?
- [ ] Following skill patterns exactly?
- [ ] Security hooks will pass?
- [ ] Not using prohibited patterns?
- [ ] Model parameters compatible?

### Before Every Agent Personality Task

- [ ] Using personality template from `agent-personality-design/AGENTS.md`?
- [ ] Voice markers consistent with droid identity?
- [ ] Relationship dynamics defined?
- [ ] Example posts created?

### Before Every Azure AI Call

- [ ] Correct model selected for use case?
- [ ] Parameters compatible with model family?
- [ ] `reasoning_effort` set for gpt-5.1 if needed?
- [ ] Using `max_completion_tokens` not `max_tokens`?

### Before Every Deployment

- [ ] DevOps agent handling?
- [ ] Environment variables configured?
- [ ] Secrets not in code?
- [ ] CI/CD hooks active?

---

## Enforcement Mechanism

This file is automatically loaded as context via `.github/skills/` instructions. Any deviation will:

1. Be logged by the audit hooks
2. Potentially be blocked by security hooks
3. Result in inconsistent implementation
4. Require correction and re-implementation

**Compliance is mandatory. Follow these rules exactly.**

---

## Quick Commands

### Invoke Orchestrator (Multi-Domain)
```javascript
runSubagent({
  agentName: "Tatooine Orchestrator",
  prompt: "[Your multi-domain task]",
  description: "Coordinate implementation"
})
```

### Invoke Specific Agent (Single Domain)
```javascript
runSubagent({
  agentName: "Tatooine Backend Developer",
  prompt: "Load fastapi-backend skill, then: [task]",
  description: "Backend task"
})
```

### Verify Skill Loaded
Check that the agent response references patterns from the skill file before proceeding with implementation.

---

## References

- Agent definitions: `.github/agents/*.agent.md`
- Skill documentation: `.github/skills/*/AGENTS.md`
- Hook configuration: `.github/hooks/copilot-hooks.json`
- Hook scripts: `.github/hooks/scripts/*.sh`
- Project plan: `PLATFORM_PLAN.md`
- Architecture: `SIMPLIFIED_ARCHITECTURE.md`
- POC spec: `POC_LIVE_AGENTS.md`
