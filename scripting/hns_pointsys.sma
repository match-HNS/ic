#include <amxmodx>
#include <amxmisc>
#include <nvault>

#pragma semicolon 1

#define POINTS_FIRST	20
#define POINTS_SECOND	15
#define POINTS_THIRD	10
#define POINTS_REDEEM	500

new g_iVault;
new g_iPoints[MAX_PLAYERS + 1];
new g_iMatchFrags[MAX_PLAYERS + 1];
new g_iMatchDeaths[MAX_PLAYERS + 1];
new g_bInMatch;

// 菜单状态
new g_iAdminMenuTarget[MAX_PLAYERS + 1]; // 当前选中的玩家
new g_iPlayerList[MAX_PLAYERS + 1][32];  // 菜单中的玩家列表
new g_iPlayerListCount[MAX_PLAYERS + 1]; // 列表数量

// 菜单ID
new g_iMenuMain;
new g_iMenuPlayers;
new g_iMenuAction;

public plugin_init() {
	register_plugin("HNS Point System", "1.1", "AI");

	g_iVault = nvault_open("hns_points");
	if (g_iVault == INVALID_HANDLE)
		server_print("[PointSys] nvault open failed!");

	register_clcmd("say /points", "cmdPoints");
	register_clcmd("say_team /points", "cmdPoints");
	register_clcmd("say /jf", "cmdPoints");
	register_clcmd("say_team /jf", "cmdPoints");
	register_clcmd("say /积分", "cmdPoints");
	register_clcmd("say_team /积分", "cmdPoints");

	register_concmd("pointsadmin", "cmdPointsAdmin", ADMIN_RCON, "积分管理菜单");
	register_clcmd("say /pointsadmin", "cmdPointsAdminChat");
	register_clcmd("say_team /pointsadmin", "cmdPointsAdminChat");

	// ★ 注册三个菜单
	g_iMenuMain = register_menuid("PointSysMain");
	g_iMenuPlayers = register_menuid("PointSysPlayers");
	g_iMenuAction = register_menuid("PointSysAction");

	register_menucmd(g_iMenuMain, (1<<0)|(1<<1)|(1<<9), "handleMainMenu");
	register_menucmd(g_iMenuPlayers, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handlePlayerMenu");
	register_menucmd(g_iMenuAction, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9), "handleActionMenu");

	register_event("TeamScore", "evTeamScore", "a");
	register_logevent("logRoundEnd", 2, "1=Round_End");

	set_task(5.0, "taskCheckMatchStart", _, _, _, "b");

	server_print("[PointSys] 积分系统已加载");
}

public plugin_end() {
	if (g_iVault != INVALID_HANDLE)
		nvault_close(g_iVault);
}

// ==================== 比赛状态检测 ====================
public taskCheckMatchStart() {
	new iMode = callfunc_begin("hns_get_mode", "HnsMatchSystem.amxx");
	if (iMode == -1) {
		new iState = callfunc_begin("hns_get_state", "HnsMatchSystem.amxx");
		if (iState == -1) return;
		callfunc_push_int(0);
		iState = callfunc_end();
		if (iState == 3 && !g_bInMatch) {
			g_bInMatch = true;
			arrayset(g_iMatchFrags, 0, sizeof(g_iMatchFrags));
			arrayset(g_iMatchDeaths, 0, sizeof(g_iMatchDeaths));
		} else if (iState != 3 && g_bInMatch) {
			g_bInMatch = false;
		}
		return;
	}
	callfunc_push_int(0);
	iMode = callfunc_end();

	new bool:bIsMatchMode = (iMode == 5 || iMode == 8 || iMode == 6 || iMode == 7);

	if (bIsMatchMode && !g_bInMatch) {
		g_bInMatch = true;
		arrayset(g_iMatchFrags, 0, sizeof(g_iMatchFrags));
		arrayset(g_iMatchDeaths, 0, sizeof(g_iMatchDeaths));
		server_print("[PointSys] 比赛开始，开始记录数据");
	} else if (!bIsMatchMode && g_bInMatch) {
		g_bInMatch = false;
	}
}

