/*---beta-version---*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
//#include <hint>
//#include <left4dhooks>
//#include <smlib>

#define DEBUG true

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.9.4.2"

#define COUNTDOWN_ING_SOUND "buttons/blip1.wav"
#define COUNTDOWN_ED_SOUND "buttons/blip2.wav"

#define INFO_LCP_SOUND "ui/pickup_secret01.wav"
#define INFO_NOTLCP_SOUND "level/scoreregular.wav"

#define MAX_STEAMAUTH_LENGTH 21
#define CHAT_COLOR_SURVIVOR 1
#define SurCount 16

//虚函数
new Handle:g_GameData;
//开局计数相关
new countDown = 0;
new bool:isFirstRound;
//幸存者列表
new linchpin;
new num;
new String:survivorsList[SurCount][MAX_STEAMAUTH_LENGTH];	// steamID
new String:survivorsName[SurCount][128];	// client name
new survivorsStat[SurCount];
//全局变量锁防止list混乱
new bool:isPreList;
new bool:isPrinting;
new bool:hasKilledAll;
new bool:isRoundEnd;
new bool:botDieFinished;
new bool:botDieStarted;
new bool:mapChange;
new bool:saved;
//血量同步
new Handle:timerSync;
//地精回血
new gnome[MAXPLAYERS + 1];
new bool:timerHeal;
//可乐荧光
new cola[MAXPLAYERS + 1];
new bool:timerCola;
new lastCola;
colaC[20000];
//近战速度
new bool:isLoading;
// new nextPrimaryAttackOffset = -1;
// new activeWeaponOffset;
// new Float:meleeAttackNextTimeFlame = -1.0;
// new meleeAttackMeleeEnt = -1;
// new meleeAttackNotMeleeEnt = -1;
// new meleeAttackCount = -1;
//witch发光
new fCount;
new witchColor[20000];
//榜单相关
new Database:handleDatabase;
new String:passList[SurCount][MAX_STEAMAUTH_LENGTH];
new String:passName[SurCount][256];
new passCount;
//过关武器保存
new bool:cleaning;
new String:slot1[SurCount][40];
new String:slot2[SurCount][40];
new String:slot3[SurCount][40];
new String:slot4[SurCount][40];
new String:slot5[SurCount][40];
new String:saveList[SurCount][MAX_STEAMAUTH_LENGTH];
new weaponUpgrade[SurCount];
new bool:needRandom;//团灭随机
//tank击飞
new Float:height;
new Float:vecX;
new Float:vecY;
new Handle:t_HitBack;
//model fix
//new MODEL_DEFIB;

static String:randomScripts[30][] =
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
	"weapon_smg_mp5",
	"weapon_grenade_launcher",
	"weapon_rifle_m60",
	"weapon_pistol_magnum",
	"weapon_chainsaw",
	"weapon_adrenaline",
	"weapon_defibrillator",
	"weapon_first_aid_kit",
	"weapon_pain_pills",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary",
	"fireaxe",
	"frying_pan",
	"machete",
	"katana",
	"knife"
};

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

public Plugin:myinfo = 
{
	name = "[l4d2] Protect the selected survivor",
	author = PLUGIN_AUTHOR,
	description = "--",
	version = PLUGIN_VERSION,
	url = "steamcommunity.com/id/m_Yui"
};

public OnPluginStart()
{
	decl String:gameName[64];
	GetGameFolderName(gameName, sizeof(gameName));
	if(!StrEqual(gameName, "left4dead2", false)) 
	{ 
		SetFailState("Use this in Left 4 Dead 2 only.");
	}
	g_GameData = LoadGameConfigFile("linchpin");
	if(g_GameData == null)
    {
    	SetFailState("Game data missing!");
    }
	
	//nextPrimaryAttackOffset = FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	//activeWeaponOffset = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	
	new Handle:hMaxSurvivorsLimitCvar = FindConVar("survivor_limit");
	SetConVarBounds(hMaxSurvivorsLimitCvar, ConVarBound_Lower, true, 4.0);
	SetConVarBounds(hMaxSurvivorsLimitCvar, ConVarBound_Upper, true, 16.0);
	SetConVarInt(hMaxSurvivorsLimitCvar, SurCount);
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);

	CreateConVar("l4d2_pl_death_linchpin_change", "1", "玩家死亡是否变更选定");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	// 选定玩家变动
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);
	// 武器保存、榜单
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	// 8人以上载具离开死亡fix
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
	// 可乐地精功能
	HookEvent("item_pickup", Event_ItemPickup);
	// tank击飞
	HookEvent("weapon_fire", Event_WeaponFire);
	
	RegConsoleCmd("sm_join", Cmd_JoinSurvivor);
	RegAdminCmd("sm_sdc", Cmd_StopDeathChange, ADMFLAG_CHEATS);
	//PreVomitSDKCall();
	ConnectDB();
	isLoading = true;
}

public ConnectDB()
{
	if (SQL_CheckConfig("db_linchpin"))
	{
		new String: error[80];
		handleDatabase = SQL_Connect("db_linchpin", true, error, sizeof(error));
		if (handleDatabase != null)
		{
			SQL_LockDatabase(handleDatabase);
			SQL_FastQuery(handleDatabase, "CREATE TABLE IF NOT EXISTS playerdata (id INTEGER PRIMARY KEY AUTOINCREMENT, steamid varchar(32), name varchar(32), needcheck INTEGER);");
			SQL_FastQuery(handleDatabase, "CREATE TABLE IF NOT EXISTS mapdata (id INTEGER PRIMARY KEY AUTOINCREMENT,steamid1 varchar(32), steamid2 varchar(32), steamid3 varchar(32), steamid4 varchar(32), steamid5 varchar(32), steamid6 varchar(32), steamid7 varchar(32), steamid8 varchar(32), steamid9 varchar(32), steamid10 varchar(32), steamid11 varchar(32), steamid12 varchar(32),  steamid13 varchar(32), steamid14 varchar(32), steamid15 varchar(32), steamid16 varchar(32), map varchar(256), time varchar(32));");
			SQL_UnlockDatabase(handleDatabase);
		}
		else
		{
			LogError("Failed connect to database: %s", error);
		}
	}
	else
	{
		LogError("databases.cfg missing 'db_linchpin' entry!");
	}
}

public DataBaseErrorCheck(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if (hndl != null)
	{
		if (error[0] != '\0')
		{
			LogError("SQL Error: %s", error);
		}
	}
}

public Action:Cmd_JoinSurvivor(client, args)
{
	if (IsCountDownFinished() && IsClientInGame(client))
	{
		PrintToChat(client,"\x03当前游戏已开始,未加入者请等待\x04过关\x03或\x04团灭重开");
	}
	else if (!IsCountDownFinished())
	{
		JoinTeam(client);
	}
}

public Action:Cmd_StopDeathChange(client, args)
{
	if (IsClientInGame(client))
	{
		PrintToChat(client, "已关闭玩家死亡后选定玩家变动");
		SetConVarInt(FindConVar("l4d2_pl_death_linchpin_change"), 0);
	}
}

public OnMapStart()
{
	#if DEBUG
		LogMessage("On Map Start");
	#endif
	isFirstRound = true;
	needRandom = false;
	timerSync = INVALID_HANDLE;
	t_HitBack = INVALID_HANDLE;
	
	PrecacheSound(COUNTDOWN_ING_SOUND,true);
	PrecacheSound(COUNTDOWN_ED_SOUND,true);
	PrecacheSound(INFO_NOTLCP_SOUND,true);
	PrecacheSound(INFO_LCP_SOUND,true);
	PrecacheModel("models/w_models/weapons/w_eq_defibrillator.mdl", true);
	CreateTimer(5.0, SQL_MapStartConnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapEnd()
{
	isLoading = true;
}

public Action:SQL_MapStartConnect(Handle:timer)
{
	#if DEBUG
		LogMessage("Timer : SQL_MapStartConnect");
	#endif
	if (handleDatabase != null)
	{
		decl String:query[512];
		decl String:map[128];
		GetCurrentMapEx(map, 128);
		Format(query, sizeof(query), "SELECT time FROM mapdata WHERE map = '%s'", map);
		#if DEBUG
			LogMessage("Timer : SQL_MapStartConnect : q = %s", query);
		#endif
		SQL_TQuery(handleDatabase, DataBaseCheckNewMap, query);
	}
}

public DataBaseCheckNewMap(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if (hndl != null)
	{
		new count = SQL_GetRowCount(hndl);
		if (count == 0)
		{
			decl String:query[88];
			decl String:map[128];
			GetCurrentMapEx(map, 128);
			Format(query, sizeof(query), "INSERT INTO mapdata (map) values ('%s')", map);
			#if DEBUG
				LogMessage("Func : DataBaseCheckNewMap : q = %s", query);
			#endif
			SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
			CreateTimer(2.0, SQL_UpdateNewMapTime, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:SQL_UpdateNewMapTime(Handle:timer)
{
	#if DEBUG
		LogMessage("Timer : SQL_UpdateNewMapTime");
	#endif
	if (handleDatabase != null)
	{
		decl String:query[512];
		decl String:timeBuffer[26];
		decl String:map[128];
		GetCurrentMapEx(map, 128);
		FormatTime(timeBuffer, sizeof(timeBuffer), "%Y-%m-%d~%H:%M:%S");
		Format(query, sizeof(query), "UPDATE mapdata SET time = '%s' WHERE map = '%s'", timeBuffer, map);
		#if DEBUG
			LogMessage("Timer : SQL_UpdateNewMapTime : q = %s", query);
		#endif
		SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (IsCountDownContinuing())
	{
		ReturnToSaferoom(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

ReturnToSaferoom(client)
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	if (IsClientInGame(client) && L4D2Team:GetClientTeam(client) == L4D2Team_Survivor)
	{
		CountingReturnPlayerToSaferoom(client, true);
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

CountingReturnPlayerToSaferoom(client, bool:flagsSet = true)
{
	new warp_flags;
	new give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	RoundStart_InitGlobalVar();
	CreateTimer(2.0, TimerCountDownReady, _, TIMER_FLAG_NO_MAPCHANGE);
}

RoundStart_InitGlobalVar()
{
	isRoundEnd = false;
	mapChange = false;
	hasKilledAll = false;
	isLoading = false;
	fCount = 0;
	linchpin = -1;
	countDown = -2;
	isPreList = false;
	isPrinting = false;
	botDieFinished = false;
	botDieStarted = false;
	saved = false;
	for (new i = 0; i < SurCount; i++)
	{
		survivorsList[i] = "";
		survivorsName[i] = "";
		survivorsStat[i] = 0;
		passList[i] = "";
		passName[i] = "";
	}
	for (new i = 0; i < MAXPLAYERS + 1; i++)
	{
		gnome[i] = 0;
		cola[i] = 0;
	}
	num = 0;
	passCount = 0;
	
	new Handle:voteEnabled = FindConVar("rcm_VoteEnabled");
	if (voteEnabled != INVALID_HANDLE)
	{
		SetConVarInt(voteEnabled, 1);
	}
}

public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	isRoundEnd = true;
	needRandom = true;
	if (timerSync != INVALID_HANDLE)
	{
		KillTimer(timerSync);
		timerSync = INVALID_HANDLE;
	}
	if (t_HitBack != INVALID_HANDLE)
	{
		KillTimer(t_HitBack);
		t_HitBack = INVALID_HANDLE;
	}
	ResetSurGlowAll();
	DeletePlayersSlot();
	CleanSaveString();
}

public Action:TimerCountDownReady(Handle:timer)
{
	if (GetSurvivorCount(false) == 0)
	{
		CreateTimer(1.0, TimerCountDownReady, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		countDown = 0;
		SetConVarInt(FindConVar("sb_stop"), 1);
		CreateTimer(0.5, TimerSpawnFakeClient, _, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.0, TimerCountDown, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:TimerCountDown(Handle:timer)
{
	if (GetSurvivorCount(false) == 0)
	{
		CreateTimer(0.1, TimerCountDownReady, _, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	if (countDown >= (isFirstRound ? 45:15))
	{
		countDown = -1;
		isFirstRound = false;
		EmitSoundToAll(COUNTDOWN_ED_SOUND);
		RestoreHealth();
		//ChooseTraitor();
		decl String:map[128];
		GetCurrentMapEx(map, 128);
		if(!StrEqual(map,"qe2_ep1"))
		{
			CreateTimer(0.5, StartInitReady, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			for (new client = 1; client <= MaxClients; client++)
			{
				if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
					GiveCommand(client, "give", "vomitjar", "");
			}
			CreateTimer(60.0, StartInitReady, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		//SetTeamUnFrozen();
		new Handle:enabled = FindConVar("l4d_is_spawn_enabled");
		if (enabled != INVALID_HANDLE)
		{
			SetConVarInt(enabled, 1);
			LogMessage("set l4d_is_spawn_enabled 1");
		}
		else
		{
			LogMessage("l4d_is_spawn_enabled missed");
	    }
	    
		new Handle:voteEnabled = FindConVar("rcm_VoteEnabled");
		if (voteEnabled != INVALID_HANDLE)
		{
			SetConVarInt(voteEnabled, 0);
		}
		SetConVarInt(FindConVar("sb_stop"), 0);
		PrintHintTextToAll("回合开始!");
	}
	else
	{
		
		if (((isFirstRound ? 45:15) - countDown) == 8)
		{
			SQL_GetSavedList();
		}
		
		EmitSoundToAll(COUNTDOWN_ING_SOUND);
		PrintHintTextToAll("请等待 %i 秒", ((isFirstRound ? 45:15) - countDown));
		countDown += 1;
		if (!isRoundEnd)
		{
			// 防止倒计时结束前团灭导致重复计时
            CreateTimer(1.0, TimerCountDown, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		
	}
	return Plugin_Continue;
}

RestoreHealth()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client, true))
		{
			GiveCommand(client, "give", "health", "");//回血
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);//去虚血
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);//去倒地次数
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);//去黑白状态
		}
	}
}

bool:IsCountDownFinished()
{
	return (countDown == -1);
}

bool:IsCountDownContinuing()
{
	return (countDown > -1);
}

GetSurvivorCount(bool:allowBots)
{	
	new count = 0;
	for (new i = 1;  i <= MaxClients; i++)
	{	
		if (IsValidSurvivor(i, allowBots))
		{
			count += 1;
		}
	}
	return count;
}

bool:IsValidSurvivor(client, bool:allowbots)
{
	if ((client < 1) || (client > MaxClients))
	{
		return false;
	}
	if (!IsClientInGame(client) || !IsClientConnected(client))
	{
		return false;
	}
	if (GetClientTeam(client) != 2)
	{
		return false;
	}
	if (IsFakeClient(client) && !allowbots)
	{
		return false;
	}
	return true;
}

public Action:TimerSpawnFakeClient(Handle:timer)
{
	if (GetSurvivorCount(false) == 0)
	{
		CreateTimer(1.0, TimerSpawnFakeClient, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		SpawnFakeClient();
		for (new i = 1; i<= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientConnected(i))
			{
				JoinTeam(i);
			}
		}
		CreateTimer(5.0, TimerReturnSaferoom);
		DeletePlayersSlot();
	}
}

public Action:TimerReturnSaferoom(Handle:timer)
{
	ReturnPlayerToSaferoom();
}

JoinTeam(client)
{
	if (client > 0)
	{
		if (GetClientTeam(client) != 2 && !IsFakeClient(client) && GetClientTeam(client) != 3)
		{
			CreateTimer(1.0, TimerJoinTeam, client);
		}
	}
}

public Action:TimerJoinTeam(Handle:timer, any:client)
{
	if(!IsClientConnected(client) || !IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == 2)
		{
			return Plugin_Stop;
		}
		TakeOverBot(client, false);
	}
	return Plugin_Continue;
}

TakeOverBot(client, bool:completely)
{
	if (!IsClientInGame(client) || GetClientTeam(client) == 2 || IsFakeClient(client))
	{
		return;
	}
	new bot = FindAFreeBot();
	if (bot == 0)
	{
		PrintHintText(client, "没有BOT接管.");
		return;
	}
	static Handle:hSetHumanIdle;
	if (!hSetHumanIdle)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "SetHumanIdle");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		hSetHumanIdle = EndPrepSDKCall();
	}
	static Handle:hTakeOverBot;
	if (!hTakeOverBot)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "TakeOverBot");
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		hTakeOverBot = EndPrepSDKCall();
	}
	if (completely)
	{
		SDKCall(hSetHumanIdle, bot, client);
		SDKCall(hTakeOverBot, client, true);
		// L4D_SetHumanSpec(bot, client);
		// L4D_TakeOverBot(client);
	}
	else
	{
		SDKCall(hSetHumanIdle, bot, client);
		// L4D_SetHumanSpec(bot, client);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	}
	return;
}

FindAFreeBot()
{
	new bool:needCheck = true;
	if (IsCountDownFinished())
	{
		needCheck = false;
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			if (IsFakeClient(i) && GetClientTeam(i) == 2 && ((IsAlive(i) && needCheck) || (!IsAlive(i) && !needCheck)) && !HasIdlePlayer(i))
			{
				return i;
			}
		}
	}
	return 0;
}

bool:HasIdlePlayer(bot)
{
	if (!IsFakeClient(bot))
	{
		return false;
	}
	if (IsClientConnected(bot) && IsClientInGame(bot))
	{
		if (GetClientTeam(bot) == 2 && IsAlive(bot))
		{
			if (IsFakeClient(bot))
			{
				if (!HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
				{
					return false;
				}
				new client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));
				if (client)
				{
					if (!IsFakeClient(client) && IsClientInGame(client) && GetClientTeam(client) == 1)
					{
						return true;
					}
				}
			}
		}
	}
	return false;
}

bool:IsAlive(client)
{
	if (!GetEntProp(client, PropType:0, "m_lifeState", 4, 0))
	{
		return true;
	}
	return false;
}

SpawnFakeClient()
{
	CreateTimer(0.1, TimerSpawnBot);
}

public Action:TimerSpawnBot(Handle:timer)
{
	new count = SurCount+2 - GetSurvivorCount(true);
	for (new i=0; i<count; i++)
	{
		SpawnAFakeClient();
		//CreateTimer(1, TimerSpawnBot);
	}
	return Plugin_Handled;
}

SpawnAFakeClient()
{
	new bool:fakeclientKicked = false;
	new fakeclient = CreateFakeClient("FakeClient");
	if (fakeclient != 0)
	{
		ChangeClientTeam(fakeclient, 2);
		if (DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)	// check if entity classname is survivorbot
		{
			if (DispatchSpawn(fakeclient) == true)								// spwan
			{
				DeletePlayerAllSlot(fakeclient);
				CreateTimer(0.1, Timer_KickFakeBot, fakeclient, TIMER_REPEAT);
				fakeclientKicked = true;
			}
		}			
		if(fakeclientKicked == false)
		{
			KickClient(fakeclient, "Kicking FakeClient");
		}
	}
}

public Action:Timer_KickFakeBot(Handle:timer, any:fakeclient)
{
	if (IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kick FakeClient");
		return Plugin_Stop;
	}	
	return Plugin_Continue;
}

public Action:StartInitReady(Handle:timer)
{	
	if (!botDieStarted) 
	{
		FocusBotDie();
	}
	botDieStarted = true;
	
	if (botDieFinished)
	{
		CreateTimer(1.0, InitFuction, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CreateTimer(0.1, StartInitReady, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

FocusBotDie()
{
	botDieFinished = false;
	new Float:pos[3];
	pos[0] = 0.0;
	pos[1] = 0.0;
	pos[2] = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i))
		{
			TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
			DeletePlayerAllSlot(i);
			ForcePlayerSuicide(i);
			RequestFrame(DeleteDeadBody, i);
		}
	}

	botDieFinished = true;
}

public void DeleteDeadBody(any:data)
{
	new entity = -1;
	while ((entity = FindEntityByClassname(entity, "survivor_death_model")) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entity, "Kill");
	}
}
/*---处理开局选定---*/
public Action:InitFuction(Handle:timer)
{
	PreList();
	CreateTimer(0.1, FirstSetLinchpin, _, TIMER_FLAG_NO_MAPCHANGE);
}

