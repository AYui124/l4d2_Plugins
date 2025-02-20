#pragma semicolon 1

#include <sourcemod>
#include <l4d2_mission>

#define DEBUG true

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"


public Plugin:myinfo = 
{
	name = "[l4d2] mission test",
	author = PLUGIN_AUTHOR,
	description = "test",
	version = PLUGIN_VERSION,
	url = "N/A",
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_lmt", Command_L4D2MissionTest, "l4d2_mission test");
}


public Action Command_L4D2MissionTest(int client, int args)
{
	char path[PLATFORM_MAX_PATH];
	GetCmdArg(1, path, sizeof(path));

	char missionCode[PLATFORM_MAX_PATH];
	char msg[PLATFORM_MAX_PATH];
	LM_GetMissionFirstMapCode(path, missionCode, msg);
	if (client > 0 && client < MaxClients)
	{
		PrintToChat(client, "Mission code: %s", missionCode);
	}
	LogMessage("Mission code: %s", missionCode);
	return Plugin_Handled;
}


