## 合成音效引擎 — 将原版 Web Audio API 合成音效转译为 Godot AudioStreamGenerator
## 所有 SFX 都是实时波形合成，零音频文件依赖
## 对应原版: data/sounds/combat.ts, ui.ts, status.ts, cinematic.ts, soundEffects.ts

class_name SynthSFX

## 振荡器类型枚举（映射 Web Audio OscillatorType）
enum WaveType { SINE, SQUARE, SAWTOOTH, TRIANGLE }

## 音效ID → 生成函数的注册表
static var _registry: Dictionary = {}

## 初始化注册表（延迟加载）
static func _ensure_registry() -> void:
	if not _registry.is_empty():
		return
	# — UI交互 —
	_registry["roll"] = _play_roll
	_registry["select"] = _play_select
	_registry["dice_lock"] = _play_dice_lock
	_registry["reroll"] = _play_reroll
	_registry["coin"] = _play_coin
	_registry["shop_buy"] = _play_shop_buy
	_registry["map_move"] = _play_map_move
	_registry["campfire"] = _play_campfire
	_registry["event"] = _play_event
	_registry["turn_end"] = _play_turn_end
	_registry["relic_activate"] = _play_relic_activate
	_registry["levelup"] = _play_levelup
	# — 战斗 —
	_registry["hit"] = _play_hit
	_registry["critical"] = _play_critical
	_registry["armor"] = _play_armor
	_registry["shield_break"] = _play_shield_break
	_registry["skill"] = _play_skill
	_registry["enemy"] = _play_enemy
	_registry["player_attack"] = _play_player_attack
	_registry["player_aoe"] = _play_player_aoe
	_registry["enemy_defend"] = _play_enemy_defend
	_registry["enemy_skill"] = _play_enemy_skill
	# — 状态/持续效果 —
	_registry["heal"] = _play_heal
	_registry["poison"] = _play_poison
	_registry["burn"] = _play_burn
	_registry["enemy_heal"] = _play_enemy_heal
	# — 过场/剧情 —
	_registry["victory"] = _play_victory
	_registry["defeat"] = _play_defeat
	_registry["boss_appear"] = _play_boss_appear
	_registry["enemy_death"] = _play_enemy_death
	_registry["player_death"] = _play_player_death
	_registry["boss_laugh"] = _play_boss_laugh
	_registry["gate_close"] = _play_gate_close
	_registry["enemy_speak"] = _play_enemy_speak


## ==========================================
## 核心：播放合成音效
## ==========================================

static func play(sound_id: String, player: AudioStreamPlayer) -> bool:
	_ensure_registry()
	if not _registry.has(sound_id):
		return false
	_registry[sound_id].call(player)
	return true


## 递进音调结算音效 — 每颗骰子计分时音调升半阶
static func play_settlement_tick(player: AudioStreamPlayer, step: int) -> void:
	var base_freq := 523.25  # C5
	var freq := base_freq * pow(2.0, step / 12.0)
	var harm_freq := freq * 1.5
	var data := _begin(player)
	# 主音 sine
	_add_tone(data, freq, WaveType.SINE, 0.28, 0.0, 0.12, freq * 1.2)
	# 泛音层 triangle
	_add_tone(data, harm_freq, WaveType.TRIANGLE, 0.14, 0.0, 0.08, 0.0)
	# 金币碰撞感 square
	_add_tone(data, freq * 3.0, WaveType.SQUARE, 0.08, 0.0, 0.03, 0.0)
	_commit(data)


## 乘区触发音效
static func play_multiplier_tick(player: AudioStreamPlayer, step: int) -> void:
	var base_freq := 392.0  # G4
	var freq := base_freq * pow(2.0, step / 8.0)
	var data := _begin(player)
	_add_tone(data, freq * 0.5, WaveType.SAWTOOTH, 0.2, 0.0, 0.2, freq * 0.3)
	_add_tone(data, freq * 2.0, WaveType.SINE, 0.22, 0.0, 0.12, freq * 2.5)
	_commit(data)


