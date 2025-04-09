; ==============================================================================
; core/state_transitions.ahk - State Transition Logic
; ==============================================================================

; Function to start a new selection cycle
StartNewSelection(key) {
    FileAppend(Format("Timestamp: {} | StartNewSelection START | key={}", A_TickCount, key) "`n", "antimouse_core.log") ; <<< CORE LOGGING
    global currentState, subGrid, highlight, StateMap, enableUltraFast, showcaseDebug, g_firstKeyPressed

    ; Define currentTime at the beginning
    currentTime := A_TickCount

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | StartNewSelection: key='{}', currentState='{}', g_firstKeyPressed='{}'",
        A_TickCount, key, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        ; Get physical key state - ONLY if key is not empty
        keyPhysicallyDown := (key != "") ? GetKeyState(key, "P") : "N/A"
        rowKeyPhysicallyDown := StateMap['activeRowKey'] != "" ? GetKeyState(StateMap['activeRowKey'], "P") : false
        logMsg := Format(
            "Timestamp: {} | StartNewSelection START | key={} | PhysicallyDown={} | currentState={} | firstKey={} | activeRowKey={} | activeRowKeyPhysicallyDown={} | inUltraFastMode={}",
            currentTime, key, keyPhysicallyDown, currentState, StateMap['firstKey'], StateMap[
                'activeRowKey'],
            rowKeyPhysicallyDown ? "DOWN" : "UP", StateMap['inUltraFastMode']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; IMPROVEMENT: Temporarily disable TrackCursor
    SetTimer(TrackCursor, 0)

    if (currentState != "SUBGRID_ACTIVE") {
        ; Re-enable TrackCursor before returning
        SetTimer(TrackCursor, 50)
        return
    }

    ; If in Ultra-Fast mode and this is the held row key, ignore - ONLY if key is not empty
    if (enableUltraFast && StateMap['inUltraFastMode'] && key != "" && key == StateMap['activeRowKey']) {
        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format("Timestamp: {} | StartNewSelection: Ignoring held row key press | key={}",
            currentTime, key) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
            SetTimer(TrackCursor, 50) ; Re-enable tracker
        return
    }

    ; If not in UltraFast mode but this is the active row key being held, don't reset - ONLY if key is not empty
    if (enableUltraFast && key != "" && key == StateMap['activeRowKey'] && GetKeyState(key, "P")) {
        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format(
            "Timestamp: {} | StartNewSelection: Ignoring active row key that's being held | key={}",
            currentTime, key) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
            SetTimer(TrackCursor, 50) ; Re-enable tracker
        return
    }

    ; Hide the subgrid first
    if (IsObject(subGrid)) {
        subGrid.Hide()
    }

    ; Hide highlight as well
    if (IsObject(highlight)) {
        highlight.Hide()
    }

    ; Reset state before handling the new key using StateMap
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | StartNewSelection: Resetting State (Before) | activeCellKey={} | activeSubCellKey={} | firstKey={} | inUltraFastMode={} | activeRowKey={}",
        currentTime, StateMap['activeCellKey'], StateMap['activeSubCellKey'], StateMap['firstKey'], StateMap[
            'inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
        StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    StateMap['firstKey'] := ""

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format("Timestamp: {} | DIAGNOSTIC | StartNewSelection: Resetting g_firstKeyPressed from '{}' to ''",
        A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; Explicitly reset g_firstKeyPressed to ensure new key selection works
    g_firstKeyPressed := ""

    StateMap['inUltraFastMode'] := false ; Exit ultra-fast mode
    StateMap['activeRowKey'] := "" ; Clear active row key
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | StartNewSelection: Reset State (After) | inUltraFastMode={} | activeRowKey={}", currentTime,
        StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
        if (showcaseDebug) FileAppend(Format(
            "Timestamp: {} | StartNewSelection: Setting currentState=GRID_VISIBLE (Before) | currentState={}",
            currentTime, currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | StartNewSelection: Transitioning from SUBGRID_ACTIVE to GRID_VISIBLE",
                A_TickCount) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    currentState := "GRID_VISIBLE"

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | StartNewSelection: Set currentState=GRID_VISIBLE (After) | currentState={}", currentTime,
        currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Force a small delay to ensure state transitions properly
        Sleep(10)

    ; Call HandleKey to process the key press - ONLY if key is not empty
    if (key != "") {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | StartNewSelection: Calling HandleKey('{}') with clean state",
            A_TickCount, key) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        HandleKey(key)
    } else {
        ; If key was empty (called from TrackCursor), just ensure state is GRID_VISIBLE and restart tracker
        currentState := "GRID_VISIBLE"
        SetTimer(TrackCursor, 50)
    }

    ; TrackCursor re-enabled in HandleKey OR above
}
