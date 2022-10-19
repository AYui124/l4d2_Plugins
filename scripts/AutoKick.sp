#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.2"
#define MaxListCount 10000

#include <sourcemod>
#include <sdktools>
#include <smlib>

new String:saveList[MaxListCount][32];
new sayCount[MaxListCount];
new count;

public Plugin:myinfo = 
{
	name = "Chat Ban",
	author = PLUGIN_AUTHOR,
	description = "auto ban those who abuse chat",
	version = PLUGIN_VERSION,
	url = "?"
};

public OnPluginStart()
{
	
}

public OnMapStart()
{
	ReadTxt();
	for (new i = 0; i < MaxListCount; i++)
	{
		sayCount[i] = 0;
	}
	CreateTimer(5.0, Check, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action:Check(Handle:timer)
{
	for (new i = 1; i < MAXPLAYERS; i++)
	{
		if (!IsValidClient(i))
		{
			continue;
		}

		if(sayCount[i] > 10)
		{
			if(!IsInBanList(i))
			{
				decl String:buffer[32];
				GetClientAuthId(i, AuthId_Steam2, buffer, 32, true);
				Format(saveList[count], 32, "%s", buffer);
				count++;
			}
		}
		sayCount[i] = 0;
	}
	WriteText();
}

public OnClientPostAdminCheck(client)
{
	if (IsInBanList(client))
	{
		KickClient(client, "Your steamid has been banned because of vocalize/chat abuse");
		LogMessage("kick client=%N", client);
	}
}

public OnClientSayCommand_Post(client, const String:command[], const String:sArgs[])
{
	if (!IsValidClient(client))
	{
		return;
	}
	sayCount[client]++;
}

public WriteText()
{
	new Handle:file = INVALID_HANDLE;
	decl String:folderPath[256];
	Format(folderPath, 256, "/addons/sourcemod/data/ban");
	decl String:filePath[256];
	Format(filePath, 256, "%s/%s.txt", folderPath, "bannedIds");
	if (!FileExists(filePath, false, "GAME"))
	{
		LogError("Error file '%s' not existed.", filePath);
	}
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		file = INVALID_HANDLE;
	}
	file = OpenFile(filePath, "w", false, "GAME");
	if (!file)
	{
		LogError("Error opening file via file '%s'.", filePath);
	}
	for (new i = 0; i < MaxListCount; i++)
	{
		if(strlen(saveList[i]) > 10)
		{
			String_Trim(saveList[i], saveList[i], 32);
			WriteFileLine(file, saveList[i]);
			FlushFile(file);
		}
	}
	FlushFile(file);
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		file = INVALID_HANDLE;
	}
}


public ReadTxt()
{
	new Handle:file = INVALID_HANDLE;
	decl String:folderPath[256];
	Format(folderPath, 256, "/addons/sourcemod/data/ban");
	decl String:filePath[256];
	Format(filePath, 256, "%s/%s.txt", folderPath, "bannedIds");
	if (!FileExists(filePath, false, "GAME"))
	{
		LogError("Error file '%s' not existed.", filePath);
	}
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		file = INVALID_HANDLE;
	}
	file = OpenFile(filePath, "r", false, "GAME");
	if (!file)
	{
		LogError("Error opening file via file '%s'.", filePath);
	}

	decl String:buffer[32];
	count = 0;
	while (!IsEndOfFile(file))
	{
		ReadFileLine(file, buffer, 32);
		if(strlen(buffer)>10)
		{
			if (Array_FindString(saveList, MaxListCount, buffer, false, 0) < 0)
			{
				Format(saveList[count], 32, buffer);
				count++;
			}
		}
	}
	if (file != INVALID_HANDLE)
	{
		CloseHandle(file);
		file = INVALID_HANDLE;
	}
	return 0;
}

public bool:IsInBanList(client)
{
	if (!IsClientInGame(client))
	{
		LogMessage("Not in game or connected:%N", client);
		return false;
	}
	decl String:buffer[32];
	GetClientAuthId(client, AuthId_Steam2, buffer, 32, true);
	new i = 0;
	while (i < MaxListCount)
	{
		if (strcmp(saveList[i], buffer, true) == 0)
		{
			return true;
		}
		i++;
	}
	return false;
}

stock bool:IsValidClient(client)
{
	if ((client < 1) || (client > MaxClients)) { return false; }
	if (!IsClientInGame(client) || !IsClientConnected(client)) { return false; }
	if (GetClientTeam(client) < 1 || GetClientTeam(client) > 3) { return false; }
	if (IsFakeClient(client)) { return false; }
	return true;
}
