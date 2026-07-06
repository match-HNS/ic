/* =====================================================
 *  HNS Test Bots - Standalone Bot Plugin
 *  Spawns stationary bots for wallbang/practice training
 *  Does NOT depend on HnsMatchSystem
 * ===================================================== */

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <reapi>

#define MAX_BOTS_PER_TEAM  5
#define MAX_BOT_NAME_LEN  32
#define PLUGIN_NAME       "HNS Test Bots"
#define PLUGIN_VERSION    "1.0"
#define PLUGIN_AUTHOR     ""

// Team index constants
enum _:BOT_TEAM
{
    BOT_TEAM_CT = 0,
    BOT_TEAM_T
}

// CT player models
new const g_szCTModels[][] =
{
    "gign", "gsg9", "sas", "urban"
};

// T player models
new const g_szTModels[][] =
{
    "terror", "leet", "arctic", "guerilla"
};

new const CT_TEAM = 2;  // CS_TEAM_CT
new const T_TEAM = 1;   // CS_TEAM_T

// Bot tracking arrays
new g_iBotCount[BOT_TEAM_T + 1];
new g_iBotIds[BOT_TEAM_T + 1][MAX_BOTS_PER_TEAM];

// Store model name for each bot (for re-apply after spawn)
new g_szBotModel[MAX_PLAYERS + 1][32];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    // Admin commands: say /testbots
    register_clcmd("say /testbots",   "clcmd_TestBots");
    register_clcmd("say_team /testbots", "clcmd_TestBots");

    // Hook player spawn to configure our bots after they spawn
    RegisterHam(Ham_Spawn, "player", "Ham_Spawn_Post", 1);

    // Hook client_putinserver to auto-set team for bots
    register_clcmd("fullserverinfo", "clcmd_FullServerInfo");

    // ★ 录制回放命令
    register_clcmd("say /record",     "cmd_StartRecord");
    register_clcmd("say_team /record", "cmd_StartRecord");
    register_clcmd("say /stoprecord",  "cmd_StopRecord");
    register_clcmd("say_team /stoprecord", "cmd_StopRecord");
    register_clcmd("say /replay",     "cmd_StartReplay");
    register_clcmd("say_team /replay", "cmd_StartReplay");
    register_clcmd("say /stopreplay",  "cmd_StopReplay");
    register_clcmd("say_team /stopreplay", "cmd_StopReplay");
}

public clcmd_FullServerInfo(const id)
{
    return PLUGIN_HANDLED;
}

public client_disconnected(id) {
    if (IsOurBot(id)) {
        for (new iTeam = 0; iTeam <= BOT_TEAM_T; iTeam++) {
            for (new i = 0; i < g_iBotCount[iTeam]; i++) {
                if (g_iBotIds[iTeam][i] != id) {
                    continue;
                }

                for (new j = i; j < g_iBotCount[iTeam] - 1; j++) {
                    g_iBotIds[iTeam][j] = g_iBotIds[iTeam][j + 1];
                }

                g_iBotIds[iTeam][g_iBotCount[iTeam] - 1] = 0;
                if (g_iBotCount[iTeam] > 0) {
                    g_iBotCount[iTeam]--;
                }
                break;
            }
        }
    }

    replay_on_disconnect(id);
}

/**
 * Menu command handler
 */
public clcmd_TestBots(const iPlayer)
{
    if (!(get_user_flags(iPlayer) & ADMIN_MENU))
    {
        client_print(iPlayer, print_chat, "[HNS Test Bots] 管理员专用");
        return PLUGIN_HANDLED;
    }

    ShowTestBotsMenu(iPlayer);
    return PLUGIN_HANDLED;
}

/**
 * Display the Test Bots control menu
 */
