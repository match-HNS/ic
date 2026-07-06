#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_dbmysql>
#include <hns_matchsystem_stats>
#include <hns_matchsystem_filter>

#define EOS 0

// ==================== 插件信息 ====================
#define PLUGIN_NAME "Match: AI Teams"
#define PLUGIN_VERSION "4.0.9"
#define PLUGIN_AUTHOR "LINNA"

// ==================== 任务ID常量 ====================
#define TASKID_SIGNUP            1001  // 报名倒计时循环任务
#define TASKID_SIGNUP_TIMEOUT    1002  // 报名超时一次性任务
#define TASKID_VOTE              1003  // 投票倒计时循环任务
#define TASKID_VOTE_TIMEOUT      1004  // 投票超时一次性任务
#define TASKID_PAUSE             1005  // 暂停倒计时循环任务
#define TASKID_RECOVERY_CHECK    1006  // 换图后重连检查任务

// ==================== 常量 ====================
#define MAX_PLAYERS 32
#define MAX_TEAMS 2
#define MAX_MAPS 256
#define MAX_MAP_NAME 32
#define MAX_STEAMID 24
#define MAX_IP 22

// AI状态
enum _:AI_STATE {
    AI_STATE_IDLE = 0,       // 空闲
    AI_STATE_SIGNUP,         // 报名中
    AI_STATE_GROUPING,       // 分组中
    AI_STATE_VOTING_MAPTYPE, // 地图类型投票中
    AI_STATE_VOTING_MODE,    // 模式投票中
    AI_STATE_VOTING_MAP,     // 地图投票中
    AI_STATE_SELECT_MAP,     // 选择地图方式（随机/管理员决定）
    AI_STATE_READY,          // 分组完成等待开始
    AI_STATE_LOCKED           // 锁定（比赛进行中）
};

// 队伍
enum _:AI_TEAM {
    AI_TEAM_A = 0,
    AI_TEAM_B
};

// 地图类型
enum _:MAP_TYPE {
    MAP_TYPE_NORMAL = 0,
    MAP_TYPE_BOOST,
    MAP_TYPE_SKILL
};

// 投票选项 - 地图类型
enum _:VOTE_MAP_TYPE {
    VOTE_MAPTYPE_RANDOM_BOOST = 0,
    VOTE_MAPTYPE_RANDOM_SKILL,
    VOTE_MAPTYPE_ADMIN_PICK,
    VOTE_MAPTYPE_CURRENT,
    VOTE_MAPTYPE_COUNT
};

// 投票选项 - 模式
enum _:VOTE_MODE {
    VOTE_MR = 0,
    VOTE_TIMER,
    VOTE_ASCENSION,
    VOTE_VAMPIRE,
    VOTE_ROUNDS,
    VOTE_DUEL,
    VOTE_RANDOM,        // 大随机模式（随机选模式+随机选地图）
    VOTE_MODE_COUNT
};

// 玩家数据
enum _:PLAYER_AI_DATA {
    bool:PAD_REGISTERED,      // 是否报名
    bool:PAD_IN_TEAM,         // 是否已分配队伍
    PAD_TEAM,                 // AI_TEAM_A 或 AI_TEAM_B
    PAD_SCORE,                // AI评分（整数，放大100倍）
    PAD_VOTE_MAPTYPE,         // 地图类型投票（-1=未投）
    PAD_VOTE_MODE,            // 模式投票（-1=未投）
    PAD_VOTE_MAP,             // 地图投票（-1=未投）
    PAD_JOIN_TIME,            // 报名时间（用于踢最后加入的）
    bool:PAD_IS_CAPTAIN,      // 是否指挥官
    PAD_IP_NUM                // IP数值（用于去重）
};

// 地图数据
enum _:MAP_DATA {
    MD_NAME[MAX_MAP_NAME],    // 地图名
    MD_TYPE,                  // MAP_TYPE
    bool:MD_ENABLED           // 是否启用
};

// ==================== 全局变量 ====================
new g_eAIState = AI_STATE_IDLE;
new g_iTeamSize = 6;              // 最大队伍人数（默认6v6）
new g_iMatchTeamSize = 6;         // 当前这场实际队伍人数
new g_iMinPlayers = 2;            // 最低报名人数
new g_iSignupTime = 60;           // 报名倒计时（秒）
new g_iSignupTimer;               // 报名倒计时任务ID
new g_iSignupTimeoutTask;            // 报名超时任务ID
new g_iSignupRemaining;           // 剩余时间
new g_iRefreshCount;              // AI刷新次数
new g_iMaxRefresh = 3;             // 最大刷新次数
new g_iVoteTime = 30;             // 投票时间
new g_iVoteTimer;                 // 投票任务ID
new g_iVoteTimeoutTask;            // 投票超时任务ID
new g_iVoteRemaining;             // 投票剩余时间

// 玩家数据
new g_ePlayers[MAX_PLAYERS + 1][PLAYER_AI_DATA];
new g_iRegisteredCount;
new g_szRegisteredIPs[MAX_PLAYERS + 1][MAX_IP];  // 用于IP去重

// ★ 恢复数据（换图后恢复玩家队伍分配）
// 盗版服用 IP+名字 做唯一标识，正版服用 SteamID
#define MAX_PLAYER_KEY 64  // IP(22) + Name(32) + 分隔符
new g_szRecoveryKeys[MAX_PLAYERS + 1][MAX_PLAYER_KEY];  // 待恢复的玩家唯一标识
new g_iRecoveryTeams[MAX_PLAYERS + 1];                 // 对应的队伍
new bool:g_bRecoveryCaptain[MAX_PLAYERS + 1];          // 是否为队长
new g_iRecoveryCount;                                   // 待恢复玩家数
new g_iRecoveryReconnected;                             // 已重连玩家数

// 30秒重连
new g_szDisconnectKey[MAX_PLAYERS + 1][MAX_PLAYER_KEY];
new g_szDisconnectTeam[MAX_PLAYERS + 1];
new g_szDisconnectTime[MAX_PLAYERS + 1];
new bool:g_bWasInMatch[MAX_PLAYERS + 1];
new bool:g_bDisconnectCaptain[MAX_PLAYERS + 1];
new g_iReconnectTimer[MAX_PLAYERS + 1];

// 队伍数据
new g_iTeamPlayers[MAX_TEAMS][MAX_PLAYERS + 1];    // 每队的玩家ID列表
new g_iTeamCount[MAX_TEAMS];                        // 每队人数
new g_iTeamScore[MAX_TEAMS];                        // 每队总分
new g_iCaptain[MAX_TEAMS];                           // 指挥官ID

// 投票数据
new g_iVoteMapTypeCount[VOTE_MAPTYPE_COUNT];
new g_iVoteModeCount[VOTE_MODE_COUNT];
new g_szAdminMap[MAX_MAP_NAME];                      // 管理员指定的地图
new g_iSelectedMapType;                              // 最终选中的地图类型
new g_iSelectedMode;                                 // 最终选中的模式
new g_szSelectedMap[MAX_MAP_NAME];                   // 最终选中的地图
new g_iFilteredModeCount;                            // 过滤后的模式数量
new bool:g_bModeVoteAll;                             // 是否正在使用6模式全投票
new g_iAdminMapMenuId;                               // 管理员地图菜单ID
new g_iAdminMapPage[MAX_PLAYERS + 1];                // 每个管理员当前的地图菜单页

// 地图数据
new g_eMaps[MAX_MAPS][MAP_DATA];
new g_iMapCount;

// HUD同步对象
new g_iHudSync;

// AI权重
new Float:g_flWeightPTS = 0.5;
new Float:g_flWeightWinRate = 0.3;
new Float:g_flWeightMatches = 0.2;

// MR/Timer配置
new g_iMR[6] = {0, 0, 0, 12, 15, 15};  // 索引=人数, 值=MR回合数 (2v2=0,3v3=12,4v4=15,5v5=15)
new Float:g_flTimer[6] = {0.0, 0.0, 0.0, 10.0, 15.0, 15.0};  // 索引=人数, 值=分钟

// 调试模式
new bool:g_bDebugMode = false;

// 状态保存
new g_szStateFile[128];

// 日志文件
new g_szLogFile[128];

// ==================== Native 过滤 ====================
// 当 HnsMatchStatsMysql.amxx 未加载时，使 hns_mysql_stats_* 原生函数变为可选依赖
new g_bMySQLAvailable = false;

public plugin_natives() {
    register_library("hns_aiteams_filter");
}

