# Expedition Guild Idle — Region Foundation Slice

## Purpose
Introduce authored regions as the new expedition context layer without rebuilding the existing expedition loop.

This milestone should establish the minimum viable foundations for:
- region definitions
- per-player region progress state
- region-based expedition generation
- minimal UI support for selecting a region and seeing region availability

This is a foundation milestone, not a full feature pass. It should make the game feel different in one meaningful way while staying small, save-safe, and compatible with the existing architecture.

## Goal
Move expedition generation from:
- global/random expedition offer pool

to:
- player selects a region, then expedition offers are generated inside that region’s authored constraints

without yet adding:
- logistics gameplay
- chained discoveries
- research
- final Codex UI
- backend/server systems

## Design intent
This milestone should establish these core truths in code:
- Regions are authored content packs, not runtime-generated areas.
- Region definition, player region progress, and generated expedition offers are separate data layers.
- The game remains JSON-driven for authored content.
- The new structure should be compatible with eventual backend/profile migration, but still use local save JSON for now.
- UI changes should be minimal and structural, only enough to support region-based generation.

## Scope

### In scope
- Add authored region data definitions in JSON
- Add region loading/parsing/validation plumbing
- Add per-player region progress save data structure
- Seed initial player region progress for the first 5 authored regions
- Support visibility/unlock state per region
- Allow the player to choose a region before browsing expeditions
- Generate expedition offers only from the selected region’s allowed pools
- Add a minimal Regions section or minimal Codex region view sufficient to inspect known/unknown regions
- Keep existing dispatch/report/reward loop working
- Keep debug tools compatible

### Out of scope
- No backend or database integration
- No auth/cloud save
- No asynchronous multiplayer systems
- No logistics requirement gameplay yet
- No chain discovery system yet
- No final tome-style Codex redesign
- No large Guild Hall redesign
- No progression rebalance pass
- No specialist/advisor systems
- No major UI polish or theming pass

## Required authored region model
For this milestone, each region should support at least these required fields:
- `id`
- `display.name`
- `display.short_name`
- `display.region_tier`
- `display.summary_text`
- `display.codex_sketch_asset`
- `theme.region_role`
- `theme.allowed_biomes`
- `theme.culture_families`
- `theme.art_motifs`
- `theme.fantasy_level`
- `progression.starts_visible`
- `progression.starts_unlocked`
- `progression.prerequisite_region_ids`
- `progression.prerequisite_clue_tags`
- `progression.prerequisite_research_tags`
- `progression.prerequisite_logistics_tags`
- `generation_rules.route_types`
- `generation_rules.site_families`
- `generation_rules.site_conditions`
- `generation_rules.opportunity_profiles`
- `generation_rules.hazard_tags`
- `rewards_and_discoveries.artifact_families`
- `rewards_and_discoveries.clue_families`
- `codex.page_order`
- `codex.starts_as_unknown_page`
- `hooks.chain_hook_tags`
- `hooks.legacy_hook_tags`

The exact five starter regions to seed:
- Greenhollow Reaches
- Emberwake Coast
- Greyfen March
- Sunscar Expanse
- Hollowspire Uplands

## Required per-player region progress save-state
Each region should have player progress stored separately from authored region JSON.

Required fields:
- `is_visible`
- `is_unlocked`
- `expeditions_completed`
- `region_discovery_points`
- `codex_reveal_stage`
- `artifact_families_seen`
- `clue_tags_found`
- `active_chain_ids`
- `completion_flags`

Important guardrail:
- authored data must not store player state
- player save data must not duplicate authored region rules unnecessarily

## Data / architecture guardrails for future backend migration
This is important, but still intentionally light-weight for now.

### Required guardrails
- Use stable string ids for regions and future-facing content tags
- Keep authored content JSON separate from player save/profile JSON
- Treat save-owned data conceptually as player profile state, even if still stored locally
- Avoid screen-local ownership of important persistent state
- Keep region unlock/progress logic in a gameplay/system layer, not buried inside UI scripts
- Keep save/load shape explicit and easy to serialize later
- If save versioning already exists, extend it cleanly; if not, add a simple save version field now only if straightforward

### Explicit non-goals
- Do not add a real database
- Do not add network code
- Do not add live-service scaffolding
- Do not attempt production-ready backend architecture

## UI guardrails
Only minimal UI changes should be made in this milestone.

### Allowed UI changes
- Add a simple way to choose the active/selected region before browsing expedition offers
- Show which regions are unlocked vs visible-but-locked
- Show region name and summary context where expeditions are being generated
- Add a minimal region info view in Codex or a minimal Regions subsection
- Add simple unknown-region placeholder presentation where needed

### Avoid in this milestone
- no full Codex visual redesign
- no decorative tome implementation
- no large navigation rewrite
- no full Guild Hall dashboard redesign
- no skinning/theming pass
- no animation pass

## Suggested implementation shape
This is not mandatory if the current repo suggests better naming, but the structure should roughly move toward:
- region content JSON file(s)
- region data loader/parser
- region progress save structure
- GameManager or a closely related system owning selected region + region access state
- Expedition generation updated to accept region context
- Expedition Board updated to use selected region context
- Codex or minimal region screen updated to show known/unknown region information

## Deliverables
- region JSON content file(s) with 5 starter regions
- loading/parsing support for region definitions
- save/load support for region player progress
- active selected region support
- expedition generation constrained by selected region
- minimal region selection UI
- minimal region information/Codex support
- updated debug/reset flows as needed so the system remains testable

## Acceptance criteria
- The game still boots and the existing core loop still works
- At least 5 authored regions exist in data
- A new save initializes with the intended initial visibility/unlock state for those regions
- The player can select an unlocked region and see expedition offers generated only from that region’s authored rules
- Locked-but-visible regions are shown as unavailable and cannot yet be selected for expedition generation
- Existing dispatch, active slot, report, reward, and upgrade flows continue to work
- Save/load persists selected region and per-region player progress correctly
- Reset/debug flows still function without breaking the new region layer
- No backend/network/database work is introduced
- UI changes remain minimal and functional rather than becoming a broad redesign
