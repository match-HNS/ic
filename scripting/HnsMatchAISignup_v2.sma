#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_matchsystem>

#define PLUGIN_NAME "HNS AI Signup"
#define PLUGIN_VERSION "2.0.0"
#define PLUGIN_AUTHOR "HNS"

#define TASK_SIGNUP_COUNTDOWN  1001
#define TASK_SIGNUP_TIMEOUT    1002
#define TASK_VOTE_TIMEOUT      1003
#define TASK_KNIFE_CHECK       1004
#define TASK_START_MATCH       1005
#define TASK_RECOVERY          1006
#define TASK_TEAM_ASSIGN       1007
#define TASK_INFO_HUD          1008

#define MAX_PLAYERS 32
#define MAX_MAPS 256
#define MAX_MAP_NAME 32

enum _:SIGNUP_STATE {
	STATE_IDLE = 0,
	STATE_SIGNUP,
	STATE_KNIFE_PENDING,
	STATE_KNIFE_ACTIVE,
	STATE_VOTE_MODE,
	STATE_FINAL,
	STATE_LOCKED
};

enum _:SIGNUP_MAP_TYPE {
	MAP_BOOST = 0,
	MAP_SKILL
};

enum _:MAP_DATA {
	MD_NAME[MAX_MAP_NAME],
	MD_TYPE
};

enum _:SIGNUP_MODE {
	MODE_MR = 0,
	MODE_TIMER,
	MODE_POINTSCAP,
	MODE_VAMP,
	MODE_ROUNDS,
	MODE_COUNT
};

enum _:PLR_DATA {
	bool:PLR_SIGNED,
	PLR_SIGN_TIME,
	PLR_TEAM,
	bool:PLR_ASSIGNED
};

new SIGNUP_STATE:g_eState = STATE_IDLE;
new g_ePlayers[MAX_PLAYERS + 1][PLR_DATA];
new g_iSignedCount;
new g_iSignupRemaining;
new g_iSignupTime = 60;
new g_iTeamSize = 3;
new g_iTotalPlayers;
new g_iHudSync;

new g_eMaps[MAX_MAPS][MAP_DATA];
new g_iMapCount;

new g_iVoteModeCount[MODE_COUNT];
new SIGNUP_MODE:g_iChosenMode;
new g_iVoteCount;
new g_szChosenMap[MAX_MAP_NAME];

new g_szRecoveryMode[16];
new bool:g_bRecoveryPending;

// ★ 报名玩家列表 (换图恢复)
new g_szSignupPlayers[MAX_PLAYERS + 1][35];
new g_iSignupPlayerCount;
new g_szTeamAPlayers[MAX_PLAYERS + 1][35];
new g_szTeamBPlayers[MAX_PLAYERS + 1][35];

// ★ 穿透模式
new bool:g_bPenetrationMode = false;
new g_szDefaultMdl_T[64] = "";
new g_szDefaultMdl_CT[64] = "";
new g_szPenMdl_T[64] = "";
new g_szPenMdl_CT[64] = "";

new g_pSignupTime;
new g_pAutoSignup;
new g_pMinPlayers;
new g_pPenMdlT;
new g_pPenMdlCT;
new g_iMenuMain;
new g_iMenuVote;

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

	g_pSignupTime = register_cvar("ais_signup_time", "60");
	g_pAutoSignup = register_cvar("ais_auto_signup", "0");
	g_pMinPlayers = register_cvar("ais_min_players", "2");
	g_pPenMdlT = register_cvar("ais_penetration_mdl_t", "");
	g_pPenMdlCT = register_cvar("ais_penetration_mdl_ct", "");
	bind_pcvar_string(g_pPenMdlT, g_szPenMdl_T, charsmax(g_szPenMdl_T));
	bind_pcvar_string(g_pPenMdlCT, g_szPenMdl_CT, charsmax(g_szPenMdl_CT));

	RegisterSayCmd("join", "ais_join", "cmdJoin");
	RegisterSayCmd("ai", "ais_menu", "cmdMenu");
	RegisterSayCmd("quit", "ais_quit", "cmdQuit");
	RegisterSayCmd("re", "ais_re", "cmdRe");
	RegisterSayCmd("teams", "ais_teams", "cmdTeams");
	RegAdminCmd("ais_forcestart", "cmdForceStart", ADMIN_CFG);

	g_iMenuMain = register_menuid("AIS_MainMenu");
	g_iMenuVote = register_menuid("AIS_VoteMenu");
	register_menucmd(g_iMenuMain, 1023, "handleMainMenu");
	register_menucmd(g_iMenuVote, 1023, "handleVoteMenu");

	g_iHudSync = CreateHudSyncObj();
	loadMaps();
	checkRecovery();
}

public hns_match_finished(iWinTeam) {
	if (g_eState == STATE_KNIFE_PENDING || g_eState == STATE_KNIFE_ACTIVE) {
		server_print("[AI报名] 拼刀结束，进入模式投票...");
		client_print(0, print_chat, "[AI报名] 拼刀结束！投票选择比赛模式。");
		set_task(1.0, "startModeVote");
	}
}

public hns_match_started() {
	if (g_eState == STATE_KNIFE_PENDING) {
		g_eState = STATE_KNIFE_ACTIVE;
		client_print(0, print_chat, "[AI报名] 拼刀开始！%dv%d 战斗！", g_iTeamSize, g_iTeamSize);
	}
}

