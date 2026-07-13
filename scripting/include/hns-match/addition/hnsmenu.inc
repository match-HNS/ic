#if defined _hnsmenu_included
  #endinput
#endif

#define _hnsmenu_included

// ★ FIX: ChatManager 前缀 native 声明（由 HnsMatchChatmanager.sma 提供）
native cm_set_prefix(id, const prefix[]);
native cm_reset_prefix(id);

// ============================================================================
// PERMISSION HELPERS (uses AMXX flags)
// ============================================================================
// Levels: 0 = 普通, 1 = 辅助 (flag f+i), 2 = VIP (flag b), 3 = 管理员 (flag d+e+f+i), 4 = 服主 (full flags)
stock hns_set_user_perm_level(id, level) {
	if (!is_user_connected(id)) return;
	if (level == 4)
		set_user_flags(id, read_flags("abcdefghijklmn"));
	else if (level == 3)
		set_user_flags(id, read_flags("defi"));
	else if (level == 2)
		set_user_flags(id, read_flags("b"));
	else if (level == 1)
		set_user_flags(id, read_flags("fi"));
	else
		set_user_flags(id, 0);
}

stock hns_get_user_perm_level(id) {
	new flags = get_user_flags(id);
	// Check from highest to lowest: owner, admin, VIP, helper
	if (flags & read_flags("m")) return 4;
	if (flags & read_flags("d")) return 3;
	if (flags & read_flags("b")) return 2;
	if (flags & read_flags("f")) return 1;
	return 0;
}

// ============================================================================
// HnsICMatch v5.0.1 - Unified Menu System
// Replaces the original LINNA v4.2.0 hnsmenu.inc
//
// Menu Structure (M key / nightvision / /mix / /menu):
//   Main Menu (6 categories):
//     1. 比赛管理    - Start/Stop/Pause/Surrender/Map
//     2. AI报名分组  - AI Signup System
//     3. 选择模式    - Mode Selection
//     4. 训练工具    - Training Tools
//     5. 个人设置    - Personal Settings
//     6. 管理工具    - Admin Tools (Watcher+)
// ============================================================================

// --- Per-player toggle states ---
new bool:g_bHudEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bModeHudEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bSpecListEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bJumpStatsEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bTrainingPage2[MAX_PLAYERS + 1] = {false, ...};

// --- Match start vote ---
new bool:g_bMatchVoteActive;
new g_iMatchVoteCount;
new g_bMatchVoted[MAX_PLAYERS + 1];
new g_iMatchVoteInitiator;
new bool:g_bVoteApproved[MAX_PLAYERS + 1];

// ============================================================================
// INIT - Register menu command and reset per-player vars
// ============================================================================

// ============================================
// 菜单初始化 - 注册所有菜单回调
// ============================================
stock hnsmenu_init() {
	// Menu commands are registered in cmds.inc
	// Register menucmds for old-style show_menu() callbacks

	new iMenuId;
	new ALL        = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9);
	new K_MAP      = (1<<0)|(1<<1)|(1<<2)|(1<<8)|(1<<9);
	new K_STATS    = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9);

	// Main + Match
	iMenuId = register_menuid("HnsICMainMenu");
	register_menucmd(iMenuId, ALL, "handlerMainMenu");

	iMenuId = register_menuid("HnsICMatchMenu");
	register_menucmd(iMenuId, ALL, "matchMenuHandler");

	// Mode Select
	iMenuId = register_menuid("HnsICModeSelect");
	register_menucmd(iMenuId, ALL, "HandlerSelectMode");

	// Confirm
	iMenuId = register_menuid("HnsICConfirm");
	register_menucmd(iMenuId, (1<<0)|(1<<1)|(1<<9), "verifMenuHandler");

	// Training
	iMenuId = register_menuid("HnsICTrainingMenu");
	register_menucmd(iMenuId, ALL, "trainingMenuHandler");

	// Personal
	iMenuId = register_menuid("HnsICPersonalMenu");
	register_menucmd(iMenuId, ALL, "personalMenuHandler");

	// Map
	iMenuId = register_menuid("HnsICMapMenu");
	register_menucmd(iMenuId, K_MAP, "mapMenuHandler");

	// Stats
	iMenuId = register_menuid("HnsICStatsMenu");
	register_menucmd(iMenuId, K_STATS, "statsMenuHandler");

	// Permissions
	iMenuId = register_menuid("HnsICPermMenu");
	register_menucmd(iMenuId, K_STATS, "permMenuHandler");

	// Admin
	iMenuId = register_menuid("HnsICAdminMenu");
	register_menucmd(iMenuId, ALL, "adminMenuHandler");

	// AI Signup
	iMenuId = register_menuid("HnsICAISignup");
	register_menucmd(iMenuId, ALL, "aiSignupMenuHandler");
}

