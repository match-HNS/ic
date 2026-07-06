#if defined _cmds_included
  #endinput
#endif

#define _cmds_included

stock cmds_init() {
	register_clcmd("say", "sayHandle");

	register_clcmd("nightvision", "cmdMainMenu");

	register_clcmd("chooseteam", 	"cmdMainMenu");
	register_clcmd("jointeam", 		"blockCmd");
	register_clcmd("joinclass", 	"blockCmd");

	new iWatcherAccess = read_flags(g_szWatcherFlag);

	RegisterSayCmd("mix", 	"mix", 	"cmdMainMenu",	iWatcherAccess, "Main menu admin");
	RegisterSayCmd("mode", 	"type", "menuSelectMode",	iWatcherAccess, "Mode match menu");
	RegisterSayCmd("menu", 	"me", 	"cmdMainMenu",	0, "Main menu (all players)");

	RegisterSayCmd("mr", 		"maxround", 	"cmdMrMode",		iWatcherAccess, "Choose MR mode");
	RegisterSayCmd("timer", 	"wintime", 		"cmdWintimeMode",	iWatcherAccess, "Choose Wintime mode");
	RegisterSayCmd("duel", 		"versus", 		"cmdDuelMode",		iWatcherAccess, "Choose 1x1 mode");
	RegisterSayCmd("pub", 		"public", 		"cmdPubMode", 		iWatcherAccess, "Public mode");
	RegisterSayCmd("dm", 		"deathmatch", 	"cmdDMMode", 		iWatcherAccess, "DeathMatch mode");
	RegisterSayCmd("zm", 		"zombie", 		"cmdZMMode", 		iWatcherAccess, "Zombie mode");
	RegisterSayCmd("bld", 		"blend", 		"cmdBlend", 		iWatcherAccess, "Blend teams");
	RegisterSayCmd("specall", 	"specall", 		"cmdTransferSpec", 	iWatcherAccess, "Spec Transfer");
	RegisterSayCmd("ttall", 	"ttall", 		"cmdTransferTT", 	iWatcherAccess, "TT Transfer");
	RegisterSayCmd("ctall", 	"ctall", 		"cmdTransferCT", 	iWatcherAccess, "CT Transfer");
	RegisterSayCmd("startmix", 	"start", 		"cmdStartMatch", 	iWatcherAccess, "Starts Round");
	RegisterSayCmd("kniferound", "kf", 			"cmdKnifeRound", 	iWatcherAccess, "Knife Round");
	RegisterSayCmd("captain", 	"cap", 			"cmdCaptain", 		iWatcherAccess, "Captain Mode");
	RegisterSayCmd("stop", 		"cancel", 		"cmdStopMode", 		iWatcherAccess, "Stop Current Mode");
	RegisterSayCmd("skill", 	"skill", 		"cmdSkillMode", 	iWatcherAccess, "Skill mode");
	RegisterSayCmd("boost", 	"boost", 		"cmdBoostMode", 	iWatcherAccess, "Boost mode");
	RegisterSayCmd("semiclip", "sem", 			"cmdSemiClip", 		0, "Toggle semi-clip");
	RegisterSayCmd("semiclipmenu", "scm", 		"cmdSemiClipMenu", ADMIN_CFG, "SemiClip admin menu");
	RegisterSayCmd("unban", "unban", 			"cmdDeserterUnban", ADMIN_CFG, "Unban deserter");
	RegisterSayCmd("deserter", "ds", 			"cmdDeserterCheck", ADMIN_CFG, "Check deserter status");
	RegisterSayCmd("leave", "quitmatch", 		"cmdLeaveMatch", 0, "Leave match without penalty");
	RegisterSayCmd("matchctrl", "mc", 			"cmdMatchControl", 0, "Match control menu");
	RegisterSayCmd("approve", "ap", 			"cmdApproveLeave", iWatcherAccess, "Approve leave request");
	RegisterSayCmd("deny", "dn", 				"cmdDenyLeave", iWatcherAccess, "Deny leave request");
	RegisterSayCmd("sub", "substitute", 		"cmdAddSubstitute", iWatcherAccess, "Add substitute player");
	RegisterSayCmd("matchadmin", "mca", 		"cmdMatchControlAdmin", iWatcherAccess, "Match control admin menu");
	RegisterSayCmd("rr", 		"restart", 		"cmdRestartRound", 	iWatcherAccess, "Restart round");
	RegisterSayCmd("swap", 		"swap", 		"cmdSwapTeams", 	iWatcherAccess, "Swap Teams");
	RegisterSayCmd("pause", 	"ps", 			"cmdStartPause", 	iWatcherAccess, "Start pause");
	RegisterSayCmd("live", 		"unpause", 		"cmdStopPause",		iWatcherAccess, "Unpause");
	RegisterSayCmd("surrender", "sur", 			"cmdSurrender", 	0, "Surrender vote");
	RegisterSayCmd("score", 	"s", 			"cmdShowTimers", 	0, "Score");
	RegisterSayCmd("back", 		"spec", 		"cmdTeamSpec", 		0, "Spec/Back player");
	RegisterSayCmd("pick", 		"pick", 		"pickMenu", 		0, "Pick player");
	RegisterSayCmd("np", 		"noplay", 		"cmdNoplay", 		0, "No play");
	RegisterSayCmd("ip", 		"play", 		"cmdPlay", 			0, "Play");
	RegisterSayCmd("save", 		"sv", 		"Save_d", 			0, "Show top");
	RegisterSayCmd("load", 		"ld", 		"Load_d", 			0, "Show top");
	RegisterSayCmd("training", 	"tr", 		"cmdTrainingMenuEntry", 0, "Training menu");
}

