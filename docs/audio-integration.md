# 初版修仙音效接入记录

日期：2026-09-02。候选版本：`mortalpath_cc0_m1_v0_1`。

## 交付范围

- 已下载 6 个原始压缩包到邻仓 `MortalPath-Art/source/audio/cc0_m1/archives/`，约 17 MiB。5 位作者、全部按源页面 CC0 标注采用，含官方零元下载的原始法术 WAV；没有使用付费试听或影视原声。
- 20 个成品：14 个已接入战斗，6 个预备资源。WAV 总计 1,089,520 字节，约 1.04 MiB；统一 48 kHz / 16-bit / mono、0.19–0.95 秒。
- 源包页面、许可全文、原包哈希、原始文件哈希与加工参数都有记录；见 [`CREDITS`](../assets/audio/cc0_m1/CREDITS.md) 和 [`manifest.json`](../assets/audio/cc0_m1/manifest.json)。
- 完整选材分析及暂缓国内素材名单在美术仓 `source/audio/cc0_m1/README.md`、`catalog.json`；本轮先采用来源说明更明确且已取得原包的候选，不因“免费”直接放行。

## 配置与表现

| 类别 | 处理与触发 |
| --- | --- |
| 御剑三段 | 三个金属＋破空变体，前摇后才出声；闪避取消前摇后无残留出剑声 |
| 青锋剑诀 | 保留剑鸣骨架，叠错开的两道风切；不作为激光声音 |
| 护体 / 承击 / 破阵 | 聚拢灵光、低金属共振、石屑崩裂分别制作 |
| 身法 / 受伤 / 死亡 | 干风切、闷实接触、失力散气；不用西式怪物叫声 |
| 敌人灵弹 | 真正生成飞行物时触发；筑基使用厚重低层配方，另保留通用灵弹备用 |
| 符箓邪修 | 已配置纸声后 120 ms 引燃，与筑基施法相同增益；不新增玩家符箓系统 |
| 五系法术预备 | 火爆燃、冰结晶、雷电裂、风流、土石；仅可调用资源，不新增元素伤害或技能玩法 |

`CombatAudio` 预加载资源，最多 8 声部、空闲优先复用，满载时轮换。成品峰值最高 -6 dBFS，播放增益最高 -14 dB；保留混音余量。`CombatFeedback` 对同类接触音实行 45 ms 合并。`M` 静音会停止尾音，重开销毁旧声部。

`.wav.import` 固定 `compress/mode=0`（PCM），避免引擎默认压缩策略变化影响短音效。当前精确基线为 Godot 4.7.2 stable。游戏不依赖美术仓、不运行合成器、不联网取声音。

## 验证证据

- 美术仓 26 项单元测试通过：含源包哈希、明确许可/证据、每个配方成员、路径穿越拒绝、损坏源拒绝、静音/超电平拒绝、重复构建一致性，以及版本锁和正式打包边界。
- 20 个成品均通过波形边界、格式、长度、峰值/RMS 与 SHA-256 校验；先构建到美术仓 runtime，再构建到游戏，两份 manifest 完全一致。
- Godot 4.7.2 的完整 headless 门禁覆盖规则、阶段流程、160 项反馈/音频检查及三轮正常输入撤离。
- 图形模式使用固定 60 FPS 的 161 项反馈测试，检查真实播放、静音、资源释放和事件时机。无界面仅验证资源与路由，不向 Dummy 声音服务提交播放；快速无界面播放对象滞留通过此边界处理。
- 先前 4.3 / 4.7 结果仅为历史证据；日常只跑 4.7.2，已移除旧版日志豁免。

本地生成证据（不作为运行时资源提交）：

- `build/audio-evidence/audition.mp4`：约 26 秒、20 个带标签音效，按实际游戏增益播放；区分已接入与预备。
- `build/audio-evidence/gameplay.mp4`：约 40 秒、1280×720 / 60 FPS，引擎录制三轮正常输入，均成功撤离且筑基仍存活；前两轮有声，第三轮静音。
- `build/audio-evidence/gameplay/input-runs.json`：每轮动作、命中、受伤与结算。
- `build/audio-evidence/godot47-headless/`、`godot43-headless/` 及 `feedback-graphical.log`：技术验证原始日志。

录制后检查：游戏录像全片峰值约 -18 dBFS；第三轮 28–36 秒片段为数字静音（FFmpeg 的 16-bit 检测下限 -91 dBFS）。音轨不是空轨，静音也不是只改了界面状态。

## 复现

```bash
# MortalPath 根目录
GODOT_BIN=/Applications/Godot_mono.app/Contents/MacOS/Godot bash scripts/validate-demo.sh
godot --path . --fixed-fps 60 --script res://tests/combat_feedback_runner.gd
godot --path . --script res://tests/audio_audition.gd

# MortalPath-Art 根目录；重建前先修改源配方，不手改游戏 WAV
python3 tools/build_audio_pack.py --check --output ../MortalPath/assets/audio/cc0_m1
python3 tools/build_audio_pack.py --output ../MortalPath/assets/audio/cc0_m1
```

## 尚待人工确认

技术分析和自动播放不能代替主观听审。请重点确认飞剑是否像实体法器、符箓纸质辨识度、冰火雷差异、护体与受伤是否混淆、筑基是否有压迫感，以及耳机/扬声器下的响度与疲劳。本轮不宣称“达到《凡人修仙传》原声质量”、完成 M1 人工签收或发布正式 Art Pack；代码和候选音效随 4.7.2 迁移提交。
