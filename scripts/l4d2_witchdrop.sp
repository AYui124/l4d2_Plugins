#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.6"

#include <sourcemod>
#include <sdktools>

#define MODEL_GNOME		"models/props_junk/gnome.mdl"
#define MODEL_COLA		"models/w_models/weapons/w_cola.mdl"

new Float:timeLos[10000];
new Handle:timerSpawn = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "witch award&spawn/slay",
	author = PLUGIN_AUTHOR,
	description = "witch spawn/slayer & drop when witch was killed",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	new flag = GameCheck();
	if(!flag)SetFailState("Use this in Left4Dead2 only!");
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

bool:GameCheck()
{
	decl String:GameName[16];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2"))
	{
		return true;
	}
	return false;
}

public OnMapStart()
{
	timerSpawn = INVALID_HANDLE;
	if (!IsModelPrecached("models/infected/witch.mdl"))
	{
		PrecacheModel("models/infected/witch.mdl");
	}
	if (!IsModelPrecached("models/infected/witch_bride.mdl"))
	{
		PrecacheModel("models/infected/witch_bride.mdl");
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(1.0, TimerLeftSafeRoom, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (timerSpawn != INVALID_HANDLE)
	{ 
		KillTimer(timerSpawn);
		timerSpawn = INVALID_HANDLE;
	}
}

public Action:TimerLeftSafeRoom(Handle:timer)
{
	if (LeftStartArea())
	{
		StartSpawnTimer();
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

StartSpawnTimer()
{
	if (timerSpawn != INVALID_HANDLE)
	{ 
		KillTimer(timerSpawn);
		timerSpawn = INVALID_HANDLE;
	}
	timerSpawn = CreateTimer(10.0, Timer_WaitWitchSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_WaitWitchSpawn(Handle:timer)
{
	new Float:interval = 0.0;
	new count = GetWitchCount();
	if (count >= 3 || count < 0)
	{
		interval = GetRandomFloat(20.0, 50.0);
	}
	else if (count > 0 && count < 3)
	{
		interval = SpawnWitch() ? GetRandomFloat(45.0, 90.0) : 1.0;
	}
	else if (count == 0)
	{
		interval = SpawnWitch() ? GetRandomFloat(80.0, 120.0) : 1.0;
	}
	if (timerSpawn != INVALID_HANDLE)
	{ 
		KillTimer(timerSpawn);
		timerSpawn = INVALID_HANDLE;
	}
	timerSpawn = CreateTimer(interval, Timer_WaitWitchSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool:SpawnWitch()
{
	new client = GetAnyClient();
	if (client)
	{
		ExecuteCheatCommand(client, "z_spawn_old", "witch", "auto");
		return true;
	}
	else
	{
		return false;
	}
}

GetAnyClient()
{
	for (new  i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && !IsFakeClient(i))
			return i;
	}
	return 0;
}

ExecuteCheatCommand(client, const String:command[], String:param1[], String:param2[]) 
{
	new admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, param1, param2);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

public Action:Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new id = GetEventInt(event, "witchid");
	timeLos[id] = 0.0;
	CreateTimer(5.0, Timer_AutoKill, id, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_AutoKill( Handle:timer, any:id)
{
	if (IsWitch(id))
	{
		new Float:dis = GetClosestClientDistanceToEnt(id);
		//LogMessage("closest distance:%f", dis);
		if (dis < 1000.0)
		{
			//LogMessage("TimeLos Set To 0.0");
			timeLos[id] = 0.0;
			if (dis < 300)
			{
				new rand = GetRandomInt(1, 100);
				if (rand > 60)
				{
					new client = GetAnyClient();
					if (client)
					{
						//if (GetTankCount() < 4 && GetSICount() + GetTankCount() < GetAliveSurvivorCount())
						//{
						//	ExecuteCheatCommand(client, "z_spawn_old", "tank", "auto");
						//}
						SetConVarInt(FindConVar("tank_rate_up"), 1);
					}
				}
			}
			else
			{
				SetConVarInt(FindConVar("tank_rate_up"), 0);
			}
		}
		else
		{
			//LogMessage("TimeLos Add 5.0");
			timeLos[id] += 5.0;
		}
		if (timeLos[id] > 60.0)
		{
			AcceptEntityInput(id, "Kill");
			return Plugin_Stop;
		}
	}
	else 
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

Float:GetClosestClientDistanceToEnt(id)
{
	new Float:temp = 0.0;
	new Float:dis = 0.0;
	new Float:tPos[3];
	new Float:cPos[3];
	GetEntPropVector(id, Prop_Send, "m_vecOrigin",cPos);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i) || !IsPlayerAlive(i) || IsFakeClient(i))
		{
			continue;
		}
		GetEntPropVector(i, Prop_Send, "m_vecOrigin",tPos);
		temp = GetVectorDistance(tPos, cPos, false);
		if (dis < temp)
		{
			dis = temp;
		}
	}
	return dis;
}

bool:IsSurvivor(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	else
	{
		return false;
	}
}

public Action:Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Float:witchPos[3];
	new edict = GetEventInt(event, "witchid");
	
	GetEntPropVector(edict, Prop_Send, "m_vecOrigin",witchPos);
	new tempnum = GetRandomInt(1, 100) % 4 + 1;
	switch(tempnum)
	{
		case 1:
		{
			new item = CreateEntityByName("weapon_ammo_spawn");
			new String:position[64];
			Format(position, sizeof(position), "%1.1f %1.1f %1.1f", witchPos[0], witchPos[1], witchPos[2]);
			DispatchKeyValue(item, "origin", position);
			DispatchKeyValue(item, "classname", "weapon_ammo_spawn");
			DispatchSpawn(item);

		}
		case 2:
		{
			new String:position[64];
			new item = CreateEntityByName("upgrade_spawn");
			DispatchKeyValue(item, "count", "1");
			DispatchKeyValue(item, "laser_sight", "1");
			Format(position, sizeof(position), "%1.1f %1.1f %1.1f",witchPos[0], witchPos[1], witchPos[2] += 10.0);
			DispatchKeyValue(item, "origin", position);
			DispatchKeyValue(item, "classname", "upgrade_spawn");
			DispatchSpawn(item);
		}
		case 3:
		{
			new item = CreateEntityByName("prop_physics");
			new String:position[64];
			Format(position, sizeof(position), "%1.1f %1.1f %1.1f", witchPos[0], witchPos[1], witchPos[2] += 50.0);
			if( item == -1 ) ThrowError("Failed to create gnome model.");
			DispatchKeyValue(item, "origin", position);
			DispatchKeyValue(item, "model", MODEL_GNOME);
			DispatchSpawn(item);
		}
		case 4:
		{
			new item = CreateEntityByName("prop_physics");
			new String:position[64];
			Format(position, sizeof(position), "%1.1f %1.1f %1.1f", witchPos[0], witchPos[1], witchPos[2] += 50.0);
			if( item == -1 ) ThrowError("Failed to create cola model.");
			DispatchKeyValue(item, "origin", position);
			DispatchKeyValue(item, "model", MODEL_COLA);
			DispatchSpawn(item);
		}
	}
}

bool:IsWitch(entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        decl String:strClassName[64];
        GetEdictClassname(entity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "witch");
    }
    return false;
}

GetWitchCount()
{
	new count = 0;
	new realMaxEntities = GetMaxEntities() * 2;
	for (new entity = 0; entity < realMaxEntities; entity++)
	{
		if (IsWitch(entity))
		{
			count += 1;
		}
	}
	return count;
}

// bool:IsSpecialInfected(client)
// {
//     return IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") != 8 && GetEntProp(client, Prop_Send, "m_zombieClass") != 7;
// }

// GetSICount()
// {
// 	new count = 0;
// 	for (new i = 1; i <= MaxClients; i++)
// 	{
// 		if (IsSpecialInfected(i))
// 		{
// 			count += 1;
// 		}
// 	}
// 	return count;
// }

// bool:IsTank(client)
// {
//     return IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
// }

// GetTankCount()
// {
// 	new count = 0;
// 	for (new i = 1; i <= MaxClients; i++)
// 	{
// 		if (IsTank(i))
// 		{
// 			count += 1;
// 		}
// 	}
// 	return count;
// }

// GetAliveSurvivorCount()
// {
// 	new count = 0;
// 	for (new i = 1; i <= MaxClients; i++)
// 	{
// 		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsFakeClient(i))
// 		{
// 			count += 1;
// 		}
// 	}
// 	return count;
// }
