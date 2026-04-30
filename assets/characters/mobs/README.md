# 怪物美术素材 · 占位期使用说明

## 当前状态
- 来源：第三方游戏（Survivor.io）提取的序列帧
- 性质：**临时占位**，用于开发阶段验证动画流程与美术风格
- **版权**：外部素材，**绝对不能**打包到正式发布版本中

## 版权防御
- `.gitignore` 已排除 `assets/characters/mobs/*/*.png`
- 本目录下的 png 文件**不会**被推到远端仓库
- 上线抖音/Steam 前必须全部换成自研或 CC0 授权素材

## 目录结构
```
mobs/
├── README.md                # 本文件
└── m10001/
    ├── m10001-idle_00.png ... m10001-idle_20.png    # 21 帧
    ├── m10001-attack01_00.png ... attack01_13.png   # 14 帧
    ├── m10001-death_00.png ... death_08.png         # 9 帧
    └── sprite_frames.tres                            # 编辑器脚本生成
```

## 添加新角色 · 三步流程
1. 在 `mobs/` 下建以 `m10xxx` 命名的子目录
2. 把 `{角色名}-{动作}_{帧号}.png` 文件放进去
3. Godot 编辑器里打开 `tools/build_sprite_frames.gd`，按 `Ctrl+Shift+X` 跑一次
4. 打开 `config/excel/enemy.xlsx`，在对应敌人行的 `art_id` 列填上 `m10xxx`
5. 跑 `python config/tools/excel_to_json.py` 打表
6. Godot 重载 → 敌人自动换贴图

## 尺寸
- 原始分辨率：约 719×325（横图）
- 推荐 scale：0.18（落在 VisualRoot 视觉高度 ~60px 内）

## 回滚
把 `config/excel/enemy.xlsx` 的 `art_id` 列清空 → 跑一次打表 → 所有敌人立即退回 ColorRect + emoji 方块
