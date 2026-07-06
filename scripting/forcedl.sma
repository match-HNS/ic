#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

// 最大文件数
#define MAX_FILES 512

new g_szFileList[MAX_FILES][192];
new g_iFileCount;
new g_szMapName[64];

public plugin_precache() {
	// 读取下载列表配置文件
	new szPath[256], szDir[128];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szPath, charsmax(szPath), "%s/download_list.ini", szDir);
	
	new f = fopen(szPath, "rt");
	if (!f) {
		// 如果没有配置文件，自动扫描 maps 目录生成一个
		server_print("[ForceDL] 配置文件不存在: %s", szPath);
		server_print("[ForceDL] 正在自动生成...");
		AutoGenerate(szDir, szPath);
		f = fopen(szPath, "rt");
		if (!f) {
			server_print("[ForceDL] 自动生成失败，插件跳过");
			return;
		}
	}
	
	new szLine[256];
	g_iFileCount = 0;
	
	while (!feof(f) && fgets(f, szLine, charsmax(szLine)) && g_iFileCount < MAX_FILES) {
		trim(szLine);
		
		// 跳过注释和空行
		if (szLine[0] == ';' || szLine[0] == '/' || szLine[0] == '#' || szLine[0] == EOS)
			continue;
		
		// 确保以 models/ sound/ sprites/ 开头
		if (!StartsWith(szLine, "models/") && !StartsWith(szLine, "sound/") && !StartsWith(szLine, "sprites/"))
			continue;
		
		copy(g_szFileList[g_iFileCount], charsmax(g_szFileList[]), szLine);
		
		// 根据文件类型 precache
		if (contain(szLine, ".mdl") >= 0) {
			if (precache_model(szLine) == 0) {
				server_print("[ForceDL] precache_model 失败: %s", szLine);
				g_iFileCount--;
			}
		} else {
			if (precache_generic(szLine) == 0) {
				server_print("[ForceDL] precache_generic 失败: %s", szLine);
				g_iFileCount--;
			}
		}
		
		if (g_iFileCount >= 0)
			server_print("[ForceDL] 强制下载: %s", szLine);
		
		g_iFileCount++;
	}
	
	fclose(f);
	
	server_print("[ForceDL] 共加载 %d 个文件", g_iFileCount);
}

AutoGenerate(szDir[], szPath[]) {
	// 自动扫描 cstrike 目录下的自定义文件
	new szBaseDir[256];
	formatex(szBaseDir, charsmax(szBaseDir), "%s/..", szDir);
	
	new f = fopen(szPath, "wt");
	if (!f) return;
	
	fprintf(f, "; ===================================^n");
	fprintf(f, "; 强制下载文件列表 - ForceDL 自动生成^n");
	fprintf(f, "; 格式: 每行一个文件路径^n");
	fprintf(f, "; 支持: models/ sound/ sprites/^n");
	fprintf(f, "; ===================================^n^n");
	
	new iCount = 0;
	
	// 扫描 models 目录
	iCount += ScanDir(f, szBaseDir, "models", ".mdl");
	
	// 扫描 sound 目录
	iCount += ScanDir(f, szBaseDir, "sound", ".wav");
	
	// 扫描 sprites 目录
	iCount += ScanDir(f, szBaseDir, "sprites", ".spr");
	
	fclose(f);
	
	server_print("[ForceDL] 自动扫描发现 %d 个自定义文件", iCount);
}

ScanDir(fHandle, szBase[], szSubDir[], szExt[]) {
	new szSearchPath[256], szFullDir[256], szDirPath[256];
	formatex(szSearchPath, charsmax(szSearchPath), "%s/%s/*", szBase, szSubDir);
	formatex(szFullDir, charsmax(szFullDir), "%s/%s", szBase, szSubDir);
	formatex(szDirPath, charsmax(szDirPath), "%s/", szSubDir);
	
	new iCount = 0;
	new iLen = strlen(szDirPath);
	
	// 递归扫描
	ScanDirRecursive(fHandle, szFullDir, szDirPath, iLen, szExt, iCount);
	
	return iCount;
}

