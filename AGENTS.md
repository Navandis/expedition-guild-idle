# AGENTS.md

## Purpose
This repository contains the working Godot 4 prototype for **Hall of Ventures**.
The repository name is still `expedition-guild-idle`, but the current working title and forward-facing design identity are **Hall of Ventures**.

This file exists to make Codex and other repo-aware agents read the correct project documents in the correct order before making changes.

---

## Project stance
- Extend the current codebase; do not rebuild the project from scratch.
- Preserve solo-dev feasibility.
- Keep debug tools in code.
- Expand one meaningful subsystem slice at a time.
- Push back on changes that conflict with the locked project direction.
- Keep authored content separate from runtime/player-owned state.
- Prefer scene-authored UI plus script-driven data binding for visible UI.
- Use GDScript only unless a task explicitly says otherwise.

---

## Required read order before making changes
Before implementing a task, read these files in this order:

1. `docs/hall_of_ventures_design_canon_v2_3.docx`
2. `docs/current_milestone.md`
3. `docs/06_decisions_and_non_decisions_log.md`

Use system references or archive material only if the active docs above are insufficient.

---

## How to interpret those files
- **Design canon** = forward-looking design truth
- **Implementation status** = factual truth about what the repo currently does
- **Decisions log** = indexed locked rulings and deferred topics
- **Current milestone** = active build target
- **Codex prompt sequence** = implementation sequence for the current milestone

Do not infer project direction from code alone when these documents provide a more explicit answer.

If a new idea conflicts with the design canon or a locked decisions-log item, surface that conflict explicitly instead of silently improvising.

---

## Active implementation rule
For current Supply Runs work:
- treat `docs/current_milestone.md` as the active build target

If a task prompt is narrower than the full milestone, still stay within the milestone’s guardrails unless the human explicitly revises them.

---

## Prompt-behavior expectations
When implementing:
- keep implementation simple and explicit
- avoid speculative abstractions
- avoid unrelated refactors
- avoid broad architecture rewrites
- reuse existing scenes/scripts/components where practical
- prefer narrow, testable changes
- add beginner-friendly file header comments and concise inline comments in touched scripts where useful

Good tasks:
- one subsystem slice
- one flow improvement
- one authored-data family
- one narrow UI extension
- one runtime/save/load hardening pass

Bad tasks:
- refactor the whole project
- redesign the whole game
- infer the next milestone from code alone
- widen scope beyond the requested subsystem slice

---

## Current high-level identity
Hall of Ventures is:
- a UI-heavy, data-driven, non-combat fantasy idle / management game
- a frontier contract guild idler
- guild-first rather than hero-first
- built around three long-term activity lanes:
  - **Commissions** = primary gold-generation loop
  - **Supply Runs** = provisioning / supply-generation loop
  - **Independent Expeditions** = discovery / knowledge / long-horizon progression loop

Authored regions remain central.
The Codex remains the primary knowledge/archive/progression surface.
Combat stays abstract and off-screen.

---

## Change-safety rules
- Do not write changing player state back into authored JSON.
- Preserve current save/runtime boundaries unless the task explicitly requires a small targeted adjustment.
- Do not replace scene-authored visible UI with large runtime-built UI trees unless truly necessary.
- Do not rename major systems or perform cleanup-only architecture passes unless the task explicitly asks for that or correctness requires it.
- When a design discussion resolves, prefer updating the relevant project document so the outcome is not left only in chat history.

---

## If documents disagree
Use this priority order unless the human explicitly instructs otherwise:
1. direct human task instructions
2. `docs/06_decisions_and_non_decisions_log.md`
3. `docs/current_milestone.md`
4. `docs/hall_of_ventures_design_canon_v2_3.docx`
5. older reference or archive docs

If there is a meaningful conflict, state it clearly before making a broad assumption.

---

## Notes for current repo context
- Repo name remains `expedition-guild-idle`
- Working game title is **Hall of Ventures**
- Commission Runtime Loop v1 is implemented
- Supply Runs Foundation v1 is the active milestone target unless later docs supersede it