PreList()
{
	isPreList = true;
	new count = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsClientConnected(i))
		{
			continue;
		}
		if (GetClientTeam(i) != 2 || IsFakeClient(i) || !IsPlayerAlive(i))
		{
			continue;
		}
		GetClientAuthId(i, AuthId_Steam2, survivorsList[count], MAX_STEAMAUTH_LENGTH);
		GetClientName(i, survivorsName[count], 128);
		survivorsStat[count] = 1;
		count += 1;
	}
	num = count;
	isPreList = false;
}

public Action:FirstSetLinchpin(Handle:timer)
{
	if (isPreList)
	{
		CreateTimer(0.1, FirstSetLinchpin, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintList();
		CreateTimer(0.5, ChooseAndSet, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action:ChooseAndSet(Handle:timer)
{
	if (isPrinting)
	{
		CreateTimer(0.1, ChooseAndSet, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		//CreateTimer(0.1, CheckBot);
		new index = RandomIndex();
		new client = FindClientBySteamId(survivorsList[index]);
		if (client > 0)
		{
			linchpin = client;
			SetSurGlowColor(linchpin);
			new Handle:limit = FindConVar("custom_survivor_count");
			if (limit != INVALID_HANDLE)
			{
				SetConVarInt(limit, num);
				LogMessage("Set convar custom_survivor_count:%d", num);
			}
		}
		PrintToChatAll("\x03当前选定:\x04%s\x03决定所有人血量, 请注意保护",survivorsName[index]);
		PlayInfoSound();
		if(timerSync != INVALID_HANDLE)
		{
			KillTimer(timerSync);
			timerSync = INVALID_HANDLE;
		}
		timerSync = CreateTimer(0.2, TimerSyncHealth, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		RemoveColaAndGnome();
		CreateTimer(1.5, GiveWeapon, _, TIMER_FLAG_NO_MAPCHANGE);
		timerHeal = true;
		timerCola = true;
	}
	return Plugin_Continue;
}

public Action:GiveWeapon(Handle:timer)
{
	if (!needRandom)
		{
			GiveItemFromSlotInfo();
		}
		else
		{
			GiveRandomItem();
		}
}

RemoveColaAndGnome()
{
	decl String:name[128];
	for (new i = 0; i <= 4096; i++)
	{
		if(IsValidEntity(i))
		{
			GetEntPropString(i, Prop_Data, "m_ModelName", name, 128);
			if (StrContains(name, "gnome", false) > -1 || StrContains(name, "cola", false) > -1)
			{
				if (HasEntProp(i, Prop_Data, "m_iState"))
				{
					new state = GetEntProp(i, Prop_Data, "m_iState", 4, 0);
					if (state == 0)
					{
						AcceptEntityInput(i, "Kill");
					}
				}
			}
		}
	}
}

ReturnPlayerToSaferoom()
{
	new commandFlags;
	new client = GetAnyClient();
	if (client > 0)
	{
		commandFlags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", commandFlags & ~FCVAR_CHEAT);	
		FakeClientCommand(client, "warp_to_start_area");	
		SetCommandFlags("warp_to_start_area", commandFlags);
	}
}

GetAnyClient()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (GetClientTeam(i) == 2) && !IsFakeClient(i) && IsAlive(i))
		{
			return i;
		}
	}
	return -1;
}

PlayInfoSound()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidSurvivor(i, false))
		{
			continue;
		}
		if (i == linchpin)
		{
			EmitSoundToClient(i, INFO_LCP_SOUND);
		}
		else
		{
			EmitSoundToClient(i, INFO_NOTLCP_SOUND);
		}
	}
}

