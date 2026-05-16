## 效果触发过滤器
## 职责：根据当前触发时机，从效果列表中筛选出应该执行的效果
## 同时处理 EffectScope 的生命周期管理（标记已触发/清除过期效果）

class_name EffectTriggerFilter
extends RefCounted


## 从效果列表中筛选出匹配当前触发时机的效果
static func filter_by_trigger(
	effects: Array[Dictionary],
	trigger: EffectTypes.TriggerType
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect: Dictionary in effects:
		if effect.get("trigger", -1) == trigger:
			result.append(effect)
	return result


## 从多个来源（骰子+遗物+牌型）收集指定触发时机的所有效果
## sources: Array[Dictionary] 每个元素 = {effects: Array[Dictionary], source: EffectSource, source_id: str}
static func collect_effects_for_trigger(
	sources: Array[Dictionary],
	trigger: EffectTypes.TriggerType
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for src: Dictionary in sources:
		var effects: Array = src.get("effects", [])
		for effect: Dictionary in effects:
			if effect.get("trigger", -1) == trigger:
				# 附加来源信息到效果副本
				var effect_copy: Dictionary = effect.duplicate()
				effect_copy["_source"] = src.get("source", EffectTypes.EffectSource.DICE_ON_PLAY)
				effect_copy["_source_id"] = src.get("source_id", "")
				result.append(effect_copy)
	return result


## 检查条件效果是否满足触发条件
## 某些效果有 condition 参数（如 GRANT_PLAY 的 condition: "combo"）
static func check_condition(effect: Dictionary, ctx: EffectEngine.ExecuteContext) -> bool:
	var params: Dictionary = effect.get("params", {})
	var condition: String = params.get("condition", "")

	if condition == "":
		return true  # 无条件，直接通过

	match condition:
		"combo":
			return ctx.player_combo >= 2
		"third_play":
			return ctx.player_combo >= 3
		"hit":
			return ctx.was_hit_last_turn
		"solo":
			# 单挑：场上存活敌人仅剩 1 个
			var alive_count: int = 0
			for e: EnemyInstance in ctx.enemies:
				if is_instance_valid(e) and e.hp > 0:
					alive_count += 1
			return alive_count <= 1
		"low_hp":
			return ctx.player_hp <= int(ctx.player_max_hp * 0.3)
		"keep":
			return ctx.kept_turns > 0
		_:
			push_warning("[EffectTriggerFilter] 未知条件: %s" % condition)
			return true


## 过滤 + 条件检查的组合方法
static func get_executable_effects(
	effects: Array[Dictionary],
	trigger: EffectTypes.TriggerType,
	ctx: EffectEngine.ExecuteContext
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect: Dictionary in effects:
		if effect.get("trigger", -1) != trigger:
			continue
		if not check_condition(effect, ctx):
			continue
		result.append(effect)
	return result
