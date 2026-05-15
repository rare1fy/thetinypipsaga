## 工具脚本：将 EnemyConfig 硬编码数据导出为 enemy.json
## 用法：在 Godot 编辑器中 File > Run Script 执行本脚本
## 或通过命令行：godot --headless --script res://config/tools/export_enemy_json.gd --quit
@tool
extends SceneTree

func _init() -> void:
	# 强制走硬编码构建（忽略 USE_JSON_CONFIG 开关）
	var all_configs: Dictionary = {}
	# 直接调用 _build_all_configs 的逻辑
	# 由于 _build_all_configs 是 static 且写入 _all_configs，我们先触发它
	# EnemyConfig._static_init() 已经在 class 加载时执行了
	# 但如果 USE_JSON_CONFIG=true 且 JSON 存在，会走 JSON 加载
	# 所以我们手动调用 _build_all_configs
	EnemyConfig._all_configs.clear()
	EnemyConfig._build_all_configs()
	all_configs = EnemyConfig._all_configs

	var base_arr: Array = []
	var phases_arr: Array = []
	var actions_arr: Array = []
	var quotes_arr: Array = []

	var enemy_idx: int = 0
	for key in all_configs:
		enemy_idx += 1
		var cfg: EnemyConfig = all_configs[key]

		# 生成 ID 编号
		var id_str: String = "E%04d" % enemy_idx
		var pg_str: String = "PG%04d" % enemy_idx
		var qg_str: String = "QG%04d" % enemy_idx

		# base 表
		var base_entry: Dictionary = {
			"id": id_str,
			"legacy_key": cfg.id,
			"art_id": cfg.art_id,
			"name": cfg.name,
			"chapter": cfg.chapter,
			"category": _category_str(cfg.category),
			"combat_type": _combat_type_str(cfg.combat_type),
			"base_hp": cfg.base_hp,
			"base_dmg": cfg.base_dmg,
			"drop_gold": cfg.drop_gold,
			"drop_relic": cfg.drop_relic,
			"drop_reroll_reward": cfg.drop_reroll_reward,
			"phase_group": pg_str,
			"quote_group": qg_str,
		}

		# Boss 专属字段
		if cfg.category == EnemyConfig.EnemyCategory.BOSS:
			base_entry["boss_rank"] = _boss_rank_str(cfg.boss_rank)
		else:
			base_entry["boss_rank"] = "NONE"

		# 召唤机制
		if cfg.summons != null:
			base_entry["summons"] = {
				"minion_id": cfg.summons.minion_id,
				"interval": cfg.summons.interval,
				"count": cfg.summons.count,
				"max_total": cfg.summons.max_total,
				"wave_cap": cfg.summons.wave_cap,
				"hp_threshold": cfg.summons.hp_threshold,
			}

		# 复活/分裂机制
		if cfg.revive != null:
			base_entry["revive"] = {
				"revive_hp_ratio": cfg.revive.revive_hp_ratio,
				"split_into": cfg.revive.split_into,
				"split_minion_id": cfg.revive.split_minion_id,
			}

		base_arr.append(base_entry)

		# phases + actions 表
		if cfg.phases != null:
			for phase_idx in cfg.phases.size():
				var phase: EnemyConfig.EnemyPhase = cfg.phases[phase_idx]
				var ag_str: String = "AG%04d%d" % [enemy_idx, phase_idx]

				phases_arr.append({
					"phase_group": pg_str,
					"phase_idx": phase_idx,
					"hp_threshold": phase.hp_threshold,
					"action_group": ag_str,
				})

				if phase.actions != null:
					for act_idx in phase.actions.size():
						var act: EnemyConfig.EnemyAction = phase.actions[act_idx]
						actions_arr.append({
							"action_group": ag_str,
							"action_idx": act_idx,
							"type": _action_type_str(act.type),
							"base_value": act.base_value,
							"description": act.description,
							"scalable": act.scalable,
						})

		# quotes 表
		if cfg.quotes != null:
			var q: EnemyConfig.EnemyQuotes = cfg.quotes
			_add_quotes(quotes_arr, qg_str, "enter", q.enter)
			_add_quotes(quotes_arr, qg_str, "death", q.death)
			_add_quotes(quotes_arr, qg_str, "attack", q.attack)
			_add_quotes(quotes_arr, qg_str, "hurt", q.hurt)
			_add_quotes(quotes_arr, qg_str, "low_hp", q.low_hp)
			_add_quotes(quotes_arr, qg_str, "greet", q.greet)
			_add_quotes(quotes_arr, qg_str, "dispatch", q.dispatch)
			_add_quotes(quotes_arr, qg_str, "mid_boss_warning", q.mid_boss_warning)
			_add_quotes(quotes_arr, qg_str, "phase2_taunt", q.phase2_taunt)

	# 组装最终 JSON
	var output: Dictionary = {
		"base": base_arr,
		"phases": phases_arr,
		"actions": actions_arr,
		"quotes": quotes_arr,
	}

	var json_str: String = JSON.stringify(output, "  ")
	var path := "res://config/json/enemy.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[ExportEnemyJSON] Failed to open: " + path)
		quit()
		return
	f.store_string(json_str)
	f.close()

	print("[ExportEnemyJSON] 导出完成: %d 只敌人 → %s" % [all_configs.size(), path])
	print("  base: %d | phases: %d | actions: %d | quotes: %d" % [base_arr.size(), phases_arr.size(), actions_arr.size(), quotes_arr.size()])
	quit()


func _add_quotes(arr: Array, qg: String, event: String, texts: Array[String]) -> void:
	for t in texts:
		if t != "":
			arr.append({"quote_group": qg, "event": event, "text": t})


func _category_str(cat: EnemyConfig.EnemyCategory) -> String:
	match cat:
		EnemyConfig.EnemyCategory.NORMAL: return "NORMAL"
		EnemyConfig.EnemyCategory.ELITE: return "ELITE"
		EnemyConfig.EnemyCategory.BOSS: return "BOSS"
	return "NORMAL"


func _combat_type_str(ct: GameTypes.EnemyCombatType) -> String:
	match ct:
		GameTypes.EnemyCombatType.WARRIOR: return "WARRIOR"
		GameTypes.EnemyCombatType.GUARDIAN: return "GUARDIAN"
		GameTypes.EnemyCombatType.RANGER: return "RANGER"
		GameTypes.EnemyCombatType.CASTER: return "CASTER"
		GameTypes.EnemyCombatType.PRIEST: return "PRIEST"
	return "WARRIOR"


func _boss_rank_str(rank: EnemyConfig.BossRank) -> String:
	match rank:
		EnemyConfig.BossRank.NONE: return "NONE"
		EnemyConfig.BossRank.MID: return "MID"
		EnemyConfig.BossRank.FINAL: return "FINAL"
	return "NONE"


func _action_type_str(at: EnemyConfig.EnemyAction.ActionType) -> String:
	match at:
		EnemyConfig.EnemyAction.ActionType.ATTACK: return "ATTACK"
		EnemyConfig.EnemyAction.ActionType.DEFEND: return "DEFEND"
		EnemyConfig.EnemyAction.ActionType.SKILL: return "SKILL"
	return "ATTACK"
