# src/player/upgrade_registry.gd
class_name UpgradeRegistry
extends RefCounted

static func get_categories() -> Array[String]:
	return ["weapons", "engine", "shield", "armor"]

static func get_upgrades(category: String) -> Array[UpgradeData]:
	match category:
		"weapons":
			return [_weapons_basic(), _weapons_plasma(), _weapons_railgun()]
		"engine":
			return [_engine_basic(), _engine_ion(), _engine_fusion()]
		"shield":
			return [_shield_basic(), _shield_mk2(), _shield_aegis()]
		"armor":
			return [_armor_basic(), _armor_reinforced(), _armor_titanium()]
		_:
			return []

# Attach points live in ShipArt now (ShipArt.get_attach_offset), because where
# a pod or nacelle belongs depends on the hull it's bolted to.

static func get_category_color(category: String) -> Color:
	match category:
		"weapons": return Color(1.0, 0.3, 0.2)
		"engine": return Color(0.3, 0.7, 1.0)
		"shield": return Color(0.3, 1.0, 0.8)
		"armor": return Color(0.8, 0.8, 0.3)
		_: return Color(1.0, 1.0, 1.0)

# Attachment silhouettes, authored small (roughly -15..15 units) so they read
# cleanly both as a tiny ship attach-point and as a scaled-up card icon.
static func get_shape_points(category: String, tier: int) -> PackedVector2Array:
	match category:
		"weapons": return _wing_shape(tier)
		"engine": return _nacelle_shape(tier)
		"shield": return _shield_shape(tier)
		"armor": return _plate_shape(tier)
		_: return PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])

static func _wing_shape(tier: int) -> PackedVector2Array:
	match tier:
		0:
			return PackedVector2Array([Vector2(-7, -2), Vector2(3, -4), Vector2(7, -1), Vector2(3, 2), Vector2(-7, 3)])
		1:
			return PackedVector2Array([Vector2(-10, -2), Vector2(4, -6), Vector2(10, -2), Vector2(4, 2), Vector2(-10, 4)])
		_:
			return PackedVector2Array([Vector2(-13, -2), Vector2(2, -9), Vector2(13, -3), Vector2(6, 0), Vector2(13, 3), Vector2(2, 6), Vector2(-13, 4)])

static func _nacelle_shape(tier: int) -> PackedVector2Array:
	match tier:
		0:
			return PackedVector2Array([Vector2(-6, -3), Vector2(4, -3), Vector2(6, 0), Vector2(4, 3), Vector2(-6, 3)])
		1:
			return PackedVector2Array([Vector2(-10, -4), Vector2(6, -4), Vector2(10, 0), Vector2(6, 4), Vector2(-10, 4)])
		_:
			return PackedVector2Array([Vector2(-14, -5), Vector2(8, -5), Vector2(14, 0), Vector2(8, 5), Vector2(-14, 5), Vector2(-14, 2), Vector2(-17, 0), Vector2(-14, -2)])

static func _shield_shape(tier: int) -> PackedVector2Array:
	match tier:
		0: return _octagon(5)
		1: return _octagon(8)
		_: return _octagon(11, true)

static func _plate_shape(tier: int) -> PackedVector2Array:
	match tier:
		0:
			return PackedVector2Array([Vector2(-6, -4), Vector2(6, -4), Vector2(6, 4), Vector2(-6, 4)])
		1:
			return PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(11, -2), Vector2(11, 2), Vector2(9, 6), Vector2(-9, 6), Vector2(-11, 2), Vector2(-11, -2)])
		_:
			return PackedVector2Array([Vector2(-12, -8), Vector2(12, -8), Vector2(15, -3), Vector2(15, 3), Vector2(12, 8), Vector2(-12, 8), Vector2(-15, 3), Vector2(-15, -3)])

static func _octagon(r: float, notched: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var sides := 8
	for i in sides:
		var angle := (TAU / sides) * i - PI / 8.0
		var radius := r
		if notched and i % 2 == 0:
			radius += 1.5
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

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
	u.shape_points = get_shape_points("weapons", u.tier)
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
	u.shape_points = get_shape_points("weapons", u.tier)
	return u

static func _weapons_railgun() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "weapons_railgun"
	u.category = "weapons"
	u.display_name = "Railgun Array"
	u.description = "Magnetically accelerated rounds. Much faster fire rate."
	u.tier = 2
	u.cost = 600
	u.required_mission_id = 2
	u.stat_modifiers = {"fire_cooldown": -0.05}
	u.shape_points = get_shape_points("weapons", u.tier)
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
	u.shape_points = get_shape_points("engine", u.tier)
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
	u.shape_points = get_shape_points("engine", u.tier)
	return u

static func _engine_fusion() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "engine_fusion"
	u.category = "engine"
	u.display_name = "Fusion Drive"
	u.description = "Fusion-powered thrusters. Even higher top speed."
	u.tier = 2
	u.cost = 650
	u.required_mission_id = 2
	u.stat_modifiers = {"move_speed": 110.0}
	u.shape_points = get_shape_points("engine", u.tier)
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
	u.shape_points = get_shape_points("shield", u.tier)
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
	u.shape_points = get_shape_points("shield", u.tier)
	return u

static func _shield_aegis() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "shield_aegis"
	u.category = "shield"
	u.display_name = "Aegis Shield"
	u.description = "High-output shield emitter. Even larger special radius."
	u.tier = 2
	u.cost = 650
	u.required_mission_id = 3
	u.stat_modifiers = {"special_radius": 80.0}
	u.shape_points = get_shape_points("shield", u.tier)
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
	u.shape_points = get_shape_points("armor", u.tier)
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
	u.shape_points = get_shape_points("armor", u.tier)
	return u

static func _armor_titanium() -> UpgradeData:
	var u := UpgradeData.new()
	u.id = "armor_titanium"
	u.category = "armor"
	u.display_name = "Titanium Plating"
	u.description = "Military-grade titanium hull. Maximum hull points."
	u.tier = 2
	u.cost = 650
	u.required_mission_id = 3
	u.stat_modifiers = {"max_hp": 60.0}
	u.shape_points = get_shape_points("armor", u.tier)
	return u
