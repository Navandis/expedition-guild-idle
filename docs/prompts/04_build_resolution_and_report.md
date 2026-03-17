# Prompt 04 - Build Resolution and Report

Context files to use:
- `game_overview.md`
- `current_milestone.md`
- `technical_decisions.md`
- `coding_standards.md`
- `content_schema.md`

Task:
Implement expedition completion, reward resolution, and the report UI.

Requirements:
- When an active expedition completes, generate an expedition outcome.
- Support three outcome states:
  - success
  - partial_success
  - failure
- Rewards should include some combination of:
  - gold
  - relic_fragments
  - codex_entries
- Add a report screen or popup that displays:
  - expedition display name
  - outcome label
  - rewards gained
  - one short summary string
- Add a Collect button.
- Collecting rewards should update player state and clear the pending report.
- A report cannot be collected twice.

Constraints:
- Keep reward formulas simple and readable.
- Do not add crafting, item inventories, or detailed injury systems.
- No animation requirements.

Deliverables:
- `scripts/systems/RewardSystem.gd`
- updates to `ExpeditionManager.gd` if needed
- `scenes/report/ExpeditionReport.tscn`
- `scripts/ui/ReportController.gd`

Acceptance criteria:
- A completed expedition produces a report.
- The report shows outcome and rewards clearly.
- Collecting updates resources once and only once.
