# Voidfront — Combined Specification

Consolidates the technical spec (2026-09-30) and the hangar upgrade system design (2026-10-01) into a single document. Where the two overlap (autoloads, project structure, mission flow, GameState), this document reflects the merged result.

## Contents

1. Overview
2. Visual Direction
3. Combat Arena
4. Core Gameplay
5. Mission System
6. Hangar, Upgrades & Economy
7. Save System
8. Scene Architecture
9. Project Structure
10. Development Phases
11. Technical Notes
12. Manual Verification Plan

---

## 1. Overview

Voidfront is a 2D arcade space combat game with 360-degree movement, mission-based progression, and cinematic presentation. The player controls a spacecraft in dangerous sectors of space, fighting enemy fleets as part of a much larger battle.

- **Target platforms:** Desktop (prototype), Android/Google Play (post-MVP)
- **Engine:** Godot 4.x stable (currently 4.7)
- **Language:** GDScript
- **Team size:** Solo / small team
- **Scope:** 3-mission vertical slice, plus a hangar with a 4-category upgrade system

---

## 2. Visual Direction

**Style:** Stylized cinematic sci-fi — strong silhouettes, detailed but readable ships, dark space environments, bright energy weapons/VFX, cinematic lighting and glow. AI-generated assets follow a consistent visual style.

**Core visual goal:** The player feels like they are participating in a much larger space battle, not simply fighting enemies that spawn around them.

### Battlefield Layers

| Layer | Content | Interactable |
|-------|---------|-------------|
| **Background** | Distant fleets, stars, nebulae, distant explosions, large-scale battle activity | No |
| **Midground** | Ships flying past, enemy formations, allied ships, missiles, explosions, battle activity | No (decorative) |
| **Gameplay** | Player, targetable enemies, projectiles, allied mission objectives | Yes |

Background and midground create the sense of scale. They should feel active and alive — distant fleets exchanging fire, ships streaking past, explosions lighting up the void — so the gameplay layer feels like a small piece of a massive engagement.

---

## 3. Combat Arena

The combat zone is **open and expansive**. There are no visible walls or obvious rectangular boundaries.

- Each mission defines its own combat area size via mission data.
- Boundaries are soft: if the player drifts too far, a subtle HUD warning appears and gentle force nudges them back.
- The boundary zone is large enough that a player focused on combat never encounters it naturally.
- Enemy spawning and background activity extend well beyond the gameplay boundary to prevent visible edges.
- The camera follows the player with slight smoothing.

---

## 4. Core Gameplay

### 4.1 Player

- 360-degree movement via WASD/arrow keys (omnidirectional, not thrust-based).
- Ship rotation follows the mouse cursor (look_at). Movement and facing are independent — the player can strafe while aiming in any direction.
- Left mouse button fires the primary weapon in the facing direction.
- Space bar activates a special ability (area burst, short cooldown).
- The player has HP only (no shield *system* in the base combat loop; the Shield upgrade category in §6 is a stat modifier layer).
- Player death = mission restart (no lives system).
- Player stats at mission start come from `ShipStats.get_effective_stats()` (base ship loadout + equipped upgrades) — see §6.3.

### 4.2 Input Abstraction

Controls are routed through Godot's Input Map, not hard-coded to specific keys, giving the abstraction layer needed for touch/gamepad support.

Input actions: `move_up`, `move_down`, `move_left`, `move_right`, `fire`, `special`, `pause`.

Aiming uses `get_global_mouse_position()` on desktop. Mobile aiming (auto-aim or virtual right stick) is addressed in Phase 6.

### 4.3 Weapons

**V1 has one weapon type:** a rapid-fire energy bolt.
- Fixed fire rate with cooldown (modifiable via upgrades).
- Projectiles travel in a straight line at high speed.
- Projectiles are pooled to avoid allocation spikes.
- Hits are detected via Area2D.

**Special ability:** Area burst — damages all enemies within a radius around the player. Short cooldown (8–10 seconds). Provides tactical relief during swarms.

### 4.4 Enemies

Four enemy types built on a shared base:

| Type | Speed | HP | Behavior | Priority |
|------|-------|----|----------|----------|
| Scout | Fast | Low | Approaches player, fires occasionally, attempts to fly past | Phase 1 |
| Interceptor | Fast | Medium | Moves toward player at an offset angle, more aggressive | Phase 5 |
| Bomber | Slow | High | Targets allied ships, ignores player unless attacked | Phase 5 |
| Carrier | Stationary | Very High | Stays at range, spawns Scout fighters periodically | Phase 5 |

All enemy types extend `BaseEnemy`, which provides:
- Health, damage, death with VFX.
- Movement toward a target (player, ally, or waypoint).
- Signal emission on death (for objective tracking).
- Configurable stats via an EnemyData resource.

Enemy AI is simple state-based behavior, not a behavior tree.

### 4.5 Spawning

`EnemySpawner` reads wave data from the current mission and spawns enemies:
- Outside the camera view at a configurable distance.
- From any angle (360 degrees around the player).
- With randomized offset to prevent predictable patterns.
- Respecting `max_enemies` limits.

Wave data:
```
wave_number
enemy_type
count
spawn_delay      (seconds between individual spawns)
wave_delay       (seconds before this wave starts)
direction_bias   (optional: "any", "north", "south", specific angle range)
formation        (optional: "scattered", "line", "cluster")
```

Spawning should feel dynamic — slight randomization in timing and position. If a mission supplies no waves, the spawner falls back to an endless-ramp mode.

### 4.6 Objectives

`ObjectiveTracker` listens to gameplay signals and checks mission completion/failure.

**Objective types (v1):**
- `destroy_count` — destroy N enemies
- `survive_time` — survive for N seconds
- `protect_ally` — keep allied ship alive until mission ends

**Completion:** All objectives met → mission complete sequence.
**Failure:** Player death OR allied ship destroyed (when protect objective active) → mission failed, option to restart.

### 4.7 Allied Ships

For Mission 02 (protect objective):
- Allied transport moves slowly along a predefined waypoint path.
- Has its own HP, displayed on HUD when relevant.
- Certain enemy types (Bomber) specifically target it.
- If destroyed → mission failure.

---

## 5. Mission System

Missions are entirely data-driven. Adding a new mission requires creating mission data — no gameplay code changes.

### 5.1 MissionData Resource

```gdscript
class_name MissionData
extends Resource

@export var id: int
@export var mission_name: String
@export var briefing_text: Array[String]
@export var objectives: Array[ObjectiveData]
@export var waves: Array[WaveData]
@export var arena_radius: float = 3000.0   # soft boundary distance from center
@export var allied_units: Array[AlliedUnitData]
@export var completion_briefing: Array[String]
@export var background_intensity: float = 1.0
```

Missions are built by `MissionRegistry` static factory methods; `get_mission_count()` is the single source of truth for how many missions exist.

### 5.2 Mission Flow

```
Main Menu
  → (Hangar: ship select + upgrades, see §6)
  → Mission Select (linear list for v1)
    → Cutscene (briefing panels)
      → Hyperspeed Transition In
        → Combat (MissionRunner active)
          → Mission Complete / Failed
            → Hyperspeed Transition Out (on success)
              → Mission Statistics (+500 credits awarded)
                → Next Mission / Replay
```

"Next Mission" sets the current mission id and goes straight to the mission runner, skipping the main menu and briefing cutscene. `MissionRunner` and `ObjectiveTracker` use one-shot guard flags so completion/failure handlers are idempotent.

### 5.3 Mission Definitions (v1)

**Mission 01 — First Contact**
- Objective: Destroy 20 enemies.
- Enemies: Scouts only, 5 waves of increasing size.
- Arena: Standard size. Tutorial-level difficulty with a ramping spawn rate.

**Mission 02 — Hold The Line**
- Objectives: Destroy 30 enemies AND protect allied transport.
- Enemies: Scouts + Interceptors + Bombers.
- Allied unit: Transport on a slow path through the arena.
- Failure: Transport destroyed. Introduces the protect mechanic.

**Mission 03 — The Swarm**
- Objectives: Survive 120 seconds AND destroy 50 enemies.
- Enemies: All types, heavy spawn rates, final swarm wave.
- Arena: Slightly larger. Introduces the Carrier.
- Highest intensity — climactic ending of the vertical slice.

---

## 6. Hangar, Upgrades & Economy

### 6.1 Goal & Scope

