/*
*    l4d2_teleport
*    Copyright (C) 2025 Yui
*   
*   Function about VPK file refers to https://github.com/SilvDev/VPK_API
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"
//#define PORTAL_MODEL "models/props_junk/petfoodbag01.mdl"
#define PORTAL_MODEL "models/props_fairgrounds/mr_mustachio.mdl"
#define PORTAL_PARTICLE "electrical_arc_01_system"
#define PORTAL_SOUND_SUCCESS "weapons/defibrillator/defibrillator_use.wav"
#define PORTAL_SOUND_FAILED "buttons/button11.wav"
#define PORTAL_SOUND_USE "elui/pickup_misc42.wav"

float durationTime = 3.0;

public Plugin myinfo = 
{
    name = "l4d2_teleport",
    author = PLUGIN_AUTHOR,
    description = "transport survivors",
    version = PLUGIN_VERSION,
    url = "N/A",
};

public void OnPluginStart()
{
    CreateConVar("l4d2_teleport_version", PLUGIN_VERSION, "l4d2_teleport plugin version.");
    HookEvent("round_start", Event_RoundStart);
    RegConsoleCmd("sm_tp", Command_Portal, "Spawn Portal");
}

public void OnMapStart()
{
    InitPrecache();
}

public Action Event_RoundStart(Handle event, const char[] event_name, bool dontBroadcast)
{
    CreateTimer(1.0, CreateInStartArea, 0, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action CreateInStartArea(Handle timer, int data)
{
    int client = GetRandomSurvivor(-1, -1);
    if (client > 0)
    {
        CreatePortal(client);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public Action Command_Portal(int client, int args)
{
    if (client > 0 && client < MaxClients && IsClientInGame(client))
    {
        CreatePortal(client);
    }
    return Plugin_Handled;
}

void CreatePortal(int client)
{
    float pos[3];
    GetClientLookingAt(client, pos);
    if (!L4D_IsPositionInFirstCheckpoint(pos))
    {
        GetClientAbsOrigin(client, pos);
    }
    float ang[3];
    GetClientEyeAngles(client, ang);
    ang[0] = 0.0;
    ang[1] += 180.0;
    ang[2] = 0.0;
    int portal = CreateEntityByName("prop_physics_override");

    DispatchKeyValue(portal, "model", PORTAL_MODEL);
    DispatchKeyValue(portal, "name", "Teleportor");
    DispatchKeyValue(portal, "spawnflags", "256");
    DispatchKeyValueVector(portal, "Origin", pos);
    DispatchKeyValueVector(portal, "Angles", ang);

    DispatchSpawn(portal);

    SetEntPropString(portal, Prop_Data, "m_iName", "Teleportor");
    SetEntPropFloat(portal, Prop_Send, "m_flModelScale", 0.8);
    SetEntProp(portal, Prop_Send, "m_usSolidFlags", 8);
    SetEntProp(portal, Prop_Send, "m_CollisionGroup", 11);

    SetEntityGlow(portal);
    SDKHook(portal, SDKHook_Use, OnUse);
}

public void OnEntityDestroyed(int entity)
{
    // For SDKUnhook
    if (!IsValidEntity(entity))
    {
        return;
    }
    char strData[12];
    GetEntPropString(entity, Prop_Data, "m_iName", strData, sizeof(strData));
    if (StrEqual(strData, "Teleportor"))
    {
        RemoveEntityGlow(entity);
        SDKUnhook(entity, SDKHook_Use, OnUse);
    }
}


void SetEntityGlow(int entity)
{
	int color = GetRgbInt(206, 127, 50);
	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 200);
	SetEntProp(entity, Prop_Send, "m_bFlashing", 1);
}

void RemoveEntityGlow(int entity)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 0);
	SetEntProp(entity, Prop_Send, "m_bFlashing", 0);
}

public void OnUse(int portal, int client)
{
    SetupProgressBar(client, durationTime);
}

void GetClientLookingAt(int client, float pos[3])
{
    float eyePos[3];
    float eyeAng[3];

    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);

    Handle trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);

    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        CloseHandle(trace);
        return;
    }

    CloseHandle(trace);
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

stock void SetupProgressBar(int client, float time)
{
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", time);
}

stock void KillProgressBar(int client)
{
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", 0.0);
}

int GetRgbInt(int red, int green, int blue)
{
	return (blue * 65536) + (green * 256) + red;
}

void InitPrecache()
{
    if (!IsModelPrecached(PORTAL_MODEL))
    {
        PrecacheModel(PORTAL_MODEL, true);
    }
    PrecacheParticle(PORTAL_PARTICLE);
    PrecacheSound(PORTAL_SOUND_SUCCESS);
    PrecacheSound(PORTAL_SOUND_FAILED);
    PrecacheSound(PORTAL_SOUND_USE);
}

void PrecacheParticle(const char[] particlename)
{
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        DispatchKeyValue(particle, "effect_name", particlename);
        DispatchKeyValue(particle, "targetname", "particle");
        DispatchSpawn(particle);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(0.01, DeleteParticles, particle);
    }
}

public Action DeleteParticles(Handle timer, int particle)
{
    if (IsValidEntity(particle))
    {
        char classname[64];
        GetEdictClassname(particle, classname, sizeof(classname));
        if (StrEqual(classname, "info_particle_system", false))
        {
            RemoveEdict(particle);
        }
    }
    return Plugin_Handled;
}
