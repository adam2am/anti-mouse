; ==============================================================================
; core/state_transitions.ahk - State Transition Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug
global enableVerboseLogging

; Function to automatically detect and activate the subgrid for the cell under the cursor
; Used for Task 2.17 Automatic Subgrid Detection
; --- Task 2.17 FIX: Commented out as detection is now immediate in activation.ahk ---
; DetectCellFunc() {
;     global StateMap, highlight, enableVerboseLogging
;
;     ; Only proceed if we're in GRID_VISIBLE state
;     if (currentState != State_GRID_VISIBLE) {
;         return
;     }
;
;     ; Get the current cell under the cursor
;     cellKey := GetCurrentCell()
;
;     if (cellKey != "") {
;         ; Cell found, transition to subgrid
;         if (enableVerboseLogging) {
;             FileAppend(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Cursor in cell '{}', activating subgrid",
;                 A_TickCount, cellKey) "`n", "antimouse_core.log")
;         }
;
;         ; Get the boundary for the cell
;         boundaries := StateMap["currentOverlay"].GetCellBoundaries(cellKey)
;
;         if (IsObject(boundaries)) {
;             ; Set the active cell key
;             StateMap["activeCellKey"] := cellKey
;
;             if (enableVerboseLogging) {
;                 FileAppend(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Mouse magnetism REMOVED.", A_TickCount) "`n",
;                 "antimouse_core.log")
;             }
;
;             ; Update highlight to show the active cell
;             if (IsObject(highlight)) {
;                 highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
;                 ; highlight.Show() ; Removed - Show is handled by Update() in HighlightOverlay
;             }
;
;             ; Transition to subgrid state -- REMOVED, will be handled by TrackCursor
;             ; TransitionToState(State_SUBGRID_STANDARD)
;             if (enableVerboseLogging) {
;                 FileAppend(Format(
;                     "Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Set activeCellKey='{}', highlight updated. Transition deferred to TrackCursor.",
;                     A_TickCount, cellKey) "`n", "antimouse_core.log")
;             }
;         } else {
;             if (enableVerboseLogging) {
;                 FileAppend(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Failed to get boundaries for cell '{}'",
;                     A_TickCount, cellKey) "`n", "antimouse_core.log")
;             }
;         }
;     } else {
;         if (enableVerboseLogging) {
;             FileAppend(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Cursor not in any cell",
;                 A_TickCount) "`n", "antimouse_core.log")
;         }
;     }
; }
; --- Task 2.17 FIX END ---

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

    ; <<< TEMP DEBUG: Re-enable recursion check >>>
    ; Check for recursive transitions
    if (transitionInProgress) {
        if (enableVerboseLogging) {
            LogToFile(Format("WARNING: Recursive TransitionToState detected! Attempted '{}'->'{}'",
                currentState, newState), "antimouse_core.log")
            LogToFile(Format("Current transition stack: {}",
                ArrayToString(transitionStack)), "antimouse_core.log")
        }
        return  ; Prevent the recursive transition
    }
    ; <<< END TEMP DEBUG >>>

    ; Set flag to detect recursion and track state transition
    transitionInProgress := true ; Also re-enable setting the flag
    transitionStack.Push(Format("{}->'{}'", A_TickCount, newState))

    ; Limit stack size to avoid memory issues
    if (transitionStack.Length > 10) {
        transitionStack.RemoveAt(1)
    }

    oldState := currentState

    if (enableVerboseLogging) { ; Task Debug: Log states at start
        LogToFile(Format("DEBUG | TransitionToState START | oldState='{}', newState='{}'",
            oldState, newState), "antimouse_core.log")
    }

    if (oldState == newState) {
        ; No actual transition needed
        transitionInProgress := false ; Reset flag if we return early
        return
    }

    currentTime := A_TickCount
    ; <<< LOGGING START >>>
    if (showcaseDebug) {
        LogToFile(Format("TransitionToState: From '{}' -> To '{}'", oldState, newState),
        A_ScriptDir "\debugRapidRefresh.log")
    }
    if (enableVerboseLogging) {
        LogToFile(Format("CORE | TransitionToState: From '{}' -> To '{}'", oldState,
            newState), "antimouse_core.log")
    }
    ; <<< LOGGING END >>>

    ; --- Exit actions for the OLD state ---
    if (enableVerboseLogging) {
        LogToFile(Format("Task: 2.0 | DIAGNOSTIC | Exiting state: {}", oldState),
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
                LogToFile(Format(
                    "TransitionToState: Hiding main grid (Transitioning to IDLE)",
                    currentTime), A_ScriptDir "\debugRapidRefresh.log")
            }
        } else {
            ; Log that we're NOT hiding the grid on exit from GRID_VISIBLE (unless going to IDLE)
            if (showcaseDebug && newState != State_IDLE) {
                LogToFile(Format(
                    "TransitionToState: NOT Hiding main grid on exit from GRID_VISIBLE (newState='{}')",
                    newState), A_ScriptDir "\debugRapidRefresh.log")
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
    if (enableVerboseLogging) { ; Task Debug: Log BEFORE state assignment
        LogToFile(Format("DEBUG | TransitionToState: About to set currentState='{}'",
            newState), "antimouse_core.log")
    }
    currentState := newState
    if (enableVerboseLogging) { ; Task Debug: Log AFTER state assignment
        LogToFile(Format("DEBUG | TransitionToState: Just set currentState='{}' (readback)",
            currentState), "antimouse_core.log")
    }
    stateTransitionTime := currentTime

    ; --- Entry actions for the NEW state ---
    if (enableVerboseLogging) {
        LogToFile(Format("Task: 2.0 | DIAGNOSTIC | Entering state: {}", newState),
        "antimouse_core.log")
    }
    if (newState == State_IDLE) {
        ; Hide main grid overlays
        if (IsObject(StateMap["overlays"])) {
            if (enableVerboseLogging) {
                LogToFile(Format("Task: 2.14 | GUI | Hiding main grid overlays (Entering IDLE)",
                    A_TickCount), "antimouse_core.log")
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
                LogToFile(Format("Task: 2.14 | GUI | Hiding highlight (Entering IDLE)"),
                "antimouse_core.log")
            }
            highlight.Hide()
        }
        ; Subgrid should already be hidden by exit actions, but hide again just in case
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                LogToFile(Format("Task: 2.14 | GUI | Hiding subGrid (Entering IDLE - safety)"),
                "antimouse_core.log")
            }
            subGrid.Hide()
        }
    }
    else if (newState == State_GRID_VISIBLE) {
        ; Show main grid overlays
        if (IsObject(StateMap["overlays"])) {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Task: 1.1 | GUI | Showing main grid overlays (Entering GRID_VISIBLE)"),
                "antimouse_core.log")
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
                LogToFile(Format("Task: 1.1 | GUI | Hiding highlight (Entering GRID_VISIBLE)"),
                "antimouse_core.log")
            }
            highlight.Hide()
        }
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                LogToFile(Format("Task: 1.1 | GUI | Hiding subGrid (Entering GRID_VISIBLE)"),
                "antimouse_core.log")
            }
            subGrid.Hide()
        }

        ; Reset first key tracking
        StateMap["firstKey"] := ""
        g_firstKeyPressed := ""
    }
    else if (newState == State_SUBGRID_STANDARD) {
        ; Handle subgrid activation
        global keepGridVisible ; Reference to config option
        if (enableVerboseLogging) {
            LogToFile(Format(
                "Task: 2.12 | GUI | Activating standard subgrid (2x2) | activeCellKey={}",
                StateMap["activeCellKey"]), "antimouse_core.log")
        }

        ; --- Task 4.4: Implement keepGridVisible Option ---
        ; Show or hide the main grid overlays based on keepGridVisible setting
        if (keepGridVisible) {
            if (enableVerboseLogging) {
                LogToFile(Format("Task: 4.4 | GUI | Keeping main grid visible (keepGridVisible=true)"),
                "antimouse_core.log")
            }
            ; Keep main grid visible by not hiding it
            ; Overlays should already be visible from GRID_VISIBLE state, but ensure they are
            for _, overlay in StateMap["overlays"] {
                if (IsObject(overlay)) {
                    overlay.Show()
                }
            }
        } else {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Task: 4.4 | GUI | Hiding main grid (keepGridVisible=false) when entering SUBGRID_STANDARD"),
                "antimouse_core.log")
            }
            ; Hide main grid overlays when entering the subgrid state
            for _, overlay in StateMap["overlays"] {
                if (IsObject(overlay)) {
                    overlay.Hide()
                }
            }
        }
        ; --- End Task 4.4 ---

        ; Make sure highlight is visible
        if (IsObject(highlight)) {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Task: 2.12 | GUI | Ensuring highlight visible for cell {} (Entering SUBGRID_STANDARD)",
                    StateMap["activeCellKey"]), "antimouse_core.log")
            }
            ; Note: highlight.Update() should already make it visible, no explicit .Show() needed
        }

        ; Show the subgrid (now configured and positioned)
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Task: 2.12 | GUI | Ensuring subgrid visible (Entering SUBGRID_STANDARD)"),
                "antimouse_core.log")
            }
            subGrid.Show()
        }
    }
    else if (newState == State_SUBGRID_ULTRAFAST) {
        ; Task 2.12: Implement transition to SUBGRID_ULTRAFAST
        if (enableVerboseLogging) {
            LogToFile(Format(
                "Task: 2.12 | CORE | Activating ultra-fast subgrid (3x4) | activeCellKey={}, activeRowKey={}",
                StateMap["activeCellKey"], StateMap["activeRowKey"]), "antimouse_core.log")
        }

        ; Hide standard subgrid first (safety)
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                LogToFile(Format("Task: 2.12 | GUI | Hiding subGrid (Entering SUBGRID_ULTRAFAST)"),
                "antimouse_core.log")
            }
            subGrid.Hide()
        }

        ; Show the ultra-fast subgrid (should be already configured by this point)
        if (IsObject(subGrid)) {
            subGrid.Show()
        }
    }

    ; Reset recursive transition check and log completion
    if (enableVerboseLogging) {
        LogToFile(Format("Task: 2.0 | CORE | TransitionToState END | newState='{}'",
            currentState), "antimouse_core.log")
    }

    transitionInProgress := false  ; Reset the flag before returning
}

