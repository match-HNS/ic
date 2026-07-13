/*
 * HNS Match Skin - 统一皮肤系统
 * 合并了: 玩家皮肤 + 管理员皮肤 + M键菜单 + 皮肤发放
 *
 * 功能:
 * 1. 普通玩家皮肤系统 (读取 player_models.ini)
 * 2. 管理员专属皮肤系统 (读取 admin_models.ini, AMXX管理员权限即可使用)
 * 3. M键玩家菜单 (chooseteam拦截 + /menu命令)
 * 4. 皮肤发放机制 (/give skin, /take skin)
 *
 * 命令:
 * /model, /skin - 打开皮肤菜单
 * /menu - 打开M键主菜单
 * /adminskin - 管理员皮肤菜单 (需AMXX管理员权限)
 * /give skin <玩家> <T/CT/Knife> <皮肤名> - 发放皮肤
 * /take skin <玩家> <皮肤名> - 收回皮肤(仅Owner)
 */

#include <amxmodx>
#include <fakemeta>
#include <amxmisc>
#include <reapi>
// View model will be set via find_weapon_and_set_view()
#include <nvault>
#include <hns_matchsystem>
// pev_viewmodel is 27, included via fakemeta.inc
#define pev_viewmodel2 28

// 前向声明
stock bool:has_skin(const id, const iType, const iSkinIndex);
stock give_skin(const id, const iType, const iSkinIndex);

// ============================================================
//  插件信息
// ============================================================
#define PLUGIN_NAME "HNS Match Skin"
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
#define Invalid_Array       -1
#define EOS                 0

// 权限等级
#define PERM_NONE           0
#define PERM_VIP            1
#define PERM_ADMIN          2
#define PERM_OWNER          3

// 比赛状态
#define MATCH_NONE          0

// 管理员皮肤 - 拥有AMXX管理员权限即可使用
#define ADMIN_SKIN_FLAG         ADMIN_LEVEL_A

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
new g_iGiveMode[MAX_PLAYERS + 1];         // 发放模式 0=单个, 1=全部
new g_iGiveType[MAX_PLAYERS + 1];         // 发放类型 1=T, 2=CT, 3=Knife
new g_iGivePage[MAX_PLAYERS + 1];         // 发放菜单翻页

// ============================================================
//  全局变量 - 玩家标识
// ============================================================
new g_szPlayerAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];
new g_szPlayerIP[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];
new g_szPlayerName[MAX_PLAYERS + 1][32];

// nvault 句柄
new g_iVault = INVALID_HANDLE;

// ============================================================
//  plugin_precache - 加载模型配置并预缓存
// ============================================================
public plugin_precache() {
    server_print("[SkinSystem] plugin_precache: 开始加载模型...");
    load_player_models();
    load_admin_models();
    precache_all_models();
    server_print("[SkinSystem] plugin_precache: 完成! T=%d, CT=%d, Knife=%d, AdminT=%d, AdminCT=%d, AdminK=%d",
        ArraySize(g_aTModels), ArraySize(g_aCTModels), ArraySize(g_aKnifeModels),
        ArraySize(g_aAdminTModels), ArraySize(g_aAdminCTModels), ArraySize(g_aAdminKnifeModels));
}

// ============================================================
//  plugin_init - 注册命令、菜单、事件
// ============================================================
public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
    
    // 注册CVAR：标记高级皮肤系统已激活，防止 player_models.inc 冲突
    register_cvar("hns_skin_advanced", "1");

    // 打开 nvault 数据库
    g_iVault = nvault_open("hns_skin_vault");

    // === 命令注册 ===
    // 皮肤菜单 - 重定向到 M键菜单
    // register_clcmd("say /model", "cmdMenu");
    // register_clcmd("say /skin", "cmdMenu");
    // register_clcmd("say /models", "cmdMenu");
    // register_clcmd("say /skins", "cmdMenu");
    register_clcmd("say /skin_t", "cmdSkinSelectT");
    register_clcmd("say /skin_ct", "cmdSkinSelectCT");
    register_clcmd("say /skin_knife", "cmdSkinSelectKnife");

    // 皮肤批量发放 - 通过 server_cmd 调用
    register_srvcmd("hns_giveallskins_menu", "srvCmdGiveAllSkins");
    register_srvcmd("hns_giveskin_menu", "srvCmdGiveSkinMenu");  // ★ 单个发放菜单
    // register_clcmd("say_team /model", "cmdMenu");
    // register_clcmd("say_team /skin", "cmdMenu");
    // register_clcmd("say_team /models", "cmdMenu");
    // register_clcmd("say_team /skins", "cmdMenu");

    // M键菜单 - 通过 /skinmenu 打开
    // register_clcmd("say /skinmenu", "cmdMenu");
    // ★ /menu 已由 HnsMatchSystem 接管，此处不重复注册
    // register_clcmd("say /skins", "cmdMenu");

    // 皮肤选择菜单注册
    register_menucmd(register_menuid("HnsICSkinSelect"), 1023, "handleSkinSelectMenu");

    // 皮肤批量发放
    register_clcmd("say /giveallskins", "cmdGiveAllSkins");
    
    // 管理员给指定玩家发放单个皮肤 - 菜单方式
    register_clcmd("say /giveskin", "cmdGiveSkinMenuStart");
    register_clcmd("say /giveskinmenu", "cmdGiveSkinMenuStart");
    
    // 管理员给指定玩家发放单个皮肤 - 命令行方式
    register_clcmd("say /giveskinid", "cmdGiveSkinCmd");
    
    // 管理员皮肤 - 直接打开，权限检查在函数内
    register_clcmd("say /adminskin", "cmdAdminSkinMenu");
    
    // 菜单处理
    register_menucmd(register_menuid("HnsIAdminSkinMain"), 1023, "handleAdminSkinMainMenu");
    register_menucmd(register_menuid("HnsIAdminSkinSelect"), 1023, "handleAdminSkinSelectMenu");
    register_menucmd(register_menuid("HnsIGiveSelectPlayer"), 1023, "handleGiveSelectPlayer");
    register_menucmd(register_menuid("HnsIGiveSelectType"), 1023, "handleGiveSelectType");
    register_menucmd(register_menuid("HnsIGiveSelectSkin"), 1023, "handleGiveSelectSkin");
    register_menucmd(register_menuid("HnsIGiveSelectSkinList"), 1023, "handleGiveSelectSkinList");

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
// 安全设置玩家刀模型（取代危险的 m_szViewModel 偏移）
// 通过找到玩家持有的刀武器实体来设置 pev_viewmodel
stock set_player_knife_view(const id, const szPath[]) {
    if (!is_user_alive(id) || !is_user_connected(id)) {
        return;
    }
    
    // 遍历所有实体，找到属于该玩家的刀武器
    new iEnt = engfunc(EngFunc_FindEntityByString, -1, "classname", "weapon_knife");
    while (iEnt) {
        new iOwner = pev(iEnt, pev_owner);
        if (iOwner == id) {
            set_pev(iEnt, pev_viewmodel, szPath);
            set_pev(iEnt, pev_viewmodel2, szPath);
            return;
        }
        iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "weapon_knife");
    }
}

public plugin_end() {
    // 关闭 nvault 数据库
    if (g_iVault != INVALID_HANDLE) {
        nvault_close(g_iVault);
    }
    cleanup_arrays();
    
    server_print("[SkinSystem] plugin_init: 完成! Hook已注册, 皮肤菜单已就绪");
}

// ============================================================
//  client_putinserver - 初始化+加载存档
// ============================================================
public client_putinserver(id) {
    if (is_user_bot(id) || is_user_hltv(id)) {
        // 机器人/HLTV: 只设置默认模型，不加载存档
        g_iSelectedT[id] = 0;
        g_iSelectedCT[id] = 0;
        g_iSelectedKnife[id] = 0;
        g_iOwnedTCount[id] = 0;
        g_iOwnedCTCount[id] = 0;
        g_iOwnedKnifeCount[id] = 0;
        g_bAdminVerified[id] = false;
        g_iAdminSelectedT[id] = -1;
        g_iAdminSelectedCT[id] = -1;
        g_iAdminSelectedKnife[id] = -1;
        g_iSkinSelectType[id] = 0;
        g_iSkinSelectPage[id] = 0;
        g_iVerifyStep[id] = 0;
        g_iAdminSelectType[id] = 0;
        g_iAdminSelectPage[id] = 0;
        g_iGiveTarget[id] = 0;
        g_iGiveMode[id] = 0;
        g_iGiveType[id] = 0;
        g_iGivePage[id] = 0;
        g_szPlayerAuth[id][0] = EOS;
        g_szPlayerIP[id][0] = EOS;
        g_szPlayerName[id][0] = EOS;
        return;
    }

    // 重置所有数据
    reset_player_data(id);

    // 获取玩家标识信息
    get_user_authid(id, g_szPlayerAuth[id], charsmax(g_szPlayerAuth[]));
    get_user_ip(id, g_szPlayerIP[id], charsmax(g_szPlayerIP[]), 1);
    get_user_name(id, g_szPlayerName[id], charsmax(g_szPlayerName[]));

    // 加载存档
    load_player_skins(id);
    load_admin_skins(id);
}

