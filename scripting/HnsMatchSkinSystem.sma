/*
 * HNS Match Skin System - 合并皮肤系统插件
 * 合并了: 玩家皮肤 + 管理员皮肤 + M键菜单 + 皮肤发放
 *
 * 功能:
 * 1. 普通玩家皮肤系统 (读取 player_models.ini)
 * 2. 管理员专属皮肤系统 (读取 admin_models.ini, 密码验证 /linna -> 890514)
 * 3. M键玩家菜单 (chooseteam拦截 + /menu命令)
 * 4. 皮肤发放机制 (/give skin, /take skin)
 *
 * 命令:
 * /model, /skin - 打开皮肤菜单
 * /menu - 打开M键主菜单
 * /linna - 管理员皮肤验证
 * /give skin <玩家> <T/CT/Knife> <皮肤名> - 发放皮肤
 * /take skin <玩家> <皮肤名> - 收回皮肤(仅Owner)
 */

#include <amxmodx>
#include <amxmisc>
#include <string>
#include <string_const>
#include <reapi>
#define m_szViewModel (m_szModel + 128)
#include <PersistentDataStorage>

// ============================================================
//  插件信息
// ============================================================
#define PLUGIN_NAME "HNS Match Skin System"
#define PLUGIN_VERSION "5.0.0"
#define PLUGIN_AUTHOR "HNS Match System"

// ============================================================
//  常量定义
// ============================================================
#define MAX_AUTHID_LENGTH    64
#define MAX_MODEL_NAME      128
#define MAX_SKIN_NAME       64
#define MAX_PLAYERS_DATA    512
#define MAX_OWNED_SKINS     64
#define MAX_MENU_PAGE       7
#define MAX_ACCOUNT_NAME    32
#define MAX_ACCOUNT_PASS    64
#define MAX_ACCOUNT_HASH    80
#define Invalid_Array       -1
#define EOS                 0

// 权限等级
#define PERM_NONE           0
#define PERM_VIP            1
#define PERM_ADMIN          2
#define PERM_OWNER          3

// 比赛状态
#define MATCH_NONE          0

// 管理员密码
#define ADMIN_PASSWORD       "890514"
#define ACCOUNT_HASH_SALT    "HNS_MATCH_SKIN_ACCOUNT_V1"

// 菜单ID
#define MENU_PLAYER_MAIN    8001
#define MENU_JOIN_TEAM      8002
#define MENU_SKIN_MAIN       8003
#define MENU_SKIN_SELECT     8004
#define MENU_ADMIN_SKIN      8005
#define MENU_ADMIN_SELECT    8006
#define MENU_GIVE_PLAYER     8007
#define MENU_GIVE_TYPE       8008
#define MENU_GIVE_SKIN       8009

// ============================================================
//  全局变量 - 普通玩家皮肤
// ============================================================
new Array:g_aTModels;          // T模型路径
new Array:g_aTModelNames;     // T模型显示名称
new Array:g_aCTModels;         // CT模型路径
new Array:g_aCTModelNames;    // CT模型显示名称
new Array:g_aKnifeModels;      // 刀模型路径
new Array:g_aKnifeModelNames; // 刀模型显示名称

// 玩家已拥有的皮肤索引数组
new g_iOwnedT[MAX_PLAYERS + 1][MAX_OWNED_SKINS];
new g_iOwnedTCount[MAX_PLAYERS + 1];
new g_iOwnedCT[MAX_PLAYERS + 1][MAX_OWNED_SKINS];
new g_iOwnedCTCount[MAX_PLAYERS + 1];
new g_iOwnedKnife[MAX_PLAYERS + 1][MAX_OWNED_SKINS];
new g_iOwnedKnifeCount[MAX_PLAYERS + 1];

// 玩家当前选择的皮肤索引
new g_iSelectedT[MAX_PLAYERS + 1] = {-1, ...};
new g_iSelectedCT[MAX_PLAYERS + 1] = {-1, ...};
new g_iSelectedKnife[MAX_PLAYERS + 1] = {-1, ...};

// 皮肤选择菜单临时变量
new g_iSkinSelectType[MAX_PLAYERS + 1];   // 0=T, 1=CT, 2=Knife
new g_iSkinSelectPage[MAX_PLAYERS + 1];

// ============================================================
//  全局变量 - 管理员皮肤
// ============================================================
new Array:g_aAdminTModels;
new Array:g_aAdminTModelNames;
new Array:g_aAdminCTModels;
new Array:g_aAdminCTModelNames;
new Array:g_aAdminKnifeModels;
new Array:g_aAdminKnifeModelNames;

new bool:g_bAdminVerified[MAX_PLAYERS + 1];
new g_iVerifyStep[MAX_PLAYERS + 1]; // 0=未开始, 1=等待密码

new g_iAdminSelectedT[MAX_PLAYERS + 1] = {-1, ...};
new g_iAdminSelectedCT[MAX_PLAYERS + 1] = {-1, ...};
new g_iAdminSelectedKnife[MAX_PLAYERS + 1] = {-1, ...};

new g_iAdminSelectType[MAX_PLAYERS + 1];
new g_iAdminSelectPage[MAX_PLAYERS + 1];

// ============================================================
//  全局变量 - M键菜单
// ============================================================
// 比赛状态 (外部变量，从主系统获取)
new g_iMatchStatus = MATCH_NONE;

// ============================================================
//  全局变量 - 皮肤发放
// ============================================================
new g_iGiveTarget[MAX_PLAYERS + 1];       // 发放目标玩家
new g_iGiveType[MAX_PLAYERS + 1];        // 发放类型 0=T, 1=CT, 2=Knife
new g_iGivePage[MAX_PLAYERS + 1];        // 发放菜单翻页

// ============================================================
//  全局变量 - 玩家标识
// ============================================================
new g_szPlayerAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];
new g_szPlayerIP[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];
new g_szPlayerName[MAX_PLAYERS + 1][32];

// ============================================================
//  全局变量 - 内测账号
// ============================================================
new bool:g_bAccountLoggedIn[MAX_PLAYERS + 1];
new g_szAccountName[MAX_PLAYERS + 1][MAX_ACCOUNT_NAME];

// ============================================================
//  plugin_precache - 加载模型配置并预缓存
// ============================================================
public plugin_precache() {
    load_player_models();
    load_admin_models();
    precache_all_models();
}

// ============================================================
//  plugin_init - 注册命令、菜单、事件
// ============================================================
public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    // === 命令注册 ===
    // 皮肤菜单
    register_clcmd("say /model", "cmdSkinMenu");
    register_clcmd("say /skin", "cmdSkinMenu");
    register_clcmd("say /models", "cmdSkinMenu");
    register_clcmd("say /skins", "cmdSkinMenu");
    register_clcmd("say_team /model", "cmdSkinMenu");
    register_clcmd("say_team /skin", "cmdSkinMenu");
    register_clcmd("say_team /models", "cmdSkinMenu");
    register_clcmd("say_team /skins", "cmdSkinMenu");

    // M键菜单
    register_clcmd("chooseteam", "cmdChooseTeam");
    register_clcmd("say /menu", "cmdMenu");

    // 管理员皮肤验证
    register_clcmd("say /linna", "cmdAdminVerify");
    register_clcmd("say_team /linna", "cmdAdminVerify");

    // 内测账号
    register_clcmd("say /reg", "cmdAccountRegister");
    register_clcmd("say_team /reg", "cmdAccountRegister");
    register_clcmd("say /register", "cmdAccountRegister");
    register_clcmd("say_team /register", "cmdAccountRegister");
    register_clcmd("say /login", "cmdAccountLogin");
    register_clcmd("say_team /login", "cmdAccountLogin");
    register_clcmd("say /logout", "cmdAccountLogout");
    register_clcmd("say_team /logout", "cmdAccountLogout");
    register_clcmd("say /account", "cmdAccountInfo");
    register_clcmd("say_team /account", "cmdAccountInfo");

    // 皮肤发放
    register_clcmd("say /give skin", "cmdGiveSkin");
    register_clcmd("say_team /give skin", "cmdGiveSkin");
    register_clcmd("say /take skin", "cmdTakeSkin");
    register_clcmd("say_team /take skin", "cmdTakeSkin");

    // 聊天拦截（用于密码验证，只拦截say）
    register_clcmd("say", "cmdSayHandler");

    // === 菜单注册 ===
    register_menucmd(register_menuid("Player Menu"), 1023, "handlePlayerMenu");
    register_menucmd(register_menuid("Join Team Menu"), 1023, "handleJoinTeamMenu");
    register_menucmd(register_menuid("Skin Main Menu"), 1023, "handleSkinMainMenu");
    register_menucmd(register_menuid("Skin Select"), 1023, "handleSkinSelectMenu");
    register_menucmd(register_menuid("Admin Skin Menu"), 1023, "handleAdminSkinMenu");
    register_menucmd(register_menuid("Admin Select"), 1023, "handleAdminSelectMenu");
    register_menucmd(register_menuid("Give Player Menu"), 1023, "handleGivePlayerMenu");
    register_menucmd(register_menuid("Give Type Menu"), 1023, "handleGiveTypeMenu");
    register_menucmd(register_menuid("Give Skin Menu"), 1023, "handleGiveSkinMenu");

    // === 事件注册 ===
    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);

    // 确保mixsystem目录存在
    new szDir[256];
    get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
    format(szDir, charsmax(szDir), "%s/mixsystem", szDir);
    if (!dir_exists(szDir)) {
        mkdir(szDir);
    }

    log_amx("[SkinSystem] 插件加载完成");
}

// ============================================================
//  plugin_end - 清理
// ============================================================
public plugin_end() {
    cleanup_arrays();
}

