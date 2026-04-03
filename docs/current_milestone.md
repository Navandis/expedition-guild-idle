# Hall of Ventures — Commission Runtime Loop v1 Milestone

## Purpose
Convert the current Commission Foundation slice from **immediate resolution on acceptance** into a **live timed operational loop** while preserving the existing foundations already built for:
- regions
- expeditions
- Codex/discovery
- save/load
- debug tools
- Commission generation and board flow
- Crew/Supplies runtime state

This milestone should establish the first playable runtime Commission loop, not the final version of supply procurement, patron depth, officer specialization, or UI polish.

---

## Goal
Extend the current Commission system so the player can:
- inspect a finite board of visible Commission offers
- dispatch a Commission immediately if they have enough Crew, Supplies, and an open active Commission slot
- convert the accepted offer into an active timed Commission rather than an instant payout
- see active and completed Commissions from Guild Hall in the same broad card/carousel language already used for Expeditions
- switch between Expedition and Commission runtime views through a shared Guild Hall TabContainer
- tap an empty Commission slot card to open the Commission Board
- tap a completed Commission card to collect reward through a compact claim flow
- experience Crew burden over time through Assigned and Recovering states
- keep the board replenishing and operational while active work runs in parallel

The outcome should feel like a real live gold loop that complements Expeditions without collapsing into "Expeditions but shorter."

---

## Design intent
This milestone should establish the following truths in code and data:

- **Commissions are the primary live gold-generation loop.**
- **Commission runtime is time-based, not instant-resolution.**
- **Board offers and active Commission slots are separate concepts.**
- **Dispatch still happens immediately on acceptance; there is no accepted-but-unlaunched backlog.**
- **Board refill happens on dispatch, not on claim.**
- **Commission completion frees operational capacity before payout is claimed.**
- **Guild Hall becomes the runtime status-and-entry surface for Commissions.**
- **Commission Board remains the offer-and-dispatch surface.**
- **Commission cards in Guild Hall should intentionally reuse the Expedition card pattern where practical.**
- **Existing Crew/Supplies and outcome scaffolding should be reused where practical rather than replaced.**
- **This milestone does not solve the Supplies-source question.**
- **This milestone does not introduce buildings/facilities or passive production systems.**

---

## Core locked design rules

### 1. Immediate dispatch remains locked
Accepting a Commission still means dispatching it immediately.
There is still no accepted-but-unlaunched contract inventory.

### 2. Active slot availability matters
A Commission can only be dispatched if the player has:
- enough Crew
- enough Supplies
- an open active Commission slot

### 3. Board offers and active slots stay distinct
The visible board is an offer surface.
Active Commission slots are a concurrency limit.

These may numerically match in v1, but they should remain conceptually separate in code and UI.

### 4. Board refill remains tied to dispatch
When a Commission is accepted and dispatched, the emptied board slot should refill immediately.
Claim timing should not control board replenishment.

### 5. No instant gold payout
Dispatching a Commission should no longer pay gold immediately.
Gold is only collected after the timed Commission finishes and the result is claimed.

### 6. Completion frees the slot before claim
When a Commission timer completes:
- its active slot should free up
- the finished Commission should move into a ready-to-claim state
- committed Crew should leave Assigned and move into Recovering under the current v1 abstraction

### 7. Claim flow should stay compact and card-driven
Completed Commissions should be claimable from Guild Hall through the Commission card state.
Do not turn this into a full Expedition-style report experience.

### 8. Existing outcome philosophy remains valid
Excellent / Solid / Strained / Poor remains the correct v1 outcome structure.
This milestone should reuse that foundation rather than redesign it.

### 9. Commission runtime should stay operational, not exploratory
Do not add authored-discovery framing, Codex collection beats, or expedition-like narrative wrappers to the Commission completion flow.

### 10. No supply-source solution in this milestone
Commissions continue to consume Supplies.
Where Supplies come from remains a separate later milestone.

---

## Required authored system scope

### A. Preserve existing Commission authored content
Continue using the current Commission authored-data foundation under `res://data/commissions/`.
This milestone is primarily a runtime/state/UI milestone, not a broad authored-content expansion milestone.

### B. Preserve runtime-needed authored fields
Generated Commission offers should continue to carry the fields needed to support runtime play, including where relevant:
- `offer_id`
- patron/family/region display identity
- risk/duration data
- Crew/Supplies requirements
- reward scaffold data
- outcome-related inputs already used by the current system

### C. Keep schema changes minimal
If a small authored-data adjustment is genuinely needed to support runtime clarity, keep it targeted and avoid broad schema redesign.

---

## Required runtime/player-state scope

### A. Active Commission runtime state
Implement a persisted/serializable runtime-state owner for live Commissions containing, at minimum:
- active dispatched Commissions
- ready-to-claim completed Commissions
- whatever small supporting metadata is necessary for safe processing

This state should not be buried inside the board UI controller.

### B. Commission slot-capacity activation
Make existing Commission slot capacity matter as a real runtime concurrency limit for active Commissions.

### C. Dispatch integration
Dispatching a Commission should:
- validate slot availability
- validate Crew and Supplies availability
- commit Crew and Supplies immediately
- create a timed active Commission entry
- remove the accepted offer from the visible board
- refill the emptied board slot immediately

### D. Completion processing
When an active Commission finishes:
- mark it complete / ready to claim
- free its active slot
- move committed Crew out of Assigned and into Recovering according to the current Crew model
- preserve any reward/outcome data needed for later claim

