"""生成第一章17个敌人的 SpriteFrames .tres 资源文件"""
import os

art_ids = [
    'human_footman', 'dwarf_musketeer', 'heavy_knight', 'priest_apprentice',
    'dwarf_priest', 'berserker_footman', 'dwarf_bomber', 'stone_guardian',
    'dark_apprentice', 'holy_inquisitor', 'elite_archmage', 'elite_paladin',
    'elite_ranger', 'boss_archbishop', 'boss_gate_colossus', 'boss_witch_judge',
    'boss_grand_marshal'
]

base_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'assets', 'characters', 'mobs')

template = '''[gd_resource type="SpriteFrames" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/characters/mobs/{art_id}/idle_0.png" id="1"]

[resource]
animations = [{{
"frames": [{{
"duration": 1.0,
"texture": ExtResource("1")
}}],
"loop": true,
"name": &"idle",
"speed": 5.0
}}]
'''

for art_id in art_ids:
    mob_dir = os.path.join(base_dir, art_id)
    os.makedirs(mob_dir, exist_ok=True)
    tres_path = os.path.join(mob_dir, 'sprite_frames.tres')
    content = template.format(art_id=art_id)
    with open(tres_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Created: {art_id}/sprite_frames.tres')

print('Done! 17 SpriteFrames resources created.')
