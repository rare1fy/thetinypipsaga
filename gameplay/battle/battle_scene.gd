## 战斗场景 — UI 绑定 + 信号转发层
## 逻辑全部委托 BattleController，本文件只管 UI 刷新

extends Node2D

# UI 引用
@onready var ui_root: Control = %Root
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var armor_label: Label = %ArmorLabel
@onready var gold_label: Label = %GoldLabel
@onready var turn_label: Label = %TurnLabel
@onready var dice_container: HBoxContainer = %DiceContainer
@onready var hand_label: Label = %HandLabel
@onready var play_btn: Button = %PlayBtn
@onready var reroll_btn: Button = %RerollBtn
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var enemy_container: VBoxContainer = %EnemyContainer
@onready var class_icon: Label = %ClassIcon

# 子组件
var _controller: BattleController = null
var _damage_preview: DamagePreview = null
var _settlement_player: SettlementPlayer = null

# 动画缓存
var _enemy_breath_tweens: Array[Tween] = []
var _hp_bar_initialized: bool = false


func _ready() -> void:
	# 创建控制器子节点
	_controller = BattleController.new()
	_controller.name = "BattleController"
	add_child(_controller)

	# 挂载伤害预览面板
	_damage_preview = DamagePreview.new()
	_damage_preview.name = "DamagePreview"
	_damage_preview.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_damage_preview.position = Vector2(-120, 220)
	_damage_preview.custom_minimum_size = Vector2(240, 0)
	ui_root.add_child(_damage_preview)

	# 挂载结算演出层
	_settlement_player = SettlementPlayer.new()
	_settlement_player.name = "SettlementPlayer"
	add_child(_settlement_player)

	# 按钮信号 → 转发 controller
	play_btn.pressed.connect(_on_play_pressed)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	# controller 信号 → UI 刷新
	_controller.ui_refresh_requested.connect(_refresh_ui)
	_controller.dice_ui_refresh_requested.connect(_refresh_dice_ui)
	_controller.enemies_ui_refresh_requested.connect(_refresh_enemies_ui)
	_controller.hand_label_updated.connect(_on_hand_label_updated)
	_controller.damage_preview_refreshed.connect(_on_damage_preview_refreshed)
	_controller.damage_preview_hidden.connect(_on_damage_preview_hidden)
	_controller.floating_text_requested.connect(_show_floating_text)
	_controller.settlement_started.connect(_on_settlement_started)
	_controller.battle_victory.connect(_on_battle_victory_vfx)
	_controller.game_over_triggered.connect(_on_game_over)

	# 全局信号
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.armor_changed.connect(_on_armor_changed)
	GameManager.dice_updated.connect(_refresh_dice_ui)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.floating_text_requested.connect(_show_floating_text)
	GameManager.game_over.connect(_on_game_over)
	GameManager.screen_shake_requested.connect(_on_screen_shake)
	EventBus.screen_shake.connect(_on_screen_shake)
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)

	# 消费 pending_wave
	if not GameManager.pending_wave.is_empty():
		_controller.start_battle(GameManager.pending_wave)
		GameManager.pending_wave = []


# ============================================================
# 按钮回调 → 转发 controller
# ============================================================

func _on_play_pressed() -> void:
	_controller.play_hand()


func _on_reroll_pressed() -> void:
	_controller.reroll_selected()


func _on_end_turn_pressed() -> void:
	_controller.end_player_turn()


# ============================================================
# Controller 信号回调
# ============================================================

func _on_hand_label_updated(text: String) -> void:
	hand_label.text = text


func _on_damage_preview_refreshed(dice: Array) -> void:
	if _damage_preview:
		_damage_preview.refresh(dice)


func _on_damage_preview_hidden() -> void:
	if _damage_preview:
		_damage_preview.visible = false


func _on_settlement_started(data: Dictionary) -> void:
	# 播放结算演出（4 阶段 await），完成后调 controller.finalize_play
	await _settlement_player.play(data)

	var hand_result := HandEvaluator.check_hands(_controller.selected_dice)
	var target := BattleHelpers.pick_target(_controller.enemies, GameManager.target_enemy_uid)
	if target:
		_controller.finalize_play(hand_result, target, data.total_damage)
	else:
		_controller.playing_hand = false


# ============================================================
# UI 刷新
# ============================================================

func _refresh_ui() -> void:
	_on_hp_changed(GameManager.hp, GameManager.max_hp)
	_on_armor_changed(GameManager.armor)
	gold_label.text = "金币: %d" % GameManager.gold
	turn_label.text = "回合 %d" % GameManager.battle_turn
	match GameManager.player_class:
		"warrior": class_icon.text = "⚔"
		"mage": class_icon.text = "🔮"
		"rogue": class_icon.text = "🗡"
		_: class_icon.text = "?"
	play_btn.disabled = _controller.selected_dice.is_empty() or GameManager.plays_left <= 0 or GameManager.is_enemy_turn
	var can_blood_afford := GameManager.can_blood_reroll and GameManager.hp > 3
	reroll_btn.disabled = (GameManager.free_rerolls_left <= 0 and not can_blood_afford) or GameManager.is_enemy_turn or GameManager.plays_left <= 0
	reroll_btn.text = "重投(%d)" % GameManager.free_rerolls_left if GameManager.free_rerolls_left > 0 else "卖血重投"
	end_turn_btn.disabled = GameManager.is_enemy_turn


