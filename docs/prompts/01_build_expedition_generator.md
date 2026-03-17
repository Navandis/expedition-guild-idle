# Prompt 01 - Build Expedition Generator

Context files to use:
- `game_overview.md`
- `current_milestone.md`
- `technical_decisions.md`
- `coding_standards.md`
- `content_schema.md`

Task:
Implement a data-driven `ExpeditionGenerator.gd` for Godot 4 using GDScript.

Requirements:
- Load content from JSON files for biomes, site types, states, reward profiles, and hazards.
- Generate 3 to 5 expedition dictionaries.
- Each generated expedition must contain:
  - `id`
  - `biome`
  - `site_type`
  - `state_modifier`
  - `reward_profile`
  - `hazard`
  - `duration_minutes`
  - `difficulty`
  - `risk_label`
  - `display_name`
  - `flavor_summary`
  - `base_success`
- Use a simple random selection approach for now.
- Use the display name format `{State} {Biome} {Site}`.
- Keep the code easy to extend later for weighted rules.

Constraints:
- GDScript only.
- No UI code in this file.
- Do not implement specialists, multiple teams, or advanced balance logic.
- Do not hardcode the full content pool inside the script except safe fallback defaults.

Deliverables:
- `scripts/systems/ExpeditionGenerator.gd`
- `scripts/models/Expedition.gd` only if genuinely useful
- sample JSON data files under `data/expeditions/` if they do not already exist

Acceptance criteria:
- Another script can call `generate_expeditions(count: int)` and receive valid expedition dictionaries.
- Missing or malformed JSON fails safely.
- Code is simple, readable, and milestone-scoped.
