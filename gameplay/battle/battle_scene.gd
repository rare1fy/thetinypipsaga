# battle_scene.gd — 战斗场景入口
# 职责：场景生命周期管理 + 启动 BattleController
class_name BattleScene
extends Node2D

const ModalHubRef := preload("res://common/ui/modal_hub.gd")
const HandGuideRef := preload("res://common/ui/hand_guide.gd")
const RelicGuideRef := preload("res://common/ui/relic_guide.gd")
const BattleLogRef := preload("res://gameplay/battle/ui/battle_log.gd")
const TooltipRef := preload("res://common/ui/tooltip.gd")
const RelicPanelRef := preload("res://gameplay/battle/ui/relic_panel.gd")
const EnemyMgr := preload("res://gameplay/battle/battle_enemy_manager.gd")

## ========================================================
## 敌人透视参数 — Inspector 直接配置，所见即所得
## 3 个 Slot × 4 档距离 × (坐标 + 缩放 + Y偏移 + 亮度 + 渲染层级) = 60 个参数
## 命名 = enemy.distance 的值，敌人头上显示"距N"就对应"距离N"这组参数
## 坐标为 EnemyContainer 局部坐标
## ========================================================

@export_group("敌人透视·Slot0(中)")
@export var 中_距离0坐标: Vector2 = Vector2(0, 300)
@export var 中_距离0缩放: float = 1.25
@export var 中_距离0纵深Y偏移: float = 30.0
@export var 中_距离0亮度: float = 1.0
@export var 中_距离0渲染层级: int = 7

@export var 中_距离1坐标: Vector2 = Vector2(0, 150)
@export var 中_距离1缩放: float = 0.95
@export var 中_距离1纵深Y偏移: float = -5.0
@export var 中_距离1亮度: float = 0.95
@export var 中_距离1渲染层级: int = 5

@export var 中_距离2坐标: Vector2 = Vector2(0, 40)
@export var 中_距离2缩放: float = 0.75
@export var 中_距离2纵深Y偏移: float = -25.0
@export var 中_距离2亮度: float = 0.9
@export var 中_距离2渲染层级: int = 3

@export var 中_距离3坐标: Vector2 = Vector2(0, -66)
@export var 中_距离3缩放: float = 0.6
@export var 中_距离3纵深Y偏移: float = -50.0
@export var 中_距离3亮度: float = 0.82
@export var 中_距离3渲染层级: int = 1

@export_group("敌人透视·Slot1(左)")
@export var 左_距离0坐标: Vector2 = Vector2(-230, 57)
@export var 左_距离0缩放: float = 1.25
@export var 左_距离0纵深Y偏移: float = 30.0
@export var 左_距离0亮度: float = 1.0
@export var 左_距离0渲染层级: int = 7

@export var 左_距离1坐标: Vector2 = Vector2(-192, 13)
@export var 左_距离1缩放: float = 0.95
@export var 左_距离1纵深Y偏移: float = -5.0
@export var 左_距离1亮度: float = 0.95
@export var 左_距离1渲染层级: int = 5

@export var 左_距离2坐标: Vector2 = Vector2(-154, -1)
@export var 左_距离2缩放: float = 0.75
@export var 左_距离2纵深Y偏移: float = -25.0
@export var 左_距离2亮度: float = 0.9
@export var 左_距离2渲染层级: int = 3

@export var 左_距离3坐标: Vector2 = Vector2(-131, -9)
@export var 左_距离3缩放: float = 0.6
@export var 左_距离3纵深Y偏移: float = -50.0
@export var 左_距离3亮度: float = 0.82
@export var 左_距离3渲染层级: int = 1

@export_group("敌人透视·Slot2(右)")
@export var 右_距离0坐标: Vector2 = Vector2(230, 60)
@export var 右_距离0缩放: float = 1.25
@export var 右_距离0纵深Y偏移: float = 30.0
@export var 右_距离0亮度: float = 1.0
@export var 右_距离0渲染层级: int = 7

@export var 右_距离1坐标: Vector2 = Vector2(192, 15)
@export var 右_距离1缩放: float = 0.95
@export var 右_距离1纵深Y偏移: float = -5.0
@export var 右_距离1亮度: float = 0.95
@export var 右_距离1渲染层级: int = 5

