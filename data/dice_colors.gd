## 骰子配色方案 — 从原版 PixelDiceRenderer.tsx 移植
## 包含通用/战士/法师/盗贼/元素5类骰子配色

class_name DiceColors

## 骰子配色结构
class DiceColorScheme:
	var border: String
	var outer: String
	var inner: String
	var highlight: String
	var shadow: String
	var digit: String
	var digit_shadow: String
	
	func _init(p_border: String, p_outer: String, p_inner: String, p_highlight: String, p_shadow: String, p_digit: String, p_digit_shadow: String) -> void:
		border = p_border
		outer = p_outer
		inner = p_inner
		highlight = p_highlight
		shadow = p_shadow
		digit = p_digit
		digit_shadow = p_digit_shadow

## 获取骰子配色
static func get_colors(dice_id: String) -> DiceColorScheme:
	if _ALL.has(dice_id):
		return _ALL[dice_id]
	return _ALL.get("standard", DiceColorScheme.new("#687078","#889098","#a0a8b0","#d0d8e0","#484850","#1a1e25","#b0b8c0"))

## 是否有该骰子的配色
static func has_colors(dice_id: String) -> bool:
	return _ALL.has(dice_id)

const _ALL: Dictionary = {
	# 通用
	"standard": DiceColorScheme.new("#687078","#889098","#a0a8b0","#d0d8e0","#484850","#1a1e25","#b0b8c0"),
	"blade": DiceColorScheme.new("#606068","#787880","#909098","#c0c0c8","#404048","#f0f0f8","#505058"),
	"amplify": DiceColorScheme.new("#382058","#503080","#6840a0","#a070e0","#201038","#d8b8ff","#302050"),
	"split": DiceColorScheme.new("#104838","#186858","#209870","#50d8a0","#083020","#a0ffd0","#104838"),
	"magnet": DiceColorScheme.new("#401828","#603040","#804858","#c07888","#280810","#ffc0d0","#401828"),
	"joker": DiceColorScheme.new("#402048","#604070","#885898","#c088d0","#281030","#f0d0ff","#402048"),
	"chaos": DiceColorScheme.new("#481810","#703020","#a04830","#e07040","#300808","#ffd040","#481810"),
	"cursed": DiceColorScheme.new("#281030","#402050","#583070","#8858a0","#180818","#c088e0","#281030"),
	"elemental": DiceColorScheme.new("#282848","#383868","#484888","#7070c0","#181830","#c0c0ff","#282848"),
	"heavy": DiceColorScheme.new("#505058","#686870","#808088","#a8a8b0","#383840","#e0e0e8","#484850"),
	
	# 嗜血狂战
	"w_bloodthirst": DiceColorScheme.new("#581010","#802020","#a83030","#e05040","#380808","#ffc0b0","#501010"),
	"w_ironwall": DiceColorScheme.new("#584018","#806020","#a88030","#d0a848","#382808","#ffe8c0","#504018"),
	"w_warcry": DiceColorScheme.new("#584810","#806818","#b09028","#e0c040","#383008","#fff8a0","#504010"),
	"w_fury": DiceColorScheme.new("#582008","#804010","#b06020","#e88830","#381008","#ffe0a0","#502008"),
	"w_charge": DiceColorScheme.new("#584008","#806010","#a88020","#d8b030","#382808","#fff0b0","#503808"),
	"w_armorbreak": DiceColorScheme.new("#582810","#804018","#a85828","#d88038","#381808","#ffc890","#502010"),
	"w_revenge": DiceColorScheme.new("#581818","#803028","#a84838","#d06850","#380808","#ffb0a0","#501010"),
	"w_roar": DiceColorScheme.new("#585010","#807018","#a89828","#d0c040","#383808","#fff0a0","#504810"),
	"w_execute": DiceColorScheme.new("#504010","#786018","#a08028","#c8a838","#382808","#ffe8a0","#483810"),
	"w_berserk": DiceColorScheme.new("#580808","#801010","#b02020","#e83830","#380404","#ff8878","#500808"),
	"w_bloodgod": DiceColorScheme.new("#400408","#600810","#801018","#b02028","#280204","#ff7868","#380408"),
	
	# 星界魔导
	"mage_elemental": DiceColorScheme.new("#202848","#304068","#405888","#6080c0","#101830","#c0d8ff","#202040"),
	"mage_reverse": DiceColorScheme.new("#301848","#483070","#604898","#8868c0","#200830","#d8c0ff","#281040"),
	"mage_missile": DiceColorScheme.new("#102048","#203870","#305098","#4878d0","#081030","#a0c8ff","#101838"),
	"mage_barrier": DiceColorScheme.new("#103848","#185868","#287888","#48a8c0","#082830","#90e0ff","#102830"),
	"mage_meditate": DiceColorScheme.new("#282048","#403868","#585088","#7870b0","#181030","#d0c0f0","#201838"),
	"mage_amplify": DiceColorScheme.new("#281048","#402070","#583098","#7850d0","#180828","#c8a8ff","#200838"),
	"mage_mirror": DiceColorScheme.new("#103048","#184868","#286088","#4890c0","#082030","#a0d8ff","#102838"),
	"mage_prism": DiceColorScheme.new("#301050","#482078","#6838a0","#9058d0","#200830","#d8b0ff","#280840"),
	"mage_devour": DiceColorScheme.new("#180830","#281050","#381870","#5030a8","#100418","#a870f0","#180828"),
	"mage_surge": DiceColorScheme.new("#200848","#381070","#502098","#7038d0","#100428","#c0a0ff","#180838"),
	"mage_purify": DiceColorScheme.new("#103848","#185870","#287898","#40a8d0","#082830","#90e8ff","#103040"),
	
	# 影锋刺客
	"r_dagger": DiceColorScheme.new("#183818","#285828","#388838","#58c058","#102810","#c0ffc0","#183018"),
	"r_envenom": DiceColorScheme.new("#084818","#106828","#189838","#30d050","#043010","#80ffa0","#084018"),
	"r_throwing": DiceColorScheme.new("#183838","#285858","#388878","#58c0b0","#102828","#a0fff0","#183030"),
	"r_pursuit": DiceColorScheme.new("#104038","#186058","#288878","#48c8b0","#083028","#90fff0","#103830"),
	"r_sleeve": DiceColorScheme.new("#184018","#286028","#389038","#58c858","#103010","#a0ffb0","#183818"),
	"r_quickdraw": DiceColorScheme.new("#104038","#186058","#289078","#48c8a8","#083028","#90fff0","#103838"),
	"r_combomastery": DiceColorScheme.new("#304010","#486018","#688828","#90c038","#202808","#d0ff70","#283810"),
	"r_lethal": DiceColorScheme.new("#284018","#406028","#589038","#80c858","#183010","#c8ffa0","#283818"),
	"r_toxblade": DiceColorScheme.new("#104810","#186818","#209828","#38d038","#083008","#80ff80","#104010"),
	"r_shadow_clone": DiceColorScheme.new("#204020","#306830","#409848","#60d068","#102810","#b0ffc0","#203020"),
	"r_venomfang": DiceColorScheme.new("#085010","#107018","#18a028","#30e040","#043808","#70ff90","#084810"),
	"r_bladestorm": DiceColorScheme.new("#085018","#107028","#18a038","#30e050","#043808","#80ffa0","#084818"),
	
	# 元素坍缩
	"fire": DiceColorScheme.new("#682010","#984020","#c06030","#ff9050","#481008","#fff0c0","#601810"),
	"ice": DiceColorScheme.new("#103050","#184870","#286898","#60b8e0","#082040","#d0f0ff","#102840"),
	"thunder": DiceColorScheme.new("#484010","#686018","#988828","#e0d040","#303008","#fffff0","#484010"),
	"poison": DiceColorScheme.new("#183818","#285828","#389838","#60e060","#102810","#c0ffc0","#183018"),
	"holy": DiceColorScheme.new("#484030","#686050","#989078","#e0d8b8","#303020","#fffff0","#484030"),
	"shadow": DiceColorScheme.new("#181020","#281838","#382848","#604878","#100818","#c0a0e0","#181020"),
}
