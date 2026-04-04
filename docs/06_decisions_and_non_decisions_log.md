# Hall of Ventures - Decisions and Non-Decisions Log

## Purpose
This file is the indexed log of high-leverage design rulings, deferrals, and workflow decisions that should be easy for both humans and AI tools to reference.

This file is **additive**, not a replacement for the design canon.
Use it for:
- decisions that need stable reference IDs
- recent rulings that are easy to lose inside chat history
- topics that were explicitly deferred and should not be silently reopened

## How to use this file
- cite the item by its **ID** when referring back to it in later chats or milestone docs
- use **LOCK** items as active rulings
- use **HOLD** items as explicitly deferred topics
- use **WF** items as workflow / process rules
- if a new decision supersedes an older one, add a new item rather than mutating history invisibly

## Format
Each entry uses:
- **ID** - stable reference marker
- **Type** - `LOCK`, `HOLD`, or `WF`
- **Status** - active or deferred
- **Decision** - the ruling itself
- **Why it matters** - short reasoning / consequence note

---

## HOV-LOCK-001
- **Type:** LOCK
- **Status:** Active
- **Decision:** The project remains a frontier contract guild idler with a hybrid spine: Commissions + Independent Expeditions.
- **Why it matters:** This remains the top-level identity filter for milestone choices and scope control.

## HOV-LOCK-002
- **Type:** LOCK
- **Status:** Active
- **Decision:** Commissions are the primary gold-generation loop; Independent Expeditions remain the discovery / knowledge / long-horizon loop.
- **Why it matters:** This is the economic asymmetry that keeps the game from collapsing into two flavor variants of the same mission type.

## HOV-LOCK-003
- **Type:** LOCK
- **Status:** Active
- **Decision:** Commission Runtime Loop v1 is time-based, not instant-resolution.
- **Why it matters:** Dispatch now creates live timed work; payout happens later at claim.

## HOV-LOCK-004
- **Type:** LOCK
- **Status:** Active
- **Decision:** Guild Hall is the runtime status-and-entry surface for ongoing operations, while Commission Board remains the offer-and-dispatch surface.
- **Why it matters:** This keeps operational monitoring and offer selection conceptually separate.

## HOV-LOCK-005
- **Type:** LOCK
- **Status:** Active
- **Decision:** Commission Board refill should preserve slot identity: the accepted offer's replacement appears in the same visible slot.
- **Why it matters:** This preserves the player's mental map while reviewing and ranking board offers.

## HOV-LOCK-006
- **Type:** LOCK
- **Status:** Active
- **Decision:** Guild Hall Commission cards should use monitoring-first ordering rather than strict slot-locking. The preferred priority is completed first, then shortest time remaining, then empty slots.
- **Why it matters:** Guild Hall is answering status questions, not preserving board-review identity.

## HOV-LOCK-007
- **Type:** LOCK
- **Status:** Active
- **Decision:** Completed commissions should open a compact settlement summary rather than a full expedition-style report.
- **Why it matters:** Commissions need readable outcome feedback without borrowing the expedition report fantasy.

## HOV-LOCK-008
- **Type:** LOCK
- **Status:** Active
- **Decision:** Supplies should not primarily come from commissions.
- **Why it matters:** Commissions already own the main gold-faucet role and should not also be the main source of the next critical resource.

## HOV-LOCK-009
- **Type:** LOCK
- **Status:** Active
- **Decision:** Supplies should not primarily be solved through a direct gold-for-supplies shop.
- **Why it matters:** That would flatten the economy and let gold solve too much too directly.

## HOV-LOCK-010
- **Type:** LOCK
- **Status:** Active
- **Decision:** Supplies should not primarily be solved through passive building or facility production.
- **Why it matters:** Passive production would undercut the intended operational loop and create design drift toward a different game.

## HOV-LOCK-011
- **Type:** LOCK
- **Status:** Active
- **Decision:** The intended near-term answer to the supplies economy is a dedicated procurement / provisioning activity using the working label **Supply Runs**.
- **Why it matters:** This is the next major milestone direction and should stay separate from both commissions and buildings.

## HOV-LOCK-012
- **Type:** LOCK
- **Status:** Active
- **Decision:** Supply Runs should sit closer to the expedition-side operational pillar than to the patron-contract pillar.
- **Why it matters:** They are about provisioning and readiness, not patron prestige or monetization.

