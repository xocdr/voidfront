extends Node

var sfx_laser: AudioStreamWAV
var sfx_explosion: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_special: AudioStreamWAV
var sfx_player_hurt: AudioStreamWAV
var sfx_menu_select: AudioStreamWAV

const MIX_RATE: int = 22050
const SFX_POOL_SIZE: int = 8

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index: int = 0

const MENU_MUSIC_VOLUME_DB: float = -10.0
var menu_music: AudioStream = preload("res://src/bg_music/main_menu.mp3")
var music_player: AudioStreamPlayer
var _music_tween: Tween

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = MENU_MUSIC_VOLUME_DB
	add_child(music_player)
	if menu_music is AudioStreamMP3:
		menu_music.loop = true

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

	sfx_laser = _generate_laser()
	sfx_explosion = _generate_explosion()
	sfx_hit = _generate_hit()
	sfx_special = _generate_special()
	sfx_player_hurt = _generate_player_hurt()
	sfx_menu_select = _generate_menu_select()

# Menu music loops until stop_music(). Safe to call from every menu screen: if
# it is already playing it carries on instead of restarting from the top.
func play_menu_music() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	music_player.volume_db = MENU_MUSIC_VOLUME_DB
	if music_player.playing and music_player.stream == menu_music:
		return
	music_player.stream = menu_music
	music_player.play()

func stop_music(fade_time: float = 0.5) -> void:
	if not music_player.playing:
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if fade_time <= 0.0:
		music_player.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", -60.0, fade_time)
	_music_tween.tween_callback(music_player.stop)

func play_laser() -> void:
	_play(sfx_laser, -12.0)

func play_explosion() -> void:
	_play(sfx_explosion, -6.0)

func play_hit() -> void:
	_play(sfx_hit, -10.0)

func play_special() -> void:
	_play(sfx_special, -4.0)

func play_player_hurt() -> void:
	_play(sfx_player_hurt, -6.0)

func play_menu_select() -> void:
	_play(sfx_menu_select, -8.0)

func _play(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	var player := sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()

# --- Procedural sound generation ---

func _generate_laser() -> AudioStreamWAV:
	var samples := int(MIX_RATE * 0.08)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(MIX_RATE)
		var env := 1.0 - float(i) / float(samples)
		env *= env
		var freq := lerpf(2200.0, 800.0, float(i) / float(samples))
		var val := sin(t * freq * TAU) * env * 0.4
		var sample := clampi(int(val * 32767), -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_stream(data)

func _generate_explosion() -> AudioStreamWAV:
	var samples := int(MIX_RATE * 0.35)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(samples):
		var t := float(i) / float(samples)
		var env := (1.0 - t) * (1.0 - t)
		if t < 0.05:
			env = t / 0.05
		var noise := rng.randf_range(-1.0, 1.0)
		var low := sin(float(i) / float(MIX_RATE) * 60.0 * TAU * (1.0 - t * 0.5))
		var val := (noise * 0.6 + low * 0.4) * env * 0.5
		var sample := clampi(int(val * 32767), -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_stream(data)

func _generate_hit() -> AudioStreamWAV:
	var samples := int(MIX_RATE * 0.04)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(samples):
		var env := 1.0 - float(i) / float(samples)
		var noise := rng.randf_range(-1.0, 1.0)
		var tone := sin(float(i) / float(MIX_RATE) * 1500.0 * TAU)
		var val := (noise * 0.5 + tone * 0.5) * env * 0.3
		var sample := clampi(int(val * 32767), -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_stream(data)

func _generate_special() -> AudioStreamWAV:
	var samples := int(MIX_RATE * 0.25)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(MIX_RATE)
		var progress := float(i) / float(samples)
		var env := 1.0 - progress
		if progress < 0.1:
			env = progress / 0.1
		var freq := lerpf(300.0, 1200.0, progress)
		var val := sin(t * freq * TAU) * env * 0.35
		val += sin(t * freq * 1.5 * TAU) * env * 0.15
		var sample := clampi(int(val * 32767), -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_stream(data)

func _generate_player_hurt() -> AudioStreamWAV:
	var samples := int(MIX_RATE * 0.15)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(samples):
		var t := float(i) / float(MIX_RATE)
		var progress := float(i) / float(samples)
		var env := 1.0 - progress
		var noise := rng.randf_range(-1.0, 1.0) * 0.3
		var tone := sin(t * 200.0 * TAU) * 0.4
		var val := (noise + tone) * env * 0.4
		var sample := clampi(int(val * 32767), -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_stream(data)

func _generate_menu_select() -> AudioStreamWAV:
	var samples := int(MIX_RATE * 0.06)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(MIX_RATE)
		var env := 1.0 - float(i) / float(samples)
		var val := sin(t * 880.0 * TAU) * env * 0.25
		var sample := clampi(int(val * 32767), -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_stream(data)

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
