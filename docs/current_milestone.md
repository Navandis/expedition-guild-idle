# Expedition Guild Idle — Tentative UI / Structure Pass

## Purpose
Do a layout and information-architecture pass, not a visual polish pass.

This milestone should happen after Region Foundation has been implemented and lightly tested, because the new region-based flow will reveal what the UI actually needs.

## Goal
Lock the game’s structural screen grammar for the v1 path:
- how screens are laid out
- how major information is grouped
- what the persistent hierarchy is
- how Codex, Regions, and the Expedition Board fit together

This should prepare the project for future depth layers without committing to final art.

## Design intent
The current v0.1 UI was appropriate for MVP, but the game is moving into a more structured region/Codex-driven design space. This pass should formalize layout without over-polishing.

The result should feel like:
- a clearer dashboard on Guild Hall
- a region-contextual Expedition Board
- a Codex that has a real structural destiny
- reusable layout patterns for future systems

## Scope

### In scope
- review and simplify screen hierarchy
- lock common header/content/action layout structure
- restructure Guild Hall into a clearer dashboard layout
- restructure Expedition Board around selected region context
- define first real layout direction for Codex pages
- improve information grouping and spacing
- prepare mobile-friendly hierarchy and viewport behavior
- create reusable container/layout patterns where appropriate

### Out of scope
- no final art pass
- no full skin/theme pass
- no backend/network work
- no large new gameplay systems
- no chain/research/logistics feature implementation unless needed for placeholders
- no ambitious animation/UI effects work

## Structural targets by screen

### Guild Hall
Target shape:
- top summary/status area
- active expeditions and pending reports visible/prominent
- major navigation/actions grouped clearly
- room for future featured objective or frontier progress later

### Expedition Board
Target shape:
- selected region clearly shown at top
- region switching visible and understandable
- expedition list below
- action area clear and mobile-friendly
- room for future special leads/filters later

### Codex
Target shape:
- establish page-based structure
- major category navigation direction
- clear left-page / right-page style content zoning, even if visually plain
- region pages support known/unknown progression
- avoid letting Codex remain a plain scrolling text bucket

### Guild Upgrades
Likely lighter pass only:
- cleaner structure if needed
- not the focus unless layout inconsistency becomes obvious

## Deliverables
- updated layout structure for Guild Hall
- updated layout structure for Expedition Board
- first structural Codex layout direction
- reusable UI layout conventions documented in code/comments
- optional lightweight wireframe notes inside project docs if useful

## Acceptance criteria
- major screens feel structurally clearer without needing final art
- Expedition Board supports region-based play naturally
- Codex no longer feels like a placeholder text dump structurally
- Guild Hall reads more like a dashboard than a vertical menu stack
- no major gameplay systems are added during the pass
- no broad UI polish rabbit hole is opened
