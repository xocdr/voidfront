class_name Meteor
extends CharacterBody2D

@export var min_drift_speed: float = 15.0
@export var max_drift_speed: float = 35.0
@export var max_hp: float = 300.0
@export var contact_damage: float = 20.0
@export var contact_cooldown: float = 0.8

var can_deal_contact: bool = true
var spin_speed: float = 0.0

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group("obstacles")
	health.max_hp = max_hp
	health.current_hp = max_hp
	health.died.connect(_on_died)
	health.damaged.connect(_on_hit)
	$ContactArea.body_entered.connect(_on_contact_body_entered)

	var drift_angle := randf() * TAU
	var drift_speed := randf_range(min_drift_speed, max_drift_speed)
	velocity = Vector2(cos(drift_angle), sin(drift_angle)) * drift_speed
	spin_speed = randf_range(-0.3, 0.3)

func _physics_process(delta: float) -> void:
	rotation += spin_speed * delta
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
	queue_free()

func _on_contact_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.is_in_group("allies") or body.is_in_group("enemies")) and can_deal_contact:
		if body.has_node("HealthComponent"):
			body.get_node("HealthComponent").take_damage(contact_damage)
			can_deal_contact = false
			get_tree().create_timer(contact_cooldown).timeout.connect(
				func(): can_deal_contact = true
			)