public handlerMainMenu(id, key) {
	if (key == 9) {
		show_menu(id, 0, "^n", 1);
		return PLUGIN_HANDLED;
	}

	switch (key) {
		case 0: showMatchMenu(id);                           // 比赛管理
		case 1: showAISignupMenu(id);                        // AI报名
		case 2: menuSelectMode(id);                          // 选择模式
		case 3: {                                            // 训练工具
			if (g_iCurrentMode == MODE_TRAINING)
				client_cmd(id, "say /tr");
			else {
				client_print(id, print_chat, "[HNS] 训练工具仅在训练模式下可用！");
				showMainMenu(id);
			}
		}
		case 4: showPersonalMenu(id);                        // 个人设置
		case 5: {                                            // 管理工具
			if (isUserWatcher(id) || isUserFullWatcher(id) || is_user_admin(id))
				showAdminMenu(id);
			else {
				client_print(id, print_chat, "[HNS] 你没有管理权限！");
				showMainMenu(id);
			}
		}
	}

	return PLUGIN_HANDLED;
}

// ★ 延迟1秒后加载权限（等 SteamID 验证完成）
new bool:g_bHnsPermsLoaded = false;

stock hnsmenu_client_putinserver(id) {
	g_bHudEnabled[id] = true;
	g_bModeHudEnabled[id] = true;
	g_bSpecListEnabled[id] = true;
	g_bJumpStatsEnabled[id] = true;
	g_bTrainingPage2[id] = false;
}

// ★ 每张地图首次有人进服时加载一次 hns_perms.ini
public hns_perm_delayed_load() {
	if (g_bHnsPermsLoaded) return;
	g_bHnsPermsLoaded = true;
	hns_perm_load_all();
}

// ============================================================================
// MAIN MENU - Entry point (M key / nightvision)
// ============================================================================

public cmdMainMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!g_bHnsPermsLoaded)
		set_task(1.0, "hns_perm_delayed_load", 0);

	showMainMenu(id);
	return PLUGIN_HANDLED;
}

// ============================================================================
// AI GROUPING MENU (AI分组菜单) — 新版集成
// ============================================================================

showAISignupMenu(id) {
	new szState[32];
	switch (g_eAISState) {
		case AIS_IDLE:          copy(szState, charsmax(szState), "\d空闲");
		case AIS_SIGNUP:        copy(szState, charsmax(szState), "\y报名中");
		case AIS_KNIFE_PENDING: copy(szState, charsmax(szState), "\y拼刀待命");
		case AIS_KNIFE_ACTIVE:  copy(szState, charsmax(szState), "\r拼刀中");
		case AIS_VOTE_MODE:     copy(szState, charsmax(szState), "\y投票中");
		case AIS_FINAL:         copy(szState, charsmax(szState), "\g准备开始");
		case AIS_LOCKED:        copy(szState, charsmax(szState), "\r比赛中");
	}

	new iOnline = 0;
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	iOnline = iNum;

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\rAI报名系统^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r状态: %s | 在线: %d人^n", szState, iOnline);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r已报名: %d/%d^n^n", g_iAISSignedCount, g_iAISTeamSize * 2);

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w报名参加 (/join)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w取消报名 (/unjoin)^n");

	if (g_eAISState == AIS_VOTE_MODE)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w投票选模式^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d3. 投票选模式^n");

	if (isUserWatcher(id))
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. \w管理设置^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\d8. 管理设置^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<9);
	if (isUserWatcher(id)) iKeys |= (1<<7);
	show_menu(id, iKeys, szMenu, -1, "HnsICAISignup");
}

public aiSignupMenuHandler(id, key) {
	if (key == 9) {
		showMainMenu(id);
		return;
	}

	if (key == 0) {
		// 报名
		aisJoin(id);
	} else if (key == 1) {
		// 取消报名
		aisUnjoin(id);
	} else if (key == 2) {
		// 投票选模式
		if (g_eAISState == AIS_VOTE_MODE)
			aisShowVoteMenu(id);
		else
			client_print(id, print_chat, "[AI报名] 当前非投票阶段。");
	} else if (key == 7) {
		// 管理设置
		if (isUserWatcher(id))
			aisShowMainMenu(id);
	}
}

getModeDisplayName(szOut[], iLen) {
	switch (g_iCurrentMode) {
		case MODE_TRAINING: { copy(szOut, iLen, "训练模式"); }
		case MODE_KNIFE: { copy(szOut, iLen, "拼刀模式"); }
		case MODE_MIX: { copy(szOut, iLen, "混合赛"); }
		case MODE_PUB: { copy(szOut, iLen, "公共模式"); }
		case MODE_DM: { copy(szOut, iLen, "死亡竞赛"); }
		case MODE_ASCENSION: { copy(szOut, iLen, "飞升模式"); }
		case MODE_VAMP: { copy(szOut, iLen, "吸血鬼模式"); }
		case MODE_ROUNDS: { copy(szOut, iLen, "回合制"); }
		case MODE_ZM: { copy(szOut, iLen, "僵尸模式"); }
		default: { copy(szOut, iLen, "空闲"); }
	}
}

