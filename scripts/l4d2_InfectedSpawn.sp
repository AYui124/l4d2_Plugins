#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "1.6"

//pz constants (for SI type checking)
#define IS_SMOKER	1
#define IS_BOOMER	2
#define IS_HUNTER	3
#define IS_SPITTER	4
#define IS_JOCKEY	5
#define IS_CHARGER	6
#define IS_TANK		8

//pz constants (for spawning)
#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5
#define SI_TANK			6

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new siCount;
new siLimit;
new Handle:handleSurvivorCount;
new Handle:handleSpawnEnabled;
new bool:musicPlaying;
new bool:leftSafeRoom;
new bool:firstSpawn;
new spawnCounts[7];


new musicNeedStop;
new musicType;
new infectType;
new musicTimeCount;

new Handle:handleTankWeight;
new Handle:handleTankWeightNearbyWitchBonus;
new Handle:handleHunterWeight;
new Handle:handleBoomerWeight;
new Handle:handleSmokerWeight;
new Handle:handleJockeyWeight;
new Handle:handleChargerWeight;
new Handle:handleSpitterWeight;

new Handle:handleSpawnTimeMax;
new Handle:handleSpawnTimeMin;
new Handle:handleMusicEnable;
new Handle:handleMusicSpawnInterval;
new Handle:handleMusicRate;

public Plugin myinfo = 
{
	name = "l4d2_InfectedSpawn",
	author = PLUGIN_AUTHOR,
	description = "Custom Special Infected Auto Spawner",
	version = PLUGIN_VERSION,
	url = "N/A"
};

new String:spawns[7][16] = {"smoker auto","boomer auto","hunter auto","spitter auto","jockey auto","charger auto","tank auto"};
new const String:RELATIVE_SOUND_PATH[5][128] =
{
	"music/flu/jukebox/all_i_want_for_xmas.wav", 
	"music/flu/jukebox/badman.wav", 
	"music/flu/jukebox/midnightride.wav", 
	"music/flu/jukebox/portal_still_alive.wav", 
	"music/flu/jukebox/re_your_brains.wav"
};

public void OnPluginStart()
{
	CreateConVar("l4d_is_version", PLUGIN_VERSION, "Infected Spawn Version",  FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	handleTankWeight = CreateConVar("l4d_is_tank_weight", "30", "生成tank权重");
	handleTankWeightNearbyWitchBonus = CreateConVar("l4d_is_tank_weight_bonus", "10","附近有witch时tank权重附加倍率(需要witchdrop.smx)");
	handleHunterWeight = CreateConVar("l4d_is_hunter_weight", "100", "生成hunter权重");
	handleBoomerWeight = CreateConVar("l4d_is_boomer_weight", "100", "生成boomer权重");
	handleSmokerWeight = CreateConVar("l4d_is_smoker_weight", "100", "生成smoker权重");
	handleJockeyWeight = CreateConVar("l4d_is_jockey_weight", "100", "生成jockey权重");
	handleChargerWeight = CreateConVar("l4d_is_charger_weight", "100", "生成charger权重");
	handleSpitterWeight = CreateConVar("l4d_is_spitter_weight", "100", "生成spitter权重");
	
	handleSpawnTimeMax = CreateConVar("l4d_is_time_max", "6.0", "最大生成间隔", 0, true, 0.0, true, 30.0);
	handleSpawnTimeMin = CreateConVar("l4d_is_time_min", "1.0", "最小生成间隔", 0, true, 0.1, true, 16.0);
	handleMusicEnable = CreateConVar("l4d_is_music_enable", "1", "允许播放音乐，音乐播放时仅生成一种特感");
	handleMusicSpawnInterval = CreateConVar("l4d_is_music_spawn_interval", "1.0", "播放音乐时的特感生成间隔");
	handleMusicRate = CreateConVar("l4d_is_music_rate", "1", "允许播放音乐的几率(每20波特感)");
	//AutoExecConfig(true, "l4d2_InfectedSpawn");
	handleSpawnEnabled = CreateConVar("l4d_is_spawn_enabled", "1", "是否生成特感");
	handleSurvivorCount = CreateConVar("custom_survivor_count", "1", "幸存者人数(决定特感上限)");

	CreateConVar("tank_rate_up", "0", "", FCVAR_DONTRECORD);
	
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);
	//SetConVarInt(FindConVar("z_attack_flow_range"), 50000);
	SetConVarInt(FindConVar("z_spawn_range"), 800);
	SetConVarInt(FindConVar("z_spawn_safety_range"), 400);
	SetConVarInt(FindConVar("z_cooldown_spawn_safety_range"), 500);
	SetConVarInt(FindConVar("z_finale_spawn_safety_range"), 400);
	SetConVarInt(FindConVar("director_no_specials"), 1);
	//SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);
	
	HookEvents();
}