// ============================================================
//  client_disconnected - 保存存档
// ============================================================
public client_disconnected(id) {
    if (is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    save_player_skins(id);
    save_admin_skins(id);
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
        load_player_skins(id);
        load_admin_skins(id);
    }
}

// ============================================================
//  重置玩家数据
// ============================================================
stock reset_player_data(id) {
    g_iOwnedTCount[id] = 0;
    g_iOwnedCTCount[id] = 0;
    g_iOwnedKnifeCount[id] = 0;
    g_iSelectedT[id] = -1;
    g_iSelectedCT[id] = -1;
    g_iSelectedKnife[id] = -1;
    g_iSkinSelectType[id] = 0;
    g_iSkinSelectPage[id] = 0;

    g_bAdminVerified[id] = false;
    g_iVerifyStep[id] = 0;
    g_iAdminSelectedT[id] = -1;
    g_iAdminSelectedCT[id] = -1;
    g_iAdminSelectedKnife[id] = -1;
    g_iAdminSelectType[id] = 0;
    g_iAdminSelectPage[id] = 0;

    g_iGiveTarget[id] = 0;
    g_iGiveMode[id] = 0;
    g_iGiveType[id] = 0;
    g_iGivePage[id] = 0;

    g_szPlayerAuth[id][0] = EOS;
    g_szPlayerIP[id][0] = EOS;
    g_szPlayerName[id][0] = EOS;
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
        log_amx("[SkinSystem] 普通皮肤配置文件不存在: %s, 使用内置默认模型", szPath);
        load_default_player_models();
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

// 内置默认模型（配置文件不存在时使用）
stock load_default_player_models() {
    // T阵营默认模型（CS 1.6 原版）
    ArrayPushString(g_aTModels, "models/player/arctic/arctic.mdl");
    ArrayPushString(g_aTModelNames, "默认T");
    ArrayPushString(g_aTModels, "models/player/guerilla/guerilla.mdl");
    ArrayPushString(g_aTModelNames, "中东游击");
    ArrayPushString(g_aTModels, "models/player/leet/leet.mdl");
    ArrayPushString(g_aTModelNames, "精英部队");
    ArrayPushString(g_aTModels, "models/player/terror/terror.mdl");
    ArrayPushString(g_aTModelNames, "凤凰战士");

    // CT阵营默认模型
    ArrayPushString(g_aCTModels, "models/player/gsg9/gsg9.mdl");
    ArrayPushString(g_aCTModelNames, "默认CT");
    ArrayPushString(g_aCTModels, "models/player/gsg9/gsg9.mdl");
    ArrayPushString(g_aCTModelNames, "德国GSG9");
    ArrayPushString(g_aCTModels, "models/player/gign/gign.mdl");
    ArrayPushString(g_aCTModelNames, "法国GIGN");
    ArrayPushString(g_aCTModels, "models/player/sas/sas.mdl");
    ArrayPushString(g_aCTModelNames, "英国SAS");
    ArrayPushString(g_aCTModels, "models/player/urban/urban.mdl");
    ArrayPushString(g_aCTModelNames, "美国城市特警");

    // 刀默认模型
    ArrayPushString(g_aKnifeModels, "models/v_knife.mdl");
    ArrayPushString(g_aKnifeModelNames, "默认刀");

    log_amx("[SkinSystem] 已加载内置默认皮肤: T=%d, CT=%d, Knife=%d",
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
    // 不检查 is_user_alive，因为 ReGameDLL post-hook 可能在 deadflag 重置前触发
    // task_apply_model 内部有 is_user_alive 检查，延迟 0.1 秒后必定 alive
    set_task(0.15, "task_apply_model", id);
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
    new bool:bModelApplied = false;

    // --- 身体模型 ---
    if (iTeam == TEAM_TERRORIST) {
        // 优先检查管理员皮肤 (AMXX管理员权限)
        if (is_user_admin(id) && g_iAdminSelectedT[id] >= 0) {
            new iSize = ArraySize(g_aAdminTModels);
            if (g_iAdminSelectedT[id] < iSize) {
                new szPath[MAX_MODEL_NAME];
                new szFolder[MAX_MODEL_NAME];
                ArrayGetString(g_aAdminTModels, g_iAdminSelectedT[id], szPath, charsmax(szPath));
                extract_folder_from_path(szPath, szFolder, charsmax(szFolder));
                rg_set_user_model(id, szFolder, true);
                bModelApplied = true;
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
                rg_set_user_model(id, szFolder, true);
                bModelApplied = true;
            }
        }
        // 否则用CS默认模型（不设置）
    }
    else if (iTeam == TEAM_CT) {
        // 优先检查管理员皮肤 (AMXX管理员权限)
        if (is_user_admin(id) && g_iAdminSelectedCT[id] >= 0) {
            new iSize = ArraySize(g_aAdminCTModels);
            if (g_iAdminSelectedCT[id] < iSize) {
                new szPath[MAX_MODEL_NAME];
                new szFolder[MAX_MODEL_NAME];
                ArrayGetString(g_aAdminCTModels, g_iAdminSelectedCT[id], szPath, charsmax(szPath));
                extract_folder_from_path(szPath, szFolder, charsmax(szFolder));
                rg_set_user_model(id, szFolder, true);
                bModelApplied = true;
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
                rg_set_user_model(id, szFolder, true);
                bModelApplied = true;
            }
        }
    }

    // --- 刀模型 ---
    // 优先管理员刀皮
    if (is_user_admin(id) && g_iAdminSelectedKnife[id] >= 0) {
        new iSize = ArraySize(g_aAdminKnifeModels);
        if (g_iAdminSelectedKnife[id] < iSize) {
            new szPath[MAX_MODEL_NAME];
            ArrayGetString(g_aAdminKnifeModels, g_iAdminSelectedKnife[id], szPath, charsmax(szPath));
            set_player_knife_view(id, szPath);
        }
    }
    // 其次普通刀皮
    else if (g_iSelectedKnife[id] >= 0) {
        new iSize = ArraySize(g_aKnifeModels);
        if (g_iSelectedKnife[id] < iSize) {
            new szPath[MAX_MODEL_NAME];
            ArrayGetString(g_aKnifeModels, g_iSelectedKnife[id], szPath, charsmax(szPath));
            set_player_knife_view(id, szPath);
        }
    }
    
    // 调试日志：每5秒输出一次模型应用状态
    static iDebugTick2 = 0;
    iDebugTick2++;
    if (iDebugTick2 % 50 == 0) {
        new szName[32];
        get_user_name(id, szName, charsmax(szName));
        server_print("[Skin-DEBUG] apply_model: %s team=%d, admin=%d, selT=%d selCT=%d selK=%d, adminSelT=%d adminSelCT=%d adminSelK=%d, applied=%d",
            szName, iTeam, g_bAdminVerified[id], g_iSelectedT[id], g_iSelectedCT[id], g_iSelectedKnife[id],
            g_iAdminSelectedT[id], g_iAdminSelectedCT[id], g_iAdminSelectedKnife[id], bModelApplied);
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
//  === 皮肤选择菜单 ===
// ============================================================

public srvCmdGiveAllSkins() {
    new szUserId[8], szType[16];
    read_argv(1, szUserId, charsmax(szUserId));
    read_argv(2, szType, charsmax(szType));
    
    new id = find_player("k", str_to_num(szUserId));
    if (!id || !is_user_connected(id)) return PLUGIN_HANDLED;
    
    if (equali(szType, "T")) {
        new iTotal = ArraySize(g_aTModels);
        g_iOwnedTCount[id] = 0;
        for (new i = 0; i < iTotal && i < MAX_OWNED_SKINS; i++) {
            g_iOwnedT[id][i] = i;
            g_iOwnedTCount[id]++;
        }
        if (g_iSelectedT[id] < 0) g_iSelectedT[id] = 0;
        save_player_skins(id);
        client_print(id, print_chat, "[HNS] 管理员已发放全部T皮肤给你(%d个)", iTotal);
    } else if (equali(szType, "CT")) {
        new iTotal = ArraySize(g_aCTModels);
        g_iOwnedCTCount[id] = 0;
        for (new i = 0; i < iTotal && i < MAX_OWNED_SKINS; i++) {
            g_iOwnedCT[id][i] = i;
            g_iOwnedCTCount[id]++;
        }
        if (g_iSelectedCT[id] < 0) g_iSelectedCT[id] = 0;
        save_player_skins(id);
        client_print(id, print_chat, "[HNS] 管理员已发放全部CT皮肤给你(%d个)", iTotal);
    } else if (equali(szType, "Knife")) {
        new iTotal = ArraySize(g_aKnifeModels);
        g_iOwnedKnifeCount[id] = 0;
        for (new i = 0; i < iTotal && i < MAX_OWNED_SKINS; i++) {
            g_iOwnedKnife[id][i] = i;
            g_iOwnedKnifeCount[id]++;
        }
        if (g_iSelectedKnife[id] < 0) g_iSelectedKnife[id] = 0;
        save_player_skins(id);
        client_print(id, print_chat, "[HNS] 管理员已发放全部刀皮肤给你(%d个)", iTotal);
    }
    
    if (is_user_alive(id)) apply_model(id);
    return PLUGIN_HANDLED;
}

// ★ 单个发放皮肤 - 从菜单触发（server_cmd）
public srvCmdGiveSkinMenu() {
    new szAdminId[8], szTargetId[8], szType[16];
    read_argv(1, szAdminId, charsmax(szAdminId));
    read_argv(2, szTargetId, charsmax(szTargetId));
    read_argv(3, szType, charsmax(szType));
    
    new id = find_player("k", str_to_num(szAdminId));
    new iTarget = find_player("k", str_to_num(szTargetId));
    if (!id || !is_user_connected(id)) return PLUGIN_HANDLED;
    if (!iTarget || !is_user_connected(iTarget)) {
        client_print(id, print_chat, "[HNS] 目标玩家已离线");
        return PLUGIN_HANDLED;
    }
    
    // 设置发放状态
    g_iGiveTarget[id] = iTarget;
    g_iGivePage[id] = 0;
    g_iGiveMode[id] = 0; // 设为单个发放模式
    
    if (equali(szType, "T")) {
        g_iGiveType[id] = 1;  // T = type 1
    } else if (equali(szType, "CT")) {
        g_iGiveType[id] = 2;  // CT = type 2
    } else if (equali(szType, "Knife")) {
        g_iGiveType[id] = 3;  // Knife = type 3
    } else {
        return PLUGIN_HANDLED;
    }
    
    showGiveSkinListMenu(id);
    return PLUGIN_HANDLED;
}

public cmdSkinSelectT(const id) {
    g_iSkinSelectType[id] = 0;
    g_iSkinSelectPage[id] = 0;
    showSkinSelectMenu(id);
    return PLUGIN_HANDLED;
}

public cmdSkinSelectCT(const id) {
    g_iSkinSelectType[id] = 1;
    g_iSkinSelectPage[id] = 0;
    showSkinSelectMenu(id);
    return PLUGIN_HANDLED;
}

public cmdSkinSelectKnife(const id) {
    g_iSkinSelectType[id] = 2;
    g_iSkinSelectPage[id] = 0;
    showSkinSelectMenu(id);
    return PLUGIN_HANDLED;
}

// 检查玩家是否拥有指定索引的皮肤
bool:is_skin_owned(const id, const iType, const iModelIdx) {
    new iOwnedCount, iOwned[MAX_OWNED_SKINS];
    if (iType == 0) {
        iOwnedCount = g_iOwnedTCount[id];
        for (new i = 0; i < iOwnedCount; i++) iOwned[i] = g_iOwnedT[id][i];
    } else if (iType == 1) {
        iOwnedCount = g_iOwnedCTCount[id];
        for (new i = 0; i < iOwnedCount; i++) iOwned[i] = g_iOwnedCT[id][i];
    } else {
        iOwnedCount = g_iOwnedKnifeCount[id];
        for (new i = 0; i < iOwnedCount; i++) iOwned[i] = g_iOwnedKnife[id][i];
    }
    for (new i = 0; i < iOwnedCount; i++) {
        if (iOwned[i] == iModelIdx) return true;
    }
    return false;
}

showSkinSelectMenu(const id) {
    if (!is_user_connected(id)) return;
    
    new iType = g_iSkinSelectType[id];
    new iPage = g_iSkinSelectPage[id];
    
    // 获取该类型的模型数组
    new Array:aModels, Array:aModelNames;
    new iSelected, szTitle[32];
    
    if (iType == 0) {  // T
        aModels = g_aTModels;
        aModelNames = g_aTModelNames;
        iSelected = g_iSelectedT[id];
        copy(szTitle, charsmax(szTitle), "T(土匪)皮肤");
    }
    else if (iType == 1) {  // CT
        aModels = g_aCTModels;
        aModelNames = g_aCTModelNames;
        iSelected = g_iSelectedCT[id];
        copy(szTitle, charsmax(szTitle), "CT(警察)皮肤");
    }
    else if (iType == 2) {  // Knife
        aModels = g_aKnifeModels;
        aModelNames = g_aKnifeModelNames;
        iSelected = g_iSelectedKnife[id];
        copy(szTitle, charsmax(szTitle), "刀皮肤");
    }
    
    new iTotalModels = ArraySize(aModels);
    if (iTotalModels <= 0) {
        client_print(id, print_chat, "[HNS] 暂无可用皮肤");
        return;
    }
    
    // 分页: 每页7项，遍历全部皮肤（不管是否已拥有）
    new iStart = iPage * 7;
    new iEnd = iStart + 7;
    if (iEnd > iTotalModels) iEnd = iTotalModels;
    
    new szMenu[512], iLen;
    iLen = formatex(szMenu, charsmax(szMenu), "\y%s \r- \w选择皮肤^n\y─────── 第%d页 ───────^n^n", szTitle, iPage + 1);
    
    new szName[64], iModelIdx;
    new bool:bOwned;
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9);
    
    for (new i = iStart; i < iEnd; i++) {
        iModelIdx = i;  // 直接使用模型索引
        ArrayGetString(aModelNames, iModelIdx, szName, charsmax(szName));
        bOwned = is_skin_owned(id, iType, iModelIdx);
        
        new iSlot = i - iStart + 1;
        new szMarker[8] = "";
        if (iModelIdx == iSelected) copy(szMarker, charsmax(szMarker), " ✓");
        
        if (bOwned) {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s%s^n", iSlot, szName, szMarker);
        } else {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \d%s \r(未解锁)^n", iSlot, szName);
        }
    }
    
    // 填充空位
    for (new i = iEnd; i < iStart + 7; i++) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
    }
    
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y───────^n");
    
    // 翻页按钮
    if (iPage > 0) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w上一页^n");
    } else {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回^n");
    }
    
    if (iTotalModels > iEnd) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w下一页^n");
    } else {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
    }
    
    show_menu(id, iKeys, szMenu, -1, "HnsICSkinSelect");
}

