#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#define DISTANCE 120
#define ACCESS_SEMICLIP ADMIN_CFG

// 穿透模式
#define MODE_AUTO 0
#define MODE_FORCE_ON 1
#define MODE_FORCE_OFF 2

// 菜单ID
#define MENU_MAIN 0
#define MENU_MAPS 1
#define MENU_ADMIN 2

new g_iTeam[33];
new bool:g_bSolid[33];
new bool:g_bHasSemiclip[33];
new bool:g_bPlayerOff[33];
new Float:g_fOrigin[33][3];

new g_iMode = MODE_AUTO;
new g_iMaxPlayers;
new bool:g_bEnabled;

// 训练模式检测
new pCvarTrainingMode;

// 地图投票
new Array:g_aMaps;
new g_iNominated[33];        // 每个玩家提名的地图索引
new g_iNominationCount[128]; // 每张地图被提名的次数
new g_iTotalNominations;
new bool:g_bHasRtv[33];
new g_iRtvCount;
new g_iMapCount;
new g_iMenuPage[33];

// 技能地图列表
new Array:g_aSkillMaps;

loadSkillMaps() {
	g_aSkillMaps = ArrayCreate(32, 1);
	
	new szPath[256], szDir[128];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szPath, charsmax(szPath), "%s/mixsystem/hns-maps.ini", szDir);
	
	new f = fopen(szPath, "rt");
	if (!f) {
		server_print("[SemiClip] 无法读取 %s", szPath);
		return;
	}
	
	new szLine[128], szMap[32];
	new bool:bInSkill = false;
	
	while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == EOS)
			continue;
		
		if (szLine[0] == '[') {
			bInSkill = (containi(szLine, "skill") != -1);
			continue;
		}
		
		if (bInSkill) {
			parse(szLine, szMap, charsmax(szMap));
			if (szMap[0] && szMap[0] != ';')
				ArrayPushString(g_aSkillMaps, szMap);
		}
	}
	fclose(f);
	
	server_print("[SemiClip] 加载 %d 张技能地图", ArraySize(g_aSkillMaps));
}

loadMaps() {
	g_aMaps = ArrayCreate(32, 1);
	
	new szPath[256], szDir[128];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szPath, charsmax(szPath), "%s/mixsystem/hns-maps.ini", szDir);
	
	new f = fopen(szPath, "rt");
	if (!f) {
		server_print("[SemiClip] 无法读取地图列表 %s", szPath);
		return;
	}
	
	new szLine[128], szMap[32];
	
	while (!feof(f) && fgets(f, szLine, charsmax(szLine))) {
		trim(szLine);
		
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == EOS)
			continue;
		
		if (szLine[0] == '[')
			continue;
		
		parse(szLine, szMap, charsmax(szMap));
		if (szMap[0] && szMap[0] != ';') {
			// 去重
			new bool:bExists = false;
			for (new i = 0; i < ArraySize(g_aMaps); i++) {
				new szExisting[32];
				ArrayGetString(g_aMaps, i, szExisting, charsmax(szExisting));
				if (equali(szExisting, szMap)) {
					bExists = true;
					break;
				}
			}
			if (!bExists)
				ArrayPushString(g_aMaps, szMap);
		}
	}
	fclose(f);
	
	g_iMapCount = ArraySize(g_aMaps);
	server_print("[SemiClip] 地图列表加载 %d 张地图", g_iMapCount);
}

bool:isSkillMap() {
	if (!g_aSkillMaps || ArraySize(g_aSkillMaps) == 0)
		return false;
	
	new szCur[32], szMap[32];
	get_mapname(szCur, charsmax(szCur));
	
	for (new i = 0; i < ArraySize(g_aSkillMaps); i++) {
		ArrayGetString(g_aSkillMaps, i, szMap, charsmax(szMap));
		if (equali(szCur, szMap))
			return true;
	}
	return false;
}

bool:isSemiclipOn() {
	// ★ 训练模式：始终开启，忽略地图类型
	if (pCvarTrainingMode && get_pcvar_num(pCvarTrainingMode) == 1)
		return true;
	
	// 其他模式：根据管理员设置
	switch (g_iMode) {
		case MODE_FORCE_ON:  return true;
		case MODE_FORCE_OFF: return false;
		case MODE_AUTO:      return isSkillMap();
	}
	return false;
}

bool:isTrainingMode() {
	return (pCvarTrainingMode && get_pcvar_num(pCvarTrainingMode) == 1);
}

// 比赛进行中（非训练模式）禁用投票
bool:isMatchActive() {
	return !isTrainingMode();
}

// ==================== 穿透核心 ====================
UpdatePlayerData() {
	for (new id = 1; id <= g_iMaxPlayers; id++) {
		if (is_user_alive(id)) {
			g_iTeam[id] = get_user_team(id);
			g_bSolid[id] = (pev(id, pev_solid) == SOLID_SLIDEBOX);
			pev(id, pev_origin, g_fOrigin[id]);
		} else {
			g_bSolid[id] = false;
		}
	}
}

DoSemiclip(plr) {
	if (!g_bSolid[plr]) return;
	
	for (new id = 1; id <= g_iMaxPlayers; id++) {
		if (g_bSolid[id] && get_distance_f(g_fOrigin[plr], g_fOrigin[id]) <= DISTANCE && id != plr) {
			if (g_iTeam[plr] != g_iTeam[id])
				continue;
			if (g_bPlayerOff[plr] || g_bPlayerOff[id])
				continue;
	
			set_pev(id, pev_solid, SOLID_NOT);
			g_bHasSemiclip[id] = true;
		}
	}
}

UndoSemiclip() {
	for (new id = 1; id <= g_iMaxPlayers; id++) {
		if (g_bHasSemiclip[id]) {
			set_pev(id, pev_solid, SOLID_SLIDEBOX);
			g_bHasSemiclip[id] = false;
		}
	}
}

public FwdHamPlayerPreThink(id) {
	if (!g_bEnabled || !is_user_alive(id)) return HAM_IGNORED;
	
	UpdatePlayerData();
	DoSemiclip(id);
	
	return HAM_IGNORED;
}

public FwdHamPlayerPostThink(id) {
	if (!g_bEnabled) return HAM_IGNORED;
	UndoSemiclip();
	return HAM_IGNORED;
}

public FwdAddToFullPack_Post(es_handle, e, ent, host, hostflags, player, pset) {
	if (player && g_bSolid[host] && g_bSolid[ent]) {
		if (get_distance_f(g_fOrigin[host], g_fOrigin[ent]) <= DISTANCE) {
			if (g_iTeam[host] != g_iTeam[ent])
				return FMRES_IGNORED;
			if (g_bPlayerOff[host] || g_bPlayerOff[ent])
				return FMRES_IGNORED;
				
			set_es(es_handle, ES_Solid, SOLID_NOT);
			set_es(es_handle, ES_RenderMode, kRenderTransAlpha);
			set_es(es_handle, ES_RenderAmt, 85);
		}
	}
	
	return FMRES_IGNORED;
}

// ==================== 插件初始化 ====================
public plugin_init() {
	register_plugin("HNS Team Semiclip", "4.0", "AI");
	
	loadSkillMaps();
	loadMaps();
	
	g_iMaxPlayers = get_maxplayers();
	
	// 训练模式 CVAR
	pCvarTrainingMode = get_cvar_pointer("hns_training_mode");
	
	RegisterHam(Ham_Player_PreThink, "player", "FwdHamPlayerPreThink", 1);
	RegisterHam(Ham_Player_PostThink, "player", "FwdHamPlayerPostThink", 1);
	
	register_forward(FM_AddToFullPack, "FwdAddToFullPack_Post", 1);
	
	// say 拦截
	register_clcmd("say", "cmdSayHook");
	register_clcmd("say_team", "cmdSayHook");
	
	// 控制台命令
	register_concmd("cpenol", "cmdSemiclipMenu", -1, "SemiClip Menu");
	register_concmd("cpenoloff", "cmdToggleSemiclip", -1, "Toggle personal semiclip");
	
	// ★ 菜单注册 - 每个菜单单独注册
	register_menucmd(register_menuid("SemiClipMain"), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), "handleMainMenu");
	register_menucmd(register_menuid("SemiClipMaps"), (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handleMapMenu");
	register_menucmd(register_menuid("SemiClipAdmin"), (1<<0)|(1<<1)|(1<<2)|(1<<9), "handleAdminMenu");
	
	// 换图时自动判断
	set_task(0.5, "CheckMapOnStart");
	
	// 定时刷新训练模式状态
	set_task(2.0, "CheckTrainingMode", _, _, _, "b");
}

UpdateEnabled() {
	g_bEnabled = isSemiclipOn();
}

public CheckMapOnStart() {
	UpdateEnabled();
	if (g_bEnabled) {
		server_print("[SemiClip] 穿透已开启%s", isTrainingMode() ? "（训练模式）" : "");
	} else {
		server_print("[SemiClip] 穿透未生效（非训练模式且非Skill图）");
	}
}

public CheckTrainingMode() {
	static bool:bLastState;
	new bool:bCurrent = isTrainingMode();
	if (bCurrent != bLastState) {
		bLastState = bCurrent;
		UpdateEnabled();
		if (bCurrent) {
			client_print_color(0, print_team_blue, "[SemiClip] 训练模式已开启，队友穿透自动生效");
		} else {
			client_print_color(0, print_team_blue, "[SemiClip] 已退出训练模式，穿透恢复自动判断");
		}
	}
}

// ==================== say 拦截 ====================
public cmdSayHook(id) {
	new szArgs[64];
	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);
	
	if (szArgs[0] != '/')
		return PLUGIN_CONTINUE;
	
	if (equali(szArgs, "/cpenol")) {
		cmdSemiclipMenu(id);
		return PLUGIN_HANDLED;
	}
	
	if (equali(szArgs, "/cpenoloff")) {
		cmdToggleSemiclip(id);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

// ==================== 主菜单 ====================
public cmdSemiclipMenu(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	showMainMenu(id);
	return PLUGIN_HANDLED;
}

showMainMenu(id) {
	new szMenu[1024], len;
	new szMode[48], szMap[32], szStatus[32];
	
	getModeName(szMode, charsmax(szMode));
	get_mapname(szMap, charsmax(szMap));
	
	if (isTrainingMode()) {
		formatex(szStatus, charsmax(szStatus), "\y训练模式（强制开启）");
	} else {
		formatex(szStatus, charsmax(szStatus), isSemiclipOn() ? "\y已开启" : "\r已关闭");
	}
	
	len = formatex(szMenu[len], charsmax(szMenu) - len, "\r[SemiClip] \w队友穿透设置^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r当前地图: \y%s^n", szMap);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r当前状态: %s^n", szStatus);
	
	if (isTrainingMode()) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d（训练模式自动开启，无视地图类型）^n^n");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r当前模式: \y%s^n^n", szMode);
	}
	
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \w个人穿透: \y%s^n", g_bPlayerOff[id] ? "关闭" : "开启");
	
	if (isMatchActive()) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d2. 地图投票（比赛模式禁用）^n");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w地图投票^n");
	}
	
	if (get_user_flags(id) & ACCESS_SEMICLIP) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \r管理员设置^n");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d3. 管理员设置^n");
	}
	
	if (isMatchActive()) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d4. RTV 投票换图（比赛模式禁用）^n");
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\d5. 查看当前投票（比赛模式禁用）^n^n");
	} else {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \wRTV 投票换图^n");
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5. \w查看当前投票^n^n");
	}
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w退出");
	
	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9), szMenu, -1, "SemiClipMain");
}

public handleMainMenu(id, key) {
	if (!is_user_connected(id)) return;
	
	switch (key) {
		case 0: { // 个人穿透开关
			g_bPlayerOff[id] = !g_bPlayerOff[id];
			client_print_color(id, print_team_blue, "[SemiClip] 个人穿透: \y%s", g_bPlayerOff[id] ? "关闭" : "开启");
			showMainMenu(id);
		}
		case 1: { // 地图投票（提名）
			if (isMatchActive()) {
				client_print_color(id, print_team_blue, "[SemiClip] 比赛模式禁用地图投票");
				showMainMenu(id);
				return;
			}
			g_iMenuPage[id] = 0;
			showMapMenu(id);
		}
		case 2: { // 管理员设置
			if (get_user_flags(id) & ACCESS_SEMICLIP) {
				showAdminMenu(id);
			} else {
				client_print_color(id, print_team_blue, "[SemiClip] 只有管理员可以操作");
				showMainMenu(id);
			}
		}
		case 3: { // RTV
			if (isMatchActive()) {
				client_print_color(id, print_team_blue, "[SemiClip] 比赛模式禁用 RTV 投票");
				showMainMenu(id);
				return;
			}
			cmdRtv(id);
			showMainMenu(id);
		}
		case 4: { // 查看投票
			if (isMatchActive()) {
				client_print_color(id, print_team_blue, "[SemiClip] 比赛模式禁用投票");
				showMainMenu(id);
				return;
			}
			showVoteStatus(id);
			showMainMenu(id);
		}
		case 9: return; // 退出
	}
}

// ==================== 管理员菜单 ====================
showAdminMenu(id) {
	new szMenu[512], len;
	new szMode[48];
	
	getModeName(szMode, charsmax(szMode));
	
	len = formatex(szMenu[len], charsmax(szMenu) - len, "\r[SemiClip] \w管理员设置^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r当前模式: \y%s^n^n", szMode);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \w强制开启^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w强制关闭^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \w恢复自动模式^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\d自动模式: Skill地图自动开，其他自动关^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w返回");
	
	show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<9), szMenu, -1, "SemiClipAdmin");
}

public handleAdminMenu(id, key) {
	if (!is_user_connected(id)) return;
	if (!(get_user_flags(id) & ACCESS_SEMICLIP)) {
		showMainMenu(id);
		return;
	}
	
	switch (key) {
		case 0: {
			g_iMode = MODE_FORCE_ON;
			UpdateEnabled();
			client_print_color(0, print_team_blue, "[SemiClip] 管理员强制开启队友穿透");
		}
		case 1: {
			g_iMode = MODE_FORCE_OFF;
			UpdateEnabled();
			client_print_color(0, print_team_blue, "[SemiClip] 管理员强制关闭队友穿透");
		}
		case 2: {
			g_iMode = MODE_AUTO;
			UpdateEnabled();
			client_print_color(0, print_team_blue, "[SemiClip] 恢复自动模式");
		}
		case 9: {
			showMainMenu(id);
			return;
		}
	}
	
	showAdminMenu(id);
}

// ==================== 地图投票菜单 ====================
showMapMenu(id) {
	if (g_iMapCount <= 0) {
		client_print_color(id, print_team_blue, "[SemiClip] 暂无可用地图");
		showMainMenu(id);
		return;
	}
	
	new szMenu[1024], len;
	new iStart = g_iMenuPage[id] * 7;
	new iEnd = min(iStart + 7, g_iMapCount);
	new szMap[32], szCurMap[32];
	
	get_mapname(szCurMap, charsmax(szCurMap));
	
	len = formatex(szMenu[len], charsmax(szMenu) - len, "\r[SemiClip] \w地图提名 (%d/%d)^n^n", g_iMenuPage[id] + 1, (g_iMapCount + 6) / 7);
	
	new keys = 0;
	new iKey = 0;
	
	for (new i = iStart; i < iEnd; i++) {
		ArrayGetString(g_aMaps, i, szMap, charsmax(szMap));
		
		new szTag[16];
		if (equali(szMap, szCurMap)) {
			copy(szTag, charsmax(szTag), "\r[当前]");
		} else if (g_iNominated[id] == i) {
			copy(szTag, charsmax(szTag), "\y[已提名]");
		} else if (g_iNominationCount[i] > 0) {
			formatex(szTag, charsmax(szTag), "\d[%d票]", g_iNominationCount[i]);
		} else {
			szTag[0] = EOS;
		}
		
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d. \w%s %s^n", iKey + 1, szMap, szTag);
		keys |= (1 << iKey);
		iKey++;
	}
	
	if (iEnd < g_iMapCount) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r9. \w下一页^n");
		keys |= (1 << 8);
	}
	
	if (g_iMenuPage[id] > 0) {
		len += formatex(szMenu[len], charsmax(szMenu) - len, "\r8. \w上一页^n");
		keys |= (1 << 7);
	}
	
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w返回");
	keys |= (1 << 9);
	
	show_menu(id, keys, szMenu, -1, "SemiClipMaps");
}

public handleMapMenu(id, key) {
	if (!is_user_connected(id)) return;
	
	if (key == 7) { // 上一页
		if (g_iMenuPage[id] > 0) {
			g_iMenuPage[id]--;
			showMapMenu(id);
		}
		return;
	}
	
	if (key == 8) { // 下一页
		if ((g_iMenuPage[id] + 1) * 7 < g_iMapCount) {
			g_iMenuPage[id]++;
			showMapMenu(id);
		}
		return;
	}
	
	if (key == 9) { // 返回
		showMainMenu(id);
		return;
	}
	
	// 提名地图
	new iMapIdx = g_iMenuPage[id] * 7 + key;
	if (iMapIdx >= g_iMapCount) {
		showMapMenu(id);
		return;
	}
	
	// 取消之前的提名
	if (g_iNominated[id] >= 0 && g_iNominated[id] < g_iMapCount) {
		g_iNominationCount[g_iNominated[id]]--;
		if (g_iNominationCount[g_iNominated[id]] < 0)
			g_iNominationCount[g_iNominated[id]] = 0;
		g_iTotalNominations--;
	}
	
	new szMap[32];
	ArrayGetString(g_aMaps, iMapIdx, szMap, charsmax(szMap));
	
	if (g_iNominated[id] == iMapIdx) {
		// 取消提名
		g_iNominated[id] = -1;
		client_print_color(id, print_team_blue, "[SemiClip] 已取消提名 \y%s", szMap);
	} else {
		// 提名新地图
		g_iNominated[id] = iMapIdx;
		g_iNominationCount[iMapIdx]++;
		g_iTotalNominations++;
		client_print_color(0, print_team_blue, "[SemiClip] \y%n\w 提名了地图 \y%s\w (%d票)", id, szMap, g_iNominationCount[iMapIdx]);
		
		// 检查是否达到换图阈值
		CheckRtvThreshold();
	}
	
	showMapMenu(id);
}

// ==================== RTV 投票 ====================
cmdRtv(id) {
	if (!is_user_connected(id)) return;
	if (g_bHasRtv[id]) {
		client_print_color(id, print_team_blue, "[SemiClip] 你已经投过 RTV 了");
		return;
	}
	
	g_bHasRtv[id] = true;
	g_iRtvCount++;
	
	new iPlayers = get_playersnum();
	new iNeeded = max(1, floatround(iPlayers * 0.66));
	
	client_print_color(0, print_team_blue, "[SemiClip] \y%n\w 发起了 RTV 投票 (\y%d\w/\y%d\w)", id, g_iRtvCount, iNeeded);
	
	if (g_iRtvCount >= iNeeded) {
		client_print_color(0, print_team_blue, "[SemiClip] RTV 投票通过，正在换图...");
		DoMapVote();
	}
}

CheckRtvThreshold() {
	new iPlayers = get_playersnum();
	new iNeeded = max(1, floatround(iPlayers * 0.5));
	
	if (g_iTotalNominations >= iNeeded) {
		client_print_color(0, print_team_blue, "[SemiClip] 提名人数达到阈值，自动发起 RTV...");
		DoMapVote();
	}
}

