# Microverse LLM Integration - Complete Implementation Guide

This document provides comprehensive patterns for integrating multiple LLM providers into applications based on the Microverse project.

## Source

Based on [KsanaDock/Microverse](https://github.com/KsanaDock/Microverse) - Multi-provider AI integration for game dialogue systems.

## Architecture Overview

```text
LLM Integration/
├── APIManager (Central Controller)
│   ├── ProviderAdapter (Per-Provider Logic)
│   ├── RequestQueue (Rate Limiting)
│   └── ResponseParser (Unified Output)
├── PromptBuilder (Context Assembly)
└── ConfigStorage (API Keys & Settings)
```

## Supported Providers

### Provider Configuration

```gdscript
enum Provider {
    OPENAI,
    CLAUDE,
    GEMINI,
    DEEPSEEK,
    DOUBAO,
    KIMI,
    OLLAMA
}

const PROVIDER_CONFIG = {
    Provider.OPENAI: {
        "name": "OpenAI",
        "endpoint": "https://api.openai.com/v1/chat/completions",
        "models": ["gpt-3.5-turbo", "gpt-4", "gpt-4o", "gpt-4-turbo"],
        "default_model": "gpt-4o",
        "auth_header": "Authorization",
        "auth_prefix": "Bearer "
    },
    Provider.CLAUDE: {
        "name": "Claude",
        "endpoint": "https://api.anthropic.com/v1/messages",
        "models": ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-5-sonnet-20241022"],
        "default_model": "claude-3-5-sonnet-20241022",
        "auth_header": "x-api-key",
        "auth_prefix": "",
        "extra_headers": {"anthropic-version": "2023-06-01"}
    },
    Provider.GEMINI: {
        "name": "Gemini",
        "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        "models": ["gemini-pro", "gemini-1.5-pro"],
        "default_model": "gemini-1.5-pro",
        "auth_type": "query",
        "auth_param": "key"
    },
    Provider.DEEPSEEK: {
        "name": "DeepSeek",
        "endpoint": "https://api.deepseek.com/v1/chat/completions",
        "models": ["deepseek-chat"],
        "default_model": "deepseek-chat",
        "auth_header": "Authorization",
        "auth_prefix": "Bearer "
    },
    Provider.DOUBAO: {
        "name": "Doubao",
        "endpoint": "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        "models": ["doubao-pro-32k"],
        "default_model": "doubao-pro-32k",
        "auth_header": "Authorization",
        "auth_prefix": "Bearer "
    },
    Provider.KIMI: {
        "name": "Kimi",
        "endpoint": "https://api.moonshot.cn/v1/chat/completions",
        "models": ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
        "default_model": "moonshot-v1-8k",
        "auth_header": "Authorization",
        "auth_prefix": "Bearer "
    },
    Provider.OLLAMA: {
        "name": "Ollama",
        "endpoint": "http://localhost:11434/api/chat",
        "models": ["llama2", "mistral", "codellama"],
        "default_model": "llama2",
        "auth_type": "none"
    }
}
```

## API Manager

### Core Manager Class

```gdscript
class_name APIManager
extends Node

signal request_started(provider: String)
signal response_received(content: String)
signal response_chunk(chunk: String)  # For streaming
signal request_failed(error: String)

var current_provider: Provider = Provider.OPENAI
var api_keys: Dictionary = {}
var selected_models: Dictionary = {}
var http_request: HTTPRequest

func _ready() -> void:
    http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_request_completed)
    load_configuration()

func set_api_key(provider: Provider, key: String) -> void:
    api_keys[provider] = key
    save_configuration()

func set_model(provider: Provider, model: String) -> void:
    var config = PROVIDER_CONFIG[provider]
    if model in config.models:
        selected_models[provider] = model
        save_configuration()
    else:
        push_error("Invalid model %s for provider %s" % [model, config.name])

func get_model(provider: Provider) -> String:
    if provider in selected_models:
        return selected_models[provider]
    return PROVIDER_CONFIG[provider].default_model
```

### Making Requests

```gdscript
func send_message(messages: Array, options: Dictionary = {}) -> void:
    var provider = options.get("provider", current_provider)
    var config = PROVIDER_CONFIG[provider]
    
    if not _validate_api_key(provider):
        emit_signal("request_failed", "API key not configured for %s" % config.name)
        return
    
    emit_signal("request_started", config.name)
    
    var endpoint = _build_endpoint(provider, config)
    var headers = _build_headers(provider, config)
    var body = _build_request_body(provider, messages, options)
    
    var error = http_request.request(
        endpoint,
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
    )
    
    if error != OK:
        emit_signal("request_failed", "HTTP request failed: %s" % error)

func _validate_api_key(provider: Provider) -> bool:
    if PROVIDER_CONFIG[provider].get("auth_type") == "none":
        return true
    return provider in api_keys and api_keys[provider].length() > 0
```

### Building Request Bodies

```gdscript
func _build_request_body(provider: Provider, messages: Array, options: Dictionary) -> Dictionary:
    var model = get_model(provider)
    var temperature = options.get("temperature", 0.7)
    var max_tokens = options.get("max_tokens", 1024)
    
    match provider:
        Provider.OPENAI, Provider.DEEPSEEK, Provider.DOUBAO, Provider.KIMI:
            return _build_openai_format(messages, model, temperature, max_tokens)
        Provider.CLAUDE:
            return _build_claude_format(messages, model, temperature, max_tokens)
        Provider.GEMINI:
            return _build_gemini_format(messages, temperature, max_tokens)
        Provider.OLLAMA:
            return _build_ollama_format(messages, model)
    
    return {}

func _build_openai_format(messages: Array, model: String, temperature: float, max_tokens: int) -> Dictionary:
    return {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens
    }

func _build_claude_format(messages: Array, model: String, temperature: float, max_tokens: int) -> Dictionary:
    # Claude requires system message to be separate
    var system_message = ""
    var chat_messages = []
    
    for msg in messages:
        if msg.role == "system":
            system_message = msg.content
        else:
            chat_messages.append({
                "role": msg.role,
                "content": msg.content
            })
    
    return {
        "model": model,
        "system": system_message,
        "messages": chat_messages,
        "temperature": temperature,
        "max_tokens": max_tokens
    }

func _build_gemini_format(messages: Array, temperature: float, max_tokens: int) -> Dictionary:
    var contents = []
    
    for msg in messages:
        var role = "user" if msg.role == "user" else "model"
        if msg.role == "system":
            # Gemini handles system as user instruction
            role = "user"
        contents.append({
            "role": role,
            "parts": [{"text": msg.content}]
        })
    
    return {
        "contents": contents,
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_tokens
        }
    }

func _build_ollama_format(messages: Array, model: String) -> Dictionary:
    return {
        "model": model,
        "messages": messages,
        "stream": false
    }
```

### Response Parsing

```gdscript
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        emit_signal("request_failed", "Request failed with result: %s" % result)
        return
    
    if response_code != 200:
        var error_body = body.get_string_from_utf8()
        emit_signal("request_failed", "API error %s: %s" % [response_code, error_body])
        return
    
    var json = JSON.new()
    if json.parse(body.get_string_from_utf8()) != OK:
        emit_signal("request_failed", "Failed to parse response JSON")
        return
    
    var data = json.get_data()
    var content = _extract_content(current_provider, data)
    
    if content:
        emit_signal("response_received", content)
    else:
        emit_signal("request_failed", "Could not extract content from response")

func _extract_content(provider: Provider, data: Dictionary) -> String:
    match provider:
        Provider.OPENAI, Provider.DEEPSEEK, Provider.DOUBAO, Provider.KIMI:
            return data.choices[0].message.content
        Provider.CLAUDE:
            return data.content[0].text
        Provider.GEMINI:
            return data.candidates[0].content.parts[0].text
        Provider.OLLAMA:
            return data.message.content
    
    return ""
```

## Prompt Building

### Character Prompt Template

```gdscript
class_name PromptBuilder
extends RefCounted

const SYSTEM_TEMPLATE = """You are {name}, a {role} in {location}.

Personality traits: {traits}
Background: {background}
Current mood: {mood}
Current activity: {activity}

Relationships:
{relationships}

Recent memories:
{memories}

World context:
{world_context}

Guidelines:
- Stay in character at all times
- Reference your memories and relationships naturally
- React appropriately to your current mood
- Keep responses concise and conversational
"""

static func build_system_prompt(character: Dictionary, context: Dictionary) -> String:
    var prompt = SYSTEM_TEMPLATE
    
    prompt = prompt.replace("{name}", character.get("name", "Unknown"))
    prompt = prompt.replace("{role}", character.get("role", "character"))
    prompt = prompt.replace("{location}", context.get("location", "unknown location"))
    prompt = prompt.replace("{traits}", ", ".join(character.get("traits", [])))
    prompt = prompt.replace("{background}", character.get("background", ""))
    prompt = prompt.replace("{mood}", context.get("mood", "neutral"))
    prompt = prompt.replace("{activity}", context.get("activity", "idle"))
    prompt = prompt.replace("{relationships}", format_relationships(context.get("relationships", {})))
    prompt = prompt.replace("{memories}", format_memories(context.get("memories", [])))
    prompt = prompt.replace("{world_context}", context.get("world_context", ""))
    
    return prompt

static func format_relationships(relations: Dictionary) -> String:
    if relations.is_empty():
        return "No established relationships"
    
    var lines = []
    for name in relations:
        var score = relations[name]
        var status = get_relationship_status(score)
        lines.append("- %s: %s (score: %d)" % [name, status, score])
    
    return "\n".join(lines)

static func format_memories(memories: Array, limit: int = 5) -> String:
    if memories.is_empty():
        return "No recent memories"
    
    var lines = []
    for i in min(limit, memories.size()):
        var memory = memories[i]
        lines.append("- %s" % (memory.summary if "summary" in memory else memory.content))
    
    return "\n".join(lines)
```

### Conversation Builder

```gdscript
static func build_messages(system_prompt: String, conversation_history: Array, user_message: String) -> Array:
    var messages = []
    
    # System message
    messages.append({
        "role": "system",
        "content": system_prompt
    })
    
    # Conversation history (trimmed to fit context)
    var history_limit = 10  # Adjust based on model context window
    var start_idx = max(0, conversation_history.size() - history_limit)
    
    for i in range(start_idx, conversation_history.size()):
        var entry = conversation_history[i]
        messages.append({
            "role": entry.role,
            "content": entry.content
        })
    
    # Current user message
    messages.append({
        "role": "user",
        "content": user_message
    })
    
    return messages

static func estimate_tokens(messages: Array) -> int:
    # Rough estimation: ~4 characters per token
    var total_chars = 0
    for msg in messages:
        total_chars += msg.content.length()
    return total_chars / 4
```

## Error Handling

### Retry Logic

```gdscript
class_name RequestWithRetry
extends RefCounted

const MAX_RETRIES = 3
const RETRY_DELAYS = [1.0, 2.0, 5.0]  # Exponential backoff

var api_manager: APIManager
var retry_count: int = 0

func execute(messages: Array, options: Dictionary = {}) -> void:
    retry_count = 0
    _attempt_request(messages, options)

func _attempt_request(messages: Array, options: Dictionary) -> void:
    api_manager.send_message(messages, options)

func _on_request_failed(error: String) -> void:
    if _is_retryable_error(error) and retry_count < MAX_RETRIES:
        var delay = RETRY_DELAYS[retry_count]
        retry_count += 1
        push_warning("Retrying request in %s seconds (attempt %d/%d)" % [delay, retry_count, MAX_RETRIES])
        await api_manager.get_tree().create_timer(delay).timeout
        _attempt_request(_last_messages, _last_options)
    else:
        # Final failure
        emit_signal("failed", error)

func _is_retryable_error(error: String) -> bool:
    # Rate limiting (429) or server errors (5xx)
    return "429" in error or "500" in error or "502" in error or "503" in error
```

### Fallback Providers

```gdscript
func send_with_fallback(messages: Array, providers: Array[Provider] = []) -> void:
    if providers.is_empty():
        providers = [Provider.OPENAI, Provider.CLAUDE, Provider.DEEPSEEK]
    
    for provider in providers:
        if _validate_api_key(provider):
            current_provider = provider
            send_message(messages, {"provider": provider})
            return
    
    emit_signal("request_failed", "No configured providers available")
```

## Streaming Responses

### Stream Handler

```gdscript
# For providers that support streaming
func send_streaming(messages: Array, options: Dictionary = {}) -> void:
    var provider = options.get("provider", current_provider)
    var body = _build_request_body(provider, messages, options)
    body["stream"] = true
    
    # Use different approach for streaming
    var tcp = StreamPeerTCP.new()
    # ... streaming implementation
    
func _process_stream_chunk(chunk: String) -> void:
    # Parse Server-Sent Events format
    var lines = chunk.split("\n")
    for line in lines:
        if line.begins_with("data: "):
            var data_str = line.substr(6)
            if data_str == "[DONE]":
                emit_signal("stream_complete")
                return
            
            var json = JSON.new()
            if json.parse(data_str) == OK:
                var data = json.get_data()
                var content = _extract_streaming_content(data)
                if content:
                    emit_signal("response_chunk", content)
```

## Configuration Storage

### Secure Key Storage

```gdscript
const CONFIG_PATH = "user://api_config.enc"
const ENCRYPTION_KEY = "your-encryption-key"  # Should be derived from user input

func save_configuration() -> void:
    var data = {
        "provider": current_provider,
        "api_keys": api_keys,
        "models": selected_models
    }
    
    var json_str = JSON.stringify(data)
    
    # Simple encryption (use proper encryption in production)
    var encrypted = encrypt_string(json_str, ENCRYPTION_KEY)
    
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(encrypted)
        file.close()

func load_configuration() -> void:
    if not FileAccess.file_exists(CONFIG_PATH):
        return
    
    var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file:
        var encrypted = file.get_as_text()
        file.close()
        
        var json_str = decrypt_string(encrypted, ENCRYPTION_KEY)
        var json = JSON.new()
        if json.parse(json_str) == OK:
            var data = json.get_data()
            current_provider = data.get("provider", Provider.OPENAI)
            api_keys = data.get("api_keys", {})
            selected_models = data.get("models", {})
```

## Best Practices Summary

1. **Provider Abstraction**: Use unified interface for all providers
2. **Secure Keys**: Encrypt API keys at rest, never log them
3. **Rate Limiting**: Implement delays between requests to avoid throttling
4. **Error Recovery**: Use exponential backoff for retries
5. **Context Management**: Trim conversation history to fit model limits
6. **Fallback Chain**: Configure multiple providers for resilience
7. **Streaming**: Use streaming for better perceived responsiveness
8. **Logging**: Log request/response metadata (not content) for debugging

## Token Limits by Model

| Provider | Model | Context Window |
|----------|-------|----------------|
| OpenAI | GPT-4o | 128K |
| OpenAI | GPT-4-turbo | 128K |
| OpenAI | GPT-3.5-turbo | 16K |
| Claude | Claude 3.5 Sonnet | 200K |
| Claude | Claude 3 Opus | 200K |
| Gemini | Gemini 1.5 Pro | 1M |
| DeepSeek | DeepSeek-Chat | 32K |
| Kimi | Moonshot-v1-128k | 128K |

## References

- [Microverse GitHub Repository](https://github.com/KsanaDock/Microverse)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Anthropic Claude API](https://docs.anthropic.com/claude/reference)
- [Google Gemini API](https://ai.google.dev/docs)
- [DeepSeek API](https://platform.deepseek.com/docs)
