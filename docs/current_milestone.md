# Current Milestone — Multi-Slot Expeditions

## Milestone Name
Two-Slot Expedition Flow

## Goal
Expand the prototype from a single active expedition into a small multi-slot version of the core loop.

This milestone is successful when the player can:
- run up to 2 expeditions at the same time
- see both slots clearly from the Home / Guild Hall screen
- dispatch new expeditions while another slot is already active
- handle multiple completed expeditions safely through pending reports
- save/load this multi-slot state correctly

This milestone is intended to improve the feel of the loop without widening the game design.

---

## Current Repo State
Already working:
- expedition generation and expedition board
- dispatch confirmation flow
- expedition completion and reports
- reward collection
- resources
- upgrades
- codex/discoveries
- save/load persistence
- debug reset and debug complete tools

Current limitation:
- only one expedition can be active at a time
- one pending report blocks further dispatch

---

## In Scope

### Systems in scope
- support exactly 2 active expedition slots
- replace single active expedition state with a 2-slot structure
- replace single pending report state with a queue or list of pending reports
- keep expedition completion logic per slot
- keep reward collection one-time and safe
- preserve existing upgrade effects, codex discovery recording, and save/load behavior

### UI in scope
- Home / Guild Hall must show 2 expedition slots clearly
- each slot should show:
  - empty / active / completed state
  - expedition name when occupied
  - remaining time when active
- pending reports should be visible as a count or list
- opening reports should work cleanly when multiple reports exist
- Expedition Board should allow dispatch while at least one slot is free
- Dispatch flow should clearly explain when all slots are full

### Save data in scope
- 2 active expedition slots
- pending reports queue/list
- all current resource / upgrade / codex state

---

## Explicitly Out of Scope
Do not implement any of the following during this milestone:

- more than 2 expedition slots
- specialist assignment per slot
- team composition
- slot-specific upgrades
- report comparison screen
- bulk collect all reports
- offline catch-up redesign
- prestige
- contracts
- events
- inventory systems
- deeper codex mechanics
- refactoring unrelated systems unless required for correctness

---

## Design Constraints
- Godot 4
- GDScript only
- keep implementation simple and readable
- prefer explicit data structures over clever abstractions
- preserve current screen flow where possible
- do not redesign the prototype around party/team systems yet
- keep this milestone focused on “2 concurrent expeditions” only

---

## Core Design Decisions
To keep complexity low, use these rules:

1. The prototype supports exactly 2 expedition slots.
2. Dispatch should use the first available free slot automatically.
3. If both slots are full, dispatch is blocked with clear messaging.
4. Completed expeditions should create pending reports in a queue/list.
5. Reports should be opened and collected one at a time.
6. Reward collection remains one-time only.
7. Debug tools should continue to work with the new multi-slot model.

---

## Code Clarity / Internal Comments Requirement
For every new or updated script in this milestone:

- add a short file header comment at the top describing:
  - what the script is responsible for
  - how it fits into the multi-slot flow
- add inline comments where helpful to explain:
  - slot assignment
  - slot completion
  - pending report queue handling
  - save/load restore behavior for multiple slots
  - how debug-complete behavior works with multiple active slots
- write comments for a novice engineer
- keep comments useful and concise; do not comment every trivial line

For scenes:
- use clear node names
- keep hierarchy straightforward
- put explanatory comments in controller scripts where scene behavior needs explanation

---

## Build Order
Implement in this order:

1. runtime data model for 2 active slots + report queue
2. Home / Guild Hall UI updates
3. dispatch flow updates
4. report queue handling
5. save/load updates
6. debug-tool compatibility
7. edge-case cleanup

---

## Deliverables
By the end of this milestone, the prototype should include:

1. support for exactly 2 simultaneous active expeditions
2. a Home / Guild Hall screen that clearly shows both slots
3. dispatch flow that fills the first free slot automatically
4. blocked dispatch messaging when all slots are occupied
5. pending reports handled through a queue/list
6. one-at-a-time report viewing and collection
7. save/load support for 2 active slots and multiple pending reports
8. compatibility with existing upgrades, codex, and debug tools

---

## Acceptance Criteria
This milestone is complete when all of the following are true:

- The player can dispatch an expedition into slot 1
- The player can dispatch a second expedition while slot 1 is still active
- The player cannot dispatch a third expedition
- The Home screen clearly shows both slot states
- Completed expeditions generate pending reports without breaking other active slots
- Multiple pending reports can be opened and collected safely, one at a time
- Reward collection still works once and only once
- Save/load restores the 2-slot runtime state safely
- Debug finish/reset tools still function correctly
- New and updated scripts contain beginner-friendly comments

---

## Notes for Codex
- Build only what is required for this milestone
- Keep the implementation explicit and prototype-friendly
- Prefer a small queue/list model over a large manager hierarchy
- Do not introduce team/party systems yet
- Do not widen the design beyond 2 concurrent expeditions
