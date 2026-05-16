## 统一效果类型系统 — 驱动骰子/遗物/敌人技能/升级/弱点击破的原子操作集合
##
## 设计原则：
##   新增骰子/遗物 = 从 EffectType 挑效果 + 填参数 → 纯配置表操作
##   新增效果类型 = 加枚举值 + 在 EffectEngine 加 match 分支 → 唯一需要动代码的场景
##
## 与 GameTypes 的关系：
##   - GameTypes.StatusType → APPLY_STATUS 的 status 参数值来源（运行时用枚举值校验）
##   - GameTypes.RelicTrigger → 将被 TriggerType 统一替代（遗物/骰子/敌人技能共用同一套触发时机）
##   - GameTypes.DiceElement → ELEMENT_TRIGGER 的 element 参数值来源
##   - ControlSystem.ControlType → CONTROL 的 control 参数值来源
##
## 效果数据格式（骰子/遗物/敌人技能通用）：
##   {
##     "type": EffectType.XXX,
##     "trigger": TriggerType.ON_PLAY,
##     "scope": EffectScope.PLAY,
##     "stacking": StackingRule.INDEPENDENT,
##     "target": TargetScope.MAIN,
##     "params": { ... },
##   }

class_name EffectTypes


# ============================================================
# 一、效果类型枚举（按效果本质分类，不按来源分）
# ============================================================

enum EffectType {
	# ---- 伤害类 (Damage) ----
	BONUS_DAMAGE,              ## 追加固定基础伤害 {value: int}
	BONUS_DAMAGE_SCALED,       ## 追加基础伤害=某数值×ratio {source: str, ratio: float, cap?: int}
	                           ##   source: "points"/"lost_hp"/"scar"/"poison"/"armor"/"shadow"/"combo"
	BONUS_MULT,                ## 伤害乘区倍率 {value: float, condition?: str}
	                           ##   condition: "hit"/"combo"/"third_play"/"solo"/"low_hp"/"keep"
	AOE,                       ## 标记/造成全体伤害 {value?: int} 无value=标记本次AOE，有value=额外固定AOE
	SPLASH,                    ## 溅射到其他目标 {ratio: float, target?: str}
	                           ##   target: "others"/"adjacent"（可选，不填=溅射除主目标外全体）
	OVERKILL_TRANSFER,         ## 击杀溢出转移 {ratio: float}
	PIERCE,                    ## 穿透护甲 {value: int}
	TRUE_DAMAGE,               ## 真实伤害（无视护甲+无视减伤） {value: int}
	EXECUTE,                   ## 处决（低于阈值斩杀） {threshold: float, mult: float, heal?: int}
	ARMOR_BREAK,               ## 摧毁目标全部护甲 {}
	ESCALATE,                  ## 每次触发递增伤害% {per_trigger: float, cap: float}
	DETONATE,                  ## 引爆目标身上的状态层数 {status: str, damage_per_stack: int, extra_per_play?: float}
	                           ##   status: "poison"/"all"

	# ---- 防御类 (Defense) ----
	HEAL,                      ## 回复HP {value: int, source?: str, ratio?: float}
	                           ##   source: "points"/"fixed"（可选，不填=直接用value）
	HEAL_ON_TRIGGER,           ## 特定条件回血 {trigger: str, value?: int, percent?: float, cap?: int}
	                           ##   trigger: "kill"/"combo"/"cleanse"
	ARMOR,                     ## 获得护甲 {value: int, source?: str, ratio?: float, scar_bonus?: dict}
	                           ##   source: "points"/"hand_size"/"fixed"（可选，不填=直接用value）
	BARRIER,                   ## 获得屏障 {value: int}
	MAX_HP_CHANGE,             ## 改变最大HP {delta: int} 正=增加，负=减少

	# ---- 状态类 (Status) ----
	APPLY_STATUS,              ## 施加状态 {status: str, value: int, target: str, bonus_if_existing?: int}
	                           ##   status: "poison"/"burn"/"vulnerable"/"weak"/"freeze"/"slow"/"strength"
	                           ##   target: "enemy"/"self"（必填）
	                           ##   bonus_if_existing: 目标已有该状态时额外叠加层数（可选，不填=不额外叠加）
	PURIFY,                    ## 清除负面状态 {scope: str, bonus_per_cleanse?: int}
	                           ##   scope: "all"/"one"

