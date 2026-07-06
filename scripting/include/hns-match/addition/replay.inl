/* =====================================================
 *  Movement Replay System
 *  Record player movements and replay on test bots
 * ===================================================== */

#if defined _replay_included
	#endinput
#endif
#define _replay_included

#define MAX_REPLAY_FRAMES  6000   // ~60 seconds at 0.01s intervals
#define REPLAY_INTERVAL    0.01   // 10ms per frame

// === Replay Frame Data ===
new Float:g_rpOrigin[MAX_REPLAY_FRAMES][3];
new Float:g_rpAngles[MAX_REPLAY_FRAMES][3];
new Float:g_rpVelocity[MAX_REPLAY_FRAMES][3];
new g_rpButtons[MAX_REPLAY_FRAMES];
new g_rpFlags[MAX_REPLAY_FRAMES];
new g_rpMovetype[MAX_REPLAY_FRAMES];
new g_rpFrameCount = 0;

// === Recording State ===
new g_rpRecordPlayer = 0;
new bool:g_rpRecording = false;

// === Replay State ===
new g_rpReplayFrame[MAX_PLAYERS + 1] = {0, ...};
new bool:g_rpReplaying[MAX_PLAYERS + 1] = {false, ...};
new g_rpReplayBot[MAX_PLAYERS + 1] = {0, ...};

// === Forward declarations ===
forward replay_start_recording(id);
forward replay_stop_recording(id);
forward replay_start_replay(id, bot);
forward replay_stop_replay(bot);

// === Start Recording ===
public cmd_StartRecord(id) {
	if (!(get_user_flags(id) & ADMIN_MENU)) {
		client_print(id, print_chat, "[Replay] 管理员专用");
		return PLUGIN_HANDLED;
	}

	if (!is_user_alive(id)) {
		client_print(id, print_chat, "[Replay] 你必须活着才能录制!");
		return PLUGIN_HANDLED;
	}

	if (g_rpRecording) {
		client_print(id, print_chat, "[Replay] 已经在录制中! 输入 /stoprecord 停止");
		return PLUGIN_HANDLED;
	}

	// Reset recording data
	g_rpFrameCount = 0;
	g_rpRecordPlayer = id;
	g_rpRecording = true;

	// Stop any existing replays
	for (new i = 1; i <= MaxClients; i++) {
		if (g_rpReplaying[i]) {
			g_rpReplaying[i] = false;
			g_rpReplayFrame[i] = 0;
		}
	}

	client_print(0, print_chat, "[Replay] ^3%n^1 开始录制动作! 输入 /stoprecord 停止", id);

	// Start recording loop
	set_task(REPLAY_INTERVAL, "task_RecordFrame", id, .flags = "b");

	return PLUGIN_HANDLED;
}

// === Stop Recording ===
public cmd_StopRecord(id) {
	if (!g_rpRecording) {
		client_print(id, print_chat, "[Replay] 没有录制在进行中");
		return PLUGIN_HANDLED;
	}

	if (id != g_rpRecordPlayer && !(get_user_flags(id) & ADMIN_MENU)) {
		client_print(id, print_chat, "[Replay] 只有录制者或管理员可以停止");
		return PLUGIN_HANDLED;
	}

	remove_task(g_rpRecordPlayer);
	g_rpRecording = false;

	client_print(0, print_chat, "[Replay] ^3录制完成!^1 共 %d 帧 (%.1f 秒). 输入 /replay 回放",
		g_rpFrameCount, float(g_rpFrameCount) * REPLAY_INTERVAL);
	g_rpRecordPlayer = 0;

	return PLUGIN_HANDLED;
}

// === Record One Frame ===
public task_RecordFrame(id) {
	if (!g_rpRecording || g_rpFrameCount >= MAX_REPLAY_FRAMES) {
		if (g_rpFrameCount >= MAX_REPLAY_FRAMES) {
			client_print(g_rpRecordPlayer, print_chat, "[Replay] 录制达到上限 (%d 帧), 自动停止", MAX_REPLAY_FRAMES);
		}
		remove_task(id);
		g_rpRecording = false;
		return;
	}

	if (!is_user_alive(id)) {
		client_print(0, print_chat, "[Replay] ^3%n^1 死亡, 录制自动停止 (%d 帧)", id, g_rpFrameCount);
		remove_task(id);
		g_rpRecording = false;
		return;
	}

	new iFrame = g_rpFrameCount;

	pev(id, pev_origin, g_rpOrigin[iFrame]);
	pev(id, pev_angles, g_rpAngles[iFrame]);
	pev(id, pev_velocity, g_rpVelocity[iFrame]);
	g_rpButtons[iFrame] = pev(id, pev_button);
	g_rpFlags[iFrame] = pev(id, pev_flags);
	g_rpMovetype[iFrame] = pev(id, pev_movetype);

	g_rpFrameCount++;
}

