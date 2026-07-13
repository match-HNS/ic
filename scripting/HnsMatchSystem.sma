#include <hns-match/index>

public plugin_precache() {
	engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"));
	g_iRegisterSpawn = register_forward(FM_Spawn, "fwdSpawn", 1);

	precache_sound(sndUseSound);

	iBeam = precache_model("sprites/laserbeam.spr");
	g_sprBeam = precache_model("sprites/zbeam4.spr");
}

public plugin_cfg() {
	get_localinfo("amxx_logs", g_szLogPath, charsmax(g_szLogPath));
	add(g_szLogPath, charsmax(g_szLogPath), "/hnsmatchsystem");

	if (!dir_exists(g_szLogPath))
		mkdir(g_szLogPath);

	// ★ 已移除: autoStartPendingMode - 功能已由 AI 状态机接管

	// FPS优化: 延迟强制设置sys_ticrate, 确保在所有cfg执行完后生效, 换图不丢失
	set_task(5.0, "taskForceTicrate");
	set_task(10.0, "taskForceTicrate");
	set_task(30.0, "taskForceTicrate");
}

public taskForceTicrate() {
	new pCvar = get_cvar_pointer("sys_ticrate");
	if (pCvar) {
		new szVal[16];
		get_pcvar_string(pCvar, szVal, charsmax(szVal));
		if (str_to_float(szVal) < 500.0) {
			set_pcvar_string(pCvar, "1000");
		}
	}
}

public registerMode() {
	g_iHostageEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hostage_entity"));
	set_pev(g_iHostageEnt, pev_origin, Float:{ 0.0, 0.0, -55000.0 });
	set_pev(g_iHostageEnt, pev_size, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 });
	dllfunc(DLLFunc_Spawn, g_iHostageEnt);
}

// v5.5: 坠落伤害显示
new Float:g_fPendingFallDmg[MAX_PLAYERS + 1];