	# ---- 控制类 (Control) ----
	CONTROL,                   ## 施加控制效果 {control: str, duration: int, target: str}
	                           ##   control: "taunt"/"stun"/"knockback"/"polymorph"/"blind"/"disarm"
	                           ##   duration: 持续回合数（knockback 时此字段改为 distance: int 表示击退格数）
	                           ##   target: "main"/"all"/"random"（必填，不做默认假设）
	IGNORE_TAUNT,              ## 无视嘲讽（本次出牌/本回合可自由选择目标） {}
	                           ##   持续范围由外层 EffectScope 决定（PLAY=本次出牌, TURN=本回合）
	                           ##   葫芦/大葫芦牌型: scope=PLAY; 影刃风暴: scope=TURN

	# ---- 代价类 (Cost) ----
	SELF_DAMAGE,               ## 自伤 {value?: int, percent?: float}
	                           ##   value=固定值, percent=%maxHP, 二选一

	# ---- Buff类 (Buff) ----
	BERSERK,                   ## 进入狂暴 {turns: int, damage_mult: float, taken_mult: float, gamble_cost: float}
	BLOOD_CHAIN,               ## 绑定血锁链 {target: str}
	                           ##   target: "main"/"all"
	SOLO_SEAL,                 ## 建立单挑 {damage_mult: float}

	# ---- 手牌操控类 (Hand) ----
	BOUNCE,                    ## 出牌后弹回手牌 {grow_per_bounce?: int, grow_cap?: int}
	RECOVER,                   ## 从弃骰库回收 {count: int, once_per_battle?: bool}
	GRANT_PLAY,                ## 获得额外出牌次数 {count: int, condition?: str}
	                           ##   condition: "combo"/"always"/"third_play"
	GRANT_REROLL,              ## 获得免费重投 {count: int}
	DRAW,                      ## 额外抽牌 {count: int}
	LOCK_DIE,                  ## 锁定骰子不可操作 {}
	RETURN_TO_DECK,            ## 骰子回库顶 {}
	GRANT_TEMP_DIE,            ## 产出临时骰子 {die_type: str, count: int}
	                           ##   die_type: "shadow"/"copy"/"random"
	CONSUME_TEMP_DIE,          ## 消耗临时骰子换效果 {die_type: str, count: str, bonus_per_point?: float}
	                           ##   count: "one"/"all"
	TRANSFORM_DIE,             ## 变形骰子 {target: str, to: str}
	                           ##   target: "lowest"/"all", to: "shadow"/"curse"
	PRESERVE_DIE,              ## 骰子保留到下回合 {condition?: str}
	                           ##   condition: "combo"
	INSERT_CURSE_DIE,          ## 塞废骰/诅咒骰到玩家骰子库 {die_id: str, count: int}
	                           ##   die_id: "cursed"/"cracked"/"blank" 等
	                           ##   仅敌人→玩家方向
	REPLACE_PLAYER_DIE,        ## [扩展] 替换玩家一颗骰子为指定骰子 {from: str, to: str}
	                           ##   from: "random"/"lowest"/"highest"（默认"random"）
	                           ##   to: 目标骰子 id
	                           ##   仅敌人→玩家方向（原版无此机制，为 Godot 版扩展设计）

	# ---- 骰子数值操控类 (Dice Value) ----
	MODIFY_POINTS,             ## 改变点数 {delta: int}
	COPY_VALUE,                ## 复制点数 {source: str}
	                           ##   source: "highest"/"majority"
	REVERSE_VALUE,             ## 点数翻转(7-x) {}
	OVERRIDE_VALUE,            ## 强制设定点数 {value: int}
	BONUS_ON_KEEP,             ## 保留时点数+N {value: int, cap?: int}
	UNIFY_ELEMENT,             ## 统一元素 {}
	LOCK_ELEMENT,              ## 锁定元素 {duration: int}

	# ---- 经济类 (Economy) ----
	GAIN_GOLD,                 ## 获得金币 {value: int}
	DAMAGE_TO_GOLD,            ## 伤害转金币 {ratio: float}
	SHOP_DISCOUNT,             ## 商店折扣 {percent: float}
	STEAL_GOLD,                ## 偷取金币 {ratio?: float, flat?: int}
	                           ##   ratio: 按攻击力比例偷取; flat: 固定值偷取（二选一）
	                           ##   仅敌人→玩家方向（Thief 类敌人技能）

	# ---- 规则改变类 (Rule Modifier) ----
	MODIFY_DRAW_COUNT,         ## 改变抽牌数 {delta: int}
	MODIFY_HAND_LIMIT,         ## 改变手牌上限 {delta: int}
	MODIFY_PLAY_COUNT,         ## 改变出牌次数 {delta: int, condition?: str}
	MODIFY_REROLL_COUNT,       ## 改变重投次数 {delta: int}
	ALL_DICE_POINTS_PLUS,      ## 所有骰子点数+N {value: int}
	REROLL_NO_DOWNGRADE,       ## 重投不降点 {}
	AUTO_REROLL,               ## 自动重投 {}
	FIXED_DICE_VALUE,          ## 点数固定中位数 {}
	HAND_TYPE_TOLERANCE,       ## 牌型判定容差 {type: str, tolerance: int}
	                           ##   type: "straight"/"same"
	STRAIGHT_FULL_AOE,         ## 顺子全额AOE {}
	FULLHOUSE_RETURN_PAIR,     ## 葫芦对子弹回 {}
	SINGLE_PLAY_ALL,           ## 单次出全部手牌 {}
	ECHO_LAST_PLAY,            ## 重复上次出牌 {cd: int}
	DEATH_IMMUNITY,            ## 免死（触发后进入冷却） {cooldown_turns: int}
	                           ##   cooldown_turns: 免死触发后冷却回合数（冷却期间不可再次触发）
	DAMAGE_MULT_GLOBAL,        ## 全局伤害倍率 {value: float}
	DODGE_ATTACK,              ## 闪避攻击 {condition: str, threshold: int}
	ARMOR_PER_TURN,            ## 每回合获得护甲 {value: int, self_damage_percent?: float}

	# ---- 职业机制类 (Class Mechanic) ----
	SCAR_CONSUME,              ## 消耗伤痕层数 {ratio: float, bonus_per_stack: float}
	SCAR_BONUS,                ## 伤痕加成（不消耗） {per_stack: float}
	CHARGE,                    ## 蓄力N回合 {turns: int, bonus_per_extra?: float}
	CHAIN_BOLT,                ## 连锁闪电 {bounce: int}
	BURN_ECHO,                 ## 灼烧回响 {}
	ELEMENT_TRIGGER,           ## 触发元素效果 {element?: str, all?: bool}
	BARRIER_TO_DAMAGE,         ## 屏障转伤害 {ratio: float}
	POISON_FROM_VALUE,         ## 施毒=本骰点数 {bonus?: int}
	POISON_FROM_DICE_COUNT,    ## 施毒=手牌毒骰数×N {per_dice: int}
	AMPLIFY_SELF,              ## 放大自身点数(amplify) {mult: float} 仅放大本骰点数×mult向上取整
	STEAL_ARMOR,               ## 偷取目标护甲 {ratio: float} 偷取目标护甲×ratio转为自身护甲
	DOUBLE_STATUS_ON_COMBO,    ## 连击时目标身上指定状态翻倍 {status: str}
	DEVOUR_DIE,                ## 吞噬骰子（移除一颗骰子换效果） {}
	SWAP_WITH_UNSELECTED,      ## 与未选骰子交换点数/元素 {}
	DAMAGE_SHIELD,             ## 伤害护盾（受伤时反弹伤害给攻击者） {value: int, duration?: int}
	BONUS_MULT_ON_KEEP,        ## 保留时倍率+N（法师吟唱系） {value: float}
}


# ============================================================
# 二、触发时机枚举（效果何时被激活）
# ============================================================

