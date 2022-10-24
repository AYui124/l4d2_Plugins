
#define DEBUG false

#define PLUGIN_NAME           "l4d2_happyFestival"
#define PLUGIN_AUTHOR         "mYui"
#define PLUGIN_DESCRIPTION    "Gives Infinite Ammo when festival"
#define PLUGIN_VERSION        "1.3"
#define PLUGIN_URL            "NA"

#define MaxClients 32

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1

new Throwing[MaxClients+1];
new Inited;
new bool:IsFestival;
new IsWeekend;
new Rate;

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
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("weapon_drop", Event_WeaponDrop);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_start", EventRoundStart);
}

public OnMapStart()
{
	Inited = 0;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (Inited == 0)
	{
		InitData(client);
		if (IsFestival)
		{
			PrintToChatAll("\x04开呱!!开呱!!");
		} 
		else if (IsWeekend == 1)
		{
			PrintToChatAll("\x04%N\x03Roll点:\x04%d\x03 ,开呱!", client, Rate);
		}
		else if (IsWeekend == -1)
		{
			PrintToChatAll("\x04%N\x03Roll点:\x04%d\x03 ,我的呱呢!", client, Rate);
		}
		else
		{
			PrintToChatAll("\x05银趴结束了!");
		}
		CreateTimer(60.0, ReSet, _, TIMER_FLAG_NO_MAPCHANGE);
		Inited = 1;
		
		
	}
}

public Action:ReSet(Handle:timer)
{
	Inited = 0;
}

public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	IsFestival = false;
	IsWeekend = 0;
}

public Action:Event_PlayerDisconnect(Handle:event, String:event_name[], bool:dontBroadcast)
{
}

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:weapon[64];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (!IsEnabled())
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
	new String:weapon[64];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "item", weapon, sizeof(weapon));

	if (client > 0 && IsEnabled())
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
		    int needChange = 0;
		    if (Throwing[client] == 1)
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
	BuildPath(Path_SM, filePath, sizeof(filePath), "data/festival.txt");
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
	new multiRate = GetRandomInt(100, 2000);
	Rate = GetRandomInt(0, multiRate * client) % 100 + 1;
	LogMessage("rate=%d",Rate);
	
	if(StrEqual(week,"Saturday") || StrEqual(week,"Sunday") || StrEqual(week,"Friday") && IsAtNight(hour, minute))
	{
		LogMessage("weekend=true");
		
		if (Rate > 50)
		{
			IsWeekend = 1;
		}
		else
		{
			IsWeekend = -1;
		}
	}
	
}

bool:IsAtNight(char[] hour, char[] minute)
{
	new h = StringToInt(hour);
	new m = StringToInt(minute);
	return h * 60 + m > 18 * 60;
}

bool:IsEnabled()
{
	return IsFestival || IsWeekend == 1;
}

public Action:Event_HealSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled())
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

	if (client > 0 && IsEnabled())
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

	if (client > 0 && IsEnabled())
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

	if (client > 0 && IsEnabled())
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
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}