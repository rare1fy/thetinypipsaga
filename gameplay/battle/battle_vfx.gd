## 战斗 VFX 分派器 — 从 battle_scene.gd 抽出的受击 / 死亡 / 状态视觉效果
## 纯 static，调用方传入所需上下文（面板、enemies、ui_root、selected_dice）
## 2026-04-24 拆分缘由：battle_scene.gd 突破 600 行硬上限，按 RULES B1 强制下沉

class_name BattleVfx


## 敌人受击 VFX（信号响应版，敌方回合反打 / 爆发伤害触发）
## 不带元素粒子，只做闪白 + 震屏
## shake_target: 震屏目标（WorldLayer），UI 不受影响
static func on_enemy_damaged_signal(enemy_container: Node, enemies: Array[EnemyInstance], enemy_uid: String, damage: int, shake_target: Node) -> void:
	var panel := _get_alive_panel(enemy_container, enemies, enemy_uid)
	if panel == null:
		return
	_flash_node(panel)
	if damage >= 30:
		VFX.shake_heavy(shake_target, 10.0, 0.4)
		SoundPlayer.play_heavy_impact(1.0)
	else:
		VFX.shake(shake_target, 5.0, 0.15)


## 敌人死亡粒子
static func on_enemy_died(enemy_container: Node, enemies: Array[EnemyInstance], ui_root: Node, enemy_uid: String) -> void:
	var panel := _get_alive_panel(enemy_container, enemies, enemy_uid)
	if panel == null:
		return
	var center := _node_center(panel)
	var burst_colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW]
	VFX.pixel_burst(ui_root, center, 12, burst_colors)


## 玩家出牌命中 VFX（真伤输出主路径）
## 根据 selected_dice 计算主导元素，决定粒子颜色；damage >= 30 触发重击震屏
## shake_target: 震屏目标（WorldLayer），UI 不受影响
static func on_player_hit(enemy_container: Node, enemies: Array[EnemyInstance], ui_root: Node, shake_target: Node, enemy_uid: String, damage: int, selected_dice: Array[Dictionary]) -> void:
	var panel := _get_alive_panel(enemy_container, enemies, enemy_uid)
	if panel == null:
		return
	_flash_node(panel)
	var element := BattleHelpers.dominant_element(selected_dice)
	var center := _node_center(panel)
	if damage >= 30:
		VFX.shake_heavy(shake_target, 8.0, 0.3)
		SoundPlayer.play_heavy_impact(minf(2.0, damage / 30.0))
		VFX.spawn_element_hit(ui_root, center, element, 14)
	else:
		VFX.shake(shake_target, 4.0, 0.15)
		VFX.spawn_element_hit(ui_root, center, element, 8)


## 内部：按 uid 找存活敌人视图节点（EnemyView 是 Node2D）
## [V2-FIX] 改用 uid 直接匹配，避免 queue_free 延迟导致 alive_idx 与 enemy_nodes 错位
static func _get_alive_panel(enemy_container: Node, enemies: Array[EnemyInstance], uid: String) -> Node:
	if enemy_container == null or uid == "":
		return null
	for child: Node in enemy_container.get_children():
		# 跳过 Slot0/1/2 等场景固有 Marker2D
		if child is Marker2D:
			continue
		# 通过 EnemyView.get_enemy_uid() 精确匹配，不依赖索引对应
		if child.has_method("get_enemy_uid") and child.get_enemy_uid() == uid:
			# 顺便校验该敌人未被标记死亡（hp > -9999）
			for e: EnemyInstance in enemies:
				if e.uid == uid:
					if e.hp <= -9999:
						return null
					return child
			return child
	return null


## 闪白效果：EnemyView (Node2D) 走 modulate tween；PanelContainer (Control) 走 VFX.hit_flash
static func _flash_node(node: Node) -> void:
	if node is Control:
		VFX.hit_flash(node as Control)
		return
	if node.has_method("get_enemy_instance"):
		# EnemyView：闪白作用于 VisualRoot 的 modulate
		var visual: Node = node.get_node_or_null("VisualRoot")
		var target: CanvasItem = visual as CanvasItem
		if target == null and node is CanvasItem:
			target = node as CanvasItem
		if target != null:
			var tw := target.create_tween()
			tw.tween_property(target, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
			tw.tween_property(target, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


## 获取节点中心坐标：EnemyView 用 get_global_center()；Control 用 position + size * 0.5
static func _node_center(node: Node) -> Vector2:
	if node.has_method("get_global_center"):
		return node.get_global_center()
	if node is Control:
		var c := node as Control
		return c.position + c.size * 0.5
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO
