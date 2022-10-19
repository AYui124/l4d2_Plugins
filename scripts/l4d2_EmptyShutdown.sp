
#define DEBUG

#define PLUGIN_NAME           "l4d2_EmptyShutdown"
#define PLUGIN_AUTHOR         "Yui"
#define PLUGIN_DESCRIPTION    ""
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

new Handle:handleWaitTime;
new bool:playerConnected;
new timeCount;

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
	handleWaitTime = CreateConVar("l4d_es_time", "300", "玩家离线后等待关闭时间");
}

public OnMapStart()
{
	playerConnected = false;
	timeCount = 0;
	CreateTimer(5.0, StopCheck, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientConnected(client)
{
	if (!IsFakeClient(client) && !playerConnected)
	{
		CreateTimer(2.0, ClientConnected, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}


public Action:ClientConnected(Handle:timer, any:client)
{
	if(IsValidSurvivor(client, false))
	{
		LogMessage("Player connected:%N", client);
	    playerConnected = true;
	}
}

public Action:StopCheck(Handle:timer)
{
	if(playerConnected)
	{
		if (GetSurvivorCount(false) < 1)
		{
			timeCount++;
		}
		else
		{
			timeCount = 0;
		}
		new maxCount = GetConVarInt(handleWaitTime) / 5;
		if(timeCount > maxCount)
		{
			timeCount = 0;
			LogMessage("Stop Server:No player");
			ServerCommand("quit");
		}
	}
}

GetSurvivorCount(bool:allowBots)
{	
	new count=0;
	for (new i=1; i<=MaxClients; i++)
	{	
		if (IsValidSurvivor(i, allowBots) && IsPlayerAlive(i))
		{
			count++;
		}
	}
	return count;
}

bool:IsValidSurvivor(client, bool:allowbots)
{
	if ((client < 1) || (client > MaxClients)) { return false; }
	if (!IsClientInGame(client) || !IsClientConnected(client)) { return false; }
	if (GetClientTeam(client) != 2) { return false; }
	if (IsFakeClient(client) && !allowbots) { return false; }
	return true;
}