public plugin_native_filter(const szNativeName[], iNativeID, iTrapMode, pOrigHandler) {
    if (equal(szNativeName, "hns_mysql_stats_init") ||
        equal(szNativeName, "hns_mysql_stats_data") ||
        equal(szNativeName, "hns_mysql_stats_deduct_pts") ||
        equal(szNativeName, "hns_mysql_stats_get_ownage") ||
        equal(szNativeName, "hns_mysql_stats_set_ownage") ||
        equal(szNativeName, "hns_mysql_stats_skill")) {
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

// ==================== 插件初始化 ====================
public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    // 命令
    register_clcmd("hns_ai_join", "cmd_join");
    register_clcmd("hns_ai_unjoin", "cmd_unjoin");
    register_clcmd("hns_ai_menu", "cmd_ai_menu");
    register_clcmd("say /join", "cmd_join");
    register_clcmd("say_team /join", "cmd_join");
    register_clcmd("say /unjoin", "cmd_unjoin");
    register_clcmd("say_team /unjoin", "cmd_unjoin");
    register_clcmd("say /ai", "cmd_ai_menu");
    register_clcmd("say_team /ai", "cmd_ai_menu");
    register_clcmd("say /forcestart", "cmd_forcestart");
    register_clcmd("say_team /forcestart", "cmd_forcestart");
    register_clcmd("say /aiswap", "cmd_swap");
    register_clcmd("say_team /aiswap", "cmd_swap");

    // CVAR
    register_cvar("ai_team_size", "6");           // 最大队伍人数（默认6v6）
    register_cvar("ai_min_players", "2");          // 最低报名人数
    register_cvar("ai_signup_time", "60");         // 报名倒计时
    register_cvar("ai_vote_time", "30");            // 投票时间
    register_cvar("ai_max_refresh", "3");          // 最大刷新次数
    register_cvar("ai_debug", "0");               // 调试模式

    // HUD
    g_iHudSync = CreateHudSyncObj();

    // 加载配置
    load_maps();
    load_config();

    // 构建文件路径
    new szDate[32];
    get_time("%Y%m%d", szDate, charsmax(szDate));
    formatex(g_szLogFile, charsmax(g_szLogFile), "logs/ai_teams_%s.log", szDate);
    formatex(g_szStateFile, charsmax(g_szStateFile), "data/ai_match_state.txt");

    // 检查未完成的比赛
    check_recovery();
    
    // 注册额外命令
    register_extra_commands();

    // 注册菜单命令（show_menu 系统）
    register_menucmd(register_menuid("HnsAIMainMenu"), 1023, "menu_main_handle");
    register_menucmd(register_menuid("Vote MapType"), 1023, "menu_map_type_vote_handle");
    register_menucmd(register_menuid("Vote Mode"), 1023, "menu_mode_vote_handle");
    register_menucmd(register_menuid("HnsAIAdminMenu"), 1023, "menu_admin_handle");
    g_iAdminMapMenuId = register_menuid("HnsAIAdminMapMenu");
    register_menucmd(g_iAdminMapMenuId, 1023, "menu_admin_map_handle");

    // 地图选择方式菜单
    register_menucmd(register_menuid("Select Map Method"), 1023, "menu_select_map_handle");

    // 管理员指定地图命令
    register_concmd("amx_ai_map", "cmd_admin_map", ADMIN_BAN, "<mapname> - set AI match map");
}

public plugin_cfg() {
    // 读取CVAR
    g_iTeamSize = get_cvar_num("ai_team_size");
    g_iMatchTeamSize = g_iTeamSize;
    g_iMinPlayers = get_cvar_num("ai_min_players");
    g_iSignupTime = get_cvar_num("ai_signup_time");
    g_iVoteTime = get_cvar_num("ai_vote_time");
    g_iMaxRefresh = get_cvar_num("ai_max_refresh");
    g_bDebugMode = bool:get_cvar_num("ai_debug");
}

// ==================== 玩家连接/断开 ====================
public client_putinserver(id) {
    // 重置玩家数据
    arrayset(g_ePlayers[id], 0, sizeof(g_ePlayers[]));
    g_ePlayers[id][PAD_VOTE_MAPTYPE] = -1;
    g_ePlayers[id][PAD_VOTE_MODE] = -1;
    g_ePlayers[id][PAD_VOTE_MAP] = -1;
    
    // 获取IP用于去重
    get_user_ip(id, g_szRegisteredIPs[id], charsmax(g_szRegisteredIPs[]), 1);
    
    // ★ 换图后恢复玩家队伍分配
    if (g_eAIState == AI_STATE_LOCKED && g_iRecoveryCount > 0) {
        check_recovery_player(id);
    }
}

// ★ 检查玩家是否在恢复名单中，恢复队伍分配
check_recovery_player(id) {
    new szKey[MAX_PLAYER_KEY];
    get_player_key(id, szKey, charsmax(szKey));
    
    for (new i = 0; i < g_iRecoveryCount; i++) {
        if (g_szRecoveryKeys[i][0] == EOS) continue;  // 已处理
        
        if (equal(szKey, g_szRecoveryKeys[i])) {
            // 恢复队伍分配
            new TeamName:iTeam = g_iRecoveryTeams[i] == AI_TEAM_A ? TEAM_TERRORIST : TEAM_CT;
            rg_set_user_team(id, iTeam, MODEL_AUTO);
            
            g_ePlayers[id][PAD_IN_TEAM] = true;
            g_ePlayers[id][PAD_TEAM] = g_iRecoveryTeams[i];
            g_ePlayers[id][PAD_REGISTERED] = true;
            g_ePlayers[id][PAD_SCORE] = calculate_player_score(id);
            if (!is_player_in_team_list(id, g_iRecoveryTeams[i])) {
                g_iTeamPlayers[g_iRecoveryTeams[i]][g_iTeamCount[g_iRecoveryTeams[i]]] = id;
                g_iTeamCount[g_iRecoveryTeams[i]]++;
            }
            if (g_bRecoveryCaptain[i]) {
                g_iCaptain[g_iRecoveryTeams[i]] = id;
                g_ePlayers[id][PAD_IS_CAPTAIN] = true;
            }
            g_iRecoveryReconnected++;
            
            client_print(id, print_chat, "[AI Teams] 队伍已恢复! 你属于 Team %s.", 
                g_iRecoveryTeams[i] == AI_TEAM_A ? "A" : "B");
            
            // 标记已处理，防止重复
            g_szRecoveryKeys[i][0] = EOS;
            g_bRecoveryCaptain[i] = false;
            recalc_team_scores();
            return;
        }
    }
    
    // ★ 不在恢复名单中 → 强制观战
    rg_set_user_team(id, TEAM_SPECTATOR, MODEL_AUTO);
    client_print(id, print_chat, "[AI Teams] 当前是AI分组比赛，你已被设为观战者。");
}

// ★ 定时检查所有玩家是否已重连
public task_CheckAllPlayersReconnected() {
    if (g_iRecoveryReconnected >= g_iRecoveryCount) {
        remove_task(TASKID_RECOVERY_CHECK);
        client_print(0, print_chat, "[AI Teams] 所有 %d 名玩家已重连，比赛即将开始!", g_iRecoveryCount);
        set_task(2.0, "task_ExecMatchConfig");
    }
}

public client_disconnected(id) {
    new bool:bWasCaptain = g_ePlayers[id][PAD_IS_CAPTAIN];
    new iTeam = g_ePlayers[id][PAD_TEAM];

    // 如果玩家已报名，取消报名
    if (g_ePlayers[id][PAD_REGISTERED] && g_eAIState == AI_STATE_SIGNUP) {
        remove_player(id);
    }

    // 保存断线数据（用于30秒重连）
    save_disconnect_data(id);

    if (g_ePlayers[id][PAD_IN_TEAM]) {
        remove_team_member(id, true);
    }

    // 如果是指挥官且在比赛中
    if (bWasCaptain && g_eAIState == AI_STATE_LOCKED) {
        select_captain(iTeam);
    }
    // 重置数据
    arrayset(g_ePlayers[id], 0, sizeof(g_ePlayers[]));
    g_ePlayers[id][PAD_VOTE_MAPTYPE] = -1;
    g_ePlayers[id][PAD_VOTE_MODE] = -1;
    g_ePlayers[id][PAD_VOTE_MAP] = -1;
}

// ==================== 报名命令 (Toggle) ====================
public cmd_join(id) {
	// 如果已报名，执行取消逻辑
	if (g_ePlayers[id][PAD_REGISTERED]) {
		return cmd_unjoin(id);
	}

	if (g_eAIState != AI_STATE_SIGNUP && g_eAIState != AI_STATE_IDLE) {
		client_print(id, print_chat, "[AI Teams] Cannot join now.");
		return PLUGIN_HANDLED;
	}

	// 检查IP去重
	new szIp[MAX_IP];
	get_user_ip(id, szIp, charsmax(szIp), 1);
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (i != id && g_ePlayers[i][PAD_REGISTERED] && equal(g_szRegisteredIPs[i], szIp)) {
			client_print(id, print_chat, "[AI Teams] Same IP already registered.");
			return PLUGIN_HANDLED;
		}
	}

	// 如果是空闲状态，自动开启报名
	if (g_eAIState == AI_STATE_IDLE) {
		start_signup();
	}

	// 注册玩家
	g_ePlayers[id][PAD_REGISTERED] = true;
	g_ePlayers[id][PAD_JOIN_TIME] = get_systime();
	copy(g_szRegisteredIPs[id], charsmax(g_szRegisteredIPs[]), szIp);
	g_iRegisteredCount++;

	// 广播
	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	client_print(0, print_chat, "[AI Teams] ^3%n^1 报名成功! (%d/%d)", id, g_iRegisteredCount, g_iTeamSize * 2);
	
	// 个人确认 + HUD
	client_print(id, print_chat, "[AI Teams] 你已报名! 当前 %d/%d 人, 输入 /unjoin 取消报名", g_iRegisteredCount, g_iTeamSize * 2);
	set_hudmessage(0, 255, 0, -1.0, 0.35, 0, 0.0, 3.0, 0.2, 0.2, 2);
	show_hudmessage(id, "报名成功!^n%d/%d 人已报名", g_iRegisteredCount, g_iTeamSize * 2);

	// 检查是否够人
	check_signup_complete();

	return PLUGIN_HANDLED;
}

public cmd_unjoin(id) {
    if (!g_ePlayers[id][PAD_REGISTERED]) {
        client_print(id, print_chat, "[AI Teams] You are not registered.");
        return PLUGIN_HANDLED;
    }
    
    if (g_eAIState == AI_STATE_LOCKED || g_eAIState == AI_STATE_VOTING_MAPTYPE || g_eAIState == AI_STATE_VOTING_MODE || g_eAIState == AI_STATE_VOTING_MAP) {
        client_print(id, print_chat, "[AI Teams] Cannot leave during voting/match.");
        return PLUGIN_HANDLED;
    }
    
    remove_player(id);
    
    new szName[32];
    get_user_name(id, szName, charsmax(szName));
    client_print(0, print_chat, "[AI Teams] ^3%n^1 left. (%d/%d)", id, g_iRegisteredCount, g_iTeamSize * 2);
    
    return PLUGIN_HANDLED;
}

// ==================== 报名管理 ====================
start_signup() {
    g_eAIState = AI_STATE_SIGNUP;
    g_iRegisteredCount = 0;
    g_iRefreshCount = 0;
    g_iSignupRemaining = g_iSignupTime;
    g_iMatchTeamSize = g_iTeamSize;
    
    // 清空队伍数据
    for (new t = 0; t < MAX_TEAMS; t++) {
        g_iTeamCount[t] = 0;
        g_iTeamScore[t] = 0;
        g_iCaptain[t] = 0;
        arrayset(g_iTeamPlayers[t], 0, sizeof(g_iTeamPlayers[]));
    }
    
    // 清空投票
    arrayset(g_iVoteMapTypeCount, 0, sizeof(g_iVoteMapTypeCount));
    arrayset(g_iVoteModeCount, 0, sizeof(g_iVoteModeCount));
    
    client_print(0, print_chat, "[AI Teams] Signup started! Type ^3/join^1 to register. (%d seconds)", g_iSignupTime);
    
    // 开始倒计时
    remove_task(TASKID_SIGNUP);
    set_task(1.0, "task_signup_countdown", TASKID_SIGNUP, _, _, "b");
    g_iSignupTimer = TASKID_SIGNUP;
    set_task(float(g_iSignupTime), "task_signup_timeout", TASKID_SIGNUP_TIMEOUT);
    g_iSignupTimeoutTask = TASKID_SIGNUP_TIMEOUT;
}

public task_signup_countdown() {
    g_iSignupRemaining--;
    
    // 最后10秒每秒显示
    if (g_iSignupRemaining <= 10 && g_iSignupRemaining > 0) {
        set_hudmessage(255, 255, 0, -1.0, 0.1, 0, 0.0, 1.0, 0.0, 0.0);
        ShowSyncHudMsg(0, g_iHudSync, "Signup: %d seconds remaining | %d/%d registered", g_iSignupRemaining, g_iRegisteredCount, g_iTeamSize * 2);
    }
    
    // 更新报名HUD
    show_signup_hud();
    
    if (g_iSignupRemaining <= 0) {
        remove_task(TASKID_SIGNUP);
    }
}

public task_signup_timeout() {
    if (g_eAIState != AI_STATE_SIGNUP) return;
    
    if (g_iRegisteredCount < g_iMinPlayers) {
        client_print(0, print_chat, "[AI Teams] Not enough players. Signup cancelled.");
        cancel_signup();
        return;
    }
    
    // 自动调整人数
    adjust_team_size();
    
    // 开始分组
    perform_grouping();
}

check_signup_complete() {
    // 够人后不自动开始，等倒计时结束
    // 但如果已经达到最大人数，立即开始
    if (g_iRegisteredCount >= g_iTeamSize * 2) {
        remove_task(TASKID_SIGNUP);
        remove_task(TASKID_SIGNUP_TIMEOUT);
        adjust_team_size();
        perform_grouping();
    }
}

adjust_team_size() {
    // 自动调整队伍大小
    new iTotal = g_iRegisteredCount;
    
    // 奇数人最后一个观战
    if (iTotal % 2 != 0) iTotal--;
    
    // 不能超过管理员设定的人数
    if (iTotal / 2 > g_iTeamSize) iTotal = g_iTeamSize * 2;
    
    // 更新实际队伍大小，但不污染全局配置
    g_iMatchTeamSize = iTotal / 2;
    if (g_iMatchTeamSize < 1) g_iMatchTeamSize = 1;
}

cancel_signup() {
    g_eAIState = AI_STATE_IDLE;
    remove_task(TASKID_SIGNUP);
    g_iSignupTimer = 0;
    
    // 清空所有报名
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED]) {
            g_ePlayers[i][PAD_REGISTERED] = false;
            g_ePlayers[i][PAD_IN_TEAM] = false;
            g_ePlayers[i][PAD_TEAM] = 0;
            g_ePlayers[i][PAD_IS_CAPTAIN] = false;
        }
    }
    g_iRegisteredCount = 0;
    g_szAdminMap[0] = EOS;
}

remove_player(id) {
    g_ePlayers[id][PAD_REGISTERED] = false;
    g_ePlayers[id][PAD_IN_TEAM] = false;
    g_ePlayers[id][PAD_TEAM] = 0;
    g_ePlayers[id][PAD_IS_CAPTAIN] = false;
    g_iRegisteredCount--;
    if (g_iRegisteredCount < 0) g_iRegisteredCount = 0;
}

// ==================== 报名信息（聊天框显示）====================
show_signup_hud() {
    if (g_eAIState != AI_STATE_SIGNUP) return;
    
    // 聊天框显示报名状态
    client_print(0, print_chat, "[AI Teams] === Signup %d/%d ===", g_iRegisteredCount, g_iTeamSize * 2);
    
    new iCount;
    new szLine[128], iLineLen;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (!g_ePlayers[i][PAD_REGISTERED]) continue;
        
        new iPts = 1000;
        if (hns_mysql_stats_init()) {
            iPts = hns_mysql_stats_data(i, e_iPts);
        }
        
        new szEntry[64];
        formatex(szEntry, charsmax(szEntry), "%n[%d] ", i, iPts);
        
        if (iLineLen + strlen(szEntry) > 120) {
            client_print(0, print_chat, "[AI Teams] %s", szLine);
            iLineLen = 0;
            szLine[0] = EOS;
        }
        iLineLen += formatex(szLine[iLineLen], charsmax(szLine) - iLineLen, "%s", szEntry);
        iCount++;
    }
    if (szLine[0] != EOS) {
        client_print(0, print_chat, "[AI Teams] %s", szLine);
    }
}

// ==================== AI评分计算 ====================
calculate_player_score(id) {
    // PTS权重 50%
    new iPts = 1000;
    new Float:flPTS = 1000.0;
    if (hns_mysql_stats_init()) {
        iPts = hns_mysql_stats_data(id, e_iPts);
        flPTS = float(iPts);
    }
    
    // 加权胜率权重 30%
    new iWins = 0, iLoss = 0, iTotal = 0;
    new Float:flWinRate = 0.0;
    if (hns_mysql_stats_init()) {
        iWins = hns_mysql_stats_data(id, e_iWins);
        iLoss = hns_mysql_stats_data(id, e_iLoss);
        iTotal = iWins + iLoss;
    }
    if (iTotal > 0) {
        // 加权：min(场次, 50) / 50
        new Float:flWeight = floatmin(float(iTotal), 50.0) / 50.0;
        flWinRate = (float(iWins) / float(iTotal)) * flWeight;
    }
    
    // 场次权重 20%
    new Float:flMatches = floatmin(float(iTotal), 50.0) / 50.0 * 1000.0;
    
    // 新玩家默认500分
    if (iTotal == 0) {
        return 500;
    }
    
    // 综合评分
    new Float:flScore = flPTS * g_flWeightPTS + flWinRate * 1000.0 * g_flWeightWinRate + flMatches * g_flWeightMatches;
    
    return max(0, floatround(flScore));
}