loadMaps() {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/hns-maps.ini");

	new f = fopen(szPath, "r");
	if (!f) return;

	new szLine[256], szSection[32];
	new bool:bInMaps = false;
	g_iMapCount = 0;

	while (!feof(f) && g_iMapCount < MAX_MAPS && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') continue;
		if (szLine[0] == '[') {
			new iEnd = strlen(szLine) - 1;
			if (szLine[iEnd] == ']') szLine[iEnd] = '^0';
			copy(szSection, charsmax(szSection), szLine[1]);
			bInMaps = equali(szSection, "maps") || equali(szSection, "skill") || equali(szSection, "boost");
			continue;
		}
		if (bInMaps) {
			new szName[MAX_MAP_NAME];
			parse(szLine, szName, charsmax(szName));
			if (szName[0] != '^0') {
				copy(g_eMaps[g_iMapCount][MD_NAME], MAX_MAP_NAME, szName);
				g_eMaps[g_iMapCount][MD_TYPE] = MAP_SKILL;
				g_iMapCount++;
			}
		}
	}
	fclose(f);
	server_print("[AI报名] 加载了 %d 张地图", g_iMapCount);
}

// ==================== 报名 ====================
public cmdJoin(id) {
	if (g_eState == STATE_LOCKED) {
		client_print(id, print_chat, "[AI报名] 比赛进行中，无法报名。");
		return PLUGIN_HANDLED;
	}
	if (g_eState == STATE_KNIFE_ACTIVE || g_eState == STATE_KNIFE_PENDING) {
		client_print(id, print_chat, "[AI报名] 拼刀进行中，无法报名。");
		return PLUGIN_HANDLED;
	}
	if (g_eState == STATE_VOTE_MODE || g_eState == STATE_FINAL) {
		client_print(id, print_chat, "[AI报名] 投票进行中，无法报名。");
		return PLUGIN_HANDLED;
	}

	if (g_ePlayers[id][PLR_SIGNED]) {
		g_ePlayers[id][PLR_SIGNED] = false;
		g_iSignedCount--;
		new szName[32]; get_user_name(id, szName, charsmax(szName));
		client_print(0, print_chat, "[AI报名] %s 取消了报名。(已报名: %d人)", szName, g_iSignedCount);
		if (g_iSignedCount <= 0 && g_eState == STATE_SIGNUP) cancelSignup();
		return PLUGIN_HANDLED;
	}

	if (g_eState == STATE_IDLE) startSignup();

	g_ePlayers[id][PLR_SIGNED] = true;
	g_ePlayers[id][PLR_SIGN_TIME] = get_systime();
	g_iSignedCount++;

	new szName[32]; get_user_name(id, szName, charsmax(szName));
	client_print(0, print_chat, "[AI报名] %s 报名了！(报名:%d)", szName, g_iSignedCount);
	checkFull();
	return PLUGIN_HANDLED;
}

public cmdQuit(id) {
	if (g_eState != STATE_SIGNUP) return PLUGIN_HANDLED;
	if (g_ePlayers[id][PLR_SIGNED]) {
		g_ePlayers[id][PLR_SIGNED] = false;
		g_iSignedCount--;
		new szName[32]; get_user_name(id, szName, charsmax(szName));
		client_print(0, print_chat, "[AI报名] %s 退出了报名。(已报名: %d人)", szName, g_iSignedCount);
		if (g_iSignedCount <= 0) cancelSignup();
	}
	return PLUGIN_HANDLED;
}

startSignup() {
	g_eState = STATE_SIGNUP;
	g_iSignedCount = 0;
	g_iSignupTime = get_pcvar_num(g_pSignupTime);
	g_iSignupRemaining = g_iSignupTime;
	g_iSignupPlayerCount = 0;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		g_ePlayers[i][PLR_SIGNED] = false;
		g_ePlayers[i][PLR_SIGN_TIME] = 0;
		g_ePlayers[i][PLR_ASSIGNED] = false;
		g_ePlayers[i][PLR_TEAM] = 0;
	}

	arrayset(g_iVoteModeCount, 0, sizeof(g_iVoteModeCount));
	g_iChosenMode = MODE_MR;
	g_iVoteCount = 0;
	g_szChosenMap[0] = '^0';

	if (g_bPenetrationMode) togglePenetration(false);

	client_print(0, print_chat, "[AI报名] 报名开始！输入 ^3/join^1 报名。(%d秒)", g_iSignupTime);

	remove_task(TASK_SIGNUP_COUNTDOWN);
	remove_task(TASK_SIGNUP_TIMEOUT);
	set_task(1.0, "taskSignupCountdown", TASK_SIGNUP_COUNTDOWN, _, _, "b");
	set_task(float(g_iSignupTime), "taskSignupTimeout", TASK_SIGNUP_TIMEOUT);
}

cancelSignup() {
	g_eState = STATE_IDLE;
	g_iSignedCount = 0;
	remove_task(TASK_SIGNUP_COUNTDOWN);
	remove_task(TASK_SIGNUP_TIMEOUT);
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		g_ePlayers[i][PLR_SIGNED] = false;
		g_ePlayers[i][PLR_SIGN_TIME] = 0;
		g_ePlayers[i][PLR_ASSIGNED] = false;
		g_ePlayers[i][PLR_TEAM] = 0;
	}
	client_print(0, print_chat, "[AI报名] 报名已取消。");
}

checkFull() {
	if (g_iSignedCount >= getMaxPlayers()) {
		client_print(0, print_chat, "[AI报名] 报名已满！立即分组...");
		remove_task(TASK_SIGNUP_TIMEOUT);
		set_task(0.5, "taskSignupTimeout", TASK_SIGNUP_TIMEOUT);
	}
}

getMaxPlayers() { return g_iTeamSize * 2; }

getOnlineCount() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	return iNum;
}