showMainMenu(id) {
	new szMenu[512], iLen;
	new szMapName[32], szModeName[32];
	new iPlayers[32], iNum, iMax;

	rh_get_mapname(szMapName, charsmax(szMapName));
	getModeDisplayName(szModeName, charsmax(szModeName));
	get_players(iPlayers, iNum, "ch");
	iMax = get_maxplayers();

	iLen = formatex(szMenu, charsmax(szMenu), "\rGTR HNS  \d— \w比赛系统 \rv1.0.1^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y地图: \w%s  \d|  \y模式: \w%s^n", szMapName, szModeName);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y在线: \w%d/%d 玩家^n^n", iNum, iMax);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w比赛管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wAI报名分组^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w选择模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w训练工具^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w个人设置^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w管理工具^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w退出");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), szMenu, -1, "HnsICMainMenu");
}

// ============================================================================
// 1. MATCH MANAGEMENT MENU (Watcher+)
// ============================================================================

showMatchMenu(id) {
	new bool:bIsAdmin = isUserWatcher(id) || is_user_admin(id);

	new szMenu[512], iLen;

	iLen = formatex(szMenu, charsmax(szMenu), "\r比赛管理^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w开始比赛 (提前)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w暂停比赛^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w投票换图^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w投降^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w地图管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9), szMenu, -1, "HnsICMatchMenu");
}

public matchMenuHandler(id, key) {
	if (key == 9) {
		showMainMenu(id); return;
	}

	switch (key) {
		case 0: { // 开始比赛
			if (isUserWatcher(id) || is_user_admin(id)) {
				menuSelectMode(id);
			} else {
				startMatchVote(id);
			}
		}
		case 1: { // 暂停比赛
			if (g_eMatchState != STATE_PAUSED)
				cmdStartPause(id);
			else
				cmdStopPause(id);
		}
		case 2: { // 投票换图
			client_cmd(id, "say /rtv");
		}
		case 3: { // 投降
			cmdSurrender(id);
		}
		case 4: { // 地图管理
			showMapMenu(id);
		}
	}
}

// ============================================================================
// MODE SELECT MENU (Sub-menu of Match Management)
// ============================================================================

public menuSelectMode(id) {
	if (!isUserWatcher(id) && !is_user_admin(id) && !g_bVoteApproved[id])
		return;

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(id, "已在 in Mix mode.");
		return;
	}

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r选择游戏模式^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wMR (最大回合数)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w计时模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w决斗 (1v1)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w突围模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w吸血模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w回合制^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w公共模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w死亡竞赛^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w僵尸模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICModeSelect");
}

public HandlerSelectMode(id, key) {
	if (key == 9) {
	    showMatchMenu(id);
	    return;
	}

	// 选择了模式，清除临时投票授权
	g_bVoteApproved[id] = false;

	if (key == 0) {
	    { cmdMrMode(id); cmdStartMatch(id); }
	} else if (key == 1) {
	    { cmdWintimeMode(id); cmdStartMatch(id); }
	} else if (key == 2) {
	    { cmdDuelMode(id); cmdStartMatch(id); }
	} else if (key == 3) {
	    { cmdAscensionMode(id); }
	} else if (key == 4) {
	    { cmdVampMode(id); }
	} else if (key == 5) {
	    { cmdRoundsMode(id); }
	} else if (key == 6) {
	    { cmdPubMode(id); }
	} else if (key == 7) {
	    { cmdDMMode(id); }
	} else if (key == 8) {
	    { cmdZMMode(id); }
	}
}

// ============================================================================
// MATCH START VOTE (Player-initiated match start)
// ============================================================================

stock startMatchVote(id) {
	if (g_bMatchVoteActive) {
		chat_print(id, "已有投票正在进行中。");
		return;
	}

	// 统计当前服务器玩家数
	new p[MAX_PLAYERS], n;
	get_players(p, n, "ch");

	// 1人直接开，不用投票
	if (n <= 1) {
		chat_print(0, "^3%n^1 直接开始比赛（服务器仅1人）", id);
		g_bVoteApproved[id] = true;
		menuSelectMode(id);
		return;
	}

	// 2人以上需要投票
	g_bMatchVoteActive = true;
	g_iMatchVoteCount = 0;
	g_iMatchVoteInitiator = id;
	for (new i = 1; i <= MaxClients; i++) {
		g_bMatchVoted[i] = false;
	}

	new szMenu[128];
	formatex(szMenu, charsmax(szMenu), "\r比赛开始投票 \y|%n发起^n^n是否开始混合赛？", id);

	for (new i = 0; i < n; i++) {
		new hMenu = menu_create(szMenu, "handleMatchVote");
		menu_additem(hMenu, "\y是，开始比赛");
		menu_additem(hMenu, "\r否");
		menu_setprop(hMenu, MPROP_EXIT, MEXIT_NEVER);
		menu_display(p[i], hMenu, 0, 15);
	}

	chat_print(0, "^3%n^1 发起了比赛开始投票 (需要多数同意)", id);

	// 15秒后结束投票
	set_task(15.0, "finishMatchVote");
}

