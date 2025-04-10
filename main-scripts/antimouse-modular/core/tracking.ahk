; ==============================================================================
; core/tracking.ahk - Cursor Tracking Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST
global StateMap, currentState, showcaseDebug

; Function to get the current cell that the cursor is in
; Returns cell key (e.g., "qj") or empty string if cursor is not in any cell
GetCurrentCell() {
    ; Get current mouse position
    MouseGetPos(&x, &y)

    ; Get the cell at current position
    cellKey := GetCellAtPosition(x, y)

    if (enableVerboseLogging) {
        FileAppend(Format("Timestamp: {} | Task: 2.17 | GetCurrentCell: Cursor at ({},{}) is in cell '{}'",
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
;             FileAppend(Format("Timestamp: {} | GetCellAtPosition: No valid overlay", A_TickCount) "`n",
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
    if (trackingInProgress) {
        return
    }
    trackingInProgress := true

    try {
        ; Access global state and configuration
        global currentState, highlight, subGrid, StateMap, showcaseDebug, enableUltraFast, rowKeyHoldThreshold,
            enableVerboseLogging

        ; Get current mouse position
        MouseGetPos(&x, &y)

        ; --- CORE LOGGING START ---
        ; currentTime := A_TickCount ; Defined earlier if needed
        ; activeCellKey := StateMap.Has('activeCellKey') ? StateMap['activeCellKey'] : ""
        ; activeRowKey := StateMap.Has('activeRowKey') ? StateMap['activeRowKey'] : ""
        ; inUltraFastMode := StateMap.Has('inUltraFastMode') ? StateMap['inUltraFastMode'] : false
        ; FileAppend(Format("Timestamp: {} | TrackCursor START | State={} | Mouse=({},{}) | ActiveCell={} | ActiveRowKey={} | UltraFastMode={}", currentTime, currentState, x, y, activeCellKey, activeRowKey, inUltraFastMode) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---

        ; Check if tracking is already in progress or state is invalid
        if (trackingInProgress || (currentState != State_GRID_VISIBLE && currentState != State_SUBGRID_STANDARD &&
            currentState != State_SUBGRID_ULTRAFAST)) {
            ; <<< CORE LOGGING START >>>
            if (trackingInProgress) FileAppend(Format("Timestamp: {} | TrackCursor: Exit (trackingInProgress=true)",
                A_TickCount) "`n", "antimouse_core.log")
                trackingInProgress := false
            return
            ; <<< CORE LOGGING END >>>
        }

        activeCellBoundaries := Map()
        cursorInsideCell := false

        ; Get boundaries if subgrid is active
        if (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) {
            if (StateMap.Has('activeCellKey') && StateMap['activeCellKey'] != "" && IsObject(subGrid)) {
                boundaries := subGrid.GetCellBoundaries(StateMap['activeCellKey'])
                if (IsObject(boundaries)) {
                    activeCellBoundaries := boundaries
                    cursorInsideCell := (x >= boundaries.x && x < boundaries.x + boundaries.w && y >= boundaries.y && y <
                        boundaries.y + boundaries.h)
                    ; --- CORE LOGGING START ---
                    FileAppend(Format(
                        "Timestamp: {} | TrackCursor: Subgrid Active. CellBounds=({},{},{},{}) | Inside={}",
                        A_TickCount, boundaries.x, boundaries.y, boundaries.w, boundaries.h, cursorInsideCell) "`n",
                    "antimouse_core.log")
                    ; --- CORE LOGGING END ---
                } else {
                    ; --- CORE LOGGING START ---
                    FileAppend(Format(
                        "Timestamp: {} | TrackCursor: WARNING - Failed to get boundaries for activeCellKey '{}'",
                        A_TickCount, StateMap['activeCellKey']) "`n", "antimouse_core.log")
                    ; --- CORE LOGGING END ---
                }
            }
        }

        ; --- Ultra-Fast Mode Check (Only when SUBGRID_ACTIVE) ---
        rowKeyIsHeld := false
        rowKeyHeldDuration := 0
        if ((currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) && enableUltraFast &&
        StateMap['activeRowKey'] != "") {
            if (GetKeyState(StateMap['activeRowKey'], "P")) { ; Check physical state
                rowKeyIsHeld := true
                rowKeyHeldDuration := A_TickCount - StateMap['rowKeyHeldTime']
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | TrackCursor: RowKey '{}' IS HELD. Duration={}ms | Threshold={}ms",
                    A_TickCount, StateMap['activeRowKey'], rowKeyHeldDuration, rowKeyHoldThreshold) "`n",
                "antimouse_core.log")
                ; --- CORE LOGGING END ---

                ; Transition TO Ultra-Fast Mode?
                if (!StateMap['inUltraFastMode'] && rowKeyHeldDuration >= rowKeyHoldThreshold) {
                    ; --- CORE LOGGING START ---
                    FileAppend(Format("Timestamp: {} | TrackCursor: === ENTERING Ultra-Fast Mode ===", A_TickCount) "`n",
                    "antimouse_core.log")
                    ; --- CORE LOGGING END ---
                    StateMap['inUltraFastMode'] := true
                    subGrid.SwitchToUltraFast() ; Update subgrid display
                }
            } else { ; Row key is UP
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | TrackCursor: RowKey '{}' IS UP.", A_TickCount, StateMap[
                    'activeRowKey']) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                ; Transition FROM Ultra-Fast Mode?
                if (StateMap['inUltraFastMode']) {
                    ; --- CORE LOGGING START ---
                    FileAppend(Format("Timestamp: {} | TrackCursor: === EXITING Ultra-Fast Mode ===", A_TickCount) "`n",
                    "antimouse_core.log")
                    ; --- CORE LOGGING END ---
                    StateMap['inUltraFastMode'] := false
                    subGrid.SwitchToStandard() ; Switch back subgrid display
                    ; No need to clear activeRowKey here, HandleKey should manage it
                }
            }
        }

        ; --- State Transition Logic based on Cursor Position ---
        if (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) {
            if (!cursorInsideCell) {
                ; --- CORE LOGGING START ---
                FileAppend(Format(
                    "Timestamp: {} | TrackCursor: Cursor left cell boundaries. Calling StartNewSelection().",
                    A_TickCount) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                ; Mouse moved outside the active subgrid cell's boundaries, reset to main grid selection
                StartNewSelection("") ; Pass empty key as it's not a key press trigger
            }
        } else if (currentState == State_GRID_VISIBLE) {
            ; <<< TASK 1.6 START: Implement Highlight Following >>>
            ; Ensure overlay and highlight objects are valid
            if (IsObject(StateMap['currentOverlay']) && IsObject(highlight)) {
                ; Get the cell key under the current cursor position
                currentCellKey := GetCellAtPosition(x, y)

                ; Check if the cell under the cursor has changed
                if (currentCellKey != lastTrackedCellKey_GridVisible) {
                    if (currentCellKey != "") {
                        ; Cursor is over a new valid cell
                        boundaries := StateMap['currentOverlay'].GetCellBoundaries(currentCellKey)
                        if (IsObject(boundaries)) {
                            ; Update and show the highlight for the new cell
                            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                            FileAppend(Format(
                                "Timestamp: {} | TrackCursor (GRID_VISIBLE): Highlight moved to cell '{}'", A_TickCount,
                                currentCellKey) "`n", "antimouse_core.log")
                        } else {
                            ; Failed to get boundaries, hide highlight as a fallback
                            highlight.Hide()
                            FileAppend(Format(
                                "Timestamp: {} | TrackCursor (GRID_VISIBLE): Failed to get boundaries for cell '{}', hiding highlight.",
                                A_TickCount, currentCellKey) "`n", "antimouse_core.log")
                        }
                    } else {
                        ; Cursor moved outside any valid cell, hide the highlight
                        highlight.Hide()
                        FileAppend(Format(
                            "Timestamp: {} | TrackCursor (GRID_VISIBLE): Cursor left all cells, hiding highlight.",
                            A_TickCount) "`n", "antimouse_core.log")
                    }
                    ; Update the last tracked cell key
                    lastTrackedCellKey_GridVisible := currentCellKey
                }
            } else {
                ; Safety check: Hide highlight if overlay/highlight becomes invalid
                if (IsObject(highlight)) {
                    highlight.Hide()
                }
                FileAppend(Format(
                    "Timestamp: {} | TrackCursor (GRID_VISIBLE): WARNING - Overlay or Highlight object invalid, hiding highlight.",
                    A_TickCount) "`n", "antimouse_core.log")
                lastTrackedCellKey_GridVisible := "" ; Reset tracking
            }
            ; <<< TASK 1.6 END >>>

            ; --- CORE LOGGING START ---
            currentOverlayInfo := IsObject(StateMap.Has('currentOverlay')) ? "Overlay OK" : "Overlay NOT Object"
            activeCellKeyInfo := StateMap.Has('activeCellKey') ? StateMap['activeCellKey'] : "<No Active Cell>"
            FileAppend(Format("Timestamp: {} | TrackCursor: In GRID_VISIBLE block. Overlay={}, ActiveCell={}",
                A_TickCount, currentOverlayInfo, activeCellKeyInfo) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            ; Add safety check for overlay before potentially using it later in the loop
            if (!StateMap.Has('currentOverlay') || !IsObject(StateMap['currentOverlay'])) {
                FileAppend(Format(
                    "Timestamp: {} | TrackCursor: WARNING - Overlay became invalid in GRID_VISIBLE state.", A_TickCount
                ) "`n", "antimouse_core.log")
                ; Consider calling Cleanup() here? Or just let the timer run?
            }
        }

        ; Show Highlight based on state
        if (highlight) {
            if (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) {
                ; In subgrid, only show highlight if a specific subcell is active
                if (StateMap['activeSubCellKey'] != "") {
                    highlight.Show()
                }
            } else if (currentState == State_GRID_VISIBLE) {
                ; In grid mode, show highlight if a cell is potentially being targeted
                if (StateMap['firstKey'] != "" || StateMap['activeCellKey'] != "") {
                    highlight.Show()
                }
            }
        }

    } catch as e {
        ; <<< TASK 5.2 START: Add verbose logging check >>>
        if (enableVerboseLogging) {
            FileAppend(Format("Timestamp: {} | TrackCursor: **** ERROR **** {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
        }
        ; <<< TASK 5.2 END >>>
        Cleanup()
    } finally {
        trackingInProgress := false
        ; <<< TASK 5.2 START: Add verbose logging check >>>
        if (enableVerboseLogging) {
            FileAppend(Format("Timestamp: {} | TrackCursor: END | trackingInProgress=false", A_TickCount) "`n",
            "antimouse_core.log")
        }
        ; <<< TASK 5.2 END >>>
    }
}
