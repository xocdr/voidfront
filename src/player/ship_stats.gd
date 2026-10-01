# src/player/ship_stats.gd
class_name ShipStats
extends RefCounted

const VALID_STAT_KEYS := ["move_speed", "fire_cooldown", "special_cooldown_time", "special_radius", "special_damage", "max_hp"]

static func get_effective_stats(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> Dictionary:
	var stats := {
		"move_speed": loadout.move_speed,
		"fire_cooldown": loadout.fire_cooldown,
		"special_cooldown_time": loadout.special_cooldown_time,
		"special_radius": loadout.special_radius,
		"special_damage": loadout.special_damage,
		"max_hp": loadout.max_hp,
	}

	for category in UpgradeRegistry.get_categories():
		var upgrade_id: String = equipment.equipped.get(category, "")
		if upgrade_id.is_empty():
			continue
		var upgrade := UpgradeRegistry.get_upgrade(upgrade_id)
		if upgrade == null:
			continue
		stats = _apply_modifiers(stats, upgrade.stat_modifiers)

	return stats

static func _apply_modifiers(stats: Dictionary, modifiers: Dictionary) -> Dictionary:
	var result := stats.duplicate()
	for key in modifiers:
		if not VALID_STAT_KEYS.has(key):
			push_warning("ShipStats: ignoring unknown stat modifier key '%s'" % key)
			continue
		result[key] = result[key] + modifiers[key]
	return result
