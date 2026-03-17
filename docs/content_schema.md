# Content Schema

This file defines the minimum data shapes for the v0.1 prototype.

## Expedition Content Overview
Expeditions are generated from modular content pools rather than a world map.

Each generated expedition should include:
- `id`
- `biome`
- `site_type`
- `state_modifier`
- `reward_profile`
- `hazard`
- `duration_minutes`
- `difficulty`
- `display_name`
- `risk_label`

Optional fields that are useful even in v0.1:
- `flavor_summary`
- `base_success`
- `reward_weights`

## Suggested Expedition Dictionary Shape
```json
{
  "id": "exp_jungle_temple_overgrown_001",
  "biome": "jungle",
  "site_type": "temple",
  "state_modifier": "overgrown",
  "reward_profile": "codex_rich",
  "hazard": "disease",
  "duration_minutes": 120,
  "difficulty": "medium",
  "risk_label": "Medium",
  "display_name": "Overgrown Jungle Temple",
  "flavor_summary": "Vines choke the outer halls, but preserved records may still remain inside.",
  "base_success": 0.78
}
```

## Minimum Content Pools

### biomes.json
```json
[
  { "id": "plains", "name": "Plains" },
  { "id": "jungle", "name": "Jungle" },
  { "id": "coast", "name": "Coast" },
  { "id": "desert", "name": "Desert" },
  { "id": "highlands", "name": "Highlands" }
]
```

### site_types.json
```json
[
  { "id": "ruins", "name": "Ruins" },
  { "id": "temple", "name": "Temple" },
  { "id": "watchtower", "name": "Watchtower" },
  { "id": "settlement", "name": "Settlement" },
  { "id": "archive", "name": "Archive" },
  { "id": "tomb", "name": "Tomb" }
]
```

### states.json
```json
[
  { "id": "buried", "name": "Buried" },
  { "id": "flooded", "name": "Flooded" },
  { "id": "overgrown", "name": "Overgrown" },
  { "id": "collapsed", "name": "Collapsed" },
  { "id": "abandoned", "name": "Abandoned" }
]
```

### reward_profiles.json
```json
[
  { "id": "relic_rich", "name": "Relic-Rich", "primary_reward": "relic_fragments" },
  { "id": "codex_rich", "name": "Codex-Rich", "primary_reward": "codex_entries" },
  { "id": "salvage_rich", "name": "Salvage-Rich", "primary_reward": "gold" },
  { "id": "balanced", "name": "Balanced", "primary_reward": "gold" }
]
```

### hazards.json
```json
[
  { "id": "collapse", "name": "Collapse" },
  { "id": "fauna", "name": "Fauna" },
  { "id": "traps", "name": "Traps" },
  { "id": "disease", "name": "Disease" },
  { "id": "heat", "name": "Heat" }
]
```

## Guild Upgrade Schema
### guild_upgrades.json
```json
[
  {
    "id": "improved_logistics_1",
    "name": "Improved Logistics I",
    "description": "Expeditions complete 10% faster.",
    "cost_gold": 100,
    "effect_type": "duration_multiplier",
    "effect_value": 0.90
  },
  {
    "id": "salvage_protocols_1",
    "name": "Salvage Protocols I",
    "description": "Gain 10% more gold from expeditions.",
    "cost_gold": 125,
    "effect_type": "gold_multiplier",
    "effect_value": 1.10
  },
  {
    "id": "archive_standards_1",
    "name": "Archive Standards I",
    "description": "Gain 10% more codex entries from expeditions.",
    "cost_gold": 125,
    "effect_type": "codex_multiplier",
    "effect_value": 1.10
  }
]
```

## Player State Shape
```json
{
  "gold": 0,
  "relic_fragments": 0,
  "codex_entries": 0,
  "purchased_upgrades": [],
  "codex_discoveries": [],
  "active_expedition": null,
  "completed_report": null
}
```

## Expedition Outcome Shape
```json
{
  "expedition_id": "exp_jungle_temple_overgrown_001",
  "display_name": "Overgrown Jungle Temple",
  "outcome": "success",
  "gold": 120,
  "relic_fragments": 2,
  "codex_entries": 1,
  "summary": "The team recovered weathered tablets and a small cache of relic fragments."
}
```

## Naming Rule
Display names should be human-readable and follow a simple pattern:
- `{State} {Biome} {Site}`

Examples:
- Flooded Coastal Watchtower
- Buried Desert Tomb
- Overgrown Jungle Temple

## Balance Rule for v0.1
Keep the numbers intentionally simple.
The prototype only needs believable reward spread, not final balance.