@export var 右_距离2坐标: Vector2 = Vector2(154, 0)
@export var 右_距离2缩放: float = 0.75
@export var 右_距离2纵深Y偏移: float = -25.0
@export var 右_距离2亮度: float = 0.9
@export var 右_距离2渲染层级: int = 3

@export var 右_距离3坐标: Vector2 = Vector2(131, -9)
@export var 右_距离3缩放: float = 0.6
@export var 右_距离3纵深Y偏移: float = -50.0
@export var 右_距离3亮度: float = 0.82
@export var 右_距离3渲染层级: int = 1


## 查表接口：根据 slot_index 和 distance 返回该档位的全部透视参数
## slot_index: 0=中 1=左 2=右
## distance: 就是 enemy.distance 的值，敌人头上显示"距N"就传 N
## 返回: { position, depth_scale, depth_y, depth_brightness, depth_z }
func get_slot_visuals(slot_index: int, distance: int) -> Dictionary:
	var d: int = clampi(distance, 0, 3)
	var prefix: String = ["中", "左", "右"][clampi(slot_index, 0, 2)]
	var d_suffix: String = "距离%d" % d
	var pos: Vector2 = _get_export_vec2(prefix, d_suffix, "坐标")
	return {
		"position": pos,
		"depth_scale": _get_export_float(prefix, d_suffix, "缩放"),
		"depth_y": _get_export_float(prefix, d_suffix, "纵深Y偏移"),
		"depth_brightness": _get_export_float(prefix, d_suffix, "亮度"),
		"depth_z": _get_export_int(prefix, d_suffix, "渲染层级"),
	}


## 反射查表辅助 — 根据 "左_距离2缩放" 这种命名规则读取 @export 值
func _get_export_vec2(prefix: String, d_suffix: String, field: String) -> Vector2:
	var prop_name: String = "%s_%s%s" % [prefix, d_suffix, field]
	if prop_name in self:
		return self[prop_name] as Vector2
	push_warning("[BattleScene] 未找到 @export 属性: %s" % prop_name)
	return Vector2.ZERO


func _get_export_float(prefix: String, d_suffix: String, field: String) -> float:
	var prop_name: String = "%s_%s%s" % [prefix, d_suffix, field]
	if prop_name in self:
		return float(self[prop_name])
	push_warning("[BattleScene] 未找到 @export 属性: %s" % prop_name)
	return 0.0


func _get_export_int(prefix: String, d_suffix: String, field: String) -> int:
	var prop_name: String = "%s_%s%s" % [prefix, d_suffix, field]
	if prop_name in self:
		return int(self[prop_name])
	push_warning("[BattleScene] 未找到 @export 属性: %s" % prop_name)
	return 0


@onready var controller: BattleController = $BattleController
@onready var player_hands: PlayerHands = %PlayerHands

## PlayerState.hp 上一帧快照，用于判断受击（hp_changed 信号也会在治疗时触发）
var _last_player_hp: int = -1

func _ready() -> void:
	# 监听 GameManager 的战斗开始信号（目前没其它地方发射，保留以兼容未来扩展）
	GameManager.battle_started.connect(_on_battle_started)
	controller.battle_won.connect(_on_battle_won)
	controller.battle_lost.connect(_on_battle_lost)
	SoundPlayer.play_music("battle")
	_spawn_topleft_buttons()
	_spawn_battle_log()
	_spawn_tooltip()
	_spawn_relic_panel()
	_connect_player_hands()
	# 地图/事件切换到 BATTLE 场景时不会发射 battle_started 信号，
	# 而是通过 GameManager.pending_wave 交付波次数据，因此这里直接启动战斗。
	_bootstrap_from_pending_wave()


## 玩家双手系统 — 接入受击 / 死亡 动画
## 攻击动画由 battle_controller 在出牌时触发（见 _on_player_play_attack）
func _connect_player_hands() -> void:
	if player_hands == null:
		push_warning("[BattleScene] PlayerHands 节点缺失，跳过双手接入")
		return
	_last_player_hp = PlayerState.hp
	PlayerState.hp_changed.connect(_on_player_hp_changed)
	PlayerState.game_over_requested.connect(_on_player_game_over)


