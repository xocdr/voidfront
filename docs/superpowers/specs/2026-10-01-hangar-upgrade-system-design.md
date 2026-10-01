# Hangar Upgrade System & 2.5D Isometric Presentation — Design

**Status:** Approved for planning
**Scope:** Architectural — new data model, new autoload, rebuilt hangar screen

## 1. Goal & Context

Replace the current hangar (`src/ui/hangar_menu.gd`), which only lets the player
switch between 3 whole, pre-made ships, with:

1. A real per-category upgrade/equipment system (not just whole-ship swapping).
2. A hangar presentation that *feels* like a 3D aircraft-customization bay
   (Ace Combat-style) while staying entirely within the project's existing 2D
   architecture — no Camera3D/Node3D, no new 3D asset pipeline.
3. A minimal credits economy and the project's first disk save system, since
   neither currently exists.

This intentionally narrows the originally-requested 9 upgrade categories down
to **4 for this vertical slice: Weapons, Engine, Shield, Armor** — architected
so additional categories (Hull, Energy, Thrusters, Utility, Special, …) can be
added later with no core-system rewrite.

### Non-goals (explicitly out of scope)

- True 3D rendering, 3D ship models, or a 3D camera/orbit control.
- A full in-game economy/store beyond "earn credits on mission complete, spend
  on upgrades."
- Player levels / XP as a separate progression axis (mission-unlock gating
  only, matching the existing `unlock_mission_id` pattern).
- Automated tests (project has none; verification is manual, per `CLAUDE.md`).

## 2. Data Model

### `UpgradeData` (new `Resource`, `src/player/upgrade_data.gd`)

```gdscript
class_name UpgradeData
extends Resource

@export var id: String = ""
@export var category: String = ""        # "weapons" | "engine" | "shield" | "armor" (plain string — new categories need no schema change)
@export var display_name: String = ""
@export var description: String = ""
@export var tier: int = 0                 # 0 = starter/free item for the category. Progression/ordering value ONLY — never conflated with a player level.
@export var cost: int = 0                 # credits; tier 0 is always cost 0
@export var required_mission_id: int = 1  # unlock gate, same pattern as ShipLoadoutData.unlock_mission_id
@export var stat_modifiers: Dictionary = {}  # e.g. {"fire_cooldown": -0.02, "special_damage": 15.0}
```

### `UpgradeRegistry` (new static class, `src/player/upgrade_registry.gd`)

Mirrors `ShipLoadoutRegistry`/`MissionRegistry`'s static-factory pattern.

```gdscript
class_name UpgradeRegistry
extends RefCounted

static func get_categories() -> Array[String]  # ["weapons", "engine", "shield", "armor"] — single source of truth; UI never hardcodes this list
static func get_upgrades(category: String) -> Array[UpgradeData]
static func get_upgrade(id: String) -> UpgradeData  # null if not found
static func get_starter_upgrade(category: String) -> UpgradeData  # the tier-0 item for that category
```

Each category needs at least a tier-0 (free, always owned/unlocked) item and
1-2 additional tiers for this slice (e.g. Weapons: Basic Cannon → Plasma
Cannon; Engine: Basic Engine → Ion Engine; etc.) — enough to exercise the full
purchase/equip flow without building out a large item list.

### `ShipEquipmentState` (new `Resource`, `src/player/ship_equipment_state.gd`)

One instance per ship loadout id.

```gdscript
class_name ShipEquipmentState
extends Resource

@export var ship_id: String = ""
@export var owned_upgrade_ids: Array[String] = []
@export var equipped: Dictionary = {}  # category (String) -> upgrade_id (String)
```

`equipped` always has one entry per `UpgradeRegistry.get_categories()` entry —
no category is ever absent or null. Deterministic default: every category's
`equipped` value is its tier-0 upgrade, and that tier-0 id is included in
`owned_upgrade_ids`.

### `GameState` additions (`src/autoloads/game_state.gd`)

```gdscript
var credits: int = 0
var equipment: Dictionary = {}  # ship_id (String) -> ShipEquipmentState
```

`equipment[ship_id]` is built lazily via one function,
`GameState.get_equipment_for(ship_id: String) -> ShipEquipmentState`, which
creates and stores a deterministic default (per above) the first time a given
`ship_id` is accessed. This function is the **only** place default equipment
is constructed — `SaveManager`'s "no save file" path and any other caller all
go through it, so there is exactly one definition of "default state"
(see §5).

### Effective stats calculation (`src/player/ship_stats.gd`, new)