public plugin_init() {
	g_PluginId = register_plugin("Hide'n'Seek Match System", "5.0.0", "LINNA (GTRHNS)");

	rh_get_mapname(g_szMapName, charsmax(g_szMapName));

	cvars_init();
	init_gameplay();
	InitGameModes();

	cmds_init();
	pointscap_editor_init();
	semiclip_init();
	hnsmenu_init();
	ais_init();

	// ★ 地图选择菜单 (拼刀选人后)
	register_menucmd(register_menuid("MapPickMenu"), 1023, "handleMapPickMenu");

	// === Training Tools — 已由 HnsMatchTraining.amxx 独立接管 ===

	// Knife viewmodel commands
	register_clcmd("say /knife", "toggleKnifeViewModel");
	register_clcmd("say_team /knife", "toggleKnifeViewModel");
	register_concmd("hns_knife_viewmodel", "cmdKnifeViewModel", ADMIN_USER, "Toggle knife viewmodel (0=hide, 1=show)");

	// ★ AI报名系统
	register_clcmd("say /join", "aisJoin");
	register_clcmd("say_team /join", "aisJoin");
	register_clcmd("say /unjoin", "aisUnjoin");
	register_clcmd("say /re", "aisToggleRe");
	register_clcmd("say_team /re", "aisToggleRe");
	register_clcmd("say /teams", "aisShowTeams");
	register_clcmd("say_team /teams", "aisShowTeams");
	register_clcmd("say_team /unjoin", "aisUnjoin");

	// === Hook System — 已由 HnsMatchTraining.amxx 独立接管 ===

	register_forward(FM_EmitSound, "fwdEmitSoundPre", 0);
	register_forward(FM_ClientKill, "fwdClientKill");
	register_forward(FM_GetGameDescription, "fwdGameNameDesc");

	RegisterHookChain(RG_RoundEnd, "rgRoundEnd", false);
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "rgResetMaxSpeed", false);
	RegisterHookChain(RG_CSGameRules_RestartRound, "rgRestartRound", false);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "rgOnRoundFreezeEnd", true);
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgFlPlayerFallDamage", true);
    RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgFlPlayerFallDamagePre", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "rgPlayerSpawn", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilled", true);
	RegisterHookChain(RG_PlayerBlind, "rgPlayerBlind", false);
	RegisterHookChain(RG_CBasePlayer_MakeBomber, "rgPlayerMakeBomber", false);
	// SemiClip is now handled by HnsMatchSemiClip.amxx (Fakemeta ShouldCollide)
	// Do NOT register PreThink/PostThink here to avoid conflicts.
	// Keep the menu and commands for admin control.
	// RegisterHookChain(RG_CBasePlayer_PreThink, "rgPlayerPreThink", false);
	// RegisterHookChain(RG_CBasePlayer_PostThink, "rgPlayerPostThink", true);

	// AMXX标准事件fallback — 无ReGameDLL时用于驱动回合逻辑
	register_logevent("logEventRoundStart", 2, "1=Round_Start");
	register_logevent("logEventRoundEnd",   2, "1=Round_End");

	// SemiClip menu
	register_menucmd(register_menuid("SemiClipMenu"), (1<<0)|(1<<1)|(1<<2)|(1<<9), "handleSemiClipMenu");
	register_menucmd(register_menuid("MatchControlPlayer"), (1<<0)|(1<<1)|(1<<9), "handleMatchControlPlayer");
	register_menucmd(register_menuid("MatchControlAdmin"), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handleMatchControlAdmin");

	// HnsIC v5.0.0 Unified Big Menu System
	// ★ 所有菜单 handler 已在 hnsmenu.inc 的 hnsmenu_init() 中注册，此处不重复
	// 仅注册 hnsmenu.inc 中未包含的菜单：
	register_menucmd(register_menuid("HnsICTestTools"), (1<<0)|(1<<1)|(1<<9), "testToolsMenuHandler");
	register_menucmd(register_menuid("HnsICMoreSettings"), (1<<0)|(1<<1)|(1<<9), "moreSettingsMenuHandler");
	register_menucmd(register_menuid("HnsRoundsConfig"), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), "roundsConfigMenuHandler");

	// One-click helper/owner auth
	register_clcmd("say /fuzhu", "hnsHelperAuth");
	register_clcmd("say_team /fuzhu", "hnsHelperAuth");
	register_clcmd("say /owner", "hnsOwnerAuth");
	register_clcmd("say_team /owner", "hnsOwnerAuth");

	// 点位录制命令
	register_clcmd("say /creatzone", "cmdCreatZone");
	register_clcmd("say_team /creatzone", "cmdCreatZone");
	register_clcmd("say /delzone", "cmdDelZone");
	register_clcmd("say_team /delzone", "cmdDelZone");
	register_clcmd("say /listzones", "cmdListZones");
	register_clcmd("say_team /listzones", "cmdListZones");
	register_clcmd("say /savezones", "cmdSaveZones");
    register_clcmd("say_team /savezones", "cmdSaveZones");
    // v5.5: 重新加载点位配置
    register_clcmd("say /reloadzones", "cmdReloadZones");
    register_clcmd("say_team /reloadzones", "cmdReloadZones");

	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "Knife_PrimaryAttack", false);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "Knife_SecondaryAttack", false);

	register_message(get_user_msgid("HostagePos"), "msgHostagePos");
	register_message(get_user_msgid("ShowMenu"), "msgShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "msgVguiMenu");
	register_message(get_user_msgid("HideWeapon"), "msgHideWeapon");

	// ★ 隐藏敌人血量 (StatusIcon + ScoreInfo)
	register_message(get_user_msgid("StatusIcon"), "msgStatusIcon");
	register_message(get_user_msgid("ScoreInfo"), "msgScoreInfo");

	unregister_forward(FM_Spawn, g_iRegisterSpawn, 1);
	

	set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET);
	set_msg_block(g_msgMoney = get_user_msgid("Money"), BLOCK_SET);

	set_task(1.0, "ShowTimeAsMoney", 15671983, .flags="b"); // TODO: Что это за число

	g_aPlayersLoadData = ArrayCreate(SAVE_PLAYER_DATA);
	loadPlayers();

	forward_init();

	registerMode();


	g_eMatchInfo[e_tLeaveData] = TrieCreate();

	register_dictionary("mixsystem.txt");

	new szPath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	format(szPath, charsmax(szPath), "%s/mixsystem/%s", szPath, "matchsystem.cfg");
	server_cmd("exec %s", szPath);

	g_bDebugMode = bool:(plugin_flags() & AMX_FLAG_DEBUG);

	set_task(1.0, "HudTask", .flags = "b");
}

public plugin_natives() {
	register_hns_natives();
}

