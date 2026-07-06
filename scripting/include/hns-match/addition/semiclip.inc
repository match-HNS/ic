#if defined _semiclip_included
	#endinput
#endif
#define _semiclip_included

// === SemiClip System ===
// 仅同队玩家之间互相穿透，并支持按 hns-maps.ini 自动识别 skill 图
// v5.7: 改用 FM_PlayerPreThink + SOLID_NOT 方式，不依赖 ReGameDLL

#define SEMICLIP_MODE_OFF 0
#define SEMICLIP_MODE_ON 1
#define SEMICLIP_MODE_AUTO 2

new g_iSemiClipEnabled = 1;
new g_iSemiClipMode = SEMICLIP_MODE_AUTO;
new bool:g_bPlayerSemiClip[MAX_PLAYERS + 1] = {true, ...};

// === Initialization ===
stock semiclip_init() {
	new pCvar = get_cvar_pointer("hns_semiclip_enabled");
	if (pCvar) {
		bind_pcvar_num(pCvar, g_iSemiClipEnabled);
	}

	pCvar = get_cvar_pointer("hns_semiclip_mode");
	if (pCvar) {
		bind_pcvar_num(pCvar, g_iSemiClipMode);
	}

	register_forward(FM_ShouldCollide, "fwSemiClipShouldCollide");
}

stock bool:semiclip_is_player_valid(id) {
	return (id >= 1 && id <= MaxClients && is_user_connected(id));
}

stock bool:semiclip_is_map_auto_enabled() {
	return hnsmatch_maps_is_skill();
}

stock bool:semiclip_is_effective_enabled() {
	if (!g_iSemiClipEnabled) {
		return false;
	}

	switch (g_iSemiClipMode) {
		case SEMICLIP_MODE_ON: {
			return true;
		}
		case SEMICLIP_MODE_AUTO: {
			return semiclip_is_map_auto_enabled();
		}
	}

	return false;
}

stock bool:semiclip_should_apply_player(id) {
	if (!semiclip_is_effective_enabled()) {
		return false;
	}

	if (!semiclip_is_player_valid(id) || !is_user_alive(id)) {
		return false;
	}

	if (!g_bPlayerSemiClip[id]) {
		return false;
	}

	new TeamName:iTeam = getUserTeam(id);
	if (iTeam == TEAM_SPECTATOR || iTeam == TEAM_UNASSIGNED) {
		return false;
	}

	return true;
}

stock bool:semiclip_should_ignore_collision(id, other) {
	if (id == other) {
		return false;
	}

	if (id < 1 || id > MaxClients || other < 1 || other > MaxClients) {
		return false;
	}

	// ★ NOCLIP 虚体模式：无条件穿透
	if (get_entvar(id, var_movetype) == MOVETYPE_NOCLIP || get_entvar(other, var_movetype) == MOVETYPE_NOCLIP) {
		return true;
	}

	if (!semiclip_should_apply_player(id) || !semiclip_should_apply_player(other)) {
		return false;
	}

	new TeamName:iTeam = getUserTeam(id);
	new TeamName:iOtherTeam = getUserTeam(other);

	if (iTeam != iOtherTeam) {
		return false;
	}

	return true;
}

// === FM_ShouldCollide 兜底 ===
public fwSemiClipShouldCollide(id, other) {
	if (!semiclip_should_ignore_collision(id, other)) {
		return FMRES_IGNORED;
	}

	forward_return(FMV_CELL, 0);
	return FMRES_SUPERCEDE;
}

// 旧接口保留为空（HnsMatchSemiClip.amxx 已接管 SOLID_NOT 穿透）
stock semiclip_prethink(id) {}
stock semiclip_postthink(id) {}

stock semiclip_get_mode_name(iMode, szBuffer[], iLen) {
	switch (iMode) {
		case SEMICLIP_MODE_OFF: copy(szBuffer, iLen, "管理员强制关闭");
		case SEMICLIP_MODE_ON: copy(szBuffer, iLen, "管理员强制开启");
		default: copy(szBuffer, iLen, "自动识别");
	}
}

stock semiclip_get_map_type_name(szBuffer[], iLen) {
	if (hnsmatch_maps_is_skill()) {
		copy(szBuffer, iLen, "Skill");
		return;
	}

	if (hnsmatch_maps_is_boost()) {
		copy(szBuffer, iLen, "Boost");
		return;
	}

	if (hnsmatch_maps_is_knife()) {
		copy(szBuffer, iLen, "Knife");
		return;
	}

	copy(szBuffer, iLen, "Other");
}