// ============================================================
//  client_putinserver - 初始化+加载存档
// ============================================================
public client_putinserver(id) {
    if (is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    // 重置所有数据
    reset_player_data(id);

    // 获取玩家标识信息
    get_user_authid(id, g_szPlayerAuth[id], charsmax(g_szPlayerAuth[]));
    get_user_ip(id, g_szPlayerIP[id], charsmax(g_szPlayerIP[]), 1);
    get_user_name(id, g_szPlayerName[id], charsmax(g_szPlayerName[]));

    // 加载存档
    load_skin_profile(id);
}

// ============================================================
//  client_disconnected - 保存存档
// ============================================================
public client_disconnected(id) {
    if (is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    save_skin_profile(id);
}

// ============================================================
//  client_authorized - Steam验证后重新加载
// ============================================================
public client_authorized(id) {
    if (is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    new szAuth[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuth, charsmax(szAuth));

    // 如果SteamID不再是LAN，重新加载
    if (!equal(szAuth, "STEAM_ID_LAN") && !equal(szAuth, "VALVE_ID_LAN")) {
        copy(g_szPlayerAuth[id], charsmax(g_szPlayerAuth[]), szAuth);
        load_skin_profile(id);
    }
}

stock clear_skin_profile_state(const id) {
    g_iOwnedTCount[id] = 0;
    g_iOwnedCTCount[id] = 0;
    g_iOwnedKnifeCount[id] = 0;
    g_iSelectedT[id] = -1;
    g_iSelectedCT[id] = -1;
    g_iSelectedKnife[id] = -1;

    g_bAdminVerified[id] = false;
    g_iAdminSelectedT[id] = -1;
    g_iAdminSelectedCT[id] = -1;
    g_iAdminSelectedKnife[id] = -1;
}

stock load_skin_profile(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    clear_skin_profile_state(id);
    load_player_skins(id);
    load_admin_skins(id);
}

stock save_skin_profile(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    save_player_skins(id);
    save_admin_skins(id);
}

// ============================================================
//  重置玩家数据
// ============================================================
stock reset_player_data(id) {
    clear_skin_profile_state(id);

    g_iSkinSelectType[id] = 0;
    g_iSkinSelectPage[id] = 0;
    g_iVerifyStep[id] = 0;
    g_iAdminSelectType[id] = 0;
    g_iAdminSelectPage[id] = 0;

    g_iGiveTarget[id] = 0;
    g_iGiveType[id] = 0;
    g_iGivePage[id] = 0;

    g_szPlayerAuth[id][0] = EOS;
    g_szPlayerIP[id][0] = EOS;
    g_szPlayerName[id][0] = EOS;
    g_bAccountLoggedIn[id] = false;
    g_szAccountName[id][0] = EOS;
}

// ============================================================
//  === 配置加载 ===
// ============================================================

// 加载 player_models.ini
stock load_player_models() {
    g_aTModels = ArrayCreate(MAX_MODEL_NAME, 1);
    g_aTModelNames = ArrayCreate(MAX_SKIN_NAME, 1);
    g_aCTModels = ArrayCreate(MAX_MODEL_NAME, 1);
    g_aCTModelNames = ArrayCreate(MAX_SKIN_NAME, 1);
    g_aKnifeModels = ArrayCreate(MAX_MODEL_NAME, 1);
    g_aKnifeModelNames = ArrayCreate(MAX_SKIN_NAME, 1);

    new szPath[256];
    get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
    format(szPath, charsmax(szPath), "%s/mixsystem/player_models.ini", szPath);

    new f = fopen(szPath, "rt");
    if (!f) {
        log_amx("[SkinSystem] 普通皮肤配置文件不存在: %s", szPath);
        return;
    }

    new szLine[512];
    new bool:bInT = false, bool:bInCT = false, bool:bInKnife = false;
    new iLineNum = 0;

    while (!feof(f)) {
        fgets(f, szLine, charsmax(szLine));
        trim(szLine);
        iLineNum++;

        // 跳过注释和空行
        if (szLine[0] == ';' || szLine[0] == '/' && szLine[1] == '/' || szLine[0] == EOS) {
            continue;
        }

        // 检查段头
        if (szLine[0] == '[') {
            new len = strlen(szLine);
            if (szLine[len - 1] == ']') {
                szLine[--len] = EOS;
            }
            // 去掉开头的 [
            if (szLine[0] == '[') {
                copy(szLine, charsmax(szLine), szLine[1]);
            }

            if (equali(szLine, "T") || equali(szLine, "Terrorist") || equali(szLine, "TT")) {
                bInT = true;
                bInCT = false;
                bInKnife = false;
            } else if (equali(szLine, "CT") || equali(szLine, "Counter-Terrorist") || equali(szLine, "CounterTerrorist")) {
                bInCT = true;
                bInT = false;
                bInKnife = false;
            } else if (equali(szLine, "Knife") || equali(szLine, "Knives")) {
                bInKnife = true;
                bInT = false;
                bInCT = false;
            } else {
                bInT = false;
                bInCT = false;
                bInKnife = false;
            }
            continue;
        }

        // 解析行: "名称 models/player/xxx/xxx.mdl"
        // 用第一个空格分隔名称和路径
        new szName[MAX_SKIN_NAME];
        new szModelPath[MAX_MODEL_NAME];
        new iSpacePos = contain(szLine, " ");
        if (iSpacePos <= 0) {
            continue;
        }

        copy(szName, iSpacePos + 1, szLine);
        copy(szModelPath, charsmax(szModelPath), szLine[iSpacePos + 1]);
        trim(szName);
        trim(szModelPath);

        if (szName[0] == EOS || szModelPath[0] == EOS) {
            continue;
        }

        if (bInT) {
            ArrayPushString(g_aTModels, szModelPath);
            ArrayPushString(g_aTModelNames, szName);
        } else if (bInCT) {
            ArrayPushString(g_aCTModels, szModelPath);
            ArrayPushString(g_aCTModelNames, szName);
        } else if (bInKnife) {
            ArrayPushString(g_aKnifeModels, szModelPath);
            ArrayPushString(g_aKnifeModelNames, szName);
        }
    }

    fclose(f);

    log_amx("[SkinSystem] 普通皮肤: T=%d, CT=%d, Knife=%d",
        ArraySize(g_aTModels), ArraySize(g_aCTModels), ArraySize(g_aKnifeModels));
}

// 加载 admin_models.ini
stock load_admin_models() {
    g_aAdminTModels = ArrayCreate(MAX_MODEL_NAME, 1);
    g_aAdminTModelNames = ArrayCreate(MAX_SKIN_NAME, 1);
    g_aAdminCTModels = ArrayCreate(MAX_MODEL_NAME, 1);
    g_aAdminCTModelNames = ArrayCreate(MAX_SKIN_NAME, 1);
    g_aAdminKnifeModels = ArrayCreate(MAX_MODEL_NAME, 1);
    g_aAdminKnifeModelNames = ArrayCreate(MAX_SKIN_NAME, 1);

    new szPath[256];
    get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
    format(szPath, charsmax(szPath), "%s/mixsystem/admin_models.ini", szPath);

    new f = fopen(szPath, "rt");
    if (!f) {
        log_amx("[SkinSystem] 管理员皮肤配置文件不存在: %s", szPath);
        return;
    }

    new szLine[512];
    new bool:bInT = false, bool:bInCT = false, bool:bInKnife = false;

    while (!feof(f)) {
        fgets(f, szLine, charsmax(szLine));
        trim(szLine);

        if (szLine[0] == ';' || szLine[0] == '/' && szLine[1] == '/' || szLine[0] == EOS) {
            continue;
        }

        if (szLine[0] == '[') {
            new len = strlen(szLine);
            if (szLine[len - 1] == ']') {
                szLine[--len] = EOS;
            }
            if (szLine[0] == '[') {
                copy(szLine, charsmax(szLine), szLine[1]);
            }

            if (equali(szLine, "T") || equali(szLine, "Terrorist") || equali(szLine, "TT")) {
                bInT = true;
                bInCT = false;
                bInKnife = false;
            } else if (equali(szLine, "CT") || equali(szLine, "Counter-Terrorist") || equali(szLine, "CounterTerrorist")) {
                bInCT = true;
                bInT = false;
                bInKnife = false;
            } else if (equali(szLine, "Knife") || equali(szLine, "Knives")) {
                bInKnife = true;
                bInT = false;
                bInCT = false;
            } else {
                bInT = false;
                bInCT = false;
                bInKnife = false;
            }
            continue;
        }

        // 解析: "名称 models/player/xxx/xxx.mdl"
        new szName[MAX_SKIN_NAME];
        new szModelPath[MAX_MODEL_NAME];
        new iSpacePos = contain(szLine, " ");
        if (iSpacePos <= 0) {
            continue;
        }

        copy(szName, iSpacePos + 1, szLine);
        copy(szModelPath, charsmax(szModelPath), szLine[iSpacePos + 1]);
        trim(szName);
        trim(szModelPath);

        if (szName[0] == EOS || szModelPath[0] == EOS) {
            continue;
        }

        if (bInT) {
            ArrayPushString(g_aAdminTModels, szModelPath);
            ArrayPushString(g_aAdminTModelNames, szName);
        } else if (bInCT) {
            ArrayPushString(g_aAdminCTModels, szModelPath);
            ArrayPushString(g_aAdminCTModelNames, szName);
        } else if (bInKnife) {
            ArrayPushString(g_aAdminKnifeModels, szModelPath);
            ArrayPushString(g_aAdminKnifeModelNames, szName);
        }
    }

    fclose(f);

    log_amx("[SkinSystem] 管理员皮肤: T=%d, CT=%d, Knife=%d",
        ArraySize(g_aAdminTModels), ArraySize(g_aAdminCTModels), ArraySize(g_aAdminKnifeModels));
}

// ============================================================
//  === 预缓存 ===
// ============================================================
stock precache_all_models() {
    new szModel[MAX_MODEL_NAME];
    new i, iSize;

    // 普通T模型
    iSize = ArraySize(g_aTModels);
    for (i = 0; i < iSize; i++) {
        ArrayGetString(g_aTModels, i, szModel, charsmax(szModel));
        precache_model(szModel);
    }

    // 普通CT模型
    iSize = ArraySize(g_aCTModels);
    for (i = 0; i < iSize; i++) {
        ArrayGetString(g_aCTModels, i, szModel, charsmax(szModel));
        precache_model(szModel);
    }

    // 普通刀模型
    iSize = ArraySize(g_aKnifeModels);
    for (i = 0; i < iSize; i++) {
        ArrayGetString(g_aKnifeModels, i, szModel, charsmax(szModel));
        precache_model(szModel);
    }

    // 管理员T模型
    iSize = ArraySize(g_aAdminTModels);
    for (i = 0; i < iSize; i++) {
        ArrayGetString(g_aAdminTModels, i, szModel, charsmax(szModel));
        precache_model(szModel);
    }

    // 管理员CT模型
    iSize = ArraySize(g_aAdminCTModels);
    for (i = 0; i < iSize; i++) {
        ArrayGetString(g_aAdminCTModels, i, szModel, charsmax(szModel));
        precache_model(szModel);
    }

    // 管理员刀模型
    iSize = ArraySize(g_aAdminKnifeModels);
    for (i = 0; i < iSize; i++) {
        ArrayGetString(g_aAdminKnifeModels, i, szModel, charsmax(szModel));
        precache_model(szModel);
    }

    log_amx("[SkinSystem] 所有模型预缓存完成");
}

// ============================================================
//  === 模型应用 ===
// ============================================================
public OnPlayerSpawn(const id) {
    if (!is_user_alive(id)) {
        return;
    }
    set_task(0.1, "task_apply_model", id);
}

public task_apply_model(const id) {
    if (!is_user_alive(id)) {
        return;
    }
    apply_model(id);
}

// 应用模型 - 优先级: 管理员皮肤 > 普通皮肤 > 默认模型
stock apply_model(const id) {
    if (!is_user_alive(id)) {
        return;
    }

    new TeamName:iTeam = get_member(id, m_iTeam);

    // --- 身体模型 ---
    if (iTeam == TEAM_TERRORIST) {
        // 优先检查管理员皮肤
        if (g_bAdminVerified[id] && g_iAdminSelectedT[id] >= 0) {
            new iSize = ArraySize(g_aAdminTModels);
            if (g_iAdminSelectedT[id] < iSize) {
                new szPath[MAX_MODEL_NAME];
                new szFolder[MAX_MODEL_NAME];
                ArrayGetString(g_aAdminTModels, g_iAdminSelectedT[id], szPath, charsmax(szPath));
                extract_folder_from_path(szPath, szFolder, charsmax(szFolder));
                rg_set_user_model(id, szFolder);
            }
        }
        // 其次检查普通皮肤
        else if (g_iSelectedT[id] >= 0) {
            new iSize = ArraySize(g_aTModels);
            if (g_iSelectedT[id] < iSize) {
                new szPath[MAX_MODEL_NAME];
                new szFolder[MAX_MODEL_NAME];
                ArrayGetString(g_aTModels, g_iSelectedT[id], szPath, charsmax(szPath));
                extract_folder_from_path(szPath, szFolder, charsmax(szFolder));
                rg_set_user_model(id, szFolder);
            }
        }
        // 否则用CS默认模型（不设置）
    }
    else if (iTeam == TEAM_CT) {
        // 优先检查管理员皮肤
        if (g_bAdminVerified[id] && g_iAdminSelectedCT[id] >= 0) {
            new iSize = ArraySize(g_aAdminCTModels);
            if (g_iAdminSelectedCT[id] < iSize) {
                new szPath[MAX_MODEL_NAME];
                new szFolder[MAX_MODEL_NAME];
                ArrayGetString(g_aAdminCTModels, g_iAdminSelectedCT[id], szPath, charsmax(szPath));
                extract_folder_from_path(szPath, szFolder, charsmax(szFolder));
                rg_set_user_model(id, szFolder);
            }
        }
        // 其次检查普通皮肤
        else if (g_iSelectedCT[id] >= 0) {
            new iSize = ArraySize(g_aCTModels);
            if (g_iSelectedCT[id] < iSize) {
                new szPath[MAX_MODEL_NAME];
                new szFolder[MAX_MODEL_NAME];
                ArrayGetString(g_aCTModels, g_iSelectedCT[id], szPath, charsmax(szPath));
                extract_folder_from_path(szPath, szFolder, charsmax(szFolder));
                rg_set_user_model(id, szFolder);
            }
        }
    }

    // --- 刀模型 ---
    // 优先管理员刀皮
    if (g_bAdminVerified[id] && g_iAdminSelectedKnife[id] >= 0) {
        new iSize = ArraySize(g_aAdminKnifeModels);
        if (g_iAdminSelectedKnife[id] < iSize) {
            new szPath[MAX_MODEL_NAME];
            ArrayGetString(g_aAdminKnifeModels, g_iAdminSelectedKnife[id], szPath, charsmax(szPath));
            set_member(id, m_szViewModel, szPath);
        }
    }
    // 其次普通刀皮
    else if (g_iSelectedKnife[id] >= 0) {
        new iSize = ArraySize(g_aKnifeModels);
        if (g_iSelectedKnife[id] < iSize) {
            new szPath[MAX_MODEL_NAME];
            ArrayGetString(g_aKnifeModels, g_iSelectedKnife[id], szPath, charsmax(szPath));
            set_member(id, m_szViewModel, szPath);
        }
    }
}

// 从路径提取文件夹名
// models/player/xxx/xxx.mdl -> xxx
// models/xxx/v_knife.mdl -> xxx
stock extract_folder_from_path(const szPath[], szFolder[], iLen) {
    new iLastSlash = 0;
    new i, len = strlen(szPath);
    for (i = 0; i < len; i++) {
        if (szPath[i] == '/' || szPath[i] == 92) {
            iLastSlash = i;
        }
    }

    if (iLastSlash <= 0) {
        copy(szFolder, iLen, szPath);
        return;
    }

    new szTemp[MAX_MODEL_NAME];
    copy(szTemp, charsmax(szTemp), szPath[iLastSlash + 1]);

    // 刀模型: v_knife.mdl -> 文件夹是倒数第二个斜杠后的部分
    if (contain(szTemp, "v_knife") >= 0 || contain(szTemp, "v_") >= 0) {
        new szDir[MAX_MODEL_NAME];
        copy(szDir, charsmax(szDir), szPath);
        szDir[iLastSlash] = EOS;
        new iPrevSlash = 0;
        for (i = 0; i < iLastSlash; i++) {
            if (szDir[i] == '/' || szDir[i] == 92) {
                iPrevSlash = i;
            }
        }
        if (iPrevSlash > 0) {
            copy(szFolder, iLen, szDir[iPrevSlash + 1]);
        } else {
            copy(szFolder, iLen, szDir);
        }
    } else {
        // 身体模型: 去掉 .mdl 后缀
        new iExt = contain(szTemp, ".mdl");
        if (iExt > 0) {
            szTemp[iExt] = EOS;
        }
        copy(szFolder, iLen, szTemp);
    }
}

// ============================================================
//  === M键玩家菜单 ===
// ============================================================
public cmdChooseTeam(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }
    showPlayerMenu(id);
    return PLUGIN_HANDLED;
}

public cmdMenu(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    if (get_user_flags(id) & ADMIN_MENU) {
        client_cmd(id, "amxmodmenu");
        return PLUGIN_HANDLED;
    }

    showPlayerMenu(id);
    return PLUGIN_HANDLED;
}

// M键玩家主菜单
stock showPlayerMenu(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[512];
    new iLen = 0;
    new iKeys = (1 << 9); // 0 = 退出

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w玩家菜单^n^n");

    // 1. 加入队伍
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w1. 加入队伍^n");
    iKeys |= (1 << 0);

    // 2. 皮肤选择
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w2. 皮肤选择^n");
    iKeys |= (1 << 1);

    // 3. 个人信息
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w3. 个人信息^n");
    iKeys |= (1 << 2);

    // 4. 地图/模式信息
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w4. 地图/模式信息^n");
    iKeys |= (1 << 3);

    // 5. 管理员皮肤（仅已验证管理员可见）
    if (g_bAdminVerified[id]) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w5. 管理员皮肤^n");
        iKeys |= (1 << 4);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d5. 管理员皮肤^n");
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 退出");

    show_menu(id, iKeys, szMenu, -1, "Player Menu");
}

public handlePlayerMenu(const id, const key) {
    if (key == 0) {
        showJoinTeamMenu(id);
    } else if (key == 1) {
        showSkinMainMenu(id);
    } else if (key == 2) {
        showPlayerInfo(id);
    } else if (key == 3) {
        showMapModeInfo(id);
    } else if (key == 4) {
        if (g_bAdminVerified[id]) {
            showAdminSkinMenu(id);
        }
    }
    // key == 9: exit
    return PLUGIN_HANDLED;
}

// 加入队伍子菜单
stock showJoinTeamMenu(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[256];
    new iLen = 0;
    new iKeys = (1 << 9);

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w选择队伍^n^n");

    // 检查是否在比赛中
    if (g_iMatchStatus != MATCH_NONE) {
        // 比赛中，禁止选队
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d1. 加入恐怖分子 (比赛中不可用)^n");
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d2. 加入反恐精英 (比赛中不可用)^n");
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w1. 加入恐怖分子^n");
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w2. 加入反恐精英^n");
        iKeys |= (1 << 0) | (1 << 1);
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, iKeys, szMenu, -1, "Join Team Menu");
}

public handleJoinTeamMenu(const id, const key) {
    switch (key) {
        case 0: {
            // 选T
            if (g_iMatchStatus != MATCH_NONE) {
                client_print(id, print_chat, "[HNS] 比赛进行中，无法切换队伍");
                showJoinTeamMenu(id);
                return;
            }
            rg_set_user_team(id, TEAM_TERRORIST, MODEL_AUTO, true);
            client_print(id, print_chat, "[HNS] 你已加入恐怖分子");
        }
        case 1: {
            // 选CT
            if (g_iMatchStatus != MATCH_NONE) {
                client_print(id, print_chat, "[HNS] 比赛进行中，无法切换队伍");
                showJoinTeamMenu(id);
                return;
            }
            rg_set_user_team(id, TEAM_CT, MODEL_AUTO, true);
            client_print(id, print_chat, "[HNS] 你已加入反恐精英");
        }
        case 9: {
            // 返回
            showPlayerMenu(id);
            return;
        }
    }
    return;
}

// Player Info
stock showPlayerInfo(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[512];
    new iLen = 0;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w个人信息^n^n");

    // 基本信息
    new szName[32];
    get_user_name(id, szName, charsmax(szName));
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w名称: \y%s^n", szName);

    new szAuth[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuth, charsmax(szAuth));
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\wSteamID: \y%s^n", szAuth);

    new szIP[MAX_AUTHID_LENGTH];
    get_user_ip(id, szIP, charsmax(szIP), 1);
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\wIP: \y%s^n", szIP);

    if (g_bAccountLoggedIn[id]) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w内测账号: \y%s^n", g_szAccountName[id]);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w内测账号: \r未登录^n");
    }

    // 战斗统计
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r-- 战斗统计 --^n");
    new iFrags = get_user_frags(id);
    new iDeaths = get_user_deaths(id);
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w击杀: \y%d \w死亡: \y%d^n", iFrags, iDeaths);

    // 权限等级
    new iPermLevel = get_user_perm_level(id);
    new szPermName[16];
    switch (iPermLevel) {
        case PERM_NONE: {
            copy(szPermName, charsmax(szPermName), "普通玩家");
        }
        case PERM_VIP: {
            copy(szPermName, charsmax(szPermName), "VIP");
        }
        case PERM_ADMIN: {
            copy(szPermName, charsmax(szPermName), "管理员");
        }
        case PERM_OWNER: {
            copy(szPermName, charsmax(szPermName), "最高服主");
        }
        default: {
            copy(szPermName, charsmax(szPermName), "未知");
        }
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w权限等级: \y%s^n", szPermName);

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, (1 << 9), szMenu, -1, "HnsSkinPlayerInfo");
}

