extends Node

@export var spawn_distance: float = 900.0
@export var max_enemies: int = 25

var scout_scene: PackedScene = preload("res://src/enemies/scout.tscn")
var player: Node2D
var enemies_container: Node2D
var active: bool = false

var waves: Array[WaveData] = []
var current_wave_index: int = 0
var wave_timer: float = 0.0
var spawn_timer: float = 0.0
var spawned_in_wave: int = 0
var wave_active: bool = false
var all_waves_done: bool = false
var continuous_after_waves: bool = false

signal all_waves_spawned

func initialize(p_player: Node2D, p_container: Node2D, p_waves: Array[WaveData] = [], p_continuous_after_waves: bool = false) -> void:
	player = p_player
	enemies_container = p_container
	waves = p_waves
	continuous_after_waves = p_continuous_after_waves
	active = true

	if waves.is_empty():
		_start_endless_mode()
	else:
		current_wave_index = 0
		wave_timer = waves[0].wave_delay
		wave_active = wave_timer <= 0.0
		if wave_active:
			spawned_in_wave = 0
			spawn_timer = 0.0

func _start_endless_mode() -> void:
	# Fallback: continuous spawning like Phase 1
	waves = []
	wave_active = true

var endless_interval: float = 1.8
var endless_min_interval: float = 0.4
var endless_ramp: float = 0.02
var endless_timer: float = 0.0

func _process(delta: float) -> void:
	if not active or player == null or not is_instance_valid(player):
		return

	if waves.is_empty():
		_process_endless(delta)
		return

	if all_waves_done:
		return

	if not wave_active:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_active = true
			spawned_in_wave = 0
			spawn_timer = 0.0
		return

	if current_wave_index >= waves.size():
		return

	var wave := waves[current_wave_index]
	spawn_timer -= delta
	if spawn_timer <= 0.0 and spawned_in_wave < wave.count:
		if enemies_container.get_child_count() < max_enemies:
			_spawn_enemy(wave)
			spawned_in_wave += 1
			spawn_timer = wave.spawn_delay

	if spawned_in_wave >= wave.count:
		current_wave_index += 1
		wave_active = false
		if current_wave_index >= waves.size():
			all_waves_done = true
			all_waves_spawned.emit()
			if continuous_after_waves:
				waves = []
				endless_timer = 0.0
		else:
			wave_timer = waves[current_wave_index].wave_delay

func _process_endless(delta: float) -> void:
	endless_interval = maxf(endless_min_interval, endless_interval - endless_ramp * delta)
	endless_timer -= delta
	if endless_timer <= 0.0:
		endless_timer = endless_interval
		if enemies_container.get_child_count() < max_enemies:
			_spawn_at_angle(scout_scene, randf() * TAU)

func _spawn_enemy(wave: WaveData) -> void:
	var scene: PackedScene = wave.enemy_scene if wave.enemy_scene else scout_scene
	var angle := _get_spawn_angle(wave.direction_bias)
	_spawn_at_angle(scene, angle)

func _spawn_at_angle(scene: PackedScene, angle: float) -> void:
	var enemy := scene.instantiate()
	var offset := Vector2(cos(angle), sin(angle)) * spawn_distance
	offset *= randf_range(0.85, 1.15)
	enemy.global_position = player.global_position + offset
	enemy.target = player
	enemies_container.add_child(enemy)

func _get_spawn_angle(bias: String) -> float:
	match bias:
		"north":
			return randf_range(-PI * 0.75, -PI * 0.25)
		"south":
			return randf_range(PI * 0.25, PI * 0.75)
		"east":
			return randf_range(-PI * 0.25, PI * 0.25)
		"west":
			return randf_range(PI * 0.75, PI * 1.25)
		_:
			return randf() * TAU
