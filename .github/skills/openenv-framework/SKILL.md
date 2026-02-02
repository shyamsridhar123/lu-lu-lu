````skill
---
name: openenv-framework
description: Meta's OpenEnv framework for agentic execution environments. Use when building RL environments, containerized simulations, or agent training infrastructure. Triggers on tasks involving reinforcement learning environments, Gymnasium-style APIs, Docker-based environments, or agent execution sandboxes.
license: BSD-3-Clause
metadata:
  author: meta-pytorch
  version: "1.0.0"
  source: https://github.com/meta-pytorch/OpenEnv
---

# OpenEnv Framework

Comprehensive patterns for building isolated execution environments for agentic RL training using Meta's OpenEnv framework - a production-ready system with Gymnasium-style APIs.

## When to Apply

Reference these guidelines when:
- Building containerized RL environments
- Creating agent execution sandboxes
- Implementing Gymnasium-style environment APIs
- Deploying environments to production
- Training language models with RL

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| Environment | Server (Docker) | Game/simulation logic |
| EnvClient | Client | HTTP/WebSocket interface |
| Models | Shared | Action, Observation, State types |

## Core Concepts

### Gymnasium-Style API
```python
env.reset()   # Initialize environment
env.step(action)  # Take action, get observation
env.state()   # Get current state
env.close()   # Clean up
```

### Type-Safe Contracts
```python
@dataclass
class Action:
    command: str

@dataclass  
class Observation:
    result: str
    done: bool
```

### Container Isolation
- Docker-based environments
- Reproducible deployments
- Secure execution
- Easy scaling

## Quick Reference

### Using an Environment
```python
from openenv import AutoEnv

env = AutoEnv.from_env("coding-env")
result = env.reset()
step_result = env.step(CodeAction(code="print('hello')"))
env.close()
```

### Creating an Environment
```bash
openenv init my_env
openenv build
openenv push
```

## Available Environments

- **Echo**: Testing and learning
- **Coding**: Python code execution
- **Chat**: Conversational RL
- **BrowserGym**: Web automation
- **OpenSpiel**: Game theory
- **Atari**: Classic games
- **FinRL**: Stock trading

## Best Practices

1. **Type Safety**: Use dataclasses for all models
2. **Error Handling**: Return errors in observations
3. **State Management**: Track all episode state
4. **Documentation**: Comprehensive README per env
5. **Testing**: Integration tests with Docker

## Full Documentation

For the complete implementation guide: `AGENTS.md`

````