public sayHandle(id) {
	new szArgs[64];

	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);

	if (!szArgs[0])
		return PLUGIN_HANDLED;

	if (szArgs[0] != '/')
		return PLUGIN_CONTINUE;

	new szTarget[32];

	parse(szArgs, \
		  szArgs, charsmax(szArgs), \
		  szTarget, charsmax(szTarget));

	if (equali(szArgs, "/roundtime", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;

		if (is_str_num(szTarget)) {
			set_round_time(szTarget);
			chat_print(0, "^3%n^1 set ^3roundtime^1 to ^3%.2f^1 minutes.", id, str_to_float(szTarget));
		}
		return PLUGIN_CONTINUE;
	}

	if (equali(szArgs, "/mr", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;
			
		if (g_iCurrentMode != MODE_MIX) {
			chat_print(id, "You can only change maxrounds during a match!");
			return PLUGIN_HANDLED;
		}

		if (!is_str_num(szTarget))
			return PLUGIN_CONTINUE;

		if (str_to_num(szTarget) > 0) {
			g_iSettings[MAXROUNDS] = str_to_num(szTarget);
			chat_print(0, "^3%n^1 set ^3maxrounds^1 to ^3%d^1 (^3%d^1 rounds).", id, str_to_num(szTarget), str_to_num(szTarget) * 2);
		}
		return PLUGIN_CONTINUE;
	}

	if (equali(szArgs, "/wintime", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;
			
		if (g_iCurrentMode != MODE_MIX) {
			chat_print(id, "You can only change wintime during a match!");
			return PLUGIN_HANDLED;
		}

		if (!is_str_num(szTarget))
			return PLUGIN_CONTINUE;

		if (str_to_float(szTarget) >= 0.0) {
			g_eMatchInfo[e_mWintime] = str_to_float(szTarget);
			cvar_update_wintime(g_eMatchInfo[e_mWintime]);
			
			chat_print(0, "^3%n^1 set ^3wintime^1 to ^3%d^1 minutes.", id, str_to_num(szTarget));
		}
		return PLUGIN_CONTINUE;
	}

	if (equali(szArgs, "/tt", 10) || equali(szArgs, "/ct", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;

		if (g_iCurrentMode != MODE_MIX)
			return PLUGIN_HANDLED;

		new bIsTT = equali(szArgs, "/tt", 10);
		new szMinutes[12], szSeconds[12];
		replace(szTarget, charsmax(szTarget), ":", " ");
		replace(szTarget, charsmax(szTarget), ".", " ");

		if (parse(szTarget, szMinutes, charsmax(szMinutes), szSeconds, charsmax(szSeconds)) < 2) {
			chat_print(id, "Неверный синтаксис. Пример: ^3/%s 15:43^1", bIsTT ? "tt" : "ct");
			return PLUGIN_HANDLED;
		}

		if (!szMinutes[0] || !szSeconds[0] || !is_str_num(szMinutes) || !is_str_num(szSeconds)) {
			chat_print(id, "Неверный синтаксис. Пример: ^3/%s 15:43^1", bIsTT ? "tt" : "ct");
			return PLUGIN_HANDLED;
		}

		new iMinutes = str_to_num(szMinutes);
		new iSeconds = str_to_num(szSeconds);

		if (iSeconds >= 60) {
			chat_print(id, "Неверный синтаксис. Пример: ^3/%s 15:43^1", bIsTT ? "tt" : "ct");
			return PLUGIN_HANDLED;
		}

		new HNS_TEAM:iTeam = bIsTT ? g_isTeamTT : HNS_TEAM:!g_isTeamTT;
		new Float:flInputTime = float(iMinutes) * 60.0 + float(iSeconds);
		new Float:flTeamTime = flInputTime;
		if (g_iCurrentRules == RULES_TIMER) {
			new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
			flTeamTime = flCapTime - flInputTime;
		}
		g_eMatchInfo[e_flSidesTime][iTeam] = flTeamTime;

		new szTime[8];
		formatex(szTime, charsmax(szTime), "%02d:%02d", iMinutes, iSeconds);
		if (bIsTT) {
			chat_print(0, "^3%n^1 set ^3TT^1 time to ^3%s^1.", id, szTime)
		} else {
			chat_print(0, "^3%n^1 set ^3CT^1 time to ^3%s^1.", id, szTime);
		}
		return PLUGIN_CONTINUE;
	}

	return PLUGIN_CONTINUE;
}

public blockCmd(id) {
	// 只在比赛激活时阻止换队
	if (g_eMatchState == STATE_ENABLED || g_eMatchState == STATE_PAUSED) {
		// During match: force to spectator
		if (is_user_connected(id) && get_member(id, m_iTeam) != TEAM_SPECTATOR) {
			rg_internal_cmd(id, "jointeam", "6");
		}
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public cmdMrMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentRules == RULES_MR) {
		chat_print(0, "The mode is already set.");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(0, "Cannot change rules during a match!");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 changed mode to ^3MR^1!", id);
	g_iCurrentRules = RULES_MR;
	set_pcvar_string(pCvar[GAMENAME], "HNS Mix [MR]");

	return PLUGIN_HANDLED;
}

public cmdWintimeMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentRules == RULES_TIMER) {
		chat_print(0, "This mode already started!");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(0, "This command is not available during the match!");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 changed mode to ^3Wintime^1!", id);
	g_iCurrentRules = RULES_TIMER;
	set_pcvar_string(pCvar[GAMENAME], "HNS Mix [Wintime]");

	return PLUGIN_HANDLED;
}

public cmdDuelMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentRules == RULES_DUEL) {
		chat_print(0, "This mode already started!");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(0, "This command is not available during the match!");
		return PLUGIN_HANDLED;
	}

	if (get_num_players_in_match() > 2) {
		chat_print(0, "You need 1 player per team to start a duel.");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 changed mode to ^3Duel^1!", id);
	g_iCurrentRules = RULES_DUEL;
	set_pcvar_string(pCvar[GAMENAME], "HNS Mix [Duel]");

	return PLUGIN_HANDLED;
}

public cmdPubMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_PUB) {
		chat_print(id, "Public mode is already active.");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iMatchStatus != MATCH_NONE) {
		chat_print(id, "Public mode has been cancelled.");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 has activated ^3public^1 mode.", id);

	pub_start();

	return PLUGIN_HANDLED;
}

public cmdDMMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_DM) {
		chat_print(id, "DeathMatch mode is already active.");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iMatchStatus != MATCH_NONE) {
		chat_print(id, "DeathMatch mode has been cancelled.");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 has activated ^3deatchmatch^1 mode.", id);

	dm_start();

	return PLUGIN_HANDLED;
}

public cmdZMMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_ZM) {
		chat_print(id, "Zombie mode is already active.");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iMatchStatus != MATCH_NONE) {
		chat_print(id, "Zombie mode has been cancelled.");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 has activated ^3zombie^1 mode.", id);

	zm_start();

	return PLUGIN_HANDLED;
}

public cmdBlend(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_ZM) {
		chat_print(0, "^3%n^1 blended the teams.", id);
		blendZM();
		return PLUGIN_HANDLED; 
	}

	if (g_iCurrentMode != MODE_PUB && g_iCurrentMode != MODE_DM) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 blended the teams.", id);

	new Players[MAX_PLAYERS], Num;
	get_players(Players, Num, "ch");

	for (new i; i < Num; i++) {
		if (!getUserTeam(Players[i])) {
			Players[i--] = Players[--Num];
		}
	}

	new Player, Team = random(2) ? 1 : 2;
	new Random;

	while (Num) {
		Random = random(Num);
		Player = Players[Random];
		rg_set_user_team(Player, TeamName:Team);
		Players[Random] = Players[--Num];
		Team = (Team % 2 + 1);
	}

	hns_restart_round();
	return PLUGIN_HANDLED;
}

public blendZM() {
	zm_set_teams();
	hns_restart_round(2.0);
}

