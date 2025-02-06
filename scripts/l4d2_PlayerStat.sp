#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1

#define SLOTLENGTH 40

char slot1[MAXPLAYERS + 1][SLOTLENGTH];
char slot2[MAXPLAYERS + 1][SLOTLENGTH];
char slot3[MAXPLAYERS + 1][SLOTLENGTH];
char slot4[MAXPLAYERS + 1][SLOTLENGTH];
char slot5[MAXPLAYERS + 1][SLOTLENGTH];

int weaponUpgrade[MAXPLAYERS];

public Plugin myinfo =
{
	name = "l4d2_PlayerStat",
	author = "mYui",
	description = "Save Player Stat(weapon, model)",
	version = "1.0.0",
	url = "https://github.com/Ayui124"
};


public void OnPluginStart()
{
    HookEvent("round_start", RoundStart);
}

void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    Reset();
    SavePlayersSlotInfo();
}

void Reset()
{
    for(int i = 0; i < MAXPLAYERS + 1; i++)
    {
        Format(slot1[i], SLOTLENGTH, "");
        Format(slot2[i], SLOTLENGTH, "");
        Format(slot3[i], SLOTLENGTH, "");
        Format(slot4[i], SLOTLENGTH, "");
        Format(slot5[i], SLOTLENGTH, "");
        weaponUpgrade[i] = 0;
    }
}

void SavePlayersSlotInfo()
{
    for(int i = 0; i < MAXPLAYERS + 1; i++)
    {
        if (IsValidClient(i, true) && GetClientTeam(i) == 2)
        {
            int gun = GetPlayerWeaponSlot(i, 0);
            int melee = GetPlayerWeaponSlot(i, 1);
            int gen = GetPlayerWeaponSlot(i, 2);
            int kits = GetPlayerWeaponSlot(i, 3);
            int pills = GetPlayerWeaponSlot(i, 4);
            char buffer[40];
            if(gun > 0)
            {
                GetEdictClassname(gun, buffer, 40);
                Format(slot1[i], SLOTLENGTH, "%s", buffer);
                weaponUpgrade[i] = GetEntProp(gun, Prop_Send, "m_upgradeBitVec", 4);
            } 
            else 
            {
                Format(slot1[i], SLOTLENGTH, "");
                weaponUpgrade[i] = 0;
            }
            if (melee > 0)
            {
                char buf[40];
                GetEdictClassname(melee, buffer, 40);
                if (!strcmp(buffer, "weapon_melee", true)) // 近战
                {
                    GetEntPropString(melee, Prop_Data, "m_strMapSetScriptName", buf, 40);
                    Format(slot2[i], SLOTLENGTH, "%s", buf);
                } 
                else if (!strcmp(buffer, "weapon_pistol", true)) // 手枪
                {
                    if (GetEntProp(melee, Prop_Send, "m_hasDualWeapons" ) == 1) // 双枪
                    {
                        Format(slot2[i], SLOTLENGTH, "dual_pistol");
                    }
                    else
                    {
                        Format(slot2[i], SLOTLENGTH, "weapon_pistol");
                    }
                }
                else // 其他
                {
                    Format(slot2[i], SLOTLENGTH, "%s", buffer);
                }
            }
            else
            {
                Format(slot2[i], SLOTLENGTH, "");
            }
            if (gen > 0)
            {
                GetEdictClassname(gen, buffer, 40);
                Format(slot3[i], SLOTLENGTH, "%s", buffer);
            }
            else
            {
                Format(slot3[i], SLOTLENGTH, "");
            }
            if (kits > 0)
            {
                GetEdictClassname(kits, buffer, 40);
                Format(slot4[i], SLOTLENGTH, "%s", buffer);
            }
            else
            {
                Format(slot4[i], SLOTLENGTH, "");
            }
            if (pills > 0)
            {
                GetEdictClassname(pills, buffer, 40);
                Format(slot5[i], SLOTLENGTH, "%s", buffer);
            }
            else
            {
                Format(slot5[i], SLOTLENGTH, "");
            }
        }
    }
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
