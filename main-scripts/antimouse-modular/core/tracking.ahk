; ==============================================================================
; core/tracking.ahk - Cursor Tracking Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST
global StateMap, currentState, showcaseDebug
global LogToFile, GetCellAtPosition, enableVerboseLogging, StartNewSelection ; Add references to other functions

; Function-scoped variables (not file-level statics to avoid linter issues)
; These will be initialized the first time TrackCursor() is called
; This pattern avoids the linter error with file-level static declarations

; Function to get the current cell that the cursor is in
; Returns cell key (e.g., "qj") or empty string if cursor is not in any cell
GetCurrentCell() {
    ; Get current mouse position
    MouseGetPos(&x, &y)

    ; Get the cell at current position
    cellKey := GetCellAtPosition(x, y)

    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | Task: 2.17 | GetCurrentCell: Cursor at ({},{}) is in cell '{}'",
            A_TickCount, x, y, cellKey) "`n", "antimouse_core.log")
    }

    return cellKey
}

; Returns the cell key (e.g., "qj") at the given screen position
; Definition moved to core/positioning.ahk to resolve conflict
; GetCellAtPosition(x, y) {
;     global StateMap
;
;     ; Ensure we have a valid overlay
;     if (!StateMap.Has('currentOverlay') || !IsObject(StateMap['currentOverlay'])) {
;         if (enableVerboseLogging) {
;             LogToFile(Format("Timestamp: {} | GetCellAtPosition: No valid overlay", A_TickCount) "`n",
;                 "antimouse_core.log")
;         }
;         return ""
;     }
;
;     ; Get column and row keys
;     colKeys := StateMap['activeColKeys']
;     rowKeys := StateMap['activeRowKeys']
;
;     ; Loop through all cells to find which one contains the current position
;     for _, colKey in colKeys {
;         for _, rowKey in rowKeys {
;             cellKey := colKey . rowKey
;             boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
;
;             if (IsObject(boundaries)) {
;                 ; Check if position is within this cell's boundaries
;                 if (x >= boundaries.x && x < boundaries.x + boundaries.w &&
;                     y >= boundaries.y && y < boundaries.y + boundaries.h) {
;                     return cellKey
;                 }
;             }
;         }
;     }
;
;     ; Not in any cell
;     return ""
; }

