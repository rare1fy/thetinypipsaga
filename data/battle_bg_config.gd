## 战斗背景配置表 — 配置表驱动的场景选择系统
## 根据战斗类型 + 地图阶段（depth）从对应场景池中随机选取背景

class_name BattleBgConfig

## 资源根路径
const BASE_PATH := "res://assets/battle_backgrounds/"

## ============================================================
## 场景池定义
## ============================================================
## 结构：每个池是一个文件名数组，运行时随机选取

## 普通战·前半段（depth 0~6）
const NORMAL_PHASE1: Array[String] = [
	"ch1_n1_01.png",
	"ch1_n1_02.png",
	"ch1_n1_03.png",
	"ch1_n1_04.png",
	"ch1_n1_05.png",
	"ch1_n1_06.png",
	"ch1_n1_07.png",
	"ch1_n1_08.png",
]

## 普通战·后半段（depth 8~13）
const NORMAL_PHASE2: Array[String] = [
	"ch1_n2_01.png",
	"ch1_n2_02.png",
	"ch1_n2_03.png",
	"ch1_n2_04.png",
	"ch1_n2_05.png",
	"ch1_n2_06.png",
]

## 精英战·前半段（depth 0~6）
const ELITE_PHASE1: Array[String] = [
	"ch1_e1_01.png",
	"ch1_e1_02.png",
	"ch1_e1_03.png",
]

## 精英战·后半段（depth 8~13）
const ELITE_PHASE2: Array[String] = [
	"ch1_e2_01.png",
	"ch1_e2_02.png",
	"ch1_e2_03.png",
]

## 中Boss（depth 7）
const MID_BOSS: Array[String] = [
	"ch1_mb_01.png",
	"ch1_mb_02.png",
	"ch1_mb_03.png",
]

## 终Boss（depth 14）
const FINAL_BOSS: Array[String] = [
	"ch1_fb_01.png",
]


## ============================================================
## 公共 API
## ============================================================

## 根据节点类型和当前 depth 获取随机背景路径
static func get_random_bg(node_type: GameTypes.NodeType, depth: int) -> String:
	var pool := _get_pool(node_type, depth)
	if pool.is_empty():
		return ""
	var filename := pool[randi() % pool.size()]
	return BASE_PATH + filename


## 根据节点类型和当前 depth 获取对应场景池
static func _get_pool(node_type: GameTypes.NodeType, depth: int) -> Array[String]:
	match node_type:
		GameTypes.NodeType.BOSS:
			if depth >= 14:
				return FINAL_BOSS
			return MID_BOSS
		GameTypes.NodeType.ELITE:
			if depth >= 8:
				return ELITE_PHASE2
			return ELITE_PHASE1
		_:
			# 普通战（ENEMY 或其他进入战斗的类型）
			if depth >= 8:
				return NORMAL_PHASE2
			return NORMAL_PHASE1
