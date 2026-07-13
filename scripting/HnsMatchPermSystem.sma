#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <PersistentDataStorage>

// ============================================================
//  ИЁПЮµИј¶¶ЁТе
// ============================================================
#define PERM_NONE    0    // 普通玩家
#define PERM_TEMP    1    // 临时管理
#define PERM_VIP     2    // VIP
#define PERM_ADMIN   3    // 管理员
#define PERM_OWNER   4    // 最高服主

// ============================================================
//  іЈБї
// ============================================================
#define MAX_BANS         512
#define MAX_PAGE_SIZE    7
#define MAX_AUTH_LEN     64
#define MAX_NAME_LEN     32
#define MAX_REASON_LEN   128
#define ADMIN_PASSWORD   "890514"

// ============================================================
//  И«ѕЦ±дБї
// ============================================================

// НжјТИЁПЮµИј¶
new g_iPermLevel[33];

// СйЦ¤ЧґМ¬
new bool:g_bVerified[33];

// µИґэГЬВлКдИлЧґМ¬
new bool:g_bWaitingPassword[33];

// ТюІШЙн·Э(Ѕц·юЦч)
new bool:g_bHidden[33];

// НжјТИПЦ¤ID (SteamID »т IP)
new g_szAuth[33][MAX_AUTH_LEN];

// НжјТГыЧЦ
new g_szName[33][MAX_NAME_LEN];

// ІЛµҐ·­Ті
new g_iPage[33];

// µ±З°ІЩЧчАаРН
// 0=ОЮ, 1=МЯИЛ, 2=·вЅы, 3=·ў№ЬАн, 4=·ўVIP, 5=ЗеИЁПЮ, 6=ЧЄ¶У
new g_iMenuAction[33];

// ·вЅыБР±н
new g_szBannedAuth[MAX_BANS][MAX_AUTH_LEN];
new g_iBanExpire[MAX_BANS];
new g_szBanReason[MAX_BANS][MAX_REASON_LEN];
new g_iBanCount = 0;

// »»НјІЛµҐ·­Ті
new g_iMapPage[33];

// µШНјБР±н
new g_szMapList[256][64];
new g_iMapCount = 0;

stock perm_apply_user_flags(id)
{
    if (!is_user_connected(id)) {
        return;
    }

    switch (g_iPermLevel[id]) {
        case PERM_OWNER: { set_user_flags(id, read_flags("abcdefghijklmn")); break; }
        case PERM_ADMIN: { set_user_flags(id, read_flags("defi")); break; }
        case PERM_VIP:   { set_user_flags(id, read_flags("b")); break; }
        case PERM_TEMP:  { set_user_flags(id, read_flags("fi")); break; }
        default:         set_user_flags(id, 0);
    }
}

// ============================================================
//  ІејюРЕПў
// ============================================================
public plugin_init()
{
    register_plugin("HNS PermSystem", "4.1.6", "HNS Match System");

    // ГьБоЧўІб
    register_clcmd("say /vipadmin", "cmdVipAdmin");
    register_clcmd("say /permcheck", "cmdPermCheck");
    register_clcmd("say /hide", "cmdToggleHide");
    register_clcmd("say", "cmdSayHandler");

    // БДМмСХЙ«А№ЅШ
    register_message(get_user_msgid("SayText"), "msgSayText");

    // ІЛµҐЧўІб
    register_menucmd(register_menuid("Perm Main"), 1023, "handlePermMain");
    register_menucmd(register_menuid("Perm Select Player"), 1023, "handlePermSelectPlayer");
    register_menucmd(register_menuid("Perm Kick Reason"), 1023, "handlePermKickReason");
    register_menucmd(register_menuid("Perm Ban Time"), 1023, "handlePermBanTime");
    register_menucmd(register_menuid("Admin Menu"), 1023, "handleAdminMenu");
    register_menucmd(register_menuid("Perm Map List"), 1023, "handlePermMapList");

    // Жф¶ЇК±јУФШОДјю±ё·ЭµЅPDS
    perm_load_file();

    // јУФШµШНјБР±н
    load_map_list();

    // ґґЅЁИЁПЮДїВј
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    format(szDir, charsmax(szDir), "%s/permsystem", szDir);
    if (!dir_exists(szDir)) {
        mkdir(szDir);
    }
}

// ============================================================
//  НжјТБ¬ЅУ/¶ПїЄ
// ============================================================
public client_putinserver(id)
{
    // іхКј»Ї±дБї
    g_iPermLevel[id] = PERM_NONE;
    g_bVerified[id] = false;
    g_bWaitingPassword[id] = false;
    g_bHidden[id] = false;
    g_iPage[id] = 0;
    g_iMenuAction[id] = 0;
    g_iMapPage[id] = 0;
    g_szAuth[id][0] = '^0';
    g_szName[id][0] = '^0';

    // »сИЎИПЦ¤РЕПў
    if (is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    // іўКФ»сИЎSteamID
    new szAuth[64];
    get_user_authid(id, szAuth, charsmax(szAuth));

    if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:")) {
        // µБ°жНжјТУГIP
        get_user_ip(id, g_szAuth[id], charsmax(g_szAuth[]), 1);
    } else {
        copy(g_szAuth[id], charsmax(g_szAuth[]), szAuth);
    }

    get_user_name(id, g_szName[id], charsmax(g_szName[]));

    // јУФШИЁПЮ
    perm_load(id);
    perm_apply_user_flags(id);

    // јмІй·вЅы
    check_ban(id);
}

public client_authorized(id)
{
    if (is_user_bot(id) || is_user_hltv(id)) {
        return;
    }

    // SteamСйЦ¤єуЦШРВјУФШИЁПЮ(SteamIDїЙДЬёьЧјИ·)
    new szAuth[64];
    get_user_authid(id, szAuth, charsmax(szAuth));

    if (!equal(szAuth, "STEAM_ID_LAN") && !equal(szAuth, "VALVE_ID_LAN") && !equal(szAuth, "STEAM_0:4:")) {
        copy(g_szAuth[id], charsmax(g_szAuth[]), szAuth);
        perm_load(id);
        perm_apply_user_flags(id);
    }
}

public client_disconnected(id)
{
    g_iPermLevel[id] = PERM_NONE;
    g_bVerified[id] = false;
    g_bWaitingPassword[id] = false;
    g_bHidden[id] = false;
    g_iPage[id] = 0;
    g_iMenuAction[id] = 0;
    g_iMapPage[id] = 0;
    g_szAuth[id][0] = '^0';
    g_szName[id][0] = '^0';
}

// ============================================================
//  ГьБо: /vipadmin - ґтїЄИЁПЮ№ЬАнІЛµҐ
// ============================================================
public cmdVipAdmin(id)
{
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }

    // Из№ыТСѕ­СйЦ¤№эЈ¬Ц±ЅУґтїЄЦчІЛµҐ
    if (g_bVerified[id]) {
        show_perm_main_menu(id);
        return PLUGIN_HANDLED;
    }

    // МбКѕКдИлГЬВл
    g_bWaitingPassword[id] = true;
    client_print(id, print_chat, "[HNS] ЗлФЪБДМмїтКдИл№ЬАнГЬВлТФСйЦ¤Йн·Э");
    client_print(id, print_chat, "[HNS] КдИлёсКЅ: Ц±ЅУФЪБДМмїтКдИлГЬВлјґїЙ");

    return PLUGIN_HANDLED;
}

// ============================================================
//  ГьБо: /permcheck - ІйїґЧФјєИЁПЮµИј¶
// ============================================================
public cmdPermCheck(id)
{
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }

    new szLevel[32];
    switch (g_iPermLevel[id]) {
        case PERM_NONE: {
            copy(szLevel, charsmax(szLevel), "ЖХНЁНжјТ");
            break;
        }
        case PERM_TEMP: {
            copy(szLevel, charsmax(szLevel), "Watcher");
            break;
        }
        case PERM_VIP: {
            copy(szLevel, charsmax(szLevel), "VIP");
            break;
        }
        case PERM_ADMIN: {
            copy(szLevel, charsmax(szLevel), "№ЬАнФ±");
            break;
        }
        case PERM_OWNER: {
            copy(szLevel, charsmax(szLevel), "ЧоёЯ·юЦч");
            break;
        }
    }

    client_print(id, print_chat, "[HNS] ДгµДИЁПЮµИј¶: %s (µИј¶ %d)", szLevel, g_iPermLevel[id]);

    return PLUGIN_HANDLED;
}

