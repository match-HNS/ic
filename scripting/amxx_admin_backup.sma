#include <amxmodx>
#include <amxmisc>

// 每次加载时检查 users.ini.tmp 并自动恢复
// 每次 admins 被重新加载时自动备份

#define PLUGIN_NAME "Admin Backup"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_AUTHOR "HNS"

new g_szBackupDir[128];
new g_szBackupFile[256];

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    // 创建备份目录
    get_configsdir(g_szBackupDir, charsmax(g_szBackupDir));
    format(g_szBackupFile, charsmax(g_szBackupFile), "%s/backup", g_szBackupDir);

    if (!dir_exists(g_szBackupFile)) {
        mkdir(g_szBackupFile);
    }

    // 自动恢复: 如果 users.ini 不存在但 users.ini.tmp 存在
    AutoRecover();

    // 启动时备份一次
    AutoBackup();

    server_print("[Admin Backup] 插件已加载。每次管理员变更自动备份。");
}

public plugin_end() {
    // 服务器关闭/地图切换时也备份一次
    AutoBackup();
}

// ==================== 自动恢复 ====================
AutoRecover() {
    new szDir[128], szIni[256], szTmp[256];
    get_configsdir(szDir, charsmax(szDir));

    formatex(szIni, charsmax(szIni), "%s/users.ini", szDir);
    formatex(szTmp, charsmax(szTmp), "%s/users.ini.tmp", szDir);

    // 如果 users.ini 存在且 tmp 也存在，删掉 tmp
    if (file_exists(szIni) && file_exists(szTmp)) {
        delete_file(szTmp);
        server_print("[Admin Backup] 清理残留 tmp 文件");
        return;
    }

    // 如果 users.ini 不存在但 tmp 存在 → 自动恢复
    if (!file_exists(szIni) && file_exists(szTmp)) {
        if (rename_file(szTmp, szIni)) {
            server_print("[Admin Backup] !!! 自动恢复 users.ini (从 tmp 恢复)");
            // 重新加载 admins
            server_cmd("amx_reloadadmins");
        } else {
            server_print("[Admin Backup] !!! 恢复失败，请手动处理");
        }
    }
}

// ==================== 自动备份 ====================
AutoBackup() {
    new szDir[128], szIni[256];
    get_configsdir(szDir, charsmax(szDir));
    formatex(szIni, charsmax(szIni), "%s/users.ini", szDir);

    if (!file_exists(szIni)) {
        server_print("[Admin Backup] users.ini 不存在，跳过备份");
        return;
    }

    // 带时间戳的备份文件名
    new szBackup[256], szTime[32];
    get_time("%Y%m%d_%H%M%S", szTime, charsmax(szTime));
    formatex(szBackup, charsmax(szBackup), "%s/users_%s.ini", g_szBackupFile, szTime);

    // 复制文件
    new fSrc = fopen(szIni, "rb");
    if (!fSrc) return;

    new fDst = fopen(szBackup, "wb");
    if (!fDst) {
        fclose(fSrc);
        return;
    }

    new szBuf[512], iRead;
    while (!feof(fSrc)) {
        iRead = fread_blocks(fSrc, szBuf, 1, 512);
        if (iRead > 0) {
            fwrite_blocks(fDst, szBuf, 1, 512);
        }
    }
    fclose(fSrc);
    fclose(fDst);

    // 同时保存一份固定名称的备份 (方便恢复)
    new szLatest[256];
    formatex(szLatest, charsmax(szLatest), "%s/users_latest.ini", g_szBackupFile);
    if (file_exists(szLatest)) delete_file(szLatest);
    rename_file(szBackup, szLatest);

    server_print("[Admin Backup] 备份完成: %s", szLatest);

    // 只保留最近 10 个备份
    CleanOldBackups();
}

// ==================== 清理旧备份 ====================
CleanOldBackups() {
    // 列出备份目录中的 users_*.ini 文件，超过10个就删最旧的
    new szDir[128], szPattern[256];
    formatex(szDir, charsmax(szDir), "%s/backup", g_szBackupDir);
    formatex(szPattern, charsmax(szPattern), "%s/users_*.ini", szDir);

    // 简单处理: 保留 users_latest.ini + 最近10个
    new szFiles[64][256], iCount = 0;

    new hDir = open_dir(szDir, szFiles[0], charsmax(szFiles[0]));
    if (!hDir) return;

    // Read first
    new szItem[256];
    while (next_file(hDir, szItem, charsmax(szItem))) {
        if (containi(szItem, "users_") == 0 && containi(szItem, ".ini") > 0) {
            formatex(szFiles[iCount], charsmax(szFiles[]), "%s/%s", szDir, szItem);
            iCount++;
            if (iCount >= 64) break;
        }
    }
    close_dir(hDir);

    // 删除超出限制的旧文件 (保留最新的，所以从前往后删)
    while (iCount > 10) {
        delete_file(szFiles[0]);
        server_print("[Admin Backup] 删除旧备份: %s", szFiles[0]);
        // Shift array
        for (new i = 1; i < iCount; i++) {
            copy(szFiles[i-1], charsmax(szFiles[]), szFiles[i]);
        }
        iCount--;
    }
}
