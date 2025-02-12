#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "1.0"
#define Primary 17
#define Secend 21
#define Special 13
#define Throwable 24
#define Medkit 13
#define Upgrade 12
#define GiftModel "models/items/l4d_gift.mdl"

/*
*
* 17%  枪
* 21%  近战
* 3.4% 手枪
* 2.4% 榴弹
* 2.4% M60
* 2.4% 沙鹰
* 2.4% 电锯
* 24%  雷/胆汁/火瓶
* 13%  电击/医疗/药/针
* 12%  升级/油桶
*
*/

static MODEL_DEFIB;


static String:gun_Scripts[15][] =
{
	"weapon_hunting_rifle",
	"weapon_sniper_military",
	"weapon_sniper_awp",
	"weapon_sniper_scout",
	"weapon_rifle",
	"weapon_rifle_ak47",
	"weapon_rifle_desert",
	"weapon_rifle_sg552",
	"weapon_pumpshotgun",
	"weapon_shotgun_chrome",
	"weapon_shotgun_spas",
	"weapon_autoshotgun",
	"weapon_smg",
	"weapon_smg_silenced",
	"weapon_smg_mp5"
};

static String:melee_Scripts[13][] =
{
	"fireaxe",
	"baseball_bat",
	"cricket_bat",
	"crowbar",
	"frying_pan",
	"golfclub",
	"electric_guitar",
	"katana",
	"machete",
	"tonfa",
	"knife",
	"shovel",
	"pitchfork"
};

static String:spweapon_Scripts[5][] =
{
	"weapon_grenade_launcher",
	"weapon_rifle_m60",
	"weapon_pistol",
	"weapon_pistol_magnum",
	"weapon_chainsaw"
};

static String:generade_Scripts[3][] =
{
	"weapon_molotov",
	"weapon_pipe_bomb",
	"weapon_vomitjar"
};

static String:medkit_Scripts[4][] =
{
	"weapon_adrenaline",
	"weapon_defibrillator",
	"weapon_first_aid_kit",
	"weapon_pain_pills"
};

static String:upgcan_Scripts[6][] =
{
	"weapon_fireworkcrate",
	"weapon_gascan",
	"weapon_oxygentank",
	"weapon_propanetank",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary"
};

static String:removeable_Scripts[21][] = 
{
    "weapon_grenade_launcher",
	"weapon_rifle_m60",
	"weapon_pistol",
	"weapon_pistol_magnum",
	"weapon_chainsaw",
	"weapon_hunting_rifle",
	"weapon_sniper_military",
	"weapon_sniper_awp",
	"weapon_sniper_scout",
	"weapon_rifle",
	"weapon_rifle_ak47",
	"weapon_rifle_desert",
	"weapon_rifle_sg552",
	"weapon_pumpshotgun",
	"weapon_shotgun_chrome",
	"weapon_shotgun_spas",
	"weapon_autoshotgun",
	"weapon_smg",
	"weapon_smg_silenced",
	"weapon_smg_mp5",
	"weapon_melee",
};

public Plugin:myinfo = 
{
	name = "l4d2_Gift",
	author = PLUGIN_AUTHOR,
	description = "drop gifts when infected has been killed",
	version = PLUGIN_VERSION,
	url = "steamcommunity.com/id/m_Yui"
};

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	
	Precache();
	CreateTimer(1.0, InitHiddenWeaponsDelayed);
}

public OnMapStart()
{
	MODEL_DEFIB = PrecacheModel("models/w_models/weapons/w_eq_defibrillator.mdl", true);
	PrecacheModel(GiftModel, true);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	new vic = GetClientOfUserId(GetEventInt(event, "userid"));
	new String: buf[40];
	if (client > 0 && vic > 0)
	{
		if (client != vic)
		{
			buf[0] = '\0';
			GetEventString(event, "victimname", buf, sizeof(buf));
			if (buf[0] == 'B' || buf[0] == 'J' || (buf[0] == 'S' &&(buf[1] == 'm' || buf[1] == 'p')) || buf[0] == 'H' || buf[0] == 'C')
			{
				CreateGifts(vic, 1);
			}
			if (buf[0] == 'T')
			{
				new random = GetRandomInt(2, 4);
				CreateGifts(vic, random);
			}
		}
	}	
}

