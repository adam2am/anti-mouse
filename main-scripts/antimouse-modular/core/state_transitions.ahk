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
;             LogToFile(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Cursor in cell '{}', activating subgrid",
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
;                 LogToFile(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Mouse magnetism REMOVED.", A_TickCount) "`n",
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
;                 LogToFile(Format(
;                     "Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Set activeCellKey='{}', highlight updated. Transition deferred to TrackCursor.",
;                     A_TickCount, cellKey) "`n", "antimouse_core.log")
;             }
;         } else {
;             if (enableVerboseLogging) {
;                 LogToFile(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Failed to get boundaries for cell '{}'",
;                     A_TickCount, cellKey) "`n", "antimouse_core.log")
;             }
;         }
;     } else {
;         if (enableVerboseLogging) {
;             LogToFile(Format("Timestamp: {} | Task: 2.17 | AUTO-DETECTION: Cursor not in any cell",
;                 A_TickCount) "`n", "antimouse_core.log")
;         }
;     }
; }
; --- Task 2.17 FIX END ---

; Central function to handle all state transitions
TransitionToState(newState) {
    global currentState, stateTransitionTime, showcaseDebug, StateMap, subGrid, enableUltraFast, rowKeyHoldThreshold,
        keepGridVisible
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
                        try {
                            overlay.Hide()
                        } catch as e {
                            LogToFile(Format("Timestamp: {} | ERROR hiding overlay: {}", A_TickCount, e.Message) "`n",
                            "antimouse_core.log")
                        }
                    }
                }
            }
            LogToFile("Task 6.4 | TransitionToState: Hiding main grid (Exiting GRID_VISIBLE -> IDLE)",
                "antimouse_core.log")
        } else if (newState == State_SUBGRID_STANDARD || newState == State_SUBGRID_ULTRAFAST) {
            ; Don't hide main grid if keepGridVisible is true when moving to subgrid
            if (!keepGridVisible) {
                if (IsObject(StateMap["overlays"])) {
                    for _, overlay in StateMap["overlays"] {
                        if (IsObject(overlay)) {
                            try {
                                overlay.Hide()
                            } catch as e {
                                LogToFile(Format("Timestamp: {} | ERROR hiding overlay: {}", A_TickCount, e.Message) "`n",
                                "antimouse_core.log")
                            }
                        }
                    }
                }
                LogToFile(
                    "Task 6.4 | TransitionToState: Hiding main grid (Exiting GRID_VISIBLE -> SUBGRID, keepGridVisible=false)",
                    "antimouse_core.log")
            } else {
                LogToFile(
                    "Task 6.4 | TransitionToState: NOT hiding main grid (Exiting GRID_VISIBLE -> SUBGRID, keepGridVisible=true)",
                    "antimouse_core.log")
            }
        } else {
            ; Log that we're NOT hiding the grid on exit from GRID_VISIBLE (unless going to IDLE or SUBGRID)
            LogToFile(Format("Task 6.4 | TransitionToState: NOT Hiding main grid (Exiting GRID_VISIBLE -> '{}')",
                newState), "antimouse_core.log")
        }
    }
    if (oldState == State_SUBGRID_STANDARD) {
        ; Hide standard subgrid when exiting this state
        if (IsObject(subGrid)) {
            try {
                subGrid.Hide()
            } catch as e {
                LogToFile(Format("Timestamp: {} | ERROR hiding subGrid: {}", A_TickCount, e.Message) "`n",
                "antimouse_core.log")
            }
            LogToFile("Task 6.4 | TransitionToState: Hiding subGrid (Exiting SUBGRID_STANDARD)", "antimouse_core.log")
        }
    }
    if (oldState == State_SUBGRID_ULTRAFAST) {
        ; Hide subgrid when exiting ultra-fast state
        if (IsObject(subGrid)) {
            ; TODO: Potentially reset subgrid layout back to standard if needed?
            try {
                subGrid.Hide()
            } catch as e {
                LogToFile(Format("Timestamp: {} | ERROR hiding subGrid: {}", A_TickCount, e.Message) "`n",
                "antimouse_core.log")
            }
            LogToFile("Task 6.4 | TransitionToState: Hiding subGrid (Exiting SUBGRID_ULTRAFAST)", "antimouse_core.log")
        }
    }

    ; Update the state
    if (enableVerboseLogging) { ; Task Debug: Log BEFORE state assignment
        LogToFile(Format("DEBUG | TransitionToState: About to set currentState='{}'",
            newState), "antimouse_core.log")
    }

    ; --- ALWAYS SET STATE HERE ---
    currentState := newState
    if (enableVerboseLogging) { ; Task Debug: Log AFTER state assignment
        LogToFile(Format("DEBUG | TransitionToState: Set currentState='{}'",
            currentState), "antimouse_core.log")
    }

    ; --- Entry actions for the NEW state ---
    if (enableVerboseLogging) {
        LogToFile(Format("Task: 2.0 | DIAGNOSTIC | Entering state: {}", newState),
        "antimouse_core.log")
    }
    if (newState == State_GRID_VISIBLE) {
        ; Show overlay for current monitor
        if (IsObject(StateMap["currentOverlay"])) {
            try {
                StateMap["currentOverlay"].Show()
            } catch as e {
                LogToFile(Format("Timestamp: {} | ERROR showing current overlay: {}", A_TickCount, e.Message) "`n",
                "antimouse_core.log")
            }
        } else {
            LogToFile("TransitionToState ERROR: currentOverlay is not a valid object", "antimouse_core.log")
        }

        ; Set timer to track cursor position (for highlight updates)
        SetTimer(TrackCursor, 50)

        ; Reset hover tracking
        ResetLastTrackedKey()

        ; S1.5.1: Ensure any residual firstKey value is cleared
        StateMap['firstKey'] := ""
        LogToFile("S1.5.1 FIX | TransitionToState | Cleared firstKey in GRID_VISIBLE state",
            "antimouse_diagnostic.log")

        LogToFile("Task 6.4 | TransitionToState: Showed main grid and started tracking (Entering GRID_VISIBLE)",
            "antimouse_core.log")
    }
    if (newState == State_SUBGRID_STANDARD) {
        if (StateMap.Has('activeCellKey') && StateMap['activeCellKey'] != "") {
            if (IsObject(StateMap['currentOverlay'])) {
                try {
                    boundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
                    if (IsObject(boundaries)) {
                        ; Update and show subgrid
                        if (IsObject(subGrid)) {
                            try {
                                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                                subGrid.Show()
                                LogToFile(
                                    "Task 6.4 | TransitionToState: Updated and showed subgrid (Entering SUBGRID_STANDARD)",
                                    "antimouse_core.log")

                                ; S1.6.2 FIX - Ensure subgrid is visible after update
                                try {
                                    if (IsObject(subGrid) && subGrid.HasMethod("ForceShow")) {
                                        subGrid.ForceShow()
                                        LogToFile("S1.6.2 FIX | TransitionToState | Used subGrid.ForceShow()",
                                            "antimouse_fix.log")
                                    } else {
                                        subGrid.gui.Show("NA")
                                        LogToFile("S1.6.2 FIX | TransitionToState | Used subGrid.gui.Show()",
                                            "antimouse_fix.log")
                                    }
                                } catch as err {
                                    LogToFile(Format("S1.6.2 FIX | TransitionToState | Error showing subGrid: {}",
                                        err.Message), "antimouse_fix.log")

                                    ; Last-resort attempt to make subgrid visible
                                    try {
                                        WinShow("ahk_id " subGrid.gui.Hwnd)
                                        LogToFile("S1.6.2 FIX | TransitionToState | Used WinShow as last resort",
                                            "antimouse_fix.log")
                                    } catch {
                                        ; Nothing more we can try at this point
                                    }
                                }
                            } catch as e {
                                LogToFile(Format(
                                    "Timestamp: {} | ERROR updating/showing subGrid: {}", A_TickCount, e.Message) "`n",
                                "antimouse_core.log")
                            }
                        }

                        ; S1.6.1 FIX - Ensure highlight remains visible
                        if (IsObject(highlight)) {
                            try {
                                if (highlight.HasMethod("ForceShow")) {
                                    highlight.ForceShow()
                                    LogToFile("S1.6.1 FIX | TransitionToState | Used highlight.ForceShow()",
                                        "antimouse_fix.log")
                                } else {
                                    highlight.gui.Show("NA")
                                    LogToFile("S1.6.1 FIX | TransitionToState | Used highlight.gui.Show()",
                                        "antimouse_fix.log")
                                }
                            } catch as err {
                                LogToFile(Format("S1.6.1 FIX | TransitionToState | Error showing highlight: {}",
                                    err.Message), "antimouse_fix.log")

                                ; Last-resort attempt to make highlight visible
                                try {
                                    WinShow("ahk_id " highlight.gui.Hwnd)
                                    LogToFile("S1.6.1 FIX | TransitionToState | Used WinShow as last resort",
                                        "antimouse_fix.log")
                                } catch {
                                    ; Nothing more we can try at this point
                                }
                            }
                        }
                    } else {
                        LogToFile(Format(
                            "TransitionToState ERROR: Failed to get boundaries for cell '{}'",
                            StateMap['activeCellKey']), "antimouse_core.log")
                    }
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR getting cell boundaries: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }
            } else {
                LogToFile("TransitionToState ERROR: currentOverlay is not a valid object", "antimouse_core.log")
            }
        } else {
            LogToFile("TransitionToState WARNING: No activeCellKey set when entering SUBGRID_STANDARD",
                "antimouse_core.log")
        }

        ; Initialize or reset timers for the subgrid state
        SetTimer(TrackCursor, 50) ; Set cursor tracking timer

        ; Not in ultra-fast mode yet
        StateMap['inUltraFastMode'] := false
    }
    if (newState == State_SUBGRID_ULTRAFAST) {
        ; Similar to SUBGRID_STANDARD but with ultra-fast layout
        if (StateMap.Has('activeCellKey') && StateMap['activeCellKey'] != "") {
            if (IsObject(StateMap['currentOverlay'])) {
                try {
                    cellBoundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
                    if (IsObject(cellBoundaries)) {
                        ; Update the highlight position
                        if (IsObject(highlight)) {
                            try {
                                highlight.Update(cellBoundaries.x, cellBoundaries.y, cellBoundaries.w, cellBoundaries.h
                                )
                                highlight.Show()
                            } catch as e {
                                LogToFile(Format("Timestamp: {} | ERROR updating highlight: {}", A_TickCount, e.Message
                                ) "`n",
                                "antimouse_core.log")
                            }
                        }

                        ; Update the subgrid position with ultra-fast layout
                        if (IsObject(subGrid)) {
                            try {
                                ; Set to ultra-fast mode layout
                                subGrid.SetLayoutType("ultrafast")
                                ; Update and show the subgrid
                                subGrid.Update(cellBoundaries.x, cellBoundaries.y, cellBoundaries.w, cellBoundaries.h)
                                subGrid.Show()
                            } catch as e {
                                LogToFile(Format("Timestamp: {} | ERROR updating/showing subGrid in ultrafast mode: {}",
                                    A_TickCount, e.Message) "`n",
                                "antimouse_core.log")
                            }
                        }

                        LogToFile(
                            "Task 6.4 | TransitionToState: Updated and showed ultra-fast mode subgrid (Entering SUBGRID_ULTRAFAST)",
                            "antimouse_core.log")
                    } else {
                        LogToFile(Format(
                            "TransitionToState ERROR: Failed to get boundaries for cell '{}'",
                            StateMap['activeCellKey']), "antimouse_core.log")
                    }
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR getting cell boundaries: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }
            } else {
                LogToFile("TransitionToState ERROR: currentOverlay is not a valid object", "antimouse_core.log")
            }
        } else {
            LogToFile("TransitionToState WARNING: No activeCellKey set when entering SUBGRID_ULTRAFAST",
                "antimouse_core.log")
        }

        ; Set ultra-fast mode state
        StateMap['inUltraFastMode'] := true
    }
    if (newState == State_IDLE) {
        ; No entry actions needed for IDLE state
        ; All GUI elements should already be hidden by the exit actions of the previous state
        LogToFile("Task 6.4 | TransitionToState: Entered IDLE state. No action needed.", "antimouse_core.log")
    }

    ; Reset recursion detection
    transitionInProgress := false
    if (enableVerboseLogging) { ; Task Debug: Log at the end of the transition
        LogToFile(Format("DEBUG | TransitionToState COMPLETE | state='{}'",
            currentState), "antimouse_core.log")
    }
}

