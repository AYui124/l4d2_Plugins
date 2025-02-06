#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.3"
#define Count 32

#include <sourcemod>
#include <sdktools>

static String:needClean_Scripts[Count][] =
{
	"weapon_spawn",
	"weapon_ammo_spawn",
	//"weapon_melee_spawn",
	"weapon_pistol_spawn",
	"weapon_pistol_magnum_spawn",
	"weapon_smg_spawn",
	"weapon_smg_silenced_spawn",
	"weapon_pumpshotgun_spawn",
	"weapon_shotgun_chrome_spawn",
	"weapon_hunting_rifle_spawn",
	"weapon_sniper_military_spawn",
	"weapon_rifle_spawn",
	"weapon_rifle_ak47_spawn",
	"weapon_rifle_desert_spawn",
	"weapon_autoshotgun_spawn",
	"weapon_shotgun_spas_spawn",
	"weapon_rifle_m60_spawn",
	"weapon_grenade_launcher_spawn",
	"weapon_chainsaw_spawn",
	"weapon_item_spawn",
	"weapon_first_aid_kit_spawn",
	"weapon_defibrillator_spawn",
	"weapon_pain_pills_spawn",
	"weapon_adrenaline_spawn",
	"weapon_pipe_bomb_spawn",
	"weapon_molotov_spawn",
	"weapon_vomitjar_spawn",
	//"weapon_gascan_spawn",
	"upgrade_spawn",
	"upgrade_laser_sight",
	"weapon_upgradepack_explosive_spawn",
	"weapon_upgradepack_incendiary_spawn",
	"upgrade_ammo_incendiary",
	"upgrade_ammo_explosive"
};

public Plugin:myinfo = 
{
	name = "kill all spawner",
	author = PLUGIN_AUTHOR,
	description = "N/A",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(1.0, TimerDelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action: TimerDelayedOnRoundStart(Handle:timer)
{
	RemoveItems();
}

RemoveItems()
{
	new String:className[128];
	new entityCount = GetEntityCount();
	for (new i = 1; i < entityCount; i++)
	{
		if (!IsValidEntity(i))
		{
			continue;
		}
		GetEdictClassname(i, className, sizeof(className));
		//if ((StrContains(className, "weapon", false) >= 0 || StrContains(className, "spawn", false) >= 0 || StrContains(className, "upgrade", false) >= 0) && StrContains(className, "pistol", false) == -1)
		if (NeedCleanSpawn(className))
		{
			AcceptEntityInput(i, "Kill");
		}
	}
}

stock bool:NeedCleanSpawn(const String:cName[])
{
	for (new i = 0; i < Count; i++)
	{
		if (StrEqual(cName, needClean_Scripts[i], false))
		{
			return true;
		}
	}
	return false;
}
