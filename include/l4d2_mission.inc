/**
 * vim  set ts=4
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http //www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http //www.sourcemod.net/license.php>.
 *
 * Version  $Id$
 */

#if defined _l4d2_mission_included
 #endinput
#endif
#define _l4d2_mission_included

#include <sourcemod>

public SharedPlugin __pl_l4d2_mission = 
{
	name = "l4d2_mission",
	file = "l4d2_mission.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_mission_SetNTVOptional()
{
	MarkNativeAsOptional("LM_GetMissionCoopMapCodes");
	MarkNativeAsOptional("LM_GetMissions");
}
#endif

/**
 * @brief Get misson code from the specified VPK file
 *
 * @param filename		The name of the VPK to open (e.g. "example" for "example.vpk")
 * @param codes			Return the codes of the coop maps of the VPK
 *
 * @return				0 on success, -1 on failed
 */
native int LM_GetMissionCoopMapCodes(const char filename[PLATFORM_MAX_PATH],  ArrayList codes);

/**
 * @brief Get all loaded missions
 *
 * @param codes			Return the codes of the coop maps of the VPK
 * @return				0 on success, -1 on failed
 */
native int LM_GetMissions(ArrayList codes);