### E. Claim processing
Claiming a completed Commission should:
- grant gold payout
- grant any existing side reward support already in the Commission system
- apply any payout-facing standing or reward effects already modeled
- remove the completed entry from the ready-to-claim state

### F. Save/load plus offline-safe timer handling
Active and ready-to-claim Commission state should persist correctly through save/load.
If enough real time passes while the game is closed, active Commissions should process into completed/claimable state correctly on load or revisit.

### G. Debug compatibility
Existing debug/testing practices should remain usable.
Add small targeted debug support for active Commissions if needed, but do not build a giant debug subsystem.

---

## UI/interaction intent for this milestone
Guild Hall should become the runtime status hub for the player's ongoing operations.
Commission Board should remain the surface for reviewing and dispatching offers.

### Guild Hall should gain an operations TabContainer
The current Expedition carousel and the new Commission carousel should be placed inside a shared TabContainer so the player can switch views cleanly.

The immediate tabs for this milestone are:
- Expeditions
- Commissions

This should be implemented as a targeted structural UI change, not as a full Guild Hall redesign.

### The Expedition view should keep its existing broad behavior
The current Expedition cards should remain recognizable and continue to work.
This milestone should restructure their container placement only as much as needed to fit the new TabContainer cleanly.

### The Commission view should mirror the Expedition card grammar
The Commission tab should use a horizontal scrolling carousel with cards that follow the same broad pattern the Expedition cards already use:
- placeholder image area
- title
- compact state label
- whole card acts as the button

### The Commission card states should be:
- **Empty / idle slot**
  - state text: Tap to Open Commission Board
  - tap behavior: open Commission Board
- **In progress**
  - state text: In progress plus time remaining
  - tap behavior: inactive or no-op while running
- **Complete**
  - state text: Complete plus Collect Reward
  - tap behavior: claim reward directly through the compact Commission claim flow

### Placeholder implementation is acceptable
For this milestone, readable scene-authored placeholder cards are acceptable.
A small scene-authored set of three Commission cards is acceptable if that is the simplest explicit implementation for the current default slot capacity.
Do not overbuild a dynamic card-factory system only for future expansion.

### Commission Board remains dispatch-focused
The Board should still let the player:
- inspect visible offers
- choose a prep tier
- dispatch immediately if requirements and slots allow
- understand why dispatch is blocked when it fails

The Board does not need to become the main ongoing-status monitor.

---

## Scope

### In scope
- active Commission runtime state
- real Commission slot-capacity usage
- dispatch-to-active-Commission conversion
- board refill on dispatch
- active countdown/timer behavior
- completion-to-claimable-state behavior
- compact claim handling
- targeted Guild Hall restructure to introduce the operations TabContainer
- Commission carousel in Guild Hall
- keeping the Expedition carousel working inside that shared TabContainer
- save/load persistence for active and claimable Commission state
- basic offline-safe completion processing
- targeted debug/test support if needed
- comments/documentation updates in touched files

### Out of scope
- supply procurement / supply-source system
- typed Supplies expansion
- buildings / facilities / hall grounds implementation
- passive building production
- deep patron reputation ladders
- deep officer system expansion
- Commission suitability / knowledge deepening beyond existing scaffold
- event/special Commission layer
- final UI polish / art direction pass
- broad rebalance across the whole game
- redesign of the Expedition loop beyond the targeted TabContainer integration

---

## Engineering / architecture guardrails
- Keep authored content separate from runtime/player-owned state.
- Preserve the "extend the working foundation, do not rebuild" principle.
- Reuse existing Commission generation, Crew/Supplies, and outcome-resolution foundations where practical.
- Keep board state, operational-resource state, and active-runtime state separated where practical.
- Prefer a small explicit runtime-state owner over burying timed Commission logic inside `CommissionBoardScreenController.gd`.
- Borrow timer/save/load patterns from the Expedition side only where they are structurally useful.
- Reuse the existing Guild Hall card/carousel interaction pattern where practical instead of inventing a second home-screen runtime grammar.
- Keep Guild Hall as a status/entry surface and Commission Board as an offer/dispatch surface.
- Prefer scene-authored UI plus script-driven data binding for any new visible UI.
- Keep implementation explicit and beginner-maintainable.
- Avoid speculative abstractions.

---

## Deliverables
- Commission runtime-state owner for active and claimable Commissions
- dispatch integration from board offer to active timed Commission
- completion and claim handling
- save/load and offline-safe processing for runtime Commissions
- Guild Hall operations TabContainer with Expedition and Commission views
- Commission carousel cards in Guild Hall with status-based behavior
- Commission Board updates needed to stay aligned with the new runtime model
- targeted debug support if needed
- comments/documentation updates

---

## Acceptance criteria
- Accepting a Commission no longer resolves it immediately
- Accepting a Commission creates a timed active Commission instead
- Dispatch requires enough Crew, Supplies, and an open active Commission slot
- Board refill still happens on dispatch
- Completed Commissions become ready to claim rather than paying instantly
- Guild Hall contains a TabContainer that lets the player switch between Expeditions and Commissions
- The Expedition view continues to function after being moved into that shared TabContainer
- The Commission view shows a readable horizontal carousel of Commission cards
- Empty Commission cards can open the Commission Board
- In-progress Commission cards show remaining time clearly
- Completed Commission cards can be tapped to collect reward through a compact flow
- The runtime loop survives save/load and offline elapsed time correctly
- The implementation remains simple, explicit, and maintainable
