#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.2"

#define DEBUG_GENERAL 0
#define DEBUG_TIMES 0
#define DEBUG_SPAWNS 0
#define DEBUG_WEIGHTS 0
#define DEBUG_EVENTS 0

// Uncommons Debug
//#define DEBUG 1


#define MAX_INFECTED 28
#define NUM_TYPES_INFECTED 7

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3

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

//make sure spawn names and ordering match pz constants
new String:Spawns[NUM_TYPES_INFECTED][16] = {"smoker auto","boomer auto","hunter auto","spitter auto","jockey auto","charger auto","tank auto"};
new const String:RELATIVE_SOUND_PATH[5][128] =
{
	"music/flu/jukebox/all_i_want_for_xmas.wav", 
	"music/flu/jukebox/badman.wav", 
	"music/flu/jukebox/midnightride.wav", 
	"music/flu/jukebox/portal_still_alive.wav", 
	"music/flu/jukebox/re_your_brains.wav"
};

enum L4D2_Team {
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum L4D2_Infected {
    L4D2Infected_Smoker = 1,
    L4D2Infected_Boomer,
    L4D2Infected_Hunter,
    L4D2Infected_Spitter,
    L4D2Infected_Jockey,
    L4D2Infected_Charger,
    L4D2Infected_Witch,
    L4D2Infected_Tank
};

// alternative enumeration
// Special infected classes
enum ZombieClass {
    ZC_NONE = 0, 
    ZC_SMOKER, 
    ZC_BOOMER, 
    ZC_HUNTER, 
    ZC_SPITTER, 
    ZC_JOCKEY, 
    ZC_CHARGER, 
    ZC_WITCH, 
    ZC_TANK, 
    ZC_NOTINFECTED
};

new rate1;
new Handle:OKindTimer;
//new Float:g_fTimeLOS[100000];

new limit;
new TankRate;
new SICount;
new SILimit;
new SpawnSize;
new SpawnTimeMode;
new GameMode;

new Float:SpawnTimeMin;
new Float:SpawnTimeMax;
new Float:SpawnTimes[MAX_INFECTED+1];

new SpawnWeights[NUM_TYPES_INFECTED];
new SpawnLimits[NUM_TYPES_INFECTED];
new SpawnCounts[NUM_TYPES_INFECTED];
new Handle:hSpawnWeights[NUM_TYPES_INFECTED];
new Handle:hSpawnLimits[NUM_TYPES_INFECTED];
new Float:IntervalEnds[NUM_TYPES_INFECTED];

new bool:Enabled;
new bool:EventsHooked;
new bool:SafeRoomChecking;
new bool:FasterResponse;
new bool:FasterSpawn;
new bool:SafeSpawn;
new bool:ScaleWeights;
new bool:ChangeByConstantTime;
new bool:SpawnTimerStarted;
new bool:WitchTimerStarted;
new bool:WitchWaitTimerStarted;
new bool:WitchCountFull;
new bool:RoundStarted;
new bool:RoundEnded;
new bool:LeftSafeRoom;


new Handle:hEnabled;
new Handle:hDisableInVersus;
new Handle:hFasterResponse;
new Handle:hFasterSpawn;
new Handle:hSafeSpawn;
new Handle:hSILimit;
new Handle:hSILimitMax;
new Handle:hScaleWeights;
new Handle:hSpawnSize;
new Handle:hSpawnTimeMin;
new Handle:hSpawnTimeMax;
new Handle:hSpawnTimer;
new Handle:hSpawnTimeMode;
new Handle:hGameMode;

new WitchCount;
new WitchLimit;
new Float:WitchPeriod;
new bool:VariableWitchPeriod;
new Handle:hWitchLimit;
new Handle:hWitchPeriod;
new Handle:hWitchPeriodMode;
new Handle:hWitchTimer;
new Handle:hWitchWaitTimer;

new bool:CmdCallEnabled;
new bool:IsCmdCallContinuing;
new OneKind;
new bool:FirstSpawn;

new Handle:hCSL;
new Handle:hTankRate;


public Plugin:myinfo =  
{
	name = "L4D2 Auto Infected Spawner",
	author = "Tordecybombo ,, FuzzOne - miniupdate ,, TacKLER - miniupdate again//Yui changeable SICount modified",
	description = "Custom automatic infected spawner",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public OnPluginStart()
{

	new Handle:survLimit = FindConVar("survivor_limit");
	SetConVarBounds(survLimit , ConVarBound_Upper, true, 12.0);

	new Handle:zombiePlayerLimit = FindConVar("z_max_player_zombies");
	SetConVarBounds(zombiePlayerLimit , ConVarBound_Upper, true, 12.0);
	SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, false);

	new Handle:zombie_minion_l = FindConVar("z_minion_limit");
	SetConVarBounds(zombie_minion_l , ConVarBound_Upper, true, 12.0);
	
	new Handle:zombie_surv = FindConVar("survival_max_specials");
	SetConVarBounds(zombie_surv , ConVarBound_Upper, true, 12.0);
	

	//l4d2 check
	decl String:mod[32];
	GetGameFolderName(mod, sizeof(mod));
	if(!StrEqual(mod, "left4dead2", false))
		SetFailState("[AIS] This plugin is for Left 4 Dead 2 only.");
	
	//hook events
	HookEvents();
	//witch events should not be unhooked to keep witch count working even when plugin is off
	HookEvent("witch_spawn", evtWitchSpawn);
	HookEvent("witch_killed", evtWitchKilled);
	
	//HookEvent("player_spawn", evtPlayerSpawn);
	//HookEvent("witch_harasser_set", evtWitchHarasse);
	
	RegAdminCmd("sm_St1", SetOnly1KindSI, ADMFLAG_CHEATS);
	RegAdminCmd("sm_Sp1", StopOnly1KindSI, ADMFLAG_CHEATS);
	//admin commands
	RegAdminCmd("l4d2_ais_reset", ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("l4d2_ais_start", StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	RegAdminCmd("l4d2_ais_time", SetConstantSpawnTime, ADMFLAG_CHEATS, "Set a constant spawn time (seconds) by setting l4d2_ais_time_min and l4d2_ais_time_max to the same value.");
	RegAdminCmd("l4d2_ais_preset", PresetWeights, ADMFLAG_CHEATS, "<default|none|boomer|smoker|hunter|tank|charger|jockey|spitter> Set spawn weights to given presets");
	
	//version cvar
	CreateConVar("l4d2_ais_version", PLUGIN_VERSION, "Auto Infected Spawner Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	//console variables and handles
	hEnabled = CreateConVar("l4d2_ais_enabled", "1", "[0=OFF|1=ON] Disable/Enable functionality of the plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hDisableInVersus = CreateConVar("l4d2_ais_disable_in_versus", "1", "[0=OFF|1=ON] Automatically disable plugin in versus mode", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hFasterResponse = CreateConVar("l4d2_ais_fast_response", "1", "[0=OFF|1=ON] Disable/Enable faster special infected response", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hFasterSpawn = CreateConVar("l4d2_ais_fast_spawn", "1", "[0=OFF|1=ON] Disable/Enable faster special infected spawn (Enable when SI spawn rate is high)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hSafeSpawn = CreateConVar("l4d2_ais_safe_spawn", "0", "[0=OFF|1=ON] Disable/Enable special infected spawning while survivors are in safe room", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hSpawnWeights[SI_BOOMER] = CreateConVar("l4d2_ais_boomer_weight", "100", "The weight for a boomer spawning", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_HUNTER] = CreateConVar("l4d2_ais_hunter_weight", "100", "The weight for a hunter spawning", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_SMOKER] = CreateConVar("l4d2_ais_smoker_weight", "100", "The weight for a smoker spawning", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_TANK] = CreateConVar("l4d2_ais_tank_weight", "100", "[-1 = Director spawns tanks] The weight for a tank spawning", FCVAR_PLUGIN, true, -1.0);
	hSpawnWeights[SI_CHARGER] = CreateConVar("l4d2_ais_charger_weight", "100", "The weight for a charger spawning", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_JOCKEY] = CreateConVar("l4d2_ais_jockey_weight", "100", "The weight for a jockey spawning", FCVAR_PLUGIN, true, 0.0);
	hSpawnWeights[SI_SPITTER] = CreateConVar("l4d2_ais_spitter_weight", "100", "The weight for a spitter spawning", FCVAR_PLUGIN, true, 0.0);
	hSpawnLimits[SI_BOOMER] = CreateConVar("l4d2_ais_boomer_limit", "8", "The max amount of boomers present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_HUNTER] = CreateConVar("l4d2_ais_hunter_limit", "8", "The max amount of hunters present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_SMOKER] = CreateConVar("l4d2_ais_smoker_limit", "8", "The max amount of smokers present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_TANK] = CreateConVar("l4d2_ais_tank_limit", "8", "The max amount of tanks present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_CHARGER] = CreateConVar("l4d2_ais_charger_limit", "8", "The max amount of chargers present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_JOCKEY] = CreateConVar("l4d2_ais_jockey_limit", "8", "The max amount of jockeys present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hSpawnLimits[SI_SPITTER] = CreateConVar("l4d2_ais_spitter_limit", "8", "The max amount of spitters present at once", FCVAR_PLUGIN, true, 0.0, true, 14.0);
	hScaleWeights = CreateConVar("l4d2_ais_scale_weights", "1", "[0=OFF|1=ON] Scale spawn weights with the limits of corresponding SI", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hWitchLimit = CreateConVar("l4d2_ais_witch_limit", "-1", "[-1 = Director spawns witches] The max amount of witches present at once (independant of l4d2_ais_limit).", FCVAR_PLUGIN, true, -1.0, true, 100.0);
	hWitchPeriod = CreateConVar("l4d2_ais_witch_period", "180.0", "The time (seconds) interval in which exactly one witch will spawn", FCVAR_PLUGIN, true, 1.0);
	hWitchPeriodMode = CreateConVar("l4d2_ais_witch_period_mode", "1", "The witch spawn rate consistency [0=CONSTANT|1=VARIABLE]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hSILimit = CreateConVar("l4d2_ais_limit", "24", "The max amount of special infected at once", FCVAR_PLUGIN, true, 1.0, true, float(MAX_INFECTED));
	hSILimitMax = FindConVar("z_max_player_zombies");
	hSpawnSize = CreateConVar("l4d2_ais_spawn_size", "20", "The amount of special infected spawned at each spawn interval", FCVAR_PLUGIN, true, 1.0, true, float(MAX_INFECTED));
	hSpawnTimeMode = CreateConVar("l4d2_ais_time_mode", "0", "The spawn time mode [0=RANDOMIZED|1=INCREMENTAL|2=DECREMENTAL]", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	//hSpawnTimeFunction = CreateConVar("l4d2_ais_time_function", "0", "The spawn time function [0=LINEAR|1=EXPONENTIAL|2=LOGARITHMIC]", FCVAR_PLUGIN, true, 0.0, true 2.0);
	hSpawnTimeMin = CreateConVar("l4d2_ais_time_min", "1.0", "The minimum auto spawn time (seconds) for infected", FCVAR_PLUGIN, true, 0.0);
	hSpawnTimeMax = CreateConVar("l4d2_ais_time_max", "8.0", "The maximum auto spawn time (seconds) for infected", FCVAR_PLUGIN, true, 1.0);
	hCSL = CreateConVar("custom_si_limit", "8");
	hTankRate = CreateConVar("AutoSI_TankRateUp", "0");
	hGameMode = FindConVar("mp_gamemode");
	//hook cvar changes to variables
	HookConVarChange(hEnabled, ConVarEnabled);
	HookConVarChange(hFasterResponse, ConVarFasterResponse);
	HookConVarChange(hFasterSpawn, ConVarFasterSpawn);
	HookConVarChange(hSafeSpawn, ConVarSafeSpawn);
	HookConVarChange(hScaleWeights, ConVarScaleWeights);
	HookConVarChange(hSILimit, ConVarSILimit);
	HookConVarChange(hSpawnSize, ConVarSpawnSize);
	HookConVarChange(hSpawnTimeMode, ConVarSpawnTimeMode);
	HookConVarChange(hSpawnTimeMin, ConVarSpawnTime);
	HookConVarChange(hSpawnTimeMax, ConVarSpawnTime);
	HookConVarChangeSpawnWeights(); //hooks all SI weights
	HookConVarChangeSpawnLimits();
	HookConVarChange(hGameMode, ConVarGameMode);
	HookConVarChange(hWitchLimit, ConVarWitchLimit);
	HookConVarChange(hWitchPeriod, ConVarWitchPeriod);
	HookConVarChange(hWitchPeriodMode, ConVarWitchPeriodMode);
	HookConVarChange(hCSL, ConVarCSL);
    HookConVarChange(hTankRate, ConVarTankRate);
	//set console variables
	EnabledCheck(); //sets Enabled, FasterResponse, FasterSpawn, and cvars
	SafeSpawn = GetConVarBool(hSafeSpawn);
	SILimit = GetConVarInt(hSILimit);
	SpawnSize = GetConVarInt(hSpawnSize);
	SpawnTimeMode = GetConVarInt(hSpawnTimeMode);
	SetSpawnTimes(); //sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	SetSpawnWeights(); //sets SpawnWeights[]
	SetSpawnLimits(); //sets SpawnLimits[]
	WitchLimit = GetConVarInt(hWitchLimit);
	WitchPeriod = GetConVarFloat(hWitchPeriod);
	VariableWitchPeriod = GetConVarBool(hWitchPeriodMode);
	
	//set other variables
	ChangeByConstantTime = false;
	RoundStarted = false;
	RoundEnded = false;
	LeftSafeRoom = false;
	
	SetConVarInt(FindConVar("director_no_specials"), 1);
	//autoconfig executed on every map change
	AutoExecConfig(true, "l4d2_autoIS_lichpinver");
}

public OnConfigsExecuted()
{
	SetCvars(); //refresh cvar settings in case they change
	GameModeCheck();
	
	if (GameMode == 2 && GetConVarBool(hDisableInVersus)) //disable in versus
		SetConVarBool(hEnabled, false);
}

HookEvents()
{
	if (!EventsHooked)
	{
		EventsHooked = true;
		//MI 5, We hook the round_start (and round_end) event on plugin start, since it occurs before map_start
		HookEvent("round_start", evtRoundStart, EventHookMode_Post);
		HookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
		//hook other events
		HookEvent("map_transition", evtRoundEnd, EventHookMode_Pre); //also stop spawn timers upon map transition
		HookEvent("create_panic_event", evtSurvivalStart);
		HookEvent("player_death", evtInfectedDeath);	
		HookEvent("tank_spawn", evtTankSpawn);
		#if DEBUG_EVENTS
		LogMessage("[AIS] Events Hooked");
		#endif
	}
}
UnhookEvents()
{
	if (EventsHooked)
	{
		EventsHooked = false;
		UnhookEvent("round_start", evtRoundStart, EventHookMode_Post);
		UnhookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
		UnhookEvent("map_transition", evtRoundEnd, EventHookMode_Pre);
		UnhookEvent("create_panic_event", evtSurvivalStart);
		UnhookEvent("player_death", evtInfectedDeath);
		UnhookEvent("tank_spawn", evtTankSpawn);
		#if DEBUG_EVENTS
		LogMessage("[AIS] Events Unhooked");
		#endif
	}
}

public OnClientPostAdminCheck(client)
{
	//SDKHook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
}

HookConVarChangeSpawnWeights()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		HookConVarChange(hSpawnWeights[i], ConVarSpawnWeights);
}

HookConVarChangeSpawnLimits()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		HookConVarChange(hSpawnLimits[i], ConVarSpawnLimits);
}

SetSpawnLimits()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		SpawnLimits[i] = GetConVarInt(hSpawnLimits[i]);
}

public ConVarEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	EnabledCheck();
}
public ConVarFasterResponse(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetAIDelayCvars();
}
public ConVarFasterSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetAISpawnCvars();
}
public ConVarSafeSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SafeSpawn = GetConVarBool(hSafeSpawn);
}
public ConVarScaleWeights(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ScaleWeights = GetConVarBool(hScaleWeights);
}
public ConVarSILimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SILimit = GetConVarInt(hSILimit); 
	CalculateSpawnTimes(); //must recalculate spawn time table to compensate for limit change
	if (LeftSafeRoom)
		StartSpawnTimer(); //restart timer after times change
}
public ConVarSpawnSize(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnSize = GetConVarInt(hSpawnSize); 
}
public ConVarSpawnTimeMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpawnTimeMode = GetConVarInt(hSpawnTimeMode);
	CalculateSpawnTimes(); //must recalculate spawn time table to compensate for mode change
	if (LeftSafeRoom)
		StartSpawnTimer(); //restart timer after times change
}
public ConVarSpawnTime(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!ChangeByConstantTime)
		SetSpawnTimes();
}
public ConVarSpawnWeights(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetSpawnWeights();
	if (WitchLimit < 0 && SpawnWeights[SI_TANK] >= 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 1);
		SetConVarInt(hWitchLimit, 0); 
	}
	else if (WitchLimit >= 0 && SpawnWeights[SI_TANK] < 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 0);
		SetConVarInt(hWitchLimit, -1);
	}
}
public ConVarSpawnLimits(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetSpawnLimits();
}
public ConVarWitchLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	WitchLimit = GetConVarInt(hWitchLimit);
	if (WitchLimit < 0 && SpawnWeights[SI_TANK] >= 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 0);
		SetConVarInt(hSpawnWeights[SI_TANK], -1);
	}
	else if (WitchLimit >= 0 && SpawnWeights[SI_TANK] < 0)
	{
		SetConVarInt(FindConVar("director_no_bosses"), 1);
		SetConVarInt(hSpawnWeights[SI_TANK], 0);
	}
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}
public ConVarWitchPeriod(Handle:convar, const String:oldValue[], const String:newValue[])
{
	WitchPeriod = GetConVarFloat(hWitchPeriod);
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}
public ConVarWitchPeriodMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	VariableWitchPeriod = GetConVarBool(hWitchPeriodMode);
	if (LeftSafeRoom && WitchLimit > 0)
		RestartWitchTimer(0.0); //restart timer after times change
}
public ConVarGameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GameModeCheck();
}

