# src/player/ship_sprite.gd
#
# Code-only node (no .tscn) that assembles a ship's hull and its four
# attachment layers out of `ShipArt` part lists. Used by both the in-mission
# player and the hangar preview so the two can never drift apart visually.
#
# Layer order back-to-front: engine (plumes trail behind the hull), hull,
# armor (plating bolted on top), weapons (pods over the wings), shield
# (translucent emitter bands wrapping everything).
class_name ShipSprite
extends Node2D

const _LAYER_ORDER := ["engine", "hull", "armor", "weapons", "shield"]

var ship_id: String = "interceptor"
var base_color: Color = Color(0.2, 0.8, 1.0)

var _hull_root: Node2D
var _attach_roots: Dictionary = {}

static func create(loadout: ShipLoadoutData, equipment: ShipEquipmentState = null, art_scale: float = 1.0) -> ShipSprite:
	var sprite := ShipSprite.new()
	sprite.scale = Vector2(art_scale, art_scale)
	sprite._build_roots()
	sprite.set_ship(loadout, equipment)
	return sprite

func _build_roots() -> void:
	for layer in _LAYER_ORDER:
		var root := Node2D.new()
		root.name = layer.capitalize()
		add_child(root)
		if layer == "hull":
			_hull_root = root
		else:
			_attach_roots[layer] = root

func set_ship(loadout: ShipLoadoutData, equipment: ShipEquipmentState = null) -> void:
	if _hull_root == null:
		_build_roots()
	ship_id = loadout.id
	base_color = loadout.color

	_clear(_hull_root)
	ShipArt.build_parts(_hull_root, ShipArt.get_hull_parts(ship_id), base_color)

	for category in UpgradeRegistry.get_categories():
		var upgrade: UpgradeData = null
		if equipment != null:
			var upgrade_id: String = equipment.equipped.get(category, "")
			if not upgrade_id.is_empty():
				upgrade = UpgradeRegistry.get_upgrade(upgrade_id)
		set_attachment(category, upgrade)

# `tint_override` lets the hangar render an unconfirmed preview in a different
# colour without touching the equipped loadout.
func set_attachment(category: String, upgrade: UpgradeData, tint_override: Color = Color(0, 0, 0, 0)) -> void:
	if not _attach_roots.has(category):
		return
	var root: Node2D = _attach_roots[category]
	_clear(root)
	root.position = ShipArt.get_attach_offset(ship_id, category)
	if upgrade == null:
		return
	var base := UpgradeRegistry.get_category_color(category)
	if tint_override.a > 0.0:
		base = tint_override
	ShipArt.build_parts(root, ShipArt.get_attachment_parts(category, upgrade.tier, ship_id), base)

func get_attach_position(category: String) -> Vector2:
	return ShipArt.get_attach_offset(ship_id, category)

# Hit flash: tint the whole assembly rather than one polygon, so every part
# (hull, pods, plating) flashes together.
func set_flash(color: Color) -> void:
	modulate = color

func clear_flash() -> void:
	modulate = Color.WHITE

func _clear(root: Node2D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