// ==================== AI分组 ====================
perform_grouping() {
    g_eAIState = AI_STATE_GROUPING;

    for (new t = 0; t < MAX_TEAMS; t++) {
        g_iTeamCount[t] = 0;
        g_iTeamScore[t] = 0;
        g_iCaptain[t] = 0;
        arrayset(g_iTeamPlayers[t], 0, sizeof(g_iTeamPlayers[]));
    }
    
    // 收集所有报名玩家
    new iPlayers[MAX_PLAYERS], iCount;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED]) {
            iPlayers[iCount++] = i;
        }
    }
    
    // 奇数人最后一个不参与
    new iActiveCount = (iCount / 2) * 2;
    
    // 计算评分
    new iScores[MAX_PLAYERS];
    for (new i = 0; i < iActiveCount; i++) {
        iScores[i] = calculate_player_score(iPlayers[i]);
        g_ePlayers[iPlayers[i]][PAD_SCORE] = iScores[i];
    }
    
    // 按评分排序（冒泡排序）
    for (new i = 0; i < iActiveCount - 1; i++) {
        for (new j = i + 1; j < iActiveCount; j++) {
            if (iScores[j] > iScores[i]) {
                // 交换
                new temp = iScores[i]; iScores[i] = iScores[j]; iScores[j] = temp;
                temp = iPlayers[i]; iPlayers[i] = iPlayers[j]; iPlayers[j] = temp;
            }
        }
    }
    
    for (new i = 0; i < iActiveCount; i++) {
        new id = iPlayers[i];
        new iTeam;
        
        // 蛇形：1→A, 2→B, 3→B, 4→A, 5→A, 6→B, 7→B, 8→A...
        new iRound = i / g_iMatchTeamSize;
        new iPos = i % g_iMatchTeamSize;
        
        if (iRound % 2 == 0) {
            // 偶数轮：正序
            iTeam = (iPos % 2 == 0) ? AI_TEAM_A : AI_TEAM_B;
        } else {
            // 奇数轮：逆序
            iTeam = (iPos % 2 == 0) ? AI_TEAM_B : AI_TEAM_A;
        }
        
        // 分配
        g_ePlayers[id][PAD_IN_TEAM] = true;
        g_ePlayers[id][PAD_TEAM] = iTeam;
        g_iTeamPlayers[iTeam][g_iTeamCount[iTeam]] = id;
        g_iTeamCount[iTeam]++;
        g_iTeamScore[iTeam] += iScores[i];
    }

    for (new i = iActiveCount; i < iCount; i++) {
        new id = iPlayers[i];
        g_ePlayers[id][PAD_IN_TEAM] = false;
        g_ePlayers[id][PAD_IS_CAPTAIN] = false;
        g_ePlayers[id][PAD_SCORE] = 0;
    }
    
    // 选择指挥官
    select_captain(AI_TEAM_A);
    select_captain(AI_TEAM_B);
    
    // 显示分组结果
    show_grouping_result();
    
    // 写日志
    log_grouping();
    
    // 保存状态
    save_state();
    
    // 进入就绪状态
    g_eAIState = AI_STATE_READY;
    
    client_print(0, print_chat, "[AI Teams] Grouping complete! Use ^3/ai^1 for menu.");
    
    // Auto-start mode voting after 3 seconds
    set_task(3.0, "auto_start_vote");
}

select_captain(iTeam) {
    // 随机选一个指挥官
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B || g_iTeamCount[iTeam] == 0) return;
    new iOldCaptain = g_iCaptain[iTeam];
    
    // 取消旧指挥官
    if (iOldCaptain > 0) {
        g_ePlayers[iOldCaptain][PAD_IS_CAPTAIN] = false;
    }
    
    new iCandidates[MAX_PLAYERS], iCandidateCount;
    for (new i = 0; i < g_iTeamCount[iTeam]; i++) {
        new pid = g_iTeamPlayers[iTeam][i];
        if (!is_user_connected(pid) || !g_ePlayers[pid][PAD_IN_TEAM] || g_ePlayers[pid][PAD_TEAM] != iTeam) {
            continue;
        }
        iCandidates[iCandidateCount++] = pid;
    }

    if (!iCandidateCount) {
        g_iCaptain[iTeam] = 0;
        return;
    }

    // 设置新指挥官
    new id = iCandidates[random(iCandidateCount)];
    g_iCaptain[iTeam] = id;
    g_ePlayers[id][PAD_IS_CAPTAIN] = true;
    
    client_print(0, print_chat, "[AI Teams] %n is the captain of %s.", id, iTeam == AI_TEAM_A ? "Team A" : "Team B");
}

// ==================== 分组结果显示 ====================
show_grouping_result() {
    // 计算实力差距
    new iTotal = g_iTeamScore[AI_TEAM_A] + g_iTeamScore[AI_TEAM_B];
    new Float:flPctA = iTotal > 0 ? (float(g_iTeamScore[AI_TEAM_A]) / float(iTotal) * 100.0) : 50.0;
    new Float:flPctB = 100.0 - flPctA;
    new iDiff = abs(g_iTeamScore[AI_TEAM_A] - g_iTeamScore[AI_TEAM_B]);
    
    // 聊天框显示分组结果
    client_print(0, print_chat, "[AI Teams] === Grouping Result ===");
    client_print(0, print_chat, "[AI Teams] Balance: %.0f%% vs %.0f%% (diff: %d)", flPctA, flPctB, iDiff);
    
    // A队
    new szTeamA[128], szTeamB[128], iLenA, iLenB;
    iLenA += formatex(szTeamA, charsmax(szTeamA), "[Team A] %d: ", g_iTeamScore[AI_TEAM_A]);
    for (new i = 0; i < g_iTeamCount[AI_TEAM_A]; i++) {
        new id = g_iTeamPlayers[AI_TEAM_A][i];
        new iScore = g_ePlayers[id][PAD_SCORE];
        new szGrade[4];
        get_score_grade(iScore, szGrade, charsmax(szGrade));
        new szTag[8] = "";
        if (g_ePlayers[id][PAD_IS_CAPTAIN]) copy(szTag, charsmax(szTag), "[C]");
        iLenA += formatex(szTeamA[iLenA], charsmax(szTeamA) - iLenA, "%n%s[%s]%d ", id, szTag, szGrade, iScore);
    }
    client_print(0, print_chat, "[AI Teams] %s", szTeamA);
    
    // B队
    iLenB += formatex(szTeamB, charsmax(szTeamB), "[Team B] %d: ", g_iTeamScore[AI_TEAM_B]);
    for (new i = 0; i < g_iTeamCount[AI_TEAM_B]; i++) {
        new id = g_iTeamPlayers[AI_TEAM_B][i];
        new iScore = g_ePlayers[id][PAD_SCORE];
        new szGrade[4];
        get_score_grade(iScore, szGrade, charsmax(szGrade));
        new szTag[8] = "";
        if (g_ePlayers[id][PAD_IS_CAPTAIN]) copy(szTag, charsmax(szTag), "[C]");
        iLenB += formatex(szTeamB[iLenB], charsmax(szTeamB) - iLenB, "%n%s[%s]%d ", id, szTag, szGrade, iScore);
    }
    client_print(0, print_chat, "[AI Teams] %s", szTeamB);
}

get_score_grade(iScore, szGrade[], iLen) {
    if (iScore >= 1500) copy(szGrade, iLen, "S");
    else if (iScore >= 1200) copy(szGrade, iLen, "A");
    else if (iScore >= 900) copy(szGrade, iLen, "B");
    else if (iScore >= 600) copy(szGrade, iLen, "C");
    else copy(szGrade, iLen, "D");
}

// ==================== 强制开始 ====================
public cmd_forcestart(id) {
    // 检查权限（管理员或Watcher）
    if (!isUserAdmin(id) && !isUserWatcher(id) && !isUserFullWatcher(id)) {
        client_print(id, print_chat, "[AI Teams] Admin/Watcher only.");
        return PLUGIN_HANDLED;
    }
    
    if (g_eAIState == AI_STATE_LOCKED) {
        client_print(id, print_chat, "[AI Teams] Match already in progress.");
        return PLUGIN_HANDLED;
    }
    
    // 强制所有在线玩家报名
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "ch");
    
    for (new i = 0; i < iNum; i++) {
        new pid = iPlayers[i];
        if (!g_ePlayers[pid][PAD_REGISTERED]) {
            g_ePlayers[pid][PAD_REGISTERED] = true;
            g_ePlayers[pid][PAD_JOIN_TIME] = get_systime();
            get_user_ip(pid, g_szRegisteredIPs[pid], charsmax(g_szRegisteredIPs[]), 1);
            g_iRegisteredCount++;
        }
    }
    
    client_print(0, print_chat, "[AI Teams] ^3%n^1 强制开启! 所有在线玩家已自动报名.", id);
    
    // 跳过报名，直接分组
    adjust_team_size();
    perform_grouping();
    
    // 开始投票（先投地图类型）
    start_map_type_vote();
    
    return PLUGIN_HANDLED;
}

// ==================== AI菜单 ====================
public cmd_ai_menu(id) {
    show_main_menu(id);
    return PLUGIN_HANDLED;
}

show_main_menu(id) {
    new szMenu[512], iLen;
    
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\rAI Teams / AI分组系统^n^n");
    
    if (g_eAIState == AI_STATE_IDLE) {
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r1. Signup / 报名比赛^n");
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r2. Force Start / 强制开始^n");
    }
    else if (g_eAIState == AI_STATE_SIGNUP) {
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r1. Cancel Signup / 取消报名^n");
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r2. Start Now / 立即开始^n");
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r^n\r%d/%d registered", g_iRegisteredCount, g_iTeamSize * 2);
    }
    else if (g_eAIState == AI_STATE_READY) {
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r1. Refresh AI / 重新分组 (%d/3)^n", g_iRefreshCount);
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r2. Start Vote / 开始投票^n");
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r3. Start Match / 开始比赛^n");
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r4. Cancel / 取消^n");
    }
    else if (g_eAIState == AI_STATE_VOTING_MODE || g_eAIState == AI_STATE_VOTING_MAP) {
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\rVoting in progress...^n");
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d seconds remaining", g_iVoteRemaining);
    }
    else if (g_eAIState == AI_STATE_LOCKED) {
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\rMatch in progress^n");
    }
    
    // 管理员选项
    if (isUserAdmin(id) || isUserWatcher(id) || isUserFullWatcher(id)) {
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r^n\r9. Admin Settings / 管理设置^n");
    }
    
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r^n\r0. Exit / 退出");

    show_menu(id, 1023, szMenu, -1, "HnsAIMainMenu");
}

public menu_main_handle(id, key) {
    if (key == 9) return; // key 9 = 按键0 = Exit

    // key 0-8 对应按键 1-9
    if (g_eAIState == AI_STATE_IDLE) {
        if (key == 0) cmd_join(id);          // 1. Signup
        else if (key == 1) cmd_forcestart(id); // 2. Force Start
    }
    else if (g_eAIState == AI_STATE_SIGNUP) {
        if (key == 0) {                      // 1. Cancel Signup
            cancel_signup();
            client_print(0, print_chat, "[AI Teams] Signup cancelled.");
        }
        else if (key == 1) {                 // 2. Start Now
            remove_task(TASKID_SIGNUP);
            remove_task(TASKID_SIGNUP_TIMEOUT);
            adjust_team_size();
            perform_grouping();
        }
    }
    else if (g_eAIState == AI_STATE_READY) {
        if (key == 0) {                      // 1. Refresh AI
            if (g_iRefreshCount < g_iMaxRefresh) {
                g_iRefreshCount++;
                perform_grouping();
            } else {
                client_print(id, print_chat, "[AI Teams] Max refresh reached (%d).", g_iMaxRefresh);
            }
        }
        else if (key == 1) {                 // 2. Start Vote
            start_mode_vote_all();
        }
        else if (key == 2) {                 // 3. Start Match
            if (g_szSelectedMap[0] == EOS) {
                client_print(id, print_chat, "[AI Teams] 请先选择地图（随机地图或 amx_ai_map <地图名>）。");
            } else {
                show_final_result();
                set_task(2.0, "task_start_match");
            }
        }
        else if (key == 3) {                 // 4. Cancel
            cancel_signup();
        }
    }

    // 9. Admin Settings 对应按键 9，即 key == 8
    if (key == 8) {
        show_admin_menu(id);
    }
}

// ==================== 投票系统 ====================
public auto_start_vote() {
    if (g_eAIState == AI_STATE_READY) {
        start_mode_vote_all();
    }
}

// ==================== 地图类型投票 ====================
start_map_type_vote() {
    g_eAIState = AI_STATE_VOTING_MAPTYPE;
    g_iVoteRemaining = g_iVoteTime;
    arrayset(g_iVoteMapTypeCount, 0, sizeof(g_iVoteMapTypeCount));
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_ePlayers[i][PAD_VOTE_MAPTYPE] = -1;
    }
    
    show_map_type_vote_menu();
    
    remove_task(TASKID_VOTE);
    set_task(1.0, "task_vote_countdown", TASKID_VOTE, _, _, "b");
    g_iVoteTimer = TASKID_VOTE;
    set_task(float(g_iVoteTime), "task_vote_end", TASKID_VOTE_TIMEOUT);
    g_iVoteTimeoutTask = TASKID_VOTE_TIMEOUT;
}

show_map_type_vote_menu() {
    new szMenu[256], iLen;
    
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r投票地图类型^n^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r1. 随机Boost图^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r2. 随机技巧图^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r3. 管理指定地图: %s^n", g_szAdminMap[0] ? g_szAdminMap : "无");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r4. 当前地图^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r^n\r0. 退出");
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED]) {
            if (g_ePlayers[i][PAD_VOTE_MAPTYPE] >= 0) {
                client_print(i, print_chat, "[AI Teams] 你已经投过票了。");
                continue;
            }
            show_menu(i, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), szMenu, -1, "Vote MapType");
        }
    }
}

