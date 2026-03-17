# Prompt 05 - Build Upgrades, Codex, and Save Layer

Context files to use:
- `game_overview.md`
- `current_milestone.md`
- `technical_decisions.md`
- `coding_standards.md`
- `content_schema.md`

Task:
Implement the remaining v0.1 progression layer: guild upgrades, codex tracking, and a basic save/load system.

Requirements:
- Add at least 3 guild upgrades loaded from JSON.
- The player can purchase upgrades with gold.
- Upgrade effects should apply to future expeditions where relevant.
- Add a simple Codex / Discoveries screen.
- Track discovered expedition entries using a minimal rule, for example first-time discovery of a display-name combination or site-type combination.
- Add a basic save/load system that preserves:
  - resources
  - purchased upgrades
  - codex discoveries
  - active expedition state
  - pending report state if practical

Constraints:
- Keep the codex logic intentionally simple.
- Keep save/load as plain JSON.
- Do not add prestige, specialists, or deep collection set logic.
- Do not refactor unrelated systems unless required for correctness.

Deliverables:
- `scripts/systems/UpgradeSystem.gd`
- `scripts/systems/CodexSystem.gd`
- `scripts/core/SaveManager.gd`
- `scenes/upgrades/GuildUpgrades.tscn`
- `scripts/ui/UpgradesController.gd`
- `scenes/codex/CodexScreen.tscn`
- `scripts/ui/CodexController.gd`
- `data/upgrades/guild_upgrades.json`

Acceptance criteria:
- The player can buy a visible upgrade.
- Codex progress updates after expeditions.
- Closing and reopening the game restores state correctly enough for prototype use.
