class_name BaseEnemy
extends CharacterBody2D

@export var move_speed: float = 150.0
@export var contact_damage: float = 15.0
@export var contact_cooldown: float = 0.8
@export var despawn_distance: float = 2000.0

var target: Node2D
var can_deal_contact: bool = true

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	health.died.connect(_on_died)
	health.damaged.connect(_on_hit)
	$ContactArea.body_entered.connect(_on_contact_body_entered)
	_find_target()
	var trail := EngineTrail.create(Color(1.0, 0.4, 0.2, 0.5), 0.6)
	add_child(trail)

func _find_target() -> void:
	if target != null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_find_target()
		return
	move_toward_target()
	# Despawn when too far from target
	if global_position.distance_to(target.global_position) > despawn_distance:
		queue_free()

func move_toward_target() -> void:
	var direction := (target.global_position - global_position).normalized()
	velocity = direction * move_speed
	rotation = direction.angle()
	move_and_slide()

func _on_hit(_amount: float) -> void:
	AudioManager.play_hit()
	var shape_node := get_node_or_null("Shape")
	if shape_node and shape_node is Polygon2D:
		var original: Color = shape_node.color
		shape_node.color = Color.WHITE
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(shape_node):
				shape_node.color = original
		)

func _on_died() -> void:
	ExplosionEffect.spawn(get_tree().root, global_position)
	AudioManager.play_explosion()
	GameState.record_kill()
	queue_free()

func _on_contact_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.is_in_group("allies")) and can_deal_contact:
		if body.has_node("HealthComponent"):
			body.get_node("HealthComponent").take_damage(contact_damage)
			can_deal_contact = false
			get_tree().create_timer(contact_cooldown).timeout.connect(
				func(): can_deal_contact = true
			)
