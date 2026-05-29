class_name ArenaRegistry
extends RefCounted
## 战斗场景注册表
## 管理背景图 → Arena 预制件的映射关系
## battle_scene.gd 通过本类获取当前战斗应加载的 Arena 场景

## ─── 注册表数据 ───
## key = 背景图文件名（不含路径和扩展名），value = arena .tscn 路径
const _ARENA_MAP: Dictionary = {
	# ── CH1 普通战 n1（森林）──
	"ch1_n1_01": "res://assets/battle_backgrounds/arenas/ch1_n1_01.tscn",
	"ch1_n1_02": "res://assets/battle_backgrounds/arenas/ch1_n1_02.tscn",
	"ch1_n1_03": "res://assets/battle_backgrounds/arenas/ch1_n1_03.tscn",
	"ch1_n1_04": "res://assets/battle_backgrounds/arenas/ch1_n1_04.tscn",
	"ch1_n1_05": "res://assets/battle_backgrounds/arenas/ch1_n1_05.tscn",
	"ch1_n1_06": "res://assets/battle_backgrounds/arenas/ch1_n1_06.tscn",
	"ch1_n1_07": "res://assets/battle_backgrounds/arenas/ch1_n1_07.tscn",
	"ch1_n1_08": "res://assets/battle_backgrounds/arenas/ch1_n1_08.tscn",

	# ── CH1 普通战 n2（城堡）──
	"ch1_n2_01": "res://assets/battle_backgrounds/arenas/ch1_n2_01.tscn",
	"ch1_n2_02": "res://assets/battle_backgrounds/arenas/ch1_n2_02.tscn",
	"ch1_n2_03": "res://assets/battle_backgrounds/arenas/ch1_n2_03.tscn",
	"ch1_n2_04": "res://assets/battle_backgrounds/arenas/ch1_n2_04.tscn",
	"ch1_n2_05": "res://assets/battle_backgrounds/arenas/ch1_n2_05.tscn",
	"ch1_n2_06": "res://assets/battle_backgrounds/arenas/ch1_n2_06.tscn",

	# ── CH1 精英战 e1（墓地）──
	"ch1_e1_01": "res://assets/battle_backgrounds/arenas/ch1_e1_01.tscn",
	"ch1_e1_02": "res://assets/battle_backgrounds/arenas/ch1_e1_02.tscn",
	"ch1_e1_03": "res://assets/battle_backgrounds/arenas/ch1_e1_03.tscn",

	# ── CH1 精英战 e2（地牢）──
	"ch1_e2_01": "res://assets/battle_backgrounds/arenas/ch1_e2_01.tscn",
	"ch1_e2_02": "res://assets/battle_backgrounds/arenas/ch1_e2_02.tscn",
	"ch1_e2_03": "res://assets/battle_backgrounds/arenas/ch1_e2_03.tscn",

	# ── CH1 中Boss mb（教堂）──
	"ch1_mb_01": "res://assets/battle_backgrounds/arenas/ch1_mb_01.tscn",
	"ch1_mb_02": "res://assets/battle_backgrounds/arenas/ch1_mb_02.tscn",
	"ch1_mb_03": "res://assets/battle_backgrounds/arenas/ch1_mb_03.tscn",

	# ── CH1 最终Boss fb（王座厅）──
	"ch1_fb_01": "res://assets/battle_backgrounds/arenas/ch1_fb_01.tscn",
}


## 根据背景图路径获取对应的 Arena 场景路径
## 返回空字符串表示无对应 Arena（降级为旧逻辑）
static func get_arena_path(bg_texture_path: String) -> String:
	# 从路径中提取文件名（不含扩展名）
	var file_name: String = bg_texture_path.get_file().get_basename()
	return _ARENA_MAP.get(file_name, "")


## 获取指定章节和战斗类型的所有可用 Arena 路径
## battle_prefix: "n1", "n2", "e1", "e2", "mb", "fb"
static func get_arenas_by_type(chapter: int, battle_prefix: String) -> Array[String]:
	var prefix: String = "ch%d_%s" % [chapter, battle_prefix]
	var result: Array[String] = []
	for key: String in _ARENA_MAP:
		if key.begins_with(prefix):
			result.append(_ARENA_MAP[key])
	return result


## 随机选取一个 Arena（带防重复）
static func pick_random_arena(chapter: int, battle_prefix: String, exclude_path: String = "") -> String:
	var candidates: Array[String] = get_arenas_by_type(chapter, battle_prefix)
	if candidates.is_empty():
		return ""
	# 防重复：排除上一次使用的
	if exclude_path != "" and candidates.size() > 1:
		candidates.erase(exclude_path)
	return candidates[randi() % candidates.size()]
