# battle_scene.gd — 战斗场景入口
# 职责：场景生命周期管理 + 启动 BattleController
class_name BattleScene
extends Node2D

const ModalHubRef := preload("res://common/ui/modal_hub.gd")
const HandGuideRef := preload("res://common/ui/hand_guide.gd")
const RelicGuideRef := preload("res://common/ui/relic_guide.gd")
const SettingsPanelRef := preload("res://common/ui/settings_panel.gd")
const BattleLogRef := preload("res://gameplay/battle/ui/battle_log.gd")
const TooltipRef := preload("res://common/ui/tooltip.gd")
const RelicBarRef := preload("res://gameplay/battle/ui/relic_panel.gd")
const RelicOverlayRef := preload("res://gameplay/battle/ui/relic_overlay.gd")
const EnemyMgr := preload("res://gameplay/battle/battle_enemy_manager.gd")

## ========================================================
## 敌人透视参数 — Inspector 直接配置，所见即所得
## 3 个 Slot × 3 档距离 × (坐标 + 缩放 + Y偏移 + 亮度 + 渲染层级) = 45 个参数
## 命名 = enemy.distance 的值，敌人头上显示"距N"就对应"距离N"这组参数
## 距离范围 1~3，1=贴脸（近战攻击距离），3=最远
## 坐标为 EnemyContainer 局部坐标
## ========================================================

@export_group("敌人透视·Slot0(中)")
@export var 中_距离1坐标: Vector2 = Vector2(0, 40)
@export var 中_距离1缩放: float = 2.0
@export var 中_距离1纵深Y偏移: float = 0.0
@export var 中_距离1亮度: float = 1.0
@export var 中_距离1渲染层级: int = 7

@export var 中_距离2坐标: Vector2 = Vector2(0, 10)
@export var 中_距离2缩放: float = 1.0
@export var 中_距离2纵深Y偏移: float = 0.0
@export var 中_距离2亮度: float = 0.88
@export var 中_距离2渲染层级: int = 5

@export_group("敌人透视·Slot1(左)")
@export var 左_距离1坐标: Vector2 = Vector2(-35, 40)
@export var 左_距离1缩放: float = 2.0
@export var 左_距离1纵深Y偏移: float = 0.0
@export var 左_距离1亮度: float = 1.0
@export var 左_距离1渲染层级: int = 7

@export var 左_距离2坐标: Vector2 = Vector2(-28, 10)
@export var 左_距离2缩放: float = 1.0
@export var 左_距离2纵深Y偏移: float = 0.0
@export var 左_距离2亮度: float = 0.88
@export var 左_距离2渲染层级: int = 5

@export_group("敌人透视·Slot2(右)")
@export var 右_距离1坐标: Vector2 = Vector2(35, 40)
@export var 右_距离1缩放: float = 2.0
@export var 右_距离1纵深Y偏移: float = 0.0
@export var 右_距离1亮度: float = 1.0
@export var 右_距离1渲染层级: int = 7

@export var 右_距离2坐标: Vector2 = Vector2(28, 10)
@export var 右_距离2缩放: float = 1.0
@export var 右_距离2纵深Y偏移: float = 0.0
@export var 右_距离2亮度: float = 0.88
@export var 右_距离2渲染层级: int = 5


## Slot 分配策略：根据敌人总数决定每个敌人的 slot 位置
## 1个敌人 → [0] (中)
## 2个敌人 → [1, 2] (左, 右)
## 3个敌人 → [1, 0, 2] (左, 中, 右)
## 4个敌人 → [1, 0, 2, 0] (左, 中, 右, 中偏移 — 兜底)
static func get_slot_assignment(enemy_count: int, enemy_index: int) -> int:
	match enemy_count:
		1:
			return 0  # 中
		2:
			return [1, 2][enemy_index] if enemy_index < 2 else 0
		3, _:
			return [1, 0, 2][enemy_index] if enemy_index < 3 else 0


## 查表接口：根据 slot_index 和 distance 返回该档位的全部透视参数
## slot_index: 0=中 1=左 2=右
## distance: 就是 enemy.distance 的值，敌人头上显示"距N"就传 N
## 返回: { position, depth_scale, depth_y, depth_brightness, depth_z }
func get_slot_visuals(slot_index: int, distance: int) -> Dictionary:
	var d: int = clampi(distance, 1, 2)
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
	_apply_static_background()
	# 地图/事件切换到 BATTLE 场景时不会发射 battle_started 信号，
	# 而是通过 GameManager.pending_wave 交付波次数据，因此这里直接启动战斗。
	_bootstrap_from_pending_wave()


