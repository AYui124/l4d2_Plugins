
#define DEBUG false

#define PLUGIN_NAME           "l4d2_happyFestival"
#define PLUGIN_AUTHOR         "Yui"
#define PLUGIN_DESCRIPTION    "Gives Infinite Ammo when festival"
#define PLUGIN_VERSION        "1.5.0"
#define PLUGIN_URL            "NA"

#define MaxClients 32
#define MaxListCount 32

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

new Throwing[MaxClients+1];
new bool:IsFestival;
new IsWeekend;
new rate;
new Float:compareRate;
new Float:FailedCount;
new String:saveList[MaxListCount][32];
new count;
new ColdDown;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public OnPluginStart()
{
	CreateConVar("l4d2_hf_enable_generade", "0", "是否允许投掷物");
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("weapon_drop", Event_WeaponDrop);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_start", EventRoundStart);
	HookEvent("round_end", EventRoundEnd);
	RegAdminCmd("sm_hfg", Cmd_ChangeGenerade, ADMFLAG_CHEATS);
}

public OnMapStart()
{
	ColdDown = 0;
	FailedCount = 0.0;
}

public Action:Cmd_ChangeGenerade(client, args)
{
	if (IsClientInGame(client))
	{
		new Handle:cvar = FindConVar("l4d2_hf_enable_generade");
		new allow = GetConVarInt(cvar);
		if (allow == 1)
		{
			PrintToChat(client, "已关闭无限手雷");
			SetConVarInt(cvar, 0);
		}
		else
		{
			PrintToChat(client, "已开启无限手雷");
			SetConVarInt(cvar, 1);
		}
	}
}

public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	IsFestival = false;
	IsWeekend = 0;
	compareRate = 100.0;
	ReadTxt();

	CreateTimer(1.0, TimerLeftSafeRoom, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:EventRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	IsFestival = false;
	IsWeekend = 0;
	compareRate = 100.0;
}