public menu_map_type_vote_handle(id, key) {
    if (key == 9 || key < 0 || key >= VOTE_MAPTYPE_COUNT) return;
    if (g_ePlayers[id][PAD_VOTE_MAPTYPE] >= 0) return;
    
    g_ePlayers[id][PAD_VOTE_MAPTYPE] = key;
    g_iVoteMapTypeCount[key]++;
    
    new iVoted;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED] && g_ePlayers[i][PAD_VOTE_MAPTYPE] >= 0) iVoted++;
    }
    
    if (iVoted >= g_iRegisteredCount) {
        remove_task(TASKID_VOTE);
        remove_task(TASKID_VOTE_TIMEOUT);
        task_vote_end();
    }
}

// ==================== 模式投票（按地图类型过滤） ====================
start_mode_vote_filtered() {
    g_eAIState = AI_STATE_VOTING_MODE;
    g_iVoteRemaining = g_iVoteTime;
    arrayset(g_iVoteModeCount, 0, sizeof(g_iVoteModeCount));
    g_bModeVoteAll = false;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_ePlayers[i][PAD_VOTE_MODE] = -1;
    }
    
    show_mode_vote_menu_filtered();
    
    remove_task(TASKID_VOTE);
    set_task(1.0, "task_vote_countdown", TASKID_VOTE, _, _, "b");
    g_iVoteTimer = TASKID_VOTE;
    set_task(float(g_iVoteTime), "task_vote_end", TASKID_VOTE_TIMEOUT);
    g_iVoteTimeoutTask = TASKID_VOTE_TIMEOUT;
}

start_mode_vote_all() {
    g_eAIState = AI_STATE_VOTING_MODE;
    g_iVoteRemaining = g_iVoteTime;
    arrayset(g_iVoteModeCount, 0, sizeof(g_iVoteModeCount));
    g_bModeVoteAll = true;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_ePlayers[i][PAD_VOTE_MODE] = -1;
    }
    
    show_mode_vote_menu_all();
    
    remove_task(TASKID_VOTE);
    set_task(1.0, "task_vote_countdown", TASKID_VOTE, _, _, "b");
    g_iVoteTimer = TASKID_VOTE;
    set_task(float(g_iVoteTime), "task_vote_end", TASKID_VOTE_TIMEOUT);
    g_iVoteTimeoutTask = TASKID_VOTE_TIMEOUT;
}

show_mode_vote_menu_all() {
    new szMenu[256], iLen;
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r投票游戏模式 [全部模式]^n^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r1. MR 模式^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r2. 计时模式^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r3. 突围模式 (点位积分)^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r4. 吸血模式 (点位扣除)^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r5. 单挑决斗 (1v1)^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r6. 回合制^n^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r0. 退出");
    
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9);
    g_iFilteredModeCount = 6;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED]) {
            if (g_ePlayers[i][PAD_VOTE_MODE] >= 0) {
                client_print(i, print_chat, "[AI Teams] 你已经投过票了。");
                continue;
            }
            show_menu(i, iKeys, szMenu, -1, "Vote Mode");
        }
    }
}

show_mode_vote_menu_filtered() {
    new szMenu[256], iLen;
    new iMapType = g_iSelectedMapType;
    
    // Boost地图: MR, Timer, Ascension, Vampire
    // 技巧地图: MR, Timer, Duel
    new bool:bIsBoost = (iMapType == VOTE_MAPTYPE_RANDOM_BOOST);
    
    new szType[32];
    if (iMapType == VOTE_MAPTYPE_RANDOM_BOOST) copy(szType, charsmax(szType), "Boost图");
    else if (iMapType == VOTE_MAPTYPE_RANDOM_SKILL) copy(szType, charsmax(szType), "技巧图");
    else if (iMapType == VOTE_MAPTYPE_ADMIN_PICK) copy(szType, charsmax(szType), "管理指定");
    else copy(szType, charsmax(szType), "当前地图");
    
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r投票游戏模式 [%s]^n^n", szType);
    
    new iKey = 1;
    new iKeys = 0;
    
    // MR（所有地图类型都可用）
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. MR 模式^n", iKey);
    iKeys |= (1<<(iKey-1));
    iKey++;
    
    // Timer（所有地图类型都可用）
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. 计时模式^n", iKey);
    iKeys |= (1<<(iKey-1));
    iKey++;
    
    if (bIsBoost) {
        // Boost图: Ascension + Vampire
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. 突围模式 (点位积分)^n", iKey);
        iKeys |= (1<<(iKey-1));
        iKey++;
        
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. 吸血模式 (点位扣除)^n", iKey);
        iKeys |= (1<<(iKey-1));
        iKey++;
    } else {
        // 技巧图: Duel + Rounds
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. 单挑决斗 (1v1)^n", iKey);
        iKeys |= (1<<(iKey-1));
        iKey++;
        
        iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. 回合制^n", iKey);
        iKeys |= (1<<(iKey-1));
        iKey++;
    }
    
    // ★ 大随机模式（所有地图类型都可用）
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r%d. \y大随机模式 \d(随机模式+随机地图)^n", iKey);
    iKeys |= (1<<(iKey-1));
    iKey++;
    
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r^n\r0. 退出");
    iKeys |= (1<<9);
    
    // 存储过滤后的模式映射
    // 如果Boost: 0=MR, 1=Timer, 2=Ascension, 3=Vampire
    // 如果Skill: 0=MR, 1=Timer, 2=Duel, 3=Rounds
    g_iFilteredModeCount = iKey - 1; // 模式数量（不含退出键）
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED]) {
            if (g_ePlayers[i][PAD_VOTE_MODE] >= 0) {
                client_print(i, print_chat, "[AI Teams] 你已经投过票了。");
                continue;
            }
            show_menu(i, iKeys, szMenu, -1, "Vote Mode");
        }
    }
}

public menu_mode_vote_handle(id, key) {
    if (key == 9) return; // 退出

    if (g_ePlayers[id][PAD_VOTE_MODE] >= 0) return;

    new iMode;

    if (g_bModeVoteAll) {
        // 6模式全投票：key 0-5 直接对应 6 个模式
        new iAllModes[] = {VOTE_MR, VOTE_TIMER, VOTE_ASCENSION, VOTE_VAMPIRE, VOTE_DUEL, VOTE_ROUNDS};
        if (key >= 0 && key < sizeof(iAllModes)) iMode = iAllModes[key];
        else return;
    } else {
        // key 0-4 → 对应过滤后的模式
        // Boost: 0=MR, 1=Timer, 2=Ascension, 3=Vampire, 4=大随机
        // Skill: 0=MR, 1=Timer, 2=Duel, 3=Rounds, 4=大随机
        new bool:bIsBoost = (g_iSelectedMapType == VOTE_MAPTYPE_RANDOM_BOOST);
        if (key == 4) {
            iMode = VOTE_RANDOM;
        } else if (bIsBoost) {
            new iBoostModes[] = {VOTE_MR, VOTE_TIMER, VOTE_ASCENSION, VOTE_VAMPIRE};
            if (key >= 0 && key < sizeof(iBoostModes)) iMode = iBoostModes[key];
            else return;
        } else {
            new iSkillModes[] = {VOTE_MR, VOTE_TIMER, VOTE_DUEL, VOTE_ROUNDS};
            if (key >= 0 && key < sizeof(iSkillModes)) iMode = iSkillModes[key];
            else return;
        }
    }

    g_ePlayers[id][PAD_VOTE_MODE] = iMode;
    g_iVoteModeCount[iMode]++;
    
    new iVoted;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED] && g_ePlayers[i][PAD_VOTE_MODE] >= 0) iVoted++;
    }
    
    if (iVoted >= g_iRegisteredCount) {
        remove_task(TASKID_VOTE);
        remove_task(TASKID_VOTE_TIMEOUT);
        task_vote_end();
    }
}

task_vote_countdown() {
    g_iVoteRemaining--;
    
    if (g_iVoteRemaining <= 10 && g_iVoteRemaining > 0) {
        set_hudmessage(255, 255, 0, -1.0, 0.1, 0, 0.0, 1.0);
        ShowSyncHudMsg(0, g_iHudSync, "投票倒计时: %d 秒", g_iVoteRemaining);
    }
}

public task_vote_end() {
    if (g_eAIState == AI_STATE_VOTING_MAPTYPE) {
        // 地图类型投票结束
        new iMax = 0, iWinner = 0;
        for (new i = 0; i < VOTE_MAPTYPE_COUNT; i++) {
            if (g_iVoteMapTypeCount[i] > iMax) {
                iMax = g_iVoteMapTypeCount[i];
                iWinner = i;
            }
        }
        
        new iTies;
        for (new i = 0; i < VOTE_MAPTYPE_COUNT; i++) {
            if (g_iVoteMapTypeCount[i] == iMax) iTies++;
        }
        
        if (iTies > 1) {
            client_print(0, print_chat, "[AI Teams] 地图类型投票平票! 重新投票...");
            start_map_type_vote();
            return;
        }
        
        g_iSelectedMapType = iWinner;
        
        new szMapTypes[VOTE_MAPTYPE_COUNT][] = {"随机Boost图", "随机技巧图", "管理指定地图", "当前地图"};
        client_print(0, print_chat, "[AI Teams] 地图类型: ^3%s^1", szMapTypes[iWinner]);
        
        // 确定地图
        if (iWinner == VOTE_MAPTYPE_RANDOM_BOOST) {
            get_random_map(MAP_TYPE_BOOST, g_szSelectedMap, charsmax(g_szSelectedMap));
        } else if (iWinner == VOTE_MAPTYPE_RANDOM_SKILL) {
            get_random_map(MAP_TYPE_SKILL, g_szSelectedMap, charsmax(g_szSelectedMap));
        } else if (iWinner == VOTE_MAPTYPE_ADMIN_PICK) {
            if (g_szAdminMap[0] != EOS)
                copy(g_szSelectedMap, charsmax(g_szSelectedMap), g_szAdminMap);
            else
                get_mapname(g_szSelectedMap, charsmax(g_szSelectedMap));
        } else {
            get_mapname(g_szSelectedMap, charsmax(g_szSelectedMap));
        }
        
        client_print(0, print_chat, "[AI Teams] 地图: ^3%s^1", g_szSelectedMap);
        
        // 开始模式投票
        start_mode_vote_filtered();
    }
    else if (g_eAIState == AI_STATE_VOTING_MODE) {
        // 模式投票结束
        new iMax = 0, iWinner = 0;
        for (new i = 0; i < VOTE_MODE_COUNT; i++) {
            if (g_iVoteModeCount[i] > iMax) {
                iMax = g_iVoteModeCount[i];
                iWinner = i;
            }
        }
        
        new iTies;
        for (new i = 0; i < VOTE_MODE_COUNT; i++) {
            if (g_iVoteModeCount[i] == iMax) iTies++;
        }
        
        if (iTies > 1) {
            client_print(0, print_chat, "[AI Teams] 模式投票平票! 重新投票...");
            start_mode_vote_filtered();
            return;
        }
        
        g_iSelectedMode = iWinner;
        
        // ★ 大随机模式：随机选模式 + 随机选地图
        if (iWinner == VOTE_RANDOM) {
            new bool:bIsBoost = (g_iSelectedMapType == VOTE_MAPTYPE_RANDOM_BOOST);
            new iRandomMode;
            
            if (bIsBoost) {
                // Boost图: MR, Timer, Ascension, Vampire, Rounds（排除Duel）
                new iPool[] = {VOTE_MR, VOTE_TIMER, VOTE_ASCENSION, VOTE_VAMPIRE, VOTE_ROUNDS};
                iRandomMode = iPool[random(sizeof(iPool))];
            } else {
                // 技巧图: MR, Timer（排除Duel, Rounds）
                new iPool[] = {VOTE_MR, VOTE_TIMER};
                iRandomMode = iPool[random(sizeof(iPool))];
            }
            
            g_iSelectedMode = iRandomMode;
            
            // ★ 重新随机选地图
            new iMapType = bIsBoost ? MAP_TYPE_BOOST : MAP_TYPE_SKILL;
            get_random_map(iMapType, g_szSelectedMap, charsmax(g_szSelectedMap));
            
            new szRandomModes[] = {"MR", "Timer", "Ascension", "Vampire", "Rounds", "Duel"};
            client_print(0, print_chat, "[AI Teams] 大随机! 模式: ^3%s^1, 地图: ^4%s^1", 
                szRandomModes[iRandomMode], g_szSelectedMap);
        } else {
            new szModes[VOTE_MODE_COUNT][] = {"MR", "Timer", "Ascension", "Vampire", "Rounds", "Duel", "随机"};
            client_print(0, print_chat, "[AI Teams] 模式: ^3%s^1", szModes[iWinner]);
        }

        // 投票完成
        if (g_bModeVoteAll) {
            // ★ 6模式全投票：弹出地图选择方式菜单（随机地图 / 管理员决定）
            g_eAIState = AI_STATE_SELECT_MAP;
            show_select_map_method_menu();
        } else {
            g_eAIState = AI_STATE_READY;
            show_final_result();
            set_task(2.0, "task_start_match");
        }
    }
}

show_select_map_method_menu() {
    new szMenu[256], iLen;
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r选择地图方式^n^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. 随机地图^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. 管理员决定^n^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. 返回");

    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_REGISTERED] && is_user_connected(i)) {
            show_menu(i, (1<<0)|(1<<1)|(1<<9), szMenu, -1, "Select Map Method");
        }
    }
}

