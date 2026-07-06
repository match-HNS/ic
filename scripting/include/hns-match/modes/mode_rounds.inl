// ============================================
// HnsMatchSystem - Rounds Mode (回合制)
// 先赢N局的队伍获胜
// ============================================

new g_iRoundsTable[6][2] = {
	{0, 0},
	{0, 0},
	{3, 5},
	{4, 7},
	{5, 9},
	{6, 10}
};

public rounds_init() {
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_START]		= CreateOneForward(g_PluginId, "rounds_start");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_END]		= CreateOneForward(g_PluginId, "rounds_stop");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_PAUSE]		= CreateOneForward(g_PluginId, "rounds_pause");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_UNPAUSE]	= CreateOneForward(g_PluginId, "rounds_unpause");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_ROUNDSTART]	= CreateOneForward(g_PluginId, "rounds_roundstart");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_ROUNDEND]	= CreateOneForward(g_PluginId, "rounds_roundend", FP_CELL);
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_FREEZEEND]	= CreateOneForward(g_PluginId, "rounds_freezeend");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_RESTARTROUND]	= CreateOneForward(g_PluginId, "rounds_restartround");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_SWAP]		= CreateOneForward(g_PluginId, "rounds_swap");
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_PLAYER_JOIN]	= CreateOneForward(g_PluginId, "rounds_player_join", FP_CELL);
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_PLAYER_LEAVE]	= CreateOneForward(g_PluginId, "rounds_player_leave", FP_CELL);
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_KILL]		= CreateOneForward(g_PluginId, "rounds_killed", FP_CELL, FP_CELL);
	g_ModFuncs[MODE_ROUNDS][MODEFUNC_FALLDAMAGE]	= CreateOneForward(g_PluginId, "rounds_falldamage", FP_CELL, FP_FLOAT);

	register_clcmd("say /rounds", "cmdRoundsConfig");
	register_clcmd("say_team /rounds", "cmdRoundsConfig");
}

public rounds_start() {
	match_reset_data();

	ChangeGameplay(GAMEPLAY_HNS);

	g_iCurrentMode = MODE_ROUNDS;
	update_hostname_prefix("ROUNDS");
	g_iMatchStatus = MATCH_STARTED;
	g_eMatchState = STATE_PREPARE;

	deserter_match_start();

	g_isTeamTT = HNS_TEAM_A;

	set_cvars_mode(MODE_ROUNDS);

	set_cvar_num("mp_forcecamera", 2);
	set_cvar_num("mp_limitteams", 0);

	loadMapCFG();

	g_iRoundsScoreT = 0;
	g_iRoundsScoreCT = 0;
	g_iRoundsTotalPlayed = 0;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", "TERRORIST");
	g_eMatchInfo[e_mTeamSizeTT] = iNum;
	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();

	new iTeamSize = g_eMatchInfo[e_mTeamSizeTT];
	if (iTeamSize > 5) iTeamSize = 5;
	if (iTeamSize < 2) iTeamSize = 2;
	if (!g_bRoundsManual) {
		g_iRoundsWinRounds = g_iRoundsTable[iTeamSize][0];
		g_iRoundsMaxRounds = g_iRoundsTable[iTeamSize][1];
	}

	hns_restart_round(2.0);

	client_cmd(0, "spk plats/elevbell1.wav");
	setTaskHud(0, 0.0, 1, 255, 255, 255, 3.0, "Going Live in 3 second!");
	setTaskHud(0, 3.1, 1, 255, 255, 255, 3.0, "Live! Live! Live!^nGood Luck & Have Fun!");

	client_print(0, print_chat, "[Rounds] %dv%d | First to %d wins (max %d rounds)", iTeamSize, iTeamSize, g_iRoundsWinRounds, g_iRoundsMaxRounds);

	ExecuteForward(g_hForwards[MATCH_START], _);
}

public rounds_stop() {
	if (task_exists(7010)) remove_task(7010);
	ExecuteForward(g_hForwards[MATCH_CANCEL], _);

	set_cvar_num("mp_forcecamera", 0);

	match_reset_data();
	training_start();
}