## HOV-LOCK-013
- **Type:** LOCK
- **Status:** Active
- **Decision:** The hall / facilities layer is a future wrapper or motherboard for mature systems, not the immediate answer to missing systems.
- **Why it matters:** This protects the project from turning the hall grounds into a premature meta-game that hijacks the core loops.

## HOV-LOCK-014
- **Type:** LOCK
- **Status:** Active
- **Decision:** Hall / facilities implementation should not arrive before the systems it wraps have proven their own value independently.
- **Why it matters:** The wrapper should organize mature systems, not force them into existence.

## HOV-HOLD-001
- **Type:** HOLD
- **Status:** Deferred
- **Decision:** Commission crew-recovery nuance is deferred to a later broader Logistics milestone.
- **Why it matters:** The current all-committed-crew-to-Recovering behavior is accepted as a temporary v1 simplification, not a final model.

## HOV-HOLD-002
- **Type:** HOLD
- **Status:** Deferred
- **Decision:** Commission suitability / region-knowledge deepening is a likely later milestone, but not the immediate next one.
- **Why it matters:** Supply Runs should come first so the economy is structurally complete before deepening commission nuance.

## HOV-HOLD-003
- **Type:** HOLD
- **Status:** Deferred
- **Decision:** Typed supply categories remain deferred.
- **Why it matters:** The core loop should prove itself before the game tracks food, rope, pack animals, cloth, and similar subtypes.

## HOV-HOLD-004
- **Type:** HOLD
- **Status:** Deferred
- **Decision:** Buildings / facilities implementation is deferred even though the hall-complex fantasy remains valuable.
- **Why it matters:** The design value of the hall wrapper is preserved without forcing it into the next milestone.

## HOV-WF-001
- **Type:** WF
- **Status:** Active
- **Decision:** The preferred working structure is one curated Project, many short chats, and explicit canonical documents.
- **Why it matters:** This reduces context drift while preserving continuity.

## HOV-WF-002
- **Type:** WF
- **Status:** Active
- **Decision:** When a debate resolves, the outcome should be moved into a document rather than left only in chat history.
- **Why it matters:** This is the main defense against design drift across long development timelines.

## HOV-LOCK-015
- **Type:** LOCK
- **Status:** Active
- **Decision:** Supply Runs Foundation v1 starts with an initial active Supply Run slot cap of **2**, and that starting value should be introduced into and sourced from `new_game_start_conditions.json`.
- **Why it matters:** This removes ambiguity from the milestone, keeps the starting cap explicit in data rather than hidden in UI code, and preserves a clean path for later progression-based cap increases.

## HOV-LOCK-016
- **Type:** LOCK
- **Status:** Active
- **Decision:** Supply Runs Foundation v1 should use a provisional working payout band of roughly **10-20 Supplies per run**, and the final Supply payout should be **pre-rolled at dispatch** and stored on the runtime row / completion payload.
- **Why it matters:** This gives implementation a concrete starting number without pretending balance is final, and it keeps claim, save/load, and offline completion behavior explicit and safe.

## HOV-LOCK-017
- **Type:** LOCK
- **Status:** Active
- **Decision:** `CommissionResolver` remains named as-is during Supply Runs Foundation v1; the milestone should reuse the current shared Crew / Supplies owner and should not widen into a naming cleanup or broader orchestration refactor unless required for correctness.
- **Why it matters:** This protects the milestone from unnecessary architecture churn and keeps Supply Runs focused on shipping the new provisioning loop rather than reopening broader ownership questions.

## HOV-HOLD-005
- **Type:** HOLD
- **Status:** Deferred
- **Decision:** Broader consolidation of narrow operational scripts into more global orchestration-style owners is deferred until a later architecture-focused milestone.
- **Why it matters:** This preserves the possibility of later cleanup without letting Supply Runs Foundation v1 expand into a premature systems refactor.

## HOV-WF-003
- **Type:** WF
- **Status:** Active
- **Decision:** Add a root-level `AGENTS.md` file to the repository and use it to direct Codex to the project’s authoritative document order before implementation work begins.
- **Why it matters:** A linked repository may make project files available to Codex, but the agent should not be expected to infer which documents are authoritative or which order they should be read in. A root-level `AGENTS.md` gives the whole repo one default instruction layer and reduces context drift across implementation chats.