// ============================================================
//  ГьБо: /hide - ·юЦчТюІШ/ПФКѕЙн·Э
// ============================================================
public cmdToggleHide(id)
{
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }

    if (g_iPermLevel[id] != PERM_OWNER) {
        client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬК№УГТюІШЙн·Э№¦ДЬ");
        return PLUGIN_HANDLED;
    }

    g_bHidden[id] = !g_bHidden[id];

    if (g_bHidden[id]) {
        client_print(id, print_chat, "[HNS] Йн·ЭТСТюІШЈ¬ДгµДБДМмЗ°ЧєЅ«ПФКѕОЄЖХНЁНжјТ");
    } else {
        client_print(id, print_chat, "[HNS] Йн·ЭТСПФКѕЈ¬ДгµДБДМмЗ°ЧєЅ«ПФКѕОЄ·юЦч");
    }

    return PLUGIN_HANDLED;
}

// ============================================================
//  БДМмА№ЅШ: ГЬВлСйЦ¤
// ============================================================
public cmdSayHandler(id)
{
    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    // Из№ыХэФЪµИґэГЬВлКдИл
    if (g_bWaitingPassword[id]) {
        new szArgs[192];
        read_args(szArgs, charsmax(szArgs));
        remove_quotes(szArgs);
        trim(szArgs);

        // јмІйКЗ·сКЗГЬВл
        if (equal(szArgs, ADMIN_PASSWORD)) {
            g_bWaitingPassword[id] = false;
            g_bVerified[id] = true;
            client_print(id, print_chat, "[HNS] ГЬВлСйЦ¤іЙ№¦ЈЎИЁПЮ№ЬАнІЛµҐТСґтїЄ");
            show_perm_main_menu(id);
            return PLUGIN_HANDLED; // І»ПФКѕГЬВлПыПў
        } else {
            // І»КЗГЬВлЈ¬јМРшХэіЈБДМм
            g_bWaitingPassword[id] = false;
            client_print(id, print_chat, "[HNS] ГЬВлґнОуЈ¬ТСИЎПыСйЦ¤");
            return PLUGIN_CONTINUE;
        }
    }

    return PLUGIN_CONTINUE;
}

// ============================================================
//  БДМмСХЙ«А№ЅШ: SayText
// ============================================================
public msgSayText(msgId, msgDest, msgEntity)
{
    if (msgEntity < 1 || msgEntity > MaxClients) {
        return PLUGIN_CONTINUE;
    }

    new id = msgEntity;

    if (!is_user_connected(id)) {
        return PLUGIN_CONTINUE;
    }

    // »сИЎПыПўДЪИЭ
    new szMessage[192];
    get_msg_arg_string(4, szMessage, charsmax(szMessage));

    // јмІйКЗ·сКЗЖХНЁБДМмПыПў(°ьє¬НжјТГы)
    // ёсКЅ: name: message »т (team) name: message
    new szName[32];
    get_user_name(id, szName, charsmax(szName));

    // Из№ыПыПўЦРІ»°ьє¬НжјТГыЈ¬І»ґ¦Ан
    if (contain(szMessage, szName) == -1) {
        return PLUGIN_CONTINUE;
    }

    new szPrefix[64];
    new szNewMsg[256];

    switch (g_iPermLevel[id]) {
        case PERM_OWNER: {
            // ·юЦчЗТОґТюІШ
            if (!g_bHidden[id]) {
                // Мж»»З°ЧєОЄ [LINNA]
                new szTemp[256];
                copy(szTemp, charsmax(szTemp), szMessage);

                // №№ЅЁРВПыПў: ^x01[LINNA]^x03 НжјТГы: ПыПў
                // ХТµЅ "name: " µДО»ЦГ
                new iPos = contain(szTemp, szName);
                if (iPos != -1) {
                    // ХТµЅГ°єЕО»ЦГ
                    new iColon = contain(szTemp[iPos], ":");
                    if (iColon != -1) {
                        iColon += iPos;
                        new szMsgAfter[192];
                        copy(szMsgAfter, charsmax(szMsgAfter), szTemp[iColon + 1]);

                        // јмІйКЗ·сУР(team)З°Чє
                        new bool:bTeam = false;
                        if (contain(szTemp, "(TEAM)") != -1 || contain(szTemp, "(team)") != -1) {
                            bTeam = true;
                        }

                        if (bTeam) {
                            formatex(szNewMsg, charsmax(szNewMsg), "^1(TEAM) ^3[LINNA]^3 %s^3 %s", szName, szMsgAfter);
                        } else {
                            formatex(szNewMsg, charsmax(szNewMsg), "^3[LINNA]^3 %s^3 %s", szName, szMsgAfter);
                        }

                        set_msg_arg_string(4, szNewMsg);
                        return PLUGIN_CONTINUE;
                    }
                }
            }
            // ТюІШЙн·ЭФтІ»РЮёД
            return PLUGIN_CONTINUE;
        }
        case PERM_ADMIN: {
            // №ЬАнФ±
            new szTemp[256];
            copy(szTemp, charsmax(szTemp), szMessage);

            new iPos = contain(szTemp, szName);
            if (iPos != -1) {
                new iColon = contain(szTemp[iPos], ":");
                if (iColon != -1) {
                    iColon += iPos;
                    new szMsgAfter[192];
                    copy(szMsgAfter, charsmax(szMsgAfter), szTemp[iColon + 1]);

                    new bool:bTeam = false;
                    if (contain(szTemp, "(TEAM)") != -1 || contain(szTemp, "(team)") != -1) {
                        bTeam = true;
                    }

                    if (bTeam) {
                        formatex(szNewMsg, charsmax(szNewMsg), "^1(TEAM) ^3[№ЬАн]^1 %s^3 %s", szName, szMsgAfter);
                    } else {
                        formatex(szNewMsg, charsmax(szNewMsg), "^3[№ЬАн]^1 %s^3 %s", szName, szMsgAfter);
                    }

                    set_msg_arg_string(4, szNewMsg);
                    return PLUGIN_CONTINUE;
                }
            }
            return PLUGIN_CONTINUE;
        }
        case PERM_TEMP: {
            // 临时管理
            new szTemp[256];
            copy(szTemp, charsmax(szTemp), szMessage);

            new iPos = contain(szTemp, szName);
            if (iPos != -1) {
                new iColon = contain(szTemp[iPos], ":");
                if (iColon != -1) {
                    iColon += iPos;
                    new szMsgAfter[192];
                    copy(szMsgAfter, charsmax(szMsgAfter), szTemp[iColon + 1]);

                    new bool:bTeam = false;
                    if (contain(szTemp, "(TEAM)") != -1 || contain(szTemp, "(team)") != -1) {
                        bTeam = true;
                    }

                    if (bTeam) {
                        formatex(szNewMsg, charsmax(szNewMsg), "^1(TEAM) ^3[Watcher]^1 %s^3 %s", szName, szMsgAfter);
                    } else {
                        formatex(szNewMsg, charsmax(szNewMsg), "^3[Watcher]^1 %s^3 %s", szName, szMsgAfter);
                    }

                    set_msg_arg_string(4, szNewMsg);
                    return PLUGIN_CONTINUE;
                }
            }
            return PLUGIN_CONTINUE;
        }
        case PERM_VIP: {
            // VIP
            new szTemp[256];
            copy(szTemp, charsmax(szTemp), szMessage);

            new iPos = contain(szTemp, szName);
            if (iPos != -1) {
                new iColon = contain(szTemp[iPos], ":");
                if (iColon != -1) {
                    iColon += iPos;
                    new szMsgAfter[192];
                    copy(szMsgAfter, charsmax(szMsgAfter), szTemp[iColon + 1]);

                    new bool:bTeam = false;
                    if (contain(szTemp, "(TEAM)") != -1 || contain(szTemp, "(team)") != -1) {
                        bTeam = true;
                    }

                    if (bTeam) {
                        formatex(szNewMsg, charsmax(szNewMsg), "^1(TEAM) ^3[VIP]^1 %s^3 %s", szName, szMsgAfter);
                    } else {
                        formatex(szNewMsg, charsmax(szNewMsg), "^3[VIP]^1 %s^3 %s", szName, szMsgAfter);
                    }

                    set_msg_arg_string(4, szNewMsg);
                    return PLUGIN_CONTINUE;
                }
            }
            return PLUGIN_CONTINUE;
        }
        default: {
            // ЖХНЁНжјТІ»РЮёД
            return PLUGIN_CONTINUE;
        }
    }

    return PLUGIN_CONTINUE;
}

// ============================================================
//  ЦчІЛµҐ
// ============================================================
show_perm_main_menu(id)
{
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[512];
    new len;

    len = formatex(szMenu, charsmax(szMenu), "\y[ИЁПЮ№ЬАн]\w^n^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \w·ў·Е№ЬАнИЁПЮ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w·ў·ЕVIPИЁПЮ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \wЗеіэИЁПЮ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \wЧоёЯ·юЦчИЁПЮЈЁёшЧФјєЈ©^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5. \wФЪПЯИЁПЮБР±н^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6. \w№ЬАнІЛµҐ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \wНЛіц");

    show_menu(id, 1023, szMenu, -1, "Perm Main");
}

public handlePermMain(id, key)
{
    if (!is_user_connected(id)) {
        return;
    }

    switch (key) {
        case 0: {
            // ·ў·Е№ЬАнИЁПЮ - РиТЄ·юЦчИЁПЮ
            if (g_iPermLevel[id] != PERM_OWNER) {
                client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬ·ў·Е№ЬАнИЁПЮ");
                show_perm_main_menu(id);
                return;
            }
            g_iMenuAction[id] = 3; // ·ў№ЬАн
            g_iPage[id] = 0;
            show_select_player_menu(id);
            break;
        }
        case 1: {
            // ·ў·ЕVIPИЁПЮ - РиТЄ·юЦчИЁПЮ
            if (g_iPermLevel[id] != PERM_OWNER) {
                client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬ·ў·ЕVIPИЁПЮ");
                show_perm_main_menu(id);
                return;
            }
            g_iMenuAction[id] = 4; // ·ўVIP
            g_iPage[id] = 0;
            show_select_player_menu(id);
            break;
        }
        case 2: {
            // ЗеіэИЁПЮ - РиТЄ·юЦчИЁПЮ
            if (g_iPermLevel[id] != PERM_OWNER) {
                client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬЗеіэИЁПЮ");
                show_perm_main_menu(id);
                return;
            }
            g_iMenuAction[id] = 5; // ЗеИЁПЮ
            g_iPage[id] = 0;
            show_select_player_menu(id);
            break;
        }
        case 3: {
            // ЧоёЯ·юЦчИЁПЮЈЁёшЧФјєЈ©
            if (g_iPermLevel[id] != PERM_OWNER) {
                client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬК№УГґЛ№¦ДЬ");
                show_perm_main_menu(id);
                return;
            }
            // ТСѕ­КЗ·юЦчБЛЈ¬МбКѕ
            client_print(id, print_chat, "[HNS] ДгТСѕ­КЗЧоёЯ·юЦчБЛ");
            show_perm_main_menu(id);
            break;
        }
        case 4: {
            // ФЪПЯИЁПЮБР±н
            show_online_perm_list(id);
            break;
        }
        case 5: {
            // №ЬАнІЛµҐ
            show_admin_menu(id);
            break;
        }
        case 9: {
            // НЛіц
            return;
        }
    }
}

// ============================================================
//  ФЪПЯИЁПЮБР±н
// ============================================================
show_online_perm_list(id)
{
    new szMenu[1024];
    new len;
    new iCount = 0;

    len = formatex(szMenu, charsmax(szMenu), "\y[ФЪПЯИЁПЮБР±н]\w^n^n");

    new players[32], num;
    get_players(players, num);

    for (new i = 0; i < num && iCount < 9; i++) {
        new pid = players[i];
        new szPermName[32];

        switch (g_iPermLevel[pid]) {
            case PERM_TEMP: {
                copy(szPermName, charsmax(szPermName), "Watcher");
                break;
            }
            case PERM_NONE: {
                copy(szPermName, charsmax(szPermName), "ЖХНЁ");
                break;
            }
            case PERM_VIP: {
                copy(szPermName, charsmax(szPermName), "VIP");
                break;
            }
            case PERM_ADMIN: {
                copy(szPermName, charsmax(szPermName), "№ЬАн");
                break;
            }
            case PERM_OWNER: {
                copy(szPermName, charsmax(szPermName), "·юЦч");
                break;
            }
        }

        new szPlayerName[32];
        get_user_name(pid, szPlayerName, charsmax(szPlayerName));

        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d. \w%s \y(%s)^n", iCount + 1, szPlayerName, szPermName);
        iCount++;
    }

    if (iCount == 0) {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\dµ±З°Г»УРФЪПЯНжјТ^n");
    }

    len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \w·µ»Ш");

    show_menu(id, 1023, szMenu, -1, "Perm Main");
}

// ============================================================
//  СЎФсНжјТІЛµҐ
// ============================================================
show_select_player_menu(id)
{
    if (!is_user_connected(id)) {
        return;
    }

    new players[32], num;
    get_players(players, num);

    if (num == 0) {
        client_print(id, print_chat, "[HNS] µ±З°Г»УРФЪПЯНжјТ");
        return;
    }

    new iMaxPages = (num - 1) / MAX_PAGE_SIZE + 1;
    if (g_iPage[id] < 0) g_iPage[id] = 0;
    if (g_iPage[id] >= iMaxPages) g_iPage[id] = iMaxPages - 1;

    new iStart = g_iPage[id] * MAX_PAGE_SIZE;
    new iEnd = iStart + MAX_PAGE_SIZE;
    if (iEnd > num) iEnd = num;

    new szMenu[1024];
    new len;

    len = formatex(szMenu, charsmax(szMenu), "\y[СЎФсНжјТ] \w%d/%d^n^n", g_iPage[id] + 1, iMaxPages);

    for (new i = iStart; i < iEnd; i++) {
        new pid = players[i];
        new szPlayerName[32];
        get_user_name(pid, szPlayerName, charsmax(szPlayerName));

        new szPermName[16];
        switch (g_iPermLevel[pid]) {
            case PERM_NONE: {
                copy(szPermName, charsmax(szPermName), "ЖХНЁ");
                break;
            }
            case PERM_VIP: {
                copy(szPermName, charsmax(szPermName), "VIP");
                break;
            }
            case PERM_ADMIN: {
                copy(szPermName, charsmax(szPermName), "№ЬАн");
                break;
            }
            case PERM_OWNER: {
                copy(szPermName, charsmax(szPermName), "·юЦч");
                break;
            }
        }

        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d. \w%s \y(%s)^n", (i - iStart) + 1, szPlayerName, szPermName);
    }

    len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");

    // ЙПТ»Ті
    if (g_iPage[id] > 0) {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r8. \wЙПТ»Ті^n");
    } else {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\d8. ЙПТ»Ті^n");
    }

    // ПВТ»Ті
    if (g_iPage[id] < iMaxPages - 1) {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r9. \wПВТ»Ті^n");
    } else {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\d9. ПВТ»Ті^n");
    }

    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w·µ»Ш");

    show_menu(id, 1023, szMenu, -1, "Perm Select Player");
}

public handlePermSelectPlayer(id, key)
{
    if (!is_user_connected(id)) {
        return;
    }

    new players[32], num;
    get_players(players, num);

    new iMaxPages = (num - 1) / MAX_PAGE_SIZE + 1;

    switch (key) {
        case 0, 1, 2, 3, 4, 5, 6: {
            // СЎФсНжјТ 1-7
            new iIndex = g_iPage[id] * MAX_PAGE_SIZE + key;
            if (iIndex >= num) {
                show_select_player_menu(id);
                return;
            }

            new target = players[iIndex];

            switch (g_iMenuAction[id]) {
                case 1: {
                    // МЯИЛ - јмІйИЁПЮ
                    if (!can_kick_target(id, target)) {
                        client_print(id, print_chat, "[HNS] ДгГ»УРИЁПЮМЯіцёГНжјТ");
                        show_select_player_menu(id);
                        return;
                    }
                    show_kick_reason_menu(id, target);
                    break;
                }
                case 2: {
                    // ·вЅы - јмІйИЁПЮ
                    if (g_iPermLevel[id] < PERM_ADMIN) {
                        client_print(id, print_chat, "[HNS] ДгГ»УР·вЅыИЁПЮ");
                        show_select_player_menu(id);
                        return;
                    }
                    if (g_iPermLevel[target] >= g_iPermLevel[id]) {
                        client_print(id, print_chat, "[HNS] ДгІ»ДЬ·вЅыН¬ј¶»тёьёЯј¶±рµДНжјТ");
                        show_select_player_menu(id);
                        return;
                    }
                    show_ban_time_menu(id, target);
                    break;
                }
                case 3: {
                    // ·ў№ЬАнИЁПЮ
                    if (g_iPermLevel[id] != PERM_OWNER) {
                        client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬ·ў·Е№ЬАнИЁПЮ");
                        show_select_player_menu(id);
                        return;
                    }
                    // І»ДЬ·ў·юЦч
                    g_iPermLevel[target] = PERM_ADMIN;
                    perm_apply_user_flags(target);
                    perm_save(target);

                    new szTargetName[32];
                    get_user_name(target, szTargetName, charsmax(szTargetName));
                    client_print(id, print_chat, "[HNS] ТСЅ« %s µДИЁПЮЙиЦГОЄ№ЬАнФ±", szTargetName);
                    client_print(target, print_chat, "[HNS] ДгТС±»КЪУи№ЬАнФ±ИЁПЮ");

                    show_perm_main_menu(id);
                    break;
                }
                case 4: {
                    // ·ўVIPИЁПЮ
                    if (g_iPermLevel[id] != PERM_OWNER) {
                        client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬ·ў·ЕVIPИЁПЮ");
                        show_select_player_menu(id);
                        return;
                    }
                    g_iPermLevel[target] = PERM_VIP;
                    perm_apply_user_flags(target);
                    perm_save(target);

                    new szTargetName[32];
                    get_user_name(target, szTargetName, charsmax(szTargetName));
                    client_print(id, print_chat, "[HNS] ТСЅ« %s µДИЁПЮЙиЦГОЄVIP", szTargetName);
                    client_print(target, print_chat, "[HNS] ДгТС±»КЪУиVIPИЁПЮ");

                    show_perm_main_menu(id);
                    break;
                }
                case 5: {
                    // ЗеіэИЁПЮ
                    if (g_iPermLevel[id] != PERM_OWNER) {
                        client_print(id, print_chat, "[HNS] Ц»УРЧоёЯ·юЦчІЕДЬЗеіэИЁПЮ");
                        show_select_player_menu(id);
                        return;
                    }
                    g_iPermLevel[target] = PERM_NONE;
                    perm_apply_user_flags(target);
                    perm_save(target);

                    new szTargetName[32];
                    get_user_name(target, szTargetName, charsmax(szTargetName));
                    client_print(id, print_chat, "[HNS] ТСЗеіэ %s µДИЁПЮ", szTargetName);
                    client_print(target, print_chat, "[HNS] ДгµДИЁПЮТС±»Зеіэ");

                    show_perm_main_menu(id);
                    break;
                }
                case 6: {
                    // ЧЄТЖ¶УОй
                    if (g_iPermLevel[id] < PERM_VIP) {
                        client_print(id, print_chat, "[HNS] ДгГ»УРЧЄТЖ¶УОйµДИЁПЮ");
                        show_select_player_menu(id);
                        return;
                    }
                    transfer_player_team(id, target);
                    show_select_player_menu(id);
                    break;
                }
                default: {
                    show_perm_main_menu(id);
                }
            }
            break;
        }
        case 7: {
            // ЙПТ»Ті
            if (g_iPage[id] > 0) {
                g_iPage[id]--;
            }
            show_select_player_menu(id);
            break;
        }
        case 8: {
            // ПВТ»Ті
            if (g_iPage[id] < iMaxPages - 1) {
                g_iPage[id]++;
            }
            show_select_player_menu(id);
            break;
        }
        case 9: {
            // ·µ»Ш
            show_perm_main_menu(id);
            break;
        }
    }
}

// ============================================================
//  МЯИЛАнУЙІЛµҐ
// ============================================================
show_kick_reason_menu(id, target)
{
    if (!is_user_connected(id)) {
        return;
    }

    // ±ЈґжДї±кµЅІЛµҐactionЦР(ёґУГg_iMenuActionґжДї±кidµДµН16О»)
    // ОТГЗУГТ»ёц¶оНвКэЧй±ЈґжМЯИЛДї±к
    new szMenu[512];
    new len;

    len = formatex(szMenu, charsmax(szMenu), "\y[МЯИЛАнУЙ]\w^n^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \wОҐ№жРРОЄ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w№Т»ъ/AFK^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \wИиВоЛыИЛ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \w¶сТвёЙИЕ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5. \wЖдЛы^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \wИЎПы");

    // ±ЈґжМЯИЛДї±кµЅpage±дБї(БЩК±ЅиУГ)
    g_iPage[id] = target;

    show_menu(id, 1023, szMenu, -1, "Perm Kick Reason");
}

public handlePermKickReason(id, key)
{
    if (!is_user_connected(id)) {
        return;
    }

    new target = g_iPage[id]; // БЩК±ЅиУГpage±дБїґжДї±кid

    // »Цёґpage
    g_iPage[id] = 0;

    if (key == 9) {
        // ИЎПы
        g_iMenuAction[id] = 1; // »ЦёґМЯИЛІЩЧч
        g_iPage[id] = 0;
        show_select_player_menu(id);
        return;
    }

    new szReason[128];
    switch (key) {
        case 0: {
            copy(szReason, charsmax(szReason), "ОҐ№жРРОЄ");
            break;
        }
        case 1: {
            copy(szReason, charsmax(szReason), "№Т»ъ/AFK");
            break;
        }
        case 2: {
            copy(szReason, charsmax(szReason), "ИиВоЛыИЛ");
            break;
        }
        case 3: {
            copy(szReason, charsmax(szReason), "¶сТвёЙИЕ");
            break;
        }
        case 4: {
            copy(szReason, charsmax(szReason), "ЖдЛы");
            break;
        }
        default: {
            copy(szReason, charsmax(szReason), "ОґЦЄ");
        }
    }

    // ЦґРРМЯИЛ
    new szTargetName[32];
    get_user_name(target, szTargetName, charsmax(szTargetName));
    new szAdminName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));

    client_print(0, print_chat, "[HNS] %s ТС±» %s МЯіц (АнУЙ: %s)", szTargetName, szAdminName, szReason);

    // СУіЩМЯИЛЈ¬ИГПыПўПИПФКѕ
    new param[2];
    param[0] = target;
    set_task(0.1, "task_kick_player", 0, param, 2);

    show_admin_menu(id);
}

// СУіЩМЯИЛИООс
public task_kick_player(param[2])
{
    new target = param[0];
    if (is_user_connected(target)) {
        server_cmd("kick #%d ^"ДгТС±»№ЬАнФ±МЯіц^"", get_user_userid(target));
    }
}

// ============================================================
//  ·вЅыК±јдІЛµҐ
// ============================================================
show_ban_time_menu(id, target)
{
    if (!is_user_connected(id)) {
        return;
    }

    new szMenu[512];
    new len;

    len = formatex(szMenu, charsmax(szMenu), "\y[·вЅыК±јд]\w^n^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \w1РЎК±^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w1Мм^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \w7Мм^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \wУАѕГ^n");
    len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \wИЎПы");

    // ±Јґж·вЅыДї±кµЅpage±дБї(БЩК±ЅиУГ)
    g_iPage[id] = target;

    show_menu(id, 1023, szMenu, -1, "Perm Ban Time");
}

public handlePermBanTime(id, key)
{
    if (!is_user_connected(id)) {
        return;
    }

    new target = g_iPage[id]; // БЩК±ЅиУГpage±дБїґжДї±кid

    // »Цёґpage
    g_iPage[id] = 0;

    if (key == 9) {
        // ИЎПы
        g_iMenuAction[id] = 2; // »Цёґ·вЅыІЩЧч
        g_iPage[id] = 0;
        show_select_player_menu(id);
        return;
    }

    new iBanTime = 0; // ГлОЄµҐО», 0=УАѕГ
    new szTimeStr[32];

    switch (key) {
        case 0: { iBanTime = 3600; copy(szTimeStr, charsmax(szTimeStr), "1РЎК±"); break; }
        case 1: { iBanTime = 86400; copy(szTimeStr, charsmax(szTimeStr), "1Мм"); break; }
        case 2: { iBanTime = 604800; copy(szTimeStr, charsmax(szTimeStr), "7Мм"); break; }
        case 3: { iBanTime = 0; copy(szTimeStr, charsmax(szTimeStr), "УАѕГ"); break; }
        default: {
            show_select_player_menu(id);
            return;
        }
    }

    // ЦґРР·вЅы
    new iExpire = 0;
    if (iBanTime > 0) {
        iExpire = get_systime() + iBanTime;
    }

    add_ban(target, iExpire, "№ЬАнФ±·вЅы");

    new szTargetName[32];
    get_user_name(target, szTargetName, charsmax(szTargetName));
    new szAdminName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));

    client_print(0, print_chat, "[HNS] %s ТС±» %s ·вЅы (К±јд: %s)", szTargetName, szAdminName, szTimeStr);

    // МЯіц±»·вЅыНжјТ
    if (is_user_connected(target)) {
        server_cmd("kick #%d ^"ДгТС±»№ЬАнФ±·вЅы (К±јд: %s)^"", get_user_userid(target), szTimeStr);
    }

    show_admin_menu(id);
}

// ============================================================
//  №ЬАнІЛµҐ
// ============================================================
show_admin_menu(id)
{
    if (!is_user_connected(id)) {
        return;
    }

    if (g_iPermLevel[id] == PERM_NONE) {
        client_print(id, print_chat, "[HNS] ДгГ»УР№ЬАнИЁПЮ");
        return;
    }

    new szMenu[1024];
    new len;

    switch (g_iPermLevel[id]) {
        case PERM_VIP: {
            len = formatex(szMenu, charsmax(szMenu), "\y[№ЬАнІЛµҐ - VIP]\w^n^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \wМЯіцНжјТ^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w»»Нј^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \wФЭНЈ/»Цёґ±ИИь^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \wЧЄТЖНжјТ¶УОй^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \w·µ»Ш");
            break;
        }
        case PERM_ADMIN: {
            len = formatex(szMenu, charsmax(szMenu), "\y[№ЬАнІЛµҐ - №ЬАн]\w^n^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \wМЯіцНжјТ^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w·вЅыНжјТ^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \w»»Нј^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \wФЭНЈ/»Цёґ±ИИь^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5. \wЧЄТЖНжјТ¶УОй^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6. \wЦШїЄ»ШєП^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r7. \wЅ»»»¶УОй^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \w·µ»Ш");
            break;
        }
        case PERM_OWNER: {
            len = formatex(szMenu, charsmax(szMenu), "\y[№ЬАнІЛµҐ - ·юЦч]\w^n^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r1. \wМЯіцНжјТ^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r2. \w·вЅыНжјТ^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r3. \wИЁПЮ·ў·Е^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r4. \w»»Нј^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r5. \wФЭНЈ/»Цёґ±ИИь^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r6. \wЧЄТЖНжјТ¶УОй^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r7. \wЦШїЄ»ШєП^n");
            len += formatex(szMenu[len], charsmax(szMenu) - len, "\r8. \wЅ»»»¶УОй^n");
            if (g_bHidden[id]) {
                len += formatex(szMenu[len], charsmax(szMenu) - len, "\r9. \wТюІШЙн·Э \y(µ±З°: ТюІШ)^n");
            } else {
                len += formatex(szMenu[len], charsmax(szMenu) - len, "\r9. \wТюІШЙн·Э \y(µ±З°: ПФКѕ)^n");
            }
            len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r0. \w·µ»Ш");
            break;
        }
        default: {
            return;
        }
    }

    show_menu(id, 1023, szMenu, -1, "Admin Menu");
}

public handleAdminMenu(id, key)
{
    if (!is_user_connected(id)) {
        return;
    }

    switch (key) {
        case 0: {
            // МЯіцНжјТ
            if (g_iPermLevel[id] < PERM_VIP) {
                client_print(id, print_chat, "[HNS] ДгГ»УРМЯИЛИЁПЮ");
                show_admin_menu(id);
                return;
            }
            g_iMenuAction[id] = 1; // МЯИЛ
            g_iPage[id] = 0;
            show_select_player_menu(id);
            break;
        }
        case 1: {
            // ёщѕЭИЁПЮµИј¶Ј¬µЪ2ПоІ»Н¬
            if (g_iPermLevel[id] == PERM_VIP) {
                // VIP: »»Нј
                show_map_list_menu(id);
            } else {
                // №ЬАн/·юЦч: ·вЅыНжјТ
                if (g_iPermLevel[id] < PERM_ADMIN) {
                    client_print(id, print_chat, "[HNS] ДгГ»УР·вЅыИЁПЮ");
                    show_admin_menu(id);
                    return;
                }
                g_iMenuAction[id] = 2; // ·вЅы
                g_iPage[id] = 0;
                show_select_player_menu(id);
            }
            break;
        }
        case 2: {
            if (g_iPermLevel[id] == PERM_VIP) {
                // VIP: ФЭНЈ/»Цёґ±ИИь
                toggle_pause_match(id);
                show_admin_menu(id);
            } else if (g_iPermLevel[id] == PERM_ADMIN) {
                // №ЬАн: »»Нј
                show_map_list_menu(id);
            } else {
                // ·юЦч: ИЁПЮ·ў·Е
                show_perm_main_menu(id);
            }
            break;
        }
        case 3: {
            if (g_iPermLevel[id] == PERM_VIP) {
                // VIP: ЧЄТЖНжјТ¶УОй
                g_iMenuAction[id] = 6; // ЧЄ¶У
                g_iPage[id] = 0;
                show_select_player_menu(id);
            } else if (g_iPermLevel[id] == PERM_ADMIN) {
                // №ЬАн: ФЭНЈ/»Цёґ±ИИь
                toggle_pause_match(id);
                show_admin_menu(id);
            } else {
                // ·юЦч: »»Нј
                show_map_list_menu(id);
            }
            break;
        }
        case 4: {
            if (g_iPermLevel[id] == PERM_ADMIN) {
                // №ЬАн: ЧЄТЖНжјТ¶УОй
                g_iMenuAction[id] = 6; // ЧЄ¶У
                g_iPage[id] = 0;
                show_select_player_menu(id);
            } else if (g_iPermLevel[id] == PERM_OWNER) {
                // ·юЦч: ФЭНЈ/»Цёґ±ИИь
                toggle_pause_match(id);
                show_admin_menu(id);
            }
            break;
        }
        case 5: {
            if (g_iPermLevel[id] == PERM_ADMIN) {
                // №ЬАн: ЦШїЄ»ШєП
                restart_round(id);
                show_admin_menu(id);
            } else if (g_iPermLevel[id] == PERM_OWNER) {
                // ·юЦч: ЧЄТЖНжјТ¶УОй
                g_iMenuAction[id] = 6; // ЧЄ¶У
                g_iPage[id] = 0;
                show_select_player_menu(id);
            }
            break;
        }
        case 6: {
            if (g_iPermLevel[id] == PERM_ADMIN) {
                // №ЬАн: Ѕ»»»¶УОй
                swap_teams(id);
                show_admin_menu(id);
            } else if (g_iPermLevel[id] == PERM_OWNER) {
                // ·юЦч: ЦШїЄ»ШєП
                restart_round(id);
                show_admin_menu(id);
            }
            break;
        }
        case 7: {
            if (g_iPermLevel[id] == PERM_OWNER) {
                // ·юЦч: Ѕ»»»¶УОй
                swap_teams(id);
                show_admin_menu(id);
            }
            break;
        }
        case 8: {
            if (g_iPermLevel[id] == PERM_OWNER) {
                // ·юЦч: ТюІШЙн·Э
                g_bHidden[id] = !g_bHidden[id];
                if (g_bHidden[id]) {
                    client_print(id, print_chat, "[HNS] Йн·ЭТСТюІШ");
                } else {
                    client_print(id, print_chat, "[HNS] Йн·ЭТСПФКѕ");
                }
                show_admin_menu(id);
            }
            break;
        }
        case 9: {
            // ·µ»Ш
            show_perm_main_menu(id);
            break;
        }
    }
}

// ============================================================
//  »»НјІЛµҐ
// ============================================================
show_map_list_menu(id)
{
    if (!is_user_connected(id)) {
        return;
    }

    if (g_iMapCount == 0) {
        client_print(id, print_chat, "[HNS] µШНјБР±нОЄїХ");
        show_admin_menu(id);
        return;
    }

    new iMaxPages = (g_iMapCount - 1) / MAX_PAGE_SIZE + 1;
    if (g_iMapPage[id] < 0) g_iMapPage[id] = 0;
    if (g_iMapPage[id] >= iMaxPages) g_iMapPage[id] = iMaxPages - 1;

    new iStart = g_iMapPage[id] * MAX_PAGE_SIZE;
    new iEnd = iStart + MAX_PAGE_SIZE;
    if (iEnd > g_iMapCount) iEnd = g_iMapCount;

    new szMenu[1024];
    new len;

    len = formatex(szMenu, charsmax(szMenu), "\y[СЎФсµШНј] \w%d/%d^n^n", g_iMapPage[id] + 1, iMaxPages);

    for (new i = iStart; i < iEnd; i++) {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d. \w%s^n", (i - iStart) + 1, g_szMapList[i]);
    }

    len += formatex(szMenu[len], charsmax(szMenu) - len, "^n");

    if (g_iMapPage[id] > 0) {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r8. \wЙПТ»Ті^n");
    } else {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\d8. ЙПТ»Ті^n");
    }

    if (g_iMapPage[id] < iMaxPages - 1) {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\r9. \wПВТ»Ті^n");
    } else {
        len += formatex(szMenu[len], charsmax(szMenu) - len, "\d9. ПВТ»Ті^n");
    }

    len += formatex(szMenu[len], charsmax(szMenu) - len, "\r0. \w·µ»Ш");

    show_menu(id, 1023, szMenu, -1, "Perm Map List");
}

public handlePermMapList(id, key)
{
    if (!is_user_connected(id)) {
        return;
    }

    new iMaxPages = (g_iMapCount - 1) / MAX_PAGE_SIZE + 1;

    switch (key) {
        case 0, 1, 2, 3, 4, 5, 6: {
            new iIndex = g_iMapPage[id] * MAX_PAGE_SIZE + key;
            if (iIndex >= g_iMapCount) {
                show_map_list_menu(id);
                return;
            }

            // »»Нј
            new szMapName[64];
            copy(szMapName, charsmax(szMapName), g_szMapList[iIndex]);

            client_print(0, print_chat, "[HNS] №ЬАнФ±ХэФЪЗР»»µШНјµЅ: %s", szMapName);

            // СУіЩ»»Нј
            new param[64];
            copy(param, charsmax(param), szMapName);
            set_task(1.0, "task_change_map", 0, param, charsmax(param));
            break;
        }
        case 7: {
            // ЙПТ»Ті
            if (g_iMapPage[id] > 0) {
                g_iMapPage[id]--;
            }
            show_map_list_menu(id);
            break;
        }
        case 8: {
            // ПВТ»Ті
            if (g_iMapPage[id] < iMaxPages - 1) {
                g_iMapPage[id]++;
            }
            show_map_list_menu(id);
            break;
        }
        case 9: {
            // ·µ»Ш
            show_admin_menu(id);
            break;
        }
    }
}

// СУіЩ»»НјИООс
public task_change_map(param[64])
{
    new szMap[64];
    copy(szMap, charsmax(szMap), param);
    client_cmd(0, "changelevel %s", szMap);
}

// ============================================================
//  ИЁПЮјмІйєЇКэ
// ============================================================

// јмІйМЯИЛХЯДЬ·сМЯДї±к
// VIPїЙТФМЯЖХНЁНжјТ
// №ЬАнїЙТФМЯЖХНЁєНVIP
// ·юЦчїЙТФМЯЛщУРИЛ
can_kick_target(kicker, target)
{
    if (kicker == target) {
        return 0;
    }

    if (!is_user_connected(target)) {
        return 0;
    }

    new iKickerLevel = g_iPermLevel[kicker];
    new iTargetLevel = g_iPermLevel[target];

    // VIP(1)їЙТФМЯЖХНЁ(0)
    // №ЬАн(2)їЙТФМЯЖХНЁ(0)єНVIP(1)
    // ·юЦч(3)їЙТФМЯЛщУРИЛ
    if (iKickerLevel > iTargetLevel) {
        return 1;
    }

    return 0;
}

// ============================================================
//  №ЬАн№¦ДЬКµПЦ
// ============================================================

// ФЭНЈ/»Цёґ±ИИь
toggle_pause_match(id)
{
    if (g_iPermLevel[id] < PERM_VIP) {
        client_print(id, print_chat, "[HNS] ДгГ»УРФЭНЈ/»Цёґ±ИИьµДИЁПЮ");
        return;
    }

    // К№УГReAPIµДФЭНЈ№¦ДЬ
    // rg_round_pause їЙТФФЭНЈ/»Цёґ»ШєП
    set_cvar_num("pausable", 1);

    // ·ўЛНФЭНЈ/»ЦёґГьБо
    // К№УГReGameDLLµДФЭНЈ№¦ДЬ
    new Float:fGameTime = get_gametime();

    // НЁ№э·ўЛНpauseГьБоКµПЦ
    client_cmd(id, "pause");

    client_print(0, print_chat, "[HNS] ±ИИьТСФЭНЈ/»Цёґ");
}

// ЧЄТЖНжјТ¶УОй
transfer_player_team(admin, target)
{
    if (!is_user_connected(target)) {
        client_print(admin, print_chat, "[HNS] Дї±кНжјТІ»ФЪПЯ");
        return;
    }

    new iTeam = get_member(target, m_iTeam);

    if (iTeam == TEAM_TERRORIST) {
        rg_set_user_team(target, TEAM_CT, MODEL_AUTO, true);
    } else if (iTeam == TEAM_CT) {
        rg_set_user_team(target, TEAM_TERRORIST, MODEL_AUTO, true);
    } else {
        // Оґ·ЦЕд¶УОйЈ¬·ЦЕдµЅCT
        rg_set_user_team(target, TEAM_CT, MODEL_AUTO, true);
    }

    new szTargetName[32];
    get_user_name(target, szTargetName, charsmax(szTargetName));
    client_print(admin, print_chat, "[HNS] ТСЧЄТЖ %s µД¶УОй", szTargetName);
    client_print(target, print_chat, "[HNS] ДгµД¶УОйТС±»№ЬАнФ±ЧЄТЖ");
}

// ЦШїЄ»ШєП
restart_round(id)
{
    if (g_iPermLevel[id] < PERM_ADMIN) {
        client_print(id, print_chat, "[HNS] ДгГ»УРЦШїЄ»ШєПµДИЁПЮ");
        return;
    }

    // К№УГReAPIЦШїЄ»ШєП
    server_cmd("sv_restart 1");
	// rg_round_restart replaced
    client_print(0, print_chat, "[HNS] №ЬАнФ±ТСЦШїЄ»ШєП");
}

// Ѕ»»»¶УОй
swap_teams(id)
{
    if (g_iPermLevel[id] < PERM_ADMIN) {
        client_print(id, print_chat, "[HNS] ДгГ»УРЅ»»»¶УОйµДИЁПЮ");
        return;
    }

    new players[32], num;
    get_players(players, num, "h"); // »сИЎЛщУРґж»оНжјТ

    for (new i = 0; i < num; i++) {
        new pid = players[i];
        new iTeam = get_member(pid, m_iTeam);

        if (iTeam == TEAM_TERRORIST) {
            rg_set_user_team(pid, TEAM_CT, MODEL_AUTO, true);
        } else if (iTeam == TEAM_CT) {
            rg_set_user_team(pid, TEAM_TERRORIST, MODEL_AUTO, true);
        }
    }

    client_print(0, print_chat, "[HNS] №ЬАнФ±ТСЅ»»»ЛщУРНжјТ¶УОй");
}