public evTeamScore() {
	if (!g_bInMatch) return;
	RecordPlayerStats();
}

public logRoundEnd() {
	if (!g_bInMatch) return;
	RecordPlayerStats();
}

RecordPlayerStats() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		g_iMatchFrags[id] = get_user_frags(id);
		g_iMatchDeaths[id] = get_user_deaths(id);
	}
}

// ==================== 比赛结束回调 ====================
public hns_match_finished(iWinTeam) {
	server_print("[PointSys] 比赛结束，开始结算积分...");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	if (iNum == 0) {
		server_print("[PointSys] 没有玩家数据");
		return;
	}

	new iAdded = 10;
	new iWinCount = 0;

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		new iTeam = get_user_team(id);
		if (iTeam == iWinTeam) {
			AddPoints(id, iAdded);
			iWinCount++;
		}
	}

	new szTeamName[16];
	if (iWinTeam == 1) copy(szTeamName, charsmax(szTeamName), "T");
	else if (iWinTeam == 2) copy(szTeamName, charsmax(szTeamName), "CT");
	else copy(szTeamName, charsmax(szTeamName), "未知");

	client_print(0, print_chat, "[积分] ====== 本场比赛结束 ======");
	client_print(0, print_chat, "[积分] 获胜方: \y%s\w 队，全队每人 +%d 分", szTeamName, iAdded);

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		new iTeam = get_user_team(id);
		new szName[32]; get_user_name(id, szName, charsmax(szName));
		if (iTeam == iWinTeam) {
			client_print(0, print_chat, "[积分] \y%s\w +%d分 | 总积分:%d", szName, iAdded, GetPoints(id));
		}
	}

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		if (GetPoints(id) >= POINTS_REDEEM) {
			new szName[32]; get_user_name(id, szName, charsmax(szName));
			client_print(0, print_chat, "[积分] \y%s\w 的积分已达到 \y%d\w 分，可以联系管理员兑换皮肤！", szName, POINTS_REDEEM);
			client_print(id, print_chat, "[积分] \y恭喜你！\w 你的积分已达 \y%d\w 分，请截图并联系管理员兑换皮肤！", POINTS_REDEEM);
		}
	}

	arrayset(g_iMatchFrags, 0, sizeof(g_iMatchFrags));
	arrayset(g_iMatchDeaths, 0, sizeof(g_iMatchDeaths));
	g_bInMatch = false;
}

// ==================== 积分操作 ====================
AddPoints(id, iAdd) {
	if (iAdd <= 0 || !is_user_connected(id)) return;
	g_iPoints[id] += iAdd;
	SavePoints(id);
}

SetPoints(id, iVal) {
	g_iPoints[id] = iVal;
	SavePoints(id);
}

GetPoints(id) {
	return g_iPoints[id];
}

LoadPoints(id) {
	new szAuth[35];
	if (!get_user_authid(id, szAuth, charsmax(szAuth)) || equal(szAuth, "STEAM_ID_PENDING") || equal(szAuth, "STEAM_ID_LAN")) {
		get_user_ip(id, szAuth, charsmax(szAuth), 1);
	}
	g_iPoints[id] = nvault_get(g_iVault, szAuth);
}

SavePoints(id) {
	new szAuth[35];
	if (!get_user_authid(id, szAuth, charsmax(szAuth)) || equal(szAuth, "STEAM_ID_PENDING") || equal(szAuth, "STEAM_ID_LAN")) {
		get_user_ip(id, szAuth, charsmax(szAuth), 1);
	}
	new szVal[16];
	num_to_str(g_iPoints[id], szVal, charsmax(szVal));
	nvault_set(g_iVault, szAuth, szVal);
}