Replaces a hangar that only switched between 3 whole, pre-made ships with:

1. A per-category upgrade/equipment system.
2. A hangar presentation that feels like a 3D aircraft-customization bay (Ace Combat-style) while staying entirely within the 2D architecture — no Camera3D/Node3D, no new 3D asset pipeline.
3. A minimal credits economy and the project's first disk save system.

Scoped to **4 categories for this slice: Weapons, Engine, Shield, Armor**, architected so more (Hull, Energy, Thrusters, Utility, Special, …) can be added without a core rewrite.

**Non-goals:** true 3D rendering or models; a full in-game store beyond "earn credits on mission complete, spend on upgrades"; player levels/XP (mission-unlock gating only, matching the existing `unlock_mission_id` pattern); automated tests.

### 6.2 Data Model

**`UpgradeData`** (`Resource`, `src/player/upgrade_data.gd`)

```gdscript
class_name UpgradeData
extends Resource

@export var id: String = ""
@export var category: String = ""        # "weapons" | "engine" | "shield" | "armor" (plain string — new categories need no schema change)
@export var display_name: String = ""
@export var description: String = ""
@export var tier: int = 0                 # 0 = starter/free item. Ordering value ONLY — never a player level.
@export var cost: int = 0                 # credits; tier 0 is always cost 0
@export var required_mission_id: int = 1  # unlock gate, same pattern as ShipLoadoutData.unlock_mission_id
@export var stat_modifiers: Dictionary = {}  # e.g. {"fire_cooldown": -0.02, "special_damage": 15.0}
```

**`UpgradeRegistry`** (static class, `src/player/upgrade_registry.gd`) — mirrors `ShipLoadoutRegistry`/`MissionRegistry`.

```gdscript
static func get_categories() -> Array[String]            # single source of truth; UI never hardcodes the list
static func get_upgrades(category: String) -> Array[UpgradeData]
static func get_upgrade(id: String) -> UpgradeData        # null if not found
static func get_starter_upgrade(category: String) -> UpgradeData  # the tier-0 item
```

Each category has a free tier-0 item plus 1–2 additional tiers (e.g. Weapons: Basic Cannon → Plasma Cannon; Engine: Basic Engine → Ion Engine) — enough to exercise the full purchase/equip flow.

**`ShipEquipmentState`** (`Resource`, `src/player/ship_equipment_state.gd`) — one per ship loadout id.

```gdscript
@export var ship_id: String = ""
@export var owned_upgrade_ids: Array[String] = []
@export var equipped: Dictionary = {}  # category -> upgrade_id
```

`equipped` always has one entry per category — never absent or null. Default: every category's tier-0 upgrade, which is also in `owned_upgrade_ids`.

**`GameState` additions** (`src/autoloads/game_state.gd`)

```gdscript
var credits: int = 0
var equipment: Dictionary = {}  # ship_id -> ShipEquipmentState
```

`GameState.get_equipment_for(ship_id)` lazily builds and stores the default state on first access. It is the **only** place default equipment is constructed.

### 6.3 Effective Stats (`src/player/ship_stats.gd`)

```gdscript
const VALID_STAT_KEYS := ["move_speed", "fire_cooldown", "special_cooldown_time", "special_radius", "special_damage", "max_hp"]

static func get_effective_stats(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> Dictionary
```

- Pure function: does not mutate `GameState`, equipment, or loadout.
- Starts from the loadout's base stats; for each category applies the **equipped** upgrade's `stat_modifiers` additively. Owned-but-unequipped upgrades contribute nothing, and swapping never stacks the previous upgrade's modifier.
- A centralized validator (`_apply_modifiers`) skips and `push_warning`s any key not in `VALID_STAT_KEYS`, so typo'd modifiers can't corrupt stats.
- Shared by the hangar stats panel, the stat-diff animation, and `player.gd` at mission start — same inputs, same result.

**`player.gd` integration:** replace direct `loadout.move_speed` / `loadout.fire_cooldown` / etc. reads with values from `ShipStats.get_effective_stats(loadout, GameState.get_equipment_for(loadout.id))`. Visual-only fields (`loadout.color`, `loadout.polygon_points`) are still read directly from the loadout.

### 6.4 Hangar Presentation (2.5D, code-only)

