## 职业选择画面

extends Node2D
signal class_selected(class_id: String)

@onready var warrior_btn: Button = %WarriorBtn
@onready var mage_btn: Button = %MageBtn
@onready var rogue_btn: Button = %RogueBtn
@onready var desc_label: RichTextLabel = %DescLabel
@onready var skill_label: RichTextLabel = %SkillLabel


func _ready() -> void:
	warrior_btn.pressed.connect(func(): _on_class_picked("warrior"))
	mage_btn.pressed.connect(func(): _on_class_picked("mage"))
	rogue_btn.pressed.connect(func(): _on_class_picked("rogue"))
	
	# 悬停预览
	warrior_btn.mouse_entered.connect(func(): _show_class_info("warrior"))
	mage_btn.mouse_entered.connect(func(): _show_class_info("mage"))
	rogue_btn.mouse_entered.connect(func(): _show_class_info("rogue"))
	
	# 进场动画：Container 子节点禁用 scale/position tween，只做 modulate 淡入
	# 避免与 HBoxContainer/VBoxContainer 的自动布局冲突导致遮挡和按钮失效
	VFX.fade_in(warrior_btn, 0.4, 0.1)
	VFX.fade_in(mage_btn, 0.4, 0.2)
	VFX.fade_in(rogue_btn, 0.4, 0.3)
	VFX.fade_in(desc_label, 0.3, 0.3)
	VFX.fade_in(skill_label, 0.3, 0.4)
	
	_show_class_info("warrior")


func _on_class_picked(class_id: String) -> void:
	SoundPlayer.play_sound("click")
	GameManager.start_run(class_id)


func _show_class_info(class_id: String) -> void:
	var class_def := ClassDef.get_all()[class_id] as ClassDef
	if not class_def:
		return
	
	desc_label.text = "[b]%s[/b] — %s\n\n%s\n\nHP: %d | 抽牌: %d | 出牌: %d | 免费重投: %d" % [
		class_def.name, class_def.title, class_def.description,
		class_def.hp, class_def.draw_count, class_def.max_plays, class_def.free_rerolls
	]
	
	var skills_text := class_def.passive_desc + "\n\n"
	for i in class_def.skill_names.size():
		skills_text += "[b]%s[/b]: %s\n" % [class_def.skill_names[i], class_def.skill_descs[i]]
	skill_label.text = skills_text
