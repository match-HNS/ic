#if defined _hnsmenu_included
  #endinput
#endif

#define _hnsmenu_included

// ============================================================================
// PERMISSION HELPERS (uses AMXX flags)
// ============================================================================
// Levels: 0 = 普通, 1 = 临时管理/Watcher (flag f+i), 2 = VIP (flag b), 3 = 管理员 (flag d+e+f+i), 4 = 服主 (full flags)
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
	// Check from highest to lowest: owner, admin, VIP, Watcher(临时管理)
	if (flags & read_flags("m")) return 4;
	if (flags & read_flags("d")) return 3;
	if (flags & read_flags("b")) return 2;
	if (flags & read_flags("f")) return 1;
	return 0;
}

// ============================================================================
// HnsICMatch v5.0.0 - Unified Big Menu System
// Replaces the original OpenHNS v4.2.0 hnsmenu.inc
//
// Menu Structure (M key / nightvision / /mix / /menu):
//   Main Menu (8 categories):
//     1. Match Management    (Watcher+)   - Start/Stop/Pause/Swap/Restart/Surrender/Mode
//     2. Training Tools       (All)        - CP/TP/Noclip/Hook/Weapons/Respawn (2 pages)
//     3. Personal Settings   (All)        - Skins/HUD/SemiClip/Knife/JumpStats
//     4. Map Management      (Watcher+)   - MapList/MapVote/MapInfo
//     5. Statistics          (All)        - MyStats/Dmg/Best/Top
//     6. Display Settings    (All)        - SemiClip/Knife/HideKnife/HUD/SpecList/JumpStats
//     7. Permission Mgmt     (Watcher+)   - Verify/VIP/Admin/Ban
//     8. Admin Tools          (FullWatcher+) - Watcher/Replace/Control/AI/Approve/Sub/Kick
//
// Plus: Quick Actions menu, Match Settings, PointScap Settings,
//       Mode Select, Custom Mode, Knife Settings, Vote System
// ============================================================================

// --- Per-player toggle states ---
new bool:g_bHudEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bModeHudEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bSpecListEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bJumpStatsEnabled[MAX_PLAYERS + 1] = {true, ...};
new bool:g_bTrainingPage2[MAX_PLAYERS + 1] = {false, ...};
new g_iDistAction[33];  // 分发菜单action缓存
new bool:g_bHideKnifeTT[MAX_PLAYERS + 1] = {false, ...};
new bool:g_bHideKnifeCT[MAX_PLAYERS + 1] = {false, ...};

// --- Vote system ---
new Float:g_flTimeToVoteMode;
new iVoteRules[NATCH_RULES];
new bool:g_bVotedRules[MAX_PLAYERS + 1];

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
	new K_0_2_9    = (1<<0)|(1<<1)|(1<<2)|(1<<9);
	new K_0_6_8_9  = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<8)|(1<<9);
	new K_0_1_8_9  = (1<<0)|(1<<1)|(1<<8)|(1<<9);
	new K_0_1_9    = (1<<0)|(1<<1)|(1<<9);
	new K_MAP      = (1<<0)|(1<<1)|(1<<2)|(1<<8)|(1<<9);
	new K_STATS    = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9);
	new K_TEAM     = K_0_2_9;

	// Main + Match
	iMenuId = register_menuid("HnsICMainMenu");
	register_menucmd(iMenuId, ALL, "handlerMainMenu");

	iMenuId = register_menuid("HnsICMatchMenu");
	register_menucmd(iMenuId, ALL, "matchMenuHandler");

	// Mode Select
	iMenuId = register_menuid("HnsICModeSelect");
	register_menucmd(iMenuId, ALL, "HandlerSelectMode");

	// Custom Mode
	iMenuId = register_menuid("HnsICCustomMode");
	register_menucmd(iMenuId, K_0_2_9, "customMenuHandler");

	// Match Settings
	iMenuId = register_menuid("HnsICMatchSettings");
	register_menucmd(iMenuId, ALL, "settingsMatchMenuHandler");

	// PointScap
	iMenuId = register_menuid("HnsICPointScore");
	register_menucmd(iMenuId, ALL, "pointScoreMenuHandler");

	// Knife Settings
	iMenuId = register_menuid("HnsICKnifeSettings");
	register_menucmd(iMenuId, K_0_1_8_9, "handleKnifeSettingsMenu");

	// Quick Actions
	iMenuId = register_menuid("HnsICQuickActions");
	register_menucmd(iMenuId, ALL, "handleQuickActionsMenu");

	// Confirm
	iMenuId = register_menuid("HnsICConfirm");
	register_menucmd(iMenuId, K_0_1_9, "verifMenuHandler");

	// Vote Rules
	iMenuId = register_menuid("HnsICVoteRules");
	register_menucmd(iMenuId, K_0_1_9, "HandlerStartVoteRules");

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

	// Display
	iMenuId = register_menuid("HnsICDisplayMenu");
	register_menucmd(iMenuId, ALL, "displayMenuHandler");

	// Permissions
	iMenuId = register_menuid("HnsICPermMenu");
	register_menucmd(iMenuId, K_STATS, "permMenuHandler");

	// Admin
	iMenuId = register_menuid("HnsICAdminMenu");
	register_menucmd(iMenuId, ALL, "adminMenuHandler");

	// Server Console
	iMenuId = register_menuid("HnsICServerConsole");
	register_menucmd(iMenuId, ALL, "serverConsoleHandler");

	// Map Change
	iMenuId = register_menuid("HnsICMapChange");
	register_menucmd(iMenuId, ALL, "mapChangeHandler");

	// Team Join
	iMenuId = register_menuid("HnsICTeamJoinMenu");
	register_menucmd(iMenuId, K_TEAM, "teamJoinMenuHandler");

	// Distribute
	iMenuId = register_menuid("HnsICDistribute");
	register_menucmd(iMenuId, K_0_6_8_9, "distributeMenuHandler");

	// Dist Player
	iMenuId = register_menuid("HnsICDistPlayer");
	register_menucmd(iMenuId, K_0_6_8_9, "distributePlayerHandler");

	// Personal Skin Distribute - Player Select
	iMenuId = register_menuid("HnsICPersonalSkinDistPlayer");
	register_menucmd(iMenuId, K_0_6_8_9, "personalSkinDistribPlayerHandler");

	// Personal Skin Distribute - Type Select
	iMenuId = register_menuid("HnsICPersonalSkinDistType");
	register_menucmd(iMenuId, (1<<0)|(1<<1)|(1<<2)|(1<<9), "personalSkinDistribTypeHandler");

	// AI Signup
	iMenuId = register_menuid("HnsICAISignup");
	register_menucmd(iMenuId, ALL, "aiSignupMenuHandler");
}

public handlerMainMenu(id, key) {
	if (key == 9) {
		show_menu(id, 0, "^n", 1);
		return PLUGIN_HANDLED;
	}

	switch(key) {
		case 0: showMatchMenu(id);      // 1. 比赛管理
		case 1: showAISignupMenu(id);   // 2. AI分组
		case 2: menuSelectMode(id);     // 3. 选择模式
		case 3: showTrainingMenu(id);   // 4. 训练工具
		case 4: showPersonalMenu(id);   // 5. 个人设置
		case 5: showMapMenu(id);        // 6. 地图管理
		case 6: showStatsMenu(id);      // 7. 数据统计
		case 7: showDisplayMenu(id);    // 8. 显示设置
		case 8: showAdminMenu(id);      // 9. 管理工具
	}

	return PLUGIN_HANDLED;
}

stock hnsmenu_client_putinserver(id) {
	g_bHudEnabled[id] = true;
	g_bModeHudEnabled[id] = true;
	g_bSpecListEnabled[id] = true;
	g_bJumpStatsEnabled[id] = true;
	g_bTrainingPage2[id] = false;
	g_bHideKnifeTT[id] = false;
	g_bHideKnifeCT[id] = false;
}