public rounds_freezeend() {
	if (g_eMatchState != STATE_ENABLED) {
		return PLUGIN_HANDLED;
	}

	set_task(5.0, "taskCheckAfk");

	if (g_bHnsBannedInit) {
		if (checkUserBan()) {
			return PLUGIN_HANDLED;
		}
	}

	if (g_eMatchInfo[e_mLeaved]) {
		set_task(1.0, "rounds_pause");
	}

	return PLUGIN_HANDLED;
}

public rounds_roundstart() {
	if (g_eMatchState == STATE_PREPARE) {
		g_eMatchState = STATE_ENABLED;
	}

	if (!task_exists(7010)) {
		set_task(1.0, "taskRoundsHud", 7010, .flags = "b");
	}

	cmdShowTimers(0);

	ResetAfkData();

	if (g_bHnsBannedInit) {
		checkUserBan();
	}

	taskCheckLeave();

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", "TERRORIST");
	g_eMatchInfo[e_mTeamSizeTT] = iNum;

	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (!is_user_connected(id)) {
			continue;
		}

		if (getUserTeam(id) == TEAM_TERRORIST || getUserTeam(id) == TEAM_CT) {
			g_ePlayerInfo[id][PLAYER_MATCH] = true;
			copy(g_ePlayerInfo[id][PLAYER_TEAM], charsmax(g_ePlayerInfo[][PLAYER_TEAM]), getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT");
		} else {
			g_ePlayerInfo[id][PLAYER_MATCH] = false;
		}
	}

	set_task(0.3, "taskSaveAfk");
	set_task(3.0, "taskCheckAfk");
}

// ★ FIX P0-1: 用独立的 A/B 分数，不交换，根据 g_isTeamTT 映射
public rounds_roundend(bool:win_ct) {
	if (g_eMatchState != STATE_ENABLED) {
		return;
	}

	g_eMatchState = STATE_PREPARE;

	// 确定本回合获胜方是 A 队还是 B 队
	new HNS_TEAM:winTeam;
	if (win_ct) {
		winTeam = (g_isTeamTT == HNS_TEAM_A) ? HNS_TEAM_B : HNS_TEAM_A;
	} else {
		winTeam = g_isTeamTT;
	}

	// 用独立的 A/B 分数计数
	if (winTeam == HNS_TEAM_A) {
		g_iRoundsScoreT++;
	} else {
		g_iRoundsScoreCT++;
	}

	g_iRoundsTotalPlayed++;

	new szWinnerName[16];
	copy(szWinnerName, charsmax(szWinnerName), winTeam == HNS_TEAM_A ? "A队" : "B队");

	// 检查是否有人获胜
	if (g_iRoundsScoreT >= g_iRoundsWinRounds) {
		client_print(0, print_chat, "[Rounds] A队赢得比赛! 最终比分 A队 %d - %d B队", g_iRoundsScoreT, g_iRoundsScoreCT);
		rounds_finish(1);
		return;
	} else if (g_iRoundsScoreCT >= g_iRoundsWinRounds) {
		client_print(0, print_chat, "[Rounds] B队赢得比赛! 最终比分 A队 %d - %d B队", g_iRoundsScoreT, g_iRoundsScoreCT);
		rounds_finish(2);
		return;
	}

	// 半场换边 — 仅当开启时
	if (g_bRoundsSwapSides && g_iRoundsTotalPlayed == g_iRoundsMaxRounds / 2) {
		rounds_swap();
	}

	// 显示比分
	client_print(0, print_chat, "[Rounds] 第 %d/%d 回合结束 | %s获胜本回合 | 当前比分: A队 %d - %d B队 | 先赢%d局获胜",
		g_iRoundsTotalPlayed, g_iRoundsMaxRounds, szWinnerName, g_iRoundsScoreT, g_iRoundsScoreCT, g_iRoundsWinRounds);

	set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 6.0, 4.0);
	show_hudmessage(0, "[Rounds] %s 获胜!^nA队 %d - %d B队 | 先赢%d局获胜", szWinnerName, g_iRoundsScoreT, g_iRoundsScoreCT, g_iRoundsWinRounds);
}

