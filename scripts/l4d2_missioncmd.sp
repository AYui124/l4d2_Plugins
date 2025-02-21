#pragma semicolon 1

#include <sourcemod>
#include <l4d2_mission>

#define DEBUG true

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.3"


public Plugin:myinfo = 
{
	name = "[l4d2] mission command",
	author = PLUGIN_AUTHOR,
	description = "mission map code",
	version = PLUGIN_VERSION,
	url = "N/A",
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_lm", Command_ShowMap, "输入vpk名获取地图代码 (eg: sm_lm 地图-伦理问题)");
}


public Action Command_ShowMap(int client, int args)
{
	char path[PLATFORM_MAX_PATH];
	GetCmdArg(1, path, sizeof(path));

	char missionCode[PLATFORM_MAX_PATH];
	char msg[PLATFORM_MAX_PATH];
	if (LM_GetMissionFirstMapCode(path, missionCode, msg) > 0)
	{
		if (client > 0 && client < MaxClients)
		{
			PrintToChat(client, "首章地图代码: %s", missionCode);
		}
		LogMessage("Mission code: %s", missionCode);
	} 
	else
	{
		if (client > 0 && client < MaxClients)
		{
			PrintToChat(client, "无法获取地图代码: %s", msg);
		}
		LogMessage("Failed To get mission code: %s", msg);
	}
	
	return Plugin_Handled;
}


