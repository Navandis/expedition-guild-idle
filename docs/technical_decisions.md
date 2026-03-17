# Technical Decisions

## Engine and Language
- Engine: Godot 4
- Language: GDScript
- Target: mobile-first UI, but desktop play during development is acceptable

## General Architecture
- Data-driven content using JSON files stored under `data/`
- Separate game logic from UI logic
- Separate content data from balancing data where practical
- Prefer simple composition over inheritance-heavy architecture
- Prefer lightweight dictionaries or small model classes over large object graphs

## Recommended Project Structure
- `scripts/core/` for global state and save/load
- `scripts/systems/` for game logic systems
- `scripts/models/` for data containers if needed
- `scripts/ui/` for screen controllers
- `scenes/` for UI scenes and reusable components
- `data/` for JSON content and balancing files

## Core Systems for MVP
- `GameManager.gd` - own player state, navigation entry points, and system wiring
- `ExpeditionGenerator.gd` - generate expedition opportunities from JSON content
- `ExpeditionManager.gd` - dispatch, track, and resolve expeditions
- `RewardSystem.gd` - calculate and grant rewards
- `UpgradeSystem.gd` - load and apply guild upgrades
- `CodexSystem.gd` - track discovered expedition entries / sets
- `SaveManager.gd` - serialize player state (optional but strongly preferred)

## Content Loading
- Use local JSON files loaded at runtime.
- The generator should not hardcode the full content pool in script.
- Reasonable fallback defaults are acceptable for stability during early development.

## UI Constraints
- UI should be readable with placeholder styling.
- Avoid elaborate visual components in v0.1.
- Prefer reusable components for expedition cards and resource bars.
- The dispatch flow can be a modal if that is faster than a full screen.

## Time Model
- Use a simple timer model first.
- If real wall-clock persistence is easy, use Unix timestamps for expedition end times.
- If not, simulate completion with short development timers in the first pass.

## Save Data
Prefer a simple JSON save file containing:
- resources
- purchased upgrades
- active expedition state
- codex progress
- current expedition board if persistence is needed

## Build Philosophy
- Build the current milestone only.
- Avoid speculative architecture for future systems.
- Optimize for readability, iteration speed, and easy AI assistance.
