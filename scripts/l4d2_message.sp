#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.8"

#include <sourcemod>

new Handle:file;
new bool:fileOpened;

new bool:isMapAnnonced;
new String:currentMap[128];

public Plugin:myinfo = 
{
	name = "[l4d2] chat log",
	author = PLUGIN_AUTHOR,
	description = "log players' chat",
	version = PLUGIN_VERSION,
	url = "steamcommunity.com/id/m_Yui"
};

public OnPluginStart()
{
	fileOpened = false;
	CreateTimer(20.0, NewFileCheck, _, TIMER_REPEAT);
	HookEvent("player_changename", Event_ChangeName);
}

public OnMapStart()
{
	isMapAnnonced = false;
	GetCurrentMap(currentMap, sizeof(currentMap));
}

public Action:NewFileCheck(Handle:timer)
{
	new String:folderPath[PLATFORM_MAX_PATH];
	Format(folderPath, sizeof(folderPath), "/addons/sourcemod/logs/chat");
	
	if (!DirExists(folderPath))
	{
		LogMessage("Directory does not exist, recreating it.");
		CreateDirectory(folderPath, 511);
	}
	
	new String:filePath[PLATFORM_MAX_PATH];
	new String:buffer[PLATFORM_MAX_PATH];
	
	FormatTime(buffer, sizeof(buffer), "%Y-%m-%d");
	Format(filePath, sizeof(filePath), "%s/chatlog_%s.txt", folderPath, buffer);
	
	if (!FileExists(filePath))
	{
		isMapAnnonced = false;
	}
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		fileOpened = false;
		file = INVALID_HANDLE;
	}
	file = OpenFile(filePath, "a+");
	if (file == INVALID_HANDLE)
	{
		LogError("Error opening file via file '%s'.", filePath);
		fileOpened = false;
		return Plugin_Continue;
	}
	
	fileOpened = true;
	return Plugin_Continue;
}

public OnClientSayCommand_Post(client, const String:command[], const String:sArgs[])
{
	if (!fileOpened || strlen(sArgs) == 0)
	{
		return;
	}
	new String:time[256];
	FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S");
	new String:buffer[512];
	if (client > 0 && client <= MaxClients)
	{
		new String:name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		new String:stat[64];
		new team = GetClientTeam(client);
		if (team == 1)
		{
			Format(stat, sizeof(stat), "%s", "旁观者");
		}
		else if (team == 2)
		{
			if (IsPlayerAlive(client))
			{
				Format(stat, sizeof(stat), "%s", "生还者");
			}
			else
			{
				Format(stat, sizeof(stat), "%s", "生还者(已死)");
			}
		}
		else if (team == 3)
		{
			Format(stat, sizeof(stat), "%s", "感染者");
		}
		else
		{
			Format(stat, sizeof(stat), "%s", "");	// never be used
		}
		Format(buffer, sizeof(buffer), "%s ~ [%s] %s", time, stat, name);
	}
	else
	{
		Format(buffer, sizeof(buffer), "%s ~ Console", time);
	}
	new String:text[512];
	if (!isMapAnnonced)
	{
		isMapAnnonced = true;
		Format(text, sizeof(text), "当前地图:%s%s", currentMap, "");
		WriteFileLine(file, text);
		FlushFile(file);
	}
	Format(text, sizeof(text), "%s: %s%s", buffer, sArgs, "");
	WriteFileLine(file, text);
	FlushFile(file);
}

public Action:Event_ChangeName(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:newName[MAX_NAME_LENGTH];
	GetEventString(event, "newname", newName, MAX_NAME_LENGTH);
	decl String:oldName[MAX_NAME_LENGTH];
	GetEventString(event, "oldname", oldName, MAX_NAME_LENGTH);
	if (!fileOpened)
	{
		return;
	}
	decl String:time[256];
	FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S");
	decl String:buf[512];
	if (!isMapAnnonced)
	{
		isMapAnnonced = true;
		Format(buf, sizeof(buf), "当前地图:%s%s", currentMap, "");
		WriteFileLine(file, buf);
		FlushFile(file);
	}
	Format(buf, sizeof(buf), "%s ~ %s 更名为 %s%s", time, oldName, newName, "");
	WriteFileLine(file, buf);
	FlushFile(file);
}
