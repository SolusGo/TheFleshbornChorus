# The Fleshborn Chorus — Patch Notes

## 2026-08-23 — Metabolism UI clarity pass

- Reorganized the ledger into a four-stage current-turn Food flow: entering Food, fixed costs, project allocation, and Food remaining after projects.
- Added a prominent empire condition with distinct Fed, Balanced, Fully Committed, Strained, and Hungry explanations.
- Expanded army feeding into its own section with supplied/required Food, coverage percentage, Hunger tier, and exact Combat Strength penalty.
- Reworked Brood Node entries to show a colored local condition, local Food equation, selected mode, progress percentage, current allocation, and estimated turns at the latest rate.
- Added an empire city summary, turn stamp, contextual card tooltips, and a dynamic map-button tooltip.
- Hardened observer and invalid-active-player handling so the Chorus-only controls remain hidden safely when no normal player is active.
- Extended repository validation to catch missing Lua controls, duplicate XML IDs, unsupported fonts, and layouts larger than the 1024×768-safe panel envelope.
- Retained only supported Civ V fonts and controls; no custom font XML or audio was added.

## 2026-08-22 — Renderer-proof Feeding Fields

- Changed the Fleshborn-only construction action to place Civ V's genuine `IMPROVEMENT_FARM` on the map. The game loaded the prior direct Farm art tag correctly but its landmark renderer still refused to draw the distinct improvement type.
- Kept the Feeding Field build name, custom icon, Civilopedia entry, Harvester restriction, Food scaling, and worked-field adjacency rules; Fleshborn-owned Farms are now treated as Feeding Fields by Lua.
- Preserved the intended +1 Fresh Water, Civil Service, Fertilizer, and adjacency Food rules by adding only the bonuses missing from the active Community Patch Farm yield.
- Added automatic save migration: legacy invisible Feeding Fields become visible stock Farms when a save finishes loading, including pillaged fields. A new game is not required.
- Added a context-sensitive CP hex-tooltip layer so the rendered improvement is still called **Feeding Field** in game. Only Chorus-owned fields are relabeled; ordinary Farms belonging to other civilizations are unchanged.
- Extended database validation to require the custom Harvester action to produce a real Farm.

## 2026-08-22 — Feeding Field renderer fallback and icon audit

- Replaced the Feeding Field's cloned landmark tag with a direct reference to Civ V's stock `ART_DEF_IMPROVEMENT_FARM` tag. The cloned rows existed correctly in the database but the landmark renderer still ignored the new tag; direct reuse now takes the exact normal Farm construction, completed, pillaged, resource, era, and Strategic View graphics.
- Removed stale custom Feeding Field landmark rows during database activation so an updated installation cannot retain the failed registration.
- Audited all 21 Fleshborn icon-atlas declarations against their DDS files. Civilization, leader, unit, building, improvement, promotion, and alpha textures now have exactly `IconSize × IconsPerRow/IconsPerColumn` dimensions at every declared resolution.
- Confirmed the Dawn of Man image is 1024×768, map image is 360×412, and static diplomacy image is 1600×900, matching Civ V and the inspected custom civilizations.
- Rebuilt the civilization alpha atlas as a transparent white maw emblem. The previous version incorrectly contained a grayscale copy of the entire framed color badge, unlike Civ V's normal alpha-symbol treatment.
- Extended `Tools/validate_database.py` to reject mismatched atlas dimensions, presentation-image dimensions, missing DDS files, or a Feeding Field that is no longer wired to stock Farm art.

## 2026-08-22 — Food-budget UI and font hotfix

- Rebuilt the metabolism panel around an empire-wide current-turn Food budget: base city surplus, queued/digested Food, city metabolism, army feeding, project spending, and Food still available after projects.
- Added an explicit usable-Food equation, army fed-versus-required status, unmet feeding warnings, locally strained Brood Node count, empire stored growth Food, and current Gold/Faith digestion.
- Reworked each city entry to show its selected growth mode, local budget, project allocation or population-growth store, and remaining Food in a consistent order.
- Changed the map button from a generic fed label to the current available Food total; it still switches to the Hunger tier whenever army feeding is deficient.
- Corrected the misleading `Gross Food` wording to `Base Surplus`; this value is Civ V's city Food difference after ordinary citizen consumption, with the Founding Core already included.
- Fixed the **Could not load font xml file** popup. The ledger requested the nonexistent `TwCenMT17` font; it now uses Civ V's supported `TwCenMT16` asset.