## 配置表驱动的战斗背景加载（24张场景图 + 防重复）
## 通过 BattleBgConfig 根据节点类型和 depth 从对应池中随机选取
var _last_bg_path: String = ""  ## 防重复：记录上一次使用的背景路径

func _apply_static_background() -> void:
	var bg_node: Node2D = get_node_or_null("%SceneBG")
	if bg_node == null:
		return
	var depth: int = GameManager.current_node
	var node_type: GameTypes.NodeType = GameManager.current_node_type
	# 从配置表获取随机背景（带防重复）
	var bg_path: String = _pick_bg_no_repeat(node_type, depth)
	if bg_path.is_empty():
		push_warning("[BattleScene] 无可用背景，node_type=%s depth=%d" % [node_type, depth])
		return
	var tex: Texture2D = load(bg_path) as Texture2D
	if tex == null:
		push_warning("[BattleScene] 背景加载失败: %s" % bg_path)
		return
	_last_bg_path = bg_path
	# 隐藏 Sky / FarView / MidView，只用 GroundBase 铺满整个视口
	var sky: Sprite2D = bg_node.get_node_or_null("Sky") as Sprite2D
	var far: Sprite2D = bg_node.get_node_or_null("FarView") as Sprite2D
	var mid: Sprite2D = bg_node.get_node_or_null("MidView") as Sprite2D
	var ground: Sprite2D = bg_node.get_node_or_null("GroundBase") as Sprite2D
	if sky != null:
		sky.visible = false
	if far != null:
		far.visible = false
	if mid != null:
		mid.visible = false
	if ground != null:
		ground.texture = tex
		var vp_size: Vector2 = get_viewport_rect().size
		var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
		var scale_x: float = vp_size.x / tex_size.x
		var scale_y: float = vp_size.y / tex_size.y
		var final_scale: float = maxf(scale_x, scale_y)
		ground.scale = Vector2(final_scale, final_scale)
		ground.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.5)
		ground.z_index = -40
		var bg_script: BgParallax = bg_node as BgParallax
		if bg_script != null:
			bg_script._base_y_ground = vp_size.y * 0.5


## 防重复选取：最多重试 5 次避免连续两场相同背景
func _pick_bg_no_repeat(node_type: GameTypes.NodeType, depth: int) -> String:
	var path: String = BattleBgConfig.get_random_bg(node_type, depth)
	var attempts: int = 0
	while path == _last_bg_path and attempts < 5:
		path = BattleBgConfig.get_random_bg(node_type, depth)
		attempts += 1
	return path


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
		# 刘叔需求 1：玩家受击时背景反弹（摄像机被打退）
		var bg: BgParallax = get_node_or_null("%SceneBG") as BgParallax
		if bg != null:
			bg.play_hurt_kick()
		# 玩家掉血飘字（从 hp_bar 位置飘出）
		if controller != null and controller._float_layer != null and controller.hp_bar != null:
			var hp_pos: Vector2 = controller.hp_bar.global_position + controller.hp_bar.size * 0.5
			VFX.spawn_damage_text(controller._float_layer, hp_pos, damage_taken)
	_last_player_hp = new_hp


func _on_player_game_over() -> void:
	if player_hands == null:
		return
	player_hands.play_death()
	# 死亡过渡动画 → 完成后切 GAME_OVER
	DeathTransition.play(self, func():
		GameManager.set_phase(GameTypes.GamePhase.GAME_OVER)
	)


## [E2-FIX] Autoload 信号连接必须在场景离开时断开
## 防止 BattleScene queue_free 后 PlayerState 持有野 Callable
func _exit_tree() -> void:
	if PlayerState.hp_changed.is_connected(_on_player_hp_changed):
		PlayerState.hp_changed.disconnect(_on_player_hp_changed)
	if PlayerState.game_over_requested.is_connected(_on_player_game_over):
		PlayerState.game_over_requested.disconnect(_on_player_game_over)
	# controller 信号由 controller 自身生命周期管理，无需手动断开
	# （controller 是 BattleScene 子节点，父死子死）


func _spawn_relic_panel() -> void:
	# 挂载到 HandPanel 顶部的 %RelicBar 容器（tscn 中已预留锚点）
	var bar_anchor: Node = get_node_or_null("%RelicBar")
	if bar_anchor == null:
		push_warning("[BattleScene] 未找到 %RelicBar 锚点，遗物栏未挂载")
		return
	var bar: VBoxContainer = RelicBarRef.new()
	bar.name = "RelicBar"
	bar_anchor.add_child(bar)
	# 订阅折叠/展开信号
	bar.expand_requested.connect(_on_relic_bar_expand.bind(bar))
	bar.collapse_requested.connect(_on_relic_bar_collapse)


