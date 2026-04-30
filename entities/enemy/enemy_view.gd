## 敌人视图组件 — Node2D 世界物体（不再是 Control UI）
## 职责：数据绑定 + 视觉刷新；节点结构和样式都在 enemy_view.tscn 中定义
##
## 架构说明：
##   - 根节点 Node2D：作为世界物体存在，支持 position / scale / rotate / z_index
##   - VisualRoot：立绘 + 状态（受击/死亡动画挂这里，不污染根节点 transform）
##   - ClickArea (Area2D)：点击选中（原 Control 的 gui_input / mouse_entered 替代）
##   - HeadUI (Control)：挂在 VisualRoot 下，随纵深缩放；无底板漂浮血条
##
## 美术替换指引：
##   - AvatarShape (ColorRect) / AvatarStyle (Panel)：换成 Sprite2D / AnimatedSprite2D
##   - AvatarEyes (Label emoji)：表情动画出来后删除或替换
##   - ClickArea 碰撞体大小：美术尺寸确定后在 tscn 中调 RectangleShape2D.size

class_name EnemyView
extends Node2D

signal enemy_clicked(enemy_uid: String)

# 距离条最多 3 格
const MAX_DISTANCE_DOTS := 3
const DISTANCE_DOT_SIZE := Vector2(6, 6)
const DISTANCE_COLOR_FILLED := Color("#e07830")
const DISTANCE_COLOR_EMPTY := Color(1, 1, 1, 0.12)
const RANGED_LABEL_COLOR := Color("#30d8d0")
const MELEE_LABEL_COLOR := Color("#e07830")

# HP条颜色阶段
const HP_COLOR_HIGH := Color("#40c060")
const HP_COLOR_MID  := Color("#e0c040")
const HP_COLOR_LOW  := Color("#e04040")

var _enemy: EnemyInstance = null

# tscn 中的节点引用（%UniqueName 访问）
@onready var _visual_root: Node2D = %VisualRoot
@onready var _art_sprite: AnimatedSprite2D = %ArtSprite
@onready var _avatar_shape: ColorRect = %AvatarShape
@onready var _avatar_style: Panel = %AvatarStyle
@onready var _avatar_eyes: Label = %AvatarEyes
@onready var _target_indicator: ColorRect = %TargetIndicator
@onready var _click_area: Area2D = %ClickArea
@onready var _name_label: Label = %NameLabel
@onready var _combat_type_label: Label = %CombatTypeLabel
@onready var _intent_row: HBoxContainer = %IntentRow
@onready var _intent_icon: Panel = %IntentIcon
@onready var _intent_label: Label = %IntentLabel
@onready var _distance_row: HBoxContainer = %DistanceRow
@onready var _distance_text: Label = %DistanceText
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_text: Label = %HpText
@onready var _armor_icon: Label = %ArmorIcon
@onready var _armor_label: Label = %ArmorLabel
@onready var _status_container: HBoxContainer = %StatusContainer

# 运行时创建的距离圆点
var _distance_dots: Array[ColorRect] = []

# 站位索引（0=中=Slot0 1=左=Slot1 2=右=Slot2），由 BattleController 设置，用于透视位置计算
var _slot_index: int = -1

## 公开接口：设置站位索引（call down 原则）
func set_slot_index(index: int) -> void:
	_slot_index = index

# 美术层状态：是否用序列帧替代了占位方块
var _has_art: bool = false
var _death_played: bool = false

# 变更检测：避免无谓重算（W1 优化）
var _last_distance: int = -1
var _last_hp: int = -1

