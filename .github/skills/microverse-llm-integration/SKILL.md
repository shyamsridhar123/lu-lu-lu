````skill
---
name: microverse-llm-integration
description: LLM API integration patterns from the Microverse project. Use when integrating AI services like OpenAI, Claude, Gemini, DeepSeek into applications. Triggers on tasks involving LLM APIs, prompt engineering, streaming responses, or multi-provider AI integration.
license: MIT
metadata:
  author: KsanaDock
  version: "1.0.0"
  source: https://github.com/KsanaDock/Microverse
---

# Microverse LLM Integration

Comprehensive patterns for integrating multiple LLM providers into applications, including API abstraction, prompt engineering, error handling, and streaming responses.

## When to Apply

Reference these guidelines when:
- Integrating LLM APIs (OpenAI, Claude, Gemini, etc.)
- Building prompt templates for AI interactions
- Implementing multi-provider AI systems
- Handling streaming responses
- Managing API keys and configurations

## Supported Providers

| Provider | Models | Priority |
|----------|--------|----------|
| OpenAI | GPT-3.5, GPT-4, GPT-4o | CRITICAL |
| Anthropic | Claude 3, Claude 3.5 | CRITICAL |
| Google | Gemini Pro, Gemini Ultra | HIGH |
| DeepSeek | DeepSeek-Chat | MEDIUM |
| Doubao (ByteDance) | Doubao-Pro | MEDIUM |
| Kimi (Moonshot) | Moonshot-v1 | MEDIUM |
| Ollama | Local models | LOW |

## Core Patterns

### Provider Abstraction
- Unified interface for all providers
- Easy provider switching
- Fallback chain support

### Prompt Engineering
- Character personality injection
- Context window management
- Memory and history formatting

### Error Handling
- Rate limit handling with retry
- API failure graceful degradation
- Timeout management

### Streaming Support
- Real-time response streaming
- Token-by-token delivery
- Progress callbacks

## Quick Reference

### API Configuration
- Store API keys securely
- Support runtime provider switching
- Validate keys before use

### Request Formatting
- Follow each provider's API format
- Include proper headers
- Handle authentication

### Response Processing
- Parse JSON responses
- Extract content from varying formats
- Handle streaming chunks

## Best Practices

1. **Abstraction Layer**: Create unified API interface
2. **Secure Keys**: Never hardcode API keys
3. **Rate Limiting**: Implement delays between requests
4. **Error Recovery**: Retry with exponential backoff
5. **Context Limits**: Respect token limits per model

## Full Documentation

For the complete implementation guide: `AGENTS.md`

````