```gdscript
class_name ShipStats
extends RefCounted

const VALID_STAT_KEYS := ["move_speed", "fire_cooldown", "special_cooldown_time", "special_radius", "special_damage", "max_hp"]

static func get_effective_stats(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> Dictionary:
    # Pure function. Does NOT mutate GameState, equipment, or loadout.
    # Returns base ship stats + equipped upgrades' modifiers (per-category,
    # equipped item only — owned-but-unequipped upgrades contribute nothing).
```

- Starts from the loadout's base stats as a `Dictionary`.
- For each category in `UpgradeRegistry.get_categories()`, looks up
  `equipment.equipped[category]`, resolves it via `UpgradeRegistry.get_upgrade()`,
  and applies its `stat_modifiers` additively.
- Modifier application goes through a centralized validator
  (`_apply_modifiers(stats, modifiers)`): any key not in `VALID_STAT_KEYS` is
  skipped and logged (`push_warning`), never applied — malformed/typo'd
  `UpgradeData.stat_modifiers` can't silently corrupt player stats.
- Because only the currently-equipped id per category is read, swapping
  equipment never stacks a previous upgrade's modifier — the old one simply
  stops being read.
- This function is UI-independent and reusable: the hangar stats panel, the
  stat-diff animation, and `player.gd` at mission start all call the same
  function with the same inputs and get the same result.

### `player.gd` integration

Replace the direct `loadout.move_speed` / `loadout.fire_cooldown` / etc.
assignment block with:

```gdscript
var equipment := GameState.get_equipment_for(loadout.id)
var stats := ShipStats.get_effective_stats(loadout, equipment)
move_speed = stats.move_speed
fire_cooldown = stats.fire_cooldown
# ...etc, same as today but reading from `stats` instead of `loadout`
```

`loadout.color` / `loadout.polygon_points` (visual-only fields) stay read
directly from the loadout — they're not stats.

## 3. Hangar Presentation (2.5D isometric, code-only node)

`HangarShipDisplay` (new, `src/ui/hangar_ship_display.gd`) follows the
project's existing code-only-node convention (like `HUD`/`CutscenePlayer` —
no companion `.tscn`), instantiated via a static factory
`HangarShipDisplay.create(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> HangarShipDisplay`.

**Independence contract:** `HangarShipDisplay` only receives a loadout +
equipment state and is responsible purely for visual presentation. It knows
nothing about credits, purchasing, or UI card state. `hangar_menu.gd` calls
`refresh_layer(category, upgrade)` after a successful equip; the display never
reaches back into `GameState` or the upgrade UI itself.

Visual layering (bottom to top), each an independent, separately-toggleable
node so a later swap to real per-upgrade art touches only that layer:

1. **Ambient background** — `ParallaxBackground`, 2-3 layers (far structure
   silhouette, mid pillars/machinery, near floor grid), slow automatic drift
   (not input-driven), subtle enough not to compete with the ship.
2. **Shadow** — a dimmed, squashed duplicate of the ship polygon beneath it.
3. **Base ship** — the existing `polygon_points`/`color` silhouette, scaled up
   as hero element, with a *subtle* fixed 3/4-perspective tilt (a light shear
   transform on the ship's `Node2D` — conservative enough not to distort the
   silhouette; if it reads as unnatural, fall back to a clean fixed angled
   presentation with no shear at all).
4. **Per-category overlay layers** — one node per category (`weapons`,
   `engine`, `shield`, `armor`), each a simple tinted overlay/accent shape
   positioned at a plausible attachment area on the base silhouette (weapon
   mount, engine exhaust, hull band, shield emitter). `refresh_layer(category,
   upgrade)` recolors/repositions only that one layer — it does not touch the
   others, and does not recolor the whole ship. This is the explicit
   placeholder for real upgrade-specific art later: the layer node is the
   permanent architectural seam, its *content* is what's a placeholder.
5. **Idle VFX** — a looping `Tween` for subtle bob, a pulsing engine-glow
   `Light2D`, and a light `GPUParticles2D` for ambient dust/sparks. Cheap,
   automatic, no per-frame heavy logic.
6. **Equip feedback** — on a *successful* equip only (never on card
   browse/selection), a scan-line sweep (animated `ColorRect`/shader line,
   ~0.4s, top-to-bottom across the ship) plus a brief highlight ring at the
   affected layer's position.

If an upgrade has no dedicated visual asset (true for everything in this
slice), `refresh_layer` still runs — the stat/ownership/equip-state change is
never gated on a visual asset existing.

### Layout

3-column composition: left = category nav + upgrade cards for the selected
category, center = `HangarShipDisplay` + credits readout, right = ship stats
panel. Reuses `hangar_menu.gd`'s existing `_apply_responsive_layout()`
pattern — on narrow viewports, side panels collapse to above/below the ship
rather than beside it; the ship is never fully obscured.

