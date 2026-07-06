// ============================================================================
// HnsMatchServerCfg.sma
// HNS Server Configuration - Wallbang Control & Test Tools
// Uses FM_TraceLine to simulate wallbang on/off (no reapi dependency)
// ============================================================================

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <engine>

#define PLUGIN_NAME    "HNS Server Cfg"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  ""

// Cvar pointer
new g_pCvarWallbangForced;
new g_iWallbangForced;  // 0=default, 1=on, -1=off

// For trace wallbang hack: track whether current frame is a bullet trace
new bool:g_bBulletTrace;

// Weapon classnames for ham hooks
new const g_szWeaponClasses[][] = {
	"weapon_p228", "weapon_scout", "weapon_xm1014", "weapon_mac10",
	"weapon_aug", "weapon_elite", "weapon_fiveseven", "weapon_ump45",
	"weapon_sg550", "weapon_galil", "weapon_famas", "weapon_usp",
	"weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1",
	"weapon_deagle", "weapon_sg552", "weapon_ak47", "weapon_p90",
	"weapon_shield", "weapon_knife"
};

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

	// Cvar: 0=default, 1=forced on, -1=forced off
	g_pCvarWallbangForced = create_cvar("hns_wallbang_forced", "0",
		FCVAR_SERVER | FCVAR_SPONLY,
		"Wallbang forced state: 0=default, 1=on, -1=off");

	g_iWallbangForced = get_pcvar_num(g_pCvarWallbangForced);

	// Admin commands
	register_concmd("hns_wallbang_on", "cmdWallbangOn", ADMIN_MENU, "强制开启穿透");
	register_concmd("hns_wallbang_off", "cmdWallbangOff", ADMIN_MENU, "强制关闭穿透");
	register_concmd("hns_wallbang_status", "cmdWallbangStatus", ADMIN_MENU, "穿透状态");

	// Hook all weapons' PrimaryAttack Post
	for (new i = 0; i < sizeof(g_szWeaponClasses); i++) {
		RegisterHam(Ham_Weapon_PrimaryAttack, g_szWeaponClasses[i],
			"Weapon_PrimaryAttack_Pre", 0);
	}

	// TraceLine hook for wallbang simulation
	register_forward(FM_TraceLine, "fw_TraceLine");
	register_forward(FM_TraceHull, "fw_TraceHull");
}

// ============================================================================
// 武器攻击前钩子 - 标记当前为子弹trace
// ============================================================================
public Weapon_PrimaryAttack_Pre(weapon) {
	if (g_iWallbangForced == 0)
		return HAM_IGNORED;

	// 标记当前trace为子弹
	g_bBulletTrace = true;

	// 设置下一帧重置
	set_task(0.05, "task_ResetBulletTrace");

	return HAM_IGNORED;
}

public task_ResetBulletTrace() {
	g_bBulletTrace = false;
}

// ============================================================================
// TraceLine - 在强制开启穿透时让子弹穿过墙体
// ============================================================================
public fw_TraceLine(Float:v1[3], Float:v2[3], fNoMonsters, idToSkip, iTrace) {
	if (g_iWallbangForced != 1)
		return FMRES_IGNORED;

	if (!g_bBulletTrace)
		return FMRES_IGNORED;

	// Get the entity that was hit
	static ent; ent = get_tr2(iTrace, TR_pHit)
	if (!pev_valid(ent))
		return FMRES_IGNORED;

	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))

	// If we hit world or a wall entity, let the bullet pass through
	// by setting the trace fraction to 1.0 (no hit)
	if (equal(classname, "worldspawn") ||
		containi(classname, "func_wall") != -1 ||
		containi(classname, "func_breakable") != -1) {

		set_tr2(iTrace, TR_flFraction, 1.0)
		set_tr2(iTrace, TR_pHit, 0)
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

// ============================================================================
// TraceHull - same logic for hull traces (grenades etc but we keep consistent)
// ============================================================================
public fw_TraceHull(Float:v1[3], Float:v2[3], fNoMonsters, iBody, idToSkip, iTrace) {
	if (g_iWallbangForced != 1)
		return FMRES_IGNORED;

	if (!g_bBulletTrace)
		return FMRES_IGNORED;

	static ent; ent = get_tr2(iTrace, TR_pHit)
	if (!pev_valid(ent))
		return FMRES_IGNORED;

	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))

	if (equal(classname, "worldspawn") ||
		containi(classname, "func_wall") != -1 ||
		containi(classname, "func_breakable") != -1) {

		set_tr2(iTrace, TR_flFraction, 1.0)
		set_tr2(iTrace, TR_pHit, 0)
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

// ============================================================================
// 管理命令
// ============================================================================
public cmdWallbangOn(id, level, cid) {
	// register_concmd already checks ADMIN_MENU flag
	g_iWallbangForced = 1;
	set_pcvar_num(g_pCvarWallbangForced, g_iWallbangForced);

	client_print(0, print_chat, "[HNS] 穿透已强制开启 (测试用)");
	log_amx("Wallbang: ON (forced by %n)", id);
	return PLUGIN_HANDLED;
}

public cmdWallbangOff(id, level, cid) {
	g_iWallbangForced = -1;
	set_pcvar_num(g_pCvarWallbangForced, g_iWallbangForced);

	client_print(0, print_chat, "[HNS] 穿透已强制关闭");
	log_amx("Wallbang: OFF (forced by %n)", id);
	return PLUGIN_HANDLED;
}

public cmdWallbangStatus(id, level, cid) {
	new szStatus[32];
	if (g_iWallbangForced == 1)
		copy(szStatus, charsmax(szStatus), "强制开启");
	else if (g_iWallbangForced == -1)
		copy(szStatus, charsmax(szStatus), "强制关闭");
	else
		copy(szStatus, charsmax(szStatus), "默认");

	client_print(id, print_console, "[HNS] 穿透状态: %s (hns_wallbang_forced = %d)",
		szStatus, g_iWallbangForced);
	client_print(id, print_chat, "[HNS] 穿透状态: %s", szStatus);
	return PLUGIN_HANDLED;
}

public plugin_end() {
	set_pcvar_num(g_pCvarWallbangForced, 0);
}