# Current Milestone - v0.1 First Playable Loop

## Milestone Goal
Implement the smallest end-to-end playable expedition loop.

The player should be able to:
1. open the game
2. see available expeditions
3. choose one expedition
4. dispatch a team
5. wait for or simulate completion
6. open a report
7. collect rewards
8. buy at least one guild upgrade
9. see basic codex/discovery progress

## In Scope
- One main scene with navigation to the MVP screens
- A guild hall / home screen
- Expedition board showing 3-5 generated expeditions
- A dispatch screen or modal
- Single active expedition is acceptable for the first cut
- Countdown timer or simulated timer completion
- Expedition resolution with outcome and rewards
- Report screen / popup
- Player resources: gold, relic_fragments, codex_entries
- At least 3 guild upgrades
- Basic codex tracking of discovered expedition/site combinations
- Save/load of player state if it can be done cheaply

## Explicitly Out of Scope
- Specialists
- Team gear or loadouts
- Multiple parallel expeditions if that delays the first playable loop
- Prestige / reset
- Events
- Contracts
- Deep balance tuning
- Animations beyond basic UI feedback
- Audio
- Localization
- Online features

## Prototype UX Targets
- The player should never see more than 5 expedition choices at once.
- Every expedition card must clearly show: name, duration, risk, primary reward profile, hazard.
- Reward collection must feel explicit and understandable.
- The UI can be plain, but it must be readable on a phone-sized layout.

## Definition of Done
This milestone is done when a fresh player can:
- launch the build
- do one complete expedition cycle in under 2 minutes
- understand the result without needing explanation
- see a reason to send another expedition

## Non-Goals
This milestone is not trying to answer:
- long-term depth
- retention beyond the first few loops
- final economy
- final art direction