## 当前展开的 Overlay 实例（同时只允许一个）
var _active_relic_overlay: Control = null


func _on_relic_bar_expand(bar: VBoxContainer) -> void:
	if _active_relic_overlay != null and is_instance_valid(_active_relic_overlay):
		return  # 已经展开
	var root: Control = get_node_or_null("%Root")
	if root == null:
		return
	var overlay: Control = RelicOverlayRef.new()
	overlay.name = "RelicOverlay"
	root.add_child(overlay)
	_active_relic_overlay = overlay
	overlay.connect("closed", func() -> void:
		_active_relic_overlay = null
		if is_instance_valid(bar) and bar.has_method("notify_collapsed"):
			bar.call("notify_collapsed")
	)


func _on_relic_bar_collapse() -> void:
	if _active_relic_overlay != null and is_instance_valid(_active_relic_overlay):
		if _active_relic_overlay.has_method("close_with_anim"):
			_active_relic_overlay.call("close_with_anim")


func _spawn_battle_log() -> void:
	# 战斗内不显示日志 UI（已下沉到 SettingsPanel），但仍需实例化以承担数据收集
	# BattleLog 静态 API 依赖 _instance，不挂节点则 log_write 全部静默丢弃
	var root: Control = get_node_or_null("%Root")
	if root == null:
		return
	var log_panel := BattleLogRef.new()
	log_panel.name = "BattleLog"
	log_panel.visible = false  # 数据收集器，UI 隐藏；通过 Settings 查看
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

	# Boss 入场演出：检查波次中是否有 Boss 级敌人（通过 EnemyConfig 查 category）
	var boss_name: String = ""
	for e_id in wave:
		if e_id is String:
			var cfg: EnemyConfig = EnemyConfig.get_config(e_id)
			if cfg != null and cfg.category == EnemyConfig.EnemyCategory.BOSS:
				boss_name = cfg.name
				break

	if boss_name != "":
		var depth: int = GameManager.current_node
		var is_final: bool = depth >= GameBalance.MAP_CONFIG.totalLayers - 1
		BossEntrance.play(self, boss_name, GameManager.chapter, is_final, func():
			controller.start_battle({"enemies": wave})
		)
	else:
		controller.start_battle({"enemies": wave})


func _spawn_topleft_buttons() -> void:
	# 战斗界面左上角快捷图鉴入口
	var root: Control = get_node_or_null("%Root")
	if root == null:
		push_warning("[BattleScene] 未找到 %Root 节点，图鉴按钮未挂载")
		return
	_spawn_guide_button(root, "[B]", "牌型图鉴", Vector2(4, 4), _on_hand_guide_pressed)
	_spawn_guide_button(root, "[R]", "遗物图鉴", Vector2(24, 4), _on_relic_guide_pressed)
	_spawn_guide_button(root, "[S]", "设置 / 战斗日志", Vector2(44, 4), _on_settings_pressed)
	# 骰子库/弃骰库按钮（右上角）
	var draw_btn := Button.new()
	draw_btn.text = "[D]"
	draw_btn.tooltip_text = "骰子库"
	draw_btn.add_theme_font_size_override("font_size", 5)
	draw_btn.custom_minimum_size = Vector2(18, 10)
	draw_btn.flat = true
	draw_btn.add_theme_color_override("font_color", Color("#c8d0e8"))
	draw_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	draw_btn.position = Vector2(-40, 4)
	draw_btn.pressed.connect(_on_draw_pile_pressed)
	root.add_child(draw_btn)

	var discard_btn := Button.new()
	discard_btn.text = "[R]"
	discard_btn.tooltip_text = "弃骰库"
	discard_btn.add_theme_font_size_override("font_size", 5)
	discard_btn.custom_minimum_size = Vector2(18, 10)
	discard_btn.flat = true
	discard_btn.add_theme_color_override("font_color", Color("#c8d0e8"))
	discard_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	discard_btn.position = Vector2(-20, 4)
	discard_btn.pressed.connect(_on_discard_pile_pressed)
	root.add_child(discard_btn)


