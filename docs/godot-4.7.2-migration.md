# Godot 4.7.2 迁移记录

日期：2026-09-02（本地迁移）、2026-09-03（远端回归收尾）。唯一日常基线：**4.7.2 stable**，不自动追新；后续升级须另行完整回归。详见 [版本策略](godot-version-policy.md)。

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
| Linux x86_64 release 导出 | 通过；导出包也已在远端 Linux CI 独立启动通过 |
| macOS universal release 导出 | 通过，使用 Apple 原生 ad-hoc 签名 |
| macOS 导出包独立启动 | 通过，不从源代码目录加载资源 |
| 邻仓美术 | 26 项单元测试、Blender → GLB → 预览 → Godot → Art Pack、20 个 WAV 哈希及独立重建通过 |

迁移时修正了三项工具链问题：macOS .NET 软链接启动路径、首次导入立即退出的清理竞态、macOS ARM 纹理导入配置。macOS 内置签名器生成的 DER 权限数据被当前系统 AMFI 拒绝；改用 Apple `codesign` 正常签名，未关闭系统安全校验。macOS 导出只在具备 Apple 签名工具的宿主执行，Linux CI 导出并启动 Linux 包。

原始证据位于 `build/m1-evidence/validation/`、`godot472-graphical/`、`godot472-realtime/` 和 `godot472-audition/`。日志没有脚本/引擎错误或泄漏；4.3 的旧日志豁免已删除。历史失败诊断和缓存只作排查证据，不代表最终门禁结果。

## 远端交付

GitHub `workflow` 授权已经生效，两个仓库的 `main` 均已推送。项目本地 Git 凭据配置改用已授权的 GitHub CLI，解决了旧钥匙串凭据优先造成的首次推送失败。

- [Godot checks #33652169813](https://github.com/pxf77/MortalPath/actions/runs/33652169813)：验证 `fa20268c7f91b926bd238ed55d4298e924bd50f5`，固定 4.7.2 导入、全部脚本解析、规则/流程、160 项反馈、3 轮正常输入及 Linux release 导出和独立启动通过。
- [Demo visual evidence #33652169798](https://github.com/pxf77/MortalPath/actions/runs/33652169798)：同一游戏提交的实时图形音频、7 张展示截图、GIF/总览图、161 项反馈测试、3 轮正常输入录像及录制音轨信号检查全部通过。录像和原始日志保存在该运行的 artifact 中。
- [Art Pipeline P0 #33649680982](https://github.com/pxf77/MortalPath-Art/actions/runs/33649680982)：美术提交 `1c0cf6b87f2d25414edc9db342ed92053709a3b0` 的 26 项测试、Blender/Khronos/Godot/Art Pack 四个任务全部通过。

图形 CI 首次运行暴露 Linux runner 没有 ALSA 声卡的问题，截图测试本身成功，但音频驱动初始化错误被严格日志门禁拦截。现为实时图形测试配置 PulseAudio 虚拟输出，并断言实际驱动不可降级；MovieWriter 单独验证录制音轨非静音且不削波。没有放宽错误门禁。本机新增驱动检查的正向测试（CoreAudio，161 项）和负向测试（拒绝 Dummy 降级）均通过。

重试期间还遇到 Ubuntu Azure 镜像下载超时；图形 CI 已改用 Ubuntu 官方主镜像（包括 runner 的独立镜像列表），限定网络超时/重试及依赖安装总时限。中途停滞或被新提交替代的运行已取消，最终验收以上述成功运行及其精确提交为准。本记录之后的纯文档提交不重复运行相同代码的 CI。

## 交付边界

本轮不创建发布标签，不宣称完成 M1 人工手感/听感签收，也不宣称 macOS Developer ID 公证或商店发布完成。
