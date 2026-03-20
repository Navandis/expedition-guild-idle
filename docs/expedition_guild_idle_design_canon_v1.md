# Expedition Guild Idle - Design Canon and v1 World-Generation Grammar Spec

This markdown companion mirrors the DOCX content at a lighter level for easy future editing.

## Locked decision on document structure
- Keep the original MVP brief separate as a historical v0.1 record.
- Use this canon as the forward-looking source of truth for post-MVP design decisions.

## Locked grammar
Region -> Route Context -> Site Family -> Site Condition -> Opportunity Profile -> Hazard Profile -> Logistics Requirements -> Discovery Outputs -> Hook Outputs -> Presentation

## Required authored region fields
- `id` (string): Stable internal key used for save-state binding, unlock dependencies, and generation lookup
- `display.name` (string): Player-facing region name
- `display.short_name` (string): Compact label for tabs, summaries, and smaller UI areas
- `display.region_tier` (int): Readable progression tier for planning and content pacing
- `display.summary_text` (string): Short dossier-style summary for the Codex
- `display.codex_sketch_asset` (string): Sketch asset used on the region page
- `theme.region_role` (enum): Design role such as starter, bridge, or frontier_gate
- `theme.allowed_biomes` (string[]): Biome pool allowed inside the region
- `theme.culture_families` (string[]): Culture/history identities tied to finds
- `theme.art_motifs` (string[]): Visual rules that keep presentation and discoveries coherent
- `theme.fantasy_level` (enum): Grounded or more fantastic positioning for the region
- `progression.starts_visible` (bool): Whether the page exists in the Codex horizon from the start
- `progression.starts_unlocked` (bool): Whether expeditions can be generated here immediately
- `progression.prerequisite_region_ids` (string[]): Previous regions required before this one can open
- `progression.prerequisite_clue_tags` (string[]): Clues that help reveal or unlock this region
- `progression.prerequisite_research_tags` (string[]): Future-facing research dependencies
- `progression.prerequisite_logistics_tags` (string[]): Tags that express operational readiness
- `generation_rules.route_types` (string[]): Allowed route contexts inside the region
- `generation_rules.site_families` (string[]): Allowed target-site families
- `generation_rules.site_conditions` (string[]): Allowed situational modifiers
- `generation_rules.opportunity_profiles` (string[]): Opportunity labels that drive player motivation
- `generation_rules.hazard_tags` (string[]): Hazard pool for the region
- `rewards_and_discoveries.artifact_families` (string[]): Artifact groupings later used by the Codex and collections
- `rewards_and_discoveries.clue_families` (string[]): Clue groupings that can feed chains or region reveals
- `codex.page_order` (int): Region page order in the Codex
- `codex.starts_as_unknown_page` (bool): Whether the page starts as hidden/blurred/unknown
- `hooks.chain_hook_tags` (string[]): Chain families that the region can seed
- `hooks.legacy_hook_tags` (string[]): Rare guild-history hooks tied to the region

## Required per-region save-state fields
- `is_visible` (bool): Whether this region appears in the player's Codex horizon
- `is_unlocked` (bool): Whether expeditions can currently be generated here
- `expeditions_completed` (int): Simple region activity counter useful for progression and debugging
- `region_discovery_points` (int): Flexible local progress currency used for reveal thresholds and unlock checks
- `codex_reveal_stage` (int): Controls how much of the dossier has been filled in
- `artifact_families_seen` (string[]): Artifact families already encountered in this region
- `clue_tags_found` (string[]): Clue tags that can unlock chains or future regions
- `active_chain_ids` (string[]): Future-safe bucket for live chain references
- `completion_flags` (object): Named booleans for mastery markers or milestone states

## Starter regions
- Greenhollow Reaches
- Emberwake Coast
- Greyfen March
- Sunscar Expanse
- Hollowspire Uplands

## JSON examples
### Greenhollow Reaches
```json
{
  "id": "greenhollow_reaches",
  "display": {
    "name": "Greenhollow Reaches",
    "short_name": "Greenhollow",
    "region_tier": 1,
    "summary_text": "Low hills, old shrines, and weathered roads at the edge of settled lands.",
    "codex_sketch_asset": "regions/greenhollow_sketch"
  },
  "theme": {
    "region_role": "starter",
    "allowed_biomes": [
      "plains",
      "temperate_forest",
      "hills"
    ],
    "culture_families": [
      "border_kingdoms",
      "old_hill_cults"
    ],
    "art_motifs": [
      "mossy_stone",
      "weathered_shrines",
      "simple_reliefs"
    ],
    "fantasy_level": "grounded"
  },
  "progression": {
    "starts_visible": true,
    "starts_unlocked": true,
    "prerequisite_region_ids": [],
    "prerequisite_clue_tags": [],
    "prerequisite_research_tags": [],
    "prerequisite_logistics_tags": []
  },
  "generation_rules": {
    "route_types": [
      "roadside_route",
      "forest_track",
      "hill_pass"
    ],
    "site_families": [
      "ruins",
      "watchtower",
      "shrine",
      "settlement"
    ],
    "site_conditions": [
      "abandoned",
      "overgrown",
      "collapsed"
    ],
    "opportunity_profiles": [
      "balanced",
      "salvage_rich",
      "clue_bearing"
    ],
    "hazard_tags": [
      "fauna",
      "collapse",
      "traps"
    ]
  },
  "rewards_and_discoveries": {
    "artifact_families": [
      "border_relics",
      "hill_shrine_offerings"
    ],
    "clue_families": [
      "old_road_records",
      "northern_rumors"
    ]
  },
  "codex": {
    "page_order": 1,
    "starts_as_unknown_page": false
  },
  "hooks": {
    "chain_hook_tags": [
      "roadside_cache_chain"
    ],
    "legacy_hook_tags": []
  }
}
```

