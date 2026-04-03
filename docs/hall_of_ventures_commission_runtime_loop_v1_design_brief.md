# Hall of Ventures — Commission Runtime Loop v1 Design Brief

## Purpose
Commission Foundation established the board, generation rules, prep-tier flow, Crew/Supplies operational inputs, and immediate gold payout behavior.

The next design step is to convert Commissions from an **instant-resolution transaction** into a **live timed operational loop** without blurring them into Expeditions.

This brief is written in canon-friendly language so it can be folded into the design canon later with minimal rewriting.

---

## Why this slice exists
The current Commission Foundation slice proves that the board grammar, authored content model, and immediate dispatch flow are viable.

However, immediate resolution still leaves a gap between what Commissions are **meant to be** and how they currently **feel** in play:
- they are meant to be the game's primary gold-generation loop
- they are meant to create short/medium-horizon operational choices
- they are meant to create ongoing pressure around Crew, Supplies, slot usage, and timing
- they are **not** meant to feel like a one-click conversion of Supplies into gold

Commission Runtime Loop v1 closes that gap by making accepted contracts occupy time, resources, and attention before paying out.

---

## Locked design position
Commission Runtime Loop v1 establishes the following:

- **Commissions remain the primary gold-generation loop.**
- **Expeditions remain the investment / discovery / knowledge / future-preparation loop.**
- **Commissions should feel shorter, more operational, and more repeatable than Expeditions.**
- **Commissions should not become "Expeditions but shorter."**
- **The Commission Board remains the offer-and-dispatch surface.**
- **Guild Hall becomes the runtime status-and-entry surface for ongoing operations.**
- **Commission payout is delayed until contract completion and claim, rather than resolving instantly at dispatch.**
- **Crew and Supplies remain the relevant operational inputs for Commissions in v1.**
- **This slice does not solve where Supplies come from.**
- **This slice does not introduce buildings/facilities, hall grounds, or passive production systems.**

---

## Core loop
The intended v1 Commission runtime loop is:

1. From Guild Hall, check the operations area to see whether Commission slots are empty, in progress, or completed.
2. Open the Commission Board when the player wants to review and dispatch new work.
3. Inspect a board offer and choose a prep tier.
4. Dispatch immediately if the guild has enough Crew, Supplies, and an open Commission slot.
5. Commit resources immediately:
   - Supplies are spent
   - Crew moves from Available to Assigned
   - an active Commission slot becomes occupied
6. Remove the accepted offer from the board and refill that visible board slot immediately.
7. Let the Commission run over time.
8. While it runs, show the contract in Guild Hall as an in-progress Commission card with remaining time.
9. When the timer completes:
   - the active slot is freed
   - committed Crew leaves Assigned and moves into Recovering under the current abstract Crew model
   - the finished contract becomes **ready to claim**
10. In Guild Hall, the completed Commission card changes into a claim state.
11. Tap the completed card to collect gold payout and any side rewards / standing changes.
12. Reinvest that gold into broader venture capability.

---

## Core runtime rules

### 1. Board offers and active Commission slots are separate concepts
The visible Commission Board is a market/offer surface.
Active Commission slots are a concurrency limit.

They may both start at 3 in v1, but they should remain conceptually separate.

### 2. Dispatch is still immediate
There is still no accepted-but-unlaunched backlog.

Accepting a Commission means dispatching it immediately, subject to:
- enough Crew
- enough Supplies
- an open active Commission slot

### 3. Slot pressure is real
If all active Commission slots are occupied, the player may still inspect board offers, but dispatch should be blocked with clear messaging.

### 4. Board refill happens on dispatch, not on claim
The board should refill when an offer is accepted and converted into an active Commission.

This preserves the board's role as a live operational surface rather than tying it to payout collection timing.

### 5. Commissions no longer pay instantly
Dispatching a Commission should no longer award gold immediately.
Gold enters the economy only after the Commission finishes and the player claims the result.

### 6. Completion should free operational capacity before payout is claimed
When a Commission completes:
- the active slot should free up
- the Commission should move into a ready-to-claim state
- committed Crew should leave Assigned and move into Recovering according to the current v1 abstraction