`HangarShipDisplay` (`src/ui/hangar_ship_display.gd`) is a code-only node (no `.tscn`), created via `HangarShipDisplay.create(loadout, equipment)`.

**Independence contract:** it receives only a loadout + equipment state and handles visuals only. It knows nothing about credits, purchasing, or UI card state, and never reaches back into `GameState` or the upgrade UI. `hangar_menu.gd` calls `refresh_layer(category, upgrade)` after a successful equip.

Layers, bottom to top (each independently toggleable so real per-upgrade art touches only its layer later):

1. **Ambient background** — `ParallaxBackground`, 2–3 layers (far structure silhouette, mid machinery, near floor grid), slow automatic drift.
2. **Shadow** — dimmed, squashed duplicate of the ship polygon.
3. **Base ship** — existing `polygon_points`/`color` silhouette scaled up as hero element, with a subtle fixed 3/4-perspective shear (fall back to a clean fixed angle with no shear if it reads as unnatural).
4. **Per-category overlays** — one node each for `weapons`, `engine`, `shield`, `armor`: a tinted accent shape at a plausible attachment point. `refresh_layer` recolors/repositions only that layer. The layer node is the permanent architectural seam; its content is the placeholder.
5. **Idle VFX** — looping `Tween` bob, pulsing engine-glow `Light2D`, light `GPUParticles2D` dust/sparks.
6. **Equip feedback** — on a *successful* equip only (never on browse/selection): ~0.4s top-to-bottom scan-line sweep plus a brief highlight ring at the affected layer.

If an upgrade has no dedicated visual asset (true for everything in this slice), `refresh_layer` still runs — equip state is never gated on a visual asset.

**Layout:** 3 columns — left: category nav + upgrade cards; center: `HangarShipDisplay` + credits readout; right: ship stats panel. Reuses `_apply_responsive_layout()`: on narrow viewports the side panels collapse above/below the ship, which is never fully obscured.

### 6.5 Equip / Purchase Flow

Single entry point: `hangar_menu.gd._try_equip(upgrade)`, in this exact order:

1. Upgrade exists and is valid (non-null `UpgradeRegistry` lookup).
2. Required mission is unlocked (`GameState.highest_unlocked >= upgrade.required_mission_id`).
3. If not already owned: verify `GameState.credits >= upgrade.cost`; if insufficient, stop — no mutation.
4. Deduct credits and add to `owned_upgrade_ids` (only if this was a purchase).
5. Set `equipment.equipped[upgrade.category] = upgrade.id`.
6. Recalculate effective stats.
7. `HangarShipDisplay.refresh_layer(category, upgrade)`.
8. Refresh all UI: credits readout, every card in the current category (owned/equipped/locked), stats panel (animate only changed values).
9. `SaveManager.save()`.

**Atomicity:** steps 4–9 begin only after step 3 passes; failure above step 4 mutates and saves nothing.

**Owned vs. Equipped** are distinct: an owned-but-unequipped card shows "EQUIP" (no cost, no credit check), not "BUY". Re-equipping never re-deducts credits.

**UI truth source:** card state, stats panel, and ship visuals are derived from `GameState` / `get_equipment_for()` on each render — never from transient UI-local state.

### 6.6 Credits

Credits are earned on mission completion (+500, awarded in `GameState.complete_mission()` before the save) and spent on upgrades. Starting credits are 0.

---

## 7. Save System (`SaveManager` autoload)

Registered in `project.godot`. **`SaveManager` is the only system that performs file I/O** — `GameState` has no knowledge of `FileAccess` or `user://save.json`.

### 7.1 Schema (`user://save.json`)

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

Unknown top-level or nested fields on load are ignored, keeping saves forward-compatible without a migration step.

### 7.2 Load (`SaveManager.load_into_game_state()`, called once from `main_menu.gd._ready()`)

1. File missing → build defaults via the single default-state path; write the file immediately.
2. Invalid JSON → warn, fall back to defaults (no partial recovery).
3. Valid JSON but `version` missing or not `1` → warn, fall back to defaults. Never reinterpret an unrecognized version.
4. `version == 1` → load, then validate:
   - `selected_loadout_id` must resolve via `ShipLoadoutRegistry`; otherwise use the default starter ship.
   - Every id in `owned` must resolve via `UpgradeRegistry.get_upgrade()`; unresolvable ids are dropped and logged.
   - Each `equipped[category]` must (a) resolve, (b) have a matching `category`, and (c) be in that ship's validated `owned` list. Any failure → that category's tier-0 starter.