## 2026-08-21 — Custom artwork and civilization colors

- Added native DDS atlases for the supplied civilization emblem, First Maw leader portrait, biological unit portraits, Digestive Chamber, Feeding Field, and all ten Hunger tiers.
- Added the supplied Civ V-style Dawn of Man scene, world-map panel, and a static First Maw diplomacy backdrop. Dawn of Man audio remains explicitly empty and the audio system is still not reloaded.
- Added a custom civilization alpha atlas for unit flags, city banners, score entries, and strategic presentation.
- Changed the player palette to deep Chorus purple with an acidic bone-gold secondary color, affecting territory borders, banners, unit flags, and map identity.
- Added civilization-specific Warrior, Archer, Crossbowman, and Musketman copies named Hunter Form, Spitter Form, Spinecaster, and Warform. They inherit active Community Patch gameplay data and stock 3D models while using the supplied portraits.
- Applied matching portraits to Devourer/Ripper forms, armored Behemoths, Skyhunters, Blightwings, Leviathans, Harvester, Colony Bud, Digestive Chamber, Feeding Field, and The Hunger.
- Selected Colony Bud v2 for the active unit portrait and the Civ V-style landscape for Dawn of Man; preserved every supplied original and alternate under `Art/Source`.
- Added `Tools/build_art.py` so every DDS texture and atlas can be rebuilt reproducibly from the source PNGs.

## 2026-08-21 — City-state and progression compatibility audit

- Blocked Gold gifts, Gold-funded city-state tile improvements, and diplomatic buyouts for the Chorus, closing city-state spending paths that existed outside the ordinary city purchase hooks.
- Added immediate digestion for city-state first-contact gifts and Gold tribute. Militaristic gifts and tribute units now normalize to their biological unit-class replacement immediately.
- Preserved quests, influence, spies, elections, alliances, unit gifting, bullying, and diplomatic victory interactions. Food, Science, Culture, free-unit, free-building, and Population rewards remain valid, while Production still cannot authorize a queue completion.
- Verified the hidden invariant policy remains a Community Patch dummy and does not affect policy costs, branch completion, score, or ideology eligibility.
- Verified Factory-gated ideology effects use the building class and therefore recognize the Industrial Stomach replacement.
- Kept policy and ideology effects that directly convert Happiness into Science or Culture as progression bonuses; they do not restore Happiness as a construction, upkeep, purchasing, expansion, or passive Golden Age economy.
- Fixed human puppets spending their entire usable Food on an autonomous order and then having all population growth rolled back. Puppets and AI cities now apply their intended partial project allocation and can grow from the remainder.
- Added cleanup and initialization for peacefully transferred, conquered, and liberated cities so hidden metabolic buildings cannot leak to a non-Chorus owner or be absent from a restored Chorus city.
- Fixed the metabolism panel's repeated `CalculateSize` Lua error by allowing its wrapped label to size itself before the scroll panel recalculates.
- Corrected the ModBuddy project to this installation's actual Civilization V path.

## 2026-08-21 — Feeding Field map graphics

- Fixed completed Feeding Fields appearing without a worked improvement model on the world map.
- Added a dedicated Feeding Field art-definition tag and cloned every active Farm landmark row, preserving construction, completed, pillaged, resource-specific, and era-specific stock models.
- Added the stock Farm Strategic View asset under the Feeding Field art tag.
- Enabled landmark and Strategic View system reloads in both the ModBuddy project and standalone manifest so the new registration is loaded reliably.
- Added no custom graphics or audio; Dawn of Man audio remains empty and audio reload remains disabled.

