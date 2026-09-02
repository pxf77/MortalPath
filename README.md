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

## 美术方向 v0.1

首版美术基线已定义为：

> **凡尘山水·写意半写实**

```text
3D 角色与场景
+ 固定正交斜俯视
+ 绘画化 PBR
+ 低饱和自然环境
+ 克制而可读的修仙特效
+ 境界驱动的动作与战场差异
```

![MortalPath 美术方向参考板](assets/art-guides/art-direction-board-v0.1.svg)

参考板用于锁定构图、色彩、材质气质和境界递进。图中的生成文字、数值和界面不是正式设定，正式文字必须人工校对并在 UI 中重新排版。

美术规范：

- [`docs/art-direction/README.md`](docs/art-direction/README.md)
- [`docs/art-direction/art-bible-v0.1.md`](docs/art-direction/art-bible-v0.1.md)
- [`docs/art-direction/realm-visual-hierarchy.md`](docs/art-direction/realm-visual-hierarchy.md)
- [`docs/art-direction/asset-production-spec.md`](docs/art-direction/asset-production-spec.md)
- [`docs/art-direction/art-review-checklist.md`](docs/art-direction/art-review-checklist.md)
- [`docs/art-direction/production-plan.md`](docs/art-direction/production-plan.md)

## 美术资源流水线 P0

项目已增加可独立迁移的 `art_pipeline/`：

```text
源资产 / 程序化源
  → Blender 5.2.1 后台导出
  → Manifest、预算与 Khronos glTF 校验
  → Godot 4.3 导入冒烟
  → 预览、资产目录与 Art Pack
```

当前流水线先在游戏仓库内打通，目录结构按后续 `MortalPath-Art` 独立仓库设计。它严格区分 `source/`、`runtime/`、`reports/` 与 `dist/`，不会让游戏运行时直接依赖 DCC 源文件。

本地预检：

```bash
python -m unittest discover -s art_pipeline/tests -v
python art_pipeline/tools/validate_manifest.py
```

相关文档：

- [`art_pipeline/README.md`](art_pipeline/README.md)
- [`docs/art-direction/art-pipeline.md`](docs/art-direction/art-pipeline.md)
- [`.github/workflows/art-pipeline.yml`](.github/workflows/art-pipeline.yml)
- [`.github/workflows/art-publish.yml`](.github/workflows/art-publish.yml)

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
├── .github/workflows/            # Godot 与美术生产 CI
├── art_pipeline/                 # 可迁移的美术源资产生产流水线
├── assets/
│   └── art-guides/               # 美术参考板与基础色板
├── docs/
│   ├── art-direction/            # 美术圣经、视觉层级、生产规范与流水线
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