public handleSkinSelectMenu(const id, const key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    
    new iType = g_iSkinSelectType[id];
    new iPage = g_iSkinSelectPage[id];
    
    // 获取总皮肤数
    new Array:aModels;
    if (iType == 0) aModels = g_aTModels;
    else if (iType == 1) aModels = g_aCTModels;
    else aModels = g_aKnifeModels;
    new iTotalModels = ArraySize(aModels);
    
    // AMXX旧式菜单: 按1→key=0, 按9→key=8, 按0→key=9
    // 按9键 → key=8 → 下一页
    if (key == 8) {
        // 下一页
        g_iSkinSelectPage[id]++;
        showSkinSelectMenu(id);
        return PLUGIN_HANDLED;
    }
    
    // 按0键 → key=9 → 上一页 或 返回
    if (key == 9) {
        // 上一页 或 返回
        if (iPage > 0) {
            g_iSkinSelectPage[id]--;
            showSkinSelectMenu(id);
        }
        // 首页按0返回 - 什么也不做，菜单关闭
        return PLUGIN_HANDLED;
    }
    
    // 选择皮肤 (按1-7 → key=0-6)
    new iSlot = key;  // key已经是0-indexed，直接使用
    new iModelIdx = iPage * 7 + iSlot;
    
    // 防止页码超出上限
    new iMaxPage = ((iTotalModels - 1) / 7);
    if (g_iSkinSelectPage[id] > iMaxPage) g_iSkinSelectPage[id] = iMaxPage;
    if (g_iSkinSelectPage[id] < 0) g_iSkinSelectPage[id] = 0;
    
    if (iModelIdx >= 0 && iModelIdx < iTotalModels) {
        // 检查是否拥有该皮肤
        if (!is_skin_owned(id, iType, iModelIdx)) {
            client_print(id, print_chat, "[HNS] 该皮肤尚未解锁！请联系管理员获取");
            showSkinSelectMenu(id);
            return PLUGIN_HANDLED;
        }
        
        // 应用皮肤
        if (iType == 0) {  // T
            g_iSelectedT[id] = iModelIdx;
            save_player_skins(id);
            apply_model(id);
        }
        else if (iType == 1) {  // CT
            g_iSelectedCT[id] = iModelIdx;
            save_player_skins(id);
            apply_model(id);
        }
        else if (iType == 2) {  // Knife
            g_iSelectedKnife[id] = iModelIdx;
            save_player_skins(id);
            apply_model(id);  // 换刀后也要应用
        }
        
        // 刷新菜单
        set_task(0.1, "taskRefreshSkinMenu", id);
    }
    
    return PLUGIN_HANDLED;
}

