# GTRHNS v5.0.0 - 更新公告

发布日期: 2026-07-06  
作者: LINNA

---

## 新增功能

### 回合制模式增强
- 新增"半场换边"开关，可在 /rounds 菜单中切换
- 关闭换边 = 公共模式风格，固定阵营先赢N局获胜
- 开启换边 = 标准比赛风格，半场互换阵营（默认行为）

### 独立积分系统 (hns_pointsys)
- 比赛结束后自动结算：获胜方每人 +10 分，输家不给分
- 积分通过 nvault 持久化存储（SteamID/IP 绑定）
- 玩家输入 /points 或 /积分 查看自己积分
- 管理员菜单 (/pointsadmin)：
  - 查看在线玩家积分排行
  - 直接选择玩家进行加分/扣分（+10/+50/+100/+500/-10/-50/-100）
  - 清零玩家积分（兑换皮肤后使用）
  - 一键清除所有玩家积分

### 穿透系统增强
- 比赛模式自动禁用地图投票和 RTV 投票选项
- 基于 hns_training_mode CVAR 检测比赛状态

---

## Bug 修复

### P0 严重 (4个)
| 修复 | 说明 |
|------|------|
| 回合制换边比分错误 | 换边后不再交换 A/B 分数，改用 g_isTeamTT 映射，比分始终正确 |
| 回合制菜单按键失效 | register_menucmd 补全 (1<<6)，"设置完成"按钮正常工作 |
| ChangeGameplay KNIFE 清理 | 新增 knife_disable_rules() 分支，切换模式时正确清理 |
| AI 报名分组人数溢出 | aisShowTeamsAssignment 限制只分配 g_iAISTotalPlayers 人 |

### P1 高优先级 (4个)
| 修复 | 说明 |
|------|------|
| sv_cheats 安全漏洞 | taskTrainingGiveUsp 改用 rg_give_item，不再开启 sv_cheats 1 |
| Pub 模式闪光弹覆盖 | 删除 loadMapCFG 后的 FLASH=1，Boost 地图闪光弹设置正常生效 |
| getUserInMatch 多模式 | 支持 Rounds/Ascension/Vamp 模式，不再仅认 Mix |
| Rounds 重连阵营 | 改用 g_iRoundsTotalPlayed 判断换边状态，重连玩家阵营分配正确 |

### P2 中优先级 (3个)
| 修复 | 说明 |
|------|------|
| MATCH_FINISH_POST 时序 | forward 移到 match_reset_data 之前，外部插件可正确读取比赛状态 |
| AI 拼刀断线清理 | 拼刀阶段玩家断线自动从队伍数组中移除 |
| BalanceKnifeTeams 判定 | 改为人数差 <=1 才认为平衡，5v1 不再误判为已平衡 |

---

## 涉及文件

- HnsMatchSystem.sma - 核心比赛系统
- hns_pointsys.sma - 积分系统（新增）
- team-semiclip.sma - 穿透系统
- mode_rounds.inl - 回合制模式
- mode_pub.inl - 公共模式
- mode_knife.inl - 拼刀模式
- gameplay_training.inc - 训练模式
- gameplay_knife.inc - 拼刀玩法
- gameplay_ai_signup.inc - AI 报名系统
- gameplay_knife.inc - KNIFE 玩法
- user.inc - 用户工具函数
- gameplays.inc - 玩法切换框架
