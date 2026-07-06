/* ============================================================
 *  HNS JumpStats - KZ跳跃统计插件 v4.0.4
 *  模仿 KZ-Rush LJ Stats 风格
 *  依赖: amxmodx, reapi
 * ============================================================*/

#include <amxmodx>
#include <reapi>

/* ======================== 常量 ======================== */

#define MAX_STRAFES    20
#define MAX_PLAYERS     32

/* ======================== 枚举 ======================== */

enum _:JUMP_TYPE {
    JUMP_NONE = 0,
    JUMP_LJ,
    JUMP_HJ,
    JUMP_CJ,
    JUMP_DCJ,
    JUMP_MCJ,
    JUMP_WJ,
    JUMP_BHOP,
    JUMP_SBJ,
    JUMP_DUCKBHOP,
    JUMP_MULTIBHOP,
    JUMP_DROPBHOP,
    JUMP_LADDER,
    JUMP_EDGEBUG,
    JUMP_JUMPBUG
};

enum _:JUMP_GRADE {
    GRADE_NONE = 0,
    GRADE_GOOD,
    GRADE_PRO,
    GRADE_HOLY,
    GRADE_LEET,
    GRADE_GOD
};

/* ======================== 全局变量 ======================== */

// HUD
new g_iSyncMain;
new g_iSyncStrafes;
new g_iSyncSpeed;

// 设置
new g_iMode = 1;        // 0=off, 1=simple, 2=advanced
new g_iShowSpeedDefault = 1;   // cvar default
new g_iShowSpeed[33];   // per-player: 0=off, 1=on
new g_iShowBeam = 0;
new g_iShowPre = 0;
new g_iShowJof = 0;
new g_iColorChat = 2;   // 0=off, 1=only me, 2=all
new g_iSound = 1;

// 玩家开关
new bool:g_bShowStats[MAX_PLAYERS + 1];
new bool:g_bSoundEnabled[MAX_PLAYERS + 1] = { true, ... };  // 默认开启声音

// 跳跃状态
new bool:g_bInAir[MAX_PLAYERS + 1];
new bool:g_bOnGround[MAX_PLAYERS + 1];
new Float:g_flJumpStart[MAX_PLAYERS + 1][3];
new Float:g_flLastOrigin[MAX_PLAYERS + 1][3];
new Float:g_flJumpDist[MAX_PLAYERS + 1];
new Float:g_flMaxSpeed[MAX_PLAYERS + 1];
new Float:g_flPreSpeed[MAX_PLAYERS + 1];
new Float:g_flPostSpeed[MAX_PLAYERS + 1];
new g_iJumpType[MAX_PLAYERS + 1];
new g_iJumpGrade[MAX_PLAYERS + 1];

// Strafe
new g_iStrafeCount[MAX_PLAYERS + 1];
new g_iCurStrafe[MAX_PLAYERS + 1];  // 0=none, 1=A, 2=D
new g_iStrafeKey[MAX_PLAYERS + 1][MAX_STRAFES];
new Float:g_flStrafeGain[MAX_PLAYERS + 1][MAX_STRAFES];
new Float:g_flStrafeLoss[MAX_PLAYERS + 1][MAX_STRAFES];
new g_iStrafeFrames[MAX_PLAYERS + 1][MAX_STRAFES];
new g_iStrafeGainFrames[MAX_PLAYERS + 1][MAX_STRAFES];

// Prestrafe
new g_iFOG[MAX_PLAYERS + 1];
new g_iDuckCount[MAX_PLAYERS + 1];
new bool:g_bLastDucked[MAX_PLAYERS + 1];
new bool:g_bLastJumped[MAX_PLAYERS + 1];

// Edgebug
new bool:g_bEBActive[MAX_PLAYERS + 1];
new Float:g_flEBStartZ[MAX_PLAYERS + 1];

// 声音
new g_szSndGood[64] = "misc/impressive.wav";
new g_szSndPro[64] = "misc/perfect.wav";
new g_szSndHoly[64] = "misc/holyshit.wav";
new g_szSndLeet[64] = "misc/mod_wickedsick.wav";
new g_szSndGod[64] = "misc/mod_godlike.wav";

