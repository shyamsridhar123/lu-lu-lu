````skill
---
name: microverse-memory-systems
description: AI agent memory system patterns from the Microverse project. Use when implementing persistent memory, context recall, and relationship tracking for AI agents. Triggers on tasks involving agent memory, conversation history, contextual recall, or long-term knowledge storage.
license: MIT
metadata:
  author: KsanaDock
  version: "1.0.0"
  source: https://github.com/KsanaDock/Microverse
---

# Microverse Memory Systems

Comprehensive patterns for implementing persistent memory systems in AI agents, enabling long-term recall, relationship development, and contextual responses.

## When to Apply

Reference these guidelines when:
- Building memory systems for AI agents
- Implementing conversation history management
- Creating contextual recall mechanisms
- Designing relationship tracking systems
- Managing memory storage and retrieval

## Core Concepts

### Long-term Memory Storage
- Persistent storage of conversations and events
- Formatted memory entries with timestamps
- Intelligent retrieval based on relevance
- Memory consolidation and summarization

### Contextual Recall
- Reference past interactions in current conversations
- Semantic search for relevant memories
- Recency and importance weighting
- Context window optimization for LLMs

### Relationship Development
- Track relationship scores between agents
- Record significant relationship events
- Evolve relationships based on interactions
- Support relationship types (friend, colleague, etc.)

## Memory Patterns

| Pattern | Purpose | Priority |
|---------|---------|----------|
| `memory-entry-format` | Standardize memory structure | CRITICAL |
| `memory-retrieval` | Efficient memory lookup | CRITICAL |
| `memory-consolidation` | Summarize old memories | HIGH |
| `memory-injection` | Include memories in prompts | HIGH |
| `memory-persistence` | Save/load memory states | MEDIUM |
| `memory-relationship` | Track social connections | MEDIUM |

## Quick Reference

### Memory Entry Structure
- Timestamp for temporal ordering
- Category (conversation, event, observation)
- Participants involved
- Content summary
- Importance score

### Retrieval Strategies
- Recent-first for conversation context
- Keyword matching for specific topics
- Relationship-filtered for social context
- Importance-weighted for key events

### Storage Optimization
- Use JSON for portable storage
- Implement memory limits per agent
- Archive old memories periodically
- Support memory export/import

## Best Practices

1. **Structured Format**: Use consistent schema for all memory entries
2. **Relevance Scoring**: Assign importance to filter critical memories
3. **Contextual Limits**: Respect LLM context window sizes
4. **Async Persistence**: Don't block agent behavior on saves
5. **Privacy Separation**: Keep agent memories isolated

## Full Documentation

For the complete implementation guide: `AGENTS.md`

````