// ==================== 倒计时 & HUD ====================
public taskSignupCountdown() {
	g_iSignupRemaining--;
	set_hudmessage(255, 255, 0, -1.0, 0.12, 0, 0.0, 1.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iHudSync,
		"AI报名系统^n已报名: %d人 | 需要: %d人^n剩余: %d秒 | 输入 /join 报名",
		g_iSignedCount, getMaxPlayers(), g_iSignupRemaining);

	if (g_iSignupRemaining <= 10 && g_iSignupRemaining > 0) {
		client_print(0, print_chat, "[AI报名] 最后 %d 秒！已报名: %d/%d", g_iSignupRemaining, g_iSignedCount, getMaxPlayers());
	}
	if (g_iSignupRemaining <= 0) remove_task(TASK_SIGNUP_COUNTDOWN);
}

public taskSignupTimeout() {
	if (g_eState != STATE_SIGNUP) return;
	remove_task(TASK_SIGNUP_COUNTDOWN);

	if (g_iSignedCount < get_pcvar_num(g_pMinPlayers)) {
		client_print(0, print_chat, "[AI报名] 人数不足 (需要至少%d人，当前%d人)，报名取消。", get_pcvar_num(g_pMinPlayers), g_iSignedCount);
		cancelSignup();
		return;
	}

	g_iTotalPlayers = g_iSignedCount;
	if (g_iTotalPlayers > getMaxPlayers()) g_iTotalPlayers = getMaxPlayers();
	if (g_iTotalPlayers % 2 != 0) g_iTotalPlayers--;
	g_iTeamSize = g_iTotalPlayers / 2;

	client_print(0, print_chat, "[AI报名] 报名结束！%d人参加，%dv%d", g_iTotalPlayers, g_iTeamSize, g_iTeamSize);

	// ★ 分配阵营并显示
	showTeamsAssignment();

	startKnifePhase();
}

// ==================== 阵营分配 ====================
showTeamsAssignment() {
	new szSignedIds[MAX_PLAYERS];
	new iSignedCount = 0;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (g_ePlayers[i][PLR_SIGNED]) {
			szSignedIds[iSignedCount++] = i;
		}
	}
	if (iSignedCount < 2) return;

	// 按报名时间排序
	for (new i = 0; i < iSignedCount - 1; i++) {
		for (new j = i + 1; j < iSignedCount; j++) {
			if (g_ePlayers[szSignedIds[j]][PLR_SIGN_TIME] < g_ePlayers[szSignedIds[i]][PLR_SIGN_TIME]) {
				new tmp = szSignedIds[i];
				szSignedIds[i] = szSignedIds[j];
				szSignedIds[j] = tmp;
			}
		}
	}

	g_iSignupPlayerCount = 0;
	new bool:bFlip = false;

	for (new i = 0; i < iSignedCount; i++) {
		new id = szSignedIds[i];
		new szAuth[35], szName[32], szIP[16];
		get_user_authid(id, szAuth, charsmax(szAuth));

		if (equal(szAuth, "") || equal(szAuth, "STEAM_ID_PENDING")) {
			get_user_ip(id, szIP, charsmax(szIP), 1);
			get_user_name(id, szName, charsmax(szName));
			formatex(szAuth, charsmax(szAuth), "%s_%s", szIP, szName);
		}

		copy(g_szSignupPlayers[g_iSignupPlayerCount], 34, szAuth);

		if (bFlip) {
			if ((i % 2) == 0) {
				g_ePlayers[id][PLR_TEAM] = 2;
				copy(g_szTeamBPlayers[g_iSignupPlayerCount], 34, szAuth);
			} else {
				g_ePlayers[id][PLR_TEAM] = 1;
				copy(g_szTeamAPlayers[g_iSignupPlayerCount], 34, szAuth);
			}
		} else {
			if ((i % 2) == 0) {
				g_ePlayers[id][PLR_TEAM] = 1;
				copy(g_szTeamAPlayers[g_iSignupPlayerCount], 34, szAuth);
			} else {
				g_ePlayers[id][PLR_TEAM] = 2;
				copy(g_szTeamBPlayers[g_iSignupPlayerCount], 34, szAuth);
			}
		}

		g_ePlayers[id][PLR_ASSIGNED] = true;
		g_iSignupPlayerCount++;
		if ((i + 1) % 2 == 0) bFlip = !bFlip;
	}

	// ★ HUD 显示阵营
	new szHud[1024], len;
	len = formatex(szHud, charsmax(szHud), "=== 阵营分配 ===^n%dv%d^n^n", g_iTeamSize, g_iTeamSize);

	len += formatex(szHud[len], charsmax(szHud) - len, "[T队]^n");
	for (new i = 0; i < iSignedCount; i++) {
		new id = szSignedIds[i];
		if (g_ePlayers[id][PLR_TEAM] == 1) {
			get_user_name(id, szName, charsmax(szName));
			len += formatex(szHud[len], charsmax(szHud) - len, "  %s^n", szName);
		}
	}

	len += formatex(szHud[len], charsmax(szHud) - len, "^n[CT队]^n");
	for (new i = 0; i < iSignedCount; i++) {
		new id = szSignedIds[i];
		if (g_ePlayers[id][PLR_TEAM] == 2) {
			get_user_name(id, szName, charsmax(szName));
			len += formatex(szHud[len], charsmax(szHud) - len, "  %s^n", szName);
		}
	}

	set_hudmessage(0, 255, 255, -1.0, 0.1, 0, 0.0, 10.0, 0.1, 0.2);
	ShowSyncHudMsg(0, g_iHudSync, szHud);

	// Chat 显示
	client_print(0, print_chat, "[AI报名] ========== 阵营分配 ==========");
	new szMsg[256];
	formatex(szMsg, charsmax(szMsg), "[T队]:");
	for (new i = 0; i < iSignedCount; i++) {
		new id = szSignedIds[i];
		if (g_ePlayers[id][PLR_TEAM] == 1) {
			get_user_name(id, szName, charsmax(szName));
			add(szMsg, charsmax(szMsg), " ");
			add(szMsg, charsmax(szMsg), szName);
		}
	}
	client_print(0, print_chat, szMsg);

	formatex(szMsg, charsmax(szMsg), "[CT队]:");
	for (new i = 0; i < iSignedCount; i++) {
		new id = szSignedIds[i];
		if (g_ePlayers[id][PLR_TEAM] == 2) {
			get_user_name(id, szName, charsmax(szName));
			add(szMsg, charsmax(szMsg), " ");
			add(szMsg, charsmax(szMsg), szName);
		}
	}
	client_print(0, print_chat, szMsg);
}

