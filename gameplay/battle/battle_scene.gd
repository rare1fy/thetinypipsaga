## 战斗场景 — 核心游戏循环
## 对应原版 DiceHeroGame.tsx，管理战斗UI和交互

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

# 状态
var enemies: Array[EnemyInstance] = []
var selected_dice: Array[Dictionary] = []
var reroll_count: int = 0
var _battle_active: bool = false
var _enemy_breath_tweens: Array[Tween] = []
var _dice_anim_tweens: Array[Tween] = []


func _ready() -> void:
	# 连接信号
	play_btn.pressed.connect(_on_play_pressed)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	
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
	
	# 消费 MapScreen 写入的波次（main.gd 走销毁重建，start_battle 必须由场景自己触发）
	if not GameManager.pending_wave.is_empty():
		start_battle(GameManager.pending_wave)
		GameManager.pending_wave = []


func start_battle(wave_data: Array) -> void:
	_battle_active = true
	GameManager.battle_turn = 0
	GameManager.hp_lost_this_battle = 0
	enemies = []
	
	# 创建敌人
	for config_id in wave_data:
		var config := EnemyConfig.get_config(config_id)
		if config:
			var scaling := GameBalance.get_depth_scaling(maxi(0, GameManager.current_node))
			var chapter_scale: Dictionary = GameBalance.CHAPTER_CONFIG.chapterScaling[mini(GameManager.chapter - 1, 4)]
			var e := EnemyInstance.from_config(config,
				scaling.hpMult * chapter_scale.hpMult,
				scaling.dmgMult * chapter_scale.dmgMult)
			enemies.append(e)
	
	_refresh_enemies_ui()
	_start_new_turn()


func _start_new_turn() -> void:
	GameManager.start_turn()
	reroll_count = 0
	_refresh_ui()
	
	# 抽骰子
	GameManager.execute_draw_phase()
	
	# 遗物触发：回合开始
	RelicEngine.on_battle_start(GameManager.relics, GameManager)
	
	SoundPlayer.play_sound("roll")


func _on_play_pressed() -> void:
	if selected_dice.is_empty():
		return
	
	if GameManager.plays_left <= 0:
		return
	
	SoundPlayer.play_sound("player_attack")
	
	# 牌型判定
	var hand_result := HandEvaluator.check_hands(selected_dice)
	var bonus_mult := RelicEngine.get_bonus_mult(GameManager.relics, hand_result.bestHand)
	bonus_mult += GameManager.mage_overcharge_mult
	bonus_mult += GameManager.warrior_rage_mult
	
	# 盗贼连击加成
	if GameManager.player_class == "rogue" and GameManager.combo_count >= 1:
		bonus_mult += 0.2  # 第2次出牌+20%
		if GameManager.last_play_hand_type == hand_result.bestHand and hand_result.bestHand != "普通攻击":
			bonus_mult += 0.25  # 同牌型再+25%
	
	# 计算总伤害
	var bonus_damage := RelicEngine.get_bonus_damage(GameManager.relics, GameManager)
	bonus_damage += GameManager.fury_bonus_damage
	var total_damage := HandEvaluator.calculate_damage(selected_dice, hand_result, bonus_mult, bonus_damage)
	
	# 清除临时加成
	GameManager.rage_fire_bonus = 0
	GameManager.fury_bonus_damage = 0
	
	# 选择目标敌人
	var target := _get_target_enemy()
	if not target:
		return
	
	# 执行攻击
	_attack_enemy(target, total_damage, hand_result)
	
	# 标记已出的骰子
	for d in selected_dice:
		d.spent = true
		GameManager.discard_pile.append(d.defId)
	selected_dice.clear()
	
	# 骰子特效（分裂、暗影残骰等）
	_process_dice_on_play_effects()
	
	# 出牌后处理
	GameManager.last_play_hand_type = hand_result.bestHand
	GameManager.after_play()
	
	# 盗贼连击：补充暗影残骰
	if GameManager.player_class == "rogue" and GameManager.combo_count >= 1:
		_grant_shadow_remnant()
	
	# 检查敌人死亡
	_check_enemy_deaths()
	
	_refresh_ui()
	
	# 检查胜利
	if enemies.all(func(e): return e.hp <= 0):
		_on_battle_victory()


