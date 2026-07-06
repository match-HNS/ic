#if defined _globals_included
  #endinput
#endif

#define _globals_included

#define TASK_TIMER 54345
#define HUD_PAUSE 23931

#define TASK_WAIT 12319
#define TASK_WAIT_CUP 11331
#define TASK_STARTED 13339

#define TASK_WAITCAP 13131
#define TASK_WAITLEAVECAP 15151
#define TASK_RANDOMPICK 17171

#define TASK_SURRENDER 55566

new bool:g_bDebugMode;

new g_szCurrentPrefix[16];
new g_szBaseHostname[128];

stock update_hostname_prefix(const szPrefix[]) {
	new szHostname[128];
	get_cvar_string("hostname", szHostname, charsmax(szHostname));

	if (!g_szBaseHostname[0]) {
		copy(g_szBaseHostname, charsmax(g_szBaseHostname), szHostname);
	}

	new szOld[32];
	format(szOld, charsmax(szOld), "[%s] ", g_szCurrentPrefix);
	if (contain(szHostname, szOld) == 0) {
		new len = strlen(szOld);
		copy(szHostname, charsmax(szHostname), szHostname[len]);
	}

	if (szPrefix[0]) {
		new szNew[128];
		formatex(szNew, charsmax(szNew), "[%s] %s", szPrefix, szHostname);
		set_cvar_string("hostname", szNew);
	} else {
		set_cvar_string("hostname", szHostname);
	}

	copy(g_szCurrentPrefix, charsmax(g_szCurrentPrefix), szPrefix);
}

new g_iRegisterSpawn;
new const g_szDefaultEntities[][] = {
	"func_hostage_rescue",
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"armoury_entity",
	"monster_scentist"
}

new g_szLogPath[64];

new iBeam;
new g_sprBeam;

new g_PluginId;

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL,
	RULES_POINTSCAP,   // 点位积分制
	RULES_VAMP,        // 点位扣除制
	RULES_ROUNDS       // 回合制
}

new NATCH_RULES:g_iCurrentRules;

enum MATCH_STATUS {
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
	MATCH_CUPKNIFE,
	MATCH_CUPPICK,
	MATCH_TEAMKNIFE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}
new MATCH_STATUS:g_iMatchStatus;

enum MODE_STATES {
	STATE_DISABLED,
	STATE_PREPARE,
	STATE_PAUSED,
	STATE_ENABLED
}
new MODE_STATES:g_eMatchState;

enum HNS_TEAM {
	HNS_TEAM_B,
	HNS_TEAM_A
}

new HNS_TEAM:g_isTeamTT;

enum _:MATCH_INFO {
	e_mTeamSize,
	e_mTeamSizeTT,
	Float:e_mWintime,
	Float:e_flSidesTime[HNS_TEAM],
	e_iSidesRounds[HNS_TEAM],
	Trie:e_tLeaveData,
	bool:e_mLeaved
};

new g_eMatchInfo[MATCH_INFO];

enum _:SurrenderData_s {
	bool:e_sStarted,
	e_sInitiator,
	Float:e_sFlDelay,
	Float:e_sFlTime
};
new g_eSurrenderData[SurrenderData_s];

new bool:g_bNoplay[MAX_PLAYERS + 1];

new Float:g_flRoundTime;

new g_iPlayerDistance;
new g_iPointsDistance;

new g_szMapName[32]
new g_iHostageEnt;

// const
new const sndDenySelect[] = "common/wpn_denyselect.wav";
new const sndUseSound[] = "buttons/blip1.wav";

enum _: Forwards {
	MATCH_START,
	MATCH_RESET_ROUND,
	MATCH_FINISH,
	MATCH_FINISH_POST,
	MATCH_CANCEL,
	MATCH_LEAVE_PLAYER,
	MATCH_JOIN_PLAYER,
	HNS_ROUND_START,
	HNS_ROUND_END,
	HNS_ROUND_FREEZEEND
};

new g_hForwards[Forwards];

enum PLAYER_ROLES { 
	ROLE_SPEC = 0, 
	ROLE_CAP_A, 
	ROLE_TEAM_A, 
	ROLE_CAP_B, 
	ROLE_TEAM_B
};

enum _: PLAYER_INFO {
	PLAYER_ROLES:PLAYER_ROLE,
	bool:PLAYER_MATCH,
	bool:IS_PICK_ME,
	PLAYER_TEAM[16],
	LEAVE_IN_ROUND
};

