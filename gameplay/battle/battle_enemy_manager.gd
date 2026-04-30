# battle_enemy_manager.gd — 敌人管理 + 胜负判定
# 从 BattleController 拆出，负责敌人视图操作、目标选择、死亡/DoT 结算
# 注：enemy_views 类型为 Array[Node]，容纳 Node2D（EnemyView）的鸭子类型接口
class_name BattleEnemyManager

## 获取存活敌人视图列表
static func get_living_enemies(enemy_views: Array[Node]) -> Array[Node]:
	var living: Array[Node] = []
	for view: Node in enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("is_alive") and view.is_alive():
			living.append(view)
	return living

## 收集所有 EnemyInstance
static func collect_enemy_instances(enemy_views: Array[Node]) -> Array[EnemyInstance]:
	var instances: Array[EnemyInstance] = []
	for view: Node in enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("get_enemy_instance"):
			var inst: EnemyInstance = view.get_enemy_instance()
			if inst:
				instances.append(inst)
	return instances

## 清空敌人容器
static func clear_enemy_views(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		# 跳过 Marker2D 站位点（Slot0/1/2），它们是场景固有锚点
		if child is Marker2D:
			continue
		child.queue_free()

## 判断某 uid 敌人是否存活
static func is_enemy_alive(enemy_views: Array[Node], uid: String) -> bool:
	for e: EnemyInstance in collect_enemy_instances(enemy_views):
		if e.uid == uid and e.hp > 0:
			return true
	return false

## 获取目标敌人视图（嘲讽 > 玩家选中 > 第一个存活）
static func get_target_enemy(enemy_views: Array[Node]) -> Node:
	# 1) 嘲讽期间强制打嘲讽目标
	if GameManager.taunt_enemy_uid != "":
		for view: Node in enemy_views:
			if not is_instance_valid(view):
				continue
			if view.has_method("get_enemy_instance"):
				var inst: EnemyInstance = view.get_enemy_instance()
				if inst and inst.uid == GameManager.taunt_enemy_uid and inst.hp > 0:
					return view
	# 2) 优先玩家选中的敌人
	for view: Node in enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("is_selected") and view.is_selected() and view.has_method("is_alive") and view.is_alive():
			return view
	# 3) 第一个存活
	for view: Node in enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("is_alive") and view.is_alive():
			return view
	return null

## 清理 enemy_views 中已被释放的无效引用（queue_free 后引用仍残留）
## 应在每次 refresh / check_battle_over 前调用
static func purge_invalid_views(enemy_views: Array[Node]) -> void:
	var i: int = enemy_views.size() - 1
	while i >= 0:
		if not is_instance_valid(enemy_views[i]):
			enemy_views.remove_at(i)
		i -= 1

## 刷新所有敌人视图 UI
static func refresh_enemy_views(enemy_views: Array[Node]) -> void:
	purge_invalid_views(enemy_views)
	for view: Node in enemy_views:
		if view.has_method("refresh"):
			view.refresh()

## 结算敌方 DoT（灼烧 + 中毒）
static func settle_enemy_dots(enemy_views: Array[Node]) -> void:
	var instances: Array[EnemyInstance] = collect_enemy_instances(enemy_views)
	BattleHelpers.settle_enemy_dot_damage(instances)
	refresh_enemy_views(enemy_views)

## 检查战斗是否结束（死亡结算 + 全灭判定）
## 返回 true 表示战斗已结束（全灭）
static func check_battle_over(enemy_views: Array[Node], on_victory: Callable) -> bool:
	purge_invalid_views(enemy_views)
	var instances: Array[EnemyInstance] = collect_enemy_instances(enemy_views)
	var settled: Array[String] = BattleHelpers.settle_enemy_deaths(instances)
	if not settled.is_empty():
		refresh_enemy_views(enemy_views)
	var living: Array[Node] = get_living_enemies(enemy_views)
	if living.is_empty():
		on_victory.call()
		return true
	return false