PrintList()
{
	isPrinting = true;
	PrintToChatAll("\x03当前更新范围:\x04%i\x03人",num);
	// for (new i = 0; i < SurCount; i++)
	// {
	// 	PrintToChatAll("\x01%s",survivorsName[i]);
	// }
	isPrinting = false;
}

RandomIndex()
{
	if (num == 1)
	{
		return 0;
	}
	else
	{
		new index = GetRandomInt(1, num);
		index -= 1;
		return index ;
	}
}

FindClientBySteamId(const String:auth[])
{
	new String:clientAuth[MAX_STEAMAUTH_LENGTH];
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientAuthorized(client))
		{
			continue;
		}
		GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
		if (StrEqual(auth, clientAuth))
		{
			return client;
		}
	}
	return -1;
}

SetSurGlowColor(client)
{
	new color = RGB_TO_INT(255, 105, 180);
	if (IsValidSurvivor(client, false))
	{
		SetEntProp(client, Prop_Send, "m_iGlowType", 3);
		SetEntProp(client, Prop_Send, "m_glowColorOverride", color);
		SetEntProp(client, Prop_Send, "m_nGlowRange", 4096);
		SetEntProp(client, Prop_Send, "m_bFlashing", 1);
	}
}

SetSurGlowDefaults(client)
{
	if (IsValidSurvivor(client, false))
	{
		SetEntProp(client, Prop_Send, "m_iGlowType", 0);
		SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
		SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(client, Prop_Send, "m_bFlashing", 0);
	}
}

ResetSurGlowAll()
{
	for (new i = 1; i<= MaxClients; i++)
	{
		if (IsValidSurvivor(i, true))
		{
			SetSurGlowDefaults(i);
		}
	}
}

