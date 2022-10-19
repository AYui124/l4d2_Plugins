#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>

new Float:g_fTimeLOS[100000];

enum L4D2_Team {
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum L4D2_Infected {
    L4D2Infected_Smoker = 1,
    L4D2Infected_Boomer,
    L4D2Infected_Hunter,
    L4D2Infected_Spitter,
    L4D2Infected_Jockey,
    L4D2Infected_Charger,
    L4D2Infected_Witch,
    L4D2Infected_Tank
};

public Plugin:myinfo = 
{
	name = "[l4d2] SI Slayer",
	author = PLUGIN_AUTHOR,
	description = "Kill Si if lost target",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	if (IsBotInfected(client) && !IsTank(client) && userid >= 0)
	{
		g_fTimeLOS[userid] = 0.0;
		// Checking LOS
		CreateTimer(0.5, Timer_StarvationLOS, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_StarvationLOS( Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	// increment tracked LOS time
	if (IsBotInfected(client) && IsPlayerAlive(client))
	{
		if (g_fTimeLOS[userid] > 15.0)
		{
			if(IsAttacking(client))
			{
				g_fTimeLOS[userid] = 0.0;
			}
			else
			{
				ForcePlayerSuicide(client);
			}
			return Plugin_Stop;
		}
		if (bool:GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
		{
			g_fTimeLOS[userid] = 0.0;
		}
		else
		{
			g_fTimeLOS[userid] += 0.5; 
		}
	}
	else 
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

L4D2_Infected:GetInfectedClass(client)
{
	return L4D2_Infected:GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool:IsInfected(client)
{
	if (!IsClientInGame(client) || L4D2_Team:GetClientTeam(client) != L4D2Team_Infected)
	{
		return false;
	}
	return true;
}

bool:IsBotInfected(client)
{
	// Check the input is valid
	if (!IsValidClient(client))
	{
		return false;
	}
	// Check if player is a bot on the infected team
	if (IsInfected(client) && IsFakeClient(client))
	{
		return true;
	}
	return false; // otherwise
}

bool:IsTank(client)
{
	return IsClientInGame(client)	
	&& L4D2_Team:GetClientTeam(client) == L4D2Team_Infected 
	&& GetInfectedClass(client) == L4D2Infected_Tank;
}

bool:IsValidClient(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}    
}

bool:IsAttacking(client)
{
	return GetEntProp(client, Prop_Send, "m_iGlowType") == 3 || 
		GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart") > GetGameTime() || 
		GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0;
}
