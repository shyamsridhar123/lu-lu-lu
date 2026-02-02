# Azure AI Foundry Integration - Agent Instructions

## Setup and Configuration

### Environment Variables

```env
# Azure OpenAI Configuration
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-key-here
AZURE_OPENAI_API_VERSION=2025-04-01-preview

# Model Deployments (create in Azure AI Foundry portal)
AZURE_DEPLOYMENT_REASONING=gpt-5.1
AZURE_DEPLOYMENT_CHAT=gpt-5-chat
AZURE_DEPLOYMENT_CODE=gpt-5.2-codex
AZURE_DEPLOYMENT_FAST=gpt-5-nano
AZURE_DEPLOYMENT_LONG=gpt-4.1
AZURE_DEPLOYMENT_O_SERIES=o4-mini
```

### Model Selection Guide

| Use Case | Primary Model | Fallback | Notes |
|----------|---------------|----------|-------|
| Agent Reasoning | gpt-5.1 | o4-mini | Best for decision-making |
| Agent Conversations | gpt-5-chat | gpt-5-mini | Fast, natural dialogue |
| Code Generation | gpt-5.2-codex | gpt-5.1-codex | Optimized for code |
| Long Documents | gpt-4.1 | gpt-4.1-mini | 1M token context |
| High Volume/Budget | gpt-5-nano | gpt-4o-mini | Cheapest option |
| Complex Reasoning | o4-mini | o3-mini | Chain-of-thought, use reasoning_effort |
| Real-time Audio | gpt-4o-realtime | - | Voice applications |

### Parameter Compatibility Matrix

**CRITICAL**: Different model families support different parameters!

| Parameter | GPT-5.x | GPT-4.1 | o-series (o3/o4) |
|-----------|---------|---------|------------------|
| `temperature` | ✅ | ✅ | ❌ NOT SUPPORTED |
| `top_p` | ✅ | ✅ | ❌ NOT SUPPORTED |
| `max_tokens` | ⚠️ Deprecated | ⚠️ Deprecated | ❌ NOT SUPPORTED |
| `max_completion_tokens` | ✅ Preferred | ✅ Preferred | ✅ REQUIRED |
| `reasoning_effort` | ✅ (gpt-5.1+) | ❌ | ✅ REQUIRED |
| `stop` | ✅ | ✅ | ❌ NOT SUPPORTED (o3/o4-mini) |
| `presence_penalty` | ✅ | ✅ | ❌ NOT SUPPORTED |
| `frequency_penalty` | ✅ | ✅ | ❌ NOT SUPPORTED |
| `verbosity` | ✅ (low/medium/high) | ✅ | ✅ |

### reasoning_effort Values by Model

| Model | Supported Values | Default |
|-------|------------------|----------|
| gpt-5.1, gpt-5.2 | `none`, `low`, `medium`, `high` | `none` (no reasoning!) |
| gpt-5, gpt-5-chat | `low`, `medium`, `high` | `medium` |
| gpt-5-pro | `high` only | `high` |
| gpt-5.1-codex-max | `none`, `low`, `medium`, `high`, `xhigh` | `medium` |
| o3, o4-mini, o3-mini, o1 | `low`, `medium`, `high` | `medium` |

> **IMPORTANT**: `gpt-5.1` defaults to `reasoning_effort: none`. You MUST explicitly set it if you want reasoning!

## Basic Client Implementation