// 地图/模式信息
stock showMapModeInfo(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[512];
    new iLen = 0;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w地图/模式信息^n^n");

    // 地图名
    new szMapName[64];
    get_mapname(szMapName, charsmax(szMapName));
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w当前地图: \y%s^n", szMapName);

    // 模式
    new szMode[32];
    if (g_iMatchStatus != MATCH_NONE) {
        copy(szMode, charsmax(szMode), "比赛模式");
    } else {
        copy(szMode, charsmax(szMode), "娱乐/练习");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w当前模式: \y%s^n", szMode);

    // 在线人数
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "c");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w在线人数: \y%d^n", iNum);

    // 比赛状态
    new szStatus[32];
    switch (g_iMatchStatus) {
        case 0: {
            copy(szStatus, charsmax(szStatus), "非比赛");
        }
        case 1: {
            copy(szStatus, charsmax(szStatus), "队长挑选");
        }
        case 2: {
            copy(szStatus, charsmax(szStatus), "队长刀战");
        }
        case 3: {
            copy(szStatus, charsmax(szStatus), "队伍挑选");
        }
        case 4: {
            copy(szStatus, charsmax(szStatus), "杯赛刀战");
        }
        case 5: {
            copy(szStatus, charsmax(szStatus), "杯赛挑选");
        }
        case 6: {
            copy(szStatus, charsmax(szStatus), "队伍刀战");
        }
        case 7: {
            copy(szStatus, charsmax(szStatus), "地图挑选");
        }
        case 8: {
            copy(szStatus, charsmax(szStatus), "等待连接");
        }
        case 9: {
            copy(szStatus, charsmax(szStatus), "比赛进行中");
        }
        default: {
            copy(szStatus, charsmax(szStatus), "未知");
        }
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w比赛状态: \y%s^n", szStatus);

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, (1 << 9), szMenu, -1, "HnsSkinMapModeInfo");
}

// ============================================================
//  === 普通皮肤菜单 ===
// ============================================================
public cmdSkinMenu(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }
    showSkinMainMenu(id);
    return PLUGIN_HANDLED;
}