HookEvents()
{
	HookEvent("round_start", EventRoundStart, EventHookMode_Post);
	HookEvent("round_end", EventRoundEnd, EventHookMode_Pre);
	HookEvent("map_transition", EventRoundEnd, EventHookMode_Pre);
	HookEvent("tank_spawn", EventTankSpawn);
}

public OnMapStart()
{
	PrecacheModel("models/infected/witch.mdl");
	PrecacheModel("models/infected/witch_bride.mdl");
	PrecacheSound( RELATIVE_SOUND_PATH[0]);
	PrecacheSound( RELATIVE_SOUND_PATH[1]);
	PrecacheSound( RELATIVE_SOUND_PATH[2]);
	PrecacheSound( RELATIVE_SOUND_PATH[3]);
	PrecacheSound( RELATIVE_SOUND_PATH[4]);
}

public OnMapEnd()
{
	leftSafeRoom = false;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (!leftSafeRoom)
	{
		leftSafeRoom = true;
		StartSpawnTimer();
	}
}

StartSpawnTimer()
{
	new Float:time;
	CountSpecialInfected();
	new survivorCount = GetConVarInt(handleSurvivorCount);
	if (survivorCount > 0)
	{
		siLimit = CalucateSiLimit();
	}
	else
	{
		siLimit = GetSurvivorCount(false);
	}

	if (musicPlaying)
	{
		time = GetConVarFloat(handleMusicSpawnInterval);
		if(survivorCount>0)
		{
			siLimit = siLimit + GetRandomInt(0, 2);
		}
	}
	else
	{
		new Float:min = GetConVarFloat(handleSpawnTimeMax);
		new Float:max = GetConVarFloat(handleSpawnTimeMin);
		time = GetRandomFloat(min, max);
	}
	//LogMessage("SpawnTimer surCount=%d,silimit=%d,time=%f", survivorCount, siLimit, time);
	CreateTimer(time, SpawnInfectedAuto);
}

StartCustomSpawnTimer(Float:time)
{
	//LogMessage("CustomSpawnTimer");
	CreateTimer(time, SpawnInfectedAuto);
}

CountSpecialInfected()
{
	//reset counter
	siCount = 0;
	
	//First we count the amount of infected players
	for (new i = 1; i <= MaxClients; i++)
	{
		//If player is not connected ...
		if (!IsClientConnected(i)) continue;
		
		//We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		//Check if client is infected ...
		if (GetClientTeam(i) == 3)
			siCount++;
	}
}