RGB_TO_INT(red, green, blue)
{
	return (blue * 65536) + (green * 256) + red;
}
/*------血量同步-----*/
public Action:TimerSyncHealth(Handle:timer)
{
	if (!IsValidSurvivor(linchpin, false))
	{
		return Plugin_Continue;
	}
	for ( new i = 1; i <= MaxClients; i++ )
	{
		if (IsValidSurvivor(i, false))
		{
			if (i == linchpin)
			{
				continue;
			}
			if (!(IsPinned(i) || IsIncapped(i) || IsHangingFromLedge(i)))
			{
				new health = GetClientHealth(linchpin);
				
				if (IsPlayerInPassList(i))
				{
					if (IsIncapped(linchpin) || IsHangingFromLedge(linchpin))
					{
						SetEntityHealth(i, 44);
					}
					else if (health >= 1)
					{
						SetEntityHealth(i, ((health + 44) >= 100) ? 100:(health + 44));
					}
				}
				else
				{
					if (IsIncapped(linchpin) || IsHangingFromLedge(linchpin))
					{
						SetEntityHealth(i, 1);
					}
					else if (health >= 1)
					{
						SetEntityHealth(i, health >= 100 ? 100:health);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

bool:IsIncapped(client)
{
	return (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1);
}

bool:IsHangingFromLedge(client)
{
	return (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") == 1);
}

bool:IsPinned(client)
{
	//new bool:bIsPinned = false;
	if (IsValidSurvivor(client,false))
	{																// check if held by:
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		{
			//bIsPinned = true;										// smoker
			return true;
		}
		if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		{
			//bIsPinned = true;										// hunter
			return true;
		}
		if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		{
			//bIsPinned = true;										// charger carry
			return true;
		}
		if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		{
			//bIsPinned = true;										// charger pummel
			return true;
		}
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		{
			//bIsPinned = true;										// jockey
			return true;
		}
	}		
	return false;
}

bool:IsPlayerInPassList(client)
{
	if (IsClientAuthorized(client))
	{
		decl String:clientAuth[MAX_STEAMAUTH_LENGTH];
		GetClientAuthId(client, AuthId_Steam2, clientAuth, MAX_STEAMAUTH_LENGTH);
		for ( new i = 0; i < passCount; i++ )
		{
			if (StrEqual(passList[i], clientAuth))
			{
				return true;
			}
		}
	}
	return false;
}

/*------近战速度&&witch发光&&胆汁------*/
public OnGameFrame()
{
	if (IsServerProcessing() == false || isLoading == true)
	{
		return;
	}
	else
	{
		//MeleeAttack_OnGameFrame();
		GlowWitch_OnGameFrame();
	}
}

// MeleeAttack_OnGameFrame()
// {
// 	if (linchpin < 1)
// 		return;
		
// 	decl index;
// 	decl meleeEntID;
// 	decl Float:flNextTime_calc;
// 	decl Float:flNextTime_ret;
// 	new Float:flGameTime=GetGameTime();
// 	index = linchpin;
// 	if (index <= 0)
// 		return;
// 	if(!IsClientInGame(index))
// 		return;
// 	if(!IsClientConnected(index))
// 		return;
// 	if (!IsPlayerAlive(index))
// 		return;
// 	if(GetClientTeam(index) != 2)
// 		return;
// 	meleeEntID = GetEntDataEnt2(index,activeWeaponOffset);
// 	if (meleeEntID == -1)
// 		return;
// 	flNextTime_ret = GetEntDataFloat(meleeEntID, nextPrimaryAttackOffset);
// 	if (meleeEntID == meleeAttackNotMeleeEnt)
// 	{
// 		return;
// 	}
// 	if (meleeAttackMeleeEnt == meleeEntID && meleeAttackCount != 0 && (flGameTime - flNextTime_ret) > 1.0)
// 	{
// 		meleeAttackCount = 0;
// 	}
// 	if (meleeAttackMeleeEnt == meleeEntID && meleeAttackNextTimeFlame >= flNextTime_ret)
// 	{
// 		return;
// 	}
// 	if (meleeAttackMeleeEnt == meleeEntID && meleeAttackNextTimeFlame < flNextTime_ret)
// 	{
// 		flNextTime_calc = flGameTime + 0.49;
// 		meleeAttackNextTimeFlame  = flNextTime_calc;
// 		SetEntDataFloat(meleeEntID, nextPrimaryAttackOffset, flNextTime_calc, true);
// 		return;
// 	}
// 	decl String:stName[32];
// 	GetEntityNetClass(meleeEntID,stName,32);
// 	if (StrEqual(stName, "CTerrorMeleeWeapon", false) == true)
// 	{
// 		meleeAttackMeleeEnt = meleeEntID;
// 		meleeAttackNextTimeFlame = flNextTime_ret;
// 		return;
// 	}
// 	else
// 	{
// 		meleeAttackNotMeleeEnt = meleeEntID;
// 		return;
// 	}
// }

GlowWitch_OnGameFrame()
{
	if (!IsValidSurvivor(linchpin, false))
	{
		return;
	}
	if (fCount < 60)
	{
		fCount += 1;
	}
	else
	{
		fCount = 0;
	}
	if (fCount == 30)
	{
		new Float:pos[3];
		new Float:angles[3];
		new target;
		GetClientEyePosition(linchpin, pos);
		GetClientEyeAngles(linchpin, angles);
		new Handle: trace= TR_TraceRayFilterEx(pos, angles, MASK_SHOT, RayType_Infinite, DontHitSelf, linchpin);
		if(TR_DidHit(trace))
		{		
			target = TR_GetEntityIndex(trace);
		}
		CloseHandle(trace);
		if (IsWitch(target))
		{
			SetEntGlow(target);
		}
	}
}

SetEntGlow(entity)
{
	if (IsWitch(entity))
	{
		SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", witchColor[entity]);
		SetEntProp(entity, Prop_Send, "m_nGlowRange", 2048);
		SetEntProp(entity, Prop_Send, "m_bFlashing", 0);
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

public OnEntityDestroyed(entity)
{
	if (IsWitch(entity))
	{
		SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0);
		SetEntProp(entity, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(entity, Prop_Send, "m_bFlashing", 0);	
	}
}

/*---linchpin更换---*/
public Action:Event_PlayerTeam(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetEventInt(event, "team");
	new oldTeam = GetEventInt(event, "oldteam");
	if (IsAllowedChange(client) && IsPlayerAlive(client) && !isRoundEnd && !mapChange)
	{
		if (team == 1 && oldTeam == 2 && !GetEventBool(event, "disconnect"))
		{
			ResetSurGlowAll();
			if (client == linchpin)
			{
				KillAll();
				PrintToChatAll("\x03选定玩家\x04%N\x03闲置", client);
			}
			else if (client != linchpin)
			{
				decl String:temp[MAX_STEAMAUTH_LENGTH];
				GetClientAuthId(client, AuthId_Steam2, temp, MAX_STEAMAUTH_LENGTH);
				new check = FindIndexBySteamId(temp);
				if (check > -1)
				{
					survivorsStat[check] = 0;
				}
				new index = RandomIndex();
				if (index == check)
				{
					KillAll();
					PrintToChatAll("\x03玩家\x04%s\x03闲置, 选定玩家变更为\x04%s\x03(已死亡)", survivorsName[check], survivorsName[check]);
				}
				else
				{
					if (survivorsStat[index] == 1)
					{
						new chose = FindClientBySteamId(survivorsList[index]);
						linchpin = chose;
						SetSurGlowColor(linchpin);
						PlayInfoSound();
						PrintToChatAll("\x03玩家\x04%s\x03闲置, 选定玩家变更为\x04%s", survivorsName[check], survivorsName[index]);
					}
					else
					{
						KillAll();
						PrintToChatAll("\x03玩家\x04%s\x03闲置, 选定玩家变更为\x04%s\x03(已死亡)", survivorsName[check], survivorsName[index]);
					}
				}
			}
			CreateTimer(0.1, TimerKickPlayer, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:TimerKickPlayer(Handle:timer,any:client)
{
	KickClient(client, "你因闲置被踢出游戏");
	CreateTimer(0.1, TimerKillAllAlivedFakeBot);
}

public Action:TimerKillAllAlivedFakeBot(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i))
		{
			DeletePlayerAllSlot(i);
			ForcePlayerSuicide(i);
			//CreateTimer(0.1, DeleteDeadBody);
		}
	}
}

KillAll()
{
	hasKilledAll = true;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i, true) && IsAlive(i))
		{
			ForcePlayerSuicide(i);
		}
	}
}

public Action:Event_DefibrillatorUsed(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	if (IsFakeClient(client))
	{
		new sur = GetADeathManInList();
		if (sur > 0)
		{
			static Handle:hSetHumanIdle;
			if (!hSetHumanIdle)
			{
				StartPrepSDKCall(SDKCall_Player);
				PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "SetHumanIdle");
				PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
				hSetHumanIdle = EndPrepSDKCall();
			}
			static Handle:hTakeOverBot;
			if (!hTakeOverBot)
			{
				StartPrepSDKCall(SDKCall_Player);
				PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "TakeOverBot");
				PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
				hTakeOverBot = EndPrepSDKCall();
			}
			SDKCall(hSetHumanIdle, client, sur);
			SDKCall(hTakeOverBot, sur, true);
			//L4D_SetHumanSpec(client, sur);
			//L4D_TakeOverBot(sur);
			new String:auth[MAX_STEAMAUTH_LENGTH];
			if (IsClientAuthorized(sur))	
			{
				GetClientAuthId(sur, AuthId_Steam2, auth, sizeof(auth));
				new ck = FindIndexBySteamId(auth);
				if (ck > -1)
				{
					survivorsStat[ck] = 1;
				}
			}
		}
		else
		{
			ForcePlayerSuicide(client);
		}
	}
	else
	{
		if (IsPlayerInSurList(client))
		{
			new String:clientAuth[MAX_STEAMAUTH_LENGTH];
			if (IsClientAuthorized(client))	
			{
				GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
				new check = FindIndexBySteamId(clientAuth);
				if (check > -1)
				{
					survivorsStat[check] = 1;
				}
			}
		}
		else
		{
			GiveCommand(client, "give", "weapon_defibrillator", "");
			ForcePlayerSuicide(client);
		}
	}
	//CreateTimer(1.0, CheckBot, _, TIMER_FLAG_NO_MAPCHANGE);
}

 GetADeathManInList()
 {
 	for (new i = 0; i < SurCount; i++)
 	{
 		new client = FindClientBySteamId(survivorsList[i]);
 		if (client > 0 && IsClientInGame(client) && IsClientConnected(client))
 		{
 			if (!IsPlayerAlive(client))
 			{
 				return client;
 			}
 		}
	}
	return -1;
}

bool:IsPlayerInSurList(client)
{
	if (IsClientAuthorized(client))
	{
		decl String:clientAuth[MAX_STEAMAUTH_LENGTH];
		GetClientAuthId(client, AuthId_Steam2, clientAuth, MAX_STEAMAUTH_LENGTH);
		for ( new i = 0; i < SurCount; i++ )
		{
			if (StrEqual(survivorsList[i], clientAuth))
			{
				return true;
			}
		}
	}
	return false;
}

// public Action:CheckBot(Handle:timer)
// {
// 	for (new i = 1; i <= MaxClients; i++)
// 	{
// 		if (!IsClientConnected(i) || !IsClientInGame(i))
// 		{
// 			continue;
// 		}
// 		if (IsValidSurvivor(i, true) && IsAlive(i) && IsFakeClient(i))
// 		{
// 			ForcePlayerSuicide(i);
// 		}
// 		RequestFrame(DeleteDeadBody, i);
// 	}
// }

public Action:Event_PlayerDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if (isRoundEnd || hasKilledAll || mapChange)
	{
		return Plugin_Continue;
	}
	if(linchpin < 1)
	{
		return Plugin_Continue;
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsAllowedChange(client))
	{
		ResetSurGlowAll();
		if (client == linchpin)
		{
			KillAll();
			PrintToChatAll("\x03选定玩家\x04%N\x03死亡", client);
		}
		else if (client != linchpin)
		{
			decl String:temp[MAX_STEAMAUTH_LENGTH];
			GetClientAuthId(client, AuthId_Steam2, temp, MAX_STEAMAUTH_LENGTH);
			new check = FindIndexBySteamId(temp);
			if (check > -1)
			{
				survivorsStat[check] = 0;
			}
			new change = GetConVarInt(FindConVar("l4d2_pl_death_linchpin_change"));
			if (change == 1)
			{
				new index = RandomIndex();
				if (index == check)
				{
					KillAll();
					PrintToChatAll("\x03玩家\x04%s\x03死亡, 选定玩家变更为\x04%s\x03(已死亡)", survivorsName[check], survivorsName[check]);
				}
				else
				{
					if (survivorsStat[index] == 1)
					{
						new chose = FindClientBySteamId(survivorsList[index]);
						linchpin = chose;
						SetSurGlowColor(linchpin);
						PlayInfoSound();
						PrintToChatAll("\x03玩家\x04%s\x03死亡, 选定玩家变更为\x04%s", survivorsName[check], survivorsName[index]);
					}
					else
					{
						KillAll();
						PrintToChatAll("\x03玩家\x04%s\x03死亡, 选定玩家变更为\x04%s\x03(已死亡)", survivorsName[check], survivorsName[index]);
					}
				}
			}
			else
			{
				PrintToChatAll("\x03玩家\x04%s\x03死亡, 选定玩家\x04不变", survivorsName[check]);
			}
		}
	}
	return Plugin_Continue;
}

bool:IsAllowedChange(client)
{
	if (!IsCountDownFinished())
	{
		return false;
	}
	if (client < 1 || client > MaxClients)
	{
		return false;
	}
	if (!IsClientAuthorized(client))
	{
		return false;
	}
	decl String:temp[MAX_STEAMAUTH_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, temp, MAX_STEAMAUTH_LENGTH);
	if (FindIndexBySteamId(temp) == -1)
	{
		return false;
	}
	return true;
}

FindIndexBySteamId(const String:auth[])
{
	for (new index = 0; index < SurCount; index++)
	{
		if (StrEqual(auth, survivorsList[index]))
		{
			return index;
		}
	}
	return -1;
}

public OnClientConnected(client)
{
	if (!IsFakeClient(client))
	{
		PrintToChatAll("\x03玩家\x04%N\x03正在加入游戏", client);
	}
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_TraceAttack, SIOnTraceAttack);
	JoinTeam(client);
	CreateTimer(1.0, TimerClientConnect, client);
	CreateTimer(0.2, TimerStripClient, client);
}

public Action:TimerStripClient(Handle:timer, any:client)
{
	if (IsValidSurvivor(client, true))
	{
		DeletePlayerAllSlot(client);
	}
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_TraceAttack, SIOnTraceAttack);
	if ((IsClientInGame(client) && GetClientTeam(client) != 2) || IsFakeClient(client) || !IsCountDownFinished() || isRoundEnd || mapChange)
	{
		return;
	}
	decl String:tempId[MAX_STEAMAUTH_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, tempId, MAX_STEAMAUTH_LENGTH);
	new checkIndex = FindIndexBySteamId(tempId);
	if (checkIndex == -1 || survivorsStat[checkIndex] != 1)
	{
		return;
	}
	if (IsAllowedChange(client))
	{
		ResetSurGlowAll();
		if (client == linchpin)
		{
			KillAll();
			PrintToChatAll("\x03选定玩家\x04%N\x03离线", client);
		}
		else if (client != linchpin)
		{
			decl String:temp[MAX_STEAMAUTH_LENGTH];
			GetClientAuthId(client, AuthId_Steam2, temp, MAX_STEAMAUTH_LENGTH);
			new check = FindIndexBySteamId(temp);
			if (check > -1)
			{
				survivorsStat[check] = 0;
			}
			new index = RandomIndex();
			if (index == check)
			{
				KillAll();
				PrintToChatAll("\x03玩家\x04%s\x03离线, 选定玩家变更为\x04%s\x03(已死亡)", survivorsName[check], survivorsName[check]);
			}
			else
			{
				if (survivorsStat[index] == 1)
				{
					new chose = FindClientBySteamId(survivorsList[index]);
					linchpin = chose;
					SetSurGlowColor(linchpin);
					PrintToChatAll("\x03玩家\x04%s\x03离线, 选定玩家变更为\x04%s", survivorsName[check], survivorsName[index]);
				}
				else
				{
					KillAll();
					PlayInfoSound();
					PrintToChatAll("\x03玩家\x04%s\x03离线, 选定玩家变更为\x04%s\x03(已死亡)", survivorsName[check], survivorsName[index]);
				}
			}
		}
		CreateTimer(0.1, TimerKillAllAlivedFakeBot);
	}
}

/*---近战伤害---*/
public Action:SIOnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if (damage == 0.0 ||
		victim < 1 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != 3 ||
		attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
	{
		return Plugin_Continue;
	}

	decl String:cName[128];
	GetEdictClassname(inflictor, cName, 128);
	if (!StrEqual(cName, "weapon_melee", false) && !StrEqual(cName, "weapon_chainsaw", false))
	{
		return Plugin_Continue;
	}
	if (StrEqual(cName, "weapon_melee", false))
	{
		if (GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)	// 是tank
		{
			if (attacker == linchpin) 
			{
                damage *= 2.0;										// 翻倍
			}
			else
			{
				damage = GetRandomFloat(0.1, 50.0);				// 修改伤害为0.1-50
			}
		}
		else
		{
			if (attacker == linchpin) 
			{
                //不调整
			}
			else
			{
				damage *= GetRandomFloat(0.1, 0.5);
			}
		}
	}
	else if (StrEqual(cName, "weapon_chainsaw", false))
	{
		damage *= GetRandomFloat(0.1, 1.0);
	}
	return Plugin_Changed;
}

/*---地精回血---*/
public Action:Event_ItemPickup(Handle:event, String:name[], bool:dontBroadcast)
{
	decl String:sTemp[32];
	GetEventString(event, "item", sTemp, sizeof(sTemp));
	if (strcmp(sTemp, "gnome") == 0)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		gnome[client] = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

		if (timerHeal)
		{
			timerHeal = false;
			CreateTimer(1.0, TimerHealLinchpin);
		}
	}
	if (strcmp(sTemp, "cola_bottles") == 0)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		cola[client] = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		lastCola = cola[client];

		if (timerCola)
		{
			timerCola = false;
			CreateTimer(1.0, TimerTakeCola);
		}
	}
}

