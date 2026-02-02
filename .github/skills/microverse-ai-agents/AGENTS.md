# Microverse AI Agents - Complete Implementation Guide

This document provides comprehensive patterns for building multi-agent AI social simulations based on the Microverse project architecture.

## Source

Based on [KsanaDock/Microverse](https://github.com/KsanaDock/Microverse) - A god-simulation sandbox game with multi-agent AI social simulation.

## Architecture Overview

```text
Agent System/
├── CharacterBody2D (Base Agent)
│   ├── State Machine
│   ├── Memory Integration
│   ├── Dialogue Handler
│   └── Task Executor
├── DialogManager (Conversation Flow)
├── MemoryManager (Long-term Storage)
├── TaskManager (Task Coordination)
└── APIManager (LLM Integration)
```

## Agent Design Patterns

### 1. Character State Machine

Agents should operate through clearly defined behavioral states:

```gdscript
enum AgentState {
    IDLE,
    WALKING,
    TALKING,
    WORKING,
    RESTING
}

var current_state: AgentState = AgentState.IDLE

func update_state(new_state: AgentState) -> void:
    if current_state != new_state:
        exit_state(current_state)
        current_state = new_state
        enter_state(new_state)
        emit_signal("state_changed", new_state)
```

### 2. Metadata-Based Agent Properties

Store agent attributes as node metadata for flexible access:

```gdscript
# Setting agent properties
character.set_meta("money", 1000)
character.set_meta("mood", "happy")
character.set_meta("health", "good")
character.set_meta("memories", [])
character.set_meta("relations", {})

# Retrieving with defaults
var money = character.get_meta("money", 0)
var mood = character.get_meta("mood", "neutral")
```

### 3. Personality System

Define distinct personality traits for each agent:

```gdscript
var personality: Dictionary = {
    "name": "Alice",
    "role": "Project Manager",
    "traits": ["friendly", "organized", "patient"],
    "goals": ["complete projects on time", "maintain team morale"],
    "constraints": ["prefers morning meetings", "avoids conflict"],
    "background": "Five years of experience in tech management..."
}
```

### 4. Dialogue Prompt Construction

Build rich context for LLM interactions:

```gdscript
func build_dialogue_prompt(character: CharacterBody2D, user_input: String) -> String:
    var prompt = ""
    
    # Character identity
    prompt += "You are %s, a %s.\n" % [personality.name, personality.role]
    prompt += "Personality: %s\n" % ", ".join(personality.traits)
    
    # Current context
    prompt += "\nCurrent Location: %s\n" % get_current_room()
    prompt += "Current Mood: %s\n" % character.get_meta("mood")
    
    # Relationship context
    prompt += "\nRelationships:\n%s\n" % format_relationships(character)
    
    # Recent memories
    prompt += "\nRecent Memories:\n%s\n" % get_recent_memories(character, 5)
    
    # Conversation history
    prompt += "\nConversation:\n%s\n" % format_history()
    
    prompt += "\nUser: %s\nYou: " % user_input
    
    return prompt
```

### 5. Scene Perception

Implement environmental awareness:

```gdscript
# Room area detection
extends Area2D

@export var room_name: String = "Unknown Room"
@export var room_desc: String = "A room in the building"

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("agents"):
        body.set_meta("current_room", room_name)
        body.set_meta("room_description", room_desc)
        emit_signal("agent_entered", body, room_name)
```

### 6. Relationship Tracking

Manage social connections between agents:

```gdscript
func update_relationship(agent1: String, agent2: String, change: int) -> void:
    var relations = agent1_node.get_meta("relations", {})
    var current = relations.get(agent2, 50)  # Default neutral
    relations[agent2] = clamp(current + change, 0, 100)
    agent1_node.set_meta("relations", relations)
    
func get_relationship_status(value: int) -> String:
    if value >= 80: return "close friend"
    elif value >= 60: return "friend"
    elif value >= 40: return "acquaintance"
    elif value >= 20: return "stranger"
    else: return "unfriendly"
```

### 7. Autonomous Task Execution

Enable agents to manage tasks independently:

```gdscript
class_name AgentTask

var id: String
var title: String
var priority: int
var assigned_to: String
var status: String  # "pending", "in_progress", "completed"
var created_at: int
var completed_at: int = -1

func execute(agent: CharacterBody2D) -> bool:
    status = "in_progress"
    # Task-specific logic here
    return true
    
func complete() -> void:
    status = "completed"
    completed_at = Time.get_unix_time_from_system()
```

### 8. Agent Communication Protocol

Handle inter-agent conversations:

```gdscript
signal conversation_started(initiator, target)
signal message_sent(from_agent, to_agent, message)
signal conversation_ended(agents)

func start_conversation(initiator: CharacterBody2D, target: CharacterBody2D) -> void:
    # Set both agents to talking state
    initiator.set_state(AgentState.TALKING)
    target.set_state(AgentState.TALKING)
    
    # Create conversation context
    var context = ConversationContext.new(initiator, target)
    active_conversations[context.id] = context
    
    emit_signal("conversation_started", initiator, target)
```

## Multi-Agent Coordination

### Interaction Cooldowns

Prevent agents from overwhelming each other:

```gdscript
var interaction_cooldowns: Dictionary = {}
const COOLDOWN_DURATION = 30.0  # seconds

func can_interact(agent1: String, agent2: String) -> bool:
    var key = get_interaction_key(agent1, agent2)
    if key in interaction_cooldowns:
        return Time.get_unix_time_from_system() > interaction_cooldowns[key]
    return true

func record_interaction(agent1: String, agent2: String) -> void:
    var key = get_interaction_key(agent1, agent2)
    interaction_cooldowns[key] = Time.get_unix_time_from_system() + COOLDOWN_DURATION
```

### Group Discussions

Handle multi-agent conversations:

```gdscript
func create_group_discussion(participants: Array[CharacterBody2D], topic: String) -> void:
    var context = GroupContext.new(participants, topic)
    
    for agent in participants:
        agent.set_state(AgentState.TALKING)
        agent.set_meta("current_discussion", context.id)
    
    # Determine speaking order based on personality
    context.speaking_order = determine_speaking_order(participants)
```

## State Persistence

### Save Agent State

```gdscript
func save_agent_state(agent: CharacterBody2D) -> Dictionary:
    return {
        "name": agent.get_meta("name"),
        "position": {"x": agent.position.x, "y": agent.position.y},
        "state": agent.current_state,
        "mood": agent.get_meta("mood"),
        "health": agent.get_meta("health"),
        "money": agent.get_meta("money"),
        "memories": agent.get_meta("memories"),
        "relations": agent.get_meta("relations"),
        "current_task": agent.get_meta("current_task", null)
    }

func load_agent_state(agent: CharacterBody2D, data: Dictionary) -> void:
    agent.position = Vector2(data.position.x, data.position.y)
    agent.current_state = data.state
    for key in ["mood", "health", "money", "memories", "relations"]:
        agent.set_meta(key, data[key])
```

## Best Practices Summary

1. **Separation of Concerns**: Keep state, dialogue, memory, and task systems modular
2. **Signal-Driven Events**: Use Godot signals for loose coupling between systems
3. **Graceful Degradation**: Handle API failures without crashing agent behavior
4. **Context Limits**: Trim conversation history and memories to fit LLM context windows
5. **Async Operations**: Use async patterns for API calls to maintain responsiveness
6. **Logging**: Implement comprehensive logging for debugging agent decisions
7. **Testing**: Create mock LLM responses for consistent testing

## References

- [Stanford AI Town Paper](https://arxiv.org/abs/2304.03442)
- [Microverse GitHub Repository](https://github.com/KsanaDock/Microverse)
- [Godot Engine Documentation](https://docs.godotengine.org/)