enum TriggerType {
	ON_PLAY,           ## 出牌时（骰子被打出的瞬间）
	ON_SKIP,           ## 跳过出牌时
	ON_KEEP,           ## 保留骰子时（法师吟唱：选择不出牌而保留）
	ON_HOLD,           ## 持有在手牌中时（符文骰被动：只要在手牌就生效）
	ON_DISCARD,        ## 弃牌时（回合结束未使用的骰子进入弃骰库）
	ON_KILL,           ## 击杀敌人时
	ON_DAMAGE_TAKEN,   ## 玩家受到伤害时
	ON_TURN_START,     ## 玩家回合开始时
	ON_TURN_END,       ## 玩家回合结束时
	ON_ENEMY_TURN_END, ## 敌方回合结束时
	ON_ENEMY_TURN_START, ## 敌方回合开始时（召唤检查等）
	ON_BATTLE_START,   ## 战斗开始时
	ON_BATTLE_END,     ## 战斗结束时
	ON_FATAL,          ## 受到致命伤害时（HP将归零的瞬间）
	ON_REROLL,         ## 重投骰子时
	ON_COMBO,          ## 连击时（盗贼：本回合第2+次出牌）
	ON_WAVE_CLEAR,     ## 波次清除时
	ON_FLOOR_CLEAR,    ## 层清除时
	ON_MOVE,           ## 地图移动时
	ON_ALLY_DEATH,     ## 友方单位死亡时（敌人 berserker vengeance 触发）
	ON_SELF_HURT,      ## 自身受伤时（敌人 warrior bloodFury 触发）
	PASSIVE,           ## 常驻被动（无需触发，持续生效）
}


# ============================================================
# 三、效果作用域枚举（效果持续多久 / 何时清除）
# ============================================================

enum EffectScope {
	PLAY,    ## 本次出牌：从点击出牌到本次伤害结算完毕，结算后立即清除
	TURN,    ## 本回合：从玩家回合开始到玩家回合结束，回合结束时清除
	WAVE,    ## 本波次：从波次开始到波次清除，波次转换时清除
	BATTLE,  ## 本场战斗：从进入战斗到战斗结算画面出现，战斗结束时清除
	RUN,     ## 本次游戏：从开始新游戏到游戏结束，游戏结束时清除
	INSTANT, ## 瞬时：立即生效，无持续时间（如造成伤害、回复HP）
}


# ============================================================
# 四、叠加规则枚举（多次触发 / 多颗同名骰子如何叠加）
# ============================================================

enum StackingRule {
	INDEPENDENT,     ## 【独立】每颗骰子独立结算，互不干扰
	STACK_LIMITED,   ## 【叠加·有限】可累计叠加，有数值上限（上限写在params.cap中）
	STACK_UNLIMITED, ## 【叠加·无限】可累计叠加，无数值上限
	UNIQUE_OVERRIDE, ## 【唯一·覆盖】同名效果只保留最新一次
	UNIQUE_REJECT,   ## 【唯一·拒绝】已存在则新触发被拒绝
	ONCE_PER_SCOPE,  ## 【一次性】在指定作用域内只能触发1次（作用域由scope字段决定）
}


# ============================================================
# 五、目标范围枚举（效果作用于谁）
# ============================================================

enum TargetScope {
	MAIN,          ## 主目标（当前选中的敌人）
	ALL_ENEMIES,   ## 全体敌人
	RANDOM_ENEMY,  ## 随机一个敌人
	SELF,          ## 自身（施放者自己）
	ADJACENT,      ## 相邻敌人
	CHAIN_TARGET,  ## 血锁链绑定目标
	SOLO_TARGET,   ## 单挑目标
	RANDOM_ALLY,   ## 随机一个友方单位（敌人给随机队友加甲）
	ALLY_LOWEST_HP,## 血量最低的友方（Priest 治疗优先级）
	ALL_ALLIES,    ## 全体友方（敌人群体增益）
	PLAYER,        ## 玩家（敌人技能作用于玩家时使用）
}


# ============================================================
# 六、效果来源枚举（谁触发了这个效果，用于结算优先级和日志）
# ============================================================

enum EffectSource {
	DICE_ON_PLAY,      ## 骰子出牌效果
	DICE_PASSIVE,      ## 骰子被动效果（持有/保留）
	RELIC,             ## 遗物效果
	HAND_TYPE,         ## 牌型效果（顺子AOE、葫芦真伤等）
	ENEMY_SKILL,       ## 敌人技能
	STATUS_TICK,       ## 状态回合结算（毒/灼烧DOT）
	CLASS_PASSIVE,     ## 职业被动（伤痕普攻放大器等）
	OVERCHARGE,        ## 过充系统
	UPGRADE,           ## 升级效果
	WEAKNESS_BREAK,    ## 弱点击破
	CAMPFIRE,          ## 篝火效果
	EVENT,             ## 事件效果
}