public menu_select_map_handle(id, key) {
    if (key == 9) {
        // 返回主菜单
        g_eAIState = AI_STATE_READY;
        show_main_menu(id);
        return;
    }

    if (g_eAIState != AI_STATE_SELECT_MAP) return;

    if (key == 0) {
        // 随机地图
        SelectRandomMapByMode();
        g_eAIState = AI_STATE_READY;
        show_final_result();
        set_task(2.0, "task_start_match");
    } else if (key == 1) {
        // 管理员决定：返回 /ai 主菜单，让管理员自己换图
        g_eAIState = AI_STATE_READY;
        client_print(0, print_chat, "[AI Teams] 地图选择交给管理员，使用 /ai 菜单或 amx_ai_map <地图名> 指定地图。");
        show_main_menu(id);
    }
}

stock SelectRandomMapByMode() {
    if (g_szAdminMap[0] != EOS) {
        // 管理员已指定地图，优先使用
        copy(g_szSelectedMap, charsmax(g_szSelectedMap), g_szAdminMap);
        g_iSelectedMapType = VOTE_MAPTYPE_ADMIN_PICK;
        for (new i = 0; i < g_iMapCount; i++) {
            if (equal(g_eMaps[i][MD_NAME], g_szAdminMap)) {
                if (g_eMaps[i][MD_TYPE] == MAP_TYPE_BOOST)
                    g_iSelectedMapType = VOTE_MAPTYPE_RANDOM_BOOST;
                else if (g_eMaps[i][MD_TYPE] == MAP_TYPE_SKILL)
                    g_iSelectedMapType = VOTE_MAPTYPE_RANDOM_SKILL;
                break;
            }
        }
        client_print(0, print_chat, "[AI Teams] 使用管理员指定地图: ^3%s^1", g_szSelectedMap);
    } else {
        // MR/Timer → 随机 skill 或 boost 图；Duel → 随机 skill 图；Ascension/Vampire/Rounds → 随机 boost 图
        if (g_iSelectedMode == VOTE_MR || g_iSelectedMode == VOTE_TIMER) {
            new iValid[MAX_MAPS], iValidCount;
            for (new i = 0; i < g_iMapCount; i++) {
                if (g_eMaps[i][MD_ENABLED] && (g_eMaps[i][MD_TYPE] == MAP_TYPE_SKILL || g_eMaps[i][MD_TYPE] == MAP_TYPE_BOOST)) {
                    iValid[iValidCount++] = i;
                }
            }
            if (iValidCount > 0) {
                new iPick = random(iValidCount);
                copy(g_szSelectedMap, charsmax(g_szSelectedMap), g_eMaps[iValid[iPick]][MD_NAME]);
                g_iSelectedMapType = (g_eMaps[iValid[iPick]][MD_TYPE] == MAP_TYPE_BOOST) ? VOTE_MAPTYPE_RANDOM_BOOST : VOTE_MAPTYPE_RANDOM_SKILL;
            } else {
                get_mapname(g_szSelectedMap, charsmax(g_szSelectedMap));
                g_iSelectedMapType = VOTE_MAPTYPE_CURRENT;
            }
        } else if (g_iSelectedMode == VOTE_DUEL) {
            g_iSelectedMapType = VOTE_MAPTYPE_RANDOM_SKILL;
            get_random_map(MAP_TYPE_SKILL, g_szSelectedMap, charsmax(g_szSelectedMap));
        } else {
            g_iSelectedMapType = VOTE_MAPTYPE_RANDOM_BOOST;
            get_random_map(MAP_TYPE_BOOST, g_szSelectedMap, charsmax(g_szSelectedMap));
        }
        client_print(0, print_chat, "[AI Teams] 自动选图: ^3%s^1", g_szSelectedMap);
    }
}

// ==================== 实际启动比赛 ====================
public task_start_match() {
    if (g_eAIState != AI_STATE_READY) return;
    
    // ★ 设置比赛进行中状态
    g_eAIState = AI_STATE_LOCKED;
    
    new szModeName[16];
    switch (g_iSelectedMode) {
        case VOTE_MR:        { copy(szModeName, charsmax(szModeName), "mr"); }
        case VOTE_TIMER:     { copy(szModeName, charsmax(szModeName), "timer"); }
        case VOTE_ASCENSION: { copy(szModeName, charsmax(szModeName), "ascension"); }
        case VOTE_VAMPIRE:   { copy(szModeName, charsmax(szModeName), "vampire"); }
        case VOTE_ROUNDS:    { copy(szModeName, charsmax(szModeName), "rounds"); }
        case VOTE_DUEL:      { copy(szModeName, charsmax(szModeName), "duel"); }
    }
    
    client_print(0, print_chat, "[AI Teams] 比赛启动! 模式: %s, 地图: %s", szModeName, g_szSelectedMap);
    
    // ★ 保存比赛状态到文件（换图后恢复用）
    save_state();
    
    // ★ 写入配置文件，换图后自动执行
    new szCfgFile[256];
    get_configsdir(szCfgFile, charsmax(szCfgFile));
    add(szCfgFile, charsmax(szCfgFile), "/hns_ai_match_start.cfg");
    
    new f = fopen(szCfgFile, "wt");
    if (f) {
        fprintf(f, "// AI Teams auto-start config^n");
        fprintf(f, "hns_match_mode %s^n", szModeName);
        fprintf(f, "hns_auto_start 1^n");
        fclose(f);
    }
    
    // 换图
    server_cmd("changelevel %s", g_szSelectedMap);
}

// ==================== 地图工具 ====================
get_random_map(iType, szOutput[], iLen) {
    new iValid[MAX_MAPS], iValidCount;
    
    for (new i = 0; i < g_iMapCount; i++) {
        if (g_eMaps[i][MD_ENABLED] && g_eMaps[i][MD_TYPE] == iType) {
            iValid[iValidCount++] = i;
        }
    }
    
    if (iValidCount == 0) {
        // 没有该类型的地图，返回当前地图
        get_mapname(szOutput, iLen);
        return;
    }
    
    new iRandom = random(iValidCount);
    copy(szOutput, iLen, g_eMaps[iValid[iRandom]][MD_NAME]);
}

// ==================== Swap命令 ====================
public cmd_swap(id) {
    if (!isUserAdmin(id) && !isUserWatcher(id) && !isUserFullWatcher(id)) {
        client_print(id, print_chat, "[AI Teams] Admin/Watcher only.");
        return PLUGIN_HANDLED;
    }
    
    if (g_eAIState != AI_STATE_READY) {
        client_print(id, print_chat, "[AI Teams] Can only swap during ready phase.");
        return PLUGIN_HANDLED;
    }
    
    new szArg1[32], szArg2[32];
    read_argv(1, szArg1, charsmax(szArg1));
    read_argv(2, szArg2, charsmax(szArg2));
    
    if (szArg1[0] == EOS || szArg2[0] == EOS) {
        client_print(id, print_chat, "[AI Teams] Usage: /swap <name1> <name2>");
        return PLUGIN_HANDLED;
    }
    
    new iTarget1 = cmd_target(id, szArg1, CMDTARGET_OBEY_IMMUNITY);
    new iTarget2 = cmd_target(id, szArg2, CMDTARGET_OBEY_IMMUNITY);
    
    if (iTarget1 == 0 || iTarget2 == 0) {
        client_print(id, print_chat, "[AI Teams] Player not found.");
        return PLUGIN_HANDLED;
    }
    
    if (!g_ePlayers[iTarget1][PAD_IN_TEAM] || !g_ePlayers[iTarget2][PAD_IN_TEAM]) {
        client_print(id, print_chat, "[AI Teams] Both players must be in teams.");
        return PLUGIN_HANDLED;
    }
    
    new iTempTeam = g_ePlayers[iTarget1][PAD_TEAM];
    g_ePlayers[iTarget1][PAD_TEAM] = g_ePlayers[iTarget2][PAD_TEAM];
    g_ePlayers[iTarget2][PAD_TEAM] = iTempTeam;
    
    recalc_team_scores();
    
    client_print(0, print_chat, "[AI Teams] ^3%n^1 and ^3%n^1 swapped.", iTarget1, iTarget2);
    show_grouping_result();
    
    return PLUGIN_HANDLED;
}

recalc_team_scores() {
    g_iTeamScore[AI_TEAM_A] = 0;
    g_iTeamScore[AI_TEAM_B] = 0;
    g_iTeamCount[AI_TEAM_A] = 0;
    g_iTeamCount[AI_TEAM_B] = 0;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (!g_ePlayers[i][PAD_IN_TEAM]) continue;
        
        new iTeam = g_ePlayers[i][PAD_TEAM];
        new iScore = g_ePlayers[i][PAD_SCORE];
        if (iScore <= 0) {
            iScore = calculate_player_score(i);
            g_ePlayers[i][PAD_SCORE] = iScore;
        }
        g_iTeamScore[iTeam] += iScore;
        g_iTeamPlayers[iTeam][g_iTeamCount[iTeam]] = i;
        g_iTeamCount[iTeam]++;
    }
}

// ==================== 管理员菜单 ====================
show_admin_menu(id) {
    new szMenu[512], iLen;
    
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\rAdmin Settings / 管理设置^n^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r1. Team Size: %dv%d^n", g_iTeamSize, g_iTeamSize);
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r2. Signup Time: %ds^n", g_iSignupTime);
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r3. Min Players: %d^n", g_iMinPlayers);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. Set Admin Map: %s^n", g_szAdminMap[0] ? g_szAdminMap : "无");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r5. Toggle Debug^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r6. Rounds Config / 回合设置^n");
    iLen += format(szMenu[iLen], sizeof(szMenu) - iLen, "\r^n\r0. Back");

    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), szMenu, -1, "HnsAIAdminMenu");
}

public menu_admin_handle(id, key) {
    if (key == 9) {
        show_main_menu(id);
        return;
    }

    if (key == 0) {
        g_iTeamSize = g_iTeamSize >= 6 ? 1 : g_iTeamSize + 1;
        show_admin_menu(id);
    }
    else if (key == 1) {
        g_iSignupTime = g_iSignupTime >= 120 ? 30 : g_iSignupTime + 15;
        show_admin_menu(id);
    }
    else if (key == 2) {
        g_iMinPlayers = g_iMinPlayers >= 10 ? 1 : g_iMinPlayers + 1;
        show_admin_menu(id);
    }
    else if (key == 3) {
        g_iAdminMapPage[id] = 0;
        show_admin_map_menu(id, 0);
    }
    else if (key == 4) {
        g_bDebugMode = !g_bDebugMode;
        client_print(id, print_chat, "[AI Teams] Debug %s.", g_bDebugMode ? "ON" : "OFF");
        show_admin_menu(id);
    }
    else if (key == 5) {
        client_cmd(id, "say /rounds");
    }
}

show_admin_map_menu(id, iPage) {
    if (!is_user_connected(id)) return;

    new iPerPage = 7;
    new iTotalPages = (g_iMapCount + iPerPage - 1) / iPerPage;
    if (iPage < 0) iPage = 0;
    if (iPage >= iTotalPages) iPage = iTotalPages - 1;
    if (iTotalPages <= 0) iPage = 0;
    g_iAdminMapPage[id] = iPage;

    new szMenu[512], iLen;
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r选择比赛地图 (Page %d/%d)^n^n", iPage + 1, iTotalPages);

    new iStart = iPage * iPerPage;
    new iEnd = min(iStart + iPerPage, g_iMapCount);
    new iKeys = (1<<9);

    for (new i = iStart; i < iEnd; i++) {
        new iIdx = i - iStart;
        new szType[16];
        if (g_eMaps[i][MD_TYPE] == MAP_TYPE_BOOST) copy(szType, charsmax(szType), "[Boost]");
        else if (g_eMaps[i][MD_TYPE] == MAP_TYPE_SKILL) copy(szType, charsmax(szType), "[Skill]");
        else copy(szType, charsmax(szType), "[Normal]");

        new szMarker[4] = "";
        if (equal(g_szAdminMap, g_eMaps[i][MD_NAME])) copy(szMarker, charsmax(szMarker), "*");

        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s %s%s^n", iIdx + 1, g_eMaps[i][MD_NAME], szType, szMarker);
        iKeys |= (1 << iIdx);
    }

    if (iPage < iTotalPages - 1) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. 下一页^n");
        iKeys |= (1<<7);
    }
    if (iPage > 0) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. 上一页^n");
    }
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. 返回");

    show_menu(id, iKeys, szMenu, -1, "HnsAIAdminMapMenu");
}

public menu_admin_map_handle(id, key) {
    if (key == 9) {
        show_admin_menu(id);
        return;
    }
    if (key == 7) {
        show_admin_map_menu(id, g_iAdminMapPage[id] + 1);
        return;
    }
    if (key == 8) {
        show_admin_map_menu(id, g_iAdminMapPage[id] - 1);
        return;
    }

    new iPerPage = 7;
    new iIdx = g_iAdminMapPage[id] * iPerPage + key;
    if (iIdx >= 0 && iIdx < g_iMapCount) {
        copy(g_szAdminMap, charsmax(g_szAdminMap), g_eMaps[iIdx][MD_NAME]);
        client_print(0, print_chat, "[AI Teams] Admin selected map: ^3%s^1", g_szAdminMap);
        show_admin_menu(id);
    }
}