// ============================================================================
// MAIN MENU - Entry point (M key / nightvision)
// ============================================================================

public cmdMainMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	showMainMenu(id);
	return PLUGIN_HANDLED;
}

// ============================================================================
// AI GROUPING MENU (AI分组菜单)
// ============================================================================

showAISignupMenu(id) {
	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\rAI组队报名 \d- 比赛系统^n^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w报名参加 (/join)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w取消报名 (/unjoin)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \wAI菜单 (/ai)^n");

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
		client_cmd(id, "hns_ai_join");
	} else if (key == 1) {
		// 取消报名
		client_cmd(id, "hns_ai_unjoin");
	} else if (key == 2) {
		// 打开AI原生菜单
		client_cmd(id, "hns_ai_menu");
	} else if (key == 7) {
		// 管理设置
		if (isUserWatcher(id))
			client_cmd(id, "say /admin");
	}
}

showMainMenu(id) {
	new szMenu[512], iLen;
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	// 模式名
	new szMode[16];
	switch (g_iCurrentMode) {
		case MODE_TRAINING: copy(szMode, charsmax(szMode), "训练");
		case MODE_KNIFE: copy(szMode, charsmax(szMode), "拼刀");
		case MODE_MIX: copy(szMode, charsmax(szMode), "混合赛");
		case MODE_PUB: copy(szMode, charsmax(szMode), "公共");
		case MODE_DM: copy(szMode, charsmax(szMode), "死斗");
		case MODE_ASCENSION: copy(szMode, charsmax(szMode), "飞升");
		case MODE_VAMP: copy(szMode, charsmax(szMode), "吸血鬼");
		case MODE_ROUNDS: copy(szMode, charsmax(szMode), "回合制");
		case MODE_ZM: copy(szMode, charsmax(szMode), "僵尸");
		default: copy(szMode, charsmax(szMode), "空闲");
	}

	// 地图名
	new szMap[32];
	rh_get_mapname(szMap, charsmax(szMap));

	// 头部
	iLen = formatex(szMenu, charsmax(szMenu), "\rGTRHNS \d— \w比赛系统 \rv1.0.1^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y地图:\w%s  \d|  \y模式:\w%s^n^n", szMap, szMode);

	// ─── 比赛 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w比赛管理 \d(开始/控制/设置)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wAI分组 \d(报名/状态)^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w选择模式^n");

	// ─── 工具 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w训练工具^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w个人设置^n");

	// ─── 信息 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w地图管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w数据统计^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w显示设置^n");

	// ─── 管理 ───
	if (isUserWatcher(id) || is_user_admin(id))
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w管理工具 \d(Watcher/Admin)^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d9. 管理工具^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w退出^n");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICMainMenu");
}

// ============================================================================
// 1. MATCH MANAGEMENT MENU (Watcher+)
// ============================================================================

showMatchMenu(id) {
	if (!isUserWatcher(id) && !is_user_admin(id)) {
		showMainMenu(id);
		return;
	}

	new szMenu[512], iLen;
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y比赛管理^n^n", szPrefix);

	// ─── 开始/停止 ───
	// Item 1: Context-sensitive start/stop
	if (hns_is_knife_map()) {
		if (!hns_cup_enabled()) {
			if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w开始队长模式^n");
			else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_TEAMKNIFE && g_eMatchState == STATE_PAUSED)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w取消拼刀暂停^n");
			else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止队长模式^n");
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d1. 开始队长模式^n");
		} else {
			if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w开始选图拼刀^n");
			else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_CUPKNIFE)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止选图拼刀^n");
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w开始选图拼刀^n");
		}
	} else {
		if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止自定义模式^n");
		else if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus <= MATCH_WAITCONNECT)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w开始混合赛^n");
		else if (g_iCurrentMode == MODE_ROUNDS)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止回合制^n");
		else if (g_iCurrentMode == MODE_ASCENSION)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止点位积分^n");
		else if (g_iCurrentMode == MODE_VAMP)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止点位扣除^n");
		else
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \r停止混合赛^n");
	}

	// Item 2: Context-sensitive second action
	if (hns_is_knife_map()) {
		if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d2. 开始拼刀局^n");
		else if (g_iCurrentMode == MODE_KNIFE)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \r停止拼刀局^n");
		else
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w开始拼刀局^n");
	} else {
		if (g_iCurrentMode == MODE_TRAINING)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w开始自定义模式^n");
		else if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w混合队伍^n");
		else {
			if (g_eMatchState != STATE_PAUSED)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w暂停比赛^n");
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w恢复比赛^n");
		}
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w重开回合^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w交换阵营^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w投降^n");
	// ─── 设置 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w选择模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w比赛测试工具^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w比赛设置^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w快捷操作^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICMatchMenu");
}

public matchMenuHandler(id, key) {
	if (key == 0) {
	    { // Key 1: Start/Stop context action
	    			if (hns_is_knife_map()) {
	    				if (!hns_cup_enabled()) {
	    					if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
	    						cmdCaptain(id);
	    					else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_TEAMKNIFE && g_eMatchState == STATE_PAUSED)
	    						cmdStopPause(id);
	    					else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
	    						cmdStop(id);
	    					else
	    						showMatchMenu(id);
	    				} else {
	    					if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
	    						cmdKnifePickBan(id);
	    					else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_CUPKNIFE)
	    						cmdStop(id);
	    					else
	    						cmdKnifePickBan(id);
	    				}
	    			} else {
					if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM || g_iMatchStatus == MATCH_WAITCONNECT) {
						cmdStop(id);
					} else if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus <= MATCH_WAITCONNECT) {
						menuSelectMode(id);
					} else if (g_iCurrentMode == MODE_ROUNDS || g_iCurrentMode == MODE_ASCENSION || g_iCurrentMode == MODE_VAMP || g_iCurrentMode == MODE_MIX) {
						cmdStop(id);
					} else {
						verifMenu(id);
					}
				}
	    		}
	} else if (key == 1) {
	    { // Key 2: Second context action
	    			if (hns_is_knife_map()) {
	    				if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
	    					showMatchMenu(id);
	    				else if (g_iCurrentMode == MODE_KNIFE)
	    					cmdStop(id);
	    				else
	    					cmdKnifeRound(id);
	    			} else {
	    				if (g_iCurrentMode == MODE_TRAINING)
	    					customMenu(id);
	    				else if (g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_ZM)
	    					cmdBlend(id);
	    				else {
	    					if (g_eMatchState != STATE_PAUSED)
	    						cmdStartPause(id);
	    					else
	    						cmdStopPause(id);
	    				}
	    			}
	    		}
	} else if (key == 2) {
	    cmdRestartRound(id);    // Key 3: Restart Round
	} else if (key == 3) {
	    cmdSwapTeams(id);      // Key 4: Swap Teams
	} else if (key == 4) {
	    cmdSurrender(id);      // Key 5: Surrender
	} else if (key == 5) {
	    menuSelectMode(id);    // Key 6: Select Mode
	} else if (key == 6) {
	    showTestToolsMenu(id); // Key 7: Test Tools (NEW)
	} else if (key == 7) {
	    settingsMatchMenu(id); // Key 8: Match Settings
	} else if (key == 8) {
	    quickActionsMenu(id); // Key 9: Quick Actions
	}
}

// ============================================================================
// MODE SELECT MENU (Sub-menu of Match Management)
// ============================================================================

public menuSelectMode(id) {
	if (!isUserWatcher(id) && !is_user_admin(id))
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
	} else if ((key == 9)) {
	    showMatchMenu(id);
	}
}

// ============================================================================
// CUSTOM MODE MENU (Public/DM/Zombie)
// ============================================================================

public customMenu(id) {
	if (!is_user_connected(id))
		return;

	new szMenu[256], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r自定义模式^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w公共模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w死亡竞赛^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w僵尸模式^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<9), szMenu, -1, "HnsICCustomMode");
}

