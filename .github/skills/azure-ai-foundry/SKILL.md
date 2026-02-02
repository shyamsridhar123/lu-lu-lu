# Azure AI Foundry Integration

## Overview

Azure AI Foundry provides access to the latest OpenAI models (GPT-5.x series, o4/o3 reasoning models) with enterprise security, compliance, and regional availability. This skill covers integrating Azure-hosted LLMs into AI agent applications.

## Key Features

- **Latest Models**: GPT-5.2, GPT-5.1, GPT-5, o4-mini, o3 reasoning models
- **Long Context**: GPT-4.1 with 1 million token context window
- **Enterprise Ready**: Private endpoints, compliance, data residency
- **Scalability**: Global and DataZone deployments
- **Multi-modal**: Vision, audio, and text capabilities

## Available Models (February 2026)

| Model | Best For | Context Window | Max Output |
|-------|----------|----------------|------------|
| gpt-5.2 | Premium reasoning | 400K tokens | 128K |
| gpt-5.1 | Agent reasoning | 400K tokens | 128K |
| gpt-5-chat | Fast conversations | 128K tokens | 16K |
| gpt-5-nano | High-volume, cheap | 400K tokens | 128K |
| o4-mini | Reasoning tasks | 200K tokens | 100K |
| gpt-4.1 | Long context | 1M tokens | 32K |

## Critical Parameter Differences

**GPT-5.x models** support:
- `temperature`, `top_p`, `max_completion_tokens`, `reasoning_effort` (gpt-5.1+)
- Note: `gpt-5.1` defaults to `reasoning_effort: none` - must set explicitly!

**o-series models (o3, o4-mini, o1)** DO NOT support:
- `temperature`, `top_p`, `max_tokens`, `stop` (o3/o4-mini), penalties
- MUST use `max_completion_tokens` and `reasoning_effort` instead

## When to Use

- Building AI agents with tool calling capabilities
- Creating conversational AI with distinct personalities
- Processing large documents (use GPT-4.1)
- Complex reasoning tasks (use o4-mini or o3)
- High-volume, cost-sensitive applications (use gpt-5-nano)

## Integration Points

- **smolagents**: HuggingFace agent framework with Azure backend
- **LangChain**: Alternative agent/chain framework
- **FastAPI**: REST API backends for AI services
- **OpenEnv**: Sandboxed execution environments