### Emberwake Coast
```json
{
  "id": "emberwake_coast",
  "display": {
    "name": "Emberwake Coast",
    "short_name": "Emberwake",
    "region_tier": 1,
    "summary_text": "Sea cliffs, beacon towers, wreck sites, and tidal ruins battered by salt and wind.",
    "codex_sketch_asset": "regions/emberwake_sketch"
  },
  "theme": {
    "region_role": "starter",
    "allowed_biomes": [
      "coast",
      "rocky_shore",
      "sea_cliffs"
    ],
    "culture_families": [
      "lighthouse_duchies",
      "old_mariner_orders"
    ],
    "art_motifs": [
      "salt_worn_stone",
      "signal_beacons",
      "maritime_seals"
    ],
    "fantasy_level": "grounded"
  },
  "progression": {
    "starts_visible": true,
    "starts_unlocked": true,
    "prerequisite_region_ids": [],
    "prerequisite_clue_tags": [],
    "prerequisite_research_tags": [],
    "prerequisite_logistics_tags": []
  },
  "generation_rules": {
    "route_types": [
      "coastal_road",
      "cliff_path",
      "shoreline_landing"
    ],
    "site_families": [
      "beacon_tower",
      "harbor_ruins",
      "wreck_site",
      "coastal_shrine"
    ],
    "site_conditions": [
      "collapsed",
      "salt_worn",
      "flooded",
      "abandoned"
    ],
    "opportunity_profiles": [
      "balanced",
      "salvage_rich",
      "codex_rich"
    ],
    "hazard_tags": [
      "storms",
      "collapse",
      "fauna"
    ]
  },
  "rewards_and_discoveries": {
    "artifact_families": [
      "mariner_charms",
      "beacon_tools"
    ],
    "clue_families": [
      "wreck_ledgers",
      "sea_route_fragments"
    ]
  },
  "codex": {
    "page_order": 2,
    "starts_as_unknown_page": false
  },
  "hooks": {
    "chain_hook_tags": [
      "wreck_manifest_chain"
    ],
    "legacy_hook_tags": []
  }
}
```

### Greyfen March
```json
{
  "id": "greyfen_march",
  "display": {
    "name": "Greyfen March",
    "short_name": "Greyfen",
    "region_tier": 2,
    "summary_text": "A reed-choked march of black water, drowned roads, flooded tombs, and abandoned stockades.",
    "codex_sketch_asset": "regions/greyfen_sketch"
  },
  "theme": {
    "region_role": "bridge",
    "allowed_biomes": [
      "marsh",
      "fen",
      "wet_lowlands"
    ],
    "culture_families": [
      "fen_wardens",
      "barrow_keepers"
    ],
    "art_motifs": [
      "peat_dark_stone",
      "reed_bound_markers",
      "funerary_posts"
    ],
    "fantasy_level": "grounded"
  },
  "progression": {
    "starts_visible": true,
    "starts_unlocked": false,
    "prerequisite_region_ids": [
      "greenhollow_reaches"
    ],
    "prerequisite_clue_tags": [
      "greyfen_rumor"
    ],
    "prerequisite_research_tags": [],
    "prerequisite_logistics_tags": [
      "marsh_prep_1"
    ]
  },
  "generation_rules": {
    "route_types": [
      "marsh_track",
      "causeway",
      "flatboat_approach"
    ],
    "site_families": [
      "tomb",
      "stockade",
      "sunken_shrine",
      "watch_post"
    ],
    "site_conditions": [
      "flooded",
      "abandoned",
      "buried",
      "overgrown"
    ],
    "opportunity_profiles": [
      "relic_rich",
      "clue_bearing",
      "balanced"
    ],
    "hazard_tags": [
      "disease",
      "navigation_difficulty",
      "flooding"
    ]
  },
  "rewards_and_discoveries": {
    "artifact_families": [
      "funerary_masks",
      "fen_idols"
    ],
    "clue_families": [
      "barrow_records",
      "sunscar_rumors"
    ]
  },
  "codex": {
    "page_order": 3,
    "starts_as_unknown_page": false
  },
  "hooks": {
    "chain_hook_tags": [
      "sunken_marker_chain"
    ],
    "legacy_hook_tags": [
      "missing_surveyor_chain"
    ]
  }
}
```

