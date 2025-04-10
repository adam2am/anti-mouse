; ==============================================================================
; core/tracking.ahk - Cursor Tracking Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST
global StateMap, currentState, showcaseDebug
global TransitionToState ; Add reference to TransitionToState function

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
    ; Static variable to prevent re-entry
    static trackingInProgress := false
    ; <<< TASK 1.6 START >>>
    ; Static variable to track the last cell the cursor was over in GRID_VISIBLE state
    static lastTrackedCellKey_GridVisible := ""
    ; <<< TASK 1.6 END >>>

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
            enableVerboseLogging, g_firstKeyPressed

        ; Get current mouse position
        MouseGetPos(&x, &y)
        LogToFile(Format("TrackCursor: Mouse at ({},{})", x, y), "antimouse_core.log")

        activeCellBoundaries := Map()
        cursorInsideCell := false

        ; Get boundaries if subgrid is active
        if (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) {
            LogToFile("TrackCursor: In SUBGRID state, checking if cursor still in cell", "antimouse_core.log")

            if (StateMap.Has('activeCellKey') && StateMap['activeCellKey'] != "") {
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
                        } else {
                            LogToFile(Format(
                                "TrackCursor: WARNING - Failed to get boundaries for activeCellKey '{}'",
                                StateMap['activeCellKey']), "antimouse_core.log")
                        }
                    } catch as err {
                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR: {}", err.Message), "antimouse_core.log")
                    }
                } else {
                    LogToFile("TrackCursor: WARNING - StateMap['currentOverlay'] invalid", "antimouse_core.log")
                }
            } else {
                LogToFile("TrackCursor: WARNING - No activeCellKey set in SUBGRID state", "antimouse_core.log")
            }

            if (!cursorInsideCell) {
                LogToFile("TrackCursor: Cursor LEFT cell boundaries! Calling StartNewSelection()", "antimouse_core.log"
                )
                ; Mouse moved outside the active subgrid cell's boundaries, reset to main grid selection
                try {
                    StartNewSelection("") ; Pass empty key as it's not a key press trigger
                } catch as err {
                    LogToFile(Format("Task: 5.10 | TrackCursor ERROR calling StartNewSelection: {}", err.Message),
                    "antimouse_core.log")
                }
            }
        } else if (currentState == State_GRID_VISIBLE) {
            ; Ensure overlay and highlight objects are valid
            if (IsObject(StateMap['currentOverlay']) && IsObject(highlight)) {
                ; Get the cell key under the current cursor position
                currentCellKey := GetCellAtPosition(x, y)

                ; Check if the cell under the cursor has changed
                if (currentCellKey != lastTrackedCellKey_GridVisible) {

                    if (currentCellKey != "") {
                        ; Cursor is over a new valid cell
                        try {
                            boundaries := StateMap['currentOverlay'].GetCellBoundaries(currentCellKey)
                            if (IsObject(boundaries)) {
                                ; --- Task 1.6: Update and show the highlight for the new cell ---
                                if (IsObject(highlight)) {
                                    try {
                                        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                                        if (enableVerboseLogging) {
                                            LogToFile(Format(
                                                "Task 1.6 | TrackCursor (GRID_VISIBLE): Highlight moved to cell '{}'",
                                                currentCellKey), "antimouse_core.log")
                                        }
                                    } catch as err {
                                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR updating highlight: {}",
                                            err.Message),
                                        "antimouse_core.log")
                                    }
                                }

                                ; --- Task 5.10: ROBUST FIX - Check if keys are being processed ---
                                ; Only activate subgrid if no keys are currently being processed
                                ; This avoids race conditions with HandleKey/HandleFirstKey/HandleSecondKey
                                if (g_firstKeyPressed == "") {
                                    ; No key being processed, safe to activate subgrid
                                    if (enableVerboseLogging) {
                                        LogToFile(Format(
                                            "Task 5.10 | TrackCursor (GRID_VISIBLE): Cursor moved to cell '{}'. No keys being processed, activating subgrid.",
                                            currentCellKey), "antimouse_core.log")
                                    }

                                    if (IsObject(StateMap)) {
                                        StateMap["activeCellKey"] := currentCellKey

                                        ; Update subgrid position BEFORE transitioning
                                        if (IsObject(subGrid)) {
                                            try {
                                                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                                            } catch as err {
                                                LogToFile(Format("Task: 5.10 | TrackCursor ERROR updating subGrid: {}",
                                                    err.Message), "antimouse_core.log")
                                            }
                                        }

                                        try {
                                            TransitionToState(State_SUBGRID_STANDARD)
                                        } catch as err {
                                            LogToFile(Format("Task: 5.10 | TrackCursor ERROR transitioning state: {}",
                                                err.Message), "antimouse_core.log")
                                        }

                                        ; Update the last key BEFORE returning
                                        lastTrackedCellKey_GridVisible := currentCellKey
                                        ; Exit TrackCursor early after transition to avoid potential conflicts
                                        trackingInProgress := false
                                        return
                                    }
                                } else {
                                    ; Key is being processed, just update highlight but don't change state
                                    if (enableVerboseLogging) {
                                        LogToFile(Format(
                                            "Task 5.10 | TrackCursor (GRID_VISIBLE): Cursor moved to cell '{}' but key '{}' is being processed. Skipping subgrid activation.",
                                            currentCellKey, g_firstKeyPressed), "antimouse_core.log")
                                    }
                                }

                            } else {
                                ; Failed to get boundaries, hide highlight as a fallback
                                if (IsObject(highlight)) {
                                    try {
                                        highlight.Hide()
                                    } catch as err {
                                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR hiding highlight: {}",
                                            err.Message), "antimouse_core.log")
                                    }
                                }
                                if (enableVerboseLogging) {
                                    LogToFile(Format(
                                        "Task 1.6 | TrackCursor (GRID_VISIBLE): Failed to get boundaries for cell '{}', hiding highlight.",
                                        currentCellKey), "antimouse_core.log")
                                }
                            }
                        } catch as err {
                            LogToFile(Format("Task: 5.10 | TrackCursor ERROR getting cell boundaries: {}",
                                err.Message), "antimouse_core.log")
                        }
                    } else {
                        ; Cursor moved outside any valid cell, hide the highlight
                        if (IsObject(highlight)) {
                            try {
                                highlight.Hide()
                            } catch as err {
                                LogToFile(Format("Task: 5.10 | TrackCursor ERROR hiding highlight: {}",
                                    err.Message), "antimouse_core.log")
                            }
                        }
                        if (enableVerboseLogging) {
                            LogToFile(
                                "Task 1.6 | TrackCursor (GRID_VISIBLE): Cursor left all cells, hiding highlight.",
                                "antimouse_core.log")
                        }
                    }
                    ; Update the last tracked cell key
                    lastTrackedCellKey_GridVisible := currentCellKey
                }
            } else {
                ; Safety check: Hide highlight if overlay/highlight becomes invalid
                if (IsObject(highlight)) {
                    try {
                        highlight.Hide()
                    } catch as err {
                        LogToFile(Format("Task: 5.10 | TrackCursor ERROR hiding highlight: {}",
                            err.Message), "antimouse_core.log")
                    }
                }
                if (enableVerboseLogging) {
                    LogToFile(
                        "TrackCursor (GRID_VISIBLE): WARNING - Overlay or Highlight object invalid, hiding highlight.",
                        "antimouse_core.log")
                }
                lastTrackedCellKey_GridVisible := "" ; Reset tracking
            }

            ; --- CORE LOGGING START ---
            currentOverlayInfo := IsObject(StateMap) && StateMap.Has('currentOverlay') && IsObject(StateMap[
                'currentOverlay']) ? "Overlay OK" : "Overlay NOT Object"
            activeCellKeyInfo := IsObject(StateMap) && StateMap.Has('activeCellKey') ? StateMap['activeCellKey'] :
                "<No Active Cell>"
            LogToFile(Format("TrackCursor: In GRID_VISIBLE block. Overlay={}, ActiveCell={}",
                currentOverlayInfo, activeCellKeyInfo), "antimouse_core.log")
            ; --- CORE LOGGING END ---
            ; Add safety check for overlay before potentially using it later in the loop
            if (!IsObject(StateMap) || !StateMap.Has('currentOverlay') || !IsObject(StateMap['currentOverlay'])) {
                LogToFile("TrackCursor: WARNING - Overlay became invalid in GRID_VISIBLE state.", "antimouse_core.log")
                ; Consider calling Cleanup() here? Or just let the timer run?
            }
        }

    } catch as e {
        ; <<< TASK 5.2 START: Add verbose logging check >>>
        if (enableVerboseLogging) {
            LogToFile(Format("TrackCursor: **** ERROR **** {}", e.Message), "antimouse_core.log")
        }
        ; <<< TASK 5.2 END >>>
        Cleanup()
    } finally {
        trackingInProgress := false
        ; <<< TASK 5.2 START: Add verbose logging check >>>
        if (enableVerboseLogging) {
            LogToFile("TrackCursor: END | trackingInProgress=false", "antimouse_core.log")
        }
        ; <<< TASK 5.2 END >>>
    }
}

; Function to reset the lastTrackedCellKey_GridVisible variable
; Call this when transitioning back to GRID_VISIBLE state
ResetLastTrackedKey() {
    ; Explicitly use the proper scoping ref to the static variable
    lastTrackedCellKey_GridVisible := ""
    LogToFile("Task: FIX | ResetLastTrackedKey: Reset lastTrackedCellKey_GridVisible to empty", "antimouse_core.log")
}
