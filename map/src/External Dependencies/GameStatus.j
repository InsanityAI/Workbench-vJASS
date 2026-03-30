library GameStatus uses optional PlayerUtils
/***************************************************************
*
*   v1.0.0 by TriggerHappy
*   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*   Simple API for detecting if the game is online, offline, or a replay.
*   _________________________________________________________________________
*   1. Installation
*   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*   Copy the script to your map and save it (requires JassHelper *or* JNGP)
*   _________________________________________________________________________
*   2. API
*   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*   This library provides one function
*
*       function GetGameStatus takes nothing returns integer
*
*   It returns one of the following constants
*
*       - GAME_STATUS_OFFLINE
*       - GAME_STATUS_ONLINE
*       - GAME_STATUS_REPLAY
*
***************************************************************/

// Configuration:
globals
    // The dummy unit is only created once, and removed directly after.
    private constant integer DUMMY_UNIT_ID = 'hfoo'
endglobals
// (end)

globals
    constant integer GAME_STATUS_OFFLINE = 0
    constant integer GAME_STATUS_ONLINE  = 1
    constant integer GAME_STATUS_REPLAY  = 2
 
    private integer status = 0
endglobals

function GetGameStatus takes nothing returns integer
    return status
endfunction

private module GameStatusInit

    private static method onInit takes nothing returns nothing
        local player firstPlayer
        local unit u
        local boolean selected
   
        // find an actual player
        static if not (LIBRARY_PlayerUtils) then
            set firstPlayer = Player(0)
            loop
                exitwhen (GetPlayerController(firstPlayer) == MAP_CONTROL_USER and GetPlayerSlotState(firstPlayer) == PLAYER_SLOT_STATE_PLAYING)
                set firstPlayer = Player(GetPlayerId(firstPlayer)+1)
            endloop
        else
            set firstPlayer = User.fromPlaying(0).toPlayer()
        endif
   
        // force the player to select a dummy unit
        set u = CreateUnit(firstPlayer, DUMMY_UNIT_ID, 0, 0, 0)
        call SelectUnit(u, true)
        set selected = IsUnitSelected(u, firstPlayer)
        call RemoveUnit(u)
        set u = null
   
        if (selected) then
       
            // detect if replay or offline game
            if (ReloadGameCachesFromDisk()) then
                set status = GAME_STATUS_OFFLINE
            else
                set status = GAME_STATUS_REPLAY
            endif
       
        else
            // if the unit wasn't selected instantly, the game is online
            set status = GAME_STATUS_ONLINE
        endif
   
    endmethod
 
endmodule

private struct GameStatus
    implement GameStatusInit
endstruct

endlibrary