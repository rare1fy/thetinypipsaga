## 音效播放器 — 统一管理所有音效和背景音乐
## 支持合成SFX（AudioStreamGenerator）+ 文件SFX（.ogg/.wav）+ BGM（.mp3/.ogg）
## 对应原版: engine/soundPlayer.ts + data/soundEffects.ts

extends Node

## BGM曲目映射（ID → 资源路径）
const BGM_MAP := {
	"start": "res://audio/music/DiceBattle-Start.mp3",
	"explore": "res://audio/music/DiceBattle-Outside.mp3",
	"battle": "res://audio/music/DiceBattle-Normal.mp3",
	"boss": "res://audio/music/DiceBattle-Boss.mp3",
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
const SFX_POOL_SIZE := 12  # 增大池子适配多层合成音效

var music_volume: float = 0.5
var sfx_volume: float = 0.7
var sfx_enabled: bool = true
var bgm_enabled: bool = true

var _current_bgm: String = ""

# 抖音小游戏 / Web 环境合成音效降级标志
# AudioStreamGenerator 在 WebGL 导出下存在兼容性问题（见 DOUYIN-GODOT-RULES 6.2），
# 桌面端 (Steam) 保留完整合成音效，Web 端静默回退到文件 SFX 或直接 no-op。
var _is_web_platform: bool = false

# 文件 SFX 缺失告警去重表（sound_id → true），避免每次 play_sound 刷日志
var _missing_sfx_warned: Dictionary = {}

func _ready() -> void:
	_is_web_platform = OS.has_feature("web")
	# 创建音乐播放器
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	# 创建 SFX 对象池
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

## ==========================================
## SFX 播放
## ==========================================

## 播放合成音效（优先）— 由 SynthSFX 引擎实时生成
func play_sound(sound_id: String) -> void:
	if not sfx_enabled:
		return
	# Web 平台跳过合成音效，直接走文件 SFX 回退
	if _is_web_platform:
		_play_file_sfx(sound_id)
		return
	# 1. 尝试合成音效
	if SynthSFX.play(sound_id, _get_next_sfx_player()):
		return
	# 2. 回退到文件音效
	_play_file_sfx(sound_id)

## 播放递进结算音效
func play_settlement_tick(step: int) -> void:
	if not sfx_enabled:
		return
	if _is_web_platform:
		return  # Web 平台跳过实时合成
	var player := _get_next_sfx_player()
	SynthSFX.play_settlement_tick(player, step)

## 播放乘区触发音效
func play_multiplier_tick(step: int) -> void:
	if not sfx_enabled:
		return
	if _is_web_platform:
		return  # Web 平台跳过实时合成
	var player := _get_next_sfx_player()
	SynthSFX.play_multiplier_tick(player, step)

## 播放大伤害重击音效
func play_heavy_impact(intensity: float = 1.0) -> void:
	if not sfx_enabled:
		return
	if _is_web_platform:
		return  # Web 平台跳过实时合成
	var player := _get_next_sfx_player()
	SynthSFX.play_heavy_impact(player, intensity)


## 获取下一个可用的 SFX 播放器
func _get_next_sfx_player() -> AudioStreamPlayer:
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	return player


## 文件SFX回退
func _play_file_sfx(sound_id: String) -> void:
	var path := "res://audio/sfx/%s.ogg" % sound_id
	if not ResourceLoader.exists(path):
		path = "res://audio/sfx/%s.wav" % sound_id
	if not ResourceLoader.exists(path):
		# Web 端 v0.1 阶段 audio/sfx 资产未填充，此分支必 miss → 静音
		# 每个 sound_id 仅警告一次，避免日志刷屏
		if not _missing_sfx_warned.has(sound_id):
			_missing_sfx_warned[sound_id] = true
			push_warning("SoundPlayer: 文件SFX缺失 res://audio/sfx/%s[.ogg|.wav]（Web 端 v0.1 阶段预期静音）" % sound_id)
		return
	var stream := load(path) as AudioStream
	if not stream:
		return
	var player := _get_next_sfx_player()
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	player.play()


## ==========================================
## BGM 控制
## ==========================================

## 播放背景音乐
func play_music(track_id: String, fade_time: float = 1.0) -> void:
	if not bgm_enabled:
		return
	if _current_bgm == track_id and _music_player.playing:
		return

	var path: String
	if BGM_MAP.has(track_id):
		path = BGM_MAP[track_id]
	else:
		path = "res://audio/music/%s.ogg" % track_id

	if not ResourceLoader.exists(path):
		path = "res://audio/music/%s.mp3" % track_id
	if not ResourceLoader.exists(path):
		return

	var stream := load(path) as AudioStream
	if not stream:
		return

	if _music_player.playing:
		var old_player := _music_player
		# 创建新播放器用于淡入
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Music"
		add_child(_music_player)
		# 淡出旧音乐
		var tween := create_tween()
		tween.tween_property(old_player, "volume_db", -80.0, fade_time)
		tween.tween_callback(old_player.stop)
		tween.tween_callback(old_player.queue_free)
	else:
		# 停止后重新开始
		_music_player.stop()

	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	_current_bgm = track_id

	# 淡入新音乐
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", linear_to_db(music_volume), fade_time)


## 停止背景音乐
func stop_music(fade_time: float = 1.0) -> void:
	if not _music_player.playing:
		return
	_current_bgm = ""
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_time)
	tween.tween_callback(_music_player.stop)


## ==========================================
## 音量与开关
## ==========================================

## 设置音乐音量 (0.0~1.0)
func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	if _music_player.playing:
		_music_player.volume_db = linear_to_db(music_volume)


## 设置音效音量 (0.0~1.0)
func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


## 设置音效开关
func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled


## 设置BGM开关
func set_bgm_enabled(enabled: bool) -> void:
	bgm_enabled = enabled
	if not enabled:
		stop_music()
