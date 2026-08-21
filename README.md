# The Fleshborn Chorus

> Gold? Production? Iron? Oil? Happiness? What are those? I require calories.

A playable Civilization V: Brave New World civilization for the Community Patch, led by **the First Maw**.

The Fleshborn Chorus is a deliberately extreme pure-Food civilization. Food is population, construction, expansion, and military supply. Science and Culture still advance technologies and policies, but almost every decision that would normally ask for Production, Gold, Faith, Happiness, or strategic resources returns to the same question:

**Can the organism feed itself?**

## At a glance

- **Civilization:** The Fleshborn Chorus
- **Leader:** The First Maw
- **Unique Ability:** All Is Sustenance
- **Unique Unit:** Devourer Form (Swordsman)
- **Unique Unit:** Harvester (Worker)
- **Unique Building:** Digestive Chamber (Granary)
- **Unique Improvement:** Feeding Field (Farm)
- **Primary victories:** Domination or Science
- **Required mod:** Community Patch
- **Graphics:** Stock placeholder art in version 1
- **Dawn of Man audio:** None—intentionally silent

## All Is Sustenance

The Chorus cannot spend normal Production and cannot construct World Wonders. Every Brood Node has an invisible `-100% Production` metabolic state plus a dynamic sink that cancels its whole raw hammer yield; the Food ledger restores only its own exact saved progress, so fractional engine Production and positive modifiers cannot reopen the economy. Mines, quarries, workshops, chops, and other sources of hammers cannot advance a Fleshborn order.

Instead, choose what the city should grow:

| Growth choice | Food cost | Result |
| --- | ---: | --- |
| **Grow Population** | Normal city growth | All usable Food remains in the growth store |
| **Unit** | 100% of its normal Production cost | Food becomes unit progress; population growth freezes |
| **Building / Project** | 125% of its normal Production cost | Food becomes project progress; population growth freezes |
| **Colony Bud** | 120% of Settler cost | Also removes 1 Population when completed |
| **World Congress project** | 1 Food per contribution | Food is staged as isolated Congress overflow; population growth freezes |

The production list is the Growth Queue. Select the explicit **Grow Population** process when a city should grow Citizens. Select a unit or building when its surplus should be diverted into a project. The normal CityView still uses hammer-shaped widgets in this placeholder release; the **Chorus metabolism button** near the top-right of the main screen shows the actual Food allocation and estimated Food cost.

The **Digestive Chamber** reduces every unit, building, and normal project’s Food cost by 10% in its city. Congress contributions remain a direct 1:1 conversion.

Population growth is stopped at the population-change callback while any project is selected, and the pre-turn Food store is restored immediately. Unit, building, and project completion also requires a short-lived authorization written by the Food ledger. This closes normal hammers, feature chops, Great Engineer hurry, purchases, and other direct-Production completion paths rather than repairing their effects a turn later.

### What “surplus Food” means

The system begins with the city’s normal Food difference, then subtracts biological burdens:

```text
Usable Food = normal Food surplus
            - city metabolism
            - citizen metabolism
            - specialist metabolism
            - allocated army feeding
```

If a human-controlled city grows a project, its stored population-growth Food is frozen. It resumes from that amount when **Grow Population** is selected again. Project progress is stored per order, so switching between organisms does not let normal Production leak into either one.

## Metabolic Burden

Happiness does not limit the Chorus. Food does.

Every city consumes:

- **3 Food per turn** for the Brood Node itself;
- **0.5 Food per Citizen**, rounded up per city;
- **1 additional Food per Specialist**.

The **Founding Core** in the current capital contributes +4 Food. The Chorus also begins with a Harvester, allowing the First Stomach to create its first Feeding Field instead of becoming trapped by metabolism before any agricultural infrastructure exists. This safeguard belongs only to the current capital; every additional Brood Node pays the complete expansion burden.

The trait removes ordinary city and population unhappiness plus military and improvement maintenance. A hidden Community Patch dummy policy zeros universal unit upkeep—including civilian and air units—and supplies the purchase gates. Lua clamps the treasury’s real base building maintenance to zero at load, construction, capture, turn processing, and end turn, with the same policy providing a -100% building fallback. The policy is excluded from policy count, score, policy cost, and ideology checks. The DLL clamps unit upkeep and base building maintenance at zero, so no nominal Gold refund or negative-maintenance income is created. Occupied cities are treated as organs, not discontented populations.

This makes wide expansion expensive in the same currency used for everything else. A new Brood Node is a mouth before it is a stomach.

## Military feeding and The Hunger

Every military unit adds to an empire-wide feeding requirement based on the era of its prerequisite technology:

| Era | Food per military unit |
| --- | ---: |
| Ancient | 0.5 |
| Classical | 0.5 |
| Medieval | 1 |
| Renaissance | 1 |
| Industrial | 1.5 |
| Modern | 2 |
| Atomic / Postmodern | 2.5 |
| Information / Future | 3 |

Fractional costs are summed empire-wide and rounded once. Available post-metabolism surplus feeds the army before it can grow population or projects.

If the empire cannot meet the requirement, military units gain **The Hunger**. Each 10% band of unmet feeding applies:

- **-3% Combat Strength**, up to -30%;
- progressively reduced healing;
- at tier 7 or higher, no new military organisms can be grown.

Units are not automatically killed. A starving Chorus becomes weak rather than entering an unavoidable deletion spiral.

This creates the intended counterplay: pillage Feeding Fields, Plantations, Fishing Boats, and Food trade routes. An army that cannot be defeated head-on can still be starved.

## No strategic resources

Horses, Iron, Coal, Oil, Aluminum, and Uranium are inedible map objects. The Chorus does not need them.

At database load, the mod finds every default unit and building in the active BNW/Community Patch roster that consumes a strategic resource and creates a civ-specific biological copy without that requirement. Copies retain the active rules and stock placeholder presentation. Unit copies keep their combat statistics, AI roles, promotions, prerequisites, and upgrade path. Common unit copies receive biological names such as:

- Hunter Beast;
- Ripper Form;
- Behemoth;
- Skyhunter;
- Blightwing;
- Leviathan;
- Apex Warform;
- Star Womb and Void Heart.

This dynamic roster also handles Community Patch changes and spaceship components without granting fake strategic resources to the player. Resource-consuming infrastructure receives biological equivalents as well: Factory becomes **Industrial Stomach**, Hydro Plant becomes **Current Organ**, Nuclear Plant becomes **Fission Cyst**, and Spaceship Factory becomes **Ascension Womb**. Captured or gifted cities normalize base versions into the Chorus replacement before resource consumption is evaluated.

Captured units use the Community Patch capture-type hook to become the Chorus replacement for their unit class. Gifted and pre-existing foreign units are normalized on the next metabolic update, preserving their state through the DLL conversion routine. Captured Workers therefore become Harvesters, while captured strategic units cannot leave a hidden Iron, Oil, or Aluminum dependency behind. Conventional Gold upgrades are disabled: later organisms must be grown through Food.

## Gold, Faith, and religion

Gold and Faith cannot become secondary economies.

- Every **4 Gold** becomes **1 stored Food**.
- Every **3 Faith** becomes **1 stored Food**.
- Converted Food is spread as evenly as possible across all Brood Nodes.
- Unconverted remainders stay in the treasury until another complete conversion is possible.
- The Chorus cannot found a Pantheon or Religion.
- Gold/Faith unit and building purchases, automatic Faith purchases, Gold unit upgrades, and Gold tile purchases are disabled.

Trade deals, foreign trade routes, city-state rewards, and Great Merchant Gold are therefore not completely worthless, but they are badly inefficient beside agriculture. Science and Culture remain normal progression outputs.

Internal Production and internal Gold routes are unavailable; the Chorus can send Food internally. International routes remain available, with any Gold they return entering normal digestion.

## Unique components

### Feeding Field

Replaces the Farm and uses stock Farm graphics for now.

- +1 Food base;
- +1 Food with Fresh Water;
- +1 Food at Civil Service;
- +1 Food at Fertilizer;
- a **worked** Feeding Field with at least three adjacent Feeding Fields gains +1 Food, capped at +1;
- may be constructed while preserving Marsh;
- Sugar, Bananas, and Citrus worked under a Plantation provide +2 additional Food to the city.

The adjacency yield is applied through a hidden city Food counter, so it is included in city output even though the stock tile tooltip cannot display the custom adjacency line.

### Digestive Chamber

Replaces the Granary.

- retains the active Community Patch Granary’s Food effects;
- has no maintenance;
- keeps an additional 15% Food after population growth;
- reduces Food spent per point of unit, building, or project progress by 10%.

### Devourer Form

Replaces the Swordsman with the same base combat profile and no Iron requirement.

When a military unit dies with a Fleshborn Devourer adjacent to it, the nearest Brood Node receives Food equal to 25% of the victim’s Combat or Ranged Combat Strength. The reward is queued safely for the next metabolic update.

### Harvester

Replaces the Worker, and one Harvester accompanies the initial Colony Bud. It builds Feeding Fields, Roads, and other normal non-Farm improvements.

Its digestion actions remove a feature and feed the nearest city:

- Forest: **20 Food**;
- Jungle: **15 Food**;
- Marsh: **12 Food**.

Unlike a normal forest chop, this never creates Production.

