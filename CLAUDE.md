# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Voidfront is a 2D, 360°-movement arcade space combat game built in **Godot 4.7 (stable)** using GDScript, targeting Android/Google Play after a desktop-first prototype. It's a solo-dev project scoped as a 3-mission vertical slice: fly a ship, fight enemies arriving from every direction, complete mission objectives, and progress through a mission-select → briefing → combat → debrief loop.

Full design intent lives in `game_spec.md` (original spec) and `docs/superpowers/specs/2026-09-30-voidfront-technical-spec.md` (as-built technical architecture) — read those for gameplay/design rationale before making significant feature changes.

## Environment

- **Godot editor**: `C:\Users\user\Desktop\Godot_v4.7-stable_win64.exe` (not on PATH — invoke by full path).
- **Android SDK**: `C:\Users\user\AppData\Local\Android\Sdk`; **Java**: `C:\Program Files\Java\jdk-17`. Both are already registered in the Godot editor settings, along with a debug keystore at `C:\Users\user\AppData\Roaming\Godot\keystores\debug.keystore`.
- No `.mcp.json` / Godot MCP server is configured yet for this project (`/gd:setup` was attempted but failed — `.mcp.json.template` path resolution issue in the plugin script). Use the CLI commands below instead of relying on MCP tools.

## Commands

Run headless from the project root (`E:\Voidfront`):

```bash
# Export a debug APK (signs with the debug keystore automatically)
"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --export-debug "Android" "export/android/voidfront.apk"

# Export a release APK (requires a release keystore configured in export_presets.cfg / editor settings)
"/c/Users/user/Desktop/Godot_v4.7-stable_win64.exe" --headless --export-release "Android" "export/android/voidfront.apk"

# Install the built APK to a connected/emulated device
adb install -r "E:\Voidfront\export\android\voidfront.apk"
```

There is no automated test suite in this repo — verification is manual (running the game in-editor or on a device).

## Architecture

### Scene graph vs. code-only nodes

Two construction styles coexist and it matters which one a given file uses:

- **`.tscn`-backed nodes** (player, enemies, projectiles, transport, main menu, mission runner, mission complete/failed) have a real scene file and are loaded via `preload()`/`PackedScene.instantiate()` or `get_tree().change_scene_to_file()`.
- **Code-only nodes** (HUD, `CutscenePlayer`, `HyperspeedTransition`, `SceneTransition`, touch controls, background/parallax layers, most VFX like `ExplosionEffect`/`EngineTrail`/`SpecialBurst`) have *no* `.tscn` — they build their entire node tree in `_ready()`/`_build_ui()` via GDScript. These are instantiated through a static factory method (`ClassName.create(...)` or `ClassName.spawn(...)`) that constructs the node and often `call_deferred`s further setup, rather than `.instantiate()`. When editing these, don't go looking for a companion scene file — it doesn't exist.

### Autoloads (singletons)

Only three, in `src/autoloads/`:

- `GameState` — session/run stats (kills, accuracy, damage), current/unlocked mission id, and the `enemy_killed` / `player_damaged` / `player_died` signals that drive objective tracking and HUD updates.
- `AudioManager` — music/SFX playback.
- `SceneTransition` — fades to black and calls `change_scene_to_file`, guarded by `is_transitioning` to prevent overlapping transitions.

### Data-driven missions

Missions are Godot `Resource` subclasses, not hardcoded scenes:

- `MissionData` (`src/mission/mission_data.gd`) — id, name, briefing/completion briefing text arrays, `objectives: Array[ObjectiveData]`, `waves: Array[WaveData]`, arena radius, transport waypoints.
- `ObjectiveData` — `DESTROY_COUNT` / `SURVIVE_TIME` / `PROTECT_ALLY` objective types.
- `WaveData` — enemy scene, count, spawn/wave delay, direction bias.
- `MissionRegistry` (`src/mission/mission_registry.gd`) — static factory (`_mission_01()`, etc.) that builds and returns `MissionData` for a given id; `get_mission_count()` is the single source of truth for how many missions exist. Add a mission by adding a new static builder method here, not by touching gameplay code.

### Mission flow

`main_menu.gd` → `CutscenePlayer` briefing → `HyperspeedTransition` → `mission_runner.tscn` (`MissionRunner`, the combat orchestrator that wires up background/player/allies/HUD/spawner/objective tracker) → on complete/fail, `ObjectiveTracker` emits a signal → `MissionRunner` plays the completion briefing/hyperspeed → `mission_complete.tscn` or `mission_failed.tscn`. `mission_complete.gd`'s "NEXT MISSION" button sets `GameState.current_mission_id` and goes straight to `mission_runner.tscn`, skipping the main menu (and its briefing cutscene) entirely.

`MissionRunner` and `ObjectiveTracker` use one-shot guard flags (`mission_ended` / `is_complete` / `is_failed`) to make their completion/failure handlers idempotent — signals like `enemy_killed` can otherwise fire the completion path more than once in the same frame.

### Enemies & components

- `BaseEnemy` (`src/enemies/base_enemy.gd`) is the shared base every enemy type (`scout`, `interceptor`, `bomber`, `carrier`) extends: target-seeking movement, contact damage, hit-flash, death VFX + `GameState.record_kill()`.
- `HealthComponent` (`src/components/health_component.gd`) is a reusable child node (`$HealthComponent`) giving any actor `take_damage`/`heal`/`damaged`/`died`, used by player, enemies, and the allied transport alike.
- `EnemySpawner` (`src/spawning/enemy_spawner.gd`) drives spawning from `MissionData.waves`; if no waves are provided it falls back to an endless-ramp mode. Spawn angle bias (`north`/`south`/`east`/`west`/`any`) picks a directional arc around the player so enemies can approach from any side.

### Systems architecture notes

- Everything is wired with Godot **signals**, not polling from other nodes — e.g. `HealthComponent.died` → enemy death handling, `ObjectiveTracker.mission_complete`/`mission_failed` → `MissionRunner`, `GameState.enemy_killed` → `ObjectiveTracker._on_enemy_killed`.
- The project targets both desktop (dev) and Android (ship target): viewport is `1920x1080` with `stretch/mode="canvas_items"` and `stretch/aspect="expand"` (see `project.godot`), meaning the *logical* viewport width shrinks on narrow/tall screens. UI built with fixed pixel widths (as several screens originally were) will overflow on narrow phones — prefer sizing relative to `get_viewport_rect().size` and re-applying on the viewport's `size_changed` signal, as done in `main_menu.gd`'s `_apply_responsive_layout()`.
- Gameplay input goes through the Input Map (`move_up/down/left/right`, `fire`, `special`, `pause` — defined in `project.godot`), not hardcoded key checks, so touch controls (`src/ui/touch_controls.gd`) can drive the same actions as keyboard/mouse.
- UI controls built programmatically default to `mouse_filter = STOP` in Godot; nodes that sit visually on top of something the player needs to tap/click through (e.g. `CutscenePlayer`'s dialogue box) must explicitly set `mouse_filter = MOUSE_FILTER_IGNORE`, or taps get swallowed before reaching `_unhandled_input`.