// ★ /teams 命令
public cmdTeams(id) {
	if (g_eState != STATE_SIGNUP && g_eState != STATE_KNIFE_PENDING && g_eState != STATE_KNIFE_ACTIVE) {
		client_print(id, print_chat, "[AI报名] 当前没有进行中的报名。");
		return PLUGIN_HANDLED;
	}

	new szHud[512], szName[32], len;
	len = formatex(szHud, charsmax(szHud), "=== 阵营分配 ===^n%dv%d^n^n", g_iTeamSize, g_iTeamSize);

	len += formatex(szHud[len], charsmax(szHud) - len, "[T队]^n");
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (g_ePlayers[i][PLR_SIGNED] && g_ePlayers[i][PLR_TEAM] == 1) {
			get_user_name(i, szName, charsmax(szName));
			len += formatex(szHud[len], charsmax(szHud) - len, "  %s^n", szName);
		}
	}
	len += formatex(szHud[len], charsmax(szHud) - len, "^n[CT队]^n");
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (g_ePlayers[i][PLR_SIGNED] && g_ePlayers[i][PLR_TEAM] == 2) {
			get_user_name(i, szName, charsmax(szName));
			len += formatex(szHud[len], charsmax(szHud) - len, "  %s^n", szName);
		}
	}

	set_hudmessage(0, 255, 255, -1.0, 0.1, 0, 0.0, 8.0, 0.1, 0.2);
	ShowSyncHudMsg(id, g_iHudSync, szHud);
	return PLUGIN_HANDLED;
}

// ==================== 拼刀阶段 ====================
startKnifePhase() {
	g_eState = STATE_KNIFE_PENDING;
	new szKnifeMap[MAX_MAP_NAME];
	getRandomKnifeMap(szKnifeMap, charsmax(szKnifeMap));

	get_mode_name_str(MODE_MR, g_szRecoveryMode, charsmax(g_szRecoveryMode));
	g_bRecoveryPending = true;
	saveRecoveryState();

	client_print(0, print_chat, "[AI报名] 即将切换到拼刀地图: %s", szKnifeMap);
	server_cmd("changelevel %s", szKnifeMap);
}

getRandomKnifeMap(szOut[], iLen) {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/hns-maps.ini");

	new f = fopen(szPath, "r");
	if (!f) { copy(szOut, iLen, "35hp_knife_v2"); return; }

	new szLine[256], szKnifeMaps[MAX_MAPS][MAX_MAP_NAME];
	new iKnifeCount = 0;
	new bool:bKnife = false;

	while (!feof(f) && iKnifeCount < MAX_MAPS && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') continue;
		if (szLine[0] == '[') {
			new szSec[32], iEnd = strlen(szLine) - 1;
			if (szLine[iEnd] == ']') szLine[iEnd] = '^0';
			copy(szSec, charsmax(szSec), szLine[1]);
			bKnife = equali(szSec, "knife");
			continue;
		}
		if (bKnife) {
			new szName[MAX_MAP_NAME];
			parse(szLine, szName, charsmax(szName));
			if (szName[0] != '^0') {
				copy(szKnifeMaps[iKnifeCount], MAX_MAP_NAME, szName);
				iKnifeCount++;
			}
		}
	}
	fclose(f);

	if (iKnifeCount > 0) copy(szOut, iLen, szKnifeMaps[random(iKnifeCount)]);
	else copy(szOut, iLen, "35hp_knife_v2");
}

