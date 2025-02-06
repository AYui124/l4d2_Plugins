/*
*
*
*
*/
#if defined _hint_included
 	#endinput
#endif
#define _hint_included

#define L4D2_IHFLAG_STATIC                (1 << 8)


/**
 * Creates an instructor hint.
 *
 * Note: Both infected and survivor players will see hint. No more than one at
 * a time can be shown. The "newest" hint will override the old no matter the
 * timeout and range. This instructor hint will not be shown if the given
 * player is dead.
 *
 * @param name				Instructor hint name.
 * @param target				Entity index of target.
 * @param caption				Caption of hint.
 * @param color					Color of the caption. RGB format.
 * @param iconOnScreen  		Icon when hint is on screen.
 * @param iconOffScreen 		Icon when hint is off screen.
 * @param binding       			Key binding to show.
 * @param iconOffset    			Height offset for icon from target entity's origin.
 * @param range         			Display range of hint. 0 for unlimited range.
 * @param timeout       			Timeout out for hint. 0 will persist until stopped
 *                      						with L4D2_EndInstructorHint.
 * @param allowNoDrawTarget 	Whether hint will work with targets that have 
 *                      						nodraw set.
 * @param noOffScreen			Whether when hint is off screen it will show an arrow 
 *                      						pointing to target.
 * @param forceCaption  		Whether the hint and icon will show even when occluded
 *                      						a wall.
 * @param flags         			Instructor hint bit flags. See L4D2_IHFLAG_* defines.
 * @return              				True if send, false otherwise.
 */
stock bool:L4D2_CreateInstructorHint(const String:name[], 
                                    target = 0,
                                    const String:caption[],
                                    const String:color[] = "255,255,255",
                                    const String:iconOnScreen[] = "icon_tip",
                                    const String:iconOffScreen[] = "icon_tip",
                                    const String:binding[] = "",
                                    Float:iconOffset = 0.0,
                                    Float:range = 0.0,
                                    timeout = 0,
                                    bool:allowNoDrawTarget = true,
                                    bool:noOffScreen = false,
                                    bool:forceCaption = false,
                                    flags = L4D2_IHFLAG_STATIC)
{
    new Handle:event = CreateEvent("instructor_server_hint_create", true);
    if (event == INVALID_HANDLE)
    {
        return false;
    }

    SetEventString(event, "hint_name", name);
    SetEventInt(event, "hint_target", target);
    SetEventString(event, "hint_caption", caption);
    SetEventString(event, "hint_color", color);
    SetEventString(event, "hint_icon_onscreen", iconOnScreen);
    SetEventString(event, "hint_icon_offscreen", iconOffScreen);
    SetEventString(event, "hint_binding", binding);
    SetEventFloat(event, "hint_icon_offset", iconOffset);
    SetEventFloat(event, "hint_range", range);
    SetEventInt(event, "hint_timeout", timeout);
    SetEventBool(event, "hint_allow_nodraw_target", allowNoDrawTarget);
    SetEventBool(event, "hint_nooffscreen", noOffScreen);
    SetEventBool(event, "hint_forcecaption", forceCaption);
    SetEventInt(event, "hint_flags", flags);
    FireEvent(event);
    return true;
}

/**
 * Stops all instructor hints with name.
 *
 * @param name          	Name of instructor hint to stop.
 * @return              		True if send, false otherwise.
 */
stock bool:L4D2_StopInstructorHint(const String:name[])
{
    new Handle:event = CreateEvent("instructor_server_hint_stop", true);
    if (event == INVALID_HANDLE)
    {
        return false;
    }

    SetEventString(event, "hint_name", name);
    FireEvent(event);
    return true;
}