// TODO: Перенести в cup
public HudTask() {
	if (g_iCurrentMode == MODE_MIX && hns_cup_enabled()) {
		new szTimeToWin[HNS_TEAM][24], szTimeDiff[24];

		new Float:fTimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
		fnConvertTime(fTimeDiff, szTimeDiff, charsmax(szTimeDiff), false);

		new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
		new Float:flTimeToWinA = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A]);
		new Float:flTimeToWinB = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B]);
		fnConvertTime(flTimeToWinA, szTimeToWin[HNS_TEAM_A], 23, false);
		fnConvertTime(flTimeToWinB, szTimeToWin[HNS_TEAM_B], 23, false);

		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ce", "SPECTATOR");
		for (new id, i = 0; i < iNum; i++) {
			id = iPlayers[i];

			if (!is_user_hltv(id)) {
				continue;
			}

			set_hudmessage(0, 190, 255, -1.0, 0.98, 0, 0.0, 1.0, 0.1, 0.1, -1);
			if (g_isTeamTT == HNS_TEAM_A) {
				show_hudmessage(id, "TT [%s] vs [%s] CT (%s diff)", szTimeToWin[HNS_TEAM_A], szTimeToWin[HNS_TEAM_B], szTimeDiff);
			} else {
				show_hudmessage(id, "TT [%s] vs [%s] CT (%s diff)", szTimeToWin[HNS_TEAM_B], szTimeToWin[HNS_TEAM_A], szTimeDiff);
			}
		}

	}
}

public forward_init() {
	g_hForwards[MATCH_START] = CreateMultiForward("hns_match_started", ET_CONTINUE);
	g_hForwards[MATCH_RESET_ROUND] = CreateMultiForward("hns_match_reset_round", ET_CONTINUE);
	g_hForwards[MATCH_FINISH] = CreateMultiForward("hns_match_finished", ET_CONTINUE, FP_CELL);
	g_hForwards[MATCH_FINISH_POST] = CreateMultiForward("hns_match_finished_post", ET_CONTINUE, FP_CELL);
	g_hForwards[MATCH_CANCEL] = CreateMultiForward("hns_match_canceled", ET_CONTINUE);
	g_hForwards[MATCH_LEAVE_PLAYER] = CreateMultiForward("hns_player_leave_inmatch", ET_CONTINUE, FP_CELL);
	g_hForwards[MATCH_JOIN_PLAYER] = CreateMultiForward("hns_player_join_inmatch", ET_CONTINUE, FP_CELL, FP_CELL);

	g_hForwards[HNS_ROUND_START] = CreateMultiForward("hns_round_start", ET_CONTINUE);
	g_hForwards[HNS_ROUND_FREEZEEND] = CreateMultiForward("hns_round_freezeend", ET_CONTINUE);
	g_hForwards[HNS_ROUND_END] = CreateMultiForward("hns_round_end", ET_CONTINUE);
}

public MATCH_STATUS:native_get_status(amxx, params) {
	return g_iMatchStatus;
}

public MODE_STATES:native_get_state(amxx, params) {
	return g_eMatchState;
}

public NATCH_RULES:native_get_rules(amxx, params) {
	return g_iCurrentRules;
}

public fwdEmitSoundPre(id, iChannel, szSample[], Float:volume, Float:attenuation, fFlags, pitch) {
	if (equal(szSample, "weapons/knife_deploy1.wav")) {
		return FMRES_SUPERCEDE;
	}

	if (is_user_alive(id) && getUserTeam(id) == TEAM_TERRORIST && equal(szSample, sndDenySelect)) {
		emit_sound(id, iChannel, sndUseSound, volume, attenuation, fFlags, pitch);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}

public fwdClientKill(id) {
	if (g_iCurrentMode == MODE_DM) {
		chat_print(id, "%n killed a teammate.", id);
		return FMRES_SUPERCEDE;
	} else if (g_iCurrentMode == MODE_MIX && g_iCurrentRules == RULES_MR && g_flRoundTime < 90.0) {
		chat_print(id, "%n killed a teammate.", id);
		return FMRES_SUPERCEDE;
	} else {
		chat_print(id, "%n killed himself.", id);
	}
	return FMRES_IGNORED;
}

public fwdGameNameDesc()
{
	static gamename[32];
	get_pcvar_string(pCvar[GAMENAME], gamename, 31);
	forward_return(FMV_STRING, gamename);
	return FMRES_SUPERCEDE;
}

public fwdSpawn(entid) {
	static szClassName[32];
	if (pev_valid(entid)) {
		pev(entid, pev_classname, szClassName, 31);
		if (equal(szClassName, "func_buyzone")) engfunc(EngFunc_RemoveEntity, entid);

		for (new i = 0; i < sizeof g_szDefaultEntities; i++) {
			if (equal(szClassName, g_szDefaultEntities[i])) {
				engfunc(EngFunc_RemoveEntity, entid);
				break;
			}
		}
	}
}


public rgRoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	if (event == ROUND_GAME_COMMENCE) {
		set_member_game(m_bGameStarted, true);
		SetHookChainReturn(ATYPE_BOOL, false);
		return HC_SUPERCEDE;
	}

	if (g_iCurrentMode == MODE_ZM && event == ROUND_TERRORISTS_WIN) {
        set_member_game(m_bGameStarted, true);
        SetHookChainReturn(ATYPE_BOOL, false);
        return HC_SUPERCEDE;
    }

	// ★ FIX: 在 rgRoundEnd 里设置标志，防止 logEventRoundEnd fallback 重复触发 rounds_roundend
	g_bReGameDLLRoundFired = true;

	ExecuteForward(g_hForwards[HNS_ROUND_END]);

	if (g_GPFuncs[g_iCurrentGameplay][GP_ROUNDEND])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_ROUNDEND], _, (status == WINSTATUS_CTS) ? true : false);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDEND], _, (status == WINSTATUS_CTS) ? true : false);
	
	return HC_CONTINUE;
}

public rgResetMaxSpeed(id) {
	if (get_member_game(m_bFreezePeriod)) {
		if (g_iCurrentMode == MODE_TRAINING) {
			set_entvar(id, var_maxspeed, 250.0);
			return HC_SUPERCEDE;
		}

		if (getUserTeam(id) == TEAM_TERRORIST) {
			set_entvar(id, var_maxspeed, 250.0);
			return HC_SUPERCEDE;
		}
	}
	return HC_CONTINUE;
}

public rgRestartRound() { // Сделать красиво
	set_task(1.0, "taskDestroyBreakables");

	g_bReGameDLLRoundFired = true; // ReGameDLL 已处理，AMXX fallback 跳过

	if (g_GPFuncs[g_iCurrentGameplay][GP_ROUNDSTART])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_ROUNDSTART], _);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDSTART])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDSTART], _);

	ExecuteForward(g_hForwards[HNS_ROUND_START], _);
}

public taskDestroyBreakables() {
	new iEntity = -1;
	while ((iEntity = engfunc(EngFunc_FindEntityByString, iEntity, "classname", "func_breakable"))) {
		if (Float:get_entvar(iEntity, var_takedamage) > 0.0) {
			set_entvar(iEntity, var_origin, Float:{ 10000.0, 10000.0, 10000.0 });
		}
	}
}

public rgOnRoundFreezeEnd() {
	g_bReGameDLLRoundFired = true; // 无 ReGameDLL 时 AMXX fallback 也跳过 freezeend
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);
}

// ============================================
// AMXX标准事件fallback — 无ReGameDLL时驱动回合
// ============================================
public logEventRoundStart() {
	// ReGameDLL 已处理则跳过
	if (g_bReGameDLLRoundFired) {
		g_bReGameDLLRoundFired = false;
		return;
	}

		server_print("[Debug] RoundStart: mode=%d, state=%d, zones=%d", g_iCurrentMode, g_eMatchState, g_iZoneCount);

	// Fallback: 直接调用 roundstart 逻辑
	set_task(1.0, "taskDestroyBreakables");

	if (g_GPFuncs[g_iCurrentGameplay][GP_ROUNDSTART])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_ROUNDSTART], _);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDSTART])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDSTART], _);

	ExecuteForward(g_hForwards[HNS_ROUND_START], _);

	// 延迟触发 freezeend（无ReGameDLL模拟）
	new Float:flFreeze = get_cvar_float("mp_freezetime");
	if (flFreeze < 0.1) flFreeze = 0.1;
	set_task(flFreeze + 0.1, "taskAmxxFreezeEnd");
}

public taskAmxxFreezeEnd() {
	// ReGameDLL 已处理则跳过
	if (g_bReGameDLLRoundFired) {
		g_bReGameDLLRoundFired = false;
		return;
	}
		server_print("[Debug] FreezeEnd: mode=%d, state=%d", g_iCurrentMode, g_eMatchState);
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);
}

public logEventRoundEnd() {
	// ReGameDLL 已处理则跳过
	if (g_bReGameDLLRoundFired) {
		g_bReGameDLLRoundFired = false;
		return;
	}

	// Fallback: 确定胜方并调用 roundend
	new bool:win_ct = false;
	new iCT = get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_MatchTeam, "CT");
	new iT  = get_playersnum_ex(GetPlayers_ExcludeBots | GetPlayers_MatchTeam, "TERRORIST");

	// T全灭 → CT赢; CT全灭 → T赢
	if (iCT > 0 && iT == 0) win_ct = true;
	else if (iT > 0 && iCT == 0) win_ct = false;
	else win_ct = (iCT >= iT);

	ExecuteForward(g_hForwards[HNS_ROUND_END]);

	if (g_GPFuncs[g_iCurrentGameplay][GP_ROUNDEND])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_ROUNDEND], _, win_ct);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDEND], _, win_ct);
}

// v5.5: 坠落伤害显示 - 预钩子保存当前血量
public rgFlPlayerFallDamagePre(const id) {
    g_fPendingFallDmg[id] = 0.0;
}

public rgFlPlayerFallDamage(const id) {
    new Float:flDmg = Float:GetHookChainReturn(ATYPE_FLOAT);
    
    // v5.5: 坠落伤害显示（仅对玩家显示，忽略0伤害）
    if (flDmg > 0.0 && is_user_connected(id)) {
        g_fPendingFallDmg[id] = flDmg;
        set_task(0.05, "task_show_fall_damage", id);
    }

    if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FALLDAMAGE])
        ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FALLDAMAGE], _, id, flDmg);
}

// v5.5: 坠落伤害DHUD显示
public task_show_fall_damage(const id) {
    if (!is_user_connected(id)) return;
    if (g_fPendingFallDmg[id] <= 0.0) return;
    
    new iDmg = floatround(g_fPendingFallDmg[id]);
    new iHp = get_user_health(id);
    g_fPendingFallDmg[id] = 0.0;
    
    if (iHp <= 0) return;  // 玩家已死亡
    
    set_dhudmessage(255, 80, 80, -1.0, 0.85, 0, 0.0, 2.0, 0.5, 0.5);
    show_dhudmessage(id, "-%d HP^n(摔伤)", iDmg);
}

public rgPlayerSpawn(id) {
	if (!is_user_alive(id) || is_user_bot(id) || is_user_hltv(id))
		return;

	if (g_GPFuncs[g_iCurrentGameplay][GP_SETROLE])
	{
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_SETROLE], _, id);
	}

	// ★ 练习模式：延迟给 USP
	if (g_iCurrentMode == MODE_TRAINING) {
		client_print(id, print_chat, "[HNS] v7.0 spawn, giving USP in 0.5s...");
		set_task(0.5, "taskTrainingGiveUsp", id + 1000);
	}

	// 检查刀模型显示设置
	if (!g_bKnifeViewModel[id] || !g_iSettings[KNIFE_VIEWMODEL_ENABLE]) {
		set_task(0.1, "checkKnifeViewModel", id);
	}
}

public taskTrainingGiveUsp(taskid) {
	new id = taskid - 1000;
	if (!is_user_alive(id)) return;
	// ★ FIX: 不再用 sv_cheats，改用 rg_give_item
	rg_give_item(id, "weapon_usp");
	rg_set_user_bpammo(id, WEAPON_USP, 100);
}

public rgPlayerKilled(victim, attacker) {
	if (g_GPFuncs[g_iCurrentGameplay][GP_KILLED])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_KILLED], _, victim, attacker);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_KILL])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_KILL], _, victim, attacker);
}

public rgPlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, alpha) {
	if (getUserTeam(index) == TEAM_TERRORIST || getUserTeam(index) == TEAM_SPECTATOR)
		return HC_SUPERCEDE;

	return HC_CONTINUE;
}

public rgPlayerMakeBomber(const this) {
	SetHookChainReturn(ATYPE_BOOL, false);
	return HC_SUPERCEDE;
}

public client_disconnected(id) {
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_LEAVE])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_LEAVE], _, id);

	e_bBanned[id] = false;
	g_iBanExpired[id] = 0;

	g_bNoplay[id] = false;
	g_eSpecBack[id] = TEAM_UNASSIGNED;

	arrayset(eAfkData[id], 0, AfkData_s);
	arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
	g_bSurrenderVoted[id] = false;

	aisOnDisconnect(id);
}

public Knife_PrimaryAttack(ent)
{
	new id = get_member(ent, m_pPlayer);
	
	// T在HNS/比赛模式中禁止任何刀攻击
	if (g_iCurrentMode != MODE_TRAINING && g_iCurrentGameplay != GAMEPLAY_KNIFE && getUserTeam(id) == TEAM_TERRORIST)
		return HAM_SUPERCEDE;
	
	// 检查刀距离设置
	new Float:flDistance = float(g_iSettings[KNIFE_DISTANCE]);
	if (flDistance != 64.0) {
		// 执行刀攻击并检查距离
		new Float:flOrigin[3], Float:flViewOfs[3], Float:flEnd[3];
		get_entvar(id, var_origin, flOrigin);
		get_entvar(id, var_view_ofs, flViewOfs);
		flOrigin[0] += flViewOfs[0];
		flOrigin[1] += flViewOfs[1];
		flOrigin[2] += flViewOfs[2];
		
		new Float:flAngles[3];
		get_entvar(id, var_angles, flAngles);
		angle_vector(flAngles, ANGLEVECTOR_FORWARD, flEnd);
		flEnd[0] *= flDistance;
		flEnd[1] *= flDistance;
		flEnd[2] *= flDistance;
		flEnd[0] += flOrigin[0];
		flEnd[1] += flOrigin[1];
		flEnd[2] += flOrigin[2];
		
		new trace = create_tr2();
		engfunc(EngFunc_TraceLine, flOrigin, flEnd, DONT_IGNORE_MONSTERS, id, trace);
		new Float:flFraction;
		get_tr2(trace, TR_flFraction, flFraction);
		free_tr2(trace);
		
		if (flFraction < 1.0) {
			// 命中目标，执行刀伤害（用SecondaryAttack绕过距离限制）
			ExecuteHamB(Ham_Weapon_SecondaryAttack, ent);
		}
		
		return HAM_SUPERCEDE;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iCurrentGameplay == GAMEPLAY_KNIFE)
	{
		ExecuteHamB(Ham_Weapon_SecondaryAttack, ent);
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public Knife_SecondaryAttack(ent)
{
	new id = get_member(ent, m_pPlayer);
	
	// T在HNS/比赛模式中禁止右键重击
	if (g_iCurrentMode != MODE_TRAINING && g_iCurrentGameplay != GAMEPLAY_KNIFE && getUserTeam(id) == TEAM_TERRORIST)
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public msgHostagePos(msgid, dest, id) {
	return PLUGIN_HANDLED;
}

public msgShowMenu(msgid, dest, id) {
	if (!shouldAutoJoin(id))
		return PLUGIN_CONTINUE;

	if (hns_is_knife_map() && hns_cup_enabled()) {
		return PLUGIN_CONTINUE;
	}

	static team_select[] = "#Team_Select";
	static menu_text_code[sizeof team_select];
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1);
	if (!equal(menu_text_code, team_select))
		return (PLUGIN_CONTINUE);

	setForceTeamJoinTask(id, msgid);

	return PLUGIN_HANDLED;
}

public msgVguiMenu(msgid, dest, id) {
	if (get_msg_arg_int(1) != 2 || !shouldAutoJoin(id))
		return (PLUGIN_CONTINUE);
	
	if (hns_is_knife_map() && hns_cup_enabled()) {
		return PLUGIN_CONTINUE;
	}

	setForceTeamJoinTask(id, msgid);

	return PLUGIN_HANDLED;
}

public msgHideWeapon(msgid, dest, id) {
	if (g_iCurrentMode != MODE_MIX) {
		const money = (1 << 5);
		set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | money);
	}
}

// ★ 隐藏敌人血量: 拦截 StatusIcon 中的 health 图标
public msgStatusIcon(msgid, dest, id) {
	new iMode = get_pcvar_num(get_cvar_pointer("hns_hide_enemy_hp"));
	if (iMode == 0) return PLUGIN_CONTINUE;

	// iMode=1: 仅比赛模式; iMode=2: 始终
	if (iMode == 1 && g_iCurrentMode != MODE_MIX) return PLUGIN_CONTINUE;

	new szIcon[16];
	get_msg_arg_string(1, szIcon, charsmax(szIcon));

	// health_icon_1/2/3/4 = 敌人血量显示
	if (containi(szIcon, "health_icon") != -1) {
		return PLUGIN_HANDLED;  // 阻止显示
	}

	return PLUGIN_CONTINUE;
}

// ★ 隐藏 Tab 计分板中的敌人血量
public msgScoreInfo(msgid, dest, id) {
	new iMode = get_pcvar_num(get_cvar_pointer("hns_hide_enemy_hp"));
	if (iMode == 0) return PLUGIN_CONTINUE;

	if (iMode == 1 && g_iCurrentMode != MODE_MIX) return PLUGIN_CONTINUE;

	// ScoreInfo: arg1=玩家ID, arg3=血量
	new iPlayer = get_msg_arg_int(1);
	if (iPlayer == id) return PLUGIN_CONTINUE; // 自己的血量正常显示

	new iMyTeam = get_user_team(id);
	new iTheirTeam = get_user_team(iPlayer);
	if (iMyTeam == iTheirTeam) return PLUGIN_CONTINUE; // 队友血量正常显示

	// 隐藏敌人血量: 显示为 0
	set_msg_arg_int(3, ARG_SHORT, 0);
	return PLUGIN_CONTINUE;
}

bool:shouldAutoJoin(id) {
	return (!get_user_team(id) && !task_exists(id));
}

setForceTeamJoinTask(id, menu_msgid) {
	static param_menu_msgid[2];
	param_menu_msgid[0] = menu_msgid;

	set_task(0.1, "taskForceTeamJoin", id, param_menu_msgid, sizeof param_menu_msgid);
}

public taskForceTeamJoin(menu_msgid[], id) {
	if (get_user_team(id))
		return;

	forceTeamJoin(id, menu_msgid[0], "5", "5");
}


stock forceTeamJoin(id, menu_msgid, team[] = "5", class[] = "0") {
	static jointeam[] = "jointeam";
	if (class[0] == '0') {
		engclient_cmd(id, jointeam, team);
		return;
	}

	static msg_block, joinclass[] = "joinclass";
	msg_block = get_msg_block(menu_msgid);
	set_msg_block(menu_msgid, BLOCK_SET);
	engclient_cmd(id, jointeam, team);
	engclient_cmd(id, joinclass, class);
	set_msg_block(menu_msgid, msg_block);

	set_task(0.2, "taskSetPlayerTeam", id);
}

public taskSetPlayerTeam(id) {
	if (!is_user_connected(id))
		return;

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_JOIN])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_JOIN], _, id);
}

public ShowTimeAsMoney()
{
	static players[32], num, id;

	// Timer mode: show time as money
	if (g_iCurrentMode == MODE_MIX && g_iMatchStatus == MATCH_STARTED && g_iCurrentRules == RULES_TIMER) {
		get_players(players, num, "ac");
		for(--num; num>=0; num--)
		{
			id = players[num];

			message_begin(MSG_ONE, g_msgMoney, .player=id);
			write_long(floatround((g_eMatchInfo[e_mWintime] * 60.0) - g_eMatchInfo[e_flSidesTime][g_isTeamTT], floatround_floor));
			write_byte(0);
			message_end();
		}
	}

	// Mode HUD display for all players
	// ★ Ascension/Vampire 有自己的 HUD，跳过全局 HUD 避免重叠闪烁
	if (g_iCurrentMode == MODE_ASCENSION || g_iCurrentMode == MODE_VAMP) return;
	
	get_players(players, num, "ch");
	for (new i = 0; i < num; i++) {
		id = players[i];
		if (!g_bModeHudEnabled[id])
			continue;

		new szModeText[64];
		getModeHudText(szModeText, charsmax(szModeText));

		if (szModeText[0]) {
			set_hudmessage(0, 255, 255, 0.02, 0.2, 0, 0.0, 1.5, 0.1, 0.0, -1);
			show_hudmessage(id, szModeText);
		}
	}
}

stock getModeHudText(szBuffer[], iLen) {
	if (g_iCurrentMode == MODE_TRAINING) {
		if (g_iMatchStatus == MATCH_NONE)
			formatex(szBuffer, iLen, "[Training]");
		else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
			formatex(szBuffer, iLen, "[Captain Mode]");
		else if (g_iMatchStatus == MATCH_CUPKNIFE || g_iMatchStatus == MATCH_CUPPICK)
			formatex(szBuffer, iLen, "[Cup Veto]");
		else
			formatex(szBuffer, iLen, "[Training]");
	} else if (g_iCurrentMode == MODE_MIX) {
		if (g_iMatchStatus == MATCH_STARTED) {
			if (g_iCurrentRules == RULES_MR) {
				new iTotalRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];
				formatex(szBuffer, iLen, "[Mix MR] %d/%d", iTotalRounds + 1, g_iSettings[MAXROUNDS] * 2);
			} else if (g_iCurrentRules == RULES_TIMER) {
				new szTime[16];
				new Float:flDiff = floatabs(g_eMatchInfo[e_flSidesTime][HNS_TEAM_A] - g_eMatchInfo[e_flSidesTime][HNS_TEAM_B]);
				fnConvertTime(flDiff, szTime, charsmax(szTime), false);
				formatex(szBuffer, iLen, "[Mix Timer] Diff: %s", szTime);
			} else if (g_iCurrentRules == RULES_DUEL) {
				formatex(szBuffer, iLen, "[Mix Duel]");
			} else if (g_iCurrentRules == RULES_POINTSCAP) {
				formatex(szBuffer, iLen, "[Mix Ascension]");
			} else if (g_iCurrentRules == RULES_VAMP) {
				formatex(szBuffer, iLen, "[Mix Vampire]");
			} else {
				formatex(szBuffer, iLen, "[Mix]");
			}
		} else {
			formatex(szBuffer, iLen, "[Mix - Starting]");
		}
	} else if (g_iCurrentMode == MODE_KNIFE) {
		formatex(szBuffer, iLen, "[Knife Round]");
	} else if (g_iCurrentMode == MODE_PUB) {
		formatex(szBuffer, iLen, "[Public]");
	} else if (g_iCurrentMode == MODE_DM) {
		formatex(szBuffer, iLen, "[DeathMatch]");
	} else if (g_iCurrentMode == MODE_ZM) {
		formatex(szBuffer, iLen, "[Zombie]");
	} else if (g_iCurrentMode == MODE_ASCENSION) {
		formatex(szBuffer, iLen, "[Ascension]");
	} else if (g_iCurrentMode == MODE_VAMP) {
		formatex(szBuffer, iLen, "[Vampire]");
	} else {
		szBuffer[0] = 0;
	}
}

