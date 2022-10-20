#if defined _l4d2_MusicPlayer_included
#endinput
#endif
#define _l4d2_MusicPlayer_included

public SharedPlugin __pl_l4d2_changelevel = 
{
	name = "l4d2_MusicPlayer",
	file = "l4d2_MusicPlayer.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_MusicPlayer_SetNTVOptional()
{
	MarkNativeAsOptional("L4d2_StartMusic");
	MarkNativeAsOptional("L4d2_StopMusic");
}
#endif


/**
* @brief Start Playing Music
*
* @param	client		    client who can listen
* @param	url			    music url
* @param	time			music time
*
*/
native void L4d2_StartMusic(int client, const char[] url, float time);

/**
* @brief Stop Playing Music
*
* @param	client		    client who should stop
*
*/
native void L4d2_StopMusic(int client);