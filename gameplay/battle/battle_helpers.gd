## 战斗工具 helpers — 从 battle_scene.gd 抽出
## 辅助函数，部分方法有 GameManager 全局副作用（heal / add_gold / stats），调用方须知

class_name BattleHelpers

const HandTypeEffects := preload("res://data/hand_type_effects.gd")


## 优先嘲讽目标 → 否则第一个存活敌人
static func pick_target(enemies: Array[EnemyInstance], target_uid: String) -> EnemyInstance:
	if target_uid != "":
		for e: EnemyInstance in enemies:
			if e.uid == target_uid and e.hp > 0:
				return e
	for e: EnemyInstance in enemies:
		if e.hp > 0:
			return e
	return null


## 应用元素效果（火/冰/雷/毒/圣），直接修改 enemies & GameManager 状态
static func apply_element_effects(enemy: EnemyInstance, selected_dice: Array[Dictionary], enemies: Array[EnemyInstance]) -> void:
	for d: Dictionary in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		match elem:
			"fire":
				enemy.armor = 0
				var burn_val := maxi(1, int(d.value * 0.5))
				var s := StatusEffect.new()
				s.type = GameTypes.StatusType.BURN
				s.value = burn_val
				s.duration = 3
				enemy.statuses.append(s)
			"wind":
				# v0.5 风元素：击退 + 2点基础伤害
				if enemy.distance < 3:
					enemy.distance = mini(3, enemy.distance + 1)
				enemy.hp = maxi(0, enemy.hp - 2)
			"thunder":
				for other: EnemyInstance in enemies:
					if other.uid != enemy.uid and other.hp > 0:
						other.hp = maxi(0, other.hp - int(d.value))
			"poison":
				var s := StatusEffect.new()
				s.type = GameTypes.StatusType.POISON
				s.value = int(d.value)
				s.duration = 3
				enemy.statuses.append(s)
			"holy":
				GameManager.heal(int(d.value))


## 扫描死亡敌人发放奖励，返回被结算的 uid 列表（供 UI 清理）
## P2: 死亡前先检查复活/分裂，满足条件则不走死亡流程
## new_enemies_out: 输出参数，分裂产生的新敌人实例（调用方负责生成视图）
static func settle_enemy_deaths(enemies: Array[EnemyInstance], new_enemies_out: Array[EnemyInstance] = []) -> Array[String]:
	var settled: Array[String] = []
	for e: EnemyInstance in enemies:
		if e.hp <= 0 and e.hp > -9999:
			# P2: 复活/分裂检查
			var revive_result: EnemySummonRevive.ReviveResult = EnemySummonRevive.try_revive(e)
			if revive_result.revived_self != null:
				# 直接复活：不走死亡流程
				BattleLog.log_enemy(revive_result.log)
				VFX.show_toast(revive_result.log, "warning")
				SoundPlayer.play_sound("heal")
				continue
			if revive_result.splits.size() > 0:
				# 分裂：本体死亡，产生新敌人
				BattleLog.log_enemy(revive_result.log)
				VFX.show_toast(revive_result.log, "warning")
				SoundPlayer.play_sound("enemy_skill")
				for split: EnemyInstance in revive_result.splits:
					new_enemies_out.append(split)
				# 本体仍然走死亡流程
				GameManager.add_gold(e.drop_gold)
				GameManager.stats.enemiesKilled += 1
				e.hp = -9999
				settled.append(e.uid)
				continue
			# 正常死亡
			GameManager.add_gold(e.drop_gold)
			GameManager.stats.enemiesKilled += 1
			# 魂晶产出：溢出伤害 × 深度倍率 × 转化率
			var overkill: int = absi(e.hp)
			var capped_overkill: int = mini(overkill, e.max_hp)
			if capped_overkill > 0:
				var depth_mult: float = GameBalance.get_soul_crystal_mult(GameManager.current_node, 1.0) + XpSystem.level_soul_bonus
				var soul_gain: int = maxi(1, ceili(capped_overkill * depth_mult * GameBalance.SOUL_CRYSTAL_CONFIG.conversionRate))
				GameManager.souls += soul_gain
				BattleLog.log_write("💎 +%d 魂晶 (溢出%d × %.0f%%倍率)" % [soul_gain, capped_overkill, depth_mult * 100])
				VFX.show_toast("+%d 魂晶" % soul_gain, "buff")
			e.hp = -9999
			settled.append(e.uid)
	# P2 Trait: Berserker vengeance — 队友死亡时存活的 berserker +1 层
	if not settled.is_empty():
		for e: EnemyInstance in enemies:
			if e.hp > 0 and not e.uid in settled:
				EnemyTraits.apply_vengeance_on_ally_death(e)
	return settled


