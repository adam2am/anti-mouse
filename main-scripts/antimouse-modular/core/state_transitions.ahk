; ==============================================================================
; core/state_transitions.ahk - State Transition Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug
global enableVerboseLogging

; Central function to handle all state transitions
TransitionToState(newState) {
    global currentState, stateTransitionTime, showcaseDebug, StateMap, subGrid, enableUltraFast, rowKeyHoldThreshold
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
        if (enableVerboseLogging) {
            FileAppend(Format("Timestamp: {} | WARNING: Recursive TransitionToState detected! Attempted '{}'->'{}'",
                A_TickCount, currentState, newState) "`n", "antimouse_core.log")
            FileAppend(Format("Timestamp: {} | Current transition stack: {}", A_TickCount,
                ArrayToString(transitionStack)) "`n", "antimouse_core.log")
        }
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
    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | CORE | TransitionToState: From '{}' -> To '{}'", currentTime, oldState,
            newState
        ) "`n", "antimouse_core.log")
    }
    ; <<< LOGGING END >>>

    ; --- Exit actions for the OLD state ---
    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | Task: 2.0 | DIAGNOSTIC | Exiting state: {}", A_TickCount, oldState) "`n",
        "antimouse_core.log")
    }
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

    ; --- Entry actions for the NEW state ---
    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | Task: 2.0 | DIAGNOSTIC | Entering state: {}", A_TickCount, newState) "`n",
        "antimouse_core.log")
    }
    if (newState == State_IDLE) {
        ; Hide main grid overlays
        if (IsObject(StateMap["overlays"])) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding main grid overlays (Entering IDLE)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            for _, overlay in StateMap["overlays"] {
                if (IsObject(overlay)) {
                    overlay.Hide()
                }
            }
        }
        ; Hide highlight
        if (IsObject(highlight)) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding highlight (Entering IDLE)", A_TickCount) "`n",
                "antimouse_core.log")
            }
            highlight.Hide()
        }
        ; Subgrid should already be hidden by exit actions, but hide again just in case
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding subGrid (Entering IDLE - safety)",
                    A_TickCount
                ) "`n", "antimouse_core.log")
            }
            subGrid.Hide()
        }
    }
    else if (newState == State_GRID_VISIBLE) {
        ; Show main grid overlays
        if (IsObject(StateMap["overlays"])) {
            if (enableVerboseLogging) {
                FileAppend(Format(
                    "Timestamp: {} | Task: 1.1 | GUI | Showing main grid overlays (Entering GRID_VISIBLE)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            for _, overlay in StateMap["overlays"] {
                if (IsObject(overlay)) {
                    overlay.Show()
                }
            }
        }
        ; Hide highlight and subgrid initially
        if (IsObject(highlight)) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 1.1 | GUI | Hiding highlight (Entering GRID_VISIBLE)",
                    A_TickCount
                ) "`n", "antimouse_core.log")
            }
            highlight.Hide()
        }
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 1.1 | GUI | Hiding subGrid (Entering GRID_VISIBLE)",
                    A_TickCount) "`n",
                "antimouse_core.log")
            }
            subGrid.Hide()
        }
    }
    else if (newState == State_SUBGRID_STANDARD) {
        ; --- Task: 4.4 Start: Optionally hide main grid ---
        ; <<< REMOVED keepGridVisible check and main grid hiding logic >>>
        ; --- Task: 4.4 End ---

        ; Ensure highlight is visible (should be updated by HandleSecondKey)
        if (IsObject(highlight)) {
            if (enableVerboseLogging) {
                FileAppend(Format(
                    "Timestamp: {} | Task: 2.1 | GUI | Ensuring highlight is shown (Entering SUBGRID_STANDARD)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            ; highlight.Show()
        }
        ; Show subgrid
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 2.11 | GUI | Showing subGrid (Entering SUBGRID_STANDARD)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            subGrid.Show()
        } else {
            if (enableVerboseLogging) {
                FileAppend(Format(
                    "Timestamp: {} | Task: 2.11 | WARNING | Cannot show subGrid - IsObject=false (Entering SUBGRID_STANDARD)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
        }
    }
    else if (newState == State_SUBGRID_ULTRAFAST) {
        ; Similar logic to SUBGRID_STANDARD for main grid visibility
        if (!keepGridVisible) {
            if (enableVerboseLogging) {
                FileAppend(Format(
                    "Timestamp: {} | Task: 4.4 | GUI | Hiding main grid (keepGridVisible=false, Entering SUBGRID_ULTRAFAST)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            if (IsObject(StateMap["overlays"])) {
                for _, overlay in StateMap["overlays"] {
                    if (IsObject(overlay)) {
                        overlay.Hide()
                    }
                }
            }
        } else {
            if (enableVerboseLogging) {
                FileAppend(Format(
                    "Timestamp: {} | Task: 4.4 | GUI | Keeping main grid visible (keepGridVisible=true, Entering SUBGRID_ULTRAFAST)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
        }
        ; Ensure highlight is visible
        if (IsObject(highlight)) {
            if (enableVerboseLogging) {
                FileAppend(Format(
                    "Timestamp: {} | Task: 2.12 | GUI | Ensuring highlight is shown (Entering SUBGRID_ULTRAFAST)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            highlight.Show()
        }
        ; Subgrid itself isn't shown in ultra-fast mode, only the highlight
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                FileAppend(Format("Timestamp: {} | Task: 2.12 | GUI | Hiding subGrid (Entering SUBGRID_ULTRAFAST)",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            subGrid.Hide()
        }
    }

    ; --- CORE LOGGING START --- Task: 2.0
    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | Task: 2.0 | CORE | TransitionToState END | newState='{}'", A_TickCount,
            newState
        ) "`n", "antimouse_core.log")
    }
    ; --- CORE LOGGING END ---

    transitionInProgress := false  ; Reset the flag before returning
}

; Function to start a new selection cycle
StartNewSelection(key) {
    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | StartNewSelection START | key={}", A_TickCount, key) "`n",
        "antimouse_core.log")
    }
    global currentState, subGrid, highlight, StateMap, enableUltraFast, showcaseDebug, g_firstKeyPressed,
        enableVerboseLogging

    ; Define currentTime at the beginning
    currentTime := A_TickCount

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    if (enableVerboseLogging) {
        FileAppend(Format(
            "Timestamp: {} | DIAGNOSTIC | StartNewSelection: key='{}', currentState='{}', g_firstKeyPressed='{}'",
            A_TickCount, key, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    }
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
    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | StartNewSelection: Resetting g_firstKeyPressed from '{}' to ''",
            A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
    }
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
    ; Transition to GRID_VISIBLE *before* processing the new key
        TransitionToState(State_GRID_VISIBLE)

    ; Call HandleKey to process the key press - ONLY if key is not empty
    if (key != "") {
        ; <<< TASK 5.1 FIX START: Defer HandleKey call >>>
        ; Use SetTimer with a negative delay (-10) to run HandleKey ASAP after current thread finishes,
        ; allowing TransitionToState to complete its GUI updates (showing overlays).
        if (enableVerboseLogging) {
            FileAppend(Format(
                "Timestamp: {} | Task: 5.1 | DIAGNOSTIC | StartNewSelection: Scheduling deferred HandleKey('{}')",
                A_TickCount, key) "`n", "antimouse_core.log")
        }
        SetTimer(() => HandleKey(key), -10) ; Defer HandleKey execution
        ; <<< TASK 5.1 FIX END >>>

        ; HandleKey(key) ; <<< REMOVED direct call
    } else {
        ; If key was empty (called from TrackCursor), just ensure state is GRID_VISIBLE and restart tracker
        ; TransitionToState(State_GRID_VISIBLE) ; Already transitioned above
        if (enableVerboseLogging) {
            FileAppend(Format(
                "Timestamp: {} | Task: 5.1 | DIAGNOSTIC | StartNewSelection: Key was empty, restarting TrackCursor directly.",
                A_TickCount) "`n", "antimouse_core.log")
        }
        SetTimer(TrackCursor, 50)
    }

    ; TrackCursor re-enabled either by deferred HandleKey or directly above for empty key
}
