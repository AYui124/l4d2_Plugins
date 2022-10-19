#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "Show UserMessage",
	author = PLUGIN_AUTHOR,
	description = "N/A",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	HookUserMessage(GetUserMessageId("MessageText"), fn_HookMessage, true);
	HookUserMessage(GetUserMessageId("VGUIMenu"), fn_HookMessage, true);
	HookUserMessage(GetUserMessageId("HudMsg"), fn_HookMessage, true);
}

public Action:fn_HookMessage(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) 
{
	decl String:msg[500];
	GetUserMessageName(msg_id, msg, 500);
	new String:buf[500] = "";
	BfReadString(bf, buf, 500);
	new String:name[128];
	if(playersNum > 1)
	{
		// do nothing
	}
	else
	{
		GetClientName(players[0], name, 128);
		if (IsClientInGame(players[0]) && IsClientConnected(players[0]) && GetClientTeam(players[0]) == 2 && !IsFakeClient(players[0]))
		{
			LogMessage("-- UserMessage: %s --playersNum: %d -- players: %s -- msg: %s --", msg, playersNum, name, buf);
		}
	}
} 