public cmdTransferSpec(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 transfered all players to ^3spectators^1!", id);

	transferUsers(TEAM_SPECTATOR);
	
	return PLUGIN_HANDLED;
}

public cmdTransferTT(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 transfered all players to ^3terrorist's^1!", id);

	transferUsers(TEAM_TERRORIST);

	return PLUGIN_HANDLED;
}

public cmdTransferCT(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 transfered all players to ^3counter-terrorist's^1!", id);

	transferUsers(TEAM_CT);

	return PLUGIN_HANDLED;
}

public cmdStartMatch(id) {
	if (!isUserWatcher(id) && !is_user_admin(id)) {
		chat_print(id, "You do not have permission to start a match.");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING) {
		chat_print(id, "Please, disable other mode to start mix game.");
		return PLUGIN_HANDLED;
	} 
	
	if (hns_is_knife_map()) {
		chat_print(id, "Cannot start mix match on a knife map. Use captain mode instead.");
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_STARTED)) {
		remove_task(TASK_STARTED);
	}

	if (task_exists(TASK_WAIT)) {
		remove_task(TASK_WAIT);
	}

	if (task_exists(TASK_WAIT_CUP)) {
		remove_task(TASK_WAIT_CUP);
	}

	chat_print(0, "^3%n^1 has started ^3mix^1.", id);

	mix_start();

	return PLUGIN_HANDLED;
}

public cmdKnifeRound(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING) {
		chat_print(id, "Cannot start knife round right now.");
		return PLUGIN_HANDLED;
	}

	if (g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMKNIFE || g_iMatchStatus == MATCH_CUPKNIFE) {
		chat_print(id, "Knife round is already in progress.");
		return PLUGIN_HANDLED;
	}

	// 只有拼刀地图才能启动拼刀选人（解决boost/其他地图也被拼刀选人的问题）
	if (!hns_is_knife_map()) {
		chat_print(id, "Knife round is only available on knife maps.");
		return PLUGIN_HANDLED;
	}

	chat_print(id, "%n has started the knife round!", id);

	g_iMatchStatus = MATCH_TEAMKNIFE;
	kniferound_start();

	return PLUGIN_HANDLED;
}

public cmdKnifePickBan(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING) {
		chat_print(id, "Пожалуйста, отключите другой режим перед запуском ножевого Pick/Ban.");
		return PLUGIN_HANDLED;
	}

	if (g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMKNIFE || g_iMatchStatus == MATCH_CUPKNIFE) {
		chat_print(id, "Ножевой раунд Pick/Ban уже запущен.");
		return PLUGIN_HANDLED;
	}

	chat_print(id, "^3%n^1 запустил ^3ножевой Pick/Ban^1 раунд!", id);

	g_iMatchStatus = MATCH_CUPKNIFE;
	kniferound_start();

	return PLUGIN_HANDLED;
}


public cmdCaptain(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (!hns_is_knife_map()) {
		chat_print(id, "You are not a captain.");
		return PLUGIN_HANDLED;
	}

	if (hns_cup_enabled()) {
		return PLUGIN_HANDLED;
	}

	// if (g_iCurrentMode != MODE_TRAINING) {
	// 	chat_print(id, "Отключите другой режим.");
	// }

	captain_start(id);

	return PLUGIN_HANDLED;
}

public cmdStopMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX || g_iCurrentMode == MODE_ASCENSION || g_iCurrentMode == MODE_VAMP || g_iCurrentMode == MODE_ROUNDS) {
		verifMenu(id);
	} else {
		cmdStop(id);
	}

	return PLUGIN_HANDLED;
}

