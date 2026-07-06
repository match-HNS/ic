#if defined _natives_included
  #endinput
#endif

#define _natives_included

register_hns_natives() {
	register_native("hns_get_prefix", "native_get_prefix");
	register_native("hns_get_flag_watcher", "native_flag_watcher");
	register_native("hns_get_flag_fullwatcher", "native_flag_fullwatcher");
	register_native("hns_get_flag_admin", "native_get_flag_admin");

	register_native("hns_get_mode", "native_get_mode");
	register_native("hns_set_mode", "native_set_mode");

	register_native("hns_get_status", "native_get_status");
	register_native("hns_get_state", "native_get_state");

	register_native("hns_get_rules", "native_get_rules");

	register_native("hns_isboost", "native_hns_isboost");

	register_native("hns_get_score_a", "native_get_score_a");
	register_native("hns_get_score_b", "native_get_score_b");

	register_native("hns_get_is_team_tt", "native_get_is_team_tt");

	register_native("hns_get_point_distance", "native_get_point_distance");
	register_native("hns_get_players_distance", "native_get_players_distance");

	register_native("hns_deserter_is_banned", "native_deserter_is_banned");
	register_native("hns_deserter_get_remaining", "native_deserter_get_remaining");
	register_native("hns_deserter_get_count", "native_deserter_get_count");

	// 旧版 HD 菜单兼容 native
	register_native("mix_start", "native_mix_start");
	register_native("mix_stop", "native_mix_stop");
	register_native("mix_pause", "native_mix_pause");
	register_native("mix_unpause", "native_mix_unpause");
	register_native("mix_restartround", "native_mix_restartround");
	register_native("mix_roundstart", "native_mix_roundstart");
	register_native("mix_roundend", "native_mix_roundend");
	register_native("mix_freezeend", "native_mix_freezeend");
	register_native("mix_swap", "native_mix_swap");
	register_native("mix_killed", "native_mix_killed");
	register_native("mix_falldamage", "native_mix_falldamage");

	set_native_filter("match_system_additons");
}

public native_get_prefix(amxx, params) {
	enum { argPrefix = 1, argLen };
	new szPrefix[24];
	format(szPrefix, charsmax(szPrefix), "[^3%s^1]", g_szPrefix);
	set_string(argPrefix, szPrefix, get_param(argLen));
}

public native_flag_watcher(amxx, params) {
	return read_flags(g_szWatcherFlag);
}

public native_flag_fullwatcher(amxx, params) {
	return read_flags(g_szFullWatcherFlag);
}

public native_get_flag_admin(amxx, params) {
	return read_flags(g_szAdminFlag);
}

public native_get_mode(amxx, params) {
	return g_iCurrentMode;
}

public native_set_mode(amxx, params) {
	enum { iSetMode = 1 };
	switch (get_param(iSetMode)) {
		case MODE_TRAINING: {
			training_start();
		}
		case MODE_KNIFE: {
			kniferound_start();
		}
		case MODE_PUB: {
			pub_start();
		}
		case MODE_DM: {
			dm_start();
		}
		case MODE_ZM: {
			zm_start();
		}
		case MODE_MIX: {
			mix_start();
		}
		case MODE_ASCENSION: {
			ascension_start();
		}
		case MODE_VAMP: {
			vamp_start();
		}
	}
}

public Float:native_get_score_a() {
	return Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A];
}

public Float:native_get_score_b() {
	return Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B];
}

public HNS_TEAM:native_get_is_team_tt() {
	return g_isTeamTT;
}

public native_get_point_distance() {
	return g_iPointsDistance;
}

public native_get_players_distance() {
	return g_iPlayerDistance;
}

public bool:native_deserter_is_banned(amxx, params) {
	enum { arg_id = 1 };
	return deserter_is_banned(get_param(arg_id));
}

public native_deserter_get_remaining(amxx, params) {
	enum { arg_id = 1 };
	return deserter_get_ban_remaining(get_param(arg_id));
}

public native_deserter_get_count(amxx, params) {
	enum { arg_id = 1 };
	new id = get_param(arg_id);
	return g_iDesertCount[id];
}

public native_hns_isboost() {
	return g_iSettings[HNSBOOST];
}

// ============================================
// 旧版 HD 菜单兼容 native - 转发到模式函数
// ============================================
public native_mix_start() { mix_start(); }
public native_mix_stop() { mix_stop(); }
public native_mix_pause() { mix_pause(); }
public native_mix_unpause() { mix_unpause(); }
public native_mix_restartround() { mix_restartround(); }
public native_mix_roundstart() { mix_roundstart(); }
public native_mix_freezeend() { mix_freezeend(); }
public native_mix_swap() { mix_swap(); }
public native_mix_roundend(amxx, params) {
	enum { argWin = 1 };
	mix_roundend(bool:get_param(argWin));
}
public native_mix_killed(amxx, params) {
	enum { argVictim = 1, argKiller = 2 };
	mix_killed(get_param(argVictim), get_param(argKiller));
}
public native_mix_falldamage(amxx, params) {
	enum { argId = 1, argDmg = 2 };
	mix_falldamage(get_param(argId), Float:get_param_f(argDmg));
}