// 皮肤选择主菜单
stock showSkinMainMenu(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[512];
    new iLen = 0;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w皮肤选择^n^n");

    // 当前T皮肤
    new szTName[MAX_SKIN_NAME];
    if (g_iSelectedT[id] >= 0 && g_iSelectedT[id] < ArraySize(g_aTModelNames)) {
        ArrayGetString(g_aTModelNames, g_iSelectedT[id], szTName, charsmax(szTName));
    } else {
        copy(szTName, charsmax(szTName), "默认");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w1. T皮肤: \y%s^n", szTName);

    // 当前CT皮肤
    new szCTName[MAX_SKIN_NAME];
    if (g_iSelectedCT[id] >= 0 && g_iSelectedCT[id] < ArraySize(g_aCTModelNames)) {
        ArrayGetString(g_aCTModelNames, g_iSelectedCT[id], szCTName, charsmax(szCTName));
    } else {
        copy(szCTName, charsmax(szCTName), "默认");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w2. CT皮肤: \y%s^n", szCTName);

    // 当前刀皮肤
    new szKnifeName[MAX_SKIN_NAME];
    if (g_iSelectedKnife[id] >= 0 && g_iSelectedKnife[id] < ArraySize(g_aKnifeModelNames)) {
        ArrayGetString(g_aKnifeModelNames, g_iSelectedKnife[id], szKnifeName, charsmax(szKnifeName));
    } else {
        copy(szKnifeName, charsmax(szKnifeName), "默认");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w3. 刀皮肤: \y%s^n", szKnifeName);

    // 重置选项
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w4. 重置所有皮肤^n");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), szMenu, -1, "Skin Main Menu");
}

public handleSkinMainMenu(const id, const key) {
    switch (key) {
        case 0: {
            // T皮肤列表
            showSkinSelectMenu(id, 0, 0);
        }
        case 1: {
            // CT皮肤列表
            showSkinSelectMenu(id, 1, 0);
        }
        case 2: {
            // 刀皮肤列表
            showSkinSelectMenu(id, 2, 0);
        }
        case 3: {
            // 重置所有皮肤
            g_iSelectedT[id] = -1;
            g_iSelectedCT[id] = -1;
            g_iSelectedKnife[id] = -1;
            save_player_skins(id);
            rg_set_user_model(id, "");
            client_print(id, print_chat, "[HNS] 所有皮肤已重置为默认");
            showSkinMainMenu(id);
        }
        case 9: {
            // 返回
            showPlayerMenu(id);
        }
    }
    return PLUGIN_HANDLED;
}

// 具体皮肤列表（带分页）
stock showSkinSelectMenu(const id, const iType, const iPage) {
    if (!is_user_connected(id)) {
        return;
    }

    g_iSkinSelectType[id] = iType;

    new Array:aModels, Array:aNames;
    new iSize;
    new iCurrent;
    new szTypeName[8];

    switch (iType) {
        case 0: {
            aModels = g_aTModels;
            aNames = g_aTModelNames;
            iCurrent = g_iSelectedT[id];
            copy(szTypeName, charsmax(szTypeName), "T");
        }
        case 1: {
            aModels = g_aCTModels;
            aNames = g_aCTModelNames;
            iCurrent = g_iSelectedCT[id];
            copy(szTypeName, charsmax(szTypeName), "CT");
        }
        case 2: {
            aModels = g_aKnifeModels;
            aNames = g_aKnifeModelNames;
            iCurrent = g_iSelectedKnife[id];
            copy(szTypeName, charsmax(szTypeName), "刀");
        }
        default: return;
    }

    iSize = ArraySize(aModels);
    new iPerPage = MAX_MENU_PAGE;
    new iTotalPages = (iSize + iPerPage - 1) / iPerPage;
    if (iTotalPages < 1) {
        iTotalPages = 1;
    }

    new page = iPage;
    if (page < 0) page = 0;
    if (page >= iTotalPages) page = iTotalPages - 1;

    g_iSkinSelectPage[id] = page;

    new iStart = page * iPerPage;
    new iEnd = min(iStart + iPerPage, iSize);

    new szMenu[1024];
    new iLen = 0;
    new iKeys = (1 << 9); // 0 = 返回
    new iItemNum = 1;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w%s皮肤选择 \y%d/%d^n^n", szTypeName, page + 1, iTotalPages);

    for (new i = iStart; i < iEnd; i++) {
        new szName[MAX_SKIN_NAME];
        ArrayGetString(aNames, i, szName, charsmax(szName));

        // 检查是否拥有该皮肤（索引0=默认皮肤，所有人拥有）
        new bool:bOwned = (i == 0) || has_skin(id, iType, i);

        if (bOwned) {
            if (i == iCurrent) {
                iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. %s \r[已选]^n", iItemNum, szName);
            } else {
                iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. %s^n", iItemNum, szName);
            }
            iKeys |= (1 << (iItemNum - 1));
        } else {
            // 未拥有，灰色显示不可选
            iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d%d. %s \r[未解锁]^n", iItemNum, szName);
        }

        iItemNum++;
    }

    // 翻页按钮
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

    if (page > 0) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w8. << 上一页^n");
        iKeys |= (1 << 7);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d8. << 上一页^n");
    }

    if (page < iTotalPages - 1) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w9. 下一页 >>^n");
        iKeys |= (1 << 8);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d9. 下一页 >>^n");
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, iKeys, szMenu, -1, "Skin Select");
}

public handleSkinSelectMenu(const id, const key) {
    if (key == 9) {
        // 返回
        showSkinMainMenu(id);
        return PLUGIN_HANDLED;
    }

    new iType = g_iSkinSelectType[id];

    // 上一页
    if (key == 7) {
        showSkinSelectMenu(id, iType, g_iSkinSelectPage[id] - 1);
        return PLUGIN_HANDLED;
    }

    // 下一页
    if (key == 8) {
        showSkinSelectMenu(id, iType, g_iSkinSelectPage[id] + 1);
        return PLUGIN_HANDLED;
    }

    // 选择皮肤
    new Array:aModels, Array:aNames;
    new iSize;

    switch (iType) {
        case 0: { aModels = g_aTModels; aNames = g_aTModelNames;             }
        case 1: { aModels = g_aCTModels; aNames = g_aCTModelNames;             }
        case 2: { aModels = g_aKnifeModels; aNames = g_aKnifeModelNames;             }
        default: return PLUGIN_HANDLED;
    }

    iSize = ArraySize(aModels);
    new iPerPage = MAX_MENU_PAGE;
    new iModelIndex = g_iSkinSelectPage[id] * iPerPage + key;

    if (iModelIndex < 0 || iModelIndex >= iSize) {
        showSkinSelectMenu(id, iType, g_iSkinSelectPage[id]);
        return PLUGIN_HANDLED;
    }

    // 检查是否拥有
    if (iModelIndex != 0 && !has_skin(id, iType, iModelIndex)) {
        client_print(id, print_chat, "[HNS] 你还没有解锁这个皮肤");
        showSkinSelectMenu(id, iType, g_iSkinSelectPage[id]);
        return PLUGIN_HANDLED;
    }

    // 保存选择
    switch (iType) {
        case 0: {
            g_iSelectedT[id] = iModelIndex;
        }
        case 1: {
            g_iSelectedCT[id] = iModelIndex;
        }
        case 2: {
            g_iSelectedKnife[id] = iModelIndex;
        }
    }

    save_player_skins(id);

    // 获取名称
    new szName[MAX_SKIN_NAME];
    ArrayGetString(aNames, iModelIndex, szName, charsmax(szName));

    new szType[8];
    switch (iType) {
        case 0: {
            copy(szType, charsmax(szType), "T");
        }
        case 1: {
            copy(szType, charsmax(szType), "CT");
        }
        case 2: {
            copy(szType, charsmax(szType), "刀");
        }
    }

    client_print(id, print_chat, "[HNS] %s皮肤已设置为: %s", szType, szName);

    // 立即应用
    apply_model(id);

    showSkinMainMenu(id);
    return PLUGIN_HANDLED;
}

// ============================================================
//  === 管理员皮肤 ===
// ============================================================
public cmdAdminVerify(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    if (g_bAdminVerified[id]) {
        showAdminSkinMenu(id);
        return PLUGIN_HANDLED;
    }

    // 开始验证流程
    g_iVerifyStep[id] = 1;
    client_print(id, print_chat, "[管理员皮肤] 请在聊天框输入密码以解锁管理员皮肤...");
    client_print(id, print_center, "请输入管理员密码");

    return PLUGIN_HANDLED;
}

// 拦截say检查密码
public cmdSayHandler(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    // 检查是否在等待密码输入
    if (g_iVerifyStep[id] == 1) {
        new szArgs[192];
        read_args(szArgs, charsmax(szArgs));
        remove_quotes(szArgs);
        trim(szArgs);

        if (equal(szArgs, ADMIN_PASSWORD)) {
            g_bAdminVerified[id] = true;
            g_iVerifyStep[id] = 0;
            client_print(id, print_chat, "[管理员皮肤] 密码正确！管理员皮肤已解锁");
            showAdminSkinMenu(id);
            return PLUGIN_HANDLED; // 阻止密码显示在聊天
        } else {
            g_iVerifyStep[id] = 0;
            client_print(id, print_chat, "[管理员皮肤] 密码错误！");
            return PLUGIN_HANDLED;
        }
    }

    return PLUGIN_CONTINUE;
}

public cmdAccountInfo(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    if (g_bAccountLoggedIn[id]) {
        client_print(id, print_chat, "[账号系统] 当前已登录内测账号: %s", g_szAccountName[id]);
        client_print(id, print_chat, "[账号系统] 可用命令: /logout");
    } else {
        client_print(id, print_chat, "[账号系统] 当前未登录内测账号");
        client_print(id, print_chat, "[账号系统] 注册: /reg <内测名> <密码>");
        client_print(id, print_chat, "[账号系统] 登录: /login <内测名> <密码>");
    }

    return PLUGIN_HANDLED;
}

public cmdAccountRegister(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    new szArgs[192], szAccountRaw[64], szPassword[MAX_ACCOUNT_PASS];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);
    strip_account_command_prefix(szArgs, charsmax(szArgs), "/reg");
    strip_account_command_prefix(szArgs, charsmax(szArgs), "reg");
    strip_account_command_prefix(szArgs, charsmax(szArgs), "/register");
    strip_account_command_prefix(szArgs, charsmax(szArgs), "register");

    parse(szArgs, szAccountRaw, charsmax(szAccountRaw), szPassword, charsmax(szPassword));

    if (szAccountRaw[0] == EOS || szPassword[0] == EOS) {
        client_print(id, print_chat, "[账号系统] 用法: /reg <内测名> <密码>");
        return PLUGIN_HANDLED;
    }

    new szAccount[MAX_ACCOUNT_NAME];
    normalize_account_name(szAccountRaw, szAccount, charsmax(szAccount));

    if (!is_valid_account_name(szAccount)) {
        client_print(id, print_chat, "[账号系统] 内测名只支持 3-24 位英文、数字、下划线、短横线");
        return PLUGIN_HANDLED;
    }

    if (!is_valid_account_password(szPassword)) {
        client_print(id, print_chat, "[账号系统] 密码长度需为 4-32 位");
        return PLUGIN_HANDLED;
    }

    new szHash[MAX_ACCOUNT_HASH];
    if (find_account_record(szAccount, szHash, charsmax(szHash))) {
        client_print(id, print_chat, "[账号系统] 内测名 %s 已存在，请换一个", szAccount);
        return PLUGIN_HANDLED;
    }

    hash_account_password(szAccount, szPassword, szHash, charsmax(szHash));
    if (!append_account_record(szAccount, szHash)) {
        client_print(id, print_chat, "[账号系统] 注册失败，账号文件写入错误");
        return PLUGIN_HANDLED;
    }

    g_bAccountLoggedIn[id] = true;
    copy(g_szAccountName[id], charsmax(g_szAccountName[]), szAccount);
    save_skin_profile(id);

    client_print(id, print_chat, "[账号系统] 注册成功，已登录内测账号: %s", szAccount);
    client_print(id, print_chat, "[账号系统] 你当前已加载/绑定的皮肤数据将保存到此账号");
    return PLUGIN_HANDLED;
}

public cmdAccountLogin(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    new szArgs[192], szAccountRaw[64], szPassword[MAX_ACCOUNT_PASS];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);
    strip_account_command_prefix(szArgs, charsmax(szArgs), "/login");
    strip_account_command_prefix(szArgs, charsmax(szArgs), "login");

    parse(szArgs, szAccountRaw, charsmax(szAccountRaw), szPassword, charsmax(szPassword));

    if (szAccountRaw[0] == EOS || szPassword[0] == EOS) {
        client_print(id, print_chat, "[账号系统] 用法: /login <内测名> <密码>");
        return PLUGIN_HANDLED;
    }

    new szAccount[MAX_ACCOUNT_NAME], szStoredHash[MAX_ACCOUNT_HASH], szInputHash[MAX_ACCOUNT_HASH];
    normalize_account_name(szAccountRaw, szAccount, charsmax(szAccount));

    if (!find_account_record(szAccount, szStoredHash, charsmax(szStoredHash))) {
        client_print(id, print_chat, "[账号系统] 内测账号不存在: %s", szAccount);
        return PLUGIN_HANDLED;
    }

    hash_account_password(szAccount, szPassword, szInputHash, charsmax(szInputHash));
    if (!equal(szStoredHash, szInputHash)) {
        client_print(id, print_chat, "[账号系统] 密码错误");
        return PLUGIN_HANDLED;
    }

    g_bAccountLoggedIn[id] = true;
    copy(g_szAccountName[id], charsmax(g_szAccountName[]), szAccount);
    load_skin_profile(id);

    client_print(id, print_chat, "[账号系统] 登录成功，当前账号: %s", szAccount);
    return PLUGIN_HANDLED;
}

public cmdAccountLogout(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    if (!g_bAccountLoggedIn[id]) {
        client_print(id, print_chat, "[账号系统] 你当前没有登录内测账号");
        return PLUGIN_HANDLED;
    }

    save_skin_profile(id);
    g_bAccountLoggedIn[id] = false;
    g_szAccountName[id][0] = EOS;
    load_skin_profile(id);

    client_print(id, print_chat, "[账号系统] 已退出内测账号，当前回到原始识别模式");
    return PLUGIN_HANDLED;
}