public rounds_restartround() {
	if (g_eMatchState == STATE_ENABLED) {
		g_eMatchState = STATE_PREPARE;
	}

	ResetAfkData();
}

public rounds_pause() {
	if (g_eMatchState == STATE_PAUSED) {
		return;
	}

	if (task_exists(7010)) remove_task(7010);
	g_eMatchState = STATE_PAUSED;
	ChangeGameplay(GAMEPLAY_TRAINING);
	set_pause_settings();
}

public rounds_unpause() {
	if (g_eMatchState != STATE_PAUSED) {
		return;
	}

	g_eMatchState = STATE_PREPARE;

	hns_restart_round(1.0);

	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();

	ChangeGameplay(GAMEPLAY_HNS);

	set_unpause_settings();
}

// ★ FIX P0-1: 换边不再交换分数
public rounds_swap() {
	g_isTeamTT = HNS_TEAM:!g_isTeamTT;

	// 只交换玩家阵营，不交换 A/B 分数
	rg_swap_all_players();

	ResetAfkData();
}

public rounds_killed(victim, killer) {
}

public rounds_falldamage(id, Float:flDmg) {
}

// ★ FIX P1-8: 用 g_iRoundsTotalPlayed 判断换边，而非 Mix 模式数据
public rounds_player_join(id) {
	if (deserter_is_banned(id)) {
		new iRemaining = deserter_get_ban_remaining(id);
		new szTime[32];
		if (iRemaining >= 3600) {
			formatex(szTime, charsmax(szTime), "%dh %dmin", iRemaining / 3600, (iRemaining % 3600) / 60);
		} else {
			formatex(szTime, charsmax(szTime), "%dmin", iRemaining / 60);
		}
		chat_print(id, "[HNS] You are banned from matches for %s (%d desertions).", szTime, g_iDesertCount[id]);
		transferUserToSpec(id);
		return;
	}

	TrieGetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iNum = get_num_players_in_match(id);

		new bool:bReplaced = iNum >= g_eMatchInfo[e_mTeamSize] ? true : false;

		ExecuteForward(g_hForwards[MATCH_JOIN_PLAYER], _, id, bReplaced);

		if (bReplaced) {
			transferUserToSpec(id);
			return;
		}

		// ★ FIX: 用 g_iRoundsTotalPlayed 判断换边
		new iSwapAt = g_iRoundsMaxRounds / 2;
		new bool:bSwapped = (g_bRoundsSwapSides && g_iRoundsTotalPlayed >= iSwapAt);

		if (bSwapped) {
			// 换边后，T/CT 标签已交换，需要反转原始阵营
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_CT : TEAM_TERRORIST);
		} else {
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_TERRORIST : TEAM_CT);
		}

		if (g_eMatchState == STATE_PAUSED)
			rg_round_respawn(id);
	} else {
		transferUserToSpec(id);
		return;
	}
}

public rounds_player_leave(id) {
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		// ★ FIX: 记录当前总回合数而非 Mix 数据
		g_ePlayerInfo[id][LEAVE_IN_ROUND] = g_iRoundsTotalPlayed;

		deserter_apply_penalty(id);
		deserter_save(id);
	}

	ExecuteForward(g_hForwards[MATCH_LEAVE_PLAYER], _, id);

	TrieSetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}

// HUD
public taskRoundsHud() {
	if (g_eMatchState != STATE_ENABLED || g_iCurrentMode != MODE_ROUNDS) {
		if (task_exists(7010)) remove_task(7010);
		return;
	}
	
	new szHud[256];
	format(szHud, charsmax(szHud), "回合制 | 第 %d/%d 回合^nA %d  -  %d B | 先赢 %d 局",
		g_iRoundsTotalPlayed + 1, g_iRoundsMaxRounds,
		g_iRoundsScoreT, g_iRoundsScoreCT, g_iRoundsWinRounds);
	
	set_hudmessage(255, 255, 255, -1.0, 0.06, 0, 0.0, 1.5, 0.1, 0.0, -1);
	show_hudmessage(0, szHud);
}