public cmdStop(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_cup_is_veto_active()) {
		hns_cup_stop_veto();
	}

	if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE) {
		// 比赛刚结束15秒内不切pub，防误触
		if (get_gametime() < g_flTrainingProtect) {
			chat_print(0, "^3%n^1: 比赛刚结束，请等待 %.0f 秒后再切换模式.", id, g_flTrainingProtect - get_gametime());
			return PLUGIN_HANDLED;
		}
		// 退出训练模式，回到公开模式
		chat_print(0, "^3%n^1 stopped ^3training mode^1.", id);
		pub_start();
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_WAIT)) {
		remove_task(TASK_WAIT)
	}

	if (task_exists(TASK_WAIT_CUP)) {
		remove_task(TASK_WAIT_CUP)
	}

	if (g_iCurrentMode == MODE_MIX) {
	    {
	    			mix_stop();	
	    			chat_print(0, "^3%n^1 stopped ^3mix^1.", id);
	    		}
	} else if (g_iCurrentMode == MODE_KNIFE) {
	    {
	    			if (g_iMatchStatus == MATCH_CAPTAINKNIFE) {
	    				resetCaptainData();
	    				chat_print(0, "^3%n^1 stopped ^3captain^1 mode^1.", id);
	    			} else if (g_iMatchStatus == MATCH_CUPKNIFE) {
	    				// TODO: Стоп cup knife

	    			} else {
	    				chat_print(0, "^3%n^1 stopped ^3knife^1 round^1.", id);
	    			}
	    			kniferound_stop();
	    		}
	} else if (g_iCurrentMode == MODE_TRAINING) {
	    {
	    			if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_TEAMPICK) {
	    				resetCaptainData();
	    				g_iMatchStatus = MATCH_NONE;
	    				training_start();
	    				chat_print(0, "^3%n^1 stopped ^3captain^1 mode^1.", id);
	    			} else if (g_iMatchStatus == MATCH_CUPPICK) {
	    				// TODO: Стоп cup pick ban
	    				hns_cup_stop_veto();
	    				g_iMatchStatus = MATCH_NONE;
	    				training_start();
	    			} else if (g_iMatchStatus) {
	    				g_iMatchStatus = MATCH_NONE;
	    			}
	    		}
	} else if (g_iCurrentMode == MODE_PUB) {
	    {
	    			training_start();
	    			chat_print(0, "^3%n^1 stopped ^3public^1 mode^1.", id);
	    		}
	} else if (g_iCurrentMode == MODE_DM) {
	    {
	    			training_start();
	    			chat_print(0, "^3%n^1 stopped ^3deathmatch^1 mode^1.", id);
	    		}
	} else if (g_iCurrentMode == MODE_ZM) {
	    {
	    			training_start();
	    			chat_print(0, "^3%n^1 stopped ^3zombie^1 mode^1.", id);
	    		}
	} else if (g_iCurrentMode == MODE_ASCENSION) {
	    {
	    			ascension_stop();
	    			chat_print(0, "Ascension mode stopped.");
	    		}
	} else if (g_iCurrentMode == MODE_VAMP) {
	    {
	    			vamp_stop();
	    			chat_print(0, "Vampire mode stopped.");
	    		}
	} else if (g_iCurrentMode == MODE_ROUNDS) {
	    {
	    			rounds_stop();
	    			chat_print(0, "Rounds mode stopped.");
	    		}
	}

	rg_send_audio(0, "fvox/fuzz.wav");

	return PLUGIN_HANDLED;
}

public cmdSkillMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 has activated ^3skill^1 mode.", id);

	if (g_iCurrentMode == MODE_MIX) {
		set_cvar_num("mp_freezetime", 5);
		g_iSettings[FLASH] = 1;
		g_iSettings[SMOKE] = 1;
	}

	g_iSettings[HNSBOOST] = 0;

	if (g_iCurrentMode == MODE_TRAINING)
		set_semiclip(SEMICLIP_ON);
	else
		set_semiclip(SEMICLIP_ON, true);

	return PLUGIN_HANDLED;
}

public cmdSemiClip(id) {
	semiclip_toggle(id);
	return PLUGIN_HANDLED;
}

public cmdSemiClipMenu(id) {
	semiclip_menu(id);
	return PLUGIN_HANDLED;
}

public cmdDeserterUnban(id) {
	new szArg[32];
	read_argv(1, szArg, charsmax(szArg));
	new target = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF);
	if (!target) {
		client_print(id, print_chat, "[HNS] Player not found.");
		return PLUGIN_HANDLED;
	}
	deserter_admin_unban(id, target);
	return PLUGIN_HANDLED;
}