public taskRefreshSkinMenu(const id) {
    if (is_user_connected(id)) {
        showSkinSelectMenu(id);
    }
}

// ============================================================
//  === 管理员皮肤菜单 ===
// ============================================================

// /adminskin 命令 - 管理员直接打开皮肤菜单
public cmdAdminSkinMenu(const id) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    
    // 检查管理员权限
    if (!(get_user_flags(id) & ADMIN_SKIN_FLAG) && !is_user_admin(id)) {
        client_print(id, print_chat, "[HNS] 只有管理员才能使用管理员皮肤系统");
        return PLUGIN_HANDLED;
    }
    
    // 自动标记为已验证
    g_bAdminVerified[id] = true;
    showAdminSkinMainMenu(id);
    return PLUGIN_HANDLED;
}

// 管理员皮肤主菜单 - 选择 T/CT/Knife
showAdminSkinMainMenu(const id) {
    new szMenu[256];
    new iLen = formatex(szMenu, charsmax(szMenu), "\y管理员皮肤选择^n\y───────^n^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wT(土匪)皮肤^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wCT(警察)皮肤^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w刀皮肤^n^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w退出^n");
    
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<9), szMenu, -1, "HnsIAdminSkinMain");
}

public handleAdminSkinMainMenu(const id, const key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (!(get_user_flags(id) & ADMIN_SKIN_FLAG) && !is_user_admin(id)) {
        client_print(id, print_chat, "[HNS] 只有管理员才能使用管理员皮肤系统");
        return PLUGIN_HANDLED;
    }
    
    switch (key) {
        case 0: { g_iAdminSelectType[id] = 0; g_iAdminSelectPage[id] = 0; showAdminSkinSelectMenu(id); return PLUGIN_HANDLED; }
        case 1: { g_iAdminSelectType[id] = 1; g_iAdminSelectPage[id] = 0; showAdminSkinSelectMenu(id); return PLUGIN_HANDLED; }
        case 2: { g_iAdminSelectType[id] = 2; g_iAdminSelectPage[id] = 0; showAdminSkinSelectMenu(id); return PLUGIN_HANDLED; }
    }
}

// 管理员皮肤选择菜单 - 分页显示
showAdminSkinSelectMenu(const id) {
    if (!is_user_connected(id)) return;
    
    new iType = g_iAdminSelectType[id];
    new iPage = g_iAdminSelectPage[id];
    
    new Array:aModels, Array:aModelNames;
    new iSelected;
    new szTitle[32];
    
    if (iType == 0) {
        aModels = g_aAdminTModels;
        aModelNames = g_aAdminTModelNames;
        iSelected = g_iAdminSelectedT[id];
        copy(szTitle, charsmax(szTitle), "管理员T皮肤");
    } else if (iType == 1) {
        aModels = g_aAdminCTModels;
        aModelNames = g_aAdminCTModelNames;
        iSelected = g_iAdminSelectedCT[id];
        copy(szTitle, charsmax(szTitle), "管理员CT皮肤");
    } else {
        aModels = g_aAdminKnifeModels;
        aModelNames = g_aAdminKnifeModelNames;
        iSelected = g_iAdminSelectedKnife[id];
        copy(szTitle, charsmax(szTitle), "管理员刀皮肤");
    }
    
    new iTotalModels = ArraySize(aModels);
    if (iTotalModels <= 0) {
        client_print(id, print_chat, "[HNS] 暂无管理员皮肤");
        showAdminSkinMainMenu(id);
        return;
    }
    
    new iStart = iPage * 7;
    new iEnd = iStart + 7;
    if (iEnd > iTotalModels) iEnd = iTotalModels;
    
    new szMenu[512], iLen;
    iLen = formatex(szMenu, charsmax(szMenu), "\y%s \r- \w选择皮肤^n\y─────── 第%d页 ───────^n^n", szTitle, iPage + 1);
    
    new szName[64], iModelIdx;
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9);
    
    for (new i = iStart; i < iEnd; i++) {
        iModelIdx = i;
        ArrayGetString(aModelNames, iModelIdx, szName, charsmax(szName));
        
        new iSlot = i - iStart + 1;
        new szMarker[8] = "";
        if (iModelIdx == iSelected) copy(szMarker, charsmax(szMarker), " ✓");
        
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s%s^n", iSlot, szName, szMarker);
    }
    
    for (new i = iEnd; i < iStart + 7; i++) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
    }
    
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y───────^n");
    
    if (iPage > 0) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w上一页^n");
    } else {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回^n");
    }
    
    if (iTotalModels > iEnd) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w下一页^n");
    }
    
    show_menu(id, iKeys, szMenu, -1, "HnsIAdminSkinSelect");
}

public handleAdminSkinSelectMenu(const id, const key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (!(get_user_flags(id) & ADMIN_SKIN_FLAG) && !is_user_admin(id)) {
        client_print(id, print_chat, "[HNS] 只有管理员才能使用管理员皮肤系统");
        return PLUGIN_HANDLED;
    }
    
    new iType = g_iAdminSelectType[id];
    new iPage = g_iAdminSelectPage[id];
    
    new Array:aModels;
    if (iType == 0) aModels = g_aAdminTModels;
    else if (iType == 1) aModels = g_aAdminCTModels;
    else aModels = g_aAdminKnifeModels;
    new iTotalModels = ArraySize(aModels);
    
    // 按9 → 下一页
    if (key == 8) {
        g_iAdminSelectPage[id]++;
        showAdminSkinSelectMenu(id);
        return PLUGIN_HANDLED;
    }
    
    // 按0 → 上一页/返回
    if (key == 9) {
        if (iPage > 0) {
            g_iAdminSelectPage[id]--;
            showAdminSkinSelectMenu(id);
        } else {
            showAdminSkinMainMenu(id);
        }
        return PLUGIN_HANDLED;
    }
    
    // 选择皮肤
    new iModelIdx = iPage * 7 + key;
    if (iModelIdx >= 0 && iModelIdx < iTotalModels) {
        if (iType == 0) {
            g_iAdminSelectedT[id] = iModelIdx;
        } else if (iType == 1) {
            g_iAdminSelectedCT[id] = iModelIdx;
        } else {
            g_iAdminSelectedKnife[id] = iModelIdx;
        }
        save_admin_skins(id);
        apply_model(id);
        client_print(id, print_chat, "[HNS] 管理员皮肤已应用!");
        set_task(0.15, "taskRefreshAdminSkinMenu", id);
    }
    
    return PLUGIN_HANDLED;
}

public taskRefreshAdminSkinMenu(const id) {
    if (is_user_connected(id)) {
        showAdminSkinSelectMenu(id);
    }
}

// ============================================================
//  === M键玩家菜单 ===
// ============================================================

public cmdMenu(const id) {
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }
    // 打开新M键主菜单
    client_cmd(id, "chooseteam");
    return PLUGIN_HANDLED;
}

