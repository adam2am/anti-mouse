; ==============================================================================
; core/state_transitions.ahk - State Transition Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug

; Central function to handle all state transitions
TransitionToState(newState) {
    global currentState, stateTransitionTime, showcaseDebug, StateMap, subGrid, enableUltraFast, rowKeyHoldThreshold
    global keepGridVisible
    local oldState
    static transitionInProgress := false  ; Static variable to detect recursive transitions
    static transitionStack := []  ; Track transition stack for debugging

    ; Helper function to convert an array to a string representation
    ArrayToString(arr) {
        result := "["
        for index, value in arr {
            if (index > 1)
                result .= ", "
            result .= value
        }
        result .= "]"
        return result
    }

    ; Check for recursive transitions
    if (transitionInProgress) {
        FileAppend(Format("Timestamp: {} | WARNING: Recursive TransitionToState detected! Attempted '{}'->'{}'",
            A_TickCount, currentState, newState) "`n", "antimouse_core.log")
        FileAppend(Format("Timestamp: {} | Current transition stack: {}", A_TickCount,
            ArrayToString(transitionStack)) "`n", "antimouse_core.log")
        return  ; Prevent the recursive transition
    }

    ; Set flag to detect recursion and track state transition
    transitionInProgress := true
    transitionStack.Push(Format("{}->'{}'", A_TickCount, newState))

    ; Limit stack size to avoid memory issues
    if (transitionStack.Length > 10) {
        transitionStack.RemoveAt(1)
    }

    oldState := currentState
    if (oldState == newState) {
        ; No actual transition needed
        transitionInProgress := false  ; Reset the flag before returning
        return
    }

    currentTime := A_TickCount
    ; <<< LOGGING START >>>
    if (showcaseDebug) {
        FileAppend(Format("Timestamp: {} | TransitionToState: From '{}' -> To '{}'", currentTime, oldState, newState) "`n",
        A_ScriptDir "\debugRapidRefresh.log")
    }
    FileAppend(Format("Timestamp: {} | CORE | TransitionToState: From '{}' -> To '{}'", currentTime, oldState, newState
    ) "`n", "antimouse_core.log")
    ; <<< LOGGING END >>>

    ; --- Perform Exit Actions for oldState ---
    if (oldState == State_GRID_VISIBLE) {
        ; Hide main grid overlays ONLY when exiting back to IDLE state
        ; Hiding when going to subgrids will be handled by subgrid entry actions.
        if (newState == State_IDLE) {
            if (IsObject(StateMap["overlays"])) {
                for _, overlay in StateMap["overlays"] {
                    if (IsObject(overlay)) {
                        try overlay.Hide()
                    }
                }
            }

            ; Add logging for grid visibility decision
            if (showcaseDebug) {
                FileAppend(Format(
                    "Timestamp: {} | TransitionToState: Hiding main grid (Transitioning to IDLE)",
                    currentTime) "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
        } else {
            ; Log that we're NOT hiding the grid on exit from GRID_VISIBLE (unless going to IDLE)
            if (showcaseDebug && newState != State_IDLE) {
                FileAppend(Format(
                    "Timestamp: {} | TransitionToState: NOT Hiding main grid on exit from GRID_VISIBLE (newState='{}')",
                    currentTime, newState) "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
        }
    }
    if (oldState == State_SUBGRID_STANDARD) {
        ; Hide standard subgrid when exiting this state
        if (IsObject(subGrid)) {
            try subGrid.Hide()
        }
    }
    if (oldState == State_SUBGRID_ULTRAFAST) {
        ; Hide subgrid when exiting ultra-fast state
        if (IsObject(subGrid)) {
            ; TODO: Potentially reset subgrid layout back to standard if needed?
            try subGrid.Hide()
        }
    }

    ; Update the state
    currentState := newState
    stateTransitionTime := currentTime

    ; --- Perform Entry Actions for newState ---
    if (newState == State_GRID_VISIBLE) {
        ; Show main grid overlays when entering GRID_VISIBLE state
        if (IsObject(StateMap["overlays"])) {
            for _, overlay in StateMap["overlays"] {
                if (IsObject(overlay)) {
                    try overlay.Show()
                }
            }
        }
    }
    /* --- Remove the entire CELL_SELECTED block --- */
    ; else if (newState == State_CELL_SELECTED) {
    ;     ; ... (entire block commented out) ...
    ; }
    /* --- End of removed block --- */
    else if (newState == State_SUBGRID_STANDARD) {
        ; Hide main grid if configured *before* showing subgrid
        if (!keepGridVisible) {
            if (IsObject(StateMap["overlays"])) {
                for _, overlay in StateMap["overlays"] {
                    if (IsObject(overlay)) {
                        try overlay.Hide()
                    }
                }
                ; Log hiding action
                if (showcaseDebug) {
                    FileAppend(Format(
                        "Timestamp: {} | TransitionToState: Hiding main grid on entry to SUBGRID_STANDARD (keepGridVisible=false)",
                        A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
            }
        }

        ; ENHANCED DEBUG: Check if subgrid exists before showing
        FileAppend(Format("Timestamp: {} | DEBUG: Entering SUBGRID_STANDARD, subGrid IsObject={}",
            A_TickCount, IsObject(subGrid)) "`n", "antimouse_core.log")

        ; Show standard subgrid when entering this state
        if (IsObject(subGrid)) {
            try {
                FileAppend(Format("Timestamp: {} | DEBUG: About to show subGrid", A_TickCount) "`n",
                "antimouse_core.log")
                subGrid.Show()
                FileAppend(Format("Timestamp: {} | DEBUG: subGrid.Show() completed successfully", A_TickCount) "`n",
                "antimouse_core.log")
            } catch as e {
                FileAppend(Format("Timestamp: {} | ERROR: Failed to show subgrid: {}", A_TickCount, e.Message) "`n",
                "antimouse_core.log")
            }
        } else {
            FileAppend(Format("Timestamp: {} | ERROR: subGrid is not a valid object when entering SUBGRID_STANDARD",
                A_TickCount) "`n", "antimouse_core.log")
        }
    }
    else if (newState == State_SUBGRID_ULTRAFAST) {
        ; Hide main grid if configured *before* showing subgrid
        if (!keepGridVisible) {
            if (IsObject(StateMap["overlays"])) {
                for _, overlay in StateMap["overlays"] {
                    if (IsObject(overlay)) {
                        try overlay.Hide()
                    }
                }
                ; Log hiding action
                if (showcaseDebug) {
                    FileAppend(Format(
                        "Timestamp: {} | TransitionToState: Hiding main grid on entry to SUBGRID_ULTRAFAST (keepGridVisible=false)",
                        A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
            }
        }

        ; Show subgrid when entering ultra-fast state
        if (IsObject(subGrid)) {
            ; TODO: Ensure subGrid is configured/updated for the ultra-fast layout before showing
            ; This will likely happen in Phase 3 logic that *triggers* this state transition.
            try subGrid.Show()
        }
    }

    transitionInProgress := false  ; Reset the flag before returning
}

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

    ; If not in a subgrid state, nothing to reset/transition from
    if (currentState != State_SUBGRID_STANDARD && currentState != State_SUBGRID_ULTRAFAST) {
        ; Re-enable TrackCursor before returning if we didn't transition
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
    ; <<< ADD LOGGING END >>>
    ; <<< STATE TRANSITION >>>
    ; Transition to GRID_VISIBLE *before* calling HandleKey for the new selection
        TransitionToState(State_GRID_VISIBLE)

    ; Force a small delay to ensure state transitions properly
    Sleep(10)

    ; Call HandleKey to process the key press - ONLY if key is not empty
    if (key != "") {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | StartNewSelection: Calling HandleKey('{}') in new state '{}'",
            A_TickCount, key, currentState) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        HandleKey(key)
    } else {
        ; If key was empty (called from TrackCursor), just ensure state is GRID_VISIBLE and restart tracker
        ; TransitionToState(State_GRID_VISIBLE) ; Already transitioned above
        SetTimer(TrackCursor, 50)
    }

    ; TrackCursor re-enabled in HandleKey OR above
}
