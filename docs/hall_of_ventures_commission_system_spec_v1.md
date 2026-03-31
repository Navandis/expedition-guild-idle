# Hall of Ventures — Commission System Spec v1

## Purpose

The Commission system is Hall of Ventures' primary **gold-generation loop** and the main source of short- and medium-duration operational decisions. Commissions are patron-issued, procedurally generated from authored rules, finite on the visible board, and generated only from the player's currently reachable world.

Commissions are distinct from Expeditions:
- **Expeditions** are the investment, discovery, knowledge, and supplies loop.
- **Commissions** are the monetization, patron progression, and operational execution loop.

## Locked principles

- Commission offers are generated only from the player's currently unlocked and serviceable regions.
- Commissions are procedural but authored: random within curated rules, not pure chaos and not primarily handcrafted one-offs.
- The visible commission board is finite. v1 starts at **3 visible offers**.
- Accepting a commission means immediate dispatch and immediate commitment of operational resources. There is no staging area or accepted-but-unlaunched inventory.
- When a commission is accepted, the board replenishes back toward its visible cap by generating a new offer for the emptied slot.
- Standard commissions persist until accepted or refreshed. Event or special commissions may expire.
- Players may influence commission type likelihood through progression systems, but this influence should remain weight-shifting rather than fully deterministic selection.
- The board should remain healthy without heavy reroll dependence, even though rerolls may exist as premium or event-adjacent rewards later.
- Commissions do **not** directly charge gold on dispatch. Gold should primarily be the output of commissions, not an immediate subtraction input.
- Commissions consume **operational resources** instead: crew, supplies, readiness, and suitability.
- Commission results are graded outcomes, not hard binary pass/fail by default.

## Core loop

1. Spend gold on expeditions, upgrades, research, recruiting, and accelerating crew recovery.
2. Expeditions return Supplies, regional knowledge, clues, collectibles, and strategic progress.
3. Use Crew + Supplies + officers + knowledge to run commissions.
4. Commissions return gold, standing, and progression.
5. Reinvest that gold into deeper expeditions and stronger operational capability.

## Commission grammar

**Patron -> Commission Family -> Brief Style -> Region Eligibility -> Objective -> Requirement Profile -> Operational Inputs -> Duration Profile -> Risk Profile -> Outcome Profile -> Reward Package -> Board Tags -> Presentation**

### Layer roles
- **Patron** — who issued the commission and what sort of work they typically request.
- **Commission Family** — the job category.
- **Brief Style** — how explicit or inferential the player-facing brief is.
- **Region Eligibility** — which unlocked regions can plausibly fulfill the commission.
- **Objective** — the concrete task to be performed.
- **Requirement Profile** — what kind of capability or suitability the commission wants.
- **Operational Inputs** — what the player actually commits to run the commission.
- **Duration Profile** — how long the commission takes.
- **Risk Profile** — how dangerous or unstable the mission is.
- **Outcome Profile** — how the mission resolves in graded quality bands.
- **Reward Package** — what the player gains on completion.
- **Board Tags** — metadata for generation, variety, weighting, and future systems.
- **Presentation** — the player-facing assembled contract card.

## First 4 commission families

### Retrieval
Recover, extract, or secure something of value.

Examples:
- retrieve inscriptions
- recover sealed records
- reclaim a lost heirloom
- secure rare samples
- recover relic caches

### Escort
Protect a person, caravan, convoy, or shipment during travel.

Examples:
- escort a noble envoy
- guard a merchant caravan
- protect a relic transport
- accompany a scholar delegation

### Survey
Chart, inspect, verify, or assess an area.

Examples:
- chart a pass
- assess ruin stability
- verify a caravan route
- locate a ford
- map a marsh trail

### Security
Secure a location or route, or remove a threat in abstracted off-screen form.

Examples:
- remove bandits from a crossing
- secure a ruin perimeter
- suppress raiders on a route
- drive off dangerous fauna near a caravan path

## Supplies model

### v1 actual supply resource
There is one actual consumable logistics resource in v1:
- **Supplies**