public Action:TimerHealLinchpin(Handle:timer)
{
	if (!IsValidSurvivor(linchpin, false))
	{
		return Plugin_Continue;
	}
	new entity;
	new bool:healed = false;
	for( new i = 1; i <= MaxClients; i++ )
	{
		entity = gnome[i];
		if (entity)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && entity == GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon"))
			{
				if (!(IsPinned(linchpin) || IsIncapped(linchpin) || IsHangingFromLedge(linchpin)))
				{
					HealClient(linchpin);
				}
				healed = true;
			}
			else
			{
				gnome[i] = 0;
			}
		}
	}

	if (healed)
	{
		CreateTimer(1.0, TimerHealLinchpin);
	}
	else
	{
		timerHeal = true;
	}
	return Plugin_Continue;
}

HealClient(client)
{
	new health = GetClientHealth(client);
	if (health >= 100)
	{
		return;
	}
	SetEntityHealth(client, (health + 1));
}
/*---可乐荧光---*/
public Action:TimerTakeCola(Handle:timer)
{
	new entity;
	new bool:need;
	for( new i = 1; i <= MaxClients; i++ )
	{
		entity = cola[i];
		if (entity)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && entity == GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon"))
			{
				need = true;
			}
			else
			{
				cola[i] = 0;
			}
		}
	}
	
	if (need == true)
	{
		SetInfGlowC();
		CreateTimer(1.0, TimerTakeCola);
	}
	else
	{
		SetInfGlowD();
		timerCola = true;
	}
	return Plugin_Continue;
}