## 2026-08-21 — Ancient Ruins compatibility

- Enabled the Community Patch goody-choice event used for civilization-specific reward filtering.
- Prevented Ancient Ruins from granting the Chorus free Population, a free Settler/Colony Bud, or direct Production; the DLL rerolls those results into another eligible reward instead of producing an empty ruin.
- Built the blocked-reward set from the active `GoodyHuts` fields, covering compatible ruin mods and alternate CP configurations without hard-coded reward IDs.
- Retained Gold and Faith rewards for normal digestion and retained safe Culture, Technology, exploration, healing, experience, promotion, and information rewards.
- Retained the Settler-difficulty Worker reward, which resolves through the civilization override into a Harvester.
- Verified from the CP 5.4.2 DLL source that ruin upgrades select the civilization-specific unit type before conversion; biological strategic-unit replacements therefore remain valid rewards without a delayed normalization window.

## 2026-08-21 — Founding metabolism hotfix

- Fixed the size-one capital deadlock shown by the metabolism panel: ordinary starting Food could be lower than city metabolism before the player had any means to create a Feeding Field.
- Added a hidden **Founding Core** that contributes +4 Food to the current capital only.
- Added one starting Harvester so the Chorus can establish its first Feeding Field immediately.
- Added a Founding Core line to the metabolism ledger so the capital bonus is explicit rather than hidden inside Gross Food.
- Left the full city, Citizen, Specialist, and army burdens intact for established play and all non-capital Brood Nodes.

## 2026-08-21 — ModBuddy project conversion

- Added `TheFleshbornChorus.civ5proj`, which opens directly in the Civilization V SDK's ModBuddy environment.
- Mirrored the existing mod identity, version, database action order, single-player support, and both in-game UI add-ins.
- Kept the Community Patch as a hard versioned dependency rather than weakening it to an optional reference.
- Added every source and documentation file to the project while leaving database scripts and UI entry points outside the virtual file system as required by their ModBuddy content types.
- Kept all audio reload settings disabled and added no Dawn of Man audio asset.
- Documented ModBuddy build/deploy and manual source-tree installation paths in the README.

## 2026-08-21 — Invariant hardening

This pass closes the failure modes found during the first full static and Community Patch source audit.

### Queue and Production safety

- Added a synchronous population-change guard: a city on any grown order cannot complete normal population growth before Lua restores its frozen Food store.
- Added end-turn Food snapshots, including save/load and newly captured-city baselines, so a project selected after the metabolic tick is protected on the very next city turn.
- Added expiring Food-ledger authorization for unit, building, and project completion. Unauthorized normal-Production and purchase completions are rejected.
- Added a whole-hammer Production sink plus exact per-order ledger restoration, preventing positive modifiers and hundredth-hammer rounding from advancing ordinary orders.
- Disabled Great Engineer hurry in Chorus hands and blocked conventional Gold unit upgrades.
- Blocked internal Production and internal Gold trade routes, leaving Food as the only internal cargo yield.
- Blocked standard Forest, Jungle, and Marsh removal actions for every Fleshborn-owned worker; only Harvester digestion can turn those features into progress.
- Isolated save keys by owner, city ID, acquisition turn, and coordinates to prevent razed, captured, or recycled city IDs from inheriting stale progress.

### Currency, maintenance, and Happiness

- Replaced nominal capital maintenance refunds by clamping the treasury’s actual base building maintenance to zero, with an engine-level -100% fallback.
- Moved purchase restrictions, universal unit upkeep, and the building-maintenance fallback into a Community Patch `IsDummy` policy, which is excluded from policy counts and progression checks. This closes civilian and air-unit upkeep that the land/naval trait fields do not cover; the DLL clamps the result at zero.
- Made Gold/Faith unit and building purchases prohibitively unavailable, disabled automatic Faith purchases, blocked Gold plot buying, and retained completion-hook rejection as a final guard.
- Replaced aggregate Golden Age meter subtraction with a one-turn Happiness reservation that preserves unrelated Golden Age points and prevents threshold crossings.