func _ready() -> void:
	# HeadUI 下所有 Control 节点设为 IGNORE，避免拦截 ClickArea 的点击事件
	_set_mouse_filter_ignore(%HeadUI)

	# 距离圆点：插入到 DistanceText 之前
	for i: int in MAX_DISTANCE_DOTS:
		var dot := ColorRect.new()
		dot.custom_minimum_size = DISTANCE_DOT_SIZE
		dot.color = DISTANCE_COLOR_EMPTY
		_distance_row.add_child(dot)
		_distance_row.move_child(dot, i)
		_distance_dots.append(dot)

	# Area2D 点击检测（替代原 Control.gui_input）
	_click_area.input_event.connect(_on_area_input_event)
	_click_area.mouse_entered.connect(_on_mouse_entered)
	_click_area.mouse_exited.connect(_on_mouse_exited)

	if _enemy != null:
		_try_load_art()
		_refresh_visual()


## 递归把 Control 子树全部设为 MOUSE_FILTER_IGNORE，防止拦截 Area2D 点击
func _set_mouse_filter_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_filter_ignore(child)

## 尝试加载美术 SpriteFrames。成功则隐藏占位三件套、显示 AnimatedSprite2D
func _try_load_art() -> void:
	if _enemy == null or _art_sprite == null:
		return
	# 先复位到"占位模式"——即使下面加载成功也会被覆盖；失败时这就是最终状态
	_restore_placeholder_visuals()
	var art_id := EnemyArtMapping.get_art_id(_enemy.config_id)
	if art_id == "":
		_has_art = false
		return
	var frames := EnemyArtMapping.load_sprite_frames(art_id)
	if frames == null:
		push_warning("[EnemyView] 美术资源加载失败 art_id=%s" % art_id)
		_has_art = false
		return
	_art_sprite.sprite_frames = frames
	# scale / flip_h / position 全部交给各敌人自己的 tscn（mobs/m*.tscn）在编辑器里调，
	# 代码不再强制覆盖——这是"一 prefab 管一敌人视觉"架构的契约
	_art_sprite.visible = true
	if frames.has_animation(EnemyArtMapping.IDLE_ANIM):
		_art_sprite.play(EnemyArtMapping.IDLE_ANIM)
	# 隐藏占位三件套
	_avatar_shape.visible = false
	_avatar_style.visible = false
	_avatar_eyes.visible = false
	_has_art = true
	_death_played = false

## 复位到"占位方块"状态：隐藏 ArtSprite、显示 ColorRect/Panel/Label
func _restore_placeholder_visuals() -> void:
	if _art_sprite:
		_art_sprite.stop()
		_art_sprite.visible = false
	if _avatar_shape:
		_avatar_shape.visible = true
	if _avatar_style:
		_avatar_style.visible = true
	if _avatar_eyes:
		_avatar_eyes.visible = true

## 播放攻击动画（外部调用，比如 EnemyActionResolver 触发敌人行动时）
func play_attack_anim() -> void:
	if not _has_art or _art_sprite == null or _art_sprite.sprite_frames == null:
		return
	if not _art_sprite.sprite_frames.has_animation(EnemyArtMapping.ATTACK_ANIM):
		return
	_art_sprite.play(EnemyArtMapping.ATTACK_ANIM)
	# 动画结束回到 idle
	if not _art_sprite.animation_finished.is_connected(_on_attack_finished):
		_art_sprite.animation_finished.connect(_on_attack_finished)

func _on_attack_finished() -> void:
	if _art_sprite == null or _art_sprite.sprite_frames == null:
		return
	# 只处理 attack01 结束回到 idle；death 不回调
	if _art_sprite.animation == EnemyArtMapping.ATTACK_ANIM:
		if _art_sprite.sprite_frames.has_animation(EnemyArtMapping.IDLE_ANIM):
			_art_sprite.play(EnemyArtMapping.IDLE_ANIM)

## 播放死亡动画（_refresh_visual 里 HP=0 时自动触发，只播一次）
func _play_death_anim() -> void:
	if _art_sprite == null or _art_sprite.sprite_frames == null:
		return
	if not _art_sprite.sprite_frames.has_animation(EnemyArtMapping.DEATH_ANIM):
		return
	_death_played = true
	_art_sprite.play(EnemyArtMapping.DEATH_ANIM)


