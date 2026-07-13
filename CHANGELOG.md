# HNS Match System 更新日志

---

## v5.6.1 (2026-07-13) — AI 系统全面修复 + 训练工具模式限制

### 🔴 P0 严重修复

- **补全 AI 状态机**：新增 `aisTaskStateMachine` 轮询任务，自动推进状态转换
  - `AIS_KNIFE_PENDING` → `AIS_KNIFE_ACTIVE`（拼刀开始）
  - `AIS_KNIFE_ACTIVE` → `AIS_VOTE_MODE`（拼刀结束，进入投票）
  - `AIS_VOTE_MODE` → `AIS_LOCKED`（比赛开始，锁定）
  - `AIS_LOCKED` → `AIS_IDLE`（比赛结束，自动重置）
- **比赛结束自动重置 AI 系统**：检测到 `MATCH_NONE` 时自动调用 `aisCancel()`，确保下次报名正常启动
- **禁用旧 AI 插件 `HnsMatchAITeams.amxx`**：`/join` `/unjoin` 命令已内置到 `HnsMatchSystem.amxx`，避免两套系统命令冲突

### 🟠 P1 高优修复

- `aisAutoStartKnife` 加 **10 次重试上限**（约 30 秒），防止无限循环等待玩家
- `g_iAISSignedCount` 3 处递减加 **负数保护**
- `aisTaskTeamCheck` 中 `static iWaitCount` 改为 **全局变量** `g_iAISWaitCount`，避免任务重启后残留

### 🟡 P2 中优修复

- 报名人数奇偶截断后 `< 2` 人时自动取消报名
- 断线玩家数据清理：报名阶段清除 `AIS_SIGN_TIME`，队伍阶段递减 `g_iAISTotalPlayers`
- 阵营 HUD 任务只在 `AIS_KNIFE_PENDING/ACTIVE` 状态运行，防止泄漏

### 🛡️ 训练工具模式限制

- **14 个训练命令**（`/tr` `/cp` `/tp` `/gc` `/st` `/rp` `/clip` `/weap` `/sc` `/usp` `/awp` `/m4` `/flash` `/showdmg` `/ang`）**仅在训练模式下可用**
- 主菜单训练入口加模式检查，非训练模式显示灰色并提示 `[HNS] 训练工具仅在训练模式下可用！`
- 去掉暂停状态例外（比赛暂停时训练工具同样不可用）

---

## v5.6.0 (2026-07-12) — Switch Break 全面修复

### 🔴 P0 严重修复

- **`HnsMatchPermSystem.sma`**：12 个 switch 语句加 **60 处 break**，修复权限系统完全失效（所有用户权限为 0）
- **`HnsMatchSkinSystem.sma`**：约 30 个 switch 语句加 break，修复皮肤/队伍菜单混乱
- **`mode_ascension.inl` / `mode_vampire.inl`**：计分 switch 加 break，修复所有点位按 3 人点计分的问题
- **`HnsMatchAITeams.sma`**：模式名 switch 加 break，修复无论选什么模式都变成 duel 的问题
- **`pointscap_editor.inl`**：分数 switch 加 break，修复所有 zone 分数为 0.5 的问题
- **`HnsMatchPlayerInfo.sma`**：状态字符串 switch 加 break，修复所有状态显示为 "Wait players" 的问题

### 🔧 其他

- `HnsMatchAITeams.sma` 任务 ID 重构：使用固定常量替代动态任务 ID
- `HnsMatchSystem.sma` 主菜单训练入口加模式检查

---

## 版本说明

| 版本号规则 | 说明 |
|-----------|------|
| 主版本 (X) | 架构大改 |
| 次版本 (Y) | 新增功能 |
| 修订号 (Z) | Bug 修复 |

---

## 启动方式

```
CS 1.6 服务器
  → Metamod 加载 AMX Mod X
    → plugins.ini 按顺序加载：
      1. HnsMatchSystem.amxx    ← 核心调度器
      2. HnsMatchSkinSystem.amxx
      3. HnsMatchTraining.amxx  ← 已禁用（AI 系统已内置）
      4. HnsMatchStats.amxx
      5. 其他插件...
```

---

## 贡献者

- adasdw-23