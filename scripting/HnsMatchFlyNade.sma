// ============================================
// HnsMatchSystem - Fly Grenade (Teleport Nade)
// Version: 3.5.0
// Author: LINNA (Original) / OpenHNS (Integrated)
// Description: Last CT gets a fly grenade for teleportation
// ============================================

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <fakemeta>

#pragma semicolon 1

#define PLUGIN_PREFIX "HNSIC"

// ============================================
// CVARs & Settings
// ============================================
new bool:g_bFlyNadeEnabled = true;
new g_iFlySpeedMin = 900;
new g_iFlySpeedMax = 1100;
new g_iFlyDuration = 5;
new g_iFlyCD = 30;

// ============================================
// Player Data
// ============================================
new g_iFlyEnt[MAX_PLAYERS + 1];
new bool:g_bHasFlyNade[MAX_PLAYERS + 1];
new bool:g_bGrenadeThrown[MAX_PLAYERS + 1];
new Float:g_fFlyEndTime[MAX_PLAYERS + 1];
new Float:g_fLastFlyUseTime[MAX_PLAYERS + 1];
new g_iFlySpeed[MAX_PLAYERS + 1];

// ============================================
// Boost Map Detection
// ============================================
new bool:g_bIsBoostMap = false;

// ============================================
// Plugin Init
// ============================================
public plugin_init() {
    register_plugin("HNS Match Fly Nade", "4.0.4", "LINNA / OpenHNS");
    
    // ReAPI hooks
    RegisterHookChain(RG_CBasePlayer_Spawn, "fw_PlayerSpawn", true);
    RegisterHookChain(RG_CBasePlayer_Killed, "fw_PlayerKilled", true);
    
    // Grenade Think via FM
    register_forward(FM_Think, "fw_NadeThink");
    
    // FM forward
    register_forward(FM_CmdStart, "fw_CmdStart");
    
    // Events
    register_event("DeathMsg", "Event_DeathMsg", "a");
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    
    // Commands
    register_clcmd("say /fly", "CmdFlyMenu");
    register_clcmd("say_team /fly", "CmdFlyMenu");
    register_clcmd("say /testfly", "CmdTestFly");
    register_concmd("hns_flynade", "CmdFlyMenu", ADMIN_CFG, "Fly Nade Settings");
    
    // Menus
    register_menucmd(register_menuid("FlyNade Menu"), 1023, "HandleFlyMenu");
    
    // CVARs
    register_cvar("hns_flynade_version", "4.0.4", FCVAR_SERVER | FCVAR_SPONLY);
    register_cvar("hns_flynade_enabled", "1");
    register_cvar("hns_flynade_speed_min", "900");
    register_cvar("hns_flynade_speed_max", "1100");
    register_cvar("hns_flynade_duration", "5");
    register_cvar("hns_flynade_cooldown", "30");
    
    // Detect boost map
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));
    g_bIsBoostMap = (containi(szMapName, "boost") != -1 || containi(szMapName, "bhop") != -1 || containi(szMapName, "kz_") != -1);
    
    // Boost map: disable by default
    if (g_bIsBoostMap) {
        g_bFlyNadeEnabled = false;
        set_cvar_num("hns_flynade_enabled", 0);
        server_print("[FlyNade] Boost map detected - Fly Nade disabled by default");
    }
    
    log_amx("[FlyNade] Plugin loaded. Map: %s | Boost: %s | Enabled: %s",
        szMapName, g_bIsBoostMap ? "Yes" : "No", g_bFlyNadeEnabled ? "Yes" : "No");
}

// ============================================
// Player Events
// ============================================
public fw_PlayerSpawn(id) {
    if (!is_user_alive(id)) return HC_CONTINUE;
    
    g_bHasFlyNade[id] = false;
    g_iFlyEnt[id] = 0;
    g_bGrenadeThrown[id] = false;
    
    return HC_CONTINUE;
}

public fw_PlayerKilled(victim) {
    CleanupFlyNade(victim);
    return HC_CONTINUE;
}

public Event_DeathMsg() {
    new victim = read_data(2);
    CleanupFlyNade(victim);

    if (g_bFlyNadeEnabled) {
        set_task(0.2, "CheckLastCT");
    }
}

public Event_NewRound() {
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (is_user_connected(i)) {
            CleanupFlyNade(i);
            g_bHasFlyNade[i] = false;
            g_bGrenadeThrown[i] = false;
            g_fLastFlyUseTime[i] = 0.0;
        }
    }
    
    // Re-check boost map setting each round
    g_bFlyNadeEnabled = bool:get_cvar_num("hns_flynade_enabled");
    
    // Check last CT after round starts (delayed to let teams settle)
    if (g_bFlyNadeEnabled) {
        set_task(1.0, "CheckLastCT");
    }
}

