# Expedition Guild Idle - Game Overview

## Project Summary
Expedition Guild Idle is an idle-first mobile game about running a guild of explorers who discover ruins, relics, and knowledge across distant frontiers. The player does not manually move through a world. Instead, they manage expeditions, choose between a few readable opportunities, collect results, and improve the guild over time.

The project is intentionally UI-heavy and systems-first. It should be feasible for a solo developer using AI coding assistance, placeholder art, and data-driven content.

## Player Fantasy
The player fantasy is:

> I run a discovery engine that keeps uncovering strange places, valuable relics, and useful knowledge over time.

The player is a guild master, not a direct-action adventurer.

## MVP Goal
Validate one question:

> Is the expedition loop satisfying enough to build the rest of the game around?

The MVP does not need to prove long-term retention, monetization, or content scale. It only needs to prove that sending expeditions, collecting reports, making small upgrade decisions, and progressing collections feels good to repeat.

## Core Loop
1. Open the game and check expedition results.
2. Collect rewards.
3. Review what was discovered.
4. Choose a new expedition from a small board of options.
5. Dispatch a team.
6. Spend some resources on permanent upgrades or collection progress.
7. Exit and let the game continue passively.

## Session Shape
### Short session (1-2 minutes)
- Collect one or more completed expeditions.
- Make one upgrade.
- Send a new expedition.

### Engaged session (5-10 minutes)
- Compare expedition choices.
- Choose between safer and riskier runs.
- Review reports and discovery progress.
- Improve the guild and optimize the next dispatch.

## Design Principles
- Idle-first, not active-control gameplay.
- Small number of readable choices at a time.
- Strong sense of discovery without requiring a world map.
- Data-driven systems with modular content generation.
- UI clarity is more important than visual spectacle.
- The prototype should prefer the simplest working implementation.

## MVP Included Systems
- Expedition generation
- Expedition board
- Dispatch flow
- Expedition timer / completion
- Expedition report
- Resource rewards
- Guild upgrades
- Codex / discovery tracking

## Out of Scope for MVP
- Specialists and team composition depth
- Multiple simultaneous teams, if that slows the first loop
- Prestige
- Crafting / relic restoration depth
- Story campaign
- Live ops
- PvP, guilds, multiplayer, global map
- Economy tuning beyond rough prototype balance

## Prototype Success Signals
The MVP is successful if testers:
- feel anticipation when expeditions are about to finish
- care which expedition they choose next
- understand what they earned and why
- feel motivated to upgrade and send another run

## Expansion Hooks
If the loop works, future systems can plug into the existing framework:
- specialist roles
- more frontiers and site archetypes
- expedition chains
- relic sets and restoration
- contracts and events
- prestige/reset layer
- additional currencies and progression tracks
