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
        ; Show main grid overlays when entering this state
        if (IsObject(StateMap["overlays"])) {
            for _, overlay in StateMap["overlays"] {
                if (IsObject(overlay)) {
                    try {
                        overlay.Show()
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | ERROR showing overlay: {}", A_TickCount, e.Message) "`n",
                        "antimouse_core.log")
                    }
                }
            }
            LogToFile("Task 6.4 | TransitionToState: Showing main grid (Entering GRID_VISIBLE)", "antimouse_core.log")
        }

        ; Hide any other GUIs as a precaution
        if (IsObject(subGrid)) {
            try {
                subGrid.Hide()
            } catch as e {
                LogToFile(Format("Timestamp: {} | ERROR hiding subGrid: {}", A_TickCount, e.Message) "`n",
                "antimouse_core.log")
            }
        }

        ; Reset the state variables for grid visible state
        StateMap['firstKey'] := ""
        ; Don't reset activeCellKey - it might be useful for other transitions
    }
    if (newState == State_SUBGRID_STANDARD) {
        ; Get boundaries of the active cell for updating the subgrid
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

                        ; Update the subgrid position
                        if (IsObject(subGrid)) {
                            try {
                                ; Ensure subgrid is in standard mode
                                subGrid.SetLayoutType("standard")
                                ; Update and show the subgrid
                                subGrid.Update(cellBoundaries.x, cellBoundaries.y, cellBoundaries.w, cellBoundaries.h)
                                subGrid.Show()
                            } catch as e {
                                LogToFile(Format("Timestamp: {} | ERROR updating/showing subGrid: {}", A_TickCount, e.Message
                                ) "`n",
                                "antimouse_core.log")
                            }
                        }

                        LogToFile(
                            "Task 6.4 | TransitionToState: Updated and showed highlight and subgrid (Entering SUBGRID_STANDARD)",
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
            LogToFile("TransitionToState WARNING: No activeCellKey set when entering SUBGRID_STANDARD",
                "antimouse_core.log")
        }

        ; Reset the ultra-fast mode state
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
    global enableVerboseLogging, StateMap

    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | StartNewSelection START | Initiating key: '{}'", A_TickCount, key) "`n",
        "antimouse_core.log")
    }

    ; Stop cursor tracking temporarily
    SetTimer(TrackCursor, 0)

    ; --- Task 5.8 / 5.10: Preserve context safely from the PREVIOUS selection (if any) ---
    ; Safely get the previous active cell key, providing "" as a default if it doesn't exist
    prevActiveCellKey := StateMap.Get("activeCellKey", "")
    prevActiveRowKey := StateMap.Get("activeRowKey", "") ; Also make this safe

    ; Preserve column key (first character of cell key)
    if (prevActiveCellKey != "" && StrLen(prevActiveCellKey) >= 1) {
        StateMap["preservedColKey"] := SubStr(prevActiveCellKey, 1, 1)
        if (enableVerboseLogging) {
            LogToFile(Format("StartNewSelection: Preserving column key '{}'",
                StateMap["preservedColKey"]), "antimouse_core.log")
        }
    } else {
        ; ROBUST FIX: Check if key exists before trying to delete it
        if (StateMap.Has("preservedColKey"))
            StateMap.Delete("preservedColKey") ; Clear if no previous cell
    }

    ; Preserve row key (second character of cell key OR specific activeRowKey)
    if (prevActiveCellKey != "" && StrLen(prevActiveCellKey) >= 2) {
        ; Preferentially use the specific activeRowKey if available, otherwise fallback to cell key part
        rowToPreserve := prevActiveRowKey ; Use the safely retrieved key
        if (rowToPreserve == "") {
            rowToPreserve := SubStr(prevActiveCellKey, 2, 1) ; Fallback to part of the cell key
        }
        StateMap["preservedRowKey"] := rowToPreserve
        LogToFile(Format("Task 5.8 | StartNewSelection: Preserving row key '{}'", rowToPreserve),
        "antimouse_core.log")
    } else {
        ; ROBUST FIX: Check if key exists before trying to delete it
        if (StateMap.Has("preservedRowKey"))
            StateMap.Delete("preservedRowKey") ; Clear if no previous cell or incomplete cell key
    }
    ; --- END Task 5.8 / 5.10 ---

    ; Transition back to grid visible state (Handles hiding subgrid/highlight)
    TransitionToState(State_GRID_VISIBLE)

    ; Clear selection-specific state variables safely and explicitly
    ; ROBUST FIX: Check if keys exist before trying to delete them
    if (StateMap.Has("activeCellKey"))
        StateMap.Delete("activeCellKey")
    if (StateMap.Has("activeSubCellKey"))
        StateMap.Delete("activeSubCellKey")
    if (StateMap.Has("activeRowKey"))
        StateMap.Delete("activeRowKey")
    if (StateMap.Has("inUltraFastMode"))
        StateMap.Delete("inUltraFastMode")
    StateMap['firstKey'] := "" ; Replaces g_firstKeyPressed := ""

    ; If a key initiated this new selection, process it now that the state is correct
    if (key != "") {
        if (enableVerboseLogging) {
            LogToFile(Format("Timestamp: {} | StartNewSelection: Processing initiating key '{}' with HandleKey",
                A_TickCount, key) "`n", "antimouse_core.log")
        }
        HandleKey(key, true) ; Pass true to bypass HandleKey's own state check
    } else {
        ; If no key initiated (e.g., cursor moved out), ensure tracking is re-enabled
        if (enableVerboseLogging) {
            LogToFile(Format("Timestamp: {} | StartNewSelection: No initiating key, enabling TrackCursor",
                A_TickCount) "`n", "antimouse_core.log")
        }
        SetTimer(TrackCursor, 50)
    }

    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | StartNewSelection END | Initiating key: '{}'", A_TickCount, key) "`n",
        "antimouse_core.log")
    }
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
