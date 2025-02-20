#define PLUGIN_NAME           "l4d2_weaponammo"
#define PLUGIN_AUTHOR         "mYui"
#define PLUGIN_DESCRIPTION    "change clip after fire"
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            "NA"
#define MaxClients 32

#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>
#include <smlib>

#pragma newdecls required
#pragma semicolon 1

int throwing[MaxClients+1];
char bannedClient[MaxClients+1][MAX_STEAMAUTH_LENGTH];
bool enabled;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};


public void OnPluginStart()
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

public Action EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	enabled = false;
	for (int i = 0; i < MaxClients + 1; i++)
	{
		bannedClient[i] = "";
		throwing[i] = false;
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	char weapon[64];
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (!IsEnabled(client))
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
	
	int slot = -1;
	int clipSize;
	throwing[client] = 0;
	if (StrEqual(weapon, "pipe_bomb") || StrEqual(weapon, "vomitjar") || StrEqual(weapon, "molotov"))
	{
		throwing[client] = 1;
	}
	else if (StrEqual(weapon, "grenade_launcher"))
	{
		slot = 0;
		clipSize = 2;
	}
	else if (StrEqual(weapon, "pumpshotgun") || StrEqual(weapon, "shotgun_chrome"))
	{
		slot = 0;
		clipSize = 8;
	}
	else if (StrEqual(weapon, "autoshotgun") || StrEqual(weapon, "shotgun_spas"))
	{
		slot = 0;
		clipSize = 10;
	}
	else if (StrEqual(weapon, "hunting_rifle"))
	{
		slot = 0;
		clipSize = 15;
	}
	else if(StrEqual(weapon, "sniper_scout"))
	{
		slot = 0;
		clipSize = 2;
	}
	else if (StrEqual(weapon, "sniper_awp"))
	{
		slot = 0;
		clipSize = 3;
	}
	else if (StrEqual(weapon, "sniper_military"))
	{
		slot = 0;
		clipSize = 30;
	}
	else if (StrEqual(weapon, "rifle_ak47"))
	{
		slot = 0;
		clipSize = 40;
	}
	else if (StrEqual(weapon, "smg") || StrEqual(weapon, "smg_silenced") || StrEqual(weapon, "rifle"))
	{
		slot = 0;
		clipSize = 50;
	}
	else if (StrEqual(weapon, "rifle_sg552") || StrEqual(weapon, "smg_mp5"))
	{
		slot = 0;
		clipSize = 80;
	}
	else if (StrEqual(weapon, "rifle_desert"))
	{
			slot = 0;
			clipSize = 60;
	}
	else if (StrEqual(weapon, "rifle_m60"))
	{
		slot = 0;
		clipSize = 150;
	}
	else if (StrEqual(weapon, "pistol"))
	{
		slot = 1;
		if (GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_isDualWielding") > 0)
			clipSize = 30;
		else
			clipSize = 15;
	}
	else if (StrEqual(weapon, "chainsaw"))
	{
		slot = 1;
		clipSize = 30;
	}
	else if (StrEqual(weapon, "pistol_magnum"))
	{
		slot = 1;
		clipSize = 8;
	}
	
	if (slot >= 0)
	{
		int weaponent = GetPlayerWeaponSlot(client, slot);
		if (weaponent > 0 && IsValidEntity(weaponent))
		{
			SetEntProp(weaponent, Prop_Send, "m_iClip1", clipSize+1);
			if (slot == 0)
			{
				int upgradedammo = GetEntProp(weaponent, Prop_Send, "m_upgradeBitVec");
				if (upgradedammo == 1 || upgradedammo == 2 || upgradedammo == 5 || upgradedammo == 6)
					SetEntProp(weaponent, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", clipSize+1);
			}
		}
	}
	return Plugin_Handled;
}

public Action Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	char weapon[64];
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "item", weapon, sizeof(weapon));

	if (client > 0 && IsEnabled(client))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
		    int needChange = 0;
		    if (throwing[client] == 1)
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
				throwing[client] = 0;
			}
		    if (needChange == 1)
			{
				int weaponEnt = GetPlayerWeaponSlot(client, 2);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weaponEnt);
			}
		}
	}
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerMedkit, client);
		}
	}
}


public Action TimerMedkit(Handle timer, any client)
{
	CheatCommand(client, "give", "first_aid_kit");
}

public Action Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerDefib, client);
		}
	}
}

public Action TimerDefib(Handle timer, any client)
{
	CheatCommand(client, "give", "defibrillator");
}

public Action Event_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerPills, client);
		}
	}
}

public Action TimerPills(Handle timer, any client)
{
	CheatCommand(client, "give", "pain_pills");
}

public Action Event_AdrenalineUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0 && IsEnabled(client))
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			CreateTimer(0.1, TimerShot, client);
		}
	}
}

public Action TimerShot(Handle timer, any client)
{
	CheatCommand(client, "give", "adrenaline");
}

bool IsEnabled(int client)
{
	return enabled && !IsAuthorizedSurvivor(client);
}

bool IsAuthorizedSurvivor(int client)
{
	if (!IsValidSurvivor(client, false))
	{
		return false;
	}
	char buffer[32];
	GetClientAuthId(client, AuthId_Steam2, buffer, 32, true);
	for (int i = 0; i < MaxClients + 1; i++)
	{
		if (strcmp(bannedClient[i], buffer, true) == 0)
		{
			return false;
		}
	}
	return true;
}

bool IsValidSurvivor(int client, bool allowbots)
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

stock void CheatCommand(int client, const char[] command, const char[] arguments)
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments );
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}