## 大伤害重击音效
static func play_heavy_impact(player: AudioStreamPlayer, intensity: float = 1.0) -> void:
	var data := _begin(player, 0.7 + intensity * 0.3)
	# 超低频冲击
	_add_tone(data, 60.0, WaveType.SINE, 0.3, 0.0, 0.5, 20.0)
	# 金属撞击
	_add_tone(data, 80.0, WaveType.SAWTOOTH, 0.2, 0.0, 0.4, 16.0)
	_add_tone(data, 160.0, WaveType.SQUARE, 0.2, 0.015, 0.4, 32.0)
	_add_tone(data, 320.0, WaveType.SQUARE, 0.2, 0.03, 0.4, 64.0)
	# 碎裂高频
	_add_tone(data, 2000.0, WaveType.SAWTOOTH, 0.1 * intensity, 0.05, 0.2, 200.0)
	_commit(data)


## ==========================================
## UI交互音效
## ==========================================

static func _play_roll(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 200.0, WaveType.SQUARE, 0.16, 0.0, 0.15, 60.0)
	_add_tone(d, 800.0, WaveType.SAWTOOTH, 0.08, 0.0, 0.08, 100.0)
	_commit(d)

static func _play_select(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 523.0, WaveType.SINE, 0.22, 0.0, 0.08, 784.0)
	_commit(d)

static func _play_dice_lock(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 659.0, WaveType.SINE, 0.2, 0.0, 0.1, 0.0)
	_add_tone(d, 880.0, WaveType.SINE, 0.2, 0.05, 0.1, 0.0)
	_commit(d)