# ============================================================
# 七、辅助方法
# ============================================================

## 创建一条效果数据（工厂方法，确保格式统一）
## 【设计原则】效果本身不带任何默认数值，所有数值由配置方在 params 中完整提供。
## EffectEngine 执行时若 params 缺少必填字段，直接 push_error 并跳过，不做兜底。
## 这样配置表写漏字段在开发期就能立刻暴露。
static func create_effect(
	type: EffectType,
	params: Dictionary,
	trigger: TriggerType = TriggerType.ON_PLAY,
	scope: EffectScope = EffectScope.INSTANT,
	stacking: StackingRule = StackingRule.INDEPENDENT,
	target: TargetScope = TargetScope.MAIN,
) -> Dictionary:
	return {
		"type": type,
		"trigger": trigger,
		"scope": scope,
		"stacking": stacking,
		"target": target,
		"params": params,
	}

## 每种 EffectType 的必填 params 字段注册表（EffectEngine 校验用）
## 配置方必须提供这些字段，缺一个就报错
## ⚠️ 维护提醒：新增/修改效果类型时，必须同步更新此表和枚举旁注释，保持一致
## 注释中标 ? 的参数 = 可选扩展（不填=该子功能不启用），不在此表中
const REQUIRED_PARAMS: Dictionary = {
	EffectType.BONUS_DAMAGE: ["value"],
	EffectType.BONUS_DAMAGE_SCALED: ["source", "ratio"],
	EffectType.BONUS_MULT: ["value"],
	EffectType.AOE: [],  # 无value=标记AOE，有value=额外固定AOE，两种都合法
	EffectType.SPLASH: ["ratio"],
	EffectType.OVERKILL_TRANSFER: ["ratio"],
	EffectType.PIERCE: ["value"],
	EffectType.TRUE_DAMAGE: ["value"],
	EffectType.EXECUTE: ["threshold", "mult"],
	EffectType.ARMOR_BREAK: [],
	EffectType.ESCALATE: ["per_trigger", "cap"],
	EffectType.DETONATE: ["status", "damage_per_stack"],
	EffectType.HEAL: ["value"],
	EffectType.HEAL_ON_TRIGGER: ["trigger"],
	EffectType.ARMOR: ["value"],
	EffectType.BARRIER: ["value"],
	EffectType.MAX_HP_CHANGE: ["delta"],
	EffectType.APPLY_STATUS: ["status", "value", "target"],
	EffectType.PURIFY: ["scope"],
	EffectType.CONTROL: ["control", "target"],  # duration/distance 由 EffectEngine 按 control 类型二次校验
	EffectType.IGNORE_TAUNT: [],  # 持续范围由外层 EffectScope 决定，params 无必填
	EffectType.SELF_DAMAGE: [],  # value 或 percent 二选一，由 EffectEngine 校验
	EffectType.BERSERK: ["turns", "damage_mult", "taken_mult", "gamble_cost"],
	EffectType.BLOOD_CHAIN: ["target"],
	EffectType.SOLO_SEAL: ["damage_mult"],
	EffectType.BOUNCE: [],
	EffectType.RECOVER: ["count"],
	EffectType.GRANT_PLAY: ["count"],
	EffectType.GRANT_REROLL: ["count"],
	EffectType.DRAW: ["count"],
	EffectType.LOCK_DIE: [],
	EffectType.RETURN_TO_DECK: [],
	EffectType.GRANT_TEMP_DIE: ["die_type", "count"],
	EffectType.CONSUME_TEMP_DIE: ["die_type", "count"],
	EffectType.TRANSFORM_DIE: ["target", "to"],
	EffectType.PRESERVE_DIE: [],
	EffectType.INSERT_CURSE_DIE: ["die_id", "count"],  # level 默认1，由 EffectEngine 从 DiceConfig 查表
	EffectType.REPLACE_PLAYER_DIE: ["from", "to"],
	EffectType.MODIFY_POINTS: ["delta"],
	EffectType.COPY_VALUE: ["source"],
	EffectType.REVERSE_VALUE: [],
	EffectType.OVERRIDE_VALUE: ["value"],
	EffectType.BONUS_ON_KEEP: ["value"],
	EffectType.UNIFY_ELEMENT: [],
	EffectType.LOCK_ELEMENT: ["duration"],
	EffectType.GAIN_GOLD: ["value"],
	EffectType.DAMAGE_TO_GOLD: ["ratio"],
	EffectType.SHOP_DISCOUNT: ["percent"],
	EffectType.STEAL_GOLD: [],  # ratio 或 flat 二选一，由 EffectEngine 校验
	EffectType.MODIFY_DRAW_COUNT: ["delta"],
	EffectType.MODIFY_HAND_LIMIT: ["delta"],
	EffectType.MODIFY_PLAY_COUNT: ["delta"],
	EffectType.MODIFY_REROLL_COUNT: ["delta"],
	EffectType.ALL_DICE_POINTS_PLUS: ["value"],
	EffectType.REROLL_NO_DOWNGRADE: [],
	EffectType.AUTO_REROLL: [],
	EffectType.FIXED_DICE_VALUE: [],
	EffectType.HAND_TYPE_TOLERANCE: ["type", "tolerance"],
	EffectType.STRAIGHT_FULL_AOE: [],
	EffectType.FULLHOUSE_RETURN_PAIR: [],
	EffectType.SINGLE_PLAY_ALL: [],
	EffectType.ECHO_LAST_PLAY: ["cd"],
	EffectType.DEATH_IMMUNITY: ["cooldown_turns"],
	EffectType.DAMAGE_MULT_GLOBAL: ["value"],
	EffectType.DODGE_ATTACK: ["condition", "threshold"],
	EffectType.ARMOR_PER_TURN: ["value"],
	EffectType.SCAR_CONSUME: ["ratio", "bonus_per_stack"],
	EffectType.SCAR_BONUS: ["per_stack"],
	EffectType.CHARGE: ["turns"],
	EffectType.CHAIN_BOLT: ["bounce"],
	EffectType.BURN_ECHO: [],
	EffectType.ELEMENT_TRIGGER: [],
	EffectType.BARRIER_TO_DAMAGE: ["ratio"],
	EffectType.POISON_FROM_VALUE: [],
	EffectType.POISON_FROM_DICE_COUNT: ["per_dice"],
	EffectType.AMPLIFY_SELF: ["mult"],
	EffectType.STEAL_ARMOR: ["ratio"],
	EffectType.DOUBLE_STATUS_ON_COMBO: ["status"],
	EffectType.DEVOUR_DIE: [],
	EffectType.SWAP_WITH_UNSELECTED: [],
	EffectType.DAMAGE_SHIELD: ["value"],
	EffectType.BONUS_MULT_ON_KEEP: ["value"],
}

