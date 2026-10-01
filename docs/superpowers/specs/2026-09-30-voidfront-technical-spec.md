# Voidfront — Technical Specification

## Overview

Voidfront is a 2D arcade space combat game with 360-degree movement, mission-based progression, and cinematic presentation. The player controls a spacecraft in dangerous sectors of space, fighting enemy fleets as part of a much larger battle.

**Target platforms:** Desktop (prototype), Android/Google Play (post-MVP)
**Engine:** Godot 4.x stable (currently 4.7.2)
**Language:** GDScript
**Team size:** Solo / small team
**Scope:** 3-mission vertical slice

---

## Visual Direction

**Style:** Stylized cinematic sci-fi — strong silhouettes, detailed but readable ships, dark space environments, bright energy weapons/VFX, cinematic lighting and glow. AI-generated assets follow a consistent visual style.

**Core visual goal:** The player feels like they are participating in a much larger space battle, not simply fighting enemies that spawn around them.

### Battlefield Layers

The battlefield is structured into three visual depth layers:

| Layer | Content | Interactable |
|-------|---------|-------------|
| **Background** | Distant fleets, stars, nebulae, distant explosions, large-scale battle activity | No |
| **Midground** | Ships flying past, enemy formations, allied ships, missiles, explosions, battle activity | No (decorative) |
| **Gameplay** | Player, targetable enemies, projectiles, allied mission objectives | Yes |

The background and midground layers create the sense of scale. They should feel active and alive — distant fleets exchanging fire, ships streaking past, explosions lighting up the void — so the gameplay layer feels like a small piece of a massive engagement.

---

## Combat Arena

The combat zone is **open and expansive**. There are no visible walls or obvious rectangular boundaries.

- Each mission defines its own combat area size via mission data
- Boundaries are soft: if the player drifts too far, a subtle HUD warning appears and gentle force nudges them back
- The boundary zone is large enough that a player focused on combat never encounters it naturally
- Enemy spawning and background activity extend well beyond the gameplay boundary to prevent visible edges
- The camera follows the player with slight smoothing

---

## Core Gameplay

### Player

- 360-degree movement via WASD/arrow keys (omnidirectional, not thrust-based)
- Ship rotation follows the mouse cursor (look_at)
- Movement and facing are independent — the player can strafe while aiming in any direction
- Left mouse button fires the primary weapon in the facing direction
- Space bar activates a special ability (area burst, short cooldown)
- The player has HP only (no shield system in v1)
- Player death = mission restart (no lives system)

### Input Abstraction

Controls are routed through Godot's Input Map, not hard-coded to specific keys. This creates the abstraction layer needed for future touch/gamepad support without requiring a custom input system.

Input actions:
- `move_up`, `move_down`, `move_left`, `move_right` — movement
- `fire` — primary weapon
- `special` — special ability
- `pause` — pause menu

Aiming is handled via `get_global_mouse_position()` for desktop. Mobile aiming (auto-aim or virtual right stick) will be addressed in Phase 6.

### Weapons

**V1 has one weapon type:** a rapid-fire energy bolt.
- Fixed fire rate with cooldown
- Projectiles travel in a straight line at high speed
- Projectiles are pooled (object pool) to avoid allocation spikes
- Projectile hits are detected via Area2D

**Special ability:** Area burst — damages all enemies within a radius around the player. Short cooldown (8-10 seconds). Simple to implement, provides tactical relief during swarms.

### Enemies

Four enemy types built on a shared base:

| Type | Speed | HP | Behavior | Priority |
|------|-------|----|----------|----------|
| Scout | Fast | Low | Approaches player, fires occasionally, attempts to fly past | Phase 1 |
| Interceptor | Fast | Medium | Moves toward player at an offset angle, more aggressive | Phase 5 |
| Bomber | Slow | High | Targets allied ships, ignores player unless attacked | Phase 5 |
| Carrier | Stationary | Very High | Stays at range, spawns Scout fighters periodically | Phase 5 |

