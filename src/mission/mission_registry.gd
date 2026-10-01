class_name MissionRegistry
extends RefCounted

static var scout_scene: PackedScene = preload("res://src/enemies/scout.tscn")
static var interceptor_scene: PackedScene = preload("res://src/enemies/interceptor.tscn")
static var bomber_scene: PackedScene = preload("res://src/enemies/bomber.tscn")
static var carrier_scene: PackedScene = preload("res://src/enemies/carrier.tscn")

static func get_mission(id: int) -> MissionData:
	match id:
		1:
			return _mission_01()
		2:
			return _mission_02()
		3:
			return _mission_03()
		_:
			return null

static func get_mission_count() -> int:
	return 3

# --- Mission 01: First Contact ---
static func _mission_01() -> MissionData:
	var mission := MissionData.new()
	mission.id = 1
	mission.mission_name = "First Contact"
	mission.briefing_text = [
		"We've lost contact with Outpost Seven.",
		"Intelligence reports an unknown fleet entering the sector.",
		"Get in there and eliminate the hostile scouts.",
	]
	mission.completion_briefing = [
		"Outpost Seven is secure. Good flying out there.",
		"Intel confirms this was just a forward scouting party.",
		"The main fleet is still incoming. Stand by for further orders.",
	]
	mission.arena_radius = 3000.0

	var obj := ObjectiveData.new()
	obj.type = ObjectiveData.Type.DESTROY_COUNT
	obj.target_value = 20.0
	obj.description = "Destroy 20 enemy scouts"
	mission.objectives = [obj]

	mission.waves = [
		_wave(scout_scene, 3, 0.8, 0.0),
		_wave(scout_scene, 4, 0.7, 4.0),
		_wave(scout_scene, 5, 0.6, 4.0),
		_wave(scout_scene, 6, 0.5, 3.5),
		_wave(scout_scene, 8, 0.4, 3.0),
	]

	return mission

# --- Mission 02: Hold The Line ---
static func _mission_02() -> MissionData:
	var mission := MissionData.new()
	mission.id = 2
	mission.mission_name = "Hold The Line"
	mission.briefing_text = [
		"A supply transport is moving through hostile space.",
		"Enemy interceptors and bombers are closing on its position.",
		"Protect the transport at all costs. It must reach the rally point.",
	]
	mission.completion_briefing = [
		"Transport is clear. Supplies are secure.",
		"Command is impressed. That was precision flying.",
		"One last mission remains. The enemy flagship has been spotted.",
	]
	mission.arena_radius = 3500.0
	mission.background_intensity = 1.5

	mission.obstacle_positions = [
		Vector2(-800, -400),
		Vector2(600, 500),
		Vector2(1200, -600),
	]

	var obj_kill := ObjectiveData.new()
	obj_kill.type = ObjectiveData.Type.DESTROY_COUNT
	obj_kill.target_value = 30.0
	obj_kill.description = "Destroy 30 enemies"

	var obj_protect := ObjectiveData.new()
	obj_protect.type = ObjectiveData.Type.PROTECT_ALLY
	obj_protect.target_value = 1.0
	obj_protect.description = "Protect the transport"

	mission.objectives = [obj_kill, obj_protect]

	# Transport path — slow arc through the arena
	mission.transport_waypoints = [
		Vector2(-1500, 800),
		Vector2(-500, 200),
		Vector2(300, -300),
		Vector2(1000, 100),
		Vector2(1500, -400),
		Vector2(800, -800),
		Vector2(-200, -500),
		Vector2(-1000, 0),
	]

	mission.waves = [
		_wave(scout_scene, 4, 0.7, 0.0),
		_wave(interceptor_scene, 3, 0.8, 5.0),
		_wave(bomber_scene, 2, 1.5, 4.0),
		_wave(scout_scene, 5, 0.5, 3.0),
		_wave(interceptor_scene, 4, 0.6, 4.0),
		_wave(bomber_scene, 3, 1.2, 3.0),
		_wave(scout_scene, 6, 0.4, 3.0),
		_wave(interceptor_scene, 4, 0.5, 2.5),
	]

	return mission

# --- Mission 03: The Swarm ---
static func _mission_03() -> MissionData:
	var mission := MissionData.new()
	mission.id = 3
	mission.mission_name = "The Swarm"
	mission.briefing_text = [
		"This is it. The enemy flagship — a Carrier — has entered the sector.",
		"It's deploying fighters at an alarming rate.",
		"Survive the onslaught and destroy everything you can.",
		"This ends now.",
	]
	mission.completion_briefing = [
		"Contact eliminated. The sector is clear.",
		"That was the hardest fight of the war so far.",
		"You've earned some rest, pilot. Well done.",
	]
	mission.arena_radius = 4000.0
	mission.background_intensity = 2.0

	var obj_survive := ObjectiveData.new()
	obj_survive.type = ObjectiveData.Type.SURVIVE_TIME
	obj_survive.target_value = 120.0
	obj_survive.description = "Survive for 2 minutes"

	mission.objectives = [obj_survive]

	mission.waves = [
		_wave(scout_scene, 5, 0.5, 0.0),
		_wave(interceptor_scene, 3, 0.7, 5.0),
		_wave(scout_scene, 6, 0.4, 4.0),
		_wave(bomber_scene, 2, 1.5, 3.0),
		_wave(interceptor_scene, 5, 0.5, 4.0),
		_wave(carrier_scene, 1, 0.0, 6.0),
		_wave(scout_scene, 8, 0.3, 3.0),
		_wave(interceptor_scene, 6, 0.4, 3.0),
		_wave(bomber_scene, 3, 1.0, 2.5),
		_wave(scout_scene, 10, 0.25, 2.0),
	]
	mission.continuous_spawn_after_waves = true

	return mission

static func _wave(scene: PackedScene, count: int, spawn_delay: float, wave_delay: float, bias: String = "any") -> WaveData:
	var w := WaveData.new()
	w.enemy_scene = scene
	w.count = count
	w.spawn_delay = spawn_delay
	w.wave_delay = wave_delay
	w.direction_bias = bias
	return w