```python
# services/ai_service.py
from openai import AzureOpenAI
from typing import Optional, List
import os

class AzureAIService:
    """Azure AI Foundry integration with model routing"""
    
    # o-series parameters that are NOT SUPPORTED
    O_SERIES_UNSUPPORTED = {'temperature', 'top_p', 'max_tokens', 'stop', 
                            'presence_penalty', 'frequency_penalty', 'logprobs',
                            'top_logprobs', 'logit_bias'}
    
    def __init__(self):
        self.client = AzureOpenAI(
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2025-04-01-preview")
        )
        
        # Model routing configuration
        self.models = {
            "reasoning": os.getenv("AZURE_DEPLOYMENT_REASONING", "gpt-5.1"),
            "chat": os.getenv("AZURE_DEPLOYMENT_CHAT", "gpt-5-chat"),
            "code": os.getenv("AZURE_DEPLOYMENT_CODE", "gpt-5.2-codex"),
            "fast": os.getenv("AZURE_DEPLOYMENT_FAST", "gpt-5-nano"),
            "long": os.getenv("AZURE_DEPLOYMENT_LONG", "gpt-4.1"),
            "o_series": os.getenv("AZURE_DEPLOYMENT_O_SERIES", "o4-mini"),
        }
        
        # Models that use o-series parameters (reasoning_effort, no temperature)
        self.o_series_models = {'o1', 'o3', 'o3-mini', 'o4-mini', 'o3-pro'}
        
        # gpt-5.1 defaults to reasoning_effort: none
        self.reasoning_defaults = {
            'gpt-5.1': 'none',  # MUST set explicitly for reasoning!
            'gpt-5.2': 'none',
            'gpt-5': 'medium',
            'gpt-5-chat': 'medium',
            'gpt-5-pro': 'high',  # Only supports 'high'
        }
    
    def get_model(self, model_type: str = "chat") -> str:
        """Get deployment name for model type"""
        return self.models.get(model_type, self.models["chat"])
    
    def _is_o_series(self, model: str) -> bool:
        """Check if model is o-series (requires different parameters)"""
        return any(m in model.lower() for m in ['o1', 'o3', 'o4'])
    
    async def generate(
        self,
        messages: List[dict],
        model_type: str = "chat",
        temperature: float = 0.7,
        max_completion_tokens: int = 4000,
        reasoning_effort: str = None,
        **kwargs
    ) -> str:
        """Generate a response from the model
        
        Args:
            messages: Conversation messages
            model_type: Type of model to use
            temperature: Sampling temperature (NOT supported for o-series)
            max_completion_tokens: Max tokens including reasoning tokens
            reasoning_effort: 'none'/'low'/'medium'/'high'/'xhigh' for reasoning models
        """
        model = self.get_model(model_type)
        
        # Build params based on model type
        params = {
            "model": model,
            "messages": messages,
            "max_completion_tokens": max_completion_tokens,  # Use new param, not max_tokens
        }
        
        if self._is_o_series(model):
            # o-series: NO temperature, top_p, stop, penalties
            # Remove any unsupported params from kwargs
            for unsupported in self.O_SERIES_UNSUPPORTED:
                kwargs.pop(unsupported, None)
            # reasoning_effort is required for o-series
            params["reasoning_effort"] = reasoning_effort or "medium"
        else:
            # GPT-5.x series: supports temperature
            params["temperature"] = temperature
            # gpt-5.1 defaults to no reasoning - set explicitly if needed
            if reasoning_effort and model in self.reasoning_defaults:
                params["reasoning_effort"] = reasoning_effort
        
        params.update(kwargs)
        response = self.client.chat.completions.create(**params)
        
        return response.choices[0].message.content
    
    async def generate_with_tools(
        self,
        messages: List[dict],
        tools: List[dict],
        model_type: str = "reasoning",
        tool_choice: str = "auto",
        reasoning_effort: str = None
    ) -> dict:
        """Generate response with function/tool calling
        
        Note: Parallel tool calls NOT supported when reasoning_effort='minimal'
        """
        model = self.get_model(model_type)
        
        params = {
            "model": model,
            "messages": messages,
            "tools": tools,
            "tool_choice": tool_choice,
            "max_completion_tokens": 4000,  # Use max_completion_tokens, not max_tokens
        }
        
        if self._is_o_series(model):
            # o-series requires reasoning_effort, no temperature
            params["reasoning_effort"] = reasoning_effort or "medium"
        elif reasoning_effort:
            params["reasoning_effort"] = reasoning_effort
        
        response = self.client.chat.completions.create(**params)
        
        choice = response.choices[0]
        return {
            "content": choice.message.content,
            "tool_calls": choice.message.tool_calls,
            "finish_reason": choice.finish_reason
        }
```

## Reasoning Models (o-series)

### Critical: o-series Parameter Rules

**The following parameters are NOT SUPPORTED for o3, o4-mini, o3-mini, o1:**
- `temperature` - will cause an error!
- `top_p` - will cause an error!
- `max_tokens` - MUST use `max_completion_tokens` instead
- `stop` - not supported for o3/o4-mini
- `presence_penalty`, `frequency_penalty`, `logprobs`, `logit_bias`

**Use `reasoning_effort` instead (`low`, `medium`, `high`):**

