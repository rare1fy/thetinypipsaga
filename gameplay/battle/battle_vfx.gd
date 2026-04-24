## 战斗 VFX 分派器 — 从 battle_scene.gd 抽出的受击 / 死亡 / 状态视觉效果
## 纯 static，调用方传入所需上下文（面板、enemies、ui_root、selected_dice）
## 2026-04-24 拆分缘由：battle_scene.gd 突破 600 行硬上限，按 RULES B1 强制下沉

class_name BattleVfx


## 敌人受击 VFX（信号响应版，敌方回合反打 / 爆发伤害触发）
## 不带元素粒子，只做闪白 + 震屏
static func on_enemy_damaged_signal(enemy_container: Node, enemies: Array[EnemyInstance], enemy_uid: String, damage: int, scene_root: Node) -> void:
	var panel := _get_alive_panel(enemy_container, enemies, enemy_uid)
	if panel == null:
		return
	VFX.hit_flash(panel)
	if damage >= 30:
		VFX.shake_heavy(scene_root, 10.0, 0.4)
		SoundPlayer.play_heavy_impact(1.0)
	else:
		VFX.shake(scene_root, 5.0, 0.15)


## 敌人死亡粒子
static func on_enemy_died(enemy_container: Node, enemies: Array[EnemyInstance], ui_root: Node, enemy_uid: String) -> void:
	var panel := _get_alive_panel(enemy_container, enemies, enemy_uid)
	if panel == null:
		return
	var center := panel.position + panel.size * 0.5
	var burst_colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW]
	VFX.pixel_burst(ui_root, center, 12, burst_colors)


## 玩家出牌命中 VFX（真伤输出主路径）
## 根据 selected_dice 计算主导元素，决定粒子颜色；damage >= 30 触发重击震屏
static func on_player_hit(enemy_container: Node, enemies: Array[EnemyInstance], ui_root: Node, scene_root: Node, enemy_uid: String, damage: int, selected_dice: Array) -> void:
	var panel := _get_alive_panel(enemy_container, enemies, enemy_uid)
	if panel == null:
		return
	VFX.hit_flash(panel)
	var element := BattleHelpers.dominant_element(selected_dice)
	var center := panel.position + panel.size * 0.5
	if damage >= 30:
		VFX.shake_heavy(scene_root, 8.0, 0.3)
		SoundPlayer.play_heavy_impact(minf(2.0, damage / 30.0))
		VFX.spawn_element_hit(ui_root, center, element, 14)
	else:
		VFX.shake(scene_root, 4.0, 0.15)
		VFX.spawn_element_hit(ui_root, center, element, 8)


## 给敌人面板挂毒 / 灼烧循环特效，返回新追加的 Tween 列表（调用方 append）
static func apply_status_tweens(panel: Control, enemy: EnemyInstance, ui_root: Node) -> Array[Tween]:
	var result: Array[Tween] = []
	for s in enemy.statuses:
		var tw: Tween = null
		match s.type:
			GameTypes.StatusType.POISON:
				tw = VFX.poison_pulse(panel)
				VFX.poison_drip(ui_root, panel.position + panel.size * 0.5, 3)
			GameTypes.StatusType.BURN:
				tw = VFX.burn_edge(panel)
		if tw:
			result.append(tw)
	return result


## 内部：按 uid 找存活敌人的面板
static func _get_alive_panel(enemy_container: Node, enemies: Array[EnemyInstance], uid: String) -> Control:
	var alive_idx := 0
	for e in enemies:
		if e.hp <= -9999:
			continue
		if e.uid == uid:
			return enemy_container.get_child(alive_idx) as Control
		alive_idx += 1
	return null
