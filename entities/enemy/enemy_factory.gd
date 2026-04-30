## 敌人工厂 — 按 config_id 动态加载对应 tscn，没有独立 tscn 则 fallback 到通用 enemy_view.tscn
## 职责：
##   1. 维护 config_id → tscn 路径的映射（约定：res://entities/enemy/mobs/{config_id}.tscn）
##   2. 路径不存在时自动 fallback 到 enemy_view.tscn（兼容旧数据，允许渐进式迁移）
##   3. 统一所有业务方调用入口，battle_controller / battle_scene 等不再直接 preload
##
## 使用方式：
##   var view: EnemyView = EnemyFactory.create("m10001")
##   enemy_container.add_child(view)
##   view.init("m10001")   # 再绑定数据
##
## 扩展新独立敌人 tscn：
##   1. 在 Godot 编辑器 → 场景 → 新建继承场景 → 选 enemy_view.tscn
##   2. 另存为 res://entities/enemy/mobs/{config_id}.tscn（文件名必须等于 config_id）
##   3. 挂 SpriteFrames、调 scale / offset，保存即可
##   4. 本工厂会自动发现（通过 ResourceLoader.exists 判定）
class_name EnemyFactory
extends RefCounted

## 通用兜底 tscn
const FALLBACK_SCENE: PackedScene = preload("res://entities/enemy/enemy_view.tscn")

## 独立敌人 tscn 目录（按 config_id 命名）
const MOBS_DIR := "res://entities/enemy/mobs/"

## PackedScene 缓存，避免重复 load
static var _scene_cache: Dictionary = {}


## 按 config_id 创建一个 EnemyView 实例（未 add_child，调用方自行挂树）
static func create(config_id: String) -> EnemyView:
	var scene: PackedScene = _resolve_scene(config_id)
	var view: EnemyView = scene.instantiate() as EnemyView
	return view


## 解析 config_id 对应的 PackedScene：
##   1. 先查缓存
##   2. 缓存未命中则探测 mobs/{config_id}.tscn
##   3. 不存在则用 FALLBACK_SCENE，并写入缓存避免每次都探测磁盘
static func _resolve_scene(config_id: String) -> PackedScene:
	if _scene_cache.has(config_id):
		return _scene_cache[config_id]
	var specific_path: String = "%s%s.tscn" % [MOBS_DIR, config_id]
	var scene: PackedScene = FALLBACK_SCENE
	if ResourceLoader.exists(specific_path):
		var loaded: Resource = ResourceLoader.load(specific_path)
		if loaded is PackedScene:
			scene = loaded
	_scene_cache[config_id] = scene
	return scene


## 手动清缓存（热重载 / 测试用）
static func clear_cache() -> void:
	_scene_cache.clear()