static func _play_reroll(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	for i in range(5):
		_add_tone(d, 150.0 + randf() * 200.0, WaveType.SQUARE, 0.18, i * 0.03, 0.05, 0.0)
	_commit(d)

static func _play_coin(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 1047.0, WaveType.SINE, 0.18, 0.0, 0.15, 0.0)
	_add_tone(d, 1319.0, WaveType.SINE, 0.18, 0.06, 0.15, 0.0)
	_add_tone(d, 1568.0, WaveType.SINE, 0.18, 0.12, 0.15, 0.0)
	_commit(d)

static func _play_shop_buy(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 880.0, WaveType.SINE, 0.2, 0.0, 0.15, 0.0)
	_add_tone(d, 1047.0, WaveType.SINE, 0.2, 0.07, 0.15, 0.0)
	_add_tone(d, 1319.0, WaveType.SINE, 0.2, 0.14, 0.15, 0.0)
	_commit(d)

static func _play_map_move(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 392.0, WaveType.SINE, 0.2, 0.0, 0.1, 523.0)
	_commit(d)

static func _play_campfire(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	for i in range(3):
		_add_tone(d, 100.0 + randf() * 100.0, WaveType.SAWTOOTH, 0.12, i * 0.1, 0.15, 0.0)
	_commit(d)

static func _play_event(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 330.0, WaveType.SINE, 0.22, 0.0, 0.5, 330.0)  # 330→440→330
	_commit(d)

static func _play_turn_end(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 440.0, WaveType.TRIANGLE, 0.2, 0.0, 0.25, 220.0)
	_commit(d)

static func _play_relic_activate(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 659.0, WaveType.SINE, 0.2, 0.0, 0.12, 0.0)
	_add_tone(d, 784.0, WaveType.SINE, 0.2, 0.04, 0.12, 0.0)
	_add_tone(d, 988.0, WaveType.SINE, 0.2, 0.08, 0.12, 0.0)
	_commit(d)

static func _play_levelup(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 440.0, WaveType.SINE, 0.24, 0.0, 0.4, 0.0)
	_add_tone(d, 554.0, WaveType.SINE, 0.24, 0.1, 0.4, 0.0)
	_add_tone(d, 659.0, WaveType.SINE, 0.24, 0.2, 0.4, 0.0)
	_add_tone(d, 880.0, WaveType.SINE, 0.24, 0.3, 0.4, 0.0)
	_commit(d)


## ==========================================
## 战斗音效
## ==========================================

static func _play_hit(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 120.0, WaveType.SAWTOOTH, 0.22, 0.0, 0.25, 30.0)
	_add_tone(d, 60.0, WaveType.SQUARE, 0.16, 0.0, 0.15, 20.0)
	_commit(d)

static func _play_critical(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 80.0, WaveType.SAWTOOTH, 0.25, 0.0, 0.35, 24.0)
	_add_tone(d, 120.0, WaveType.SAWTOOTH, 0.25, 0.02, 0.35, 36.0)
	_add_tone(d, 200.0, WaveType.SQUARE, 0.25, 0.04, 0.35, 60.0)
	_commit(d)

static func _play_armor(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 300.0, WaveType.TRIANGLE, 0.25, 0.0, 0.2, 600.0)
	_commit(d)

static func _play_shield_break(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 600.0, WaveType.SAWTOOTH, 0.25, 0.0, 0.3, 50.0)
	_commit(d)

static func _play_skill(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 400.0, WaveType.SAWTOOTH, 0.25, 0.0, 0.3, 800.0)
	_commit(d)

static func _play_enemy(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 110.0, WaveType.SAWTOOTH, 0.4, 0.0, 0.55, 20.0)
	_add_tone(d, 220.0, WaveType.SQUARE, 0.3, 0.0, 0.35, 45.0)
	_add_tone(d, 500.0, WaveType.SAWTOOTH, 0.18, 0.0, 0.18, 80.0)
	_commit(d)

static func _play_player_attack(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 320.0, WaveType.SAWTOOTH, 0.25, 0.0, 0.3, 70.0)
	_add_tone(d, 900.0, WaveType.SQUARE, 0.15, 0.0, 0.18, 180.0)
	_add_tone(d, 65.0, WaveType.SINE, 0.2, 0.02, 0.3, 18.0)
	_commit(d)

static func _play_player_aoe(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var freqs := [150.0, 200.0, 120.0, 180.0]
	for i in range(4):
		_add_tone(d, freqs[i], WaveType.SAWTOOTH, 0.22, i * 0.06, 0.4, freqs[i] * 0.15)
	_add_tone(d, 700.0, WaveType.SQUARE, 0.15, 0.0, 0.3, 80.0)
	_add_tone(d, 45.0, WaveType.SINE, 0.15, 0.1, 0.5, 0.0)
	_commit(d)

static func _play_enemy_defend(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 180.0, WaveType.TRIANGLE, 0.3, 0.0, 0.55, 280.0)
	_add_tone(d, 700.0, WaveType.SINE, 0.15, 0.04, 0.4, 300.0)
	_add_tone(d, 70.0, WaveType.SINE, 0.15, 0.06, 0.4, 0.0)
	_commit(d)

static func _play_enemy_skill(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var freqs := [220.0, 330.0, 440.0, 550.0, 660.0]
	for i in range(5):
		_add_tone(d, freqs[i], WaveType.SINE, 0.15, i * 0.07, 0.28, 0.0)
	_add_tone(d, 90.0, WaveType.SAWTOOTH, 0.25, 0.35, 0.8, 25.0)
	_add_tone(d, 800.0, WaveType.SINE, 0.1, 0.4, 0.85, 200.0)
	_commit(d)


## ==========================================
## 状态/持续效果音效
## ==========================================

static func _play_heal(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 523.0, WaveType.SINE, 0.22, 0.0, 0.3, 0.0)
	_add_tone(d, 659.0, WaveType.SINE, 0.22, 0.08, 0.3, 0.0)
	_add_tone(d, 784.0, WaveType.SINE, 0.22, 0.16, 0.3, 0.0)
	_commit(d)

static func _play_poison(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 800.0, WaveType.SINE, 0.22, 0.0, 0.2, 200.0)
	_commit(d)

static func _play_burn(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 400.0, WaveType.SAWTOOTH, 0.25, 0.0, 0.25, 100.0)
	_commit(d)

static func _play_enemy_heal(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var freqs := [220.0, 277.0, 330.0, 392.0]
	for i in range(4):
		_add_tone(d, freqs[i], WaveType.SINE, 0.18, i * 0.12, 0.38, 0.0)
	_add_tone(d, 110.0, WaveType.SINE, 0.12, 0.0, 0.65, 0.0)
	_commit(d)


## ==========================================
## 过场/剧情音效
## ==========================================

static func _play_victory(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 523.0, WaveType.SINE, 0.25, 0.0, 0.5, 0.0)
	_add_tone(d, 659.0, WaveType.SINE, 0.25, 0.12, 0.5, 0.0)
	_add_tone(d, 784.0, WaveType.SINE, 0.25, 0.24, 0.5, 0.0)
	_add_tone(d, 1047.0, WaveType.SINE, 0.25, 0.36, 0.5, 0.0)
	_commit(d)

static func _play_defeat(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var freqs := [200.0, 150.0, 100.0, 60.0]
	for i in range(4):
		_add_tone(d, freqs[i], WaveType.SAWTOOTH, 0.28, i * 0.2, 0.6, 0.0)
	_commit(d)

static func _play_boss_appear(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var freqs := [50.0, 60.0, 75.0, 50.0, 65.0]
	for i in range(5):
		_add_tone(d, freqs[i], WaveType.SAWTOOTH, 0.3, i * 0.3, 0.65, 0.0)
	_add_tone(d, 200.0, WaveType.SINE, 0.12, 0.5, 2.3, 150.0)
	_commit(d)

static func _play_enemy_death(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	# Layer1: 低频爆裂
	_add_tone(d, 140.0, WaveType.SAWTOOTH, 0.35, 0.0, 0.65, 18.0)
	# Layer2: 骨碎飞散
	for i in range(8):
		_add_tone(d, 400.0 + randf() * 600.0, WaveType.SQUARE, 0.12, 0.02 + i * 0.04, 0.2, 40.0 + randf() * 60.0)
	# Layer3: 灵魂消散
	_add_tone(d, 500.0, WaveType.SINE, 0.18, 0.15, 1.0, 40.0)
	# Layer4: 坠地
	_add_tone(d, 65.0, WaveType.SINE, 0.25, 0.4, 0.8, 25.0)
	_commit(d)

static func _play_player_death(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	# 心跳渐停
	_add_tone(d, 50.0, WaveType.SINE, 0.35, 0.0, 0.2, 25.0)
	_add_tone(d, 50.0, WaveType.SINE, 0.21, 0.3, 0.2, 25.0)
	# 不和谐下行
	var freqs := [293.0, 277.0, 207.0]
	for i in range(3):
		_add_tone(d, freqs[i], WaveType.SAWTOOTH, 0.14, 0.5 + i * 0.05, 1.3, freqs[i] * 0.4)
	# 回响
	_add_tone(d, 80.0, WaveType.TRIANGLE, 0.18, 1.0, 2.0, 30.0)
	_commit(d)

static func _play_boss_laugh(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var notes := [100.0, 120.0, 110.0, 135.0, 125.0, 150.0, 140.0, 165.0, 155.0, 180.0]
	for i in range(10):
		_add_tone(d, notes[i], WaveType.SAWTOOTH, 0.28, i * 0.16, 0.16, notes[i] * 0.65)
	_add_tone(d, 55.0, WaveType.SINE, 0.15, 0.0, 1.9, 0.0)
	_commit(d)

static func _play_gate_close(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	_add_tone(d, 60.0, WaveType.SAWTOOTH, 0.15, 0.0, 1.2, 35.0)
	_add_tone(d, 90.0, WaveType.SQUARE, 0.2, 0.6, 1.0, 30.0)
	_add_tone(d, 45.0, WaveType.SINE, 0.08, 0.8, 2.0, 0.0)
	_commit(d)

static func _play_enemy_speak(p: AudioStreamPlayer) -> void:
	var d := _begin(p)
	var vowels := [160.0, 200.0, 140.0, 220.0, 170.0, 190.0]
	for i in range(6):
		_add_tone(d, vowels[i] + randf() * 30.0, WaveType.SAWTOOTH, 0.3, i * 0.14, 0.14, vowels[i] - 30.0)
	_add_tone(d, 80.0, WaveType.SINE, 0.1, 0.0, 0.95, 0.0)
	_commit(d)


## ==========================================
## 底层波形合成引擎
## ==========================================

## 音符描述
class Note:
	var freq: float
	var wave: int  # WaveType
	var amp: float
	var start: float  # 秒
	var duration: float  # 秒
	var freq_end: float  # 频率滑动目标（0=不滑动）

## 合成上下文
class SynthCtx:
	var sample_rate: int
	var duration: float
	var notes: Array[Note] = []
	var volume_scale: float = 1.0

static func _begin(player: AudioStreamPlayer, vol_scale: float = 1.0) -> SynthCtx:
	var ctx := SynthCtx.new()
	ctx.sample_rate = AudioServer.get_mix_rate()
	ctx.volume_scale = vol_scale
	return ctx

## 添加一个音符到合成上下文
static func _add_tone(ctx: SynthCtx, freq: float, wave: int, amp: float, start: float, dur: float, freq_end: float) -> void:
	var n := Note.new()
	n.freq = freq
	n.wave = wave
	n.amp = amp
	n.start = start
	n.duration = dur
	n.freq_end = freq_end
	ctx.notes.append(n)

## 计算总时长并提交到播放器
static func _commit(ctx: SynthCtx) -> void:
	# 计算最长音符结束时间
	var max_end := 0.0
	for n in ctx.notes:
		var end := n.start + n.duration
		if end > max_end:
			max_end = end
	ctx.duration = max_end + 0.01  # 微量缓冲

	# 生成PCM数据
	var total_samples := int(ctx.duration * ctx.sample_rate)
	var data := PackedVector2Array()
	data.resize(total_samples)

	for n in ctx.notes:
		var start_sample := int(n.start * ctx.sample_rate)
		var end_sample := mini(start_sample + int(n.duration * ctx.sample_rate), total_samples)
		var note_samples := end_sample - start_sample
		if note_samples <= 0:
			continue

		for i in range(note_samples):
			var t := float(i) / ctx.sample_rate
			var progress := float(i) / note_samples
			var sample_idx := start_sample + i

			# 当前频率（线性插值滑动）
			var cur_freq: float
			if n.freq_end > 0.0:
				cur_freq = lerpf(n.freq, n.freq_end, progress)
			else:
				cur_freq = n.freq

			# 振幅包络（指数衰减）
			var envelope: float
			if progress < 0.01:
				envelope = progress / 0.01  # 快速起音
			else:
				envelope = exp(-4.0 * progress)  # 指数衰减

			# 波形生成
			var phase := fmod(t * cur_freq, 1.0)
			var sample: float
			match n.wave:
				WaveType.SINE:
					sample = sin(phase * TAU)
				WaveType.SQUARE:
					sample = 1.0 if phase < 0.5 else -1.0
				WaveType.SAWTOOTH:
					sample = 2.0 * phase - 1.0
				WaveType.TRIANGLE:
					sample = 4.0 * absf(phase - 0.5) - 1.0
				_:
					sample = 0.0

			sample *= n.amp * envelope * ctx.volume_scale

			# 叠加到输出
			if sample_idx < total_samples:
				data[sample_idx] = Vector2(
					data[sample_idx].x + sample,
					data[sample_idx].y + sample
				)

	# 创建 AudioStreamGenerator 并播放
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = ctx.sample_rate
	stream.buffer_length = 0.1

	# 使用传入的播放器（由 SoundPlayer 管理）
	# 先停止当前播放
	if ctx.notes.size() > 0:
		_find_free_player_and_play(stream, data)


## 找到空闲播放器并播放
static func _find_free_player_and_play(stream: AudioStreamGenerator, data: PackedVector2Array) -> void:
	# 通过 SoundPlayer 单例获取播放器池
	var sp := _get_sound_player()
	if not sp:
		return
	var player := sp._get_next_sfx_player()
	if not player:
		return
	player.stream = stream
	player.volume_db = linear_to_db(sp.sfx_volume)
	player.play()
	# 推送PCM数据
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames_available := playback.get_frames_available()
		var to_push := mini(data.size(), frames_available)
		for i in range(to_push):
			playback.push_frame(data[i])


## 获取 SoundPlayer 单例
static func _get_sound_player() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		for child in tree.root.get_children():
			if child.name == "SoundPlayer" or child.has_method("_get_next_sfx_player"):
				return child
	return null
