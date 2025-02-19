#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma newdecls required
#pragma semicolon 1

#define GAMEDATA_FILENAME "l4d2_revolt"

GameData gameData = null;
Handle takeOverInfected = null;
Handle takeOverBot = null;
Handle setHumanSpec = null;
Handle stateTransition = null;

//int propGhost;

public Plugin myinfo =
{
	name = "l4d2_revolt",
	author = "mYui",
	description = "revolt",
	version = "1.0.0",
	url = "https://github.com/ayui124"
};


public void OnPluginStart()
{
	InitSdkCall();
	HookEvents();
	RegisterCmds();
}

void InitSdkCall()
{
	gameData = LoadGameConfigFile(GAMEDATA_FILENAME);
	if (gameData == null) 
	{
		SetFailState("GameData Not Found:%s", GAMEDATA_FILENAME);
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	setHumanSpec = EndPrepSDKCall();
	if (setHumanSpec == null)
	{
		SetFailState("Cant initialize SetHumanSpec SDKCall");
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "State_Transition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
	stateTransition = EndPrepSDKCall();
	if (stateTransition == null)
	{
		SetFailState("Cant initialize State_Transition SDKCall");
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "TakeOverZombieBot");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	takeOverInfected = EndPrepSDKCall();
	if (takeOverInfected == null)
	{
		SetFailState("Cant initialize TakeOverZombieBot SDKCall");
		return;
    }
    
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	takeOverBot = EndPrepSDKCall();
	if (takeOverBot == null)
	{
		SetFailState("Cant initialize TakeOverBot SDKCall");
		return;
	}
	//
}

void HookEvents()
{
	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
	HookEvent("map_transition", MapTransition, EventHookMode_PostNoCopy);
}

void RegisterCmds()
{
	RegConsoleCmd("sm_js", CmdJoinInfected);
	RegConsoleCmd("sm_jg", CmdJoinSurvivor);
}

public Action CmdJoinSurvivor(int client, int args)
{
    if (!IsValidClient(client, false) && GetClientTeam(client) == 2)
	{
        return;
	}
    SwitchToSpec(client);
    CreateTimer(0.5, JoinSurvivor, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CmdJoinInfected(int client, int args)
{
	if (!IsValidClient(client, false) && GetClientTeam(client) == 3)
	{
        return;
	}
	SwitchToSpec(client);
	CreateTimer(0.5, JoinInfected, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action JoinInfected(Handle timer, int client)
{
	if (!IsValidClient(client, false) && GetClientTeam(client) != 1)
	{
        return;
	}
	int target = FindBot(3);
	if (target > 0)
	{
		Handle gameMode = FindConVar("mp_gamemode");
		SendConVarValue(client, gameMode, "versus");

		SDKCall(takeOverInfected, client, target);
		SDKCall(stateTransition, client, 8);
	}
	else
	{
		CreateTimer(0.5, JoinInfected, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action JoinSurvivor(Handle timer, int client)
{
	int target = FindBot(2);
	if (target > 0)
	{
		Handle gameMode = FindConVar("mp_gamemode");
		SendConVarValue(client, gameMode, "coop");
		
		SDKCall(setHumanSpec, target, client);
		SDKCall(takeOverBot, client, true);
	}
}

public void OnMapStart()
{
	
}

public void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetToSurvivor();
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	//LogMessage("Round End");
	ResetToSurvivor();
}

void MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	ResetToSurvivor();
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client, false) && GetClientTeam(client) != 2)
	{
		SwitchToSpec(client);
		CreateTimer(0.5, JoinSurvivor, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsValidClient(client, false)
		&& GetClientTeam(client) == 3)
	{
		SwitchToSpec(client);
		CreateTimer(0.5, JoinInfected, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void SwitchToSpec(int client)
{
	AcceptEntityInput(client, "clearparent");
	ChangeClientTeam(client, 1);

	int target = FindSpecBot(client);
	if (HasEntProp(target, Prop_Send, "m_humanSpectatorUserID"))
	{
		SetEntProp(target, Prop_Send, "m_humanSpectatorUserID", 0);
	}
}

int FindBot(int team)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i, true) && IsFakeClient(i) && GetClientTeam(i) == team && !IsClientInKickQueue(i))
		{
			return i;
			// if (team == 3)
			// {
			// 	if (IsGhost(i))
			// 	{
			// 		return i;
			// 	}
			// }
			// else if (team == 2)
			// {
			// 	return i;
			// }
		}
	}
	return 0;
}

int FindSpecBot(int client)
{
	int userid = GetClientUserId(client);
	for (int i = 1; i <= MaxClients; i++)
	{
	    if (IsValidClient(i, true) && GetClientTeam(i) == 2)
		{
			if (HasEntProp(i, Prop_Send, "m_humanSpectatorUserID")) {
				int spec = GetEntProp(i, Prop_Send, "m_humanSpectatorUserID");
				if (userid == spec) 
				{
					return i;
				}
			}
		}
	}
	return 0;
}

bool IsValidClient(int client, bool allowBot)
{
    if (client < 1 || client > MaxClients) 
	{
		return false;
	}
    if (!IsClientConnected(client))
	{
		return false;
	}
    if (!IsClientInGame(client))
	{
		return false;
	}
    if (IsFakeClient(client) && !allowBot)
	{
        return false;
	}
    return true;
}

void ResetToSurvivor()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, false))
		{
			SwitchToSpec(i);
			CreateTimer(0.1, JoinSurvivor, i, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

// bool IsGhost(int client)
// {
// 	int propGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
// 	return GetEntData(client, propGhost, 4) == 1;
// }



