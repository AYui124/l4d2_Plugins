#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "1.00"
#define VOTE_NO "no"
#define VOTE_YES "yes"

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <json>

new Handle:h_OnlyOfficial;
new b_OnlyOfficial;
new Handle:h_VoteEnabled;
new b_VoteEnabled;
new String:votesMap[256];
new String:votesMapName[256];
new voteYes = 0;
new voteNo = 0;

new String:nextMap[256];
new String:nextName[256];
new bool:hasCalled;
new bool:called;

public Plugin myinfo = 
{
	name = "ChangeMap",
	author = PLUGIN_AUTHOR,
	description = "Auto Change Map on final Level（use left4dhooks）",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vote", Cmd_MapVote);
	
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_acm", Cmd_ChangeCustomMapState);
	h_OnlyOfficial = CreateConVar("rcm_OnlyOfficial", "1", "默认官图循环");
	b_OnlyOfficial = GetConVarInt(h_OnlyOfficial);
	h_VoteEnabled = CreateConVar("rcm_VoteEnabled", "1", "是否允许投票");
	b_VoteEnabled = GetConVarInt(h_VoteEnabled);

}

public Action:Cmd_MapVote(client, args)
{
	b_VoteEnabled = GetConVarInt(h_VoteEnabled);
	if(b_VoteEnabled < 1)
	{
		PrintToChat(client, "当前不可投票！");
		return Plugin_Handled;
	}
	
	if(IsVoteInProgress())
	{
		PrintToChat(client, "当前已有投票进行中！");
		return Plugin_Handled;
    }
    ShowMainMenu(client);
	return Plugin_Handled;
}

public ShowMainMenu(client)
{
	new Handle:menu = CreateMenu(MapTypeMenuHandler);
	SetMenuTitle(menu, "投票换图");
	AddMenuItem(menu, "1", "官图");
	AddMenuItem(menu, "2", "三方图");
	AddMenuItem(menu, "3", "炸服");
    SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MapTypeMenuHandler(Handle:menu, MenuAction:action, client, param)
{
	if (action != MenuAction_Select) 
	{
		return;
	}
	new String:filePath[PLATFORM_MAX_PATH];
	switch (param)
	{
		case 0: 
		{
			BuildPath(Path_SM, filePath, sizeof(filePath), "data/maplist_official.json");
			
		}
		case 1: 
		{
			BuildPath(Path_SM, filePath, sizeof(filePath), "data/maplist_third.json");
		}
		case 2: 
		{
			ShowRestartMenu(client);
			return;
		}
		default: 
		{
			return;
		}
	}
	
    new Handle:fileHandle = OpenFile(filePath, "r");
	decl String:strData[10000];
	if(fileHandle != INVALID_HANDLE)
	{
		ReadFileString(fileHandle, strData, sizeof(strData));
		CloseHandle(fileHandle);
	}
	menu = CreateMenu(MapMenuHandler);
    SetMenuTitle(menu, "投票换图");
	
	JSON_Array mapJson = view_as<JSON_Array>(json_decode(strData));
	JSON_Object countObj = mapJson.GetObject(0);
	new count = countObj.GetInt("count");
	for (new i = 1; i <= count; i++)
	{
		decl String:voteMap[256];
		decl String:voteMapName[256];
		JSON_Object contentObj = mapJson.GetObject(i);
	    contentObj.GetString("map", voteMap, sizeof(voteMap));
	    contentObj.GetString("name", voteMapName, sizeof(voteMapName));
		AddMenuItem(menu, voteMap, voteMapName);
    }
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MapMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	if (action == MenuAction_Select)
	{
		voteYes = 0;
	    voteNo = 0;
		new String:info[32] , String:name[32];
		GetMenuItem(menu, itemNum, info, sizeof(info), _, name, sizeof(name));
		votesMap = info;
		votesMapName = name;
		DisplayVoteMapsMenu(client);
	}
}

public ShowRestartMenu(client)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "上一轮投票上尚未结束");
		return;
	}
	PrintToChatAll("\x04%N\x03发起投票炸服", client);
	new Handle:menu = CreateMenu(RestartVoteHandler, MenuAction:MENU_ACTIONS_ALL);
	SetMenuTitle(menu, "炸服?");
	AddMenuItem(menu, VOTE_YES, "Yes");
	AddMenuItem(menu, VOTE_NO, "No");
	SetMenuExitButton(menu, false);
	VoteMenuToAll(menu, 20);
}

public RestartVoteHandler(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				voteYes += 1;
				PrintToChatAll("\x03%N \x05同意.", client);
			}
			case 1: 
			{
				voteNo += 1;
				PrintToChatAll("\x03%N \x04反对.", client);
			}
		}
	}
	if (action == MenuAction_End)
	{
		PrintToChatAll("\x03投票结束!");
	}
	else if (action == MenuAction_VoteCancel && client == VoteCancel_NoVotes)
	{
		PrintToChatAll("\x03无人投票或投票取消!");
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if(voteYes >= voteNo)
		{
			PrintToChatAll("\x04%d人 \x03同意\x04%d人 \x03反对,\x05投票通过!", voteYes, voteNo);
			PrintToChatAll("\x035秒后重启");
	        CreateTimer(5.0, RestartServer);
		}
		else
		{
			PrintToChatAll("\x04%d人 \x03同意\x04%d人 \x03反对,\x05投票失败!", voteYes, voteNo);
		}
	}
}

public void CrashServer()
{
    PrintToServer("L4D2 Server Restarter: Crashing the server...");
    ServerCommand("quit");
}


