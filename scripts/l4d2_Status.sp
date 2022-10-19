#pragma semicolon 1

#define DEBUG false
#define WINDOWS false

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "1.0"
#define MISSIONS_PATH_All "addons/sourcemod/data/missions_info"
#define MISSIONS_PATH_Official "addons/sourcemod/data/missions_info_Official"
#define MAX_STEAMAUTH_LENGTH 21

#include <sourcemod>
#include <sdktools>
#include <socket>
#include <adt_array>
#include <string>

new Database:handleDatabase;
new String:mapName[256];
new String:buf[500];
new Handle:db = INVALID_HANDLE;
new Handle:csoc = INVALID_HANDLE;
new String:receivecommand[256];

public Plugin:myinfo = 
{
	name = "[l4d2] Server Status&Socket",
	author = PLUGIN_AUTHOR,
	description = "N/A",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	decl String:gameName[64];
	GetGameFolderName(gameName, sizeof(gameName));
	if(!StrEqual(gameName, "left4dead2", false)) 
	{ 
		SetFailState("Use this in Left 4 Dead 2 only.");
	}
	// create a new tcp socket and bind
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketBind(socket, "172.17.0.2", 23456);
	// socket listen
	SocketListen(socket, OnSocketIncoming);
	
	InitializeDB();
	
}

public InitializeDB()
{
	ConnectSqliteDB();
	ConnectMysqlDB();
}

public ConnectSqliteDB()
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

public ConnectMysqlDB()
{
	if (SQL_CheckConfig("db_linchpin"))
	{
		new String: error[80];
		handleDatabase = SQL_Connect("db_linchpin", true, error, sizeof(error));
		if (handleDatabase != null)
		{
			#if WINDOWS
				SQL_TQuery(handleDatabase, DataBaseErrorCheck, "SET NAMES 'utf8mb4'", 0);
			#endif
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

public OnMapStart()
{
	mapName = "";
	decl String:currentMap[256];
	GetCurrentMap(currentMap, sizeof(currentMap));
	if (!StrEqual(currentMap, "credits"))
	{
		GetMapName(currentMap);
	}
}

static GetMapName(String:currentMap[])
{
	new Handle: h_OnlyOfficial = FindConVar("rcm_OnlyOfficial");
	new bool:b_OnlyOfficial = GetConVarBool(h_OnlyOfficial);
	new String:Missions_Path[100];
	if(b_OnlyOfficial)
	{
		Format(Missions_Path, 100, "%s", MISSIONS_PATH_Official);
	}
	else
	{
		Format(Missions_Path, 100, "%s", MISSIONS_PATH_All);
	}
	
	new Handle:missionsDir = INVALID_HANDLE;
	missionsDir = OpenDirectory(Missions_Path);
	if (missionsDir == INVALID_HANDLE)
	{
		SetFailState("Cannot open missionsinfo directory");
	}
	decl String:buffer[256];
	decl String:fullPath[256];
	while (ReadDirEntry(missionsDir, buffer, sizeof(buffer)))
	{
		if (DirExists(buffer))
		{
			continue;
		}
		Format(fullPath, sizeof(fullPath), "%s/%s", Missions_Path, buffer);
		new Handle:missions = CreateKeyValues("mission");
		FileToKeyValues(missions, fullPath);
		KvJumpToKey(missions, "modes", false);
		if (KvJumpToKey(missions, "coop", false))
		{
			KvGotoFirstSubKey(missions); // first map for each txt
			do
			{
				decl String:map[256];
				KvGetString(missions, "map", map, sizeof(map));
				if (StrEqual(map, currentMap, false))
				{
					strcopy(mapName, 256, buffer);
					ReplaceString(mapName, sizeof(mapName), ".txt", "", false);
					StartUpdate();
					return ;
				}
			}
			while (KvGotoNextKey(missions));
		}
		else
		{
			LogMessage("Could not find a coop section in missions file: %s", fullPath);
		}
		CloseHandle(missions);
	}
	LogMessage("The map could not be found. No valid missions file?");
	CloseHandle(missionsDir);
}

StartUpdate()
{
	if (handleDatabase != null)
	{
		decl String:timeBuf[26];
		FormatTime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S");
		decl String:query[360];
		Format(query, sizeof(query), "UPDATE `statusdata` SET `time` = '%s', `map` = '%s' WHERE `server` = 'linchpin'", timeBuf, mapName);
		#if DEBUG
		LogMessage("map query = %s", query);
		#endif
		SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
		CreateTimer(5.0, StartIdSQL, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:StartIdSQL(Handle:timer)
{
	//LogMessage("now map : %s",mapName);
	decl String:timeBuf[26];
	FormatTime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S");
	new String:idBuf[500]="";
	for (new i = 1;  i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i,true))
		{
			if((IsFakeClient(i) && HasIdlePlayer(i)) || !IsFakeClient(i))
			{
				decl String:sid[MAX_STEAMAUTH_LENGTH];
				new bool:ret = GetClientAuthId(i, AuthId_Steam2, sid, MAX_STEAMAUTH_LENGTH);
				if(ret)
				{
					if (strlen(idBuf) < 5)
					{
						Format(idBuf, 500, "%s",sid);
					}
					else
					{
						Format(idBuf, 500, "%s,%s", idBuf, sid);
					}
				}
			}
		}
	}

	if (handleDatabase != null)
	{
		decl String:query[1024];
		Format(query, sizeof(query), "UPDATE `statusdata` SET `time` = '%s', `ids` = '%s' WHERE `server` = 'linchpin'", timeBuf, idBuf);
		#if DEBUG
		LogMessage("id query = %s", query);
		#endif
		SQL_TQuery(handleDatabase, DataBaseErrorCheck, query, 0);
		strcopy(buf, 500, idBuf);
	}
	
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
	if (StrContains(receiveData, "admin!changelevel", false) > -1)
	{
		decl String:buffer[256];
		strcopy(buffer, 256, receiveData);
		ReplaceString(buffer, 256, "admin!", "", true);
		LogMessage("In admin:%s",buffer);
		ServerCommand(buffer);
		SocketSend(socket, "Admin Success!");
	}
	else if (StrContains(receiveData, "changelevel", false) > -1)
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
	else if (StrContains(receiveData, "getmap", false) > -1)
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


GetMap(Handle:socket)
{
	
	new Handle: h_OnlyOfficial = FindConVar("rcm_OnlyOfficial");
	new b_OnlyOfficial = GetConVarInt(h_OnlyOfficial);
	new String:Missions_Path[100];
	if(b_OnlyOfficial==1)
	{
		Format(Missions_Path, 100, "%s", MISSIONS_PATH_Official);
	}
	else
	{
		Format(Missions_Path, 100, "%s", MISSIONS_PATH_All);
	}
	new Handle: missions_dir = INVALID_HANDLE;
	missions_dir = OpenDirectory(Missions_Path);
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
		
		Format(full_path, sizeof(full_path), "%s/%s", Missions_Path, buffer); 
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
			SocketSend(csoc, "开始换图!");
			LogMessage("receive:%s", receivecommand);
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
		ReplaceString(map, 128, "changelevel ", "", true);
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
