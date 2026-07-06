# GTRHNS - HNS Match System

Hide and Seek 比赛系统 (AMX Mod X / ReGameDLL)
Author: **LINNA**

## 功能

- 公共模式 / Mix比赛 / 回合制 / AI报名 / 拼刀 / 训练
- 穿透系统 (team-semiclip)
- 积分系统 (hns_pointsys)
- RTV 地图投票
- 观战/管理员系统
- 皮肤系统
- 统计系统 (MySQL)

## 目录结构

```
scripting/           - 插件源码 (.sma)
  include/
    hns-match/       - 核心模块
      addition/      - 附加功能 (AFK/投降/管理员/菜单等)
      gameplay/      - 游戏玩法 (HNS/训练/拼刀/AI报名)
      modes/         - 模式 (公共/Mix/回合制/DM/Vamp等)
    hns_matchsystem_*.inc - 公开 API
configs/             - 配置文件
  mixsystem/         - 比赛系统配置
    mode/            - 各模式配置
```

## 编译

将 scripting/ 目录放到 AMXX Mod X 的 cstrike/addons/amxmodx/scripting/ 下，使用 amxxpc 编译。

## 依赖

- AMX Mod X 1.8.3+
- ReGameDLL
- ReAPI
- ReUnion (盗版服)
- MySQL (统计功能可选)
