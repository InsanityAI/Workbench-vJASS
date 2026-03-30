library ReplayPOVDetection initializer init requires /**
    
    v1.0.0 by InsanityAI
    -------------------------------------------------------
    This snippet is used to detect which player perspective is the replay spectator currently viewing, by abusing how leaderboards work.
    In short, IsLeaderboardDisplayed will only return true for your current spectator / player

    Credits to sotzaii_shuen for finding this function (among others) with this behaviour
    -------------------------------------------------------
    1. Installation
    - Copy this script to your map
    - Put the following library in your map
    **/ GameStatus /** https://www.hiveworkshop.com/threads/gamestatus-replay-detection.293176/ 
    - Save map
    -------------------------------------------------------
    2. API
    // function GetReplayPlayer takes nothing returns player
    -  - returns the player that the replay spectator is currently observing
    -  - returns local player if it was either
    -  -  - a. unable to determine which POV was observed
    -  -  - b. not a replay (but an ongoing game)
    -------------------------------------------------------**/

    globals
        private leaderboard lb
        private leaderboard tempLeaderboard = null
        private player povPlayer = null
        private integer i = 0
        private boolean wasDisplayed = false
        private boolean somethingWrong = false
    endglobals

    // Will return whatever player the replay spectator is currently viewing, otherwise, if GameStatus determines that it is not a replay, or if it is
    // unable to determine the replay player, will return local player instead. It is advised to store the resulting player in a variable if it were to 
    // be used multiple times in same scope/instance, since it does have quite a few native calls happening during a replay
    function GetReplayPlayer takes nothing returns player
        if GetGameStatus() != GAME_STATUS_REPLAY then
            return GetLocalPlayer()
            UnitAlive
        endif

        set somethingWrong = true
        set i = 0
        loop
            set povPlayer = Player(i)

            //record player's current leaderboard
            set tempLeaderboard = PlayerGetLeaderboard(povPlayer)
            if (tempLeaderboard != null) then
                set wasDisplayed = IsLeaderboardDisplayed(tempLeaderboard)
            else
                set wasDisplayed = false
            endif

            //Check if player is being spectated
            call PlayerSetLeaderboard(povPlayer, lb)
            if IsLeaderboardDisplayed(lb) then
                set somethingWrong = false
                set i = bj_MAX_PLAYER_SLOTS //force exit after cleanup is done
            endif

            //restore player's leaderboard, if any
            if (tempLeaderboard != null) then
                call PlayerSetLeaderboard(povPlayer, tempLeaderboard)
                call LeaderboardDisplay(tempLeaderboard, wasDisplayed)
            else
                call PlayerSetLeaderboard(povPlayer, null)
            endif

            set i = i + 1
            exitwhen i >= bj_MAX_PLAYER_SLOTS
        endloop
        call LeaderboardDisplay(lb, false)

        //In case it couldn't determine observed player
        if (somethingWrong) then 
            return GetLocalPlayer()
        endif

        return povPlayer
    endfunction

    private function init takes nothing returns nothing
        set lb = CreateLeaderboard()
    endfunction
endlibrary