extends Node2D

var player_scene: PackedScene = preload("res://src/player/player.tscn")
var StarfieldScript: GDScript = preload("res://src/environment/starfield.gd")
var NebulaScript: GDScript = preload("res://src/environment/nebula_layer.gd")
var TrafficScript: GDScript = preload("res://src/environment/midground_traffic.gd")
var HudScript: GDScript = preload("res://src/ui/hud.gd")
var TouchScript: GDScript = preload("res://src/ui/touch_controls.gd")
var SpawnerScript: GDScript = preload("res://src/spawning/enemy_spawner.gd")
var CutsceneScript: GDScript = preload("res://src/cinematics/cutscene_player.gd")
var HyperspeedScript: GDScript = preload("res://src/cinematics/hyperspeed.gd")
var PauseMenuScript: GDScript = preload("res://src/ui/pause_menu.gd")
var CrosshairScript: GDScript = preload("res://src/ui/crosshair.gd")
var transport_scene: PackedScene = preload("res://src/allies/transport.tscn")
var meteor_scene: PackedScene = preload("res://src/enemies/meteor.tscn")

var player: CharacterBody2D
var hud: CanvasLayer
var enemy_spawner: Node
var enemies_container: Node2D
var projectiles_container: Node2D
var allies_container: Node2D
var obstacles_container: Node2D
var objective_tracker: ObjectiveTracker
var midground_traffic: Node2D
var transport: Node2D
var touch_controls: CanvasLayer
var pause_menu: CanvasLayer
var crosshair: Crosshair
var is_running: bool = false
var mission: MissionData

func _ready() -> void:
	mission = MissionRegistry.get_mission(GameState.current_mission_id)
	if mission == null:
		push_error("No mission data for id %d" % GameState.current_mission_id)
		SceneTransition.change_scene("res://src/ui/main_menu.tscn")
		return

	_setup_background()
	_setup_containers()
	_setup_player()
	_setup_allies()
	_setup_obstacles()
	_setup_midground()
	_setup_hud()
	if OS.is_debug_build():
		add_child(PerfOverlay.create())
	_setup_spawner()
	_setup_objectives()
	_setup_touch()
	_setup_pause_menu()
	_setup_crosshair()
	_start_combat()

func _setup_background() -> void:
	var parallax_bg := ParallaxBackground.new()
	parallax_bg.name = "Background"
	add_child(parallax_bg)

	# Layer 1: Deep nebula (slowest parallax)
	var nebula_layer := ParallaxLayer.new()
	nebula_layer.motion_mirroring = Vector2(2048, 2048)
	nebula_layer.motion_scale = Vector2(0.1, 0.1)
	parallax_bg.add_child(nebula_layer)
	var nebula := Node2D.new()
	nebula.set_script(NebulaScript)
	nebula_layer.add_child(nebula)

	# Layer 2: Distant stars (slow)
	var star_layer := ParallaxLayer.new()
	star_layer.motion_mirroring = Vector2(2048, 2048)
	star_layer.motion_scale = Vector2(0.2, 0.2)
	parallax_bg.add_child(star_layer)
	var starfield := Node2D.new()
	starfield.set_script(StarfieldScript)
	starfield.seed_value = 1
	star_layer.add_child(starfield)

	# Layer 3: Mid-range stars (medium)
	var star_layer2 := ParallaxLayer.new()
	star_layer2.motion_mirroring = Vector2(2048, 2048)
	star_layer2.motion_scale = Vector2(0.45, 0.45)
	parallax_bg.add_child(star_layer2)
	var starfield2 := Node2D.new()
	starfield2.set_script(StarfieldScript)
	starfield2.seed_value = 2
	star_layer2.add_child(starfield2)

	# Layer 4: Near stars (faster, sparser, brighter)
	var star_layer3 := ParallaxLayer.new()
	star_layer3.motion_mirroring = Vector2(2048, 2048)
	star_layer3.motion_scale = Vector2(0.7, 0.7)
	parallax_bg.add_child(star_layer3)
	var starfield3 := Node2D.new()
	starfield3.set_script(StarfieldScript)
	starfield3.seed_value = 3
	star_layer3.add_child(starfield3)