public cmd_admin_map(id, level, cid) {
    if (!cmd_access(id, level, cid, 2))
        return PLUGIN_HANDLED;

    new szMap[MAX_MAP_NAME];
    read_argv(1, szMap, charsmax(szMap));
    if (szMap[0] == EOS) {
        client_print(id, print_chat, "[AI Teams] Usage: amx_ai_map <mapname>");
        return PLUGIN_HANDLED;
    }

    copy(g_szAdminMap, charsmax(g_szAdminMap), szMap);
    client_print(0, print_chat, "[AI Teams] Admin selected map: ^3%s^1", g_szAdminMap);
    return PLUGIN_HANDLED;
}

// ==================== 最终结果显示 ====================
show_final_result() {
    new szModes[VOTE_MODE_COUNT][] = {"MR", "Timer", "Ascension", "Vampire", "Rounds", "Duel", "随机"};
    
    new szMapTypes[VOTE_MAPTYPE_COUNT][] = {"随机Boost图", "随机技巧图", "管理指定", "当前地图"};
    
    set_hudmessage(0, 255, 100, -1.0, 0.3, 0, 0.0, 10.0, 0.5, 0.5);
    ShowSyncHudMsg(0, g_iHudSync, "地图: %s | 模式: %s^n2秒后自动开始比赛...", szMapTypes[g_iSelectedMapType], szModes[g_iSelectedMode]);
    
    client_print(0, print_chat, "[AI Teams] === 最终设置 ===");
    client_print(0, print_chat, "[AI Teams] 地图类型: %s | 地图: %s", szMapTypes[g_iSelectedMapType], g_szSelectedMap);
    client_print(0, print_chat, "[AI Teams] 模式: %s | 2秒后自动开始...", szModes[g_iSelectedMode]);
}

// ==================== 配置加载 ====================
load_maps() {
    new szPath[128];
    get_configsdir(szPath, charsmax(szPath));
    add(szPath, charsmax(szPath), "/ai_teams/maps.ini");
    
    g_iMapCount = 0;
    
    new f = fopen(szPath, "r");
    if (!f) {
        // 自动生成默认配置
        auto_generate_maps_config(szPath);
        return;
    }
    
    new szLine[128];
    while (!feof(f) && g_iMapCount < MAX_MAPS && fgets(f, szLine, charsmax(szLine))) {
        trim(szLine);
        if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == EOS) continue;
        
        new szName[MAX_MAP_NAME], szType[16];
        if (parse(szLine, szName, charsmax(szName), szType, charsmax(szType)) < 2) continue;
        
        copy(g_eMaps[g_iMapCount][MD_NAME], charsmax(g_eMaps[][MD_NAME]), szName);
        
        if (equali(szType, "boost")) g_eMaps[g_iMapCount][MD_TYPE] = MAP_TYPE_BOOST;
        else if (equali(szType, "skill")) g_eMaps[g_iMapCount][MD_TYPE] = MAP_TYPE_SKILL;
        else g_eMaps[g_iMapCount][MD_TYPE] = MAP_TYPE_NORMAL;
        
        g_eMaps[g_iMapCount][MD_ENABLED] = true;
        g_iMapCount++;
    }
    fclose(f);
}

auto_generate_maps_config(szPath[]) {
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    add(szDir, charsmax(szDir), "/ai_teams");
    
    mkdir(szDir); // 确保目录存在
    
    new f = fopen(szPath, "w");
    if (!f) return;
    
    fprintf(f, "; AI Teams Map Configuration^n");
    fprintf(f, "; Format: map_name type^n");
    fprintf(f, "; Types: normal, boost, skill^n");
    fprintf(f, "; ^n");
    
    // 扫描maps目录
    new szMapDir[128];
    get_localinfo("amxx_basedir", szMapDir, charsmax(szMapDir));
    add(szMapDir, charsmax(szMapDir), "/maps");
    
    new szFile[64];
    new h = open_dir(szMapDir, szFile, charsmax(szFile));
    if (h) {
        new iType;
        while (next_file(h, szFile, charsmax(szFile))) {
            // 去掉 .bsp 后缀
            new szName[MAX_MAP_NAME];
            copy(szName, charsmax(szName), szFile);
            new iLen = strlen(szName) - 4;
            if (iLen > 0 && equali(szName[iLen], ".bsp")) {
                szName[iLen] = EOS;
            }
            
            // 自动分类
            iType = MAP_TYPE_NORMAL;
            if (containi(szName, "boost") >= 0) iType = MAP_TYPE_BOOST;
            else if (containi(szName, "skill") >= 0) iType = MAP_TYPE_SKILL;
            
            new szTypeStr[16];
            // Use if/else to avoid Pawn switch fall-through bugs
            if (iType == MAP_TYPE_BOOST) copy(szTypeStr, charsmax(szTypeStr), "boost");
            else if (iType == MAP_TYPE_SKILL) copy(szTypeStr, charsmax(szTypeStr), "skill");
            else copy(szTypeStr, charsmax(szTypeStr), "normal");
            
            fprintf(f, "%s %s^n", szName, szTypeStr);
            
            // 同时加载到内存
            if (g_iMapCount < MAX_MAPS) {
                copy(g_eMaps[g_iMapCount][MD_NAME], charsmax(g_eMaps[][MD_NAME]), szName);
                g_eMaps[g_iMapCount][MD_TYPE] = iType;
                g_eMaps[g_iMapCount][MD_ENABLED] = true;
                g_iMapCount++;
            }
        }
        close_dir(h);
    }
    
    fclose(f);
}

load_config() {
    new szPath[128];
    get_configsdir(szPath, charsmax(szPath));
    add(szPath, charsmax(szPath), "/ai_teams/ai_config.ini");
    
    new f = fopen(szPath, "r");
    if (!f) {
        // 自动生成默认配置
        auto_generate_config(szPath);
        return;
    }
    
    new szLine[128], szKey[32], szValue[16];
    while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
        trim(szLine);
        if (szLine[0] == ';' || szLine[0] == EOS) continue;
        
        strtok(szLine, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
        trim(szKey); trim(szValue);
        
        if (equali(szKey, "team_size")) g_iTeamSize = str_to_num(szValue);
        else if (equali(szKey, "min_players")) g_iMinPlayers = str_to_num(szValue);
        else if (equali(szKey, "signup_time")) g_iSignupTime = str_to_num(szValue);
        else if (equali(szKey, "vote_time")) g_iVoteTime = str_to_num(szValue);
        else if (equali(szKey, "max_refresh")) g_iMaxRefresh = str_to_num(szValue);
        else if (equali(szKey, "weight_pts")) g_flWeightPTS = str_to_float(szValue);
        else if (equali(szKey, "weight_winrate")) g_flWeightWinRate = str_to_float(szValue);
        else if (equali(szKey, "weight_matches")) g_flWeightMatches = str_to_float(szValue);
    }
    fclose(f);
}

auto_generate_config(szPath[]) {
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    add(szDir, charsmax(szDir), "/ai_teams");
    mkdir(szDir);
    
    new f = fopen(szPath, "w");
    if (!f) return;
    
    fprintf(f, "; AI Teams Configuration^n");
    fprintf(f, ";^n");
    fprintf(f, "team_size = 5^n");
    fprintf(f, "min_players = 2^n");
    fprintf(f, "signup_time = 60^n");
    fprintf(f, "vote_time = 30^n");
    fprintf(f, "max_refresh = 3^n");
    fprintf(f, "weight_pts = 0.5^n");
    fprintf(f, "weight_winrate = 0.3^n");
    fprintf(f, "weight_matches = 0.2^n");
    
    fclose(f);
}

// ==================== 玩家唯一标识 ====================
// 盗版服: IP+名字; 正版服: SteamID
get_player_key(id, szKey[], iLen) {
    new szAuthId[MAX_STEAMID];
    get_user_authid(id, szAuthId, charsmax(szAuthId));
    
    // 检测是否为盗版（LAN ID 或 BOT）
    if (contain(szAuthId, "STEAM_ID_LAN") != -1 
        || contain(szAuthId, "VALVE_ID_LAN") != -1
        || equal(szAuthId, "BOT")) {
        new szIp[MAX_IP], szName[32];
        get_user_ip(id, szIp, charsmax(szIp), 1);
        get_user_name(id, szName, charsmax(szName));
        formatex(szKey, iLen, "%s|%s", szIp, szName);
    } else {
        copy(szKey, iLen, szAuthId);
    }
}

stock bool:is_player_in_team_list(id, iTeam) {
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B) {
        return false;
    }

    for (new i = 0; i < g_iTeamCount[iTeam]; i++) {
        if (g_iTeamPlayers[iTeam][i] == id) {
            return true;
        }
    }

    return false;
}

stock remove_team_member(id, bool:bClearPlayerState = true) {
    new iTeam = g_ePlayers[id][PAD_TEAM];
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B) {
        return;
    }

    for (new i = 0; i < g_iTeamCount[iTeam]; i++) {
        if (g_iTeamPlayers[iTeam][i] != id) {
            continue;
        }

        for (new j = i; j < g_iTeamCount[iTeam] - 1; j++) {
            g_iTeamPlayers[iTeam][j] = g_iTeamPlayers[iTeam][j + 1];
        }

        g_iTeamPlayers[iTeam][g_iTeamCount[iTeam] - 1] = 0;
        g_iTeamCount[iTeam]--;
        break;
    }

    if (g_iCaptain[iTeam] == id) {
        g_iCaptain[iTeam] = 0;
    }

    if (bClearPlayerState) {
        g_ePlayers[id][PAD_IN_TEAM] = false;
        g_ePlayers[id][PAD_TEAM] = 0;
        g_ePlayers[id][PAD_IS_CAPTAIN] = false;
    }

    recalc_team_scores();
}

stock clear_disconnect_slot_by_team(iTeam) {
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (!g_bWasInMatch[i] || g_szDisconnectTeam[i] != iTeam) {
            continue;
        }

        g_bWasInMatch[i] = false;
        g_bDisconnectCaptain[i] = false;
        g_szDisconnectKey[i][0] = EOS;
        g_szDisconnectTime[i] = 0;
        remove_task(i);
        g_iReconnectTimer[i] = 0;
        return;
    }
}

// ==================== 状态保存/恢复 ====================
save_state() {
    new f = fopen(g_szStateFile, "w");
    if (!f) return;
    
    fprintf(f, "state %d^n", g_eAIState);
    fprintf(f, "team_size %d^n", g_iTeamSize);
    fprintf(f, "match_team_size %d^n", g_iMatchTeamSize);
    fprintf(f, "mode %d^n", g_iSelectedMode);
    fprintf(f, "map %s^n", g_szSelectedMap);
    fprintf(f, "timestamp %d^n", get_systime());
    
    // 保存玩家队伍
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_ePlayers[i][PAD_IN_TEAM]) {
            new szKey[MAX_PLAYER_KEY];
            get_player_key(i, szKey, charsmax(szKey));
            fprintf(f, "player ^"%s^" %d %d^n", szKey, g_ePlayers[i][PAD_TEAM], g_ePlayers[i][PAD_IS_CAPTAIN]);
        }
    }
    
    fclose(f);
}

check_recovery() {
    new f = fopen(g_szStateFile, "r");
    if (!f) return;
    
    new szLine[128], iState = -1, iMode = -1;
    new szMap[MAX_MAP_NAME];
    g_iRecoveryCount = 0;
    g_iRecoveryReconnected = 0;
    
    while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
        trim(szLine);
        if (szLine[0] == EOS) continue;
        
        new szKey[32], szValue1[64], szValue2[16], szValue3[16];
        parse(szLine, szKey, charsmax(szKey), szValue1, charsmax(szValue1), szValue2, charsmax(szValue2), szValue3, charsmax(szValue3));
        
        if (equal(szKey, "state"))      iState = str_to_num(szValue1);
        if (equal(szKey, "mode"))       iMode = str_to_num(szValue1);
        if (equal(szKey, "map"))        copy(szMap, charsmax(szMap), szValue1);
        if (equal(szKey, "team_size"))  g_iTeamSize = str_to_num(szValue1);
        if (equal(szKey, "match_team_size")) g_iMatchTeamSize = str_to_num(szValue1);
        
        // ★ 读取玩家恢复数据
        if (equal(szKey, "player") && g_iRecoveryCount < MAX_PLAYERS) {
            copy(g_szRecoveryKeys[g_iRecoveryCount], charsmax(g_szRecoveryKeys[]), szValue1);
            g_iRecoveryTeams[g_iRecoveryCount] = str_to_num(szValue2);
            g_bRecoveryCaptain[g_iRecoveryCount] = bool:str_to_num(szValue3);
            g_iRecoveryCount++;
        }
    }
    fclose(f);
    
    // ★ 如果换图前是比赛进行中状态，恢复比赛
    if (iState == AI_STATE_LOCKED && iMode >= 0) {
        g_iSelectedMode = iMode;
        copy(g_szSelectedMap, charsmax(g_szSelectedMap), szMap);
        g_eAIState = AI_STATE_LOCKED;
        
        client_print(0, print_chat, "[AI Teams] 检测到未完成的比赛，等待 %d 名玩家重连... 模式: %d, 地图: %s", 
            g_iRecoveryCount, iMode, szMap);
        
        // ★ 如果有玩家数据，等待他们重连后再执行比赛配置
        if (g_iRecoveryCount > 0) {
            set_task(3.0, "task_CheckAllPlayersReconnected", TASKID_RECOVERY_CHECK, _, _, "b");
        } else {
            // 没有玩家数据，直接执行配置
            set_task(3.0, "task_ExecMatchConfig");
        }
    }
    
    // 非比赛状态，清理配置文件
    if (iState != AI_STATE_LOCKED) {
        delete_file(g_szStateFile);
    }
}