This keeps the loop operational rather than punitive if the player delays collection.

### 7. Claiming should be compact and direct
Completed Commissions should be claimable through the Guild Hall Commission card state.
They should not reuse the full emotional or narrative framing of Expedition reports.

### 8. Commission durations remain shorter and steadier than Expedition durations
The point of runtime Commissions is to create a more active operational cadence, not a second long-form venture system.

### 9. Existing Commission outcome logic remains useful
Excellent / Solid / Strained / Poor remains the correct v1 outcome model.
This slice changes **when** outcomes matter in play, not the whole outcome philosophy.

### 10. This slice does not answer the Supplies-source question
Supplies remain a committed operational input here.
Their broader acquisition loop should be solved in a later, separate milestone.

---

## Identity guardrails versus Expeditions
Commission Runtime Loop v1 must preserve loop asymmetry.

### Commissions should feel like:
- contracts
- operations
- throughput
- logistics pressure
- repeatable gold work
- quick board-driven decisions

### Expeditions should continue to feel like:
- investment
- discovery
- authored-region interaction
- knowledge growth
- clue progression
- more strategic longer-horizon ventures

### Therefore
Commission runtime should borrow only the structural parts of Expedition flow that are genuinely useful:
- active timed state
- save/load persistence
- offline-compatible timer handling
- compact card-based Guild Hall presentation

It should **not** borrow the full expedition emotional wrapper.

---

## UI/interaction principles

### Guild Hall and Commission Board serve different roles
Guild Hall should become the ongoing operations surface.
Commission Board should remain the place where offers are reviewed and dispatched.

The player's runtime read should happen in Guild Hall.
The player's offer-selection read should happen in Commission Board.

### Guild Hall should use an operations TabContainer
The existing Expedition carousel and the new Commission carousel should live inside a shared TabContainer in Guild Hall.

The immediate purpose is legibility.
A secondary benefit is future extensibility for later operational views such as supply-focused runs.

### The Commission tab should mirror the Expedition card grammar
Commission cards in Guild Hall should follow the same broad pattern already used by Expedition cards:
- horizontal scrolling carousel
- placeholder image area
- title text
- compact state/status text
- the whole card acting as the button

This reuse is intentional because it keeps the home-screen operations surface legible and cohesive.

### Commission card states should be explicit
The first Guild Hall Commission card states should be:

- **Empty / idle slot**
  - title: empty-slot placeholder
  - state text: Tap to Open Commission Board
  - tap behavior: open Commission Board

- **In progress**
  - title: Commission title
  - state text: In progress + remaining time
  - tap behavior: inactive or no-op while running

- **Complete**
  - title: Commission title
  - state text: Complete + Collect Reward
  - tap behavior: claim reward directly through the compact Commission claim flow

### Commission Board remains dispatch-focused
The Board should still handle:
- visible offers
- offer inspection
- prep-tier selection
- dispatch validation
- dispatch blocking reasons

It should not become the main place where ongoing contracts are monitored.

### Placeholder UI remains acceptable
This slice may still use placeholder/test-oriented layout and art as long as the flow is readable and maintainable.

---

## Deliberate non-goals
Commission Runtime Loop v1 does **not** attempt to do the following:

- solve Supplies generation/procurement
- introduce typed supply categories
- add buildings/facilities or hall-grounds systems
- add passive building-based resource production
- introduce deep officer specialization
- introduce deep patron reputation ladders
- add event/special Commission logic
- redesign the entire Guild Hall beyond the targeted operations TabContainer and Commission tab needed for this loop
- turn Commission completion into a narrative report layer

---

## Future-facing notes
This slice should make later work easier without forcing it now.

It should leave clean hooks for later additions such as:
- Commission suitability / region-knowledge weighting
- deeper patron standing and unlock ladders
- procurement/provisioning loops for Supplies
- hall/facility wrappers that organize mature systems
- additional operations tabs later, such as supply-run views
- automation, batching, or claim-flow conveniences

Those are later expansions.
The point of this slice is narrower:

**make Commissions feel like an active live loop while keeping their identity distinct from Expeditions and surfacing their runtime state clearly in Guild Hall.**