func _setup_containers() -> void:
	enemies_container = Node2D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	projectiles_container = Node2D.new()
	projectiles_container.name = "Projectiles"
	add_child(projectiles_container)

	allies_container = Node2D.new()
	allies_container.name = "Allies"
	add_child(allies_container)

	obstacles_container = Node2D.new()
	obstacles_container.name = "Obstacles"
	add_child(obstacles_container)

func _setup_player() -> void:
	player = player_scene.instantiate()
	player.apply_loadout(ShipLoadoutRegistry.get_loadout(GameState.selected_loadout_id))
	player.global_position = Vector2.ZERO
	player.arena_radius = mission.arena_radius
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera:
		camera.zoom = Vector2.ONE * UiScale.world_zoom()
	add_child(player)
	player.fired_projectile.connect(_on_player_fired)
	player.used_special.connect(_on_player_special)

func _setup_hud() -> void:
	hud = HudScript.new()
	add_child(hud)
	hud.pause_requested.connect(_on_pause_requested)

func _setup_allies() -> void:
	if mission.transport_waypoints.is_empty():
		return
	transport = transport_scene.instantiate()
	allies_container.add_child(transport)
	transport.initialize(mission.transport_waypoints)
	transport.transport_destroyed.connect(_on_transport_destroyed)

func _on_transport_destroyed() -> void:
	objective_tracker.notify_ally_destroyed()

func _setup_obstacles() -> void:
	for pos in mission.obstacle_positions:
		var meteor := meteor_scene.instantiate()
		meteor.global_position = pos
		obstacles_container.add_child(meteor)

func _setup_midground() -> void:
	midground_traffic = Node2D.new()
	midground_traffic.set_script(TrafficScript)
	midground_traffic.name = "MidgroundTraffic"
	add_child(midground_traffic)
	midground_traffic.initialize(player, mission.background_intensity)

func _setup_touch() -> void:
	touch_controls = TouchScript.new()
	add_child(touch_controls)

func _setup_pause_menu() -> void:
	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)
	pause_menu.resumed.connect(_on_pause_resumed)
	pause_menu.main_menu_requested.connect(_on_pause_main_menu)

func _setup_crosshair() -> void:
	crosshair = CrosshairScript.new()
	add_child(crosshair)

func _unhandled_input(event: InputEvent) -> void:
	if mission_ended or pause_menu.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
		crosshair.set_active(false)

func _on_pause_resumed() -> void:
	crosshair.set_active(true)

func _on_pause_main_menu() -> void:
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")

func _on_pause_requested() -> void:
	if mission_ended or pause_menu.visible:
		return
	pause_menu.open()
	crosshair.set_active(false)

func _setup_spawner() -> void:
	enemy_spawner = SpawnerScript.new()
	enemy_spawner.name = "EnemySpawner"
	add_child(enemy_spawner)

	var wave_array: Array[WaveData] = []
	for w in mission.waves:
		wave_array.append(w)
	enemy_spawner.initialize(player, enemies_container, wave_array, mission.continuous_spawn_after_waves)

func _setup_objectives() -> void:
	objective_tracker = ObjectiveTracker.new()
	objective_tracker.name = "ObjectiveTracker"
	add_child(objective_tracker)

	var obj_array: Array[ObjectiveData] = []
	for o in mission.objectives:
		obj_array.append(o)
	objective_tracker.initialize(obj_array)
	objective_tracker.mission_complete.connect(_on_mission_complete)
	objective_tracker.mission_failed.connect(_on_mission_failed)

func _start_combat() -> void:
	GameState.reset_stats()
	GameState.is_mission_active = true
	GameState.player_damaged.connect(_on_player_damaged)
	GameState.player_died.connect(_on_player_died)
	_play_arrival_effect()

func _play_arrival_effect() -> void:
	# Brief flash + fade to simulate arriving from hyperspeed
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.9, 1.0, 0.8)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 95
	flash_layer.add_child(flash)
	add_child(flash_layer)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.6)
	tween.tween_callback(func():
		flash_layer.queue_free()
		is_running = true
	)