### 7.3 Single default-state source

`GameState._default_state()` is the one place starter credits (0), starter ship (`interceptor`), starting `highest_unlocked` (1), and starter tier-0 equipment are defined. `SaveManager`'s missing/invalid-file path calls into it. Deleting `user://save.json` and a fresh in-memory `GameState` produce identical state.

### 7.4 Save (`SaveManager.save()`)

- Serializes current `GameState` per the schema.
- Atomic write: full content to `user://save.tmp`, confirm success, then rename over `user://save.json`.
- Call sites (exactly these — no per-frame autosave):
  - End of `GameState.complete_mission()`, **after** credits are awarded.
  - End of `_try_equip()`'s success path only.
  - Ship selection, **only** on explicit confirm (not on browse/highlight).
- Failures and discarded data are logged with `push_warning`/`push_error`; no player-facing UI.

---

## 8. Scene Architecture

### 8.1 Construction styles

- **`.tscn`-backed nodes:** player, enemies, projectiles, transport, main menu, mission runner, mission complete/failed.
- **Code-only nodes** (no `.tscn`; built in `_ready()`/`_build_ui()`, created via a static `create(...)`/`spawn(...)` factory): HUD, `CutscenePlayer`, `HyperspeedTransition`, `SceneTransition`, touch controls, background/parallax layers, `HangarShipDisplay`, and most VFX.

### 8.2 Autoloads

| Autoload | Responsibility |
|----------|---------------|
| `GameState` | Run/session stats, current/unlocked mission, credits, per-ship equipment, default state; `enemy_killed` / `player_damaged` / `player_died` signals |
| `AudioManager` | Music (with crossfade) and SFX playback |
| `SceneTransition` | Scene changes and fades; guarded by `is_transitioning` |
| `SaveManager` | All save-file I/O (§7) |

### 8.3 Scene tree (combat)

```
MissionRunner (Node2D)
├── CombatArena (Node2D)
│   ├── BackgroundLayer (ParallaxBackground)
│   ├── MidgroundTraffic (Node2D) — ambient ships
│   └── BoundarySystem (Area2D) — soft boundary detection
├── Player (CharacterBody2D)
│   ├── Sprite2D
│   ├── CollisionShape2D
│   ├── WeaponMount (Marker2D)
│   ├── HealthComponent (Node)
│   └── SpecialAbility (Node)
├── EnemySpawner (Node)
├── Enemies (Node)
├── Projectiles (Node)
├── Allies (Node)
├── ObjectiveTracker (Node)
├── Camera2D (follows player)
└── HUD (CanvasLayer)
    ├── HealthBar
    ├── ObjectiveDisplay
    └── EnemyCounter
```

### 8.4 Signals architecture

Systems are wired with signals, not cross-node polling:
- `enemy_died` → ObjectiveTracker (counts kills)
- `player_damaged` → HUD (health bar), camera (screen shake)
- `player_died` → MissionRunner (failure)
- `objective_completed` → MissionRunner (all objectives done?)
- `ally_destroyed` → ObjectiveTracker (fails protect objective)

`HealthComponent` (`$HealthComponent`) is the reusable `take_damage`/`heal`/`damaged`/`died` provider for player, enemies, and the allied transport.

---

## 9. Project Structure

