# Hall of Ventures - Supply Runs Foundation v1 Milestone

## Purpose
Introduce the first dedicated **supply-generation loop** as a short-to-medium-duration operational activity while preserving the existing foundations already built for:
- regions
- expeditions
- Codex / discovery
- save/load
- debug tools
- Commission Runtime Loop v1
- Guild Hall operations tabs and card grammar
- shared Crew / Supplies runtime state

This milestone should establish the first playable Supply Runs loop, not the final logistics model, the hall/facilities layer, typed supplies, or a broad economy rebalance.

---

## Goal
Extend the current game so the player can:
- inspect a finite board of visible Supply Run offers
- receive Supply Runs only from currently unlocked / serviceable regions
- dispatch a Supply Run immediately if they have enough Crew, enough Gold where required, and an open active Supply Run slot
- convert the accepted offer into an active timed Supply Run rather than an instant reward
- see active and completed Supply Runs from Guild Hall in a dedicated third operations tab
- tap an empty Supply Run card to open the Supply Board
- tap a completed Supply Run card to collect Supplies through a compact claim flow
- use Supply Runs as the first real source of Supplies rather than relying on commissions, shops, or passive buildings

The outcome should feel like a real provisioning loop that complements Commissions and Expeditions without turning into either "Commissions that pay supplies" or "Expeditions but shorter."

---

## Design intent
This milestone should establish the following truths in code and data:

- **Supply Runs are the first dedicated source of Supplies.**
- **Supply Runs are a provisioning / procurement lane, not a patron-contract lane.**
- **Supply Runs are time-based runtime work, not instant-resolution rewards.**
- **Supply Run board offers and active Supply Run slots are separate concepts.**
- **Dispatch still happens immediately on acceptance; there is no accepted-but-unlaunched backlog.**
- **Board refill happens on dispatch, not on claim.**
- **Supply Runs can consume Crew, time, and sometimes Gold. They do not consume Supplies.**
- **Supply Runs primarily return Supplies, not Gold.**
- **Guild Hall becomes the runtime status-and-entry surface for Supply Runs as well.**
- **The Supply Board remains the offer-and-dispatch surface for this new activity.**
- **This milestone does not introduce buildings / facilities or passive production.**
- **This milestone does not introduce typed supplies or a deeper logistics simulation.**

---


## Implementation locks for this v1 slice
These are explicit working assumptions for Supply Runs Foundation v1 so Codex does not have to invent them during implementation:

- **Initial active Supply Run slot cap starts at 2.**
- **The starting slot-cap value should be introduced into and sourced from `new_game_start_conditions.json`.**
- **That starting cap is only a v1 starting point.** It should be treated as progression-owned state that can later be increased through systems such as Research, Rank bonuses, or similar progression sources.
- **Initial Supply Run payout targets a provisional working band of 10-20 Supplies per run.** This is a starter implementation number, not a balance-locked long-term economy value.
- **The final Supply payout should be pre-rolled at dispatch and stored on the runtime row / completion payload.** This keeps claim, save/load, and offline completion handling explicit and safe.
- **`CommissionResolver` should remain named as-is for this milestone.** Reuse the current shared Crew / Supplies owner where practical, but do not widen this milestone into a naming cleanup or broader orchestration refactor unless required for correctness.

---

## Core locked design rules

### 1. Immediate dispatch remains locked
Accepting a Supply Run means dispatching it immediately.
There is still no accepted-but-unlaunched backlog.

### 2. Supplies are not spent to make supplies
Supply Runs must not consume Supplies to generate Supplies.
They may consume Crew, time, and in some cases Gold, but not the output resource itself.

### 3. Supply Runs are not commissions without patrons
Supply Runs should not use patron framing, patron standing, or commission-style social identity.
They are internal provisioning operations performed by the guild.

### 4. Supply Runs should have their own active slot capacity
Supply Runs should not occupy the same active slot lane as exploratory Expeditions.
They are their own operational track and should be modeled explicitly as such.

### 5. Board refill remains tied to dispatch
When a Supply Run is accepted and dispatched, the emptied board slot should refill immediately.
Claim timing should not control board replenishment.

