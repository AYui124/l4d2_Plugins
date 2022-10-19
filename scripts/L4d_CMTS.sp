#pragma semicolon 1

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.6"

#include <sourcemod>
#include <sdktools>
#include <socket>
#include <adt_array>
#include <string>

#define MISSIONS_PATH "addons/sourcemod/data/missions_info"

new Handle:db = INVALID_HANDLE;
new Handle:csoc = INVALID_HANDLE;
new String:receivecommand[256];

public Plugin:myinfo = 
{
	name = "ChangeMap[Socket.Version]",
	author = PLUGIN_AUTHOR,
	description = "ChangeLevel Through Socket",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	// create a new tcp socket and bind
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketBind(socket, "172.17.0.2", 23456);
	// socket listen
	SocketListen(socket, OnSocketIncoming);
	
	InitializeDB();
}

public InitializeDB()
{
	if (SQL_CheckConfig("mapstatus"))
	{
		new String: cerror[80];
		db = SQL_Connect("mapstatus", true, cerror, sizeof(cerror));
	}
	if(db == INVALID_HANDLE)
	{
		return;
	}
	SQL_LockDatabase(db);
	SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS mapstatus (id INTEGER PRIMARY KEY AUTOINCREMENT, map TEXT, time INTEGER);");
	SQL_UnlockDatabase(db);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:ary)
{
	// a socket error occured
	PrintToServer("Socket error!");
	LogError("Socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}

public OnSocketIncoming(Handle:socket, Handle:newSocket, String:remoteIP[], remotePort, any:arg)
{
	PrintToServer("%s:%d socket连接", remoteIP, remotePort);

	SocketSetReceiveCallback(newSocket, OnCSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnCSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnCSocketError);

	SocketSend(newSocket, "成功连接\n");
}

public OnCSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile)
{

	if (StrContains(receiveData, "changelevel", false) > -1)
	{
		if (GetSurvivorCount(false) == 0)
		{
			Format(receivecommand, 256, "%s", receiveData);
			csoc = socket;
			CreateQuery();
		}
		else
		{
			SocketSend(socket, "失败：玩家数 > 0");
		}
	}
	
	if (StrContains(receiveData, "getmap", false) > -1)
	{
		GetMap(socket);
	}
}

public OnCSocketDisconnected(Handle:socket, any:hFile)
{
	// remote side disconnected
	PrintToServer("客户端断开连接");
	CloseHandle(socket);
}

public OnCSocketError(Handle:socket, const errorType, const errorNum, any:ary)
{
	// a socket error occured
	PrintToServer("Socket Connect error!");
	LogError("Socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
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

GetMap(Handle:socket)
{
	new Handle: missions_dir = INVALID_HANDLE;
	missions_dir = OpenDirectory(MISSIONS_PATH);
	if (missions_dir == INVALID_HANDLE)
	{
		SetFailState("Cannot open missions directory");
	}
	decl String:buffer[256];
	decl String:buf1[5000];
	decl String:buf2[5000];
	decl String:full_path[256];
	while (ReadDirEntry(missions_dir, buffer, sizeof(buffer)))
	{
		if (DirExists(buffer) || StrEqual(buffer, "credits.txt", false))
		{
			continue;
		}
		if (strlen(buf1) < 1)
		{
			Format(buf1, 5000, "%s", buffer);
		}
		else
		{
			Format(buf1, 5000, "%s,%s", buf1, buffer);
		}
		
		Format(full_path, sizeof(full_path), "%s/%s", MISSIONS_PATH, buffer); 
		new Handle: missions_kv = CreateKeyValues("mission");
		FileToKeyValues(missions_kv, full_path);
		KvJumpToKey(missions_kv, "modes", false);
		if (KvJumpToKey(missions_kv, "coop", false))
		{ 			
		
			KvGotoFirstSubKey(missions_kv); // first map
			new String:map_name[256];
			KvGetString(missions_kv, "map", map_name, sizeof(map_name));
			if (strlen(buf2) < 1)
			{
				Format(buf2, 5000, "%s", map_name);
			}
			else
			{
				Format(buf2, 5000, "%s,%s", buf2, map_name);
			}
		}
	}
	SocketSend(socket, buf1);
	Format(buf1, 5000, "");
	SocketSend(socket, buf2);
	Format(buf2, 5000, "");
}

CreateQuery()
{
	if (db != INVALID_HANDLE)
	{
		decl String:query[200];
		Format(query, sizeof(query), "SELECT time FROM mapstatus ORDER BY time DESC LIMIT 1");
		SQL_TQuery(db, SQLCallback, query, 0);
	}
}

public SQLCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl != INVALID_HANDLE)
	{
		new oldTime = 0;
		while (SQL_FetchRow(hndl))
		{
			oldTime = SQL_FetchInt(hndl, 0);
		}
		new nowTime = GetTime();
		new ival = nowTime - oldTime;
		if (ival >= 60 * 5)
		{
			SocketSend(csoc, "换图成功!");
			ServerCommand(receivecommand);
			CloseHandle(csoc);
			WriteToSQL();
			Format(receivecommand, 256, "");
		}
		else
		{
			decl String:msg[32];
			Format(msg, 32, "换图CD：%ds", 300 - ival);
			SocketSend(csoc, msg);
			CloseHandle(csoc);
		}
	}
}

WriteToSQL()
{
	if (db != INVALID_HANDLE)
	{
		decl String:query[200];
		decl String:map[128];
		Format(map,128,"%s",receivecommand);
		LogMessage("receive:%s", receivecommand);
		ReplaceString(map, 128, "changelevel ", "", true);
		LogMessage("replaced:%s", map);
		Format(query, sizeof(query), "INSERT INTO mapstatus (id, map, time) VALUES (NULL, '%s', %i)", map, GetTime());
		SQL_TQuery(db, SQLErrorCheckCallback, query);
	}
}

public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (!StrEqual("", error))
	{
		PrintToServer("Last Connect SQL Error: %s", error);
	}
}
