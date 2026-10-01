# Hangar Upgrade System & 2.5D Isometric Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the whole-ship-only hangar with a per-category (Weapons/Engine/Shield/Armor) upgrade system that has a real gameplay effect, a 2.5D isometric hangar presentation, a minimal credits economy, and the project's first disk save system.

**Architecture:** New `UpgradeData`/`UpgradeRegistry`/`ShipEquipmentState` data layer (mirrors the existing `MissionData`/`MissionRegistry` and `ShipLoadoutData`/`ShipLoadoutRegistry` static-factory pattern) feeds a pure `ShipStats.get_effective_stats()` calculation consumed by both `player.gd` and the UI. A new `SaveManager` autoload owns all `user://save.json` file I/O; `GameState` stays I/O-free. The hangar screen is rebuilt around a new code-only `HangarShipDisplay` node (no `.tscn`, matching the project's existing `HUD`/`CutscenePlayer` convention) plus a 3-column upgrade UI in `hangar_menu.gd`.

**Tech Stack:** Godot 4.7 (stable), GDScript. No automated test framework exists in this project (confirmed: no `addons/`, no GdUnit4) — per `CLAUDE.md`, verification is manual. This plan uses small disposable verification scripts (`--headless --script`) for pure-logic tasks and manual in-editor steps for UI/visual tasks, instead of introducing new test infrastructure that isn't part of this spec.

**Spec:** `docs/superpowers/specs/2026-10-01-hangar-upgrade-system-design.md`

## Global Constraints

- 4 upgrade categories only for this slice: `weapons`, `engine`, `shield`, `armor` — architecture must allow adding more later with zero schema change (category is a plain `String`).
- `UpgradeRegistry.get_categories()` is the single source of truth for which categories exist; no other file hardcodes the category list.
- `tier` is a progression/ordering value on `UpgradeData` only — never conflated with a player level or any other requirement.
- `ShipStats.get_effective_stats()` must be a pure function: no mutation of `GameState`, `ShipEquipmentState`, or `ShipLoadoutData`.
- Only the currently-equipped upgrade per category contributes stat modifiers; owned-but-unequipped upgrades must have zero gameplay effect.
- `SaveManager` is the only file in the project that touches `FileAccess`/`user://save.json`. `GameState` must have no file I/O.
- Exactly one function (`GameState._default_state()`) defines starter credits (0), starter ship (`interceptor`), starting `highest_unlocked` (1), and starter tier-0 equipment. `SaveManager`'s missing/invalid-file path must call into it, never redefine defaults independently.
- Save schema has a `version` field; unsupported versions and invalid JSON fall back to defaults (never partial/guessed interpretation); unknown fields are ignored, not errors.
- `_try_equip()` is the single entry point for both purchase and equip; validation order is fixed (exists → mission unlocked → credits if unowned → deduct+own → equip → recalc stats → refresh visuals → refresh UI → save) and must be atomic (nothing mutates if any check before "deduct" fails).
- `HangarShipDisplay` only ever receives a loadout + equipment state; it must not read `GameState`, credits, or UI card state directly.
- No Camera3D/Node3D, no new 3D asset pipeline — 2.5D depth is simulated entirely with existing 2D nodes (`ParallaxBackground`, `Light2D`, `GPUParticles2D`, transforms).
- This project is **not a git repository** (confirmed via `git status` → "fatal: not a git repository"). Tasks below have no git commit step; each task's completion is its passing verification step.

## Review Focus

- **Equipping an upgrade in category A must not alter stats contributed by category B** — a modifier-key typo or an off-by-one in the per-category loop could leak one category's deltas into another. Covered in Task 3's test.
- **Switching ships must not leak one ship's equipment into another's** — `GameState.equipment` keyed wrong (e.g. overwritten instead of per-`ship_id`) would silently merge two ships' loadouts. Covered in Task 2's test.
- **A corrupted or hand-edited save file must never crash the game or load a half-valid state** — missing fields, wrong-category equipped ids, or an unknown `version` are realistic file-edit scenarios, not just malformed JSON. Covered in Task 5's tests.
- **A blocked purchase (insufficient credits or mission-locked) must leave credits, ownership, and equipped state completely untouched** — a validation check that returns early after already deducting credits (ordering bug) would silently charge the player for nothing. Covered in Task 8's test.
- **Re-equipping an already-owned upgrade must never re-deduct credits** — conflating "owned" and "equipped" in one boolean instead of two tracked states is an easy mistake that would silently drain credits on every re-equip. Covered in Task 8's test.

---

## Task 1: `UpgradeData` resource and `UpgradeRegistry`

**Files:**
- Create: `src/player/upgrade_data.gd`
- Create: `src/player/upgrade_registry.gd`
- Create (temporary, deleted at end of task): `scratch_verify_task1.gd` (project root)

**Interfaces:**
- Consumes: nothing (first new file in the chain)
- Produces:
  - `class_name UpgradeData extends Resource` with fields `id: String`, `category: String`, `display_name: String`, `description: String`, `tier: int`, `cost: int`, `required_mission_id: int`, `stat_modifiers: Dictionary`
  - `class_name UpgradeRegistry extends RefCounted` with static methods:
    - `get_categories() -> Array[String]`
    - `get_upgrades(category: String) -> Array[UpgradeData]`
    - `get_upgrade(id: String) -> UpgradeData` (returns `null` if not found)
    - `get_starter_upgrade(category: String) -> UpgradeData`

- [ ] **Step 1: Create `UpgradeData`**

```gdscript
# src/player/upgrade_data.gd
class_name UpgradeData
extends Resource

@export var id: String = ""
@export var category: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var tier: int = 0
@export var cost: int = 0
@export var required_mission_id: int = 1
@export var stat_modifiers: Dictionary = {}
```

- [ ] **Step 2: Create `UpgradeRegistry` with 4 categories, 2 tiers each**

```gdscript
# src/player/upgrade_registry.gd
class_name UpgradeRegistry
extends RefCounted

static func get_categories() -> Array[String]:
	return ["weapons", "engine", "shield", "armor"]

static func get_upgrades(category: String) -> Array[UpgradeData]:
	match category:
		"weapons":
			return [_weapons_basic(), _weapons_plasma()]
		"engine":
			return [_engine_basic(), _engine_ion()]
		"shield":
			return [_shield_basic(), _shield_mk2()]
		"armor":
			return [_armor_basic(), _armor_reinforced()]
		_:
			return []

static func get_upgrade(id: String) -> UpgradeData:
	for category in get_categories():
		for upgrade in get_upgrades(category):
			if upgrade.id == id:
				return upgrade
	return null

static func get_starter_upgrade(category: String) -> UpgradeData:
	for upgrade in get_upgrades(category):
		if upgrade.tier == 0:
			return upgrade
	return null

# --- Weapons ---
static func _weapons_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "weapons_basic"
	u.category = "weapons"
	u.display_name = "Basic Cannon"
	u.description = "Standard-issue ballistic cannon."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _weapons_plasma() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "weapons_plasma"
	u.category = "weapons"
	u.display_name = "Plasma Cannon"
	u.description = "Superheated plasma rounds. Faster fire rate."
	u.tier = 1
	u.cost = 300
	u.required_mission_id = 1
	u.stat_modifiers = {"fire_cooldown": -0.03}
	return u

# --- Engine ---
static func _engine_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "engine_basic"
	u.category = "engine"
	u.display_name = "Basic Engine"
	u.description = "Factory-standard thrusters."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _engine_ion() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "engine_ion"
	u.category = "engine"
	u.display_name = "Ion Engine"
	u.description = "Ion-driven propulsion. Higher top speed."
	u.tier = 1
	u.cost = 300
	u.required_mission_id = 1
	u.stat_modifiers = {"move_speed": 60.0}
	return u

# --- Shield ---
static func _shield_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "shield_basic"
	u.category = "shield"
	u.display_name = "Basic Shield"
	u.description = "Standard deflector plating."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _shield_mk2() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "shield_mk2"
	u.category = "shield"
	u.display_name = "Mk2 Shield"
	u.description = "Reinforced shield emitter. Larger special radius."
	u.tier = 1
	u.cost = 350
	u.required_mission_id = 2
	u.stat_modifiers = {"special_radius": 40.0}
	return u

# --- Armor ---
static func _armor_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "armor_basic"
	u.category = "armor"
	u.display_name = "Basic Armor"
	u.description = "Standard hull plating."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _armor_reinforced() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "armor_reinforced"
	u.category = "armor"
	u.display_name = "Reinforced Armor"
	u.description = "Thicker plating. More hull points."
	u.tier = 1
	u.cost = 350
	u.required_mission_id = 2
	u.stat_modifiers = {"max_hp": 30.0}
	return u
```

- [ ] **Step 3: Write a disposable verification script**

```gdscript
# scratch_verify_task1.gd (project root, deleted after this task passes)
extends SceneTree

func _initialize() -> void:
	var failures := 0

	var categories := UpgradeRegistry.get_categories()
	if categories != ["weapons", "engine", "shield", "armor"]:
		print("FAIL: get_categories() = ", categories)
		failures += 1

	for category in categories:
		var starter := UpgradeRegistry.get_starter_upgrade(category)
		if starter == null or starter.tier != 0 or starter.cost != 0:
			print("FAIL: starter upgrade for ", category, " is not a valid tier-0/cost-0 item")
			failures += 1
		if starter.category != category:
			print("FAIL: starter upgrade category mismatch for ", category)
			failures += 1

	var plasma := UpgradeRegistry.get_upgrade("weapons_plasma")
	if plasma == null or plasma.category != "weapons" or plasma.cost != 300:
		print("FAIL: get_upgrade('weapons_plasma') returned unexpected data")
		failures += 1

	var missing := UpgradeRegistry.get_upgrade("does_not_exist")
	if missing != null:
		print("FAIL: get_upgrade() should return null for unknown id")
		failures += 1

	if failures == 0:
		print("PASS: all UpgradeRegistry checks passed")
	else:
		print("FAILURES: ", failures)
	quit()
```

- [ ] **Step 4: Run it and confirm it fails before the registry exists / passes after**

Run: `"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --script res://scratch_verify_task1.gd`
Expected (after Steps 1-2 are in place): `PASS: all UpgradeRegistry checks passed`

- [ ] **Step 5: Delete the disposable verification script**

Delete `scratch_verify_task1.gd` from the project root — it is not part of the shipped codebase.

---

## Task 2: `ShipEquipmentState` and `GameState` additions

**Files:**
- Create: `src/player/ship_equipment_state.gd`
- Modify: `src/autoloads/game_state.gd`
- Create (temporary): `scratch_verify_task2.gd`

**Interfaces:**
- Consumes: `UpgradeRegistry.get_categories()`, `UpgradeRegistry.get_starter_upgrade()` (Task 1)
- Produces:
  - `class_name ShipEquipmentState extends Resource` with `ship_id: String`, `owned_upgrade_ids: Array[String]`, `equipped: Dictionary`
  - `GameState.credits: int`
  - `GameState.equipment: Dictionary` (ship_id -> `ShipEquipmentState`)
  - `GameState.get_equipment_for(ship_id: String) -> ShipEquipmentState`
  - `GameState._default_equipment_for(ship_id: String) -> ShipEquipmentState` (deterministic tier-0 builder, used by both `get_equipment_for` and later by `SaveManager`)
  - `GameState._default_state() -> Dictionary` with keys `credits`, `selected_loadout_id`, `highest_unlocked` — the single source of starter values

- [ ] **Step 1: Create `ShipEquipmentState`**

```gdscript
# src/player/ship_equipment_state.gd
class_name ShipEquipmentState
extends Resource

@export var ship_id: String = ""
@export var owned_upgrade_ids: Array[String] = []
@export var equipped: Dictionary = {}
```

- [ ] **Step 2: Add credits, equipment, and default-state helpers to `GameState`**

Modify `src/autoloads/game_state.gd` — add after the existing `var selected_loadout_id: String = "interceptor"` line:

```gdscript
var credits: int = 0
var equipment: Dictionary = {}
```

Add these new functions (anywhere after `reset_stats()`):

```gdscript
func _default_state() -> Dictionary:
	return {
		"credits": 0,
		"selected_loadout_id": "interceptor",
		"highest_unlocked": 1,
	}

func _default_equipment_for(ship_id: String) -> ShipEquipmentState:
	var state := ShipEquipmentState.new()
	state.ship_id = ship_id
	state.owned_upgrade_ids = []
	state.equipped = {}
	for category in UpgradeRegistry.get_categories():
		var starter := UpgradeRegistry.get_starter_upgrade(category)
		state.owned_upgrade_ids.append(starter.id)
		state.equipped[category] = starter.id
	return state

func get_equipment_for(ship_id: String) -> ShipEquipmentState:
	if not equipment.has(ship_id):
		equipment[ship_id] = _default_equipment_for(ship_id)
	return equipment[ship_id]
```

- [ ] **Step 3: Write a disposable verification script**

```gdscript
# scratch_verify_task2.gd (project root, deleted after this task passes)
extends SceneTree

func _initialize() -> void:
	var failures := 0

	var eq_a := GameState.get_equipment_for("interceptor")
	for category in UpgradeRegistry.get_categories():
		if not eq_a.equipped.has(category):
			print("FAIL: interceptor equipment missing category ", category)
			failures += 1
		var starter := UpgradeRegistry.get_starter_upgrade(category)
		if eq_a.equipped[category] != starter.id:
			print("FAIL: interceptor default equipped[", category, "] != starter id")
			failures += 1
		if not eq_a.owned_upgrade_ids.has(starter.id):
			print("FAIL: interceptor does not own its own starter upgrade for ", category)
			failures += 1

	var eq_b := GameState.get_equipment_for("juggernaut")
	eq_b.owned_upgrade_ids.append("weapons_plasma")
	eq_b.equipped["weapons"] = "weapons_plasma"

	var eq_a_again := GameState.get_equipment_for("interceptor")
	if eq_a_again.equipped["weapons"] != UpgradeRegistry.get_starter_upgrade("weapons").id:
		print("FAIL: juggernaut's equipment change leaked into interceptor's equipment")
		failures += 1

	if failures == 0:
		print("PASS: all GameState equipment checks passed")
	else:
		print("FAILURES: ", failures)
	quit()
```

- [ ] **Step 4: Run it**

Run: `"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --script res://scratch_verify_task2.gd`
Expected: `PASS: all GameState equipment checks passed`

- [ ] **Step 5: Delete the disposable verification script**

Delete `scratch_verify_task2.gd`.

---

## Task 3: `ShipStats.get_effective_stats()` pure calculation

**Files:**
- Create: `src/player/ship_stats.gd`
- Create (temporary): `scratch_verify_task3.gd`

**Interfaces:**
- Consumes: `ShipLoadoutData` (existing), `ShipEquipmentState` + `UpgradeRegistry.get_categories()`/`get_upgrade()` (Tasks 1-2)
- Produces: `class_name ShipStats extends RefCounted` with static `get_effective_stats(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> Dictionary`, returning keys `move_speed`, `fire_cooldown`, `special_cooldown_time`, `special_radius`, `special_damage`, `max_hp` (all `float`)

- [ ] **Step 1: Create `ShipStats`**

```gdscript
# src/player/ship_stats.gd
class_name ShipStats
extends RefCounted

const VALID_STAT_KEYS := ["move_speed", "fire_cooldown", "special_cooldown_time", "special_radius", "special_damage", "max_hp"]

static func get_effective_stats(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> Dictionary:
	var stats := {
		"move_speed": loadout.move_speed,
		"fire_cooldown": loadout.fire_cooldown,
		"special_cooldown_time": loadout.special_cooldown_time,
		"special_radius": loadout.special_radius,
		"special_damage": loadout.special_damage,
		"max_hp": loadout.max_hp,
	}

	for category in UpgradeRegistry.get_categories():
		var upgrade_id: String = equipment.equipped.get(category, "")
		if upgrade_id.is_empty():
			continue
		var upgrade := UpgradeRegistry.get_upgrade(upgrade_id)
		if upgrade == null:
			continue
		stats = _apply_modifiers(stats, upgrade.stat_modifiers)

	return stats

static func _apply_modifiers(stats: Dictionary, modifiers: Dictionary) -> Dictionary:
	var result := stats.duplicate()
	for key in modifiers:
		if not VALID_STAT_KEYS.has(key):
			push_warning("ShipStats: ignoring unknown stat modifier key '%s'" % key)
			continue
		result[key] = result[key] + modifiers[key]
	return result
```

- [ ] **Step 2: Write a disposable verification script**

```gdscript
# scratch_verify_task3.gd (project root, deleted after this task passes)
extends SceneTree

func _initialize() -> void:
	var failures := 0
	var loadout := ShipLoadoutRegistry.get_loadout("interceptor")

	# Tier-0 everything: effective stats must equal base loadout stats exactly.
	var eq := GameState._default_equipment_for("interceptor")
	var stats := ShipStats.get_effective_stats(loadout, eq)
	if stats.move_speed != loadout.move_speed or stats.fire_cooldown != loadout.fire_cooldown:
		print("FAIL: tier-0 effective stats should equal base loadout stats")
		failures += 1

	# Equip weapons_plasma only: fire_cooldown changes, nothing else does.
	eq.equipped["weapons"] = "weapons_plasma"
	var stats_with_plasma := ShipStats.get_effective_stats(loadout, eq)
	var expected_cooldown: float = loadout.fire_cooldown - 0.03
	if absf(stats_with_plasma.fire_cooldown - expected_cooldown) > 0.0001:
		print("FAIL: weapons_plasma modifier not applied correctly")
		failures += 1
	if stats_with_plasma.move_speed != loadout.move_speed:
		print("FAIL: weapons category modifier leaked into move_speed (engine stat)")
		failures += 1
	if stats_with_plasma.max_hp != loadout.max_hp:
		print("FAIL: weapons category modifier leaked into max_hp (armor stat)")
		failures += 1

	# Swap weapons back to basic: cooldown returns to base, no stacking residue.
	eq.equipped["weapons"] = "weapons_basic"
	var stats_reverted := ShipStats.get_effective_stats(loadout, eq)
	if stats_reverted.fire_cooldown != loadout.fire_cooldown:
		print("FAIL: swapping back to weapons_basic should restore base fire_cooldown exactly")
		failures += 1

	# Owning-but-not-equipping has zero effect.
	eq.owned_upgrade_ids.append("engine_ion")
	var stats_owned_only := ShipStats.get_effective_stats(loadout, eq)
	if stats_owned_only.move_speed != loadout.move_speed:
		print("FAIL: an owned-but-unequipped upgrade must not affect effective stats")
		failures += 1

	# Unknown modifier key must be ignored, not crash or corrupt other stats.
	var bogus := UpgradeData.new()
	bogus.id = "bogus_test_item"
	bogus.category = "weapons"
	bogus.stat_modifiers = {"not_a_real_stat": 999.0, "fire_cooldown": -0.01}
	var patched := ShipStats._apply_modifiers(stats.duplicate(), bogus.stat_modifiers)
	if patched.has("not_a_real_stat"):
		print("FAIL: unknown stat modifier key should not be added to the stats dict")
		failures += 1
	if absf(patched.fire_cooldown - (stats.fire_cooldown - 0.01)) > 0.0001:
		print("FAIL: valid key in a mixed-validity modifiers dict should still apply")
		failures += 1

	if failures == 0:
		print("PASS: all ShipStats checks passed")
	else:
		print("FAILURES: ", failures)
	quit()
```

- [ ] **Step 3: Run it**

Run: `"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --script res://scratch_verify_task3.gd`
Expected: `PASS: all ShipStats checks passed`

- [ ] **Step 4: Delete the disposable verification script**

Delete `scratch_verify_task3.gd`.

---

## Task 4: `player.gd` reads effective stats instead of raw loadout fields

**Files:**
- Modify: `src/player/player.gd`

**Interfaces:**
- Consumes: `GameState.get_equipment_for()` (Task 2), `ShipStats.get_effective_stats()` (Task 3)
- Produces: no new interface — `player.gd`'s runtime stat fields (`move_speed`, `fire_cooldown`, `special_cooldown_time`, `special_radius`, `special_damage`, `health_component.max_hp`) now reflect equipped upgrades

- [ ] **Step 1: Read the current loadout-application block**

Open `src/player/player.gd` around lines 30-46 (the block assigning `move_speed = loadout.move_speed`, `fire_cooldown = loadout.fire_cooldown`, `special_cooldown_time = loadout.special_cooldown_time`, `special_radius = loadout.special_radius`, `special_damage = loadout.special_damage`, `base_color = loadout.color`, `health_component.max_hp = loadout.max_hp`, `ship_shape.polygon = loadout.polygon_points`, `ship_shape.color = loadout.color`).

- [ ] **Step 2: Replace the stat-field assignments with effective-stat reads**

Replace:
```gdscript
	move_speed = loadout.move_speed
	fire_cooldown = loadout.fire_cooldown
	special_cooldown_time = loadout.special_cooldown_time
	special_radius = loadout.special_radius
	special_damage = loadout.special_damage
	base_color = loadout.color
```
with:
```gdscript
	var equipment := GameState.get_equipment_for(loadout.id)
	var stats := ShipStats.get_effective_stats(loadout, equipment)
	move_speed = stats.move_speed
	fire_cooldown = stats.fire_cooldown
	special_cooldown_time = stats.special_cooldown_time
	special_radius = stats.special_radius
	special_damage = stats.special_damage
	base_color = loadout.color
```

Leave `health_component.max_hp = loadout.max_hp` as a separate line but change its right-hand side to `stats.max_hp`, and leave `ship_shape.polygon = loadout.polygon_points` / `ship_shape.color = loadout.color` untouched (visual-only fields, not stats).

- [ ] **Step 3: Manual verification — confirm the game still launches and stats are unaffected with all-tier-0 equipment**

Run: `"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --export-debug "Android" "export/android/voidfront_task4_check.apk"`
Expected: export completes with no GDScript parse/compile errors (confirms `player.gd` still compiles). Delete `export/android/voidfront_task4_check.apk` afterward — it's a compile smoke-check, not a deliverable.

If a Windows desktop debug export preset exists instead, use that preset name in place of `"Android"`. The goal is only to confirm the script compiles; either export target works.

- [ ] **Step 4: Manual verification — in-editor play test**

Open the project in the Godot editor, run the main scene, start Mission 01 with the default (tier-0 everywhere) Interceptor loadout. Confirm the ship moves, fires, and uses its special ability exactly as it did before this task (no behavior change yet, since no upgrade is equipped above tier 0).

---

## Task 5: `SaveManager` — schema, defaults, load/validate, atomic save (logic only, not yet an autoload)

**Files:**
- Create: `src/autoloads/save_manager.gd`
- Create (temporary): `scratch_verify_task5.gd`

**Interfaces:**
- Consumes: `GameState._default_state()` (Task 2), `UpgradeRegistry.get_upgrade()`/`get_starter_upgrade()`/`get_categories()` (Task 1), `ShipLoadoutRegistry.get_loadout()` (existing)
- Produces:
  - `class_name SaveManager extends Node` with:
    - `const SAVE_PATH := "user://save.json"`
    - `const TMP_PATH := "user://save.tmp"`
    - `const SAVE_VERSION := 1`
    - `func load_into_game_state() -> void`
    - `func save() -> void`
    - `func _build_default_payload() -> Dictionary` (calls `GameState._default_state()` + `GameState._default_equipment_for()` — never redefines defaults itself)
    - `func _apply_payload(payload: Dictionary) -> void` (validates and writes into `GameState`)

This task builds `SaveManager` as a plain `class_name` so it can be exercised directly from a headless script without needing the autoload singleton wiring (that's Task 6). `SaveManager.new()` must work standalone.

- [ ] **Step 1: Create `SaveManager`**

```gdscript
# src/autoloads/save_manager.gd
class_name SaveManager
extends Node

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const SAVE_VERSION := 1

func load_into_game_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("SaveManager: no save file found, writing defaults")
		_apply_payload(_build_default_payload())
		save()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: failed to open save file, falling back to defaults")
		_apply_payload(_build_default_payload())
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is not valid JSON, falling back to defaults")
		_apply_payload(_build_default_payload())
		return

	var payload: Dictionary = parsed
	if not payload.has("version") or payload["version"] != SAVE_VERSION:
		push_warning("SaveManager: unsupported save version '%s', falling back to defaults" % str(payload.get("version", "<missing>")))
		_apply_payload(_build_default_payload())
		return

	_apply_payload(payload)

func save() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"credits": GameState.credits,
		"selected_loadout_id": GameState.selected_loadout_id,
		"highest_unlocked": GameState.highest_unlocked,
		"equipment": {},
	}
	for ship_id in GameState.equipment:
		var state: ShipEquipmentState = GameState.equipment[ship_id]
		payload["equipment"][ship_id] = {
			"owned": state.owned_upgrade_ids,
			"equipped": state.equipped,
		}

	var json_text := JSON.stringify(payload, "\t")

	var tmp_file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp_file == null:
		push_error("SaveManager: failed to open temp save file for writing")
		return
	tmp_file.store_string(json_text)
	tmp_file.close()

	var dir := DirAccess.open("user://")
	if dir == null or dir.rename(TMP_PATH, SAVE_PATH) != OK:
		push_error("SaveManager: failed to replace save file with temp file")

func _build_default_payload() -> Dictionary:
	var defaults := GameState._default_state()
	return {
		"version": SAVE_VERSION,
		"credits": defaults["credits"],
		"selected_loadout_id": defaults["selected_loadout_id"],
		"highest_unlocked": defaults["highest_unlocked"],
		"equipment": {},
	}

func _apply_payload(payload: Dictionary) -> void:
	GameState.credits = int(payload.get("credits", 0))
	GameState.highest_unlocked = int(payload.get("highest_unlocked", 1))

	var loadout_id: String = payload.get("selected_loadout_id", "interceptor")
	if ShipLoadoutRegistry.get_loadout(loadout_id) == null:
		push_warning("SaveManager: selected_loadout_id '%s' not found, falling back to interceptor" % loadout_id)
		loadout_id = "interceptor"
	GameState.selected_loadout_id = loadout_id

	GameState.equipment = {}
	var equipment_payload: Dictionary = payload.get("equipment", {})
	for ship_id in equipment_payload:
		var raw: Dictionary = equipment_payload[ship_id]
		var state := ShipEquipmentState.new()
		state.ship_id = ship_id

		var validated_owned: Array[String] = []
		for upgrade_id in raw.get("owned", []):
			if UpgradeRegistry.get_upgrade(upgrade_id) != null:
				validated_owned.append(upgrade_id)
			else:
				push_warning("SaveManager: dropping unknown owned upgrade id '%s' for ship '%s'" % [upgrade_id, ship_id])
		state.owned_upgrade_ids = validated_owned

		var validated_equipped: Dictionary = {}
		var raw_equipped: Dictionary = raw.get("equipped", {})
		for category in UpgradeRegistry.get_categories():
			var candidate_id: String = raw_equipped.get(category, "")
			var candidate := UpgradeRegistry.get_upgrade(candidate_id) if not candidate_id.is_empty() else null
			var valid := candidate != null and candidate.category == category and validated_owned.has(candidate_id)
			if valid:
				validated_equipped[category] = candidate_id
			else:
				if not candidate_id.is_empty():
					push_warning("SaveManager: equipped[%s]='%s' invalid for ship '%s', falling back to starter" % [category, candidate_id, ship_id])
				validated_equipped[category] = UpgradeRegistry.get_starter_upgrade(category).id
				if not validated_owned.has(validated_equipped[category]):
					validated_owned.append(validated_equipped[category])
		state.owned_upgrade_ids = validated_owned
		state.equipped = validated_equipped

		GameState.equipment[ship_id] = state
```

- [ ] **Step 2: Write a disposable verification script covering load/save/validation**

```gdscript
# scratch_verify_task5.gd (project root, deleted after this task passes)
extends SceneTree

func _initialize() -> void:
	var failures := 0
	var mgr := SaveManager.new()

	# --- Case 1: no save file -> defaults applied and file created ---
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	GameState.credits = 999
	mgr.load_into_game_state()
	if GameState.credits != 0:
		print("FAIL: missing save file should load default credits (0)")
		failures += 1
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		print("FAIL: load_into_game_state() should write a save file when none exists")
		failures += 1

	# --- Case 2: default-state consistency (Review Focus item) ---
	var fresh_defaults := GameState._default_state()
	if GameState.credits != fresh_defaults["credits"] or GameState.selected_loadout_id != fresh_defaults["selected_loadout_id"] or GameState.highest_unlocked != fresh_defaults["highest_unlocked"]:
		print("FAIL: state loaded from a missing save file does not match GameState._default_state()")
		failures += 1

	# --- Case 3: valid round-trip save/load ---
	GameState.credits = 750
	GameState.get_equipment_for("interceptor").equipped["weapons"] = "weapons_plasma"
	GameState.get_equipment_for("interceptor").owned_upgrade_ids.append("weapons_plasma")
	mgr.save()
	GameState.credits = 0
	GameState.equipment = {}
	mgr.load_into_game_state()
	if GameState.credits != 750:
		print("FAIL: round-trip save/load did not preserve credits")
		failures += 1
	if GameState.get_equipment_for("interceptor").equipped["weapons"] != "weapons_plasma":
		print("FAIL: round-trip save/load did not preserve equipped upgrade")
		failures += 1

	# --- Case 4: invalid JSON falls back to defaults ---
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ not valid json ")
	f.close()
	GameState.credits = 999
	mgr.load_into_game_state()
	if GameState.credits != 0:
		print("FAIL: invalid JSON should fall back to default credits (0)")
		failures += 1

	# --- Case 5: unsupported version falls back to defaults ---
	var payload_v99 := {"version": 99, "credits": 12345, "selected_loadout_id": "interceptor", "highest_unlocked": 1, "equipment": {}}
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload_v99))
	f.close()
	GameState.credits = 0
	mgr.load_into_game_state()
	if GameState.credits == 12345:
		print("FAIL: unsupported save version should NOT be loaded as-is")
		failures += 1

	# --- Case 6: invalid ship id falls back to default ship ---
	var payload_bad_ship := {"version": 1, "credits": 100, "selected_loadout_id": "not_a_real_ship", "highest_unlocked": 1, "equipment": {}}
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload_bad_ship))
	f.close()
	mgr.load_into_game_state()
	if GameState.selected_loadout_id != "interceptor":
		print("FAIL: invalid selected_loadout_id should fall back to interceptor")
		failures += 1

	# --- Case 7: invalid owned/equipped upgrade ids are dropped/fallback ---
	var payload_bad_equipment := {
		"version": 1, "credits": 100, "selected_loadout_id": "interceptor", "highest_unlocked": 1,
		"equipment": {
			"interceptor": {
				"owned": ["weapons_basic", "totally_fake_id"],
				"equipped": {"weapons": "totally_fake_id", "engine": "engine_basic", "shield": "shield_basic", "armor": "armor_basic"},
			}
		}
	}
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload_bad_equipment))
	f.close()
	mgr.load_into_game_state()
	var eq := GameState.get_equipment_for("interceptor")
	if eq.owned_upgrade_ids.has("totally_fake_id"):
		print("FAIL: unknown owned upgrade id should be dropped")
		failures += 1
	if eq.equipped["weapons"] != "weapons_basic":
		print("FAIL: invalid equipped upgrade id should fall back to the category's tier-0 starter")
		failures += 1

	# --- Case 8: wrong-category equipped id falls back ---
	var payload_wrong_category := {
		"version": 1, "credits": 100, "selected_loadout_id": "interceptor", "highest_unlocked": 1,
		"equipment": {
			"interceptor": {
				"owned": ["weapons_basic", "engine_basic", "shield_basic", "armor_basic"],
				"equipped": {"weapons": "engine_basic", "engine": "engine_basic", "shield": "shield_basic", "armor": "armor_basic"},
			}
		}
	}
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload_wrong_category))
	f.close()
	mgr.load_into_game_state()
	eq = GameState.get_equipment_for("interceptor")
	if eq.equipped["weapons"] != "weapons_basic":
		print("FAIL: an upgrade stored under the wrong category should fall back to that category's starter")
		failures += 1

	# Clean up the real save file so this disposable test doesn't leave state behind.
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	if FileAccess.file_exists(SaveManager.TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.TMP_PATH))

	if failures == 0:
		print("PASS: all SaveManager checks passed")
	else:
		print("FAILURES: ", failures)
	quit()
```

- [ ] **Step 3: Run it**

Run: `"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --script res://scratch_verify_task5.gd`
Expected: `PASS: all SaveManager checks passed`

- [ ] **Step 4: Delete the disposable verification script**

Delete `scratch_verify_task5.gd`.

---

## Task 6: Register `SaveManager` as an autoload; award mission-complete credits

**Files:**
- Modify: `project.godot`
- Modify: `src/autoloads/game_state.gd`

**Interfaces:**
- Consumes: `SaveManager` class from Task 5
- Produces: `SaveManager` available as a global singleton (like `GameState`/`AudioManager`); `GameState.complete_mission()` now awards credits and persists

- [ ] **Step 1: Register the autoload**

In `project.godot`, under `[autoload]`, add a line after the existing three:
```
SaveManager="*res://src/autoloads/save_manager.gd"
```

- [ ] **Step 2: Load the save on startup from within `SaveManager` itself**

Add a `_ready()` to `src/autoloads/save_manager.gd` (this makes it self-initializing, consistent with how `GameState`/`AudioManager` already behave as autoloads, and means no other scene needs to know `SaveManager` exists in order for load to happen):

```gdscript
func _ready() -> void:
	load_into_game_state()
```

- [ ] **Step 3: Award credits and save on mission completion**

Modify `src/autoloads/game_state.gd`'s existing `complete_mission()`:

```gdscript
func complete_mission(mission_id: int) -> void:
	if mission_id >= highest_unlocked:
		highest_unlocked = mini(mission_id + 1, MissionRegistry.get_mission_count())
	credits += 500
	SaveManager.save()
```

- [ ] **Step 4: Manual verification — in-editor play test**

Open the project in the Godot editor. Run the main scene. Confirm no autoload wiring errors appear in the Output panel on startup (this would surface a typo in the `project.godot` autoload path or a parse error in `save_manager.gd`). Play Mission 01 to completion. Confirm the Output panel shows no errors. Close the game, then check the user data directory (Project > Open User Data Folder in the editor) for `save.json` — confirm it now contains `"credits": 500`.

- [ ] **Step 5: Manual verification — restart persistence**

Relaunch the game (close and reopen the Godot editor's running instance, or re-run the scene). Confirm `GameState.credits` is `500` immediately on startup (e.g. temporarily add `print(GameState.credits)` to `main_menu.gd._ready()`, observe `500` in the Output panel, then remove that print line — it was only for this manual check).

---

## Task 7: `HangarShipDisplay` — code-only 2.5D presentation node

**Files:**
- Create: `src/ui/hangar_ship_display.gd`

**Interfaces:**
- Consumes: `ShipLoadoutData` (existing), `ShipEquipmentState`, `UpgradeData`/`UpgradeRegistry` (Tasks 1-2)
- Produces:
  - `class_name HangarShipDisplay extends Control` with:
    - `static func create(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> HangarShipDisplay`
    - `func refresh_layer(category: String, upgrade: UpgradeData) -> void`
    - `func set_ship(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void` (rebuilds all layers for a ship switch)
    - `func play_equip_feedback(category: String) -> void` (the scan-line sweep; called only after a successful equip)

This node has no `.tscn` — it builds its tree in `_build_ui()`, matching the project's existing `HUD`/`CutscenePlayer` convention described in `CLAUDE.md`.

- [ ] **Step 1: Create the base structure, ambient background, shadow, and base ship layers**

```gdscript
# src/ui/hangar_ship_display.gd
class_name HangarShipDisplay
extends Control

const CATEGORY_ATTACH_OFFSETS := {
	"weapons": Vector2(18, -4),
	"engine": Vector2(-18, 0),
	"shield": Vector2(0, 0),
	"armor": Vector2(0, 8),
}

var _loadout: ShipLoadoutData
var _equipment: ShipEquipmentState

var _background: ParallaxBackground
var _ship_root: Node2D
var _shadow_shape: Polygon2D
var _base_shape: Polygon2D
var _category_layers: Dictionary = {}
var _engine_glow: Light2D
var _particles: GPUParticles2D
var _bob_tween: Tween

static func create(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> HangarShipDisplay:
	var display := HangarShipDisplay.new()
	display.custom_minimum_size = Vector2(480, 480)
	display.call_deferred("_build_ui", loadout, equipment)
	return display

func _build_ui(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void:
	_loadout = loadout
	_equipment = equipment

	_build_background()

	var viewport_center := Control.new()
	viewport_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(viewport_center)

	_ship_root = Node2D.new()
	viewport_center.add_child(_ship_root)
	_ship_root.position = size * 0.5

	_build_shadow()
	_build_base_ship()
	_build_category_layers()
	_build_idle_vfx()

	resized.connect(func(): _ship_root.position = size * 0.5)

func _build_background() -> void:
	_background = ParallaxBackground.new()
	add_child(_background)
	move_child(_background, 0)

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.1, 0.1)
	_background.add_child(far)
	var far_bg := ColorRect.new()
	far_bg.color = Color(0.05, 0.05, 0.1, 1.0)
	far_bg.size = Vector2(1200, 1200)
	far_bg.position = Vector2(-600, -600)
	far.add_child(far_bg)

	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.3, 0.3)
	_background.add_child(mid)
	for i in range(4):
		var pillar := ColorRect.new()
		pillar.color = Color(0.1, 0.12, 0.18, 0.6)
		pillar.size = Vector2(20, 400)
		pillar.position = Vector2(-500 + i * 300, -200)
		mid.add_child(pillar)

func _build_shadow() -> void:
	_shadow_shape = Polygon2D.new()
	_shadow_shape.polygon = _loadout.polygon_points
	_shadow_shape.color = Color(0, 0, 0, 0.35)
	_shadow_shape.scale = Vector2(4.2, 1.2)
	_shadow_shape.position = Vector2(0, 60)
	_ship_root.add_child(_shadow_shape)

func _build_base_ship() -> void:
	_base_shape = Polygon2D.new()
	_base_shape.polygon = _loadout.polygon_points
	_base_shape.color = _loadout.color
	_base_shape.scale = Vector2(4.0, 4.0)
	# Subtle fixed 3/4-perspective tilt via a light shear, not an aggressive distortion.
	_base_shape.skew = deg_to_rad(8.0)
	_ship_root.add_child(_base_shape)
```

- [ ] **Step 2: Add per-category overlay layers and `refresh_layer()`**

```gdscript
func _build_category_layers() -> void:
	for category in UpgradeRegistry.get_categories():
		var layer := Polygon2D.new()
		layer.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
		layer.color = Color(1, 1, 1, 0.0)
		layer.position = CATEGORY_ATTACH_OFFSETS.get(category, Vector2.ZERO) * 4.0
		_ship_root.add_child(layer)
		_category_layers[category] = layer

		var upgrade_id: String = _equipment.equipped.get(category, "")
		var upgrade := UpgradeRegistry.get_upgrade(upgrade_id) if not upgrade_id.is_empty() else null
		if upgrade != null:
			_apply_layer_visual(category, upgrade)

func refresh_layer(category: String, upgrade: UpgradeData) -> void:
	if not _category_layers.has(category):
		return
	_apply_layer_visual(category, upgrade)

func _apply_layer_visual(category: String, upgrade: UpgradeData) -> void:
	var layer: Polygon2D = _category_layers[category]
	# Placeholder visual: tier-0 items are invisible (no accent), higher tiers get a category-tinted accent.
	# This is the seam where real per-upgrade art replaces the tint later without touching any other layer.
	if upgrade.tier <= 0:
		layer.color = Color(1, 1, 1, 0.0)
		return
	match category:
		"weapons":
			layer.color = Color(1.0, 0.3, 0.2, 0.9)
		"engine":
			layer.color = Color(0.3, 0.7, 1.0, 0.9)
		"shield":
			layer.color = Color(0.3, 1.0, 0.8, 0.9)
		"armor":
			layer.color = Color(0.8, 0.8, 0.3, 0.9)
		_:
			layer.color = Color(1, 1, 1, 0.9)

func set_ship(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void:
	_loadout = loadout
	_equipment = equipment
	_base_shape.polygon = loadout.polygon_points
	_base_shape.color = loadout.color
	_shadow_shape.polygon = loadout.polygon_points
	for category in UpgradeRegistry.get_categories():
		var upgrade_id: String = equipment.equipped.get(category, "")
		var upgrade := UpgradeRegistry.get_upgrade(upgrade_id) if not upgrade_id.is_empty() else null
		if upgrade != null:
			_apply_layer_visual(category, upgrade)
```

- [ ] **Step 3: Add idle VFX and the equip scan-line feedback**

```gdscript
func _build_idle_vfx() -> void:
	_engine_glow = PointLight2D.new()
	_engine_glow.color = Color(0.3, 0.7, 1.0)
	_engine_glow.energy = 0.6
	_engine_glow.position = CATEGORY_ATTACH_OFFSETS["engine"] * 4.0
	_ship_root.add_child(_engine_glow)

	_particles = GPUParticles2D.new()
	_particles.amount = 12
	_particles.lifetime = 3.0
	_particles.position = Vector2.ZERO
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 10.0
	mat.spread = 180.0
	_particles.process_material = mat
	_ship_root.add_child(_particles)

	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_ship_root, "position:y", _ship_root.position.y - 6.0, 1.6).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_ship_root, "position:y", _ship_root.position.y + 6.0, 1.6).set_trans(Tween.TRANS_SINE)

	var glow_tween := create_tween().set_loops()
	glow_tween.tween_property(_engine_glow, "energy", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(_engine_glow, "energy", 0.5, 0.8).set_trans(Tween.TRANS_SINE)

func play_equip_feedback(category: String) -> void:
	if not _category_layers.has(category):
		return
	var layer: Polygon2D = _category_layers[category]

	var scan := ColorRect.new()
	scan.color = Color(0.6, 0.9, 1.0, 0.5)
	scan.size = Vector2(160, 4)
	scan.position = layer.position + Vector2(-80, -100)
	_ship_root.add_child(scan)

	var sweep := create_tween()
	sweep.tween_property(scan, "position:y", layer.position.y + 100, 0.4).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(scan, "modulate:a", 0.0, 0.1)
	sweep.tween_callback(scan.queue_free)

	var ring := Polygon2D.new()
	ring.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	ring.color = Color(1, 1, 1, 0.0)
	ring.position = layer.position
	_ship_root.add_child(ring)
	var ring_tween := create_tween()
	ring_tween.tween_property(ring, "modulate:a", 0.8, 0.1)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	ring_tween.tween_callback(ring.queue_free)
```

- [ ] **Step 4: Manual verification — in-editor visual check**

Temporarily instantiate the display to check it renders: open the Godot editor, create a throwaway scene with a single `Control` root, attach a short script that calls `add_child(HangarShipDisplay.create(ShipLoadoutRegistry.get_loadout("interceptor"), GameState.get_equipment_for("interceptor")))` in `_ready()`, and run that scene directly (Godot's "Run Current Scene"). Confirm: the ship silhouette renders centered, with a visible subtle tilt (not heavily distorted), a soft shadow beneath it, a pulsing engine glow, drifting background layers, and slow bob motion. Call `.refresh_layer("weapons", UpgradeRegistry.get_upgrade("weapons_plasma"))` from the same throwaway script and confirm only the weapons-area accent appears (no change elsewhere on the ship). Delete the throwaway scene/script after confirming.

---

## Task 8: Rebuild `hangar_menu.gd` — 3-column layout, category nav, upgrade cards, `_try_equip()`

**Files:**
- Modify: `src/ui/hangar_menu.gd`

**Interfaces:**
- Consumes: `HangarShipDisplay` (Task 7), `UpgradeRegistry`/`UpgradeData` (Task 1), `GameState.get_equipment_for()`/`GameState.credits` (Task 2), `ShipStats.get_effective_stats()` (Task 3), `SaveManager.save()` (Tasks 5-6)
- Produces: the playable hangar screen described in the spec. No further files depend on this one.

- [ ] **Step 1: Replace the single-column layout with the 3-column structure**

Rewrite `src/ui/hangar_menu.gd` in full:

```gdscript
extends Control

var loadouts: Array[ShipLoadoutData] = []
var index: int = 0
var selected_category: String = ""

var root_row: HBoxContainer
var nav_column: VBoxContainer
var category_buttons: Dictionary = {}
var card_list: VBoxContainer

var center_column: VBoxContainer
var ship_selector_row: HBoxContainer
var prev_btn: Button
var next_btn: Button
var name_label: Label
var credits_label: Label
var ship_display: HangarShipDisplay
var back_button: Button

var stats_column: VBoxContainer
var stats_rows: Dictionary = {}
var _last_stats: Dictionary = {}

func _ready() -> void:
	loadouts = ShipLoadoutRegistry.get_all_loadouts()
	index = _find_selected_index()
	selected_category = UpgradeRegistry.get_categories()[0]
	_create_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _find_selected_index() -> int:
	for i in loadouts.size():
		if loadouts[i].id == GameState.selected_loadout_id:
			return i
	return 0

func _current_loadout() -> ShipLoadoutData:
	return loadouts[index]

func _current_equipment() -> ShipEquipmentState:
	return GameState.get_equipment_for(_current_loadout().id)

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root_row = HBoxContainer.new()
	root_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_row.add_theme_constant_override("separation", 16)
	add_child(root_row)

	_build_nav_column()
	_build_center_column()
	_build_stats_column()

	_update_all()

func _build_nav_column() -> void:
	nav_column = VBoxContainer.new()
	nav_column.custom_minimum_size = Vector2(220, 0)
	nav_column.add_theme_constant_override("separation", 8)
	root_row.add_child(nav_column)

	var title := Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	nav_column.add_child(title)

	for category in UpgradeRegistry.get_categories():
		var btn := Button.new()
		btn.text = category.to_upper()
		btn.toggle_mode = true
		btn.pressed.connect(_on_category_selected.bind(category))
		nav_column.add_child(btn)
		category_buttons[category] = btn

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_column.add_child(card_scroll)

	card_list = VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 6)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(card_list)

func _build_center_column() -> void:
	center_column = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	center_column.add_theme_constant_override("separation", 8)
	root_row.add_child(center_column)

	var title_label := Label.new()
	title_label.text = "HANGAR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center_column.add_child(title_label)

	credits_label = Label.new()
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.add_theme_font_size_override("font_size", 18)
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	center_column.add_child(credits_label)

	ship_selector_row = HBoxContainer.new()
	ship_selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ship_selector_row.add_theme_constant_override("separation", 16)
	center_column.add_child(ship_selector_row)

	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(56, 56)
	prev_btn.pressed.connect(_on_prev_pressed)
	ship_selector_row.add_child(prev_btn)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ship_selector_row.add_child(name_label)

	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(56, 56)
	next_btn.pressed.connect(_on_next_pressed)
	ship_selector_row.add_child(next_btn)

	ship_display = HangarShipDisplay.create(_current_loadout(), _current_equipment())
	ship_display.custom_minimum_size = Vector2(480, 480)
	ship_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_column.add_child(ship_display)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(320, 60)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_on_back_pressed)
	center_column.add_child(back_button)

func _build_stats_column() -> void:
	stats_column = VBoxContainer.new()
	stats_column.custom_minimum_size = Vector2(220, 0)
	stats_column.add_theme_constant_override("separation", 6)
	root_row.add_child(stats_column)

	var title := Label.new()
	title.text = "SHIP STATS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	stats_column.add_child(title)

	for stat_key in ["move_speed", "fire_cooldown", "special_damage", "max_hp"]:
		var row := HBoxContainer.new()
		stats_column.add_child(row)
		var label := Label.new()
		label.text = _stat_display_name(stat_key) + ":"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		row.add_child(label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 14)
		value.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(value)
		stats_rows[stat_key] = value

func _stat_display_name(stat_key: String) -> String:
	match stat_key:
		"move_speed": return "Speed"
		"fire_cooldown": return "Fire Rate"
		"special_damage": return "Special Dmg"
		"max_hp": return "Hull"
		_: return stat_key

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	if vp_w < 900.0:
		root_row.vertical = true
	else:
		root_row.vertical = false
```

- [ ] **Step 2: Add category/card rendering and the single `_try_equip()` entry point**

Append to the same file:

```gdscript
func _on_category_selected(category: String) -> void:
	AudioManager.play_menu_select()
	selected_category = category
	_update_all()

func _update_all() -> void:
	_update_nav_buttons()
	_update_cards()
	_update_center()
	_update_stats(false)

func _update_nav_buttons() -> void:
	for category in category_buttons:
		category_buttons[category].button_pressed = (category == selected_category)

func _update_cards() -> void:
	for child in card_list.get_children():
		child.queue_free()

	var equipment := _current_equipment()
	for upgrade in UpgradeRegistry.get_upgrades(selected_category):
		card_list.add_child(_build_card(upgrade, equipment))

func _build_card(upgrade: UpgradeData, equipment: ShipEquipmentState) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	name_lbl.text = upgrade.display_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	card.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	card.add_child(desc_lbl)

	var is_equipped := equipment.equipped.get(upgrade.category, "") == upgrade.id
	var is_owned := equipment.owned_upgrade_ids.has(upgrade.id)
	var mission_unlocked := GameState.highest_unlocked >= upgrade.required_mission_id
	var can_afford := GameState.credits >= upgrade.cost

	var action_btn := Button.new()
	if is_equipped:
		action_btn.text = "EQUIPPED"
		action_btn.disabled = true
	elif is_owned:
		action_btn.text = "EQUIP"
		action_btn.disabled = false
	elif not mission_unlocked:
		action_btn.text = "NEED MISSION %d" % upgrade.required_mission_id
		action_btn.disabled = true
	elif not can_afford:
		action_btn.text = "NOT ENOUGH CREDITS (%d)" % upgrade.cost
		action_btn.disabled = true
	else:
		action_btn.text = "BUY (%d)" % upgrade.cost
		action_btn.disabled = false

	action_btn.pressed.connect(_try_equip.bind(upgrade))
	card.add_child(action_btn)

	return card

func _try_equip(upgrade: UpgradeData) -> void:
	if UpgradeRegistry.get_upgrade(upgrade.id) == null:
		return

	if GameState.highest_unlocked < upgrade.required_mission_id:
		return

	var equipment := _current_equipment()
	var already_owned := equipment.owned_upgrade_ids.has(upgrade.id)

	if not already_owned:
		if GameState.credits < upgrade.cost:
			return
		GameState.credits -= upgrade.cost
		equipment.owned_upgrade_ids.append(upgrade.id)

	equipment.equipped[upgrade.category] = upgrade.id

	AudioManager.play_menu_select()
	ship_display.refresh_layer(upgrade.category, upgrade)
	ship_display.play_equip_feedback(upgrade.category)

	_update_cards()
	_update_center()
	_update_stats(true)

	SaveManager.save()

func _update_center() -> void:
	var loadout := _current_loadout()
	var unlocked := ShipLoadoutRegistry.is_unlocked(loadout)
	name_label.text = loadout.display_name
	credits_label.text = "CREDITS: %d" % GameState.credits
	prev_btn.disabled = index <= 0
	next_btn.disabled = index >= loadouts.size() - 1

func _update_stats(animate: bool) -> void:
	var loadout := _current_loadout()
	var equipment := _current_equipment()
	var stats := ShipStats.get_effective_stats(loadout, equipment)

	for stat_key in stats_rows:
		var value_label: Label = stats_rows[stat_key]
		var new_value: float = stats[stat_key]
		var old_value: float = _last_stats.get(stat_key, new_value)

		if animate and not is_equal_approx(old_value, new_value):
			var tween := create_tween()
			tween.tween_method(
				func(v): value_label.text = _format_stat(stat_key, v),
				old_value, new_value, 0.3
			)
		else:
			value_label.text = _format_stat(stat_key, new_value)

	_last_stats = stats.duplicate()

func _format_stat(stat_key: String, value: float) -> String:
	match stat_key:
		"fire_cooldown": return "%.1f/s" % (1.0 / value)
		_: return "%d" % roundi(value)

func _on_prev_pressed() -> void:
	AudioManager.play_menu_select()
	index = maxi(0, index - 1)
	ship_display.set_ship(_current_loadout(), _current_equipment())
	_update_all()

func _on_next_pressed() -> void:
	AudioManager.play_menu_select()
	index = mini(loadouts.size() - 1, index + 1)
	ship_display.set_ship(_current_loadout(), _current_equipment())
	_update_all()

func _on_back_pressed() -> void:
	AudioManager.play_menu_select()
	if ShipLoadoutRegistry.is_unlocked(_current_loadout()) and GameState.selected_loadout_id != _current_loadout().id:
		GameState.selected_loadout_id = _current_loadout().id
		SaveManager.save()
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
```

Note: ship selection is confirmed (and saved) when leaving the hangar with a different ship actively browsed, matching the spec's "ship selection, only on explicit confirm (not on browse/highlight)" — browsing with prev/next does not itself save.

- [ ] **Step 3: Manual verification — full in-editor play test of the end-to-end flow**

Open the project in the Godot editor, run the main scene, and walk through this exact sequence, confirming each point:

1. Enter the hangar from the main menu. Confirm 3 columns render: category nav + cards on the left, the ship (with idle bob/glow/particles) in the center with credits shown, stats on the right.
2. With 0 credits, confirm every non-tier-0 card shows "NOT ENOUGH CREDITS" and is disabled, and tier-0 cards show "EQUIPPED" (disabled) since they're the default.
3. Back out to the main menu, start and complete Mission 01. Confirm credits become 500 after mission complete (reuses Task 6's check).
4. Re-enter the hangar. Confirm the Weapons category's `weapons_plasma` card now shows "BUY (300)" and is enabled. Click it. Confirm: credits drop to 200, the card flips to "EQUIPPED", the ship's weapon-area accent changes color, a scan-line sweep plays once, and the Fire Rate stat animates to its new value.
5. Switch to the Engine category and equip `engine_ion` with the remaining credits if affordable, or confirm it correctly shows "NOT ENOUGH CREDITS" if not (300 cost vs 200 remaining credits — expect this to be blocked, confirming the atomicity check: clicking it must not change credits, cards, or stats).
6. Switch back to Weapons, equip `weapons_basic` (free, already owned from the ship's tier-0 default) over the currently-equipped `weapons_plasma`. Confirm credits do **not** change (it's a re-equip of an already-owned item, not a purchase). Then equip `weapons_plasma` again. Confirm credits still do not drop a second time (it was already owned from step 4) — only the `equipped` pointer changes, no new deduction.
7. Switch ships via the ◀/▶ buttons. Confirm the new ship's cards show its own independent equipped/owned state (not the first ship's).
8. Switch back to the first ship. Confirm its `weapons_plasma` equip from step 4/6 is still shown as equipped (state is derived from `GameState`, not transient UI state).
9. Leave the hangar (BACK) and re-enter it. Confirm all state (credits, equipped upgrades, selected ship) is unchanged.
10. Fully close and relaunch the game. Re-enter the hangar. Confirm credits, equipped upgrades, and selected ship all match what was left before closing (disk persistence).
11. Launch a mission with `weapons_plasma` equipped. Confirm the ship's fire rate is visibly faster than the pre-upgrade baseline (gameplay effect, not just UI).

If any point fails, fix the underlying code before proceeding — this is the task's deliverable, not a follow-up.

---

## Task 9: Final regression pass against the spec's full verification list

**Files:** none (verification-only task; no code changes expected unless a regression is found, in which case fix it in the relevant file from Tasks 1-8)

**Interfaces:** none — this task exercises the finished feature end-to-end.

- [ ] **Step 1: Re-run every item in the spec's "Manual Verification Plan" section (18 items)**

Open `docs/superpowers/specs/2026-10-01-hangar-upgrade-system-design.md` and work through items 1-18 under "Manual Verification Plan" in order, in the Godot editor. Items 1-10 and part of 18 are already covered by Task 8 Step 3 and Task 6 Steps 4-5 — re-confirm them hold together as a whole sequence rather than in isolation. Pay particular attention to:
- Item 12 (invalid equipment/save data) — hand-edit `user://save.json` (found via Project > Open User Data Folder) to inject an invalid upgrade id as described, relaunch, confirm no crash and correct fallback.
- Item 16 (default-state consistency) — delete `user://save.json` entirely, relaunch, confirm the resulting state matches what a fresh install would show.
- Item 17 (existing functionality regression) — play all 3 missions' intro briefings, HUD, audio cues, and mission-complete/mission-failed screens to confirm nothing outside the hangar regressed.

- [ ] **Step 2: Confirm no stray files were left behind**

Check the project root and confirm no `scratch_verify_task*.gd` files remain (they should have been deleted at the end of Tasks 1, 2, 3, and 5). Check the user data folder and confirm no leftover `save.tmp` file exists after a normal play session (it should only exist transiently during `SaveManager.save()`).

- [ ] **Step 3: Done**

If all 18 spec verification items pass and no stray files remain, the feature is complete. There is no git repository in this project, so there is no commit/PR step — implementation is done when this task's checks pass.