public Action:TimerLeftSafeRoom(Handle:timer)
{
	if (LeftStartArea())
	{
		if (ColdDown == 0)
		{
			OnLeaveStartArea();
		}
		else
		{
			PrintToChatAll("\x03呱呱冷却中:\x04%d\x03s!", ColdDown);
		}
	}
	else
	{
		CreateTimer(1.0, TimerLeftSafeRoom, _, TIMER_FLAG_NO_MAPCHANGE);
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

void OnLeaveStartArea()
{
	ColdDown = 120;
	new client = GetRandomSurvivor();
	InitData(client);
	if (IsFestival)
	{
		PrintToChatAll("\x04开趴!!");
	} 
	else if (IsWeekend == 1)
	{
		PrintToChatAll("\x04%N\x03Roll点:\x04%d\x03, 有呱", client, rate);
	}
	else if (IsWeekend == -1)
	{
		PrintToChatAll("\x04%N\x03Roll点:\x04%d\x05<\x04%.2f\x03, 那我问你", client, rate, compareRate);
		if (FailedCount > 1)
		{
			PrintToChatAll("\x03Roll点失败次数\x04%d, 你脸怎么黑黑的", FailedCount);
		}
	}
	else
	{
		PrintToChatAll("\x05银趴结束了!");
	}
	CreateTimer(1.0, CountDown, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:CountDown(Handle:timer)
{
	if (ColdDown > 0)
	{
		ColdDown--;
		CreateTimer(1.0, CountDown, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		ColdDown = 0;
	}
}

public Action:Event_PlayerDisconnect(Handle:event, String:event_name[], bool:dontBroadcast)
{
}

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:weapon[64];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (!IsEnabled(client, true))
	{
		return Plugin_Handled;
	}
	if (client < 1)
	{
		return Plugin_Handled;
	}
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2)
	{
		return Plugin_Handled;
	}
	
	new slot = -1;
	new clipsize;
	Throwing[client] = 0;
	if (StrEqual(weapon, "pipe_bomb") || StrEqual(weapon, "vomitjar") || StrEqual(weapon, "molotov"))
	{
		Throwing[client] = 1;
	}
	else if (StrEqual(weapon, "grenade_launcher"))
	{
		slot = 0;
		clipsize = 2;
	}
	else if (StrEqual(weapon, "pumpshotgun") || StrEqual(weapon, "shotgun_chrome"))
	{
		slot = 0;
		clipsize = 8;
	}
	else if (StrEqual(weapon, "autoshotgun") || StrEqual(weapon, "shotgun_spas"))
	{
		slot = 0;
		clipsize = 10;
	}
	else if (StrEqual(weapon, "hunting_rifle"))
	{
		slot = 0;
		clipsize = 15;
	}
	else if(StrEqual(weapon, "sniper_scout"))
	{
		slot = 0;
		clipsize = 2;
	}
	else if (StrEqual(weapon, "sniper_awp"))
	{
		slot = 0;
		clipsize = 3;
	}
	else if (StrEqual(weapon, "sniper_military"))
	{
		slot = 0;
		clipsize = 30;
	}
	else if (StrEqual(weapon, "rifle_ak47"))
	{
		slot = 0;
		clipsize = 40;
	}
	else if (StrEqual(weapon, "smg") || StrEqual(weapon, "smg_silenced") || StrEqual(weapon, "rifle"))
	{
		slot = 0;
		clipsize = 50;
	}
	else if (StrEqual(weapon, "rifle_sg552") || StrEqual(weapon, "smg_mp5"))
	{
		slot = 0;
		clipsize = 80;
	}
	else if (StrEqual(weapon, "rifle_desert"))
	{
			slot = 0;
			clipsize = 60;
	}
	else if (StrEqual(weapon, "rifle_m60"))
	{
		slot = 0;
		clipsize = 150;
	}
	else if (StrEqual(weapon, "pistol"))
	{
		slot = 1;
		if (GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_isDualWielding") > 0)
			clipsize = 30;
		else
			clipsize = 15;
	}
	else if (StrEqual(weapon, "chainsaw"))
	{
		slot = 1;
		clipsize = 30;
	}
	else if (StrEqual(weapon, "pistol_magnum"))
	{
		slot = 1;
		clipsize = 8;
	}
	
	if (slot >= 0)
	{
		new weaponent = GetPlayerWeaponSlot(client, slot);
		if (weaponent > 0 && IsValidEntity(weaponent))
		{
			SetEntProp(weaponent, Prop_Send, "m_iClip1", clipsize+1);
			if (slot == 0)
			{
				new upgradedammo = GetEntProp(weaponent, Prop_Send, "m_upgradeBitVec");
				if (upgradedammo == 1 || upgradedammo == 2 || upgradedammo == 5 || upgradedammo == 6)
					SetEntProp(weaponent, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", clipsize+1);
			}
		}
	}
	return Plugin_Handled;
}

public Action:Event_WeaponDrop(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Handle:cvar = FindConVar("l4d2_hf_enable_generade");
	new allow = GetConVarInt(cvar);
	new String:weapon[64];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "item", weapon, sizeof(weapon));

	if (client > 0 && IsEnabled(client, true))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
		    int needChange = 0;
		    if (Throwing[client] == 1)
			{
				if (allow == 1)
				{
					if (StrEqual(weapon, "pipe_bomb"))
					{
						needChange = 1;
						CheatCommand(client, "give", "pipe_bomb");
					}
					else if (StrEqual(weapon, "vomitjar"))
					{
						needChange = 1;
						CheatCommand(client, "give", "vomitjar");
					}
					else if (StrEqual(weapon, "molotov"))
					{
						needChange = 1;
						CheatCommand(client, "give", "molotov");
					}
				}
				Throwing[client] = 0;
			}
		    if (needChange == 1)
			{
				new weaponEnt = GetPlayerWeaponSlot(client, 2);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weaponEnt);
			}
		}
	}
}

InitData(any:client)
{
	IsFestival = false;
	IsWeekend = 0;
	
	decl String:date[20];
	FormatTime(date, sizeof(date), "%m-%d");
	decl String:week[20];
	FormatTime(week, sizeof(week), "%A");
	decl String:hour[4];
	FormatTime(hour, sizeof(hour), "%H");
	decl String:minute[4];
	FormatTime(minute, sizeof(minute), "%M");
	LogMessage("date:%s,week:%s,time:%s:%s", date, week, hour, minute);
	
	new String:filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "data/festival/date.txt");
	new Handle:fileHandle = OpenFile(filePath, "r");
	decl String:strData[10000];
	if(fileHandle != INVALID_HANDLE)
	{
		ReadFileString(fileHandle, strData, sizeof(strData));
		CloseHandle(fileHandle);
	}
	
	if (StrContains(strData, date) > -1)
	{
		LogMessage("fesitival=true");
		IsFestival = true;
		return;
	}
	new multiRate = GetRandomInt(100, 1000);
	rate = GetRandomInt(0, multiRate * client) % 100 + 1;
	LogMessage("rate=%d",rate);
	if(StrEqual(week,"Saturday") 
		|| StrEqual(week,"Sunday") 
		|| StrEqual(week,"Friday") && IsAfterEvening(hour, minute) 
		|| StrEqual(week,"Monday") && IsBeforeMorning(hour, minute))
	{
		LogMessage("weekend=true");
		compareRate = FailedCount == 0 ? 50.0 : (50.0 / SquareRoot(FailedCount));
	} 
	else
	{
		new Float: add = GetRandomFloat(5.0, 25.0 - FailedCount < 10 ? FailedCount * 2 : 20.0);
		compareRate = FailedCount == 0 ? (50.0 + add) : ((50.0 + add) / SquareRoot(FailedCount)); 
	}
	
	LogMessage("compareRate=%f", compareRate);
	if (compareRate < 20.0)
	{
		compareRate = 20.0;
	}
	if (rate >= compareRate)
	{
		IsWeekend = 1;
		FailedCount = 0.0;
	}
	else
	{
		IsWeekend = -1;
		FailedCount = FailedCount + 1.0;
	}
}

