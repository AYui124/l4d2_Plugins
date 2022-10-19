#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "Show Vote Context",
	author = PLUGIN_AUTHOR,
	description = "N/A",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	AddCommandListener(Listener_CallVote, "callvote");
	AddCommandListener(Listener_All);
	LogMessage("Add Listener:vote");
	
	HookUserMessage(GetUserMessageId("VGUIMenu"), Hook_VGUIMenu, false);
	LogMessage("Add Hook:VGUIMenu");
}

public Action:Listener_CallVote(client, const String:command[], argc)
{
	decl String:issuer[128];
	GetClientName(client, issuer, 128);
	decl String:msg[100];
	GetCmdArg(1, msg, 100);
	LogMessage("----VoteStart----issue: %s ----msg: %s ----", issuer, msg);
	if (StrEqual(msg, "kick", false))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Listener_All(client, const String:command[], argc)
{
	decl String:issuer[128];
	GetClientName(client, issuer, 128);
	LogMessage("--ShowCommand--issuer: %s --command: %s --", issuer, command);
}

public Action:Hook_VGUIMenu(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) 
{
    new String:msg[50]="N/A";
    BfReadString(bf, msg, 50);
    LogMessage("--VGUIMenu--msg: %s --", msg);
}