func _refresh_dice_ui() -> void:
	for child in dice_container.get_children():
		child.queue_free()

	for d in GameManager.hand_dice:
		if d.spent:
			continue
		var btn: DiceButton = DiceButton.new()
		dice_container.add_child(btn)
		btn.setup(d)
		btn.tooltip_text = GameData.get_dice_def(d.defId).name
		btn.die_clicked.connect(_on_die_clicked)


func _refresh_enemies_ui() -> void:
	for tw in _enemy_breath_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_enemy_breath_tweens.clear()

	for child in enemy_container.get_children():
		child.queue_free()

	for e in _controller.enemies:
		if e.hp <= -9999:
			continue
		var view: EnemyView = EnemyView.new()
		enemy_container.add_child(view)
		view.setup(e)
		view.enemy_clicked.connect(_on_enemy_clicked)

		var breathe_tween: Tween = null
		match e.combat_type:
			GameTypes.EnemyCombatType.WARRIOR:
				breathe_tween = VFX.breathe_warrior(view)
			GameTypes.EnemyCombatType.GUARDIAN:
				breathe_tween = VFX.breathe_guardian(view)
			GameTypes.EnemyCombatType.CASTER, GameTypes.EnemyCombatType.PRIEST:
				breathe_tween = VFX.breathe_caster(view)
			_:
				breathe_tween = VFX.breathe(view)
		if breathe_tween:
			_enemy_breath_tweens.append(breathe_tween)

		_apply_enemy_status_vfx(view, e)


# ============================================================
# 全局信号回调
# ============================================================

func _on_die_clicked(die_id: int) -> void:
	_controller.toggle_die_selection(die_id)


func _on_enemy_clicked(enemy_uid: String) -> void:
	_controller.set_target_enemy(enemy_uid)


func _on_hp_changed(new_hp: int, new_max: int) -> void:
	if not _hp_bar_initialized:
		_hp_bar_initialized = true
		hp_bar.max_value = new_max
		hp_bar.value = new_hp
		hp_label.text = "HP: %d/%d" % [new_hp, new_max]
		return
	var was_damage: bool = new_hp < int(hp_bar.value)
	hp_bar.max_value = new_max
	hp_bar.value = new_hp
	hp_label.text = "HP: %d/%d" % [new_hp, new_max]
	VFX.hp_pulse(hp_bar, was_damage)


func _on_armor_changed(new_armor: int) -> void:
	armor_label.text = "护甲: %d" % new_armor if new_armor > 0 else ""


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.BATTLE


func _show_floating_text(text: String, color: Color, target: String, _icon: String = "") -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spawn_pos := Vector2(randi_range(80, 280), 200 if target == "player" else 80)
	label.position = spawn_pos
	ui_root.add_child(label)

	VFX.damage_pop(label, 0.25)
	if color == Color.GREEN or text.begins_with("+"):
		VFX.heal_burst(ui_root, spawn_pos, 6)
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
	)


func _on_screen_shake() -> void:
	VFX.shake(self, 8.0, 0.3)


func _on_enemy_damaged(enemy_uid: String, damage: int, _is_crit: bool) -> void:
	if _find_enemy_by_uid(enemy_uid) == null:
		return
	BattleVfx.on_enemy_damaged_signal(enemy_container, _controller.enemies, enemy_uid, damage, self)


func _on_enemy_died(enemy_uid: String) -> void:
	BattleVfx.on_enemy_died(enemy_container, _controller.enemies, ui_root, enemy_uid)


func _on_battle_victory_vfx() -> void:
	VFX.victory_burst(ui_root, ui_root.size * 0.5, 20)
	VFX.shake_heavy(self, 6.0, 0.3)


func _on_game_over() -> void:
	_controller.battle_active = false
	GameManager.set_phase(GameTypes.GamePhase.GAME_OVER)


# ============================================================
# 辅助
# ============================================================

func _hit_enemy_vfx(enemy: EnemyInstance, damage: int) -> void:
	BattleVfx.on_player_hit(enemy_container, _controller.enemies, ui_root, self, enemy.uid, damage, _controller.selected_dice)


func _apply_enemy_status_vfx(panel: Control, enemy: EnemyInstance) -> void:
	for tw in BattleVfx.apply_status_tweens(panel, enemy, ui_root):
		_enemy_breath_tweens.append(tw)


func _find_enemy_by_uid(uid: String) -> EnemyInstance:
	for e in _controller.enemies:
		if e.uid == uid and e.hp > -9999:
			return e
	return null
