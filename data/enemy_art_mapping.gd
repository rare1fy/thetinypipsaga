## 敌人 art_id → 精灵图纹理 映射
##
## 新方案（v2）：直接从 spritesheet 按 region 裁切 AtlasTexture
## 不再需要每个敌人一个文件夹 + sprite_frames.tres
## 动画全部用程序动画（Tween 呼吸/弹跳/闪烁），类似口袋妖怪风格
##
## spritesheet 规格：
##   - 路径：res://assets/characters/enemies/spritesheet_enemies_ch1.png
##   - 格子大小：64×64
##   - 网格：10列×4行（640×256）
##
## 映射方式：art_id → 格子索引 → AtlasTexture region

class_name EnemyArtMapping
extends RefCounted

## spritesheet 路径（按章节扩展）
const SPRITESHEET_CH1 := "res://assets/characters/enemies/spritesheet_enemies_ch1.png"

## 格子尺寸
const CELL_SIZE := 64

## art_id → (row, col) 在 spritesheet 中的位置
## 顺序与精灵图表中实际排列一致
const _ART_GRID_MAP: Dictionary = {
	"human_footman":     Vector2i(0, 0),
	"dwarf_musketeer":   Vector2i(1, 0),
	"heavy_knight":      Vector2i(1, 1),
	"priest_apprentice": Vector2i(1, 2),
	"dwarf_priest":      Vector2i(2, 0),
	"berserker_footman": Vector2i(2, 1),
	"dwarf_bomber":      Vector2i(2, 2),
	"stone_guardian":    Vector2i(3, 0),
	"dark_apprentice":   Vector2i(3, 1),
	"holy_inquisitor":   Vector2i(3, 2),
	"elite_archmage":    Vector2i(3, 3),
	"elite_paladin":     Vector2i(3, 4),
	"elite_ranger":      Vector2i(3, 5),
	"boss_archbishop":   Vector2i(3, 6),
	"boss_gate_colossus": Vector2i(3, 7),
	"boss_witch_judge":  Vector2i(3, 8),
	"boss_grand_marshal": Vector2i(3, 9),
}

## 缓存已加载的 AtlasTexture（避免重复创建）
static var _texture_cache: Dictionary = {}

## 查询某敌人的美术 id；返回 "" 表示没有映射
static func get_art_id(enemy_config_id: String) -> String:
	var config: EnemyConfig = EnemyConfig.get_config(enemy_config_id)
	if config != null and config.art_id != "":
		return config.art_id
	return ""


## 加载敌人的静态纹理（AtlasTexture from spritesheet）
## 返回 null 表示该 art_id 没有对应的精灵图
static func load_texture(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	# 缓存命中
	if _texture_cache.has(art_id):
		return _texture_cache[art_id] as Texture2D
	# 查找格子位置
	if not _ART_GRID_MAP.has(art_id):
		return null
	var grid_pos: Vector2i = _ART_GRID_MAP[art_id]
	# 加载 spritesheet 基础纹理
	var sheet_path := _get_spritesheet_for_art(art_id)
	if not ResourceLoader.exists(sheet_path):
		push_warning("[EnemyArtMapping] spritesheet 不存在: %s" % sheet_path)
		return null
	var sheet_tex: Texture2D = load(sheet_path) as Texture2D
	if sheet_tex == null:
		return null
	# 创建 AtlasTexture 裁切对应格子
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_tex
	atlas.region = Rect2(
		grid_pos.y * CELL_SIZE,
		grid_pos.x * CELL_SIZE,
		CELL_SIZE,
		CELL_SIZE
	)
	_texture_cache[art_id] = atlas
	return atlas


## 根据 art_id 确定使用哪张 spritesheet（未来按章节扩展）
static func _get_spritesheet_for_art(_art_id: String) -> String:
	# TODO: CH2-CH5 的 spritesheet 加入后，根据 art_id 前缀或配置表判断
	return SPRITESHEET_CH1


## ── 兼容旧接口（逐步废弃）──

## 旧接口：加载 SpriteFrames（现在返回 null，强制走新的 load_texture 路径）
static func load_sprite_frames(_art_id: String) -> SpriteFrames:
	return null

## 旧常量保留（EnemyView 中还有引用，但不再实际使用）
const IDLE_ANIM := "idle"
const ATTACK_ANIM := "attack01"
const DEATH_ANIM := "death"
const HURT_ANIM := "hurt"