// ==================== 换图后恢复 (核心修复) ====================
checkRecovery() {
	new szPath[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/ais_recovery.txt");

	if (!file_exists(szPath)) return;

	new f = fopen(szPath, "r");
	if (!f) return;

	new szLine[256];
	new szTmpPlayers[MAX_PLAYERS + 1][35];
	new szTmpTeamA[MAX_PLAYERS + 1][35];
	new szTmpTeamB[MAX_PLAYERS + 1][35];
	new iTmpPlayerCount = 0;
	new iState = -1;

	while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		if (szLine[0] == '^0') continue;

		new szKey[32], szVal[64];
		parse(szLine, szKey, charsmax(szKey), szVal, charsmax(szVal));

		if (equal(szKey, "state")) {
			iState = str_to_num(szVal);
			if (iState == STATE_KNIFE_PENDING) g_bRecoveryPending = true;
		}
		if (equal(szKey, "team_size")) g_iTeamSize = str_to_num(szVal);
		if (equal(szKey, "total_players")) g_iTotalPlayers = str_to_num(szVal);
		if (equal(szKey, "player") && iTmpPlayerCount < MAX_PLAYERS) {
			copy(szTmpPlayers[iTmpPlayerCount], 34, szVal);
			iTmpPlayerCount++;
		}
		if (equal(szKey, "teama") && iTmpPlayerCount < MAX_PLAYERS) {
			copy(szTmpTeamA[iTmpPlayerCount], 34, szVal);
		}
		if (equal(szKey, "teamb") && iTmpPlayerCount < MAX_PLAYERS) {
			copy(szTmpTeamB[iTmpPlayerCount], 34, szVal);
		}
	}
	fclose(f);
	delete_file(szPath);

	if (g_bRecoveryPending) {
		// 恢复玩家列表
		g_iSignupPlayerCount = iTmpPlayerCount;
		for (new i = 0; i < iTmpPlayerCount; i++) {
			copy(g_szSignupPlayers[i], 34, szTmpPlayers[i]);
			copy(g_szTeamAPlayers[i], 34, szTmpTeamA[i]);
			copy(g_szTeamBPlayers[i], 34, szTmpTeamB[i]);
		}

		g_iSignedCount = g_iTotalPlayers;
		g_eState = STATE_KNIFE_PENDING;

		server_print("[AI报名] 拼刀地图恢复，已保存 %d 个报名玩家，等待连接...", iTmpPlayerCount);
		client_print(0, print_chat, "[AI报名] %dv%d 拼刀选人！等待玩家连接...", g_iTeamSize, g_iTeamSize);

		// ★ 延迟分配阵营，等待玩家连接
		remove_task(TASK_TEAM_ASSIGN);
		remove_task(TASK_INFO_HUD);
		set_task(5.0, "taskTeamAssign", TASK_TEAM_ASSIGN);
		set_task(1.0, "taskTeamAssignCheck", TASK_TEAM_ASSIGN, _, _, "b");
	}
}

// ★ 等待玩家连接
public taskTeamAssignCheck() {
	if (g_eState != STATE_KNIFE_PENDING || !g_bRecoveryPending) {
		remove_task(TASK_TEAM_ASSIGN);
		return;
	}

	new iConnected = 0;
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i)) continue;
		new szAuth[35];
		get_user_authid(i, szAuth, charsmax(szAuth));
		if (equal(szAuth, "") || equal(szAuth, "STEAM_ID_PENDING")) {
			new szIP[16], szName[32];
			get_user_ip(i, szIP, charsmax(szIP), 1);
			get_user_name(i, szName, charsmax(szName));
			formatex(szAuth, charsmax(szAuth), "%s_%s", szIP, szName);
		}
		for (new j = 0; j < g_iSignupPlayerCount; j++) {
			if (equal(szAuth, g_szSignupPlayers[j])) { iConnected++; break; }
		}
	}

	if (iConnected >= g_iTotalPlayers) {
		remove_task(TASK_TEAM_ASSIGN);
		taskTeamAssign();
	}
}

// ★ 核心修复: 分配阵营
public taskTeamAssign() {
	if (g_eState != STATE_KNIFE_PENDING || !g_bRecoveryPending) return;
	g_bRecoveryPending = false;

	new iAssigned = 0;
	new szName[32];

	client_print(0, print_chat, "[AI报名] 正在分配阵营...");

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i)) continue;

		new szAuth[35];
		get_user_authid(i, szAuth, charsmax(szAuth));
		if (equal(szAuth, "") || equal(szAuth, "STEAM_ID_PENDING")) {
			new szIP[16], szN[32];
			get_user_ip(i, szIP, charsmax(szIP), 1);
			get_user_name(i, szN, charsmax(szN));
			formatex(szAuth, charsmax(szAuth), "%s_%s", szIP, szN);
		}

		new iTeam = 0;
		new bool:bFound = false;
		for (new j = 0; j < g_iSignupPlayerCount && !bFound; j++) {
			if (equal(szAuth, g_szSignupPlayers[j])) {
				// 查找是 A队还是 B队
				for (new k = 0; k < g_iSignupPlayerCount; k++) {
					if (equal(szAuth, g_szTeamAPlayers[k])) { iTeam = 1; bFound = true; break; }
					if (equal(szAuth, g_szTeamBPlayers[k])) { iTeam = 2; bFound = true; break; }
				}
			}
		}

		if (iTeam == 1) {
			rg_set_user_team(i, TEAM_TERRORIST, MODEL_AUTO);
			get_user_name(i, szName, charsmax(szName));
			server_print("[AI报名] %s -> T (A队)", szName);
			iAssigned++;
		} else if (iTeam == 2) {
			rg_set_user_team(i, TEAM_CT, MODEL_AUTO);
			get_user_name(i, szName, charsmax(szName));
			server_print("[AI报名] %s -> CT (B队)", szName);
			iAssigned++;
		} else {
			// 不在名单中 → 观战
			if (get_user_team(i) != TEAM_SPECTATOR) {
				rg_set_user_team(i, TEAM_SPECTATOR, MODEL_AUTO);
			}
			get_user_name(i, szName, charsmax(szName));
			server_print("[AI报名] %s -> SPECTATOR (未报名)", szName);
		}
	}

	client_print(0, print_chat, "[AI报名] 阵营分配完成！已分配 %d/%d 人。输入 /knife 开始拼刀", iAssigned, g_iTotalPlayers);

	set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 5.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iHudSync, "阵营已分配^n%dv%d^n输入 /knife 开始拼刀", g_iTeamSize, g_iTeamSize);

	// 持续显示阵营 HUD
	remove_task(TASK_INFO_HUD);
	set_task(2.0, "taskShowInfoHud", TASK_INFO_HUD, _, _, "b");
}