ShowTestBotsMenu(const iPlayer)
{
    new szMenuTitle[128];
    formatex(szMenuTitle, charsmax(szMenuTitle), "\y[HNS] \wTest Bots^n\yCT: \w%d/%d    \yT: \w%d/%d^n^n",
        g_iBotCount[BOT_TEAM_CT], MAX_BOTS_PER_TEAM,
        g_iBotCount[BOT_TEAM_T],  MAX_BOTS_PER_TEAM);

    new iMenu = menu_create(szMenuTitle, "MenuHandler_TestBots");

    menu_additem(iMenu, "创建 CT 机器人", "1", ADMIN_ALL);
    menu_additem(iMenu, "创建 T 机器人", "2", ADMIN_ALL);
    menu_additem(iMenu, "清除所有机器人", "3", ADMIN_ALL);
    menu_additem(iMenu, "随机创建 (1-3个)", "4", ADMIN_ALL);
    menu_additem(iMenu, "开始录制动作", "5", ADMIN_ALL);
    menu_additem(iMenu, "停止录制", "6", ADMIN_ALL);
    menu_additem(iMenu, "回放录制动作", "7", ADMIN_ALL);
    menu_additem(iMenu, "停止回放", "8", ADMIN_ALL);

    menu_setprop(iMenu, MPROP_EXITNAME, "返回");
    menu_display(iPlayer, iMenu, 0);
}

/**
 * Menu item selection handler
 */
public MenuHandler_TestBots(const iPlayer, const iMenu, const iItem)
{
    if (iItem == MENU_EXIT)
    {
        menu_destroy(iMenu);
        return PLUGIN_HANDLED;
    }

    new szData[6], szName[64];
    new iAccess, iCallback;
    menu_item_getinfo(iMenu, iItem, iAccess, szData, charsmax(szData),
        szName, charsmax(szName), iCallback);
    menu_destroy(iMenu);

    switch (str_to_num(szData))
    {
        case 1: BotCreate(CT_TEAM);
        case 2: BotCreate(T_TEAM);
        case 3: BotClearAll();
        case 4: BotRandomCreate();
        case 5: cmd_StartRecord(iPlayer);
        case 6: cmd_StopRecord(iPlayer);
        case 7: cmd_StartReplay(iPlayer);
        case 8: cmd_StopReplay(iPlayer);
    }

    // Re-show menu
    ShowTestBotsMenu(iPlayer);
    return PLUGIN_HANDLED;
}

/**
 * Create a single bot on the given team
 */
BotCreate(const iTeam)
{
    new iTeamIdx = (iTeam == CT_TEAM) ? BOT_TEAM_CT : BOT_TEAM_T;

    // Enforce per-team limit
    if (g_iBotCount[iTeamIdx] >= MAX_BOTS_PER_TEAM)
    {
        client_print(0, print_chat, "[HNS Test Bots] %s 已经到机器人上限 (%d)",
            iTeam == CT_TEAM ? "CT" : "T", MAX_BOTS_PER_TEAM);
        return 0;
    }

    // Build name
    new szBotName[MAX_BOT_NAME_LEN];
    new iSlot = g_iBotCount[iTeamIdx] + 1;

    if (iTeam == CT_TEAM)
        formatex(szBotName, charsmax(szBotName), "[BOT]CT%d", iSlot);
    else
        formatex(szBotName, charsmax(szBotName), "[BOT]T%d", iSlot);

    // Create fake client
    new iBot = engfunc(EngFunc_CreateFakeClient, szBotName);
    if (!iBot)
    {
        log_amx("[HNS] Failed to create bot: %s", szBotName);
        return 0;
    }

    // Required info keys
    set_user_info(iBot, "rate", "3500");
    set_user_info(iBot, "cl_updaterate", "30");
    set_user_info(iBot, "cl_lw", "1");
    set_user_info(iBot, "cl_lc", "1");
    set_user_info(iBot, "_vgui_menus", "0");
    set_user_info(iBot, "_cl_autowepswitch", "0");

    // Connect
    dllfunc(DLLFunc_ClientPutInServer, iBot);

    // Assign team
    cs_set_user_team(iBot, iTeam);

    // Assign model
    new szModel[32];
    if (iTeam == CT_TEAM)
        copy(szModel, charsmax(szModel), g_szCTModels[iSlot % sizeof g_szCTModels]);
    else
        copy(szModel, charsmax(szModel), g_szTModels[iSlot % sizeof g_szTModels]);

    // Store model name for later re-apply
    copy(g_szBotModel[iBot], 31, szModel);

    // Spawn
    ExecuteHamB(Ham_Spawn, iBot);

    // Apply model via ReAPI (fixes bot invisibility)
    rg_set_user_model(iBot, szModel, true);

    // Give default weapon
    if (iTeam == CT_TEAM)
        give_item(iBot, "weapon_usp");
    else
        give_item(iBot, "weapon_glock18");

    // Record
    g_iBotIds[iTeamIdx][g_iBotCount[iTeamIdx]] = iBot;
    g_iBotCount[iTeamIdx]++;

    client_print(0, print_chat, "[HNS Test Bots] 已创建 %s 机器人: %s",
        iTeam == CT_TEAM ? "CT" : "T", szBotName);

    return 1;
}