// 管理员皮肤主菜单
stock showAdminSkinMenu(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    if (!g_bAdminVerified[id]) {
        client_print(id, print_chat, "[管理员皮肤] 你还没有通过密码验证");
        return;
    }

    new szMenu[512];
    new iLen = 0;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[管理员专属皮肤]^n^n");

    // 当前T皮肤
    new szTName[MAX_SKIN_NAME];
    if (g_iAdminSelectedT[id] >= 0 && g_iAdminSelectedT[id] < ArraySize(g_aAdminTModelNames)) {
        ArrayGetString(g_aAdminTModelNames, g_iAdminSelectedT[id], szTName, charsmax(szTName));
    } else {
        copy(szTName, charsmax(szTName), "默认");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w1. T皮肤: \y%s^n", szTName);

    // 当前CT皮肤
    new szCTName[MAX_SKIN_NAME];
    if (g_iAdminSelectedCT[id] >= 0 && g_iAdminSelectedCT[id] < ArraySize(g_aAdminCTModelNames)) {
        ArrayGetString(g_aAdminCTModelNames, g_iAdminSelectedCT[id], szCTName, charsmax(szCTName));
    } else {
        copy(szCTName, charsmax(szCTName), "默认");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w2. CT皮肤: \y%s^n", szCTName);

    // 当前刀皮肤
    new szKnifeName[MAX_SKIN_NAME];
    if (g_iAdminSelectedKnife[id] >= 0 && g_iAdminSelectedKnife[id] < ArraySize(g_aAdminKnifeModelNames)) {
        ArrayGetString(g_aAdminKnifeModelNames, g_iAdminSelectedKnife[id], szKnifeName, charsmax(szKnifeName));
    } else {
        copy(szKnifeName, charsmax(szKnifeName), "默认");
    }
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w3. 刀皮肤: \y%s^n", szKnifeName);

    // 重置
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w4. 全部重置为默认^n");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9), szMenu, -1, "Admin Skin Menu");
}

public handleAdminSkinMenu(const id, const key) {
    switch (key) {
        case 0: {
            showAdminSelectMenu(id, 0, 0);  // T
        }
        case 1: {
            showAdminSelectMenu(id, 1, 0);  // CT
        }
        case 2: {
            showAdminSelectMenu(id, 2, 0);  // Knife
        }
        case 3: {
            // 重置全部
            g_iAdminSelectedT[id] = -1;
            g_iAdminSelectedCT[id] = -1;
            g_iAdminSelectedKnife[id] = -1;
            save_admin_skins(id);
            client_print(id, print_chat, "[管理员皮肤] 已重置为默认");
            showAdminSkinMenu(id);
        }
        case 9: {
            // 返回
            showPlayerMenu(id);
        }
    }
    return PLUGIN_HANDLED;
}

// 管理员皮肤列表（带分页）
stock showAdminSelectMenu(const id, const iType, const iPage) {
    if (!is_user_connected(id)) {
        return;
    }

    if (!g_bAdminVerified[id]) {
        return;
    }

    g_iAdminSelectType[id] = iType;

    new Array:aModels, Array:aNames;
    new iSize;
    new iCurrent;
    new szTypeName[8];

    switch (iType) {
        case 0: {
            aModels = g_aAdminTModels;
            aNames = g_aAdminTModelNames;
            iCurrent = g_iAdminSelectedT[id];
            copy(szTypeName, charsmax(szTypeName), "T");
        }
        case 1: {
            aModels = g_aAdminCTModels;
            aNames = g_aAdminCTModelNames;
            iCurrent = g_iAdminSelectedCT[id];
            copy(szTypeName, charsmax(szTypeName), "CT");
        }
        case 2: {
            aModels = g_aAdminKnifeModels;
            aNames = g_aAdminKnifeModelNames;
            iCurrent = g_iAdminSelectedKnife[id];
            copy(szTypeName, charsmax(szTypeName), "刀");
        }
        default: return;
    }

    iSize = ArraySize(aModels);
    new iPerPage = MAX_MENU_PAGE;
    new iTotalPages = (iSize + iPerPage - 1) / iPerPage;
    if (iTotalPages < 1) {
        iTotalPages = 1;
    }

    new page = iPage;
    if (page < 0) page = 0;
    if (page >= iTotalPages) page = iTotalPages - 1;

    g_iAdminSelectPage[id] = page;

    new iStart = page * iPerPage;
    new iEnd = min(iStart + iPerPage, iSize);

    new szMenu[1024];
    new iLen = 0;
    new iKeys = (1 << 9); // 0 = 返回
    new iItemNum = 1;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[管理员%s皮肤] \y%d/%d^n^n", szTypeName, page + 1, iTotalPages);

    for (new i = iStart; i < iEnd; i++) {
        new szName[MAX_SKIN_NAME];
        ArrayGetString(aNames, i, szName, charsmax(szName));

        if (i == iCurrent) {
            iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. %s \r[已选]^n", iItemNum, szName);
        } else {
            iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. %s^n", iItemNum, szName);
        }

        iKeys |= (1 << (iItemNum - 1));
        iItemNum++;
    }

    // 翻页按钮
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

    if (page > 0) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w8. << 上一页^n");
        iKeys |= (1 << 7);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d8. << 上一页^n");
    }

    if (page < iTotalPages - 1) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w9. 下一页 >>^n");
        iKeys |= (1 << 8);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d9. 下一页 >>^n");
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, iKeys, szMenu, -1, "Admin Select");
}

public handleAdminSelectMenu(const id, const key) {
    if (key == 9) {
        showAdminSkinMenu(id);
        return PLUGIN_HANDLED;
    }

    new iType = g_iAdminSelectType[id];

    // 上一页
    if (key == 7) {
        showAdminSelectMenu(id, iType, g_iAdminSelectPage[id] - 1);
        return PLUGIN_HANDLED;
    }

    // 下一页
    if (key == 8) {
        showAdminSelectMenu(id, iType, g_iAdminSelectPage[id] + 1);
        return PLUGIN_HANDLED;
    }

    // 选择模型
    new Array:aModels, Array:aNames;
    new iSize;

    switch (iType) {
        case 0: { aModels = g_aAdminTModels; aNames = g_aAdminTModelNames;             }
        case 1: { aModels = g_aAdminCTModels; aNames = g_aAdminCTModelNames;             }
        case 2: { aModels = g_aAdminKnifeModels; aNames = g_aAdminKnifeModelNames;             }
        default: return PLUGIN_HANDLED;
    }

    iSize = ArraySize(aModels);
    new iPerPage = MAX_MENU_PAGE;
    new iModelIndex = g_iAdminSelectPage[id] * iPerPage + key;

    if (iModelIndex < 0 || iModelIndex >= iSize) {
        showAdminSelectMenu(id, iType, g_iAdminSelectPage[id]);
        return PLUGIN_HANDLED;
    }

    // 保存选择
    switch (iType) {
        case 0: {
            g_iAdminSelectedT[id] = iModelIndex;
        }
        case 1: {
            g_iAdminSelectedCT[id] = iModelIndex;
        }
        case 2: {
            g_iAdminSelectedKnife[id] = iModelIndex;
        }
    }

    save_admin_skins(id);

    // 获取名称
    new szName[MAX_SKIN_NAME];
    ArrayGetString(aNames, iModelIndex, szName, charsmax(szName));

    new szType[8];
    switch (iType) {
        case 0: {
            copy(szType, charsmax(szType), "T");
        }
        case 1: {
            copy(szType, charsmax(szType), "CT");
        }
        case 2: {
            copy(szType, charsmax(szType), "刀");
        }
    }

    client_print(id, print_chat, "[管理员皮肤] %s皮肤已设置为: %s", szType, szName);

    // 立即应用
    apply_model(id);

    showAdminSkinMenu(id);
    return PLUGIN_HANDLED;
}

// ============================================================
//  === 皮肤发放 ===
// ============================================================
public cmdGiveSkin(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    // 权限检查: Admin(2)及以上
    new iPermLevel = get_user_perm_level(id);
    if (iPermLevel < PERM_ADMIN) {
        client_print(id, print_chat, "[HNS] 只有管理员及以上才能发放皮肤");
        return PLUGIN_HANDLED;
    }

    // 解析参数: /give skin <玩家名> <T/CT/Knife> <皮肤名>
    new szArgs[256];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);

    // 去掉 "skin " 前缀
    new szTemp[256];
    copy(szTemp, charsmax(szTemp), szArgs);
    new iPos = contain(szTemp, "skin ");
    if (iPos >= 0) {
        copy(szArgs, charsmax(szArgs), szTemp[iPos + 5]);
        trim(szArgs);
    }

    // 解析: 玩家名 类型 皮肤名
    new szTargetName[32], szTypeStr[16], szSkinName[MAX_SKIN_NAME];
    parse(szArgs, szTargetName, charsmax(szTargetName), szTypeStr, charsmax(szTypeStr), szSkinName, charsmax(szSkinName));

    if (szTargetName[0] == EOS || szTypeStr[0] == EOS || szSkinName[0] == EOS) {
        // 参数不完整，打开菜单发放流程
        g_iGivePage[id] = 0;
        showGivePlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    // 查找目标玩家
    new iTarget = find_player_by_name(szTargetName);
    if (iTarget == 0) {
        client_print(id, print_chat, "[HNS] 找不到玩家: %s", szTargetName);
        return PLUGIN_HANDLED;
    }

    // 确定类型
    new iType = -1;
    if (equali(szTypeStr, "T") || equali(szTypeStr, "TT") || equali(szTypeStr, "Terrorist")) {
        iType = 0;
    } else if (equali(szTypeStr, "CT") || equali(szTypeStr, "CounterTerrorist")) {
        iType = 1;
    } else if (equali(szTypeStr, "Knife") || equali(szTypeStr, "Knives")) {
        iType = 2;
    }

    if (iType == -1) {
        client_print(id, print_chat, "[HNS] 无效的类型: %s (可用: T, CT, Knife)", szTypeStr);
        return PLUGIN_HANDLED;
    }

    // 查找皮肤索引
    new iSkinIndex = find_skin_index_by_name(iType, szSkinName);
    if (iSkinIndex == -1) {
        client_print(id, print_chat, "[HNS] 找不到皮肤: %s", szSkinName);
        return PLUGIN_HANDLED;
    }

    // 不能发放默认皮肤
    if (iSkinIndex == 0) {
        client_print(id, print_chat, "[HNS] 默认皮肤不需要发放");
        return PLUGIN_HANDLED;
    }

    // 发放皮肤
    give_skin(iTarget, iType, iSkinIndex);

    new szAdminName[32], szTargetRealName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));
    get_user_name(iTarget, szTargetRealName, charsmax(szTargetRealName));

    new szType[8];
    switch (iType) {
        case 0: {
            copy(szType, charsmax(szType), "T");
        }
        case 1: {
            copy(szType, charsmax(szType), "CT");
        }
        case 2: {
            copy(szType, charsmax(szType), "刀");
        }
    }

    // 获取皮肤显示名
    new Array:aNames;
    switch (iType) {
        case 0: {
            aNames = g_aTModelNames;
        }
        case 1: {
            aNames = g_aCTModelNames;
        }
        case 2: {
            aNames = g_aKnifeModelNames;
        }
        default: return PLUGIN_HANDLED;
    }
    new szRealSkinName[MAX_SKIN_NAME];
    ArrayGetString(aNames, iSkinIndex, szRealSkinName, charsmax(szRealSkinName));

    client_print(id, print_chat, "[HNS] 已向 %s 发放 %s皮肤: %s", szTargetRealName, szType, szRealSkinName);
    client_print(iTarget, print_chat, "[HNS] 管理员向你发放了 %s皮肤: %s", szType, szRealSkinName);

    // 日志
    log_amx("[SkinSystem] 管理员 %s 向 %s 发放 %s皮肤: %s", szAdminName, szTargetRealName, szType, szRealSkinName);

    return PLUGIN_HANDLED;
}

public cmdTakeSkin(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    // 权限检查: 仅Owner(3)
    new iPermLevel = get_user_perm_level(id);
    if (iPermLevel < PERM_OWNER) {
        client_print(id, print_chat, "[HNS] 只有最高服主才能收回皮肤");
        return PLUGIN_HANDLED;
    }

    // 解析参数: /take skin <玩家名> <皮肤名>
    new szArgs[256];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);

    // 去掉 "skin " 前缀
    new szTemp[256];
    copy(szTemp, charsmax(szTemp), szArgs);
    new iPos = contain(szTemp, "skin ");
    if (iPos >= 0) {
        copy(szArgs, charsmax(szArgs), szTemp[iPos + 5]);
        trim(szArgs);
    }

    new szTargetName[32], szSkinName[MAX_SKIN_NAME];
    parse(szArgs, szTargetName, charsmax(szTargetName), szSkinName, charsmax(szSkinName));

    if (szTargetName[0] == EOS || szSkinName[0] == EOS) {
        client_print(id, print_chat, "[HNS] 用法: /take skin <玩家名> <皮肤名>");
        return PLUGIN_HANDLED;
    }

    // 查找目标玩家
    new iTarget = find_player_by_name(szTargetName);
    if (iTarget == 0) {
        client_print(id, print_chat, "[HNS] 找不到玩家: %s", szTargetName);
        return PLUGIN_HANDLED;
    }

    // 在所有类型中查找皮肤
    new bool:bFound = false;
    new iType, iSkinIndex;

    // T
    iSkinIndex = find_skin_index_by_name(0, szSkinName);
    if (iSkinIndex > 0 && has_skin(iTarget, 0, iSkinIndex)) {
        iType = 0;
        bFound = true;
    }

    // CT
    if (!bFound) {
        iSkinIndex = find_skin_index_by_name(1, szSkinName);
        if (iSkinIndex > 0 && has_skin(iTarget, 1, iSkinIndex)) {
            iType = 1;
            bFound = true;
        }
    }

    // Knife
    if (!bFound) {
        iSkinIndex = find_skin_index_by_name(2, szSkinName);
        if (iSkinIndex > 0 && has_skin(iTarget, 2, iSkinIndex)) {
            iType = 2;
            bFound = true;
        }
    }

    if (!bFound) {
        client_print(id, print_chat, "[HNS] 玩家 %s 没有名为 %s 的皮肤", szTargetName, szSkinName);
        return PLUGIN_HANDLED;
    }

    // 收回皮肤
    take_skin(iTarget, iType, iSkinIndex);

    new szAdminName[32], szTargetRealName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));
    get_user_name(iTarget, szTargetRealName, charsmax(szTargetRealName));

    new szType[8];
    switch (iType) {
        case 0: {
            copy(szType, charsmax(szType), "T");
        }
        case 1: {
            copy(szType, charsmax(szType), "CT");
        }
        case 2: {
            copy(szType, charsmax(szType), "刀");
        }
    }

    client_print(id, print_chat, "[HNS] 已从 %s 收回 %s皮肤: %s", szTargetRealName, szType, szSkinName);
    client_print(iTarget, print_chat, "[HNS] 管理员收回了你的 %s皮肤: %s", szType, szSkinName);

    log_amx("[SkinSystem] 服主 %s 从 %s 收回 %s皮肤: %s", szAdminName, szTargetRealName, szType, szSkinName);

    return PLUGIN_HANDLED;
}

