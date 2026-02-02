# Microverse Memory Systems - Complete Implementation Guide

This document provides comprehensive patterns for implementing persistent memory systems in AI agents based on the Microverse project.

## Source

Based on [KsanaDock/Microverse](https://github.com/KsanaDock/Microverse) - Memory system enabling AI characters to remember conversations and develop relationships.

## Architecture Overview

```text
Memory System/
├── MemoryManager (Core Controller)
│   ├── MemoryStore (Per-Agent Storage)
│   ├── MemoryRetriever (Query Engine)
│   └── MemoryConsolidator (Summarization)
├── RelationshipTracker (Social Graph)
└── StorageBackend (JSON/Database)
```

## Memory Entry Format

### Standard Memory Structure

```gdscript
class_name MemoryEntry

var id: String
var timestamp: int
var category: String  # "conversation", "event", "observation"
var participants: Array[String]
var content: String
var summary: String
var importance: float  # 0.0 to 1.0
var location: String
var tags: Array[String]

func _init(data: Dictionary = {}) -> void:
    id = data.get("id", str(Time.get_unix_time_from_system()) + "_" + str(randi()))
    timestamp = data.get("timestamp", Time.get_unix_time_from_system())
    category = data.get("category", "conversation")
    participants = data.get("participants", [])
    content = data.get("content", "")
    summary = data.get("summary", "")
    importance = data.get("importance", 0.5)
    location = data.get("location", "unknown")
    tags = data.get("tags", [])

func to_dict() -> Dictionary:
    return {
        "id": id,
        "timestamp": timestamp,
        "category": category,
        "participants": participants,
        "content": content,
        "summary": summary,
        "importance": importance,
        "location": location,
        "tags": tags
    }
```

## Memory Manager

### Core Memory Manager Class

```gdscript
class_name MemoryManager

const MAX_MEMORIES_PER_AGENT = 1000
const MEMORY_SAVE_PATH = "user://memories/"

var agent_memories: Dictionary = {}  # agent_name -> Array[MemoryEntry]
var relationship_scores: Dictionary = {}  # "agent1_agent2" -> int

signal memory_added(agent: String, memory: MemoryEntry)
signal memory_retrieved(agent: String, memories: Array)
signal relationship_updated(agent1: String, agent2: String, score: int)

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(MEMORY_SAVE_PATH)
    load_all_memories()

func add_memory(agent: String, memory: MemoryEntry) -> void:
    if not agent in agent_memories:
        agent_memories[agent] = []
    
    agent_memories[agent].append(memory)
    
    # Enforce memory limit
    if agent_memories[agent].size() > MAX_MEMORIES_PER_AGENT:
        consolidate_old_memories(agent)
    
    emit_signal("memory_added", agent, memory)
    save_agent_memories(agent)

func get_memories(agent: String, count: int = 10, filter: Dictionary = {}) -> Array:
    if not agent in agent_memories:
        return []
    
    var memories = agent_memories[agent].duplicate()
    
    # Apply filters
    if "category" in filter:
        memories = memories.filter(func(m): return m.category == filter.category)
    
    if "participant" in filter:
        memories = memories.filter(func(m): return filter.participant in m.participants)
    
    if "min_importance" in filter:
        memories = memories.filter(func(m): return m.importance >= filter.min_importance)
    
    if "after_timestamp" in filter:
        memories = memories.filter(func(m): return m.timestamp > filter.after_timestamp)
    
    # Sort by recency and importance
    memories.sort_custom(func(a, b): 
        var score_a = a.timestamp * 0.3 + a.importance * 0.7 * 1000000000
        var score_b = b.timestamp * 0.3 + b.importance * 0.7 * 1000000000
        return score_a > score_b
    )
    
    emit_signal("memory_retrieved", agent, memories.slice(0, count))
    return memories.slice(0, count)
```

## Memory Retrieval Strategies

### Recent Memories

```gdscript
func get_recent_memories(agent: String, count: int = 5) -> Array:
    return get_memories(agent, count, {})

func get_memories_since(agent: String, hours_ago: int) -> Array:
    var cutoff = Time.get_unix_time_from_system() - (hours_ago * 3600)
    return get_memories(agent, 50, {"after_timestamp": cutoff})
```

### Contextual Search

```gdscript
func search_memories(agent: String, query: String, count: int = 5) -> Array:
    if not agent in agent_memories:
        return []
    
    var query_lower = query.to_lower()
    var scored_memories = []
    
    for memory in agent_memories[agent]:
        var score = 0.0
        var content_lower = memory.content.to_lower()
        
        # Keyword matching
        for word in query_lower.split(" "):
            if word.length() > 2 and word in content_lower:
                score += 0.2
        
        # Recency bonus
        var age_hours = (Time.get_unix_time_from_system() - memory.timestamp) / 3600.0
        score += max(0, (168 - age_hours) / 168.0) * 0.3  # Week recency
        
        # Importance bonus
        score += memory.importance * 0.3
        
        if score > 0:
            scored_memories.append({"memory": memory, "score": score})
    
    scored_memories.sort_custom(func(a, b): return a.score > b.score)
    return scored_memories.slice(0, count).map(func(m): return m.memory)
```

### Relationship-Based Retrieval

```gdscript
func get_memories_with_agent(agent: String, other_agent: String, count: int = 10) -> Array:
    return get_memories(agent, count, {"participant": other_agent})

func get_relationship_history(agent1: String, agent2: String) -> Dictionary:
    var memories = get_memories_with_agent(agent1, agent2, 20)
    var score = get_relationship_score(agent1, agent2)
    
    return {
        "current_score": score,
        "status": get_relationship_status(score),
        "interaction_count": memories.size(),
        "recent_interactions": memories.slice(0, 5)
    }
```

## Memory Consolidation

### Summarize Old Memories

```gdscript
func consolidate_old_memories(agent: String) -> void:
    var memories = agent_memories[agent]
    
    # Keep important recent memories
    var keep_threshold = Time.get_unix_time_from_system() - (7 * 24 * 3600)  # 1 week
    var recent = memories.filter(func(m): return m.timestamp > keep_threshold)
    var old = memories.filter(func(m): return m.timestamp <= keep_threshold)
    
    # Keep high-importance old memories
    var important_old = old.filter(func(m): return m.importance >= 0.7)
    
    # Summarize regular old memories by week
    var weekly_summaries = summarize_memories_by_week(old.filter(func(m): return m.importance < 0.7))
    
    agent_memories[agent] = recent + important_old + weekly_summaries

func summarize_memories_by_week(memories: Array) -> Array:
    var by_week: Dictionary = {}
    
    for memory in memories:
        var week_key = memory.timestamp / (7 * 24 * 3600)
        if not week_key in by_week:
            by_week[week_key] = []
        by_week[week_key].append(memory)
    
    var summaries = []
    for week_key in by_week:
        var week_memories = by_week[week_key]
        var summary = MemoryEntry.new({
            "category": "summary",
            "timestamp": week_memories[0].timestamp,
            "content": "Week summary: %d events recorded" % week_memories.size(),
            "summary": generate_week_summary(week_memories),
            "importance": 0.5,
            "tags": ["consolidated"]
        })
        summaries.append(summary)
    
    return summaries
```

## Relationship Tracking

### Relationship Score Management

```gdscript
const RELATIONSHIP_MIN = 0
const RELATIONSHIP_MAX = 100
const RELATIONSHIP_DEFAULT = 50

func get_relationship_key(agent1: String, agent2: String) -> String:
    var sorted = [agent1, agent2]
    sorted.sort()
    return "%s_%s" % sorted

func get_relationship_score(agent1: String, agent2: String) -> int:
    var key = get_relationship_key(agent1, agent2)
    return relationship_scores.get(key, RELATIONSHIP_DEFAULT)

func update_relationship(agent1: String, agent2: String, change: int) -> void:
    var key = get_relationship_key(agent1, agent2)
    var current = relationship_scores.get(key, RELATIONSHIP_DEFAULT)
    var new_score = clamp(current + change, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
    relationship_scores[key] = new_score
    
    emit_signal("relationship_updated", agent1, agent2, new_score)
    
    # Record significant relationship changes
    if abs(change) >= 5:
        record_relationship_event(agent1, agent2, change, new_score)

func get_relationship_status(score: int) -> String:
    if score >= 90: return "best friend"
    elif score >= 75: return "close friend"
    elif score >= 60: return "friend"
    elif score >= 45: return "acquaintance"
    elif score >= 30: return "neutral"
    elif score >= 15: return "unfriendly"
    else: return "hostile"
```

### Relationship Events

```gdscript
func record_relationship_event(agent1: String, agent2: String, change: int, new_score: int) -> void:
    var event_type = "improved" if change > 0 else "worsened"
    var memory = MemoryEntry.new({
        "category": "relationship",
        "participants": [agent1, agent2],
        "content": "Relationship %s by %d points (now %d)" % [event_type, abs(change), new_score],
        "importance": min(abs(change) / 20.0, 1.0),
        "tags": ["relationship", event_type]
    })
    
    add_memory(agent1, memory)
    add_memory(agent2, memory)
```

## Memory Injection for LLM

### Format Memories for Prompts

```gdscript
func format_memories_for_prompt(agent: String, context: Dictionary = {}) -> String:
    var formatted = ""
    
    # Recent general memories
    var recent = get_recent_memories(agent, 3)
    if recent.size() > 0:
        formatted += "Recent memories:\n"
        for memory in recent:
            formatted += "- [%s] %s\n" % [format_timestamp(memory.timestamp), memory.summary or memory.content]
    
    # Memories with current conversation partner
    if "other_agent" in context:
        var relationship_memories = get_memories_with_agent(agent, context.other_agent, 3)
        if relationship_memories.size() > 0:
            formatted += "\nPrevious interactions with %s:\n" % context.other_agent
            for memory in relationship_memories:
                formatted += "- %s\n" % (memory.summary or memory.content)
    
    # Important memories
    var important = get_memories(agent, 3, {"min_importance": 0.8})
    if important.size() > 0:
        formatted += "\nImportant memories:\n"
        for memory in important:
            formatted += "- %s\n" % (memory.summary or memory.content)
    
    return formatted

func format_timestamp(unix_time: int) -> String:
    var days_ago = (Time.get_unix_time_from_system() - unix_time) / (24 * 3600)
    if days_ago < 1:
        return "Today"
    elif days_ago < 2:
        return "Yesterday"
    elif days_ago < 7:
        return "%d days ago" % days_ago
    else:
        return "%d weeks ago" % (days_ago / 7)
```

## Persistence

### Save and Load Memories

```gdscript
func save_agent_memories(agent: String) -> void:
    var path = MEMORY_SAVE_PATH + agent + "_memories.json"
    var data = {
        "agent": agent,
        "memories": agent_memories.get(agent, []).map(func(m): return m.to_dict()),
        "saved_at": Time.get_unix_time_from_system()
    }
    
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "  "))
        file.close()

func load_agent_memories(agent: String) -> void:
    var path = MEMORY_SAVE_PATH + agent + "_memories.json"
    if not FileAccess.file_exists(path):
        agent_memories[agent] = []
        return
    
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            var data = json.get_data()
            agent_memories[agent] = data.memories.map(func(m): return MemoryEntry.new(m))
        file.close()

func save_relationships() -> void:
    var path = MEMORY_SAVE_PATH + "relationships.json"
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(relationship_scores, "  "))
        file.close()

func load_relationships() -> void:
    var path = MEMORY_SAVE_PATH + "relationships.json"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            relationship_scores = json.get_data()
        file.close()
```

## Best Practices Summary

1. **Structured Entries**: Always use consistent MemoryEntry format
2. **Importance Scoring**: Assign importance based on event significance
3. **Regular Consolidation**: Summarize old memories to prevent bloat
4. **Contextual Retrieval**: Use filters to get relevant memories
5. **Relationship Symmetry**: Keep relationship data consistent for both agents
6. **Async Saves**: Don't block gameplay on memory persistence
7. **Memory Limits**: Enforce per-agent memory limits
8. **Graceful Loading**: Handle missing or corrupted memory files

## References

- [Microverse GitHub Repository](https://github.com/KsanaDock/Microverse)
- [Generative Agents Paper](https://arxiv.org/abs/2304.03442)
- [Godot FileAccess Documentation](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)