public ConVarCSL(Handle:convar, const String:oldValue[], const String:newValue[])
{
	limit = GetConVarInt(hCSL);
	LogMessage("si limit=%d", limit);
}

public ConVarTankRate(Handle:convar, const String:oldValue[], const String:newValue[])
{
	TankRate = GetConVarInt(hTankRate);
	if(TankRate == 1)
	{
		hSpawnWeights[SI_TANK] = hSpawnWeights[SI_TANK] * 5;
	}
	else
	{
		hSpawnWeights[SI_TANK] = hSpawnWeights[SI_TANK] / 5;
	}
}

EnabledCheck()
{
	Enabled = GetConVarBool(hEnabled);
	SetCvars();
	if (Enabled)
	{
		HookEvents();
		InitTimers();
	}
	else
		UnhookEvents();
	#if DEBUG_GENERAL
	LogMessage("[AIS] Plugin Enabled?: %b", Enabled);
	#endif
}

InitTimers()
{
	if (LeftSafeRoom)
		StartTimers();
	else if (GameMode != 3 && !SafeRoomChecking) //start safe room check in non-survival mode
	{
		SafeRoomChecking = true;
		CreateTimer(1.0, PlayerLeftStart);
	}
}

SetCvars()
{
	if (Enabled)
	{
		SetConVarBounds(hSILimitMax, ConVarBound_Upper, true, float(MAX_INFECTED));
		SetConVarFloat(hSILimitMax, float(MAX_INFECTED));
		SetConVarInt(FindConVar("z_boomer_limit"), 0);
		SetConVarInt(FindConVar("z_hunter_limit"), 0);
		SetConVarInt(FindConVar("z_smoker_limit"), 0);
		SetConVarInt(FindConVar("z_charger_limit"), 0);
		SetConVarInt(FindConVar("z_spitter_limit"), 0);
		SetConVarInt(FindConVar("z_jockey_limit"), 0);
		SetConVarInt(FindConVar("survival_max_boomers"), 0);
		SetConVarInt(FindConVar("survival_max_hunters"), 0);
		SetConVarInt(FindConVar("survival_max_smokers"), 0);
		SetConVarInt(FindConVar("survival_max_chargers"), 0);
		SetConVarInt(FindConVar("survival_max_spitters"), 0);
		SetConVarInt(FindConVar("survival_max_jockeys"), 0);	
		SetConVarInt(FindConVar("survival_max_specials"), SILimit);
		SetBossesCvar();
		SetConVarInt(FindConVar("director_spectate_specials"), 1);
	}
	else
	{
		ResetConVar(FindConVar("z_max_player_zombies"));
		ResetConVar(FindConVar("z_boomer_limit"));
		ResetConVar(FindConVar("z_hunter_limit"));
		ResetConVar(FindConVar("z_smoker_limit"));
		ResetConVar(FindConVar("z_charger_limit"));
		ResetConVar(FindConVar("z_spitter_limit"));
		ResetConVar(FindConVar("z_jockey_limit"));
		ResetConVar(FindConVar("survival_max_boomers"));
		ResetConVar(FindConVar("survival_max_hunters"));
		ResetConVar(FindConVar("survival_max_smokers"));
		ResetConVar(FindConVar("survival_max_chargers"));
		ResetConVar(FindConVar("survival_max_spitters"));
		ResetConVar(FindConVar("survival_max_jockeys"));
		ResetConVar(FindConVar("survival_max_specials"));
		ResetConVar(FindConVar("director_no_bosses"));	
		ResetConVar(FindConVar("director_spectate_specials"));
	}
	
	SetAIDelayCvars();
	SetAISpawnCvars();
}