// ★ FIX P2-9: MATCH_FINISH_POST 移到 match_reset_data 之前
stock rounds_finish(iWinTeam) {
	if (task_exists(7010)) remove_task(7010);
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);

	deserter_clear_on_match_end();
	matchControl_reset();

	chat_print(0, "Team %s wins the match! (^3%d-%d^1)", iWinTeam == 1 ? "A" : "B", g_iRoundsScoreT, g_iRoundsScoreCT);

	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "Game Over");

	// ★ FIX: POST forward 在重置之前触发，让外部插件能读到比赛状态
	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);

	match_reset_data();

	training_start();
}

// ============================================================
//  === 回合数动态调整菜单 (/rounds) ===
// ============================================================
public cmdRoundsConfig(id) {
	if (!isUserWatcher(id)) {
		client_print(id, print_chat, "[Rounds] 只有管理员可以调整回合设置");
		return PLUGIN_HANDLED;
	}
	showRoundsConfigMenu(id);
	return PLUGIN_HANDLED;
}

showRoundsConfigMenu(id) {
	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r回合比赛设置 \d- 动态调整^n^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w获胜回合: \y%d (-1)^n", g_iRoundsWinRounds);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w获胜回合: \y%d (+1)^n", g_iRoundsWinRounds);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w最大回合: \y%d (-1)^n", g_iRoundsMaxRounds);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w最大回合: \y%d (+1)^n", g_iRoundsMaxRounds);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w半场换边: \y%s^n", g_bRoundsSwapSides ? "开启" : "关闭");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r6. \w根据人数自动设定回合数^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r7. \w设置完成^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w退出");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), szMenu, -1, "HnsRoundsConfig");
}

public roundsConfigMenuHandler(id, key) {
	if (key == 9) return;

	if (key == 0) {
		if (g_iRoundsWinRounds > 2) {
			g_iRoundsWinRounds--;
			g_bRoundsManual = true;
		}
		showRoundsConfigMenu(id);
	} else if (key == 1) {
		if (g_iRoundsWinRounds < g_iRoundsMaxRounds) {
			g_iRoundsWinRounds++;
			g_bRoundsManual = true;
		}
		showRoundsConfigMenu(id);
	} else if (key == 2) {
		if (g_iRoundsMaxRounds > g_iRoundsWinRounds + 1) {
			g_iRoundsMaxRounds--;
			if (g_iRoundsWinRounds > g_iRoundsMaxRounds)
				g_iRoundsWinRounds = g_iRoundsMaxRounds;
			g_bRoundsManual = true;
		}
		showRoundsConfigMenu(id);
	} else if (key == 3) {
		if (g_iRoundsMaxRounds < 20) {
			g_iRoundsMaxRounds++;
			g_bRoundsManual = true;
		}
		showRoundsConfigMenu(id);
	} else if (key == 4) {
		g_bRoundsSwapSides = !g_bRoundsSwapSides;
		client_print(0, print_chat, "[Rounds] 管理员 %n 将半场换边设为: %s", id, g_bRoundsSwapSides ? "开启" : "关闭");
		showRoundsConfigMenu(id);
	} else if (key == 5) {
		g_bRoundsManual = false;
		new iTeamSize = g_eMatchInfo[e_mTeamSizeTT];
		if (iTeamSize > 5) iTeamSize = 5;
		if (iTeamSize < 2) iTeamSize = 2;
		g_iRoundsWinRounds = g_iRoundsTable[iTeamSize][0];
		g_iRoundsMaxRounds = g_iRoundsTable[iTeamSize][1];
		client_print(id, print_chat, "[Rounds] 已根据 %dv%d 自动设定: 先赢%d局 / 最多%d局", iTeamSize, iTeamSize, g_iRoundsWinRounds, g_iRoundsMaxRounds);
		showRoundsConfigMenu(id);
	} else if (key == 6) {
		client_print(id, print_chat, "[Rounds] 回合设置: 先赢 %d 局 (最多 %d 局) | 换边: %s", g_iRoundsWinRounds, g_iRoundsMaxRounds, g_bRoundsSwapSides ? "开启" : "关闭");
	}
}