public customMenuHandler(id, key) {
	if (key == 0) {
	    cmdPubMode(id);
	} else if (key == 1) {
	    cmdDMMode(id);
	} else if (key == 2) {
	    cmdZMMode(id);
	} else if (key == 9) {
	    showMatchMenu(id);
	}
}

// ============================================================================
// MATCH SETTINGS MENU
// ============================================================================

public settingsMatchMenu(id) {
	if (!is_user_connected(id) || (!isUserWatcher(id) && !is_user_admin(id)))
		return;

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r比赛设置^n^n");

	if (g_iCurrentMode == MODE_TRAINING)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w回合时间: \d[训练]^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w回合时间: \y%.1f^n", get_cvar_float("mp_roundtime"));

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w冻结时间: \y%d^n", get_cvar_num("mp_freezetime"));

	if (g_iCurrentRules == RULES_MR) {
	    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w最大回合数: \y%d \d(%d 总回合)^n", g_iSettings[MAXROUNDS], g_iSettings[MAXROUNDS] * 2);
	} else if (g_iCurrentRules == RULES_TIMER) {
	    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w胜利时间: \y%.0f^n", g_eMatchInfo[e_mWintime]);
	} else if (g_iCurrentRules == RULES_DUEL) {
	    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w胜利时间: \y%.0f^n", g_eMatchInfo[e_mWintime]);
	} else if (g_iCurrentMode == MODE_ASCENSION || g_iCurrentMode == MODE_VAMP) {
	    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w目标分数: \y%d 分^n", g_iPointScapTargetScore);
	} else if (g_iCurrentMode == MODE_ROUNDS) {
	    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w回合设置: \y先赢%d局 \d(最多%d局)^n", g_iRoundsWinRounds, g_iRoundsMaxRounds);
	} else {
	    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w规则: \y无^n");
	}

	if (g_iSettings[ONEHPMODE] == 0)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w一击必杀: \y关^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w一击必杀: \y开^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w闪光弹数: \y%d^n", g_iSettings[FLASH]);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w烟雾弹数: \y%d^n", g_iSettings[SMOKE]);

	// 刀战/Boost模式
	new szBoostStatus[16];
	if (g_iSettings[HNSBOOST])
		copy(szBoostStatus, charsmax(szBoostStatus), "开");
	else
		copy(szBoostStatus, charsmax(szBoostStatus), "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w刀战模式: \y%s^n", szBoostStatus);

	// ★ 点位积分设置
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w目标分数: \y%d^n", g_iPointScapTargetScore);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w点位分数配置^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICMatchSettings");
}

public settingsMatchMenuHandler(id, key) {
	if (!is_user_connected(id)) return;

	if (key == 0) {
	    { // Round Time cycle
	    			new Float:flRT = get_cvar_float("mp_roundtime");
	    			if (flRT <= 2.5) flRT = 3.0;
	    			else if (flRT <= 3.0) flRT = 3.5;
	    			else if (flRT <= 3.5) flRT = 4.0;
	    			else if (flRT <= 4.0) flRT = 4.5;
	    			else if (flRT <= 4.5) flRT = 5.0;
	    			else flRT = 2.5;
	    			set_cvar_float("mp_roundtime", flRT);
	    			settingsMatchMenu(id);
	    		}
	} else if (key == 1) {
	    { // Freeze Time cycle
	    			new iFT = get_cvar_num("mp_freezetime");
	    			if (iFT == 0) iFT = 5;
	    			else if (iFT <= 5) iFT = 10;
	    			else if (iFT <= 10) iFT = 15;
	    			else if (iFT <= 15) iFT = 20;
	    			else if (iFT <= 20) iFT = 25;
	    			else if (iFT <= 25) iFT = 30;
	    			else iFT = 0;
	    			set_cvar_num("mp_freezetime", iFT);
	    			settingsMatchMenu(id);
	    		}
	} else if (key == 2) {
	    { // Rules/MR/Wintime/PointScore cycle
	    			if (g_iCurrentRules == RULES_MR) {
	    				if (g_iSettings[MAXROUNDS] <= 6) g_iSettings[MAXROUNDS] = 8;
	    				else if (g_iSettings[MAXROUNDS] <= 8) g_iSettings[MAXROUNDS] = 10;
	    				else if (g_iSettings[MAXROUNDS] <= 10) g_iSettings[MAXROUNDS] = 12;
	    				else if (g_iSettings[MAXROUNDS] <= 12) g_iSettings[MAXROUNDS] = 14;
	    				else g_iSettings[MAXROUNDS] = 6;
	    			} else if (g_iCurrentRules == RULES_TIMER) {
	    				if (g_eMatchInfo[e_mWintime] <= 10.0) g_eMatchInfo[e_mWintime] = 15.0;
	    				else if (g_eMatchInfo[e_mWintime] <= 15.0) g_eMatchInfo[e_mWintime] = 20.0;
	    				else g_eMatchInfo[e_mWintime] = 10.0;
	    				set_pcvar_float(pCvar[WINTIME], g_eMatchInfo[e_mWintime]);
	    			} else if (g_iCurrentRules == RULES_DUEL) {
	    				if (g_eMatchInfo[e_mWintime] <= 10.0) g_eMatchInfo[e_mWintime] = 15.0;
	    				else if (g_eMatchInfo[e_mWintime] <= 15.0) g_eMatchInfo[e_mWintime] = 20.0;
	    				else g_eMatchInfo[e_mWintime] = 10.0;
	    				set_pcvar_float(pCvar[WINTIME], g_eMatchInfo[e_mWintime]);
	    			} else if (g_iCurrentMode == MODE_ASCENSION || g_iCurrentMode == MODE_VAMP) {
	    			    // ★ 目标分数: 10→15→20→...→95→100→10
	    			    if (g_iPointScapTargetScore >= 100) {
	    			        g_iPointScapTargetScore = 10;
	    			    } else {
	    			        g_iPointScapTargetScore += 5;
	    			    }
	    			    set_cvar_num("hns_pointscap_target_score", g_iPointScapTargetScore);
	    			} else if (g_iCurrentMode == MODE_ROUNDS) {
	    			    // ★ 回合制: 先赢N局 2→3→4→5→6→2
	    			    if (g_iRoundsWinRounds <= 2)      g_iRoundsWinRounds = 3;
	    			    else if (g_iRoundsWinRounds <= 3) g_iRoundsWinRounds = 4;
	    			    else if (g_iRoundsWinRounds <= 4) g_iRoundsWinRounds = 5;
	    			    else if (g_iRoundsWinRounds <= 5) g_iRoundsWinRounds = 6;
	    			    else g_iRoundsWinRounds = 2;
	    			    g_bRoundsManual = true;
	    			    g_iRoundsMaxRounds = g_iRoundsWinRounds * 2 - 1;  // 最多回合 = 2N-1
	    			}
	    			settingsMatchMenu(id);
	    		}
	} else if (key == 3) {
	    { // 1HP Mode toggle
	    			g_iSettings[ONEHPMODE] = (g_iSettings[ONEHPMODE] == 0) ? 1 : 0;
	    			settingsMatchMenu(id);
	    		}
	} else if (key == 4) {
	    { // Flash count cycle
	    			if (g_iSettings[FLASH] == 0) g_iSettings[FLASH] = 1;
	    			else if (g_iSettings[FLASH] <= 1) g_iSettings[FLASH] = 2;
	    			else if (g_iSettings[FLASH] <= 2) g_iSettings[FLASH] = 3;
	    			else g_iSettings[FLASH] = 0;
	    			settingsMatchMenu(id);
	    		}
	} else if (key == 5) {
	    { // Smoke count cycle
	    			if (g_iSettings[SMOKE] <= 1) g_iSettings[SMOKE] = 2;
	    			else g_iSettings[SMOKE] = 1;
	    			settingsMatchMenu(id);
	    		}
	} else if (key == 6) {
	    // 刀战模式开关
	    g_iSettings[HNSBOOST] = !g_iSettings[HNSBOOST];
	    if (g_iSettings[HNSBOOST]) {
	    	chat_print(0, "^3%n^1 activated ^3boost^1 mode.", id);
	    } else {
	    	chat_print(0, "^3%n^1 deactivated ^3boost^1 mode.", id);
	    }
	    settingsMatchMenu(id);
	} else if (key == 7) {
	    // ★ 目标分数循环: 10→15→20→...→100→10, 步长5
	    g_iPointScapTargetScore = g_iPointScapTargetScore >= 100 ? 10 : g_iPointScapTargetScore + 5;
	    set_cvar_num("hns_pointscap_target_score", g_iPointScapTargetScore);
	    settingsMatchMenu(id);
	} else if (key == 8) {
	    showPointScoreMenu(id); // ★ 点位分数配置子菜单
	} else if (key == 9) {
	    showMatchMenu(id); // Back
	}
}