func _spawn_guide_button(parent: Control, text: String, tooltip: String, pos: Vector2, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.add_theme_font_size_override("font_size", 4)
	btn.custom_minimum_size = Vector2(9, 5)
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


func _on_settings_pressed() -> void:
	SoundPlayer.play_sound("click")
	ModalHubRef.open(
		SettingsPanelRef.new(),
		"设置",
		{"size": Vector2(480, 680), "close_on_backdrop": true}
	)


var _dice_bag_panel: DiceBagPanel = null

func _on_draw_pile_pressed() -> void:
	SoundPlayer.play_sound("click")
	_open_dice_bag_panel(DiceBagPanel.PanelMode.DRAW_PILE)


func _on_discard_pile_pressed() -> void:
	SoundPlayer.play_sound("click")
	_open_dice_bag_panel(DiceBagPanel.PanelMode.DISCARD_PILE)


func _open_dice_bag_panel(mode: DiceBagPanel.PanelMode) -> void:
	if _dice_bag_panel != null and is_instance_valid(_dice_bag_panel):
		_dice_bag_panel.queue_free()
	_dice_bag_panel = DiceBagPanel.new()
	add_child(_dice_bag_panel)
	_dice_bag_panel.open(mode)

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

	# === 状态转换（对齐原版 useBattleLifecycle gmPendingNextWave） ===
	# 跨波次重置（原版行为）：
	# - playsLeft: 重置为 maxPlays
	# - freeRerollsLeft: 重置为 freeRerollsPerTurn
	# - comboCount: 重置为 0
	# - lastPlayHandType: 重置为空
	# - armor: 清零
	# - bloodRerollCount: 清零
	# - 法师吟唱判定：playsLeft >= maxPlays 时保留吟唱状态
	var prev_plays_left: int = GameManager.plays_left

	# 法师吟唱判定：没出过牌（playsLeft >= maxPlays）= 吟唱中
	var is_mage_chanting: bool = (
		PlayerState.player_class == "mage" and prev_plays_left >= GameManager.max_plays
	)

	# 更新波次索引
	GameManager.current_wave_index = next_wave_idx

	# 重置出牌次数和免费重投（原版行为：回到满值）
	TurnManager.plays_left = GameManager.max_plays
	TurnManager.free_rerolls_left = GameManager.free_rerolls_per_turn

	# 重置连击和上次牌型（原版行为：跨波不保留连击）
	PlayerState.combo_count = 0
	PlayerState.last_play_hand_type = ""

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
		var slot_idx: int = BattleScene.get_slot_assignment(next_enemy_ids.size(), i)
		view.set_slot_index(slot_idx)    # 先设 slot，再 init（init→setup→_refresh_visual 会读 _slot_index）
		view.init(enemy_id)
		# 设初始位置：用 enemy 真实 distance 查表
		var battle_scene_ref := owner as BattleScene
		if battle_scene_ref != null:
			var e_inst: EnemyInstance = view.get_enemy_instance()
			var real_dist: int = e_inst.distance if e_inst else 1
			var init_vis: Dictionary = battle_scene_ref.get_slot_visuals(slot_idx, real_dist)
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

	BattleLog.log_write("X 第 %d 波敌人来袭！" % (next_wave_idx + 1))

	# 波次切换全屏公告
	_show_wave_announcement(next_wave_idx + 1)

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

	# 4. 经验值奖励 — 根据当前节点类型给予 XP
	var node_type_str: String = _get_current_node_type_for_xp()
	var XpSystemScript := preload("res://common/autoload/xp_system.gd")
	var xp_gain: int = XpSystemScript.roll_kill_xp(node_type_str)
	XpSystem.apply_xp_gain(xp_gain)
	BattleLog.log_write("* 获得 %d 经验值" % xp_gain)

	# 5. 遗物 tick：incrementFloorsCleared + tickHourglass
	# （简化：当前 Godot 版遗物 tick 机制与原版不同，跳过复杂逻辑）

	# 6. 地图标记当前节点为 completed
	for node: MapGenerator.MapNode in GameManager.map_nodes:
		if node.depth == GameManager.current_node:
			node.visited = true
			break

	# 6. 判断后续阶段
	var depth: int = GameManager.current_node
	var is_chapter_boss: bool = depth >= GameBalance.MAP_CONFIG.totalLayers - 1

	# 6b. 终焉Boss奖励：+1抽牌上限（原版 lootHandler.ts isFinalBoss → diceCount+1）
	if is_chapter_boss:
		GameManager.draw_count += 1
		BattleLog.log_write("[D] 击败Boss！抽牌上限 +1（当前 %d）" % GameManager.draw_count)

	# 6c. 精英额外奖励：额外金币（原版 LOOT_CONFIG.eliteRewards）
	if node_type_str == "elite":
		var elite_bonus_gold: int = 15 + randi() % 16  # 15-30 额外金币
		GameManager.gold += elite_bonus_gold
		BattleLog.log_write("G 精英战额外奖励：+%d 金币" % elite_bonus_gold)

	# 胜利特效：全屏奖励爆发
	var viewport_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	VFX.reward_explosion(self, viewport_center, 20)

	# 播放胜利音效
	SoundPlayer.play_sound("victory")

	# 7. 检查升级弹窗（经验值可能触发了升级）
	if XpSystem.has_pending_level_up():
		var LevelUpModalRef := preload("res://common/ui/level_up_modal.gd")
		LevelUpModalRef.check_and_show()
		# 等待所有升级选择完成后再切换阶段
		while XpSystem.has_pending_level_up():
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				return

	if is_chapter_boss:
		var has_next_chapter: bool = GameManager.advance_chapter()
		if has_next_chapter:
			GameManager.set_phase(GameTypes.GamePhase.CHAPTER_TRANSITION)
		else:
			GameManager.set_phase(GameTypes.GamePhase.VICTORY)
	else:
		# 普通战斗/精英/中Boss → 骰子奖励
		GameManager.set_phase(GameTypes.GamePhase.DICE_REWARD)

## 获取当前节点类型字符串（用于 XpSystem 经验计算）
func _get_current_node_type_for_xp() -> String:
	for node: MapGenerator.MapNode in GameManager.map_nodes:
		if node.depth == GameManager.current_node:
			match node.type:
				GameTypes.NodeType.ELITE: return "elite"
				GameTypes.NodeType.BOSS: return "boss"
				_: return "normal"
	return "normal"

func _on_battle_lost() -> void:
	# BattleController 已切 GAME_OVER，这里仅作兜底
	pass


## 波次切换全屏公告动画
func _show_wave_announcement(wave_num: int) -> void:
	var label := Label.new()
	label.text = "第 %d 波" % wave_num
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("#ffffff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.custom_minimum_size = Vector2(75, 15)
	label.modulate = Color(1, 1, 1, 0)
	label.z_index = 100
	# 用 CanvasLayer 确保在最上层
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	add_child(canvas)
	canvas.add_child(label)
	# 居中定位
	label.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 300) * 0.5,
		get_viewport().get_visible_rect().size.y * 0.35
	)
	# 动画：淡入 → 停留 → 淡出
	var tw := create_tween()
	tw.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.tween_interval(1.0)
	tw.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(canvas.queue_free)


