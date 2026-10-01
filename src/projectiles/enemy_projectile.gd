extends Area2D

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

var direction: Vector2

func _ready() -> void:
	direction = Vector2.RIGHT.rotated(rotation)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_node("HealthComponent"):
			body.get_node("HealthComponent").take_damage(damage)
		LaserImpact.spawn(get_tree().root, global_position)
		queue_free()
	elif body.is_in_group("allies"):
		if body.has_node("HealthComponent"):
			body.get_node("HealthComponent").take_damage(damage)
		LaserImpact.spawn(get_tree().root, global_position)
		queue_free()
	elif body.is_in_group("obstacles"):
		if body.has_node("HealthComponent"):
			body.get_node("HealthComponent").take_damage(damage)
		LaserImpact.spawn(get_tree().root, global_position)
		queue_free()