ScanDirRecursive(fHandle, szCurrentDir[], szPrefix[], iPrefixLen, szExt[], &iCount) {
	new szEntry[64], szPath[256], szEntryPath[256];
	
	new dir = open_dir(szCurrentDir, szEntry, charsmax(szEntry));
	if (!dir) return;
	
	while (next_file(dir, szEntry, charsmax(szEntry))) {
		if (equal(szEntry, ".") || equal(szEntry, ".."))
			continue;
		
		formatex(szPath, charsmax(szPath), "%s/%s", szCurrentDir, szEntry);
		
		if (dir_exists(szPath)) {
			// 递归子目录
			new szNewPrefix[256];
			copy(szNewPrefix, charsmax(szNewPrefix), szPrefix);
			format(szNewPrefix, charsmax(szNewPrefix), "%s%s/", szPrefix, szEntry);
			ScanDirRecursive(fHandle, szPath, szNewPrefix, strlen(szNewPrefix), szExt, iCount);
		} else {
			// 检查扩展名
			new iExtLen = strlen(szExt);
			new iNameLen = strlen(szEntry);
			if (iNameLen > iExtLen) {
				new iPos = iNameLen - iExtLen;
				if (equal(szEntry[iPos], szExt, iExtLen)) {
					// 跳过默认 CS 文件
					if (IsDefaultFile(szPrefix, szEntry))
						continue;
					
					new szLine[256];
					formatex(szLine, charsmax(szLine), "%s%s", szPrefix, szEntry);
					fprintf(fHandle, "%s^n", szLine);
					iCount++;
				}
			}
		}
	}
	close_dir(dir);
}

bool:IsDefaultFile(szPrefix[], szName[]) {
	// 跳过默认 CS 模型
	if (contain(szPrefix, "player/") >= 0) {
		if (equali(szName, "leet.mdl") || equali(szName, "arctic.mdl") ||
		    equali(szName, "guerilla.mdl") || equali(szName, "terror.mdl") ||
		    equali(szName, "gsg9.mdl") || equali(szName, "gign.mdl") ||
		    equali(szName, "sas.mdl") || equali(szName, "urban.mdl") ||
		    equali(szName, "vip.mdl") || equali(szName, "spetnaz.mdl") ||
		    equali(szName, "militia.mdl"))
			return true;
	}
	
	// 跳过默认武器模型
	if (equali(szName, "v_ak47.mdl") || equali(szName, "v_awp.mdl") ||
	    equali(szName, "v_deagle.mdl") || equali(szName, "v_famas.mdl") ||
	    equali(szName, "v_g3sg1.mdl") || equali(szName, "v_galil.mdl") ||
	    equali(szName, "v_knife.mdl") || equali(szName, "v_m249.mdl") ||
	    equali(szName, "v_m3.mdl") || equali(szName, "v_m4a1.mdl") ||
	    equali(szName, "v_mac10.mdl") || equali(szName, "v_mp5.mdl") ||
	    equali(szName, "v_p228.mdl") || equali(szName, "v_p90.mdl") ||
	    equali(szName, "v_scout.mdl") || equali(szName, "v_sg550.mdl") ||
	    equali(szName, "v_sg552.mdl") || equali(szName, "v_tmp.mdl") ||
	    equali(szName, "v_ump45.mdl") || equali(szName, "v_usp.mdl") ||
	    equali(szName, "v_xm1014.mdl") || equali(szName, "v_shield.mdl") ||
	    equali(szName, "p_") || equali(szName, "w_"))
		return true;
	
	return false;
}

bool:StartsWith(szStr[], szPrefix[]) {
	new iLen = strlen(szPrefix);
	for (new i = 0; i < iLen; i++) {
		if (szStr[i] != szPrefix[i])
			return false;
	}
	return true;
}

public plugin_init() {
	register_plugin("Force Download", "1.0", "AI");
	
	// 管理员重新加载命令
	register_concmd("forcedl_reload", "cmdReload", ADMIN_CFG, "重新加载下载列表");
	
	get_mapname(g_szMapName, charsmax(g_szMapName));
}

public cmdReload(id) {
	// precache 只能在 plugin_precache 里调用
	// 所以这里只能提示玩家重启地图
	client_print_color(id, print_team_blue, "[ForceDL] 下载列表在地图加载时生效，请换图或重启地图");
	console_print(id, "[ForceDL] 运行 maps * 0; changelevel %s 来重新加载", g_szMapName);
	return PLUGIN_HANDLED;
}
