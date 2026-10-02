extends CharacterBody2D

@export var move_speed: float = 400.0
@export var fire_cooldown: float = 0.12
@export var special_cooldown_time: float = 8.0
@export var special_radius: float = 200.0
@export var special_damage: float = 50.0
@export var arena_radius: float = 3000.0
@export var boundary_push_strength: float = 500.0

var can_fire: bool = true
var can_special: bool = true
var is_alive: bool = true
var is_mobile: bool = false
var base_color: Color = Color(0.2, 0.8, 1.0)
var projectile_scene: PackedScene = preload("res://src/projectiles/projectile.tscn")

@onready var health: HealthComponent = $HealthComponent
@onready var muzzle: Marker2D = $Muzzle

# Built in code from ShipArt part lists (see src/player/ship_sprite.gd) rather
# than being a Polygon2D in player.tscn, so the hull the player flies is the
# exact same assembly the hangar previews.
var sprite: ShipSprite

signal fired_projectile(projectile: Node2D)
signal used_special(pos: Vector2, radius: float)

func _ready() -> void:
	add_to_group("player")
	# Fallback hull for a player dropped into a scene without apply_loadout().
	# If apply_loadout() already ran (MissionRunner calls it before add_child),
	# the sprite exists and this must not clobber it with the saved selection.
	if not is_instance_valid(sprite):
		var loadout := ShipLoadoutRegistry.get_loadout(GameState.selected_loadout_id)
		_ensure_sprite(loadout)
		_apply_muzzle_offset(loadout.id)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	is_mobile = TouchControls.is_mobile_device()
	var trail := EngineTrail.create(Color(base_color.r, base_color.g, base_color.b, 0.7), 1.0)
	add_child(trail)

func apply_loadout(loadout: ShipLoadoutData) -> void:
	var equipment := GameState.get_equipment_for(loadout.id)
	var stats := ShipStats.get_effective_stats(loadout, equipment)
	move_speed = stats.move_speed
	fire_cooldown = stats.fire_cooldown
	special_cooldown_time = stats.special_cooldown_time
	special_radius = stats.special_radius
	special_damage = stats.special_damage
	base_color = loadout.color

	var health_component: HealthComponent = get_node("HealthComponent")
	health_component.max_hp = stats.max_hp

	_ensure_sprite(loadout)
	sprite.set_ship(loadout, equipment)
	_apply_muzzle_offset(loadout.id)

func _ensure_sprite(loadout: ShipLoadoutData) -> void:
	if is_instance_valid(sprite):
		return
	sprite = ShipSprite.create(loadout)
	add_child(sprite)
	move_child(sprite, 0)

# MissionRunner calls apply_loadout() *before* adding the player to the tree, so
# @onready vars aren't resolved yet — reach these nodes via get_node(), the same
# way the health component is fetched above.
func _apply_muzzle_offset(ship_id: String) -> void:
	var muzzle_node: Marker2D = get_node("Muzzle")
	muzzle_node.position = ShipArt.get_muzzle_offset(ship_id)

func _physics_process(_delta: float) -> void:
	if not is_alive:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * move_speed

	# Soft boundary — push back when drifting too far from center
	var dist := global_position.length()
	var boundary_start := arena_radius * 0.85
	if dist > boundary_start:
		var overshoot := (dist - boundary_start) / (arena_radius * 0.15)
		velocity += -global_position.normalized() * boundary_push_strength * clampf(overshoot, 0.0, 4.0)

	move_and_slide()

	if is_mobile:
		_auto_aim()
	else:
		look_at(get_global_mouse_position())

	if Input.is_action_pressed("fire") and can_fire:
		_fire()

	if Input.is_action_just_pressed("special") and can_special:
		_use_special()

func is_near_boundary() -> bool:
	return global_position.length() > arena_radius * 0.85

func _fire() -> void:
	can_fire = false
	var proj := projectile_scene.instantiate()
	proj.global_position = muzzle.global_position
	proj.rotation = rotation
	fired_projectile.emit(proj)
	GameState.record_shot()
	MuzzleFlash.spawn(get_parent(), muzzle.global_position, rotation)
	AudioManager.play_laser()
	get_tree().create_timer(fire_cooldown).timeout.connect(func(): can_fire = true)

func _use_special() -> void:
	can_special = false
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= special_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(special_damage)
	used_special.emit(global_position, special_radius)
	AudioManager.play_special()
	get_tree().create_timer(special_cooldown_time).timeout.connect(func(): can_special = true)

func _auto_aim() -> void:
	var nearest: Node2D = null
	var nearest_dist := 9999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest:
		look_at(nearest.global_position)
	elif velocity.length() > 10.0:
		rotation = velocity.angle()

func _on_damaged(amount: float) -> void:
	GameState.damage_taken += amount
	GameState.player_damaged.emit(amount)
	AudioManager.play_player_hurt()
	if is_instance_valid(sprite):
		sprite.set_flash(Color(1.6, 0.5, 0.5))
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(sprite):
				sprite.clear_flash()
		)

func _on_died() -> void:
	is_alive = false
	visible = false
	GameState.player_died.emit()