## 校验效果数据的 params 是否包含所有必填字段
## 返回 true = 合法，false = 缺字段（同时 push_error）
static func validate_params(effect: Dictionary) -> bool:
	var type: int = effect.get("type", -1)
	if not REQUIRED_PARAMS.has(type):
		push_error("[EffectTypes] 未知效果类型: %d" % type)
		return false
	var required: Array = REQUIRED_PARAMS[type]
	var params: Dictionary = effect.get("params", {})
	for field in required:
		if not params.has(field) or params[field] == null:
			push_error("[EffectTypes] 效果 %s 缺少必填参数: %s" % [get_effect_name(type), field])
			return false
	# CONTROL 特殊校验：必须包含 duration 或 distance 之一
	if type == EffectType.CONTROL:
		if not params.has("duration") and not params.has("distance"):
			push_error("[EffectTypes] CONTROL 效果必须包含 duration（持续回合）或 distance（击退格数）")
			return false
	# SELF_DAMAGE 特殊校验：必须包含 value 或 percent 之一
	if type == EffectType.SELF_DAMAGE:
		if not params.has("value") and not params.has("percent"):
			push_error("[EffectTypes] SELF_DAMAGE 效果必须包含 value（固定值）或 percent（%maxHP）")
			return false
	return true


## 获取效果类型的中文名（用于UI显示和日志）
static func get_effect_name(type: EffectType) -> String:
	match type:
		# 伤害类
		EffectType.BONUS_DAMAGE: return "追加伤害"
		EffectType.BONUS_DAMAGE_SCALED: return "比例追加伤害"
		EffectType.BONUS_MULT: return "伤害倍率"
		EffectType.AOE: return "全体伤害"
		EffectType.SPLASH: return "溅射"
		EffectType.OVERKILL_TRANSFER: return "溢出转移"
		EffectType.PIERCE: return "穿透"
		EffectType.TRUE_DAMAGE: return "真实伤害"
		EffectType.EXECUTE: return "处决"
		EffectType.ARMOR_BREAK: return "破甲"
		EffectType.ESCALATE: return "递增伤害"
		EffectType.DETONATE: return "引爆"
		# 防御类
		EffectType.HEAL: return "治疗"
		EffectType.HEAL_ON_TRIGGER: return "条件治疗"
		EffectType.ARMOR: return "护甲"
		EffectType.BARRIER: return "屏障"
		EffectType.MAX_HP_CHANGE: return "最大HP变化"
		# 状态类
		EffectType.APPLY_STATUS: return "施加状态"
		EffectType.PURIFY: return "净化"
		# 控制类
		EffectType.CONTROL: return "控制"
		EffectType.IGNORE_TAUNT: return "无视嘲讽"
		# 代价类
		EffectType.SELF_DAMAGE: return "自伤"
		# Buff类
		EffectType.BERSERK: return "狂暴"
		EffectType.BLOOD_CHAIN: return "血锁链"
		EffectType.SOLO_SEAL: return "单挑"
		# 手牌操控类
		EffectType.BOUNCE: return "弹回"
		EffectType.RECOVER: return "回收"
		EffectType.GRANT_PLAY: return "额外出牌"
		EffectType.GRANT_REROLL: return "免费重投"
		EffectType.DRAW: return "额外抽牌"
		EffectType.LOCK_DIE: return "锁定骰子"
		EffectType.RETURN_TO_DECK: return "回库"
		EffectType.GRANT_TEMP_DIE: return "产出临时骰"
		EffectType.CONSUME_TEMP_DIE: return "消耗临时骰"
		EffectType.TRANSFORM_DIE: return "变形骰子"
		EffectType.PRESERVE_DIE: return "保留骰子"
		EffectType.INSERT_CURSE_DIE: return "塞废骰"
		EffectType.REPLACE_PLAYER_DIE: return "替换骰子"
		# 骰子数值操控类
		EffectType.MODIFY_POINTS: return "改变点数"
		EffectType.COPY_VALUE: return "复制点数"
		EffectType.REVERSE_VALUE: return "翻转点数"
		EffectType.OVERRIDE_VALUE: return "覆写点数"
		EffectType.BONUS_ON_KEEP: return "保留加点"
		EffectType.UNIFY_ELEMENT: return "统一元素"
		EffectType.LOCK_ELEMENT: return "锁定元素"
		# 经济类
		EffectType.GAIN_GOLD: return "获得金币"
		EffectType.DAMAGE_TO_GOLD: return "伤害转金币"
		EffectType.SHOP_DISCOUNT: return "商店折扣"
		EffectType.STEAL_GOLD: return "偷取金币"
		# 规则改变类
		EffectType.MODIFY_DRAW_COUNT: return "改变抽牌数"
		EffectType.MODIFY_HAND_LIMIT: return "改变手牌上限"
		EffectType.MODIFY_PLAY_COUNT: return "改变出牌次数"
		EffectType.MODIFY_REROLL_COUNT: return "改变重投次数"
		EffectType.ALL_DICE_POINTS_PLUS: return "全骰加点"
		EffectType.REROLL_NO_DOWNGRADE: return "重投不降"
		EffectType.AUTO_REROLL: return "自动重投"
		EffectType.FIXED_DICE_VALUE: return "固定点数"
		EffectType.HAND_TYPE_TOLERANCE: return "牌型容差"
		EffectType.STRAIGHT_FULL_AOE: return "顺子全额AOE"
		EffectType.FULLHOUSE_RETURN_PAIR: return "葫芦弹回"
		EffectType.SINGLE_PLAY_ALL: return "全手出牌"
		EffectType.ECHO_LAST_PLAY: return "回声"
		EffectType.DEATH_IMMUNITY: return "免死"
		EffectType.DAMAGE_MULT_GLOBAL: return "全局伤害倍率"
		EffectType.DODGE_ATTACK: return "闪避"
		EffectType.ARMOR_PER_TURN: return "每回合护甲"
		# 职业机制类
		EffectType.SCAR_CONSUME: return "消耗伤痕"
		EffectType.SCAR_BONUS: return "伤痕加成"
		EffectType.CHARGE: return "蓄力"
		EffectType.CHAIN_BOLT: return "连锁闪电"
		EffectType.BURN_ECHO: return "灼烧回响"
		EffectType.ELEMENT_TRIGGER: return "元素触发"
		EffectType.BARRIER_TO_DAMAGE: return "屏障转伤"
		EffectType.POISON_FROM_VALUE: return "点数施毒"
		EffectType.POISON_FROM_DICE_COUNT: return "毒骰施毒"
		EffectType.AMPLIFY_SELF: return "自身放大"
		EffectType.STEAL_ARMOR: return "偷取护甲"
		EffectType.DOUBLE_STATUS_ON_COMBO: return "连击翻倍状态"
		EffectType.DEVOUR_DIE: return "吞噬骰子"
		EffectType.SWAP_WITH_UNSELECTED: return "交换骰子"
		EffectType.DAMAGE_SHIELD: return "伤害护盾"
		EffectType.BONUS_MULT_ON_KEEP: return "保留倍率"
		_: return "未知效果"


