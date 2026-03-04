## Audio Manager - Music crossfade and SFX with polyphony limits
extends Node

const CROSSFADE_TIME: float = 0.5
const MUSIC_VOLUME_DB: float = -3.0
const SFX_VOLUME_DB: float = 0.0

## Polyphony limits per SFX name
var _polyphony_limits: Dictionary = {
	"sfx_pickup_xp": 3,
	"sfx_enemy_hit": 5,
}

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _current_music: String = ""
var _sfx_counts: Dictionary = {}


func _ready() -> void:
	_ensure_audio_buses()

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	_music_player_a.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	_music_player_b.volume_db = -80.0
	add_child(_music_player_b)

	_active_player = _music_player_a


func _ensure_audio_buses() -> void:
	# Create Music and SFX buses if they don't exist
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, 0.0)
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, SFX_VOLUME_DB)


func play_music(track_name: String) -> void:
	if _current_music == track_name:
		return
	var path := "res://assets/audio/music/%s.ogg" % track_name
	if not ResourceLoader.exists(path):
		return
	_current_music = track_name
	var stream := load(path) as AudioStream

	# Determine which player to fade in
	var fade_in: AudioStreamPlayer
	var fade_out: AudioStreamPlayer
	if _active_player == _music_player_a:
		fade_in = _music_player_b
		fade_out = _music_player_a
	else:
		fade_in = _music_player_a
		fade_out = _music_player_b

	fade_in.stream = stream
	fade_in.volume_db = -80.0
	fade_in.play()

	# Crossfade tween
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_out, "volume_db", -80.0, CROSSFADE_TIME)
	tween.tween_property(fade_in, "volume_db", MUSIC_VOLUME_DB, CROSSFADE_TIME)
	tween.chain().tween_callback(func():
		fade_out.stop()
	)

	_active_player = fade_in


func stop_music() -> void:
	_current_music = ""
	var tween := create_tween()
	tween.tween_property(_active_player, "volume_db", -80.0, CROSSFADE_TIME)
	tween.tween_callback(func():
		_music_player_a.stop()
		_music_player_b.stop()
	)


func play_sfx(sfx_name: String) -> void:
	# Check polyphony limits
	var limit: int = _polyphony_limits.get(sfx_name, 0)
	if limit > 0:
		var current_count: int = _sfx_counts.get(sfx_name, 0)
		if current_count >= limit:
			return

	var path := "res://assets/audio/sfx/%s.ogg" % sfx_name
	if not ResourceLoader.exists(path):
		return

	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = SFX_VOLUME_DB
	player.bus = "SFX"
	add_child(player)
	player.play()

	# Track polyphony
	if _polyphony_limits.has(sfx_name):
		_sfx_counts[sfx_name] = _sfx_counts.get(sfx_name, 0) + 1

	player.finished.connect(func():
		if _polyphony_limits.has(sfx_name):
			_sfx_counts[sfx_name] = max(0, _sfx_counts.get(sfx_name, 0) - 1)
		player.queue_free()
	)