; Function to start a new selection cycle
StartNewSelection(key) {
    global currentState, highlight, StateMap, timers, enableVerboseLogging

    ; S1.5.1 DIAGNOSTIC: StartNewSelection entry
    LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection ENTRY | key='{}' | currentState='{}' | firstKey='{}'",
        key, currentState, StateMap.Get('firstKey', "")), "antimouse_diagnostic.log")

    ; <<< TASK 2.4 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.4 | StartNewSelection START | key={}, currentState={}", A_TickCount,
            key, currentState), "antimouse_core.log")
    }
    ; <<< TASK 2.4 CORE LOGGING END >>>

    ; Prevent infinite recursion by recording that we're transitioning
    static inStartNewSelection := false
    static recursionCount := 0

    ; S1.5.1 DIAGNOSTIC: Recursion check
    LogToFile(Format(
        "S1.5.1 DIAGNOSTIC | StartNewSelection - Recursion check | inStartNewSelection={}, recursionCount={}",
        inStartNewSelection, recursionCount), "antimouse_diagnostic.log")

    ; Protect against recursion
    if (inStartNewSelection) {
        ; We're already inside StartNewSelection - prevent stack overflow
        recursionCount++

        ; S1.5.1 DIAGNOSTIC: Recursion detected
        LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - RECURSION DETECTED! Count={}",
            recursionCount), "antimouse_diagnostic.log")

        if (recursionCount > 2) {
            ; Too much recursion, bail out to prevent crash
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Timestamp: {} | Task: 2.4 | S1.4 FIX | StartNewSelection - ABORTED - Too much recursion ({} levels). BAILING OUT!",
                    A_TickCount, recursionCount), "antimouse_core.log")
            }

            ; S1.5.1 DIAGNOSTIC: Recursion bailout
            LogToFile("S1.5.1 DIAGNOSTIC | StartNewSelection - TOO MUCH RECURSION! BAILING OUT",
                "antimouse_diagnostic.log")

            recursionCount := 0
            inStartNewSelection := false
            return
        }
    } else {
        ; First entry to StartNewSelection
        inStartNewSelection := true
        recursionCount := 0
    }

    ; S1.5.1 DIAGNOSTIC: Current state check
    LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - currentState before transition: '{}'",
        currentState), "antimouse_diagnostic.log")

    ; Ensure we always reset firstKey, regardless of what happens next
    oldFirstKey := StateMap.Get('firstKey', "")
    StateMap['firstKey'] := ""

    ; S1.5.1 DIAGNOSTIC: firstKey reset
    LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - Reset firstKey: '{}' -> ''",
        oldFirstKey), "antimouse_diagnostic.log")

    ; Reset the state first - go back to grid visibility
    ; S1.1: Add try/catch for TransitionToState
    try {
        LogToFile(Format(
            "S1.5.1 DIAGNOSTIC | StartNewSelection - Transitioning to GRID_VISIBLE | currentState before='{}'",
            currentState), "antimouse_diagnostic.log")

        TransitionToState(State_GRID_VISIBLE)

        ; S1.5.1 DIAGNOSTIC: State after transition
        LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - State after transition: '{}'",
            currentState), "antimouse_diagnostic.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR in TransitionToState: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")

        ; S1.5.1 DIAGNOSTIC: TransitionToState error
        LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - ERROR in TransitionToState: {}",
            e.Message), "antimouse_diagnostic.log")
    }

    ; Process the new key if provided
    if (key != "") {
        ; S1.5.1 DIAGNOSTIC: Processing new key
        LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - Processing new key: '{}'",
            key), "antimouse_diagnostic.log")

        ; S1.1: Add try/catch for HandleKey
        try {
            HandleKey(key, true) ; true to bypass state check

            ; S1.5.1 DIAGNOSTIC: HandleKey success
            LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - HandleKey('{}') success | firstKey='{}'",
                key, StateMap.Get('firstKey', "")), "antimouse_diagnostic.log")
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR in HandleKey: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")

            ; S1.5.1 DIAGNOSTIC: HandleKey error
            LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection - ERROR in HandleKey: {}",
                e.Message), "antimouse_diagnostic.log")
        }
    } else {
        ; S1.5.1 DIAGNOSTIC: No key provided
        LogToFile("S1.5.1 DIAGNOSTIC | StartNewSelection - No key provided, not calling HandleKey",
            "antimouse_diagnostic.log")
    }

    ; <<< TASK 2.4 CORE LOGGING END >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.4 | StartNewSelection END | key={}, newState={}", A_TickCount, key,
            currentState), "antimouse_core.log")
    }

    ; Reset recursion tracking
    inStartNewSelection := false
    recursionCount := 0

    ; S1.5.1 DIAGNOSTIC: StartNewSelection exit
    LogToFile(Format("S1.5.1 DIAGNOSTIC | StartNewSelection EXIT | key='{}' | currentState='{}' | firstKey='{}'",
        key, currentState, StateMap.Get('firstKey', "")), "antimouse_diagnostic.log")
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