public handleMatchVote(id, hMenu, item) {
	menu_destroy(hMenu);
	if (!g_bMatchVoteActive) return;
	if (g_bMatchVoted[id]) return;

	g_bMatchVoted[id] = true;

	if (item == 0) {
		g_iMatchVoteCount++;
		chat_print(0, "^3%n^1 投票同意开始比赛 (%d票)", id, g_iMatchVoteCount);
		// 多数通过（超过半数）
		new p[MAX_PLAYERS], n;
		get_players(p, n, "ch");
		if (g_iMatchVoteCount > n / 2) {
			finishMatchVote();
		}
	} else {
		chat_print(0, "^3%n^1 投票拒绝开始比赛", id);
	}
}

public finishMatchVote() {
	if (!g_bMatchVoteActive) return;
	g_bMatchVoteActive = false;

	new p[MAX_PLAYERS], n;
	get_players(p, n, "ch");

	if (g_iMatchVoteCount > n / 2) {
		chat_print(0, "比赛开始投票通过！开始选择模式...");
		g_bVoteApproved[g_iMatchVoteInitiator] = true;
		menuSelectMode(g_iMatchVoteInitiator);
	} else {
		chat_print(0, "比赛开始投票未通过。");
	}
}

// customMenu/settingsMatchMenu/showPointScoreMenu/showKnifeSettingsMenu/quickActionsMenu/VoteRules/MapPick 已删除 - 不再需要

// ============================================================================
// VERIFY / CONFIRM MENU
// ============================================================================

public verifMenu(id) {
	if (!is_user_connected(id))
		return;

	new szMenu[256], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r确认^n^n\d停止当前模式?^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w否^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w是^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w退出");

	show_menu(id, (1<<0)|(1<<1)|(1<<9), szMenu, -1, "HnsICConfirm");
}

public verifMenuHandler(id, key) {
	if (key == 0) {
	    return; // No
	} else if (key == 1) {
	    cmdStop(id); // Yes
	} else if (key == 9) {
	    return; // Exit
	}
}

// VoteRules/MapPick 已删除 - 不再需要

// MapPick 已删除 - 不再需要

// ============================================================================
// ASCENSION / VAMPIRE MODE LAUNCHERS
// ============================================================================

public cmdAscensionMode(id) {
	if (!isUserWatcher(id) && !is_user_admin(id))
		return;
	g_iCurrentRules = RULES_POINTSCAP;
	set_pcvar_string(pCvar[GAMENAME], "HNS Mix [Ascension]");
	cmdStartMatch(id);
}

public cmdVampMode(id) {
	if (!isUserWatcher(id) && !is_user_admin(id))
		return;
	g_iCurrentRules = RULES_VAMP;
	set_pcvar_string(pCvar[GAMENAME], "HNS Mix [Vampire]");
	cmdStartMatch(id);
}

public cmdRoundsMode(id) {
	if (!isUserWatcher(id) && !is_user_admin(id))
		return;
	g_iCurrentRules = RULES_MR; // 回合制基于MR规则
	rounds_start();
}

// ============================================================================
// 2. TRAINING TOOLS MENU (All players, 2 pages)
// ============================================================================

showTrainingMenu(id) {
	// ★ 训练工具仅在训练模式下可用
	if (g_iCurrentMode != MODE_TRAINING) {
		client_print(id, print_chat, "[HNS] 训练工具仅在训练模式下可用！");
		showMainMenu(id);
		return;
	}

	new szMenu[512], iLen;
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y训练工具 \d(1/2)^n^n", szPrefix);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w保存记录点^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w传送到记录点^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w切换CP/自救^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w重生^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w穿墙^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w钩子^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w鸟狙^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \wUSP手枪^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \wAWP狙击^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w下一页");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICTrainingMenu");
}

showTrainingMenuPage2(id) {
	new szMenu[512], iLen;
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y训练工具 \d(2/2)^n^n", szPrefix);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wM4A1步枪^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w闪光弹^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w全部武器^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w显示伤害^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w保存角度^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<8)|(1<<9), szMenu, -1, "HnsICTrainingMenu");
}

