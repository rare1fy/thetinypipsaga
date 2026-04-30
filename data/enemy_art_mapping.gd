## 敌人 ID → 美术素材 ID 映射表
##
## 单一真源：enemy.xlsx base sheet 的 art_id 列 → enemy.json → EnemyConfig.art_id
## 本文件只负责把 config_id 翻译成 art_id，以及把 art_id 翻译成 tres 路径。
##
## 查找顺序：
##   1) EnemyConfig.get_config(config_id).art_id  ← 配置表（权威来源）
##   2) _FALLBACK_MAPPING                         ← 代码侧兜底（应急覆盖 / 调试）
##
## 美术替换工作流：
##   1) 改 config/excel/enemy.xlsx 的 art_id 列
##   2) 跑 python config/tools/excel_to_json.py 打表
##   3) Godot 重载配置 → 敌人视图自动换贴图
##
## 回滚占位方块：把 art_id 列清空即可。

class_name EnemyArtMapping
extends RefCounted

## 兜底映射（config_id → art_id）
## 一般不用写，只在配置表尚未打表或需要紧急覆盖时用
const _FALLBACK_MAPPING: Dictionary = {}

## 默认循环播放的动作
const IDLE_ANIM := "idle"
const ATTACK_ANIM := "attack01"
const DEATH_ANIM := "death"
const HURT_ANIM := "hurt"

## 查询某敌人的美术 id；返回 "" 表示没有映射
static func get_art_id(enemy_config_id: String) -> String:
	# 优先走配置表（单一真源）
	var config: EnemyConfig = EnemyConfig.get_config(enemy_config_id)
	if config != null and config.art_id != "":
		return config.art_id
	# 配置未填 → 查代码兜底
	return _FALLBACK_MAPPING.get(enemy_config_id, "")

## 构造 sprite_frames.tres 的资源路径
static func get_sprite_frames_path(art_id: String) -> String:
	return "res://assets/characters/mobs/%s/sprite_frames.tres" % art_id

## 加载 SpriteFrames，失败返回 null
static func load_sprite_frames(art_id: String) -> SpriteFrames:
	if art_id == "":
		return null
	var path := get_sprite_frames_path(art_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as SpriteFrames