## 构造盗贼暗影残骰（append 到 GameManager.hand_dice 的 Dictionary）
static func make_shadow_remnant() -> Dictionary:
	return {
		"id": randi(), "defId": "temp_rogue", "value": randi_range(1, 3),
			"element": "normal", "selected": false, "rolling": false,
		"isShadowRemnant": true, "isTemp": true, "shadowRemnantPersistent": false,
		"kept": false, "keptBonusAccum": 0,
	}


## 出牌后的骰子特效（分裂、影分身）：返回要追加进 hand_dice 的新骰子列表
static func compute_dice_on_play_extras(selected_dice: Array[Dictionary]) -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	for d: Dictionary in selected_dice:
		var def: DiceDef = GameData.get_dice_def(d.defId)
		if _has_shadow_clone_effect(def):
			var clone: Dictionary = d.duplicate()
			clone.id = randi()
			clone.spent = true
			clone["isShadowRemnant"] = true
			extras.append(clone)
	return extras


## 检查骰子是否有影分身效果（通过 effects 数组判断）
static func _has_shadow_clone_effect(def: DiceDef) -> bool:
	for eff: Dictionary in def.effects:
		if eff.get("type", -1) == EffectTypes.EffectType.GRANT_PLAY:
			return true
	return false


## AOE 检测（雷元素 或 顺子 / 多条 / 元素系顺子牌型）
## 演出 Phase4 震屏强度 + UI AOE 标识共用
## §6.8 对齐：AOE 判定从 HandTypeEffects 配置表读取
static func detect_aoe(selected_dice: Array[Dictionary], hand_result: Dictionary) -> bool:
	# 雷元素骰子自带 AOE
	for d: Dictionary in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		if elem == "thunder":
			return true
	# 牌型 AOE 从配置表判定
	var active: Array[String] = []
	active.assign(hand_result.get("activeHands", []))
	return HandTypeEffects.has_aoe_in_active(active)


## 主导元素 — 取本次出牌中出现次数最多的非 normal 元素，用于受击粒子配色
## 全 normal 返回 "physical"；平局时按 ELEMENT_PRIORITY 打破平局，保证同组牌输出同一粒子色
static func dominant_element(selected_dice: Array[Dictionary]) -> String:
	var counts: Dictionary = {}
	for d: Dictionary in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		if elem == "normal" or elem == "":
			continue
		counts[elem] = counts.get(elem, 0) + 1
	if counts.is_empty():
		return "physical"
	# 平局打破：火>雷>冰>毒>圣
	var priority := ["fire", "thunder", "wind", "poison", "holy"]
	var best := ""
	var best_count := 0
	var best_rank := 999
	for k: String in counts.keys():
		var rank: int = priority.find(k) if k in priority else 500
		if counts[k] > best_count or (counts[k] == best_count and rank < best_rank):
			best = k
			best_count = counts[k]
			best_rank = rank
	return best


## 敌方 DoT 预结算（灼烧/中毒扣血 + 过期清理 + v0.5 易伤层数衰减），供 controller 和 enemy_ai 共用
static func settle_enemy_dot_damage(enemies: Array[EnemyInstance]) -> void:
	for e: EnemyInstance in enemies:
		if e.hp <= 0:
			continue
		for s: StatusEffect in e.statuses:
			if s.type == GameTypes.StatusType.BURN and s.value > 0:
				e.hp = maxi(0, e.hp - s.value)
				s.value = 0
				s.duration = 0  # 同步清零，避免僵尸状态残留
			elif s.type == GameTypes.StatusType.POISON and s.value > 0:
				e.hp = maxi(0, e.hp - s.value)
				s.duration -= 1
		# 易伤层数衰减：每敌方回合结束 -1 层
		StatusService.tick_vulnerable(e.statuses)
		# 清理到期状态（不含易伤/法脉紊乱，走层数衰减）
		e.statuses = e.statuses.filter(func(s: StatusEffect) -> bool:
			if s.type == GameTypes.StatusType.VULNERABLE \
				or s.type == GameTypes.StatusType.ARCANE_DISRUPTION:
				return s.value > 0
			return s.duration > 0
		)
