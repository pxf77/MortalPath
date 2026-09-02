# 独立美术资源生产流水线 P0

## 1. 状态

P0 已在仓库内以自包含目录 `art_pipeline/` 落地。该目录按未来独立仓库 `MortalPath-Art` 的根结构设计；当前 GitHub 连接不提供创建新仓库动作，因此先打通真实产线，再整体迁移，而不是阻塞美术生产。

迁移时仅需：

1. 将 `art_pipeline/` 内容提升为新仓库根目录；
2. 将两条 `art-*.yml` 工作流随之迁移并调整相对路径；
3. 在游戏仓库只保留已发布的 Runtime Art Pack 和锁文件；
4. 源文件历史不再继续进入游戏仓库。

## 2. 流水线边界

```text
source / reference / manifests
              ↓
       Blender 5.2.1 LTS
              ↓
           GLB runtime
              ↓
Manifest + budget + Khronos validation
              ↓
       Godot 4.3 import fixture
              ↓
 preview + reports + asset catalog
              ↓
      snapshot / versioned Art Pack
```

游戏运行时只接收：

- `.glb/.gltf`；
- `.png/.webp/.svg`；
- `.ogg`；
- Godot `.tres/.tscn/.gdshader`；
- `asset-catalog.json` 和 Art Pack 锁文件。

游戏运行时不读取：

- `.blend/.psd/.kra/.exr`；
- AI 生成图中的文字与图标；
- 临时预览、缓存和 DCC 自动保存文件。

## 3. P0 已实现能力

### 3.1 工具链锁定

`art_pipeline/toolchain.lock.json` 统一锁定：

- Blender `5.2.1`；
- Godot `4.3`，与当前游戏工程一致；
- Khronos glTF Validator `2.0.0-dev.3.10`；
- Python `3.12`。

CI 从 Blender 官方发布地址下载归档，并使用同版本官方 SHA-256 清单校验；Khronos Validator 使用固定 Release 资产。

### 3.2 源资产与 Git LFS

仓库根目录 `.gitattributes` 已为以下大型源文件配置 LFS：

```text
.blend .psd .kra .exr .wav
```

轻量 Manifest、脚本、SVG、运行时 GLB 和校验报告仍使用普通 Git。当前没有提交大型二进制样本，避免无意义消耗 LFS 配额。

### 3.3 Manifest

一个正式资产对应一个 Manifest，只描述：

- 唯一 ID 和类型；
- 源文件及运行时路径；
- 尺寸；
- 技术预算；
- 色板、风格、境界；
- 来源与授权。

版本由 Git 管理，审查由 PR 管理，发布由 `artpack-v*` 标签管理，不增加资产审批状态机。

### 3.4 Blender 后台生产

CI 使用 Blender 后台模式：

1. 读取源 `.blend`，或通过 `blender_python` 脚本重建源场景；
2. 应用旋转和缩放；
3. 导出 GLB；
4. 生成固定正交构图的审查预览。

当前 `prop_pipeline_marker` 是程序化自检道具，用于证明完整链路，不代表最终美术品质。

### 3.5 客观校验

机器检查包括：

- JSON 与必填字段；
- 资产 ID、路径和扩展名；
- 重复 ID 与重复运行时路径；
- 源文件和运行时文件存在性；
- GLB 头、JSON Chunk 和基础统计；
- 三角面、材质、骨骼、动画和高度预算；
- Khronos glTF 2.0 规范验证；
- Godot `PackedScene` 导入和网格存在性。

机器不判断“是否好看”和“境界气势是否正确”。这些继续按现有美术验收清单人工审查。

### 3.6 产物

每次有效 PR/Push 会生成：

| Artifact | 内容 | 保留期 |
|---|---|---:|
| `art-runtime` | GLB、预览、Manifest/预算/Khronos 报告、资产目录 | 30 天 |
| `godot-smoke` | Godot 导入结果 | 30 天 |
| `art-pack` | Snapshot Art Pack、SHA-256、元数据 | 30 天 |

标签 `artpack-v*` 会重新执行完整流水线，并创建 GitHub Release。

## 4. 首个自检资产

```text
prop_pipeline_marker
```

它验证：

- Blender 官方版本可在 CI 启动；
- 程序化源可保存为 `.blend`；
- 石材与玉色材质可导出到 GLB；
- 预算统计和 Khronos 校验可运行；
- Godot 4.3 能导入并实例化；
- 预览、Catalog 和 Art Pack 可生成。

它不会进入正式游戏世界，也不作为场景风格样本。

## 5. 下一阶段

P0 通过后按以下顺序推进：

1. A1 三张无字 Style Frame 的来源与授权登记；
2. 一把低阶飞剑，验证 Blender 源文件和挂点；
3. 一个山谷岩石模块，验证碰撞命名与场景尺度；
4. 一个御剑命中特效，验证 Godot 原生 VFX 资产；
5. 一个 HUD 边框，验证 SVG/纹理与 UI 缩放；
6. 稳定后再拆分到 `MortalPath-Art` 并增加跨仓晋升 PR。

P0 不包含 GPU 截图回归、视觉差异阈值、资产数据库和自动跨仓写入，这些在真实资产数量增长后再评估。