```
voidfront/
├── project.godot
├── export_presets.cfg
│
├── assets/
│   ├── ships/{player,enemies,allies}/
│   ├── backgrounds/
│   ├── vfx/
│   ├── ui/fonts/
│   ├── audio/{music,sfx}/
│   └── cutscenes/{portraits,backgrounds}/
│
├── src/
│   ├── autoloads/
│   │   ├── game_state.gd
│   │   ├── audio_manager.gd
│   │   ├── scene_transition.gd
│   │   └── save_manager.gd
│   ├── player/
│   │   ├── player.tscn / player.gd
│   │   ├── weapon.gd
│   │   ├── special_ability.gd
│   │   ├── upgrade_data.gd
│   │   ├── upgrade_registry.gd
│   │   ├── ship_equipment_state.gd
│   │   └── ship_stats.gd
│   ├── enemies/
│   │   ├── base_enemy.tscn / base_enemy.gd
│   │   ├── scout.tscn / scout.gd
│   │   ├── interceptor.tscn / interceptor.gd
│   │   ├── bomber.tscn / bomber.gd
│   │   └── carrier.tscn / carrier.gd
│   ├── components/health_component.gd
│   ├── spawning/
│   │   ├── enemy_spawner.tscn / enemy_spawner.gd
│   │   └── background_traffic.gd
│   ├── mission/
│   │   ├── mission_runner.tscn / mission_runner.gd
│   │   ├── objective_tracker.gd
│   │   └── combat_arena.gd
│   ├── ui/
│   │   ├── hud.tscn / hud.gd
│   │   ├── main_menu.tscn / main_menu.gd
│   │   ├── hangar_menu.gd
│   │   ├── hangar_ship_display.gd
│   │   ├── mission_complete.tscn / mission_complete.gd
│   │   ├── mission_select.tscn / mission_select.gd
│   │   └── pause_menu.tscn / pause_menu.gd
│   ├── cinematics/
│   │   ├── cutscene_player.tscn / cutscene_player.gd
│   │   └── hyperspeed.tscn / hyperspeed.gd
│   └── vfx/{explosion,laser_impact,engine_trail}.tscn
│
├── data/
│   ├── missions/mission_0{1,2,3}.tres
│   ├── enemies/{scout,interceptor,bomber,carrier}_data.tres
│   └── waves/
│
└── docs/
```

Note: some entries above (e.g. HUD, pause menu) are built code-only in the as-built project despite the `.tscn` names in the original plan; follow §8.1 when editing.

---

## 10. Development Phases

### Phase 1 — Combat Prototype

**Goal:** Answer one question — is the 360-degree combat actually fun? All graphics are simple placeholders; the point is to validate movement, aiming, shooting, enemy behavior, all-direction spawning, pacing, and game feel.

Deliverables:

```
1.1  Project setup: structure, input map, autoload stubs, window/stretch settings
1.2  Player movement: CharacterBody2D, 360° WASD, Camera2D follow, placeholder sprite, tuned speed/accel
1.3  Player aiming: rotate toward mouse; movement and facing independent
1.4  Shooting: projectile Area2D, fire on left click with cooldown, pooling, placeholder sprite
1.5  Base enemy (Scout): approaches player, takes damage, dies, placeholder sprite/death effect, emits signal
1.6  Enemy spawner: outside camera view, random angles, configurable rate/max, simple wave config, rising intensity
1.7  Health system: HealthComponent (damaged/died); player and enemy HP; contact/projectile damage
1.8  Combat arena: starfield background, soft boundary (HUD warning + gentle push), configurable size
1.9  Basic HUD: health bar, kill counter
1.10 Special ability: area burst on Space, radius damage, cooldown
1.11 Game feel: screen shake on player damage, enemy hit flash, satisfying death
```

Placeholder art: white ~32x32 triangle (player); red ~24x24 diamond/circle (scout); bright ~4x12 rectangle (projectile); dark starfield; orange/yellow GPUParticles2D explosion; green→red health bar rectangle.

Success criteria before Phase 2:
- [ ] 360° movement feels smooth and responsive
- [ ] Aiming at enemies is intuitive and satisfying
- [ ] Shooting and killing enemies feels good
- [ ] Enemies from all directions create tension
- [ ] Spawn pacing creates an engaging rhythm
- [ ] The arena feels open, not boxed-in
- [ ] The special ability provides tactical relief
- [ ] Fly/aim/shoot/survive is fun for 2+ minutes

### Phases 2–6 (summary)

- **Phase 2 — Mission Loop:** mission data resources, objective tracking, mission runner, complete/stats screen, main menu, full scene flow; one complete mission end-to-end.
- **Phase 3 — Presentation:** AI-generated ship art, parallax backgrounds with 3-layer depth, explosion/laser VFX, engine trails, screen shake polish, audio, HUD styling, midground battle traffic.
- **Phase 4 — Cinematics:** cutscene player (portrait + text + background), hyperspeed shader transition, mission entry/exit sequences.
- **Phase 5 — Content:** remaining enemies (Interceptor, Bomber, Carrier), allied transport, all 3 missions with wave tuning, all briefing content.
- **Hangar & Upgrades (this spec, §6–7):** upgrade data model, `ShipStats`, credits, `SaveManager`, rebuilt 3-column hangar with `HangarShipDisplay`.
- **Phase 6 — Mobile:** touch controls, mobile UI, Android build, performance optimization, Google Play deployment.