// 跳跃名称
new const g_szJumpNames[15][] = {
    "None", "LongJump", "HighJump", "CountJump", "Double CJ",
    "Multi CJ", "WeirdJump", "Bhop", "Standup Bhop", "Duck Bhop",
    "Multi Bhop", "Drop Bhop", "LadderJump", "EdgeBug", "JumpBug"
};

// 评级名称
new const g_szGradeNames[6][] = {
    "", "Good", "Pro", "Holy", "Leet", "God"
};

/* ======================== 插件初始化 ======================== */

public plugin_init() {
    register_plugin("HNS JumpStats", "4.0.4", "HNS");

    RegisterHookChain(RG_CBasePlayer_PreThink, "fw_PreThink");
    
    // 声音开关命令
    register_clcmd("say /ljsound", "cmd_toggle_sound");
    register_clcmd("say_team /ljsound", "cmd_toggle_sound");

    g_iSyncMain = CreateHudSyncObj();
    g_iSyncStrafes = CreateHudSyncObj();
    g_iSyncSpeed = CreateHudSyncObj();

    // Cvars
    bind_pcvar_num(create_cvar("ljs_mode", "1"), g_iMode);
    bind_pcvar_num(create_cvar("ljs_speed", "1"), g_iShowSpeedDefault);
    bind_pcvar_num(create_cvar("ljs_beam", "0"), g_iShowBeam);
    bind_pcvar_num(create_cvar("ljs_showpre", "0"), g_iShowPre);
    bind_pcvar_num(create_cvar("ljs_jumpoff", "0"), g_iShowJof);
    bind_pcvar_num(create_cvar("ljs_colorchat", "2"), g_iColorChat);
    bind_pcvar_num(create_cvar("ljs_sound", "1"), g_iSound);

    // 命令
    register_clcmd("say /js", "cmdToggleStats");
    register_clcmd("say /ljstats", "cmdToggleStats");
    register_clcmd("say /speed", "cmdToggleSpeed");
    register_clcmd("say /beam", "cmdToggleBeam");
    register_clcmd("say /ljbeam", "cmdToggleBeam");
    register_clcmd("say /pre", "cmdTogglePre");
    register_clcmd("say /showpre", "cmdTogglePre");
    register_clcmd("say /jof", "cmdToggleJof");
    register_clcmd("say /jumpoff", "cmdToggleJof");
}

public plugin_precache() {
    precache_sound(g_szSndGood);
    precache_sound(g_szSndPro);
    precache_sound(g_szSndHoly);
    precache_sound(g_szSndLeet);
    precache_sound(g_szSndGod);
}

/* ======================== 客户端命令 ======================== */