// ============================================================================
// MORE SETTINGS SUBMENU
// ============================================================================

public showMoreSettingsMenu(id) {
    if (!is_user_connected(id)) return;

    new szMenu[512], iLen;
    iLen = formatex(szMenu, charsmax(szMenu), "\r更多设置^n^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w拼刀设置^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w飞行手雷设置^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

    show_menu(id, (1<<0)|(1<<1)|(1<<9), szMenu, -1, "HnsICMoreSettings");
}

public moreSettingsMenuHandler(id, key) {
    if (key == 0) {
        showKnifeSettingsMenu(id); // 拼刀设置
    } else if (key == 1) {
        client_cmd(id, "hns_flynade"); // 飞行手雷
    } else if (key == 9) {
        settingsMatchMenu(id); // 返回
    }
}

// ============================================================================
// 点位分数配置子菜单
// ============================================================================

public showPointScoreMenu(id) {
	if (!is_user_connected(id))
		return;

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r点位分数配置^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w3人分数: \y%.1f^n", g_flPointScapScore3);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w4人分数: \y%.1f^n", g_flPointScapScore4);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w5人分数: \y%.1f^n", g_flPointScapScore5);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w停留时间: \y%.1f 秒^n", g_flPointScapStayTime);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9), szMenu, -1, "HnsICPointScore");
}

public pointScoreMenuHandler(id, key) {
	if (!is_user_connected(id)) return;

	if (key >= 0 && key <= 2) {
		// ★ 点位分数: 0.5→1.0→1.5→...→6.0→0.5, 步长0.5
		new Float:flScore = 0.0;
		if (key == 0) {
			flScore = g_flPointScapScore3 >= 6.0 ? 0.5 : g_flPointScapScore3 + 0.5;
			g_flPointScapScore3 = flScore;
			set_pcvar_float(pCvar[POINTSCAP_SCORE_3], flScore);
		} else if (key == 1) {
			flScore = g_flPointScapScore4 >= 6.0 ? 0.5 : g_flPointScapScore4 + 0.5;
			g_flPointScapScore4 = flScore;
			set_pcvar_float(pCvar[POINTSCAP_SCORE_4], flScore);
		} else if (key == 2) {
			flScore = g_flPointScapScore5 >= 6.0 ? 0.5 : g_flPointScapScore5 + 0.5;
			g_flPointScapScore5 = flScore;
			set_pcvar_float(pCvar[POINTSCAP_SCORE_5], flScore);
		}
	} else if (key == 3) {
	    { // 停留时间: 0.5→1.0→1.5→2.0→2.5→3.0→0.5, 步长0.5
	    			if (g_flPointScapStayTime < 0.6) g_flPointScapStayTime = 1.0;
	    			else if (g_flPointScapStayTime < 1.1) g_flPointScapStayTime = 1.5;
	    			else if (g_flPointScapStayTime < 1.6) g_flPointScapStayTime = 2.0;
	    			else if (g_flPointScapStayTime < 2.1) g_flPointScapStayTime = 2.5;
	    			else if (g_flPointScapStayTime < 2.6) g_flPointScapStayTime = 3.0;
	    			else g_flPointScapStayTime = 0.5;
	    			set_pcvar_float(pCvar[POINTSCAP_STAY_TIME], g_flPointScapStayTime);
	    		}
	} else if ((key == 8 || key == 9)) {
	    settingsMatchMenu(id); // Back
	    return;
	}
	showPointScoreMenu(id);
}

// ============================================================================
// KNIFE SETTINGS MENU
// ============================================================================

public showKnifeSettingsMenu(id) {
	if (!is_user_alive(id)) {
		settingsMatchMenu(id);
		return;
	}
	if (getUserTeam(id) != TEAM_TERRORIST) {
		chat_print(id, "Only T can access knife settings.");
		settingsMatchMenu(id);
		return;
	}

	new szMenu[256], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r拼刀设置^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w拼刀视角: %s^n", g_bKnifeViewModel[id] ? "\yShow" : "\rHide");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w攻击距离: \y%d 单位^n", g_iSettings[KNIFE_DISTANCE]);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<8)|(1<<9), szMenu, -1, "HnsICKnifeSettings");
}

public handleKnifeSettingsMenu(id, key) {
	if (key == 0) {
	    {
	    			g_bKnifeViewModel[id] = !g_bKnifeViewModel[id];
	    			showKnifeSettingsMenu(id);
	    		}
	} else if (key == 1) {
	    {
	    			chat_print(id, "Knife distance is set by server admin.");
	    			showKnifeSettingsMenu(id);
	    		}
	} else if (key == 8) {
	    settingsMatchMenu(id); // Back
	}
}

// ============================================================================
// QUICK ACTIONS MENU
// ============================================================================

public quickActionsMenu(id) {
	if (!is_user_connected(id))
		return;

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r快捷操作^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w全体转观战^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w全体转T^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w全体转CT^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w显示比分^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w允许比赛^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w禁止比赛^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w点位编辑器^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w投降^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICQuickActions");
}

public handleQuickActionsMenu(id, key) {
	if (key == 0) {
	    cmdTransferSpec(id);
	} else if (key == 1) {
	    cmdTransferTT(id);
	} else if (key == 2) {
	    cmdTransferCT(id);
	} else if (key == 3) {
	    cmdShowTimers(id);
	} else if (key == 4) {
	    cmdPlay(id);
	} else if (key == 5) {
	    cmdNoplay(id);
	} else if (key == 6) {
	    client_cmd(id, "pointscap_editor");
	} else if (key == 7) {
	    cmdSurrender(id);
	} else if ((key == 8 || key == 9)) {
	    showMatchMenu(id); // Back
	}
}

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

// ============================================================================
// VOTE SYSTEM
// ============================================================================

public StartVoteRules() {
	g_flTimeToVoteMode = get_gametime() + 20.0;
	arrayset(iVoteRules, 0, sizeof(iVoteRules));
	arrayset(g_bVotedRules, false, sizeof(g_bVotedRules));

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (!is_user_connected(id))
			continue;
		if (getUserTeam(id) != TEAM_CT && getUserTeam(id) != TEAM_TERRORIST)
			continue;

		new szMenu[256], iLen;
		iLen = formatex(szMenu, charsmax(szMenu), "\r投票: 游戏模式^n^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wMR (最大回合数)^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w计时模式^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w决斗模式 (1v1)^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w点位积分模式^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w点位扣除模式^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w回合制比赛^n^n");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w退出");

		show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), szMenu, -1, "HnsICVoteRules");
	}

	set_task(20.0, "VoteFinished", 83129);
}

public HandlerStartVoteRules(id, key) {
	if (key == 9 || get_gametime() > g_flTimeToVoteMode)
		return;

	// Prevent repeat voting
	if (g_bVotedRules[id])
		return;
	g_bVotedRules[id] = true;

	new szRuleNames[NATCH_RULES][32] = {
		"MR",
		"Timer",
		"Duel",
		"PointScap",
		"Vampire",
		"Rounds"
	};

	if (key >= 0 && key < sizeof(iVoteRules)) {
		iVoteRules[key]++;
		chat_print(0, "^3%n^1 voted for ^3%s^1.", id, szRuleNames[key]);
	}
}