public task_ExecMatchConfig() {
    // 执行 AI 比赛启动配置
    new szCfgFile[256];
    get_configsdir(szCfgFile, charsmax(szCfgFile));
    add(szCfgFile, charsmax(szCfgFile), "/hns_ai_match_start.cfg");
    
    if (file_exists(szCfgFile)) {
        server_cmd("exec %s", szCfgFile);
        // 延迟删除配置文件，确保 exec 已生效
        set_task(1.0, "task_DeleteMatchConfig");
    }
}

public task_DeleteMatchConfig() {
    new szCfgFile[256];
    get_configsdir(szCfgFile, charsmax(szCfgFile));
    add(szCfgFile, charsmax(szCfgFile), "/hns_ai_match_start.cfg");
    
    if (file_exists(szCfgFile)) {
        delete_file(szCfgFile);
    }
}

// ==================== 日志 ====================
log_grouping() {
    new f = fopen(g_szLogFile, "a");
    if (!f) return;
    
    new szTime[32];
    get_time("%Y-%m-%d %H:%M:%S", szTime, charsmax(szTime));
    
    fprintf(f, "[%s] AI Grouping^n", szTime);
    fprintf(f, "  Team A (score: %d):^n", g_iTeamScore[AI_TEAM_A]);
    for (new i = 0; i < g_iTeamCount[AI_TEAM_A]; i++) {
        new id = g_iTeamPlayers[AI_TEAM_A][i];
        new szName[32], szAuth[MAX_STEAMID];
        get_user_name(id, szName, charsmax(szName));
        get_user_authid(id, szAuth, charsmax(szAuth));
        fprintf(f, "    %s (%s) score:%d%s^n", szName, szAuth, g_ePlayers[id][PAD_SCORE], g_ePlayers[id][PAD_IS_CAPTAIN] ? " [CAPTAIN]" : "");
    }
    fprintf(f, "  Team B (score: %d):^n", g_iTeamScore[AI_TEAM_B]);
    for (new i = 0; i < g_iTeamCount[AI_TEAM_B]; i++) {
        new id = g_iTeamPlayers[AI_TEAM_B][i];
        new szName[32], szAuth[MAX_STEAMID];
        get_user_name(id, szName, charsmax(szName));
        get_user_authid(id, szAuth, charsmax(szAuth));
        fprintf(f, "    %s (%s) score:%d%s^n", szName, szAuth, g_ePlayers[id][PAD_SCORE], g_ePlayers[id][PAD_IS_CAPTAIN] ? " [CAPTAIN]" : "");
    }
    fprintf(f, "^n");
    
    fclose(f);
}
new g_iPauseCount[MAX_TEAMS];           // 每队暂停次数
new g_iPauseRemaining[MAX_TEAMS];       // 暂停剩余时间
new bool:g_bPaused;                     // 是否暂停中
new g_iPauseTimer;

public cmd_pause(id) {
    if (g_eAIState != AI_STATE_LOCKED) {
        return PLUGIN_CONTINUE; // ★ 不是AI比赛，交给HnsMatchSystem处理
    }
    
    // 检查权限（管理员/指挥官）
    if (!isUserAdmin(id) && !isUserWatcher(id) && !isUserFullWatcher(id) && !g_ePlayers[id][PAD_IS_CAPTAIN]) {
        client_print(id, print_chat, "[AI Teams] Captain/Admin only.");
        return PLUGIN_HANDLED;
    }
    
    if (g_bPaused) {
        client_print(id, print_chat, "[AI Teams] Already paused.");
        return PLUGIN_HANDLED;
    }
    
    // 确定是哪队
    new iTeam = g_ePlayers[id][PAD_TEAM];
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B) {
        // 管理员可以暂停任意队，默认暂停当前回合的防守方
        iTeam = AI_TEAM_A; // 简化处理
    }
    
    if (g_iPauseCount[iTeam] >= 2) {
        client_print(id, print_chat, "[AI Teams] No pauses remaining for this team.");
        return PLUGIN_HANDLED;
    }
    
    g_bPaused = true;
    g_iPauseCount[iTeam]++;
    g_iPauseRemaining[iTeam] = 60;
    
    client_print(0, print_chat, "[AI Teams] %n paused the match! (%d/2, %d seconds)", id, g_iPauseCount[iTeam], g_iPauseRemaining[iTeam]);
    
    set_hudmessage(255, 50, 50, -1.0, 0.3, 0, 0.0, 2.0);
    ShowSyncHudMsg(0, g_iHudSync, "MATCH PAUSED^n%d seconds", g_iPauseRemaining[iTeam]);
    
    remove_task(TASKID_PAUSE);
    set_task(1.0, "task_pause_countdown", TASKID_PAUSE, _, _, "b");
    g_iPauseTimer = TASKID_PAUSE;
    
    return PLUGIN_HANDLED;
}

public cmd_unpause(id) {
    if (!g_bPaused) {
        return PLUGIN_CONTINUE; // ★ 不是AI暂停，交给HnsMatchSystem处理
    }
    
    if (!isUserAdmin(id) && !isUserWatcher(id) && !isUserFullWatcher(id) && !g_ePlayers[id][PAD_IS_CAPTAIN]) {
        client_print(id, print_chat, "[AI Teams] Captain/Admin only.");
        return PLUGIN_HANDLED;
    }
    
    g_bPaused = false;
    remove_task(TASKID_PAUSE);
    
    client_print(0, print_chat, "[AI Teams] %n unpaused the match.", id);
    return PLUGIN_HANDLED;
}

task_pause_countdown() {
    // 找到暂停的队伍
    for (new t = 0; t < MAX_TEAMS; t++) {
        if (g_iPauseRemaining[t] > 0) {
            g_iPauseRemaining[t]--;
            
            if (g_iPauseRemaining[t] <= 10 && g_iPauseRemaining[t] > 0) {
                set_hudmessage(255, 255, 0, -1.0, 0.3, 0, 0.0, 1.0);
                ShowSyncHudMsg(0, g_iHudSync, "PAUSED: %d seconds", g_iPauseRemaining[t]);
            }
            
            if (g_iPauseRemaining[t] <= 0) {
                g_bPaused = false;
                remove_task(TASKID_PAUSE);
                client_print(0, print_chat, "[AI Teams] Pause time expired. Match resumed.");
            }
            
            break;
        }
    }
}

// ==================== 替补系统 ====================
new g_iSubstituteCount;     // 替补次数

public cmd_substitute(id) {
    if (g_eAIState != AI_STATE_LOCKED) {
        client_print(id, print_chat, "[AI Teams] No match in progress.");
        return PLUGIN_HANDLED;
    }
    
    // 检查权限
    if (!isUserAdmin(id) && !isUserWatcher(id) && !isUserFullWatcher(id) && !g_ePlayers[id][PAD_IS_CAPTAIN]) {
        client_print(id, print_chat, "[AI Teams] Captain/Admin only.");
        return PLUGIN_HANDLED;
    }
    
    new szTarget[32];
    read_argv(1, szTarget, charsmax(szTarget));
    
    if (szTarget[0] == EOS) {
        client_print(id, print_chat, "[AI Teams] Usage: /substitute <player_name>");
        return PLUGIN_HANDLED;
    }
    
    new iTarget = cmd_target(id, szTarget, CMDTARGET_OBEY_IMMUNITY);
    if (iTarget == 0) {
        client_print(id, print_chat, "[AI Teams] Player not found.");
        return PLUGIN_HANDLED;
    }
    
    if (g_ePlayers[iTarget][PAD_IN_TEAM]) {
        client_print(id, print_chat, "[AI Teams] Player is already in a team.");
        return PLUGIN_HANDLED;
    }
    
    // 优先补到实际缺人的那支队伍
    new iTeam = -1;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_bWasInMatch[i]) {
            iTeam = g_szDisconnectTeam[i];
            break;
        }
    }
    if (iTeam == -1) {
        iTeam = (g_iTeamCount[AI_TEAM_A] <= g_iTeamCount[AI_TEAM_B]) ? AI_TEAM_A : AI_TEAM_B;
    }
    
    // 检查是否超人数
    if (g_iTeamCount[iTeam] >= g_iMatchTeamSize) {
        // 踢最后加入的人
        new iLastJoin = 0, iMaxTime = 0;
        for (new i = 0; i < g_iTeamCount[iTeam]; i++) {
            new pid = g_iTeamPlayers[iTeam][i];
            if (g_ePlayers[pid][PAD_JOIN_TIME] > iMaxTime) {
                iMaxTime = g_ePlayers[pid][PAD_JOIN_TIME];
                iLastJoin = pid;
            }
        }
        
        if (iLastJoin > 0) {
            // 踢出
            g_ePlayers[iLastJoin][PAD_IN_TEAM] = false;
            g_ePlayers[iLastJoin][PAD_TEAM] = 0;
            g_ePlayers[iLastJoin][PAD_IS_CAPTAIN] = false;
            
            client_print(iLastJoin, print_chat, "[AI Teams] You have been replaced. Team is full.");
            rg_set_user_team(iLastJoin, TEAM_SPECTATOR, MODEL_AUTO);
            
            client_print(0, print_chat, "[AI Teams] %n was removed (team full, last joined).", iLastJoin);
            
            // 重新计算队伍
            recalc_team_scores();
        }
    }
    
    // 添加替补
    g_ePlayers[iTarget][PAD_IN_TEAM] = true;
    g_ePlayers[iTarget][PAD_TEAM] = iTeam;
    g_ePlayers[iTarget][PAD_JOIN_TIME] = get_systime();
    g_ePlayers[iTarget][PAD_SCORE] = calculate_player_score(iTarget);
    if (!is_player_in_team_list(iTarget, iTeam)) {
        g_iTeamPlayers[iTeam][g_iTeamCount[iTeam]] = iTarget;
        g_iTeamCount[iTeam]++;
    }
    g_iSubstituteCount++;
    
    rg_set_user_team(iTarget, iTeam == AI_TEAM_A ? TEAM_TERRORIST : TEAM_CT, MODEL_AUTO);
    clear_disconnect_slot_by_team(iTeam);
    recalc_team_scores();
    
    // 通知相关人
    new szTeamName[8] = "A";
    if (iTeam == AI_TEAM_B) copy(szTeamName, charsmax(szTeamName), "B");
    client_print(0, print_chat, "[AI Teams] %n substituted into Team %s.", iTarget, szTeamName);
    
    // 日志
    log_substitute(id, iTarget, iTeam);
    
    return PLUGIN_HANDLED;
}

log_substitute(iAdmin, iTarget, iTeam) {
    new f = fopen(g_szLogFile, "a");
    if (!f) return;
    
    new szTime[32];
    get_time("%Y-%m-%d %H:%M:%S", szTime, charsmax(szTime));
    
    new szAdminName[32], szTargetName[32];
    get_user_name(iAdmin, szAdminName, charsmax(szAdminName));
    get_user_name(iTarget, szTargetName, charsmax(szTargetName));
    
    fprintf(f, "[%s] Substitute: %s added %s to Team %d (total subs: %d)^n", szTime, szAdminName, szTargetName, iTeam, g_iSubstituteCount);
    fclose(f);
}

// ==================== 投降系统 ====================
new g_iSurrenderVotes[MAX_TEAMS];
new g_iSurrenderInitiator;

public cmd_surrender(id) {
    if (g_eAIState != AI_STATE_LOCKED) {
        client_print(id, print_chat, "[AI Teams] No match in progress.");
        return PLUGIN_HANDLED;
    }
    
    if (!isUserAdmin(id) && !isUserWatcher(id) && !isUserFullWatcher(id) && !g_ePlayers[id][PAD_IS_CAPTAIN]) {
        client_print(id, print_chat, "[AI Teams] Captain/Admin only.");
        return PLUGIN_HANDLED;
    }
    
    new iTeam = g_ePlayers[id][PAD_TEAM];
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B) iTeam = AI_TEAM_A;
    
    g_iSurrenderInitiator = id;
    g_iSurrenderVotes[iTeam] = 0;
    
    client_print(0, print_chat, "[AI Teams] %n initiated surrender vote for Team %s. Type ^3/accept^1 or ^3/decline^1.", id, iTeam == AI_TEAM_A ? "A" : "B");
    
    // 给同队玩家投票
    for (new i = 0; i < g_iTeamCount[iTeam]; i++) {
        new pid = g_iTeamPlayers[iTeam][i];
        if (pid != id && is_user_connected(pid)) {
            set_task(30.0, "task_surrender_timeout", pid);
        }
    }
    
    return PLUGIN_HANDLED;
}

public cmd_accept(id) {
    new iTeam = g_ePlayers[id][PAD_TEAM];
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B) return;
    
    g_iSurrenderVotes[iTeam]++;
    
    // 检查是否达到80%
    new iRequired = floatround(g_iTeamCount[iTeam] * 0.8);
    if (g_iSurrenderVotes[iTeam] >= iRequired) {
        client_print(0, print_chat, "[AI Teams] Team %s surrendered! Match ended.", iTeam == AI_TEAM_A ? "A" : "B");
        end_match(iTeam == AI_TEAM_A ? AI_TEAM_B : AI_TEAM_A);
    }
}

public cmd_decline(id) {
    new iTeam = g_ePlayers[id][PAD_TEAM];
    if (iTeam < AI_TEAM_A || iTeam > AI_TEAM_B) return;
    
    client_print(0, print_chat, "[AI Teams] %n declined surrender.", id);
    g_iSurrenderVotes[iTeam] = 0;
}