// ============================================================
//  === 批量发放全部皮肤 (/giveallskins) ===
// ============================================================
public cmdGiveAllSkins(const id) {
    if (!is_user_connected(id)) return PLUGIN_CONTINUE;

    // 权限检查: Admin(2)及以上，或 AMXX users.ini 管理员
    new iPermLevel = get_user_perm_level(id);
    if (iPermLevel < PERM_ADMIN && !(get_user_flags(id) & ADMIN_IMMUNITY)) {
        client_print(id, print_chat, "[HNS] 只有管理员及以上才能发放皮肤");
        return PLUGIN_HANDLED;
    }

    // 解析参数: /giveallskins <玩家名> <T/CT/Knife/all>
    new szArgs[256];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);

    // 去掉 "giveallskins " 前缀
    new szTemp[256];
    copy(szTemp, charsmax(szTemp), szArgs);
    new iPos = contain(szTemp, "giveallskins ");
    if (iPos >= 0) {
        copy(szArgs, charsmax(szArgs), szTemp[iPos + 13]);
        trim(szArgs);
    }

    new szTargetName[32], szTypeStr[16];
    parse(szArgs, szTargetName, charsmax(szTargetName), szTypeStr, charsmax(szTypeStr));

    if (szTargetName[0] == EOS || szTypeStr[0] == EOS) {
        client_print(id, print_chat, "[HNS] 用法: /giveallskins <玩家名> <T/CT/Knife/all>");
        return PLUGIN_HANDLED;
    }

    // 查找目标玩家
    new iTarget = find_player_by_name(szTargetName);
    if (iTarget == 0) {
        client_print(id, print_chat, "[HNS] 找不到玩家: %s", szTargetName);
        return PLUGIN_HANDLED;
    }

    new szAdminName[32], szTargetRealName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));
    get_user_name(iTarget, szTargetRealName, charsmax(szTargetRealName));

    new iCount = 0;
    new bool:bT = false, bool:bCT = false, bool:bKnife = false;

    if (equali(szTypeStr, "all")) {
        bT = true; bCT = true; bKnife = true;
    } else if (equali(szTypeStr, "T") || equali(szTypeStr, "t")) {
        bT = true;
    } else if (equali(szTypeStr, "CT") || equali(szTypeStr, "ct")) {
        bCT = true;
    } else if (equali(szTypeStr, "Knife") || equali(szTypeStr, "knife") || equali(szTypeStr, "刀")) {
        bKnife = true;
    } else {
        client_print(id, print_chat, "[HNS] 无效类型: %s, 请用 T/CT/Knife/all", szTypeStr);
        return PLUGIN_HANDLED;
    }

    // Give T skins
    if (bT) {
        new iSize = ArraySize(g_aTModels);
        for (new i = 0; i < iSize; i++) {
            if (!has_skin(iTarget, 0, i)) {
                give_skin(iTarget, 0, i);
                iCount++;
            }
        }
        // Give admin T skins too
        new iAdminSize = ArraySize(g_aAdminTModels);
        for (new i = 0; i < iAdminSize; i++) {
            if (!has_skin(iTarget, 0, i + iSize)) {
                give_skin(iTarget, 0, i + iSize);
                iCount++;
            }
        }
    }

    // Give CT skins
    if (bCT) {
        new iSize = ArraySize(g_aCTModels);
        for (new i = 0; i < iSize; i++) {
            if (!has_skin(iTarget, 1, i)) {
                give_skin(iTarget, 1, i);
                iCount++;
            }
        }
        new iAdminSize = ArraySize(g_aAdminCTModels);
        for (new i = 0; i < iAdminSize; i++) {
            if (!has_skin(iTarget, 1, i + iSize)) {
                give_skin(iTarget, 1, i + iSize);
                iCount++;
            }
        }
    }

    // Give Knife skins
    if (bKnife) {
        new iSize = ArraySize(g_aKnifeModels);
        for (new i = 0; i < iSize; i++) {
            if (!has_skin(iTarget, 2, i)) {
                give_skin(iTarget, 2, i);
                iCount++;
            }
        }
        new iAdminSize = ArraySize(g_aAdminKnifeModels);
        for (new i = 0; i < iAdminSize; i++) {
            if (!has_skin(iTarget, 2, i + iSize)) {
                give_skin(iTarget, 2, i + iSize);
                iCount++;
            }
        }
    }

    client_print(id, print_chat, "[HNS] 已向 %s 发放 %s类型全部皮肤 (%d个)", szTargetRealName, szTypeStr, iCount);
    client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了 %s类型全部皮肤 (%d个)", szAdminName, szTypeStr, iCount);
    log_amx("[SkinSystem] 管理员 %s 向 %s 发放 %s类型全部皮肤 (%d个)", szAdminName, szTargetRealName, szTypeStr, iCount);

    return PLUGIN_HANDLED;
}

// ============================================================
//  === 管理员给指定玩家发放皮肤 - 菜单方式 (/giveskin) ===
// ============================================================

// 第一步：显示在线玩家列表，选择目标玩家
public cmdGiveSkinMenuStart(const id) {
    if (!is_user_connected(id)) return PLUGIN_CONTINUE;
    
    new iPermLevel = get_user_perm_level(id);
    if (iPermLevel < PERM_ADMIN && !(get_user_flags(id) & ADMIN_IMMUNITY)) {
        client_print(id, print_chat, "[HNS] 只有管理员及以上才能发放皮肤");
        return PLUGIN_HANDLED;
    }
    
    g_iGivePage[id] = 0;
    showGiveSelectPlayerMenu(id);
    return PLUGIN_HANDLED;
}

showGiveSelectPlayerMenu(const id) {
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "ch");
    
    if (iNum == 0) {
        client_print(id, print_chat, "[HNS] 当前没有在线玩家");
        return;
    }
    
    new iPage = g_iGivePage[id];
    new iStart = iPage * 8;
    new iEnd = iStart + 8;
    if (iEnd > iNum) iEnd = iNum;
    
    new szMenu[512], iLen, szName[32], iPlayer;
    iLen = formatex(szMenu, charsmax(szMenu), "\y选择要发放皮肤的目标玩家^n\y─────── 第%d页 ───────^n^n", iPage + 1);
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9);
    
    for (new i = iStart; i < iEnd; i++) {
        iPlayer = iPlayers[i];
        get_user_name(iPlayer, szName, charsmax(szName));
        new iSlot = i - iStart + 1;
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iSlot, szName);
    }
    
    for (new i = iEnd; i < iStart + 8; i++) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
    }
    
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y───────^n");
    if (iPage > 0) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w上一页^n");
    } else {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回^n");
    }
    if (iNum > iEnd) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w下一页^n");
    }
    
    show_menu(id, iKeys, szMenu, -1, "HnsIGiveSelectPlayer");
}

public handleGiveSelectPlayer(const id, const key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    
    new iPlayers[MAX_PLAYERS], iNum;
    get_players(iPlayers, iNum, "ch");
    
    if (key == 8) {  // 下一页
        g_iGivePage[id]++;
        showGiveSelectPlayerMenu(id);
        return PLUGIN_HANDLED;
    }
    if (key == 9) {  // 上一页/返回
        if (g_iGivePage[id] > 0) {
            g_iGivePage[id]--;
            showGiveSelectPlayerMenu(id);
        }
        return PLUGIN_HANDLED;
    }
    
    new iAbsIndex = g_iGivePage[id] * 8 + key;
    if (iAbsIndex >= 0 && iAbsIndex < iNum) {
        g_iGiveTarget[id] = iPlayers[iAbsIndex];
        g_iGivePage[id] = 0;
        showGiveSelectTypeMenu(id);
    }
    
    return PLUGIN_HANDLED;
}

// 第二步：选择发放类型（单个发放 / 全部发放）
showGiveSelectTypeMenu(const id) {
    new iTarget = g_iGiveTarget[id];
    if (!is_user_connected(iTarget)) {
        client_print(id, print_chat, "[HNS] 目标玩家已离线");
        return PLUGIN_HANDLED;
    }
    
    new szTargetName[32];
    get_user_name(iTarget, szTargetName, charsmax(szTargetName));
    
    new szMenu[256];
    formatex(szMenu, charsmax(szMenu), "\y向 \r%s \y发放皮肤^n^n\r1. \w单个发放皮肤^n\r2. \w全部发放皮肤^n^n\r0. \w返回", szTargetName);
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<9);
    show_menu(id, iKeys, szMenu, -1, "HnsIGiveSelectType");
}

public handleGiveSelectType(const id, const key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    
    if (key == 9) {  // 返回
        showGiveSelectPlayerMenu(id);
        return PLUGIN_HANDLED;
    }
    
    if (key == 0) {  // 单个发放
        g_iGiveMode[id] = 0;  // 标记为单个发放模式
        g_iGivePage[id] = 0;
        showGiveSkinTypeMenu(id);
    } else if (key == 1) {  // 全部发放
        g_iGiveMode[id] = 1;  // 标记为全部发放模式
        showGiveAllTypeMenu(id);
    }
    
    return PLUGIN_HANDLED;
}

// 单个发放 - 选择皮肤类型
showGiveSkinTypeMenu(const id) {
    new iTarget = g_iGiveTarget[id];
    if (!is_user_connected(iTarget)) {
        client_print(id, print_chat, "[HNS] 目标玩家已离线");
        return;
    }
    new szTargetName[32];
    get_user_name(iTarget, szTargetName, charsmax(szTargetName));
    
    new szMenu[256];
    formatex(szMenu, charsmax(szMenu), "\y向 \r%s \y发放单个皮肤^n选择皮肤类型:^n^n\r1. \wT(土匪)皮肤^n\r2. \wCT(警察)皮肤^n\r3. \w刀皮肤^n^n\r0. \w返回", szTargetName);
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<9);
    show_menu(id, iKeys, szMenu, -1, "HnsIGiveSelectSkin");
}

