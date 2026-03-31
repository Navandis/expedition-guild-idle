# Hall of Ventures — Commission Foundation Milestone

## Purpose
Introduce the first playable Commission loop as the game’s primary gold-generation and short/medium-duration operational layer, while preserving the existing foundations already built for:
- regions
- expeditions
- Codex/discovery
- save/load
- debug tools
- screen-based flow

This milestone should establish a working Commission system foundation, not the final version of the economy, UI polish, patron progression, or faction depth.

---

## Goal
Add a Commission Board and the underlying authored/runtime systems so the player can:
- see a finite set of procedurally generated commission offers
- receive offers only from currently unlocked/reachable regions
- inspect offers that vary by patron, family, objective, and risk/reward profile
- immediately dispatch a commission when accepted
- consume operational inputs (Crew and Supplies), not direct gold dispatch cost
- receive graded outcomes, gold rewards, and board replenishment on completion

The outcome should feel like a real second major loop that complements Expeditions rather than replacing them.

---

## Design intent
This milestone should establish the following truths in code and data:

- **Commissions are the primary gold-generation loop.**
- **Expeditions remain the investment/discovery/knowledge/supplies loop.**
- **Commission offers are generated only from the player’s currently reachable world.**
- **Commissions are procedural but authored, just like Expeditions.**
- **The board is finite, curated, and replenishing, not an endless feed.**
- **Accepting a commission means immediate dispatch and immediate commitment of resources.**
- **Commissions consume operational resources (Crew, Supplies, prep quality), not direct gold dispatch cost.**
- **Commission results are graded outcomes, not primarily hard failures.**
- **UI should stay utilitarian and readable for now; final visual polish comes later.**

---

## Core locked design rules
### 1. Reachable-world generation
Commission offers must be generated only from the player’s currently unlocked/reachable regions.

### 2. Procedural board
Commission offers are randomly generated, but only inside authored rules and content pools.

### 3. Finite visible board
Visible offers begin at **3**, expandable later by progression.

### 4. Immediate dispatch on acceptance
There is no “accepted quest backlog.”
Accepting a commission means dispatching immediately and committing the required resources immediately.

### 5. Board replenishment
When one commission is accepted, the board should generate one new commission to refill the visible slot.

### 6. Variety rules
The board should attempt soft curation:
- family spread
- risk spread
- patron spread
- region spread where possible
- avoid duplicate-heavy boards when alternatives exist

### 7. Non-expiring standard offers
Standard commissions persist until accepted or refreshed.
Event/special commissions may expire later, but that is out of scope for this milestone.

### 8. Player influence is soft, not deterministic
Later systems may bias board weights, but the player should not directly choose exact outcomes.

### 9. Commission economy
Commissions do **not** charge direct gold dispatch costs.
Their operational inputs are:
- Crew
- Supplies
- preparation tier
- officer/knowledge suitability where applicable

### 10. Soft outcomes
Commission completion should resolve through graded outcomes:
- Excellent
- Solid
- Strained
- Poor

These should mainly affect payout, standing, recovery burden, and side rewards rather than hard binary failure.

---

## Required authored system scope

### A. Patron tiers and pools
Implement authored data scaffolding for the first patron tiers and pools:

- Tier 1: Local Patrons
- Tier 2: Organized Institutions
- Tier 3: Regional Powers
- Tier 4: Sovereign / Grand Factions

The system does not need all tiers fully content-complete in the first pass, but the model should support them cleanly.

### B. First 4 commission families
Implement authored support for:
- Retrieval
- Escort
- Survey
- Security

### C. Board generation rules
Implement authored/scaffolded rules for:
- visible offer count
- family spread
- risk spread
- patron spread
- region spread
- refill behavior
- reroll behavior scaffold

### D. Objective templates
Implement the first wave of commission objective templates across the 4 families.

### E. Requirement tags
Implement first-pass requirement tag support for:
- officer tags
- mission suitability tags
- environmental/prep tags
- region knowledge tags

### F. Operational Inputs
Support first-pass operational input requirements:
- Crew Required
- Supplies Required
- prep tier adjustments