DoMapVote() {
	// 找到提名最多的地图
	new iMaxVotes = -1;
	new iBestMap = -1;
	
	for (new i = 0; i < g_iMapCount; i++) {
		if (g_iNominationCount[i] > iMaxVotes) {
			iMaxVotes = g_iNominationCount[i];
			iBestMap = i;
		}
	}
	
	if (iBestMap >= 0 && iMaxVotes > 0) {
		new szMap[32];
		ArrayGetString(g_aMaps, iBestMap, szMap, charsmax(szMap));
		
		client_print_color(0, print_team_blue, "[SemiClip] 投票结果: \y%s\w (%d票)，5秒后换图", szMap, iMaxVotes);
		
		// 5秒后换图
		set_task(5.0, "ChangeToVotedMap", iBestMap);
	} else {
		// 随机换图
		new iRand = random(g_iMapCount);
		new szMap[32];
		ArrayGetString(g_aMaps, iRand, szMap, charsmax(szMap));
		
		client_print_color(0, print_team_blue, "[SemiClip] 无提名地图，随机选择: \y%s", szMap);
		set_task(5.0, "ChangeToVotedMap", iRand);
	}
	
	// 重置投票
	ResetVotes();
}

public ChangeToVotedMap(iMapIdx) {
	if (iMapIdx < 0 || iMapIdx >= g_iMapCount) return;
	
	new szMap[32];
	ArrayGetString(g_aMaps, iMapIdx, szMap, charsmax(szMap));
	
	server_cmd("changelevel %s", szMap);
	server_exec();
}

ResetVotes() {
	for (new i = 0; i < 128; i++)
		g_iNominationCount[i] = 0;
	
	for (new i = 1; i <= 32; i++) {
		g_iNominated[i] = -1;
		g_bHasRtv[i] = false;
	}
	
	g_iTotalNominations = 0;
	g_iRtvCount = 0;
}

showVoteStatus(id) {
	new szMsg[512], len;
	new szMap[32];
	
	len = formatex(szMsg[len], charsmax(szMsg) - len, "[SemiClip] 当前投票情况:^n");
	
	new bool:bHasVotes = false;
	for (new i = 0; i < g_iMapCount; i++) {
		if (g_iNominationCount[i] > 0) {
			ArrayGetString(g_aMaps, i, szMap, charsmax(szMap));
			len += formatex(szMsg[len], charsmax(szMsg) - len, "  %s: %d票^n", szMap, g_iNominationCount[i]);
			bHasVotes = true;
		}
	}
	
	if (!bHasVotes) {
		len += formatex(szMsg[len], charsmax(szMsg) - len, "  暂无提名^n");
	}
	
	new iPlayers = get_playersnum();
	new iNeeded = max(1, floatround(iPlayers * 0.66));
	len += formatex(szMsg[len], charsmax(szMsg) - len, "RTV: %d/%d", g_iRtvCount, iNeeded);
	
	client_print_color(id, print_team_blue, szMsg);
}

// ==================== 个人开关 ====================
public cmdToggleSemiclip(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	
	g_bPlayerOff[id] = !g_bPlayerOff[id];
	
	if (g_bPlayerOff[id])
		client_print_color(id, print_team_blue, "[SemiClip] 个人穿透: \y关闭");
	else
		client_print_color(id, print_team_blue, "[SemiClip] 个人穿透: \y开启");
	
	return PLUGIN_HANDLED;
}

public client_disconnected(id) {
	// 取消该玩家的提名
	if (g_iNominated[id] >= 0 && g_iNominated[id] < g_iMapCount) {
		g_iNominationCount[g_iNominated[id]]--;
		if (g_iNominationCount[g_iNominated[id]] < 0)
			g_iNominationCount[g_iNominated[id]] = 0;
		g_iTotalNominations--;
	}
	
	if (g_bHasRtv[id])
		g_iRtvCount--;
	
	g_iNominated[id] = -1;
	g_bHasRtv[id] = false;
	g_bPlayerOff[id] = false;
}

public client_authorized(id) {
	g_iNominated[id] = -1;
	g_bHasRtv[id] = false;
	g_bPlayerOff[id] = false;
}

// ==================== 辅助函数 ====================
getModeName(szBuf[], len) {
	switch (g_iMode) {
		case MODE_AUTO:      copy(szBuf, len, "自动识别(Skill开/其他关)");
		case MODE_FORCE_ON:  copy(szBuf, len, "管理员强制开启");
		case MODE_FORCE_OFF: copy(szBuf, len, "管理员强制关闭");
	}
}