func _process(delta: float) -> void:
	if not is_running:
		return

	GameState.mission_time += delta

	if player and is_instance_valid(player) and player.is_alive:
		hud.update_display(
			player.health.current_hp,
			player.health.max_hp,
			GameState.kills,
			player.can_special,
			player.is_near_boundary(),
			GameState.mission_time
		)

	# Update objective display
	_update_objective_display()

	# Update wave display
	if enemy_spawner and not mission.waves.is_empty():
		var current_wave: int = mini(enemy_spawner.current_wave_index + 1, mission.waves.size())
		hud.update_wave(current_wave, mission.waves.size())

func _update_objective_display() -> void:
	var parts: PackedStringArray = []
	for i in range(objective_tracker.objectives.size()):
		var progress := objective_tracker.get_objective_progress(i)
		if progress.is_empty():
			continue
		var obj := objective_tracker.objectives[i]
		match obj.type:
			ObjectiveData.Type.DESTROY_COUNT:
				var current := mini(int(progress.current), int(progress.target))
				parts.append("Destroy: %d/%d" % [current, int(progress.target)])
			ObjectiveData.Type.SURVIVE_TIME:
				var remaining := maxf(0, progress.target - progress.current)
				var mins := int(remaining) / 60
				var secs := int(remaining) % 60
				parts.append("Survive: %d:%02d" % [mins, secs])
			ObjectiveData.Type.PROTECT_ALLY:
				if transport and is_instance_valid(transport):
					var hp_pct: float = transport.health.current_hp / transport.health.max_hp * 100.0
					parts.append("Transport: %d%%" % int(hp_pct))
				else:
					parts.append("Transport: LOST")
	hud.update_objective(" | ".join(parts))

func _on_player_fired(proj: Node2D) -> void:
	projectiles_container.add_child(proj)

func _on_player_special(pos: Vector2, radius: float) -> void:
	SpecialBurst.spawn(self, pos, radius)
	_screen_shake(12.0)

func _on_player_damaged(amount: float) -> void:
	_screen_shake(clampf(amount * 0.5, 4.0, 10.0))

var mission_ended: bool = false

func _on_player_died() -> void:
	if mission_ended:
		return
	mission_ended = true
	is_running = false
	enemy_spawner.active = false
	crosshair.set_active(false)
	hud.show_death_message()
	get_tree().create_timer(2.5).timeout.connect(func():
		SceneTransition.change_scene("res://src/ui/mission_failed.tscn")
	)

func _on_mission_complete() -> void:
	if mission_ended:
		return
	mission_ended = true
	is_running = false
	enemy_spawner.active = false
	crosshair.set_active(false)
	GameState.complete_mission(mission.id)
	hud.show_mission_complete_banner()
	get_tree().create_timer(2.0).timeout.connect(_start_completion_sequence)

func _start_completion_sequence() -> void:
	if mission.completion_briefing.is_empty():
		_play_exit_hyperspeed()
		return
	var cutscene := CutsceneScript.new() as CutscenePlayer
	add_child(cutscene)
	cutscene.play(mission.completion_briefing, "COMMAND")
	cutscene.cutscene_finished.connect(_play_exit_hyperspeed)

func _play_exit_hyperspeed() -> void:
	var hs := HyperspeedTransition.create()
	add_child(hs)
	hs.transition_midpoint.connect(func():
		get_tree().change_scene_to_file("res://src/ui/mission_complete.tscn")
	)
	hs.play()

func _on_mission_failed() -> void:
	if mission_ended:
		return
	mission_ended = true
	is_running = false
	enemy_spawner.active = false
	crosshair.set_active(false)
	hud.show_death_message()
	get_tree().create_timer(2.5).timeout.connect(func():
		SceneTransition.change_scene("res://src/ui/mission_failed.tscn")
	)

func _screen_shake(intensity: float = 6.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera == null:
		return
	var tween := create_tween()
	var shakes := int(clampf(intensity * 0.6, 3, 8))
	for i in range(shakes):
		var decay := 1.0 - float(i) / float(shakes)
		var mag := intensity * decay
		tween.tween_property(camera, "offset", Vector2(randf_range(-mag, mag), randf_range(-mag, mag)), 0.035)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)