public cmdToggleStats(id) {
    g_bShowStats[id] = !g_bShowStats[id];
    client_print(id, print_chat, "[JumpStats] %s", g_bShowStats[id] ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public cmdToggleSpeed(id) {
    g_iShowSpeed[id] = g_iShowSpeed[id] ? 0 : 1;
    client_print(id, print_chat, "[JumpStats] Speed: %s", g_iShowSpeed[id] ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public cmdToggleBeam(id) {
    g_iShowBeam = g_iShowBeam ? 0 : 1;
    client_print(id, print_chat, "[JumpStats] Beam: %s", g_iShowBeam ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public cmdTogglePre(id) {
    g_iShowPre = g_iShowPre ? 0 : 1;
    client_print(id, print_chat, "[JumpStats] ShowPre: %s", g_iShowPre ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public cmdToggleJof(id) {
    g_iShowJof = g_iShowJof ? 0 : 1;
    client_print(id, print_chat, "[JumpStats] JumpOff: %s", g_iShowJof ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

/* ======================== 客户端连接 ======================== */

public client_putinserver(id) {
    g_bShowStats[id] = true;
    g_bInAir[id] = false;
    g_bOnGround[id] = true;
    g_iJumpType[id] = JUMP_NONE;
    g_iStrafeCount[id] = 0;
    g_iCurStrafe[id] = 0;
    g_iFOG[id] = 0;
    g_iDuckCount[id] = 0;
    g_bLastDucked[id] = false;
    g_bLastJumped[id] = false;
    g_bEBActive[id] = false;
    g_iShowSpeed[id] = g_iShowSpeedDefault;
    g_flMaxSpeed[id] = 0.0;
}

/* ======================== 核心逻辑 ======================== */

public fw_PreThink(id) {
    if (g_iMode == 0 || !is_user_alive(id))
        return HC_CONTINUE;

    new flags = get_entvar(id, var_flags);
    new button = get_entvar(id, var_button);
    new Float:origin[3], Float:velocity[3];
    get_entvar(id, var_origin, origin);
    get_entvar(id, var_velocity, velocity);

    // 水平速度
    new Float:speed = floatsqroot(velocity[0] * velocity[0] + velocity[1] * velocity[1]);

    // 实时速度显示
    if (g_iShowSpeed[id]) {
        set_hudmessage(255, 255, 255, -1.0, 0.59, 0, 0.0, 0.1, 0.0, 0.0);
        ShowSyncHudMsg(id, g_iSyncSpeed, "Speed: %.1f", speed);
    }

    // 地面状态
    new bool:onGround = bool:(flags & FL_ONGROUND);

    // === 检测跳跃 (从地面到空中) ===
    if (g_bOnGround[id] && !onGround && (button & IN_JUMP)) {
        // 记录起跳信息
        g_flJumpStart[id][0] = origin[0];
        g_flJumpStart[id][1] = origin[1];
        g_flJumpStart[id][2] = origin[2];
        g_flPreSpeed[id] = speed;
        g_flMaxSpeed[id] = speed;
        g_flPostSpeed[id] = 0.0;
        g_flJumpDist[id] = 0.0;
        g_iStrafeCount[id] = 0;
        g_iCurStrafe[id] = 0;
        g_bInAir[id] = true;

        // 检测跳跃类型
        if (g_iDuckCount[id] >= 3) {
            g_iJumpType[id] = JUMP_MCJ;
        } else if (g_iDuckCount[id] == 2) {
            g_iJumpType[id] = JUMP_DCJ;
        } else if (g_iDuckCount[id] == 1 && g_bLastDucked[id]) {
            g_iJumpType[id] = JUMP_CJ;
        } else if (g_iFOG[id] <= 2 && g_bLastJumped[id]) {
            g_iJumpType[id] = JUMP_BHOP;
        } else {
            g_iJumpType[id] = JUMP_LJ;
        }

        // 重置
        g_iFOG[id] = 0;
        g_iDuckCount[id] = 0;
        g_bLastJumped[id] = true;
    }

    // === 在空中 ===
    if (!onGround && g_bInAir[id]) {
        // 更新最大速度
        if (speed > g_flMaxSpeed[id]) {
            g_flMaxSpeed[id] = speed;
        }
        g_flPostSpeed[id] = speed;

        // 计算实时距离
        new Float:dx = origin[0] - g_flJumpStart[id][0];
        new Float:dy = origin[1] - g_flJumpStart[id][1];
        g_flJumpDist[id] = floatsqroot(dx * dx + dy * dy);

        // 空中实时HUD：显示速度和距离（青色）
        set_hudmessage(0, 255, 255, -1.0, 0.65, 0, 0.0, 0.1, 0.0, 0.0);
        ShowSyncHudMsg(id, g_iSyncSpeed, "Speed: %.1f | Dist: %.1f", speed, g_flJumpDist[id]);

        // Strafe 检测
        new moveLeft = (button & IN_MOVELEFT) ? 1 : 0;
        new moveRight = (button & IN_MOVERIGHT) ? 1 : 0;
        new newStrafe = 0;

        if (moveLeft && !moveRight) {
            newStrafe = 1; // A
        } else if (moveRight && !moveLeft) {
            newStrafe = 2; // D
        }

        if (newStrafe != 0 && newStrafe != g_iCurStrafe[id]) {
            // Strafe 切换
            if (g_iStrafeCount[id] < MAX_STRAFES) {
                new idx = g_iStrafeCount[id];
                g_iStrafeKey[id][idx] = newStrafe;
                g_iStrafeFrames[id][idx] = 1;
                g_iStrafeGainFrames[id][idx] = 0;
                g_flStrafeGain[id][idx] = 0.0;
                g_flStrafeLoss[id][idx] = 0.0;
                g_iStrafeCount[id]++;
                g_iCurStrafe[id] = newStrafe;
            }
        } else if (newStrafe != 0 && g_iStrafeCount[id] > 0) {
            // 累加当前 strafe 数据
            new idx = g_iStrafeCount[id] - 1;
            g_iStrafeFrames[id][idx]++;

            // 计算 gain/loss
            new Float:lastSpeed = 0.0;
            if (g_flLastOrigin[id][0] != 0.0 || g_flLastOrigin[id][1] != 0.0) {
                lastSpeed = floatsqroot(
                    (origin[0] - g_flLastOrigin[id][0]) * (origin[0] - g_flLastOrigin[id][0]) +
                    (origin[1] - g_flLastOrigin[id][1]) * (origin[1] - g_flLastOrigin[id][1])
                ) * 10.0; // 近似帧速度
            }

            if (speed > lastSpeed) {
                g_flStrafeGain[id][idx] += (speed - lastSpeed);
                g_iStrafeGainFrames[id][idx]++;
            } else {
                g_flStrafeLoss[id][idx] += (lastSpeed - speed);
            }
        }

        // Edgebug 检测
        if (g_bEBActive[id]) {
            // 检测是否在坠落中速度不变（edgebug成功）
        }

        // Beam
        if (g_iShowBeam) {
            // 简单的起点标记
        }
    }

    // === 检测落地 (从空中到地面) ===
    if (!g_bOnGround[id] && onGround && g_bInAir[id]) {
        g_bInAir[id] = false;
        g_bLastJumped[id] = false;

        // 最终距离
        new Float:dx = origin[0] - g_flJumpStart[id][0];
        new Float:dy = origin[1] - g_flJumpStart[id][1];
        g_flJumpDist[id] = floatsqroot(dx * dx + dy * dy);

        // 确定评级
        g_iJumpGrade[id] = get_grade(g_iJumpType[id], g_flJumpDist[id]);

        // 最小距离检查
        new minDist = get_min_dist(g_iJumpType[id]);
        if (g_flJumpDist[id] < float(minDist)) {
            g_iJumpGrade[id] = GRADE_NONE;
        }

        // 显示统计
        if (g_bShowStats[id] && g_iJumpGrade[id] > GRADE_NONE) {
            show_main_stats(id);
            show_strafe_stats(id);
        }

        // 播放声音（仅Pro及以上才触发，避免太吵）
        if (g_iSound && g_bSoundEnabled[id] && g_iJumpGrade[id] >= GRADE_PRO) {
            play_grade_sound(id, g_iJumpGrade[id]);
        }

        // 聊天消息（仅Pro及以上才广播）
        if (g_iColorChat >= 2 && g_iJumpGrade[id] >= GRADE_PRO) {
            new szName[32];
            get_user_name(id, szName, charsmax(szName));
            new grade = g_iJumpGrade[id];
            if (grade == GRADE_GOOD) {
                client_print(0, print_chat, "[JumpStats] %s - %s %.2f units (%d strafes)", szName, g_szJumpNames[g_iJumpType[id]], g_flJumpDist[id], g_iStrafeCount[id]);
            } else if (grade == GRADE_PRO) {
                client_print(0, print_chat, "[JumpStats] %s - %s %.2f units [%s] (%d strafes)", szName, g_szJumpNames[g_iJumpType[id]], g_flJumpDist[id], g_szGradeNames[grade], g_iStrafeCount[id]);
            } else if (grade >= GRADE_HOLY) {
                client_print(0, print_chat, "[JumpStats] %s - %s %.2f units [%s] (maxspeed: %.1f) (%d strafes)", szName, g_szJumpNames[g_iJumpType[id]], g_flJumpDist[id], g_szGradeNames[grade], g_flMaxSpeed[id], g_iStrafeCount[id]);
            }
        }
    }

    // === 在地面 ===
    if (onGround) {
        g_iFOG[id]++;
        if (button & IN_DUCK) {
            if (!g_bLastDucked[id]) {
                g_iDuckCount[id]++;
                g_bLastDucked[id] = true;
            }
        } else {
            g_bLastDucked[id] = false;
        }
    }

    // 保存上一帧位置
    g_flLastOrigin[id][0] = origin[0];
    g_flLastOrigin[id][1] = origin[1];
    g_flLastOrigin[id][2] = origin[2];
    g_bOnGround[id] = onGround;

    return HC_CONTINUE;
}

/* ======================== 评级系统 ======================== */

get_grade(type, Float:dist) {
    // LJ 阈值（提高门槛，只有真正好的数据才触发）
    if (type == JUMP_LJ) {
        if (dist >= 255.0) return GRADE_GOD;
        if (dist >= 253.0) return GRADE_LEET;
        if (dist >= 250.0) return GRADE_HOLY;
        if (dist >= 245.0) return GRADE_PRO;
        if (dist >= 240.0) return GRADE_GOOD;
    }
    // CJ 阈值
    if (type == JUMP_CJ) {
        if (dist >= 265.0) return GRADE_GOD;
        if (dist >= 260.0) return GRADE_LEET;
        if (dist >= 255.0) return GRADE_HOLY;
        if (dist >= 250.0) return GRADE_PRO;
        if (dist >= 245.0) return GRADE_GOOD;
    }
    // Bhop 阈值
    if (type == JUMP_BHOP || type == JUMP_SBJ || type == JUMP_MULTIBHOP) {
        if (dist >= 250.0) return GRADE_GOD;
        if (dist >= 245.0) return GRADE_LEET;
        if (dist >= 240.0) return GRADE_HOLY;
        if (dist >= 235.0) return GRADE_PRO;
        if (dist >= 230.0) return GRADE_GOOD;
    }
    // DCJ/MCJ
    if (type == JUMP_DCJ || type == JUMP_MCJ) {
        if (dist >= 270.0) return GRADE_GOD;
        if (dist >= 265.0) return GRADE_LEET;
        if (dist >= 260.0) return GRADE_HOLY;
        if (dist >= 255.0) return GRADE_PRO;
        if (dist >= 250.0) return GRADE_GOOD;
    }
    // WJ
    if (type == JUMP_WJ) {
        if (dist >= 260.0) return GRADE_GOD;
        if (dist >= 255.0) return GRADE_LEET;
        if (dist >= 250.0) return GRADE_HOLY;
        if (dist >= 245.0) return GRADE_PRO;
        if (dist >= 240.0) return GRADE_GOOD;
    }
    // Ladder
    if (type == JUMP_LADDER) {
        if (dist >= 180.0) return GRADE_GOD;
        if (dist >= 170.0) return GRADE_LEET;
        if (dist >= 160.0) return GRADE_HOLY;
        if (dist >= 150.0) return GRADE_PRO;
        if (dist >= 140.0) return GRADE_GOOD;
    }
    // EdgeBug/JumpBug
    if (type == JUMP_EDGEBUG || type == JUMP_JUMPBUG) {
        if (dist >= 200.0) return GRADE_GOD;
        if (dist >= 180.0) return GRADE_LEET;
        if (dist >= 160.0) return GRADE_HOLY;
        if (dist >= 140.0) return GRADE_PRO;
        if (dist >= 120.0) return GRADE_GOOD;
    }
    // 默认
    if (dist >= 200.0) return GRADE_GOD;
    if (dist >= 180.0) return GRADE_LEET;
    if (dist >= 160.0) return GRADE_HOLY;
    if (dist >= 140.0) return GRADE_PRO;
    if (dist >= 120.0) return GRADE_GOOD;

    return GRADE_NONE;
}

get_min_dist(type) {
    switch (type) {
        case JUMP_LJ: {
            return 120;
        }
        case JUMP_CJ: {
            return 130;
        }
        case JUMP_DCJ: {
            return 140;
        }
        case JUMP_MCJ: {
            return 150;
        }
        case JUMP_WJ: {
            return 120;
        }
        case JUMP_BHOP: {
            return 100;
        }
        case JUMP_SBJ: {
            return 100;
        }
        case JUMP_MULTIBHOP: {
            return 100;
        }
        case JUMP_DUCKBHOP: {
            return 100;
        }
        case JUMP_DROPBHOP: {
            return 100;
        }
        case JUMP_LADDER: {
            return 80;
        }
        case JUMP_EDGEBUG: {
            return 60;
        }
        case JUMP_JUMPBUG: {
            return 60;
        }
    }
    return 100;
}

/* ======================== HUD 显示 ======================== */

show_main_stats(id) {
    new grade = g_iJumpGrade[id];
    new r, g, b;

    // 颜色: 成功=青绿, 失败=红粉
    if (grade >= GRADE_PRO) {
        r = 20; g = 255; b = 150; // 青绿
    } else {
        r = 255; g = 70; b = 120; // 红粉
    }

    set_hudmessage(r, g, b, -1.0, 0.72, 0, 0.0, 3.0, 0.0, 0.0);

    new szType[32];
    copy(szType, charsmax(szType), g_szJumpNames[g_iJumpType[id]]);

    new Float:dist = g_flJumpDist[id];

    if (grade >= GRADE_HOLY) {
        ShowSyncHudMsg(id, g_iSyncMain,
            "%s^n%.2f units [%s]^nPre: %.1f | Post: %.1f^nStrafes: %d | MaxSpeed: %.1f",
            szType, dist, g_szGradeNames[grade],
            g_flPreSpeed[id], g_flPostSpeed[id],
            g_iStrafeCount[id], g_flMaxSpeed[id]);
    } else {
        ShowSyncHudMsg(id, g_iSyncMain,
            "%s^n%.2f units [%s]^nPre: %.1f | Post: %.1f^nStrafes: %d",
            szType, dist, g_szGradeNames[grade],
            g_flPreSpeed[id], g_flPostSpeed[id],
            g_iStrafeCount[id]);
    }
}

show_strafe_stats(id) {
    if (g_iStrafeCount[id] == 0)
        return;

    set_hudmessage(200, 200, 200, 0.79, 0.40, 0, 0.0, 3.0, 0.0, 0.0);

    new szBuf[512];
    new len = 0;

    // 表头
    len += formatex(szBuf[len], charsmax(szBuf) - len, "Key GainLoss Loss Frms Eff%%^n");

    new i;
    for (i = 0; i < g_iStrafeCount[id]; i++) {
        new key = g_iStrafeKey[id][i];
        new szKey[2];
        szKey[0] = key == 1 ? 'A' : 'D';
        szKey[1] = 0;

        new Float:gain = g_flStrafeGain[id][i];
        new Float:loss = g_flStrafeLoss[id][i];
        new frames = g_iStrafeFrames[id][i];
        new gainFrames = g_iStrafeGainFrames[id][i];

        new eff = 0;
        if (frames > 0) {
            eff = (gainFrames * 100) / frames;
        }

        new Float:gl = gain - loss;

        len += formatex(szBuf[len], charsmax(szBuf) - len,
            " %s  %6.1f  %5.1f  %3d  %3d%%^n",
            szKey, gl, loss, frames, eff);
    }

    ShowSyncHudMsg(id, g_iSyncStrafes, szBuf);
}

/* ======================== 声音 ======================== */

play_grade_sound(id, grade) {
    new szSound[64];
    switch (grade) {
        case GRADE_GOOD: {
            copy(szSound, charsmax(szSound), g_szSndGood);
        }
        case GRADE_PRO: {
            copy(szSound, charsmax(szSound), g_szSndPro);
        }
        case GRADE_HOLY: {
            copy(szSound, charsmax(szSound), g_szSndHoly);
        }
        case GRADE_LEET: {
            copy(szSound, charsmax(szSound), g_szSndLeet);
        }
        case GRADE_GOD: {
            copy(szSound, charsmax(szSound), g_szSndGod);
        }
        default: {
            return;
        }
    }
    // 只让跳跃者自己听到声音
    client_cmd(id, "spk ^"%s^"", szSound);
}

// 声音开关命令
public cmd_toggle_sound(id) {
    g_bSoundEnabled[id] = !g_bSoundEnabled[id];
    client_print(id, print_chat, "[JumpStats] Sound %s.", g_bSoundEnabled[id] ? "enabled" : "disabled");
    return PLUGIN_HANDLED;
}
