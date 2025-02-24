/*
*	l4d2_mission
*	Copyright (C) 2025 Yui
*   
*   Function about VPK file refers to https://github.com/SilvDev/VPK_API
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_mission>

#define PLUGIN_AUTHOR "Yui"
#define PLUGIN_VERSION "0.6.5"

#define MISSIONS_PATH_WORKSHOP "addons/workshop" // If vpk in addons/workshop directory
#define MISSIONS_PATH "addons"
#define	MAX_EXTRACTION_TIME 0.3
#define	LOG_VPK_EXTRACTION_DETAILS false

ArrayList missionList;

public Plugin myinfo = 
{
	name = "l4d2_mission",
	author = PLUGIN_AUTHOR,
	description = "Get map codes in coop mode from vpk",
	version = PLUGIN_VERSION,
	url = "N/A",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("LM_GetMissionCoopMapCodes", Native_GetMissionCoopMapCode);
	CreateNative("LM_GetMissions", Native_GetMissions);

	RegPluginLibrary("l4d2_mission");
	return APLRes_Success;
}

public void OnPluginStart()
{
	missionList = new ArrayList(PLATFORM_MAX_PATH);
	CreateConVar("l4d2_mission_version", PLUGIN_VERSION, "l4d2_mission plugin version.");
	CreateTimer(0.5, InitMissions, 0, 0);// Important: must not use TIMER_FLAG_NO_MAPCHANGE !!
}

public Action InitMissions(Handle timer, int data)
{
	#if LOG_VPK_EXTRACTION_DETAILS
		LogMessage("InitMissions...");
	#endif
	ArrayList paths = new ArrayList(PLATFORM_MAX_PATH, 0);
	FindVpks(paths, MISSIONS_PATH);
	FindVpks(paths, MISSIONS_PATH_WORKSHOP);
	#if LOG_VPK_EXTRACTION_DETAILS
		LogMessage("InitMissions find %d vpk files", paths.Length / 2);
	#endif
	char missionPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, missionPath, sizeof(missionPath), "data/missions");
	if (!DirExists(missionPath))
	{
		CreateDirectory(missionPath, 511);
	}
	char missionFile[PLATFORM_MAX_PATH];
	
	for (int i = 0;i < paths.Length; i+=2)
	{
		char filename[PLATFORM_MAX_PATH];
		paths.GetString(i, filename, sizeof(filename));
		char filePath[PLATFORM_MAX_PATH];
		paths.GetString(i + 1, filePath, sizeof(filePath));
		BuildPath(Path_SM, missionFile, sizeof(missionFile), "data/missions/%s.txt", filename);
		if (FileExists(missionFile))
		{
			#if LOG_VPK_EXTRACTION_DETAILS
				LogMessage("[%s] mission txt existed", filename);
			#endif
			missionList.PushString(filename);
			continue;
		}
		GetMissionTxtFromVpk(filePath, filename, missionFile);
	}
	paths.Close();
	return Plugin_Continue;
}


// Modify from ReadVpk() in https://github.com/SilvDev/VPK_API
void GetMissionTxtFromVpk(const char filePath[PLATFORM_MAX_PATH], const char filename[PLATFORM_MAX_PATH], char missionFile[PLATFORM_MAX_PATH])
{
	File fileVpk = OpenFile(filePath, "rb");
	if (fileVpk == null)
	{
		LogMessage("Failed to open file %s", filePath);
		return;
	}
	int version;
	int treeSize;
	fileVpk.Seek(4, SEEK_SET); // 4 bytes for signature, we don't care about it
	ReadFileCell(fileVpk, version, 4);
	ReadFileCell(fileVpk, treeSize, 4);

	delete fileVpk;
    /*
	* Why 12 and 28?
	* version_1 header length is 12 bytes: signature + version + size
	* version_2 header length is 28 bytes: 12 for version_1 and 16 for other info
	*/
	int headerSize = version == 1 ? 12 : 28;
	
	// Some variables
	char temp[PLATFORM_MAX_PATH];
	char file[PLATFORM_MAX_PATH];
	char lastDir[PLATFORM_MAX_PATH];
	char lastExt[PLATFORM_MAX_PATH];
	bool newSegment = true;
	int byteCheck;
	// use timer to avoid timeout
	DataPack pack = new DataPack();
	pack.WriteCell(headerSize);
	pack.WriteCell(treeSize);
	pack.WriteCell(headerSize);
	pack.WriteString(filePath);
	pack.WriteString(filename);
	pack.WriteString(missionFile);
	pack.WriteString(temp);
	pack.WriteString(file);
	pack.WriteString(lastDir);
	pack.WriteString(lastExt);
	pack.WriteCell(newSegment);
	pack.WriteCell(byteCheck);
	
	CreateTimer(0.1, ReadVpkCatalogue, pack, 0); 
}

