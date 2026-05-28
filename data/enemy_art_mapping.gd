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
## spritesheet 布局（10列×4行）：
##   Row 3: 10 sprites (普通小怪) — cols 0-9
##   Row 1-2: 5 sprites (精英/中Boss) — Row1 cols 0-2, Row2 cols 0-1
##   Row 0: 2 sprites (Boss级) — cols 0-1
const _ART_GRID_MAP: Dictionary = {
	# ── CH1 普通敌人（Row 3 的 10 个小怪精灵）──
	"m10001": Vector2i(3, 0),   # 步兵列兵 (forest_ghoul) — 人类步兵
	"m10002": Vector2i(3, 1),   # 矮人火枪手 (forest_spider) — 矮人火枪
	"m10003": Vector2i(3, 2),   # 重甲骑士 (forest_treant) — 人类重甲
	"m10004": Vector2i(3, 3),   # 牧师学徒 (forest_banshee) — 人类牧师
	"m10005": Vector2i(3, 4),   # 矮人祭司 (forest_wolf_priest) — 矮人祭司
	"m10006": Vector2i(3, 5),   # 狂战步兵 (forest_bone_reaver) — 人类狂战
	"m10007": Vector2i(3, 6),   # 矮人毒弹兵 (forest_poison_sprite) — 矮人投弹
	"m10008": Vector2i(3, 7),   # 石盾卫兵 (forest_moss_golem) — 人类盾卫
	"m10009": Vector2i(3, 8),   # 暗法学徒 (forest_wraith_cultist) — 人类法师
	"m10010": Vector2i(3, 9),   # 圣光司铎 (forest_old_willow) — 人类司铎

	# ── CH1 精英敌人（Row 1 的中型精灵）──
	"m10011": Vector2i(1, 0),   # 大法师 (elite_necromancer) — 人类大法师
	"m10012": Vector2i(1, 1),   # 圣骑士队长 (elite_alpha_wolf) — 人类圣骑士
	"m10013": Vector2i(1, 2),   # 精锐游骑兵 (elite_phantom_hunter) — 人类游侠

	# ── CH1 Boss（Row 2 + Row 0 的大型精灵）──
	"m10014": Vector2i(2, 0),   # 大主教 (boss_lich_forest) — 中Boss
	"m10015": Vector2i(2, 1),   # 城门巨像 (boss_root_colossus) — 中Boss
	"m10016": Vector2i(0, 0),   # 女巫审判官 (boss_coven_matriarch) — 中Boss
	"m10017": Vector2i(0, 1),   # 人族大元帅 (boss_ancient_treant) — 终极Boss
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
