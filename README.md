# MortalPath

**MortalPath** 是一款固定斜俯视 2.5D 修仙即时战斗 RPG。

项目采用“凡人流”修仙叙事：玩家从凡俗或炼气阶段起步，在境界森严、资源有限、强者真实存在的世界中，通过功法、法器、丹药、符箓、情报与战前准备逐步成长。具体人物、宗门、剧情与法宝设定保持原创。

## 初版 Demo：青岚谷脱身

当前主场景已经从规则试验场演进为一段可完整结束的战斗 Demo：

```text
击退三名炼气邪修
  ↓
筑基守阵修士现身
  ↓
承受大境界压制并破坏三处锁灵阵眼
  ↓
启动遁光阵撤离
```

已实现：

- Godot 4.7.2 stable（精确固定）、GDScript；
- 3D 战斗平面与固定正交斜俯视镜头；
- 三段御剑普攻及输入缓冲；
- 主动剑诀、护体灵光、身法闪避；
- 气血、灵力恢复、技能消耗和冷却；
- 近战、远程与筑基守阵三种敌人行为；
- 敌方攻击前摇、范围提示、远程术法飞行物；
- 炼气同境界击杀与筑基大境界压制；
- 锁灵阵眼、遁光阵、撤离胜利条件；
- 开场、胜利、失败和重新挑战流程；
- 规则测试、主场景冒烟和 Demo 阶段流转测试。
- 短前摇、输入缓冲、命中停顿、局部受击与破阵反馈、[CC0 初版采样音效](assets/audio/README.md)；
- 默认 / 减弱动态 / 静音三轮正常输入回归与技能使用记录。

当前仍使用工程占位几何体，目标是先验证玩法闭环、战斗可读性和境界秩序。正式美术资产将由独立美术仓库发布 Runtime Art Pack 后再接入。

## 运行

1. 使用 Godot 4.7.2 stable 打开仓库根目录，不使用其他补丁版或预览版。
2. 运行项目或主场景 `res://src/main/main.tscn`。
3. 按 `Enter` 开始 Demo。

命令行：

```bash
python3 tools/godot_toolchain.py install --templates
bash scripts/godot.sh
```

## 操作

| 操作 | 按键 |
|---|---|
| 移动 | `WASD` / 方向键 |
| 三段御剑 | 鼠标左键 / `J` |
| 青锋剑诀 | `Q` |
| 护体灵光 | `E` |
| 身法闪避 | `Space` / `K` |
| 开始 / 结算后重开 | `Enter` |
| 随时重置 | `R` |
| 减弱动态（震屏及停顿） | `F6` |
| 音效开关 | `M` |

移动相对于屏幕方向，攻击朝向由最后一次移动决定；左键触发攻击但不按鼠标指针瞄准。

战斗建议：

1. 连续输入普攻完成三段连击，第三段可以命中多个近身目标，实际命中才回复少量灵力；
2. `Q` 消耗灵力释放远距离贯穿剑诀；
3. `E` 在敌人重击或筑基修士施法前展开护体灵光；
4. 筑基修士出现后不要把击杀作为首要目标，优先破坏三处阵眼并进入南侧遁光阵。

## 验证

```bash
# 境界、伤害、连击与灵力规则
 bash scripts/godot.sh --headless --script res://tests/test_runner.gd

# Demo 阶段、敌人生成、破阵和撤离入口流转
 bash scripts/godot.sh --headless --script res://tests/demo_scene_runner.gd
```

GitHub Actions 还会执行 Godot 工程导入和主场景 headless 冒烟。

本地完整回归：`bash scripts/validate-demo.sh`，导出验收：`bash scripts/validate-export.sh`。本地编辑器、匹配的导出模板、游戏 CI 和美术夹具统一从 `toolchain.lock.json` 读取 4.7.2；不再日常验证 4.3，不自动追随最新版。版本升级须单独完整回归，见 [`版本策略`](docs/godot-version-policy.md)。首批实施和待人工签收项目见 [`M1 验收记录`](docs/m1-validation.md)。自动通关不等于人工手感验收。

## 美术仓库

首版美术基线为：

> **凡尘山水·写意半写实**

美术源资产、方向板、生产规范、校验工具与 Art Pack 发布独立维护于：

- [`pxf77/MortalPath-Art`](https://github.com/pxf77/MortalPath-Art)

仓库职责边界：

```text
MortalPath-Art
  → 源资产 / Manifest / 自动导出 / 技术验收 / Runtime Art Pack
MortalPath
  → 锁定 Art Pack 版本 / Godot 集成 / 游戏回归
```

游戏仓不直接依赖 `.blend`、`.psd`、`.kra` 等 DCC 源文件，也不把临时 Actions Artifact 当作长期资产源。

## 目录

```text
.
├── docs/
│   ├── architecture.md
│   ├── demo-v0.1.md
│   ├── game-vision.md
│   ├── realm-and-combat.md
│   └── roadmap.md
├── src/
│   ├── actors/                   # 玩家、敌人和战斗实体
│   ├── combat/                   # 伤害、Demo 战斗规则与飞行物
│   ├── core/                     # 输入等基础能力
│   ├── cultivation/              # 境界与修炼规则
│   ├── main/                     # Demo 编排、场景与 HUD
│   └── world/                    # 阵眼与遁光阵等交互目标
├── tests/                        # 规则与 Demo 流程 headless 测试
├── project.godot
└── README.md
```

## 首作范围基线

- 玩家跨度：凡俗或炼气起步，结丹初期收束；
- 一个主要宗门、一个坊市、三个野外区域、两个大型秘境；
- 三条主要修炼流派；
- 单主角、固定视角、区域式地图；
- 不做开放世界、联机、多角色即时切换、全局等级缩放；
- 元婴及以上作为世界背景和高压事件存在，不作为首作常规可战胜目标。

其他设计文档：

- [`docs/demo-v0.1.md`](docs/demo-v0.1.md)
- [`docs/game-vision.md`](docs/game-vision.md)
- [`docs/realm-and-combat.md`](docs/realm-and-combat.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/roadmap.md`](docs/roadmap.md)