public trainingMenuHandler(id, key) {
	if (g_bTrainingPage2[id]) {
		g_bTrainingPage2[id] = false;
		if (key == 0) {
		    {
		    				client_cmd(id, "say /m4a1");
		    				showTrainingMenuPage2(id);
		    			}
		} else if (key == 1) {
		    {
		    				client_cmd(id, "say /flash");
		    				showTrainingMenuPage2(id);
		    			}
		} else if (key == 2) {
		    {
		    				client_cmd(id, "say /weapons");
		    				showTrainingMenuPage2(id);
		    			}
		} else if (key == 3) {
		    {
		    				client_cmd(id, "say /dmg");
		    				showTrainingMenuPage2(id);
		    			}
		} else if (key == 4) {
		    {
		    				client_cmd(id, "say /angles");
		    				showTrainingMenuPage2(id);
		    			}
		} else {
		    showTrainingMenu(id);
		}
		return;
	}

	if (key == 0) {
	    {
	    			client_cmd(id, "say /cp");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 1) {
	    {
	    			client_cmd(id, "say /tp");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 2) {
	    {
	    			client_cmd(id, "say /st");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 3) {
	    {
	    			client_cmd(id, "say /rp");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 4) {
	    {
	    			client_cmd(id, "say /clip");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 5) {
	    {
	    			client_cmd(id, "say /hook");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 6) {
	    {
	    			client_cmd(id, "say /scout");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 7) {
	    {
	    			client_cmd(id, "say /usp");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 8) {
	    {
	    			client_cmd(id, "say /awp");
	    			showTrainingMenu(id);
	    		}
	} else if (key == 9) {
	    {
	    			g_bTrainingPage2[id] = true;
	    			showTrainingMenuPage2(id);
	    		}
	}
}

// ============================================================================
// 3. PERSONAL SETTINGS MENU (All players)
// ============================================================================

showPersonalMenu(id) {
	new szMenu[512], iLen;

	iLen = formatex(szMenu, charsmax(szMenu), "\r个人设置^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wT皮肤选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wCT皮肤选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w刀模选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w玩家HUD \y[\r%s\y]^n", g_bHudEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w观战列表 \y[\r%s\y]^n", g_bSpecListEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w发放皮肤管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), szMenu, -1, "HnsICPersonalMenu");
}

public personalMenuHandler(id, key) {
	if (key == 9) {
		showMainMenu(id); return;
	}

	switch (key) {
		case 0: { client_cmd(id, "say /skin_t"); }           // T皮肤选择
		case 1: { client_cmd(id, "say /skin_ct"); }          // CT皮肤选择
		case 2: { client_cmd(id, "say /skin_knife"); }       // 刀模选择
		case 3: {                                            // 玩家HUD
			g_bHudEnabled[id] = !g_bHudEnabled[id];
			chat_print(id, "[HNS] 玩家HUD: %s", g_bHudEnabled[id] ? "开" : "关");
			showPersonalMenu(id);
		}
		case 4: {                                            // 观战列表
			g_bSpecListEnabled[id] = !g_bSpecListEnabled[id];
			chat_print(id, "[HNS] 观战列表: %s", g_bSpecListEnabled[id] ? "开" : "关");
			showPersonalMenu(id);
		}
		case 5: {                                            // 发放皮肤管理
			client_cmd(id, "say /adminskin");
		}
	}
}

// taskReopenPersonalMenu 已删除 - 不再使用 task 延迟

// taskReopenDistributeMenu 等已删除 - 无需回调

// ============================================================================
// 4. MAP MANAGEMENT MENU (Watcher+)
// ============================================================================

showMapMenu(id) {
	if (!isUserWatcher(id) && !is_user_admin(id)) {
		showMainMenu(id);
		return;
	}

	new szMenu[256], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r地图管理^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w地图列表^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w地图投票^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w当前地图信息^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<8)|(1<<9), szMenu, -1, "HnsICMapMenu");
}

public mapMenuHandler(id, key) {
	if (key == 0) {
	    client_cmd(id, "say /maps");
	} else if (key == 1) {
	    client_cmd(id, "say /maps");
	} else if (key == 2) {
	    {
	    			new szMapName[32];
	    			rh_get_mapname(szMapName, charsmax(szMapName));
	    			chat_print(id, "Current Map: %s", szMapName);
	    			set_task(0.3, "taskReopenMapMenu", id);
	    		}
	} else if ((key == 7 || key == 8)) {
	    showMainMenu(id); // Back
	}
}

public taskReopenMapMenu(id) {
	if (is_user_connected(id))
		showMapMenu(id);
}

// ============================================================================
// 5. STATISTICS MENU (All players)
// ============================================================================

showStatsMenu(id) {
	new szMenu[256], iLen;
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y数据统计^n^n", szPrefix);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w我的数据^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w伤害查询^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w本局最佳^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w玩家排行^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9), szMenu, -1, "HnsICStatsMenu");
}

public statsMenuHandler(id, key) {
	if (key == 0) {
	    client_cmd(id, "say /top");
	} else if (key == 1) {
	    client_cmd(id, "say /showdmg");
	} else if (key == 2) {
	    client_cmd(id, "say /pts");
	} else if (key == 3) {
	    client_cmd(id, "say /top");
	} else if ((key == 7 || key == 8)) {
	    showMainMenu(id); // Back
	}
}

// ============================================================================
// 6. DISPLAY SETTINGS MENU (All players)
// ============================================================================

// showDisplayMenu 已删除 - 合并到个人设置

// ============================================================================
// 7. PERMISSION MANAGEMENT MENU (Watcher+)
// ============================================================================

showPermMenu(id) {
	// Allow any AMXX admin even without watcher flag
	if (!isUserWatcher(id) && !is_user_admin(id)) {
		showMainMenu(id);
		return;
	}

	new szMenu[256], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r权限管理 \d- 管理功能^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w身份验证 (/vipadmin)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w管理功能 (/admin)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w踢出玩家^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w封禁玩家^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9), szMenu, -1, "HnsICPermMenu");
}

public permMenuHandler(id, key) {
	if (key == 0) {
	    client_cmd(id, "say /vipadmin");    // 身份验证
	} else if (key == 1) {
	    client_cmd(id, "say /admin");       // 管理功能
	} else if (key == 2) {
	    client_cmd(id, "amx_kickmenu");     // 踢出玩家
	} else if (key == 3) {
	    client_cmd(id, "amx_banmenu");      // 封禁玩家
	} else if ((key == 7 || key == 8)) {
	    showMainMenu(id); // Back
	}
}

// ============================================================================
// 8. ADMIN TOOLS MENU (FullWatcher+)
// ============================================================================

showAdminMenu(id) {
	if (!isUserFullWatcher(id) && !is_user_admin(id)) {
		showMainMenu(id);
		return;
	}

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r管理工具^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w观战管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w替换玩家^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w比赛控制^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \wAI队伍^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w踢出/封禁^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w逃兵解封^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w发放管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), szMenu, -1, "HnsICAdminMenu");
}

public adminMenuHandler(id, key) {
	if (key == 9) {
		showMainMenu(id); return;
	}

	switch (key) {
		case 0: { client_cmd(id, "say /watcher"); }           // 观战管理
		case 1: { client_cmd(id, "say /replace"); }           // 替换玩家
		case 2: { matchControl_admin_menu(id); }              // 比赛控制
		case 3: { client_cmd(id, "say /ai"); }                // AI队伍
		case 4: { client_cmd(id, "say /kickmenu"); }          // 踢出/封禁 (使用AMXX内置菜单)
		case 5: { client_cmd(id, "say /unban"); }             // 逃兵解封
		case 6: { client_cmd(id, "say /adminskin"); }         // 发放管理
	}
}

// ============================================================================
// BAN/KICK SUBMENU (FullWatcher+)
// ============================================================================

// showBanKickMenu 已删除 - 合并到管理工具

// ============================================================================
// SERVER CONSOLE MENU (FullWatcher+)
// ============================================================================

// showServerConsoleMenu 已删除 - 无需菜单

// ============================================================================
// MAP CHANGE MENU
// ============================================================================

// showMapChangeMenu 已删除 - 无需菜单

// ============================================================================
// BACKWARD COMPATIBILITY - Old menu entry points
// ============================================================================

// Keep old function names so existing cmds.inc references still work
public mainMatchMenu(id) {
	cmdMainMenu(id);
}

// ============================================================================
// ACCESSOR STOCKS - For other plugins to read toggle states
// ============================================================================

stock bool:hnsmenu_get_hud(id) { return g_bHudEnabled[id]; }
stock bool:hnsmenu_get_modehud(id) { return g_bModeHudEnabled[id]; }
stock bool:hnsmenu_get_speclist(id) { return g_bSpecListEnabled[id]; }
stock bool:hnsmenu_get_jumpstats(id) { return g_bJumpStatsEnabled[id]; }

// ============================================================================
// TEAM JOIN MENU - 加入队伍
// ============================================================================

// showTeamJoinMenu 已删除 - 合并到主菜单

// ============================================================================
// DISTRIBUTE MANAGEMENT MENU (发放管理) - FullWatcher+
// ============================================================================

// showDistributeMenu 已删除 - 皮肤系统已内置

// ============================================================================
// SKIN DISTRIBUTION TYPE MENU - Step 2 of 3 (select T/CT/Knife)
// ============================================================================
// 已废弃：旧分发皮肤菜单已被 showPersonalSkinDistribType 替代
// 保留 stub 防止编译错误

// showDistributePlayerList 已删除 - 皮肤系统已内置

// ============================================================================
// PERSONAL SKIN DISTRIBUTE - 个人菜单 → 发放皮肤管理
// ============================================================================
// showPersonalSkinDistribPlayerList 已删除 - 皮肤系统已内置

// showPersonalSkinDistribType 已删除 - 皮肤系统已内置

// ============================================================================
// PERM SAVE HELPER — 写入 hns_perms.ini (独立权限文件，不碰 users.ini)
// 每次地图加载时自动读取 hns_perms.ini 并设置 flags
// ============================================================================
hns_perm_save_by_auth(szAuth[], perm) {
	new szDir[128], szFile[256];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szFile, charsmax(szFile), "%s/hns_perms.ini", szDir);

	// 确保目录存在
	new szSubDir[128];
	formatex(szSubDir, charsmax(szSubDir), "%s/mixsystem", szDir);
	if (!dir_exists(szSubDir)) mkdir(szSubDir);

	// 权限 flags
	new szFlags[24];
	if (perm == 4)      copy(szFlags, charsmax(szFlags), "abcdefghijklmn");
	else if (perm == 3) copy(szFlags, charsmax(szFlags), "defi");
	else if (perm == 2) copy(szFlags, charsmax(szFlags), "b");
	else if (perm == 1) copy(szFlags, charsmax(szFlags), "fi");
	else                copy(szFlags, charsmax(szFlags), "");

	// 读写 hns_perms.ini: 跳过旧条目，写入新条目
	new bool:bFound = false;
	new fpIn, fpOut;
	new szLine[512];
	new szTmp[256];
	formatex(szTmp, charsmax(szTmp), "%s/hns_perms.tmp", szDir);

	if (file_exists(szFile)) {
		fpIn = fopen(szFile, "rt");
		fpOut = fopen(szTmp, "wt");
		if (fpIn && fpOut) {
			new szReadAuth[64];
			while (!feof(fpIn)) {
				fgets(fpIn, szLine, charsmax(szLine));
				trim(szLine);

				if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') {
					fprintf(fpOut, "%s^n", szLine);
					continue;
				}

				parse(szLine, szReadAuth, charsmax(szReadAuth));

				if (equal(szReadAuth, szAuth)) {
					bFound = true;
					if (perm == 0) continue;  // 清除 → 跳过
					fprintf(fpOut, "^"%s^" ^"^" ^"%s^"^n", szAuth, szFlags);
				} else {
					fprintf(fpOut, "%s^n", szLine);
				}
			}
			fclose(fpIn);
			fclose(fpOut);
		}
	}

	if (!bFound && perm > 0) {
		fpOut = fopen(szFile, "at");
		if (fpOut) {
			fprintf(fpOut, "^"%s^" ^"^" ^"%s^"^n", szAuth, szFlags);
			fclose(fpOut);
		}
	}

	if (bFound && file_exists(szTmp)) {
		delete_file(szFile);
		rename_file(szTmp, szFile);
	} else if (file_exists(szTmp)) {
		delete_file(szTmp);
	}

	// ★ 同时设置当前在线玩家的 flags（即时生效，不用等换图）
	new iPlayer = find_player_const(szAuth);
	if (iPlayer > 0) {
		if (perm == 4)      set_user_flags(iPlayer, read_flags("abcdefghijklmn"));
		else if (perm == 3) set_user_flags(iPlayer, read_flags("defi"));
		else if (perm == 2) set_user_flags(iPlayer, read_flags("b"));
		else if (perm == 1) set_user_flags(iPlayer, read_flags("fi"));
		else                remove_user_flags(iPlayer, read_flags("abcdefghijklmnopqrstuvwxyz"));
	}
}

// ============================================================================
// LOAD PERMS FROM hns_perms.ini — 每张地图加载时调用
// ============================================================================
hns_perm_load_all() {
	new szDir[128], szFile[256];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szFile, charsmax(szFile), "%s/hns_perms.ini", szDir);

	if (!file_exists(szFile)) return;

	new f = fopen(szFile, "rt");
	if (!f) return;

	new szLine[512];
	new iLoaded = 0;
	while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') continue;

		new szAuth[64], szFlags[32];
		parse(szLine, szAuth, charsmax(szAuth), szFlags, charsmax(szFlags));

		if (szAuth[0] == '^0' || szFlags[0] == '^0') continue;

		// 去掉引号
		remove_quotes(szAuth);
		remove_quotes(szFlags);

		// 写入 users.ini 条目让 AMXX 也认识
		new szType[4];
		if (containi(szAuth, "STEAM_") != -1) copy(szType, charsmax(szType), "ce");
		else if (containi(szAuth, ".") != -1) copy(szType, charsmax(szType), "de");
		else copy(szType, charsmax(szType), "ce");

		// ★ 同步到 users.ini
		new szUsersFile[256], szUsersTmp[256];
		get_configsdir(szDir, charsmax(szDir));
		formatex(szUsersFile, charsmax(szUsersFile), "%s/users.ini", szDir);
		formatex(szUsersTmp, charsmax(szUsersTmp), "%s/hns_sync.tmp", szDir);

		// 检查 users.ini 里是否已有这个 auth
		new bool:bInUsers = false;
		new fpU = fopen(szUsersFile, "rt");
		if (fpU) {
			new szULine[512], szUAuth[64];
			while (!feof(fpU)) {
				fgets(fpU, szULine, charsmax(szULine));
				trim(szULine);
				if (szULine[0] == ';' || szULine[0] == '/' || szULine[0] == '^0') continue;
				parse(szULine, szUAuth, charsmax(szUAuth));
				if (equal(szUAuth, szAuth)) { bInUsers = true; break; }
			}
			fclose(fpU);
		}

		if (!bInUsers) {
			new fpAppend = fopen(szUsersFile, "at");
			if (fpAppend) {
				fprintf(fpAppend, "^"%s^" ^"^" ^"%s^" ^"%s^"^n", szAuth, szFlags, szType);
				fclose(fpAppend);
			}
		}

		// ★ 设置当前在线玩家的 flags
		new iPlayer = find_player_const(szAuth);
		if (iPlayer > 0) {
			set_user_flags(iPlayer, read_flags(szFlags));
			iLoaded++;
		}
	}
	fclose(f);

	if (iLoaded > 0) {
		server_print("[HNS Perms] 从 hns_perms.ini 加载了 %d 个在线玩家权限", iLoaded);
	}

	// 通知 AMXX 重新加载
	server_cmd("amx_reloadadmins");
}

