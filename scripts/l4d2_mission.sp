/*
*	l4d2_mission
*	Copyright (C) 2025 Yui
*   
*   Function of VPK File extraction is modified from https://github.com/SilvDev/VPK_API
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
#define PLUGIN_VERSION "0.4.1"

#define MISSIONS_PATH_WORKSHOP "addons/workshop" // If vpk in addons/workshop directory
#define MISSIONS_PATH "addons"

#define DebugVpkInfo false

public Plugin myinfo = 
{
	name = "[l4d2] mission",
	author = PLUGIN_AUTHOR,
	description = "Get first map code in coop mode from vpk",
	version = PLUGIN_VERSION,
	url = "N/A",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("LM_GetMissionFirstMapCode", Native_GetMissionFirstMapCode);

	RegPluginLibrary("l4d2_mission");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_mission_version", PLUGIN_VERSION, "l4d2_mission plugin version.");
}

int Native_GetMissionFirstMapCode(Handle plugin, int numParams)
{
	char filename[PLATFORM_MAX_PATH];
	GetNativeString(1, filename, sizeof(filename));
	char msg[PLATFORM_MAX_PATH];
	char missionFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, missionFile, sizeof(missionFile), "data/missions");
	if (!DirExists(missionFile))
	{
		CreateDirectory(missionFile, 511);
	}
	BuildPath(Path_SM, missionFile, sizeof(missionFile), "data/missions/%s.txt", filename);
	if (FileExists(missionFile))
	{
		LogMessage("[%s] file exists, skip vpk extraction!", missionFile);
	} 
	else
	{
		if (GetMissionTxtFromVpk(filename, missionFile, msg) < 0)
		{
			SetNativeString(2, "", PLATFORM_MAX_PATH);
			SetNativeString(3, msg, sizeof(msg));
			return -1;
		}
	}
	char code[PLATFORM_MAX_PATH];
	if (GetFirstMapFromMissionTxt(missionFile, code))
	{
		SetNativeString(2, code, PLATFORM_MAX_PATH);
		SetNativeString(3, "", PLATFORM_MAX_PATH);
		return 0;
	}
	SetNativeString(2, "", PLATFORM_MAX_PATH);
	SetNativeString(3, "mission txt error!", PLATFORM_MAX_PATH);
	return -1;
}

bool GetFirstMapFromMissionTxt(const char missionTxt[PLATFORM_MAX_PATH], char code[PLATFORM_MAX_PATH])
{
	Handle missions = CreateKeyValues("mission");
	FileToKeyValues(missions, missionTxt);
	KvJumpToKey(missions, "modes", false);
	if (KvJumpToKey(missions, "coop", false))
	{
		KvGotoFirstSubKey(missions);
		KvGetString(missions, "map", code, sizeof(code));
		CloseHandle(missions);
		return true;
	}
	CloseHandle(missions);
	return false;
}

// Modify from ReadVpk() in https://github.com/SilvDev/VPK_API
int GetMissionTxtFromVpk(const char filename[PLATFORM_MAX_PATH], char missionFile[PLATFORM_MAX_PATH], char msg[PLATFORM_MAX_PATH] = "")
{
	char filePath[PLATFORM_MAX_PATH];
	if (!GetVpkPath(filename, filePath))
	{
		Format(msg, sizeof(msg), "File [%s] not found", filename);
		return -1;
	}

	File fileVpk = OpenFile(filePath, "rb");
	if (fileVpk == null)
	{
		Format(msg, sizeof(msg), "Failed to open file %s", filePath);
		return -1;
	}
	int version;
	int treeSize;
	fileVpk.Seek(4, SEEK_SET); // 4 bytes for signature, we don't care about it
	ReadFileCell(fileVpk, version, 4);
	ReadFileCell(fileVpk, treeSize, 4);
	#if DebugVpkInfo
		LogMessage("vpk treeSize=[%d], version=[%d]", treeSize, version);
	#endif
    /*
	* Why 12 and 28?
	* version_1 header length is 12 bytes: signature + version + size
	* version_2 header length is 28 bytes: 12 for version_1 and 16 for other info
	*/
	int headerSize = version == 1 ? 12 : 28;
	fileVpk.Seek(headerSize, SEEK_SET); // Go to entry data 
	
	// Some variables
	char temp[PLATFORM_MAX_PATH];
	char file[PLATFORM_MAX_PATH];
	char lastDir[PLATFORM_MAX_PATH];
	char lastExt[PLATFORM_MAX_PATH];
	bool newSegment = true;
	int byteCheck;

	// VPKEntry variables 
	int entryHash;
	int entryPreloadBytes;
	int entryIndex;
	int entryOffset;
	int entryLength;
	int entryTerminator;
	do
	{
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
					#if DebugVpkInfo
						LogMessage("new extention=[%s]", lastExt);
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
				#if DebugVpkInfo
					LogMessage("new directory=[%s]", lastDir);
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
		ReadFileCell(fileVpk, entryHash, 4);
		ReadFileCell(fileVpk, entryPreloadBytes, 2);
		ReadFileCell(fileVpk, entryIndex, 2);
		ReadFileCell(fileVpk, entryOffset, 4);
		ReadFileCell(fileVpk, entryLength, 4);
		ReadFileCell(fileVpk, entryTerminator, 2);

		Format(temp, sizeof(temp), "%s%s%s", lastDir, file, lastExt);
		#if DebugVpkInfo
			LogMessage("new file=[%s] info:entryIndex=%d,entryPreloadBytes=%d,entryOffset=%d,entryLength=%d", temp, entryIndex, entryPreloadBytes, entryOffset, entryLength);
		#endif
		// We only need to get txt in missions directory
		if (StrContains(temp, "missions/") > -1)
		{
			LogMessage("Find mission=[%s], length=[%d]", temp, entryLength);
			File fRead = OpenFile(filePath, "rb");
			fRead.Seek(fileVpk.Position, SEEK_SET);
			File fWrite = OpenFile(missionFile, "wb+");
			if (entryPreloadBytes > 0)
			{
				for (int index = 0; index < entryPreloadBytes; index++)
				{
					int copyByte;
					ReadFileCell(fRead, copyByte, 1);
					WriteFileCell(fWrite, copyByte, 1);
				}
			}
			
			if (entryLength > 0)
			{
				if (entryIndex == 0x7fff)
				{
					// Maybe cause timeout if entry is a large file, but no problem here for mission txt
					int offset = entryOffset + headerSize + treeSize;
					fRead.Seek(offset, SEEK_SET);
					for (int index = 0; index < entryLength; index++)
					{
						int copyByte;
						ReadFileCell(fRead, copyByte, 1);
						WriteFileCell(fWrite, copyByte, 1);
					}
				} 
				else
				{
					// Just extract .txt file from mission folder, we dont care about others like .vpk
				}
				
			}
			fWrite.Flush();
			delete fRead;
			delete fWrite;
		}

		if (entryPreloadBytes)
		{
			fileVpk.Seek(fileVpk.Position + entryPreloadBytes, SEEK_SET);
		}

		newSegment = false;
		NewSegmentByteCheck(fileVpk, byteCheck, newSegment);
	}
	while (fileVpk.Position < treeSize);

	delete fileVpk;
	return 0;
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

int GetVpkPath(const char filename[256], char path[PLATFORM_MAX_PATH])
{
	Format(path, sizeof(path), "%s/%s.vpk", MISSIONS_PATH, filename);
	if (FileExists(path))
	{
		return 1;
	}
	Format(path, sizeof(path), "%s/%s.vpk", MISSIONS_PATH_WORKSHOP, filename);
	if (FileExists(path))
	{
		return 1;
	}
	return 0;
}