// ==================== 玩家命令 ====================
public cmdPoints(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	LoadPoints(id);

	new szName[32]; get_user_name(id, szName, charsmax(szName));
	new iPts = GetPoints(id);

	client_print(id, print_chat, "[积分] %s 当前积分: \y%d\w 分", szName, iPts);

	if (iPts >= POINTS_REDEEM) {
		client_print(id, print_chat, "[积分] \y恭喜你！\w 你的积分已达 \y%d\w 分，请截图联系管理员兑换皮肤！", POINTS_REDEEM);
	} else {
		client_print(id, print_chat, "[积分] 还差 \y%d\w 分即可兑换皮肤 (%d分)", POINTS_REDEEM - iPts, POINTS_REDEEM);
	}

	return PLUGIN_HANDLED;
}

public client_authorized(id) {
	g_iPoints[id] = 0;
	LoadPoints(id);
}

public client_disconnected(id) {
	g_iPoints[id] = 0;
	g_iMatchFrags[id] = 0;
	g_iMatchDeaths[id] = 0;
}

// ==================== 管理菜单系统 ====================
public cmdPointsAdminChat(id) {
	if (!(get_user_flags(id) & ADMIN_RCON)) {
		client_print(id, print_chat, "[积分] 只有超级管理员可以使用");
		return PLUGIN_HANDLED;
	}
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public cmdPointsAdmin(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

// ★ 主菜单
showMainMenu(id) {
	new szMenu[512], len;
	len = formatex(szMenu, charsmax(szMenu), "\r[积分系统] \w管理员菜单^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \w选择玩家调整积分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w查看排行榜^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \r清除所有玩家积分^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w退出");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<9), szMenu, -1, "PointSysMain");
}

public handleMainMenu(id, key) {
	if (!is_user_connected(id)) return;
	if (!(get_user_flags(id) & ADMIN_RCON)) return;

	switch (key) {
		case 0: showPlayerMenu(id);
		case 1: showLeaderboard(id);
		case 2: ClearAllPoints(id);
		case 9: return;
	}
}

// ★ 玩家列表菜单
showPlayerMenu(id) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new szMenu[1024], len;
	len = formatex(szMenu, charsmax(szMenu), "\r[积分系统] \w选择要调整积分的玩家^n^n");

	new iKeys = 0;
	new iSlot = 0;
	g_iPlayerListCount[id] = 0;

	for (new i = 0; i < iNum && iSlot < 8; i++) {
		new pid = iPlayers[i];
		LoadPoints(pid);
		new szName[32]; get_user_name(pid, szName, charsmax(szName));
		new iPts = GetPoints(pid);

		g_iPlayerList[id][iSlot] = pid;
		g_iPlayerListCount[id]++;

		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d. \w%s \d(%d分)^n", iSlot + 1, szName, iPts);
		iKeys |= (1 << iSlot);
		iSlot++;
	}

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r9. \w刷新列表^n");
	iKeys |= (1 << 8);

	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w返回");
	iKeys |= (1 << 9);

	show_menu(id, iKeys, szMenu, -1, "PointSysPlayers");
}

public handlePlayerMenu(id, key) {
	if (!is_user_connected(id)) return;
	if (!(get_user_flags(id) & ADMIN_RCON)) return;

	if (key == 9) {
		showMainMenu(id);
		return;
	}
	if (key == 8) {
		showPlayerMenu(id);
		return;
	}
	if (key < 0 || key >= g_iPlayerListCount[id]) {
		showPlayerMenu(id);
		return;
	}

	g_iAdminMenuTarget[id] = g_iPlayerList[id][key];
	showActionMenu(id);
}

// ★ 操作菜单
showActionMenu(id) {
	new iTarget = g_iAdminMenuTarget[id];
	if (!is_user_connected(iTarget)) {
		client_print(id, print_chat, "[积分] 玩家已离线");
		showPlayerMenu(id);
		return;
	}

	new szName[32]; get_user_name(iTarget, szName, charsmax(szName));
	LoadPoints(iTarget);
	new iPts = GetPoints(iTarget);

	new szMenu[1024], len;
	len = formatex(szMenu, charsmax(szMenu), "\r[积分系统] \w操作玩家: \y%s\w (%d分)^n^n", szName, iPts);

	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \w+10 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w+50 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \w+100 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \w+500 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5. \w-10 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6. \w-50 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r7. \w-100 分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r8. \r清零积分 (兑换后)^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w返回玩家列表");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9), szMenu, -1, "PointSysAction");
}

