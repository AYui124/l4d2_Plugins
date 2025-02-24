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
#define PLUGIN_VERSION "0.6.1"

public Plugin myinfo = 
{
	name = "l4d2_missioncmd",
	author = PLUGIN_AUTHOR,
	description = "mission map code",
	version = PLUGIN_VERSION,
	url = "N/A",
};

public void OnPluginStart()
{
	CreateConVar("l4d2_missioncmd_version", PLUGIN_VERSION, "l4d2_missioncmd plugin version.");
	RegConsoleCmd("sm_lm", Command_ShowMap, "Show Maps");
}

public Action Command_ShowMap(int client, int args)
{
	ArrayList missionList = new ArrayList(PLATFORM_MAX_PATH, 0);
	LM_GetMissions(missionList);
	if (missionList.Length < 1)
	{
		LogMessage("无法获取地图数据或没有三方图");
		if (client > 0 && client < MaxClients)
		{
			PrintToChat(client, "无法获取地图数据或没有三方图");
			return Plugin_Handled;
		}
	}
	Menu menu = CreateMenu(MapMenuHandler);
	for (int i = 0; i < missionList.Length; i++)
	{
		char mission[PLATFORM_MAX_PATH];
		missionList.GetString(i, mission, sizeof(mission));
		LogMessage("%d: %s", i+1, mission);
		char display[PLATFORM_MAX_PATH];
		FormatEx(display, PLATFORM_MAX_PATH, "%s", mission);
		ReplaceString(display, sizeof(display), ".vpk", "");
		AddMenuItem(menu, mission, display);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MapMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select) 
	{
		char info[PLATFORM_MAX_PATH];
		char display[PLATFORM_MAX_PATH];
		menu.GetItem(itemNum, info, sizeof(info), _, display, sizeof(display));
		
		LogMessage("%N 选择: [%d] 项 info:[%s],display:[%s]", client, itemNum, info, display);

		ArrayList missionCodes = new ArrayList(PLATFORM_MAX_PATH, 0);
		char buffer[2048];
		if (LM_GetMissionCoopMapCodes(info, missionCodes) == 0)
		{
			if (client > 0 && client < MaxClients)
			{
				for (int i = 0; i < missionCodes.Length; i++)
				{
					char missionCode[PLATFORM_MAX_PATH];
					missionCodes.GetString(i, missionCode, sizeof(missionCode));
					Format(buffer, sizeof(buffer), "%s\n第%i章节: %s", buffer, i+1, missionCode);
				}
				PrintToChat(client, "%s 地图代码: %s", display, buffer);
			}
		} 
		else
		{
			if (client > 0 && client < MaxClients)
			{
				PrintToChat(client, "无法获取地图代码");
			}
		}
	}
	return 0;
}
