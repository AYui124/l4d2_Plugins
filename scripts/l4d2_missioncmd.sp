/*
*	l4d2_missioncmd
*	Copyright (C) 2025 Yui
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_mission>

#define DEBUG true

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.4"


public Plugin myinfo = 
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
	for(int i = 1; i <= args; i++)
	{
		char arg[PLATFORM_MAX_PATH];
		GetCmdArg(i, arg, sizeof(arg));
		if (i == 1)
		{
			FormatEx(path, sizeof(path), "%s", arg);
		}
		else
		{
			FormatEx(path, sizeof(path), "%s %s", path, arg);
		}
	}

	char missionCode[PLATFORM_MAX_PATH];
	char msg[PLATFORM_MAX_PATH];
	if (LM_GetMissionFirstMapCode(path, missionCode, msg) == 0)
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