CalucateSiLimit()
{
	new survivorCount = GetConVarInt(handleSurvivorCount);
	if(survivorCount <= 0)
	{
		return GetSurvivorCount(false);
	}
	else if(survivorCount <= 1)
	{
		return survivorCount + GetRandomInt(0, 1);
	}
	else if(survivorCount <= 6)
	{
		return survivorCount + GetRandomInt(0, 2);
	}
	else if(survivorCount <= 12)
	{
		return survivorCount + GetRandomInt(1, 2);
	}
	else if(survivorCount <= 16)
	{
		return survivorCount + GetRandomInt(2, 3);
	}
	
	return survivorCount;
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

public Action:SpawnInfectedAuto(Handle:timer)
{
	new spawnTimerEnabled = GetConVarInt(handleSpawnEnabled);
	if(spawnTimerEnabled == 0)
	{
		//LogMessage("Wait 5 sec: Not Enabled");
		StartCustomSpawnTimer(5.0);
		return Plugin_Continue;
	}
	if (leftSafeRoom) //only spawn infected and repeat spawn timer when survivors have left safe room
	{
		new client = GetAnyClient();
		if (client) //make sure client is in-game
		{
			GenerateSpawn(client);
			StartSpawnTimer();
		}
		else
		{
			//longer timer for when invalid client was returned (prevent a potential infinite loop when there are 0 SI)
			//LogMessage("Wait 5 sec: No valid client");
			StartCustomSpawnTimer(5.0);
		}
	}
	else
	{
		//LogMessage("Wait 5 sec: Not leave saferoom");
		StartCustomSpawnTimer(5.0);
	}
	if (musicPlaying == false)
	{
		new enabled = GetConVarInt(handleMusicEnable);
		if(enabled == 1)
		{
			RandomMusic();
		}
	}
	return Plugin_Continue;
}

GenerateSpawn(client)
{
	CountSpecialInfected(); //refresh infected count
	if (siCount < siLimit) //spawn when infected count hasn't reached limit
	{
		new size;
		if (20 > siLimit - siCount) //prevent amount of special infected from exceeding SILimit
			size = siLimit - siCount;
		else
			size = 20;
			
		if (firstSpawn)
		{
			if (size > 4)
				size = 4;//improve network
		}
		
		new index;
		new spawnQueue[28] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
		
		//refresh current SI counts
		SITypeCount();
		
		//generate the spawn queue
		for (new i = 0; i < size; i++)
		{
			if (musicPlaying)
				index = infectType;
			else
				index = GenerateIndex();
			if (index == -1)
				break;
			spawnQueue[i]= index;
			spawnCounts[index] += 1;
		}
		
		for (new i = 0; i < 28; i++)
		{
			if(spawnQueue[i] < 0) //stops if the current array index is out of bound
				break;
			new bot = CreateFakeClient("Infected Bot");
			if (bot != 0)
			{
				ChangeClientTeam(bot, 3);
				CreateTimer(0.1, KickBot, bot);
			}
			CheatCommand(client, "z_spawn_old", spawns[spawnQueue[i]]); 
			firstSpawn = false;
		
		}
	}
}

SITypeCount() //Count the number of each SI ingame
{
	for (new i = 0; i < 7; i++)
		spawnCounts[i] = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		//If player is not connected ...
		if (!IsClientConnected(i)) continue;
		
		//We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		//Check if client is infected ...
		if (GetClientTeam(i) == 3)
		{
			switch (GetEntProp(i,Prop_Send,"m_zombieClass")) //detect SI type
			{
				case IS_SMOKER:
					spawnCounts[SI_SMOKER]++;
				
				case IS_BOOMER:
					spawnCounts[SI_BOOMER]++;
				
				case IS_HUNTER:
					spawnCounts[SI_HUNTER]++;
				
				case IS_SPITTER:
					spawnCounts[SI_SPITTER]++;
				
				case IS_JOCKEY:
					spawnCounts[SI_JOCKEY]++;
				
				case IS_CHARGER:
					spawnCounts[SI_CHARGER]++;
				
				case IS_TANK:
					spawnCounts[SI_TANK]++;
			}
		}
	}
}

GenerateIndex()
{
	new rateUp = GetConVarInt(FindConVar("tank_rate_up"));
	new totalSpawnWeight, standardizedSpawnWeight;
	new Float:r = GetRandomFloat(0.0, 1.0);
	new infectWeight[7];
	infectWeight[0] = GetConVarInt(handleSmokerWeight);
	infectWeight[1] = GetConVarInt(handleBoomerWeight);
	infectWeight[2] = GetConVarInt(handleHunterWeight);
	infectWeight[3] = GetConVarInt(handleSpitterWeight);
	infectWeight[4] = GetConVarInt(handleJockeyWeight);
	infectWeight[5] = GetConVarInt(handleChargerWeight);
	infectWeight[6] = GetConVarInt(handleTankWeight);

	new spawnLimits[7] =  { 4, 6, 5, 8, 6, 5, 4 };
	decl tempSpawnWeights[7];
	new Float:intervalWeight[7];

	for(new i = 0; i < 7; i++)
	{
		if(spawnCounts[i] < spawnLimits[i])
		{
			tempSpawnWeights[i] = (spawnLimits[i] - spawnCounts[i]) * infectWeight[i];
		}
		else
			tempSpawnWeights[i] = 0;
		
		totalSpawnWeight += tempSpawnWeights[i];
	}
	if(rateUp == 1)
	{
		new bonus = GetConVarInt(handleTankWeightNearbyWitchBonus);
		if(bonus>0) 
		{
			tempSpawnWeights[6] = tempSpawnWeights[6] * bonus;
			totalSpawnWeight += tempSpawnWeights[6] * (bonus - 1);
		}
	}
	new Float:unit = 1.0/totalSpawnWeight;
	for (new i = 0; i < 7; i++)
	{
		if (tempSpawnWeights[i] >= 0)
		{
			standardizedSpawnWeight += tempSpawnWeights[i];
			intervalWeight[i] = standardizedSpawnWeight * unit;
		}
	}
	for (new i = 0; i < 7; i++)
	{
		//negative and 0 weights are ignored
		if (tempSpawnWeights[i] <= 0) continue;
		//r is not within the ith interval
		if (intervalWeight[i] < r) continue;
		//selected index i because r is within ith interval
		return i;
	}
	return -1; //no selection because all weights were negative or 0
}