// ============================================================
//  ·вЅыПµНі
// ============================================================

// МнјУ·вЅы
add_ban(id, iExpire, const szReason[])
{
    if (g_iBanCount >= MAX_BANS) {
        return;
    }

    new szAuth[MAX_AUTH_LEN];
    get_user_authid(id, szAuth, charsmax(szAuth));

    // Из№ыКЗµБ°жНжјТЈ¬УГIP
    if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:")) {
        get_user_ip(id, szAuth, charsmax(szAuth), 1);
    }

    // јмІйКЗ·сТСґжФЪ
    for (new i = 0; i < g_iBanCount; i++) {
        if (equal(g_szBannedAuth[i], szAuth)) {
            // ёьРВ·вЅы
            g_iBanExpire[i] = iExpire;
            copy(g_szBanReason[i], charsmax(g_szBanReason[]), szReason);
            save_bans_file();
            return;
        }
    }

    // МнјУРВ·вЅы
    copy(g_szBannedAuth[g_iBanCount], charsmax(g_szBannedAuth[]), szAuth);
    g_iBanExpire[g_iBanCount] = iExpire;
    copy(g_szBanReason[g_iBanCount], charsmax(g_szBanReason[]), szReason);
    g_iBanCount++;

    save_bans_file();
}

// јмІйНжјТКЗ·с±»·вЅы
check_ban(id)
{
    new szAuth[MAX_AUTH_LEN];
    get_user_authid(id, szAuth, charsmax(szAuth));

    // Из№ыКЗµБ°жНжјТЈ¬УГIP
    if (equal(szAuth, "STEAM_ID_LAN") || equal(szAuth, "VALVE_ID_LAN") || equal(szAuth, "STEAM_0:4:")) {
        get_user_ip(id, szAuth, charsmax(szAuth), 1);
    }

    new iCurrentTime = get_systime();

    for (new i = 0; i < g_iBanCount; i++) {
        if (equal(g_szBannedAuth[i], szAuth)) {
            // јмІйКЗ·с№эЖЪ
            if (g_iBanExpire[i] == 0 || g_iBanExpire[i] > iCurrentTime) {
                // Оґ№эЖЪЈ¬МЯіц
                new szReason[128];
                copy(szReason, charsmax(szReason), g_szBanReason[i]);

                new szKickMsg[256];
                if (g_iBanExpire[i] == 0) {
                    formatex(szKickMsg, charsmax(szKickMsg), "ДгТС±»УАѕГ·вЅы (АнУЙ: %s)", szReason);
                } else {
                    new iRemaining = g_iBanExpire[i] - iCurrentTime;
                    new szTime[64];
                    format_ban_time(iRemaining, szTime, charsmax(szTime));
                    formatex(szKickMsg, charsmax(szKickMsg), "ДгТС±»·вЅы (КЈУа: %s, АнУЙ: %s)", szTime, szReason);
                }

                server_cmd("kick #%d ^"%s^"", get_user_userid(id), szKickMsg);
                return;
            } else {
                // ТС№эЖЪЈ¬ТЖіэ·вЅы
                remove_ban(i);
                i--; // ТтОЄТЖіэБЛТ»ёцЈ¬ЛчТэ»ШНЛ
            }
        }
    }
}

// ТЖіэ·вЅы
remove_ban(index)
{
    if (index < 0 || index >= g_iBanCount) {
        return;
    }

    // Ѕ«ЧоєуТ»ёц·вЅыТЖµЅµ±З°О»ЦГ
    g_iBanCount--;

    if (index < g_iBanCount) {
        copy(g_szBannedAuth[index], charsmax(g_szBannedAuth[]), g_szBannedAuth[g_iBanCount]);
        g_iBanExpire[index] = g_iBanExpire[g_iBanCount];
        copy(g_szBanReason[index], charsmax(g_szBanReason[]), g_szBanReason[g_iBanCount]);
    }

    g_szBannedAuth[g_iBanCount][0] = '^0';
    g_szBanReason[g_iBanCount][0] = '^0';
    g_iBanExpire[g_iBanCount] = 0;

    save_bans_file();
}

// ёсКЅ»Ї·вЅыКЈУаК±јд
format_ban_time(iSeconds, szBuffer[], iLen)
{
    if (iSeconds <= 0) {
        copy(szBuffer, iLen, "ТС№эЖЪ");
        return;
    }

    new iDays = iSeconds / 86400;
    new iHours = (iSeconds % 86400) / 3600;
    new iMins = (iSeconds % 3600) / 60;

    if (iDays > 0) {
        formatex(szBuffer, iLen, "%dМм%dРЎК±%d·ЦЦУ", iDays, iHours, iMins);
    } else if (iHours > 0) {
        formatex(szBuffer, iLen, "%dРЎК±%d·ЦЦУ", iHours, iMins);
    } else {
        formatex(szBuffer, iLen, "%d·ЦЦУ", iMins);
    }
}

// ±Јґж·вЅыБР±нµЅОДјю
save_bans_file()
{
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    new szFile[256];
    formatex(szFile, charsmax(szFile), "%s/permsystem/ban_list.txt", szDir);

    new fp = fopen(szFile, "wt");
    if (!fp) {
        return;
    }

    fprintf(fp, "; HNS PermSystem Ban List^n");
    fprintf(fp, "; Format: authid/ip expire_timestamp reason^n");
    fprintf(fp, "; expire 0 = permanent^n^n");

    for (new i = 0; i < g_iBanCount; i++) {
        fprintf(fp, "^"%s^" %d ^"%s^"^n", g_szBannedAuth[i], g_iBanExpire[i], g_szBanReason[i]);
    }

    fclose(fp);
}

// ґУОДјюјУФШ·вЅыБР±н
load_bans_file()
{
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    new szFile[256];
    formatex(szFile, charsmax(szFile), "%s/permsystem/ban_list.txt", szDir);

    new fp = fopen(szFile, "rt");
    if (!fp) {
        return;
    }

    g_iBanCount = 0;

    new szLine[512];
    while (!feof(fp) && g_iBanCount < MAX_BANS) {
        fgets(fp, szLine, charsmax(szLine));
        trim(szLine);

        // Мш№эЧўКНєНїХРР
        if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') {
            continue;
        }

        // ЅвОц: "authid/ip" expire "reason"
        new szAuth[64], szReason[128], szExpire[32];
        new iLen = strlen(szLine);

        // МбИЎauthid (ТэєЕДЪ)
        new iStart = -1, iEnd = -1;
        for (new i = 0; i < iLen; i++) {
            if (szLine[i] == '"') {
                if (iStart == -1) {
                    iStart = i + 1;
                } else {
                    iEnd = i;
                    break;
                }
            }
        }

        if (iStart == -1 || iEnd == -1) {
            continue;
        }

        new iAuthLen = iEnd - iStart;
        if (iAuthLen >= charsmax(szAuth)) {
            iAuthLen = charsmax(szAuth) - 1;
        }
        copy(szAuth, iAuthLen, szLine[iStart]);

        // Мш№эТэєЕєНїХёсЈ¬ХТexpire
        new iPos = iEnd + 1;
        while (iPos < iLen && (szLine[iPos] == ' ' || szLine[iPos] == '"')) {
            iPos++;
        }

        // МбИЎexpire
        new iExpireStart = iPos;
        while (iPos < iLen && szLine[iPos] != ' ' && szLine[iPos] != '"') {
            iPos++;
        }
        new iExpireLen = iPos - iExpireStart;
        if (iExpireLen >= charsmax(szExpire)) {
            iExpireLen = charsmax(szExpire) - 1;
        }
        copy(szExpire, iExpireLen, szLine[iExpireStart]);

        // МбИЎreason (ТэєЕДЪ)
        iStart = -1;
        iEnd = -1;
        for (new i = iPos; i < iLen; i++) {
            if (szLine[i] == '"') {
                if (iStart == -1) {
                    iStart = i + 1;
                } else {
                    iEnd = i;
                    break;
                }
            }
        }

        if (iStart != -1 && iEnd != -1) {
            new iReasonLen = iEnd - iStart;
            if (iReasonLen >= charsmax(szReason)) {
                iReasonLen = charsmax(szReason) - 1;
            }
            copy(szReason, iReasonLen, szLine[iStart]);
        } else {
            copy(szReason, charsmax(szReason), "ОґЦЄ");
        }

        // јмІйКЗ·с№эЖЪ
        new iExpire = str_to_num(szExpire);
        if (iExpire != 0 && iExpire < get_systime()) {
            continue; // Мш№эТС№эЖЪµД·вЅы
        }

        copy(g_szBannedAuth[g_iBanCount], charsmax(g_szBannedAuth[]), szAuth);
        g_iBanExpire[g_iBanCount] = iExpire;
        copy(g_szBanReason[g_iBanCount], charsmax(g_szBanReason[]), szReason);
        g_iBanCount++;
    }

    fclose(fp);
}

