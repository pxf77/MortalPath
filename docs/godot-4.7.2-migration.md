# Godot 4.7.2 迁移记录

日期：2026-09-02。唯一日常基线：**4.7.2 stable**，不自动追新；后续升级须另行完整回归。详见 [版本策略](godot-version-policy.md)。

## 工具链

- 本机编辑器及窗口已确认 `4.7.2.stable.mono.official.ed1daf0bf`。
- 编辑器 SHA-256：`8af3977b60d2c59802f7c8ff1914b3ca02a5e294f7381fc1104ee777e33cbbd8`。
- 匹配 .NET 导出模板 SHA-256：`92f8681e349ef1f90891b792da95e3b2b0bd1ed610b78018c58feb2d87e15a9d`，安装目录为 `~/Library/Application Support/Godot/export_templates/4.7.2.stable.mono`。
- 旧编辑器保留在 `~/Library/Caches/MortalPath/toolchains/backups/Godot-4.7-mono.app`；旧模板和历史验证证据未删除，不再作为本项目日常基线。
- 游戏 / 美术 CI 都读取版本锁，官方包校验后安装，不再使用 4.3 容器。

## 本地回归

| 验收 | 结果 |
| --- | --- |
| 旧缓存隔离后的冷导入 | 通过，使用 `--import` 等待完成 |
| 精确版本工具测试 / 日志门禁 | 7 / 9 项通过 |
| 全部 19 个 GDScript 解析、规则和场景流程 | 通过 |
| headless 反馈/音频 | 160 项通过 |
| 真实图形反馈/音频 | 161 项通过 |
| headless / 实时图形 / MovieWriter 正常输入 | 每组 3 轮撤离成功，筑基守阵修士保持存活 |
| 音频录像 | 全片峰值 -17.7 dBFS；第三轮 28–36 秒为数字静音 |
| 20 个音效逐项试听录制 | 25.98 秒；主观音色与响度仍待人工签收 |
| Linux x86_64 release 导出 | 通过；Linux 实际运行等待远端 CI |
| macOS universal release 导出 | 通过，使用 Apple 原生 ad-hoc 签名 |
| macOS 导出包独立启动 | 通过，不从源代码目录加载资源 |
| 邻仓美术 | 26 项单元测试、Blender → GLB → 预览 → Godot → Art Pack、20 个 WAV 哈希及独立重建通过 |

迁移时修正了三项工具链问题：macOS .NET 软链接启动路径、首次导入立即退出的清理竞态、macOS ARM 纹理导入配置。macOS 内置签名器生成的 DER 权限数据被当前系统 AMFI 拒绝；改用 Apple `codesign` 正常签名，未关闭系统安全校验。macOS 导出只在具备 Apple 签名工具的宿主执行，Linux CI 导出并启动 Linux 包。

原始证据位于 `build/m1-evidence/validation/`、`godot472-graphical/`、`godot472-realtime/` 和 `godot472-audition/`。日志没有脚本/引擎错误或泄漏；4.3 的旧日志豁免已删除。历史失败诊断和缓存只作排查证据，不代表最终门禁结果。

## 交付边界

本地回归不是远端 CI 结果。首次推送被 GitHub 拒绝：当前 OAuth 凭据缺少修改 workflow 文件所需的 `workflow` scope，远端 main 尚未更新。授权后须推送两仓并核对新提交的 GitHub Actions；不宣称尚未发生的远端验证通过。

本轮不创建发布标签，不宣称完成 M1 人工手感/听感签收，也不宣称 macOS Developer ID 公证或商店发布完成。
