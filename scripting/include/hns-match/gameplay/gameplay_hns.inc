new HookChain:fwdResetMaxSpeed;
new bool:g_bHideKnifeModel = false;

// ★ FIX: 飞行手雷查询 native（由 HnsMatchFlyNade.sma 提供）
native hns_flynade_has_nade(id);

enum
{
	LAST_FLASH_NO = 0,
	LAST_FLASH_MENU,
	LAST_FLASH_PICK
}
new g_bLastFlash;

public hns_init()
{
	g_GPFuncs[GAMEPLAY_HNS][GP_ENABLE]		= CreateOneForward(g_PluginId, "hns_enable_rules");
	g_GPFuncs[GAMEPLAY_HNS][GP_DISABLE]		= CreateOneForward(g_PluginId, "hns_disable_rules");
	g_GPFuncs[GAMEPLAY_HNS][GP_SETROLE]		= CreateOneForward(g_PluginId, "hns_setrole", FP_CELL);
	g_GPFuncs[GAMEPLAY_HNS][GP_KILLED]		= CreateOneForward(g_PluginId, "hns_killed", FP_CELL, FP_CELL);
	g_GPFuncs[GAMEPLAY_HNS][GP_ROUNDSTART]	= CreateOneForward(g_PluginId, "hns_roundstart");
	g_GPFuncs[GAMEPLAY_HNS][GP_ROUNDEND]	= CreateOneForward(g_PluginId, "hns_roundend", FP_CELL);
}

public hns_enable_rules()
{
	g_iCurrentGameplay = GAMEPLAY_HNS;

	// Semiclip is handled by semiclip.inc (PreThink/PostThink with SOLID_NOT)
	// Boost maps are handled by semiclip_should_apply()

	g_bHideKnifeModel = true;

	// Register Ham_Item_Deploy for knife model hiding and speed reset
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "hns_item_deploy_post", true);
}

public hns_disable_rules()
{
	g_bHideKnifeModel = false;
	if (fwdResetMaxSpeed)
	{
		DisableHookChain(fwdResetMaxSpeed);
	}
}

public hns_setrole(id)
{
	if (!is_user_connected(id))
		return;

	rg_remove_all_items(id);
	switch (getUserTeam(id))
	{
		case TEAM_TERRORIST:
		{
			rg_give_item(id, "weapon_knife");
			rg_set_user_footsteps(id, true);
			if (g_iSettings[FLASH] >= 1)
			{
				new ent = rg_give_item(id, "weapon_flashbang", GT_APPEND);
				rg_set_iteminfo(ent, ItemInfo_iMaxAmmo1, 10);
				rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_iSettings[FLASH]);
			}

			if (g_iSettings[SMOKE] >= 1)
			{
				new ent = rg_give_item(id, "weapon_smokegrenade");
				rg_set_iteminfo(ent, ItemInfo_iMaxAmmo1, 10);
				rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_iSettings[SMOKE]);
			}
		}
		case TEAM_CT:
		{
			rg_give_item(id, "weapon_knife");
			rg_set_user_footsteps(id, false);
			// ★ FIX: 如果该CT拥有飞行手雷标记，在清空装备后重新补发HE
			if (hns_flynade_has_nade(id)) {
				rg_give_item(id, "weapon_hegrenade");
			}
		}
	}

	if (g_iSettings[ONEHPMODE] == 1)
	{
		set_entvar(id, var_health, 1.0);
	}
}

public hns_killed(victim, attacker)
{
	if (getUserTeam(victim) != TEAM_TERRORIST || g_bLastFlash != LAST_FLASH_NO)
	{
		return;
	}
	
	if (g_iCurrentMode == MODE_DM || !g_iSettings[LASTGRENADE])
	{
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "aech", "TERRORIST");
	if (iNum == 1 && iPlayers[0] != victim)
	{
		g_bLastFlash = LAST_FLASH_MENU;
		NewNadesMenu(iPlayers[0]);
	}
}

public NewNadesMenu(id)
{
	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NADES_TITLE");
	new hMenu = menu_create(szMsg, "NadesHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_YES");
	menu_additem(hMenu, szMsg);

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NO");
	menu_additem(hMenu, szMsg);

	menu_setprop(hMenu, MPROP_PERPAGE, 0);
	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}


public NadesHandler(id, hMenu, item)
{
	if (g_bLastFlash != LAST_FLASH_MENU)
	{
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (!item)
	{
		if (g_iSettings[FLASH] >= 1) 
		{
			if (user_has_weapon(id, CSW_FLASHBANG))
			{
				//ExecuteHam(Ham_GiveAmmo, id, 1, "Flashbang", 1024);
				rg_set_user_bpammo(id, WEAPON_FLASHBANG, rg_get_user_bpammo(id, WEAPON_FLASHBANG) + 1);
			}
			else
			{
				rg_give_item(id, "weapon_flashbang");
			}
		}

		if (g_iSettings[SMOKE] >= 1)
		{
			if (user_has_weapon(id, CSW_SMOKEGRENADE))
			{
				//ExecuteHam(Ham_GiveAmmo, id, 1, "SmokeGrenade", 1024);
				rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, rg_get_user_bpammo(id, WEAPON_SMOKEGRENADE) + 1);
			}
			else
			{
				rg_give_item(id, "weapon_smokegrenade");
			}
		}

		g_bLastFlash = LAST_FLASH_PICK;
	}

	menu_destroy(hMenu);
	return PLUGIN_HANDLED;
}

public hns_roundstart()
{
	g_bLastFlash = LAST_FLASH_NO;
}

public hns_roundend(bool:win_ct)
{
	if (g_iCurrentMode != MODE_MIX && g_iCurrentMode != MODE_ZM && g_iCurrentMode != MODE_ASCENSION && g_iCurrentMode != MODE_VAMP && g_iCurrentMode != MODE_ROUNDS) {
		if (win_ct)
		{
			rg_swap_all_players();
			for (new i = 1; i <= MaxClients; i++) {
				if (is_user_connected(i) && rg_is_player_can_respawn(i))
					rg_round_respawn(i);
			}
		}
	}
}

// 替代 fwd_Player_ResetMaxSpeed_Post - 用 Ham_Item_Deploy 实现
// 兼容无 ReGameDLL 的服务器
public hns_item_deploy_post(id) {
	if (!is_user_alive(id) || getUserTeam(id) != TEAM_TERRORIST)
		return;

	new weapon = get_member(id, m_pActiveItem);
	if (weapon == -1) return;

	set_entvar(id, var_maxspeed, get_member(weapon, m_Weapon_fMaxSpeed));

	// 隐藏 T 的刀模型 + 禁止刀攻击
	if (g_iCurrentMode != MODE_KNIFE)
	{
		new szClass[32];
		get_entvar(weapon, var_classname, szClass, charsmax(szClass));
		if (equal(szClass, "weapon_knife")) {
			if (g_bHideKnifeModel)
				set_entvar(id, var_weaponmodel, 0);
			// T禁止任何刀攻击（不依赖 g_bHideKnifeModel）
			set_member(weapon, m_Weapon_flNextPrimaryAttack, 99999.0);
			set_member(weapon, m_Weapon_flNextSecondaryAttack, 99999.0);
		}
	}
}