// ============================================
// Last CT Check
// ============================================
public CheckLastCT() {
    if (!g_bFlyNadeEnabled) return;
    
    new iCTCount, iLastCT;
    
    for (new i = 1; i <= MAX_PLAYERS; i++) {
        if (is_user_alive(i) && get_member(i, m_iTeam) == TEAM_CT) {
            iCTCount++;
            iLastCT = i;
        }
    }
    
    if (iCTCount == 1 && iLastCT > 0) {
        GiveFlyNade(iLastCT);
    }
}

// ============================================
// Give Fly Nade
// ============================================
GiveFlyNade(id) {
    if (!is_user_alive(id)) return;
    if (get_gametime() - g_fLastFlyUseTime[id] < float(g_iFlyCD)) return;
    
    if (!g_bHasFlyNade[id]) {
        g_bHasFlyNade[id] = true;
        rg_give_item(id, "weapon_hegrenade");
        g_iFlySpeed[id] = random_num(g_iFlySpeedMin, g_iFlySpeedMax);
        
        // HUD notification
        set_dhudmessage(0, 255, 255, -1.0, 0.3, 0, 0.0, 4.0, 0.5, 0.5);
        show_dhudmessage(id, "Last CT! Fly Nade Speed: %d^nRight-click to teleport!", g_iFlySpeed[id]);
    }
}

// ============================================
// Cleanup
// ============================================
CleanupFlyNade(id) {
    g_bHasFlyNade[id] = false;
    
    if (g_iFlyEnt[id] && pev_valid(g_iFlyEnt[id]) == 2) {
        engfunc(EngFunc_RemoveEntity, g_iFlyEnt[id]);
        g_iFlyEnt[id] = 0;
    }
}

// ============================================
// Grenade Think - Detect throw
// ============================================
public fw_NadeThink(ent) {
    if (!pev_valid(ent) || !g_bFlyNadeEnabled) return FMRES_IGNORED;
    
    new szClass[32];
    get_entvar(ent, var_classname, szClass, charsmax(szClass));
    if (!equal(szClass, "grenade")) return FMRES_IGNORED;
    
    new owner = get_entvar(ent, var_owner);
    if (owner < 1 || owner > MAX_PLAYERS || !is_user_connected(owner))
        return FMRES_IGNORED;
    if (!g_bHasFlyNade[owner] || g_bGrenadeThrown[owner])
        return FMRES_IGNORED;
    
    // Check if HE grenade (not flash/smoke)
    new Float:vOwnerOrigin[3], Float:vNadeOrigin[3];
    get_entvar(owner, var_origin, vOwnerOrigin);
    get_entvar(ent, var_origin, vNadeOrigin);
    
    if (get_distance_f(vOwnerOrigin, vNadeOrigin) > 100.0) {
        g_iFlyEnt[owner] = ent;
        g_bGrenadeThrown[owner] = true;
        g_fFlyEndTime[owner] = get_gametime() + float(g_iFlyDuration);
    }
    
    return FMRES_IGNORED;
}

// ============================================
// CmdStart - Handle right-click teleport
// ============================================
public fw_CmdStart(id, uc_handle) {
    if (!g_bFlyNadeEnabled || !is_user_alive(id) || !g_bGrenadeThrown[id])
        return FMRES_IGNORED;
    
    new ent = g_iFlyEnt[id];
    if (!pev_valid(ent)) return FMRES_IGNORED;
    
    new Float:fGameTime = get_gametime();
    
    // Check if fly time expired
    if (fGameTime > g_fFlyEndTime[id]) {
        g_bGrenadeThrown[id] = false;
        g_fLastFlyUseTime[id] = fGameTime;
        
        engfunc(EngFunc_RemoveEntity, ent);
        g_iFlyEnt[id] = 0;
        
        set_dhudmessage(255, 50, 50, -1.0, 0.35, 0, 0.0, 3.0, 0.5, 0.5);
        show_dhudmessage(id, "Fly time expired!");
        return FMRES_IGNORED;
    }
    
    // Show HUD timer
    new iRemain = floatround(g_fFlyEndTime[id] - fGameTime);
    set_dhudmessage(0, 255, 255, -1.0, 0.85, 0, 0.2, 0.0, 0.0, 0.0);
    show_dhudmessage(id, "Fly Nade: %ds | Speed: %d | Right-click: Teleport", iRemain, g_iFlySpeed[id]);
    
    // Right-click teleport
    new buttons = get_uc(uc_handle, UC_Buttons);
    if (buttons & IN_ATTACK2) {
        new Float:vOrigin[3], Float:vVelocity[3];
        get_entvar(ent, var_origin, vOrigin);
        get_entvar(ent, var_velocity, vVelocity);
        
        if (vOrigin[2] > -2000.0) {
            // Teleport player to grenade
            vOrigin[2] += 36.0;
            set_entvar(id, var_origin, vOrigin);
            vVelocity[2] = 300.0;
            set_entvar(id, var_velocity, vVelocity);
            
            // Cleanup
            g_bGrenadeThrown[id] = false;
            g_fLastFlyUseTime[id] = fGameTime;
            engfunc(EngFunc_RemoveEntity, ent);
            g_iFlyEnt[id] = 0;
            
            set_dhudmessage(0, 255, 100, -1.0, 0.3, 0, 0.0, 3.0, 0.5, 0.5);
            show_dhudmessage(id, "Teleported! Inherited speed: %d", g_iFlySpeed[id]);
        }
        return FMRES_IGNORED;
    }
    
    return FMRES_IGNORED;
}