public VoteFinished() {
	new iMaxVotes = -1;
	new iWinners[5], iWinnerCount = 0;

	for (new i = 0; i < sizeof(iVoteRules); i++) {
		if (iVoteRules[i] > iMaxVotes) {
			iMaxVotes = iVoteRules[i];
			iWinnerCount = 0;
			iWinners[iWinnerCount++] = i;
		} else if (iVoteRules[i] == iMaxVotes && iMaxVotes > 0) {
			iWinners[iWinnerCount++] = i;
		}
	}

	if (iWinnerCount == 0) {
		g_iCurrentRules = NATCH_RULES:random_num(0, sizeof(iVoteRules) - 1);
	} else {
		g_iCurrentRules = NATCH_RULES:iWinners[random(iWinnerCount)];
	}

	new szRuleNames[NATCH_RULES][32] = {
		"MR",
		"Timer",
		"Duel",
		"PointScap",
		"Vampire",
		"Rounds"
	};

	chat_print(0, "^3%s^1 won the vote! Mode set to ^3%s^1.",
		szRuleNames[g_iCurrentRules],
		szRuleNames[g_iCurrentRules]);

	// Direct-launch modes that don't need the normal MR/Timer match setup
	if (g_iCurrentRules == RULES_POINTSCAP) {
		cmdAscensionMode(0);
	} else if (g_iCurrentRules == RULES_VAMP) {
		cmdVampMode(0);
	} else if (g_iCurrentRules == RULES_ROUNDS) {
		g_iCurrentRules = RULES_MR;
		rounds_start();
	}

	arrayset(iVoteRules, 0, sizeof(iVoteRules));
}

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
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y个人设置^n^n", szPrefix);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wT皮肤选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wCT皮肤选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w玩家HUD \y[\r%s\y]^n", g_bHudEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w模式HUD \y[\r%s\y]^n", g_bModeHudEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w观战列表 \y[\r%s\y]^n", g_bSpecListEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w刀模选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w跳跃数据 \y[\r%s\y]^n", g_bJumpStatsEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w发放皮肤管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICPersonalMenu");
}

