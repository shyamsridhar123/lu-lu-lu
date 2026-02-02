````skill
---
name: microverse-ai-agents
description: Multi-agent AI social simulation patterns from the Microverse project. Use when building autonomous AI agents that interact, communicate, and form relationships. Triggers on tasks involving AI characters, autonomous behavior, social simulation, or agent-based systems.
license: MIT
metadata:
  author: KsanaDock
  version: "1.0.0"
  source: https://github.com/KsanaDock/Microverse
---

# Microverse AI Agents

Comprehensive patterns for building multi-agent AI social simulations, inspired by Stanford AI Town research. Contains guidelines for creating autonomous AI characters with independent thinking, memory, and social capabilities.

## When to Apply

Reference these guidelines when:
- Building multi-agent AI systems
- Creating autonomous character behaviors
- Implementing social simulation mechanics
- Designing AI-driven sandbox games
- Integrating LLMs for character dialogue and decision-making

## Core Concepts

### AI Character Ecosystem
- Design characters with unique personalities, backstories, and behavioral patterns
- Implement autonomous movement, exploration, and interaction
- Support emotional state changes and decision-making
- Build realistic responses based on environment and social context

### Natural Social System
- Natural language conversations powered by large language models
- Multi-turn deep exchanges with context retention
- Dynamic dialogue systems with real-time interaction
- Group discussions, private conversations, and spontaneous social events

### Autonomous Task Management
- Automatic task creation and intelligent assignment
- Priority-based task management
- Dynamic task completion monitoring
- Inter-agent task collaboration and competition

## Architecture Patterns

| Pattern | Purpose | Priority |
|---------|---------|----------|
| `agent-state-machine` | Character behavior states | CRITICAL |
| `agent-memory-integration` | Connect agents to memory systems | CRITICAL |
| `agent-dialogue-manager` | Handle conversation flows | HIGH |
| `agent-task-executor` | Autonomous task handling | HIGH |
| `agent-environment-perception` | Scene and context awareness | MEDIUM |
| `agent-relationship-tracking` | Social relationship management | MEDIUM |

## Quick Reference

### Agent State Management
- Implement finite state machines for agent behaviors
- Track emotional states (mood, health, energy)
- Store metadata on agent nodes for easy access
- Use signals for state change notifications

### Dialogue Integration
- Build prompts with character personality context
- Include environmental and social situation data
- Maintain conversation history per agent pair
- Support streaming responses for real-time feel

### Task System
- Define task priorities and dependencies
- Allow agents to create, claim, and complete tasks
- Track task status changes with callbacks
- Enable collaborative task completion

### Environment Awareness
- Implement scene perception for spatial awareness
- Track proximity to other agents and objects
- React to environmental changes dynamically
- Use area detection for room/zone awareness

## Best Practices

1. **Character Design**: Each agent needs distinct personality traits, goals, and constraints
2. **Memory Injection**: Include relevant memories in dialogue prompts
3. **Context Building**: Combine environment, relationships, and current state in prompts
4. **Rate Limiting**: Implement cooldowns for agent-to-agent interactions
5. **State Persistence**: Save and restore agent states between sessions

## Integration Points

- **LLM APIs**: OpenAI, Claude, Gemini, DeepSeek, Doubao, Kimi, Ollama
- **Game Engines**: Godot 4.x with GDScript
- **Storage**: JSON-based local persistence

## Full Documentation

For the complete implementation guide: `AGENTS.md`

````