// 发放菜单 - 选玩家
stock showGivePlayerMenu(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "c");

    if (iNum == 0) {
        client_print(id, print_chat, "[HNS] 当前没有在线玩家");
        return;
    }

    new iPerPage = MAX_MENU_PAGE;
    new iTotalPages = (iNum + iPerPage - 1) / iPerPage;
    if (iTotalPages < 1) iTotalPages = 1;

    if (g_iGivePage[id] < 0) g_iGivePage[id] = 0;
    if (g_iGivePage[id] >= iTotalPages) g_iGivePage[id] = iTotalPages - 1;

    new iStart = g_iGivePage[id] * iPerPage;
    new iEnd = min(iStart + iPerPage, iNum);

    new szMenu[1024];
    new iLen = 0;
    new iKeys = (1 << 9); // 0 = 返回

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w选择玩家 \y%d/%d^n^n", g_iGivePage[id] + 1, iTotalPages);

    for (new i = iStart; i < iEnd; i++) {
        new pid = iPlayers[i];
        new szName[32];
        get_user_name(pid, szName, charsmax(szName));

        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. %s^n", (i - iStart) + 1, szName);
        iKeys |= (1 << (i - iStart));
    }

    // 翻页
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

    if (g_iGivePage[id] > 0) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w8. << 上一页^n");
        iKeys |= (1 << 7);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d8. << 上一页^n");
    }

    if (g_iGivePage[id] < iTotalPages - 1) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w9. 下一页 >>^n");
        iKeys |= (1 << 8);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d9. 下一页 >>^n");
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, iKeys, szMenu, -1, "Give Player Menu");
}

public handleGivePlayerMenu(const id, const key) {
    if (key == 9) {
        showPlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    // 上一页
    if (key == 7) {
        g_iGivePage[id]--;
        showGivePlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    // 下一页
    if (key == 8) {
        g_iGivePage[id]++;
        showGivePlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    // 选择玩家
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "c");
    new iPerPage = MAX_MENU_PAGE;
    new iIndex = g_iGivePage[id] * iPerPage + key;

    if (iIndex < 0 || iIndex >= iNum) {
        showGivePlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    g_iGiveTarget[id] = iPlayers[iIndex];
    showGiveTypeMenu(id);
    return PLUGIN_HANDLED;
}

// 发放菜单 - 选类型
stock showGiveTypeMenu(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[256];
    new iLen = 0;

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w选择皮肤类型^n^n");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w1. T皮肤^n");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w2. CT皮肤^n");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w3. 刀皮肤^n");
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<9), szMenu, -1, "Give Type Menu");
}

public handleGiveTypeMenu(const id, const key) {
    switch (key) {
        case 0: {
            g_iGiveType[id] = 0;
            showGiveSkinMenu(id, 0, 0);
        }
        case 1: {
            g_iGiveType[id] = 1;
            showGiveSkinMenu(id, 1, 0);
        }
        case 2: {
            g_iGiveType[id] = 2;
            showGiveSkinMenu(id, 2, 0);
        }
        case 9: {
            showGivePlayerMenu(id);
        }
    }
    return PLUGIN_HANDLED;
}

// 发放菜单 - 选皮肤
stock showGiveSkinMenu(const id, const iType, const iPage) {
    if (!is_user_connected(id)) {
        return;
    }

    new Array:aNames;
    new iSize;

    switch (iType) {
        case 0: {
            aNames = g_aTModelNames;
        }
        case 1: {
            aNames = g_aCTModelNames;
        }
        case 2: {
            aNames = g_aKnifeModelNames;
        }
        default: return;
    }

    iSize = ArraySize(aNames);
    new iPerPage = MAX_MENU_PAGE;
    new iTotalPages = (iSize + iPerPage - 1) / iPerPage;
    if (iTotalPages < 1) iTotalPages = 1;

    new page = iPage;
    if (page < 0) page = 0;
    if (page >= iTotalPages) page = iTotalPages - 1;

    g_iGivePage[id] = page;

    new iStart = page * iPerPage;
    new iEnd = min(iStart + iPerPage, iSize);

    new szMenu[1024];
    new iLen = 0;
    new iKeys = (1 << 9); // 0 = 返回
    new iItemNum = 1;

    new szTypeName[8];
    switch (iType) {
        case 0: {
            copy(szTypeName, charsmax(szTypeName), "T");
        }
        case 1: {
            copy(szTypeName, charsmax(szTypeName), "CT");
        }
        case 2: {
            copy(szTypeName, charsmax(szTypeName), "刀");
        }
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\r[HNS] \w选择%s皮肤 \y%d/%d^n^n", szTypeName, page + 1, iTotalPages);

    for (new i = iStart; i < iEnd; i++) {
        new szName[MAX_SKIN_NAME];
        ArrayGetString(aNames, i, szName, charsmax(szName));

        if (i == 0) {
            // 默认皮肤，不需要发放
            iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d%d. %s \r[默认]^n", iItemNum, szName);
        } else {
            iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. %s^n", iItemNum, szName);
            iKeys |= (1 << (iItemNum - 1));
        }

        iItemNum++;
    }

    // 翻页
    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

    if (page > 0) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w8. << 上一页^n");
        iKeys |= (1 << 7);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d8. << 上一页^n");
    }

    if (page < iTotalPages - 1) {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\w9. 下一页 >>^n");
        iKeys |= (1 << 8);
    } else {
        iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "\d9. 下一页 >>^n");
    }

    iLen += format(szMenu[iLen], charsmax(szMenu) - iLen, "^n\w0. 返回");

    show_menu(id, iKeys, szMenu, -1, "Give Skin Menu");
}

public handleGiveSkinMenu(const id, const key) {
    if (key == 9) {
        showGiveTypeMenu(id);
        return PLUGIN_HANDLED;
    }

    new iType = g_iGiveType[id];

    // 上一页
    if (key == 7) {
        showGiveSkinMenu(id, iType, g_iGivePage[id] - 1);
        return PLUGIN_HANDLED;
    }

    // 下一页
    if (key == 8) {
        showGiveSkinMenu(id, iType, g_iGivePage[id] + 1);
        return PLUGIN_HANDLED;
    }

    // 选择皮肤
    new Array:aNames;
    new iSize;

    switch (iType) {
        case 0: {
            aNames = g_aTModelNames;
        }
        case 1: {
            aNames = g_aCTModelNames;
        }
        case 2: {
            aNames = g_aKnifeModelNames;
        }
        default: return PLUGIN_HANDLED;
    }

    iSize = ArraySize(aNames);
    new iPerPage = MAX_MENU_PAGE;
    new iSkinIndex = g_iGivePage[id] * iPerPage + key;

    if (iSkinIndex < 0 || iSkinIndex >= iSize) {
        showGiveSkinMenu(id, iType, g_iGivePage[id]);
        return PLUGIN_HANDLED;
    }

    // 不能发放默认皮肤
    if (iSkinIndex == 0) {
        client_print(id, print_chat, "[HNS] 默认皮肤不需要发放");
        showGiveSkinMenu(id, iType, g_iGivePage[id]);
        return PLUGIN_HANDLED;
    }

    // 发放
    new iTarget = g_iGiveTarget[id];
    give_skin(iTarget, iType, iSkinIndex);

    new szAdminName[32], szTargetName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));
    get_user_name(iTarget, szTargetName, charsmax(szTargetName));

    new szSkinName[MAX_SKIN_NAME];
    ArrayGetString(aNames, iSkinIndex, szSkinName, charsmax(szSkinName));

    new szType[8];
    switch (iType) {
        case 0: {
            copy(szType, charsmax(szType), "T");
        }
        case 1: {
            copy(szType, charsmax(szType), "CT");
        }
        case 2: {
            copy(szType, charsmax(szType), "刀");
        }
    }

    client_print(id, print_chat, "[HNS] 已向 %s 发放 %s皮肤: %s", szTargetName, szType, szSkinName);
    client_print(iTarget, print_chat, "[HNS] 管理员向你发放了 %s皮肤: %s", szType, szSkinName);

    log_amx("[SkinSystem] 管理员 %s 向 %s 发放 %s皮肤: %s", szAdminName, szTargetName, szType, szSkinName);

    // 返回玩家选择
    showGivePlayerMenu(id);
    return PLUGIN_HANDLED;
}

// ============================================================
//  === 存档 ===
// ============================================================

// 保存玩家皮肤到PDS+文件
stock save_player_skins(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szIdentifier[MAX_AUTHID_LENGTH];
    get_player_identifier(id, szIdentifier, charsmax(szIdentifier));

    if (szIdentifier[0] == EOS) {
        return;
    }

    // 构建JSON数据
    new szData[1024];
    new szAuth[MAX_AUTHID_LENGTH], szIP[MAX_AUTHID_LENGTH], szName[32];
    get_user_authid(id, szAuth, charsmax(szAuth));
    get_user_ip(id, szIP, charsmax(szIP), 1);
    get_user_name(id, szName, charsmax(szName));

    // 替换名字中的双引号
    /*replace_all(szName, charsmax(szName), "^"^"", "'");*/
    new szQuote[2] = {34, 0}; replace_all(szName, charsmax(szName), szQuote, "'");

    new iLen = 0;
    iLen += format(szData[iLen], charsmax(szData) - iLen, "{^"auth^":^"%s^",^"ip^":^"%s^",^"name^":^"%s^",^"t^":[", szAuth, szIP, szName);

    // T皮肤数组
    for (new i = 0; i < g_iOwnedTCount[id]; i++) {
        if (i > 0) {
            iLen += format(szData[iLen], charsmax(szData) - iLen, ",");
        }
        iLen += format(szData[iLen], charsmax(szData) - iLen, "%d", g_iOwnedT[id][i]);
    }
    iLen += format(szData[iLen], charsmax(szData) - iLen, "],^"ct^":[");

    // CT皮肤数组
    for (new i = 0; i < g_iOwnedCTCount[id]; i++) {
        if (i > 0) {
            iLen += format(szData[iLen], charsmax(szData) - iLen, ",");
        }
        iLen += format(szData[iLen], charsmax(szData) - iLen, "%d", g_iOwnedCT[id][i]);
    }
    iLen += format(szData[iLen], charsmax(szData) - iLen, "],^"knife^":[");

    // 刀皮肤数组
    for (new i = 0; i < g_iOwnedKnifeCount[id]; i++) {
        if (i > 0) {
            iLen += format(szData[iLen], charsmax(szData) - iLen, ",");
        }
        iLen += format(szData[iLen], charsmax(szData) - iLen, "%d", g_iOwnedKnife[id][i]);
    }
    iLen += format(szData[iLen], charsmax(szData) - iLen, "]}");

    // 保存到PDS
    new szKey[128];
    format(szKey, charsmax(szKey), "hns_skin_%s", szIdentifier);
    PDS_SetString(szKey, szData);

    // 保存选择到PDS
    format(szKey, charsmax(szKey), "hns_skin_sel_t_%s", szIdentifier);
    PDS_SetCell(szKey, g_iSelectedT[id]);
    format(szKey, charsmax(szKey), "hns_skin_sel_ct_%s", szIdentifier);
    PDS_SetCell(szKey, g_iSelectedCT[id]);
    format(szKey, charsmax(szKey), "hns_skin_sel_knife_%s", szIdentifier);
    PDS_SetCell(szKey, g_iSelectedKnife[id]);

    // 保存到文件
    save_skin_data_to_file();
}