## 获取触发时机的中文名
static func get_trigger_name(trigger: TriggerType) -> String:
	match trigger:
		TriggerType.ON_PLAY: return "出牌时"
		TriggerType.ON_SKIP: return "跳过时"
		TriggerType.ON_KEEP: return "保留时"
		TriggerType.ON_HOLD: return "持有时"
		TriggerType.ON_DISCARD: return "弃牌时"
		TriggerType.ON_KILL: return "击杀时"
		TriggerType.ON_DAMAGE_TAKEN: return "受伤时"
		TriggerType.ON_TURN_START: return "回合开始"
		TriggerType.ON_TURN_END: return "回合结束"
		TriggerType.ON_ENEMY_TURN_END: return "敌方回合结束"
		TriggerType.ON_ENEMY_TURN_START: return "敌方回合开始"
		TriggerType.ON_BATTLE_START: return "战斗开始"
		TriggerType.ON_BATTLE_END: return "战斗结束"
		TriggerType.ON_FATAL: return "致命伤害时"
		TriggerType.ON_REROLL: return "重投时"
		TriggerType.ON_COMBO: return "连击时"
		TriggerType.ON_WAVE_CLEAR: return "波次清除"
		TriggerType.ON_FLOOR_CLEAR: return "层清除"
		TriggerType.ON_MOVE: return "移动时"
		TriggerType.ON_ALLY_DEATH: return "友方死亡时"
		TriggerType.ON_SELF_HURT: return "自身受伤时"
		TriggerType.PASSIVE: return "常驻"
		_: return "未知时机"


