# Prompt 03 - Build Dispatch and Active Expedition Flow

Context files to use:
- `game_overview.md`
- `current_milestone.md`
- `technical_decisions.md`
- `coding_standards.md`
- `content_schema.md`

Task:
Implement the dispatch flow and active expedition tracking.

Requirements:
- The player can confirm dispatch of one selected expedition.
- Track one active expedition for v0.1.
- Store enough information to show:
  - expedition display name
  - end time or remaining time
  - current status
- Add a simple Guild Hall or Home screen that shows current resources and the active expedition timer.
- The dispatch action should make the expedition active and remove the need to keep it on the board.

Constraints:
- Single active expedition is acceptable and preferred for this milestone.
- Keep timing logic simple.
- No specialist system.
- No multiple simultaneous expeditions.
- No premature save/load complexity unless it is cheap.

Deliverables:
- `scripts/systems/ExpeditionManager.gd`
- `scenes/guild_hall/GuildHall.tscn`
- `scripts/ui/GuildHallController.gd`
- `scenes/dispatch/DispatchScreen.tscn` or a dispatch modal if that is faster
- `scripts/ui/DispatchController.gd`

Acceptance criteria:
- A selected expedition can be dispatched.
- The active expedition appears on the home/guild hall screen.
- Remaining time is visible and updates.