public plugin_end() {
	TrieDestroy(g_eMatchInfo[e_tLeaveData]);
	ArrayDestroy(g_aPlayersLoadData);
}

// ============================================
// Knife ViewModel Control
// ============================================
public setKnifeViewModel(id, bool:bShow) {
	g_bKnifeViewModel[id] = bShow;
	
	if (!bShow) {
		// 隐藏刀模型
		set_pev(id, pev_viewmodel2, "");
		set_pev(id, pev_weaponmodel2, "");
	} else {
		// 恢复刀模型
		if (get_user_weapon(id) == CSW_KNIFE) {
			set_pev(id, pev_viewmodel2, "models/v_knife.mdl");
			set_pev(id, pev_weaponmodel2, "models/p_knife.mdl");
		}
	}
}

public toggleKnifeViewModel(id) {
	if (!is_user_alive(id)) return;
	if (getUserTeam(id) != TEAM_TERRORIST) {
		client_print(id, print_chat, "[HNS] Only T can toggle knife viewmodel.");
		return;
	}
	
	g_bKnifeViewModel[id] = !g_bKnifeViewModel[id];
	setKnifeViewModel(id, g_bKnifeViewModel[id]);
	
	client_print(id, print_chat, "[HNS] Knife viewmodel %s.", g_bKnifeViewModel[id] ? "shown" : "hidden");
}

public cmdKnifeViewModel(id, level, cid) {
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new szArg[4];
	read_argv(1, szArg, charsmax(szArg));
	
	new iTarget = id;
	if (read_argc() > 2) {
		new szTarget[32];
		read_argv(2, szTarget, charsmax(szTarget));
		iTarget = cmd_target(id, szTarget, CMDTARGET_ALLOW_SELF);
		if (!iTarget)
			return PLUGIN_HANDLED;
	}
	
	new bool:bShow = str_to_num(szArg) != 0;
	setKnifeViewModel(iTarget, bShow);
	
	client_print(id, print_chat, "[HNS] Knife viewmodel %s for %n.", bShow ? "shown" : "hidden", iTarget);
	return PLUGIN_HANDLED;
}

public client_spawn(id) {
	// 重置刀模型显示状态
	g_bKnifeViewModel[id] = true;
}

public client_putinserver(id) {
	g_bKnifeViewModel[id] = true;
	g_iModelSelectTeam[id] = 0;
	g_bPlayerSemiClip[id] = true;
	deserter_load(id);
	hns_load_owner_list(id);
	hnsmenu_client_putinserver(id);

	aisOnPutInServer(id);
}

// === SemiClip: PreThink/PostThink ===
public rgPlayerPreThink(id) {
	semiclip_prethink(id);
}

public rgPlayerPostThink(id) {
	semiclip_postthink(id);
}

public checkKnifeViewModel(id) {
	if (!is_user_alive(id)) return;
	if (!g_bKnifeViewModel[id] || !g_iSettings[KNIFE_VIEWMODEL_ENABLE]) {
		setKnifeViewModel(id, false);
	}
}

// ============================================
// Main Menu Handler (routes to sub-menus)
// ============================================
public mainMenuHandler(id, key) {
	if (key == 0) {                                // Key 1: 比赛管理
		if (isUserWatcher(id) || is_user_admin(id))
			showMatchMenu(id);
		else {
			client_print(id, print_center, "你没有比赛管理权限");
			showMainMenu(id);
		}
	} else if (key == 1) {                        // Key 2: AI分组
		showAISignupMenu(id);
	} else if (key == 2) {                        // Key 3: 选择模式
		menuSelectMode(id);
	} else if (key == 3) {                        // Key 4: 训练工具
		if (g_iCurrentMode != MODE_TRAINING) {
			client_print(id, print_chat, "[HNS] 训练工具仅在训练模式下可用！");
			showMainMenu(id);
		} else {
			showTrainingMenu(id);
		}
	} else if (key == 4) {                        // Key 5: 个人设置
		showPersonalMenu(id);
	} else if (key == 5) {                        // Key 6: 地图管理
		showMapMenu(id);
	} else if (key == 6) {                        // Key 7: 数据统计
		showStatsMenu(id);
	} else if (key == 7) {                        // Key 8: 个人设置
		showPersonalMenu(id);
	} else if (key == 8) {                        // Key 9: 管理工具
		if (isUserWatcher(id) || is_user_admin(id))
			showAdminMenu(id);
		else
			showMainMenu(id);
	} else if (key == 9) {
		// Key 0: 退出
	}
}

// ============================================================================
// TRAINING TOOLS — 已由 HnsMatchTraining.amxx 独立接管
// ============================================================================