bool:IsAfterEvening(char[] hour, char[] minute)
{
	new h = StringToInt(hour);
	new m = StringToInt(minute);
	return h * 60 + m > 18 * 60;
}


bool:IsBeforeMorning(char[] hour, char[] minute)
{
	new h = StringToInt(hour);
	new m = StringToInt(minute);
	return h * 60 + m < 3 * 60;
}

bool:IsEnabled(int client, bool:isWeapon)
{
	return (IsFestival || IsWeekend == 1) && (!isWeapon || IsAuthorizedSurvivor(client));
}

bool:IsAuthorizedSurvivor(int client)
{
	if (!IsValidSurvivor(client, false))
	{
		return false;
	}
	decl String:buffer[32];
	GetClientAuthId(client, AuthId_Steam2, buffer, 32, true);
	new i = 0;
	while (i < count)
	{
		if (strcmp(saveList[i], buffer, true) == 0)
		{
			return false;
		}
		i++;
	}
	return true;
}

bool:IsValidSurvivor(client, bool:allowbots)
{
	if ((client < 1) || (client > MaxClients))
	{
		return false;
	}
	if (!IsClientInGame(client) || !IsClientConnected(client))
	{
		return false;
	}
	if (GetClientTeam(client) != 2)
	{
		return false;
	}
	if (IsFakeClient(client) && !allowbots)
	{
		return false;
	}
	return true;
}

ReadTxt()
{
	new Handle:file = INVALID_HANDLE;
	new String:filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "data/festival/banned.txt");
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		file = INVALID_HANDLE;
	}
	file = OpenFile(filePath, "r");
	if (!file)
	{
		LogError("Error opening file via file '%s'.", filePath);
		return -1;
	}

	decl String:buffer[32];
	count = 0;
	while (!IsEndOfFile(file))
	{
		ReadFileLine(file, buffer, 32);
		if(strlen(buffer)>10)
		{
			if (Array_FindString(saveList, MaxListCount, buffer, false, 0) < 0)
			{
				LogMessage("Id: %s", buffer);
				Format(saveList[count], 32, buffer);
				count++;
			}
		}
	}
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		file = INVALID_HANDLE;
	}
	
	return 0;
}

public Action:Event_HealSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client, false))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerMedkit, client);
		}
	}
}

public Action:TimerMedkit(Handle:timer, any:client)
{
	CheatCommand(client, "give", "first_aid_kit");
}

public Action:Event_DefibrillatorUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client, false))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerDefib, client);
		}
	}
}

public Action:TimerDefib(Handle:timer, any:client)
{
	CheatCommand(client, "give", "defibrillator");
}

public Action:Event_PillsUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client, false))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerPills, client);
		}
	}
}

public Action:TimerPills(Handle:timer, any:client)
{
	CheatCommand(client, "give", "pain_pills");
}

public Action:Event_AdrenalineUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client, false))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerShot, client);
		}
	}
}

public Action:TimerShot(Handle:timer, any:client)
{
	CheatCommand(client, "give", "adrenaline");
}

stock CheatCommand(client, const String:command[], const String:arguments[])
{
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments );
	SetCommandFlags(command, flags);
}

stock Array_FindString(const String:array[][], size, const String:str[], bool:caseSensitive=true, start=0)
{
	if (start < 0) {
		start = 0;
	}

	for (new i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) {
			return i;
		}
	}

	return -1;
}

stock GetRandomSurvivor()
{
	new survivors[MAXPLAYERS];
	new numSurvivors = 0;
	new last = 0;
	for (new i = 0; i < MAXPLAYERS; i++) 
	{
		if (i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
		    survivors[numSurvivors] = i;
		    last = i;
		    numSurvivors++;
		}
	}
	new client = survivors[GetRandomInt(0, numSurvivors - 1)];
	return IsClientInGame(client) && GetClientTeam(client) ? client : last;
}
