## 战士骰子配置（v2 数据驱动格式）
## 所有骰子效果用 EffectType 枚举 + params 描述
## 新增骰子只需在此文件添加条目，不需要动任何代码

class_name DiceConfigWarrior
extends RefCounted

const ET := EffectTypes.EffectType
const TT := EffectTypes.TriggerType
const ES := EffectTypes.EffectScope
const SR := EffectTypes.StackingRule
const TS := EffectTypes.TargetScope


## 获取所有战士骰子定义
static func get_all() -> Array[Dictionary]:
	return [
		_warhammer(),
		_giant_shield(),
		_whirlwind(),
		_quake(),
		_berserk_heart(),
		_blood_god_eye(),
		_titan_fist(),
		_solo_blade(),
		_revenge_blade(),
		_war_cry(),
		_life_furnace(),
		_blood_chain(),
	]


# ============================================================
# 战神之锤 — ≥三条时追加基础伤害=点数总和×50% + 眩晕主目标
# ============================================================
static func _warhammer() -> Dictionary:
	return {
		"id": "w_warhammer",
		"name": "战神之锤",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 4, 5, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "warrior",
		"description": "≥三条时追加点数总和×50%伤害并眩晕目标",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "points", "ratio": 0.5},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.CONTROL,
				{"control": "stun", "duration": 1, "target": "main"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 巨人壁垒 — 护甲=点数总和×2.5(伤痕≥3时×3.5) + 嘲讽全体1回合
# ============================================================
static func _giant_shield() -> Dictionary:
	return {
		"id": "w_giant_shield",
		"name": "巨人壁垒",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "warrior",
		"description": "获得护甲=点数×2.5(伤痕≥3时×3.5)，嘲讽全体",
		"effects": [
			EffectTypes.create_effect(ET.ARMOR,
				{"value": 0, "source": "points", "ratio": 2.5,
				 "scar_bonus": {"threshold": 3, "ratio": 0.4}},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.CONTROL,
				{"control": "taunt", "duration": 1, "target": "all"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.ALL_ENEMIES),
		],
	}


# ============================================================
# 旋风斩 — 骰子自带AOE + 每目标+6(受伤后+12) + 眩晕全体
# ============================================================
static func _whirlwind() -> Dictionary:
	return {
		"id": "w_whirlwind",
		"name": "旋风斩",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "warrior",
		"description": "AOE攻击全体+6(受伤后+12)，眩晕全体",
		"effects": [
			EffectTypes.create_effect(ET.AOE, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
			EffectTypes.create_effect(ET.BONUS_DAMAGE,
				{"value": 6},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
			# 受伤后额外+6（总共+12）通过 condition:"hit" 控制
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 1.0, "condition": "hit"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
			EffectTypes.create_effect(ET.CONTROL,
				{"control": "stun", "duration": 1, "target": "all"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.ALL_ENEMIES),
		],
	}


# ============================================================
# 震地 — 点数+3 + 随机敌人+3层易伤(封顶5层)
# ============================================================
static func _quake() -> Dictionary:
	return {
		"id": "w_quake",
		"name": "震地",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "warrior",
		"description": "点数+3，随机敌人+3层易伤",
		"effects": [
			EffectTypes.create_effect(ET.MODIFY_POINTS,
				{"delta": 3},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "vulnerable", "value": 3, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.RANDOM_ENEMY),
		],
	}


# ============================================================
# 狂暴之心 — 进入狂暴2回合(+30%伤害/+20%受伤/搏命-50%)
# ============================================================
static func _berserk_heart() -> Dictionary:
	return {
		"id": "w_berserk_heart",
		"name": "狂暴之心",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [3, 4, 4, 5, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "warrior",
		"description": "进入狂暴2回合：+30%伤害/+20%受伤/搏命-50%",
		"effects": [
			EffectTypes.create_effect(ET.BERSERK,
				{"turns": 2, "damage_mult": 0.3, "taken_mult": 0.2, "gamble_cost": 0.5},
				TT.ON_PLAY, ES.INSTANT, SR.UNIQUE_OVERRIDE, TS.SELF),
		],
	}


# ============================================================
# 血神之眼 — 三段加成(损失HP%×15% + 伤痕消耗 + 状态+20%) 封顶200%
# ============================================================
static func _blood_god_eye() -> Dictionary:
	return {
		"id": "w_blood_god",
		"name": "血神之眼",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.LEGENDARY,
		"class_type": "warrior",
		"description": "三段加成：损失HP%×15% + 伤痕消耗30%×5%/层 + 状态+20%，封顶200%",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "lost_hp", "ratio": 0.15, "cap": 120},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.SCAR_CONSUME,
				{"ratio": 0.3, "bonus_per_stack": 0.05},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.2, "condition": "hit"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 泰坦之拳 — 自伤10%maxHP + 摧毁护甲 + 真实伤害30 + 兜底%HP
# ============================================================
static func _titan_fist() -> Dictionary:
	return {
		"id": "w_titan_fist",
		"name": "泰坦之拳",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [3, 4, 5, 5, 6, 6],
		"rarity": GameTypes.DiceRarity.LEGENDARY,
		"class_type": "warrior",
		"description": "自伤10%HP，摧毁护甲+30真实伤害+兜底60%HP",
		"effects": [
			EffectTypes.create_effect(ET.SELF_DAMAGE,
				{"percent": 0.1},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.ARMOR_BREAK, {},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.TRUE_DAMAGE,
				{"value": 30},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 孤注之刃 — 仅普攻时×3.0 + 点数总和追加基础伤害
# ============================================================
static func _solo_blade() -> Dictionary:
	return {
		"id": "w_solo_blade",
		"name": "孤注之刃",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [4, 5, 5, 6, 6, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "warrior",
		"description": "仅普攻时×3.0 + 点数总和追加伤害",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 2.0, "condition": "solo"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "points", "ratio": 1.0},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 复仇之刃 — 追加基础伤害=已损失HP×25%(封顶80)
# ============================================================
static func _revenge_blade() -> Dictionary:
	return {
		"id": "w_revenge_blade",
		"name": "复仇之刃",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 4, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "warrior",
		"description": "追加伤害=已损失HP×25%（封顶80）",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "lost_hp", "ratio": 0.25, "cap": 80},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 怒吼净化 — 清除全部负面+嘲讽全体1回合+每清1层对随机敌人1伤害
# ============================================================
static func _war_cry() -> Dictionary:
	return {
		"id": "w_war_cry",
		"name": "怒吼净化",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "warrior",
		"description": "清除全部负面状态+嘲讽全体+每清1层造成1伤害",
		"effects": [
			EffectTypes.create_effect(ET.PURIFY,
				{"scope": "all", "bonus_per_cleanse": 1},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.CONTROL,
				{"control": "taunt", "duration": 1, "target": "all"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.ALL_ENEMIES),
		],
	}


# ============================================================
# 生命熔炉 — 未满血回复点数×2，满血获得护甲=点数×3+本回合+20%
# ============================================================
static func _life_furnace() -> Dictionary:
	return {
		"id": "w_life_furnace",
		"name": "生命熔炉",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "warrior",
		"description": "未满血回复点数×2，满血获得护甲×3+20%增伤",
		"effects": [
			# 未满血时：回复（condition: "low_hp" 表示HP未满）
			EffectTypes.create_effect(ET.HEAL,
				{"value": 0, "source": "points", "ratio": 2.0, "condition": "not_full_hp"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
			# 满血时：护甲+增伤（condition: "full_hp"）
			EffectTypes.create_effect(ET.ARMOR,
				{"value": 0, "source": "points", "ratio": 3.0, "condition": "full_hp"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.2, "condition": "full_hp"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 血锁链 — 绑定目标，伤害传递
# ============================================================
static func _blood_chain() -> Dictionary:
	return {
		"id": "w_blood_chain",
		"name": "血锁链",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "warrior",
		"description": "绑定目标，自伤和受伤等额传递给被锁敌人",
		"effects": [
			EffectTypes.create_effect(ET.BLOOD_CHAIN,
				{"target": "main"},
				TT.ON_PLAY, ES.BATTLE, SR.UNIQUE_OVERRIDE, TS.MAIN),
		],
	}
