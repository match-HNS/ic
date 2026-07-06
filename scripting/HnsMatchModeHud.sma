#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_matchsystem>

#define HNS_MODE_TRAINING      0
#define HNS_MODE_KNIFE         1
#define HNS_MODE_PUBLIC        2
#define HNS_MODE_DEATHMATCH    3
#define HNS_MODE_ZOMBIE        4
#define HNS_MODE_MIX           5
#define HNS_MODE_ASCENSION     6
#define HNS_MODE_VAMPIRE       7

#define PLUGIN_NAME "HNS Match Mode HUD"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR "LINNA"

new g_iHudTask;

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
}

public plugin_cfg() {
    g_iHudTask = set_task(1.0, "taskShowModeHud", _, _, _, "b");
}

public plugin_end() {
    if (task_exists(g_iHudTask)) {
        remove_task(g_iHudTask);
    }
}

public taskShowModeHud() {
    new iMode = hns_get_mode();
    new iState = hns_get_state();
    
    if (iState == STATE_DISABLED) {
        return;
    }
    
    new szModeName[32];
    new szPrefix[24];
    
    hns_get_prefix(szPrefix, charsmax(szPrefix));
    
    switch (iMode) {
        case HNS_MODE_TRAINING: {
            copy(szModeName, charsmax(szModeName), "Training");
        }
        case HNS_MODE_KNIFE: {
            copy(szModeName, charsmax(szModeName), "Knife");
        }
        case HNS_MODE_PUBLIC: {
            copy(szModeName, charsmax(szModeName), "Public");
        }
        case HNS_MODE_DEATHMATCH: {
            copy(szModeName, charsmax(szModeName), "DeathMatch");
        }
        case HNS_MODE_ZOMBIE: {
            copy(szModeName, charsmax(szModeName), "Zombie");
        }
        case HNS_MODE_MIX: {
            copy(szModeName, charsmax(szModeName), "Mix");
        }
        case HNS_MODE_ASCENSION: {
            copy(szModeName, charsmax(szModeName), "Ascension");
        }
        case HNS_MODE_VAMPIRE: {
            copy(szModeName, charsmax(szModeName), "Vampire");
        }
        default: {
            copy(szModeName, charsmax(szModeName), "Unknown");
        }
    }
    
    set_hudmessage(0, 160, 180, -1.0, 0.15, 0, 0.0, 1.2, 0.0, 0.0, -1);
    show_hudmessage(0, "[ %s ] %s", szPrefix, szModeName);
}