// 全部发放 - 选择类型
showGiveAllTypeMenu(const id) {
    new iTarget = g_iGiveTarget[id];
    if (!is_user_connected(iTarget)) {
        client_print(id, print_chat, "[HNS] 目标玩家已离线");
        return;
    }
    new szTargetName[32];
    get_user_name(iTarget, szTargetName, charsmax(szTargetName));
    
    new szMenu[256];
    formatex(szMenu, charsmax(szMenu), "\y向 \r%s \y发放全部皮肤^n选择类型:^n^n\r1. \wT(土匪)全部^n\r2. \wCT(警察)全部^n\r3. \w刀全部^n\r4. \w全部类型^n^n\r0. \w返回", szTargetName);
    new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<9);
    show_menu(id, iKeys, szMenu, -1, "HnsIGiveSelectSkin");
}

// 处理皮肤选择（单个发放选择类型 / 全部发放选择类型）
public handleGiveSelectSkin(const id, const key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    
    new iTarget = g_iGiveTarget[id];
    if (!is_user_connected(iTarget)) {
        client_print(id, print_chat, "[HNS] 目标玩家已离线");
        return PLUGIN_HANDLED;
    }
    
    if (key == 9) {  // 返回
        showGiveSelectTypeMenu(id);
        return PLUGIN_HANDLED;
    }
    
    if (g_iGiveMode[id] == 0) {
        // 单个发放模式 - 选择皮肤类型后显示皮肤列表
        switch (key) {
            case 0: { g_iGiveType[id] = 1; g_iGivePage[id] = 0; showGiveSkinListMenu(id); return PLUGIN_HANDLED; }
            case 1: { g_iGiveType[id] = 2; g_iGivePage[id] = 0; showGiveSkinListMenu(id); return PLUGIN_HANDLED; }
            case 2: { g_iGiveType[id] = 3; g_iGivePage[id] = 0; showGiveSkinListMenu(id); return PLUGIN_HANDLED; }
        }
        return PLUGIN_HANDLED;
    } else {
        // 全部发放模式 - 直接发放
        new iTarget = g_iGiveTarget[id];
        new szAdminName[32], szTargetRealName[32];
        get_user_name(id, szAdminName, charsmax(szAdminName));
        get_user_name(iTarget, szTargetRealName, charsmax(szTargetRealName));
        new iCount = 0;
        new szTypeStr[32];
        
        switch (key) {
            case 0: {
                new iSize = ArraySize(g_aTModels);
                for (new i = 0; i < iSize; i++) {
                    if (!has_skin(iTarget, 0, i)) {
                        give_skin(iTarget, 0, i);
                        iCount++;
                    }
                }
                save_player_skins(iTarget);
                client_print(id, print_chat, "[HNS] 已向 %s 发放 T类型全部皮肤 (%d个)", szTargetRealName, iCount);
                client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了 T类型全部皮肤 (%d个)", szAdminName, iCount);
                log_amx("[SkinSystem] 管理员 %s 向 %s 发放 T类型全部皮肤 (%d个)", szAdminName, szTargetRealName, iCount);
                return PLUGIN_HANDLED;
            }
            case 1: {
                new iSize = ArraySize(g_aCTModels);
                for (new i = 0; i < iSize; i++) {
                    if (!has_skin(iTarget, 1, i)) {
                        give_skin(iTarget, 1, i);
                        iCount++;
                    }
                }
                save_player_skins(iTarget);
                client_print(id, print_chat, "[HNS] 已向 %s 发放 CT类型全部皮肤 (%d个)", szTargetRealName, iCount);
                client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了 CT类型全部皮肤 (%d个)", szAdminName, iCount);
                log_amx("[SkinSystem] 管理员 %s 向 %s 发放 CT类型全部皮肤 (%d个)", szAdminName, szTargetRealName, iCount);
                return PLUGIN_HANDLED;
            }
            case 2: {
                new iSize = ArraySize(g_aKnifeModels);
                for (new i = 0; i < iSize; i++) {
                    if (!has_skin(iTarget, 2, i)) {
                        give_skin(iTarget, 2, i);
                        iCount++;
                    }
                }
                save_player_skins(iTarget);
                client_print(id, print_chat, "[HNS] 已向 %s 发放 Knife类型全部皮肤 (%d个)", szTargetRealName, iCount);
                client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了 Knife类型全部皮肤 (%d个)", szAdminName, iCount);
                log_amx("[SkinSystem] 管理员 %s 向 %s 发放 Knife类型全部皮肤 (%d个)", szAdminName, szTargetRealName, iCount);
                return PLUGIN_HANDLED;
            }
            case 3: {
                new iSize = ArraySize(g_aTModels);
                for (new i = 0; i < iSize; i++) {
                    if (!has_skin(iTarget, 0, i)) { give_skin(iTarget, 0, i); iCount++; }
                }
                iSize = ArraySize(g_aCTModels);
                for (new i = 0; i < iSize; i++) {
                    if (!has_skin(iTarget, 1, i)) { give_skin(iTarget, 1, i); iCount++; }
                }
                iSize = ArraySize(g_aKnifeModels);
                for (new i = 0; i < iSize; i++) {
                    if (!has_skin(iTarget, 2, i)) { give_skin(iTarget, 2, i); iCount++; }
                }
                save_player_skins(iTarget);
                client_print(id, print_chat, "[HNS] 已向 %s 发放 全部类型皮肤 (%d个)", szTargetRealName, iCount);
                client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了 全部类型皮肤 (%d个)", szAdminName, iCount);
                log_amx("[SkinSystem] 管理员 %s 向 %s 发放 全部类型皮肤 (%d个)", szAdminName, szTargetRealName, iCount);
                return PLUGIN_HANDLED;
            }
        }
    }
    
    return PLUGIN_HANDLED;
}
 
 // 单个发放 - 显示具体皮肤列表
 showGiveSkinListMenu(const id) {
     new iTarget = g_iGiveTarget[id];
     if (!is_user_connected(iTarget)) {
         client_print(id, print_chat, "[HNS] 目标玩家已离线");
         return;
     }
     
     new iType = g_iGiveType[id] - 1;  // 1=T, 2=CT, 3=Knife → 0,1,2
     new Array:aModels, Array:aModelNames;
     new szTypeName[8];
     if (iType == 0) { aModels = g_aTModels; aModelNames = g_aTModelNames; copy(szTypeName, charsmax(szTypeName), "T"); }
     else if (iType == 1) { aModels = g_aCTModels; aModelNames = g_aCTModelNames; copy(szTypeName, charsmax(szTypeName), "CT"); }
     else { aModels = g_aKnifeModels; aModelNames = g_aKnifeModelNames; copy(szTypeName, charsmax(szTypeName), "Knife"); }
     
     new iTotal = ArraySize(aModels);
     new iPage = g_iGivePage[id];
     new iStart = iPage * 7;
     new iEnd = iStart + 7;
     if (iEnd > iTotal) iEnd = iTotal;
     
     new szTargetName[32];
     get_user_name(iTarget, szTargetName, charsmax(szTargetName));
     
     new szMenu[512], iLen, szName[64];
     iLen = formatex(szMenu, charsmax(szMenu), "\y向 \r%s \y发放 %s 皮肤^n\y─────── 第%d页 ───────^n^n", szTargetName, szTypeName, iPage + 1);
     new iKeys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9);
     
     for (new i = iStart; i < iEnd; i++) {
         ArrayGetString(aModelNames, i, szName, charsmax(szName));
         new iSlot = i - iStart + 1;
         new bool:bOwned = has_skin(iTarget, iType, i);
         if (bOwned) {
             iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \d%s \r(已拥有)^n", iSlot, szName);
         } else {
             iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iSlot, szName);
         }
     }
     
     for (new i = iEnd; i < iStart + 7; i++) {
         iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
     }
     
     iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y───────^n");
     if (iPage > 0) {
         iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w上一页^n");
     } else {
         iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w返回^n");
     }
     if (iTotal > iEnd) {
         iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w下一页^n");
     }
     
     show_menu(id, iKeys, szMenu, -1, "HnsIGiveSelectSkinList");
 }
 
 public handleGiveSelectSkinList(const id, const key) {
     if (!is_user_connected(id)) return PLUGIN_HANDLED;
     
     new iTarget = g_iGiveTarget[id];
     if (!is_user_connected(iTarget)) {
         client_print(id, print_chat, "[HNS] 目标玩家已离线");
         return PLUGIN_HANDLED;
     }
     
     new iType = g_iGiveType[id] - 1;
     new Array:aModels, Array:aModelNames;
     if (iType == 0) { aModels = g_aTModels; aModelNames = g_aTModelNames; }
     else if (iType == 1) { aModels = g_aCTModels; aModelNames = g_aCTModelNames; }
     else { aModels = g_aKnifeModels; aModelNames = g_aKnifeModelNames; }
     
     if (key == 8) {  // 下一页
         g_iGivePage[id]++;
         showGiveSkinListMenu(id);
         return PLUGIN_HANDLED;
     }
     if (key == 9) {  // 上一页/返回
         if (g_iGivePage[id] > 0) {
             g_iGivePage[id]--;
             showGiveSkinListMenu(id);
         } else {
             showGiveSkinTypeMenu(id);
         }
         return PLUGIN_HANDLED;
     }
     
     new iTotal = ArraySize(aModels);
     new iSkinIndex = g_iGivePage[id] * 7 + key;
     if (iSkinIndex >= 0 && iSkinIndex < iTotal) {
         // 确认发放皮肤
         if (has_skin(iTarget, iType, iSkinIndex)) {
             new szModelName[MAX_SKIN_NAME];
             ArrayGetString(aModelNames, iSkinIndex, szModelName, charsmax(szModelName));
             client_print(id, print_chat, "[HNS] 玩家已拥有该皮肤: %s", szModelName);
             set_task(0.1, "taskRefreshGiveSkinMenu", id);
             return PLUGIN_HANDLED;
         }
         
         give_skin(iTarget, iType, iSkinIndex);
         save_player_skins(iTarget); // [FIX] 单个发放后立即持久化，防止地图切换/服务器重启丢失
         
         new szAdminName[32], szTargetRealName[32], szModelName[MAX_SKIN_NAME];
         get_user_name(id, szAdminName, charsmax(szAdminName));
         get_user_name(iTarget, szTargetRealName, charsmax(szTargetRealName));
         ArrayGetString(aModelNames, iSkinIndex, szModelName, charsmax(szModelName));
         new szTypeStr[8];
         if (iType == 0) copy(szTypeStr, charsmax(szTypeStr), "T");
         else if (iType == 1) copy(szTypeStr, charsmax(szTypeStr), "CT");
         else copy(szTypeStr, charsmax(szTypeStr), "Knife");
         
         client_print(id, print_chat, "[HNS] 已向 %s 发放皮肤: %s (%s)", szTargetRealName, szModelName, szTypeStr);
         client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了皮肤: %s (%s)", szAdminName, szModelName, szTypeStr);
         log_amx("[SkinSystem] 管理员 %s 向 %s 发放单个皮肤: %s (%s)", szAdminName, szTargetRealName, szModelName, szTypeStr);
         
         set_task(0.1, "taskRefreshGiveSkinMenu", id);
     }
     
     return PLUGIN_HANDLED;
 }
 
 public taskRefreshGiveSkinMenu(const id) {
     if (is_user_connected(id)) {
         showGiveSkinListMenu(id);
     }
 }