public cmdDeserterCheck(id) {
	new szArg[32];
	read_argv(1, szArg, charsmax(szArg));
	new target = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF);
	if (!target) {
		client_print(id, print_chat, "[HNS] Player not found.");
		return PLUGIN_HANDLED;
	}
	deserter_admin_check(id, target);
	return PLUGIN_HANDLED;
}

public cmdLeaveMatch(id) {
	// Only works during active match
	if (g_iCurrentMode != MODE_MIX && g_iCurrentMode != MODE_ASCENSION && g_iCurrentMode != MODE_VAMP) {
		client_print(id, print_chat, "[HNS] No active match.");
		return PLUGIN_HANDLED;
	}

	if (!g_ePlayerInfo[id][PLAYER_MATCH]) {
		client_print(id, print_chat, "[HNS] You are not in the match.");
		return PLUGIN_HANDLED;
	}

	// Excuse leave - no penalty
	if (!deserter_excuse_leave(id)) {
		new Float:flCd = deserter_get_leave_cooldown(id);
		client_print(id, print_chat, "[HNS] Wait %.0f seconds before using /leave again.", flCd);
		return PLUGIN_HANDLED;
	}

	// Notify
	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	chat_print(0, "[HNS] %n left the match (no penalty).", id);

	// Transfer to spec
	transferUserToSpec(id);
	return PLUGIN_HANDLED;
}

public cmdMatchControl(id) {
	matchControl_player_menu(id);
	return PLUGIN_HANDLED;
}

public cmdMatchControlAdmin(id) {
	matchControl_admin_menu(id);
	return PLUGIN_HANDLED;
}

public cmdApproveLeave(id) {
	new szArg[32];
	read_argv(1, szArg, charsmax(szArg));
	new target = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF);
	if (!target) {
		client_print(id, print_chat, "[HNS] Player not found.");
		return PLUGIN_HANDLED;
	}
	matchControl_approve_leave(id, target);
	return PLUGIN_HANDLED;
}

public cmdDenyLeave(id) {
	new szArg[32];
	read_argv(1, szArg, charsmax(szArg));
	new target = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF);
	if (!target) {
		client_print(id, print_chat, "[HNS] Player not found.");
		return PLUGIN_HANDLED;
	}
	matchControl_deny_leave(id, target);
	return PLUGIN_HANDLED;
}

public cmdAddSubstitute(id) {
	new szArg[32];
	read_argv(1, szArg, charsmax(szArg));
	new target = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF);
	if (!target) {
		client_print(id, print_chat, "[HNS] Player not found.");
		return PLUGIN_HANDLED;
	}
	matchControl_add_substitute(id, target);
	return PLUGIN_HANDLED;
}

public cmdBoostMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 has activated ^3boost^1 mode.", id);

	if (g_iCurrentMode == MODE_MIX) {
		set_cvar_num("mp_freezetime", 15);
		g_iSettings[FLASH] = 3;
		g_iSettings[SMOKE] = 1;
	}

	g_iSettings[HNSBOOST] = 1;

	// Semiclip boost override is handled by semiclip.inc (semiclip_should_apply checks g_bSemiClipAdminOverride)

	return PLUGIN_HANDLED;
}

public cmdRestartRound(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 did restart!", id);

	hns_restart_round();

	return PLUGIN_HANDLED;
}

public cmdSwapTeams(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_cup_enabled() && hns_is_knife_map()) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "^3%n^1 swapped teams!", id);

	if (g_iCurrentMode == MODE_MIX) {
		mix_reverttimer(); // TODO: Доработать
	}

	hns_swap_teams();

	hns_restart_round(0.5);

	return PLUGIN_HANDLED;
}

public cmdStartPause(id) {
	// ★ 防重复：1秒内不允许重复暂停
	new Float:flNow = get_gametime();
	if (flNow - g_flLastPauseTime < 1.0) {
		return PLUGIN_HANDLED;
	}
	g_flLastPauseTime = flNow;

	if (!isUserWatcher(id)) {
		client_print(id, print_chat, "[Pause] 你没有权限暂停!");
		return PLUGIN_HANDLED;
	}

	if (g_eMatchState == STATE_PAUSED) {
		client_print(id, print_chat, "[Pause] 比赛已经暂停了!");
		return PLUGIN_HANDLED;
	}

	// ★ 直接用 if-else 调用，避免 Pawn switch fall-through
	if (g_iCurrentMode == MODE_MIX) {
		mix_pause();
	} else if (g_iCurrentMode == MODE_KNIFE) {
		kniferound_pause();
	} else if (g_iCurrentMode == MODE_ASCENSION) {
		ascension_pause();
	} else if (g_iCurrentMode == MODE_VAMP) {
		vamp_pause();
	} else if (g_iCurrentMode == MODE_ROUNDS) {
		rounds_pause();
	} else if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE], _);
	} else {
		client_print(id, print_chat, "[Pause] 当前模式不支持暂停!");
		return PLUGIN_HANDLED;
	}

	client_cmd(0, "spk fvox/deactivated.wav");
	chat_print(0, "^3%n^1 paused the game!", id);

	return PLUGIN_HANDLED;
}

