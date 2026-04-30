# 一点点史诗 (The Tiny-Pip Saga) 配置表规范 v1.0

> 创建日期：2026-04-24
> 适用范围：Excel 驱动的游戏数值配置
> 工具链：Excel(编辑) → Python(excel_to_json.py) → JSON(运行时) → ConfigLoader(gdscript)

## 一、工作流

```
策划改 Excel → 跑 python config/tools/excel_to_json.py → 生成 json → git 提交 → deploy.cjs 自动读最新 json
```

部署前 `deploy.cjs` 会自动跑一次 excel_to_json.py，忘了转也不会部署旧数据。

## 二、目录约定

```
config/
├── README.md                 # 本文件
├── excel/                    # 策划编辑源文件
│   ├── _enums.xlsx           # 全局枚举 + ID 映射（查号必看）
│   ├── balance.xlsx          # 游戏常量
│   ├── dice.xlsx             # 骰子（3 sheet: base / effects / status）
│   ├── relic.xlsx            # 遗物（2 sheet: base / effects）
│   ├── enemy.xlsx            # 敌人（4 sheet: base / phases / actions / quotes）
│   └── class.xlsx            # 职业（2 sheet: base / starting_items）
├── json/                     # 运行时读取产物（git 追踪，部署用）
│   └── *.json
└── tools/
    ├── requirements.txt      # openpyxl
    ├── build_excel.py        # 一次性：从 gd 代码生成初始 xlsx
    └── excel_to_json.py      # 每次改完 Excel 跑
```

## 三、编号规则

| 类型 | 格式 | 范围分段 |
|---|---|---|
| 骰子 | D + 4位 | D0001-0099 通用 / D0101-0199 战士 / D0201-0299 法师 / D0301-0399 盗贼 |
| 遗物 | R + 4位 | R0001-0099 通用 / R0101+ 职业专属（预留） |
| 敌人 | E + 4位 | E0001-0099 森林 / E0101-0199 冰封 / E0201-0299 熔岩 / E0301-0399 暗影 / E0401-0499 永恒 / E9001+ 精英 Boss |
| 职业 | C + 2位 | C01 战士 / C02 法师 / C03 盗贼 |
| 效果组 | EG + 4位 | EG0001-0999 骰子 / EG1001-1999 遗物 |
| 效果类型 | ET + 2位 | ET01 damage / ET02 damage_mult / ET03 armor ...（见 _enums.xlsx） |
| 状态类型 | ST + 2位 | ST01 灼烧 / ST02 中毒 ...（见 _enums.xlsx） |
| 触发时机 | TR + 2位 | TR01 on_play / TR02 on_turn_end ...（见 _enums.xlsx） |
| 稀有度 | RA + 1位 | RA1 普通 / RA2 稀有 / RA3 史诗 / RA4 传说 / RA5 诅咒 |
| 元素 | EL + 1位 | EL0 无 / EL1 火 / EL2 冰 / EL3 雷 / EL4 毒 / EL5 圣 / EL6 暗 |

## 四、表头规则（所有 Sheet 统一 3 行表头）

```
行1：字段英文名（代码读取）         如：id / name / faces
行2：字段类型（代码验证用）         如：string / int / intarray / float / bool / json / ref / enum
行3：备注描述（策划可读，含规则）    长文，说明填写规范、枚举可选值、单位、默认值
行4 起：实际数据
```

**代码只读第 1 行 + 第 4 行起**，跳过 2、3 行。

## 五、字段类型枚举

| 类型 | 解析规则 | 示例 |
|---|---|---|
| `int` | 整数 | `100` |
| `float` | 浮点 | `1.2` |
| `bool` | 0/1 → bool | `0` / `1` |
| `string` | 字符串 | `赤焰小骰` |
| `intarray` | 逗号分隔 → int[] | `1,2,3,4,5,6` |
| `strarray` | 分号分隔 → str[] | `D0001;D0001;D0101` |
| `floatarray` | 逗号分隔 → float[] | `0.9,1.1,1.25` |
| `json` | JSON 字符串 | `["森林","山脉"]` / `{"hp":0.9}` |
| `ref` | 外键 ID | `EG0001` / `D0001` |
| `enum` | 枚举编号 | `RA1` / `ET01` |

## 六、状态紧凑编码

骰子 / 遗物的"施加状态"类效果，用 `param_ref` 字段紧凑编码：

```
ST<类型编号>x<数值>x<持续回合>
```

示例：
- `ST02x2x3` = 中毒 2 层 持续 3 回合
- `ST01x3x2` = 灼烧 3 层 持续 2 回合

## 七、策划改数值流程

1. 打开 `config/excel/xxx.xlsx`，改第 4 行以下的数据
2. 保存 Excel
3. 终端执行：`python config/tools/excel_to_json.py`
4. 确认 `config/json/xxx.json` 已更新
5. Godot 中 F5 运行，验证效果
6. `node deploy.cjs` 部署到在线

## 八、新增数据流程

### 新增骰子
1. 查 `_enums.xlsx · id_map` sheet 找下一个可用编号（例如 D0008）
2. 在 `dice.xlsx · base` sheet 加一行
3. 如果需要特殊效果，在 `dice.xlsx · effects` sheet 加若干行，挂到同一个 effect_group
4. 把新号写回 `_enums.xlsx · id_map`

### 新增效果类型
1. 如果现有 effect_type 无法表达，在 `_enums.xlsx · enum_effect_type` 新增一行
2. 在 `common/autoload/config_loader.gd` 的效果组装函数里实现对应代码分支

## 九、约束

- 禁止在 Excel 里删除第 1、2、3 行
- 禁止更改已发布 ID（会导致存档失效）
- 禁止在 json/ 目录手动改数据（一定走 Excel）
