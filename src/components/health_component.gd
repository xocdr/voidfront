class_name HealthComponent
extends Node

@export var max_hp: float = 100.0
var current_hp: float

signal damaged(amount: float)
signal died

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	if current_hp <= 0:
		return
	current_hp -= amount
	damaged.emit(amount)
	if current_hp <= 0:
		current_hp = 0
		died.emit()

func heal(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp)

func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return current_hp / max_hp