public personalMenuHandler(id, key) {
	if (key == 0) {
	    client_cmd(id, "say /skin_t"); // T Skin
	} else if (key == 1) {
	    client_cmd(id, "say /skin_ct"); // CT Skin
	} else if (key == 2) {
	    { // Player HUD toggle
	    			g_bHudEnabled[id] = !g_bHudEnabled[id];
	    			chat_print(id, "玩家HUD: %s", g_bHudEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenPersonalMenu", id);
	    		}
	} else if (key == 3) {
	    { // Mode HUD toggle
	    			g_bModeHudEnabled[id] = !g_bModeHudEnabled[id];
	    			chat_print(id, "模式HUD: %s", g_bModeHudEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenPersonalMenu", id);
	    		}
	} else if (key == 4) {
	    { // Spec List toggle
	    			g_bSpecListEnabled[id] = !g_bSpecListEnabled[id];
	    			chat_print(id, "观战列表: %s", g_bSpecListEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenPersonalMenu", id);
	    		}
	} else if (key == 5) {
	    client_cmd(id, "say /knife"); // Knife Model
	} else if (key == 6) {
	    { // JumpStats toggle
	    			g_bJumpStatsEnabled[id] = !g_bJumpStatsEnabled[id];
	    			chat_print(id, "跳跃数据: %s", g_bJumpStatsEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenPersonalMenu", id);
	    		}
	} else if (key == 7) {
        // 发放皮肤管理 - 选玩家→数量→类型
        showPersonalSkinDistribPlayerList(id);
    } else if (key == 8 || key == 9) {
	    showMainMenu(id); // Back
	}
}

public taskReopenPersonalMenu(id) {
	if (is_user_connected(id))
		showPersonalMenu(id);
}

public taskReopenDistributeMenu(id) {
	if (is_user_connected(id))
		showDistributeMenu(id);
}

public taskReopenDistributePlayerList(id) {
	if (is_user_connected(id))
		showDistributePlayerList(id, g_iDistAction[id]);
}

public taskReopenMainMenu(id) {
	if (is_user_connected(id))
		showMainMenu(id);
}

public taskReopenServerConsole(id) {
	if (is_user_connected(id))
		showServerConsoleMenu(id);
}

public taskReopenSkinDistrib(id) {
	if (is_user_connected(id))
		showPersonalSkinDistribType(id);
}

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

showDisplayMenu(id) {
	new szMenu[512], iLen;
	new szPrefix[24];

	if (g_szPrefix[0])
		formatex(szPrefix, charsmax(szPrefix), "%s", g_szPrefix);
	else
		copy(szPrefix, charsmax(szPrefix), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y显示设置^n^n", szPrefix);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w刀模选择^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w隐藏刀 (T) \y[\r%s\y]^n", g_bHideKnifeTT[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w隐藏刀 (CT) \y[\r%s\y]^n", g_bHideKnifeCT[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w玩家HUD \y[\r%s\y]^n", g_bHudEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w模式HUD \y[\r%s\y]^n", g_bModeHudEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w观战列表 \y[\r%s\y]^n", g_bSpecListEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w跳跃数据 \y[\r%s\y]^n", g_bJumpStatsEnabled[id] ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICDisplayMenu");
}

public displayMenuHandler(id, key) {
	if (key == 0) {
	    client_cmd(id, "say /knife"); // Knife Model
	} else if (key == 1) {
	    { // Hide Knife TT
	    			g_bHideKnifeTT[id] = !g_bHideKnifeTT[id];
	    			chat_print(id, "隐藏刀 (T): %s", g_bHideKnifeTT[id] ? "开" : "关");
	    			applyHideKnife(id);
	    			set_task(0.2, "taskReopenDisplayMenu", id);
	    		}
	} else if (key == 2) {
	    { // Hide Knife CT
	    			g_bHideKnifeCT[id] = !g_bHideKnifeCT[id];
	    			chat_print(id, "隐藏刀 (CT): %s", g_bHideKnifeCT[id] ? "开" : "关");
	    			applyHideKnife(id);
	    			set_task(0.2, "taskReopenDisplayMenu", id);
	    		}
	} else if (key == 3) {
	    { // Player HUD
	    			g_bHudEnabled[id] = !g_bHudEnabled[id];
	    			chat_print(id, "玩家HUD: %s", g_bHudEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenDisplayMenu", id);
	    		}
	} else if (key == 4) {
	    { // Mode HUD
	    			g_bModeHudEnabled[id] = !g_bModeHudEnabled[id];
	    			chat_print(id, "模式HUD: %s", g_bModeHudEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenDisplayMenu", id);
	    		}
	} else if (key == 5) {
	    { // Spec List
	    			g_bSpecListEnabled[id] = !g_bSpecListEnabled[id];
	    			chat_print(id, "观战列表: %s", g_bSpecListEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenDisplayMenu", id);
	    		}
	} else if (key == 6) {
	    { // JumpStats
	    			g_bJumpStatsEnabled[id] = !g_bJumpStatsEnabled[id];
	    			chat_print(id, "跳跃数据: %s", g_bJumpStatsEnabled[id] ? "开" : "关");
	    			set_task(0.2, "taskReopenDisplayMenu", id);
	    		}
	} else if ((key == 8 || key == 9)) {
	    showMainMenu(id); // Back
	}
}

public taskReopenDisplayMenu(id) {
	if (is_user_connected(id))
		showDisplayMenu(id);
}

// ============================================================================
// HIDE KNIFE HELPER
// ============================================================================

stock applyHideKnife(id) {
	if (!is_user_alive(id))
		return;

	new iTeam = getUserTeam(id);
	new bool:bHide = false;

	if (iTeam == TEAM_TERRORIST && g_bHideKnifeTT[id])
		bHide = true;
	else if (iTeam == TEAM_CT && g_bHideKnifeCT[id])
		bHide = true;

	new iActiveItem = get_member(id, m_pActiveItem);
	if (!is_nullent(iActiveItem) && get_member(iActiveItem, m_iId) == WEAPON_KNIFE) {
		set_entvar(id, var_viewmodel, bHide ? "" : "models/v_knife.mdl");
	}
}

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
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w批准离开^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w添加替补^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w踢出玩家^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w逃兵解封^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w发放管理^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICAdminMenu");
}

public adminMenuHandler(id, key) {
	if (key == 0) {
	    client_cmd(id, "say /watcher");
	} else if (key == 1) {
	    client_cmd(id, "say /replace");
	} else if (key == 2) {
	    matchControl_admin_menu(id);
	} else if (key == 3) {
	    client_cmd(id, "say /ai");
	} else if (key == 4) {
	    client_cmd(id, "say /approve");
	} else if (key == 5) {
	    client_cmd(id, "say /sub");
	} else if (key == 6) {
	    client_cmd(id, "amx_kickmenu");
	} else if (key == 7) {
	    client_cmd(id, "say /unban");
	} else if (key == 8) {
	    showDistributeMenu(id);
	} else if (key == 9) {
	    showMainMenu(id); // Back
	}
}

// ============================================================================
// SERVER CONSOLE MENU (FullWatcher+)
// ============================================================================

showServerConsoleMenu(id) {
	if (!isUserFullWatcher(id) && !is_user_admin(id)) {
		showAdminMenu(id);
		return;
	}

	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r服务器控制台^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w重力: \y%.0f^n", get_cvar_float("sv_gravity"));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w最大速度: \y%.0f^n", get_cvar_float("sv_maxspeed"));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w摩擦力: \y%.0f^n", get_cvar_float("sv_friction"));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w空中加速: \y%d^n", get_cvar_num("sv_airaccelerate"));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w作弊: \y%s^n", get_cvar_num("sv_cheats") ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w全体语音: \y%s^n", get_cvar_num("sv_alltalk") ? "开" : "关");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w重启服务器^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w更换地图^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICServerConsole");
}

public serverConsoleHandler(id, key) {
	if (key == 0) {
	    { // Gravity cycle
	    			new Float:flG = get_cvar_float("sv_gravity");
	    			if (flG <= 200.0) flG = 400.0;
	    			else if (flG <= 400.0) flG = 800.0;
	    			else if (flG <= 800.0) flG = 1200.0;
	    			else flG = 100.0;
	    			set_cvar_float("sv_gravity", flG);
	    			chat_print(0, "重力 set to %.0f", flG);
	    			showServerConsoleMenu(id);
	    		}
	} else if (key == 1) {
	    { // Maxspeed cycle
	    			new Float:flS = get_cvar_float("sv_maxspeed");
	    			if (flS <= 250.0) flS = 320.0;
	    			else if (flS <= 320.0) flS = 500.0;
	    			else if (flS <= 500.0) flS = 1000.0;
	    			else flS = 250.0;
	    			set_cvar_float("sv_maxspeed", flS);
	    			chat_print(0, "Maxspeed set to %.0f", flS);
	    			showServerConsoleMenu(id);
	    		}
	} else if (key == 2) {
	    { // Friction cycle
	    			new Float:flF = get_cvar_float("sv_friction");
	    			if (flF <= 1.0) flF = 4.0;
	    			else if (flF <= 4.0) flF = 8.0;
	    			else flF = 1.0;
	    			set_cvar_float("sv_friction", flF);
	    			chat_print(0, "摩擦力 set to %.0f", flF);
	    			showServerConsoleMenu(id);
	    		}
	} else if (key == 3) {
	    { // Airaccelerate cycle
	    			new iAA = get_cvar_num("sv_airaccelerate");
	    			if (iAA <= 0) iAA = 10;
	    			else if (iAA <= 10) iAA = 100;
	    			else if (iAA <= 100) iAA = 1000;
	    			else iAA = 0;
	    			set_cvar_num("sv_airaccelerate", iAA);
	    			chat_print(0, "Airaccelerate set to %d", iAA);
	    			showServerConsoleMenu(id);
	    		}
	} else if (key == 4) {
	    { // Cheats toggle
	    			new iC = get_cvar_num("sv_cheats") ? 0 : 1;
	    			set_cvar_num("sv_cheats", iC);
	    			chat_print(0, "作弊 %s", iC ? "开" : "关");
	    			showServerConsoleMenu(id);
	    		}
	} else if (key == 5) {
	    { // Alltalk toggle
	    			new iT = get_cvar_num("sv_alltalk") ? 0 : 1;
	    			set_cvar_num("sv_alltalk", iT);
	    			chat_print(0, "Alltalk %s", iT ? "开" : "关");
	    			showServerConsoleMenu(id);
	    		}
	} else if (key == 6) {
	    { // Restart server
	    			chat_print(0, "Server restarting...");
	    			server_cmd("restart");
	    			server_exec();
	    		}
	} else if (key == 7) {
	    { // Change map
	    			showMapChangeMenu(id);
	    		}
	} else if ((key == 8 || key == 9)) {
	    showAdminMenu(id); // Back
	}
}

// ============================================================================
// MAP CHANGE MENU
// ============================================================================

showMapChangeMenu(id) {
	new szMenu[512], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r更换地图^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wde_dust2^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wde_inferno^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \wde_nuke^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \wde_train^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \wde_mirage^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \wcs_italy^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \wfy_snow^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \whns_floppytown^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "HnsICMapChange");
}

public mapChangeHandler(id, key) {
	new szMap[32];
	if (key == 0) {
	    copy(szMap, charsmax(szMap), "de_dust2");
	} else if (key == 1) {
	    copy(szMap, charsmax(szMap), "de_inferno");
	} else if (key == 2) {
	    copy(szMap, charsmax(szMap), "de_nuke");
	} else if (key == 3) {
	    copy(szMap, charsmax(szMap), "de_train");
	} else if (key == 4) {
	    copy(szMap, charsmax(szMap), "de_mirage");
	} else if (key == 5) {
	    copy(szMap, charsmax(szMap), "cs_italy");
	} else if (key == 6) {
	    copy(szMap, charsmax(szMap), "fy_snow");
	} else if (key == 7) {
	    copy(szMap, charsmax(szMap), "hns_floppytown");
	} else if ((key == 8 || key == 9)) {
	    { showServerConsoleMenu(id); return; }
	}

	if (szMap[0]) {
		chat_print(0, "Changing map to %s...", szMap);
		server_cmd("changelevel %s", szMap);
		server_exec();
	}
}

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
stock bool:hnsmenu_get_hideknife_tt(id) { return g_bHideKnifeTT[id]; }
stock bool:hnsmenu_get_hideknife_ct(id) { return g_bHideKnifeCT[id]; }

// ============================================================================
// TEAM JOIN MENU - 加入队伍
// ============================================================================

showTeamJoinMenu(id) {
	new szMenu[512], iLen;
	new iNumTT = get_playersnum_ex(GetPlayers_MatchTeam, "TERRORIST");
	new iNumCT = get_playersnum_ex(GetPlayers_MatchTeam, "CT");
	new TeamName:iCurTeam = getUserTeam(id);

	new szTitle[64];
	if (g_szPrefix[0])
		formatex(szTitle, charsmax(szTitle), "%s", g_szPrefix);
	else
		copy(szTitle, charsmax(szTitle), "HNS");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s \w- \y加入队伍^n^n", szTitle);

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "当前: \y%s\w | TT: \y%d\w | CT: \y%d^n^n",
		iCurTeam == TEAM_TERRORIST ? "TT" : (iCurTeam == TEAM_CT ? "CT" : "观战"),
		iNumTT, iNumCT);

	// Option 1: Join Terrorist
	if (iCurTeam == TEAM_TERRORIST)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d1. 恐怖分子 (已在) \r[%d]^n", iNumTT);
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w恐怖分子 \y[%d]^n", iNumTT);

	// Option 2: Join Counter-Terrorist
	if (iCurTeam == TEAM_CT)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d2. 反恐精英 (已在) \r[%d]^n", iNumCT);
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w反恐精英 \y[%d]^n", iNumCT);

	// Option 3: Join Spectator
	if (iCurTeam == TEAM_SPECTATOR)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d3. 观察者 (已在)^n");
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w观察者^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<9), szMenu, -1, "HnsICTeamJoinMenu");
}