; Monitors the mouse cursor position and updates the active cell/highlight/subgrid accordingly.
TrackCursor() {
    ; Static variables properly scoped inside the function
    static trackingInProgress := false
    static lastTrackedCellKey_GridVisible := ""

    ; Check if tracking is already in progress
    if (trackingInProgress) {
        ; Log that we're exiting due to trackingInProgress flag
        LogToFile("TrackCursor: Exit (trackingInProgress=true)", "antimouse_core.log")
        return
    }

    ; Check if the state is valid for tracking
    if (currentState != State_GRID_VISIBLE && currentState != State_SUBGRID_STANDARD && currentState !=
        State_SUBGRID_ULTRAFAST) {
        LogToFile(Format("TrackCursor: Exit (invalid state={})", currentState), "antimouse_core.log")
        return
    }

    ; Only set the flag if we're actually going to process tracking
    trackingInProgress := true
    LogToFile(Format("TrackCursor: STARTING. State={}, lastTrackedKey={}", currentState,
        lastTrackedCellKey_GridVisible), "antimouse_core.log")

    try {
        ; Access global state and configuration
        global currentState, highlight, subGrid, StateMap, showcaseDebug, enableUltraFast, rowKeyHoldThreshold,
            enableVerboseLogging

        ; Get current mouse position
        MouseGetPos(&x, &y)
        LogToFile(Format("TrackCursor: Mouse at ({},{})", x, y), "antimouse_core.log")

        ; --- 5.13.1: VISUAL DEBUGGING ---
        LogToFile(Format("5.13.1 DEBUG | TrackCursor - Mouse at ({},{}), state='{}'",
            x, y, currentState), "antimouse_fix.log")

        activeCellBoundaries := Map()
        cursorInsideCell := false

        ; Get boundaries if subgrid is active
        if (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) {
            LogToFile("TrackCursor: In SUBGRID state, checking if cursor still in cell", "antimouse_core.log")

            if (StateMap.Has('activeCellKey') && StateMap['activeCellKey'] != "") {
                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile(Format("5.13.1 DEBUG | TrackCursor - In subgrid state, activeCellKey='{}'",
                    StateMap['activeCellKey']), "antimouse_fix.log")

                ; <<< FIX: Get boundaries from the MAIN overlay, not the subgrid itself >>>
                if (IsObject(StateMap['currentOverlay'])) { ; Check if main overlay exists
                    try {
                        boundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
                        if (IsObject(boundaries)) {
                            activeCellBoundaries := boundaries
                            cursorInsideCell := (x >= boundaries.x && x < boundaries.x + boundaries.w && y >=
                                boundaries.y &&
                                y < boundaries.y + boundaries.h)

                            LogToFile(Format(
                                "TrackCursor: Subgrid Active. Cell='{}', Bounds=({},{},{},{}), Cursor Inside={}",
                                StateMap['activeCellKey'], boundaries.x, boundaries.y, boundaries.w,
                                boundaries.h, cursorInsideCell), "antimouse_core.log")

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            LogToFile(Format(
                                "5.13.1 DEBUG | TrackCursor - Got boundaries: x={}, y={}, w={}, h={}, cursorInside={}",
                                boundaries.x, boundaries.y, boundaries.w, boundaries.h, cursorInsideCell),
                            "antimouse_fix.log")
                        } else {
                            LogToFile(Format(
                                "TrackCursor: WARNING - Failed to get boundaries for activeCellKey '{}'",
                                StateMap['activeCellKey']), "antimouse_core.log")

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            LogToFile(Format("5.13.1 DEBUG | TrackCursor - FAILED to get boundaries for '{}'",
                                StateMap['activeCellKey']), "antimouse_fix.log")
                        }
                    } catch as err {
                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR: {}", err.Message), "antimouse_core.log")

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile(Format("5.13.1 DEBUG | TrackCursor - ERROR getting boundaries: {}",
                            err.Message), "antimouse_fix.log")
                    }
                } else {
                    LogToFile("TrackCursor: WARNING - StateMap['currentOverlay'] invalid", "antimouse_core.log")

                    ; --- 5.13.1: VISUAL DEBUGGING ---
                    LogToFile("5.13.1 DEBUG | TrackCursor - ERROR: currentOverlay is not a valid object",
                        "antimouse_fix.log")
                }
            } else {
                LogToFile("TrackCursor: WARNING - No activeCellKey set in SUBGRID state", "antimouse_core.log")

                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile("5.13.1 DEBUG | TrackCursor - WARNING: No activeCellKey set in SUBGRID state",
                    "antimouse_fix.log")
            }

            if (!cursorInsideCell) {
                LogToFile("TrackCursor: Cursor LEFT cell boundaries! Calling StartNewSelection()", "antimouse_core.log"
                )

                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile("5.13.1 DEBUG | TrackCursor - Cursor LEFT cell boundaries, calling StartNewSelection()",
                    "antimouse_fix.log")

                ; Mouse moved outside the active subgrid cell's boundaries, reset to main grid selection
                try {
                    StartNewSelection("") ; Pass empty key as it's not a key press trigger
                } catch as err {
                    LogToFile(Format("Task: 5.10 | TrackCursor ERROR calling StartNewSelection: {}", err.Message),
                    "antimouse_core.log")

                    ; --- 5.13.1: VISUAL DEBUGGING ---
                    LogToFile(Format("5.13.1 DEBUG | TrackCursor - ERROR calling StartNewSelection: {}",
                        err.Message), "antimouse_fix.log")
                }
            }
        } else if (currentState == State_GRID_VISIBLE) {
            ; --- 5.13.1: VISUAL DEBUGGING ---
            LogToFile(Format("5.13.1 DEBUG | TrackCursor - In GRID_VISIBLE state, checking highlight"),
            "antimouse_fix.log")

            ; Ensure overlay and highlight objects are valid
            if (IsObject(StateMap['currentOverlay']) && IsObject(highlight)) {
                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile("5.13.1 DEBUG | TrackCursor - Both currentOverlay and highlight are valid objects",
                    "antimouse_fix.log")

                ; Get the cell key under the current cursor position
                currentCellKey := GetCellAtPosition(x, y)

                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile(Format("5.13.1 DEBUG | TrackCursor - GetCellAtPosition returned: '{}'",
                    currentCellKey), "antimouse_fix.log")

                ; Check if the cell under the cursor has changed
                if (currentCellKey != lastTrackedCellKey_GridVisible) {
                    ; --- 5.13.1: VISUAL DEBUGGING ---
                    LogToFile(Format("5.13.1 DEBUG | TrackCursor - Cell changed from '{}' to '{}'",
                        lastTrackedCellKey_GridVisible, currentCellKey), "antimouse_fix.log")

                    if (currentCellKey != "") {
                        ; Cursor is over a new valid cell
                        try {
                            boundaries := StateMap['currentOverlay'].GetCellBoundaries(currentCellKey)

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            if (IsObject(boundaries)) {
                                LogToFile(Format(
                                    "5.13.1 DEBUG | TrackCursor - Got boundaries for '{}': x={}, y={}, w={}, h={}",
                                    currentCellKey, boundaries.x, boundaries.y, boundaries.w, boundaries.h),
                                "antimouse_fix.log")
                            } else {
                                LogToFile(Format("5.13.1 DEBUG | TrackCursor - FAILED to get boundaries for '{}'",
                                    currentCellKey), "antimouse_fix.log")
                            }

                            if (IsObject(boundaries)) {
                                ; --- Task 1.6: Update and show the highlight for the new cell ---
                                if (IsObject(highlight)) {
                                    try {
                                        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)

                                        ; --- 5.13.1: VISUAL DEBUGGING ---
                                        LogToFile("5.13.1 DEBUG | TrackCursor - Successfully called highlight.Update()",
                                            "antimouse_fix.log")

                                        ; S1.6.1 FIX - Ensure highlight is visible after update
                                        try {
                                            ; First try to use ForceShow if available
                                            if (IsObject(highlight) && highlight.HasMethod("ForceShow")) {
                                                highlight.ForceShow()
                                                LogToFile("S1.6.1 FIX | TrackCursor | Used highlight.ForceShow()",
                                                    "antimouse_fix.log")
                                            } else {
                                                ; Fallback to regular Show if ForceShow unavailable
                                                highlight.gui.Show("NA")
                                                LogToFile("S1.6.1 FIX | TrackCursor | Used highlight.gui.Show()",
                                                    "antimouse_fix.log")
                                            }
                                        } catch as visErr {
                                            LogToFile(Format(
                                                "S1.6.1 FIX | TrackCursor | ERROR forcing highlight visibility: {}",
                                                visErr.Message), "antimouse_fix.log")

                                            ; Last-resort attempt to make highlight visible
                                            try {
                                                WinShow("ahk_id " highlight.gui.Hwnd)
                                                LogToFile("S1.6.1 FIX | TrackCursor | Used WinShow as last resort",
                                                    "antimouse_fix.log")
                                            } catch {
                                                ; Nothing more we can try at this point
                                            }
                                        }

                                        if (enableVerboseLogging) {
                                            LogToFile(Format(
                                                "Task 1.6 | TrackCursor (GRID_VISIBLE): Highlight moved to cell '{}'",
                                                currentCellKey), "antimouse_core.log")
                                        }
                                    } catch as err {
                                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR updating highlight: {}",
                                            err.Message),
                                        "antimouse_core.log")

                                        ; --- 5.13.1: VISUAL DEBUGGING ---
                                        LogToFile(Format("5.13.1 DEBUG | TrackCursor - ERROR updating highlight: {}",
                                            err.Message), "antimouse_fix.log")
                                    }
                                } else {
                                    LogToFile("TrackCursor: WARNING - highlight object invalid", "antimouse_core.log")

                                    ; --- 5.13.1: VISUAL DEBUGGING ---
                                    LogToFile("5.13.1 DEBUG | TrackCursor - ERROR: highlight is not a valid object",
                                        "antimouse_fix.log")
                                }

                                ; --- RE-ENABLE HOVER ACTIVATION - START ---
                                ; S1.6.2 FIX - Re-enable hover activation with debounce protection

                                ; Check if key processing is safe (no keys being processed or enough time has passed)
                                if (StateMap['firstKey'] == "") {
                                    ; No key being processed, check debounce time
                                    if (A_TickCount - StateMap.Get('lastKeypressTime', 0) > 150) {
                                        ; Debounce period passed, safe to activate subgrid on hover
                                        LogToFile(Format(
                                            "S1.6.2 FIX | TrackCursor | Hover activation for cell '{}'",
                                            currentCellKey), "antimouse_fix.log")

                                        if (IsObject(StateMap)) {
                                            StateMap["activeCellKey"] := currentCellKey

                                            ; Update subgrid position BEFORE transitioning
                                            if (IsObject(subGrid)) {
                                                try {
                                                    subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries
                                                        .h)
                                                    LogToFile("S1.6.2 FIX | TrackCursor | Updated subGrid position",
                                                        "antimouse_fix.log")

                                                    ; Ensure subgrid is visible
                                                    try {
                                                        if (IsObject(subGrid) && subGrid.HasMethod("ForceShow")) {
                                                            subGrid.ForceShow()
                                                            LogToFile(
                                                                "S1.6.2 FIX | TrackCursor | Used subGrid.ForceShow()",
                                                                "antimouse_fix.log")
                                                        } else {
                                                            subGrid.gui.Show("NA")
                                                            LogToFile(
                                                                "S1.6.2 FIX | TrackCursor | Used subGrid.gui.Show()",
                                                                "antimouse_fix.log")
                                                        }
                                                    } catch as err {
                                                        LogToFile(Format(
                                                            "S1.6.2 FIX | TrackCursor | Error showing subGrid: {}",
                                                            err.Message), "antimouse_fix.log")
                                                    }
                                                } catch as err {
                                                    LogToFile(Format(
                                                        "S1.6.2 FIX | TrackCursor | Error updating subGrid: {}",
                                                        err.Message), "antimouse_fix.log")
                                                }
                                            }

                                            ; Transition to subgrid state
                                            try {
                                                TransitionToState(State_SUBGRID_STANDARD)
                                                LogToFile(
                                                    "S1.6.2 FIX | TrackCursor | Transitioned to SUBGRID_STANDARD state",
                                                    "antimouse_fix.log")
                                            } catch as err {
                                                LogToFile(Format(
                                                    "S1.6.2 FIX | TrackCursor | Error in state transition: {}",
                                                    err.Message), "antimouse_fix.log")
                                            }
                                        } else {
                                            LogToFile(
                                                "S1.6.2 FIX | TrackCursor | Skipping hover activation - within debounce period",
                                                "antimouse_fix.log")
                                        }
                                    } else {
                                        LogToFile(Format(
                                            "S1.6.2 FIX | TrackCursor | Skipping hover activation - firstKey '{}' is being processed",
                                            StateMap['firstKey']), "antimouse_fix.log")
                                    }
                                    ; --- RE-ENABLE HOVER ACTIVATION - END ---
                                }
                            } else {
                                LogToFile(Format(
                                    "TrackCursor: WARNING - Failed to get boundaries for cell '{}'",
                                    currentCellKey), "antimouse_core.log")
                            }
                        } catch as err {
                            LogToFile(Format("Task: 5.10 | TrackCursor ERROR: {}", err.Message), "antimouse_core.log")
                        }
                    } else {
                        ; Cursor is not over any cell, hide highlight
                        if (IsObject(highlight)) {
                            try {
                                highlight.Hide()
                                if (enableVerboseLogging) {
                                    LogToFile(
                                        "Task 1.6 | TrackCursor (GRID_VISIBLE): Cursor not over any cell, hiding highlight",
                                        "antimouse_core.log")
                                }
                            } catch as err {
                                LogToFile(Format("Task: 5.10 | TrackCursor ERROR hiding highlight: {}", err.Message),
                                "antimouse_core.log")
                            }
                        }
                    }

                    ; Update the last tracked cell key
                    lastTrackedCellKey_GridVisible := currentCellKey
                }
            } else {
                LogToFile("TrackCursor: WARNING - currentOverlay or highlight object invalid", "antimouse_core.log")
            }
        }
    } catch as err {
        LogToFile(Format("TrackCursor: UNHANDLED ERROR: {}", err.Message), "antimouse_core.log")
    } finally {
        ; Always reset the tracking flag when we're done
        trackingInProgress := false
    }
}

; Function to reset the lastTrackedCellKey_GridVisible variable
; Call this when transitioning back to GRID_VISIBLE state
ResetLastTrackedKey() {
    ; Explicitly define that we're using TrackCursor's static variable
    TrackCursor.lastTrackedCellKey_GridVisible := ""
    LogToFile("Task: FIX | ResetLastTrackedKey: Reset lastTrackedCellKey_GridVisible to empty", "antimouse_core.log")
}
