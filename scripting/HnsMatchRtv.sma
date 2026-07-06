#include <amxmodx>
#include <reapi>

#define RTV_MIN_PLAYERS 1
#define RTV_PERCENT    1.0
#define RTV_DELAY      0
#define RTV_VOTE_TIME  20
#define RTV_MAX_MAPS   7

new g_szAllMaps[128][32];
new g_iAllMapCount;

new g_szNominated[32][32];
new g_iNominatedCount;
new g_iNominateCount[32];

new g_iRtvCount;
new g_iVoted[MAX_PLAYERS + 1];
new g_iPlayerNomination[MAX_PLAYERS + 1][32];
new bool:g_bVoteActive;

new Float:g_flMapStart;
new g_iTimer;
new g_iHudSync;
new g_szPrefix[24] = "[RTV]";

public plugin_init() {
    register_plugin("Rock The Vote", "2.1", "AI");

    register_clcmd("say /rtv", "cmdRtv");
    register_clcmd("say .rtv", "cmdRtv");
    register_clcmd("say /rockthevote", "cmdRtv");
    register_clcmd("say_team /rtv", "cmdRtv");
    register_clcmd("say_team /rockthevote", "cmdRtv");

    register_clcmd("say /nominate", "cmdNominate");
    register_clcmd("say .nominate", "cmdNominate");
    register_clcmd("say_team /nominate", "cmdNominate");

    g_iHudSync = CreateHudSyncObj();
    g_flMapStart = get_gametime();

    buildAllMapList();
}

// ==================== 地图列表 ====================
buildAllMapList() {
    new szPath[256], szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    formatex(szPath, charsmax(szPath), "%s/mixsystem/hns-maps.ini", szDir);

    new f = fopen(szPath, "rt");
    if (f) {
        new szLine[128], szMap[32];
        while (!feof(f) && g_iAllMapCount < 128) {
            fgets(f, szLine, charsmax(szLine));
            trim(szLine);
            if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '[' || szLine[0] == EOS)
                continue;
            parse(szLine, szMap, charsmax(szMap));
            tryAddAllMap(szMap);
        }
        fclose(f);
    }

    if (g_iAllMapCount < 3) {
        get_cvar_string("mapcyclefile", szPath, charsmax(szPath));
        if (!file_exists(szPath)) {
            formatex(szPath, charsmax(szPath), "%s/%s", szDir, szPath);
        }
        f = fopen(szPath, "rt");
        if (f) {
            new szLine[64], szMap[32];
            while (!feof(f) && g_iAllMapCount < 128) {
                fgets(f, szLine, charsmax(szLine));
                trim(szLine);
                if (szLine[0] == ';' || szLine[0] == EOS) continue;
                parse(szLine, szMap, charsmax(szMap));
                tryAddAllMap(szMap);
            }
            fclose(f);
        }
    }
}

bool:tryAddAllMap(const szMap[]) {
    new szCurrent[32];
    get_mapname(szCurrent, charsmax(szCurrent));
    if (equali(szMap, szCurrent)) return false;

    new szCheck[128];
    formatex(szCheck, charsmax(szCheck), "maps/%s.bsp", szMap);
    if (!file_exists(szCheck)) return false;

    copy(g_szAllMaps[g_iAllMapCount], 31, szMap);
    g_iAllMapCount++;
    return true;
}

findAllMapIndex(const szMap[]) {
    for (new i = 0; i < g_iAllMapCount; i++) {
        if (equali(g_szAllMaps[i], szMap)) return i;
    }
    return -1;
}

findNominatedIndex(const szMap[]) {
    for (new i = 0; i < g_iNominatedCount; i++) {
        if (equali(g_szNominated[i], szMap)) return i;
    }
    return -1;
}

isMapInNominated(const szMap[]) {
    return findNominatedIndex(szMap) >= 0;
}

// ==================== 提名系统 ====================
addNomination(id, const szMap[]) {
    if (findAllMapIndex(szMap) < 0) {
        client_print_color(id, print_team_blue, "%s 该地图不在可用地图列表中", g_szPrefix);
        return;
    }

    if (g_iPlayerNomination[id][0]) {
        removeNomination(id);
    }

    new idx = findNominatedIndex(szMap);
    if (idx < 0) {
        if (g_iNominatedCount >= 32) {
            client_print_color(id, print_team_blue, "%s 提名地图已满", g_szPrefix);
            return;
        }
        copy(g_szNominated[g_iNominatedCount], 31, szMap);
        g_iNominateCount[g_iNominatedCount] = 1;
        g_iNominatedCount++;
    } else {
        g_iNominateCount[idx]++;
    }

    copy(g_iPlayerNomination[id], 31, szMap);
    client_print_color(0, print_team_blue, "%s ^3%n^1 提名了 ^4%s^1", g_szPrefix, id, szMap);
}