### 6. No gold payout from Supply Runs
Supply Runs are primarily a Supplies-returning loop.
They should not become a second gold faucet.

### 7. Crew handling should stay lighter than commissions in v1
Supply Runs are intended to be lower-stakes logistical activity.
For v1, committed crew should generally return directly to Available on completion rather than entering a full recovery burden model.
Deeper nuance can come later.

### 8. Supply Runs should remain operational, not exploratory
They can be region-aware and region-flavored, but they should not be framed as the main discovery / Codex advancement lane.

### 9. No facilities solution in this milestone
This milestone must not solve the supplies economy through buildings, hall grounds, or passive production.

### 10. Working implementation label is acceptable
`Supply Runs` is an acceptable working milestone label even if the final fiction-facing name changes later.

---

## Required authored system scope

### A. Add a first authored Supply Runs data foundation
Add authored data for the first Supply Runs board and offer generation under a dedicated data location.
The exact file structure can be simple, but it should support:
- board rules
- offer generation scaffolding
- region eligibility
- run-method or run-family identity
- basic duration / Crew / Gold / Supplies-yield data

### B. First Supply Run methods / families
The first milestone should support at least a small, clear set of distinct supply-side offer types.
A good v1 starting shape is:
- **Forage / Gathering** - Crew + time, low stakes, no gold cost
- **Procurement / Trade** - Crew + time + some gold cost, more reliable supplies return
- **Salvage / Recovery** - Crew + time, slightly riskier / swingier supply yield

Exact naming may vary, but the activity types should stay operational and provisioning-oriented.

### C. Reachable-world generation
Supply Run offers must be generated only from the player's currently unlocked / serviceable regions.

### D. Visible board
The board should start as a finite visible set, consistent with the project's current board-driven patterns.
A visible count of **3 offers** is acceptable for v1.

### E. Offer shape
Generated Supply Run offers should carry the fields needed for runtime play, such as where relevant:
- `offer_id`
- region identity and player-facing title
- run method / family
- duration
- Crew requirement
- Gold cost if any
- estimated or scaffolded Supplies yield, using a provisional v1 working target of roughly 10-20 Supplies per run
- any minimal note / risk text needed for readability

### F. Keep schema changes narrow
Do not overbuild authored data.
This milestone needs a usable board and runtime loop, not a huge logistics schema.

---

## Required runtime/player-state scope

### A. Active Supply Run runtime state
Implement a persisted / serializable runtime-state owner for live Supply Runs containing, at minimum:
- active dispatched Supply Runs
- ready-to-claim completed Supply Runs
- supporting metadata needed for safe completion and claim

### B. Supply Run slot-capacity state
Introduce or wire a real runtime concurrency limit for active Supply Runs.
For this milestone, the initial active Supply Run slot cap should start at **2** and should be sourced from `new_game_start_conditions.json`.
This should be progression-owned state, not a UI-only constant.

### C. Dispatch integration
Dispatching a Supply Run should:
- validate slot availability
- validate Crew availability
- validate Gold availability if the run has a gold cost
- commit Crew immediately
- spend Gold immediately when relevant
- create a timed active Supply Run entry
- remove the accepted offer from the visible board
- refill the emptied board slot immediately

### D. Completion processing
When an active Supply Run finishes:
- mark it complete / ready to claim
- free its active slot
- return committed Crew to Available under the current v1 abstraction
- preserve the stored pre-rolled Supplies payout needed for later claim

### E. Claim processing
Claiming a completed Supply Run should:
- grant Supplies
- clear the claimable entry afterward
- update Guild Hall state cleanly

### F. Save/load plus offline-safe timer handling
Active and ready-to-claim Supply Run state should persist correctly through save/load.
If enough real time passes while the game is closed, active Supply Runs should process into completed / claimable state correctly on load or revisit.

### G. Debug compatibility
Existing debug/testing practices should remain usable.
Add only small targeted debug support if needed.

---

## UI/interaction intent for this milestone
Guild Hall should continue to act as the runtime status hub.
The Supply Board should become the offer / dispatch surface for Supply Runs.

