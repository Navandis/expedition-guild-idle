# Current Milestone — Day 3

## Milestone Name
Light Progression + Persistence Layer

## Goal
Extend the working expedition loop with the first lightweight progression systems and a basic persistence layer.

This milestone is successful when the player can:
- complete expeditions and earn resources
- spend gold on visible guild upgrades
- see simple discovery progress in a Codex screen
- close and reopen the game without losing core prototype progress

This milestone should deepen the current loop without widening the project scope.

---

## Current Repo State
Already working:
- main screen flow and runtime screen hosting
- expedition board generation and selection
- dispatch confirmation flow
- one active expedition at a time
- expedition completion and report generation
- reward collection
- visible runtime resource totals

Not yet implemented:
- purchasable guild upgrades
- codex / discovery tracking
- save/load persistence across game restarts

---

## In Scope

### Systems in scope
- JSON-driven guild upgrades
- visible upgrade purchasing with gold
- applying simple upgrade effects to future expeditions where relevant
- codex tracking for completed discoveries using a deliberately simple rule
- codex screen for viewing discoveries
- basic save/load using plain JSON
- restoring prototype state on restart

### UI in scope
- Guild Upgrades screen
- Codex / Discoveries screen
- basic buttons/navigation from Home to Upgrades and Codex
- simple save/load integration that does not require a dedicated save UI

### Save data in scope
- resources
- purchased upgrades
- codex discoveries
- active expedition state
- pending report state if practical

---

## Explicitly Out of Scope
Do not implement any of the following during this milestone:

- prestige
- specialists
- multiple simultaneous expeditions
- deep collection set bonuses
- artifact crafting or item inventories
- offline progress / catch-up
- migration/versioning beyond a simple safe prototype approach
- backend / online systems
- monetization
- polish animations
- broad architecture refactors unless required for correctness

---

## Design Constraints
- Godot 4
- GDScript only
- keep implementation simple, readable, and prototype-friendly
- use plain JSON for content and save data
- keep upgrade effects intentionally small and understandable
- codex discovery logic should be intentionally simple
- no speculative architecture
- do not reorganize the repo structure

---

## Code Clarity / Internal Comments Requirement
For every new or updated script in this milestone:

- add a short file header comment at the top describing:
  - what the script is responsible for
  - how it fits into the current day-3 flow
- add inline comments where helpful to explain:
  - upgrade loading and application flow
  - codex discovery recording flow
  - save/load flow
  - any key state transitions or edge-case handling
- write comments for a novice engineer
- keep comments useful and concise; do not comment every trivial line

For scenes:
- use clear node names
- keep hierarchy straightforward
- put explanatory comments in the controller scripts where scene behavior needs explanation

---

## Build Order
Implement in this order:

1. Guild upgrades
2. Codex / discoveries
3. Save/load

Do not start save/load before upgrades and codex are stable enough to persist.

---

## Day-3 Deliverables
By the end of this milestone, the prototype should include:

1. A JSON file for guild upgrades
2. An UpgradeSystem that loads upgrades and applies simple effects
3. A Guild Upgrades screen with visible purchasable upgrades
4. A CodexSystem that records simple discoveries
5. A Codex screen that displays discovery progress
6. A SaveManager that saves and loads prototype state using plain JSON
7. Startup restore of saved state
8. Reasonable preservation of:
   - resources
   - purchased upgrades
   - codex progress
   - active expedition
   - pending report (if practical)

---

## Acceptance Criteria
This milestone is complete when all of the following are true:

- The player can open an Upgrades screen
- The player can purchase at least 3 visible upgrades with gold
- Purchased upgrades affect future expedition behavior where relevant
- The player can open a Codex screen
- Completed expeditions add discoverable entries using a simple rule
- Codex progress is visible and updates correctly
- Closing and reopening the project restores core prototype state well enough for continued testing
- New and updated scripts contain beginner-friendly comments

---

## Notes for Codex
- Build only what is required for this milestone
- Prefer simple and explicit implementations over clever abstractions
- Keep upgrade math modest and easy to inspect
- Keep codex logic intentionally shallow for v0.1
- Keep save/load plain and prototype-safe