<div align="center">

**服务器需维护者可联系 LINNA**

WeChat: 19391496561 | Telegram: @19391496561

</div>

# GTRHNS - Hide'n'Seek Match System

**CS 1.6 捉迷藏比赛管理系统**

[![AMX Mod X](https://img.shields.io/badge/AMX_Mod_X-1.8.3+-blue)]()
[![ReGameDLL](https://img.shields.io/badge/ReGameDLL-5.x-orange)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

Author: **LINNA**  
Version: 1.0.0

</div>

---

## 关于项目

GTRHNS 是一套为 CS 1.6 打造的完整捉迷藏（Hide'n'Seek）比赛管理插件，基于 AMX Mod X + ReGameDLL + ReAPI 构建。

项目由 **LINNA** 一人独立开发，灵感来源于 CS 1.6 HNS 社区的各种玩法。在参考了社区内多个优秀项目的设计思路后，结合自身服务器运营需求，打造出了一套功能完善、模式丰富的比赛系统。代码架构完全自主设计，所有核心模块均为原创实现。

### 开发历程

| 时间 | 里程碑 |
|------|--------|
| 2026.01 | 项目启动，完成核心框架设计，实现基础 HNS 玩法和训练模式 |
| 2026.02 | 开发统一菜单系统，支持 M 键 / 夜视仪快捷打开 |
| 2026.03 | 开发 Mix 混合赛核心流程，支持 MR 制和计时制 |
| 2026.03 | 开发 AI 自动报名分组系统，实现全自动比赛组织 |
| 2026.04 | 开发皮肤系统、权限管理系统、管理员分级体系 |
| 2026.04 | 新增公共模式、死亡竞赛模式、穿透系统 |
| 2026.05 | 新增回合制模式、点位积分模式、吸血鬼模式 |
| 2026.05 | 新增投降系统、逃跑惩罚、AFK 检测、队长选人 |
| 2026.06 | 新增 RTV 投票换图、观战者投票系统、独立积分系统 |
| 2026.06 | 全面代码审计，修复关键缺陷，优化稳定性 |
| 2026.07 | **v1.0.0 正式发布** |

---

## 游戏模式

系统内置 **9 种游戏模式**，覆盖从休闲到竞技的完整场景：

### 1. Mix 混合赛 (核心比赛模式)

最核心的比赛模式，支持 4 种子规则：

- **MR 制** — 双方各打 N 回合，累计 T 方存活时间，总时间少的队伍获胜。打平进入 OVERTIME
- **计时制 (Timer)** — T 方需在限定时间内存活到目标时间，存活则继续进攻，死亡则换边
- **决斗 (Duel)** — 1v1 对决模式
- **点位积分 (PointScap)** — T 进入指定区域得分，先达到目标分数的队伍获胜

### 2. 回合制 (Rounds)

先赢 N 局的队伍获胜。支持可选的半场换边机制，管理员可通过 `/rounds` 动态调整回合参数：

| 队伍人数 | 先赢几局 | 最大回合 |
|---------|---------|---------|
| 2v2 | 3 | 5 |
| 3v3 | 4 | 7 |
| 4v4 | 5 | 9 |
| 5v5 | 6 | 10 |

### 3. AI 自动报名系统

全自动比赛组织流程：

1. 玩家输入 `/join` 报名
2. 达到最低人数后自动开始拼刀分组
3. 拼刀获胜方优先选人（Snake Draft 交替选人）
4. 全员投票选择比赛模式（MR/Timer/点位积分/吸血/回合制）
5. 系统自动切换到对应地图并开始比赛
6. 换图后自动恢复队伍分组

### 4. 公共模式 (Pub)

休闲捉迷藏，启用闪光弹和烟雾弹，自动穿透，CT 全灭 T 后换边重生。

### 5. 死亡竞赛 (DM)

CT 击杀 T 后双方互换角色，击杀者回满血量，死亡后自动重生。

### 6. 飞升/点位积分 (Ascension)

T 进入预定义的点位区域停留足够时间即得分，点位有不同类型和分值，用彩色光束可视化显示。先达到目标分数的队伍获胜。

### 7. 吸血鬼模式 (Vampire)

初始双方各有配置分数，T 方占领点位扣 CT 分数，CT 击杀 T 也扣 T 分。对方分数归零则获胜。

### 8. 拼刀模式 (Knife)

纯刀战模式，自动平衡两队人数。支持队长拼刀（决定选人顺序）和队伍拼刀（决定地图选择权）。

### 9. 训练模式 (Training)

无敌 + USP + 钩爪 (`+hook`)，用于地图探索和战术练习。

---

## 核心玩法机制

### 捉迷藏规则 (HNS)

- **T（逃跑方）**: 刀 + 闪光弹 + 烟雾弹 + 无声脚步
- **CT（追击方）**: 刀 + HE 手雷（若有飞行手雷标记）
- T 被全部消灭 → CT 赢
- CT 全灭 → T 赢
- 可选 OneHP 模式（所有玩家只有 1 滴血）
- 最后一人闪光弹补充机制

### 穿透系统 (SemiClip)

队友之间可以互相穿透（半透明显示），避免拥挤地图中的卡位问题。支持：
- 自动模式（仅 Skill 地图生效）
- 强制开启/关闭
- 个人穿透开关（`/cpenoloff`）

### 投降系统 (Surrender)

Mix 模式下，发起者所在队伍全员同意后方可投降，有时间限制。

### 逃跑惩罚 (Deserter)

比赛中途逃跑自动扣 30 积分，禁赛时间指数级增长（基础 30 分钟 x 2^逃跑次数，最大 24 小时）。最低 3 回合或 5 分钟后触发。

---

## 配套插件

| 插件 | 功能 |
|------|------|
| HnsMatchSystem | 核心比赛系统（主控制器） |
| HnsMatchSkinSystem | 皮肤系统（T/CT/刀模型） |
| HnsMatchStats | 统计系统（击杀/伤害/跑动/连跳等） |
| HnsMatchStatsMysql | MySQL 统计存储 |
| HnsMatchPermSystem | 权限管理（VIP/管理员/服主） |
| HnsMatchRtv | RTV 地图投票换图 |
| HnsMatchWatcher | 观战者投票和管理系统 |
| HnsMatchChatmanager | 聊天管理 |
| HnsMatchFlyNade | 飞行手雷 |
| HnsMatchMaps | 地图池管理 |
| HnsMatchMapRules | 地图特殊规则（如击杀 Piranesi） |
| HnsMatchModeHud | 模式 HUD 显示 |
| HnsMatchOwnage | Ownage 音效提示 |
| HnsMatchPlayerInfo | 玩家信息显示 |
| HnsMatchSpectatorInfo | 观战信息 |
| HnsMatchTraining | 训练工具增强 |
| HnsMatchAITeams | AI 报名队伍管理 |
| HnsMatchTestBots | 测试机器人 |
| HnsMatchRecontrol | 重连控制 |
| HnsMatchServerCfg | 服务器配置 |
| team-semiclip | 穿透插件（独立 Fakemeta 实现） |
| hns_pointsys | 独立积分系统 |
| hns_jumpstats | 跳跃统计 |
| flash-notifier | 闪光弹通知 |

---

## 玩家命令

| 命令 | 说明 |
|------|------|
| `/menu` | 打开主菜单 |
| `/join` / `/unjoin` | AI 报名 / 取消 |
| `/rtv` / `/nominate` | 换图投票 / 提名地图 |
| `/points` / `/积分` / `/jf` | 查看积分 |
| `/model` / `/skin` | 皮肤选择 |
| `/cpenoloff` | 个人穿透开关 |
| `/knife` | 切换刀模型显示 |
| `/rounds` | 回合制设置（管理员） |
| `/pointsadmin` | 积分管理（管理员） |
| `/creatzone` / `/delzone` | 点位编辑（管理员） |

---

## 技术架构

### 模块化设计

```
HnsMatchSystem (核心)
├── modes/          — 游戏模式（每种模式独立 .inl）
│   ├── mode_mix.inl
│   ├── mode_rounds.inl
│   ├── mode_pub.inl
│   └── ...
├── gameplay/       — 玩法规则
│   ├── gameplay_hns.inc
│   ├── gameplay_training.inc
│   ├── gameplay_knife.inc
│   └── gameplay_ai_signup.inc
└── addition/       — 附加系统
    ├── hnsmenu.inc    — 统一菜单框架
    ├── semiclip.inc   — 穿透逻辑
    ├── surrender.inc  — 投降系统
    ├── deserter.inc   — 逃跑惩罚
    ├── afk.inc        — AFK 检测
    └── ...
```

### 事件驱动 (Forward 系统)

外部插件可通过监听 Forward 接入比赛生命周期：

| Forward | 触发时机 |
|---------|---------|
| `hns_match_finished` | 比赛结束（带获胜方参数） |
| `hns_match_start` | 比赛开始 |
| `hns_match_cancel` | 比赛取消 |
| `hns_round_start` | 回合开始 |
| `hns_round_end` | 回合结束 |

### HookChain 注册

- `RG_RoundEnd` — 回合结束
- `RG_CBasePlayer_Spawn` — 出生
- `RG_CBasePlayer_Killed` — 死亡
- `RG_PlayerBlind` — 闪光弹致盲
- `RG_PM_Move` — 钩爪物理
- `FM_ShouldCollide` — 穿透碰撞
- `FM_AddToFullPack` — 穿透半透明渲染

---

## 目录结构

```
scripting/
├── HnsMatchSystem.sma              — 核心主系统
├── HnsMatch*.sma                   — 配套插件（20+）
├── team-semiclip.sma               — 穿透插件
├── hns_pointsys.sma                — 积分系统
└── include/
    ├── hns-match/                   — 核心模块
    │   ├── globals.inc              — 全局变量/枚举/Forward
    │   ├── modes/                   — 游戏模式
    │   ├── gameplay/                — 玩法规则
    │   └── addition/                — 附加系统
    └── hns_matchsystem_*.inc        — 公开 API 头文件

configs/
├── plugins.ini                     — 插件加载列表
├── modules.ini                     — 模块加载列表
└── mixsystem/
    ├── matchsystem.cfg              — 主配置
    ├── hns-maps.ini                — 地图池
    ├── player_models.ini           — 玩家皮肤
    ├── admin_models.ini             — 管理员皮肤
    └── mode/                       — 各模式配置
        ├── match.cfg
        ├── public.cfg
        ├── knife.cfg
        └── ...
```

---

## 编译

1. 将 `scripting/` 目录放到 AMXX Mod X 的 `cstrike/addons/amxmodx/scripting/` 下
2. 确保 ReAPI、ReGameDLL、HamSandwich 等模块已安装
3. 执行编译：`amxxpc HnsMatchSystem.sma`
4. 将编译产物 `.amxx` 放到 `plugins/` 目录

---

## 依赖

| 依赖 | 说明 |
|------|------|
| AMX Mod X 1.8.3+ | 脚本引擎 |
| ReGameDLL 5.x | 游戏核心 |
| ReAPI | ReGameDLL API 接口 |
| ReUnion | 盗版服 SteamID 模拟 |
| HamSandwich | 实体 Hook |
| MySQL (可选) | 统计系统数据库 |

---

## 权限等级

| 等级 | Flags | 说明 |
|------|-------|------|
| 普通玩家 | 无 | 基础功能 |
| 辅助 | f+i | 辅助权限 |
| VIP | b | 踢人/换图/暂停 |
| 管理员 | d+e+f+i | +封禁/重开/换边 |
| 服主 | 全权限 | +权限发放/隐藏身份 |

---

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

---

<div align="center">

**服务器需维护者可联系 LINNA**

WeChat: 19391496561 | Telegram: @19391496561

</div>

**GTRHNS** — Built with passion for the HNS community.

</div>