SetBossesCvar() //both tank and witch must be handled by director or not
{
	if (WitchLimit < 0 || SpawnWeights[SI_TANK] < 0)
		SetConVarInt(FindConVar("director_no_bosses"), 0);
	else
		SetConVarInt(FindConVar("director_no_bosses"), 1);		
}

SetAIDelayCvars()
{
	FasterResponse = GetConVarBool(hFasterResponse);
	if (FasterResponse)
	{
		SetConVarInt(FindConVar("boomer_exposed_time_tolerance"), 1);			
		SetConVarInt(FindConVar("boomer_vomit_delay"), 1);
		SetConVarInt(FindConVar("smoker_tongue_delay"), 1);
		SetConVarInt(FindConVar("hunter_leap_away_give_up_range"), 1);
	}
	else
	{
		ResetConVar(FindConVar("boomer_exposed_time_tolerance"));
		ResetConVar(FindConVar("boomer_vomit_delay"));
		ResetConVar(FindConVar("smoker_tongue_delay"));
		ResetConVar(FindConVar("hunter_leap_away_give_up_range"));	
	}
}

SetAISpawnCvars()
{
	FasterSpawn = GetConVarBool(hFasterSpawn);
	if (FasterSpawn)
	{
		SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
		SetConVarInt(FindConVar("z_cooldown_spawn_safety_range"), 0);
		SetConVarInt(FindConVar("z_finale_spawn_safety_range"), 0);
	}
	else
	{
		ResetConVar(FindConVar("z_spawn_safety_range"));
		ResetConVar(FindConVar("z_finale_spawn_safety_range"));
		ResetConVar(FindConVar("z_cooldown_spawn_safety_range"));
	}
}