public Action ReadVpkCatalogue(Handle timer, DataPack pack)
{
	float start = GetEngineTime();
	pack.Reset();

	char filePath[PLATFORM_MAX_PATH];
	char filename[PLATFORM_MAX_PATH];
	char missionFile[PLATFORM_MAX_PATH];

	char temp[PLATFORM_MAX_PATH];
	char file[PLATFORM_MAX_PATH];
	char lastDir[PLATFORM_MAX_PATH];
	char lastExt[PLATFORM_MAX_PATH];
	bool newSegment;
	int byteCheck;

	int headerSize = pack.ReadCell();
	int treeSize = pack.ReadCell();
	int position = pack.ReadCell();
	
	pack.ReadString(filePath, sizeof(filePath));
	pack.ReadString(filename, sizeof(filename));
	pack.ReadString(missionFile, sizeof(missionFile));
	#if LOG_VPK_EXTRACTION_DETAILS
		LogMessage("ReadVpk: [%s], position=%d", filePath, position);
	#endif
	pack.ReadString(temp, sizeof(temp));
	pack.ReadString(file, sizeof(file));
	pack.ReadString(lastDir, sizeof(lastDir));
	pack.ReadString(lastExt, sizeof(lastExt));
	newSegment = view_as<bool>(pack.ReadCell());
	byteCheck = pack.ReadCell();

	File fileVpk = OpenFile(filePath, "rb");
	fileVpk.Seek(position, SEEK_SET);
	do
	{
		// Start new process if reached timeout
		if(GetEngineTime() - start > MAX_EXTRACTION_TIME)
		{
			pack.Reset(true);
			pack.WriteCell(headerSize);
			pack.WriteCell(treeSize);
			pack.WriteCell(fileVpk.Position);
			pack.WriteString(filePath);
			pack.WriteString(filename);
			pack.WriteString(missionFile);
			pack.WriteString(temp);
			pack.WriteString(file);
			pack.WriteString(lastDir);
			pack.WriteString(lastExt);
			pack.WriteCell(newSegment);
			pack.WriteCell(byteCheck);
			CreateTimer(0.1, ReadVpkCatalogue, pack, 0);
			delete fileVpk;
			return Plugin_Continue;
		}

		if (newSegment)
		{
			if (byteCheck == 0)
			{
				byteCheck = 1;
				fileVpk.ReadString(temp, sizeof(temp));
				if (strcmp(temp, "") && strncmp(temp, " ", 1) )
				{
					if (temp[0] == ' ')
					{
						lastExt = "";
					}
					else
					{
						FormatEx(lastExt, sizeof(lastExt), ".%s", temp);
					}
					#if LOG_VPK_EXTRACTION_DETAILS
						LogMessage("New ext: [%s]", lastExt);
					#endif
				}
			}
			fileVpk.ReadString(temp, sizeof(temp));
			if (strcmp(temp, "") && strncmp(temp, " ", 1))
			{
				strcopy(lastDir, sizeof(lastDir), temp);
				if (lastDir[0] == ' ')
				{
					lastDir = "";
				}	
				else
				{
					StrCat(lastDir, sizeof(lastDir), "/");
				}
				#if LOG_VPK_EXTRACTION_DETAILS
					LogMessage("New dir: [%s]", lastDir);
				#endif
			}
		}

		fileVpk.ReadString(file, sizeof(file));
		if (file[0] == 0)
		{
			fileVpk.Seek(fileVpk.Position - 1, SEEK_SET);
			NewSegmentByteCheck(fileVpk, byteCheck, newSegment);
			continue;
		}
		// 18 bytes per file data section
		int entryHash;
		int entryPreloadBytes;
		int entryIndex;
		int entryOffset;
		int entryLength;
		int entryTerminator;
		ReadFileCell(fileVpk, entryHash, 4);
		ReadFileCell(fileVpk, entryPreloadBytes, 2);
		ReadFileCell(fileVpk, entryIndex, 2);
		ReadFileCell(fileVpk, entryOffset, 4);
		ReadFileCell(fileVpk, entryLength, 4);
		ReadFileCell(fileVpk, entryTerminator, 2);

		Format(temp, sizeof(temp), "%s%s%s", lastDir, file, lastExt);
		#if LOG_VPK_EXTRACTION_DETAILS
			LogMessage("New file: [%s], %d-%d", temp, entryOffset, entryLength);
		#endif
		// We only need to get txt in missions directory
		if (StrContains(temp, "missions/") == 0 && StrContains(temp, "addoninfo.txt") < 0 && StrContains(temp, ".txt") > 1)
		{
			#if LOG_VPK_EXTRACTION_DETAILS
				LogMessage("Find mission=[%s], length=[%d]", temp, entryLength);
			#endif
			// Create a new file handle to avoid position reset problem
			File fRead = OpenFile(filePath, "rb");
			fRead.Seek(fileVpk.Position, SEEK_SET);
			File fWrite = OpenFile(missionFile, "wb+");
			// Should write preload bytes first
			if (entryPreloadBytes > 0)
			{
				for (int index = 0; index < entryPreloadBytes; index++)
				{
					int copyByte;
					ReadFileCell(fRead, copyByte, 1);
					WriteFileCell(fWrite, copyByte, 1);
				}
			}
			fWrite.Flush();
			delete fRead;
			delete fWrite;

			if (entryLength > 0)
			{
				if (entryIndex == 0x7fff)
				{
					#if LOG_VPK_EXTRACTION_DETAILS
						LogMessage("Start Timer to extract: %s", temp);
					#endif
					int offset = entryOffset + headerSize + treeSize;
					DataPack newPack = new DataPack();
					newPack.WriteCell(offset);
					newPack.WriteCell(entryLength);
					newPack.WriteString(filePath);
					newPack.WriteString(missionFile);
					newPack.WriteString(filename);
					CreateTimer(0.1, ExtractFile, newPack, 0);
				} 
				else
				{
					// Maybe some internal vpk here, but who cares?
				}
			}
		}

		if (entryPreloadBytes)
		{
			fileVpk.Seek(fileVpk.Position + entryPreloadBytes, SEEK_SET);
		}

		newSegment = false;
		NewSegmentByteCheck(fileVpk, byteCheck, newSegment);
	}
	while (fileVpk.Position < treeSize);
	pack.Close();
	delete fileVpk;
	#if LOG_VPK_EXTRACTION_DETAILS
		LogMessage("Reading Vpk finished: %s", filePath);
	#endif
	return Plugin_Continue;
}