// 辅助: 通过 authid 查找玩家（兼容 SteamID 和 IP）
stock find_player_const(const szAuth[]) {
	if (containi(szAuth, "STEAM_") != -1 || containi(szAuth, "VALVE_") != -1) {
		return find_player("ch", szAuth);
	}
	// IP
	return find_player("chi", szAuth);
}

// ============================================================================
// ONE-CLICK HELPER AUTH (一键认证辅助)
// ============================================================================
public hnsHelperAuth(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	if (hns_get_user_perm_level(id) >= 1) {
		client_print(id, print_chat, "[HNS] 你已经有权限了！");
		return PLUGIN_HANDLED;
	}

	new szArgs[192];
	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);

	new szPassword[32];
	argbreak(szArgs, szArgs, 0, szPassword, charsmax(szPassword));

	if (equal(szPassword, "890514")) {
		new szAuth[64];
		get_user_authid(id, szAuth, charsmax(szAuth));
		if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:"))
			get_user_ip(id, szAuth, charsmax(szAuth), 1);

		hns_set_user_perm_level(id, 1);
		hns_perm_save_by_auth(szAuth, 1);

		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		chat_print(0, "^4[HNS] ^3%s ^1已被认证为 ^4辅助 ^1(永久保存)", szName);
		client_print(id, print_chat, "[HNS] 认证成功！你现在是辅助，权限已永久保存。");
		return PLUGIN_HANDLED;
	}

	client_print(id, print_chat, "[HNS] 密码错误！");
	return PLUGIN_HANDLED;
}

