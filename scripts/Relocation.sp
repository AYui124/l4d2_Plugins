#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "Relocation",
	author = PLUGIN_AUTHOR,
	description = "N/A",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	RegAdminCmd("sm_add", Cmd_AddSI, ADMFLAG_CHEATS);
}

public Action:Cmd_AddSI(client, args)
{
	Create(client);
}

Create(client)
{
	CheatCommand(client,"z_spawn bommer");
	
	new Float:pos[3];
	new Float:angles[3];
	new target;
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, angles);
	new Handle: trace= TR_TraceRayFilterEx(pos, angles, MASK_SHOT, RayType_Infinite, DontHitSelf, client);
	if(TR_DidHit(trace))
	{		
		target = TR_GetEntityIndex(trace);
	}
	CloseHandle(trace);
	PrintToChat(client, "Create id:%i", target);
}

public bool:DontHitSelf(entity, mask, any:data)
{
	if(entity == data) 
	{
		return false; 
	}
	return true;
}

stock CheatCommand(client, String:command[])
{
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s", command);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}