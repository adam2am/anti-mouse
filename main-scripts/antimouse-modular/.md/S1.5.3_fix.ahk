; ==============================================================================
; S1.5.3_fix.ahk - Targeted fixes for key navigation regression
; ==============================================================================

/*
Based on the diagnostic logging from S1.5.1 and code review in S1.5.2, the following issues
were identified as causing the key navigation regression:

1. Improper global variable references causing highlight/subGrid/currentOverlay to appear
   undefined when they should be accessible

2. The defensive IsObject checks added in S1.1 are preventing execution when valid
   objects exist but aren't properly accessed from the global scope

3. State transition issues in StartNewSelection possibly disrupting normal flow

The fixes below address these issues while maintaining the stability improvements from Stage 1.
*/

; ======================
; FIXES FOR key_processing.ahk
; ======================

; 1. Ensure UI objects are properly accessible globally
;    In key_processing.ahk, add at top level:
global highlight, subGrid ; Explicitly declare these globals for key processing module

; 2. In ProcessKeyPress function, add:
global highlight, subGrid ; Explicitly reference UI objects again to ensure they're accessible

; 3. Add diagnostic logging:
LogToFile(Format("S1.5.3 FIX | ProcessKeyPress | Check global objects: highlight={}, subGrid={}, StateMap={}",
    IsObject(highlight), IsObject(subGrid), IsObject(StateMap)), "antimouse_fix.log")

; ======================
; FIXES FOR grid_keys.ahk
; ======================

; 1. In HandleKey function, modify the state check:
; REPLACE:
if (!bypassStateCheck && (currentState != State_GRID_VISIBLE || !IsObject(StateMap['currentOverlay']))) {
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Invalid state/overlay. currentState='{}', IsObject(currentOverlay)={}. Exiting.",
            A_TickCount, currentState, IsObject(StateMap['currentOverlay'])), "antimouse_core.log")
    }
    return
}

; WITH:
if (!bypassStateCheck) {
    ; Log state check
    LogToFile(Format("S1.5.3 FIX | HandleKey | State check: currentState='{}', expect GRID_VISIBLE='{}'",
        currentState, State_GRID_VISIBLE), "antimouse_fix.log")

    ; Only exit if state is definitely not GRID_VISIBLE - continue for valid state
    if (currentState != State_GRID_VISIBLE) {
        if (enableVerboseLogging) {
            LogToFile(Format(
                "Timestamp: {} | S1.5.3 FIX | HandleKey: Invalid state='{}', expected GRID_VISIBLE. Exiting.",
                A_TickCount, currentState), "antimouse_core.log")
        }
        return
    }

    ; S1.5.3 FIX: Separate check for currentOverlay - warn but don't exit immediately
    if (!StateMap.Has('currentOverlay') || !IsObject(StateMap['currentOverlay'])) {
        ; Log the issue but continue - will try to recover
        LogToFile(Format("S1.5.3 FIX | HandleKey | WARNING: currentOverlay missing or invalid. Has='{}', IsObject='{}'",
            StateMap.Has('currentOverlay'), IsObject(StateMap.Get('currentOverlay', ""))), "antimouse_fix.log")

        ; Try to recover if we have overlays but currentOverlay not set
        if (StateMap.Has('overlays') && IsObject(StateMap['overlays']) && StateMap['overlays'].Length > 0) {
            ; Use the first available overlay
            StateMap['currentOverlay'] := StateMap['overlays'][1]
            LogToFile("S1.5.3 FIX | HandleKey | RECOVERED: Set currentOverlay to first overlay", "antimouse_fix.log")
        }
    }
}

; 2. Add object state logging at start of HandleFirstKey:
LogToFile(Format("S1.5.3 FIX | HandleFirstKey | key='{}' | highlight={}",
    key, IsObject(highlight)), "antimouse_fix.log")

; 3. Add recovery for missing highlight in HandleFirstKey:
if (!IsObject(highlight)) {
    LogToFile("S1.5.3 FIX | HandleFirstKey | ERROR: highlight is not an object. Attempting recreation.",
        "antimouse_fix.log")

    ; Try to create a new highlight object if possible
    try {
        highlight := new HighlightOverlay()
        LogToFile("S1.5.3 FIX | HandleFirstKey | Successfully recreated highlight object",
            "antimouse_fix.log")
    } catch as e {
        LogToFile(Format("S1.5.3 FIX | HandleFirstKey | Failed to recreate highlight: {}",
            e.Message), "antimouse_fix.log")
    }
}

; 4. Add recovery for missing currentOverlay in HandleFirstKey:
if (!StateMap.Has('currentOverlay') || !IsObject(StateMap['currentOverlay'])) {
    ; Try to recover by setting currentOverlay to first available overlay
    if (StateMap.Has('overlays') && IsObject(StateMap['overlays']) && StateMap['overlays'].Length > 0) {
        StateMap['currentOverlay'] := StateMap['overlays'][1]
        LogToFile("S1.5.3 FIX | HandleFirstKey | RECOVERED: Set currentOverlay to first overlay",
            "antimouse_fix.log")

        try {
            StateMap['currentOverlay'].Show()
            LogToFile("S1.5.3 FIX | HandleFirstKey | Successfully showed recovered overlay",
                "antimouse_fix.log")
        } catch as e {
            LogToFile(Format("S1.5.3 FIX | HandleFirstKey | Error showing recovered overlay: {}",
                e.Message), "antimouse_fix.log")
        }
    }
}

; 5. Add similar logging and recovery for HandleSecondKey:
LogToFile(Format("S1.5.3 FIX | HandleSecondKey | key='{}' | highlight={}, subGrid={}",
    key, IsObject(highlight), IsObject(subGrid)), "antimouse_fix.log")

; ======================
; FIXES FOR state_transitions.ahk
; ======================

; 1. Make StartNewSelection more robust by ensuring it properly clears state before transitions
;    Add logging and prevent any possible recursion:
LogToFile(Format("S1.5.3 FIX | StartNewSelection | key='{}' | currentState='{}' | firstKey='{}'",
    key, currentState, StateMap.Get('firstKey', "")), "antimouse_fix.log")

; 2. Ensure we reset firstKey early:
oldFirstKey := StateMap.Get('firstKey', "")
StateMap['firstKey'] := ""

; 3. Log state clearing:
LogToFile(Format("S1.5.3 FIX | StartNewSelection | Reset firstKey: '{}' -> ''",
    oldFirstKey), "antimouse_fix.log")

; ======================
; IMPLEMENTATION NOTES
; ======================

/*
To implement these fixes:

1. Add the global declarations at the top of key_processing.ahk
2. Modify the state check in HandleKey as shown
3. Add the highlight recovery code in HandleFirstKey
4. Add the currentOverlay recovery in both HandleFirstKey and HandleSecondKey
5. Modify StartNewSelection to clear state before transitions

These changes maintain the robust error handling from Stage 1 while ensuring
the key processing flow works correctly for valid sequences.
*/