//MI 5
GameModeCheck()
{
	//We determine what the gamemode is
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrContains(GameName, "survival", false) != -1)
		GameMode = 1; //3
	else if (StrContains(GameName, "versus", false) != -1)
		GameMode = 1; //2
	else if (StrContains(GameName, "coop", false) != -1)
		GameMode = 1; //1
	else 
		GameMode = 1; //0
}

public Action:SetConstantSpawnTime(client, args)
{
	ChangeByConstantTime = true; //prevent conflict with hooked event change
	if (args > 0)
	{
		new Float:time = 1.0;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0)
			time = 1.0;
		SetConVarFloat(hSpawnTimeMin, time);
		SetConVarFloat(hSpawnTimeMax, time);
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		ReplyToCommand(client, "[AIS] Minimum and maximum spawn time set to %.3f seconds.", time);
	}
	else
		ReplyToCommand(client, "l4d2_ais_time <# of seconds>");
	ChangeByConstantTime = false;
}

SetSpawnTimes()
{
	SpawnTimeMin = GetConVarFloat(hSpawnTimeMin);
	SpawnTimeMax = GetConVarFloat(hSpawnTimeMax);
	if (SpawnTimeMin > SpawnTimeMax) //SpawnTimeMin cannot be greater than SpawnTimeMax
		SetConVarFloat(hSpawnTimeMin, SpawnTimeMax); //set back to appropriate limit
	else if (SpawnTimeMax < SpawnTimeMin) //SpawnTimeMax cannot be less than SpawnTimeMin
		SetConVarFloat(hSpawnTimeMax, SpawnTimeMin); //set back to appropriate limit
	else
	{
		CalculateSpawnTimes(); //must recalculate spawn time table to compensate for min change
		if (LeftSafeRoom)
			StartSpawnTimer(); //restart timer after times change	
	}
}