// ★ 阵营信息 HUD
public taskShowInfoHud() {
	if (g_eState != STATE_KNIFE_PENDING && g_eState != STATE_KNIFE_ACTIVE) {
		remove_task(TASK_INFO_HUD);
		return;
	}

	new szHud[512], szName[32], len;
	len = formatex(szHud, charsmax(szHud), "AI报名 %dv%d^n", g_iTeamSize, g_iTeamSize);

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i)) continue;
		if (get_user_team(i) == TEAM_TERRORIST) {
			get_user_name(i, szName, charsmax(szName));
			len += formatex(szHud[len], charsmax(szHud) - len, "[T] %s^n", szName);
		}
	}
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i)) continue;
		if (get_user_team(i) == TEAM_CT) {
			get_user_name(i, szName, charsmax(szName));
			len += formatex(szHud[len], charsmax(szHud) - len, "[CT] %s^n", szName);
		}
	}

	set_hudmessage(0, 255, 200, 0.02, 0.15, 0, 0.0, 2.0, 0.0, 0.1);
	ShowSyncHudMsg(0, g_iHudSync, szHud);
}

saveRecoveryState() {
	new szPath[128], szDir[128];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/mixsystem/ais_recovery.txt");
	get_configsdir(szDir, charsmax(szDir));
	format(szDir, charsmax(szDir), "%s/mixsystem", szDir);
	if (!dir_exists(szDir)) mkdir(szDir);

	new f = fopen(szPath, "wt");
	if (f) {
		fprintf(f, "state %d^n", _:g_eState);
		fprintf(f, "team_size %d^n", g_iTeamSize);
		fprintf(f, "total_players %d^n", g_iTotalPlayers);
		// ★ 保存报名玩家和阵营
		for (new i = 0; i < g_iSignupPlayerCount; i++) {
			fprintf(f, "player %s^n", g_szSignupPlayers[i]);
		}
		for (new i = 0; i < g_iSignupPlayerCount; i++) {
			if (g_szTeamAPlayers[i][0] != '^0')
				fprintf(f, "teama %s^n", g_szTeamAPlayers[i]);
		}
		for (new i = 0; i < g_iSignupPlayerCount; i++) {
			if (g_szTeamBPlayers[i][0] != '^0')
				fprintf(f, "teamb %s^n", g_szTeamBPlayers[i]);
		}
		fclose(f);
	}
}

// ==================== 穿透模式 /re ====================
public cmdRe(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	if (g_bPenetrationMode) {
		togglePenetration(false);
		client_print(id, print_chat, "[AI报名] 穿透模式已关闭");
	} else {
		if (g_szPenMdl_T[0] != '^0' || g_szPenMdl_CT[0] != '^0') {
			togglePenetration(true);
			client_print(id, print_chat, "[AI报名] 穿透模式已开启");
		} else {
			client_print(id, print_chat, "[AI报名] 未配置穿透模型！设置 ais_penetration_mdl_t 和 ais_penetration_mdl_ct");
		}
	}
	return PLUGIN_HANDLED;
}

togglePenetration(bool:bEnable) {
	g_bPenetrationMode = bEnable;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_alive(i)) continue;
		new iTeam = get_user_team(i);
		if (bEnable) {
			if (iTeam == TEAM_TERRORIST && g_szPenMdl_T[0] != '^0') {
				if (g_szDefaultMdl_T[0] == '^0') {
					get_entvar(i, var_model, g_szDefaultMdl_T, charsmax(g_szDefaultMdl_T));
				}
				set_entvar(i, var_model, g_szPenMdl_T);
			} else if (iTeam == TEAM_CT && g_szPenMdl_CT[0] != '^0') {
				if (g_szDefaultMdl_CT[0] == '^0') {
					get_entvar(i, var_model, g_szDefaultMdl_CT, charsmax(g_szDefaultMdl_CT));
				}
				set_entvar(i, var_model, g_szPenMdl_CT);
			}
			set_entvar(i, var_renderamt, 100.0);
		} else {
			if (iTeam == TEAM_TERRORIST && g_szDefaultMdl_T[0] != '^0') {
				set_entvar(i, var_model, g_szDefaultMdl_T);
			} else if (iTeam == TEAM_CT && g_szDefaultMdl_CT[0] != '^0') {
				set_entvar(i, var_model, g_szDefaultMdl_CT);
			}
			set_entvar(i, var_renderamt, 255.0);
		}
	}

	if (!bEnable) {
		g_szDefaultMdl_T[0] = '^0';
		g_szDefaultMdl_CT[0] = '^0';
	}
}

// ==================== 模式投票 ====================
startModeVote() {
	g_eState = STATE_VOTE_MODE;
	g_iVoteCount = 0;
	arrayset(g_iVoteModeCount, 0, sizeof(g_iVoteModeCount));

	client_print(0, print_chat, "[AI报名] 投票选择比赛模式！输入 /ai 打开投票菜单");

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (is_user_connected(i)) showVoteMenu(i);
	}

	remove_task(TASK_VOTE_TIMEOUT);
	set_task(15.0, "taskVoteTimeout", TASK_VOTE_TIMEOUT);
}

showVoteMenu(id) {
	new szMenu[512], len;
	len  = formatex(szMenu, charsmax(szMenu), "\r选择比赛模式^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r参赛人数: %dv%d^n^n", g_iTeamSize, g_iTeamSize);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w MR^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w 计时^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3.\w 点位积分^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4.\w 吸血^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5.\w 回合制^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 退出");
	show_menu(id, g_iMenuVote, szMenu, -1, "AIS_VoteMenu");
}

