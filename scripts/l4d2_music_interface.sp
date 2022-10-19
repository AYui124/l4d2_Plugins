
#define DEBUG false

#define PLUGIN_NAME           "l4d2_music_interface"
#define PLUGIN_AUTHOR         "mYui"
#define PLUGIN_DESCRIPTION    "motd music"
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            "NA"

#define MaxClients 32

#include <sourcemod>
#include <sdktools>
#include <json>

#pragma semicolon 1


public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public OnPluginStart()
{

}
