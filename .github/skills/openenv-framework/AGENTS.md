# OpenEnv Framework - Complete Implementation Guide

This document provides comprehensive patterns for building agentic execution environments using Meta's OpenEnv framework.

## Source

Based on [meta-pytorch/OpenEnv](https://github.com/meta-pytorch/OpenEnv) - An e2e framework for creating, deploying, and using isolated execution environments for agentic RL training.

## Architecture Overview

```text
OpenEnv Architecture/
├── Client Side (Your Code)
│   ├── EnvClient (HTTP/WebSocket)
│   ├── AutoEnv (Auto-discovery)
│   └── Models (Action, Observation)
│
├── Server Side (Docker Container)
│   ├── FastAPI Server
│   ├── Environment Class
│   └── WebSocket Handler
│
└── Container Providers
    ├── Docker
    ├── Hugging Face Spaces
    └── Local Process
```

## Installation

```bash
# Install OpenEnv
pip install git+https://github.com/meta-pytorch/OpenEnv.git

# Install with CLI tools
pip install 'openenv[cli]'
```

## Core Abstractions

### Environment (Server-Side)

The base class for all environments:

```python
from openenv.core.env_server import Environment
from dataclasses import dataclass

@dataclass
class MyAction:
    command: str
    value: int = 0

@dataclass
class MyObservation:
    result: str
    done: bool = False
    reward: float = 0.0

@dataclass
class MyState:
    step_count: int = 0
    episode_reward: float = 0.0

class MyEnvironment(Environment[MyAction, MyObservation, MyState]):
    def __init__(self):
        self._state = MyState()
    
    def reset(self) -> MyObservation:
        self._state = MyState()
        return MyObservation(result="Environment reset", done=False)
    
    def step(self, action: MyAction) -> MyObservation:
        self._state.step_count += 1
        result = self._process_action(action)
        return MyObservation(
            result=result,
            done=self._is_done(),
            reward=self._calculate_reward()
        )
    
    def state(self) -> MyState:
        return self._state
    
    def _process_action(self, action: MyAction) -> str:
        return f"Processed: {action.command}"
    
    def _is_done(self) -> bool:
        return self._state.step_count >= 100
    
    def _calculate_reward(self) -> float:
        return 1.0
```

### EnvClient (Client-Side)

The HTTP client for interacting with environments:

```python
from openenv.core.env_client import EnvClient
from openenv.core.http_env_client import HTTPEnvClient

class MyEnv(HTTPEnvClient[MyAction, MyObservation, MyState]):
    """Client for MyEnvironment."""
    
    @classmethod
    def from_docker_image(cls, image: str, port: int = 8000) -> "MyEnv":
        return cls._from_docker(image, port)
    
    @classmethod
    def from_url(cls, url: str) -> "MyEnv":
        return cls(base_url=url)
    
    def _parse_observation(self, data: dict) -> MyObservation:
        return MyObservation(**data)
    
    def _parse_state(self, data: dict) -> MyState:
        return MyState(**data)
    
    def _serialize_action(self, action: MyAction) -> dict:
        return {"command": action.command, "value": action.value}
```

### FastAPI Server

The HTTP server exposing the environment:

```python
from fastapi import FastAPI
from openenv.core.env_server import HTTPEnvServer
from .my_environment import MyEnvironment, MyAction, MyObservation, MyState

app = FastAPI(title="My Environment")

# Create environment and wrap in HTTP server
env = MyEnvironment()
server = HTTPEnvServer(env, MyAction, MyObservation, MyState)

# Mount routes
app.include_router(server.router)

# Health check
@app.get("/health")
def health():
    return {"status": "ok"}
```

## Project Structure

```text
my_env/
├── __init__.py              # Export Action, Observation, State, Env
├── models.py                # Action, Observation, State dataclasses
├── client.py                # MyEnv client implementation
├── openenv.yaml             # Environment manifest
├── pyproject.toml           # Dependencies
├── README.md                # Documentation
└── server/
    ├── __init__.py
    ├── my_environment.py    # Environment logic
    ├── app.py               # FastAPI application
    └── Dockerfile           # Container definition
```

## CLI Commands

### Initialize New Environment

```bash
openenv init my_env
```

This scaffolds the complete structure with templates.

### Build Docker Image

```bash
cd my_env
openenv build
```

### Validate Environment

```bash
openenv validate
```

### Push to Registry

```bash
openenv push --registry docker.io/myuser
```

## Using AutoEnv

Auto-discovery for available environments:

```python
from openenv import AutoEnv, AutoAction

# List available environments
AutoEnv.list_environments()

# Create environment by name
env = AutoEnv.from_env("coding-env")

# Get action class
CodeAction = AutoAction.from_env("coding-env")

# Use environment
result = env.reset()
print(f"Reset: {result.observation}")

action = CodeAction(code="print('Hello, World!')")
step_result = env.step(action)
print(f"Output: {step_result.observation.stdout}")

env.close()
```

## Example Environments

### Echo Environment (Reference)

Minimal environment for testing:

```python
from openenv.core.env_server import Environment
from dataclasses import dataclass

@dataclass
class EchoAction:
    message: str

@dataclass
class EchoObservation:
    echo: str
    timestamp: float

class EchoEnvironment(Environment[EchoAction, EchoObservation, dict]):
    def reset(self) -> EchoObservation:
        return EchoObservation(echo="Ready", timestamp=time.time())
    
    def step(self, action: EchoAction) -> EchoObservation:
        return EchoObservation(
            echo=f"Echo: {action.message}",
            timestamp=time.time()
        )
    
    def state(self) -> dict:
        return {"status": "running"}
```

### Coding Environment

Python code execution with sandboxing:

```python
@dataclass
class CodeAction:
    code: str
    timeout: float = 30.0

@dataclass
class CodeObservation:
    stdout: str
    stderr: str
    exit_code: int
    done: bool

class CodingEnvironment(Environment):
    def step(self, action: CodeAction) -> CodeObservation:
        try:
            result = execute_code_safely(action.code, timeout=action.timeout)
            return CodeObservation(
                stdout=result.stdout,
                stderr=result.stderr,
                exit_code=result.exit_code,
                done=False
            )
        except TimeoutError:
            return CodeObservation(
                stdout="",
                stderr="Execution timed out",
                exit_code=-1,
                done=False
            )
```

### Chat Environment

Conversational RL with tokenization:

```python
@dataclass
class ChatAction:
    tokens: list[int]

@dataclass
class ChatObservation:
    response_tokens: list[int]
    reward: float
    done: bool

class ChatEnvironment(Environment):
    def __init__(self, tokenizer_name: str):
        self.tokenizer = load_tokenizer(tokenizer_name)
        self.history = []
    
    def step(self, action: ChatAction) -> ChatObservation:
        text = self.tokenizer.decode(action.tokens)
        self.history.append(text)
        
        response = generate_response(self.history)
        response_tokens = self.tokenizer.encode(response)
        
        return ChatObservation(
            response_tokens=response_tokens,
            reward=calculate_reward(response),
            done=len(self.history) >= 10
        )
```

## Docker Configuration

### Dockerfile Template

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen

# Copy environment code
COPY . .

# Expose port
EXPOSE 8000

# Run server
CMD ["uvicorn", "server.app:app", "--host", "0.0.0.0", "--port", "8000"]
```

### openenv.yaml Manifest

```yaml
name: my_env
version: "1.0.0"
description: My custom environment

server:
  port: 8000
  dockerfile: server/Dockerfile

client:
  module: client
  class: MyEnv

models:
  action: models.MyAction
  observation: models.MyObservation
  state: models.MyState

dependencies:
  - numpy>=1.20
  - torch>=2.0
```

## Integration with RL Frameworks

### With TRL (Transformer Reinforcement Learning)

```python
from trl import PPOTrainer
from openenv import AutoEnv

env = AutoEnv.from_env("chat-env")

def reward_fn(responses, prompts):
    rewards = []
    for response, prompt in zip(responses, prompts):
        action = ChatAction(tokens=tokenize(response))
        result = env.step(action)
        rewards.append(result.reward)
    return rewards

trainer = PPOTrainer(
    model=model,
    tokenizer=tokenizer,
    reward_model=reward_fn,
)
```

### With Stable-Baselines3

```python
import gymnasium as gym
from stable_baselines3 import PPO
from openenv import AutoEnv

class OpenEnvGymWrapper(gym.Env):
    def __init__(self, env_name: str):
        self.env = AutoEnv.from_env(env_name)
        # Define action/observation spaces
    
    def reset(self, seed=None):
        result = self.env.reset()
        return self._obs_to_array(result.observation), {}
    
    def step(self, action):
        result = self.env.step(self._array_to_action(action))
        return (
            self._obs_to_array(result.observation),
            result.reward,
            result.done,
            False,
            {}
        )

env = OpenEnvGymWrapper("atari-env")
model = PPO("MlpPolicy", env, verbose=1)
model.learn(total_timesteps=100000)
```

## WebSocket Support

For persistent sessions with streaming:

```python
from openenv.core.env_client import EnvClient

class MyStreamingEnv(EnvClient):
    async def stream_step(self, action: MyAction):
        async for observation in self._ws_step(action):
            yield observation
```

## Best Practices

### 1. Type Safety

Always use typed dataclasses:

```python
@dataclass
class Action:
    command: str  # Explicit types
    count: int = 0  # Defaults when appropriate
```

### 2. Error Handling

Handle errors gracefully:

```python
def step(self, action: MyAction) -> MyObservation:
    try:
        result = self._process(action)
        return MyObservation(result=result, success=True)
    except Exception as e:
        return MyObservation(result="", success=False, error=str(e))
```

### 3. State Management

Track all relevant episode state:

```python
@dataclass
class MyState:
    accumulated_reward: float = 0.0
    last_action: str = ""
    step_count: int = 0
```

### 4. Documentation

Each environment needs:
- Overview and purpose
- Quick start example
- Action/Observation specs
- Build instructions

### 5. Testing

Integration tests with actual Docker:

```python
def test_environment():
    env = MyEnv.from_docker_image("my_env:latest")
    
    result = env.reset()
    assert result.observation is not None
    
    step_result = env.step(MyAction(command="test"))
    assert not step_result.done
    
    env.close()
```

## Available Environments

| Environment | Use Case | Complexity |
|-------------|----------|------------|
| `echo_env` | Testing | Minimal |
| `coding_env` | Code execution | Medium |
| `chat_env` | Conversational RL | Medium |
| `browsergym_env` | Web automation | High |
| `openspiel_env` | Game theory | Medium |
| `atari_env` | Classic games | Medium |
| `finrl_env` | Stock trading | High |
| `repl_env` | REPL with LLM | Medium |

## References

- [OpenEnv GitHub](https://github.com/meta-pytorch/OpenEnv)
- [OpenEnv Documentation](https://meta-pytorch.github.io/OpenEnv/)
- [Gymnasium API](https://gymnasium.farama.org/)
- [RFC: Core Abstractions](https://github.com/meta-pytorch/OpenEnv/blob/main/rfcs/001-abstractions.md)