func _on_reroll_pressed() -> void:
	const BLOOD_COST := 3
	if GameManager.free_rerolls_left > 0:
		GameManager.free_rerolls_left -= 1
	elif GameManager.can_blood_reroll and GameManager.hp > BLOOD_COST:
		# 卖血重投
		GameManager.blood_reroll_count += 1
		GameManager.take_damage(BLOOD_COST)
		SoundPlayer.play_sound("hit")
	else:
		return  # 没有免费重投也没有卖血
	
	reroll_count += 1
	SoundPlayer.play_sound("reroll")
	
	# 重投未选中的骰子
	for d in GameManager.hand_dice:
		if not d.selected and not d.spent:
			d.value = GameManager.reroll_die(d)
			d.rolling = true
	
	_refresh_dice_ui()
	
	# 短暂动画后停止
	get_tree().create_timer(0.3).timeout.connect(func():
		for d in GameManager.hand_dice:
			d.rolling = false
		_refresh_dice_ui()
	)


func _on_end_turn_pressed() -> void:
	if GameManager.is_enemy_turn:
		return
	
	SoundPlayer.play_sound("turn_end")
	_execute_enemy_turn()


func _execute_enemy_turn() -> void:
	GameManager.is_enemy_turn = true
	_refresh_ui()
	
	var result := EnemyAI.execute_enemy_turn(GameManager, enemies, GameManager.hand_dice)
	
	if result.get("gameOver", false):
		GameManager.game_over.emit()
		return
	
	if result.get("waveTransition", false):
		# 波次转换
		pass
	
	_refresh_enemies_ui()
	_start_new_turn()


func _attack_enemy(enemy: EnemyInstance, damage: int, hand_result: Dictionary) -> void:
	# 护甲吸收
	var absorbed := mini(enemy.armor, damage)
	enemy.armor -= absorbed
	var hp_damage := damage - absorbed
	enemy.hp = maxi(0, enemy.hp - hp_damage)
	
	# 元素效果
	_apply_element_effects(enemy, hand_result, damage)
	
	# 统计
	GameManager.record_damage(damage, true)
	
	# 受击特效：闪白 + 震动
	_hit_enemy_vfx(enemy, damage)
	
	_show_floating_text("-%d" % damage, Color.RED, "enemy")
	SoundPlayer.play_sound("hit")


func _apply_element_effects(enemy: EnemyInstance, hand_result: Dictionary, base_damage: int) -> void:
	for d in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		match elem:
			"fire":
				# 火：摧毁护甲 + 灼烧
				enemy.armor = 0
				var burn_val := maxi(1, int(d.value * 0.5))
				enemy.statuses.append(StatusEffect.new())
				enemy.statuses[-1].type = GameTypes.StatusType.BURN
				enemy.statuses[-1].value = burn_val
				enemy.statuses[-1].duration = 3
			"ice":
				# 冰：冻结1回合
				enemy.statuses.append(StatusEffect.new())
				enemy.statuses[-1].type = GameTypes.StatusType.FREEZE
				enemy.statuses[-1].value = 1
				enemy.statuses[-1].duration = 1
			"thunder":
				# 雷：AOE穿透其他敌人
				for other in enemies:
					if other.uid != enemy.uid and other.hp > 0:
						other.hp = maxi(0, other.hp - d.value)
			"poison":
				# 毒：叠层
				enemy.statuses.append(StatusEffect.new())
				enemy.statuses[-1].type = GameTypes.StatusType.POISON
				enemy.statuses[-1].value = d.value
				enemy.statuses[-1].duration = 3
			"holy":
				# 圣：回血
				GameManager.heal(d.value)


func _check_enemy_deaths() -> void:
	for e in enemies:
		if e.hp <= 0 and e.hp > -9999:
			# 击杀奖励
			GameManager.add_gold(e.drop_gold)
			GameManager.stats.enemiesKilled += 1
			e.hp = -9999  # 标记已处理


func _get_target_enemy() -> EnemyInstance:
	# 优先攻击嘲讽目标
	if GameManager.target_enemy_uid != "":
		for e in enemies:
			if e.uid == GameManager.target_enemy_uid and e.hp > 0:
				return e
	# 否则攻击第一个存活的
	for e in enemies:
		if e.hp > 0:
			return e
	return null


func _grant_shadow_remnant() -> void:
	var shadow_die := {
		"id": randi(), "defId": "temp_rogue", "value": randi_range(1, 3),
		"element": "normal", "selected": false, "spent": false, "rolling": false,
		"isShadowRemnant": true, "isTemp": true, "shadowRemnantPersistent": false,
		"kept": false, "keptBonusAccum": 0,
	}
	GameManager.hand_dice.append(shadow_die)


func _process_dice_on_play_effects() -> void:
	# 分裂骰子、影分身等效果
	var extra_dice: Array[Dictionary] = []
	for d in selected_dice:
		var def: DiceDef = GameData.get_dice_def(d.defId)
		if def.shadow_clone_play:
			var clone := d.duplicate()
			clone.id = randi()
			clone.spent = true
			clone.isShadowRemnant = true
			extra_dice.append(clone)
	GameManager.hand_dice.append_array(extra_dice)


func _on_battle_victory() -> void:
	_battle_active = false
	GameManager.stats.battlesWon += 1
	SoundPlayer.play_sound("victory")
	# 胜利粒子特效
	VFX.victory_burst(ui_root, ui_root.size * 0.5, 20)
	VFX.shake_heavy(self, 6.0, 0.3)
	GameManager.set_phase(GameTypes.GamePhase.LOOT)


# ============================================================
# UI 刷新
# ============================================================

func _refresh_ui() -> void:
	_on_hp_changed(GameManager.hp, GameManager.max_hp)
	_on_armor_changed(GameManager.armor)
	gold_label.text = "金币: %d" % GameManager.gold
	turn_label.text = "回合 %d" % GameManager.battle_turn
	play_btn.disabled = selected_dice.is_empty() or GameManager.plays_left <= 0 or GameManager.is_enemy_turn
	reroll_btn.disabled = GameManager.free_rerolls_left <= 0 and not (GameManager.player_class == "warrior")
	reroll_btn.text = "重投(%d)" % GameManager.free_rerolls_left if GameManager.free_rerolls_left > 0 else "卖血重投"
	end_turn_btn.disabled = GameManager.is_enemy_turn


func _refresh_dice_ui() -> void:
	# 停止旧骰子动画
	for tw in _dice_anim_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_dice_anim_tweens.clear()
	
	for child in dice_container.get_children():
		child.queue_free()
	
	for d in GameManager.hand_dice:
		if d.spent:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(44, 44)
		btn.text = str(d.value)
		btn.tooltip_text = GameData.get_dice_def(d.defId).name
		
		if d.selected:
			btn.modulate = Color(1.0, 1.0, 0.5)
		if d.rolling:
			btn.modulate = Color(0.7, 0.7, 1.0)
			# 骰子滚动动画
			var roll_tween := VFX.dice_roll(btn)
			if roll_tween:
				_dice_anim_tweens.append(roll_tween)
		
		# 元素着色 + 持续特效
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		var elem_tween: Tween = null
		match elem:
			"fire":
				btn.modulate = Color(1.0, 0.5, 0.2)
				elem_tween = VFX.fire_glow(btn)
			"ice":
				btn.modulate = Color(0.3, 0.7, 1.0)
				elem_tween = VFX.ice_sparkle(btn)
			"thunder":
				btn.modulate = Color(1.0, 1.0, 0.3)
			"poison":
				btn.modulate = Color(0.4, 1.0, 0.4)
				elem_tween = VFX.poison_pulse(btn)
			"holy":
				btn.modulate = Color(1.0, 1.0, 0.8)
				elem_tween = VFX.holy_pulse(btn)
			"shadow":
				btn.modulate = Color(0.5, 0.3, 0.7)
				elem_tween = VFX.shadow_pulse(btn)
		if elem_tween:
			_dice_anim_tweens.append(elem_tween)
		
		# 选中骰子动画
		if d.selected:
			VFX.dice_select(btn)
		
		btn.pressed.connect(_on_die_clicked.bind(d))
		dice_container.add_child(btn)


func _refresh_enemies_ui() -> void:
	# 停止旧呼吸动画
	for tw in _enemy_breath_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_enemy_breath_tweens.clear()
	
	for child in enemy_container.get_children():
		child.queue_free()
	
	for e in enemies:
		if e.hp <= -9999:
			continue
		var panel := PanelContainer.new()
		var vbox := VBoxContainer.new()
		
		var name_label := Label.new()
		name_label.text = e.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var hp_bar_e := ProgressBar.new()
		hp_bar_e.max_value = e.max_hp
		hp_bar_e.value = maxi(0, e.hp)
		hp_bar_e.custom_minimum_size = Vector2(100, 12)
		
		var hp_text := Label.new()
		hp_text.text = "HP: %d/%d" % [maxi(0, e.hp), e.max_hp]
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if e.armor > 0:
			var armor_l := Label.new()
			armor_l.text = "护甲: %d" % e.armor
			armor_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(armor_l)
		
		vbox.add_child(name_label)
		vbox.add_child(hp_bar_e)
		vbox.add_child(hp_text)
		panel.add_child(vbox)
		enemy_container.add_child(panel)
		
		# 按敌人战斗类型应用呼吸动画
		var breathe_tween: Tween = null
		match e.combat_type:
			GameTypes.EnemyCombatType.WARRIOR:
				breathe_tween = VFX.breathe_warrior(panel)
			GameTypes.EnemyCombatType.GUARDIAN:
				breathe_tween = VFX.breathe_guardian(panel)
			GameTypes.EnemyCombatType.CASTER, GameTypes.EnemyCombatType.PRIEST:
				breathe_tween = VFX.breathe_caster(panel)
			_:
				breathe_tween = VFX.breathe(panel)
		if breathe_tween:
			_enemy_breath_tweens.append(breathe_tween)
		
		# 按元素状态应用持续特效
		_apply_enemy_status_vfx(panel, e)


