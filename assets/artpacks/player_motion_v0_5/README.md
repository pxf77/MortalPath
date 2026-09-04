# Player Motion Art Pack v0.5

本目录消费 `pxf77/MortalPath-Art` 的固定发布：

- 版本：`artpack-v0.5.0-player-motion-refinement`
- Release 目标提交：`cf54156051b1524863a8ad52514d8ebba3505f8a`
- 美术实现提交：`4bae9b47e6b95b97406f676441dfffd8938a9cb7`
- 运行时角色：`chr_player_qi_refining_refined_v0_5`

该包替换 v0.4 主角增量包；青岚谷环境、敌人、阵器和基础 VFX 继续从 `qinglan_v0_2` 读取。

## 运行时契约

- 骨架：`humanoid_v1_aux_v0_5`，包含 8 根衣摆、袖口和发束辅助骨骼；
- 移动：八个屏幕方向循环，以及起步、停止和 180° 急转动作；
- 受击：前、后、左、右四方向轻重受击；
- 材质：7 类绘画化 PBR 材质，内嵌 2K/1K 布料贴图；
- 飞剑：攻击有效帧逐帧校准，死亡动作包含法器坠落与落地；
- 战斗同步：仍由既有 `action_started` / `action_released` / `damage_received` / `died` 信号驱动。

动画只负责表现；移动、伤害、碰撞、无敌帧、AI 与关卡流转继续由游戏逻辑控制。