// === Start Replay ===
public cmd_StartReplay(id) {
	if (!(get_user_flags(id) & ADMIN_MENU)) {
		client_print(id, print_chat, "[Replay] 管理员专用");
		return PLUGIN_HANDLED;
	}

	if (g_rpFrameCount == 0) {
		client_print(id, print_chat, "[Replay] 没有录制数据! 先输入 /record 录制");
		return PLUGIN_HANDLED;
	}

	if (g_rpRecording) {
		client_print(id, print_chat, "[Replay] 录制中不能回放! 先 /stoprecord");
		return PLUGIN_HANDLED;
	}

	// Create a bot for replay
	new iBot = BotCreate(CT_TEAM);
	if (!iBot) {
		client_print(id, print_chat, "[Replay] 创建回放机器人失败!");
		return PLUGIN_HANDLED;
	}

	// Unfreeze bot for replay
	if (task_exists(iBot))
		remove_task(iBot);
	set_pev(iBot, pev_maxspeed, 1.0);
	set_pev(iBot, pev_flags, pev(iBot, pev_flags) & ~FL_FROZEN);

	// Setup replay state
	g_rpReplayFrame[iBot] = 0;
	g_rpReplaying[iBot] = true;
	g_rpReplayBot[iBot] = iBot;

	// Set initial position
	engfunc(EngFunc_SetOrigin, iBot, g_rpOrigin[0]);
	set_pev(iBot, pev_angles, g_rpAngles[0]);
	set_pev(iBot, pev_v_angle, g_rpAngles[0]);
	set_pev(iBot, pev_fixangle, 1);

	client_print(0, print_chat, "[Replay] ^3%n^1 开始回放录制动作! (%d 帧)", id, g_rpFrameCount);

	// Start replay loop
	set_task(REPLAY_INTERVAL, "task_ReplayFrame", iBot, .flags = "b");

	return PLUGIN_HANDLED;
}

// === Stop All Replays ===
public cmd_StopReplay(id) {
	if (!(get_user_flags(id) & ADMIN_MENU)) {
		client_print(id, print_chat, "[Replay] 管理员专用");
		return PLUGIN_HANDLED;
	}

	new iCount = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (g_rpReplaying[i]) {
			remove_task(i);
			g_rpReplaying[i] = false;
			g_rpReplayFrame[i] = 0;
			iCount++;
		}
	}

	if (iCount == 0) {
		client_print(id, print_chat, "[Replay] 没有回放在进行中");
	} else {
		client_print(0, print_chat, "[Replay] 已停止 %d 个回放", iCount);
	}

	return PLUGIN_HANDLED;
}

// === Replay One Frame ===
public task_ReplayFrame(iBot) {
	if (!g_rpReplaying[iBot]) {
		remove_task(iBot);
		return;
	}

	new iFrame = g_rpReplayFrame[iBot];

	if (iFrame >= g_rpFrameCount) {
		// Replay finished - loop back to beginning
		g_rpReplayFrame[iBot] = 0;
		engfunc(EngFunc_SetOrigin, iBot, g_rpOrigin[0]);
		set_pev(iBot, pev_angles, g_rpAngles[0]);
		set_pev(iBot, pev_v_angle, g_rpAngles[0]);
		set_pev(iBot, pev_fixangle, 1);
		set_pev(iBot, pev_velocity, Float:{0.0, 0.0, 0.0});
		return;
	}

	// Apply frame data
	engfunc(EngFunc_SetOrigin, iBot, g_rpOrigin[iFrame]);

	set_pev(iBot, pev_angles, g_rpAngles[iFrame]);
	set_pev(iBot, pev_v_angle, g_rpAngles[iFrame]);

	// Only apply velocity for frames with FL_ONGROUND (jump trajectories)
	// This prevents the bot from sliding due to velocity interpolation
	if (g_rpFlags[iFrame] & FL_ONGROUND) {
		set_pev(iBot, pev_velocity, Float:{0.0, 0.0, 0.0});
	} else {
		set_pev(iBot, pev_velocity, g_rpVelocity[iFrame]);
	}

	set_pev(iBot, pev_fixangle, 1);

	g_rpReplayFrame[iBot]++;
}

// === Cleanup on bot disconnect ===
stock replay_on_disconnect(id) {
	if (g_rpReplaying[id]) {
		remove_task(id);
		g_rpReplaying[id] = false;
		g_rpReplayFrame[id] = 0;
	}
	if (g_rpRecording && g_rpRecordPlayer == id) {
		remove_task(id);
		g_rpRecording = false;
		g_rpRecordPlayer = 0;
	}
}