## 像素风主题配色 — 从原版 index.css CSS变量移植
## 暗黑地牢 8-Bit 像素风调色板

class_name Theme

## 地牢基调
const DUNGEON_BG := Color("#0a0908")
const DUNGEON_BG_LIGHT := Color("#141210")
const DUNGEON_PANEL := Color("#1a1714")
const DUNGEON_PANEL_BORDER := Color("#2e2820")
const DUNGEON_PANEL_HIGHLIGHT := Color("#3a3228")
const DUNGEON_TEXT := Color("#b8c4cc")
const DUNGEON_TEXT_DIM := Color("#5a6e7e")
const DUNGEON_TEXT_BRIGHT := Color("#e0e8f0")

## 强调色
const PIXEL_RED := Color("#d44a2a")
const PIXEL_RED_DARK := Color("#8b2210")
const PIXEL_RED_LIGHT := Color("#f07050")

const PIXEL_BLUE := Color("#3c6cc8")
const PIXEL_BLUE_DARK := Color("#1a3c8b")
const PIXEL_BLUE_LIGHT := Color("#68a0e8")

const PIXEL_PURPLE := Color("#7a30c0")
const PIXEL_PURPLE_DARK := Color("#4a1080")
const PIXEL_PURPLE_LIGHT := Color("#a858e8")

const PIXEL_GOLD := Color("#d4a030")
const PIXEL_GOLD_DARK := Color("#8b6a10")
const PIXEL_GOLD_LIGHT := Color("#f0c850")

const PIXEL_GREEN := Color("#38c060")
const PIXEL_GREEN_DARK := Color("#188838")
const PIXEL_GREEN_LIGHT := Color("#60e880")

const PIXEL_ORANGE := Color("#e07830")
const PIXEL_ORANGE_DARK := Color("#a05010")
const PIXEL_ORANGE_LIGHT := Color("#f0a050")

const PIXEL_CYAN := Color("#30d8d0")
const PIXEL_CYAN_DARK := Color("#108880")
const PIXEL_CYAN_LIGHT := Color("#60f0e8")

const PIXEL_ABYSS := Color("#6020a0")
const PIXEL_ABYSS_LIGHT := Color("#9050d0")

## 稀有度颜色
const RARITY_COMMON := Color("#38c060")
const RARITY_UNCOMMON := Color("#3c6cc8")
const RARITY_RARE := Color("#a855f7")
const RARITY_LEGENDARY := Color("#f97316")

## 稀有度标签
const RARITY_LABELS: Dictionary = {
	"common": "普通",
	"uncommon": "精良",
	"rare": "稀有",
	"legendary": "传说",
	"curse": "诅咒",
}

## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return RARITY_COMMON
		"uncommon": return RARITY_UNCOMMON
		"rare": return RARITY_RARE
		"legendary": return RARITY_LEGENDARY
		"curse": return PIXEL_RED
		_: return DUNGEON_TEXT_DIM

## 像素风按钮样式配置
class PixelButtonStyle:
	var bg_color: Color
	var border_color: Color
	var text_color: Color
	var highlight_color: Color
	var shadow_color: Color
	
	func _init(p_bg: Color, p_border: Color, p_text: Color, p_highlight: Color, p_shadow: Color) -> void:
		bg_color = p_bg
		border_color = p_border
		text_color = p_text
		highlight_color = p_highlight
		shadow_color = p_shadow

## 按钮样式
static func btn_primary() -> PixelButtonStyle:
	return PixelButtonStyle.new(
		Color("#18803a"), Color("#0a3014"), Color("#c8ffd0"),
		Color("#3ccc60"), Color("#0c4418")
	)

static func btn_danger() -> PixelButtonStyle:
	return PixelButtonStyle.new(
		Color("#a02820"), Color("#2a0808"), Color("#ffc8c0"),
		Color("#d04838"), Color("#601008")
	)

static func btn_gold() -> PixelButtonStyle:
	return PixelButtonStyle.new(
		Color("#907020"), Color("#2a2008"), Color("#fff0c0"),
		Color("#c8a040"), Color("#604008")
	)

static func btn_ghost() -> PixelButtonStyle:
	return PixelButtonStyle.new(
		Color("#1a1a2e"), Color("#2a2a40"), DUNGEON_TEXT_DIM,
		Color("#282840"), Color("#0e0e1a")
	)
