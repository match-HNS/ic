#if defined _afk_included
  #endinput
#endif

#define _afk_included

const TASK_AFK = 77832;
const TASK_AFK_STOP = 77833;

#define AFK_STOP_SECONDS 30

enum _:AfkData_s {
	bool:is_afk,
	afk_timer
};

new eAfkData[MAX_PLAYERS + 1][AfkData_s];
new iPlayersAfk;
new bool:g_bAllAfkWarned;

new Float:flAfkOrigin[MAX_PLAYERS + 1][3];

public taskCheckAfk() {
	if(task_exists(TASK_AFK)) {
		return;
	}

	if (g_eMatchState != STATE_ENABLED) {
		ResetAfkData();
		return;
	}

	if (g_iCurrentMode != MODE_MIX && g_iMatchStatus != MATCH_TEAMKNIFE && g_iMatchStatus != MATCH_CUPKNIFE) {
		ResetAfkData();
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	iPlayersAfk = 0;
	get_players(iPlayers, iNum, "ach");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (PlayerIsAfk(id)) {
			eAfkData[id][is_afk] = true;
			iPlayersAfk++;
		}
	}

	if (iPlayersAfk) {
		// 检查是否所有比赛玩家都挂机
		if (iPlayersAfk >= iNum && iNum > 0) {
			if (!g_bAllAfkWarned) {
				chat_print(0, "[AFK] 所有人都挂机了！%d秒后自动停止比赛...", AFK_STOP_SECONDS);
				g_bAllAfkWarned = true;
				set_task(float(AFK_STOP_SECONDS), "taskAfkAutoStop", TASK_AFK_STOP);
			}
		}

		new szNames[256], iLen;
		for (new i; i < iNum; i++) {
			new pid = iPlayers[i];
			if (eAfkData[pid][is_afk]) {
				new szName[32]; get_user_name(pid, szName, 31);
				if (iLen > 0) iLen += format(szNames[iLen], 255 - iLen, ", ");
				iLen += format(szNames[iLen], 255 - iLen, "%s", szName);
			}
		}
		chat_print(0, "[AFK] %d 挂机玩家: %s — 使用 /pause 暂停比赛", iPlayersAfk, szNames);
		set_task(5.0, "taskCheckAfk");
	} else {
		// 有人回来了，取消自动停止
		if (g_bAllAfkWarned) {
			g_bAllAfkWarned = false;
			if (task_exists(TASK_AFK_STOP))
				remove_task(TASK_AFK_STOP);
			chat_print(0, "[AFK] 玩家已恢复，取消自动停止比赛");
		}
		set_task(5.0, "taskCheckAfk");
	}
}

// 所有人挂机30秒后自动停止比赛
public taskAfkAutoStop() {
	if (g_eMatchState != STATE_ENABLED) return;

	chat_print(0, "[AFK] 所有人挂机超过%d秒，比赛已自动停止", AFK_STOP_SECONDS);

	// 停止当前比赛模式
	if (g_iCurrentMode == MODE_MIX) {
		mix_stop();
	} else if (g_iCurrentMode == MODE_KNIFE) {
		cmdStop(0);
	} else {
		cmdStop(0);
	}

	g_bAllAfkWarned = false;
}

public taskAfk() {
	if (g_eMatchState != STATE_PAUSED) {
		ResetAfkData();
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum, szBuffer[512];
	get_players(iPlayers, iNum, "ch");

	add(szBuffer, charsmax(szBuffer), "AFK Players [wait time]:^n");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];
		new szTime[16];

		if (eAfkData[id][is_afk]) {
			if (getUserTeam(id) == TEAM_SPECTATOR || !is_user_alive(id)) {
				arrayset(eAfkData[id], 0, AfkData_s);
				arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
				iPlayersAfk--;
				continue;
			}

			if (!PlayerIsAfk(id)) {
				arrayset(eAfkData[id], 0, AfkData_s);
				arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
				iPlayersAfk--;
			} else {
				eAfkData[id][afk_timer]++;
				fnConvertTime(eAfkData[id][afk_timer] * 1.0, szTime, 23, false);
				add(szBuffer, charsmax(szBuffer), fmt("%n (%s)^n", id, szTime));
			}
		}
	}

	if (!iPlayersAfk) {
		if (g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE])
			ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE], _);
			
		chat_print(0, "Match unpaused! All players are back.");

		if(task_exists(TASK_AFK))
			remove_task(TASK_AFK);
	} else {
		set_dhudmessage(.red = 100, .green = 100, .blue = 100, .x = 0.80, .y = 0.10, .holdtime = 1.05);
		show_dhudmessage(0, "%s", szBuffer);
	}
}

ResetAfkData() {
	if(task_exists(TASK_AFK)) {
		remove_task(TASK_AFK);
	}

	if(task_exists(TASK_AFK_STOP)) {
		remove_task(TASK_AFK_STOP);
	}

	iPlayersAfk = 0;
	g_bAllAfkWarned = false;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(eAfkData[id], 0, AfkData_s);
		arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
	}
}

stock bool:PlayerIsAfk(id) {
	new Float:origin[3]; get_entvar(id, var_origin, origin);

	if (getUserTeam(id) == TEAM_CT && get_member_game(m_bFreezePeriod)) {
		flAfkOrigin[id][0] = origin[0];
		flAfkOrigin[id][1] = origin[1];
		flAfkOrigin[id][2] = origin[2];
		return false;
	}

	if (get_distance_f(flAfkOrigin[id], origin) <= 1.0)
		return true;

	return false;
}

public taskSaveAfk() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ach");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];
		get_entvar(id, var_origin, flAfkOrigin[id]);
	}
}