func _on_player_hp_changed(new_hp: int, _max_hp: int) -> void:
	if player_hands == null:
		return
	var damage_taken: int = _last_player_hp - new_hp
	if damage_taken > 0 and new_hp > 0:
		player_hands.play_hurt()
		# 玩家掉血飘字（从 hp_bar 位置飘出）
		if controller != null and controller._float_layer != null and controller.hp_bar != null:
			var hp_pos: Vector2 = controller.hp_bar.global_position + controller.hp_bar.size * 0.5
			VFX.spawn_damage_text(controller._float_layer, hp_pos, damage_taken)
	_last_player_hp = new_hp


func _on_player_game_over() -> void:
	if player_hands == null:
		return
	player_hands.play_death()


## [E2-FIX] Autoload 信号连接必须在场景离开时断开
## 防止 BattleScene queue_free 后 PlayerState 持有野 Callable
func _exit_tree() -> void:
	if PlayerState.hp_changed.is_connected(_on_player_hp_changed):
		PlayerState.hp_changed.disconnect(_on_player_hp_changed)
	if PlayerState.game_over_requested.is_connected(_on_player_game_over):
		PlayerState.game_over_requested.disconnect(_on_player_game_over)


func _spawn_relic_panel() -> void:
	var root: Control = get_node_or_null("%Root")
	if root == null:
		return
	var panel := RelicPanelRef.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 48)  # 左上角 2 个图鉴按钮下方
	root.add_child(panel)


func _spawn_battle_log() -> void:
	var root: Control = get_node_or_null("%Root")
	if root == null:
		return
	var log_panel := BattleLogRef.new()
	log_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	log_panel.position = Vector2(-260, 48)  # 距右边 260（刚好面板宽），顶部留给左上角按钮
	log_panel.custom_minimum_size = Vector2(240, 0)
	root.add_child(log_panel)


func _spawn_tooltip() -> void:
	var root: Control = get_node_or_null("%Root")
	if root == null:
		return
	var tip := TooltipRef.new()
	root.add_child(tip)


func _bootstrap_from_pending_wave() -> void:
	var wave: Array = GameManager.pending_wave.duplicate()  # [RULES-B2-EXEMPT] pending_wave 类型不确定
	if wave.is_empty():
		push_warning("[BattleScene] pending_wave 为空，无法启动战斗")
		return
	# 用完即清，防止下一次战斗复用旧数据
	GameManager.pending_wave = []
	controller.start_battle({"enemies": wave})


func _spawn_topleft_buttons() -> void:
	# 战斗界面左上角快捷图鉴入口
	var root: Control = get_node_or_null("%Root")
	if root == null:
		push_warning("[BattleScene] 未找到 %Root 节点，图鉴按钮未挂载")
		return
	_spawn_guide_button(root, "📖", "牌型图鉴", Vector2(8, 8), _on_hand_guide_pressed)
	_spawn_guide_button(root, "🏺", "遗物图鉴", Vector2(48, 8), _on_relic_guide_pressed)


