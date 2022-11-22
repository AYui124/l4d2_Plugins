#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1

ConVar handleMaxSurvivor;
ConVar handleMinSurvivor;

public Plugin myinfo =
{
	name = "l4d2_MoreSurvivor",
	author = "mYui",
	description = "5+ Survivor",
	version = "1.0.0",
	url = "https://github.com/Ayui124"
};


public void OnPluginStart()
{
    HookEvents();
    SetConvar();
    AddCmds();
}

void HookEvents()
{
    HookEvent("round_start", RoundStart);
    HookEvent("round_end", RoundEnd, EventHookMode_Pre);
}

void SetConvar()
{
    handleMaxSurvivor = CreateConVar("l4d2_ms_max_survivor", "16", "生还者最多人数");
    handleMinSurvivor = CreateConVar("l4d2_ms_min_survivor", "4", "生还者最少人数");
}

void AddCmds()
{
    RegConsoleCmd("sm_add", CmdAddBot);
    RegConsoleCmd("sm_remove", CmdRemoveBot);
}

public Action CmdAddBot(int client, int args)
{
    TryAddBot();
}

public Action CmdRemoveBot(int client, int args)
{
    TryRemoveBot();
}

void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    
}

void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    
}

public void OnClientConnected(int client)
{
    if (IsVaildClient(client, 2, false) || IsVaildClient(client, 1, false))
    {
        int bot = FindAvailableBot();
        if (bot <= 0)
        {
            if(TryAddBot())
            {
                bot = FindAvailableBot();
            }
        }
        if (bot > 0)
        {
            TakeOver(client, bot);
        }
    }
}


public void OnClientDisconnect(int client)
{
    if (IsVaildClient(client, 2, false) || IsVaildClient(client, 1, false))
    {
        TryRemoveBot();
    }
}

bool TryAddBot()
{
    if (!IsReachMaxSurvivorCount())
    {
        SpawnFakeClient();
        return true;
    }
    return false; 
}

void TryRemoveBot()
{
    int minCount = GetConVarInt(handleMinSurvivor);  
    int botCount = GetSurvivorCount(1);
    int allCount = GetSurvivorCount(0);
    if (botCount > 0 && allCount > minCount)
    {
        int bot = FindAvailableBot();
        if (bot > 0)
        {
            KickClient(bot, "Kick FakeClient");
        }
    }
}

void TakeOver(int client, int bot)
{
    LogMessage("TakeOver %N %d", client, bot);
}

int FindAvailableBot()
{
    for (int i = 1; i < MaxClients; i++)
    {
        if (IsVaildClient(i, 2, true))
        {
            if (!IsFakeClient(i))
            {
                continue;
            }
            if (GetIdledPlayer(i) > 0)
            {
                continue;
            } 
            return i;
        }
    }
    return 0;
}

int GetIdledPlayer(int bot)
{
    if (!IsVaildClient(bot, 2, true) && !IsFakeClient(bot))
    {
        return 0;
    }
    if (!HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
    {
        return 0;
    }
    int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));
    if (IsVaildClient(client, 1, false))
    {
        return client;
    }
    return 0;
}

bool IsReachMaxSurvivorCount()
{
    int maxCount = GetConVarInt(handleMaxSurvivor);
    return GetSurvivorCount(0) >= maxCount;
}


/**
 * GetSurvivorCount
 * 
 * @param survivorType       0: 所有幸存者 1: 无玩家接管的bot 2: 玩家闲置接管的bot 3: 仅玩家
 */
int GetSurvivorCount(int survivorType)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsVaildClient(i, 2, true))
        {
            if (survivorType == 0)
            {
                count++;
            }
            else if (survivorType == 1)
            {
                if (IsFakeClient(i) && GetIdledPlayer(i) <= 0)
                {
                    count++;
                }
            }
            else if (survivorType == 2)
            {
                if (IsFakeClient(i) && GetIdledPlayer(i) > 0)
                {
                    count++;
                }
            }
            else if (survivorType == 3)
            {
                if(!IsFakeClient(i))
                {
                    count++;
                }
            }
        }
    }
    return count;
}

bool IsVaildClient(int client, int team, bool allowBots)
{
    if (client < 1 || client > MaxClients) 
    { 
        return false; 
    }
    if (!IsClientInGame(client) || !IsClientConnected(client)) 
    { 
        return false; 
    }
    if (GetClientTeam(client) != team) 
    { 
        return false; 
    }
    if (IsFakeClient(client) && !allowBots) 
    { 
        return false; 
    }
    return true;
}

void SpawnFakeClient()
{
	bool fakeClientKicked = false;
	int fakeClient = CreateFakeClient("FakeClient");
	if (fakeClient != 0)
	{
		ChangeClientTeam(fakeClient, 2);
		if (DispatchKeyValue(fakeClient, "classname", "survivorbot") == true)	// check if entity classname is survivorbot
		{
			if (DispatchSpawn(fakeClient) == true)								// spwan
			{
                CreateTimer(0.1, KickFakeBot, fakeClient, TIMER_REPEAT);
                fakeClientKicked = true;
			}
		}			
		if(fakeClientKicked == false)
		{
			KickClient(fakeClient, "Kicking FakeClient");
		}
	}
}

public Action KickFakeBot(Handle timer, int fakeClient)
{
	if (IsClientConnected(fakeClient))
	{
		KickClient(fakeClient, "Kick FakeClient");
		return Plugin_Stop;
	}	
	return Plugin_Continue;
}