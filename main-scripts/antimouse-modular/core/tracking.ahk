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

    ; --- ADDED: Check for reset request --- START
    if (StateMap.Get('requestResetTracking', false)) {
        LogToFile("Task: FIX | TrackCursor: Resetting lastTrackedCellKey_GridVisible due to flag.",
            "antimouse_core.log")
        lastTrackedCellKey_GridVisible := ""
        StateMap.Delete('requestResetTracking') ; Clear the flag using Delete for safety
    }
    ; --- ADDED: Check for reset request --- END

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
                                        highlight.ForceShow() ; Ensure visible
                                        LogToFile("S1.7.1 DIAG | TrackCursor | Highlight updated & shown for " currentCellKey,
                                            "antimouse_diagnostic.log")

                                        ; --- ADDED: Update SubGrid position to match --- START
                                        if (IsObject(subGrid)) {
                                            try {
                                                ; Make copy of boundaries to ensure we don't pass boundaries object directly
                                                ; This avoids potential property name mismatches
                                                x := boundaries.x
                                                y := boundaries.y
                                                w := boundaries.w
                                                h := boundaries.h

                                                ; Update with explicit property values rather than the object
                                                subGrid.Update(x, y, w, h)
                                                subGrid.ForceShow() ; Ensure visible
                                                LogToFile("S1.7.1 DIAG | TrackCursor | SubGrid updated & shown for " currentCellKey,
                                                    "antimouse_diagnostic.log")
                                            } catch as e {
                                                LogToFile(Format(
                                                    "S1.7.1 ERROR | TrackCursor | Error updating/showing subGrid: {}",
                                                    e.Message), "antimouse_diagnostic.log")
                                            }
                                        }
                                        ; --- ADDED: Update SubGrid position to match --- END

                                        if (enableVerboseLogging) {
                                            LogToFile(Format(
                                                "Task 1.6 | TrackCursor (GRID_VISIBLE): Highlight moved to cell '{}'",
                                                currentCellKey), "antimouse_core.log")
                                        }
                                    } catch as err {
                                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR updating highlight: {}",
                                            err.Message),
                                        "antimouse_core.log")
                                        LogToFile(Format("S1.7.1 ERROR | TrackCursor | Error updating highlight: {}",
                                            err.Message), "antimouse_diagnostic.log")
                                    }
                                } else {
                                    LogToFile("TrackCursor: WARNING - highlight object invalid", "antimouse_core.log")
                                    LogToFile("S1.7.1 ERROR | TrackCursor | Highlight object invalid",
                                        "antimouse_diagnostic.log")
                                }

                                ; --- REMOVED HOVER ACTIVATION LOGIC --- START
                                ; The block that checked firstKey and transitioned to SUBGRID_STANDARD is removed.
                                ; Subgrid is now updated directly after highlight update.
                                ; --- REMOVED HOVER ACTIVATION LOGIC --- END

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
                                highlight.Hide() ; Now moves highlight off-screen instead of just hiding
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