## ── 敌人点击检测 ──────────────────────────────────────────
## Area2D.input_event 被 UILayer(CanvasLayer layer=10) 拦截，
## 改用 _input + 手动碰撞检测 + UI 区域排除
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# 排除 UI 区域（TopBar 和 PlayerHUD 占据的屏幕顶部/底部）
	var screen_pos: Vector2 = mb.position
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	# TopBar 高度约 48px，PlayerHUD + DamagePreview 约 134px
	if screen_pos.y < 48.0 or screen_pos.y > vp_size.y - 134.0:
		return
	# 将屏幕坐标转换为世界坐标
	var world_pos: Vector2 = get_global_mouse_position()
	# 遍历所有存活的敌人视图，检查点击是否命中其 ClickArea
	var hit_view: EnemyView = _find_clicked_enemy(world_pos)
	if hit_view:
		controller._on_enemy_clicked(hit_view.get_enemy_uid())
		get_viewport().set_input_as_handled()


## 查找被点击的敌人视图（按渲染层级从高到低，优先选中前景敌人）
func _find_clicked_enemy(world_pos: Vector2) -> EnemyView:
	var best_view: EnemyView = null
	var best_z: int = -9999
	for view: EnemyView in controller.enemy_views:
		if not is_instance_valid(view) or not view.is_inside_tree():
			continue
		var click_area: Area2D = view.get_click_area()
		if click_area == null:
			continue
		var shape_node: CollisionShape2D = click_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			continue
		# 用 global_transform 正确计算碰撞矩形（包含所有父节点的缩放/旋转/位移）
		var gt: Transform2D = shape_node.global_transform
		var half_size: Vector2 = rect_shape.size * 0.5
		# 将世界坐标转换到 shape 的局部坐标系
		var local_pos: Vector2 = gt.affine_inverse() * world_pos
		if absf(local_pos.x) <= half_size.x and absf(local_pos.y) <= half_size.y:
			if view.z_index > best_z:
				best_z = view.z_index
				best_view = view
	return best_view