public handleActionMenu(id, key) {
	if (!is_user_connected(id)) return;
	if (!(get_user_flags(id) & ADMIN_RCON)) return;

	if (key == 9) {
		showPlayerMenu(id);
		return;
	}

	new iTarget = g_iAdminMenuTarget[id];
	if (!is_user_connected(iTarget)) {
		client_print(id, print_chat, "[积分] 玩家已离线");
		showPlayerMenu(id);
		return;
	}

	LoadPoints(iTarget);
	new szName[32]; get_user_name(iTarget, szName, charsmax(szName));
	new iPts = GetPoints(iTarget);
	new iChange = 0;
	new szAction[16];

	switch (key) {
		case 0: { iChange = 10; copy(szAction, charsmax(szAction), "加了"); }
		case 1: { iChange = 50; copy(szAction, charsmax(szAction), "加了"); }
		case 2: { iChange = 100; copy(szAction, charsmax(szAction), "加了"); }
		case 3: { iChange = 500; copy(szAction, charsmax(szAction), "加了"); }
		case 4: { iChange = -10; copy(szAction, charsmax(szAction), "扣了"); }
		case 5: { iChange = -50; copy(szAction, charsmax(szAction), "扣了"); }
		case 6: { iChange = -100; copy(szAction, charsmax(szAction), "扣了"); }
		case 7: {
			SetPoints(iTarget, 0);
			client_print(0, print_chat, "[积分] 管理员 %n 清除了 %s 的积分（已兑换皮肤）", id, szName);
			showActionMenu(id);
			return;
		}
		default: {
			showActionMenu(id);
			return;
		}
	}

	if (iChange > 0) {
		AddPoints(iTarget, iChange);
	} else if (iChange < 0) {
		new iNew = iPts + iChange;
		if (iNew < 0) iNew = 0;
		SetPoints(iTarget, iNew);
	}

	client_print(0, print_chat, "[积分] 管理员 %n %s %s %d 分，当前: %d分", id, szAction, szName, abs(iChange), GetPoints(iTarget));
	showActionMenu(id);
}

// ==================== 排行榜 ====================
showLeaderboard(id) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new iData[32][2];
	new iCount = 0;
	for (new i = 0; i < iNum; i++) {
		new pid = iPlayers[i];
		LoadPoints(pid);
		iData[iCount][0] = pid;
		iData[iCount][1] = GetPoints(pid);
		iCount++;
	}

	for (new i = 0; i < iCount - 1; i++) {
		for (new j = 0; j < iCount - 1 - i; j++) {
			if (iData[j][1] < iData[j+1][1]) {
				new t0 = iData[j][0], t1 = iData[j][1];
				iData[j][0] = iData[j+1][0];
				iData[j][1] = iData[j+1][1];
				iData[j+1][0] = t0;
				iData[j+1][1] = t1;
			}
		}
	}

	client_print(id, print_chat, "[积分] ====== 排行榜 ======");
	for (new i = 0; i < iCount && i < 10; i++) {
		new pid = iData[i][0];
		new szName[32]; get_user_name(pid, szName, charsmax(szName));
		client_print(id, print_chat, "[积分] 第%d名: %s - %d分", i + 1, szName, iData[i][1]);
	}

	showMainMenu(id);
}

ClearAllPoints(id) {
	if (!(get_user_flags(id) & ADMIN_RCON)) return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		SetPoints(iPlayers[i], 0);
	}

	nvault_prune(g_iVault, 0, get_systime() + 86400);

	client_print(0, print_chat, "[积分] 管理员 %n 清除了所有玩家的积分", id);
	showMainMenu(id);
}