### G. Outcome profile rules
Support the first outcome profile rules:
- Excellent
- Solid
- Strained
- Poor

---

## Required runtime/player-state scope

### A. Commission Board state
The player should have a persisted/serializable board state containing:
- current visible offers
- reroll-related state scaffold if needed
- last seen/generated offer identity where needed for persistence

### B. Crew state
Implement first-pass Crew resource state:
- Max Crew
- Available Crew
- Assigned Crew
- Recovering Crew

Crew recovery should continue over time and should be compatible with offline progression logic.
If full offline recovery is not implemented in this milestone, the data/state structure should still support it cleanly.

### C. Supplies state
Use one actual v1 supply resource:
- Supplies

Do not split into typed supply categories in this milestone.

### D. Commission progression state
Persist whatever minimum commission-related state is needed for:
- current board
- last selected/inspected offer if needed
- future patron/reputation hooks
- future unlock expansion

Do not overbuild this.

---

## UI/interaction intent for this milestone
The Commission Board should be functional and readable, but does **not** need final art or final information architecture.

The player should be able to:
- open the Commission Board
- inspect 3 visible offers
- understand the main offer properties
- open a commission detail view
- choose a prep tier using a pre-built selector (not raw input fields)
- dispatch immediately on acceptance
- see the offer slot refill afterward

### Important UI lock
Prep tier should be presented through a **pre-built selector** (for example a horizontal 3-step selector), not manual numerical entry for crew/supplies.

### Important item lock
Rare/special items are **not** part of per-dispatch prep-tier consumption in v1.
If referenced at all, they should remain separate global modifiers.

---

## Scope

### In scope
- Commission authored data scaffolding
- Commission board generation from unlocked regions
- Finite 3-offer board
- Commission family/patron/objective template support
- Board composition rules
- Commission UI foundation
- Immediate dispatch on acceptance
- Crew/Supplies operational inputs
- Prep tier selector
- Graded commission outcomes
- Gold payout and basic standing/reputation scaffold
- Board refill on acceptance
- Save/load support for commission state
- Debug compatibility

### Out of scope
- Final art pass
- Final Commission Board visual polish
- Deep patron reputation systems
- Faction diplomacy systems
- Typed supply categories
- Rare item loadout systems
- Final officer system depth
- Hard mission failure states
- Monetization hooks
- Event commissions
- Full battle pass/event reward integration
- Broad rebalance pass across the whole game

---

## Engineering / architecture guardrails
- Keep authored data separate from player-owned/runtime state.
- Preserve the existing “expand foundation, do not rebuild” principle.
- Reuse existing dispatch/report/slot architecture where practical instead of inventing parallel systems unless there is a strong reason not to.
- Prefer scene-authored UI structures and script-driven data binding over large UI trees built entirely in code.
- Keep implementation explicit and beginner-maintainable.
- Avoid speculative abstractions.

---

## Deliverables
- commission authored data files and/or tables
- first-pass patron tier/pool definitions
- first-pass family definitions
- first-pass objective templates
- first-pass board generation rules
- Commission Board runtime generation
- visible 3-offer board
- dispatch-on-accept flow
- Crew and Supplies operational input handling
- prep tier selector
- outcome resolution rules
- gold reward handling
- board replenishment handling
- save/load integration
- updated comments/documentation in touched scripts/scenes/data files

---

## Acceptance criteria
- The player can access a Commission Board with 3 visible offers.
- Visible commissions are generated only from unlocked/reachable regions.
- Offers feel procedurally varied but coherent.
- The board is not duplicate-heavy when valid alternatives exist.
- Accepting a commission dispatches it immediately and commits resources immediately.
- There is no staging/holding area for accepted commissions.
- Commissions consume Crew and Supplies rather than direct gold dispatch cost.
- Prep tier is selected through a pre-built UI control, not manual numeric entry.
- Commissions resolve into Excellent / Solid / Strained / Poor outcome bands.
- Commissions pay gold on completion.
- Accepted board slots are replenished with newly generated offers.
- Commission state persists correctly through save/load.
- Existing expedition/region systems continue to function.
- No typed supply expansion or overbuilt reputation system is introduced prematurely.
