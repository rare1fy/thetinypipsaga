## 骰子特效应用器 — 将 DiceEffectResolver 的结算结果应用到战斗状态
## 职责：把纯函数结算结果转化为实际的 HP/护甲/状态变更
## 设计原则：所有副作用集中于此，Resolver 本身保持纯函数

class_name DiceEffectApplier
extends RefCounted


## 应用骰子特效结果：自伤、治疗、护甲、穿透、AOE、状态效果
## 参数：
##   effect_result: DiceEffectResolver.ResolveResult
##   enemy_views: 敌人视图数组（Array[Node]，容纳 EnemyView(Node2D) 的鸭子类型接口）
##   status_bar_refresh_cb: 刷新状态栏的回调（Callable）
##   dice_in_hand: 当前手牌骰子定义列表（用于吞噬/交换等操作）
##   hp_bar: 玩家血条（用于自伤时的脉冲 VFX，可选）
static func apply(
	effect_result: DiceEffectResolver.ResolveResult,
	enemy_views: Array[Node],
	status_bar_refresh_cb: Callable,
	dice_in_hand: Array[DiceDef] = [],
	hp_bar: Control = null
) -> void:
	# 自伤
	if effect_result.self_damage > 0 or effect_result.self_damage_percent > 0.0:
		var self_dmg: int = effect_result.self_damage
		if effect_result.self_damage_percent > 0.0:
			self_dmg += int(float(PlayerState.max_hp) * effect_result.self_damage_percent)
		if self_dmg > 0:
			PlayerState.take_damage(self_dmg)
			if hp_bar != null:
				VFX.hp_pulse(hp_bar, true)
			effect_result.descriptions.insert(0, "自伤 %d HP" % self_dmg)

	# 治疗
	if effect_result.heal > 0:
		PlayerState.heal(effect_result.heal)
		effect_result.descriptions.append("回复 %d HP" % effect_result.heal)

	# 护甲
	if effect_result.armor > 0:
		PlayerState.gain_armor(effect_result.armor)
		effect_result.descriptions.append("获得 %d 护甲" % effect_result.armor)

	# Reroll
	if effect_result.reroll > 0:
		GameManager.free_rerolls_left += effect_result.reroll
		effect_result.descriptions.append("+%d 重投" % effect_result.reroll)

	# 状态效果
	if not effect_result.apply_statuses.is_empty():
		for status: Dictionary in effect_result.apply_statuses:
			var st_type: int = status.get("type", 0)
			var st_value: int = status.get("value", 0)
			var st_duration: int = status.get("duration", 1)
			var target_tag: String = status.get("target", "enemy")
			var target_uid: String = status.get("target_uid", "")

			if target_tag == "self" or target_uid.is_empty():
				# 给自己 — 用 PlayerState 封装方法
				PlayerState.add_status(st_type, st_value, st_duration)
			elif not target_uid.is_empty():
				# 给指定 UID 的敌人 — 直接操作 statuses 数组
				var target_inst: EnemyInstance = _find_enemy_by_uid(target_uid, enemy_views)
				if target_inst:
					StatusService.add(target_inst.statuses, st_type, st_value, st_duration)
			else:
				# 给目标敌人（由 battle_controller 在调用前设置好 target）
				pass
		effect_result.descriptions.append("施加 %d 个状态效果" % effect_result.apply_statuses.size())

	# 吞噬骰子：从手牌中移除一张未选中骰子
	if effect_result.devour_die:
		var devoured := false
		for i: int in range(DiceBag.hand_dice.size()):
			var die_dict: Dictionary = DiceBag.hand_dice[i]
			if not die_dict.get("selected", false):
				DiceBag.hand_dice.remove_at(i)
				devoured = true
				break
		if devoured:
			effect_result.descriptions.append("吞噬了一张骰子")
		else:
			effect_result.descriptions.append("吞噬失败（无可用骰子）")

	# 额外出牌次数
	if effect_result.extra_plays > 0:
		GameManager.plays_left += effect_result.extra_plays
		effect_result.descriptions.append("额外出牌 +%d" % effect_result.extra_plays)

	# 临时骰子：直接加入手牌
	if not effect_result.temp_dice.is_empty():
		for dice_id: String in effect_result.temp_dice:
			var def: DiceDef = GameData.get_dice_def(dice_id)
			if def == null:
				continue
			var value: int = DiceBagService.roll_dice_def(def)
			DiceBag.hand_dice.append({
				"id": randi(), "defId": dice_id, "value": value,
				"element": GameTypes.DiceElement.keys()[def.element].to_lower(),
				"selected": false, "rolling": false,
				"kept": false, "isShadowRemnant": false, "isTemp": true,
				"shadowRemnantPersistent": false, "keptBonusAccum": 0,
			})
		effect_result.descriptions.append("获得 %d 张临时骰子" % effect_result.temp_dice.size())

	# 与未选中骰子交换：将选中骰子的点数替换为未选中骰子中最大的点数
	if effect_result.swap_with_unselected:
		var max_unselected_value := 0
		for die_dict: Dictionary in DiceBag.hand_dice:
			if not die_dict.get("selected", false):
				var v: int = int(die_dict.get("value", 0))
				if v > max_unselected_value:
					max_unselected_value = v
		if max_unselected_value > 0:
			for die_dict: Dictionary in DiceBag.hand_dice:
				if die_dict.get("selected", false):
					die_dict["value"] = max_unselected_value
					break
			# resolver 中已添加描述，此处追加交换结果
			effect_result.descriptions.append("交换结果 → %d" % max_unselected_value)
		else:
			effect_result.descriptions.append("交换失败（无可用骰子）")

	# 统一元素：将手牌所有元素骰子坍缩为同一随机元素
	if effect_result.unify_element:
		var elements := ["fire", "ice", "thunder", "poison", "holy"]
		var chosen: String = elements[randi() % elements.size()]
		for die_dict: Dictionary in DiceBag.hand_dice:
			var elem: String = die_dict.get("collapsedElement", die_dict.get("element", "normal"))
			if elem != "normal":
				die_dict["collapsedElement"] = chosen
		effect_result.descriptions.append("统一元素 → %s" % chosen)

	# 复制多数元素：将本骰子元素设为手牌中数量最多的元素
	if effect_result.copy_majority_element:
		var element_counts: Dictionary = {}
		for die_dict: Dictionary in DiceBag.hand_dice:
			var elem: String = die_dict.get("collapsedElement", die_dict.get("element", "normal"))
			if elem != "normal":
				element_counts[elem] = element_counts.get(elem, 0) + 1
		var majority: String = ""
		var max_count: int = 0
		for elem: String in element_counts:
			if int(element_counts[elem]) > max_count:
				max_count = int(element_counts[elem])
				majority = elem
		if majority != "":
			for die_dict: Dictionary in DiceBag.hand_dice:
				if die_dict.get("selected", false):
					die_dict["collapsedElement"] = majority
					break
			effect_result.descriptions.append("复制多数元素 → %s" % majority)
		else:
			effect_result.descriptions.append("复制多数元素（无元素骰子）")

	# 护甲转伤害：将目标敌人护甲转为额外伤害
	if effect_result.armor_to_damage:
		var target_uid: String = ""
		for status: Dictionary in effect_result.apply_statuses:
			if status.get("target", "") != "self" and status.get("target_uid", "") != "":
				target_uid = status["target_uid"]
				break
		if target_uid.is_empty() and enemy_views.size() > 0:
			var first_view: Node = enemy_views[0]
			if is_instance_valid(first_view) and first_view.has_method("get_enemy_instance"):
				var inst: EnemyInstance = first_view.get_enemy_instance()
				if inst and inst.armor > 0:
					effect_result.bonus_damage += inst.armor
					inst.armor = 0
					effect_result.descriptions.append("护甲转伤害 +%d" % effect_result.bonus_damage)

	# 自我复制：将当前骰子复制一份加入手牌
	if effect_result.clone_self:
		for die_dict: Dictionary in DiceBag.hand_dice:
			if die_dict.get("selected", false):
				var clone: Dictionary = die_dict.duplicate(true)
				clone["selected"] = false
				clone.erase("uid")
				DiceBag.hand_dice.append(clone)
				effect_result.descriptions.append("复制自身到手牌")
				break

	# 刷新状态栏
	if status_bar_refresh_cb.is_valid():
		status_bar_refresh_cb.call()


## 获取选中骰子的 DiceDef（取第一个选中骰子的定义）
static func get_dice_def_for_selected(selected_dice: Array[Dictionary]) -> DiceDef:
	if selected_dice.is_empty():
		return null
	var def_id: String = selected_dice[0].get("defId", "")
	if def_id.is_empty():
		return null
	return GameData.get_dice_def(def_id)


## 获取目标敌人的 EnemyInstance
static func get_target_enemy_instance(target_view: Node) -> EnemyInstance:
	if not target_view:
		return null
	if target_view.has_method("get_enemy_instance"):
		return target_view.get_enemy_instance()
	return null


## 按 UID 查找敌人实例
static func _find_enemy_by_uid(uid: String, enemy_views: Array[Node]) -> EnemyInstance:
	for view: Node in enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("get_enemy_instance"):
			var inst: EnemyInstance = view.get_enemy_instance()
			if inst and inst.uid == uid:
				return inst
	return null