func _on_die_clicked(die: Dictionary) -> void:
	if GameManager.is_enemy_turn or die.spent:
		return
	
	die.selected = not die.selected
	
	if die.selected:
		selected_dice.append(die)
	else:
		selected_dice.erase(die)
	
	# 更新牌型提示
	if selected_dice.size() > 0:
		var hand := HandEvaluator.check_hands(selected_dice)
		hand_label.text = hand.bestHand
	else:
		hand_label.text = ""
	
	_refresh_dice_ui()


func _on_hp_changed(new_hp: int, new_max: int) -> void:
	hp_bar.max_value = new_max
	hp_bar.value = new_hp
	hp_label.text = "HP: %d/%d" % [new_hp, new_max]


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
	# 治疗类文字附带绿色粒子
	if color == Color.GREEN or text.begins_with("+"):
		VFX.heal_burst(ui_root, spawn_pos, 6)
	# 动画已全局关闭：静止显示 0.8s 后回收
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
	)


## 屏幕震动响应
func _on_screen_shake() -> void:
	VFX.shake(self, 8.0, 0.3)


## 敌人受击VFX信号响应
func _on_enemy_damaged(enemy_uid: String, damage: int, _is_crit: bool) -> void:
	var enemy := _find_enemy_by_uid(enemy_uid)
	if not enemy:
		return
	var idx := _find_enemy_panel_index(enemy_uid)
	if idx < 0:
		return
	var panel := enemy_container.get_child(idx) as Control
	if panel:
		VFX.hit_flash(panel)
		if damage >= 30:
			VFX.shake_heavy(self, 10.0, 0.4)
			SoundPlayer.play_heavy_impact(1.0)
		else:
			VFX.shake(self, 5.0, 0.15)


## 敌人死亡信号响应
func _on_enemy_died(enemy_uid: String) -> void:
	var idx := _find_enemy_panel_index(enemy_uid)
	if idx < 0:
		return
	var panel := enemy_container.get_child(idx) as Control
	if panel:
		var center := panel.position + panel.size * 0.5
		VFX.pixel_burst(ui_root, center, 12, [Color.RED, Color.ORANGE, Color.YELLOW])


## 受击VFX（攻击敌人时内部调用）
func _hit_enemy_vfx(enemy: EnemyInstance, damage: int) -> void:
	var idx := _find_enemy_panel_index(enemy.uid)
	if idx < 0:
		return
	var panel := enemy_container.get_child(idx) as Control
	if not panel:
		return
	VFX.hit_flash(panel)
	if damage >= 30:
		VFX.shake_heavy(self, 8.0, 0.3)
		SoundPlayer.play_heavy_impact(minf(2.0, damage / 30.0))
		VFX.pixel_burst(ui_root, panel.position + panel.size * 0.5, 10, [Color.RED, Color.ORANGE, Color.YELLOW])
	else:
		VFX.shake(self, 4.0, 0.15)


## 给敌人面板应用状态持续特效（毒/灼烧等）
func _apply_enemy_status_vfx(panel: Control, enemy: EnemyInstance) -> void:
	for s in enemy.statuses:
		var tw: Tween = null
		match s.type:
			GameTypes.StatusType.POISON:
				tw = VFX.poison_pulse(panel)
				VFX.poison_drip(ui_root, panel.position + panel.size * 0.5, 3)
			GameTypes.StatusType.BURN:
				tw = VFX.burn_edge(panel)
		if tw:
			_enemy_breath_tweens.append(tw)


## 按uid查找敌人实例
func _find_enemy_by_uid(uid: String) -> EnemyInstance:
	for e in enemies:
		if e.uid == uid and e.hp > -9999:
			return e
	return null


## 按uid查找敌人面板在container中的索引
func _find_enemy_panel_index(uid: String) -> int:
	var alive_idx := 0
	for e in enemies:
		if e.hp <= -9999:
			continue
		if e.uid == uid:
			return alive_idx
		alive_idx += 1
	return -1


func _on_game_over() -> void:
	_battle_active = false
	GameManager.set_phase(GameTypes.GamePhase.GAME_OVER)
