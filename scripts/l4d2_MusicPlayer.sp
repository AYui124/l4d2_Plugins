
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
    if (_musicStopTimer != INVALID_HANDLE)
	{
		KillTimer(_musicStopTimer);
	}
}

any Native_L4d2_StartMusic(Handle plugin, int numParams)
{
	LogMessage("Call Start Music!");
	int client = view_as<int>(GetNativeCell(1));
	int urlLength;
	GetNativeStringLength(2, urlLength);
	char[] url = new char[urlLength + 1];
	GetNativeString(2, url, urlLength + 1);

	float time = view_as<float>(GetNativeCell(3));

	StartMusic(client, url, time);
}

void StartMusic(int client, char[] url, float time)
{
    motd(client, url);
    CreateTimer(time, StopMusic, client, TIMER_FLAG_NO_MAPCHANGE);
}

Action StopMusic(Handle timer, int client)
{
	motd(client, "about:blank");
}

any Native_L4d2_StopMusic(Handle plugin, int numParams)
{
    LogMessage("Call Stop Music!");
    int client = view_as<int>(GetNativeCell(1));
    CreateTimer(0.1, StopMusic, client, TIMER_FLAG_NO_MAPCHANGE);
}

void motd(int client, char[] url)
{
	Handle panel = CreateKeyValues("data");
	KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
	KvSetString(panel, "msg", url);
	ShowVGUIPanel(client, "info", panel, false);
	delete panel;
}