All enemy types extend a `BaseEnemy` scene/script that provides:
- Health, damage, death with VFX
- Movement toward a target (player, ally, or waypoint)
- Signal emission on death (for objective tracking)
- Configurable stats via EnemyData resource

Enemy AI is simple state-based behavior, not a full behavior tree. Each type has a small set of behaviors appropriate to its role.

### Spawning

The `EnemySpawner` reads wave data from the current mission and spawns enemies:
- Outside the camera view at a configurable distance
- From any angle (360 degrees around the player)
- With randomized offset to prevent predictable patterns
- Respecting max_enemies limits to control performance

Wave data defines:
```
wave_number
enemy_type
count
spawn_delay (seconds between individual spawns)
wave_delay (seconds before this wave starts)
direction_bias (optional: "any", "north", "south", specific angle range)
formation (optional: "scattered", "line", "cluster")
```

Spawning should feel dynamic — slight randomization in timing and position within the configured parameters.

### Objectives

The `ObjectiveTracker` listens to gameplay signals and checks mission completion/failure:

**Objective types (v1):**
- `destroy_count` — destroy N enemies
- `survive_time` — survive for N seconds
- `protect_ally` — keep allied ship alive until mission ends

**Completion:** All objectives met → mission complete sequence
**Failure:** Player death OR allied ship destroyed (when protect objective active) → mission failed, option to restart

### Allied Ships

For Mission 02 (protect objective):
- Allied transport moves slowly along a predefined path (series of waypoints)
- Has its own HP, displayed on HUD when relevant
- Certain enemy types (Bomber) specifically target it
- If destroyed → mission failure

---

## Mission System

Missions are entirely data-driven. Adding a new mission requires creating mission data — no gameplay code changes.

### MissionData Resource

```gdscript
class_name MissionData
extends Resource

@export var id: int
@export var mission_name: String
@export var briefing_text: Array[String]  # lines of briefing dialogue
@export var objectives: Array[ObjectiveData]
@export var waves: Array[WaveData]
@export var arena_radius: float = 3000.0  # soft boundary distance from center
@export var allied_units: Array[AlliedUnitData]
@export var completion_briefing: Array[String]
@export var background_intensity: float = 1.0  # controls midground/background activity density
```

### Mission Flow

```
Main Menu
  → Mission Select (linear list for v1)
    → Cutscene (briefing panels)
      → Hyperspeed Transition In
        → Combat (MissionRunner active)
          → Mission Complete / Failed
            → Hyperspeed Transition Out (on success)
              → Mission Statistics
                → Next Mission / Replay
```

### Mission Definitions (v1)

**Mission 01 — First Contact**
- Objective: Destroy 20 enemies
- Enemies: Scouts only, 5 waves of increasing size
- Arena: Standard size
- Difficulty: Tutorial-level, low spawn rate ramping up

**Mission 02 — Hold The Line**
- Objectives: Destroy 30 enemies AND protect allied transport
- Enemies: Scouts + Interceptors + Bombers
- Allied unit: Transport on a slow path through the arena
- Failure: Transport destroyed
- Introduces the protect mechanic

**Mission 03 — The Swarm**
- Objectives: Survive 120 seconds AND destroy 50 enemies
- Enemies: All types, heavy spawn rates, final swarm wave
- Arena: Slightly larger
- Introduces the Carrier enemy
- Highest intensity — climactic vertical slice ending

---

## Scene Architecture

### Autoloads (Singletons)

Only three — truly global state:

| Autoload | Responsibility |
|----------|---------------|
| `GameState` | Current mission progress, unlocked missions, session stats |
| `AudioManager` | Music playback (with crossfade), SFX playback |
| `SceneTransition` | Scene change handling, fade effects |

### Scene Tree (during combat)

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
├── Enemies (Node) — container for spawned enemies
├── Projectiles (Node) — container for pooled projectiles
├── Allies (Node) — container for allied ships
├── ObjectiveTracker (Node)
├── Camera2D (follows player)
└── HUD (CanvasLayer)
    ├── HealthBar
    ├── ObjectiveDisplay
    └── EnemyCounter
