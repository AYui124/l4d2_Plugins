/*--- beta version ---*/
#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.6.1"

#include <sourcemod>

#define MISSIONS_PATH_All "addons/sourcemod/data/missions_info"
#define MISSIONS_PATH_Official "addons/sourcemod/data/missions_info_Official"
// IsLastMap
new count;
new bool:isProcessing;
new bool:siginal;
new bool:notfound;
// RandomNextMap
new current;
new String:nextMap[256];
new String:nextName[256];
// Triggle change
new bool:hasCalled;
// No finale_win fix
new bool:needListen;
// Mission
new b_OnlyOfficial;
new String:Missions_Path[100];
new Handle:h_OnlyOfficial;
new bool:b_HasChanged;

public Plugin:myinfo = 
{
	name = "[l4d2] random change map",
	author = PLUGIN_AUTHOR,
	description = "N/A",
	version = PLUGIN_VERSION,
	url = "steamcommunity.com/id/m_Yui"
};

public OnPluginStart()
{
	decl String:gameName[64];
	GetGameFolderName(gameName, sizeof(gameName));
	if(!StrEqual(gameName, "left4dead2", false)) 
	{ 
		SetFailState("Use this in Left 4 Dead 2 only.");
	}
	CheckGamemode();
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	AddCommandListener(Listener_Skip, "skipouttro");
	RegConsoleCmd("sm_acm", Cmd_ChangeCustomMapState);
	h_OnlyOfficial = CreateConVar("rcm_OnlyOfficial", "1");
	b_OnlyOfficial = GetConVarInt(h_OnlyOfficial);
	Format(Missions_Path, 100, "%s", MISSIONS_PATH_Official);
}

CheckGamemode()
{
	decl String:gameMode[16];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if (StrEqual(gameMode, "versus", false) || StrEqual(gameMode, "teamversus", false) || StrEqual(gameMode, "scavenge", false) || StrEqual(gameMode, "teamscavenge", false))
	{
		SetFailState("Use this in non-vs mode");
	}
}

public Action:Cmd_ChangeCustomMapState(client, args)
{
	if(b_HasChanged==false)
	{
		if(b_OnlyOfficial==0)
		{
			Format(Missions_Path, 100, "%s", MISSIONS_PATH_Official);
			PrintToChatAll("\x03切换为仅官图模式!");
			b_OnlyOfficial = 1;
			SetConVarInt(h_OnlyOfficial, 1);
		}
		else
		{
			Format(Missions_Path, 100, "%s", MISSIONS_PATH_All);
			PrintToChatAll("\x03切换为所有地图模式!");
			b_OnlyOfficial = 0;
			SetConVarInt(h_OnlyOfficial, 0);
		}
	}
	else
	{
		if(client>0)
		{
			PrintToChat(client, "\x05当前回合已切换过循环模式!");
		}
	}
}