## 获取作用域的中文名
static func get_scope_name(scope: EffectScope) -> String:
	match scope:
		EffectScope.PLAY: return "本次出牌"
		EffectScope.TURN: return "本回合"
		EffectScope.WAVE: return "本波次"
		EffectScope.BATTLE: return "本场战斗"
		EffectScope.RUN: return "本次游戏"
		EffectScope.INSTANT: return "瞬时"
		_: return "未知作用域"


## 获取叠加规则的中文名
static func get_stacking_name(rule: StackingRule) -> String:
	match rule:
		StackingRule.INDEPENDENT: return "独立"
		StackingRule.STACK_LIMITED: return "叠加·有限"
		StackingRule.STACK_UNLIMITED: return "叠加·无限"
		StackingRule.UNIQUE_OVERRIDE: return "唯一·覆盖"
		StackingRule.UNIQUE_REJECT: return "唯一·拒绝"
		StackingRule.ONCE_PER_SCOPE: return "一次性"
		_: return "未知规则"


## 状态名字符串 → GameTypes.StatusType 映射（公共方法，消除重复）
static func status_name_to_type(name: String) -> int:
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
		"dodge":
			return GameTypes.StatusType.DODGE if "DODGE" in GameTypes.StatusType else -1
		"strength":
			return GameTypes.StatusType.STRENGTH if "STRENGTH" in GameTypes.StatusType else -1
		"armor":
			return GameTypes.StatusType.ARMOR if "ARMOR" in GameTypes.StatusType else -1
		_:
			push_warning("[EffectTypes] 未知状态名: %s" % name)
			return -1
