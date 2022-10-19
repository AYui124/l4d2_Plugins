#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.3"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

static const String:sound[] = "./level/loud/climber.wav";
static const Float:ang[3]	= { 90.0 , 0.0 , 0.0 };

static Handle:h_Charge = INVALID_HANDLE;
static bool:g_bIsCharging[MAXPLAYERS + 1];
static bool:g_bSteerEnabled;

public Plugin:myinfo = 
{
	name = "death slow",
	author = PLUGIN_AUTHOR,
	description = "slow motion when a survivor will fly to death",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	HookEvent("charger_carry_start", Event_CarryStart);
	HookEvent("charger_carry_end", Event_CarryEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	g_bSteerEnabled = false;
}

public OnMapStart()
{
	PrefetchSound(sound);
	PrecacheSound(sound);
	h_Charge = INVALID_HANDLE;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( client ) g_bIsCharging[client] = false;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetEventInt(event, "attackerentid");
	g_bIsCharging[client] = false;
	
	
	if (IsClientAndInGame(client) && GetClientTeam(client) == 2 && IsWitch(attacker))
    {
    	EmitSoundToAll(sound, client);
	    //SlowTime(client);
    }
	
}



public Action:Event_CarryStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client))
	{
		return;
	}
	if (h_Charge != INVALID_HANDLE)
	{
		CloseHandle(h_Charge);
		h_Charge = INVALID_HANDLE;
	}
	h_Charge = CreateTimer(0.4, timer_Check, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(h_Charge, true);
	if(g_bSteerEnabled)
	{
		g_bIsCharging[client] = true;
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);
	
		new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( entity != -1 )
		{
			SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 999.9);
		}
	}
}

public Action:Event_CarryEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (h_Charge != INVALID_HANDLE)
	{
		CloseHandle(h_Charge);
		h_Charge = INVALID_HANDLE;
	}
	if(g_bSteerEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client <= 0 || client>MaxClients || !IsClientInGame(client))
		{
			return;
		}
		g_bIsCharging[client] = false;
		new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( entity != -1 )
		{
			SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);
		}
	}

}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(g_bSteerEnabled && (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) && g_bIsCharging[client] && GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND)
	{
		new Float:vVel[3], vVec[3], vAng[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		GetClientEyeAngles(client, vAng);

		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		NormalizeVector(vVec, vVec);

		ScaleVector(vVec, 50.0);
		if (buttons & IN_MOVELEFT)
			ScaleVector(vVec, -1.0);

		AddVectors(vVel, vVec, vVel);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
	return Plugin_Continue;
}

public Action:timer_Check(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		h_Charge = INVALID_HANDLE;
		return Plugin_Stop;
	}
	if (GetEntityFlags(client) & FL_ONGROUND)
	{
		return Plugin_Continue;
	}
	new Float:height = GetHeight(client);
	if (height > 425.0)
	{
		SlowMotion(client);
		h_Charge = INVALID_HANDLE;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

static Float:GetHeight(client)
{
	decl Float:pos[3];
	GetClientAbsOrigin(client, pos);
	new Handle:trace = TR_TraceRayFilterEx(pos, ang, MASK_SHOT, RayType_Infinite, TraceFilter);
	
	if (!TR_DidHit(trace))
	{
		LogError("Tracer Bug: Trace did not hit anything");
	}
	
	decl Float:vEnd[3];
	TR_GetEndPosition(vEnd, trace);
	CloseHandle(trace);
	
	return GetVectorDistance(pos, vEnd, false);
}

public bool:TraceFilter(entity, contentsMask)
{
	if (!entity || !IsValidEntity(entity))
	{
		return false;
	}
	return true;
}

static SlowMotion(client)
{
	if (!HasEntProp(client, Prop_Send, "m_carryVictim"))
	{
		return;
	}
	new victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
	if (victim < 1 || victim > MaxClients || !IsClientInGame(victim))
	{
		return;
	}
	EmitSoundToAll(sound, client);
	SlowTime(victim);
}

SlowTime(client)
{
	new ent = CreateEntityByName("func_timescale");
	
	DispatchKeyValue(ent, "desiredTimescale", "0.1");
	DispatchKeyValue(ent, "acceleration", "2.0");
	DispatchKeyValue(ent, "minBlendRate", "1.0");
	DispatchKeyValue(ent, "blendDeltaMultiplier", "2.0");
	
	DispatchSpawn(ent);
	AcceptEntityInput(ent, "Start");
	
	CreateTimer(0.4, Timer_SetNormal, ent);
	CreateTimer(0.5, Timer_Kill, client);
}

public Action:Timer_SetNormal(Handle:timer, any:ent)
{
	if(IsValidEdict(ent))
	{
		AcceptEntityInput(ent, "Stop");
	}
}

public Action:Timer_Kill(Handle:timer, any:victim)
{
	if (victim < 1 || victim > MaxClients || !IsClientInGame(victim))
	{
		return;
	}
	if(IsPlayerAlive(victim))
	{
		ForcePlayerSuicide(victim);
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
}

public Action:Event_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!inflictor || !IsValidEntity(inflictor) || !IsValidSurvivorAndInGame(victim) || !IsValidInfectedAndInGame(attacker))
	{
		return Plugin_Continue;
	}
	decl String:classname[64];
	if (attacker == inflictor)                                             
	{
		GetClientWeapon(inflictor, classname, sizeof(classname));			// for claws
	}
	else
	{
	 	GetEntityClassname(inflictor, classname, sizeof(classname));		// for tank punch/rock
	}
	// only check tank punch (also rules out anything but infected-to-survivor damage)
	if (!StrEqual("weapon_tank_claw", classname))
	{
		return Plugin_Continue;
	}
	CreateTimer(0.4, timer_Check2, victim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

bool:IsValidSurvivorAndInGame(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool:IsValidInfectedAndInGame(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}

public Action:timer_Check2(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	if (GetEntityFlags(client) & FL_ONGROUND)
	{
		return Plugin_Stop;
	}
	new Float:vec[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec);
	if (vec[2] < -600.0)
	{
		SlowTankVictim(client);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

static SlowTankVictim(client)
{
	if (client > 0)
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 0.1);
	}
	CreateTimer(4.0, NormalTankTimeSlow, client);
}

public Action:NormalTankTimeSlow(Handle:timer, any:client)
{
	if (client > 0 && IsClientInGame(client))
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
	}
}

bool:IsWitch(iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "witch");
    }
    return false;
}

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}