// 命令行方式发放单个皮肤（保留兼容）
public cmdGiveSkinCmd(const id) {
    if (!is_user_connected(id)) return PLUGIN_CONTINUE;
    
    new iPermLevel = get_user_perm_level(id);
    if (iPermLevel < PERM_ADMIN && !(get_user_flags(id) & ADMIN_IMMUNITY)) {
        client_print(id, print_chat, "[HNS] 只有管理员及以上才能发放皮肤");
        return PLUGIN_HANDLED;
    }
    
    new szArgs[256];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);
    
    new szTemp[256];
    copy(szTemp, charsmax(szTemp), szArgs);
    new iPos = contain(szTemp, "giveskinid ");
    if (iPos >= 0) {
        copy(szArgs, charsmax(szArgs), szTemp[iPos + 11]);
        trim(szArgs);
    }
    
    new szTargetName[32], szTypeStr[16], szSkinName[MAX_SKIN_NAME];
    parse(szArgs, szTargetName, charsmax(szTargetName), szTypeStr, charsmax(szTypeStr));
    new iTypeLen = strlen(szTypeStr);
    new iRemaining = strlen(szArgs) - (strlen(szTargetName) + 1 + iTypeLen);
    if (iRemaining > 0) {
        copy(szSkinName, charsmax(szSkinName), szArgs[strlen(szTargetName) + 1 + iTypeLen + 1]);
        trim(szSkinName);
    }
    
    if (szTargetName[0] == EOS || szTypeStr[0] == EOS || szSkinName[0] == EOS) {
        client_print(id, print_chat, "[HNS] 用法: /giveskinid <玩家名|#id> <T|CT|Knife> <皮肤名>");
        client_print(id, print_chat, "[HNS] 示例: /giveskinid Player T 北极战士");
        client_print(id, print_chat, "[HNS] 提示: 使用 /giveskin 可以打开菜单选择界面");
        return PLUGIN_HANDLED;
    }
    
    new iTarget = cmd_target(id, szTargetName, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_ALLOW_SELF);
    if (!iTarget) return PLUGIN_HANDLED;
    
    new iType = -1;
    new Array:aModels, Array:aModelNames;
    if (equali(szTypeStr, "T") || equali(szTypeStr, "t")) { iType = 0; aModels = g_aTModels; aModelNames = g_aTModelNames; }
    else if (equali(szTypeStr, "CT") || equali(szTypeStr, "ct")) { iType = 1; aModels = g_aCTModels; aModelNames = g_aCTModelNames; }
    else if (equali(szTypeStr, "Knife") || equali(szTypeStr, "knife") || equali(szTypeStr, "刀")) { iType = 2; aModels = g_aKnifeModels; aModelNames = g_aKnifeModelNames; }
    
    if (iType == -1 || aModels == Invalid_Array) {
        client_print(id, print_chat, "[HNS] 无效类型: %s, 请用 T/CT/Knife", szTypeStr);
        return PLUGIN_HANDLED;
    }
    
    new iSkinIndex = -1;
    new iSize = ArraySize(aModels);
    new szModelName[MAX_SKIN_NAME];
    for (new i = 0; i < iSize; i++) {
        ArrayGetString(aModelNames, i, szModelName, charsmax(szModelName));
        if (containi(szModelName, szSkinName) != -1) { iSkinIndex = i; break; }
    }
    
    if (iSkinIndex == -1) {
        client_print(id, print_chat, "[HNS] 找不到皮肤: %s (类型: %s)", szSkinName, szTypeStr);
        client_print(id, print_chat, "[HNS] 可用皮肤列表:");
        for (new i = 0; i < iSize; i++) {
            ArrayGetString(aModelNames, i, szModelName, charsmax(szModelName));
            client_print(id, print_chat, "[HNS]   %d. %s", i + 1, szModelName);
        }
        return PLUGIN_HANDLED;
    }
    
    if (has_skin(iTarget, iType, iSkinIndex)) {
        ArrayGetString(aModelNames, iSkinIndex, szModelName, charsmax(szModelName));
        client_print(id, print_chat, "[HNS] 玩家已拥有该皮肤: %s", szModelName);
        return PLUGIN_HANDLED;
    }
    
    give_skin(iTarget, iType, iSkinIndex);
    
    new szAdminName[32], szTargetRealName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));
    get_user_name(iTarget, szTargetRealName, charsmax(szTargetRealName));
    ArrayGetString(aModelNames, iSkinIndex, szModelName, charsmax(szModelName));
    
    client_print(id, print_chat, "[HNS] 已向 %s 发放皮肤: %s (%s)", szTargetRealName, szModelName, szTypeStr);
    client_print(iTarget, print_chat, "[HNS] 管理员 %s 向你发放了皮肤: %s (%s)", szAdminName, szModelName, szTypeStr);
    log_amx("[SkinSystem] 管理员 %s 向 %s 发放单个皮肤: %s (%s)", szAdminName, szTargetRealName, szModelName, szTypeStr);
    
    return PLUGIN_HANDLED;
}

