## Audio Manager - Handles music and SFX playback
extends Node

var _music_player: AudioStreamPlayer
var _current_music: String = ""
var _sfx_players: Dictionary = {}

## Polyphony limits
const MAX_PICKUP_XP: int = 3
const MAX_ENEMY_HIT: int = 5

var _pickup_xp_count: int = 0
var _enemy_hit_count: int = 0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = linear_to_db(0.7)
	add_child(_music_player)


func play_music(track_name: String) -> void:
	if _current_music == track_name:
		return
	var path := "res://assets/audio/music/%s.ogg" % track_name
	if not ResourceLoader.exists(path):
		return
	_current_music = track_name
	var stream := load(path) as AudioStream
	if stream:
		_music_player.stream = stream
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_current_music = ""


func play_sfx(sfx_name: String) -> void:
	# Polyphony limits
	if sfx_name == "sfx_pickup_xp" and _pickup_xp_count >= MAX_PICKUP_XP:
		return
	if sfx_name == "sfx_enemy_hit" and _enemy_hit_count >= MAX_ENEMY_HIT:
		return

	var path := "res://assets/audio/sfx/%s.ogg" % sfx_name
	if not ResourceLoader.exists(path):
		return

	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = 0.0
	add_child(player)
	player.play()

	if sfx_name == "sfx_pickup_xp":
		_pickup_xp_count += 1
	elif sfx_name == "sfx_enemy_hit":
		_enemy_hit_count += 1

	player.finished.connect(func():
		if sfx_name == "sfx_pickup_xp":
			_pickup_xp_count -= 1
		elif sfx_name == "sfx_enemy_hit":
			_enemy_hit_count -= 1
		player.queue_free()
	)
