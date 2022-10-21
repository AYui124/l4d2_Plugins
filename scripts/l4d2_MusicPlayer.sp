
#define DEBUG false

#define PLUGIN_NAME           "l4d2_MusicPlayer"
#define PLUGIN_AUTHOR         "mYui"
#define PLUGIN_DESCRIPTION    "motd music"
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            "NA"

#define MaxClients 32

#include <sourcemod>
#include <sdktools>
#include <l4d2_MusicPlayer>

#pragma semicolon 1
#pragma newdecls required

Handle _musicStopTimer;
bool _musicWorking;


public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

	CreateNative("L4d2_StartMusic", Native_L4d2_StartMusic);
	CreateNative("L4d2_StopMusic", Native_L4d2_StopMusic);

	RegPluginLibrary("l4d2_MusicPlayer");
	return APLRes_Success;
}

public void OnMapStart()
{
}

public void OnPluginStart()
{
    HookEvent("round_start", RoundStart);
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	ClearTimer();
}
    

any Native_L4d2_StartMusic(Handle plugin, int numParams)
{
	LogMessage("Call Start Music!");
	int urlLength;
	GetNativeStringLength(1, urlLength);
	char[] url = new char[urlLength + 1];
	GetNativeString(1, url, urlLength + 1);

	float time = view_as<float>(GetNativeCell(2));

	StartMusic(url, time);
}

void StartMusic(char[] url, float time)
{
	if (_musicWorking)
	{
		LogMessage("Already Started Music!");
		return;
	}
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidSurvivor(i, false))
		{
             motd(i, url);
		}
	}
	_musicWorking = true;
	ClearTimer();
	_musicStopTimer = CreateTimer(time, TimerStopMusic, 0, TIMER_FLAG_NO_MAPCHANGE);
}

Action TimerStopMusic(Handle timer, int client)
{   
	if (StopMusic(client))
	{
		return;
	}
	for(int i = 1; i <= MaxClients; i++) 
	{
		StopMusic(i);
	}
	_musicWorking = false;
}

bool StopMusic(int client)
{
	if (IsValidSurvivor(client, false))
	{
		motd(client, "about:blank");
		return true;
	}
	return false;
}

any Native_L4d2_StopMusic(Handle plugin, int numParams)
{
    LogMessage("Call Stop Music!");
    int client = view_as<int>(GetNativeCell(1));
    StopMusic(client);
}

void motd(int client, char[] url)
{
	Handle panel = CreateKeyValues("data");
	KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
	KvSetString(panel, "msg", url);
	ShowVGUIPanel(client, "info", panel, false);
	delete panel;
}

bool IsValidSurvivor(int client, bool allowbots)
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

void ClearTimer()
{
    if (_musicStopTimer != INVALID_HANDLE)
	{
		KillTimer(_musicStopTimer);
		_musicStopTimer = INVALID_HANDLE;
	}
}

void Reset()
{
	_musicWorking = false;
}