### Guild Hall should gain a third operations tab
The current operations TabContainer should gain:
- Expeditions
- Commissions
- Supply Runs

This should be implemented as a targeted extension of the existing Guild Hall operations structure, not as a full redesign.

### The Supply Runs tab should mirror the existing card grammar
The Supply Runs tab should use a horizontal scrolling carousel with cards that follow the same broad pattern already used by Expeditions and Commissions:
- placeholder image area
- title
- compact status text
- whole card acts as the button

### Supply Run card states should be:
- **Empty / idle slot**
  - state text: Tap to Open Supply Board
  - tap behavior: open Supply Board
- **In progress**
  - state text: In progress plus remaining time
  - tap behavior: inactive or no-op while running
- **Complete**
  - state text: Complete plus Collect Supplies
  - tap behavior: compact claim flow (direct claim is acceptable in v1)

### Supply Board should remain dispatch-focused
The player should still inspect and launch Supply Run offers from a dedicated screen / surface rather than from Guild Hall directly.
Guild Hall is the status-and-entry surface, not the deep offer-review surface.

### Placeholder implementation is acceptable
Readable scene-authored placeholder cards are acceptable.
Do not overbuild a dynamic card factory system solely for future expansion.

---

## Scope

### In scope
- authored Supply Runs data foundation
- finite Supply Board generation from unlocked regions
- real Supply Run runtime state
- real Supply Run slot-capacity usage
- dispatch-to-active-Supply-Run conversion
- board refill on dispatch
- active countdown / timer behavior
- completion-to-claimable-state behavior
- Guild Hall third operations tab for Supply Runs
- Supply Runs carousel cards in Guild Hall
- save/load persistence for active and claimable Supply Runs
- basic offline-safe completion processing
- targeted debug / test support if needed
- comments / documentation updates in touched files

### Out of scope
- buildings / facilities / hall grounds implementation
- passive building production
- typed Supplies expansion
- deep logistics model
- full crew injury / infirmary redesign
- deeper commission suitability / region-knowledge systems
- broad economy rebalance across the whole game
- final UI polish / art direction pass
- full renaming / fiction pass if `Supply Runs` later changes name

---

## Engineering / architecture guardrails
- Keep authored content separate from runtime/player-owned state.
- Preserve the "extend the working foundation, do not rebuild" principle.
- Reuse existing card / board / runtime/save patterns where they are structurally useful.
- Keep Supply Board offers, shared operational resources, and active Supply Run runtime rows separated where practical.
- Reuse the existing shared Crew / Supplies runtime owner for this milestone.
- Do not rename `CommissionResolver` during this milestone unless a correctness issue makes a narrow change unavoidable.
- Prefer a small explicit runtime-state owner for Supply Runs rather than burying timed logic inside the Supply Board screen controller.
- Keep visible UI scene-authored where practical.
- Keep implementation explicit and beginner-maintainable.
- Avoid speculative abstractions.

---

## Deliverables
- authored Supply Runs data foundation
- Supply Board generation and refill behavior
- Supply Run runtime-state owner
- dispatch integration and active slot validation
- Guild Hall Supply Runs tab and carousel
- completion and claim handling
- save/load and offline-safe processing for Supply Runs
- targeted debug support if needed
- comments/documentation updates

---

## Acceptance criteria
- A finite Supply Board exists and generates offers only from unlocked / serviceable regions
- Accepting a Supply Run no longer grants instant reward; it creates a timed active run instead
- Dispatch requires enough Crew, any required Gold, and an open active Supply Run slot
- Supply Runs do not consume Supplies on dispatch
- Board refill still happens on dispatch
- Completed Supply Runs become ready to claim rather than paying instantly
- Guild Hall contains a third operations tab for Supply Runs
- Empty Supply Run cards can open the Supply Board
- In-progress Supply Run cards show remaining time clearly
- Completed Supply Run cards can be tapped to collect Supplies through a compact flow
- The runtime loop survives save/load and offline elapsed time correctly
- The implementation remains simple, explicit, and maintainable