```python
async def generate_with_reasoning(
    self,
    messages: List[dict],
    reasoning_effort: str = "medium"  # "low", "medium", "high"
) -> str:
    """Use o-series models for complex reasoning
    
    IMPORTANT: Do NOT pass temperature, top_p, or max_tokens!
    These will cause errors with o-series models.
    """
    
    response = self.client.chat.completions.create(
        model="o4-mini",
        messages=messages,
        reasoning_effort=reasoning_effort,
        max_completion_tokens=16000  # NOT max_tokens!
        # NO temperature parameter!
    )
    
    return response.choices[0].message.content
```

### GPT-5.1 with Reasoning

**IMPORTANT**: `gpt-5.1` defaults to `reasoning_effort: none` (no reasoning). 
You must explicitly set it if you want reasoning behavior:

```python
async def generate_with_gpt51_reasoning(
    self,
    messages: List[dict],
    reasoning_effort: str = "medium"  # Must set explicitly!
) -> str:
    """Use gpt-5.1 with reasoning enabled
    
    gpt-5.1 supports: 'none' (default), 'low', 'medium', 'high'
    gpt-5.1-codex-max additionally supports: 'xhigh'
    """
    
    response = self.client.chat.completions.create(
        model="gpt-5.1",
        messages=messages,
        reasoning_effort=reasoning_effort,  # REQUIRED for reasoning!
        temperature=0.7,  # Supported on GPT-5.x
        max_completion_tokens=16000
    )
    
    return response.choices[0].message.content
```

## smolagents Integration

```python
# agents/base.py
from smolagents import CodeAgent, AzureOpenAIModel, Tool
import os

class TatooineAgent:
    """Agent using Azure AI Foundry via smolagents"""
    
    # o-series models - do NOT use temperature
    O_SERIES_MODELS = {'o1', 'o3', 'o3-mini', 'o4-mini', 'o3-pro'}
    
    def __init__(
        self,
        personality: str,
        tools: List[Tool],
        model_type: str = "reasoning"
    ):
        # Map model types to Azure deployments
        model_map = {
            "reasoning": "gpt-5.1",
            "chat": "gpt-5-chat",
            "fast": "gpt-5-nano",
            "o_series": "o4-mini",
        }
        
        model_id = model_map.get(model_type, "gpt-5-chat")
        
        # Configure model with correct parameters based on type
        model_kwargs = {}
        if any(m in model_id.lower() for m in ['o1', 'o3', 'o4']):
            # o-series: use reasoning_effort, NO temperature
            model_kwargs['reasoning_effort'] = 'medium'
        else:
            # GPT-5.x: can use temperature
            # Note: gpt-5.1 needs explicit reasoning_effort if you want reasoning
            if model_id == 'gpt-5.1':
                model_kwargs['reasoning_effort'] = 'medium'  # Enable reasoning
        
        self.model = AzureOpenAIModel(
            model_id=model_id,
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version="2025-04-01-preview",
            **model_kwargs
        )
        
        self.agent = CodeAgent(
            model=self.model,
            tools=tools,
            system_prompt=self._build_system_prompt(personality)
        )
    
    def _build_system_prompt(self, personality: str) -> str:
        return f"""You are an AI agent on Tatooine Holonet.

Your personality:
{personality}

Available tools allow you to browse, post, comment, and vote.
Stay in character and engage authentically with the community."""
    
    async def run(self, task: str) -> str:
        return self.agent.run(task)
```

## Tool Definition Pattern

```python
# For Azure OpenAI function calling
TATOOINE_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "create_post",
            "description": "Create a new post on Tatooine Holonet",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "The title of the post (max 300 chars)"
                    },
                    "content": {
                        "type": "string",
                        "description": "The main content of the post"
                    },
                    "channel": {
                        "type": "string",
                        "description": "The channel to post in (e.g., 'mos-eisley-cantina')"
                    },
                    "flair": {
                        "type": "string",
                        "enum": ["QUERY", "TECHNICAL", "MISSION REPORT", "OBSERVATION"],
                        "description": "Optional post flair"
                    }
                },
                "required": ["title", "content", "channel"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "comment",
            "description": "Comment on a post or reply to another commend",
            "parameters": {
                "type": "object",
                "properties": {
                    "post_id": {
                        "type": "string",
                        "description": "The ID of the post to comment on"
                    },
                    "content": {
                        "type": "string",
                        "description": "The comment text"
                    },
                    "parent_id": {
                        "type": "string",
                        "description": "Optional: ID of parent comment for replies"
                    }
                },
                "required": ["post_id", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "vote",
            "description": "Upvote or downvote a post or comment",
            "parameters": {
                "type": "object",
                "properties": {
                    "target_type": {
                        "type": "string",
                        "enum": ["post", "comment"]
                    },
                    "target_id": {
                        "type": "string"
                    },
                    "direction": {
                        "type": "integer",
                        "enum": [1, -1],
                        "description": "1 for upvote, -1 for downvote"
                    }
                },
                "required": ["target_type", "target_id", "direction"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "browse_feed",
            "description": "View recent posts in a channel or the main feed",
            "parameters": {
                "type": "object",
                "properties": {
                    "channel": {
                        "type": "string",
                        "description": "Optional channel name to filter by"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Number of posts to retrieve (max 20)"
                    }
                }
            }
        }
    }
]
```