func _spawn_guide_button(parent: Control, text: String, tooltip: String, pos: Vector2, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(32, 32)
	btn.flat = true
	btn.add_theme_color_override("font_color", Color("#c8d0e8"))
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.position = pos
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _on_hand_guide_pressed() -> void:
	SoundPlayer.play_sound("click")
	ModalHubRef.open(
		HandGuideRef.new(),
		"牌型图鉴",
		{"size": Vector2(560, 780), "close_on_backdrop": true}
	)


func _on_relic_guide_pressed() -> void:
	SoundPlayer.play_sound("click")
	ModalHubRef.open(
		RelicGuideRef.new(),
		"遗物图鉴",
		{"size": Vector2(560, 780), "close_on_backdrop": true}
	)

func _on_battle_started(encounter: Dictionary) -> void:
	controller.start_battle(encounter)

func _on_battle_won() -> void:
	# 检查是否还有下一波敌人（波次转换）
	var wave_index: int = GameManager.current_wave_index
	var total_waves: int = GameManager.battle_waves.size()
	var next_wave_idx: int = wave_index + 1

	if next_wave_idx < total_waves:
		# 还有下一波 → 执行波次转换
		_begin_wave_transition(next_wave_idx)
	else:
		# 全部波次完成 → 战斗胜利后处理
		_handle_victory()

## 波次转换 — 对应原版 useBattleLifecycle gmPendingNextWave
## 垮波次保留：playsLeft/comboCount/freeRerollsLeft（Bug-21 修复）
func _begin_wave_transition(next_wave_idx: int) -> void:
	var wave_data: Array[Dictionary] = GameManager.battle_waves
	if next_wave_idx >= wave_data.size():
		_handle_victory()
		return

	var next_wave: Dictionary = wave_data[next_wave_idx]
	var next_enemies_raw: Array = next_wave.get("enemies", [])

	# 等待死亡动画播完
	await get_tree().create_timer(
		float(GameBalance.ANIMATION_TIMING.get("waveTransitionDeathBuffer", 400)) / 1000.0
	).timeout

	if not is_inside_tree():
		return

	# === 状态转换（关键：原版 Bug-21 对齐） ===
	# 垮波次≠回合结束，保留以下状态：
	# - playsLeft: max(prev, 1) — 保留剩余出牌次数，至少1
	# - freeRerollsLeft: max(prev, 1) — 保留免费重投，至少1
	# - comboCount: 保留连击
	# - lastPlayHandType: 保留
	# - armor: 清零
	# - bloodRerollCount: 清零（出牌后也重置）
	# - 法师吟唱判定：playsLeft >= maxPlays 时保留吟唱状态
	var prev_plays_left: int = GameManager.plays_left
	var prev_free_rerolls: int = GameManager.free_rerolls_left
	var prev_combo: int = PlayerState.combo_count
	var prev_last_hand: String = PlayerState.last_play_hand_type

	# 法师吟唱判定：没出过牌（playsLeft >= maxPlays）= 吟唱中
	var is_mage_chanting: bool = (
		PlayerState.player_class == "mage" and prev_plays_left >= GameManager.max_plays
	)

	# 更新波次索引
	GameManager.current_wave_index = next_wave_idx

	# 保留出牌次数和免费重投（至少1）
	TurnManager.plays_left = maxi(prev_plays_left, 1)
	TurnManager.free_rerolls_left = maxi(prev_free_rerolls, 1)

	# 保留连击和上次牌型
	PlayerState.combo_count = prev_combo
	PlayerState.last_play_hand_type = prev_last_hand

	# 护甲清零
	PlayerState.armor = 0

	# 血怒重置
	PlayerState.blood_reroll_count = 0

	# 法师吟唱状态处理
	if not is_mage_chanting:
		PlayerState.charge_stacks = 0
		PlayerState.mage_overcharge_mult = 0.0
		PlayerState.locked_element = ""

	# 波次内计数重置
	TurnManager.battle_turn = 1
	TurnManager.is_enemy_turn = false

	# 清除旧敌人视图，生成新敌人
	EnemyMgr.clear_enemy_views(controller.enemy_container)
	controller.enemy_views.clear()
	controller.selected_dice_indices.clear()
	controller._is_resolving = false

	var next_enemy_ids: Array[String] = []
	for e_id in next_enemies_raw:
		if e_id is String:
			next_enemy_ids.append(e_id)

	# 生成新敌人视图 — 绑定到 EnemyContainer 下 Slot0/1/2（位置所见即所得）
	for i: int in next_enemy_ids.size():
		var enemy_id: String = next_enemy_ids[i]
		# 通过工厂按 enemy_id 加载对应 tscn（独立 tscn 优先，兜底 enemy_view.tscn）
		var view: EnemyView = EnemyFactory.create(enemy_id)
		controller.enemy_container.add_child(view)
		view.set_slot_index(i)           # 先设 slot，再 init（init→setup→_refresh_visual 会读 _slot_index）
		view.init(enemy_id)
		# 设初始位置：用 enemy 真实 distance 查表（不再硬编码 distance=0）
		var battle_scene_ref := owner as BattleScene
		if battle_scene_ref != null:
			var e_inst: EnemyInstance = view.get_enemy_instance()
			var real_dist: int = e_inst.distance if e_inst else 0
			var init_vis: Dictionary = battle_scene_ref.get_slot_visuals(i, real_dist)
			view.position = init_vis.position
		view.enemy_clicked.connect(controller._on_enemy_clicked)
		controller.enemy_views.append(view)

	# 选择目标：优先 Guardian
	var target_uid: String = ""
	for e_inst: EnemyInstance in EnemyMgr.collect_enemy_instances(controller.enemy_views):
		if e_inst.combat_type == GameTypes.EnemyCombatType.GUARDIAN and e_inst.hp > 0:
			target_uid = e_inst.uid
			break
	if target_uid == "" and EnemyMgr.collect_enemy_instances(controller.enemy_views).size() > 0:
		target_uid = EnemyMgr.collect_enemy_instances(controller.enemy_views)[0].uid
	GameManager.target_enemy_uid = target_uid
	GameManager.taunt_enemy_uid = ""

	BattleLog.log_write("⚔ 第 %d 波敌人来袭！" % (next_wave_idx + 1))

	# 重新抽牌（法师吟唱时保留手牌）
	if not is_mage_chanting:
		# 非吟唱：清空手牌，从骰子库重新抽
		var leftover_ids: Array[String] = []
		for d: Dictionary in DiceBag.hand_dice:
			var did: String = d.get("defId", "")
			if did != "" and not d.get("isTemp", false):
				leftover_ids.append(did)
		if not leftover_ids.is_empty():
			DiceBag.discard_hand_dice(leftover_ids)
		DiceBag.hand_dice = []

	# 执行抽牌
	GameManager.execute_draw_phase()

	# 刷新UI
	EnemyMgr.refresh_enemy_views(controller.enemy_views)
	controller._refresh_status_bar()


## 战斗胜利处理 — 对应原版 useBattleVictory handleVictory
func _handle_victory() -> void:
	if not is_inside_tree():
		return

	# 1. 清除诅咒/碎裂骰子
	var cleaned_owned: Array[Dictionary] = []
	for d: Dictionary in GameManager.owned_dice:
		var def_id: String = d.get("defId", "")
		if def_id != "cursed" and def_id != "cracked":
			cleaned_owned.append(d)
	DiceBag.owned_dice = cleaned_owned

	var cleaned_bag: Array[String] = []
	for id: String in DiceBag.dice_bag:
		if id != "cursed" and id != "cracked":
			cleaned_bag.append(id)
	DiceBag.dice_bag = cleaned_bag

	var cleaned_discard: Array[String] = []
	for id: String in DiceBag.discard_pile:
		if id != "cursed" and id != "cracked":
			cleaned_discard.append(id)
	DiceBag.discard_pile = cleaned_discard

	# 2. 清除临时抽牌奖励
	PlayerState.temp_draw_count_bonus = 0

	# 3. 统计更新
	StatsTracker.stats.battlesWon = int(StatsTracker.stats.get("battlesWon", 0)) + 1

	# 4. 遗物 tick：incrementFloorsCleared + tickHourglass
	# （简化：当前 Godot 版遗物 tick 机制与原版不同，跳过复杂逻辑）

	# 5. 地图标记当前节点为 completed
	for node: MapGenerator.MapNode in GameManager.map_nodes:
		if node.depth == GameManager.current_node:
			node.visited = true
			break

	# 6. 判断后续阶段
	var depth: int = GameManager.current_node
	var is_chapter_boss: bool = depth >= GameBalance.MAP_CONFIG.totalLayers - 1

	# 播放胜利音效
	SoundPlayer.play_sound("victory")

	if is_chapter_boss:
		var has_next_chapter: bool = GameManager.advance_chapter()
		if has_next_chapter:
			GameManager.set_phase(GameTypes.GamePhase.CHAPTER_TRANSITION)
		else:
			GameManager.set_phase(GameTypes.GamePhase.VICTORY)
	else:
		# 普通战斗/精英/中Boss → 骰子奖励
		GameManager.set_phase(GameTypes.GamePhase.DICE_REWARD)

func _on_battle_lost() -> void:
	# BattleController 已切 GAME_OVER，这里仅作兜底
	pass