// ============================================================================
// ONE-CLICK OWNER AUTH (一键认证服主)
// ============================================================================
public hnsOwnerAuth(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	if (hns_get_user_perm_level(id) >= 4) {
		client_print(id, print_chat, "[HNS] 你已经是服主了！");
		return PLUGIN_HANDLED;
	}

	new szArgs[192];
	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);

	new szPassword[32];
	argbreak(szArgs, szArgs, 0, szPassword, charsmax(szPassword));

	if (equal(szPassword, "890514")) {
		new szAuth[64];
		get_user_authid(id, szAuth, charsmax(szAuth));
		if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:"))
			get_user_ip(id, szAuth, charsmax(szAuth), 1);

		hns_set_user_perm_level(id, 4);
		hns_perm_save_by_auth(szAuth, 4);

		// ★ FIX: 设置服主聊天前缀（红色服主标识，显示在名字前）
		cm_set_prefix(id, "^4[服主]^1 ");

		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		chat_print(0, "^4[HNS] ^3%s ^1已被认证为 ^4服主 ^1(永久保存)", szName);
		client_print(id, print_chat, "[HNS] 认证成功！你现在是服主，权限已永久保存。");
		return PLUGIN_HANDLED;
	}

	client_print(id, print_chat, "[HNS] 密码错误！");
	return PLUGIN_HANDLED;
}