// 从PDS+文件加载玩家皮肤
stock load_player_skins(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szIdentifier[MAX_AUTHID_LENGTH];
    get_player_identifier(id, szIdentifier, charsmax(szIdentifier));

    if (szIdentifier[0] == EOS) {
        return;
    }

    new szKey[128];
    new szData[1024];
    new bool:bLoaded = false;

    format(szKey, charsmax(szKey), "hns_skin_%s", szIdentifier);
    if (PDS_GetString(szKey, szData, charsmax(szData))) {
        bLoaded = true;
    }

    // 未登录账号时保留旧兼容逻辑：SteamID -> IP -> 名字
    if (!bLoaded && !g_bAccountLoggedIn[id]) {
        new szAuth[MAX_AUTHID_LENGTH];
        get_user_authid(id, szAuth, charsmax(szAuth));

        if (!equal(szAuth, "STEAM_ID_LAN") && !equal(szAuth, "VALVE_ID_LAN")) {
            format(szKey, charsmax(szKey), "hns_skin_%s", szAuth);
            if (PDS_GetString(szKey, szData, charsmax(szData))) {
                bLoaded = true;
            }
        }
    }

    if (!bLoaded && !g_bAccountLoggedIn[id]) {
        new szIP[MAX_AUTHID_LENGTH];
        get_user_ip(id, szIP, charsmax(szIP), 1);
        format(szKey, charsmax(szKey), "hns_skin_%s", szIP);
        if (PDS_GetString(szKey, szData, charsmax(szData))) {
            bLoaded = true;
        }
    }

    if (!bLoaded && !g_bAccountLoggedIn[id]) {
        new szName[32];
        get_user_name(id, szName, charsmax(szName));
        format(szKey, charsmax(szKey), "hns_skin_%s", szName);
        if (PDS_GetString(szKey, szData, charsmax(szData))) {
            bLoaded = true;
        }
    }

    // 如果PDS中没找到，从文件加载（仅旧兼容模式使用）
    if (!bLoaded && !g_bAccountLoggedIn[id]) {
        load_skin_data_from_file_for_player(id);
    }

    if (bLoaded) {
        parse_skin_json(id, szData);
    }

    // 加载选择
    format(szKey, charsmax(szKey), "hns_skin_sel_t_%s", szIdentifier);
    new iVal;
    if (PDS_GetCell(szKey, iVal)) {
        g_iSelectedT[id] = iVal;
    }
    format(szKey, charsmax(szKey), "hns_skin_sel_ct_%s", szIdentifier);
    if (PDS_GetCell(szKey, iVal)) {
        g_iSelectedCT[id] = iVal;
    }
    format(szKey, charsmax(szKey), "hns_skin_sel_knife_%s", szIdentifier);
    if (PDS_GetCell(szKey, iVal)) {
        g_iSelectedKnife[id] = iVal;
    }

    // 确保每个分类的第一个皮肤（默认皮肤）已拥有
    ensure_default_skins(id);
}

// 保存管理员皮肤选择到PDS
stock save_admin_skins(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szAuth[MAX_AUTHID_LENGTH];
    get_player_identifier(id, szAuth, charsmax(szAuth));

    if (szAuth[0] == EOS) {
        return;
    }

    new szKey[128];
    format(szKey, charsmax(szKey), "hns_admin_t_%s", szAuth);
    PDS_SetCell(szKey, g_iAdminSelectedT[id]);

    format(szKey, charsmax(szKey), "hns_admin_ct_%s", szAuth);
    PDS_SetCell(szKey, g_iAdminSelectedCT[id]);

    format(szKey, charsmax(szKey), "hns_admin_knife_%s", szAuth);
    PDS_SetCell(szKey, g_iAdminSelectedKnife[id]);

    // 保存验证状态
    format(szKey, charsmax(szKey), "hns_admin_verified_%s", szAuth);
    PDS_SetCell(szKey, g_bAdminVerified[id] ? 1 : 0);
}

// 加载管理员皮肤选择从PDS
stock load_admin_skins(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szAuth[MAX_AUTHID_LENGTH];
    get_player_identifier(id, szAuth, charsmax(szAuth));

    if (szAuth[0] == EOS) {
        return;
    }

    new szKey[128];
    new iVal;

    format(szKey, charsmax(szKey), "hns_admin_t_%s", szAuth);
    if (PDS_GetCell(szKey, iVal)) {
        g_iAdminSelectedT[id] = iVal;
    }

    format(szKey, charsmax(szKey), "hns_admin_ct_%s", szAuth);
    if (PDS_GetCell(szKey, iVal)) {
        g_iAdminSelectedCT[id] = iVal;
    }

    format(szKey, charsmax(szKey), "hns_admin_knife_%s", szAuth);
    if (PDS_GetCell(szKey, iVal)) {
        g_iAdminSelectedKnife[id] = iVal;
    }

    // 加载验证状态
    format(szKey, charsmax(szKey), "hns_admin_verified_%s", szAuth);
    if (PDS_GetCell(szKey, iVal)) {
        g_bAdminVerified[id] = (iVal == 1);
    }
}

// 保存皮肤数据到文件
stock save_skin_data_to_file() {
    new szPath[256];
    get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
    format(szPath, charsmax(szPath), "%s/mixsystem/skin_data.txt", szPath);

    new f = fopen(szPath, "wt");
    if (!f) {
        log_amx("[SkinSystem] 无法打开皮肤数据文件进行写入: %s", szPath);
        return;
    }

    // 遍历所有已连接玩家，保存数据
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "c");

    for (new p = 0; p < iNum; p++) {
        new pid = iPlayers[p];

        new szAuth[MAX_AUTHID_LENGTH], szIP[MAX_AUTHID_LENGTH], szName[32];
        get_user_authid(pid, szAuth, charsmax(szAuth));
        get_user_ip(pid, szIP, charsmax(szIP), 1);
        get_user_name(pid, szName, charsmax(szName));

        // 替换名字中的双引号
        /*replace_all(szName, charsmax(szName), "^"^"", "'");*/
    new szQuote[2] = {34, 0}; replace_all(szName, charsmax(szName), szQuote, "'");

        new szLine[1024];
        new iLen = 0;

        iLen += format(szLine[iLen], charsmax(szLine) - iLen, "{^"auth^":^"%s^",^"ip^":^"%s^",^"name^":^"%s^",^"t^":[", szAuth, szIP, szName);

        for (new i = 0; i < g_iOwnedTCount[pid]; i++) {
            if (i > 0) iLen += format(szLine[iLen], charsmax(szLine) - iLen, ",");
            iLen += format(szLine[iLen], charsmax(szLine) - iLen, "%d", g_iOwnedT[pid][i]);
        }
        iLen += format(szLine[iLen], charsmax(szLine) - iLen, "],^"ct^":[");

        for (new i = 0; i < g_iOwnedCTCount[pid]; i++) {
            if (i > 0) iLen += format(szLine[iLen], charsmax(szLine) - iLen, ",");
            iLen += format(szLine[iLen], charsmax(szLine) - iLen, "%d", g_iOwnedCT[pid][i]);
        }
        iLen += format(szLine[iLen], charsmax(szLine) - iLen, "],^"knife^":[");

        for (new i = 0; i < g_iOwnedKnifeCount[pid]; i++) {
            if (i > 0) iLen += format(szLine[iLen], charsmax(szLine) - iLen, ",");
            iLen += format(szLine[iLen], charsmax(szLine) - iLen, "%d", g_iOwnedKnife[pid][i]);
        }
        iLen += format(szLine[iLen], charsmax(szLine) - iLen, "]}");

        fprintf(f, "%s^n", szLine);
    }

    fclose(f);
}

// 从文件加载皮肤数据（给特定玩家）
stock load_skin_data_from_file_for_player(const id) {
    new szPath[256];
    get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
    format(szPath, charsmax(szPath), "%s/mixsystem/skin_data.txt", szPath);

    new f = fopen(szPath, "rt");
    if (!f) {
        return;
    }

    new szAuth[MAX_AUTHID_LENGTH], szIP[MAX_AUTHID_LENGTH], szName[32];
    get_user_authid(id, szAuth, charsmax(szAuth));
    get_user_ip(id, szIP, charsmax(szIP), 1);
    get_user_name(id, szName, charsmax(szName));

    new szLine[1024];
    new bool:bFound = false;

    while (!feof(f) && !bFound) {
        fgets(f, szLine, charsmax(szLine));
        trim(szLine);

        if (szLine[0] == EOS) {
            continue;
        }

        // 检查是否匹配当前玩家
        // 先检查auth
        if (contain(szLine, szAuth) == -1) {
            continue;
        }

        // 检查IP
        if (contain(szLine, szIP) == -1) {
            continue;
        }

        // 检查名字
        if (contain(szLine, szName) == -1) {
            continue;
        }

        // 匹配成功，解析
        parse_skin_json(id, szLine);
        bFound = true;

        // 同步到PDS
        new szIdentifier[MAX_AUTHID_LENGTH];
        get_player_identifier(id, szIdentifier, charsmax(szIdentifier));
        new szKey[128];
        format(szKey, charsmax(szKey), "hns_skin_%s", szIdentifier);
        PDS_SetString(szKey, szLine);
    }

    fclose(f);
}

// 解析皮肤JSON数据
stock parse_skin_json(const id, const szData[]) {
    // 简单JSON解析（不使用JSON库，手动解析）
    // 格式: {"auth":"xxx","ip":"xxx","name":"xxx","t":[0,1,2],"ct":[0,1],"knife":[0]}

    // 解析T数组
    new szTSection[256];
    if (extract_json_array(szData, "t", szTSection, charsmax(szTSection))) {
        parse_skin_array(szTSection, g_iOwnedT[id], g_iOwnedTCount[id]);
    }

    // 解析CT数组
    new szCTSection[256];
    if (extract_json_array(szData, "ct", szCTSection, charsmax(szCTSection))) {
        parse_skin_array(szCTSection, g_iOwnedCT[id], g_iOwnedCTCount[id]);
    }

    // 解析Knife数组
    new szKnifeSection[256];
    if (extract_json_array(szData, "knife", szKnifeSection, charsmax(szKnifeSection))) {
        parse_skin_array(szKnifeSection, g_iOwnedKnife[id], g_iOwnedKnifeCount[id]);
    }
}

// 从JSON中提取数组部分
stock bool:extract_json_array(const szJson[], const szKey[], szOut[], iOutLen) {
    // 查找 "key":[
    new szSearch[32];
    formatex(szSearch, charsmax(szSearch), "^"%s^":[", szKey);

    new iPos = contain(szJson, szSearch);
    if (iPos == -1) {
        return false;
    }

    iPos += strlen(szSearch);

    // 查找结束的 ]
    new iEnd = contain(szJson[iPos], "]");
    if (iEnd == -1) {
        return false;
    }

    new iCopyLen = iEnd;
    if (iCopyLen >= iOutLen) {
        iCopyLen = iOutLen - 1;
    }
    copy(szOut, iCopyLen, szJson[iPos]);

    return true;
}

// 解析皮肤索引数组 "0,1,2"
stock parse_skin_array(const szArray[], iOut[], &iOutCount) {
    iOutCount = 0;

    new szTemp[256];
    copy(szTemp, charsmax(szTemp), szArray);
    trim(szTemp);

    if (szTemp[0] == EOS) {
        return;
    }

    new iLen = strlen(szTemp);
    new iStart = 0;

    for (new i = 0; i <= iLen && iOutCount < MAX_OWNED_SKINS; i++) {
        if (szTemp[i] == ',' || szTemp[i] == EOS) {
            if (i > iStart) {
                new szNum[16];
                new iNumLen = i - iStart;
                if (iNumLen >= charsmax(szNum)) {
                    iNumLen = charsmax(szNum) - 1;
                }
                copy(szNum, iNumLen, szTemp[iStart]);
                trim(szNum);

                if (szNum[0] != EOS) {
                    iOut[iOutCount] = str_to_num(szNum);
                    iOutCount++;
                }
            }
            iStart = i + 1;
        }
    }
}

