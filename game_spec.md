# Game Development Specification — 360° Space Combat Game

## 1. Goal

I want to build a small, polished 2D space-combat game that can serve as a playable product/demo.

The core gameplay should feel like a mix of:

* A small arcade space shooter
* 360° movement and combat
* Enemy ships attacking from all directions
* Short cinematic cutscenes between missions
* Mission-based progression
* Simple objectives and mission statistics

The scope should remain small enough for a solo/small-team development effort, but the game should feel polished enough to eventually publish to the Google Play Store.

Do not over-engineer the project. Prioritize a playable vertical slice first.

---

# 2. Core Game Concept

The player controls a futuristic spacecraft entering dangerous sectors of space.

A mission starts with a short cinematic:

> "We've detected a massive alien infestation in Sector XYZ. Your objective is to enter the sector, eliminate the hostile fleet, and protect the remaining allied ships."

The player then enters hyperspeed and arrives in the combat zone.

Once inside the sector:

* Enemy ships spawn from different directions.
* Some enemies fly directly toward the player.
* Some pass across the screen like ships in a larger space battle.
* Enemy formations/swarms should create the feeling that the player is inside a much larger battle.
* The player moves and aims/shoots in 360 degrees.
* Missions have objectives rather than simply requiring the player to kill everything.

Example objectives:

* Destroy 25 enemy ships.
* Destroy 50 enemy ships.
* Survive for 90 seconds.
* Protect an allied ship.
* Prevent an allied ship from being destroyed.
* Destroy an enemy carrier.
* Survive an enemy swarm.
* Destroy specific enemy types.

When the mission is completed:

1. Combat ends.
2. A short cinematic plays.
3. The player's ship enters hyperspeed.
4. The ship exits the sector.
5. Mission statistics are displayed.
6. The player can press `NEXT MISSION`.

---

# 3. Camera / Gameplay Perspective

The game should be presented as a 2D game, but combat should support 360-degree movement and attacks.

The player should be able to:

* Move in any direction.
* Rotate/aim in any direction.
* Shoot toward enemies from any angle.
* Encounter enemies from every direction.

The camera should follow the player.

The combat arena should feel larger than the visible screen.

The goal is to create the feeling of being inside a space battle rather than playing a traditional left-to-right shooter.

---

# 4. Gameplay Loop

The main loop should be:

```text
Mission Selection
       ↓
Mission Briefing / Cutscene
       ↓
Hyperspeed Entry
       ↓
Combat
       ↓
Mission Objectives
       ↓
Mission Complete
       ↓
Hyperspeed Exit
       ↓
Mission Statistics
       ↓
NEXT MISSION
       ↓
Next Mission
```

The first playable version should contain approximately 3 missions.

The architecture should make it easy to add more missions later through configuration/data rather than rewriting the gameplay system.

---

# 5. Mission Structure

Each mission should define:

```text
Mission ID
Mission Name
Mission Briefing
Cutscene
Objectives
Enemy Types
Enemy Spawn Configuration
Allied Units
Mission Duration
Difficulty
Rewards
Completion Conditions
Failure Conditions
```

Example:

### Mission 01 — First Contact

Briefing:

> "We've lost contact with Outpost Seven. Intelligence reports an unknown fleet entering the sector. Get in there and eliminate the hostile scouts."

Objectives:

* Destroy 20 enemy ships.
* Survive the encounter.

Gameplay:

* Small enemy fighters.
* Enemies approach from all directions.
* Occasional enemy ships fly across the battlefield.
* Increasing spawn intensity.

Completion:

* Destroy 20 enemies.

---

### Mission 02 — Hold The Line

Objectives:

* Protect Allied Transport Ship.
* Destroy 30 enemy ships.
* Allied ship must survive.

Gameplay:

* Enemy ships attack the player.
* Some enemies target the allied transport.
* Player must move around the battlefield and intercept attackers.

Failure:

* Allied transport destroyed.

---

### Mission 03 — The Swarm

Objectives:

* Survive for 2 minutes.
* Destroy 50 enemies.
* Survive the final swarm.

Gameplay:

* Much larger enemy formations.
* Enemies approach from multiple directions.
* More ships fly through the battlefield.
* Final large swarm sequence.

---

# 6. Enemy Design

Start with only a few enemy types.

### Scout Fighter

Fast and weak.

Behavior:

* Approaches player.
* Fires occasionally.
* Attempts to pass the player.

### Interceptor

Fast enemy that aggressively attacks.

Behavior:

* Moves toward player.
* Attempts to flank player.
* More health than Scout.

### Bomber

Slow but dangerous.

Behavior:

* Targets allied ships.
* Requires player interception.

### Carrier

Large enemy.

Behavior:

* Remains farther away.
* Spawns smaller fighters.
* Can be used as a mission objective.

Do not create dozens of enemy types initially.

Build a reusable enemy AI system so additional enemy types can be added later.

---

# 7. Spawn System

Create a reusable enemy spawn system.

Enemies should be able to spawn:

* Above the player
* Below the player
* Left
* Right
* Diagonally
* At random angles
* Outside the camera view

The spawn system should support:

```text
spawn_rate
max_enemies
spawn_distance
enemy_type
direction
formation
wave
```

Example wave:

```text
Wave 1:
5 Scouts

Wave 2:
8 Scouts + 2 Interceptors

Wave 3:
12 Scouts

Wave 4:
5 Interceptors + 2 Bombers

Wave 5:
Large swarm
```

Enemy spawning should feel dynamic rather than completely predictable.

---

# 8. Space Battle Background

The background should sell the idea that a much larger battle is happening around the player.

In addition to enemies directly attacking the player, create background/ambient ships that:

* Fly across the screen.
* Enter from one side and leave through another.
* Fly toward distant targets.
* Explode in the distance.
* Appear in groups.
* Occasionally cross the player's path.

These ships do not necessarily need to be interactable.

They exist to create scale and atmosphere.

The player should feel like they are participating in a larger space battle.

---

# 9. Hyperspeed Sequence

Create a reusable hyperspeed transition.

### Entering a mission

```text
Mission briefing
      ↓
Ship launches
      ↓
Stars stretch into speed lines
      ↓
Hyperspeed
      ↓
Camera exits hyperspeed
      ↓
Combat begins
```

### Leaving a mission

```text
Mission complete
      ↓
Combat slows/stops
      ↓
Ship turns away
      ↓
Hyperspeed effect
      ↓
Mission statistics
```

This should be a short cinematic transition rather than a long animation.

---

# 10. Cutscenes

Cutscenes should be simple and inexpensive to produce.

Use:

* 2D illustrations
* Character portraits
* Spaceship artwork
* Camera movement
* Parallax
* Text/dialogue
* Sound effects
* Music

Avoid building a complicated 3D cinematic system.

Example:

### Opening Cutscene

Panel 1:

A command center.

Text:

> "Commander, we've detected unusual activity in Sector 07."

Panel 2:

A holographic map showing enemy activity.

Text:

> "Our scouts disappeared shortly after entering the sector."

Panel 3:

Player's spacecraft.

Text:

> "You're the closest unit. Get in there and find out what happened."

Then:

`ENTER SECTOR`

---

# 11. Mission Statistics

After completing a mission, display:

```text
MISSION COMPLETE

Enemies Destroyed       37
Accuracy                72%
Allies Saved            1/1
Damage Taken            24%
Mission Time            02:14

REWARDS

Credits                 +500
XP                      +250

[NEXT MISSION]
```

Statistics should be calculated from actual gameplay data.

Avoid fake/static numbers.

---

# 12. UI

Create a clean sci-fi HUD.

During gameplay:

```text
+--------------------------------------+
| HP ██████████          MISSION 01    |
|                         18/20         |
|                                      |
|              SPACE BATTLE            |
|                                      |
|          [PLAYER SHIP]               |
|                                      |
|                                      |
| OBJECTIVE                            |
| Destroy enemy ships 18/20            |
+--------------------------------------+
```

Possible HUD elements:

* Health
* Shield
* Mission objective
* Enemy counter
* Allied ship status
* Pause button
* Weapon indicator
* Special ability indicator

Keep the HUD minimal.

---

# 13. Controls

The initial target should support keyboard/mouse for development.

Design the input system so mobile controls can be added later.

Desktop prototype:

* WASD / Arrow Keys → movement
* Mouse → aim
* Left Mouse Button → fire
* Space → special ability
* ESC → pause

Do not hard-code gameplay directly to keyboard inputs.

Create an input abstraction that can later support:

* Touch joystick
* Touch aiming
* Gamepad

---

# 14. Audio

Create a simple sci-fi audio system.

Needed sounds:

* Laser fire
* Enemy explosion
* Player explosion
* Shield hit
* Damage
* Mission complete
* Mission failed
* Hyperspeed
* UI click
* UI confirmation
* Warning alarm
* Enemy incoming warning

Music:

* Mission briefing music
* Combat music
* Mission completion music
* Mission statistics/menu music

Music should be modular so it can be replaced easily.

---

# 15. Art Direction

Overall style:

* Futuristic sci-fi
* Cinematic
* Dark space backgrounds
* Bright spacecraft silhouettes
* Strong glowing weapons
* Neon energy effects
* High contrast
* Clean readable UI

The game should look polished without requiring highly detailed assets.

Prioritize:

1. Strong silhouettes
2. Consistent art direction
3. Good VFX
4. Good lighting/glow
5. Good animation
6. UI polish

---

# 16. Asset Generation Prompts

I will generate many of the visual assets using AI image-generation tools.

Create prompts for the following assets.

## Player Ship

Prompt:

> Futuristic elite space fighter spacecraft, compact aggressive silhouette, designed for a 2D arcade space combat game, symmetrical shape, front-facing and side-facing readable silhouette, dark metallic armor, glowing cyan energy accents, futuristic engines, weapons mounted on wings, clean game asset design, high contrast, isolated on transparent background, no text, no UI, consistent sci-fi game art style.

Generate variants for:

* Idle
* Flying
* Damaged
* Destroyed

---

## Scout Fighter

> Small futuristic alien attack fighter, fast aggressive silhouette, asymmetrical alien-inspired spacecraft, dark metallic surface, glowing red energy cores, sharp angular wings, designed as a 2D arcade game enemy, isolated, transparent background, no text, no UI.

---

## Interceptor

> Fast futuristic alien interceptor spacecraft, sleek aggressive design, narrow silhouette, glowing red propulsion system, alien technology, designed for a 2D sci-fi arcade shooter, isolated on transparent background, no text, no UI.

---

## Bomber

> Large futuristic alien bomber spacecraft, heavy armored body, intimidating silhouette, glowing red engines and weapon cores, designed as a 2D sci-fi arcade game enemy, isolated on transparent background, no text, no UI.

---

## Carrier

> Massive alien space carrier, enormous futuristic spacecraft, intimidating alien architecture, multiple hangar openings, glowing red energy cores, dark metallic structure, designed for a 2D space combat game, isolated on transparent background, no text, no UI.

---

## Allied Transport

> Futuristic civilian/defense transport spaceship, large protected hull, blue and white lighting, friendly human technology, designed as a 2D arcade space game asset, isolated on transparent background, no text, no UI.

---

## Space Background

> Deep futuristic outer space battlefield, dense stars, distant planets, nebula clouds, distant spacecraft silhouettes, explosions in the distance, cinematic sci-fi atmosphere, designed as a 2D game background, no foreground spaceship, no text, no UI.

Create several variations.

---

## Explosion VFX

Generate sprite-style assets for:

* Small explosion
* Medium explosion
* Large explosion
* Alien ship explosion
* Player ship explosion
* Energy impact
* Laser impact
* Shield impact

---

## UI

Generate visual references for:

* Sci-fi buttons
* Mission panels
* Health bars
* Shield bars
* Objective indicators
* Mission complete screen
* Mission statistics screen
* Mission selection screen

UI assets should remain simple enough to recreate using the game's UI framework instead of relying entirely on generated images.

---

# 17. Recommended Development Tools

Before implementing anything, determine the best technology stack for this game.

Compare suitable 2D game engines/frameworks such as:

* Godot
* Unity
* Phaser
* Other appropriate options

Prioritize:

* Fast development
* 2D performance
* Mobile/Android support
* Easy particle/VFX implementation
* Animation support
* Good asset pipeline
* Easy deployment
* Small project footprint
* Ability to publish to Google Play

Make a recommendation based on the actual requirements of this project.

Do not choose a technology just because it is popular.

---

# 18. MCP / AI Development Tools

I want to use AI heavily during development.

Investigate and recommend useful MCP servers/tools for the project.

Potential categories:

### Documentation

Use Context7 or an equivalent documentation MCP for:

* Engine documentation
* Framework APIs
* Libraries
* SDKs

### Codebase Understanding

Use a code intelligence MCP such as Serena if appropriate.

It should help with:

* Finding symbols
* Understanding relationships
* Refactoring
* Navigating the codebase

### Asset Workflow

Recommend tools/MCPs that could help with:

* Image generation
* Asset organization
* Sprite processing
* Audio generation
* Image conversion
* File management

### Testing

Recommend tools for:

* Automated testing
* Gameplay testing where practical
* Screenshot testing
* Performance checks
* Android build validation

### Project Management

If useful, recommend MCP integrations for:

* GitHub
* Issues
* Documentation
* Task tracking

Do not add MCP servers just because they exist.

Only recommend tools that provide meaningful value for this project.

---

# 19. AI Asset Workflow

Design a repeatable workflow:

```text
Concept
   ↓
AI-generated asset
   ↓
Background removal / cleanup
   ↓
Resize / optimize
   ↓
Sprite preparation
   ↓
Import into game
   ↓
Animation
   ↓
VFX
   ↓
Gameplay integration
```

The workflow should allow me to regenerate assets without breaking the game.

Use consistent naming conventions.

Example:

```text
assets/
  ships/
    player/
    enemies/
    allies/

  backgrounds/

  vfx/
    explosions/
    lasers/
    impacts/

  ui/

  audio/
    music/
    sfx/

  cutscenes/
```

---

# 20. Project Architecture

Keep the architecture modular.

Suggested systems:

```text
GameManager
MissionManager
MissionData
PlayerController
WeaponSystem
EnemyController
EnemySpawner
WaveManager
ObjectiveSystem
CombatSystem
ProjectileSystem
HealthSystem
ShieldSystem
VFXManager
AudioManager
CutsceneManager
UIManager
SaveManager
```

Do not implement all of these blindly.

Only introduce abstractions when they provide clear value.

Mission configuration should ideally be data-driven.

For example:

```json
{
  "id": 1,
  "name": "First Contact",
  "objectives": [
    {
      "type": "destroy",
      "target": 20
    }
  ],
  "enemy_waves": [
    {
      "enemy": "scout",
      "count": 5
    },
    {
      "enemy": "interceptor",
      "count": 3
    }
  ]
}
```

Use the equivalent format appropriate for the chosen engine.

---

# 21. Development Strategy

Do NOT build the entire game at once.

Use this order:

### Phase 1 — Technical Prototype

Build only:

* Player movement
* 360° aiming
* Shooting
* One enemy
* Enemy spawning
* Enemy destruction
* Basic health
* Basic objective

Goal:

A playable combat prototype.

---

### Phase 2 — Mission System

Add:

* Mission data
* Objectives
* Mission completion
* Mission failure
* Mission transitions
* Mission statistics

Goal:

A complete gameplay loop.

---

### Phase 3 — Presentation

Add:

* Space backgrounds
* Ship art
* Explosions
* Lasers
* Particles
* Screen shake
* Audio
* HUD

Goal:

Make the prototype feel like a real game.

---

### Phase 4 — Cinematics

Add:

* Mission briefing
* Dialogue
* Hyperspeed entry
* Hyperspeed exit
* Mission completion sequence

Goal:

Create the cinematic identity of the game.

---

### Phase 5 — Content

Add:

* 3 missions
* More enemy types
* Allied ship mission
* Carrier mission
* More waves

Goal:

Complete vertical slice.

---

### Phase 6 — Mobile

After the desktop gameplay is stable:

* Touch controls
* Mobile UI
* Android build
* Performance optimization
* Different screen ratios
* Google Play configuration

Do not optimize for mobile before the core gameplay is working.

---

# 22. Definition of Done

The first vertical slice is complete when I can:

1. Launch the game.
2. Start Mission 01.
3. Watch a short briefing.
4. Enter hyperspeed.
5. Arrive in the combat zone.
6. Control the ship in 360°.
7. Shoot enemies.
8. Fight enemies arriving from multiple directions.
9. See background ships and combat.
10. Complete the mission objective.
11. See the mission completion sequence.
12. Enter hyperspeed.
13. See mission statistics.
14. Press `NEXT MISSION`.
15. Play Mission 02.
16. Fail a mission if the objective requires protecting an allied ship.
17. Restart the mission.
18. Complete all 3 missions.

---

# 23. Important Development Rules

Keep the project small and playable.

Do not build unnecessary systems before the core gameplay works.

Avoid premature architecture.

Avoid adding multiplayer.

Avoid procedural galaxy generation.

Avoid complex economy systems.

Avoid inventory systems.

Avoid dozens of enemy types.

Avoid complex 3D systems unless the selected engine requires them.

The priority is:

```text
FUN GAMEPLAY
    ↓
POLISHED PRESENTATION
    ↓
MISSION LOOP
    ↓
CONTENT
    ↓
EXPANSION
```

---

# 24. Your First Task

Before writing the actual game code:

1. Analyze this specification.
2. Identify any missing requirements or technical risks.
3. Recommend the most suitable engine/framework.
4. Recommend the development stack.
5. Recommend useful MCP servers/tools.
6. Propose the project directory structure.
7. Propose the initial architecture.
8. Create the first 3 mission specifications.
9. Create the complete asset list.
10. Create optimized AI prompts for each required asset.
11. Define the minimum viable vertical slice.
12. Create a phased implementation plan.
13. Identify which parts should be implemented first.
14. Do not start generating the entire codebase yet.

Wait for approval after presenting the architecture and implementation plan.
