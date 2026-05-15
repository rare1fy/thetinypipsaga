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
			PlayerState.take_damage(self_dmg, "self")
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
	if effect_result.extra_rerolls > 0:
		GameManager.free_rerolls_left += effect_result.extra_rerolls
		effect_result.descriptions.append("+%d 重投" % effect_result.extra_rerolls)

	# 状态效果（新格式：{status: str, value: int, target: str}）
	if not effect_result.apply_statuses.is_empty():
		for status: Dictionary in effect_result.apply_statuses:
			var st_name: String = status.get("status", "")
			var st_value: int = status.get("value", 0)
			var target_tag: String = status.get("target", "enemy")

			# 将状态名映射为 GameTypes.StatusType
			var st_type: int = _status_name_to_type(st_name)
			if st_type < 0:
				continue

			if target_tag == "self":
				PlayerState.add_status(st_type, st_value, 3)
			else:
				# 给目标敌人
				var target_inst: EnemyInstance = _get_target_from_views(enemy_views)
				if target_inst:
					StatusService.add(target_inst.statuses, st_type, st_value, 3)
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

	# 护甲转伤害：由 ARMOR_BREAK + TRUE_DAMAGE 效果组合替代
	if effect_result.is_armor_break:
		var target_inst: EnemyInstance = _get_target_from_views(enemy_views)
		if target_inst and target_inst.armor > 0:
			effect_result.bonus_damage += target_inst.armor
			target_inst.armor = 0
			effect_result.descriptions.append("摧毁护甲 → +%d 伤害" % effect_result.bonus_damage)

	# 处决：目标HP低于阈值时直接击杀
	if effect_result.execute_threshold > 0.0:
		var target_inst2: EnemyInstance = _get_target_from_views(enemy_views)
		if target_inst2:
			var hp_ratio: float = float(target_inst2.hp) / float(target_inst2.max_hp)
			if hp_ratio <= effect_result.execute_threshold:
				target_inst2.hp = 0
				effect_result.descriptions.append("处决成功！")

	# 引爆：消耗目标状态层数造成伤害
	if effect_result.detonate_status != "":
		var target_inst3: EnemyInstance = _get_target_from_views(enemy_views)
		if target_inst3:
			var st_type: int = _status_name_to_type(effect_result.detonate_status)
			if st_type >= 0:
				var stacks: int = target_inst3.get_status_stacks(effect_result.detonate_status) if target_inst3.has_method("get_status_stacks") else 0
				if stacks > 0:
					var det_dmg: int = stacks * effect_result.detonate_damage_per_stack
					target_inst3.hp -= det_dmg
					effect_result.descriptions.append("引爆 %s %d层 → %d 伤害" % [effect_result.detonate_status, stacks, det_dmg])

	# 伤害护盾：给玩家添加伤害护盾
	if effect_result.damage_shield_value > 0:
		if "damage_shield" in PlayerState:
			PlayerState.damage_shield = effect_result.damage_shield_value
			PlayerState.damage_shield_duration = effect_result.damage_shield_duration
		effect_result.descriptions.append("获得 %d 伤害护盾（%d回合）" % [effect_result.damage_shield_value, effect_result.damage_shield_duration])

	# 控制效果：通过 ControlSystem 应用
	if not effect_result.controls.is_empty():
		for ctrl: Dictionary in effect_result.controls:
			var ctrl_type_str: String = ctrl.get("control", "")
			var duration: int = ctrl.get("duration", 0)
			var distance: int = ctrl.get("distance", 0)
			var target_tag: String = ctrl.get("target", "main")
			var ctrl_enum: int = _control_name_to_type(ctrl_type_str)
			if ctrl_enum < 0:
				continue
			if target_tag == "main":
				var target_inst4: EnemyInstance = _get_target_from_views(enemy_views)
				if target_inst4:
					ControlSystem.apply_control(target_inst4, ctrl_enum, maxi(duration, distance))
			elif target_tag == "all":
				for view: Node in enemy_views:
					if not is_instance_valid(view):
						continue
					var inst: EnemyInstance = get_target_enemy_instance(view)
					if inst and inst.hp > 0:
						ControlSystem.apply_control(inst, ctrl_enum, maxi(duration, distance))

	# 金币
	if effect_result.gold_gain > 0:
		if PlayerState.has_method("add_gold"):
			PlayerState.add_gold(effect_result.gold_gain)
		effect_result.descriptions.append("+%d 金币" % effect_result.gold_gain)

	# 屏障
	if effect_result.barrier > 0:
		if PlayerState.has_method("gain_barrier"):
			PlayerState.gain_barrier(effect_result.barrier)
		else:
			# 降级为护甲
			PlayerState.gain_armor(effect_result.barrier)
		effect_result.descriptions.append("获得 %d 屏障" % effect_result.barrier)

	# 规则改变：抽牌数/手牌上限/全骰点数加成
	if effect_result.draw_count_delta != 0:
		PlayerState.temp_draw_count_bonus += effect_result.draw_count_delta
	if effect_result.hand_limit_delta != 0:
		if "hand_limit_bonus" in GameManager:
			GameManager.hand_limit_bonus += effect_result.hand_limit_delta
	if effect_result.all_dice_points_plus > 0:
		if "all_dice_points_bonus" in GameManager:
			GameManager.all_dice_points_bonus += effect_result.all_dice_points_plus

	# 免死
	if effect_result.death_immunity_cooldown > 0:
		if "death_immunity" in PlayerState:
			PlayerState.death_immunity = true
			PlayerState.death_immunity_cooldown = effect_result.death_immunity_cooldown

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


## 从 enemy_views 获取当前目标敌人
static func _get_target_from_views(enemy_views: Array[Node]) -> EnemyInstance:
	for view: Node in enemy_views:
		if not is_instance_valid(view):
			continue
		if view.has_method("get_enemy_instance"):
			var inst: EnemyInstance = view.get_enemy_instance()
			if inst and inst.hp > 0:
				return inst
	return null


## 状态名字符串 → GameTypes.StatusType 映射
static func _status_name_to_type(name: String) -> int:
	match name:
		"poison":
			return GameTypes.StatusType.POISON
		"burn":
			return GameTypes.StatusType.BURN
		"vulnerable":
			return GameTypes.StatusType.VULNERABLE
		"weak":
			return GameTypes.StatusType.WEAK
		"freeze":
			return GameTypes.StatusType.FREEZE
		"slow":
			return GameTypes.StatusType.SLOW
		"strength":
			return GameTypes.StatusType.STRENGTH if "STRENGTH" in GameTypes.StatusType else -1
		"dodge":
			return GameTypes.StatusType.DODGE if "DODGE" in GameTypes.StatusType else -1
		"armor":
			return GameTypes.StatusType.ARMOR if "ARMOR" in GameTypes.StatusType else -1
		_:
			push_warning("[DiceEffectApplier] 未知状态名: %s" % name)
			return -1


## 控制类型字符串 → ControlSystem.ControlType 映射
static func _control_name_to_type(name: String) -> int:
	match name:
		"taunt":
			return ControlSystem.ControlType.TAUNT
		"stun":
			return ControlSystem.ControlType.STUN
		"knockback":
			return ControlSystem.ControlType.KNOCKBACK
		"polymorph":
			return ControlSystem.ControlType.POLYMORPH
		"blind":
			return ControlSystem.ControlType.BLIND
		"disarm":
			return ControlSystem.ControlType.DISARM
		_:
			push_warning("[DiceEffectApplier] 未知控制类型: %s" % name)
			return -1