public cmdStopPause(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (g_eMatchState != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	// ★ 直接用 if-else 调用，避免 switch fall-through
	if (g_iCurrentMode == MODE_MIX) {
		mix_unpause();
	} else if (g_iCurrentMode == MODE_KNIFE) {
		kniferound_unpause();
	} else if (g_iCurrentMode == MODE_ASCENSION) {
		ascension_unpause();
	} else if (g_iCurrentMode == MODE_VAMP) {
		vamp_unpause();
	} else if (g_iCurrentMode == MODE_ROUNDS) {
		rounds_unpause();
	} else if (g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE], _);
	} else {
		return PLUGIN_HANDLED;
	}

	client_cmd(0, "spk fvox/activated.wav");
	chat_print(0, "^3%n^1 unpaused the game!", id);

	return PLUGIN_HANDLED;
}

public cmdSurrender(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (g_iCurrentMode != MODE_MIX)
		return PLUGIN_HANDLED;

	if (!getUserInMatch(id))
		return PLUGIN_HANDLED;

	if (g_eSurrenderData[e_sStarted])
		return PLUGIN_HANDLED;

	if (g_eSurrenderData[e_sFlDelay] > get_gametime()) {
		new szTime[24];
		fnConvertTime(g_eSurrenderData[e_sFlDelay] - get_gametime(), szTime, 23, false);
		chat_print(id, "Surrender is not available for another %s.", szTime);
		return PLUGIN_HANDLED;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT");

	if (iNum != g_eMatchInfo[e_mTeamSizeTT])
		return PLUGIN_HANDLED;

	g_eSurrenderData[e_sStarted] = true;
	g_eSurrenderData[e_sInitiator] = id;
	g_eSurrenderData[e_sFlDelay] = get_gametime() + g_iSettings[SURTIMEDELAY];
	chat_print(0, "Player ^3%n^1 (^3%s^1) started vote for surrender!", id, getUserTeam(id) == TEAM_TERRORIST ? "TERRORISTS" : "CTS");

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		surrenderMenu(iPlayer);
	}
	set_task(1.0, "taskSurrender", TASK_SURRENDER, .flags = "b");

	return PLUGIN_HANDLED;
}