---

## 11. Technical Notes

### Object pooling
Projectiles and common VFX use pooling from the start; instantiate/queue_free spikes cause frame drops in a 360° shmup, especially on mobile.

### Performance budget (all phases)
- Max simultaneous enemies: ~30 on the gameplay layer
- Max simultaneous projectiles: ~100
- Max active particle emitters: ~20
- Background/midground ships: sprites on simple paths, no physics
- Target: 60 FPS on mid-range Android (Phase 6 concern, but pool from Phase 1)

### Project settings
- Display: 1920x1080 reference, stretch mode `canvas_items`, aspect `expand`. The logical viewport width shrinks on narrow screens, so size UI relative to `get_viewport_rect().size` and re-apply on `size_changed` (see `main_menu.gd`'s `_apply_responsive_layout()`) instead of fixed pixel widths.
- Physics: default 2D physics, with layers for player/enemy/projectile.
- Rendering: Compatibility renderer (best mobile support).

### UI mouse filtering
Programmatically built Controls default to `mouse_filter = STOP`. Nodes overlaying something the player must tap through (e.g. the `CutscenePlayer` dialogue box) must set `MOUSE_FILTER_IGNORE`.

---

## 12. Manual Verification Plan

There is no automated test suite; all checks are manual (in-editor or on-device) and should be reproducible by another developer.

**Hangar / upgrades / save**

1. **Fresh launch** (no save) — 0 credits; each ship's 4 categories show tier-0 equipped; nothing purchasable.
2. **Mission reward** — complete a mission → +500 credits; `user://save.json` written with the correct schema.
3. **Full equip flow** — buy + equip in each of the 4 categories → stats update, ship layer changes, card shows Equipped, credits deducted exactly once.
4. **Re-equip, no re-charge** — re-equipping an owned upgrade deducts nothing.
5. **Per-ship independence** — switching ships leaves the other ship's equipment unaffected.
6. **Restart persistence** — credits, equipment, selected ship, and mission progress survive quit/relaunch.
7. **Corrupt save handling** — bad JSON, then `version: 99` → safe fallback to defaults, no crash, a log line each.
8. **Gameplay effect** — an equipped stat upgrade measurably changes `player.gd` behavior in a mission (e.g. faster fire rate).
9. **Responsive layout** — narrow/mobile viewport keeps the ship visible; panels collapse per the existing pattern.
10. **Purchase failure atomicity** — insufficient credits → no change to credits, owned, equipped, stats, or visuals.
11. **Mission-gated upgrade** — BUY blocked with the requirement shown before the mission is unlocked; purchasable after unlocking, without restart.
12. **Invalid equipment/save data** — invalid id in `owned`, invalid id in `equipped`, and an id under the wrong category → no crash; tier-0 fallback where required.
13. **Stat modifier isolation** — only the intended stat changes; swapping within a category replaces rather than stacks; owned-but-unequipped upgrades have zero effect.
14. **Visual isolation** — only the relevant layer changes per equip; re-equipping in a category replaces rather than accumulates.
15. **Save integrity** — failed attempts never save; successful changes save exactly once at the intended call sites; the temp file is cleaned up/replaced after an atomic save.
16. **Default-state consistency** — deleting `user://save.json` yields state identical to `GameState`'s in-memory default.
17. **Regression** — the 3 ships still select and launch; mission flow, transitions, HUD, audio, and completion work unchanged.
18. **Reload consistency** — equip, leave and return to the hangar → correct upgrade/stats/visuals/credits/cards; then restart → same state from disk.

**Combat / missions** — apply the Phase 1 success criteria (§10) plus: each of the three missions is completable end-to-end through the briefing → combat → debrief loop, failure conditions (player death, transport destroyed) trigger the failed screen exactly once, and "Next Mission" skips the menu and briefing.
