# MortalPath

**MortalPath** 是一款固定斜俯视 2.5D 修仙即时战斗 RPG 的工程骨架。

项目采用“凡人流”修仙叙事：玩家从凡俗或炼气阶段起步，在境界森严、资源有限、强者真实存在的世界中，通过功法、法器、丹药、符箓、情报与战前准备逐步成长。具体人物、宗门、剧情与法宝设定保持原创。

## 当前骨架

当前版本是一个可以直接运行的 **Combat Lab**：

- Godot 4.3+，GDScript；
- 3D 战斗平面 + 固定正交相机，形成 2.5D 斜俯视表现；
- 单角色即时移动、普攻、闪避；
- 炼气四层玩家；
- 炼气六层敌人与筑基初期敌人；
- 境界威胁指数、属性缩放与大境界穿透规则；
- 调试突破能力，可直观看到筑基前后的战力差距；
- 无外部生产素材，当前战斗对象仍使用 Godot 内置几何体；
- 规则层 headless 测试。

## 美术仓库

首版美术基线为：

> **凡尘山水·写意半写实**

```text
3D 角色与场景
+ 固定正交斜俯视
+ 绘画化 PBR
+ 低饱和自然环境
+ 克制而可读的修仙特效
+ 境界驱动的动作与战场差异
```

美术源资产、方向板、生产规范、校验工具与 Art Pack 发布已独立维护于：

- [`pxf77/MortalPath-Art`](https://github.com/pxf77/MortalPath-Art)

仓库职责边界：

```text
MortalPath-Art
  → 源资产 / Manifest / 自动导出 / 技术验收 / Art Pack
  → 发布固定版本 Runtime Art Pack
MortalPath
  → 锁定 Art Pack 版本
  → 在 Godot 场景中集成并执行游戏回归
```

游戏仓不直接依赖 `.blend`、`.psd`、`.kra` 等 DCC 源文件，也不把临时 Actions Artifact 当作长期资产源。

## 运行

1. 使用 Godot 4.3 或更高版本打开仓库根目录。
2. 运行主场景 `res://src/main/main.tscn`，或直接运行项目。

命令行：

```bash
godot --path .
```

规则测试：

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

## 操作

| 操作 | 按键 |
|---|---|
| 移动 | `WASD` / 方向键 |
| 御剑普攻 | 鼠标左键 / `J` |
| 身法闪避 | `Space` / `K` |
| 调试突破 | `B` |
| 重置试验场 | `R` |

试验建议：

1. 先攻击左侧炼气六层敌人，观察同一大境界内的正常交战。
2. 再攻击右侧筑基初期敌人，观察低一大境界时的伤害衰减与被压制效果。
3. 按 `B` 突破到筑基初期，再次交战。

## 目录

```text
.
├── docs/
│   ├── architecture.md
│   ├── game-vision.md
│   ├── realm-and-combat.md
│   └── roadmap.md
├── src/
│   ├── actors/                   # 玩家、敌人与战斗实体
│   ├── combat/                   # 伤害规则
│   ├── core/                     # 输入等基础能力
│   ├── cultivation/              # 境界与修炼规则
│   └── main/                     # Combat Lab 场景组合与 HUD
├── tests/                        # 无插件的 headless 规则测试
├── project.godot
└── README.md
```

## 首作范围基线

首作建议控制在：

- 玩家跨度：凡俗/炼气起步，结丹初期收束；
- 一个主要宗门、一个坊市、三个野外区域、两个大型秘境；
- 三条主要修炼流派；
- 单主角、固定视角、区域式地图；
- 不做开放世界、联机、多角色即时切换、全局等级缩放；
- 元婴及以上作为世界背景和高压事件存在，不作为首作常规可战胜目标。

其他设计文档：

- [`docs/game-vision.md`](docs/game-vision.md)
- [`docs/realm-and-combat.md`](docs/realm-and-combat.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/roadmap.md`](docs/roadmap.md)