### Congress, rewards, capture, and upkeep

- Re-enabled World’s Fair, International Games, and International Space Station processes.
- Added a 1 Food to 1 Congress-contribution bridge using isolated overflow read by the normal Community Patch League update, with a fractional credit/debt ledger that charges residual native Production against later Food.
- Counted queued digestion, terrain, and Devourer rewards as army food before calculating The Hunger; rewards can now save an army on the turn they are consumed.
- Added Community Patch capture-type conversion for Fleshborn unit-class replacements and turn-safe normalization for gifted or pre-existing foreign units.
- Captured Workers become Harvesters; captured strategic units become their biological class replacement and no longer retain resource requirements.
- Added dynamic biological replacements for every default building that consumes a strategic resource, including Factory, Hydro Plant, Nuclear Plant, and Spaceship Factory, plus captured-city building normalization.
- Added immediate metabolic initialization for captured cities and bounded the kill de-duplication cache to the current game turn.

### Loading and presentation

- Changed the Community Patch from a load-order reference to a hard dependency.
- Updated the metabolism panel for suppressed maintenance, queued Food, and Congress allocation.
- Kept placeholder graphics and the intentionally empty Dawn of Man audio unchanged.

## Version 1 — Initial organism

The first playable Community Patch release establishes the complete core loop: Food can grow population, infrastructure, expansion, or an army, and the size of that army feeds back into the same Food supply.

### Civilization shell

- Added the Fleshborn Chorus, led by the First Maw.
- Added the **All Is Sustenance** trait and full English Civilopedia/strategy text.
- Added Grassland starting-region priority and 20 Brood Node city names.
- Added aggressive Expansion/Offense/Growth AI flavors with no Wonder interest.
- Reused stock America/Washington presentation as placeholder graphics.
- Explicitly set `DawnOfManAudio` to an empty value.
- Disabled audio, landmark, strategic-view, and unit-system reloads.

### Pure Food economy

- Added a permanent -100% Production modifier to every Fleshborn city.
- Added per-order saved progress so normal hammers cannot leak into projects.
- Added **Grow Population** as an explicit growth-queue process.
- Units convert Food at 1:1 with normal Production cost.
- Buildings and projects require 125% of normal Production cost in Food.
- Colony Buds require 120% of normal Settler cost in Food.
- Human project cities freeze their population-growth store until Grow Population is selected again.
- Added Digestive Chamber 10% project discount with integer remainder tracking.
- Blocked World Wonder construction.

### Metabolism

- Added 3 Food per-city burden.
- Added 0.5 Food per-Citizen burden, rounded up by city.
- Added 1 Food per Specialist burden.
- Removed ordinary city and population unhappiness through trait/city modifiers.
- Removed excess Happiness contribution to the Golden Age meter while preserving non-Happiness Golden Age sources.
- Removed land, naval, road, and improvement maintenance through trait modifiers.
- Added the original calculated capital Gold maintenance refund (replaced by the engine-level modifier in the hardening pass above).
- Added +1 Culture per city and +1 per five Population.
- Added +10% Food during Golden Ages/Blooming Cycles.

### Currency and religion

- Added 4 Gold to 1 Food digestion.
- Added 3 Faith to 1 Food digestion.
- Distributed digested Food evenly between living cities.
- Preserved incomplete Gold/Faith conversion remainders.
- Blocked Pantheon and Religion founding for the Chorus.

### Army feeding and The Hunger

- Added era-scaled Food upkeep from 0.5 to 3 Food per military organism.
- Summed fractional upkeep empire-wide before rounding.
- Allocated feeding burden across cities according to post-metabolism surplus.
- Added ten Hunger promotion tiers, from -3% to -30% Combat Strength.
- Added progressively reduced healing at higher tiers.
- Disabled new military growth at tier 7 or above.
- Added active-player notifications when Hunger begins, changes tier, or ends.
- Added AI allocation support: 40% peace projects, 60% Colony Buds, and 70% wartime military.

### Strategic-resource replacement roster