public handleVoteMenu(id, key) {
	if (g_eState != STATE_VOTE_MODE) return PLUGIN_HANDLED;
	if (key < 0 || key >= MODE_COUNT) return PLUGIN_HANDLED;

	g_iVoteModeCount[key]++;
	g_iVoteCount++;

	new szModes[MODE_COUNT][32] = { "MR", "计时", "点位积分", "吸血", "回合制" };
	new szName[32]; get_user_name(id, szName, charsmax(szName));
	client_print(0, print_chat, "[AI投票] %s 投了 %s", szName, szModes[key]);

	showVoteHUD();
	checkVoteEnd();
	return PLUGIN_HANDLED;
}

showVoteHUD() {
	new szModes[MODE_COUNT][32] = { "MR", "计时", "点位积分", "吸血", "回合制" };
	new szHud[512], len;
	len = formatex(szHud, charsmax(szHud), "模式投票 (%d票)^n^n", g_iVoteCount);
	for (new i = 0; i < MODE_COUNT; i++) {
		len += formatex(szHud[len], charsmax(szHud) - len, "%d. %s: %d票^n", i + 1, szModes[i], g_iVoteModeCount[i]);
	}
	set_hudmessage(255, 255, 255, -1.0, 0.2, 0, 0.0, 3.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iHudSync, szHud);
}

checkVoteEnd() {
	if (g_iVoteCount >= g_iTotalPlayers) {
		remove_task(TASK_VOTE_TIMEOUT);
		set_task(0.5, "taskVoteTimeout", TASK_VOTE_TIMEOUT);
	}
}

public taskVoteTimeout() {
	if (g_eState != STATE_VOTE_MODE) return;

	new iBest = 0;
	for (new i = 1; i < MODE_COUNT; i++) {
		if (g_iVoteModeCount[i] > g_iVoteModeCount[iBest]) iBest = i;
	}

	g_iChosenMode = SIGNUP_MODE:iBest;
	new szModes[MODE_COUNT][32] = { "MR", "计时", "点位积分", "吸血", "回合制" };
	client_print(0, print_chat, "[AI报名] 投票结束！模式: %s (%d票)", szModes[iBest], g_iVoteModeCount[iBest]);

	selectRandomMap();
	showFinalResult();
}

selectRandomMap() {
	new bool:bUseSkill = (g_iChosenMode == MODE_MR || g_iChosenMode == MODE_TIMER);

	new iPool[MAX_MAPS], iPoolCount;
	for (new i = 0; i < g_iMapCount; i++) {
		if (bUseSkill) {
			iPool[iPoolCount++] = i;
		} else {
			if (g_eMaps[i][MD_TYPE] == MAP_BOOST) iPool[iPoolCount++] = i;
		}
	}

	if (iPoolCount > 0) copy(g_szChosenMap, charsmax(g_szChosenMap), g_eMaps[iPool[random(iPoolCount)]][MD_NAME]);
	else get_mapname(g_szChosenMap, charsmax(g_szChosenMap));
}

showFinalResult() {
	g_eState = STATE_FINAL;
	new szModes[MODE_COUNT][32] = { "MR", "计时", "点位积分", "吸血", "回合制" };

	client_print(0, print_chat, "[AI报名] ========== 最终设置 ==========");
	client_print(0, print_chat, "[AI报名] 参赛人数: %d (%dv%d)", g_iTotalPlayers, g_iTeamSize, g_iTeamSize);
	client_print(0, print_chat, "[AI报名] 模式: %s", szModes[g_iChosenMode]);
	client_print(0, print_chat, "[AI报名] 地图: %s", g_szChosenMap);
	client_print(0, print_chat, "[AI报名] 3秒后自动开始...");

	set_hudmessage(0, 255, 0, -1.0, 0.2, 0, 0.0, 5.0, 0.0, 0.0);
	ShowSyncHudMsg(0, g_iHudSync, "比赛即将开始^n%dv%d | %s | %s^n3秒后自动启动...",
		g_iTeamSize, g_iTeamSize, szModes[g_iChosenMode], g_szChosenMap);

	remove_task(TASK_START_MATCH);
	set_task(3.0, "taskStartMatch", TASK_START_MATCH);
}

public taskStartMatch() {
	if (g_eState != STATE_FINAL) return;
	g_eState = STATE_LOCKED;

	if (g_bPenetrationMode) togglePenetration(false);

	new szModeName[16];
	get_mode_name_for_config(g_iChosenMode, szModeName, charsmax(szModeName));

	new szCfg[256];
	get_configsdir(szCfg, charsmax(szCfg));
	add(szCfg, charsmax(szCfg), "/hns_ai_match_start.cfg");

	new f = fopen(szCfg, "wt");
	if (f) {
		fprintf(f, "hns_match_mode %s^n", szModeName);
		fprintf(f, "hns_auto_start 1^n");
		fclose(f);
	}

	new szCurMap[64];
	get_mapname(szCurMap, charsmax(szCurMap));

	if (equali(szCurMap, g_szChosenMap)) {
		client_print(0, print_chat, "[AI报名] 目标地图与当前相同，直接启动！");
		server_cmd("hns_match_mode %s", szModeName);
		server_cmd("hns_auto_start 1");
	} else {
		client_print(0, print_chat, "[AI报名] 正在切换到 %s...", g_szChosenMap);
		server_cmd("changelevel %s", g_szChosenMap);
	}
}