public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	//and we reset some variables
	SetConVarInt(handleSpawnEnabled, 0);
	leftSafeRoom = false;
	musicTimeCount = 0;
	musicPlaying = false;
	infectType = 0;
	firstSpawn = true;
	CreateTimer(60.0, FixNoSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:FixNoSpawn(Handle:timer)
{
	leftSafeRoom = true;
	SetConVarInt(handleSpawnEnabled, 1);
}

public Action:EventRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{	
	leftSafeRoom = false;
	musicTimeCount = 0;
	if(musicPlaying)
	{
		StopPlayingMusic();
	}
}

public Action:EventTankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	//LogMessage("Tank Spawn");
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(2.0, LeaveStasis, client);
}

public Action:LeaveStasis(Handle:timer, any:client)
{
	if ((client < 1) || (client > MaxClients) || !IsClientInGame(client) || !IsFakeClient(client))
		return;
	//LogMessage("Call DealDamage:%d", client);
	DealDamage(client, 0, GetRandomSurvivor(), DMG_BULLET, "weapon_rifle_ak47");
}

public int GetRandomSurvivor() 
{
	int survivors[MAXPLAYERS];
	int numSurvivors = 0;
	for( int i = 0; i < MAXPLAYERS; i++ )
	{
		if(IsValidSurvivor(i,true) && IsPlayerAlive(i)) 
		{
		    survivors[numSurvivors] = i;
		    numSurvivors++;
		}
	}
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}

DealDamage(int victim, int damage, int attacker = 0, int dmg_type = DMG_GENERIC, char[] weapon = "")
{
	if(victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim))
	{
		char dmg_str[16];
		IntToString(damage,dmg_str,16);
		char dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		int pointHurt=CreateEntityByName("point_hurt");
		if (pointHurt)
		{
			DispatchKeyValue(victim,"targetname","war3_hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","war3_hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

RandomMusic()
{
	new bool:start = false;
	if(musicTimeCount >= 100)
	{
		musicTimeCount = 0;
		start = true;
	}
	else
	{
		musicTimeCount++;
	}
	if(start==false)
	{
		return;
	}
	new rate = GetConVarInt(handleMusicRate);
	new musicRate = GetRandomInt(1, 100);
	if (musicRate <= rate)
	{
		CreateTimer(0.1, StartMusic, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:StartMusic(Handle:timer)
{
	musicPlaying = true;
	infectType = GetRandomInt(0, 5);
	new Float:time = 0.0;
	musicType = GetRandomInt(1, 5);
	switch(musicType)
	{
		case 1:
		{
			time = 211.0;
		}
		case 2:
		{
			time = 198.0;
		}
		case 3:
		{
			time = 208.0;
		}
		case 4:
		{
			time = 190.0;
		}
		case 5:
		{
			time = 284.0;
		}
	}
	musicNeedStop = true;
	CreateTimer(time, StopMusic, _, TIMER_FLAG_NO_MAPCHANGE);
	EmitSoundToAll(RELATIVE_SOUND_PATH[musicType-1], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0 );
}

public Action:StopMusic(Handle:timer)
{
	if(musicNeedStop)
	{
		musicNeedStop = false;
		StopPlayingMusic();
	}
}

StopPlayingMusic()
{
	musicPlaying = false;
	if(musicType >= 1)
	{
		for(new i=1; i<=MaxClients; i++) 
		{
			if (IsClientInGame(i))
			{
				StopSound(i, SNDCHAN_AUTO, RELATIVE_SOUND_PATH[musicType - 1]);
			}
		}
	}
}

public GetAnyClient ()
{
	for (new  i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i)))
			return i;
	}
	return 0;
}

bool:IsValidSurvivor(client, bool:allowbots)
{
	if ((client < 1) || (client > MaxClients)) { return false; }
	if (!IsClientInGame(client) || !IsClientConnected(client)) { return false; }
	if (GetClientTeam(client) != 2) { return false; }
	if (IsFakeClient(client) && !allowbots) { return false; }
	return true;
}

CheatCommand(client, String:command[], String:arguments[] = "")
{
	if (!client || !IsClientInGame(client))
	{
		for (new target = 1; target <= MaxClients; target++)
		{
			client = target;
			break;
		}
		
		return; // case no valid Client found
	}
	
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

public Action:KickBot(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client))
		{
			KickClient(client);
		}
	}
}



