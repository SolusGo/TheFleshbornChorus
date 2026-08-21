# The Fleshborn Chorus — Patch Notes

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

- All graphics are placeholders. Biological unit copies deliberately reuse the base unit model and icon.
- The stock CityView still calls the order list “Production” and displays hammer-shaped cost/progress widgets. The metabolism panel is authoritative for Food costs.
- Feeding Field adjacency is a hidden city yield. The bonus appears in total city Food but not on the individual tile tooltip.
- The normal top bar remains visible. Gold and Faith are digested at the start of the Chorus turn rather than being graphically removed from the top bar.
- Gold or Faith received during the active turn can briefly exist until the next metabolic update, but purchase, tile-buy, automatic-Faith, upgrade, and completion gates prevent it becoming a spending window. Ordinary conversion leaves at most 3 Gold and 2 Faith.
- Happiness UI remains visible even though standard city/population unhappiness is neutralized and its per-turn Golden Age contribution is removed.
- Conquered buildings without a Fleshborn class override keep their normal definitions; their maintenance is suppressed rather than refunded. Granaries and strategic-resource infrastructure normalize into their biological replacements.
- Great People retain stock names and mission UI. Great Merchant Gold is handled by normal 4:1 digestion rather than a bespoke Foraging Migration mission.
- Foreign trade routes keep their stock yield display; Gold is subsequently digested and Science remains normal.
- The release is single-player only and has not been tested for multiplayer synchronization.

## Planned follow-up work

- Custom civilization, leader, unique-component, unit, and Feeding Field artwork.
- A fully reskinned CityView that labels the queue and progress as Food rather than Production.
- Top-panel presentation that hides irrelevant economies and renames Golden Ages to Blooming Cycles.
- Dedicated biological names and help text for every non-resource military class.
- Great Person biological presentation and a custom Great Merchant Food mission.
- Direct trade-route yield presentation and deeper AI tuning from live game telemetry.
- Balance passes after games on lush, average, and food-poor starts.