public cmdShowTimers(id) {
	if (g_iCurrentMode != MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	new szTimeToWin[HNS_TEAM][24], szTimeDiff[24];

	new Float:fTimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	fnConvertTime(fTimeDiff, szTimeDiff, charsmax(szTimeDiff), false);

	if (g_iCurrentRules == RULES_MR) {
	    {
	    			fnConvertTime(Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B], szTimeToWin[HNS_TEAM_B], 23);
	    			fnConvertTime(Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A], szTimeToWin[HNS_TEAM_A], 23);

	    			new iPlayers[MAX_PLAYERS], TTsize, CTSize;
	    			get_players(iPlayers, TTsize, "che", "TERRORIST");
	    			get_players(iPlayers, CTSize, "che", "CT");
	    			if (g_isTeamTT == HNS_TEAM_A) {
	    				chat_print(id, "TT [^3%s^1] %d vs %d [^3%s^1] CT (^3%d^1/^3%d^1 rounds) (^3%s^1 diff)",
	    					szTimeToWin[HNS_TEAM_A], TTsize, CTSize, szTimeToWin[HNS_TEAM_B],
	    					(g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B]) + 1, g_iSettings[MAXROUNDS] * 2,
	    					szTimeDiff);
	    			} else {
	    				chat_print(id, "TT [^3%s^1] %d vs %d [^3%s^1] CT (^3%d^1/^3%d^1 rounds) (^3%s^1 diff)",
	    					szTimeToWin[HNS_TEAM_B], TTsize, CTSize, szTimeToWin[HNS_TEAM_A],
	    					(g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A]) + 1, g_iSettings[MAXROUNDS] * 2,
	    					szTimeDiff);
	    			}
	    		}
	} else if (g_iCurrentRules == RULES_TIMER) {
	    {
	    			new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
	    			new Float:flTimeToWinA = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A]);
	    			new Float:flTimeToWinB = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B]);
	    			fnConvertTime(flTimeToWinA, szTimeToWin[HNS_TEAM_A], 23);
	    			fnConvertTime(flTimeToWinB, szTimeToWin[HNS_TEAM_B], 23);
	    			if (g_isTeamTT == HNS_TEAM_A) {
	    				chat_print(id, "TT [^3%s^1] vs [^3%s^1] CT (^3%s^1 diff)", szTimeToWin[HNS_TEAM_A], szTimeToWin[HNS_TEAM_B], szTimeDiff);
	    			} else {
	    				chat_print(id, "TT [^3%s^1] vs [^3%s^1] CT (^3%s^1 diff)", szTimeToWin[HNS_TEAM_B], szTimeToWin[HNS_TEAM_A], szTimeDiff);
	    			}
	    		}
	} else if (g_iCurrentRules == RULES_DUEL) {
	    {
	    			new Float:flScoreA = Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A];
	    			new Float:flScoreB = Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B];

	    			new ttPlayers[MAX_PLAYERS], ctPlayers[MAX_PLAYERS], ttNum, ctNum;
	    			get_players(ttPlayers, ttNum, "he", "TERRORIST");
	    			get_players(ctPlayers, ctNum, "he", "CT");

	    			new iPlayerA, iPlayerB;
	    			if (g_isTeamTT == HNS_TEAM_A) {
	    				iPlayerA = ttPlayers[0];
	    				iPlayerB = ctPlayers[0];
	    			} else {
	    				iPlayerA = ctPlayers[0];
	    				iPlayerB = ttPlayers[0];
	    			}

	    			new szTime[24];
	    			fnConvertTime(g_flPointsMatchTime, szTime, charsmax(szTime), false);

	    			chat_print(id, "Points: ^3%n^1 ^4%.1f^1 vs ^4%.1f^1 ^3%n^1 | Time: ^3%s", iPlayerA, flScoreA, flScoreB, iPlayerB, szTime);
	    		}
	}

	return PLUGIN_HANDLED;
}

public cmdTeamSpec(id) {
	if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)) { // Переделать
		if (getUserTeam(id) == TEAM_SPECTATOR) {
			new iNumTT = get_playersnum_ex(GetPlayers_MatchTeam, "TERRORIST");
			new iNumCT = get_playersnum_ex(GetPlayers_MatchTeam, "CT");
			if (iNumTT == iNumCT && g_eSpecBack[id] != TEAM_UNASSIGNED) {
				rg_set_user_team(id, g_eSpecBack[id]);
			} else if (iNumTT < iNumCT) {
				rg_set_user_team(id, TEAM_TERRORIST);
			} else {
				rg_set_user_team(id, TEAM_CT);
			}
			if (g_iCurrentMode == MODE_PUB) {
				if (rg_is_player_can_respawn(id)) {
					rg_round_respawn(id);
				}
			} else {
				rg_round_respawn(id);
			}
		} else {
			g_eSpecBack[id] = getUserTeam(id);
			transferUserToSpec(id);
		}
	}
}

public cmdNoplay(id) {
	if (!g_bNoplay[id]) {
		g_bNoplay[id] = true;
		chat_print(0, "^3%n^1 is ^3not available^1 for pick. [^3NOPLAY^1]", id);
	}
}

public cmdPlay(id) {
	if (g_bNoplay[id]) {
		g_bNoplay[id] = false;
		chat_print(0, "^3%n^1 is now ^3available^1 for pick. [^3PLAY^1]", id);
	}
}

stock RegisterSayCmd(const szCmd[], const szShort[], const szFunc[], flags = -1, szInfo[] = "") {
	new szTemp[65], szInfoLang[65];
	copy(szInfoLang, 64, szInfo);

	format(szTemp, 64, "say /%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say /%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	return 1;
}

// Training menu entry point (delegates to hnsmenu.inc)
public cmdTrainingMenuEntry(id) {
	if (!is_user_connected(id))
		return;
	showTrainingMenu(id);
}