- Added an SQL-generated biological copy of every active default unit that requires a strategic resource.
- Removed strategic-resource requirements, Faith purchase, and maintenance from each copy.
- Copied AI roles, upgrade paths, flavors, free promotions, requirements, sounds, and other unit associations.
- Added biological names for the stock BNW/Community Patch mounted, armored, naval, air, nuclear, and spaceship roster.
- Kept all stock models and icons as placeholders.

### Unique components

- Added **Devourer Form**, a resource-free Swordsman replacement.
- Added adjacent military kill rewards equal to 25% of victim strength as queued Food.
- Added **Harvester**, a maintenance-free Worker replacement.
- Added Forest/Jungle/Marsh digestion for 20/15/12 Food.
- Added **Colony Bud**, a Settler replacement that removes 1 Population on completion.
- Prevented size-1 cities from growing Colony Buds.
- Added **Digestive Chamber**, a maintenance-free Granary replacement with +15% Food kept and project discount.
- Added **Feeding Field**, a Farm replacement with Fresh Water, Civil Service, and Fertilizer scaling.
- Added worked Feeding Field cluster bonus for three adjacent fields, capped at +1 per central field.
- Added +2 Food for worked Sugar, Banana, or Citrus Plantations.
- Allowed Feeding Fields to preserve Marsh.
- Blocked normal Farms for Fleshborn-owned workers.

### Interface and save handling

- Added the in-game **Chorus metabolism** button and status ledger.
- Added empire army requirement, feeding, Hunger, and currency-digestion readouts.
- Added city gross Food, metabolism, army allocation, usable Food, current order, project progress, estimated Food cost, and Digestive Chamber readouts.
- Stored frozen Food, per-order progress, fractional conversion credit, pending Food rewards, and Hunger tier in Civ V save data.
- Added safe load initialization that refreshes hidden city state without granting an extra project tick.

## Known limitations in version 1

- 3D unit and Feeding Field landmark models remain stock placeholders. Their interface portraits and civilization presentation are now custom.
- The stock CityView still calls the order list “Production” and displays hammer-shaped cost/progress widgets. The metabolism panel is authoritative for Food costs.
- Feeding Field adjacency is a hidden city yield. The bonus appears in total city Food but not on the individual tile tooltip.
- The normal top bar remains visible. Gold and Faith are digested at the start of the Chorus turn rather than being graphically removed from the top bar.
- Gold or Faith received during the active turn can briefly exist until the next metabolic update, except first-contact and tribute Gold which are digested immediately. Purchase, city-state spending, tile-buy, automatic-Faith, upgrade, and completion gates prevent it becoming a spending window. Ordinary conversion leaves at most 3 Gold and 2 Faith.
- Happiness UI remains visible even though standard city/population unhappiness is neutralized and its per-turn Golden Age contribution is removed.
- Policy and tenet effects that explicitly convert Happiness into Science or Culture remain active for compatibility. This is a narrow exception to the fiction that luxuries are wholly irrelevant, but it does not make Happiness spendable or restore its normal expansion and Golden Age roles.
- Conquered buildings without a Fleshborn class override keep their normal definitions; their maintenance is suppressed rather than refunded. Granaries and strategic-resource infrastructure normalize into their biological replacements.
- Great People retain stock names and mission UI. Great Merchant Gold is handled by normal 4:1 digestion rather than a bespoke Foraging Migration mission.
- Foreign trade routes keep their stock yield display; Gold is subsequently digested and Science remains normal.
- The release is single-player only and has not been tested for multiplayer synchronization.

## Planned follow-up work

- Custom 3D biological unit and Feeding Field landmark models.
- A fully reskinned CityView that labels the queue and progress as Food rather than Production.
- Top-panel presentation that hides irrelevant economies and renames Golden Ages to Blooming Cycles.
- Dedicated biological names and help text for every non-resource military class.
- Great Person biological presentation and a custom Great Merchant Food mission.
- Direct trade-route yield presentation and deeper AI tuning from live game telemetry.
- Balance passes after games on lush, average, and food-poor starts.
