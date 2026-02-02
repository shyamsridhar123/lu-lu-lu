````skill
---
name: microverse-godot-practices
description: GDScript best practices for Godot 4 game development from the Microverse project. Use when writing Godot scripts, organizing project structure, or implementing game systems. Triggers on tasks involving GDScript, Godot scenes, game mechanics, or Godot project architecture.
license: MIT
metadata:
  author: KsanaDock
  version: "1.0.0"
  source: https://github.com/KsanaDock/Microverse
---

# Microverse Godot Practices

Comprehensive GDScript and Godot 4 best practices from the Microverse project, covering code style, project organization, and common game development patterns.

## When to Apply

Reference these guidelines when:
- Writing GDScript code for Godot 4
- Organizing Godot project structure
- Implementing game systems and mechanics
- Creating reusable components
- Building UI systems in Godot

## Project Organization

### Directory Structure
```
project/
├── asset/          # Game assets
│   ├── fonts/      # Font files
│   ├── pics/       # Images and sprites
│   └── sounds/     # Audio files
├── scene/          # Godot scenes
│   ├── characters/ # Character scenes
│   ├── maps/       # Map/level scenes
│   └── ui/         # UI scenes
├── script/         # GDScript files
│   ├── ai/         # AI-related scripts
│   └── ui/         # UI-related scripts
└── docs/           # Documentation
```

## GDScript Conventions

| Convention | Example | Priority |
|------------|---------|----------|
| Variables: snake_case | `my_variable` | CRITICAL |
| Constants: UPPER_CASE | `MAX_HEALTH` | CRITICAL |
| Classes: PascalCase | `CharacterManager` | CRITICAL |
| Functions: snake_case | `calculate_damage()` | CRITICAL |
| Signals: snake_case | `health_changed` | HIGH |

## Quick Reference

### Code Style
- Use Tab indentation (Godot default)
- Max 100 characters per line
- One blank line between functions
- Document public functions

### Signal Patterns
- Prefer signals over direct method calls
- Use signals for loose coupling
- Name signals as past-tense events

### Exports and Metadata
- Use @export for inspector variables
- Use set_meta/get_meta for dynamic data
- Provide sensible defaults

### Resource Management
- Preload frequently used resources
- Load heavy resources asynchronously
- Clear references when not needed

## Best Practices

1. **Separation of Concerns**: Keep scripts focused on single responsibility
2. **Scene Composition**: Build complex scenes from reusable subscenes
3. **Signal-Driven**: Use signals for communication between nodes
4. **Defensive Coding**: Check for null before accessing properties
5. **Consistent Naming**: Follow GDScript naming conventions

## Full Documentation

For the complete implementation guide: `AGENTS.md`

````
