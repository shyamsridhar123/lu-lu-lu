````skill
---
name: smolagents-framework
description: Hugging Face smolagents library for building AI agents. Use when creating CodeAgents, ToolCallingAgents, custom tools, or multi-agent systems. Triggers on tasks involving agent orchestration, LLM tool use, code execution agents, or Hugging Face agent integration.
license: Apache-2.0
metadata:
  author: huggingface
  version: "1.0.0"
  source: https://github.com/huggingface/smolagents
---

# Smolagents Framework

Comprehensive patterns for building AI agents using Hugging Face's smolagents library - a lightweight, model-agnostic framework for creating code agents and tool-calling agents.

## When to Apply

Reference these guidelines when:
- Building AI agents that execute Python code
- Creating tool-calling agents with JSON actions
- Integrating with multiple LLM providers
- Building multi-agent systems with orchestration
- Implementing custom tools for agents

## Core Agent Types

| Agent Type | Description | Use Case |
|------------|-------------|----------|
| `CodeAgent` | Writes actions as Python code | Complex logic, loops, conditionals |
| `ToolCallingAgent` | Writes actions as JSON tool calls | Simpler workflows, structured output |

## Key Features

### Model Agnostic
- Hugging Face Inference API
- OpenAI, Anthropic, Google via LiteLLM
- Local models via Transformers or Ollama
- Azure OpenAI deployments

### Tool Agnostic
- MCP server tools
- LangChain tools
- Hugging Face Spaces as tools
- Custom tool creation

### Multi-Modal
- Text inputs
- Vision/image inputs
- Video and audio processing

## Quick Reference

### Agent Creation
```python
from smolagents import CodeAgent, InferenceClientModel

model = InferenceClientModel()
agent = CodeAgent(tools=[], model=model)
result = agent.run("Calculate fibonacci(10)")
```

### Custom Tools
```python
from smolagents import tool

@tool
def search_web(query: str) -> str:
    """Search the web for information."""
    return perform_search(query)
```

### Multi-Agent Systems
```python
web_agent = ToolCallingAgent(
    tools=[WebSearchTool()],
    model=model,
    name="search",
    description="Runs web searches"
)
manager = CodeAgent(managed_agents=[web_agent])
```

## Best Practices

1. **Code Agents First**: Use CodeAgent for complex tasks (30% fewer steps)
2. **Secure Execution**: Use sandboxed environments (E2B, Blaxel, Docker)
3. **Tool Descriptions**: Write clear, detailed tool descriptions
4. **Planning Steps**: Enable `planning_interval` for complex tasks
5. **Memory Management**: Use agent memory for multi-step workflows

## Full Documentation

For the complete implementation guide: `AGENTS.md`

````