task_surrender_timeout(id) {
    if (g_iSurrenderVotes[g_ePlayers[id][PAD_TEAM]] == 0) {
        client_print(0, print_chat, "[AI Teams] Surrender vote expired.");
    }
}

// ==================== 比赛结束 ====================
end_match(iWinnerTeam) {
    g_eAIState = AI_STATE_IDLE;
    g_bPaused = false;
    
    remove_task(TASKID_PAUSE);
    
    // 计算MVP
    new iMVP = calculate_mvp();
    
    // 显示结果
    show_match_result(iWinnerTeam, iMVP);
    
    // PTS积分
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (!g_ePlayers[i][PAD_IN_TEAM]) continue;
        
        new iTeam = g_ePlayers[i][PAD_TEAM];
        new iPtsChange = 0;
        
        if (iTeam == iWinnerTeam) {
            iPtsChange = 15; // 赢+15
        } else {
            iPtsChange = -10; // 输-10
        }
        
        if (hns_mysql_stats_init()) {
            // PTS更新由主系统的 hns_mysql_stats_deduct_pts 处理
            // 当前仅做 chat 通知，实际数据库写入依赖主系统
        }
        
        new szTeamName[8] = "A";
        if (iTeam == AI_TEAM_B) copy(szTeamName, charsmax(szTeamName), "B");
        
        new iPts = 1000;
        if (hns_mysql_stats_init()) iPts = hns_mysql_stats_data(i, e_iPts);
        
        client_print(i, print_chat, "[AI Teams] PTS: %s%d (Total: %d)", iPtsChange > 0 ? "+" : "", iPtsChange, iPts + iPtsChange);
    }
    
    // MVP显示
    if (iMVP > 0) {
        client_print(0, print_chat, "[AI Teams] MVP: ^3%n^1!", iMVP);
    }
    
    // 日志
    log_match_result(iWinnerTeam, iMVP);
    
    // 清除状态文件
    if (file_exists(g_szStateFile)) delete_file(g_szStateFile);
    
    // ★ 清除启动配置文件
    new szCfgFile[256];
    get_configsdir(szCfgFile, charsmax(szCfgFile));
    add(szCfgFile, charsmax(szCfgFile), "/hns_ai_match_start.cfg");
    if (file_exists(szCfgFile)) delete_file(szCfgFile);
    
    // 重置所有数据
    reset_all();
}

calculate_mvp() {
    // 综合评分：击杀*2 + 助攻*1 + 存活时间/10
    new iBestId = 0, iBestScore = 0;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (!g_ePlayers[i][PAD_IN_TEAM]) continue;
        
        new iKills = hns_get_stats_kills(STATS_ALL, i);
        new iAssists = hns_get_stats_assists(STATS_ALL, i);
        new Float:flSurv = hns_get_stats_surv(STATS_ALL, i);
        
        new iScore = iKills * 2 + iAssists + floatround(flSurv / 10.0);
        
        if (iScore > iBestScore) {
            iBestScore = iScore;
            iBestId = i;
        }
    }
    
    return iBestId;
}

show_match_result(iWinnerTeam, iMVP) {
    new szHud[512], iLen;
    
    new szWinner[8] = "Team A";
    if (iWinnerTeam == AI_TEAM_B) copy(szWinner, charsmax(szWinner), "Team B");
    
    iLen += format(szHud[iLen], sizeof(szHud) - iLen, "=== MATCH RESULT ===^n");
    iLen += format(szHud[iLen], sizeof(szHud) - iLen, "Winner: %s^n", szWinner);
    
    if (iMVP > 0) {
        iLen += format(szHud[iLen], sizeof(szHud) - iLen, "MVP: %n^n", iMVP);
    }
    
    iLen += format(szHud[iLen], sizeof(szHud) - iLen, "Substitutes: %d", g_iSubstituteCount);
    
    set_hudmessage(0, 255, 100, -1.0, 0.3, 0, 0.0, 10.0, 0.5, 0.5);
    ShowSyncHudMsg(0, g_iHudSync, "%s", szHud);
}

log_match_result(iWinnerTeam, iMVP) {
    new f = fopen(g_szLogFile, "a");
    if (!f) return;
    
    new szTime[32];
    get_time("%Y-%m-%d %H:%M:%S", szTime, charsmax(szTime));
    
    new szMVPName[32];
    if (iMVP > 0) get_user_name(iMVP, szMVPName, charsmax(szMVPName));
    
    fprintf(f, "[%s] Match Result: Team %d wins, MVP: %s, Subs: %d^n^n", 
        szTime, iWinnerTeam, iMVP > 0 ? szMVPName : "None", g_iSubstituteCount);
    fclose(f);
}

// ==================== 指挥官HUD ====================
new g_iCaptainHudTimer;

show_captain_hud() {
    if (g_eAIState != AI_STATE_LOCKED) return;
    
    new szHud[128], iLen;
    
    for (new t = 0; t < MAX_TEAMS; t++) {
        if (g_iCaptain[t] > 0 && is_user_connected(g_iCaptain[t])) {
            new szTeamName[8] = "A";
            if (t == AI_TEAM_B) copy(szTeamName, charsmax(szTeamName), "B");
            iLen = 0;
            iLen += format(szHud[iLen], sizeof(szHud) - iLen, "[CAPTAIN] Team %s", szTeamName);
            
            set_hudmessage(255, 215, 0, 0.01, 0.01, 0, 0.0, 2.0, 0.0, 0.0);
            ShowSyncHudMsg(0, g_iHudSync, "%s", szHud);
        }
    }
}

public client_authorized(id) {
    new szKey[MAX_PLAYER_KEY];
    get_player_key(id, szKey, charsmax(szKey));
    
    // 检查是否有未完成的比赛断线记录
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_bWasInMatch[i] && equal(g_szDisconnectKey[i], szKey)) {
            new iElapsed = get_systime() - g_szDisconnectTime[i];
            
            if (iElapsed <= 30) {
                // 30秒内重连，恢复队伍
                new iTeam = g_szDisconnectTeam[i];
                g_ePlayers[id][PAD_IN_TEAM] = true;
                g_ePlayers[id][PAD_TEAM] = iTeam;
                g_ePlayers[id][PAD_REGISTERED] = true;
                g_ePlayers[id][PAD_SCORE] = calculate_player_score(id);
                if (!is_player_in_team_list(id, iTeam)) {
                    g_iTeamPlayers[iTeam][g_iTeamCount[iTeam]] = id;
                    g_iTeamCount[iTeam]++;
                }
                rg_set_user_team(id, iTeam == AI_TEAM_A ? TEAM_TERRORIST : TEAM_CT, MODEL_AUTO);

                if (g_bDisconnectCaptain[i]) {
                    if (g_iCaptain[iTeam] > 0 && g_iCaptain[iTeam] != id) {
                        g_ePlayers[g_iCaptain[iTeam]][PAD_IS_CAPTAIN] = false;
                    }
                    g_iCaptain[iTeam] = id;
                    g_ePlayers[id][PAD_IS_CAPTAIN] = true;
                }
                
                client_print(0, print_chat, "[AI Teams] %n reconnected! Welcome back.", id);
                
                // 清除断线记录
                g_bWasInMatch[i] = false;
                g_bDisconnectCaptain[i] = false;
                g_szDisconnectKey[i][0] = EOS;
                g_szDisconnectTime[i] = 0;
                
                remove_task(i);
                recalc_team_scores();
            }
            
            break;
        }
    }
}

// 在 client_disconnected 中添加断线记录
// 注意：这需要修改现有的 client_disconnected 函数
// 我们用一个单独的函数处理

save_disconnect_data(id) {
    if (!g_ePlayers[id][PAD_IN_TEAM] || g_eAIState != AI_STATE_LOCKED) return;
    
    new szKey[MAX_PLAYER_KEY];
    get_player_key(id, szKey, charsmax(szKey));
    
    // 找一个空位保存
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (!g_bWasInMatch[i]) {
            copy(g_szDisconnectKey[i], charsmax(g_szDisconnectKey[]), szKey);
            g_szDisconnectTeam[i] = g_ePlayers[id][PAD_TEAM];
            g_szDisconnectTime[i] = get_systime();
            g_bWasInMatch[i] = true;
            g_bDisconnectCaptain[i] = g_ePlayers[id][PAD_IS_CAPTAIN];
            
            // 30秒后清除记录
            remove_task(i);
            set_task(30.0, "task_clear_reconnect", i);
            g_iReconnectTimer[i] = i;
            
            // 暂停比赛等待替补
            g_bPaused = true;
            client_print(0, print_chat, "[AI Teams] %n disconnected. Match paused. Waiting for substitute or reconnect (30s).", id);
            
            // 额外扣分
            if (hns_mysql_stats_init()) {
                // hns_mysql_stats_deduct_pts(id, 5); // 额外扣5分
            }
            
            break;
        }
    }
}

public task_clear_reconnect(iSlot) {
    g_bWasInMatch[iSlot] = false;
    g_bDisconnectCaptain[iSlot] = false;
    g_szDisconnectKey[iSlot][0] = EOS;
    g_szDisconnectTime[iSlot] = 0;
    
    // 如果还没人替补，关闭比赛
    new bHasMissing = false;
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (g_bWasInMatch[i]) bHasMissing = true;
    }
    
    if (!bHasMissing && g_bPaused) {
        // 检查两队是否都有足够人
        for (new t = 0; t < MAX_TEAMS; t++) {
            if (g_iTeamCount[t] < g_iMatchTeamSize) {
                client_print(0, print_chat, "[AI Teams] No substitute after 30s. Match closed.");
                end_match(t == AI_TEAM_A ? AI_TEAM_B : AI_TEAM_A);
                return;
            }
        }
        g_bPaused = false;
    }
}

// ==================== 临时权限系统 ====================
grant_temporary_rights(id) {
    // 给指挥官临时Watcher权限 (flag f = Watcher/临时管理)
    if (g_ePlayers[id][PAD_IS_CAPTAIN]) {
        new iFlags = get_user_flags(id);
        if (!(iFlags & read_flags("f"))) {
            set_user_flags(id, iFlags | read_flags("f"));
        }
        client_print(id, print_chat, "[AI Teams] 你已获得临时管理权限 (Watcher).");
    }
}

revoke_temporary_rights(id) {
    if (g_ePlayers[id][PAD_IS_CAPTAIN]) {
        new iFlags = get_user_flags(id);
        if (iFlags & read_flags("f")) {
            set_user_flags(id, iFlags & ~read_flags("f"));
        }
        client_print(id, print_chat, "[AI Teams] 你的临时管理权限已被移除.");
    }
}

// ==================== 重置 ====================
reset_all() {
    g_eAIState = AI_STATE_IDLE;
    g_bPaused = false;
    g_iRegisteredCount = 0;
    g_iRefreshCount = 0;
    g_iSubstituteCount = 0;
    g_iSurrenderInitiator = 0;
    g_iMatchTeamSize = g_iTeamSize;
    remove_task(TASKID_RECOVERY_CHECK);
    
    for (new t = 0; t < MAX_TEAMS; t++) {
        g_iTeamCount[t] = 0;
        g_iTeamScore[t] = 0;
        g_iCaptain[t] = 0;
        g_iPauseCount[t] = 0;
        g_iPauseRemaining[t] = 0;
        g_iSurrenderVotes[t] = 0;
        arrayset(g_iTeamPlayers[t], 0, sizeof(g_iTeamPlayers[]));
    }
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        g_ePlayers[i][PAD_REGISTERED] = false;
        g_ePlayers[i][PAD_IN_TEAM] = false;
        g_ePlayers[i][PAD_TEAM] = 0;
        g_ePlayers[i][PAD_SCORE] = 0;
        g_ePlayers[i][PAD_IS_CAPTAIN] = false;
        g_ePlayers[i][PAD_VOTE_MODE] = -1;
        g_ePlayers[i][PAD_VOTE_MAP] = -1;
    }
    
    // ★ 清理恢复数据
    g_iRecoveryCount = 0;
    g_iRecoveryReconnected = 0;
    for (new i = 0; i <= MAX_PLAYERS; i++) {
        g_szRecoveryKeys[i][0] = EOS;
        g_bRecoveryCaptain[i] = false;
        g_bWasInMatch[i] = false;
        g_bDisconnectCaptain[i] = false;
        g_szDisconnectKey[i][0] = EOS;
        g_szDisconnectTime[i] = 0;
        remove_task(i);
    }
}

// ==================== 额外命令注册 ====================
// 注意：这些命令需要在 plugin_init 中注册
// 这里用单独的函数包装，在 plugin_init 中调用
register_extra_commands() {
    register_clcmd("say /aipause", "cmd_pause");
    register_clcmd("say_team /aipause", "cmd_pause");
    register_clcmd("say /aiunpause", "cmd_unpause");
    register_clcmd("say_team /aiunpause", "cmd_unpause");
    register_clcmd("say /substitute", "cmd_substitute");
    register_clcmd("say_team /substitute", "cmd_substitute");
    register_clcmd("say /aisurrender", "cmd_surrender");
    register_clcmd("say_team /aisurrender", "cmd_surrender");
    register_clcmd("say /accept", "cmd_accept");
    register_clcmd("say_team /accept", "cmd_accept");
    register_clcmd("say /decline", "cmd_decline");
    register_clcmd("say_team /decline", "cmd_decline");
}

// ==================== Native 声明补充 ====================
// hns_get_stats_kills, hns_get_stats_assists, STATS_ROUND, STATS_ALL
// 已在 hns_matchsystem_stats.inc 中声明
// hns_get_stats_surv 已在 hns_matchsystem_stats.inc 中声明为 native