```

### Key Scenes (files)

```
src/
├── player/player.tscn          — CharacterBody2D with weapon, health
├── enemies/base_enemy.tscn     — base enemy scene (inherited by types)
├── enemies/scout.tscn          — Scout inherits base_enemy
├── projectiles/projectile.tscn — energy bolt
├── vfx/explosion.tscn          — GPUParticles2D explosion
├── mission/mission_runner.tscn — combat orchestrator
├── ui/hud.tscn                 — in-combat HUD
├── ui/main_menu.tscn           — title / mission select
├── ui/mission_complete.tscn    — stats display
├── ui/pause_menu.tscn          — pause overlay
├── cinematics/cutscene_player.tscn   — briefing panel system
├── cinematics/hyperspeed.tscn        — transition effect
```

---

## Project Structure

```
voidfront/
├── project.godot
├── export_presets.cfg
│
├── assets/
│   ├── ships/
│   │   ├── player/
│   │   ├── enemies/
│   │   └── allies/
│   ├── backgrounds/
│   ├── vfx/
│   ├── ui/
│   │   └── fonts/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── cutscenes/
│       ├── portraits/
│       └── backgrounds/
│
├── src/
│   ├── autoloads/
│   │   ├── game_state.gd
│   │   ├── audio_manager.gd
│   │   └── scene_transition.gd
│   ├── player/
│   │   ├── player.tscn / player.gd
│   │   ├── weapon.gd
│   │   └── special_ability.gd
│   ├── enemies/
│   │   ├── base_enemy.tscn / base_enemy.gd
│   │   ├── scout.tscn / scout.gd
│   │   ├── interceptor.tscn / interceptor.gd
│   │   ├── bomber.tscn / bomber.gd
│   │   └── carrier.tscn / carrier.gd
│   ├── components/
│   │   └── health_component.gd
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
│   │   ├── mission_complete.tscn / mission_complete.gd
│   │   ├── mission_select.tscn / mission_select.gd
│   │   └── pause_menu.tscn / pause_menu.gd
│   ├── cinematics/
│   │   ├── cutscene_player.tscn / cutscene_player.gd
│   │   └── hyperspeed.tscn / hyperspeed.gd
│   └── vfx/
│       ├── explosion.tscn
│       ├── laser_impact.tscn
│       └── engine_trail.tscn
│
├── data/
│   ├── missions/
│   │   ├── mission_01.tres
│   │   ├── mission_02.tres
│   │   └── mission_03.tres
│   ├── enemies/
│   │   ├── scout_data.tres
│   │   ├── interceptor_data.tres
│   │   ├── bomber_data.tres
│   │   └── carrier_data.tres
│   └── waves/
│
└── docs/
```

---

## Phase 1 — Combat Prototype

**Goal:** Answer one question — is the 360-degree combat actually fun?

**All graphics are simple placeholders.** No AI-generated art, no final sprites. The point is to validate movement, aiming, shooting, enemy behavior, spawning from all directions, combat pacing, and game feel.

### Phase 1 Deliverables

```
1.1  Godot project setup
     - Project structure, folders, input map, autoload stubs
     - Window size, stretch mode, project settings

1.2  Player movement
     - CharacterBody2D, 360° WASD movement
     - Camera2D following the player
     - Placeholder triangle/arrow sprite
     - Movement feels responsive (tune speed, acceleration)

1.3  Player aiming
     - Ship rotates toward mouse cursor (look_at)
     - Movement and facing are independent

1.4  Shooting
     - Projectile scene (Area2D, moves forward, self-destructs off-screen)
     - Fire on left click with cooldown
     - Basic projectile pooling or queue_free with preload
     - Placeholder rectangle sprite for projectile

1.5  Base enemy (Scout)
     - Approaches player from spawn position
     - Takes damage from projectiles, dies
     - Placeholder circle/diamond sprite
     - Basic death effect (placeholder particles or scale tween)
     - Emits signal on death

