# src/player/upgrade_registry.gd
class_name UpgradeRegistry
extends RefCounted

static func get_categories() -> Array[String]:
	return ["weapons", "engine", "shield", "armor"]

static func get_upgrades(category: String) -> Array[UpgradeData]:
	match category:
		"weapons":
			return [_weapons_basic(), _weapons_plasma()]
		"engine":
			return [_engine_basic(), _engine_ion()]
		"shield":
			return [_shield_basic(), _shield_mk2()]
		"armor":
			return [_armor_basic(), _armor_reinforced()]
		_:
			return []

static func get_upgrade(id: String) -> UpgradeData:
	for category in get_categories():
		for upgrade in get_upgrades(category):
			if upgrade.id == id:
				return upgrade
	return null

static func get_starter_upgrade(category: String) -> UpgradeData:
	for upgrade in get_upgrades(category):
		if upgrade.tier == 0:
			return upgrade
	return null

# --- Weapons ---
static func _weapons_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "weapons_basic"
	u.category = "weapons"
	u.display_name = "Basic Cannon"
	u.description = "Standard-issue ballistic cannon."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _weapons_plasma() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "weapons_plasma"
	u.category = "weapons"
	u.display_name = "Plasma Cannon"
	u.description = "Superheated plasma rounds. Faster fire rate."
	u.tier = 1
	u.cost = 300
	u.required_mission_id = 1
	u.stat_modifiers = {"fire_cooldown": -0.03}
	return u

# --- Engine ---
static func _engine_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "engine_basic"
	u.category = "engine"
	u.display_name = "Basic Engine"
	u.description = "Factory-standard thrusters."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _engine_ion() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "engine_ion"
	u.category = "engine"
	u.display_name = "Ion Engine"
	u.description = "Ion-driven propulsion. Higher top speed."
	u.tier = 1
	u.cost = 300
	u.required_mission_id = 1
	u.stat_modifiers = {"move_speed": 60.0}
	return u

# --- Shield ---
static func _shield_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "shield_basic"
	u.category = "shield"
	u.display_name = "Basic Shield"
	u.description = "Standard deflector plating."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _shield_mk2() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "shield_mk2"
	u.category = "shield"
	u.display_name = "Mk2 Shield"
	u.description = "Reinforced shield emitter. Larger special radius."
	u.tier = 1
	u.cost = 350
	u.required_mission_id = 2
	u.stat_modifiers = {"special_radius": 40.0}
	return u

# --- Armor ---
static func _armor_basic() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "armor_basic"
	u.category = "armor"
	u.display_name = "Basic Armor"
	u.description = "Standard hull plating."
	u.tier = 0
	u.cost = 0
	u.required_mission_id = 1
	u.stat_modifiers = {}
	return u

static func _armor_reinforced() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "armor_reinforced"
	u.category = "armor"
	u.display_name = "Reinforced Armor"
	u.description = "Thicker plating. More hull points."
	u.tier = 1
	u.cost = 350
	u.required_mission_id = 2
	u.stat_modifiers = {"max_hp": 30.0}
	return u