// ============================================
// Admin Commands
// ============================================
public CmdTestFly(id) {
    if (!(get_user_flags(id) & ADMIN_KICK)) {
        client_print(id, print_chat, "[%s] Admin only.", PLUGIN_PREFIX);
        return PLUGIN_HANDLED;
    }
    
    g_bHasFlyNade[id] = true;
    rg_give_item(id, "weapon_hegrenade");
    g_iFlySpeed[id] = random_num(g_iFlySpeedMin, g_iFlySpeedMax);
    client_print(id, print_chat, "[%s] Test fly nade! Speed: %d", PLUGIN_PREFIX, g_iFlySpeed[id]);
    return PLUGIN_HANDLED;
}

// ============================================
// Admin Menu
// ============================================
public CmdFlyMenu(id) {
    if (!(get_user_flags(id) & ADMIN_KICK)) {
        client_print(id, print_chat, "[%s] Admin only.", PLUGIN_PREFIX);
        return PLUGIN_HANDLED;
    }
    
    new szMenu[512], len;
    
    len = formatex(szMenu, charsmax(szMenu), "\rFly Nade Settings^n^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1.\w Status: %s^n", g_bFlyNadeEnabled ? "\y[ON]" : "\r[OFF]");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2.\w Test Fly Nade^n^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3.\w Min Speed: \y%d^n", g_iFlySpeedMin);
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4.\w Max Speed: \y%d^n", g_iFlySpeedMax);
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5.\w Duration: \y%d sec^n", g_iFlyDuration);
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6.\w Cooldown: \y%d sec^n^n", g_iFlyCD);
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0.\w Exit");
    
    show_menu(id, 1023, szMenu, -1, "FlyNade Menu");
    return PLUGIN_HANDLED;
}

public HandleFlyMenu(id, key) {
    switch (key) {
        case 0: {
            g_bFlyNadeEnabled = !g_bFlyNadeEnabled;
            set_cvar_num("hns_flynade_enabled", g_bFlyNadeEnabled ? 1 : 0);
            client_print(0, print_chat, "[%s] Fly Nade %s", PLUGIN_PREFIX, g_bFlyNadeEnabled ? "ENABLED" : "DISABLED");
            CmdFlyMenu(id);
        }
        case 1: {
            CmdTestFly(id);
            CmdFlyMenu(id);
        }
        case 2: {
            g_iFlySpeedMin += 100;
            if (g_iFlySpeedMin > g_iFlySpeedMax) g_iFlySpeedMin = g_iFlySpeedMax;
            set_cvar_num("hns_flynade_speed_min", g_iFlySpeedMin);
            CmdFlyMenu(id);
        }
        case 3: {
            g_iFlySpeedMax += 100;
            if (g_iFlySpeedMax > 2000) g_iFlySpeedMax = 2000;
            set_cvar_num("hns_flynade_speed_max", g_iFlySpeedMax);
            CmdFlyMenu(id);
        }
        case 4: {
            g_iFlyDuration += 1;
            if (g_iFlyDuration > 15) g_iFlyDuration = 5;
            set_cvar_num("hns_flynade_duration", g_iFlyDuration);
            CmdFlyMenu(id);
        }
        case 5: {
            g_iFlyCD += 5;
            if (g_iFlyCD > 120) g_iFlyCD = 15;
            set_cvar_num("hns_flynade_cooldown", g_iFlyCD);
            CmdFlyMenu(id);
        }
        case 9: {
            return PLUGIN_HANDLED;
        }
    }
    return PLUGIN_HANDLED;
}

public plugin_end() {
    log_amx("[FlyNade] Plugin shutting down");
}