### Colony Bud

Replaces the Settler.

- costs about 120% of normal Settler cost in Food;
- cannot be grown by a size-1 city;
- removes 1 Population from its parent when completed;
- founds a normal mechanically functional city presented as a Brood Node.

## Culture, Golden Ages, and AI

Each Brood Node receives **+1 Culture**, plus another +1 Culture per five Population, representing collective instinct and inherited memory. Normal population Science remains the main path from Food to technology.

Golden Ages function as **Blooming Cycles** and give every Brood Node +10% Food. This release keeps the stock Golden Age label outside the metabolism panel.

Luxury Happiness remains visible in the stock interface, but its normal per-turn contribution to the Golden Age meter is removed. Golden Age points from policies, wonders, and Great People still work, so Blooming Cycles remain possible without turning luxuries into a second managed economy.

The Golden Age filter uses a one-turn meter reservation instead of subtracting from the aggregate meter after the fact. The next Happiness tick pays back that reservation, while unrelated meter gains remain intact and Happiness cannot silently push the meter over its threshold first.

The explicit growth process and active World Congress processes are the only processes available to the Chorus. World’s Fair, International Games, and International Space Station contributions consume Food and reach the normal League system, so their rewards and rankings remain compatible with Community Patch behavior. Congress conversion carries fractional hundredth-hammer credit or debt between turns, preserving the 1:1 rate over time without allowing rounding residue to become a second economy.

Human players make a hard city-by-city choice between population and projects. AI players use an automated approximation of the design targets:

- about 40% of usable Food goes to a selected project at peace;
- about 60% goes to Colony Buds;
- about 70% goes to military projects during war;
- severe Hunger disables military growth.

The remainder stays available for AI population growth, preventing the normal AI production chooser from accidentally freezing every city forever.

## Installation

### Build and deploy with ModBuddy

1. Install the Civilization V SDK and the **Community Patch** for Civilization V: Brave New World.
2. Open `TheFleshbornChorus.civ5sln` in ModBuddy (or open `TheFleshbornChorus.civ5proj` directly).
3. In the project properties, verify **Civilization V Path** and **Civilization V User Path** if the game or Documents folder is not in the default location recorded by the project.
4. Choose **Build > Build Solution** to generate the mod, or **Build > Deploy Solution** to copy it into Civilization V's `MODS` directory.
5. Start Civilization V, open **MODS**, and enable the Community Patch and **The Fleshborn Chorus** before beginning a new game.

ModBuddy writes the generated manifest and deployable files under the sibling `Build\The Fleshborn Chorus` directory. The checked-in `The Fleshborn Chorus (v 1).modinfo` remains a standalone source-tree manifest for manual installs; ModBuddy regenerates its own equivalent manifest when the project builds.

### Manual source-tree install

1. Install and enable the **Community Patch** for Civilization V: Brave New World. It is a hard manifest dependency; the Chorus will not load ahead of or without it.
2. Copy this repository folder into:

   ```text
   Documents\My Games\Sid Meier's Civilization 5\MODS\The Fleshborn Chorus (v 1)
   ```

3. Start Civilization V, open **MODS**, enable the Community Patch and **The Fleshborn Chorus**, then begin a new game.
4. Do not add the mod to an existing save; it changes database definitions and save data.

The mod is designed for single-player. Multiplayer and Hot Seat are disabled in the manifest because the growth ledger and UI have not yet been network-synchronization tested.

## Placeholder presentation

Version 1 intentionally reuses stock Civilization V assets:

- Washington/America leader and civilization presentation;
- stock unit models, flags, and icons;
- Farm art for Feeding Fields;
- Granary/Worker/Swordsman/Settler icons for the named uniques.

No custom audio is installed, audio reload is disabled, and the civilization’s `DawnOfManAudio` value is explicitly empty. The Dawn of Man screen is silent by design.

## Repository layout

```text
The Fleshborn Chorus (v 1).modinfo  Mod manifest and hard CP dependency
TheFleshbornChorus.civ5sln          ModBuddy solution
TheFleshbornChorus.civ5proj         ModBuddy project; build or deploy this file
SQL/00_Fleshborn_Core.sql           Civilization, units, buildings, improvement, promotions
SQL/10_Fleshborn_Text.sql           English text and Civilopedia entries
Lua/FleshbornCore.lua               Food economy and Community Patch event systems
UI/FleshbornStatusPanel.xml         In-game metabolism panel layout
UI/FleshbornStatusPanel.lua         Panel data and interaction
PATCH_NOTES.md                      Release history, known limitations, and next work
```

See [PATCH_NOTES.md](PATCH_NOTES.md) for the exact version 1 implementation scope and known placeholder-era limitations.
