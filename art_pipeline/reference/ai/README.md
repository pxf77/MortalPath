# AI Reference Only

该目录只能放置用于构图、气氛、材质或概念探索的生成式参考图。

每个参考资产应在同名 `.json` 中记录：

```json
{
  "generator": "工具或模型名称",
  "generated_at": "YYYY-MM-DD",
  "purpose": "参考用途",
  "license_note": "权利与使用边界说明",
  "approved_for_runtime": false
}
```

生成图不得直接进入 `runtime/`，其中的文字、数值、图标和错误境界设定不得进入正式游戏资产。
