# Player Polish Art Pack v0.4

本目录消费 `pxf77/MortalPath-Art` 的固定发布：

- 版本：`artpack-v0.4.0-player-polish`
- Release 目标提交：`5923e0ccc217606341f2d4c0ccb50e5ec80db0a3`
- 美术实现提交：`3383041a6ea655d2c32ad75e617426b0605350bf`
- 运行时角色：`chr_player_qi_refining_polished_v0_4`

该包是对 `qinglan_v0_2` 的增量：敌人、环境、阵器和既有 VFX 继续从旧包读取，玩家角色改用本目录中的共享骨架动画资产。

## 运行时契约

- 骨架：`humanoid_v1`
- 动作：11 项
- PBR 材质：7 类
- 飞剑节点：`presentation_flying_sword`
- 剑尖采样节点：`presentation_flying_sword_tip`
- 战斗同步：由玩家已有 `action_started` / `action_released` 信号驱动

游戏仓只提交已验证的 GLB 和 Manifest，不提交 Blender 源文件。
