#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>

new Handle:g_GameData;
new ClientStat[MAXPLAYERS+1];//0:不可；1：等待；2：完成
new bool:Client[MAXPLAYERS];
new bool:timerEnabled;

public Plugin:myinfo = 
{
	name = "l4d2_traitor",
	author = PLUGIN_AUTHOR,
	description = "change to be a traitor",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
    g_GameData = LoadGameConfigFile("l4d2_traitor");
    if(g_GameData == null)
    {
    	SetFailState("Game data missing!");
    }
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    RegConsoleCmd("sm_k", CMD_TakeOverInfected);
}

public Action:CMD_TakeOverInfected(client, args)
{
	SwitchToSpec(client);
	ClientStat[client] = 1;
	Client[client] = true;
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	timerEnabled = true;
	SpecAllPlayer();
	CreateTimer(5.0, Check, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	timerEnabled = false;
}



SpecAllPlayer()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		ClientStat[i] = 0;
		Client[i] = false;
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == 3 && !IsFakeClient(i))
			{
				
				SwitchToSpec(i);
			}
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0 && !IsFakeClient(client) && GetClientTeam(client) == 3)
	{
		LogMessage("Event_PlayerDeath:%d", client);
		SwitchToSpec(client);
		if(ClientStat[client] == 2)
		{
			ClientStat[client] = 1;
		}
	}
}

public Action:Check(Handle:timer)
{
	LogMessage("DoCheck");
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientValid(i))
		{
			continue;
		}
		if(Client[i] == true && ClientStat[i] == 1)
		{
			LogMessage("Change");
			ChangeToInfected(i);
		}
	}
	if(timerEnabled)
	{
		CreateTimer(5.0, Check, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public ChangeToInfected(client)
{
	new bot = GetAnInfectBot();
	if (bot > 0)
	{
		if(TakeoverZombieBotSig(client, bot, true))
		{
			LogMessage("Change Success");
			ClientStat[client] = 2;
		}
	}
}

GetAnInfectBot()
{
	for (new i = 0; i < MAXPLAYERS + 1; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == 3 && GetVictim(i) <= 0 && !IsInSurvivorView(i))
			{
				return i;
			}
		}
	}
	return 0;
}

GetVictim(client)
{
    new victim = 0;
    /* Charger */
    victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
    if (victim > 0)
    {
        return victim;
    }
    victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
    if (victim > 0)
    {
        return victim;
    }

    /* Hunter */
    victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
    if (victim > 0)
    {
        return victim;
    }

    /* Smoker */
    victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
    if (victim > 0)
    {
        return victim;
    }

    /* Jockey */
    victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
    if (victim > 0)
    {
        return victim;
    }

    return -1;
}

bool:TakeoverZombieBotSig(client, target, si_ghost)
{
    static Handle:hSwitch;
    
    if (hSwitch == null)
    {
        StartPrepSDKCall(SDKCall_Player);
        PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "TakeOverZombieBot");
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        hSwitch = EndPrepSDKCall();
    }

    if (hSwitch != null)
    {
        if (IsClientInKickQueue(target))
        {
            KickClient(target);
        }
        else if (IsClientValid(target) && IsPlayerAlive(target))
        {
        	SwitchToSpec(client);
            SDKCall(hSwitch, client, target);
            if (si_ghost)
            {
                State_TransitionSig(client, 8);
            }
            return true;
        }
    }

    else
    {
    	LogMessage("TakeoverZombieBot Signature broken.");
    }
    return false;
}

State_TransitionSig(client, mode)
{
	static Handle:hSpec;
	
	if (hSpec == null)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "State_Transition");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hSpec = EndPrepSDKCall();
	}

	if(hSpec != null)
	{
		SDKCall(hSpec, client, mode);  // mode 8, press 8 to get closer
	}
	else
	{
		LogMessage("State_TransitionSig Signature broken.");
	}
}

SwitchToSpec(client)
{
    // clearparent jockey bug switching teams (thanks to Lux)
    AcceptEntityInput(client, "clearparent");
    ChangeClientTeam(client, 1);
}

bool:IsClientValid(client)
{
	if (client >= 1 && client <= MaxClients)
	{
		if (IsClientConnected(client))
		{
			if (IsClientInGame(client))
			{
				return true;
			} 	
		}
	}
	return false;
}

bool:IsInSurvivorView(client)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientValid(i) || GetClientTeam(i) != 2)
		{
			continue;
		}
		if(IsInView(i, client))
		{
			return true;
		}
	}
	return false;
}

 bool:IsInView(int viewer, int target, float fMaxDistance=0.0, float fThreshold=0.73)
{
	// Retrieve view and target eyes position
	float fViewPos[3];  
	GetClientEyePosition(viewer, fViewPos);
	float fViewAng[3];  
	GetClientEyeAngles(viewer, fViewAng);
	float fViewDir[3];
	float fTargetPos[3];
	GetClientEyePosition(target, fTargetPos);
	float fTargetDir[3];
	float fDistance[3];

	// Calculate view direction
	fViewAng[0] = fViewAng[2] = 0.0;
	GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);

	// Calculate distance to viewer to see if it can be seen.
	fDistance[0] = fTargetPos[0]-fViewPos[0];
	fDistance[1] = fTargetPos[1]-fViewPos[1];
	fDistance[2] = 0.0;
	if (fMaxDistance != 0.0)
	{
		if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
			return false;
	}

	// Check dot product. If it's negative, that means the viewer is facing
	// backwards to the target.
	NormalizeVector(fDistance, fTargetDir);
	if (GetVectorDotProduct(fViewDir, fTargetDir) < fThreshold)
		return false;

	// Now check if there are no obstacles in between through raycasting
	Handle hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
	if (TR_DidHit(hTrace))
	{
		CloseHandle(hTrace);
		return false;
	}
	CloseHandle(hTrace);

	// Done, it's visible
	return true;
}

stock bool:ClientViewsFilter(int entity, int mask, any junk)
{
	if (entity >= 1 && entity <= MaxClients) 
		return false;

	return true;
}