public Action ExtractFile(Handle timer, DataPack pack)
{
	float start = GetEngineTime();

	char filePath[PLATFORM_MAX_PATH];
	char missionFile[PLATFORM_MAX_PATH];
	char filename[PLATFORM_MAX_PATH];
	pack.Reset();
	int offset = pack.ReadCell();
	int entryLength = pack.ReadCell();
	pack.ReadString(filePath, sizeof(filePath));
	pack.ReadString(missionFile, sizeof(missionFile));
	pack.ReadString(filename, sizeof(filename));
	#if LOG_VPK_EXTRACTION_DETAILS
		LogMessage("ExtractFile: [%s], offset:%d,length:%d", missionFile, offset, entryLength);
	#endif
	File fRead = OpenFile(filePath, "rb");
	File fWrite = OpenFile(missionFile, "ab+");

	fRead.Seek(offset, SEEK_SET);
	for (int index = 0; index < entryLength; index++)
	{
		// Start new process if reached timeout
		if(GetEngineTime() - start > MAX_EXTRACTION_TIME)
		{
			fWrite.Flush();
			delete fRead;
			delete fWrite;
			pack.Reset(true);
			pack.WriteCell(offset + index);
			pack.WriteCell(entryLength - index);
			pack.WriteString(filePath);
			pack.WriteString(missionFile);
			pack.WriteString(filename);
			CreateTimer(0.1, ExtractFile, pack, TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Continue;
		}
		int copyByte;
		ReadFileCell(fRead, copyByte, 1);
		WriteFileCell(fWrite, copyByte, 1);
	}
	pack.Close();
	fWrite.Flush();
	delete fRead;
	delete fWrite;
	missionList.PushString(filename);
	return Plugin_Continue;
}

void NewSegmentByteCheck(File fileVpk, int &byteCheck, bool &newSegment)
{
	ReadFileCell(fileVpk, byteCheck, 1);
	if (byteCheck == 0 || byteCheck == 255)
	{
		newSegment = true;

		ReadFileCell(fileVpk, byteCheck, 1);
		if (byteCheck != 0)
		{
			fileVpk.Seek(fileVpk.Position - 1, SEEK_SET);
		} 
	}
	else
	{
		fileVpk.Seek(fileVpk.Position - 1, SEEK_SET);
	}
}

bool FindVpks(ArrayList paths, char path[PLATFORM_MAX_PATH])
{
	DirectoryListing dir = OpenDirectory(path);
	char temp[PLATFORM_MAX_PATH];
	FileType currType;
	while (dir.GetNext(temp, sizeof(temp), currType))
	{
		if (currType != FileType_File)
		{
			continue;
		}
		if (StrContains(temp, ".vpk", false) > -1)
		{
			char file[PLATFORM_MAX_PATH];
			Format(file, sizeof(file), "%s/%s", path, temp);
			if (!FileExists(file))
			{
				continue;
			}
			#if LOG_VPK_EXTRACTION_DETAILS
				LogMessage("FindVpks find: [%s]", file);
			#endif
			paths.PushString(temp);
			paths.PushString(file);
		}
	}
	return true;
}

int Native_GetMissionCoopMapCode(Handle plugin, int numParams)
{
	char filename[PLATFORM_MAX_PATH];
	GetNativeString(1, filename, sizeof(filename));
	char missionFile[PLATFORM_MAX_PATH];
	if (StrContains(filename, ".vpk") < 1)
	{
		LogMessage("The filename [%s] is invalid! should end with .vpk", filename);
		return -1;
	}
	BuildPath(Path_SM, missionFile, sizeof(missionFile), "data/missions/%s.txt", filename);
	if (!FileExists(missionFile))
	{
		LogMessage("The mission file [%s] is missed", missionFile);
		return -1;
	} 
	ArrayList codes = GetNativeCell(2);
	if (GetCoopModesFromMissionTxt(missionFile, codes))
	{
		return 0;
	}
	return -1;
}

bool GetCoopModesFromMissionTxt(const char missionTxt[PLATFORM_MAX_PATH], ArrayList codes)
{
	Handle missions = CreateKeyValues("mission");
	FileToKeyValues(missions, missionTxt);
	KvJumpToKey(missions, "modes", false);
	if (KvJumpToKey(missions, "coop", false))
	{
		KvGotoFirstSubKey(missions); // first map for each txt
		do
		{
			char mapName[PLATFORM_MAX_PATH];
			KvGetString(missions, "map", mapName, sizeof(mapName));
			codes.PushString(mapName);
		}
		while (KvGotoNextKey(missions));
	}
	CloseHandle(missions);
	return true;
}

int Native_GetMissions(Handle plugin, int numParams)
{	
	ArrayList list = GetNativeCell(1);
	for (int i = 0; i < missionList.Length; i++)
	{
		char buffer[PLATFORM_MAX_PATH];
		missionList.GetString(i, buffer, PLATFORM_MAX_PATH);
		if (strlen(buffer) > 1)
		{
			list.PushString(buffer);
		}
	}
	return 0;
}