CalculateSpawnTimes()
{
	new i;
	if (SILimit > 1 && SpawnTimeMode > 0)
	{
		new Float:unit = (SpawnTimeMax-SpawnTimeMin)/(SILimit-1);
		switch (SpawnTimeMode)
		{
			case 1: //incremental spawn time mode
			{
				SpawnTimes[0] = SpawnTimeMin;
				for (i = 1; i <= MAX_INFECTED; i++)
				{
					if (i < SILimit)
						SpawnTimes[i] = SpawnTimes[i-1] + unit;
					else
						SpawnTimes[i] = SpawnTimeMax;
				}
			}
			case 2: //decremental spawn time mode
			{
				SpawnTimes[0] = SpawnTimeMax;
				for (i = 1; i <= MAX_INFECTED; i++)
				{
					if (i < SILimit)
						SpawnTimes[i] = SpawnTimes[i-1] - unit;
					else
						SpawnTimes[i] = SpawnTimeMax;
				}
			}
			//randomized spawn time mode does not use time tables
		}	
	}
	else //constant spawn time for if SILimit is 1
		SpawnTimes[0] = SpawnTimeMax;
	#if DEBUG_TIMES
	for (i = 0; i <= MAX_INFECTED; i++)
		LogMessage("[AIS] %d : %.5f s", i, SpawnTimes[i]);
	#endif
}

SetSpawnWeights()
{
	new i, weight, TotalWeight;
	//set and sum spawn weights
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		weight = GetConVarInt(hSpawnWeights[i]);
		SpawnWeights[i] = weight;
		if (weight >= 0)
			TotalWeight += weight;
	}
	#if DEBUG_WEIGHTS
	for (i = 0; i < NUM_TYPES_INFECTED; i++)
		LogMessage("[AIS] %s weight: %d (%.5f)", Spawns[i], SpawnWeights[i]);
	#endif
}

public Action:PresetWeights(client, args)
{
	decl String:arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (strcmp(arg, "default") == 0)
		ResetWeights();
	else if (strcmp(arg, "none") == 0)
		ZeroWeights();
	else //presets for spawning special infected i only
	{
		for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		{
			if (strcmp(arg, Spawns[i]) == 0)
			{
				ZeroWeightsExcept(i);
				return Plugin_Handled;
			}
		}	
	}
	ReplyToCommand(client, "l4d2_ais_preset <default|none|smoker|boomer|hunter|spitter|jockey|charger|tank>");
	return Plugin_Handled;
}

ResetWeights()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		ResetConVar(hSpawnWeights[i]);
}
ZeroWeights()
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		SetConVarInt(hSpawnWeights[i], 0);
}
ZeroWeightsExcept(index)
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if (i == index)
			SetConVarInt(hSpawnWeights[i], 100);
		else
			SetConVarInt(hSpawnWeights[i], 0);
	}
	if (index != SI_TANK) //include director spawning of tank for non-tank SI presets
		ResetConVar(hSpawnWeights[SI_TANK]);
}

GenerateSpawn(client)
{
	CountSpecialInfected(); //refresh infected count
	if (SICount < SILimit) //spawn when infected count hasn't reached limit
	{
		new size;
		if (SpawnSize > SILimit - SICount) //prevent amount of special infected from exceeding SILimit
			size = SILimit - SICount;
		else
			size = SpawnSize;
			
		if (FirstSpawn)
		{
			if (size > 4)
				size = 4;//improve network
		}
		
		new index;
		new SpawnQueue[MAX_INFECTED] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
		
		//refresh current SI counts
		SITypeCount();
		
		//generate the spawn queue
		for (new i = 0; i < size; i++)
		{
			if (CmdCallEnabled)
				index = OneKind;
			else
				index = GenerateIndex();
			//index = GenerateIndex();
			if (index == -1)
				break;
			SpawnQueue[i]= index;
			SpawnCounts[index] += 1;
		}
		
		for (new i = 0; i < MAX_INFECTED; i++)
		{
			if(SpawnQueue[i] < 0) //stops if the current array index is out of bound
				break;
			new bot = CreateFakeClient("Infected Bot");
			if (bot != 0)
			{
				ChangeClientTeam(bot,TEAM_INFECTED);
				CreateTimer(0.1,kickbot,bot);
			}	
			CheatCommand(client, "z_spawn_old", Spawns[SpawnQueue[i]]); 
			FirstSpawn = false;
			
			#if DEBUG_SPAWNS
				LogMessage("[AIS] Spawned %s", Spawns[SpawnQueue[i]]);
			#endif
		}
	}
}

//MI
SITypeCount() //Count the number of each SI ingame
{
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
		SpawnCounts[i] = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		//If player is not connected ...
		if (!IsClientConnected(i)) continue;
		
		//We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		//Check if client is infected ...
		if (GetClientTeam(i)==3)
		{
			switch (GetEntProp(i,Prop_Send,"m_zombieClass")) //detect SI type
			{
				case IS_SMOKER:
					SpawnCounts[SI_SMOKER]++;
				
				case IS_BOOMER:
					SpawnCounts[SI_BOOMER]++;
				
				case IS_HUNTER:
					SpawnCounts[SI_HUNTER]++;
				
				case IS_SPITTER:
					SpawnCounts[SI_SPITTER]++;
				
				case IS_JOCKEY:
					SpawnCounts[SI_JOCKEY]++;
				
				case IS_CHARGER:
					SpawnCounts[SI_CHARGER]++;
				
				case IS_TANK:
					SpawnCounts[SI_TANK]++;
			}
		}
	}
}