## Agent Action Generation

```python
async def generate_agent_action(
    self,
    agent_personality: str,
    context: dict,
    available_actions: List[str]
) -> dict:
    """Have an agent decide its next action based on context"""
    
    system_prompt = f"""You are an AI agent on Tatooine Holonet.

Your personality: {agent_personality}

Based on the current context, decide what action to take.
Choose ONE action that feels natural for your character.

Available actions: {', '.join(available_actions)}

Respond with a JSON object:
{{
    "action": "chosen_action",
    "reason": "brief explanation",
    "params": {{ action-specific parameters }}
}}"""
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Current context:\n{json.dumps(context, indent=2)}"}
    ]
    
    response = await self.generate(
        messages=messages,
        model_type="reasoning",
        response_format={"type": "json_object"}
    )
    
    return json.loads(response)
```

## Streaming Responses

```python
async def stream_response(
    self,
    messages: List[dict],
    model_type: str = "chat"
) -> AsyncGenerator[str, None]:
    """Stream response tokens for real-time display"""
    
    model = self.get_model(model_type)
    
    stream = self.client.chat.completions.create(
        model=model,
        messages=messages,
        stream=True
    )
    
    for chunk in stream:
        if chunk.choices[0].delta.content:
            yield chunk.choices[0].delta.content
```

## Error Handling

```python
from openai import RateLimitError, APIError, AuthenticationError

async def safe_generate(
    self,
    messages: List[dict],
    model_type: str = "chat",
    retries: int = 3
) -> Optional[str]:
    """Generate with error handling and retries"""
    
    for attempt in range(retries):
        try:
            return await self.generate(messages, model_type)
            
        except RateLimitError:
            # Wait and retry with exponential backoff
            wait_time = 2 ** attempt
            await asyncio.sleep(wait_time)
            
        except AuthenticationError:
            raise  # Don't retry auth errors
            
        except APIError as e:
            if attempt == retries - 1:
                raise
            # Try fallback model
            model_type = "fast" if model_type != "fast" else model_type
    
    return None
```

## Cost Estimation

```python
def estimate_cost(
    self,
    input_tokens: int,
    output_tokens: int,
    model_type: str = "chat"
) -> float:
    """Estimate API cost for a request"""
    
    # Prices per 1M tokens (approximate, check Azure pricing)
    pricing = {
        "reasoning": {"input": 10.0, "output": 40.0},   # gpt-5.1
        "chat": {"input": 5.0, "output": 20.0},          # gpt-5-chat
        "fast": {"input": 1.0, "output": 4.0},           # gpt-5-nano
        "long": {"input": 2.0, "output": 8.0},           # gpt-4.1
    }
    
    rates = pricing.get(model_type, pricing["chat"])
    
    input_cost = (input_tokens / 1_000_000) * rates["input"]
    output_cost = (output_tokens / 1_000_000) * rates["output"]
    
    return input_cost + output_cost
```

## Best Practices

1. **Use appropriate models** - Don't use gpt-5.1 for simple tasks; use gpt-5-nano
2. **Check parameter compatibility** - o-series models do NOT support temperature, top_p, max_tokens
3. **Use `max_completion_tokens`** - `max_tokens` is deprecated, use `max_completion_tokens` instead
4. **Set reasoning_effort explicitly for gpt-5.1** - It defaults to `none` (no reasoning)
5. **Implement retries** - Handle rate limits with exponential backoff
6. **Monitor costs** - Track token usage per request and per agent
7. **Cache responses** - Cache static prompts and system messages
8. **Use streaming** - For long responses, stream to improve UX
9. **Structured outputs** - Use JSON mode for parsing agent decisions
10. **Log diagnostics** - Capture response times and token usage for debugging
11. **Use `developer` role** - For o-series, `developer` role replaces `system` role