// ============================================================
//  µШНјБР±нјУФШ
// ============================================================
load_map_list()
{
    // ґУmapcyclefileјУФШµШНјБР±н
    new szMapCycleFile[64];
    get_cvar_string("mapcyclefile", szMapCycleFile, charsmax(szMapCycleFile));

    new fp = fopen(szMapCycleFile, "rt");
    if (!fp) {
        // іўКФД¬ИПВ·ѕ¶
        fp = fopen("mapcycle.txt", "rt");
        if (!fp) {
            return;
        }
    }

    g_iMapCount = 0;
    new szLine[64];

    while (!feof(fp) && g_iMapCount < 256) {
        fgets(fp, szLine, charsmax(szLine));
        trim(szLine);

        // Мш№эЧўКНєНїХРР
        if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0' || strlen(szLine) < 2) {
            continue;
        }

        // јмІйКЗ·сКЗµ±З°µШНј
        new szCurrentMap[64];
        get_mapname(szCurrentMap, charsmax(szCurrentMap));

        if (!equal(szLine, szCurrentMap)) {
            copy(g_szMapList[g_iMapCount], charsmax(g_szMapList[]), szLine);
            g_iMapCount++;
        }
    }

    fclose(fp);
}

// ============================================================
//  ИЁПЮ±Јґж/јУФШ (PDS + ОДјюЛ«±ё·Э)
// ============================================================

// ±ЈґжНжјТИЁПЮµЅPDSєНОДјю
stock perm_save(id)
{
    if (g_szAuth[id][0] == '^0') {
        return;
    }

    new szKey[128];
    new szValue[8];
    num_to_str(g_iPermLevel[id], szValue, charsmax(szValue));

    // ЕР¶ПКЗSteamНжјТ»№КЗµБ°жНжјТ
    if (contain(g_szAuth[id], "STEAM_") != -1) {
        formatex(szKey, charsmax(szKey), "hns_perm_%s", g_szAuth[id]);
    } else {
        formatex(szKey, charsmax(szKey), "hns_permip_%s", g_szAuth[id]);
    }

    // ±ЈґжµЅPDS
    PDS_SetString(szKey, szValue);

    // ±ЈґжµЅОДјю
    perm_save_file();
}

// ґУPDSєНОДјюјУФШНжјТИЁПЮ
stock perm_load(id)
{
    if (g_szAuth[id][0] == '^0') {
        return;
    }

    new szKey[128];
    new szValue[8];

    // ЕР¶ПКЗSteamНжјТ»№КЗµБ°жНжјТ
    if (contain(g_szAuth[id], "STEAM_") != -1) {
        formatex(szKey, charsmax(szKey), "hns_perm_%s", g_szAuth[id]);
    } else {
        formatex(szKey, charsmax(szKey), "hns_permip_%s", g_szAuth[id]);
    }

    // ПИґУPDSјУФШ
    if (PDS_GetString(szKey, szValue, charsmax(szValue))) {
        g_iPermLevel[id] = str_to_num(szValue);
        return;
    }

    // PDSГ»УРЈ¬ґУОДјюјУФШ
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    new szFile[256];
    formatex(szFile, charsmax(szFile), "%s/permsystem/perm_list.txt", szDir);

    new fp = fopen(szFile, "rt");
    if (!fp) {
        g_iPermLevel[id] = PERM_NONE;
        return;
    }

    new szLine[256];
    new bool:bFound = false;

    while (!feof(fp) && !bFound) {
        fgets(fp, szLine, charsmax(szLine));
        trim(szLine);

        // Мш№эЧўКНєНїХРР
        if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') {
            continue;
        }

        // ёсКЅ: steamid_or_ip name permission_level
        new szAuth[64], szName[32], szPerm[8];
        parse(szLine, szAuth, charsmax(szAuth), szName, charsmax(szName), szPerm, charsmax(szPerm));

        if (equal(szAuth, g_szAuth[id])) {
            new iPerm = str_to_num(szPerm);
            // 迁移旧权限值：旧 1=VIP 2=管理 3=服主 → 新 2=VIP 3=管理 4=服主
            if (iPerm >= 1 && iPerm <= 3)
                iPerm += 1;
            
            if (iPerm >= PERM_NONE && iPerm <= PERM_OWNER) {
                g_iPermLevel[id] = iPerm;

                // Н¬ІЅµЅPDS
                PDS_SetString(szKey, szPerm);
            }
            bFound = true;
        }
    }

    fclose(fp);

    if (!bFound) {
        g_iPermLevel[id] = PERM_NONE;
    }
}

// РґИлОДјю±ё·Э
stock perm_save_file()
{
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    new szFile[256];
    formatex(szFile, charsmax(szFile), "%s/permsystem/perm_list.txt", szDir);

    new fp = fopen(szFile, "wt");
    if (!fp) {
        return;
    }

    fprintf(fp, "; HNS PermSystem Permission List^n");
    fprintf(fp, "; Format: steamid_or_ip name permission_level^n");
    fprintf(fp, "; Levels: 0=ЖХНЁ 1=VIP 2=№ЬАн 3=·юЦч^n^n");

    new players[32], num;
    get_players(players, num);

    // ±йАъЛщУРНжјТЈ¬±ЈґжУРИЁПЮµД
    for (new i = 0; i < num; i++) {
        new pid = players[i];
        if (g_iPermLevel[pid] > PERM_NONE && g_szAuth[pid][0] != '^0') {
            new szName[32];
            get_user_name(pid, szName, charsmax(szName));

            // Мж»»їХёсОЄПВ»®ПЯ
            for (new j = 0; j < strlen(szName); j++) {
                if (szName[j] == ' ') {
                    szName[j] = '_';
                }
            }

            fprintf(fp, "%s %s %d^n", g_szAuth[pid], szName, g_iPermLevel[pid]);
        }
    }

    fclose(fp);
}

// Жф¶ЇК±ґУОДјюјУФШµЅPDS
stock perm_load_file()
{
    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    new szFile[256];
    formatex(szFile, charsmax(szFile), "%s/permsystem/perm_list.txt", szDir);

    new fp = fopen(szFile, "rt");
    if (!fp) {
        return;
    }

    new szLine[256];

    while (!feof(fp)) {
        fgets(fp, szLine, charsmax(szLine));
        trim(szLine);

        // Мш№эЧўКНєНїХРР
        if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '^0') {
            continue;
        }

        // ёсКЅ: steamid_or_ip name permission_level
        new szAuth[64], szName[32], szPerm[8];
        parse(szLine, szAuth, charsmax(szAuth), szName, charsmax(szName), szPerm, charsmax(szPerm));

        new iPerm = str_to_num(szPerm);
        if (iPerm < PERM_NONE || iPerm > PERM_OWNER) {
            continue;
        }

        // №№ЅЁPDSјьГы
        new szKey[128];
        if (contain(szAuth, "STEAM_") != -1) {
            formatex(szKey, charsmax(szKey), "hns_perm_%s", szAuth);
        } else {
            formatex(szKey, charsmax(szKey), "hns_permip_%s", szAuth);
        }

        // јУФШµЅPDS
        PDS_SetString(szKey, szPerm);
    }

    fclose(fp);

    // Н¬К±јУФШ·вЅыБР±н
    load_bans_file();
}