public teamJoinMenuHandler(id, key) {
	if (key == 9) {
		showMainMenu(id);
		return;
	}

	// 比赛进行中禁止换队
	if (g_eMatchState == STATE_ENABLED || g_eMatchState == STATE_PAUSED) {
		client_print(id, print_chat, "[HNS] 比赛进行中，禁止更换队伍");
		showMainMenu(id);
		return;
	}

	if (key == 0) {
		// Join Terrorist
		if (getUserTeam(id) != TEAM_TERRORIST) {
			g_eSpecBack[id] = getUserTeam(id);
			rg_set_user_team(id, TEAM_TERRORIST);
			if (rg_is_player_can_respawn(id))
				rg_round_respawn(id);
		}
	} else if (key == 1) {
		// Join Counter-Terrorist
		if (getUserTeam(id) != TEAM_CT) {
			g_eSpecBack[id] = getUserTeam(id);
			rg_set_user_team(id, TEAM_CT);
			if (rg_is_player_can_respawn(id))
				rg_round_respawn(id);
		}
	} else if (key == 2) {
		// Join Spectator
		if (getUserTeam(id) != TEAM_SPECTATOR) {
			g_eSpecBack[id] = getUserTeam(id);
			transferUserToSpec(id);
		}
	}
}

// ============================================================================
// DISTRIBUTE MANAGEMENT MENU (发放管理) - FullWatcher+
// ============================================================================

// Player cache for distribute menu
new g_iDistPage[33];
new g_iDistPlayers[32], g_iDistCount;
new g_iSkinDistribTarget[33];  // Target for skin distribution flow

showDistributeMenu(id) {
	if (!isUserFullWatcher(id) && !is_user_admin(id)) {
		showMainMenu(id);
		return;
	}

	new szMenu[768], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r发放管理^n^n");

	// ─── 权限 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w发放皮肤^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w设置Watcher^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w设置VIP^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w设置管理员^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w设置服主^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w清除权限^n");

	// ─── 其他 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \w管理员皮肤^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w服务器控制台^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<8)|(1<<9), szMenu, -1, "HnsICDistribute");
}

public distributeMenuHandler(id, key) {
	// 先保存action再延迟打开，避免嵌套菜单
	if (key == 0) {
		// ★ 发放皮肤 → 直接走新的皮肤发放系统
		showPersonalSkinDistribPlayerList(id);
		return;
	} else if (key == 1) {
		g_iDistAction[id] = 1;  // 临时管理
		set_task(0.1, "taskReopenDistributePlayerList", id);
	} else if (key == 2) {
		g_iDistAction[id] = 2;  // VIP
		set_task(0.1, "taskReopenDistributePlayerList", id);
	} else if (key == 3) {
		g_iDistAction[id] = 3;  // 管理员
		set_task(0.1, "taskReopenDistributePlayerList", id);
	} else if (key == 4) {
		g_iDistAction[id] = 4;  // 服主
		set_task(0.1, "taskReopenDistributePlayerList", id);
	} else if (key == 5) {
		g_iDistAction[id] = 5;  // 清除权限
		set_task(0.1, "taskReopenDistributePlayerList", id);
	} else if (key == 6) {
		// 管理员皮肤 - 触发皮肤插件的管理员皮肤菜单
		client_cmd(id, "say /adminskin");
	} else if (key == 7) {
		// 服务器控制台
		set_task(0.1, "taskReopenServerConsole", id);
	} else if (key == 8 || key == 9) {
		set_task(0.1, "taskReopenMainMenu", id);
	}
}

// ============================================================================
// SKIN DISTRIBUTION TYPE MENU - Step 2 of 3 (select T/CT/Knife)
// ============================================================================
// 已废弃：旧分发皮肤菜单已被 showPersonalSkinDistribType 替代
// 保留 stub 防止编译错误

showDistributePlayerList(id, action) {
	if (!isUserFullWatcher(id) && !is_user_admin(id)) {
		showMainMenu(id);
		return;
	}

	g_iDistPage[id] = 0;

	new szMenu[768], iLen;
	new szAction[32];
	if (action == 0) copy(szAction, charsmax(szAction), "发放皮肤");
	else if (action == 1) copy(szAction, charsmax(szAction), "设置VIP");
	else if (action == 2) copy(szAction, charsmax(szAction), "设置管理员");
	else if (action == 3) copy(szAction, charsmax(szAction), "设置服主");
	else if (action == 4) copy(szAction, charsmax(szAction), "清除权限");

	iLen = formatex(szMenu, charsmax(szMenu), "\r%s - \y选择玩家^n^n", szAction);

	new players[32], num, iPlayer;
	get_players(players, num, "ch");

	if (num == 0) {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d没有玩家在线^n");
	} else {
		for (new i = 0; i < num && i < 7; i++) {
			iPlayer = players[i];
			new szName[32], szTeam[8];
			get_user_name(iPlayer, szName, charsmax(szName));
			if (getUserTeam(iPlayer) == TEAM_TERRORIST)
				copy(szTeam, charsmax(szTeam), "\r[T]");
			else if (getUserTeam(iPlayer) == TEAM_CT)
				copy(szTeam, charsmax(szTeam), "\d[CT]");
			else
				copy(szTeam, charsmax(szTeam), "\w[OB]");

			// Get perm level display
			new szPerm[16];
			new iPerm = hns_get_user_perm_level(iPlayer);
			if (iPerm == 4)
				copy(szPerm, charsmax(szPerm), " \d[服主]");
			else if (iPerm == 3)
				copy(szPerm, charsmax(szPerm), " \d[管理]");
			else if (iPerm == 2)
				copy(szPerm, charsmax(szPerm), " \d[VIP]");
			else if (iPerm == 1)
				copy(szPerm, charsmax(szPerm), " \d[Watcher]");
			else
				szPerm[0] = '^0';

			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s %s%s^n", i + 1, szName, szTeam, szPerm);
		}
	}

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回");

	// Store action type for handler
	g_iDistPlayers = players;
	g_iDistCount = num;
	g_iDistAction[id] = action;

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<8)|(1<<9), szMenu, -1, "HnsICDistPlayer");
}

