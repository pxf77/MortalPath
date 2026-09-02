# Demo 初版采样音效

已用 6 个 CC0 源包制作的 20 个 WAV 替换原程序合成声。候选版本 `mortalpath_cc0_m1_v0_1`，约 1.04 MiB；来源、作者、许可和修改说明见 [CREDITS](cc0_m1/CREDITS.md)，逐文件哈希及配方见 [manifest.json](cc0_m1/manifest.json)。

| 状态 | 资源与触发 |
| --- | --- |
| 已接入 | 御剑三段、剑诀：在前摇结束、实际释放时触发，取消前摇不会留下出剑声 |
| 已接入 | 护体展开、身法、命中、受伤、护体承击、闪避成功、阵眼破裂、死亡消散 |
| 已接入 | 现有符箓邪修的纸张＋引燃、筑基守阵者厚重施法：飞行物真正生成时触发 |
| 仅预备 | 通用灵弹备用、火/冰/雷/风/土法术；可经 `CombatAudio.play_cue()` 调用，但没有因此新增玩法 |

音效本体在 `cc0_m1/`，以 `preload` 纳入游戏资源；不依赖邻仓或网络。48 kHz、16-bit、单声道，无损 PCM 导入。最多 8 声部、同类接触音 45 ms 合并，`M` 静音并停止尾音，场景销毁清理播放。炼气和筑基施法保持相同增益，用材质密度区分。

原始 ZIP、许可快照、完整选材分析及可复现工具位于 MortalPath-Art 的 `source/audio/cc0_m1/` 与 `tools/build_audio_pack.py`。不要手工覆盖成品 WAV；在源配方修改后重建，并保留本目录的 `.wav.import` 设置。

## 验证与试听

```bash
GODOT_BIN=/Applications/Godot_mono.app/Contents/MacOS/Godot bash scripts/validate-demo.sh
godot --path . --fixed-fps 60 --script res://tests/combat_feedback_runner.gd
godot --path . --script res://tests/audio_audition.gd
```

Headless 验证素材、映射及事件，不向 Dummy 音频驱动提交播放；图形测试检查真实播放、静音及声部回收。试听脚本使用实际游戏增益并标记已接入/预备状态，不是关卡通关证据。

目前通过本地技术门禁，**人工听感确认仍待完成**；这不是正式 Art Pack 发布。没有使用《凡人修仙传》原声音轨、影视提取音频、付费包试听或授权不明的国内转载素材。详细验收见 [音效接入记录](../../docs/audio-integration.md)。
