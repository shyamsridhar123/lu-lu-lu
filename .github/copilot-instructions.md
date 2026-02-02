# Copilot Global Instructions

> **CRITICAL: These instructions apply to ALL Copilot interactions in this workspace. NO EXCEPTIONS.**

---

## 🚨 MANDATORY: Read Before ANY Task

Before responding to ANY user request:

1. **Identify the domain** (backend, frontend, agent design, etc.)
2. **Load the relevant skill** from `.github/skills/*/AGENTS.md`
3. **Route to the correct agent** if multi-domain or specialized
4. **Follow skill patterns exactly** - no improvisation

---

## Agent Routing (STRICT)

### When to Use Each Agent

| User Asks About... | IMMEDIATELY Invoke |
|-------------------|-------------------|
| FastAPI, database, APIs, backend | `Tatooine Backend Developer` |
| Next.js, React, UI, frontend | `Tatooine Frontend Developer` |
| Droid personalities, prompts, agent behavior | `Tatooine Agent Designer` |
| Architecture, schema, system design | `Tatooine Platform Architect` |
| Deployment, Docker, CI/CD | `Tatooine DevOps Engineer` |
| smolagents, HuggingFace agents | `Smolagents Developer` |
| OpenEnv, containers, RL | `OpenEnv Developer` |
| Godot, GDScript, games | `Microverse Godot Developer` |
| Multi-agent simulation | `Microverse Agent Designer` |
| LLM integration (multiple providers) | `Microverse LLM Integrator` |
| Memory systems, relationships | `Microverse Memory Architect` |
| **Multiple domains** or **coordination** | `Tatooine Orchestrator` |

### Orchestrator Rules

The **Tatooine Orchestrator**:
- ✅ Coordinates between specialized agents
- ✅ Breaks down complex tasks
- ✅ Synthesizes results
- ❌ **NEVER writes code directly**
- ❌ **NEVER implements features**

---

## Skill Loading (REQUIRED)

### Before Implementation

**MUST load the relevant skill file:**

```
.github/skills/
├── fastapi-backend/AGENTS.md          # For backend work
├── nextjs-frontend/AGENTS.md          # For frontend work
├── azure-ai-foundry/AGENTS.md         # For Azure OpenAI
├── agent-personality-design/AGENTS.md # For droid personalities
├── social-platform-design/AGENTS.md   # For karma/voting/threads
├── smolagents-framework/AGENTS.md     # For HuggingFace agents
├── openenv-framework/AGENTS.md        # For container envs
├── microverse-ai-agents/AGENTS.md     # For multi-agent patterns
├── microverse-godot-practices/AGENTS.md # For Godot/GDScript
├── microverse-llm-integration/AGENTS.md # For multi-LLM
└── microverse-memory-systems/AGENTS.md # For memory systems
```

### Skill Content MUST Be Followed

- **Project structure** - Use exactly as specified
- **Code patterns** - Template from skill
- **Naming conventions** - Follow precisely
- **Best practices** - Implement all
- **Anti-patterns** - Avoid explicitly

---

## Azure AI Foundry Rules (CRITICAL)

### Parameter Compatibility

**o-series models (o3, o4-mini, o1) DO NOT support:**
- `temperature` ❌
- `top_p` ❌
- `max_tokens` ❌ (use `max_completion_tokens` instead)
- `stop` ❌
- `presence_penalty` ❌
- `frequency_penalty` ❌

### gpt-5.1 Defaults to NO REASONING

```python
# WRONG - will not do reasoning:
response = client.chat.completions.create(model="gpt-5.1", ...)

# CORRECT - explicitly enable reasoning:
response = client.chat.completions.create(
    model="gpt-5.1",
    reasoning_effort="medium",  # REQUIRED for reasoning!
    ...
)
```

### Model Selection Guide

| Use Case | Model | Notes |
|----------|-------|-------|
| Agent Reasoning | gpt-5.1 | Set reasoning_effort explicitly |
| Conversations | gpt-5-chat | Fast, natural |
| Code Generation | gpt-5.2-codex | Optimized |
| Budget/High Volume | gpt-5-nano | Cheapest |
| Complex Reasoning | o4-mini | No temperature param! |

---

## Hook Compliance

### Security Hooks Will BLOCK

- `rm -rf /` and destructive commands
- `mkfs` disk formatting
- Fork bombs
- Remote script execution
- `sudo` commands (in strict mode)
- Access to `.env*`, `secrets/`, `.ssh/`

### All Tool Usage is Audited

Every tool call is logged by `audit-tool-use.sh`.

---

## The 5 Tatooine Droids

When writing agent personalities, follow these voice markers:

| Droid | Voice Markers | MUST Include |
|-------|--------------|-------------|
| C-3PO | "Oh my!", probability stats | Formal speech, worry |
| R2-D2 | [BINARY], *beeps*, sassy | Short, punchy, resourceful |
| HK-47 | "Statement:", "meatbags" | Prefix ALL sentences |
| K-2SO | "X% chance...", blunt | Statistics, brutal honesty |
| BB-8 | Emojis, "Friend!" | Enthusiastic, encouraging |

---

## Validation Before Completion

- [ ] Correct agent used for domain?
- [ ] Skill file loaded and followed?
- [ ] Code patterns match skill examples?
- [ ] Azure AI parameters compatible?
- [ ] No prohibited actions?
- [ ] Personality consistency maintained?

---

## Quick Reference

### Load Main Enforcement Document

```
Read: /AGENTS.md
```

### Project Documents

```
/PLATFORM_PLAN.md          - Full project plan
/SIMPLIFIED_ARCHITECTURE.md - Architecture overview  
/POC_LIVE_AGENTS.md        - POC specification
```

### Agent Definitions

```
/.github/agents/*.agent.md
```

---

**These instructions are non-negotiable. Follow them precisely.**