1.6  Enemy spawner
     - Spawns Scouts outside camera view at random angles
     - Configurable spawn rate, max enemies
     - Reads from a simple wave configuration
     - Increasing intensity over time

1.7  Health system
     - HealthComponent: tracks HP, emits damaged/died signals
     - Player has HP, enemies have HP
     - Player takes damage on enemy collision or enemy projectile

1.8  Combat arena
     - Basic starfield background (simple parallax or scrolling dots)
     - Soft boundary — HUD warning + gentle push when player drifts too far
     - Arena size configurable

1.9  Basic HUD
     - Player health bar
     - Kill counter
     - Minimal — enough to see game state during testing

1.10 Special ability
     - Area burst on Space key
     - Damages all enemies in radius
     - Cooldown timer (displayed on HUD or just functional)

1.11 Basic game feel
     - Screen shake on player damage
     - Brief flash on enemy hit
     - Enemy death feels satisfying even with placeholders
```

### Phase 1 Placeholder Art

| Element | Placeholder |
|---------|------------|
| Player ship | White triangle/arrow, ~32x32 px |
| Scout enemy | Red diamond/circle, ~24x24 px |
| Projectile | Small bright rectangle, ~4x12 px |
| Background | Dark blue/black with scattered small white dots (simple starfield) |
| Explosion | GPUParticles2D with default circle texture, orange/yellow |
| Health bar | Simple colored rectangle (green → red) |

### Phase 1 Success Criteria

Before proceeding to Phase 2, these must be true:
- [ ] Moving in 360° feels smooth and responsive
- [ ] Aiming at enemies is intuitive and satisfying
- [ ] Shooting enemies and seeing them die feels good
- [ ] Enemies approaching from all directions creates tension
- [ ] The spawn pacing creates engaging combat rhythm
- [ ] The arena feels open, not boxed-in
- [ ] The special ability provides tactical relief
- [ ] The basic loop (fly, aim, shoot, survive) is fun to play for 2+ minutes

---

## Phases 2-6 Summary

Detailed specs for these phases will be written when Phase 1 is validated.

### Phase 2 — Mission Loop
Mission data resources, objective tracking, mission runner, mission complete/stats screen, main menu, full scene flow. One complete mission loop end-to-end.

### Phase 3 — Presentation
AI-generated ship art, parallax backgrounds with 3-layer battlefield depth, explosion/laser VFX, engine trails, screen shake polish, audio (SFX + music), HUD styling, midground battle traffic.

### Phase 4 — Cinematics
Cutscene player (portrait + text + background), hyperspeed shader transition, mission entry/exit sequences.

### Phase 5 — Content
Remaining enemy types (Interceptor, Bomber, Carrier), allied transport ship, all 3 missions with wave tuning, all briefing content.

### Phase 6 — Mobile
Touch controls, mobile UI, Android build, performance optimization, Google Play deployment.

---

## Technical Notes

### Object Pooling
Projectiles and common VFX must use object pooling from the start. In a 360° shmup with multiple enemies firing, allocation spikes from instantiate/queue_free cause frame drops — especially on mobile later.

### Performance Budget (guideline for all phases)
- Max simultaneous enemies: ~30 on gameplay layer
- Max simultaneous projectiles: ~100
- Max particle emitters: ~20 active
- Background/midground ships: sprites on simple paths, no physics
- Target: 60 FPS on mid-range Android (Phase 6 concern, but pool from Phase 1)

### Godot Project Settings (Phase 1)
- Display: 1920x1080 reference, stretch mode `canvas_items`, aspect `expand`
- Physics: default 2D physics (no need for custom physics layers yet beyond player/enemy/projectile)
- Rendering: Compatibility renderer (best mobile support)

### Signals Architecture
Godot signals connect the systems without tight coupling:
- `enemy_died` → ObjectiveTracker (counts kills)
- `player_damaged` → HUD (updates health bar), camera (screen shake)
- `player_died` → MissionRunner (triggers failure)
- `objective_completed` → MissionRunner (checks if all objectives done)
- `ally_destroyed` → ObjectiveTracker (fails protect objective)