new g_ePlayerInfo[MAX_PLAYERS + 1][PLAYER_INFO];

new g_iCaptainPick;
new g_iCaptainPickSteam[MAX_AUTHID_LENGTH];

new g_iCaptainFirst;
new g_iCaptainSecond;

new Array:g_aPlayersLoadData;

new TeamName:g_eSpecBack[MAX_PLAYERS + 1];

new g_msgMoney;

// === PointScap System Globals ===
#define TASK_POINTSCAP_DETECT  67890
#define TASK_POINTSCAP_KNIFE   67891
#define TASK_POINTSCAP_HUD     67892
#define TASK_POINTSCAP_FALLBACK 67893
#define TASK_POINTSCAP_FORCE   67894
#define TASK_POINTSCAP_ROUNDTIMER 67895
#define TASK_FREEZE            93761
#define MAX_ZONES 10

new Float:g_flPointScapDetectTime;
new Float:g_flPointScapKnifeTime;
new Float:g_flPointScapStayTime;
new Float:g_flTrainingProtect; // 比赛结束后15秒保护期，禁止 training→pub 切换
new bool:g_bReGameDLLRoundFired; // ReGameDLL 钩子已触发本回合事件，AMXX fallback 跳过
new Float:g_flPointScapScore5;
new Float:g_flPointScapScore4;
new Float:g_flPointScapScore3;
new g_iPointScapKnifeBonus;
new g_iPointScapTargetScore;
new g_iPointScapVampInit;

// ★ 回合制模式 (MODE_ROUNDS)
new g_iRoundsMaxRounds = 10;
new g_iRoundsWinRounds = 6;
new g_iRoundsScoreT;
new g_iRoundsScoreCT;
new g_iRoundsTotalPlayed;
new bool:g_bRoundsManual = false;
new bool:g_bRoundsSwapSides = true;  // ★ 回合制是否半场换边 (默认true=换边)
new g_iPointScapDetectTime;
new g_iPointScapKnifeTime;
new g_iPointScapSoundCapture;
new g_iPointScapSoundKnife;
new g_iPointScapSoundScore;

enum _:ZONE_DATA {
	ZONE_LABEL,           // 区域标签 (0=A, 1=B, ...)
	ZONE_ENABLED,         // 是否启用
	Float:ZONE_MINS[3],   // 区域最小坐标
	Float:ZONE_MAXS[3],   // 区域最大坐标
	ZONE_TYPE,            // 点位类型 (3=3人, 4=4人, 5=5人)
	Float:ZONE_SCORE,     // 该点位分数
	ZONE_CAPTURED,        // 是否已占领
	Float:ZONE_CAPTURE_TIME, // 占点进度/占领用时
	ZONE_STATUS,          // 0=未占, 1=已占, 2=已锁定
	ZONE_CAPTURED_TYPE,   // 3=3人点, 4=4人点, 5=5人点
	ZONE_PLAYER_COUNT,    // 区域内玩家数
	// Legacy fields (kept for compatibility)
	ZONE_POINT3_ENABLED,
	Float:ZONE_POINT3_MINS[3],
	Float:ZONE_POINT3_MAXS[3],
	ZONE_POINT4_ENABLED,
	Float:ZONE_POINT4_MINS[3],
	Float:ZONE_POINT4_MAXS[3],
	ZONE_POINT5_ENABLED,
	Float:ZONE_POINT5_MINS[3],
	Float:ZONE_POINT5_MAXS[3]
};

new g_eZones[MAX_ZONES][ZONE_DATA];
new g_iZoneCount;
new Float:g_flScoreA;  // Ascension: T方积分 / Vampire: 当前T方分数
new Float:g_flScoreB;  // Ascension: CT方积分 / Vampire: 当前CT方分数
new bool:g_bPointScapSpectatorJoin; // 是否允许观战者加入
new g_iPointScapRound;  // 点位模式回合数
new bool:g_bPointScapDetectFirstRun; // 点位检测首次运行标记
new Float:g_flScorePreRound[2];      // ★ 回合开始时的分数 [A, B]，暂停恢复用
new Float:g_flLastPauseTime;             // ★ 防重复暂停

// === Deserter System ===
new g_iDesertCount[MAX_PLAYERS + 1];

// === Knife ViewModel Settings ===
new bool:g_bKnifeViewModel[MAX_PLAYERS + 1];  // 每个玩家是否显示刀模型（true=显示, false=隐藏）
new bool:g_bKnifeSkipSpec = false;  // ★ AI报名恢复期间跳过观战拉人