### v1 presentation rule
Commission flavor text may imply specialized preparation such as:
- provisions
- archive kits
- marsh gear
- survey materials
- escort supplies

But these remain presentation wrappers over the same underlying v1 resource: **Supplies**.

### Expansion rule
Typed supply categories are a later expansion only if the base loop proves strong enough to justify added tracking complexity.

## Crew model

Crew is a pooled, recoverable operational resource.

### Crew states
- **Max Crew** — total manpower capacity
- **Available Crew** — ready to assign now
- **Assigned Crew** — currently on active missions or expeditions
- **Recovering Crew** — temporarily unavailable, returns over time

### Crew behavior
- assigning a mission reserves crew
- after completion, most crew returns
- risk, under-preparation, unfamiliar regions, or bad events may send some crew into Recovering
- recovery occurs over time, including while offline
- gold may accelerate recovery

### Design intent
Crew depletion should create pressure, not paralysis.

## Prep-tier model

### Core rule
The player should **not** manually type or fine-tune raw operational numbers for v1. Prep tier should be chosen through a pre-built selector UI.

### Recommended v1 UI
A horizontal 3-step selector, for example:
- **Lean**
- **Standard**
- **Reinforced**

or
- **Under-Prepared**
- **Prepared**
- **Over-Prepared**

### What prep tier controls under the hood
Prep tier modifies:
- crew commitment
- supplies commitment
- outcome weighting
- crew stress / recovery burden
- bonus or negative event odds

### Important v1 lock
Prep tiers are standardized operational presets, not manual per-resource sliders.

## Rare/special item rule

Rare items are **not** part of prep-tier consumption.

### Design rule
Rare or special items act as **global mission modifiers**, not variable per-dispatch consumables.

Examples:
- Detailed Maps -> reduce duration
- Masterwork Armor -> reduce crew recovery burden
- Noble Writ of Passage -> improve escort outcomes
- Survey Charts -> improve survey success bands

This keeps v1 prep readable and avoids premature supply-type explosion.

## First requirement tags

### Officer tags
- `combat_officer`
- `merchant_officer`
- `scholar_officer`
- `scout_officer`

### Mission suitability tags
- `escort_capable`
- `survey_capable`
- `retrieval_capable`
- `security_capable`

### Environmental / prep tags
- `marsh_ready`
- `desert_ready`
- `highland_ready`
- `archive_handling`

### Region knowledge tags
- `region_knowledge_<region_id>_1`
- `region_knowledge_<region_id>_2`

### v1 recommendation
Most commissions should use:
- one core requirement
- one recommended suitability or prep element
- optional region knowledge advantage

Do not overload commissions with too many tags at once.

## Operational Inputs

Operational Inputs replace the earlier idea of a direct preparation gold cost.

### v1 operational input categories
- **Crew Required**
- **Supplies Required**
- optional prep-tier multiplier or shift

### Example structure
- Retrieval: 3 Crew, 1 Supplies
- Escort: 5 Crew, 2 Supplies
- Survey: 4 Crew, 1 Supplies
- Security: 6 Crew, 2 Supplies

## Duration profile

Commissions are the shorter operational loop.

### v1 duration bands
Suggested rough range:
- **Short** — about 10 min
- **Medium** — about 30 min
- **Long** — about 60 min

Longer commission durations can be introduced later, but these should still feel clearly shorter and more active than exploratory expeditions.

## Risk profile

### v1 risk bands
- **Low**
- **Moderate**
- **High**

Risk influences:
- likelihood of reduced payout
- crew recovery burden
- event chance
- sensitivity to poor preparation

### Family tendencies
- Escort skews lower and steadier
- Survey skews low-to-medium
- Retrieval is flexible
- Security skews medium-to-high

## Outcome profile rules

Commissions use graded outcomes, not hard binary success/failure.

### Excellent
- full or slightly boosted payout
- strong standing gain
- little or no crew sent to Recovering
- small chance of bonus reward or event