// 确保默认皮肤已拥有
stock ensure_default_skins(const id) {
    // T默认皮肤（索引0）
    if (!has_skin(id, 0, 0)) {
        give_skin(id, 0, 0);
    }

    // CT默认皮肤（索引0）
    if (!has_skin(id, 1, 0)) {
        give_skin(id, 1, 0);
    }

    // 刀默认皮肤（索引0）
    if (!has_skin(id, 2, 0)) {
        give_skin(id, 2, 0);
    }
}

// ============================================================
//  === 工具函数 ===
// ============================================================

// 检查玩家是否拥有某皮肤
stock bool:has_skin(const id, const iType, const iSkinIndex) {
    switch (iType) {
        case 0: {
            for (new i = 0; i < g_iOwnedTCount[id]; i++) {
                if (g_iOwnedT[id][i] == iSkinIndex) {
                    return true;
                }
            }
        }
        case 1: {
            for (new i = 0; i < g_iOwnedCTCount[id]; i++) {
                if (g_iOwnedCT[id][i] == iSkinIndex) {
                    return true;
                }
            }
        }
        case 2: {
            for (new i = 0; i < g_iOwnedKnifeCount[id]; i++) {
                if (g_iOwnedKnife[id][i] == iSkinIndex) {
                    return true;
                }
            }
        }
    }
    return false;
}

// 发放皮肤
stock give_skin(const id, const iType, const iSkinIndex) {
    // 检查是否已拥有
    if (has_skin(id, iType, iSkinIndex)) {
        return;
    }

    switch (iType) {
        case 0: {
            if (g_iOwnedTCount[id] < MAX_OWNED_SKINS) {
                g_iOwnedT[id][g_iOwnedTCount[id]] = iSkinIndex;
                g_iOwnedTCount[id]++;
            }
        }
        case 1: {
            if (g_iOwnedCTCount[id] < MAX_OWNED_SKINS) {
                g_iOwnedCT[id][g_iOwnedCTCount[id]] = iSkinIndex;
                g_iOwnedCTCount[id]++;
            }
        }
        case 2: {
            if (g_iOwnedKnifeCount[id] < MAX_OWNED_SKINS) {
                g_iOwnedKnife[id][g_iOwnedKnifeCount[id]] = iSkinIndex;
                g_iOwnedKnifeCount[id]++;
            }
        }
    }
}

// 收回皮肤
stock take_skin(const id, const iType, const iSkinIndex) {
    switch (iType) {
        case 0: {
            for (new i = 0; i < g_iOwnedTCount[id]; i++) {
                if (g_iOwnedT[id][i] == iSkinIndex) {
                    // 移除：将后面的元素前移
                    for (new j = i; j < g_iOwnedTCount[id] - 1; j++) {
                        g_iOwnedT[id][j] = g_iOwnedT[id][j + 1];
                    }
                    g_iOwnedTCount[id]--;
                    // 如果当前选择的就是这个皮肤，重置
                    if (g_iSelectedT[id] == iSkinIndex) {
                        g_iSelectedT[id] = 0; // 回到默认
                    }
                }
            }
        }
        case 1: {
            for (new i = 0; i < g_iOwnedCTCount[id]; i++) {
                if (g_iOwnedCT[id][i] == iSkinIndex) {
                    for (new j = i; j < g_iOwnedCTCount[id] - 1; j++) {
                        g_iOwnedCT[id][j] = g_iOwnedCT[id][j + 1];
                    }
                    g_iOwnedCTCount[id]--;
                    if (g_iSelectedCT[id] == iSkinIndex) {
                        g_iSelectedCT[id] = 0;
                    }
                }
            }
        }
        case 2: {
            for (new i = 0; i < g_iOwnedKnifeCount[id]; i++) {
                if (g_iOwnedKnife[id][i] == iSkinIndex) {
                    for (new j = i; j < g_iOwnedKnifeCount[id] - 1; j++) {
                        g_iOwnedKnife[id][j] = g_iOwnedKnife[id][j + 1];
                    }
                    g_iOwnedKnifeCount[id]--;
                    if (g_iSelectedKnife[id] == iSkinIndex) {
                        g_iSelectedKnife[id] = 0;
                    }
                }
            }
        }
    }
}

stock strip_account_command_prefix(szArgs[], iLen, const szPrefix[]) {
    if (containi(szArgs, szPrefix) == 0) {
        copy(szArgs, iLen, szArgs[strlen(szPrefix)]);
        trim(szArgs);
    }
}

stock normalize_account_name(const szInput[], szOutput[], iLen) {
    copy(szOutput, iLen, szInput);
    trim(szOutput);
    strtolower(szOutput);
}

stock bool:is_valid_account_name(const szAccount[]) {
    new iLen = strlen(szAccount);
    if (iLen < 3 || iLen > 24) {
        return false;
    }

    for (new i = 0; i < iLen; i++) {
        new c = szAccount[i];
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-') {
            continue;
        }
        return false;
    }

    return true;
}

stock bool:is_valid_account_password(const szPassword[]) {
    new iLen = strlen(szPassword);
    return (iLen >= 4 && iLen <= 32);
}

stock get_account_file_path(szPath[], iLen) {
    get_localinfo("amxx_configsdir", szPath, iLen);
    format(szPath, iLen, "%s/mixsystem/skin_accounts.txt", szPath);
}

stock hash_account_password(const szAccount[], const szPassword[], szOutput[], iOutputLen) {
    new szSource[160];
    formatex(szSource, charsmax(szSource), "%s|%s|%s", ACCOUNT_HASH_SALT, szAccount, szPassword);
    hash_string(szSource, Hash_Sha256, szOutput, iOutputLen);
}

stock bool:find_account_record(const szAccount[], szHashOut[], iHashLen) {
    new szPath[256];
    get_account_file_path(szPath, charsmax(szPath));

    new f = fopen(szPath, "rt");
    if (!f) {
        return false;
    }

    new szLine[256], szStoredAccount[MAX_ACCOUNT_NAME], szRest[160];
    new bool:bFound = false;

    while (!feof(f) && !bFound) {
        fgets(f, szLine, charsmax(szLine));
        trim(szLine);

        if (szLine[0] == EOS || szLine[0] == ';' || szLine[0] == '#') {
            continue;
        }

        strtok2(szLine, szStoredAccount, charsmax(szStoredAccount), szRest, charsmax(szRest), '|', TRIM_FULL);
        if (equali(szStoredAccount, szAccount)) {
            copy(szHashOut, iHashLen, szRest);
            bFound = true;
        }
    }

    fclose(f);
    return bFound;
}

stock bool:append_account_record(const szAccount[], const szHash[]) {
    new szPath[256];
    get_account_file_path(szPath, charsmax(szPath));

    new f = fopen(szPath, "at");
    if (!f) {
        return false;
    }

    fprintf(f, "%s|%s^n", szAccount, szHash);
    fclose(f);
    return true;
}

// 获取玩家标识（优先内测账号，其次SteamID/IP）
stock get_player_identifier(const id, szOut[], iLen) {
    if (g_bAccountLoggedIn[id] && g_szAccountName[id][0] != EOS) {
        formatex(szOut, iLen, "acc_%s", g_szAccountName[id]);
        return;
    }

    new szAuth[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuth, charsmax(szAuth));

    // 正版玩家用SteamID
    if (!equal(szAuth, "STEAM_ID_LAN") && !equal(szAuth, "VALVE_ID_LAN")) {
        copy(szOut, iLen, szAuth);
        return;
    }

    // 盗版玩家用IP
    new szIP[MAX_AUTHID_LENGTH];
    get_user_ip(id, szIP, charsmax(szIP), 1);
    copy(szOut, iLen, szIP);
}

// 按名字查找玩家
stock find_player_by_name(const szName[]) {
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "c");

    // 精确匹配
    for (new i = 0; i < iNum; i++) {
        new szPlayerName[32];
        get_user_name(iPlayers[i], szPlayerName, charsmax(szPlayerName));
        if (equal(szPlayerName, szName)) {
            return iPlayers[i];
        }
    }

    // 部分匹配
    for (new i = 0; i < iNum; i++) {
        new szPlayerName[32];
        get_user_name(iPlayers[i], szPlayerName, charsmax(szPlayerName));
        if (containi(szPlayerName, szName) >= 0) {
            return iPlayers[i];
        }
    }

    return 0;
}

// 按皮肤名查找皮肤索引
stock find_skin_index_by_name(const iType, const szName[]) {
    new Array:aNames;
    switch (iType) {
        case 0: {
            aNames = g_aTModelNames;
        }
        case 1: {
            aNames = g_aCTModelNames;
        }
        case 2: {
            aNames = g_aKnifeModelNames;
        }
        default: return -1;
    }

    new iSize = ArraySize(aNames);
    for (new i = 0; i < iSize; i++) {
        new szSkinName[MAX_SKIN_NAME];
        ArrayGetString(aNames, i, szSkinName, charsmax(szSkinName));
        if (equali(szSkinName, szName)) {
            return i;
        }
    }

    // 部分匹配
    for (new i = 0; i < iSize; i++) {
        new szSkinName[MAX_SKIN_NAME];
        ArrayGetString(aNames, i, szSkinName, charsmax(szSkinName));
        if (containi(szSkinName, szName) >= 0) {
            return i;
        }
    }

    return -1;
}

// 获取玩家权限等级（通过PDS读取）
stock get_user_perm_level(const id) {
    new szAuth[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuth, charsmax(szAuth));

    // 盗版玩家用IP
    if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN")) {
        get_user_ip(id, szAuth, charsmax(szAuth), 1);
    }

    new szKey[128];
    format(szKey, charsmax(szKey), "hns_perm_level_%s", szAuth);

    new iLevel;
    if (PDS_GetCell(szKey, iLevel)) {
        return iLevel;
    }

    // 尝试旧格式键名
    if (contain(szAuth, "STEAM_") != -1) {
        format(szKey, charsmax(szKey), "hns_perm_%s", szAuth);
    } else {
        format(szKey, charsmax(szKey), "hns_permip_%s", szAuth);
    }

    // 旧格式存的是字符串
    new szVal[8];
    if (PDS_GetString(szKey, szVal, charsmax(szVal))) {
        return str_to_num(szVal);
    }

    return PERM_NONE;
}

// 清理动态数组
stock cleanup_arrays() {
    if (g_aTModels != Invalid_Array) { ArrayDestroy(g_aTModels); g_aTModels = Invalid_Array; }
    if (g_aTModelNames != Invalid_Array) { ArrayDestroy(g_aTModelNames); g_aTModelNames = Invalid_Array; }
    if (g_aCTModels != Invalid_Array) { ArrayDestroy(g_aCTModels); g_aCTModels = Invalid_Array; }
    if (g_aCTModelNames != Invalid_Array) { ArrayDestroy(g_aCTModelNames); g_aCTModelNames = Invalid_Array; }
    if (g_aKnifeModels != Invalid_Array) { ArrayDestroy(g_aKnifeModels); g_aKnifeModels = Invalid_Array; }
    if (g_aKnifeModelNames != Invalid_Array) { ArrayDestroy(g_aKnifeModelNames); g_aKnifeModelNames = Invalid_Array; }

    if (g_aAdminTModels != Invalid_Array) { ArrayDestroy(g_aAdminTModels); g_aAdminTModels = Invalid_Array; }
    if (g_aAdminTModelNames != Invalid_Array) { ArrayDestroy(g_aAdminTModelNames); g_aAdminTModelNames = Invalid_Array; }
    if (g_aAdminCTModels != Invalid_Array) { ArrayDestroy(g_aAdminCTModels); g_aAdminCTModels = Invalid_Array; }
    if (g_aAdminCTModelNames != Invalid_Array) { ArrayDestroy(g_aAdminCTModelNames); g_aAdminCTModelNames = Invalid_Array; }
    if (g_aAdminKnifeModels != Invalid_Array) { ArrayDestroy(g_aAdminKnifeModels); g_aAdminKnifeModels = Invalid_Array; }
    if (g_aAdminKnifeModelNames != Invalid_Array) { ArrayDestroy(g_aAdminKnifeModelNames); g_aAdminKnifeModelNames = Invalid_Array; }
}