// ==================== 菜单 ====================
public cmdMenu(id) {
	if (!isUserAdmin(id) && !isUserWatcher(id)) {
		showVoteMenu(id);
		return PLUGIN_HANDLED;
	}
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

showMainMenu(id) {
	new szState[32];
	switch (g_eState) {
		case STATE_IDLE:         copy(szState, charsmax(szState), "\d空闲");
		case STATE_SIGNUP:       copy(szState, charsmax(szState), "\y报名中");
		case STATE_KNIFE_PENDING: copy(szState, charsmax(szState), "\y拼刀待命");
		case STATE_KNIFE_ACTIVE: copy(szState, charsmax(szState), "\r拼刀中");
		case STATE_VOTE_MODE:    copy(szState, charsmax(szState), "\y投票中");
		case STATE_FINAL:        copy(szState, charsmax(szState), "\g准备开始");
		case STATE_LOCKED:       copy(szState, charsmax(szState), "\r比赛中");
	}

	new szMenu[512], len;
	len  = formatex(szMenu, charsmax(szMenu), "\rAI报名系统 v2.0^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r状态: %s^n", szState);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r已报名: %d/%d^n^n", g_iSignedCount, getMaxPlayers());
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w 开始报名^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w 强制开始^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3.\w 取消报名^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4.\w 设置人数 (%dv%d)^n", g_iTeamSize, g_iTeamSize);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5.\w 穿透 %s^n", g_bPenetrationMode ? "\y[开]" : "\d[关]");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6.\w 查看阵营^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r/join报名 /re穿透 /teams阵营^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 退出");
	show_menu(id, g_iMenuMain, szMenu, -1, "AIS_MainMenu");
}

public handleMainMenu(id, key) {
	if (!isUserAdmin(id) && !isUserWatcher(id)) return PLUGIN_HANDLED;
	switch (key) {
		case 0: {
			if (g_eState == STATE_LOCKED) { client_print(id, print_chat, "[AI报名] 比赛进行中。"); return PLUGIN_HANDLED; }
			if (g_eState == STATE_SIGNUP) { client_print(id, print_chat, "[AI报名] 已在报名中。"); return PLUGIN_HANDLED; }
			startSignup();
		}
		case 1: {
			if (g_eState == STATE_LOCKED) { client_print(id, print_chat, "[AI报名] 比赛进行中。"); return PLUGIN_HANDLED; }
			if (g_eState == STATE_SIGNUP) {
				remove_task(TASK_SIGNUP_TIMEOUT);
				set_task(0.3, "taskSignupTimeout", TASK_SIGNUP_TIMEOUT);
			} else {
				cmdForceStart(id, 0);
			}
		}
		case 2: cancelSignup();
		case 3: {
			g_iTeamSize++;
			if (g_iTeamSize > 10) g_iTeamSize = 2;
			client_print(0, print_chat, "[AI报名] 每队人数: %d (%dv%d)", g_iTeamSize, g_iTeamSize, g_iTeamSize);
		}
		case 4: cmdRe(id);
		case 5: cmdTeams(id);
	}
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

public cmdForceStart(id, level) {
	if (!cmd_access(id, level, 1)) return PLUGIN_HANDLED;
	if (g_eState == STATE_LOCKED) { client_print(id, print_chat, "[AI报名] 比赛进行中。"); return PLUGIN_HANDLED; }
	if (g_eState == STATE_SIGNUP) {
		remove_task(TASK_SIGNUP_TIMEOUT);
		set_task(0.3, "taskSignupTimeout", TASK_SIGNUP_TIMEOUT);
		return PLUGIN_HANDLED;
	}
	g_iTotalPlayers = getMaxPlayers();
	g_iTeamSize = g_iTotalPlayers / 2;
	startKnifePhase();
	return PLUGIN_HANDLED;
}

get_mode_name_str(SIGNUP_MODE:mode, szOut[], iLen) {
	switch (mode) {
		case MODE_MR:        copy(szOut, iLen, "mr");
		case MODE_TIMER:     copy(szOut, iLen, "timer");
		case MODE_POINTSCAP: copy(szOut, iLen, "ascension");
		case MODE_VAMP:      copy(szOut, iLen, "vampire");
		case MODE_ROUNDS:    copy(szOut, iLen, "rounds");
		default:             copy(szOut, iLen, "mr");
	}
}

get_mode_name_for_config(SIGNUP_MODE:mode, szOut[], iLen) {
	get_mode_name_str(mode, szOut, iLen);
}

public client_disconnected(id) {
	if (g_eState == STATE_SIGNUP && g_ePlayers[id][PLR_SIGNED]) {
		g_ePlayers[id][PLR_SIGNED] = false;
		g_iSignedCount--;
		if (g_iSignedCount <= 0) cancelSignup();
	}
}

public client_putinserver(id) {
	g_ePlayers[id][PLR_SIGNED] = false;
	g_ePlayers[id][PLR_SIGN_TIME] = 0;
	g_ePlayers[id][PLR_ASSIGNED] = false;
	g_ePlayers[id][PLR_TEAM] = 0;

	if (get_pcvar_num(g_pAutoSignup) && g_eState == STATE_SIGNUP) {
		if (!g_ePlayers[id][PLR_SIGNED]) {
			g_ePlayers[id][PLR_SIGNED] = true;
			g_ePlayers[id][PLR_SIGN_TIME] = get_systime();
			g_iSignedCount++;
			checkFull();
		}
	}
}

public hns_match_reset_round() {
	if (get_pcvar_num(g_pAutoSignup) && g_eState == STATE_IDLE) {
		new szCurMap[64]; get_mapname(szCurMap, charsmax(szCurMap));
		if (containi(szCurMap, "knife") == -1) set_task(2.0, "autoStartSignup");
	}
}

public autoStartSignup() {
	if (g_eState == STATE_IDLE) startSignup();
}
