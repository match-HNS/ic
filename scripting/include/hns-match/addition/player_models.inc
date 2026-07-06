#if defined _player_models_included
	#endinput
#endif
#define _player_models_included

#include <reapi>

#define MAX_AUTHID_LENGTH 64
#define Invalid_Array -1

// === Player Model System ===
// Allows players to choose custom T/CT models, saved via PDS

#define MAX_MODEL_NAME 64
#define MAX_MODELS_PER_TEAM 32
#define MODEL_MENU_PAGE_SIZE 7

// Available models for T and CT teams
new Array:g_aTModels;
new Array:g_aCTModels;

// Player's selected model index (-1 = default)
new g_iPlayerTModel[MAX_PLAYERS + 1] = {-1, ...};
new g_iPlayerCTModel[MAX_PLAYERS + 1] = {-1, ...};

// Temp variable to track which team's model list is being shown
new g_iModelSelectTeam[MAX_PLAYERS + 1];

// === Initialization ===
stock player_models_init() {
	g_aTModels = ArrayCreate(MAX_MODEL_NAME, 1);
	g_aCTModels = ArrayCreate(MAX_MODEL_NAME, 1);

	// Load default T models
	ArrayPushString(g_aTModels, "arctic");
	ArrayPushString(g_aTModels, "guerilla");
	ArrayPushString(g_aTModels, "leet");
	ArrayPushString(g_aTModels, "terror");

	// Load default CT models
	ArrayPushString(g_aCTModels, "gign");
	ArrayPushString(g_aCTModels, "gsg9");
	ArrayPushString(g_aCTModels, "sas");
	ArrayPushString(g_aCTModels, "urban");
	// ArrayPushString(g_aCTModels, "spetsnaz"); // CS:CZ only, not available in CS 1.6
	ArrayPushString(g_aCTModels, "vip");

	// Load custom models from config
	player_models_load_config();
}

stock player_models_load_config() {
	new szPath[256];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	format(szPath, charsmax(szPath), "%s/mixsystem/player_models.ini", szPath);

	new f = fopen(szPath, "rt");
	if (!f) return;

	new szLine[128], szKey[32], szValue[MAX_MODEL_NAME];
	new szSection[32];
	new bool:bInT = false, bool:bInCT = false;

	while (!feof(f)) {
		fgets(f, szLine, charsmax(szLine));
		trim(szLine);

		if (szLine[0] == ';' || szLine[0] == '/' && szLine[1] == '/' || szLine[0] == 0)
			continue;

		if (szLine[0] == '[') {
			// Section header - remove [ and ]
			new len = strlen(szLine);
			if (szLine[len-1] == ']')
				szLine[--len] = 0;
			if (szLine[0] == '[')
				copy(szLine, charsmax(szLine), szLine[1]);
			if (equali(szLine, "Terrorist") || equali(szLine, "T") || equali(szLine, "TT")) {
				bInT = true;
				bInCT = false;
			} else if (equali(szLine, "Counter-Terrorist") || equali(szLine, "CT")) {
				bInCT = true;
				bInT = false;
			} else {
				bInT = false;
				bInCT = false;
			}
			continue;
		}

		// Parse "model_path" or "model_path = display_name"
		strtok(szLine, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
		trim(szKey);
		trim(szValue);

		if (szKey[0] == 0) continue;

		if (bInT) {
			ArrayPushString(g_aTModels, szKey);
		} else if (bInCT) {
			ArrayPushString(g_aCTModels, szKey);
		}
	}
	fclose(f);
}

// === Save/Load player model selection ===
stock player_models_save(id) {
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));

	new szKey[64];
	format(szKey, charsmax(szKey), "model_%s_t", szAuth);
	PDS_SetCell(szKey, g_iPlayerTModel[id]);

	format(szKey, charsmax(szKey), "model_%s_ct", szAuth);
	PDS_SetCell(szKey, g_iPlayerCTModel[id]);
}