removeNomination(id) {
    if (!g_iPlayerNomination[id][0]) return;

    new szMap[32];
    copy(szMap, 31, g_iPlayerNomination[id]);
    g_iPlayerNomination[id][0] = EOS;

    new idx = findNominatedIndex(szMap);
    if (idx >= 0) {
        g_iNominateCount[idx]--;
        if (g_iNominateCount[idx] <= 0) {
            for (new i = idx; i < g_iNominatedCount - 1; i++) {
                copy(g_szNominated[i], 31, g_szNominated[i + 1]);
                g_iNominateCount[i] = g_iNominateCount[i + 1];
            }
            g_iNominatedCount--;
        }
    }
}

// ==================== /nominate ====================
public cmdNominate(id) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (g_bVoteActive) {
        client_print_color(id, print_team_blue, "%s 投票进行中", g_szPrefix);
        return PLUGIN_HANDLED;
    }

    new hMenu = menu_create("\yRTV - 提名地图", "nominateHandler");

    new szItem[64];
    for (new i = 0; i < g_iAllMapCount && i < 60; i++) {
        if (equali(g_iPlayerNomination[id], g_szAllMaps[i])) {
            formatex(szItem, charsmax(szItem), "\d%s [已提名]", g_szAllMaps[i]);
        } else {
            copy(szItem, charsmax(szItem), g_szAllMaps[i]);
        }
        menu_additem(hMenu, szItem);
    }

    menu_setprop(hMenu, MPROP_BACKNAME, "上一页");
    menu_setprop(hMenu, MPROP_NEXTNAME, "下一页");
    menu_setprop(hMenu, MPROP_EXITNAME, "退出");
    menu_display(id, hMenu, 0);

    return PLUGIN_HANDLED;
}

public nominateHandler(id, hMenu, item) {
    menu_destroy(hMenu);
    if (item == MENU_EXIT || g_bVoteActive) return;
    if (item < 0 || item >= g_iAllMapCount) return;

    if (equali(g_iPlayerNomination[id], g_szAllMaps[item])) {
        removeNomination(id);
        client_print_color(0, print_team_blue, "%s ^3%n^1 取消了 ^4%s^1 的提名", g_szPrefix, id, g_szAllMaps[item]);
        return;
    }

    addNomination(id, g_szAllMaps[item]);
}

// ==================== /rtv ====================
playerCount() {
    new p[MAX_PLAYERS], n;
    get_players(p, n, "ch");
    return n;
}

neededVotes() {
    return floatround(playerCount() * RTV_PERCENT);
}

public cmdRtv(id) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (is_user_bot(id) || is_user_hltv(id)) return PLUGIN_HANDLED;

    if (g_bVoteActive) {
        client_print_color(id, print_team_blue, "%s 投票进行中，请等待结果", g_szPrefix);
        return PLUGIN_HANDLED;
    }

    if (get_gametime() - g_flMapStart < RTV_DELAY) {
        new iLeft = RTV_DELAY - floatround(get_gametime() - g_flMapStart);
        client_print_color(id, print_team_blue, "%s RTV 还需 %d 秒后才能使用", g_szPrefix, iLeft);
        return PLUGIN_HANDLED;
    }

    if (playerCount() < RTV_MIN_PLAYERS) {
        client_print_color(id, print_team_blue, "%s 需要 %d 人以上才能 RTV (当前 %d 人)", g_szPrefix, RTV_MIN_PLAYERS, playerCount());
        return PLUGIN_HANDLED;
    }

    if (g_iVoted[id]) {
        client_print_color(id, print_team_blue, "%s 你已经投过票了 (RTV: %d/%d)", g_szPrefix, g_iRtvCount, neededVotes());
        return PLUGIN_HANDLED;
    }

    g_iVoted[id] = 1;
    g_iRtvCount++;

    new iNeed = neededVotes();
    client_print_color(0, print_team_blue, "%s ^3%n^1 想换图 RTV: ^4%d/%d^1", g_szPrefix, id, g_iRtvCount, iNeed);

    if (g_iRtvCount >= iNeed) {
        startVote();
    }

    return PLUGIN_HANDLED;
}

// ==================== 投票（提名优先） ====================
new g_iVoteCount[32];
new g_szVoteMaps[32][32];
new g_iVoteMapCount;