## 4. Equip / Purchase Flow

Single entry point, `hangar_menu.gd._try_equip(upgrade: UpgradeData) -> void`,
validation and mutation in this exact order:

1. Upgrade exists and is valid (non-null lookup via `UpgradeRegistry`).
2. Required mission is unlocked (`GameState.highest_unlocked >= upgrade.required_mission_id`).
3. If not already in `owned_upgrade_ids`: verify `GameState.credits >= upgrade.cost`.
   If insufficient, stop here — no mutation of any kind.
4. Deduct credits, add to `owned_upgrade_ids` (only if this was a purchase).
5. Set `equipment.equipped[upgrade.category] = upgrade.id`.
6. Recalculate effective stats (`ShipStats.get_effective_stats`).
7. `HangarShipDisplay.refresh_layer(upgrade.category, upgrade)`.
8. Refresh all UI: credits readout, every card's state in the current
   category (owned/equipped/locked), stats panel (animate only values that
   changed vs. the previous effective-stat dict).
9. `SaveManager.save()`.

**Atomicity:** steps 4-9 only begin after step 3 passes. If anything above
step 4 fails, nothing is mutated and nothing is saved — there is no partial
state where credits are deducted but equip didn't happen, or vice versa.

**Owned vs. Equipped** are tracked and displayed distinctly: a card for an
owned-but-not-currently-equipped upgrade shows an "EQUIP" action (no cost,
no credit check) rather than "BUY". Re-equipping never re-deducts credits.

**UI truth source:** every card's displayed state, the stats panel, and the
ship visuals are derived from `GameState`/`GameState.get_equipment_for()` on
each render — never from transient UI-local state — so reopening the hangar,
switching ships, or any other re-entry always shows state consistent with
the actual game state.

## 5. Save System (`SaveManager` autoload)

New autoload, registered in `project.godot` alongside `GameState`/
`SceneTransition`/`AudioManager`. **`SaveManager` is the only system that
performs file I/O** — `GameState` has no knowledge of `FileAccess` or
`user://save.json`.

### Schema (`user://save.json`)

```json
{
  "version": 1,
  "credits": 500,
  "selected_loadout_id": "interceptor",
  "highest_unlocked": 2,
  "equipment": {
    "interceptor": {
      "owned": ["weapons_basic", "engine_basic", "shield_basic", "armor_basic", "weapons_plasma"],
      "equipped": {"weapons": "weapons_plasma", "engine": "engine_basic", "shield": "shield_basic", "armor": "armor_basic"}
    }
  }
}
```

Unknown top-level or nested fields encountered on load are ignored (not an
error) — this keeps older/simpler saves forward-compatible with future
`GameState` additions without a migration step.

### Load (`SaveManager.load_into_game_state()`, called once from `main_menu.gd._ready()`)

1. File missing → build defaults via the single default-state path (below),
   write the file immediately so it exists after first launch.
2. File present but invalid JSON → log a warning, fall back to defaults (do
   not attempt partial recovery).
3. File present, valid JSON, `version` is missing/not `1` (unsupported/future
   version) → log a warning, fall back to defaults. Never attempt to
   reinterpret an unrecognized version's shape.
4. File present, valid JSON, `version == 1` → load normally, then validate:
   - `selected_loadout_id` must resolve via `ShipLoadoutRegistry`; if not,
     fall back to the default starter ship.
   - For each ship's equipment: every id in `owned` must resolve via
     `UpgradeRegistry.get_upgrade()`; unresolvable ids are dropped (logged),
     not loaded.
   - For each `equipped[category]`: the id must (a) resolve, (b) have a
     `category` matching the key it's stored under, and (c) be present in
     that ship's (validated) `owned` list. Any failure → fall back to that
     category's tier-0 starter upgrade instead.

### Single default-state source

`GameState._default_state()` (or equivalent single function) is the one
place starter credits (0), starter ship (`interceptor`), starting
`highest_unlocked` (1), and starter tier-0 equipment per ship are defined.
`SaveManager`'s "missing/invalid file" path calls into this same function —
it never independently redefines defaults. This guarantees deleting
`user://save.json` and a fresh in-memory `GameState` produce identical state.

### Save (`SaveManager.save()`)

- Serializes current `GameState` fields per the schema above.
- Writes atomically: full content to `user://save.tmp`, confirm the write
  succeeded, then rename over `user://save.json`. Guards against a corrupt
  save file if the game is killed mid-write.
- Call sites (exactly these — no autosave-on-every-frame/every-read):
  - End of `GameState.complete_mission()`, **after** credits are awarded (not
    before/mid-operation).
  - End of `_try_equip()`'s success path only (never on a failed/blocked
    attempt).
  - Ship selection, **only** on explicit confirm (not on browse/highlight).