/**
 * Post-spawn hook
 */
public Ham_Spawn_Post(const iPlayer)
{
    if (!is_user_alive(iPlayer))
        return HAM_IGNORED;

    if (!IsOurBot(iPlayer))
        return HAM_IGNORED;

    // Move to spawn point (先移到位，再冻结)
    new iTeamCS = _:cs_get_user_team(iPlayer);
    new Float:vOrigin[3];

    if (_:iTeamCS == _:CS_TEAM_CT)
        GetSpawnOrigin("info_player_start", vOrigin);
    else
        GetSpawnOrigin("info_player_deathmatch", vOrigin);

    vOrigin[0] += random_float(-30.0, 30.0);
    vOrigin[1] += random_float(-30.0, 30.0);

    // ★ 使用 EngFunc_SetOrigin 而不是 set_pev，确保引擎正确更新位置
    engfunc(EngFunc_SetOrigin, iPlayer, vOrigin);

    // Armor + health
    cs_set_user_armor(iPlayer, 200, CS_ARMOR_VESTHELM);
    set_pev(iPlayer, pev_health, 100.0);

    // Re-apply model after spawn (fixes bot invisibility)
    if (g_szBotModel[iPlayer][0] != EOS) {
        rg_set_user_model(iPlayer, g_szBotModel[iPlayer], true);
    }

    // ★ 延迟冻结，让引擎先完成位置更新和重力沉降
    set_task(0.1, "task_FreezeBot", iPlayer);

    return HAM_IGNORED;
}

public task_FreezeBot(id) {
    if (!is_user_alive(id) || !IsOurBot(id))
        return;

    set_pev(id, pev_maxspeed, 0.01);
    set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
}

/**
 * Find spawn origin by classname
 */
GetSpawnOrigin(const szClassname[], Float:vOrigin[3])
{
    vOrigin[0] = 0.0;
    vOrigin[1] = 0.0;
    vOrigin[2] = 0.0;

    new iEnt = -1;
    while ((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", szClassname)) != 0)
    {
        pev(iEnt, pev_origin, vOrigin);
        return;
    }
}

/**
 * Remove all bots
 */
BotClearAll()
{
    new iMaxPlayers = get_maxplayers();
    new iRemoved = 0;

    for (new i = 1; i <= iMaxPlayers; i++)
    {
        if (is_user_connected(i) && IsOurBot(i))
        {
            new szName[MAX_BOT_NAME_LEN];
            get_user_name(i, szName, charsmax(szName));

            new szCmd[96];
            formatex(szCmd, charsmax(szCmd), "kick ^"%s^"", szName);
            server_cmd(szCmd);
            iRemoved++;
        }
    }

    server_exec();

    g_iBotCount[BOT_TEAM_CT] = 0;
    g_iBotCount[BOT_TEAM_T]  = 0;
    arrayset(g_iBotIds[BOT_TEAM_CT], 0, sizeof(g_iBotIds[]));
    arrayset(g_iBotIds[BOT_TEAM_T], 0, sizeof(g_iBotIds[]));

    client_print(0, print_chat, "[HNS Test Bots] 已清除 %d 个机器人", iRemoved);
}

/**
 * Random create (1-3)
 */
BotRandomCreate()
{
    new iCount = random_num(1, 3);
    for (new i = 0; i < iCount; i++)
    {
        new iTeam = (random_num(0, 1) == 0) ? CT_TEAM : T_TEAM;
        BotCreate(iTeam);
    }
}

/**
 * Check if player is our bot
 */
bool:IsOurBot(const iPlayer)
{
    if (!is_user_connected(iPlayer))
        return false;
    if (!is_user_bot(iPlayer))
        return false;

    for (new iTeam = 0; iTeam <= BOT_TEAM_T; iTeam++) {
        for (new i = 0; i < g_iBotCount[iTeam]; i++) {
            if (g_iBotIds[iTeam][i] == iPlayer) {
                return true;
            }
        }
    }

    return false;
}

// ★ 动作录制回放系统（放最后才能调用 BotCreate）
#include <hns-match/addition/replay.inl>