startVote() {
    if (g_bVoteActive) return;
    g_bVoteActive = true;

    g_iVoteMapCount = 0;

    // 第一步：先把所有提名地图加入投票列表（优先）
    for (new i = 0; i < g_iNominatedCount && g_iVoteMapCount < RTV_MAX_MAPS; i++) {
        copy(g_szVoteMaps[g_iVoteMapCount], 31, g_szNominated[i]);
        g_iVoteCount[g_iVoteMapCount] = 0;
        g_iVoteMapCount++;
    }

    // 第二步：随机补充未提名地图，凑满 RTV_MAX_MAPS
    if (g_iVoteMapCount < RTV_MAX_MAPS && g_iAllMapCount > 0) {
        // 收集未提名地图
        new szRandom[128][32];
        new iRandomCount;

        for (new i = 0; i < g_iAllMapCount; i++) {
            if (!isMapInNominated(g_szAllMaps[i])) {
                copy(szRandom[iRandomCount], 31, g_szAllMaps[i]);
                iRandomCount++;
            }
        }

        // 随机打乱
        for (new i = iRandomCount - 1; i > 0; i--) {
            new j = random(i + 1);
            new szTmp[32];
            copy(szTmp, 31, szRandom[i]);
            copy(szRandom[i], 31, szRandom[j]);
            copy(szRandom[j], 31, szTmp);
        }

        // 取需要的数量
        new iNeed = RTV_MAX_MAPS - g_iVoteMapCount;
        if (iNeed > iRandomCount) iNeed = iRandomCount;
        for (new i = 0; i < iNeed; i++) {
            copy(g_szVoteMaps[g_iVoteMapCount], 31, szRandom[i]);
            g_iVoteCount[g_iVoteMapCount] = 0;
            g_iVoteMapCount++;
        }
    }

    if (g_iVoteMapCount < 2) {
        client_print_color(0, print_team_red, "%s 可用地图不足，无法发起投票", g_szPrefix);
        g_bVoteActive = false;
        g_iRtvCount = 0;
        for (new i = 1; i <= MaxClients; i++) g_iVoted[i] = 0;
        return;
    }

    new p[MAX_PLAYERS], n;
    get_players(p, n, "ch");
    for (new k = 0; k < n; k++) {
        showVoteMenu(p[k]);
    }

    client_print_color(0, print_team_blue, "%s ^4RTV 投票开始！^1 有 %d 秒投票", g_szPrefix, RTV_VOTE_TIME);

    g_iTimer = RTV_VOTE_TIME;
    set_task(1.0, "voteTick", .flags = "b");
}

showVoteMenu(id) {
    new szTitle[64];
    formatex(szTitle, charsmax(szTitle), "\rRTV \w换图投票 \y(%d秒)", RTV_VOTE_TIME);

    new hMenu = menu_create(szTitle, "voteHandler");

    for (new i = 0; i < g_iVoteMapCount; i++) {
        new szItem[64];
        if (isMapInNominated(g_szVoteMaps[i])) {
            new idx = findNominatedIndex(g_szVoteMaps[i]);
            new count = idx >= 0 ? g_iNominateCount[idx] : 0;
            formatex(szItem, charsmax(szItem), "\y%s \w[提名%d次]", g_szVoteMaps[i], count);
        } else {
            formatex(szItem, charsmax(szItem), "\w%s", g_szVoteMaps[i]);
        }
        menu_additem(hMenu, szItem);
    }

    menu_setprop(hMenu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, hMenu);
}

public voteHandler(id, hMenu, item) {
    menu_destroy(hMenu);
    if (!g_bVoteActive) return;
    if (item < 0 || item >= g_iVoteMapCount) return;

    g_iVoteCount[item]++;
}

public voteTick() {
    g_iTimer--;

    set_hudmessage(255, 255, 255, -1.0, 0.3, 0, 0.0, 1.1, 0.0, 0.0, -1);
    ShowSyncHudMsg(0, g_iHudSync, "RTV 投票剩余: %d 秒^n/nominate 提名 | /rtv 换图", g_iTimer);

    if (g_iTimer <= 0) {
        remove_task();
        finishVote();
    }
}

finishVote() {
    g_bVoteActive = false;

    new iWinner = 0, iMax = 0;
    for (new i = 0; i < g_iVoteMapCount; i++) {
        if (g_iVoteCount[i] > iMax) {
            iMax = g_iVoteCount[i];
            iWinner = i;
        }
    }

    if (iMax == 0) {
        client_print_color(0, print_team_red, "%s 没有人投票，RTV取消", g_szPrefix);
        return;
    }

    client_print_color(0, print_team_blue, "%s ^4RTV 结果^1: ^4%s^1 获胜！3秒后换图", g_szPrefix, g_szVoteMaps[iWinner]);

    set_task(3.0, "doChange", iWinner);
}

public doChange(iMapIdx) {
    // 换图前清除所有投票和提名数据
    for (new i = 1; i <= MaxClients; i++) {
        g_iPlayerNomination[i][0] = EOS;
        g_iVoted[i] = 0;
    }
    g_iNominatedCount = 0;
    g_iRtvCount = 0;
    g_bVoteActive = false;

    server_cmd("changelevel %s", g_szVoteMaps[iMapIdx]);
}

public client_disconnected(id) {
    removeNomination(id);
    g_iVoted[id] = 0;
}