// ============================================================================
// LOAD OWNER LIST ON CONNECT — AMXX 已自动读取 users.ini，这里只做前缀恢复
// ============================================================================
hns_load_owner_list(id) {
	// AMXX 已从 users.ini 自动设置 flags，这里只需要检查并恢复前缀
	new iPerm = hns_get_user_perm_level(id);
	if (iPerm >= 4) {
		cm_set_prefix(id, "^4[服主]^1 ");
		client_print(id, print_chat, "[HNS] 欢迎服主！你的权限已自动加载。");
		return true;
	} else if (iPerm >= 3) {
		cm_set_prefix(id, "^3[管理]^1 ");
		return true;
	} else if (iPerm >= 2) {
		return true;
	} else if (iPerm >= 1) {
		return true;
	}
	return false;
}

// ============================================================================
// TEST TOOLS MENU (比赛测试工具 - 穿透等)
// ============================================================================
showTestToolsMenu(id) {
	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r比赛测试工具^n^n");

	// 穿透状态显示
	new iWallbangStatus = get_cvar_num("hns_wallbang_forced");
	if (iWallbangStatus == 1)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \d穿透: \y强制开启^n");
	else if (iWallbangStatus == -1)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \d穿透: \r强制关闭^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \d穿透: \w默认状态^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r2. \w测试人机 (/testbots)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w录制动作 (/record)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w回放动作 (/replay)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), szMenu, -1, "HnsICTestTools");
}

public testToolsMenuHandler(id, key) {
	if (key == 9) { showMatchMenu(id); return; }

	if (key == 0) {
		// 穿透开关 - 2种状态切换: 默认/强制关 → 强制开, 强制开 → 强制关
		new iCur = get_cvar_num("hns_wallbang_forced");
		if (iCur <= 0) {
			server_cmd("hns_wallbang_on");
			client_print(id, print_chat, "[HNS] 穿透已强制开启");
		} else if (iCur == 1) {
			server_cmd("hns_wallbang_off");
			client_print(id, print_chat, "[HNS] 穿透已强制关闭");
		}
		set_task(0.2, "taskReopenTestTools", id);
	} else if (key == 1) {
		client_cmd(id, "say /testbots");
	} else if (key == 2) {
		client_cmd(id, "say /record");
	} else if (key == 3) {
		client_cmd(id, "say /replay");
	}
}

public taskReopenTestTools(id) {
	if (is_user_connected(id))
		showTestToolsMenu(id);
}
