# Smolagents Framework - Complete Implementation Guide

This document provides comprehensive patterns for building AI agents using Hugging Face's smolagents library.

## Source

Based on [huggingface/smolagents](https://github.com/huggingface/smolagents) - A lightweight library for building AI agents in Python.

## Architecture Overview

```text
smolagents/
├── Agents
│   ├── CodeAgent (writes Python code actions)
│   └── ToolCallingAgent (writes JSON tool calls)
├── Models
│   ├── InferenceClientModel (HF Inference API)
│   ├── LiteLLMModel (OpenAI, Anthropic, etc.)
│   ├── TransformersModel (local models)
│   └── OllamaModel (local Ollama)
├── Tools
│   ├── Built-in tools (web search, code execution)
│   ├── MCP server tools
│   └── Custom tools via @tool decorator
└── Memory
    ├── ActionStep
    ├── PlanningStep
    └── FinalAnswerStep
```

## Installation

```bash
# Basic installation
pip install smolagents

# With default tools
pip install 'smolagents[toolkit]'

# With MCP support
pip install 'smolagents[mcp]'

# With LiteLLM for multi-provider support
pip install 'smolagents[litellm]'
```

## Agent Types

### CodeAgent

The recommended agent type that writes actions as Python code:

```python
from smolagents import CodeAgent, InferenceClientModel, WebSearchTool

# Initialize model
model = InferenceClientModel(model_id="Qwen/Qwen2.5-Coder-32B-Instruct")

# Create agent with tools
agent = CodeAgent(
    tools=[WebSearchTool()],
    model=model,
    add_base_tools=True,  # Include default tools
    additional_authorized_imports=["numpy", "pandas"],
    stream_outputs=True
)

# Run a task
result = agent.run("What is the population of France? Calculate the per-capita GDP.")
print(result)
```

**Advantages of CodeAgent:**
- 30% fewer steps than JSON-based agents
- Natural composability (loops, conditionals, function nesting)
- Higher performance on complex benchmarks
- Can combine multiple tool calls in one step

### ToolCallingAgent

For simpler workflows using structured JSON tool calls:

```python
from smolagents import ToolCallingAgent, WebSearchTool

agent = ToolCallingAgent(
    tools=[WebSearchTool()],
    model=model
)

result = agent.run("Search for the latest news about AI")
```

## Model Configuration

### Hugging Face Inference API

```python
from smolagents import InferenceClientModel

# Default model
model = InferenceClientModel()

# Specific model
model = InferenceClientModel(model_id="meta-llama/Llama-3.3-70B-Instruct")

# With custom token
model = InferenceClientModel(
    model_id="Qwen/Qwen2.5-Coder-32B-Instruct",
    token="hf_xxx"
)
```

### LiteLLM (Multi-Provider)

```python
from smolagents import LiteLLMModel

# OpenAI
model = LiteLLMModel(model_id="gpt-4o")

# Anthropic
model = LiteLLMModel(model_id="claude-3-5-sonnet-20241022")

# Ollama (local)
model = LiteLLMModel(
    model_id="ollama_chat/llama3.2",
    api_base="http://localhost:11434"
)

# Azure OpenAI
import os
os.environ["AZURE_API_KEY"] = "your-key"
os.environ["AZURE_API_BASE"] = "https://your-endpoint.openai.azure.com"
os.environ["AZURE_API_VERSION"] = "2024-10-01-preview"
model = LiteLLMModel(model_id="azure/your-deployment-name")
```

### Local Transformers

```python
from smolagents import TransformersModel

model = TransformersModel(model_id="Qwen/Qwen2.5-Coder-7B-Instruct")
```

## Tool Creation

### Using the @tool Decorator

```python
from smolagents import tool

@tool
def get_weather(city: str) -> str:
    """
    Get the current weather for a city.
    
    Args:
        city: The name of the city to get weather for.
    
    Returns:
        A string describing the current weather conditions.
    """
    # Implementation
    return f"Weather in {city}: Sunny, 72°F"

# Use in agent
agent = CodeAgent(tools=[get_weather], model=model)
```

### Class-Based Tools

```python
from smolagents import Tool

class DatabaseQueryTool(Tool):
    name = "database_query"
    description = "Execute SQL queries against the database"
    inputs = {
        "query": {
            "type": "string",
            "description": "SQL query to execute"
        }
    }
    output_type = "string"
    
    def __init__(self, connection_string: str):
        super().__init__()
        self.connection = self._connect(connection_string)
    
    def forward(self, query: str) -> str:
        result = self.connection.execute(query)
        return str(result.fetchall())
```

### Loading Tools from Hub

```python
from smolagents import load_tool

# Load from Hugging Face Hub
image_tool = load_tool("m-ric/text-to-image", trust_remote_code=True)

# Use in agent
agent = CodeAgent(tools=[image_tool], model=model)
```

### MCP Server Tools

```python
from smolagents import ToolCollection

# Load all tools from an MCP server
tools = ToolCollection.from_mcp("npx @anthropic/mcp-server-filesystem")

agent = CodeAgent(tools=tools.tools, model=model)
```

### LangChain Tools

```python
from langchain_community.tools import DuckDuckGoSearchRun
from smolagents import Tool

# Convert LangChain tool
langchain_tool = DuckDuckGoSearchRun()
smolagents_tool = Tool.from_langchain(langchain_tool)
```

### Hugging Face Space as Tool

```python
from smolagents import Tool

# Use a Gradio Space as a tool
tool = Tool.from_space("black-forest-labs/FLUX.1-schnell")
```

## Built-in Tools

```python
from smolagents import (
    WebSearchTool,           # Web search
    DuckDuckGoSearchTool,    # DuckDuckGo search
    GoogleSearchTool,        # Google search (requires API key)
    WikipediaSearchTool,     # Wikipedia search
    VisitWebpageTool,        # Fetch webpage content
    PythonInterpreterTool,   # Execute Python code
    SpeechToTextTool,        # Audio transcription
    TextToSpeechTool,        # Text to audio
)

agent = CodeAgent(
    tools=[WebSearchTool(), VisitWebpageTool()],
    model=model,
    add_base_tools=True  # Includes PythonInterpreterTool
)
```

## Multi-Agent Systems

### Creating Managed Agents

```python
from smolagents import CodeAgent, ToolCallingAgent, InferenceClientModel

model = InferenceClientModel(model_id="Qwen/Qwen2.5-72B-Instruct")

# Create specialized agents
web_agent = ToolCallingAgent(
    tools=[WebSearchTool(), VisitWebpageTool()],
    model=model,
    max_steps=10,
    name="web_search",
    description="Searches the web and retrieves webpage content"
)

code_agent = CodeAgent(
    tools=[],
    model=model,
    name="coder",
    description="Writes and executes Python code"
)

# Create manager agent
manager = CodeAgent(
    tools=[],
    model=model,
    managed_agents=[web_agent, code_agent]
)

# Manager orchestrates sub-agents
result = manager.run(
    "Search for Python best practices and write a summary script"
)
```

## Advanced Configuration

### Planning Steps

Enable periodic planning for complex tasks:

```python
agent = CodeAgent(
    tools=[WebSearchTool()],
    model=model,
    planning_interval=3  # Plan every 3 steps
)
```

### Memory and Step Callbacks

```python
def my_callback(step):
    print(f"Step {step.step_number}: {type(step).__name__}")
    if hasattr(step, 'observations'):
        print(f"  Observations: {step.observations[:100]}...")

agent = CodeAgent(
    tools=[],
    model=model,
    step_callbacks=[my_callback]
)

# Access memory after run
result = agent.run("Calculate 10!")
for step in agent.memory.steps:
    print(f"Step type: {type(step).__name__}")
```

### Secure Code Execution

```python
# Using E2B sandbox
from smolagents import CodeAgent, E2BExecutor

agent = CodeAgent(
    tools=[],
    model=model,
    code_executor=E2BExecutor()
)

# Using Docker
from smolagents import DockerExecutor

agent = CodeAgent(
    tools=[],
    model=model,
    code_executor=DockerExecutor()
)
```

### Custom System Prompt

```python
agent = CodeAgent(
    tools=[],
    model=model,
    system_prompt="""You are a helpful coding assistant.
Always explain your reasoning before writing code.
Use type hints in all Python code."""
)
```

## CLI Usage

```bash
# Run with direct prompt
smolagent "Plan a trip to Tokyo" --model-type InferenceClientModel \
    --model-id "Qwen/Qwen2.5-Coder-32B-Instruct" \
    --tools web_search

# Interactive mode
smolagent

# Web browsing agent
webagent "Find the latest AI news"
```

## Sharing Agents

### Push to Hub

```python
# Push agent to Hugging Face Hub
agent.push_to_hub("username/my-agent")

# Load agent from Hub
loaded_agent = CodeAgent.from_hub("username/my-agent")
```

### Share Tools

```python
# Push tool to Hub
my_tool.push_to_hub("username/my-tool")

# Load tool
tool = load_tool("username/my-tool", trust_remote_code=True)
```

## Gradio Interface

```python
from smolagents import CodeAgent, InferenceClientModel, GradioUI

agent = CodeAgent(tools=[], model=InferenceClientModel())

# Launch interactive UI
GradioUI(agent).launch()
```

## Best Practices Summary

1. **Choose CodeAgent** for complex tasks requiring loops, conditionals, or multi-step reasoning
2. **Use ToolCallingAgent** for simpler, structured workflows
3. **Write detailed tool descriptions** - they're included in the prompt
4. **Enable planning** for tasks with 5+ steps
5. **Use sandboxed execution** (E2B, Docker) for production
6. **Limit tools** - too many can overwhelm weaker models
7. **Stream outputs** for better UX
8. **Use callbacks** to monitor and debug agent behavior

## Token Limits by Provider

| Provider | Model | Context |
|----------|-------|---------|
| HF Inference | Qwen2.5-72B | 128K |
| OpenAI | GPT-4o | 128K |
| Anthropic | Claude 3.5 Sonnet | 200K |
| Google | Gemini 1.5 Pro | 1M |

## References

- [Smolagents Documentation](https://huggingface.co/docs/smolagents)
- [GitHub Repository](https://github.com/huggingface/smolagents)
- [Code Agents Paper](https://huggingface.co/papers/2402.01030)
- [Hugging Face Hub](https://huggingface.co/models)