SetInfGlowC()
{
	new color = colaC[lastCola];
	for( new i = 1; i <= MaxClients; i++ )
	{
		if (!IsClientInGame(i) || !IsClientConnected(i) || GetClientTeam(i) != 3)
		{
			continue;
		}
		if (IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Send, "m_iGlowType", 3);
			SetEntProp(i, Prop_Send, "m_glowColorOverride", color);
			SetEntProp(i, Prop_Send, "m_nGlowRange", 2048);
			SetEntProp(i, Prop_Send, "m_bFlashing", 0);
		}
		else
		{
			SetEntProp(i, Prop_Send, "m_iGlowType", 0);
			SetEntProp(i, Prop_Send, "m_glowColorOverride", 0);
			SetEntProp(i, Prop_Send, "m_nGlowRange", 0);
			SetEntProp(i, Prop_Send, "m_bFlashing", 0);
		}
	}
}

SetInfGlowD()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if (!IsClientInGame(i) || !IsClientConnected(i) || GetClientTeam(i) != 3)
		{
			continue;
		}
		SetEntProp(i, Prop_Send, "m_iGlowType", 0);
		SetEntProp(i, Prop_Send, "m_glowColorOverride", 0);
		SetEntProp(i, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(i, Prop_Send, "m_bFlashing", 0);
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrContains(classname,"cola_bottles",false) > -1)
	{
		new r = GetRandomInt(0, 200);
		new g = GetRandomInt(0, 200);
		new b = GetRandomInt(0, 200);
		colaC[entity] = RGB_TO_INT(r, g, b);
	}
	if (IsWitch(entity))
	{
		new r = GetRandomInt(0, 200);
		new g = GetRandomInt(0, 200);
		new b = GetRandomInt(0, 200);
		witchColor[entity] = RGB_TO_INT(r, g, b);
	}
}

/*---tank击飞---*/
public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client < 1 || !IsClientInGame(client) || !IsPlayerAlive(client) || !(GetClientTeam(client) == 2))
	{
		return Plugin_Continue;
	}
	new flags = GetEntityFlags(client);
	if (flags & FL_ONGROUND)
	{
		return Plugin_Continue;
	}
	decl String:weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	if (StrContains(weapon, "shotgun", false) == -1)
	{
		return Plugin_Continue;
	}
	new Float:startPos[3];
	new Float:angles[3];
	new target;
	GetClientEyePosition(client, startPos);
	GetClientEyeAngles(client, angles);
	new Handle: trace= TR_TraceRayFilterEx(startPos, angles, MASK_SHOT, RayType_Infinite, DontHitSelf, client);
	if(TR_DidHit(trace))
	{		
		target = TR_GetEntityIndex(trace);
	}
	CloseHandle(trace);
	if (target < 0)
	{
		return Plugin_Continue;
	}
	decl String:className[128];
	GetEntityNetClass(target, className, sizeof(className));
	if (!StrEqual(className, "Tank", false))
	{
		return Plugin_Continue;
	}
	//计算
	new Float:first[3];
	new Float:sec[3];
	GetClientAbsOrigin(client, first);
	GetClientAbsOrigin(target, sec);
	new Float:x = sec[0] - first[0];
	new Float:y = sec[1] - first[1];
	new Float:s = FloatAbs(SquareRoot(x * x + y * y));	// 2D向量长度
	if (s > 300.0)
	{
		return Plugin_Continue;
	}
	if (s < 1.0)
	{
		s = 1.0;
	}
	new Float:vector[3];
	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vector);	//初始化0
	vector[0] = x / s * (600.0 - 5.0 / 3.0 * s);
	vector[1] = y / s * (600.0 - 5.0 / 3.0 * s);
	vector[2] = 800.0 - 5.0 / 3.0 * s;
	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vector);
	height = sec[2];
	vecX = vector[0];
	vecY = vector[1];
	if (t_HitBack == INVALID_HANDLE)
	{
		t_HitBack = CreateTimer(0.2, CheckFly, target, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public bool:DontHitSelf(entity, mask, any:data)
{
	if(entity == data) 
	{
		return false; 
	}
	return true;
}

public Action:CheckFly(Handle:timer,any:client)
{
	if (IsClientInGame(client) && IsClientConnected(client))
	{
		new Float:pos[3];
		GetClientAbsOrigin(client, pos);
		if (pos[2] < height)
		{
			new flags = GetEntityFlags(client);
			if (flags & FL_ONGROUND)
			{
				if (t_HitBack != INVALID_HANDLE)
				{
					KillTimer(t_HitBack);
					t_HitBack = INVALID_HANDLE;
				}
				return Plugin_Stop;
			}
			else
			{
				if (IsClientInGame(client) && IsClientConnected(client))
				{
					new Float:vec[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec);
					vec[0] = vecX;
					vec[1] = vecY;
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vec);
				}
			}
		}
		else
		{
			height = pos[2];
			if (IsClientInGame(client) && IsClientConnected(client))
			{
				new Float:vec[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec);
				vec[0] = vecX;
				vec[1] = vecY;
				vec[2] -= 160.0;//0.2s间隔 z轴向上速度降160
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vec);
			}
		}
	}
	else
	{
		if (t_HitBack != INVALID_HANDLE)
		{
			KillTimer(t_HitBack);
			t_HitBack = INVALID_HANDLE;
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/*---4人以上掉出飞机不判定死亡&&榜单&&武器保存---*/
public Action:Event_FinaleVehicleLeaving(Handle:event, String:event_name[], bool:dontBroadcast)
{
	mapChange = true;
	if (!saved)
	{
		saved = true;
		cleaning = false;
		CleanSaveString();
		if (!cleaning)
		{
			SavePlayersSlotInfo();
		}
		else
		{
			CreateTimer(0.1, TimerWaitForSave);
		}
		MapPlayerListSave();
	}
}

public Action:Event_FinaleWin(Handle:event, String:event_name[], bool:dontBroadcast)
{
	mapChange = true;
	if (!saved)
	{
		saved = true;
		cleaning = false;
		CleanSaveString();
		if (!cleaning)
		{
			SavePlayersSlotInfo();
		}
		else
		{
			CreateTimer(0.1, TimerWaitForSave);
		}
		MapPlayerListSave();
	}
}

public Action:Event_MapTransition(Handle:event, String:event_name[], bool:dontBroadcast)
{
	mapChange = true;
	CreateTimer(0.1, TimerKickAllFakeBot);
	cleaning = false;
	CleanSaveString();
	if (!cleaning)
	{
		SavePlayersSlotInfo();
	}
	else
	{
		CreateTimer(0.1, TimerWaitForSave);
	}
	MapPlayerListSave();
}

public Action:TimerKickAllFakeBot(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i))
		{
			KickClient(i, "kick bot");
		}
	}
}