stock player_models_load(id) {
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));

	new szKey[64], data;
	format(szKey, charsmax(szKey), "model_%s_t", szAuth);
	if (PDS_GetCell(szKey, data))
		g_iPlayerTModel[id] = data;

	format(szKey, charsmax(szKey), "model_%s_ct", szAuth);
	if (PDS_GetCell(szKey, data))
		g_iPlayerCTModel[id] = data;
}

// === Apply model on spawn ===
// NOTE: If HnsMatchSkin.amxx is loaded, skip model setting here
// to avoid conflict with the advanced skin system.
stock player_models_apply(id) {
	if (!is_user_connected(id)) return;
	
	// Check if advanced skin plugin is active (cvar set by HnsMatchSkin)
	if (cvar_exists("hns_skin_advanced") && get_cvar_num("hns_skin_advanced") == 1) {
		return;
	}

	new TeamName:iTeam = getUserTeam(id);

	if (iTeam == TEAM_TERRORIST && g_iPlayerTModel[id] >= 0) {
		new iSize = ArraySize(g_aTModels);
		if (g_iPlayerTModel[id] < iSize) {
			new szModel[MAX_MODEL_NAME];
			ArrayGetString(g_aTModels, g_iPlayerTModel[id], szModel, charsmax(szModel));
			rg_set_user_model(id, szModel, true);
		}
	} else if (iTeam == TEAM_CT && g_iPlayerCTModel[id] >= 0) {
		new iSize = ArraySize(g_aCTModels);
		if (g_iPlayerCTModel[id] < iSize) {
			new szModel[MAX_MODEL_NAME];
			ArrayGetString(g_aCTModels, g_iPlayerCTModel[id], szModel, charsmax(szModel));
			rg_set_user_model(id, szModel, true);
		}
	}
}

// === Reset model to default ===
stock player_models_reset(id) {
	// ReAPI: set empty string resets to default
	rg_set_user_model(id, "");
}

// === Menu ===
stock playerModelsMenu(id) {
	new hMenu = menu_create("\r[HNS] \wPlayer Models", "handlePlayerModelsMenu");

	new szItem[128];

	// T model selection
	new szTModel[MAX_MODEL_NAME];
	if (g_iPlayerTModel[id] >= 0 && g_iPlayerTModel[id] < ArraySize(g_aTModels)) {
		ArrayGetString(g_aTModels, g_iPlayerTModel[id], szTModel, charsmax(szTModel));
	} else {
		copy(szTModel, charsmax(szTModel), "Default");
	}
	format(szItem, charsmax(szItem), "T Model: \y%s", szTModel);
	menu_additem(hMenu, szItem, "1");

	// CT model selection
	new szCTModel[MAX_MODEL_NAME];
	if (g_iPlayerCTModel[id] >= 0 && g_iPlayerCTModel[id] < ArraySize(g_aCTModels)) {
		ArrayGetString(g_aCTModels, g_iPlayerCTModel[id], szCTModel, charsmax(szCTModel));
	} else {
		copy(szCTModel, charsmax(szCTModel), "Default");
	}
	format(szItem, charsmax(szItem), "CT Model: \y%s", szCTModel);
	menu_additem(hMenu, szItem, "2");

	// Reset to default
	menu_additem(hMenu, "\rReset to Default", "3");

	menu_additem(hMenu, "\wBack", "0");

	menu_setprop(hMenu, MPROP_EXITNAME, "Exit");
	menu_display(id, hMenu, 0);
}

public handlePlayerModelsMenu(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		mainMatchMenu(id);
		return;
	}

	new szData[2], iAccess, hCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), _, _, hCallback);
	menu_destroy(hMenu);

	new iChoice = str_to_num(szData);

	if (iChoice == 1) {
		playerModelSelectMenuEx(id, 0);  // T models
	} else if (iChoice == 2) {
		playerModelSelectMenuEx(id, 1);  // CT models
	} else if (iChoice == 3) {
		// Reset
		g_iPlayerTModel[id] = -1;
		g_iPlayerCTModel[id] = -1;
		player_models_save(id);
		player_models_reset(id);
		client_print(id, print_chat, "[HNS] Models reset to default.");
		playerModelsMenu(id);
	} else if (iChoice == 0) {
		mainMatchMenu(id);
	}
}