- Lightweight logging (`push_warning`/`push_error`, no player-facing UI) on
  any load/save failure or discarded invalid data, so issues are debuggable
  without surfacing errors to the player.

## 6. File/Module Breakdown

**New:**
- `src/player/upgrade_data.gd` — `UpgradeData` Resource
- `src/player/upgrade_registry.gd` — `UpgradeRegistry` static class
- `src/player/ship_equipment_state.gd` — `ShipEquipmentState` Resource
- `src/player/ship_stats.gd` — `ShipStats.get_effective_stats()` + modifier validation
- `src/autoloads/save_manager.gd` — `SaveManager` autoload
- `src/ui/hangar_ship_display.gd` — `HangarShipDisplay` code-only node

**Modified:**
- `src/autoloads/game_state.gd` — add `credits`, `equipment`, `get_equipment_for()`, `_default_state()`; `complete_mission()` awards +500 credits and triggers save
- `src/player/player.gd` — read stats via `ShipStats.get_effective_stats()` instead of raw loadout fields
- `src/ui/hangar_menu.gd` — rebuilt: 3-column layout, category nav driven by `UpgradeRegistry.get_categories()`, upgrade cards, `_try_equip()`, hosts a `HangarShipDisplay`
- `project.godot` — register `SaveManager` autoload

## 7. Manual Verification Plan

No automated test suite exists in this project (per `CLAUDE.md`); all checks
are manual, run in-editor or on-device, and should be reproducible
step-by-step by another developer.

1. **Fresh launch** (no save file) — hangar shows 0 credits; each ship's 4
   categories show tier-0 equipped; nothing else purchasable (0 credits).
2. **Mission reward** — complete a mission → confirm +500 credits; confirm
   `user://save.json` was written with the correct schema.
3. **Full equip flow** — buy + equip an upgrade in each of the 4 categories →
   stat panel updates, ship visual layer changes, card flips to Equipped,
   credits deducted exactly once.
4. **Re-equip, no re-charge** — re-equip a previously owned-but-unequipped
   upgrade → no second credit deduction.
5. **Per-ship independence** — switch ships → the other ship's equipment is
   unaffected by the first ship's purchases/equips.
6. **Restart persistence** — quit and relaunch → credits, equipment, selected
   ship, and mission progress all survived.
7. **Corrupt save handling** — manually corrupt `user://save.json` (bad JSON,
   then `version: 99`) → safe fallback to defaults, no crash, a log line is
   emitted for each case.
8. **Gameplay effect, not just UI** — equip a stat-changing upgrade, launch a
   mission → `player.gd` measurably reflects the modified stat (e.g. faster
   fire rate) during actual gameplay.
9. **Responsive layout** — resize to a narrow/mobile viewport while in the
   hangar → ship stays visible, panels collapse per the existing responsive
   pattern.
10. **Purchase failure atomicity** — attempt to buy with insufficient
    credits → credits unchanged, upgrade not added to `owned`, not equipped,
    no partial stat or visual change.
11. **Mission-gated upgrade** — attempt to purchase before the required
    mission is unlocked → BUY is blocked, correct mission requirement shown;
    unlock the mission → upgrade becomes purchasable without restarting.
12. **Invalid equipment/save data** — manually inject an invalid upgrade id
    into `owned`, an invalid id into `equipped`, and an id under the wrong
    category → no crash; correct fallback to tier-0 where required.
13. **Stat modifier isolation** — equip an upgrade with a known modifier →
    only the intended stat changes; equip a different upgrade in the same
    category → the previous modifier is replaced, not stacked; confirm
    owned-but-unequipped upgrades have zero gameplay effect.
14. **Upgrade visual isolation** — equip upgrades across categories → only
    the relevant visual layer changes each time; re-equip another upgrade in
    the same category → the previous visual layer is replaced, not
    accumulated.
15. **Save integrity** — confirm failed purchase/equip attempts never
    trigger a save; confirm successful changes save exactly once at the
    intended call sites; confirm the temp save file is cleaned up/replaced
    correctly after a successful atomic save.
16. **Default-state consistency** — delete `user://save.json` → the
    resulting initial state is identical to `GameState`'s in-memory default
    (same starter credits/ship/mission progress/tier-0 equipment) — confirms
    there is exactly one authoritative default-state definition.
17. **Existing functionality regression** — the existing 3 ships still
    select and launch correctly; existing mission flow, scene transitions,
    HUD, audio, and mission completion all continue working unchanged.
18. **Reload consistency** — equip an upgrade, leave the hangar and return
    without restarting → correct upgrade/stats/visuals/credits/card state
    still shown; then restart the game → the same state persists from disk.