; Function to start a new selection cycle
StartNewSelection(key) {
    global StateMap, g_firstKeyPressed, highlight, subGrid, currentState, enableVerboseLogging, showcaseDebug

    ; --- Task: 2.16 DEBUG START ---
    if (enableVerboseLogging) {
        LogToFile(Format("DEBUG | StartNewSelection START (from key press) | key={}", key),
        "antimouse_core.log")
    }
    ; --- Task: 2.16 DEBUG END ---

    ; Safety check for current state
    if (currentState != State_SUBGRID_STANDARD && currentState != State_SUBGRID_ULTRAFAST) {
        if (enableVerboseLogging) {
            LogToFile(Format(
                "WARNING: StartNewSelection called from invalid state: {}", currentState),
            "antimouse_core.log")
        }
        return
    }

    try {
        ; Stop tracking timer when resetting selection
        SetTimer TrackCursor, 0

        ; Debugging log for showcaseDebug mode
        if (showcaseDebug) {
            logMsg := Format("Timestamp: {} | StartNewSelection: key='{}', g_firstKeyPressed='{}', firstKey='{}'",
                A_TickCount, key, g_firstKeyPressed, StateMap["firstKey"])
            LogToFile(logMsg, A_ScriptDir "\debugRapidRefresh.log")
        }

        ; Determine if key is a valid grid key (moved inside function for Task 2.16)
        isGridKey := CheckIfGridKey(key)

        ; --- Task 2.16: Free Cell Navigation ---
        ; Hide subgrid
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Task: 2.16 | StartNewSelection: Hiding subgrid for state transition"),
                "antimouse_core.log")
            }
            subGrid.Hide()
        }

        ; Hide highlight
        if (IsObject(highlight)) {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Task: 2.16 | StartNewSelection: Hiding highlight for state transition"),
                "antimouse_core.log")
            }
            highlight.Hide()
        }

        ; === ROW KEY HANDLING FOR ULTRA-FAST MODE (Task 3.3) ===
        ; Determine if we're transitioning due to a held row key release
        static keyMap := Map("u", true, "i", true, "o", true, "p", true, "j", true, "k", true, "l", true, ";", true,
            "m", true, ",", true, ".", true, "/", true)
        if (key != "" && keyMap.Has(key) && StateMap["inUltraFastMode"]) {
            ; Log that we're ignoring a row key release that would trigger another selection
            if (showcaseDebug) LogToFile(Format("StartNewSelection: Ignoring held row key press | key={}",
                key), A_ScriptDir "\debugRapidRefresh.log")
            ; Reset flag but don't handle the key (it's from the release of a held key)
                StateMap["inUltraFastMode"] := false
            return
        }
        ; === END TASK 3.3 ===

        ; Reset state tracking variables
        StateMap["activeCellKey"] := ""
        StateMap["activeSubCellKey"] := ""
        StateMap["firstKey"] := ""
        g_firstKeyPressed := ""
        StateMap["activeRowKey"] := ""
        StateMap["inUltraFastMode"] := false

        ; CRITICAL FIX: Directly set the state without using TransitionToState
        ; This avoids issues with rapid key presses causing transitions
        if (enableVerboseLogging) {
            LogToFile(Format(
                "Task: 2.16 | StartNewSelection: DIRECT STATE ASSIGNMENT | currentState = GRID_VISIBLE"),
            "antimouse_core.log")
        }
        currentState := State_GRID_VISIBLE
        if (enableVerboseLogging) {
            LogToFile(Format("DEBUG | StartNewSelection: State immediately after DIRECT assignment = {}",
                currentState), "antimouse_core.log")
        }

        ; Reset key tracking for cursor tracking function
        ResetLastTrackedKey()

        ; Restart cursor tracking
        SetTimer TrackCursor, 50

        ; If a key was pressed (not just cursor leaving cell), handle it as a grid key
        if (key != "") {
            if (isGridKey) {
                ; --- Task 2.16: Added deferred key handling ---
                ; Handle key press after state transition using a deferred function call
                if (enableVerboseLogging) {
                    LogToFile(Format(
                        "Task: 2.16 | StartNewSelection: Calling deferred HandleKey for '{}'",
                        key), "antimouse_core.log")
                }
                ; Call HandleKey outside this function to avoid reentrancy
                SetTimer(() => DeferredHandleKey(key), -50)
            } else {
                if (enableVerboseLogging) {
                    LogToFile(Format(
                        "Task: 2.16 | StartNewSelection: Key '{}' is not a valid grid key, ignoring.",
                        key), "antimouse_core.log")
                }
            }
        }
    } catch as e {
        ; Log error
        LogToFile(Format("ERROR in StartNewSelection: {}", e.Message),
        "antimouse_core.log")
        ; Try cleanup as a safety measure
        Cleanup()
    }

    ; --- Task: 2.16 DEBUG START ---
    if (enableVerboseLogging) {
        LogToFile(Format("DEBUG | StartNewSelection END (from key press) | key={}", key),
        "antimouse_core.log")
    }
    ; --- Task: 2.16 DEBUG END ---
}

; Deferred key handling function to avoid reentrancy when transitioning states
DeferredHandleKey(key) {
    if (enableVerboseLogging) {
        LogToFile(Format("DEBUG | DeferredHandleKey STARTING | currentState={}",
            currentState), "antimouse_core.log")
    }
    if (currentState == State_GRID_VISIBLE) {
        if (enableVerboseLogging) {
            LogToFile(Format("DEBUG | Deferred HandleKey Executing for key='{}'", key),
            "antimouse_core.log")
        }
        ; Call HandleKey with bypassStateCheck=true to force handling
        HandleKey(key, true)
    }
}