### Solid
- normal payout
- normal standing gain
- most crew return normally
- baseline expected outcome

### Strained
- reduced payout
- reduced standing gain
- meaningful crew sent to Recovering
- no bonus rewards
- possible mild negative event flavor

### Poor
- heavily reduced payout
- no standing gain or slight standing loss
- significant crew sent to Recovering
- small chance of true attrition if the game later needs it
- no bonus rewards

### Outcome driver rules
Outcome band should be influenced mainly by:
1. prep tier
2. requirement fit / suitability
3. region knowledge
4. risk profile

## Patron tiers and pools

### Tier 1 — Local patrons
Typical role:
- early-game bread-and-butter work
- modest stakes
- practical regional needs
- lower-risk gold generation

Representative pool:
- Village Elder
- Local Merchant
- Minor Noble Household
- Border Reeve
- Small Temple Chapter
- Town Factor
- Road Warden

Typical family bias:
- Escort and Survey first
- Retrieval next
- Security less common

### Tier 2 — Organized institutions
Typical role:
- recurring professional work
- stronger thematic identity
- more specialized asks

Representative pool:
- Merchant Consortium
- Jewelers' Guild
- Mages' Guild
- Scholars' Chapter
- Surveyor's Office
- Caravan League
- Archive Conservators
- Temple Treasury

Typical family bias:
- Retrieval strongest
- then Survey and Escort
- occasional Security work

### Tier 3 — Regional powers
Typical role:
- higher-stakes work tied to routes, order, and strategic access

Representative pool:
- Regional Court
- Frontier Quartermaster
- Military Survey Office
- Governor's Office
- Border March Authority
- Provincial Archives

Typical family bias:
- Security and Escort strongest
- Retrieval and Survey still present

### Tier 4 — Sovereign / grand faction patrons
Typical role:
- aspirational prestige work
- powerful institutions
- stronger payouts
- more demanding readiness expectations

Representative pool:
- Royal Court
- Imperial Envoy
- Grand Mage Conclave
- High Mercantile House
- Sacred Synod
- Crown Cartography Office
- Sovereign Treasury

Typical family bias:
- broad and prestigious, with stronger demand and stronger rewards

## Board composition rules

### v1 board assumptions
- visible offers start at **3**
- generated only from unlocked regions
- accepted offer replenishes one slot
- standard offers persist until accepted or rerolled
- rerolls exist and refresh the full board

### Core composition rules
- The board should not be three fully independent random rolls. It should be curated randomness with soft composition rules.
- Try to avoid duplicate commission families when valid alternatives exist.
- Try to avoid all offers clustering into the same risk band, patron source, or brief style unless the reachable world is still very narrow.
- Try not to collapse all visible commissions into the same region if the player has multiple unlocked regions.
- Whenever possible, keep one slightly more interesting slot on the board: better payout, rarer patron, unusual region, or stronger hook.
- When one commission is accepted, refill only the emptied slot and run the composition checks against the remaining visible offers rather than regenerating the whole board.

## Commission objective templates

The v1 starting set should use **5 templates per family**, for **20 modular starting templates** total.

### Retrieval templates
- Recover Records
- Reclaim Heirloom
- Extract Valuable Material
- Salvage Sealed Goods
- Recover Missing Samples

### Escort templates
- Guard Caravan
- Escort Person of Interest
- Protect Sensitive Transport
- Convoy Support
- Extraction Escort

### Survey templates
- Chart Route
- Verify Passage
- Assess Site Condition
- Identify New Access
- Mark and Record

### Security templates
- Clear Route Threat
- Secure Site Perimeter
- Protect Local Assets
- Suppress Raider Activity
- Guard Work Team

These templates should remain modular authored scaffolding, not long handcrafted questlines. Their job is to produce a board that feels coherent, varied, and region-aware.

## Immediate design consequence

The next milestone after locking commissions should not jump straight into full implementation breadth. The first practical build target should be a **Commission Foundation** slice that establishes the board, patron context, commission family variety, operational inputs, and outcome logic in a deliberately narrow v1 form.
