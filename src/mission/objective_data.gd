class_name ObjectiveData
extends Resource

enum Type { DESTROY_COUNT, SURVIVE_TIME, PROTECT_ALLY }

@export var type: Type = Type.DESTROY_COUNT
@export var target_value: float = 20.0
@export var description: String = ""
