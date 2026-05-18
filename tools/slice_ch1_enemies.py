"""
切分第一章敌人精灵图，为每个敌人生成：
- assets/characters/mobs/<art_id>/idle.png
- assets/characters/mobs/<art_id>/idle.png.import
- assets/characters/mobs/<art_id>/sprite_frames.tres

布局（精灵图 640x512，64px 网格）：
- 终Boss: r0-r1, c0  (64x128)
- 中Boss: r3, c0..c2 (3 个 64x64)
- 精英:   r5, c0..c2 (3 个 64x64)
- 普通:   r7, c0..c9 (10 个 64x64)
"""
from PIL import Image
import os
import uuid
import random
import string

PROJ = r"C:\Users\slimboiliu\TheTiny-PipSaga"
SRC = os.path.join(PROJ, "assets", "characters", "enemies", "spritesheet_enemies_ch1.png")
OUT_BASE = os.path.join(PROJ, "assets", "characters", "mobs")

ENEMIES = [
    # 普通 r7 c0..c9
    (0, 7, 64, 64, "human_footman"),
    (1, 7, 64, 64, "dwarf_musketeer"),
    (2, 7, 64, 64, "heavy_knight"),
    (3, 7, 64, 64, "priest_apprentice"),
    (4, 7, 64, 64, "dwarf_priest"),
    (5, 7, 64, 64, "berserker_footman"),
    (6, 7, 64, 64, "dwarf_bomber"),
    (7, 7, 64, 64, "stone_guardian"),
    (8, 7, 64, 64, "dark_apprentice"),
    (9, 7, 64, 64, "holy_inquisitor"),
    # 精英 r5 c0..c2
    (0, 5, 64, 64, "elite_archmage"),
    (1, 5, 64, 64, "elite_paladin"),
    (2, 5, 64, 64, "elite_ranger"),
    # 中Boss r3 c0..c2
    (0, 3, 64, 64, "boss_archbishop"),
    (1, 3, 64, 64, "boss_gate_colossus"),
    (2, 3, 64, 64, "boss_witch_judge"),
    # 终Boss r0-r1 c0 (64x128)
    (0, 0, 64, 128, "boss_grand_marshal"),
]


def md5_hex() -> str:
    return uuid.uuid4().hex


def gen_uid() -> str:
    """生成 13 字符 base32 风格 id（Godot uid 风格）"""
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(13))


def main():
    im = Image.open(SRC).convert("RGBA")
    print(f"Source image: {im.size}")

    for col, row, w, h, art_id in ENEMIES:
        x = col * 64
        y = row * 64
        cell = im.crop((x, y, x + w, y + h))

        mob_dir = os.path.join(OUT_BASE, art_id)
        os.makedirs(mob_dir, exist_ok=True)

        # 写 PNG
        png_path = os.path.join(mob_dir, "idle.png")
        cell.save(png_path)

        # 给 PNG 一个 uid，sprite_frames 和 .import 必须共享同一个
        idle_uid = gen_uid()
        frames_uid = gen_uid()
        md5 = md5_hex()

        # .png.import
        import_text = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{idle_uid}"
path="res://.godot/imported/idle.png-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/characters/mobs/{art_id}/idle.png"
dest_files=["res://.godot/imported/idle.png-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
        with open(png_path + ".import", "w", encoding="utf-8") as f:
            f.write(import_text)

        # sprite_frames.tres（引用 idle_uid）
        tres_text = f"""[gd_resource type="SpriteFrames" load_steps=2 format=3 uid="uid://{frames_uid}"]

[ext_resource type="Texture2D" uid="uid://{idle_uid}" path="res://assets/characters/mobs/{art_id}/idle.png" id="1_idle"]

[resource]
animations = [{{
"frames": [{{
"duration": 1.0,
"texture": ExtResource("1_idle")
}}],
"loop": true,
"name": &"idle",
"speed": 5.0
}}]
"""
        tres_path = os.path.join(mob_dir, "sprite_frames.tres")
        with open(tres_path, "w", encoding="utf-8") as f:
            f.write(tres_text)

        print(f"  [{art_id}] {w}x{h}  png_uid={idle_uid}  tres_uid={frames_uid}")

    print(f"\nDone. {len(ENEMIES)} enemies generated.")


if __name__ == "__main__":
    main()
