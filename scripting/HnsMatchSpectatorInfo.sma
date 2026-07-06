#include <amxmodx>
#include <reapi>
#include <geoip>

#include <hns_matchsystem>
#include <hns_matchsystem_filter>
#include <hns_matchsystem_dbmysql>
#include <hns_matchsystem_api>
#include <hns_matchsystem_stats>

#include <reapi_reunion>

new g_iHudSync;

public plugin_natives() {
	set_native_filter("match_system_additons");
}

public plugin_init() {
	register_plugin("Match: Spectator Info", "4.0.4", "LINNA");

	g_iHudSync = CreateHudSyncObj();

	set_task(1.0, "task_ShowSpectatorInfo", .flags = "b");
}

public task_ShowSpectatorInfo() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];

		if (!is_user_connected(id)) {
			continue;
		}

		// Only show for spectators (not alive players)
		if (is_user_alive(id)) {
			continue;
		}

		// Must be in spectator team
		if (get_user_team(id) != TEAM_SPECTATOR) {
			continue;
		}

		// Get spectated target
		new iTarget = get_entvar(id, var_iuser2);

		if (!iTarget || !is_user_connected(iTarget)) {
			continue;
		}

		// Don't show info for other spectators
		if (!is_user_alive(iTarget)) {
			continue;
		}

		new szHud[512], iLen;

		// === Identity tag and player name ===
		new szTag[32] = "";
		new iColorR = 255, iColorG = 255, iColorB = 255; // default white

		if (isUserAdmin(iTarget)) {
			szTag = "[Admin]";
			iColorR = 255; iColorG = 50; iColorB = 50; // red
		} else if (isUserFullWatcher(iTarget)) {
			szTag = "[FullWatcher]";
			iColorR = 255; iColorG = 50; iColorB = 50; // red
		} else if (isUserWatcher(iTarget)) {
			szTag = "[Watcher]";
			iColorR = 0; iColorG = 255; iColorB = 255; // cyan
		}

		// Steam / Non-Steam - 简化检测，只显示"玩家"标签
	new szSteamTag[16] = "[玩家]";

		// Line 1: [Tag] PlayerName (#Rank) [Steam/Non-Steam]
		if (hns_mysql_stats_init()) {
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"%s %n (#%d) %s^n",
				szTag, iTarget,
				hns_mysql_stats_data(iTarget, e_iTop),
				szSteamTag);
		} else {
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"%s %n %s^n",
				szTag, iTarget,
				szSteamTag);
		}

		// === Country (GeoIP) ===
		new szIp[16], szCountry[46];
		get_user_ip(iTarget, szIp, charsmax(szIp), 1);

		if (geoip_country(szIp, szCountry, charsmax(szCountry))) {
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"^3[%s]^n", szCountry);
		} else {
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"^3[Unknown]^n");
		}

		// === Match stats (only if MySQL available) ===
		if (hns_mysql_stats_init()) {
			new iWins = hns_mysql_stats_data(iTarget, e_iWins);
			new iLoss = hns_mysql_stats_data(iTarget, e_iLoss);
			new iTotal = iWins + iLoss;
			new Float:fWinRate = iTotal > 0 ? (float(iWins) / float(iTotal) * 100.0) : 0.0;
			new iPts = hns_mysql_stats_data(iTarget, e_iPts);
			new iRank = hns_mysql_stats_data(iTarget, e_iTop);
			new szSkill[10];
			copy(szSkill, charsmax(szSkill), hns_mysql_stats_skill(iTarget));

			// Line 3: PTS: xxx [Skill] | Rank: #x
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"PTS: %d [%s] | Rank: #%d^n",
				iPts, szSkill, iRank);

			// Line 4: W: x / L: x (xx%)
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"W: %d / L: %d (%.0f%%)^n",
				iWins, iLoss, fWinRate);

			// Line 5: Matches: x | Kills: x
			new iKills = hns_get_stats_kills(STATS_ALL, iTarget);
			iLen += formatex(szHud[iLen], sizeof(szHud) - iLen,
				"Matches: %d | Kills: %d",
				iTotal, iKills);
		}

		// Set HUD color based on identity
		set_hudmessage(
			.red = iColorR,
			.green = iColorG,
			.blue = iColorB,
			.x = 0.01,
			.y = 0.25,
			.holdtime = 1.1
		);

		ShowSyncHudMsg(id, g_iHudSync, "%s", szHud);
	}
}
