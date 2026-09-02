# MortalPath Art Pipeline P0

该目录是 `MortalPath-Art` 独立仓库的可迁移 P0 实现。当前先放在游戏仓库中，以便在不依赖新仓库创建权限的情况下打通真实流水线；目录内路径和脚本均保持自包含，后续可整体迁移。

## 目标

```text
源资产 / 程序化源
  → Blender 后台导出 GLB
  → Manifest 与预算校验
  → Khronos glTF Validator
  → Godot 4.3 导入冒烟
  → 预览图、报告与资产目录
  → 可版本化 Art Pack
```

流水线只保留两级验收：

1. **机器验收**：可导出、可导入、无缺失引用、符合命名和预算；
2. **人工验收**：符合“凡尘山水·写意半写实”、正交镜头可读、境界层级正确。

## 目录

```text
art_pipeline/
├── fixtures/godot/            # 独立 Godot 导入夹具
├── manifests/                 # 每个正式资产一个 JSON 清单
├── reference/                 # 参考资料；AI 图只能进入 reference/ai
├── source/                    # DCC 源文件或可复现源脚本
├── tools/                     # 导出、校验、目录和打包脚本
├── tests/                     # 流水线脚本单元测试
├── runtime/                   # CI 生成的运行时资产，不直接手改
├── reports/                   # CI 生成的报告与预览
├── dist/                      # CI 生成的 Art Pack
└── toolchain.lock.json        # 工具链版本唯一来源
```

## 本地预检

无需 Blender：

```bash
python -m unittest discover -s art_pipeline/tests -v
python art_pipeline/tools/validate_manifest.py
```

具有 Blender 5.2.1 时，可执行完整样本：

```bash
mkdir -p art_pipeline/work/source/props
blender --background \
  --python art_pipeline/source/bootstrap/prop_pipeline_marker.py \
  -- --output art_pipeline/work/source/props/prop_pipeline_marker.blend

blender --background art_pipeline/work/source/props/prop_pipeline_marker.blend \
  --python art_pipeline/tools/blender/export_asset.py \
  -- --manifest art_pipeline/manifests/props/prop_pipeline_marker.json

blender --background art_pipeline/work/source/props/prop_pipeline_marker.blend \
  --python art_pipeline/tools/blender/render_preview.py \
  -- --manifest art_pipeline/manifests/props/prop_pipeline_marker.json
```

## 资产新增流程

1. 在 `source/` 添加源文件；大型 `.blend/.psd/.kra/.exr/.wav` 使用 Git LFS；
2. 在 `manifests/<kind>/` 添加资产 Manifest；
3. 提交 PR，流水线生成 GLB、预览、Khronos 报告、Godot 冒烟结果和 Art Pack；
4. 人工按照 `docs/art-direction/art-review-checklist.md` 审查；
5. 通过后合并。正式版本使用 `artpack-v*` 标签触发 Release。

## 约束

- `runtime/`、`reports/`、`dist/` 和 `work/` 均为生成目录；
- 不允许从游戏运行时代码读取 `.blend`、`.psd` 或生成图；
- 生成图不得直接成为正式 UI 文字、图标或最终贴图；
- 文件名使用小写英文 `snake_case`，版本由 Git 和 Art Pack 标签表达；
- P0 不引入资产审批状态机、数据库或常驻服务。