MapPlayerListSave()
{
	decl String:map[128];
	GetCurrentMapEx(map, 128);
	#if DEBUG
		LogMessage("map save start:%s", map);
	#endif
	if (handleDatabase != null)
	{
		decl String:query[1024];
		decl String:timeBuffer[26];
		FormatTime(timeBuffer, sizeof(timeBuffer), "%Y-%m-%d~%H:%M:%S");
		LogMessage("time:%s", timeBuffer);
		decl String:idBuffer[750];
		Format(idBuffer, sizeof(idBuffer), "steamid1 = '%s', steamid2 = '%s', steamid3 = '%s', steamid4 = '%s', steamid5 = '%s', steamid6 = '%s', steamid7 = '%s', steamid8 = '%s', steamid9 = '%s', steamid10 = '%s', steamid11 = '%s', steamid12 = '%s', steamid13 = '%s', steamid14 = '%s', steamid15 = '%s', steamid16 = '%s'", survivorsList[0], survivorsList[1], survivorsList[2], survivorsList[3], survivorsList[4], survivorsList[5], survivorsList[6], survivorsList[7], survivorsList[8], survivorsList[9], survivorsList[10], survivorsList[11], survivorsList[12], survivorsList[13], survivorsList[14], survivorsList[15]);
		Format(query, sizeof(query), "UPDATE mapdata SET time = '%s', %s WHERE map = '%s'", timeBuffer, idBuffer, map);
		#if DEBUG
			LogMessage("Func : MapPlayerListSave : q = %s", query);
		#endif
		SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
		#if DEBUG
			LogMessage("map save end:%s", map);
		#endif
	}
}

SQL_GetSavedList()
{
	if (handleDatabase != null)
	{
		decl String:query[512];
		decl String:map[128];
		GetCurrentMapEx(map, 128);
		Format(query, sizeof(query), "SELECT steamid1, steamid2, steamid3, steamid4, steamid5, steamid6, steamid7, steamid8, steamid9, steamid10, steamid11, steamid12, steamid13, steamid14, steamid15, steamid16 FROM mapdata WHERE map = '%s'", map);
		#if DEBUG
			LogMessage("Func : SQL_GetSavedList : q = %s", query);
		#endif
		SQL_TQuery(handleDatabase, DataBaseSelectMap, query);
	}
}

public DataBaseSelectMap(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if (error[0] != '\0')
	{
		LogError("SQL Error: %s", error);
	}
	if (hndl != null)
	{
		if (SQL_GetRowCount(hndl) > 0)
		{
			while (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, passList[0], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 1, passList[1], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 2, passList[2], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 3, passList[3], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 4, passList[4], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 5, passList[5], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 6, passList[6], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 7, passList[7], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 8, passList[8], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 9, passList[9], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 10, passList[10], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 11, passList[11], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 12, passList[12], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 13, passList[13], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 14, passList[14], MAX_STEAMAUTH_LENGTH);
				SQL_FetchString(hndl, 15, passList[15], MAX_STEAMAUTH_LENGTH);
			}
			new it = 0;
			for (new i = 0; i < SurCount; i++)
			{
				if (strlen(passList[i]) > 5)
				{
					it += 1;
				}
			}
			passCount = it;
			CreateTimer(1.0, SQL_GetName);
		}
	}
}

public Action:TimerClientConnect(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		if (handleDatabase != null)
		{
			SQLClientConnect(client);
		}
	}
	return Plugin_Stop;
}

public SQLClientConnect(client)
{		//检查player 添加 更新
	if (!IsFakeClient(client))
	{
		if (handleDatabase != null)
		{
			new String: query[120];
			new String: steamId[MAX_STEAMAUTH_LENGTH];

			GetClientAuthId(client, AuthId_Steam2, steamId, MAX_STEAMAUTH_LENGTH);
			Format(query, sizeof(query), "SELECT name FROM playerdata WHERE steamid = '%s'", steamId);
			#if DEBUG
				LogMessage("Func : SQLClientConnect : q = %s", query);
			#endif
			SQL_TQuery(handleDatabase, DataBaseSelestClient, query, client);
		}
	}
}

public DataBaseSelestClient(Handle:owner, Handle:hndl, String:error[], any:data)
{
	new client = data;
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (hndl != null)
			{
				if (SQL_GetRowCount(hndl) == 0)
				{
					decl String:query[200];
					decl String:steamId[MAX_STEAMAUTH_LENGTH];
					GetClientAuthId(client, AuthId_Steam2, steamId, MAX_STEAMAUTH_LENGTH);
					Format(query, sizeof(query), "INSERT INTO playerdata (steamid, name, needcheck) VALUES ('%s', '%s', 1)", steamId, "-");
					#if DEBUG
						LogMessage("Func : DataBaseSelestClient : q = %s", query);
					#endif
					SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
				}
				
				if (IsClientInGame(client))
				{
					CreateTimer(1.0, SetSQLPlayerName, client, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action:SetSQLPlayerName(Handle:timer, client)
{
	if (handleDatabase != null)
	{
		if (IsClientInGame(client))
		{
			decl String:query[512];
			decl String:name[128];
			decl String:steamId[MAX_STEAMAUTH_LENGTH];
			GetClientName(client, name, 128);
			LogMessage("Func : SetSQLPlayerName : name = %s", name);
			//if(strlen(name)>0)
			//{
			//	ReplaceString(name, sizeof(name), ";", "", false);
			//	ReplaceString(name, sizeof(name), "", "", false);
			//	ReplaceString(name, sizeof(name), "'", "", false);
			//	ReplaceString(name, sizeof(name), "/", "", false);
			//	ReplaceString(name, sizeof(name), "$", "", false);
			//	ReplaceString(name, sizeof(name), "%", "", false);
			//}
			//else
			//{
			//	Format(name, sizeof(name), "-");
			//}
			GetClientAuthId(client, AuthId_Steam2, steamId, MAX_STEAMAUTH_LENGTH);
			Format(query, sizeof(query), "UPDATE playerdata SET name = '%s',needcheck = 1 WHERE steamid = '%s'", name, steamId);
			#if DEBUG
				LogMessage("Func : SetSQLPlayerName : query = %s", query);
			#endif
			SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
		}
	}
}

public Action:SQL_GetName(Handle:timer)
{
	if (handleDatabase != null)
	{
		decl String:query[750];
		decl String:idBuffer[500];
		switch (passCount)
		{
			case 1:
			{
				Format(idBuffer, sizeof(idBuffer), "= '%s'", passList[0]);
			}
			case 2:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s')", passList[0], passList[1]);
			}
			case 3:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s')", passList[0], passList[1], passList[2]);
			}
			case 4:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3]);
			}
			case 5:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4]);
			}
			case 6:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5]);
			}
			case 7:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6]);
			}
			case 8:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7]);
			}
			case 9:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8]);
			}
			case 10:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9]);
			}
			case 11:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9], passList[10]);
			}
			case 12:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9], passList[10], passList[11]);
			}
			case 13:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9], passList[10], passList[11], passList[12]);
			}
			case 14:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9], passList[10], passList[11], passList[12], passList[13]);
			}
			case 15:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9], passList[10], passList[11], passList[12], passList[13], passList[14]);
			}
			case 16:
			{
				Format(idBuffer, sizeof(idBuffer), "IN ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", passList[0], passList[1], passList[2], passList[3], passList[4], passList[5], passList[6], passList[7], passList[8], passList[9], passList[10], passList[11], passList[12], passList[13], passList[14], passList[15]);
			}
			default:
			{
				Format(idBuffer, sizeof(idBuffer), "");
			}
		}
		
		if (passCount > 0)
		{
			Format(query, sizeof(query), "SELECT name FROM playerdata WHERE steamid %s", idBuffer);
			#if DEBUG
				LogMessage("Func : SQL_GetName : query = %s", query);
			#endif
			SQL_TQuery(handleDatabase, DataBaseGetName, query);
		}
		CreateTimer(1.0, PrintSaveList);
	}
}

public DataBaseGetName(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if (error[0] != '\0')
	{
		LogError("SQL Error: %s", error);
	}
	if (hndl != null)
	{
		new count = SQL_GetRowCount(hndl);
		if (count > 0)
		{
			#if DEBUG
				LogMessage("Func : DataBaseGetName : count = %i", count);
			#endif
			for (new i = 0; i < count; i++)
			{
				if (SQL_FetchRow(hndl))
				{
					SQL_FetchString(hndl, 0, passName[i], 256);
				}
			}
		}
	}
}