// ============================================================
//  === END ===
// ============================================================

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

    // 保存到nvault
    new szKey[128];
    format(szKey, charsmax(szKey), "hns_skin_%s", szIdentifier);
    nvault_set(g_iVault, szKey, szData);

    // 保存选择到nvault
    new szNumStr[32];
    format(szKey, charsmax(szKey), "hns_skin_sel_t_%s", szIdentifier);
    num_to_str(g_iSelectedT[id], szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);
    format(szKey, charsmax(szKey), "hns_skin_sel_ct_%s", szIdentifier);
    num_to_str(g_iSelectedCT[id], szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);
    format(szKey, charsmax(szKey), "hns_skin_sel_knife_%s", szIdentifier);
    num_to_str(g_iSelectedKnife[id], szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);

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

    // 先尝试用SteamID
    new szAuth[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuth, charsmax(szAuth));

    new bool:bLoaded = false;

    // 尝试SteamID
    if (!equal(szAuth, "STEAM_ID_LAN") && !equal(szAuth, "VALVE_ID_LAN")) {
        format(szKey, charsmax(szKey), "hns_skin_%s", szAuth);
        if (nvault_get(g_iVault, szKey, szData, charsmax(szData))) {
            bLoaded = true;
        }
    }

    // SteamID没找到，尝试IP
    if (!bLoaded) {
        new szIP[MAX_AUTHID_LENGTH];
        get_user_ip(id, szIP, charsmax(szIP), 1);
        format(szKey, charsmax(szKey), "hns_skin_%s", szIP);
        if (nvault_get(g_iVault, szKey, szData, charsmax(szData))) {
            bLoaded = true;
        }
    }

    // IP也没找到，尝试名字
    if (!bLoaded) {
        new szName[32];
        get_user_name(id, szName, charsmax(szName));
        format(szKey, charsmax(szKey), "hns_skin_%s", szName);
        if (nvault_get(g_iVault, szKey, szData, charsmax(szData))) {
            bLoaded = true;
        }
    }

    // 如果PDS中没找到，从文件加载
    if (!bLoaded) {
        load_skin_data_from_file_for_player(id);
    }

    if (bLoaded) {
        parse_skin_json(id, szData);
    }

    // 加载选择
    format(szKey, charsmax(szKey), "hns_skin_sel_t_%s", szIdentifier);
    new iVal;
    new szNumBuf[32];
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_iSelectedT[id] = str_to_num(szNumBuf);
    }
    format(szKey, charsmax(szKey), "hns_skin_sel_ct_%s", szIdentifier);
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_iSelectedCT[id] = str_to_num(szNumBuf);
    }
    format(szKey, charsmax(szKey), "hns_skin_sel_knife_%s", szIdentifier);
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_iSelectedKnife[id] = str_to_num(szNumBuf);
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
    get_user_authid(id, szAuth, charsmax(szAuth));

    // 盗版玩家用IP
    if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN")) {
        get_user_ip(id, szAuth, charsmax(szAuth), 1);
    }

    new szKey[128];
    new szNumStr[32];
    format(szKey, charsmax(szKey), "hns_admin_t_%s", szAuth);
    num_to_str(g_iAdminSelectedT[id], szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);

    format(szKey, charsmax(szKey), "hns_admin_ct_%s", szAuth);
    num_to_str(g_iAdminSelectedCT[id], szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);

    format(szKey, charsmax(szKey), "hns_admin_knife_%s", szAuth);
    num_to_str(g_iAdminSelectedKnife[id], szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);

    // 保存验证状态
    format(szKey, charsmax(szKey), "hns_admin_verified_%s", szAuth);
    num_to_str(g_bAdminVerified[id] ? 1 : 0, szNumStr, charsmax(szNumStr));
    nvault_set(g_iVault, szKey, szNumStr);
}

// 加载管理员皮肤选择从PDS
stock load_admin_skins(const id) {
    if (!is_user_connected(id)) {
        return;
    }

    new szAuth[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuth, charsmax(szAuth));

    // 盗版玩家用IP
    if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN")) {
        get_user_ip(id, szAuth, charsmax(szAuth), 1);
    }

    new szKey[128];
    new szNumBuf[32];

    format(szKey, charsmax(szKey), "hns_admin_t_%s", szAuth);
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_iAdminSelectedT[id] = str_to_num(szNumBuf);
    }

    format(szKey, charsmax(szKey), "hns_admin_ct_%s", szAuth);
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_iAdminSelectedCT[id] = str_to_num(szNumBuf);
    }

    format(szKey, charsmax(szKey), "hns_admin_knife_%s", szAuth);
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_iAdminSelectedKnife[id] = str_to_num(szNumBuf);
    }

    // 加载验证状态
    format(szKey, charsmax(szKey), "hns_admin_verified_%s", szAuth);
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        g_bAdminVerified[id] = (str_to_num(szNumBuf) == 1);
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

        // 同步到nvault
        new szIdentifier[MAX_AUTHID_LENGTH];
        get_player_identifier(id, szIdentifier, charsmax(szIdentifier));
        new szKey[128];
        format(szKey, charsmax(szKey), "hns_skin_%s", szIdentifier);
        nvault_set(g_iVault, szKey, szLine);
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
    // 如果玩家还没有选中任何T皮肤，自动选中默认皮肤
    if (g_iSelectedT[id] < 0) {
        g_iSelectedT[id] = 0;
    }

    // CT默认皮肤（索引0）
    if (!has_skin(id, 1, 0)) {
        give_skin(id, 1, 0);
    }
    // 如果玩家还没有选中任何CT皮肤，自动选中默认皮肤
    if (g_iSelectedCT[id] < 0) {
        g_iSelectedCT[id] = 0;
    }

    // 刀默认皮肤（索引0）
    if (!has_skin(id, 2, 0)) {
        give_skin(id, 2, 0);
    }
    // 如果玩家还没有选中任何刀皮肤，自动选中默认皮肤
    if (g_iSelectedKnife[id] < 0) {
        g_iSelectedKnife[id] = 0;
    }
}

// ============================================================
//  === 工具函数 ===
// ============================================================

// 检查玩家是否拥有某皮肤
stock bool:has_skin(const id, const iType, const iSkinIndex) {
    if (iType == 0) {
        {
                    for (new i = 0; i < g_iOwnedTCount[id]; i++) {
                        if (g_iOwnedT[id][i] == iSkinIndex) {
                            return true;
                        }
                    }
                }
    } else if (iType == 1) {
        {
                    for (new i = 0; i < g_iOwnedCTCount[id]; i++) {
                        if (g_iOwnedCT[id][i] == iSkinIndex) {
                            return true;
                        }
                    }
                }
    } else if (iType == 2) {
        {
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

    if (iType == 0) {
        {
                    if (g_iOwnedTCount[id] < MAX_OWNED_SKINS) {
                        g_iOwnedT[id][g_iOwnedTCount[id]] = iSkinIndex;
                        g_iOwnedTCount[id]++;
                    }
                }
    } else if (iType == 1) {
        {
                    if (g_iOwnedCTCount[id] < MAX_OWNED_SKINS) {
                        g_iOwnedCT[id][g_iOwnedCTCount[id]] = iSkinIndex;
                        g_iOwnedCTCount[id]++;
                    }
                }
    } else if (iType == 2) {
        {
                    if (g_iOwnedKnifeCount[id] < MAX_OWNED_SKINS) {
                        g_iOwnedKnife[id][g_iOwnedKnifeCount[id]] = iSkinIndex;
                        g_iOwnedKnifeCount[id]++;
                    }
                }
    }
}

// 收回皮肤
stock take_skin(const id, const iType, const iSkinIndex) {
    if (iType == 0) {
        {
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
                            break;
                        }
                    }
                }
    } else if (iType == 1) {
        {
                    for (new i = 0; i < g_iOwnedCTCount[id]; i++) {
                        if (g_iOwnedCT[id][i] == iSkinIndex) {
                            for (new j = i; j < g_iOwnedCTCount[id] - 1; j++) {
                                g_iOwnedCT[id][j] = g_iOwnedCT[id][j + 1];
                            }
                            g_iOwnedCTCount[id]--;
                            if (g_iSelectedCT[id] == iSkinIndex) {
                                g_iSelectedCT[id] = 0;
                            }
                            break;
                        }
                    }
                }
    } else if (iType == 2) {
        {
                    for (new i = 0; i < g_iOwnedKnifeCount[id]; i++) {
                        if (g_iOwnedKnife[id][i] == iSkinIndex) {
                            for (new j = i; j < g_iOwnedKnifeCount[id] - 1; j++) {
                                g_iOwnedKnife[id][j] = g_iOwnedKnife[id][j + 1];
                            }
                            g_iOwnedKnifeCount[id]--;
                            if (g_iSelectedKnife[id] == iSkinIndex) {
                                g_iSelectedKnife[id] = 0;
                            }
                            break;
                        }
                    }
                }
    }
}

// 获取玩家标识（SteamID/IP/Name）
stock get_player_identifier(const id, szOut[], iLen) {
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
    if (iType == 0) {
        aNames = g_aTModelNames;
    } else if (iType == 1) {
        aNames = g_aCTModelNames;
    } else if (iType == 2) {
        aNames = g_aKnifeModelNames;
    } else {
        return -1;
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

    new szNumBuf[32];
    if (nvault_get(g_iVault, szKey, szNumBuf, charsmax(szNumBuf))) {
        return str_to_num(szNumBuf);
    }

    // 尝试旧格式键名
    if (contain(szAuth, "STEAM_") != -1) {
        format(szKey, charsmax(szKey), "hns_perm_%s", szAuth);
    } else {
        format(szKey, charsmax(szKey), "hns_permip_%s", szAuth);
    }

    // 旧格式存的是字符串
    new szVal[8];
    if (nvault_get(g_iVault, szKey, szVal, charsmax(szVal))) {
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
