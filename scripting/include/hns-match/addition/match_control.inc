#if defined _match_control_included
	#endinput
#endif
#define _match_control_included

// === Match Control Menu ===
// Player can request to leave, admin can approve/substitute/pause

// Leave request
new bool:g_bLeaveRequest[MAX_PLAYERS + 1] = {false, ...};
new g_iLeaveRequestTarget[MAX_PLAYERS + 1] = {0, ...}; // Who wants to leave
new g_iLeaveRequestCount = 0;

// Substitute request
new g_iSubstituteRequest[MAX_PLAYERS + 1] = {0, ...}; // Player who wants to sub in

// === Player Menu (available during match) ===
stock matchControl_player_menu(id) {
	if (g_iCurrentMode != MODE_MIX && g_iCurrentMode != MODE_ASCENSION && g_iCurrentMode != MODE_VAMP) {
		client_print(id, print_chat, "[HNS] No active match.");
		return;
	}

	new szMenu[512], len;
	new bool:bInMatch = g_ePlayerInfo[id][PLAYER_MATCH];

	len = formatex(szMenu, charsmax(szMenu), "\r[HNS] \wMatch Control^n^n");

	if (bInMatch) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w Request to leave match^n");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d1. Request to leave (not in match)^n");
	}

	if (!bInMatch) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w Request to substitute^n");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d2. Request to substitute (in match)^n");
	}

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0.\w Exit");

	show_menu(id, (1<<0)|(1<<1)|(1<<9), szMenu, -1, "MatchControlPlayer");
}

public handleMatchControlPlayer(id, key) {
	if (key == 0) {
		// Request to leave
		if (!g_ePlayerInfo[id][PLAYER_MATCH]) {
			client_print(id, print_chat, "[HNS] You are not in the match.");
			return;
		}
		if (g_bLeaveRequest[id]) {
			client_print(id, print_chat, "[HNS] You already have a pending request.");
			return;
		}

		g_bLeaveRequest[id] = true;
		g_iLeaveRequestCount++;

		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		chat_print(0, "[HNS] %n requests to leave the match. Waiting for watcher approval.", id);

		// Notify watchers
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			if (isUserWatcher(iPlayers[i])) {
				set_hudmessage(.red = 255, .green = 100, .blue = 100, .x = -1.0, .y = 0.3, .holdtime = 8.0);
				show_hudmessage(iPlayers[i], "%n wants to leave!^nType /approve %d or /deny %d", id, id, id);
			}
		}
	} else if (key == 1) {
		// Request to substitute
		if (g_ePlayerInfo[id][PLAYER_MATCH]) {
			client_print(id, print_chat, "[HNS] You are already in the match.");
			return;
		}

		g_iSubstituteRequest[id] = 1;

		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		chat_print(0, "[HNS] %n wants to substitute into the match.", id);

		// Notify watchers
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i = 0; i < iNum; i++) {
			if (isUserWatcher(iPlayers[i])) {
				set_hudmessage(.red = 100, .green = 255, .blue = 100, .x = -1.0, .y = 0.3, .holdtime = 8.0);
				show_hudmessage(iPlayers[i], "%n wants to sub in!^nType /sub %d to add them", id, id);
			}
		}
	}
}

// === Admin/Watcher Menu ===
stock matchControl_admin_menu(id) {
	if (!isUserWatcher(id) && !isUserFullWatcher(id)) {
		client_print(id, print_chat, "[HNS] Watcher only.");
		return;
	}

	new szMenu[512], len;

	len = formatex(szMenu, charsmax(szMenu), "\r[HNS] \wMatch Control (Admin)^n^n");

	// List pending leave requests
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r--- Leave Requests ---^n");
	new iPlayers[MAX_PLAYERS], iNum;
	new bool:bHasRequest = false;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		if (g_bLeaveRequest[iPlayers[i]]) {
			bHasRequest = true;
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\y%d. %n wants to leave^n", iPlayers[i], iPlayers[i]);
		}
	}
	if (!bHasRequest) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "  No pending requests^n");
	}

	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r--- Actions ---^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r8.\w Pause/Resume match^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r9.\w Stop match^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w Exit");

	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), szMenu, -1, "MatchControlAdmin");
}

public handleMatchControlAdmin(id, key) {
	if (!isUserWatcher(id) && !isUserFullWatcher(id)) return;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	// Keys 1-7: approve leave requests
	if (key >= 0 && key <= 6) {
		new iRequestIdx = 0;
		for (new i = 0; i < iNum; i++) {
			if (g_bLeaveRequest[iPlayers[i]]) {
				if (iRequestIdx == key) {
					// Approve this request
					g_bLeaveRequest[iPlayers[i]] = false;
					g_iLeaveRequestCount--;

					// No penalty leave
					deserter_excuse_leave(iPlayers[i]);

					new szName[32];
					get_user_name(iPlayers[i], szName, charsmax(szName));
					chat_print(0, "[HNS] Watcher %n approved %s's leave request (no penalty).", id, szName);

					// Transfer to spec
					transferUserToSpec(iPlayers[i]);
					break;
				}
				iRequestIdx++;
			}
		}
		matchControl_admin_menu(id);
		return;
	}

	if (key == 7) {
		// Pause/Resume
		if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE]) {
			ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE], _);
			chat_print(0, "[HNS] Watcher %n toggled pause.", id);
		}
		matchControl_admin_menu(id);
	} else if (key == 8) {
		// Stop match
		if (g_ModFuncs[g_iCurrentMode][MODEFUNC_END]) {
			ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_END], _);
			chat_print(0, "[HNS] Watcher %n stopped the match.", id);
		}
	}
}

// === Admin commands ===
// /approve <id|name> - approve leave request
// /deny <id|name> - deny leave request  
// /sub <id|name> - add player as substitute
stock matchControl_approve_leave(adminid, target) {
	if (!g_bLeaveRequest[target]) {
		client_print(adminid, print_chat, "[HNS] That player has no pending request.");
		return;
	}

	g_bLeaveRequest[target] = false;
	g_iLeaveRequestCount--;
	deserter_excuse_leave(target);

	new szName[32];
	get_user_name(target, szName, charsmax(szName));
	chat_print(0, "[HNS] Watcher %n approved %s's leave request (no penalty).", adminid, szName);
	transferUserToSpec(target);
}

stock matchControl_deny_leave(adminid, target) {
	if (!g_bLeaveRequest[target]) {
		client_print(adminid, print_chat, "[HNS] That player has no pending request.");
		return;
	}

	g_bLeaveRequest[target] = false;
	g_iLeaveRequestCount--;

	new szName[32];
	get_user_name(target, szName, charsmax(szName));
	chat_print(0, "[HNS] Watcher %n denied %s's leave request.", adminid, szName);
	client_print(target, print_chat, "[HNS] Your leave request was denied. Stay in the match!");
}

stock matchControl_add_substitute(adminid, target) {
	if (g_ePlayerInfo[target][PLAYER_MATCH]) {
		client_print(adminid, print_chat, "[HNS] That player is already in the match.");
		return;
	}

	g_iSubstituteRequest[target] = 0;

	new szName[32];
	get_user_name(target, szName, charsmax(szName));
	chat_print(0, "[HNS] Watcher %n added %s as substitute.", adminid, szName);

	// Trigger join
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_JOIN]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_JOIN], _, target);
	}
}

// === Reset on match end ===
stock matchControl_reset() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		g_bLeaveRequest[iPlayers[i]] = false;
		g_iSubstituteRequest[iPlayers[i]] = 0;
	}
	g_iLeaveRequestCount = 0;
}
