#if defined _deserter_included
	#endinput
#endif
#define _deserter_included

// === Deserter Penalty System ===
// Players who leave during a match get PTS penalty + temporary match ban
// Multiple desertions increase ban duration exponentially

// Per-player deserter data (g_iDesertCount defined in globals.inc)
new g_iDeserterBanEnd[MAX_PLAYERS + 1] = {0, ...};    // Unix timestamp when ban expires
new bool:g_bDeserterActive[MAX_PLAYERS + 1] = {false, ...}; // Was in match when left

// Cvar-backed settings
new g_iDesertPenaltyPts = 30;       // PTS penalty per desertion
new g_iDesertBanBase = 1800;        // Base ban duration in seconds (30 min)
new g_iDesertBanMultiplier = 2;     // Ban multiplier per consecutive desertion
new g_iDesertBanMax = 86400;        // Max ban duration (24 hours)
new g_iDesertMinRounds = 3;         // Minimum rounds played before penalty applies
new g_iDesertMinTime = 300;         // Minimum match time in seconds (5 min) before penalty

// Match start time (set when match begins)
new Float:g_flDeserterMatchStart = 0.0;

// Leave cooldown per player
new Float:g_flLeaveCooldown[MAX_PLAYERS + 1] = {0.0, ...};
new Float:g_flLeaveCooldownTime = 60.0; // 60 seconds cooldown

// === Check if player is currently banned from matches ===
stock bool:deserter_is_banned(id) {
	if (g_iDeserterBanEnd[id] == 0) return false;
	if (get_systime() >= g_iDeserterBanEnd[id]) {
		// Ban expired, reset
		g_iDeserterBanEnd[id] = 0;
		g_iDesertCount[id] = 0;
		return false;
	}
	return true;
}

// === Get remaining ban time in seconds ===
stock deserter_get_ban_remaining(id) {
	if (g_iDeserterBanEnd[id] == 0) return 0;
	new iRemaining = g_iDeserterBanEnd[id] - get_systime();
	if (iRemaining < 0) return 0;
	return iRemaining;
}

// === Apply penalty when player leaves during match ===
// Returns: ban duration in seconds (0 if no penalty)
stock deserter_apply_penalty(id) {
	if (!g_bDeserterActive[id]) return 0;
	g_bDeserterActive[id] = false;

	// Check minimum requirements
	new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];
	if (iMatchRounds < g_iDesertMinRounds) return 0;

	new Float:flMatchTime = get_gametime() - g_flDeserterMatchStart;
	if (flMatchTime < float(g_iDesertMinTime)) return 0;

	g_iDesertCount[id]++;

	// Calculate ban duration (exponential)
	new iBanDuration = g_iDesertBanBase;
	for (new i = 1; i < g_iDesertCount[id]; i++) {
		iBanDuration = iBanDuration * g_iDesertBanMultiplier;
		if (iBanDuration > g_iDesertBanMax) {
			iBanDuration = g_iDesertBanMax;
			break;
		}
	}

	g_iDeserterBanEnd[id] = get_systime() + iBanDuration;

	// Deduct PTS if MySQL available
	if (hns_mysql_stats_init()) {
		hns_mysql_stats_deduct_pts(id, g_iDesertPenaltyPts);
	}

	// Notify all players
	new szName[32];
	get_user_name(id, szName, charsmax(szName));

	new szBanTime[32];
	if (iBanDuration >= 86400) {
		formatex(szBanTime, charsmax(szBanTime), "%dh", iBanDuration / 3600);
	} else if (iBanDuration >= 3600) {
		formatex(szBanTime, charsmax(szBanTime), "%dh %dm", iBanDuration / 3600, (iBanDuration % 3600) / 60);
	} else {
		formatex(szBanTime, charsmax(szBanTime), "%dmin", iBanDuration / 60);
	}

	chat_print(0, "[HNS] %n left during match! PTS -%d, banned from matches for %s (%d desertions).",
		id, g_iDesertPenaltyPts, szBanTime, g_iDesertCount[id]);

	return iBanDuration;
}

// === Clear penalty when match ends normally ===
stock deserter_clear_on_match_end() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		g_bDeserterActive[iPlayers[i]] = false;
	}
}

// === Mark player as active in match ===
stock deserter_mark_active(id) {
	g_bDeserterActive[id] = true;
}

// === Player voluntarily leaves match (no penalty) ===
// Returns: true if allowed, false if on cooldown
stock bool:deserter_excuse_leave(id) {
	// Check cooldown
	new Float:flElapsed = get_gametime() - g_flLeaveCooldown[id];
	if (flElapsed < g_flLeaveCooldownTime) {
		return false;
	}

	g_bDeserterActive[id] = false;
	g_flLeaveCooldown[id] = get_gametime(); // Set cooldown
	deserter_save(id);
	return true;
}

// === Get remaining leave cooldown in seconds ===
stock Float:deserter_get_leave_cooldown(id) {
	new Float:flElapsed = get_gametime() - g_flLeaveCooldown[id];
	new Float:flRemaining = g_flLeaveCooldownTime - flElapsed;
	if (flRemaining < 0.0) return 0.0;
	return flRemaining;
}

// === Record match start time ===
stock deserter_match_start() {
	g_flDeserterMatchStart = get_gametime();
}

// === Reset on disconnect ===
stock deserter_reset(id) {
	g_bDeserterActive[id] = false;
	// Don't reset ban/desert count - persist via PDS
}

// === Save/Load via PDS ===
stock deserter_save(id) {
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));

	new szKey[64];
	formatex(szKey, charsmax(szKey), "deserter_%s", szAuth);
	PDS_SetCell(szKey, g_iDesertCount[id]);

	formatex(szKey, charsmax(szKey), "deserter_ban_%s", szAuth);
	PDS_SetCell(szKey, g_iDeserterBanEnd[id]);
}

stock deserter_load(id) {
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));

	new szKey[64], data;
	formatex(szKey, charsmax(szKey), "deserter_%s", szAuth);
	if (PDS_GetCell(szKey, data))
		g_iDesertCount[id] = data;

	formatex(szKey, charsmax(szKey), "deserter_ban_%s", szAuth);
	if (PDS_GetCell(szKey, data))
		g_iDeserterBanEnd[id] = data;

	// Check if ban already expired
	if (g_iDeserterBanEnd[id] > 0 && get_systime() >= g_iDeserterBanEnd[id]) {
		g_iDeserterBanEnd[id] = 0;
		g_iDesertCount[id] = 0;
	}
}

// === Admin commands ===
stock deserter_admin_unban(id, target) {
	if (!(get_user_flags(id) & ADMIN_CFG)) {
		client_print(id, print_chat, "[HNS] Admin only.");
		return;
	}

	g_iDeserterBanEnd[target] = 0;
	g_iDesertCount[target] = 0;
	deserter_save(target);

	client_print(0, print_chat, "[HNS] Admin %n removed deserter ban from %n.", id, target);
}

stock deserter_admin_check(id, target) {
	new szName[32];
	get_user_name(target, szName, charsmax(szName));

	if (deserter_is_banned(target)) {
		new iRemaining = deserter_get_ban_remaining(target);
		client_print(id, print_chat, "[HNS] %s: BANNED from matches (%d desertions, %d sec remaining).",
			szName, g_iDesertCount[target], iRemaining);
	} else {
		client_print(id, print_chat, "[HNS] %s: No active deserter ban. (Desertions: %d)",
			szName, g_iDesertCount[target]);
	}
}