stock semiclip_get_effect_reason(szBuffer[], iLen) {
	switch (g_iSemiClipMode) {
		case SEMICLIP_MODE_ON: copy(szBuffer, iLen, "管理员强制开启");
		case SEMICLIP_MODE_AUTO: {
			if (hnsmatch_maps_is_skill()) {
				copy(szBuffer, iLen, "自动识别为 Skill 图，已开启");
			} else {
				copy(szBuffer, iLen, "当前不是 Skill 图，自动关闭");
			}
		}
		default: copy(szBuffer, iLen, "管理员强制关闭");
	}
}

stock semiclip_cycle_mode() {
	switch (g_iSemiClipMode) {
		case SEMICLIP_MODE_AUTO: g_iSemiClipMode = SEMICLIP_MODE_ON;
		case SEMICLIP_MODE_ON: g_iSemiClipMode = SEMICLIP_MODE_OFF;
		default: g_iSemiClipMode = SEMICLIP_MODE_AUTO;
	}
}

stock semiclip_sync_cvars() {
	set_cvar_num("hns_semiclip_enabled", g_iSemiClipEnabled);
	set_cvar_num("hns_semiclip_mode", g_iSemiClipMode);
}

// === Player toggle command ===
stock semiclip_toggle(id) {
	if (!semiclip_is_player_valid(id)) {
		return;
	}

	g_bPlayerSemiClip[id] = !g_bPlayerSemiClip[id];

	if (g_bPlayerSemiClip[id]) {
		client_print(id, print_chat, "[HNS] 队友穿透个人开关：开启。");
	} else {
		client_print(id, print_chat, "[HNS] 队友穿透个人开关：关闭。");
	}

	if (!semiclip_is_effective_enabled()) {
		client_print(id, print_chat, "[HNS] 当前全局未生效，自动模式仅在 Skill 地图开启。");
	}
}

// === SemiClip Menu ===
stock semiclip_menu(id) {
	if (!(get_user_flags(id) & ADMIN_CFG)) {
		client_print(id, print_chat, "[HNS] 仅管理员可用。");
		return;
	}

	new szMenu[640], len;
	new szMode[32], szMapType[32], szReason[64];

	semiclip_get_mode_name(g_iSemiClipMode, szMode, charsmax(szMode));
	semiclip_get_map_type_name(szMapType, charsmax(szMapType));
	semiclip_get_effect_reason(szReason, charsmax(szReason));

	len = formatex(szMenu, charsmax(szMenu), "\r[HNS] \w队友穿透菜单^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r地图类型: \y%s^n", szMapType);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r当前模式: \y%s^n", szMode);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r当前效果: \y%s^n", semiclip_is_effective_enabled() ? "已开启" : "已关闭");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r原因: \y%s^n^n", szReason);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w 模式切换: \y%s^n", szMode);
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\d循环: 自动识别 -> 管理员强制开启 -> 管理员强制关闭^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\d说明: 自动模式只在 Skill 图开启，其他地图关闭。^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\d所以在 Skill 图也可以被管理员强制开启或强制关闭。^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\d玩家可用 /semiclip 切个人开关。^n^n");
	len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w 退出");

	show_menu(id, (1<<0)|(1<<9), szMenu, -1, "SemiClipMenu");
}

public handleSemiClipMenu(id, key) {
	if (!(get_user_flags(id) & ADMIN_CFG)) return;

	if (key == 0) {
		semiclip_cycle_mode();

		g_iSemiClipEnabled = (g_iSemiClipMode != SEMICLIP_MODE_OFF);
		semiclip_sync_cvars();

		new szMode[32];
		semiclip_get_mode_name(g_iSemiClipMode, szMode, charsmax(szMode));
		client_print(0, print_chat, "[HNS] 队友穿透模式已切换为：%s。", szMode);
	}

	if (key != 9) semiclip_menu(id);
}

// === Settings ===
stock semiclip_set_enabled(iEnabled) {
	g_iSemiClipEnabled = iEnabled ? 1 : 0;
	g_iSemiClipMode = iEnabled ? SEMICLIP_MODE_ON : SEMICLIP_MODE_OFF;
	semiclip_sync_cvars();
}

stock semiclip_is_enabled() {
	return semiclip_is_effective_enabled();
}

stock semiclip_set_team(iTeam) {
	// 兼容旧接口：队友穿透已固定为仅同队生效，此设置不再使用
}