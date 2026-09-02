# Asset Manifest

每个正式资产使用一个 JSON Manifest。Manifest 是流水线输入，不是审批状态机。

## 必填字段

| 字段 | 含义 |
|---|---|
| `id` | 全局唯一、小写 `snake_case` 资产 ID |
| `kind` | `character/environment/prop/weapon/vfx/ui/audio` |
| `milestone` | 当前生产阶段或目标里程碑 |
| `source` | 源类型与仓库内路径 |
| `runtime.path` | 导出后的运行时文件路径 |
| `preview.path` | 自动预览路径 |
| `scale` | 米制单位与合理高度范围 |
| `budget` | 三角面、材质、骨骼、动画和贴图上限 |
| `art` | 色板、风格和境界标签 |
| `provenance` | 来源和授权状态 |

## 原则

- 不在 Manifest 中维护 `draft/review/approved/rejected` 等复杂状态；
- Git 提交记录负责版本，PR 负责审查，Art Pack 标签负责发布；
- 一个运行时路径只能由一个 Manifest 声明；
- 正式源文件必须位于 `art_pipeline/source/`；
- 游戏可用产物必须位于 `art_pipeline/runtime/`。
