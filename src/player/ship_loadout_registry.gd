class_name ShipLoadoutRegistry
extends RefCounted

static func get_all_loadouts() -> Array[ShipLoadoutData]:
	var loadouts: Array[ShipLoadoutData] = []
	loadouts.append(_interceptor())
	loadouts.append(_juggernaut())
	loadouts.append(_razor())
	return loadouts

static func get_loadout(id: String) -> ShipLoadoutData:
	for loadout in get_all_loadouts():
		if loadout.id == id:
			return loadout
	return _interceptor()

static func is_unlocked(loadout: ShipLoadoutData) -> bool:
	return GameState.highest_unlocked >= loadout.unlock_mission_id

# --- Interceptor: balanced starting ship ---
static func _interceptor() -> ShipLoadoutData:
	var loadout := ShipLoadoutData.new()
	loadout.id = "interceptor"
	loadout.display_name = "Interceptor"
	loadout.description = "Balanced all-rounder. Reliable in any engagement."
	loadout.unlock_mission_id = 1
	loadout.move_speed = 400.0
	loadout.fire_cooldown = 0.12
	loadout.special_cooldown_time = 8.0
	loadout.special_radius = 200.0
	loadout.special_damage = 50.0
	loadout.max_hp = 100.0
	loadout.color = Color(0.2, 0.8, 1.0)
	loadout.polygon_points = PackedVector2Array([Vector2(-12, -10), Vector2(16, 0), Vector2(-12, 10)])
	return loadout

# --- Juggernaut: tanky, slower ---
static func _juggernaut() -> ShipLoadoutData:
	var loadout := ShipLoadoutData.new()
	loadout.id = "juggernaut"
	loadout.display_name = "Juggernaut"
	loadout.description = "Heavy plating sacrifices speed for survivability."
	loadout.unlock_mission_id = 2
	loadout.move_speed = 300.0
	loadout.fire_cooldown = 0.16
	loadout.special_cooldown_time = 10.0
	loadout.special_radius = 220.0
	loadout.special_damage = 60.0
	loadout.max_hp = 160.0
	loadout.color = Color(1.0, 0.6, 0.2)
	loadout.polygon_points = PackedVector2Array([Vector2(-16, -14), Vector2(14, 0), Vector2(-16, 14)])
	return loadout

# --- Razor: fast, fragile glass cannon ---
static func _razor() -> ShipLoadoutData:
	var loadout := ShipLoadoutData.new()
	loadout.id = "razor"
	loadout.display_name = "Razor"
	loadout.description = "Stripped-down hull built for speed and burst damage."
	loadout.unlock_mission_id = 3
	loadout.move_speed = 500.0
	loadout.fire_cooldown = 0.09
	loadout.special_cooldown_time = 7.0
	loadout.special_radius = 180.0
	loadout.special_damage = 70.0
	loadout.max_hp = 70.0
	loadout.color = Color(1.0, 0.2, 0.6)
	loadout.polygon_points = PackedVector2Array([Vector2(-10, -6), Vector2(20, 0), Vector2(-10, 6)])
	return loadout