public distributePlayerHandler(id, key) {
	new action = g_iDistAction[id];

	if (key == 8 || key == 9 || key >= g_iDistCount) {
		set_task(0.1, "taskReopenDistributeMenu", id);
		return;
	}

	new target = g_iDistPlayers[key];
	if (!is_user_connected(target)) {
		client_print(id, print_chat, "[HNS] 目标玩家已离开");
		set_task(0.1, "taskReopenDistributeMenu", id);
		return;
	}

	new szName[32], szAuth[64];
	get_user_name(target, szName, charsmax(szName));
	get_user_authid(target, szAuth, charsmax(szAuth));

	if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:"))
		get_user_ip(target, szAuth, charsmax(szAuth), 1);

	// 发放皮肤 - 使用新皮肤发放菜单（无嵌套菜单）
	if (action == 0) {
		g_iSkinDistribTarget[id] = target;
		client_print(id, print_chat, "[HNS] 已选择玩家: %s", szName);
		set_task(0.1, "taskReopenSkinDistrib", id);
	}
	// 设置临时管理
	else if (action == 1) {
		hns_set_user_perm_level(target, 1);
		hns_perm_save_by_auth(szAuth, 1);
		chat_print(0, "^4[HNS] ^3%s ^1被设置为 ^4Watcher", szName);
	}
	// 设置VIP
	else if (action == 2) {
		hns_set_user_perm_level(target, 2);
		hns_perm_save_by_auth(szAuth, 2);
		chat_print(0, "^4[HNS] ^3%s ^1被设置为 ^4VIP", szName);
	}
	// 设置管理员
	else if (action == 3) {
		hns_set_user_perm_level(target, 3);
		hns_perm_save_by_auth(szAuth, 3);
		chat_print(0, "^4[HNS] ^3%s ^1被设置为 ^4管理员", szName);
	}
	// 设置服主
	else if (action == 4) {
		hns_set_user_perm_level(target, 4);
		hns_perm_save_by_auth(szAuth, 4);
		chat_print(0, "^4[HNS] ^3%s ^1被设置为 ^4服主", szName);
	}
	// 清除权限
	else if (action == 5) {
		hns_set_user_perm_level(target, 0);
		hns_perm_save_by_auth(szAuth, 0);
		chat_print(0, "^4[HNS] ^3%s ^1的权限已被清除", szName);
	}

	set_task(0.1, "taskReopenDistributeMenu", id);
}

// ============================================================================
// PERSONAL SKIN DISTRIBUTE - 个人菜单 → 发放皮肤管理
// ============================================================================
showPersonalSkinDistribPlayerList(id) {
	new szMenu[1024], iLen, szName[32], iPlayers[MAX_PLAYERS], iNum, iKey;

	get_players(iPlayers, iNum, "ch");

	iLen = formatex(szMenu, charsmax(szMenu), "\y发放皮肤管理^n^n");

	if (iNum == 0) {
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r无可用玩家^n^n");
	} else {
		for (new i = 0; i < iNum; i++) {
			iKey = i;
			get_user_name(iPlayers[i], szName, charsmax(szName));

			if (iKey == 9) {
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%s^n", szName);
			} else {
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iKey + 1, szName);
			}
		}
	}
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \w返回");

	g_iDistPlayers = iPlayers;
	g_iDistCount = iNum;
	g_iDistAction[id] = 0; // action = 0 for skin distribute

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<8)|(1<<9), szMenu, -1, "HnsICPersonalSkinDistPlayer");
}

public personalSkinDistribPlayerHandler(id, key) {
	if (key == 7 || key == 8 || key == 9 || key >= g_iDistCount) {
		set_task(0.1, "taskReopenPersonalMenu", id);
		return;
	}

	new target = g_iDistPlayers[key];
	if (!is_user_connected(target)) {
		client_print(id, print_chat, "[HNS] 目标玩家已离开");
		set_task(0.1, "taskReopenPersonalMenu", id);
		return;
	}

	new szName[32];
	get_user_name(target, szName, charsmax(szName));
	g_iSkinDistribTarget[id] = target;
	client_print(id, print_chat, "[HNS] 已选择玩家: %s", szName);

	// 延迟显示皮肤类型选择，避免嵌套菜单触发VGUIMenu
	set_task(0.1, "taskReopenSkinDistrib", id);
}

showPersonalSkinDistribType(id) {
	new szTargetName[32];
	new iTarget = g_iSkinDistribTarget[id];
	get_user_name(iTarget, szTargetName, charsmax(szTargetName));

	new szMenu[384], iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\r发放皮肤 - \y%s^n^n", szTargetName);

	// ─── 单个发放 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w单个发放 T皮肤^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w单个发放 CT皮肤^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w单个发放 刀皮肤^n");

	// ─── 全部发放 ───
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w全部发放 T皮肤^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w全部发放 CT皮肤^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w全部发放 刀皮肤^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w返回");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), szMenu, -1, "HnsICPersonalSkinDistType");
}

public personalSkinDistribTypeHandler(id, key) {
	if (key == 9) {
		showPersonalSkinDistribPlayerList(id);
		return;
	}

	new iTarget = g_iSkinDistribTarget[id];
	if (!is_user_connected(iTarget)) {
		client_print(id, print_chat, "[HNS] 目标玩家已离开");
		showPersonalSkinDistribPlayerList(id);
		return;
	}

	new szTargetName[32];
	get_user_name(iTarget, szTargetName, charsmax(szTargetName));

	if (key == 0) {
		// 单个发放 T皮肤
		server_cmd("hns_giveskin_menu %d %d T", get_user_userid(id), get_user_userid(iTarget));
		client_print(id, print_chat, "[HNS] 打开 %s 的T皮肤列表...", szTargetName);
	} else if (key == 1) {
		// 单个发放 CT皮肤
		server_cmd("hns_giveskin_menu %d %d CT", get_user_userid(id), get_user_userid(iTarget));
		client_print(id, print_chat, "[HNS] 打开 %s 的CT皮肤列表...", szTargetName);
	} else if (key == 2) {
		// 单个发放 刀皮肤
		server_cmd("hns_giveskin_menu %d %d Knife", get_user_userid(id), get_user_userid(iTarget));
		client_print(id, print_chat, "[HNS] 打开 %s 的刀皮肤列表...", szTargetName);
	} else if (key == 3) {
		// 全部发放 T皮肤
		server_cmd("hns_giveallskins_menu %d T", get_user_userid(iTarget));
		client_print(id, print_chat, "[HNS] 已发放全部T皮肤给 %s", szTargetName);
	} else if (key == 4) {
		// 全部发放 CT皮肤
		server_cmd("hns_giveallskins_menu %d CT", get_user_userid(iTarget));
		client_print(id, print_chat, "[HNS] 已发放全部CT皮肤给 %s", szTargetName);
	} else if (key == 5) {
		// 全部发放 刀皮肤
		server_cmd("hns_giveallskins_menu %d Knife", get_user_userid(iTarget));
		client_print(id, print_chat, "[HNS] 已发放全部刀皮肤给 %s", szTargetName);
	}

	// 对于全部发放，重开菜单方便继续操作
	if (key >= 3) {
		showPersonalSkinDistribType(id);
	}
}

// ============================================================================
// PERM SAVE HELPER - Simple append, no Array dependency
// ============================================================================
hns_perm_save_by_auth(szAuth[], perm) {
	new szDir[128], szFile[256];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szFile, charsmax(szFile), "%s/mixsystem/owner_list.txt", szDir);

	// Simple append: last matching entry wins on load
	new fp = fopen(szFile, "at");
	if (fp) {
		fprintf(fp, "%s owner %d^n", szAuth, perm);
		fclose(fp);
	}
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
// LOAD OWNER LIST ON CONNECT (safe, no crash)
// ============================================================================
hns_load_owner_list(id) {
	new szAuth[64];
	get_user_authid(id, szAuth, charsmax(szAuth));
	if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:"))
		get_user_ip(id, szAuth, charsmax(szAuth), 1);

	new szDir[128], szFile[256];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szFile, charsmax(szFile), "%s/mixsystem/owner_list.txt", szDir);

	if (!file_exists(szFile)) return false;

	new fp = fopen(szFile, "rt");
	if (!fp) return false;

	new szLine[256], szReadAuth[64], szReadName[32], szReadPerm[8];
	new iFoundPerm = -1;

	while (!feof(fp)) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') continue;
		parse(szLine, szReadAuth, charsmax(szReadAuth), szReadName, charsmax(szReadName), szReadPerm, charsmax(szReadPerm));

		if (equal(szReadAuth, szAuth)) {
			iFoundPerm = str_to_num(szReadPerm);
		}
	}
	fclose(fp);

	if (iFoundPerm >= 0) {
		hns_set_user_perm_level(id, iFoundPerm);
		if (iFoundPerm == 4)
			client_print(id, print_chat, "[HNS] 欢迎服主！你的权限已自动加载。");
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
