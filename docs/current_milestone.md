# Current Milestone — Day 2

## Milestone Name
Single Playable Expedition Loop

## Goal
Turn the prototype from a board-only interaction slice into the first complete playable loop:

Home -> Expedition Board -> Dispatch -> Active Timer -> Completion -> Report -> Collect Rewards -> Return Home

This milestone is successful when a player can launch the project, dispatch one expedition, wait for it to complete, collect rewards once, and repeat the loop cleanly.

---

## Current Repo State
Already working:
- Godot project and repo structure are set up
- Expedition content is loaded from JSON
- 3–5 expedition cards are generated and displayed
- The player can select an expedition
- Dispatch action is wired at a basic level
- Console output confirms dispatch requests

Not yet implemented:
- Home / Guild Hall landing screen
- Active expedition state and timer
- Real dispatch confirmation flow
- Expedition completion resolution
- Expedition report UI
- Reward collection and visible resource updates

---

## In Scope
Build the minimum systems and UI needed for one real expedition loop.

### Systems in scope
- minimal runtime player state
- one active expedition maximum
- dispatch confirmation flow
- expedition timer / completion tracking
- simple expedition outcome resolution
- simple reward generation
- pending expedition report state
- single-collect reward handling

### UI in scope
- Home / Guild Hall screen
- navigation from Home to Expedition Board
- Dispatch confirmation screen or modal
- Active expedition status display
- Expedition report screen or popup
- Updated resource display on Home

### Runtime state in scope
- gold
- relic_fragments
- codex_entries
- active_expedition
- pending_report

---

## Explicitly Out of Scope
Do not implement any of the following during this milestone:

- save/load
- offline progress / catch-up
- upgrades
- codex screen
- discovery set bonuses
- specialists
- multiple simultaneous expeditions
- prestige
- contracts
- events
- inventory systems
- backend / online systems
- polish animations
- large refactors unless required for correctness

---

## Design Constraints
- Godot 4
- GDScript only
- UI-heavy, mobile-friendly, simple layout
- Keep implementation readable and milestone-scoped
- Prefer plain data structures or lightweight models
- No speculative architecture
- No unnecessary abstraction layers
- Do not reorganize the repo structure

---

## Day-2 Deliverables
By the end of this milestone, the prototype should include:

1. A Home / Guild Hall screen
2. Navigation to and from the Expedition Board
3. A dispatch confirmation flow
4. One active expedition tracked in runtime state
5. A visible remaining-time display on Home
6. Completion of the expedition into a pending report
7. A report screen with:
   - expedition name
   - outcome
   - rewards
   - short summary
8. A Collect button that applies rewards exactly once
9. Updated visible resource totals on Home
10. Clean repeatability of the loop

---

## Acceptance Criteria
This milestone is complete when all of the following are true:

- The game boots into a Home / Guild Hall screen
- The player can open the Expedition Board from Home
- The player can select an expedition and confirm dispatch
- Only one expedition can be active at a time
- The Home screen shows the active expedition and remaining time
- When the timer finishes, a report becomes available
- The player can open the report and collect rewards
- Rewards update visible resource totals
- Rewards cannot be collected twice
- After collection, the player returns to a clean state and can dispatch again

---

## Build Priorities
Implement in this order:

1. Home / Guild Hall shell and navigation
2. Dispatch confirmation flow
3. Active expedition state and timer
4. Completion logic
5. Report UI
6. Reward collection and resource update
7. Edge-case cleanup

---

## Notes for Codex
- Build only what is required for this milestone
- Keep each script focused on one responsibility
- Avoid introducing future systems early
- Keep UI and logic separate
- Choose the simplest correct implementation when ambiguous