CreateGifts(any:client, any:data)
{
	if(client > 0)
	{
		decl String:strData[2];
		Format(strData, sizeof(strData), "%d", data);
		
		decl Float:vPos[3];
		GetClientEyePosition(client, vPos);
		vPos[2] += 10.0;
		
		new entity = CreateEntityByName("prop_physics_override");
		if(entity == -1)
			return;
			
		DispatchKeyValueVector(entity, "origin", vPos);
		DispatchKeyValue(entity, "model", GiftModel);
		DispatchKeyValue(entity, "spawnflags", "256");
		SetEntPropString(entity, Prop_Data, "m_iName", strData);
		DispatchSpawn(entity);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.8);
		SetEntProp(entity, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11);
		SetEntityRenderColor(entity, 255, 255, 255, 150);
		CreateTimer(0.1, ColdDown, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		
	}
}

SetEntityGlow(entity)
{
	new color = GetRgbInt(206, 127, 50);

	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 2048);
	SetEntProp(entity, Prop_Send, "m_bFlashing", 1);
}

RemoveEntityGlow(entity)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 0);
	SetEntProp(entity, Prop_Send, "m_bFlashing", 0);
}

public Action:ColdDown(Handle:timer, any:ref)
{
	//LogMessage("ColdDown ref=%d", ref);
	int gift;
	if (ref && (gift = EntRefToEntIndex(ref)) != INVALID_ENT_REFERENCE)
	{
		//LogMessage("ColdDown gift=%d", gift);
		SetEntityGlow(gift);
		SDKHook(gift, SDKHook_Use, OnUse);
		CreateTimer(30.0, RemoveGift, ref, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action:RemoveGift(Handle:timer, any:ref)
{
	//LogMessage("RemoveGift ref=%d", ref);
	int gift;
	if ( ref && (gift = EntRefToEntIndex(ref)) != INVALID_ENT_REFERENCE)
	{
		//LogMessage("RemoveGift gift=%d", gift);
		SDKUnhook(gift, SDKHook_Use, OnUse);
		RemoveEntityGlow(gift);
		AcceptEntityInput(ref, "kill");
	}

	return Plugin_Continue;
}

public OnUse(any:gift, any:client)
{
	//LogMessage("OnUse:%N,%d", client, gift);
	if (IsValidSurvivor(client))
	{
		decl String:strData[2];
		GetEntPropString(gift, Prop_Data, "m_iName", strData, sizeof(strData));
		new data = StringToInt(strData);
		
		new Float:vNew[3];
		GetEntPropVector(gift, Prop_Data, "m_vecAbsOrigin", vNew);
		vNew[2] += 20;
		
		decl Handle:dataPack;
		dataPack = CreateDataPack();
		WritePackCell(dataPack, vNew[0]);
		WritePackCell(dataPack, vNew[1]);
		WritePackCell(dataPack, vNew[2]);
		
		for (new i = 0; i < data; i++)
		{
			if (i == data -1)
			{
				WritePackCell(dataPack, 1);
			} 
			else 
			{
				WritePackCell(dataPack, 0);
			}
			
			CreateTimer(0.1 + i * 0.1, DoRoll, dataPack, TIMER_FLAG_NO_MAPCHANGE);
		}
		SDKUnhook(gift, SDKHook_Use, OnUse);
		RemoveEntityGlow(gift);
		AcceptEntityInput(gift, "kill");
	}
}

bool:IsValidSurvivor(any:client)
{
	if (client < 1 || client > MaxClients) 
		return false;
	
	if (!IsClientConnected(client)) 
		return false;
	
	if (!IsClientInGame(client)) 
		return false;

	if (IsFakeClient(client))
	    return false;
	
	return true;
}

public Action:DoRoll(Handle:timer, Handle:pack)
{
	decl Float:pos[3];
	ResetPack(pack, false);
	pos[0] = ReadPackCell(pack);
	pos[1] = ReadPackCell(pack);
	pos[2] = ReadPackCell(pack);
	new last = ReadPackCell(pack);
	if (last == 1)
	{
		CloseHandle(pack);
	}
	
	
	new sRate = GetRandomInt(1, 1000) % 100 + 1;
	//LogMessage("sRate=%i", sRate);
	new sum1 = Primary;
	new sum2 = Primary+Secend;
	new sum3 = Primary+Secend+Special;
	new sum4 = Primary+Secend+Special+Throwable;
	new sum5 = Primary+Secend+Special+Throwable+Medkit;
	new sum6 = Primary+Secend+Special+Throwable+Medkit+Upgrade;
	new ent;
	if (sRate > 0 && sRate <= sum1)
	{
		ent = C_PrimWeapon();
	}
	else if (sRate > sum1 && sRate <= sum2)
	{
		ent = C_Melee();
	}
	else if (sRate > sum2 && sRate <= sum3)
	{
		ent = C_SpWeapon();
	}
	else if (sRate > sum3 && sRate <= sum4)
	{
		ent = C_Generade();
	}
	else if (sRate > sum4 && sRate <= sum5)
	{
		ent = C_Medkit();
	}
	else if (sRate > sum5 && sRate <= sum6)
	{
		ent = C_UpGAndCan();
	}
	else
	{
		LogMessage("Wrong:sRate=%i", sRate);
	}
	CreateTimer(30.0, RemoveGun, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
}


C_PrimWeapon()
{
	new weapon = -1;
	new ammo = 0;
	new model = GetRandomInt(0, 14);
	if (model == 0)
	{
		ammo = 150;
	}
	else if (model >= 1 && model <=3)
	{
		ammo = 180;
	}
	else if (model >= 4 && model <= 7)
	{
		ammo = 360;
	}
	else if (model >= 8 && model <= 9)
	{
		ammo = 72;
	}
	else if (model >= 10 && model <= 11)
	{
		ammo = 90;
	}
	else if (model >= 12 && model <= 14)
	{
		ammo = 650;
	}
	else
	{
		ammo = 0;
	}
	weapon = CreateEntity(gun_Scripts[model]);
	if (weapon == -1)
	{
		ThrowError("Failed to create entity %s.",gun_Scripts[model]);
	}
	LogMessage("drop model=%d,%s", model, gun_Scripts[model]);
	DispatchSpawn(weapon);
	SetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo", ammo, 4);
	return weapon;
}

C_Melee()
{
	new weapon = -1;
	weapon = CreateEntity("weapon_melee");
	if (weapon == -1)
	{
		ThrowError("Failed to create entity 'weapon_melee'.");
	}
	new model = GetRandomInt(0, 12);
	LogMessage("drop model=%d,%s", model, melee_Scripts[model]);
	DispatchKeyValue(weapon, "solid", "6");
	DispatchKeyValue(weapon, "melee_script_name", melee_Scripts[model]);
	DispatchSpawn(weapon);
	return weapon;
}

C_SpWeapon()
{
	new weapon = -1;
	new ammo = 0;
	new model = GetRandomInt(0, 4);
	new changeRate = GetRandomInt(1, 100);
	if (changeRate > 40 && (model == 0 || model == 1))
	{
		model = 2;
	}
	if (model == 0)
	{
		ammo = 30;
	}
	else if (model == 1)
	{
		ammo = 150;
	}
	else
	{
		ammo = 0;
	}
	weapon = CreateEntity(spweapon_Scripts[model]);
	if (weapon == -1)
	{
		ThrowError("Failed to create entity %s.",spweapon_Scripts[model]);
	}
	LogMessage("drop model=%d,%s", model, spweapon_Scripts[model]);
	DispatchSpawn(weapon);
	if (model == 0 || model == 1)
	{
		SetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo", ammo, 4);
	}
	return weapon;
}

C_Generade()
{
	new weapon = -1;
	new model = GetRandomInt(0, 2);
	weapon = CreateEntity(generade_Scripts[model]);
	if (weapon == -1)
	{
		ThrowError("Failed to create entity %s.",generade_Scripts[model]);
	}
	LogMessage("drop model=%d,%s", model, generade_Scripts[model]);
	DispatchSpawn(weapon);
	return weapon;
}

C_Medkit()
{
	new weapon = -1;
	new model = GetRandomInt(0, 3);
	weapon = CreateEntity(medkit_Scripts[model]);
	if (weapon == -1)
	{
		ThrowError("Failed to create entity %s.",medkit_Scripts[model]);
	}
	LogMessage("drop model=%d,%s", model, medkit_Scripts[model]);
	if (StrEqual(medkit_Scripts[model],"weapon_defibrillator",false))
	{
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", MODEL_DEFIB);
	}
	DispatchSpawn(weapon);
	return weapon;
}

C_UpGAndCan()
{
	new weapon = -1;
	new model = GetRandomInt(0, 5);
	weapon = CreateEntity(upgcan_Scripts[model]);
	if (weapon == -1)
	{
		ThrowError("Failed to create entity %s.",upgcan_Scripts[model]);
	}
	LogMessage("drop model=%d,%s", model, upgcan_Scripts[model]);
	DispatchSpawn(weapon);
	return weapon;
}

CreateEntity(const String:name[])
{
	new entity = CreateEntityByName(name);
	return entity;
}

public Action:RemoveGun(Handle:timer, any:ref)
{
	new ent;
	if (ref && (ent = EntRefToEntIndex(ref)) != INVALID_ENT_REFERENCE)
	{
		decl String:className[64];
		GetEntityClassname(ent, className, sizeof(className));
		//LogMessage("class=%s", className);
		for (new i = 0; i < 21; i++) 
		{
            if (StrEqual(removeable_Scripts[i], className, false))
			{
				if (!HasEntProp(ent, Prop_Data, "m_iState"))
				{
					continue;
				}
				new weaponState = GetEntProp(ent, Prop_Data, "m_iState", 4, 0);
				if (weaponState == 0)
				{
					AcceptEntityInput(ent, "Kill");
					break;
				}
			}
		}
	}
}

public Action:InitHiddenWeaponsDelayed(Handle:timer, any:client)
{
	PreCacheGun("weapon_rifle_sg552");
	PreCacheGun("weapon_smg_mp5");
	PreCacheGun("weapon_sniper_awp");
	PreCacheGun("weapon_sniper_scout");
	PreCacheGun("weapon_rifle_m60");
	
	// decl String:Map[56];
	// GetCurrentMap(Map, sizeof(Map));
	//LogMessage("Hidden weapon initialization.");
	//ForceChangeLevel(Map, "Hidden weapon initialization.");			// plugin start change  map 已由其他插件实现
}

static PreCacheGun(const String:GunEntity[])
{
	new index = CreateEntityByName(GunEntity);
	DispatchSpawn(index);
	RemoveEdict(index);
}

Precache()
{
	// CSS weapons
	if (!IsModelPrecached("models/v_models/v_rif_sg552.mdl"))
	{
		PrecacheModel("models/v_models/v_rif_sg552.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_rifle_sg552.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_rifle_sg552.mdl", true);
	}
	if (!IsModelPrecached("models/v_models/v_smg_mp5.mdl"))
	{
		PrecacheModel("models/v_models/v_smg_mp5.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_smg_mp5.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_smg_mp5.mdl", true);
	}
	if (!IsModelPrecached("models/v_models/v_snip_awp.mdl"))
	{
		PrecacheModel("models/v_models/v_snip_awp.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_awp.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_sniper_awp.mdl", true);
	}
	if (!IsModelPrecached("models/v_models/v_snip_scout.mdl"))
	{
		PrecacheModel("models/v_models/v_snip_scout.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_scout.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl");	
	}
	if (!IsModelPrecached("models/v_models/v_knife_t.mdl"))
	{
		PrecacheModel("models/v_models/v_knife_t.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_knife_t.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_knife_t.mdl", true);
	}
	if (!IsModelPrecached("models/v_models/v_snip_scout.mdl"))
	{
		PrecacheModel("models/v_models/v_snip_scout.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_scout.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl", true);
	}
	
	// M60
	if (!IsModelPrecached("models/v_models/v_m60.mdl"))
	{
		PrecacheModel("models/v_models/v_m60.mdl", true);
	}
	if (!IsModelPrecached("models/w_models/weapons/w_m60.mdl"))
	{
		PrecacheModel("models/w_models/weapons/w_m60.mdl", true);
	}
	
	// Melee weapons	
	if (!IsModelPrecached("models/weapons/melee/v_bat.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_bat.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_bat.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_bat.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_cricket_bat.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_cricket_bat.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_cricket_bat.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_cricket_bat.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_crowbar.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_crowbar.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_crowbar.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_crowbar.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_electric_guitar.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_electric_guitar.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_electric_guitar.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_electric_guitar.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_fireaxe.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_fireaxe.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_fireaxe.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_fireaxe.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_frying_pan.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_frying_pan.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_frying_pan.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_frying_pan.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_golfculb.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_golfculb.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_golfculb.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_golfculb.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_katana.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_katana.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_katana.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_katana.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_machete.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_machete.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_machete.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_machete.mdl", true);
	}
	/*
	if (!IsModelPrecached("models/weapons/melee/v_riotshield.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_riotshield.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_riotshield.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_riotshield.mdl", true);
	}
	*/
	if (!IsModelPrecached("models/weapons/melee/v_tonfa.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_tonfa.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_tonfa.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_tonfa.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_pitchfork.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_pitchfork.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_pitchfork.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_pitchfork.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/v_shovel.mdl"))
	{
		PrecacheModel("models/weapons/melee/v_shovel.mdl", true);
	}
	if (!IsModelPrecached("models/weapons/melee/w_shovel.mdl"))
	{
		PrecacheModel("models/weapons/melee/w_shovel.mdl", true);
	}
}

GetRgbInt(red, green, blue)
{
	return (blue * 65536) + (green * 256) + red;
}