public Action:PrintSaveList(Handle:timer)
{
	if (passCount < 1)
	{
		CPrintToChatAll("{blue}当前地图榜单为空");
		return Plugin_Continue;
	}
	decl String:str[2048];
	Format(str,2048,"{blue}当前地图通关榜单:{olive}");
	for (new i = 0; i < passCount; i++)
	{
		Format(str, 2048, "%s\n %s", str, passName[i]);
	}
	CPrintToChatAll("%s", str);
	return Plugin_Continue;
}

CleanSaveString()
{
	cleaning = true;
	for (new i = 0; i < SurCount; i++)
	{
		Format(slot1[i], 40, "");
		Format(slot2[i], 40, "");
		Format(slot3[i], 40, "");
		Format(slot4[i], 40, "");
		Format(slot5[i], 40, "");
		Format(saveList[i], MAX_STEAMAUTH_LENGTH, "");
		weaponUpgrade[i] = 0;
	}
	cleaning = false;
}

public Action:TimerWaitForSave(Handle:timer)
{
	if (!cleaning)
	{
		SavePlayersSlotInfo();
	}
	else
	{
		CreateTimer(0.1, TimerWaitForSave);
	}
}

SavePlayersSlotInfo()
{
	#if DEBUG
		LogMessage("Player slots save start");
	#endif
	new i = 0;
	while (i < num)
	{
		strcopy(saveList[i], 40, survivorsList[i]);
		if (survivorsStat[i] != 1)
		{
			Format(slot1[i], 40, "");
			Format(slot2[i], 40, "");
			Format(slot3[i], 40, "");
			Format(slot4[i], 40, "");
			Format(slot5[i], 40, "");
			weaponUpgrade[i] = 0;
		}
		else
		{
			new client = FindClientBySteamId(survivorsList[i]);
			if (client > -1 && IsClientInGame(client) && GetClientTeam(client) == 2)
			{
				new gun = GetPlayerWeaponSlot(client, 0);
				new melee = GetPlayerWeaponSlot(client, 1);
				new gen = GetPlayerWeaponSlot(client, 2);
				new kits = GetPlayerWeaponSlot(client, 3);
				new pills = GetPlayerWeaponSlot(client, 4);
				decl String:buffer[40];
				if (gun > 0)
				{
					GetEdictClassname(gun, buffer, 40);
					Format(slot1[i], 40, "%s", buffer);
					
					weaponUpgrade[i] = GetEntProp(gun, Prop_Send, "m_upgradeBitVec", 4);
				}
				else
				{
					Format(slot1[i], 40, "");
				}
				if (melee > 0)
				{
					decl String:buf[40];
					GetEdictClassname(melee, buffer, 40);
					if (!strcmp(buffer, "weapon_melee", true)) // 近战
					{
						GetEntPropString(melee, Prop_Data, "m_strMapSetScriptName", buf, 40);
						Format(slot2[i], 40, "%s", buf);
					} 
					else if (!strcmp(buffer, "weapon_pistol", true)) // 手枪
					{
						if (GetEntProp(melee, Prop_Send, "m_hasDualWeapons" ) == 1) // 双枪
						{
							Format(slot2[i], 40, "dual_pistol");
						}
						else
						{
							Format(slot2[i], 40, "weapon_pistol");
						}
					}
					else // 其他
					{
						Format(slot2[i], 40, "%s", buffer);
					}
				}
				else
				{
					Format(slot2[i], 40, "");
				}
				if (gen > 0)
				{
					GetEdictClassname(gen, buffer, 40);
					Format(slot3[i], 40, "%s", buffer);
				}
				else
				{
					Format(slot3[i], 40, "");
				}
				if (kits > 0)
				{
					GetEdictClassname(kits, buffer, 40);
					Format(slot4[i], 40, "%s", buffer);
				}
				else
				{
					Format(slot4[i], 40, "");
				}
				if (pills > 0)
				{
					GetEdictClassname(pills, buffer, 40);
					Format(slot5[i], 40, "%s", buffer);
				}
				else
				{
					Format(slot5[i], 40, "");
				}
			}
		}
		#if DEBUG
			LogMessage("Player slots save: i=%i, id=%s, 1=%s, 2=%s, 3=%s, 4=%s, 5=%s", i, saveList[i], slot1[i], slot2[i], slot3[i], slot4[i], slot5[i]);
		#endif
		i += 1;
	}
	DeletePlayersSlot();
	#if DEBUG
		LogMessage("Player slots save finish");
	#endif
}

public Action:GiveBaseWeapon(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i, false))
		{
			new ent = GetPlayerWeaponSlot(i, 1);
			if (ent < 0)
			{
				GiveCommand(i, "give", "weapon_pistol", "");
			}
		}
	}
}

GiveItemFromSlotInfo()
{
	#if DEBUG
		LogMessage("Give saved weapon");
	#endif
	for (new i = 0; i < SurCount; i++)
	{
		new client = FindClientBySteamId(saveList[i]);
		if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			DeletePlayerAllSlot(client);
			if (!StrEqual(slot1[i], "", false))
			{
				GiveCommand(client, "give", slot1[i], "");
				if (weaponUpgrade[i] > 0)
				{
					new gun = GetPlayerWeaponSlot(client, 0);
					if (gun > 0)
					{
						new clipSize = GetEntProp(gun, Prop_Send, "m_iClip1", 4);
						SetEntProp(gun, Prop_Send, "m_upgradeBitVec", weaponUpgrade[i], 4);
						SetEntProp(gun, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", clipSize, 4);
					}
				}
			}
			if (!StrEqual(slot2[i], "", false))
			{
				if (StrEqual(slot2[i], "dual_pistol", false))
				{
					GiveCommand(client, "give", "weapon_pistol", "");
					GiveCommand(client, "give", "weapon_pistol", "");
				}
				else
				{
					GiveCommand(client, "give", slot2[i], "");
				}
			}
			else
			{
				GiveCommand(client, "give", "weapon_pistol", "");
			}
			if (!StrEqual(slot3[i], "", false))
			{
				GiveCommand(client, "give", slot3[i], "");
			}
			if (!StrEqual(slot4[i], "", false))
			{
				GiveCommand(client, "give", slot4[i], "");
			}
			if (!StrEqual(slot5[i], "none", false))
			{
				GiveCommand(client, "give", slot5[i], "");
			}
		}
	}
	CreateTimer(1.0, GiveBaseWeapon);
}

GiveRandomItem()
{
	#if DEBUG
		LogMessage("Give random weapon");
	#endif
	new i = 0;
	while (i < num)
	{
		new client = FindClientBySteamId(survivorsList[i]);
		if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			DeletePlayerAllSlot(client);
			new rate = GetRandomInt(1, 100);
			if (rate > 40)
			{
				new ran = GetRandomInt(0, 29);
				GiveCommand(client, "give", randomScripts[ran], "");
			}
			new melee = GetPlayerWeaponSlot(client, 1);
			if (melee < 0)
			{
				GiveCommand(client, "give", "weapon_pistol", "");
			}
		}
		i += 1;
	}
}

DeletePlayersSlot()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i, true))
		{
			DeletePlayerAllSlot(i);
		}
	}
}

DeletePlayerAllSlot(client)
{
	new slot;
	for (new i = 0; i < 5; i++)
	{
		slot = GetPlayerWeaponSlot(client, i);
		if (slot > 0)
		{
			DeletePlayerASlot(client, slot);
		}
	}
}

DeletePlayerASlot(client, weapon)
{		
	if(RemovePlayerItem(client, weapon))
	{
		AcceptEntityInput(weapon, "Kill");
	}
}

GiveCommand(client, const String:command[], const String:argument1[], const String:argument2[])
{
    if (!client)
    {
    	return;
    }
    new admindata = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s %s", command, argument1, argument2);
    SetCommandFlags(command, flags);
    SetUserFlagBits(client, admindata);
}

// GetVictim(client)
// {
//     new victim = 0;
//     /* Charger */
//     victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
//     if (victim > 0)
//     {
//         return victim;
//     }
//     victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
//     if (victim > 0)
//     {
//         return victim;
//     }

//     /* Hunter */
//     victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
//     if (victim > 0)
//     {
//         return victim;
//     }

//     /* Smoker */
//     victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
//     if (victim > 0)
//     {
//         return victim;
//     }

//     /* Jockey */
//     victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
//     if (victim > 0)
//     {
//         return victim;
//     }

//     return -1;
// }

GetCurrentMapEx(String:map[],length)
{
	new String:old[length];
	GetCurrentMap(old, length);
	StringToLower(old, map, length);
}

StringToLower(const String:input[], String:output[], size)
{
	size--;

	new x=0;
	while (input[x] != '\0' && x < size) {

		output[x] = CharToLower(input[x]);

		x++;
	}

	output[x] = '\0';
}