public Action:kickbot(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}

stock CheatCommand(client, String:command[], String:arguments[] = "")
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

GenerateIndex()
{
	TankRate = GetConVarInt(hTankRate);
	if(TankRate == 1)
	{
		hSpawnWeights[SI_TANK] = hSpawnWeights[SI_TANK] * 5;
	}
	else
	{
		hSpawnWeights[SI_TANK] = hSpawnWeights[SI_TANK] / 5;
	}
	
	new TotalSpawnWeight, StandardizedSpawnWeight;
	
	//temporary spawn weights factoring in SI spawn limits
	decl TempSpawnWeights[NUM_TYPES_INFECTED];
	for(new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if(SpawnCounts[i] < SpawnLimits[i])
		{
			if(ScaleWeights)
				TempSpawnWeights[i] = (SpawnLimits[i] - SpawnCounts[i]) * SpawnWeights[i];
			else
				TempSpawnWeights[i] = SpawnWeights[i];
		}
		else
			TempSpawnWeights[i] = 0;
		
		TotalSpawnWeight += TempSpawnWeights[i];
	}
	
	//calculate end intervals for each spawn
	new Float:unit = 1.0/TotalSpawnWeight;
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if (TempSpawnWeights[i] >= 0)
		{
			StandardizedSpawnWeight += TempSpawnWeights[i];
			IntervalEnds[i] = StandardizedSpawnWeight * unit;
		}
	}
	
	new Float:r = GetRandomFloat(0.0, 1.0); //selector r must be within the ith interval for i to be selected
	for (new i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		//negative and 0 weights are ignored
		if (TempSpawnWeights[i] <= 0) continue;
		//r is not within the ith interval
		if (IntervalEnds[i] < r) continue;
		//selected index i because r is within ith interval
		return i;
	}
	return -1; //no selection because all weights were negative or 0
}

//special infected spawn timer based on time modes
StartSpawnTimer()
{
	limit = GetConVarInt(hCSL);
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	if (Enabled)
	{
		new Float:time;
		CountSpecialInfected();
		
//		if (SpawnTimeMode > 0) //NOT randomization spawn time mode
//			time = SpawnTimes[SICount]; //a spawn time based on the current amount of special infected
//		else //randomization spawn time mode
//			time = GetRandomFloat(SpawnTimeMin, SpawnTimeMax); //a random spawn time between min and max inclusive
		if (CmdCallEnabled)
		{
			time = 0.75;
			if (limit > 0)
			{
				SILimit = CalucateSILimit() + GetRandomInt(0,2);
			}
			else
			{
				SILimit = GetSurvivorCount(false);
			}
		}
		else
		{
			if (SpawnTimeMode > 0) //NOT randomization spawn time mode
				time = SpawnTimes[SICount]; //a spawn time based on the current amount of special infected
			else //randomization spawn time mode
				time = GetRandomFloat(SpawnTimeMin, SpawnTimeMax); //a random spawn time between min and max inclusive
			if (limit > 0)
			{
				SILimit = CalucateSILimit();
			}
			else
			{
				SILimit = GetSurvivorCount(false);
			}
		}
		//LogMessage("limit=%d,SILimit=%d", limit,SILimit);
		SpawnTimerStarted = true;
		hSpawnTimer = CreateTimer(time, SpawnInfectedAuto);
		#if DEBUG_TIMES
		LogMessage("[AIS] Mode: %d | SI: %d | Next: %.3f s", SpawnTimeMode, SICount, time);
		#endif
	}
}
CalucateSILimit()
{
	if(limit <= 0)
	{
		return GetSurvivorCount(false);
	}
	else if(limit <= 2)
	{
		return limit + 1;
	}
	else if(limit <= 3)
	{
		return limit + 2;
	}
	else if(limit <= 4)
	{
		return limit + 3;
	}
	else if(limit <= 8)
	{
		return limit + 2;
	}
	else if(limit <= 10)
	{
		return limit + 1;
	}
	return limit;
}

//never directly set hSpawnTimer, use this function for custom spawn times
StartCustomSpawnTimer(Float:time)
{
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	if (Enabled)
	{
		SpawnTimerStarted = true;
		hSpawnTimer = CreateTimer(time, SpawnInfectedAuto);
	}
}
EndSpawnTimer()
{
	if (SpawnTimerStarted)
	{
		CloseHandle(hSpawnTimer);
		SpawnTimerStarted = false;
	}
}

StartWitchWaitTimer(Float:time)
{
	EndWitchWaitTimer();
	if (Enabled && WitchLimit > 0)
	{
		if (WitchCount < WitchLimit)
		{
			WitchWaitTimerStarted = true;
			hWitchWaitTimer = CreateTimer(time, StartWitchTimer);
			#if DEBUG_TIMES
			LogMessage("[AIS] Mode: %b | Witches: %d | Next(WitchWait): %.3f s", VariableWitchPeriod, WitchCount, time);
			#endif
		}
		else //if witch count reached limit, wait until a witch killed event to start witch timer
		{
			WitchCountFull = true;
			#if DEBUG_TIMES
			LogMessage("[AIS] Witch Limit reached. Waiting for witch death.");
			#endif		
		}
	}
}
public Action:StartWitchTimer(Handle:timer)
{
	WitchWaitTimerStarted = false;
	EndWitchTimer();
	if (Enabled && WitchLimit > 0)
	{
		new Float:time;
		if (VariableWitchPeriod)
			time = GetRandomFloat(0.0, WitchPeriod);
		else
			time = WitchPeriod;
		
		WitchTimerStarted = true;
		hWitchTimer = CreateTimer(time, SpawnWitchAuto, WitchPeriod-time);
		#if DEBUG_TIMES
		LogMessage("[AIS] Mode: %b | Witches: %d | Next(Witch): %.3f s", VariableWitchPeriod, WitchCount, time);
		#endif
	}
	return Plugin_Handled;
}
EndWitchWaitTimer()
{
	if (WitchWaitTimerStarted)
	{
		CloseHandle(hWitchWaitTimer);
		WitchWaitTimerStarted = false;
	}
}
EndWitchTimer()
{
	if (WitchTimerStarted)
	{
		CloseHandle(hWitchTimer);
		WitchTimerStarted = false;
	}
}
//take account of both witch timers when restarting overall witch timer
RestartWitchTimer(Float:time)
{
	EndWitchTimer();
	StartWitchWaitTimer(time);
}