### Sunscar Expanse
```json
{
  "id": "sunscar_expanse",
  "display": {
    "name": "Sunscar Expanse",
    "short_name": "Sunscar",
    "region_tier": 3,
    "summary_text": "A vast scar of dunes, shattered observatories, and caravan-buried stone roads.",
    "codex_sketch_asset": "regions/sunscar_sketch"
  },
  "theme": {
    "region_role": "frontier_gate",
    "allowed_biomes": [
      "desert",
      "rocky_waste",
      "dry_plateau"
    ],
    "culture_families": [
      "sun_kingdom",
      "glass_nomads"
    ],
    "art_motifs": [
      "weathered_stone",
      "astral_glyphs",
      "sunburst_seals"
    ],
    "fantasy_level": "grounded"
  },
  "progression": {
    "starts_visible": true,
    "starts_unlocked": false,
    "prerequisite_region_ids": [
      "greyfen_march"
    ],
    "prerequisite_clue_tags": [
      "sunscar_rumor",
      "desert_route_fragment"
    ],
    "prerequisite_research_tags": [
      "desert_preparation_1"
    ],
    "prerequisite_logistics_tags": [
      "pack_caravan_1"
    ]
  },
  "generation_rules": {
    "route_types": [
      "caravan_route",
      "dune_crossing",
      "canyon_approach"
    ],
    "site_families": [
      "observatory",
      "buried_archive",
      "waystation",
      "ruins"
    ],
    "site_conditions": [
      "buried",
      "collapsed",
      "sand_choked",
      "abandoned"
    ],
    "opportunity_profiles": [
      "codex_rich",
      "clue_bearing",
      "balanced"
    ],
    "hazard_tags": [
      "heat",
      "collapse",
      "navigation_difficulty"
    ]
  },
  "rewards_and_discoveries": {
    "artifact_families": [
      "solar_seals",
      "glass_astrolabes"
    ],
    "clue_families": [
      "map_fragments",
      "star_charts"
    ]
  },
  "codex": {
    "page_order": 4,
    "starts_as_unknown_page": true
  },
  "hooks": {
    "chain_hook_tags": [
      "sunscar_map_chain",
      "observatory_inscription_chain"
    ],
    "legacy_hook_tags": [
      "lost_charter_chain"
    ]
  }
}
```

### Hollowspire Uplands
```json
{
  "id": "hollowspire_uplands",
  "display": {
    "name": "Hollowspire Uplands",
    "short_name": "Hollowspire",
    "region_tier": 3,
    "summary_text": "Bleak escarpments, old signal towers, cliff shrines, and exposed roads high above the lowlands.",
    "codex_sketch_asset": "regions/hollowspire_sketch"
  },
  "theme": {
    "region_role": "specialist",
    "allowed_biomes": [
      "highlands",
      "wind_scoured_ridges",
      "clifflands"
    ],
    "culture_families": [
      "spire_wardens",
      "ridge_kingdoms"
    ],
    "art_motifs": [
      "wind_cut_stone",
      "signal_fire_basins",
      "tower_glyphs"
    ],
    "fantasy_level": "grounded"
  },
  "progression": {
    "starts_visible": true,
    "starts_unlocked": false,
    "prerequisite_region_ids": [
      "greenhollow_reaches"
    ],
    "prerequisite_clue_tags": [
      "spire_rumor"
    ],
    "prerequisite_research_tags": [],
    "prerequisite_logistics_tags": [
      "ridge_travel_1"
    ]
  },
  "generation_rules": {
    "route_types": [
      "ridge_trail",
      "cliff_ascent",
      "old_military_road"
    ],
    "site_families": [
      "signal_tower",
      "cliff_shrine",
      "keep_ruins",
      "watch_post"
    ],
    "site_conditions": [
      "exposed",
      "collapsed",
      "abandoned",
      "partially_buried"
    ],
    "opportunity_profiles": [
      "balanced",
      "codex_rich",
      "clue_bearing"
    ],
    "hazard_tags": [
      "exposure",
      "collapse",
      "fauna"
    ]
  },
  "rewards_and_discoveries": {
    "artifact_families": [
      "signal_relics",
      "spire_tablets"
    ],
    "clue_families": [
      "tower_logs",
      "northern_route_marks"
    ]
  },
  "codex": {
    "page_order": 5,
    "starts_as_unknown_page": true
  },
  "hooks": {
    "chain_hook_tags": [
      "tower_signal_chain"
    ],
    "legacy_hook_tags": [
      "heirloom_bearing_chain"
    ]
  }
}
```
