# Microverse Godot Practices - Complete Implementation Guide

This document provides comprehensive GDScript and Godot 4 best practices from the Microverse project.

## Source

Based on [KsanaDock/Microverse](https://github.com/KsanaDock/Microverse) - A Godot 4 game with extensive AI and UI systems.

## Project Structure

### Recommended Directory Layout

```text
microverse/
├── asset/                  # All game assets
│   ├── fonts/             # Font files (.ttf, .otf)
│   ├── pics/              # Images, sprites, textures
│   ├── sounds/            # Audio files
│   └── ui/                # UI-specific assets
├── scene/                  # Godot scene files (.tscn)
│   ├── characters/        # Character scenes
│   ├── maps/              # Level/map scenes
│   ├── ui/                # UI component scenes
│   └── common/            # Shared/reusable scenes
├── script/                 # GDScript files (.gd)
│   ├── ai/                # AI-related scripts
│   │   ├── background_story/  # Story system
│   │   └── memory/            # Memory system
│   ├── ui/                # UI scripts
│   ├── managers/          # Singleton managers
│   └── utils/             # Utility scripts
├── docs/                   # Documentation
└── project.godot          # Project configuration
```

## GDScript Coding Conventions

### Naming Conventions

```gdscript
# Constants - UPPER_CASE
const MAX_HEALTH = 100
const DEFAULT_SPEED = 200.0
const API_ENDPOINT = "https://api.example.com"

# Variables - snake_case
var current_health: int = MAX_HEALTH
var player_speed: float = DEFAULT_SPEED
var is_moving: bool = false

# Class names - PascalCase
class_name CharacterManager
class_name DialogService
class_name MemoryEntry

# Functions - snake_case
func calculate_damage(attacker: Node, defender: Node) -> int:
    pass

func get_current_room() -> String:
    pass

# Private functions - prefix with underscore
func _internal_calculation() -> void:
    pass

# Signals - snake_case, past tense
signal health_changed(new_health: int)
signal dialog_started(speaker: String)
signal task_completed(task_id: String)
```

### Type Hints

Always use type hints for clarity and IDE support:

```gdscript
# Variables
var player_name: String = ""
var health: int = 100
var position_offset: Vector2 = Vector2.ZERO
var items: Array[Item] = []
var stats: Dictionary = {}

# Function parameters and returns
func take_damage(amount: int, source: Node = null) -> void:
    health -= amount
    emit_signal("health_changed", health)

func get_nearby_characters(radius: float) -> Array[CharacterBody2D]:
    var result: Array[CharacterBody2D] = []
    # ... implementation
    return result

# Optional parameters with defaults
func speak(message: String, volume: float = 1.0, delay: float = 0.0) -> void:
    pass
```

### Comments and Documentation

```gdscript
## CharacterManager handles all AI character behaviors and interactions.
## 
## This manager is responsible for:
## - Character state management
## - Movement and pathfinding
## - Inter-character communication
class_name CharacterManager
extends Node

## Maximum number of characters allowed in a scene
const MAX_CHARACTERS = 20

## Emitted when a character changes state
signal state_changed(character: CharacterBody2D, new_state: int)

## List of all active characters
var characters: Array[CharacterBody2D] = []

## Registers a new character with the manager
## [br][br]
## [param character] The character to register
## [param initial_state] Optional initial state (defaults to IDLE)
func register_character(character: CharacterBody2D, initial_state: int = 0) -> void:
    # Add character to tracking list
    characters.append(character)
    
    # Set up signals
    character.connect("died", _on_character_died)
```

## Common Patterns

### Singleton/Autoload Pattern

```gdscript
# In project.godot, add as autoload: GameManager -> res://script/managers/game_manager.gd

class_name GameManager
extends Node

static var instance: GameManager

var game_state: String = "menu"
var current_map: String = ""

func _ready() -> void:
    instance = self

func change_state(new_state: String) -> void:
    game_state = new_state
    emit_signal("state_changed", new_state)
```

### Node Metadata Pattern

Use metadata for flexible data storage on nodes:

```gdscript
# Setting data
character.set_meta("money", 1000)
character.set_meta("mood", "happy")
character.set_meta("memories", [])
character.set_meta("relations", {"Alice": 75, "Bob": 50})

# Getting data with defaults
var money: int = character.get_meta("money", 0)
var mood: String = character.get_meta("mood", "neutral")
var memories: Array = character.get_meta("memories", [])

# Checking if metadata exists
if character.has_meta("custom_data"):
    var data = character.get_meta("custom_data")

# Removing metadata
character.remove_meta("temporary_flag")
```

### Signal Patterns

```gdscript
# Defining signals
signal dialog_started(speaker: String, listener: String)
signal dialog_message(speaker: String, message: String)
signal dialog_ended(speaker: String, listener: String)

# Connecting signals - preferred method
func _ready() -> void:
    # Lambda connection (Godot 4 style)
    button.pressed.connect(_on_button_pressed)
    
    # With additional arguments
    button.pressed.connect(func(): _handle_button(button.name))
    
    # One-shot connection
    animation_player.animation_finished.connect(_on_animation_done, CONNECT_ONE_SHOT)

# Emitting signals
func start_dialog(speaker: Node, listener: Node) -> void:
    emit_signal("dialog_started", speaker.name, listener.name)
    # or Godot 4 style:
    dialog_started.emit(speaker.name, listener.name)

# Disconnecting when needed
func _exit_tree() -> void:
    if button.pressed.is_connected(_on_button_pressed):
        button.pressed.disconnect(_on_button_pressed)
```

### Area Detection Pattern

```gdscript
# RoomArea.gd - Detects when characters enter rooms
extends Area2D

@export var room_name: String = "Unknown Room"
@export var room_desc: String = "A room in the building"

signal character_entered(character: CharacterBody2D, room: String)
signal character_exited(character: CharacterBody2D, room: String)

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
    if body is CharacterBody2D and body.is_in_group("characters"):
        body.set_meta("current_room", room_name)
        body.set_meta("room_description", room_desc)
        character_entered.emit(body, room_name)

func _on_body_exited(body: Node2D) -> void:
    if body is CharacterBody2D and body.is_in_group("characters"):
        character_exited.emit(body, room_name)
```

### Async HTTP Requests

```gdscript
class_name APIManager
extends Node

var http_request: HTTPRequest

func _ready() -> void:
    http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_request_completed)

func make_api_call(endpoint: String, data: Dictionary) -> void:
    var headers = ["Content-Type: application/json"]
    var body = JSON.stringify(data)
    var error = http_request.request(endpoint, headers, HTTPClient.METHOD_POST, body)
    
    if error != OK:
        push_error("HTTP request failed: %s" % error)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        var json = JSON.new()
        if json.parse(body.get_string_from_utf8()) == OK:
            var response = json.get_data()
            emit_signal("api_response_received", response)
    else:
        push_error("API request failed with code: %s" % response_code)
```

### Resource Preloading

```gdscript
# Preload for frequently used resources
const CharacterScene = preload("res://scene/characters/character.tscn")
const DialogFont = preload("res://asset/fonts/dialog.ttf")
const ButtonClickSound = preload("res://asset/sounds/click.wav")

# Load for dynamic resources
func load_map(map_name: String) -> void:
    var map_path = "res://scene/maps/%s.tscn" % map_name
    if ResourceLoader.exists(map_path):
        var map_scene = load(map_path)
        var map_instance = map_scene.instantiate()
        add_child(map_instance)
```

### State Machine Pattern

```gdscript
class_name CharacterStateMachine
extends Node

enum State { IDLE, WALKING, TALKING, WORKING, RESTING }

@export var initial_state: State = State.IDLE

var current_state: State
var previous_state: State

signal state_changed(from_state: State, to_state: State)

func _ready() -> void:
    current_state = initial_state
    previous_state = initial_state

func change_state(new_state: State) -> void:
    if current_state == new_state:
        return
    
    previous_state = current_state
    _exit_state(current_state)
    current_state = new_state
    _enter_state(new_state)
    state_changed.emit(previous_state, new_state)

func _enter_state(state: State) -> void:
    match state:
        State.IDLE:
            _start_idle()
        State.WALKING:
            _start_walking()
        State.TALKING:
            _start_talking()
        # ... etc

func _exit_state(state: State) -> void:
    match state:
        State.TALKING:
            _end_conversation()
        # ... cleanup for other states
```

## UI Best Practices

### Control Node Organization

```gdscript
# DialogBubble.gd
extends Control

@onready var speaker_label: Label = $VBox/SpeakerLabel
@onready var message_label: RichTextLabel = $VBox/MessageLabel
@onready var background: Panel = $Background
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    hide()

func show_message(speaker: String, message: String) -> void:
    speaker_label.text = speaker
    message_label.text = ""
    show()
    animation_player.play("fade_in")
    
    # Typewriter effect
    for char in message:
        message_label.text += char
        await get_tree().create_timer(0.03).timeout

func close() -> void:
    animation_player.play("fade_out")
    await animation_player.animation_finished
    hide()
```

### Theme and Styling

```gdscript
# Apply consistent styling
func setup_theme() -> void:
    var theme = Theme.new()
    
    # Font settings
    var font = preload("res://asset/fonts/main.ttf")
    theme.set_font("font", "Label", font)
    theme.set_font_size("font_size", "Label", 16)
    
    # Button styling
    var button_style = StyleBoxFlat.new()
    button_style.bg_color = Color("#2d2d2d")
    button_style.corner_radius_top_left = 4
    button_style.corner_radius_top_right = 4
    button_style.corner_radius_bottom_left = 4
    button_style.corner_radius_bottom_right = 4
    theme.set_stylebox("normal", "Button", button_style)
    
    get_tree().root.theme = theme
```

## Error Handling

### Defensive Coding

```gdscript
func get_character_status(character: CharacterBody2D) -> String:
    # Null check
    if not character:
        push_warning("Character is null")
        return "Status unavailable"
    
    # Safe metadata access with defaults
    var mood = character.get_meta("mood", "unknown")
    var health = character.get_meta("health", "unknown")
    
    return "Mood: %s, Health: %s" % [mood, health]

func find_character_by_name(name: String) -> CharacterBody2D:
    var characters = get_tree().get_nodes_in_group("characters")
    for character in characters:
        if character.has_meta("name") and character.get_meta("name") == name:
            return character
    
    push_warning("Character not found: %s" % name)
    return null
```

### JSON Parsing

```gdscript
func parse_json_safely(json_string: String) -> Variant:
    var json = JSON.new()
    var error = json.parse(json_string)
    
    if error != OK:
        push_error("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
        return null
    
    return json.get_data()

func save_data_to_file(path: String, data: Dictionary) -> bool:
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to open file for writing: %s (Error: %s)" % [path, FileAccess.get_open_error()])
        return false
    
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    return true
```

## Performance Tips

### Object Pooling

```gdscript
class_name ObjectPool
extends Node

var pool: Array[Node] = []
var scene: PackedScene
var pool_size: int

func _init(scene_path: String, size: int = 10) -> void:
    scene = load(scene_path)
    pool_size = size

func _ready() -> void:
    for i in pool_size:
        var instance = scene.instantiate()
        instance.hide()
        add_child(instance)
        pool.append(instance)

func get_instance() -> Node:
    for instance in pool:
        if not instance.visible:
            instance.show()
            return instance
    
    # Pool exhausted, create new
    var instance = scene.instantiate()
    add_child(instance)
    pool.append(instance)
    return instance

func return_instance(instance: Node) -> void:
    instance.hide()
```

### Frame-Distributed Processing

```gdscript
# Spread heavy work across frames
func process_all_characters() -> void:
    var characters = get_tree().get_nodes_in_group("characters")
    var batch_size = 5
    var current_index = 0
    
    while current_index < characters.size():
        var batch_end = min(current_index + batch_size, characters.size())
        for i in range(current_index, batch_end):
            process_character(characters[i])
        
        current_index = batch_end
        await get_tree().process_frame  # Yield to next frame
```

## Best Practices Summary

1. **Use Type Hints**: Always specify types for variables, parameters, and returns
2. **Follow Naming Conventions**: snake_case for variables/functions, PascalCase for classes
3. **Signal-Driven Architecture**: Use signals for loose coupling between components
4. **Null Safety**: Always check for null before accessing node properties
5. **Resource Management**: Preload common resources, load dynamic ones asynchronously
6. **Documentation**: Comment complex logic and document public APIs
7. **Error Handling**: Use push_error/push_warning for debugging, handle edge cases
8. **Scene Composition**: Build from reusable, focused subscenes

## References

- [Microverse GitHub Repository](https://github.com/KsanaDock/Microverse)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Godot Engine Documentation](https://docs.godotengine.org/)