public OnMapStart()
{
	decl String:currentMap[256]; //current map being played
	GetCurrentMap(currentMap, sizeof(currentMap));
	if(StrEqual(currentMap,"credits") )
		CreateTimer(2.0, StartChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:StartChangeMap(Handle:timer)
{
	count = 0;
	current = 0;
	GetCount();
	RandomNextMap();
	CreateTimer(5.0, ChangeMap);
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	b_HasChanged = false;
	isProcessing = false;
	siginal = false;
	nextMap = "";
	nextName = "";
	count = 0;
	current = 0;
	notfound = false;
	hasCalled = false;
	GetCount();
	needListen = true;
	CreateTimer(15.0, TimerPre, _, TIMER_FLAG_NO_MAPCHANGE);
}

GetCount()
{
	new Handle:missionsDir = INVALID_HANDLE;
	missionsDir = OpenDirectory(Missions_Path);
	if (missionsDir == INVALID_HANDLE)
	{
		SetFailState("Cannot open missionsinfo directory");
	}
	decl String:buffer[256];
	while (ReadDirEntry(missionsDir, buffer, sizeof(buffer)))
	{
		if (DirExists(buffer))
		{
			continue;
		}
		count += 1;
	}
	CloseHandle(missionsDir);
}

public Action:TimerPre(Handle:timer)
{
	if (LeftStartArea())
	{
		CreateTimer(1.0, PreMapInfo);
	}
	else
	{
		CreateTimer(2.0, TimerPre, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool:LeftStartArea()
{
	new maxents = GetMaxEntities();	
	for (new i = MaxClients + 1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];	
			GetEntityNetClass(i, netclass, sizeof(netclass));	
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				if (GetEntProp(i, Prop_Send, "m_hasAnySurvivorLeftSafeArea"))
				{
					return true;
				}
			}
		}
	}
	return false;
}

public Action:PreMapInfo(Handle:timer)
{
	IsLastMap();
	CreateTimer(2.0, GetMapInfo);
}

public Action:GetMapInfo(Handle:timer)
{
	if (isProcessing)
	{
		CreateTimer(0.5, GetMapInfo);		// Make sure the checking process has finished
	}
	else
	{
		if (siginal)
		{
			CreateTimer(2.0, TimerRandom);
			PrintToChatAll("\x03地图终章:下一张地图随机选择中...");
		}
		else
		{
			if (notfound)
			{
				Format(nextMap, sizeof(nextMap), "c5m1_waterfront");
				Format(nextName, sizeof(nextName), "教区");
				PrintToChatAll("\x03配置丢失");
			}
			else
			{
				Format(nextMap, sizeof(nextMap), "c5m1_waterfront");
				Format(nextName, sizeof(nextName), "教区");
				PrintToChatAll("\x03战役进行中");
			}
		}
	}
	return Plugin_Continue;
}
/*--- core code from: [github/HardCoop] mapskipper.sp  ---*/
IsLastMap()
{
	isProcessing = true;
	new Handle:missionsDir = INVALID_HANDLE;
	missionsDir = OpenDirectory(Missions_Path);
	if (missionsDir == INVALID_HANDLE)
	{
		SetFailState("Cannot open missionsinfo directory");
	}
	decl String:currentMap[256]; //current map being played
	GetCurrentMap(currentMap, sizeof(currentMap));
	decl String:buffer[256];
	decl String:fullPath[256];
	new it = 0;
	while (ReadDirEntry(missionsDir, buffer, sizeof(buffer)))
	{
		if (DirExists(buffer))
		{
			continue;
		}
		it += 1;
		Format(fullPath, sizeof(fullPath), "%s/%s", Missions_Path, buffer);
		new Handle:missions = CreateKeyValues("mission");
		FileToKeyValues(missions, fullPath);
		KvJumpToKey(missions, "modes", false);
		if (KvJumpToKey(missions, "coop", false))
		{
			KvGotoFirstSubKey(missions); // first map for each txt
			do
			{
				decl String:mapName[256];
				KvGetString(missions, "map", mapName, sizeof(mapName));
				if (StrEqual(mapName, currentMap, false))
				{
					current = it;
					if (KvGotoNextKey(missions))
					{
						// LogMessage("Not Finale:%s", currentMap);
						// Close handles
						CloseHandle(missions);
						CloseHandle(missionsDir);
						siginal = false;
						isProcessing = false;
						return;
					} 
					else
					{
						// LogMessage("Finale Map");
						// Close handles
						CloseHandle(missions);
						CloseHandle(missionsDir);
						siginal = true;
						isProcessing = false;
						return;
					}
				}
			}
			while (KvGotoNextKey(missions));
		} 
		else
		{
			LogMessage("Could not find a coop section in missions file: %s", fullPath);
		}
		CloseHandle(missions);
	}
	LogMessage("The map could not be found. No valid missions file?");
	CloseHandle(missionsDir);
	notfound = true;
	siginal = false;
	isProcessing = false;
	return;
}

public Action:TimerRandom(Handle:timer)
{
	RandomNextMap();
}

RandomNextMap()
{
	new Handle:missionsDir = INVALID_HANDLE;
	missionsDir = OpenDirectory(Missions_Path);
	if (missionsDir == INVALID_HANDLE)
	{
		SetFailState("Cannot open missionsinfo directory");
	}

	decl String:buffer[256];
	decl String:fullPath[256];
	new rand = GetRandomNum();
	new i = 0;
	while (ReadDirEntry(missionsDir, buffer, sizeof(buffer)))
	{
		if (DirExists(buffer))
		{
			continue;
		}
		i += 1;
		if (i == rand)
		{
			break;
		}
	}
	strcopy(nextName, 256, buffer);
	ReplaceString(nextName, sizeof(nextName), ".txt", "", false);
	Format(fullPath, sizeof(fullPath), "%s/%s", Missions_Path, buffer);
	new Handle:missions = CreateKeyValues("mission");
	FileToKeyValues(missions, fullPath);
	KvJumpToKey(missions, "modes", false);
	if (KvJumpToKey(missions, "coop", false))
	{
		KvGotoFirstSubKey(missions);
		KvGetString(missions, "map", nextMap, sizeof(nextMap));
	}
	CloseHandle(missions);
	CloseHandle(missionsDir);
	CreateTimer(1.0, ShowMessage);
}

public Action:ShowMessage(Handle:timer)
{
	PrintToChatAll("\x03地图预告:\x04%s", nextName);
	PrintToChatAll("\x03当前地图循环模式:\x04%s", b_OnlyOfficial ? "官图":"所有");
	PrintToChatAll("\x03输入\x04!acm\x03切换");
}

GetRandomNum()
{
	new index = GetRandomInt(1, count);
	//LogMessage("random=%i--current=%i--total=%i", index, current, count);
	if (index == current)
	{
		if ((current * 2) < count)
		{
			return GetRandomInt(current + 1, count);
		}
		else
		{
			return GetRandomInt(1, current - 1);
		}
	}
	else
	{
		return index;
	}
}

public Action:Event_FinaleVehicleLeaving(Handle:event, String:event_name[], bool:dontBroadcast)
{
	needListen = false;
	decl String:currentMap[256]; 
	GetCurrentMap(currentMap, sizeof(currentMap));
	LogMessage("--Event_FinaleVehicleLeaving has been called.--Map: %s", currentMap);
	CreateTimer(10.0, ChangeMapReady);
}

public Action:Event_FinaleWin(Handle:event, String:event_name[], bool:dontBroadcast)
{
	needListen = false;
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
	PrintToChatAll("\x03 5秒后换图:\x04%s", nextName);
	CreateTimer(5.0, ChangeMap);
	return Plugin_Continue;
}

public Action:ChangeMap(Handle:timer)
{
	ServerCommand("changelevel %s", nextMap);
}

public Action:Listener_Skip(client, const String:command[], argc)
{
	if (needListen)
	{
		decl String:currentMap[256]; 
		GetCurrentMap(currentMap, sizeof(currentMap));
		LogMessage("--CommandListener 'skipouttro' has been called.--Map: %s", currentMap);
		needListen = false;
		new Handle:event = CreateEvent("finale_win", true);
		FireEvent(event, false);
	}
}