StartTimers()
{
	StartSpawnTimer();
	RestartWitchTimer(0.0);
}
EndTimers()
{
	EndSpawnTimer();
	EndWitchWaitTimer();
	EndWitchTimer();
}

public Action:StartSpawnTimerManually(client, args)
{
	if (Enabled)
	{
		if (args < 1)
		{
			StartSpawnTimer();
			ReplyToCommand(client, "[AIS] Spawn timer started manually.");
		}
		else
		{
			new Float:time = 1.0;
			decl String:arg[8];
			GetCmdArg(1, arg, sizeof(arg));
			time = StringToFloat(arg);
			
			if (time < 0.0)
				time = 1.0;
			
			StartCustomSpawnTimer(time);
			ReplyToCommand(client, "[AIS] Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
		}
	}
	else
		ReplyToCommand(client, "[AIS] Plugin is disabled. Enable plugin before manually starting timer.");

	return Plugin_Handled;
}
 
public Action:SpawnInfectedAuto(Handle:timer)
{
	SpawnTimerStarted = false; //spawn timer always stops here (the non-repeated spawn timer calls this function)
	if (LeftSafeRoom) //only spawn infected and repeat spawn timer when survivors have left safe room
	{
		new client = GetAnyClient();
		if (client) //make sure client is in-game
		{
			GenerateSpawn(client);
			StartSpawnTimer();
		}
		else //longer timer for when invalid client was returned (prevent a potential infinite loop when there are 0 SI)
			StartCustomSpawnTimer(SpawnTimeMax);
	}
	if (IsCmdCallContinuing == false)
	{
		Random();
	}
	return Plugin_Handled;
}

public Action:SpawnWitchAuto(Handle:timer, any:waitTime)
{
	WitchTimerStarted = false;
	if (LeftSafeRoom)
	{
		new client = GetAnyClient();
		if (client)
		{
			if (WitchCount < WitchLimit)
				ExecuteCheatCommand(client, "z_spawn_old", "witch", "auto");
			StartWitchWaitTimer(waitTime);
		}
		else
			StartWitchWaitTimer(waitTime+1.0);
	}
	return Plugin_Handled;
}

ExecuteCheatCommand(client, const String:command[], String:param1[], String:param2[]) {
	//Hold original user flag for restoration, temporarily give user root admin flag (prevent conflict with admincheats)
	new admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	
	//Removes sv_cheat flag from command
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);

	FakeClientCommand(client, "%s %s %s", command, param1, param2);
	
	//Restore command flag and user flag
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

public Action:ResetSpawns(client, args)
{	
	KillSpecialInfected();
	if (Enabled)
	{
		StartCustomSpawnTimer(SpawnTimes[0]);
		RestartWitchTimer(0.0);
		ReplyToCommand(client, "[AIS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", SpawnTimeMin);
	}
	else
		ReplyToCommand(client, "[AIS] Slayed all special infected.");
	return Plugin_Handled;
}

CountSpecialInfected()
{
	//reset counter
	SICount = 0;
	
	//First we count the amount of infected players
	for (new i = 1; i <= MaxClients; i++)
	{
		//If player is not connected ...
		if (!IsClientConnected(i)) continue;
		
		//We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		//Check if client is infected ...
		if (GetClientTeam(i)==3)
			SICount++;
	}
}

KillSpecialInfected()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i)) continue;
		
		if (!IsClientInGame(i)) continue;
		
		if (GetClientTeam(i)==3)
			ForcePlayerSuicide(i);
	}
	
	//reset counter after all special infected have been killed
	SICount = 0;
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

//MI 5
public Action:evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	//If round haven't started
	if (!RoundStarted)
	{
		//and we reset some variables
		RoundEnded = false;
		RoundStarted = true;
		LeftSafeRoom = SafeSpawn; //depends on whether special infected should spawn while survivors are in starting safe room
		WitchCount = 0;
		SpawnTimerStarted = false;
		WitchTimerStarted = false;
		WitchWaitTimerStarted = false;
		WitchCountFull = false;

		InitTimers();
		
		limit = 0;
		CmdCallEnabled = false;
		IsCmdCallContinuing = false;
		OneKind = 0;
		FirstSpawn = true;
		if (OKindTimer != INVALID_HANDLE)
		{
			CloseHandle(OKindTimer);
			OKindTimer = INVALID_HANDLE;
		}
	}
}

//MI 5
public Action:evtRoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{	
	//If round has not been reported as ended ..
	if (!RoundEnded)
	{
		//we mark the round as ended
		EndTimers();
		RoundEnded = true;
		RoundStarted = false;
		LeftSafeRoom = false;
		if (OKindTimer != INVALID_HANDLE)
		{
			CloseHandle(OKindTimer);
			OKindTimer = INVALID_HANDLE;
		}
	}
}

//MI 5
public Action:PlayerLeftStart(Handle:Timer)
{
	if (LeftStartArea())
	{
		// We don't care who left, just that at least one did
		if (!LeftSafeRoom)
		{
			LeftSafeRoom = true;
			StartTimers();		
		}
		SafeRoomChecking = false;
	}
	else
		CreateTimer(1.0, PlayerLeftStart);
	
	return Plugin_Continue;
}

//MI 5
bool:LeftStartArea()
{
	new ent = -1, maxents = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		new offset = FindSendPropInfo("CTerrorPlayerResource", "m_hasAnySurvivorLeftSafeArea");
		if (offset > 0)
		{
			if (GetEntData(ent, offset))
			{
				if (GetEntData(ent, offset) == 1) return true;
			}
		}
	}
	return false;
}

//MI 5
//This is hooked to the panic event, but only starts if its survival. This is what starts up the bots in survival.
public Action:evtSurvivalStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GameMode == 3)
	{  
		if (!LeftSafeRoom)
		{
			LeftSafeRoom = true;
			StartTimers();
		}
	}
	return Plugin_Continue;
}