public handleModelSelectMenu(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		playerModelsMenu(id);
		return;
	}

	if (item == MENU_BACK) {
		menu_destroy(hMenu);
		playerModelsMenu(id);
		return;
	}

	new szData[8], iAccess, hCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), _, _, hCallback);
	menu_destroy(hMenu);

	new iModelIndex = str_to_num(szData);

	// Determine which team menu this was for by checking current page context
	// We pass team via menu title, but since we can't easily retrieve it,
	// we'll use a global temp variable
	if (g_iModelSelectTeam[id] == 0) {
		g_iPlayerTModel[id] = iModelIndex;
	} else {
		g_iPlayerCTModel[id] = iModelIndex;
	}

	player_models_save(id);

	new szModel[MAX_MODEL_NAME];
	if (iModelIndex >= 0) {
		new Array:aModels = g_iModelSelectTeam[id] == 0 ? g_aTModels : g_aCTModels;
		if (iModelIndex < ArraySize(aModels)) {
			ArrayGetString(aModels, iModelIndex, szModel, charsmax(szModel));
		}
	}

	if (iModelIndex >= 0 && szModel[0] != 0) {
		client_print(id, print_chat, "[HNS] %s model set to: %s", g_iModelSelectTeam[id] == 0 ? "T" : "CT", szModel);
	} else {
		client_print(id, print_chat, "[HNS] %s model set to default.", g_iModelSelectTeam[id] == 0 ? "T" : "CT");
	}

	// Apply immediately if on correct team
	new TeamName:iTeam = getUserTeam(id);
	if ((g_iModelSelectTeam[id] == 0 && iTeam == TEAM_TERRORIST) ||
		(g_iModelSelectTeam[id] == 1 && iTeam == TEAM_CT)) {
		if (iModelIndex >= 0) {
			player_models_apply(id);
		} else {
			player_models_reset(id);
		}
	}

	playerModelsMenu(id);
}

// Override playerModelSelectMenu to set team context
stock playerModelSelectMenuEx(id, team) {
	g_iModelSelectTeam[id] = team;

	new szTitle[64];
	format(szTitle, charsmax(szTitle), "\r[HNS] \wSelect %s Model", team == 0 ? "T" : "CT");
	new hMenu = menu_create(szTitle, "handleModelSelectMenu");

	new Array:aModels = team == 0 ? g_aTModels : g_aCTModels;
	new iSize = ArraySize(aModels);
	new szModel[MAX_MODEL_NAME];
	new szItem[128], szData[8];
	new iCurrent = team == 0 ? g_iPlayerTModel[id] : g_iPlayerCTModel[id];

	// Add "Default" option
	format(szItem, charsmax(szItem), "%sDefault", iCurrent == -1 ? "\y" : "\w");
	menu_additem(hMenu, szItem, "-1");

	for (new i = 0; i < iSize; i++) {
		ArrayGetString(aModels, i, szModel, charsmax(szModel));
		num_to_str(i, szData, charsmax(szData));

		if (i == iCurrent) {
			format(szItem, charsmax(szItem), "\y%s", szModel);
		} else {
			format(szItem, charsmax(szItem), "\w%s", szModel);
		}
		menu_additem(hMenu, szItem, szData);
	}

	menu_setprop(hMenu, MPROP_BACKNAME, "Back");
	menu_setprop(hMenu, MPROP_EXITNAME, "Exit");
	menu_display(id, hMenu, 0);
}

// === Cleanup on plugin end ===
stock player_models_cleanup() {
	if (g_aTModels != Invalid_Array) {
		ArrayDestroy(g_aTModels);
		g_aTModels = Invalid_Array;
	}
	if (g_aCTModels != Invalid_Array) {
		ArrayDestroy(g_aCTModels);
		g_aCTModels = Invalid_Array;
	}
}
