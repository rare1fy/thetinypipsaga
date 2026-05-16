# TheTiny-PipSaga — 一点点史诗 (The Tiny-Pip Saga) Godot 版

竖屏 Roguelike 骰子构筑游戏，从 React Web 版复刻到 Godot 4.3。

## 项目结构

```
├── common/              # 核心逻辑
│   ├── autoload/        # Autoload 单例
│   ├── ui/              # 弹窗/面板 (纯代码构建)
│   ├── game_types.gd    # 枚举/类型定义
│   ├── hand_evaluator.gd # 牌型判定
│   ├── attack_calc.gd   # 伤害计算
│   ├── map_generator.gd # 地图生成
│   ├── relic_engine.gd  # 遗物引擎
│   └── effect_types.gd  # 效果类型枚举
├── scenes/              # 所有场景 (.tscn + .gd 同目录)
│   ├── battle/          # 战斗场景 + 战斗子系统
│   ├── campfire/        # 篝火休息
│   ├── chapter_transition/ # 章节过渡
│   ├── class_select/    # 职业选择
│   ├── dice_reward/     # 骰子奖励
│   ├── event/           # 随机事件
│   ├── game_over/       # 死亡画面
│   ├── loot/            # 战利品
│   ├── map/             # 地图
│   ├── merchant/        # 商店
│   ├── skill_select/    # 技能选择
│   ├── start/           # 主菜单
│   ├── treasure/        # 宝箱
│   └── victory/         # 胜利画面
├── data/                # 数据定义
│   ├── class_def.gd     # 职业 (嗜血狂战/星界魔导/影锋刺客)
│   ├── dice_def.gd      # 骰子定义
│   ├── enemy_config.gd  # 敌人配置 (5章)
│   ├── relic_def.gd     # 遗物定义
│   └── game_balance.gd  # 平衡数值
├── entities/            # 可复用实体组件
│   ├── dice_button/     # 骰子按钮
│   ├── dice_tooltip/    # 骰子提示
│   ├── enemy/           # 敌人视图 + 工厂
│   └── player_hands/    # 玩家手牌
├── audio/               # 音效/音乐
├── main.gd / main.tscn  # 主场景路由
└── project.godot        # 720×1280 竖屏
```

## 核心系统

- 牌型判定 (HandEvaluator): 对子→皇家元素顺，17种牌型
- 战斗引擎: 骰子抽取→选择→出牌→敌人AI→波次推进
- 三职业差异: 战士卖血/法师吟唱/盗贼连击
- 5章地图: 幽暗森林→冰封山脉→熔岩深渊→暗影要塞→永恒之巅
- 遗物系统: 15+遗物，5种触发时机
- 元素系统: 火/冰/雷/毒/圣 5元素效果