public DisplayVoteMapsMenu(client)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "上一轮投票上尚未结束");
		return;
	}
	PrintToChatAll("\x04%N\x03发起投票换图: \x05%s", client, votesMapName);
	new Handle:menu = CreateMenu(MapVoteHandler, MenuAction:MENU_ACTIONS_ALL);
	SetMenuTitle(menu, "投票换图:%s",votesMapName);
	AddMenuItem(menu, VOTE_YES, "Yes");
	AddMenuItem(menu, VOTE_NO, "No");
	SetMenuExitButton(menu, false);
	VoteMenuToAll(menu, 20);
}

public MapVoteHandler(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				voteYes += 1;
				PrintToChatAll("\x03%N \x05同意.", client);
			}
			case 1: 
			{
				voteNo += 1;
				PrintToChatAll("\x03%N \x04反对.", client);
			}
		}
	}
	if (action == MenuAction_End)
	{
		PrintToChatAll("\x03投票结束!");
	}
	else if (action == MenuAction_VoteCancel && client == VoteCancel_NoVotes)
	{
		PrintToChatAll("\x03无人投票或投票取消!");
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if(voteYes >= voteNo)
		{
			PrintToChatAll("\x04%d人 \x03同意\x04%d人 \x03反对,\x05投票通过!", voteYes, voteNo);
			nextMap = votesMap;
			nextName = votesMapName;
			PrintToChatAll("\x035秒后换图: \x04%s", nextName);
	        CreateTimer(5.0, ChangeMap);
		}
		else
		{
			PrintToChatAll("\x04%d人 \x03同意\x04%d人 \x03反对,\x05投票失败!", voteYes, voteNo);
		}
	}
}


public void OnMapStart()
{
	decl String:currentMap[256];
	GetCurrentMap(currentMap, sizeof(currentMap));
	if(StrEqual(currentMap,"credits"))
	{
		ReadMap();
		LogMessage("map change:%s->%s", "credits", nextMap);
		ServerCommand("changelevel %s", nextMap);
	}
}

public Action:Cmd_ChangeCustomMapState(client, args)
{
	if(b_OnlyOfficial == 0)
	{
		PrintToChatAll("\x03切换为仅官图模式!");
		b_OnlyOfficial = 1;
		SetConVarInt(h_OnlyOfficial, 1);
	}
	else
	{
		PrintToChatAll("\x03切换为三方图模式!");
		b_OnlyOfficial = 0;
		SetConVarInt(h_OnlyOfficial, 0);
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	LogMessage("LeftSafeArea:%N", client);
    if(L4D_IsMissionFinalMap())
    {
    	if(called)
		{
			return;
		}
		called = true;
    	nextMap = "";
	    nextName = "";
    	CreateTimer(1.0, RandomMap);
    }
}

public Action:RandomMap(Handle:timer)
{
	ReadMap();
	CreateTimer(1.0, ShowMessage);
}

public Action:ShowMessage(Handle:timer)
{
	PrintToChatAll("\x03地图预告:\x04%s", nextName);
	PrintToChatAll("\x03当前地图循环模式:\x04%s", b_OnlyOfficial ? "官图":"三方");
	PrintToChatAll("\x03输入\x04!acm\x03切换");
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	hasCalled = false;	
	called = false;
}

public Action:Event_FinaleVehicleLeaving(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:currentMap[256]; 
	GetCurrentMap(currentMap, sizeof(currentMap));
	LogMessage("--Event_FinaleVehicleLeaving has been called.--Map: %s", currentMap);
	CreateTimer(10.0, ChangeMapReady);
}

public Action:Event_FinaleWin(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:currentMap[256]; 
	GetCurrentMap(currentMap, sizeof(currentMap));
	LogMessage("--Event_FinaleWin has been called.--Map: %s", currentMap);
	CreateTimer(2.0, ChangeMapReady);
}

public Action:ChangeMapReady(Handle:timer)
{
	if (hasCalled)
	{
		return Plugin_Continue;
	}
	hasCalled = true;
	if (strlen(nextName) < 1)
	{
		Format(nextName, sizeof(nextName), "教区");
		Format(nextMap, sizeof(nextMap), "c5m1_waterfront");
	}
	PrintToChatAll("\x03 5秒后换图:\x04%s", nextName);
	CreateTimer(5.0, ChangeMap);
	return Plugin_Continue;
}

public Action:RestartServer(Handle:timer)
{
	CrashServer();
}

public Action:ChangeMap(Handle:timer)
{
	ServerCommand("changelevel %s", nextMap);
}

ReadMap()
{
	new String:filePath[PLATFORM_MAX_PATH];
	if(b_OnlyOfficial == 1)
	{
	    BuildPath(Path_SM, filePath, sizeof(filePath), "data/maplist_official.json");
    }
    else
    {
        BuildPath(Path_SM, filePath, sizeof(filePath), "data/maplist_third.json");
    }
	new Handle:fileHandle = OpenFile(filePath, "r");
	decl String:strData[10000];
	if(fileHandle != INVALID_HANDLE)
	{
		ReadFileString(fileHandle, strData, sizeof(strData));
		CloseHandle(fileHandle);
	}
	JSON_Array mapJson = view_as<JSON_Array>(json_decode(strData));
	
	JSON_Object countObj = mapJson.GetObject(0);
	new count = countObj.GetInt("count");
	LogMessage("map count=%i", count);
	new random = GetRandomNum(count);
	LogMessage("random=%i", random);
	JSON_Object contentObj = mapJson.GetObject(random);
	contentObj.GetString("map", nextMap, sizeof(nextMap));
	contentObj.GetString("name", nextName, sizeof(nextName));
	delete countObj;
	delete contentObj;
	delete mapJson;
	
	LogMessage("map=%s,name=%s", nextMap, nextName);
}

GetRandomNum(max)
{
	return GetRandomInt(1, max);
}