## 受击动画：闪白 + 位移抖动（外部调用，玩家出牌命中时触发）
## 优先播放序列帧 hurt 动画（如果美术提供了），否则走代码驱动的闪白+抖动
func play_hurt() -> void:
	# 尝试序列帧 hurt 动画（美术后续可补 hurt 帧，不补也走下面的代码兜底）
	if _has_art and _art_sprite != null and _art_sprite.sprite_frames != null:
		if _art_sprite.sprite_frames.has_animation(EnemyArtMapping.HURT_ANIM):
			_art_sprite.play(EnemyArtMapping.HURT_ANIM)
			if not _art_sprite.animation_finished.is_connected(_on_hurt_finished):
				_art_sprite.animation_finished.connect(_on_hurt_finished)
			return
	# 代码驱动兜底：闪白 + X轴抖动
	if _visual_root == null:
		return
	# 记住原始 X，防止多次抖动累积偏移
	var origin_x: float = _visual_root.position.x
	# 单 tween 顺序编排：阶段1(并行) → 阶段2(并行) → 阶段3
	var tw := create_tween()
	# 阶段1：闪白 + 前冲（并行）
	tw.set_parallel(true)
	tw.tween_property(_visual_root, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.04)
	tw.tween_property(_visual_root, "position:x", origin_x + 6.0, 0.04)
	# 阶段2：闪白恢复 + 回弹（并行）
	tw.set_parallel(false)
	tw.set_parallel(true)
	tw.tween_property(_visual_root, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	tw.tween_property(_visual_root, "position:x", origin_x - 4.0, 0.08)
	# 阶段3：微颤归位
	tw.set_parallel(false)
	tw.tween_property(_visual_root, "position:x", origin_x, 0.06)


func _on_hurt_finished() -> void:
	if _art_sprite == null or _art_sprite.sprite_frames == null:
		return
	if _art_sprite.animation == EnemyArtMapping.HURT_ANIM:
		if _art_sprite.sprite_frames.has_animation(EnemyArtMapping.IDLE_ANIM):
			_art_sprite.play(EnemyArtMapping.IDLE_ANIM)


## 外部接口：绑定敌人实例并刷新视觉
func setup(enemy: EnemyInstance) -> void:
	_enemy = enemy
	# 修复 ART01-E2：重绑时必须重置美术状态，否则复用节点时 death 动画被跳过
	_death_played = false
	_has_art = false
	if is_node_ready():
		_try_load_art()
		_refresh_visual()


func refresh() -> void:
	if is_node_ready():
		_refresh_visual()


func get_enemy_uid() -> String:
	return _enemy.uid if _enemy else ""


func get_enemy_instance() -> EnemyInstance:
	return _enemy


## Controller 兼容接口：初始化（通过 enemy_id 从 EnemyConfig 查找数据构建真实实例）
func init(enemy_id: String) -> void:
	var config: EnemyConfig = EnemyConfig.get_config(enemy_id)
	if config == null:
		push_warning("[EnemyView] 未找到敌人配置: %s" % enemy_id)
		return
	var depth_scaling: Dictionary = GameBalance.get_depth_scaling(GameManager.current_node)
	var hp_scale: float = PlayerState.enemy_hp_multiplier * float(depth_scaling.get("hpMult", 1.0))
	var dmg_scale: float = float(depth_scaling.get("dmgMult", 1.0))
	var e: EnemyInstance = EnemyInstance.from_config(config, hp_scale, dmg_scale)
	setup(e)


## Controller 兼容接口：对敌人造成伤害（先扣护甲再扣血）
## §6.6 第 3 级：pierce 参数先于 armor 吸收前扣除目标护甲（不消耗伤害）
func take_damage(amount: int, pierce: int = 0) -> void:
	if _enemy == null:
		return
	if pierce > 0 and _enemy.armor > 0:
		_enemy.armor = maxi(0, _enemy.armor - pierce)
	var remaining := amount
	if _enemy.armor > 0:
		var absorbed := mini(_enemy.armor, remaining)
		_enemy.armor -= absorbed
		remaining -= absorbed
	_enemy.hp = maxi(0, _enemy.hp - remaining)
	_refresh_visual()


func is_alive() -> bool:
	return _enemy != null and _enemy.hp > 0


func is_selected() -> bool:
	return _enemy != null and _enemy.uid == GameManager.target_enemy_uid


func get_attack() -> int:
	return _enemy.attack_dmg if _enemy else 0


## Node2D 下，"中心坐标"就是自身全局坐标（上方 VisualRoot 中心偏移 -20）
func get_global_center() -> Vector2:
	return global_position + Vector2(0, -20)


func _refresh_visual() -> void:
	if _enemy == null or _name_label == null:
		return

	# W1 优化：数据未变时跳过重算
	var cur_dist := maxi(0, _enemy.distance)
	var cur_hp := _enemy.hp
	if cur_dist == _last_distance and cur_hp == _last_hp and _has_art:
		return
	_last_distance = cur_dist
	_last_hp = cur_hp

	_name_label.text = _enemy.name
	_update_combat_status()
	_update_avatar_visuals()
	_update_intent()
	_update_distance_display()
	_update_hp_display()
	_update_status_icons()
	_target_indicator.visible = (_enemy.uid == GameManager.target_enemy_uid)
	_update_depth_visuals()


## 战斗类型标签 + 立绘色（仅占位模式）
func _update_combat_status() -> void:
	var is_melee := _enemy.combat_type == GameTypes.EnemyCombatType.WARRIOR \
		or _enemy.combat_type == GameTypes.EnemyCombatType.GUARDIAN
	_combat_type_label.text = "[近]" if is_melee else "[远]"
	_combat_type_label.add_theme_color_override(
		"font_color", MELEE_LABEL_COLOR if is_melee else RANGED_LABEL_COLOR
	)
	if not _has_art:
		var avatar_color: Color = _enemy_type_color(_enemy.combat_type)
		_avatar_shape.color = avatar_color
		var avatar_style: StyleBoxFlat = _avatar_style.get_theme_stylebox("panel") as StyleBoxFlat
		if avatar_style:
			avatar_style.bg_color = avatar_color


## 眼睛表情 + 死亡动画触发
func _update_avatar_visuals() -> void:
	var hp_ratio := float(_enemy.hp) / float(_enemy.max_hp)
	if not _has_art:
		if hp_ratio > 0.6:
			_avatar_eyes.text = "◉ ◉"
		elif hp_ratio > 0.3:
			_avatar_eyes.text = "◉ ◔"
		else:
			_avatar_eyes.text = "× ×"
	# 序列帧模式下：死亡触发一次 death 动画
	if _has_art and _enemy.hp <= 0 and not _death_played:
		_play_death_anim()


## 距离条
func _update_distance_display() -> void:
	var dist := maxi(0, _enemy.distance)
	var show_distance := dist > 0
	_distance_row.visible = show_distance
	if show_distance:
		for i: int in MAX_DISTANCE_DOTS:
			_distance_dots[i].color = DISTANCE_COLOR_FILLED if i < dist else DISTANCE_COLOR_EMPTY
		_distance_text.text = "距%d" % dist


## HP 条 + 护甲
func _update_hp_display() -> void:
	var hp_ratio := float(_enemy.hp) / float(_enemy.max_hp)
	_hp_bar.max_value = _enemy.max_hp
	_hp_bar.value = maxi(0, _enemy.hp)
	var hp_fill: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if hp_fill:
		if hp_ratio > 0.6:
			hp_fill.bg_color = HP_COLOR_HIGH
		elif hp_ratio > 0.3:
			hp_fill.bg_color = HP_COLOR_MID
		else:
			hp_fill.bg_color = HP_COLOR_LOW
	_hp_text.text = "%d/%d" % [maxi(0, _enemy.hp), _enemy.max_hp]
	# 护甲
	if _enemy.armor > 0:
		_armor_label.text = str(_enemy.armor)
		_armor_icon.visible = true
		_armor_label.visible = true
	else:
		_armor_icon.visible = false
		_armor_label.visible = false


## 纵深视觉（缩放/亮度/z-index + 位置查表）
## 位置契约（所见即所得·Inspector 配置）：
##   battle_scene.gd 的 @export 定义 3×4=12 个坐标 + 对应缩放/Y偏移/亮度/z_index
##   distance 的值就是属性名中的数字，敌人头上显示"距N"就对应"距离N"这组参数
##   所有参数在 Inspector 面板直接调，代码不做任何插值
func _update_depth_visuals() -> void:
	if _slot_index < 0:
		return
	var dist := maxi(0, _enemy.distance)
	var battle_scene := _get_battle_scene()
	if battle_scene == null:
		return
	var visuals: Dictionary = battle_scene.get_slot_visuals(_slot_index, dist)
	position = visuals.position
	_visual_root.scale = Vector2(visuals.depth_scale, visuals.depth_scale)
	_visual_root.position.y = visuals.depth_y
	_visual_root.modulate = Color(visuals.depth_brightness, visuals.depth_brightness, visuals.depth_brightness, 1.0)
	z_index = int(visuals.depth_z)


## 获取 BattleScene 引用 — 通过 owner（场景根节点）向上查找
func _get_battle_scene() -> BattleScene:
	var node: Node = self
	while node != null:
		if node is BattleScene:
			return node as BattleScene
		node = node.get_parent()
	return null


func _update_intent() -> void:
	if _enemy == null:
		return
	var action: Dictionary = _enemy.get_action()
	var action_type: String = action.get("type", "攻击")
	var desc: String = action.get("description", "")
	var value: int = int(action.get("value", 0))

	var intent_text: String
	var intent_color: Color
	match action_type:
		"攻击":
			intent_text = "⚔ %d" % value if desc == "" else "⚔ %s %d" % [desc, value]
			intent_color = Color("#e04040")
		"防御":
			intent_text = "🛡 %d" % value if desc == "" else "🛡 %s %d" % [desc, value]
			intent_color = Color("#4080e0")
		"技能":
			intent_text = "✦ %s" % desc if desc != "" else "✦ 施法"
			intent_color = Color("#c040e0")
		_:
			intent_text = "?"
			intent_color = Color.GRAY

	if _enemy.is_frozen():
		intent_text = "❄ 冻结"
		intent_color = Color("#80d0ff")

	_intent_label.text = intent_text
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = intent_color
	icon_style.corner_radius_top_left = 5
	icon_style.corner_radius_top_right = 5
	icon_style.corner_radius_bottom_right = 5
	icon_style.corner_radius_bottom_left = 5
	_intent_icon.add_theme_stylebox_override("panel", icon_style)
	_intent_row.visible = true


func _update_status_icons() -> void:
	for child: Node in _status_container.get_children():
		child.queue_free()

	if _enemy == null or _enemy.statuses.is_empty():
		return

	for s: StatusEffect in _enemy.statuses:
		var icon := Label.new()
		icon.add_theme_font_size_override("font_size", 10)
		match s.type:
			GameTypes.StatusType.POISON:
				icon.text = "☠"
				icon.add_theme_color_override("font_color", Color("#50e050"))
			GameTypes.StatusType.BURN:
				icon.text = "🔥"
				icon.add_theme_color_override("font_color", Color("#e08030"))
			GameTypes.StatusType.WEAK:
				icon.text = "💪"
				icon.add_theme_color_override("font_color", Color("#e0e040"))
			GameTypes.StatusType.VULNERABLE:
				icon.text = "💔"
				icon.add_theme_color_override("font_color", Color("#e04040"))
			GameTypes.StatusType.FREEZE:
				icon.text = "❄"
				icon.add_theme_color_override("font_color", Color("#80d0ff"))
			GameTypes.StatusType.SLOW:
				icon.text = "⬇"
				icon.add_theme_color_override("font_color", Color("#a0a0a0"))
			_:
				icon.text = "?"
		_status_container.add_child(icon)


func _enemy_type_color(combat_type: GameTypes.EnemyCombatType) -> Color:
	match combat_type:
		GameTypes.EnemyCombatType.WARRIOR:
			return Color(0.75, 0.35, 0.25, 1.0)
		GameTypes.EnemyCombatType.GUARDIAN:
			return Color(0.35, 0.55, 0.75, 1.0)
		GameTypes.EnemyCombatType.CASTER:
			return Color(0.65, 0.35, 0.75, 1.0)
		GameTypes.EnemyCombatType.PRIEST:
			return Color(0.35, 0.75, 0.55, 1.0)
		_:
			return Color(0.5, 0.5, 0.5, 1.0)


# ── 点击与鼠标悬浮（Area2D 替代 Control 系统）

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _enemy:
			enemy_clicked.emit(_enemy.uid)


func _on_mouse_entered() -> void:
	if _enemy == null:
		return
	Tooltip.show_text(_build_tooltip_text(), get_global_mouse_position())


func _on_mouse_exited() -> void:
	Tooltip.hide_tip()


func _build_tooltip_text() -> String:
	if _enemy == null:
		return ""
	var cfg: EnemyConfig = EnemyConfig.get_config(_enemy.config_id)
	var lines: Array[String] = []
	lines.append("【%s】" % (cfg.name if cfg else _enemy.config_id))
	lines.append("HP %d / %d" % [_enemy.hp, _enemy.max_hp])
	lines.append("攻击 %d" % _enemy.attack_dmg)
	if _enemy.armor > 0:
		lines.append("护甲 %d" % _enemy.armor)
	if _enemy.distance > 0:
		lines.append("距离 %d" % _enemy.distance)
	var job_desc: String = _job_desc(_enemy.combat_type)
	if job_desc != "":
		lines.append("")
		lines.append(job_desc)
	var action: Dictionary = _enemy.get_action()
	if not action.is_empty():
		lines.append("")
		lines.append("意图：%s" % action.get("description", ""))
	if not _enemy.statuses.is_empty():
		lines.append("")
		lines.append("状态：")
		for s: StatusEffect in _enemy.statuses:
			lines.append("• %s" % _status_tooltip_line(s))
	return "\n".join(lines)


func _job_desc(t: GameTypes.EnemyCombatType) -> String:
	match t:
		GameTypes.EnemyCombatType.WARRIOR:
			return "战士 · 近战，冲锋造成基础伤害"
		GameTypes.EnemyCombatType.RANGER:
			return "射手 · 远程，每次攻击附带追击"
		GameTypes.EnemyCombatType.GUARDIAN:
			return "守卫 · 每 2 回合举盾嘲讽"
		GameTypes.EnemyCombatType.PRIEST:
			return "祭司 · 治疗盟友或施加负面状态"
		GameTypes.EnemyCombatType.CASTER:
			return "法师 · 释放中毒或灼烧 DoT"
		_:
			return ""


static func _status_tooltip_line(s: StatusEffect) -> String:
	var status_name: String = ""
	var desc: String = ""
	match s.type:
		GameTypes.StatusType.POISON:
			status_name = "中毒"; desc = "每回合损失 HP"
		GameTypes.StatusType.BURN:
			status_name = "灼烧"; desc = "回合末一次性灼烧伤害"
		GameTypes.StatusType.WEAK:
			status_name = "虚弱"; desc = "造成伤害降低"
		GameTypes.StatusType.VULNERABLE:
			status_name = "易伤"; desc = "受到伤害提升"
		GameTypes.StatusType.FREEZE:
			status_name = "冻结"; desc = "跳过下一次行动"
		GameTypes.StatusType.SLOW:
			status_name = "迟缓"; desc = "近战推进减慢"
		_:
			status_name = "未知状态"
	return "%s %d（%d 回合） — %s" % [status_name, s.value, s.duration, desc]