//Kick infected bots immediately after they die to allow quicker infected respawn
public Action:evtInfectedDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
}

public Action:evtTankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	/*
	new client =  GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsClientInGame(client))
	{
		CreateTimer(1.0, TankSpawnTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	*/
}
/*
public Action:TankSpawnTimer(Handle:timer, any:client)
{
	new pHurt = CreateEntityByName("point_hurt");
	if (pHurt)
	{
		DispatchKeyValue(client, "targetname", "hurtme");
		DispatchKeyValue(pHurt, "Damage", "10");
		DispatchKeyValue(pHurt, "DamageTarget", "hurtme");
		DispatchKeyValue(pHurt, "DamageType", "2");
		DispatchSpawn(pHurt);
		AcceptEntityInput(pHurt, "Hurt", GetAliveSurvivor());
		AcceptEntityInput(pHurt, "Kill");
		DispatchKeyValue(client, "targetname", "donthurtme");
	}
}

GetAliveSurvivor()
{
	for (new  i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i)))
		{
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				return i;
			}
		}
	}
	return 0;
}

public Action:TankSpawnTimer(Handle:timer, any:client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		if (GetEntProp(client, Prop_Send, "m_lifeState") != 1)
		{
			if (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 1)
			{
				decl String:classname[32];
				GetEntityNetClass(client, classname, sizeof(classname));
				if (StrEqual(classname, "Tank", false))
				{
					new health = GetEntProp(client, Prop_Send, "m_iHealth");
					new maxhealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
					if (CmdCallEnabled)
					{
					}
					else
					{
						new extrahealth = GetSurvivorCount(false) * 1000;
						SetEntProp(client, Prop_Send, "m_iHealth", health + extrahealth);
						SetEntProp(client, Prop_Send, "m_iMaxHealth", maxhealth + extrahealth);
					}
				}
			}
		}
	}
}

public Action:OnPlayerTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (damage > 0.0 && (victim > 0 && victim <= MaxClients && IsClientInGame(victim)))
	{
		if (GetClientTeam(victim) == 2)
		{
			if (attacker > 0 && (attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == 3))
			{
				if (GetEntProp(attacker, Prop_Send, "m_lifeState") != 1)
				{
					if (GetEntProp(attacker, Prop_Send, "m_isIncapacitated") != 1)
					{
						decl String:classname[32];
						GetEntityNetClass(attacker, classname, sizeof(classname));
						if (StrEqual(classname, "Tank", false))
						{
							if (damagetype != 2)
							{
								if (CmdCallEnabled)
								{
									new iHealth = GetClientHealth(victim);
									SetEntityHealth(victim, iHealth + RoundFloat(damage) - 2);
								}
							}	
						}
					}
				}
			}
		}
	}
}
*/
public Action:evtWitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	WitchCount++;
}

/*
public Action:evtWitchHarasse(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:names[32];
	new killer = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(killer) == 2) //only show message if player is in survivor team
	{
		GetClientName(killer, names, sizeof(names));
		PrintToChatAll("%s startled the Witch!",names);
	}
}
*/
public Action:evtWitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	WitchCount--;
	if (WitchCountFull)
	{
		WitchCountFull = false;
		StartWitchWaitTimer(0.0);
	}
}
/*
public Action:evtPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	if (IsBotInfected(client) && !IsTank(client) && userid >= 0)
	{
		g_fTimeLOS[userid] = 0.0;
		// Checking LOS
		CreateTimer(0.5, Timer_StarvationLOS, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_StarvationLOS( Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	// increment tracked LOS time
	if (IsBotInfected(client) && IsPlayerAlive(client))
	{
		if (g_fTimeLOS[userid] > 20.0)
		{
			ForcePlayerSuicide(client);
			return Plugin_Stop;
		}
		if (bool:GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
		{
			g_fTimeLOS[userid] = 0.0;
		}
		else
		{
			g_fTimeLOS[userid] += 0.5; 
		}
	}
	else 
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
*/
public OnMapStart()
{
	OKindTimer = INVALID_HANDLE;
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
	RoundStarted = false;
	RoundEnded = true;
	LeftSafeRoom = false;
	//KillTimer(timer);

}

stock GetSurvivorCount(bool:allowBots)
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

stock bool:IsValidSurvivor(client, bool:allowbots)
{
	if ((client < 1) || (client > MaxClients)) { return false; }
	if (!IsClientInGame(client) || !IsClientConnected(client)) { return false; }
	if (GetClientTeam(client) != TEAM_SURVIVORS) { return false; }
	if (IsFakeClient(client) && !allowbots) { return false; }
	return true;
}

public Action:SetOnly1KindSI(client, args)
{
	if (IsCmdCallContinuing == false)
	{
		CreateTimer(1.0, Start, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChatAll("\x03切换BGM");
		CreateTimer(1.0, Stop, _, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(10.0, Start, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:StopOnly1KindSI(client, args)
{
	CreateTimer(1.0, Stop, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Start(Handle:timer)
{
	CmdCallEnabled = true;
	IsCmdCallContinuing = true;
	OneKind = GetRandomInt(0, 5);
	new Float:time = 0.0;
	rate1 = GetRandomInt(1, 5);
	switch(rate1)
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
	OKindTimer = CreateTimer(time, Stop, _, TIMER_FLAG_NO_MAPCHANGE);
	EmitSoundToAll(RELATIVE_SOUND_PATH[rate1-1], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HELICOPTER, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0 );
}

public Action:Stop(Handle:timer)
{
	CmdCallEnabled = false;
	IsCmdCallContinuing = false;
	for(new i=1;i<=MaxClients;i++) 
	{
		if (IsClientInGame(i))
		{
			StopSound(i, SNDCHAN_AUTO, RELATIVE_SOUND_PATH[rate1 - 1]);
		}
	}
	if (OKindTimer != INVALID_HANDLE)
	{
		KillTimer(OKindTimer);
		OKindTimer = INVALID_HANDLE;
	}
}

Random()
{
	new Float:musicrate = GetRandomFloat(0.0, 100.0);
	if (musicrate <= 0.1)
	{
		CreateTimer(1.0, Start, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}
