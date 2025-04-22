; ==============================================================================
; core/grid_keys.ahk - Grid Key Handling Logic
; ==============================================================================

; state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug, highlight, subGrid, stateTransitionDelay, stateTransitionTime
global enableVerboseLogging ; Added
; global LogToFile ; Add explicit references to functions from other modules - Assuming LogToFile is auto-global or included earlier

; Functions are global by default in AHKv2
; global FindNearestCell, GetCellBoundaries

; S1.6.2 FIX - Delayed visibility check function for subgrid
SubGridVisibilityCheck(subGrid) {
    try {
        if (IsObject(subGrid) && !WinExist("ahk_id " subGrid.gui.Hwnd)) {
            LogToFile("S1.6.2 CRITICAL FIX | Delayed visibility check - subGrid still not visible. Forcing again!",
                "antimouse_fix.log")
            subGrid.ForceShow()
            WinRedraw("ahk_id " subGrid.gui.Hwnd)
        }
    } catch {
        ; Ignore errors in timer callback
    }
}

; S1.6.3 FIX - Add function to find the nearest cell matching a given row or column key
FindNearestCell(currentCellKey, targetKey, isColKey) {
    ; REMOVED internal global declaration as function refs are already global
    ; global highlight, StateMap

    ; Log the request
    LogToFile(Format("S1.6.3 FIX | FindNearestCell | Current cell: '{}', Target key: '{}', isColKey: {}",
        currentCellKey, targetKey, isColKey), "antimouse_fix.log")

    ; Ensure we have a valid current cell
    if (currentCellKey == "" || StrLen(currentCellKey) != 2) {
        LogToFile("S1.6.3 FIX | FindNearestCell | Invalid current cell key", "antimouse_fix.log")
        return ""
    }

    ; Extract current col and row keys from currentCellKey
    currentColKey := SubStr(currentCellKey, 1, 1)
    currentRowKey := SubStr(currentCellKey, 2, 1)

    ; Get array of available keys
    colKeys := StateMap['activeColKeys']
    rowKeys := StateMap['activeRowKeys']

    ; Log keys
    LogToFile(Format("S1.6.3 FIX | FindNearestCell | Current: col='{}', row='{}', Available cols={}, rows={}",
        currentColKey, currentRowKey, colKeys.Length, rowKeys.Length), "antimouse_fix.log")

    ; Find new cell key based on the target key type
    if (isColKey) {
        ; Target is a column key, keep the same row
        newCellKey := targetKey . currentRowKey
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Moving to cell with same row: '{}'",
            newCellKey), "antimouse_fix.log")
    } else {
        ; Target is a row key, keep the same column
        newCellKey := currentColKey . targetKey
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Moving to cell with same column: '{}'",
            newCellKey), "antimouse_fix.log")
    }

    ; Verify the new cell key exists
    cellExists := false
    for _, colKey in colKeys {
        for _, rowKey in rowKeys {
            if (newCellKey == colKey . rowKey) {
                cellExists := true
                break
            }
        }
        if (cellExists)
            break
    }

    if (cellExists) {
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Found valid target cell: '{}'",
            newCellKey), "antimouse_fix.log")
        return newCellKey
    } else {
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Target cell '{}' does not exist",
            newCellKey), "antimouse_fix.log")
        return ""
    }
}

; Handle a key press in GRID_VISIBLE state by performing direct navigation
; MODIFIED: Optimized to work in both GRID_VISIBLE and SUBGRID_STANDARD states
HandleKey(key) {
    global currentState, highlight, subGrid, StateMap, showcaseDebug
    ; REMOVED Function names from global declaration - they are already global
    global enableVerboseLogging

    ; S1.2: Add lastKeypressTime for potential future debounce (though less critical now)
    StateMap['lastKeypressTime'] := A_TickCount

    ; <<< CORE LOGGING START >>>
    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | Task: S1.7.1 | HandleKey (Optimized) START | key={}", A_TickCount, key),
        "antimouse_core.log")
    }
    ; <<< CORE LOGGING END >>>

    ; <<< DIAGNOSTIC LOGGING START >>>
    LogToFile(Format(
        "S1.7.1 DIAGNOSTIC | HandleKey (Optimized) | key='{}' | currentState='{}' | activeCellKey='{}'",
        key, currentState, StateMap.Get('activeCellKey', "")), "antimouse_diagnostic.log")
    ; <<< DIAGNOSTIC LOGGING END ---

    ; State check - allow both GRID_VISIBLE and SUBGRID_STANDARD
    if ((currentState != State_GRID_VISIBLE && currentState != State_SUBGRID_STANDARD) || !IsObject(StateMap[
        'currentOverlay'])) {
        if (enableVerboseLogging) {
            LogToFile(Format(
                "Timestamp: {} | Task: S1.7.1 | HandleKey (Optimized): Invalid state/overlay. currentState='{}'. Exiting.",
                A_TickCount, currentState), "antimouse_core.log")
        }
        return
    }

    ; Stop cursor tracking temporarily to avoid interference during movement
    SetTimer(TrackCursor, 0)

    ; Get current cell context
    currentCellKey := StateMap.Get('activeCellKey', "")
    if (currentCellKey == "") {
        LogToFile(Format(
            "Timestamp: {} | Task: S1.7.1 | HandleKey (Optimized): No activeCellKey context for key '{}'. Exiting.",
            A_TickCount, key), "antimouse_core.log")
        SetTimer(TrackCursor, 50) ; Restart tracking
        return ; Cannot navigate without context
    }

    ; Determine if the key is a column or row key
    isColKey := false
    isRowKey := false
    loop StateMap['activeColKeys'].Length {
        if (key == StateMap['activeColKeys'][A_Index]) {
            isColKey := true
            break
        }
    }
    if (!isColKey) {
        loop StateMap['activeRowKeys'].Length {
            if (key == StateMap['activeRowKeys'][A_Index]) {
                isRowKey := true
                break
            }
        }
    }

    ; If key is invalid (should have been caught by ProcessKeyPress, but double-check)
    if (!isColKey && !isRowKey) {
        LogToFile(Format("Timestamp: {} | Task: S1.7.1 | HandleKey (Optimized): Invalid key '{}'. Exiting.",
            A_TickCount, key), "antimouse_core.log")
        SetTimer(TrackCursor, 50) ; Restart tracking
        return
    }

    ; --- Always perform Nearest Cell Navigation --- START
    LogToFile(Format("S1.7.1 DIAG | HandleKey (Optimized) | Performing direct navigation | current='{}', key='{}'",
        currentCellKey, key), "antimouse_diagnostic.log")

    targetCellKey := FindNearestCell(currentCellKey, key, isColKey)

    if (targetCellKey != "") {
        ; Valid target cell found - navigate to it
        LogToFile(Format("S1.7.1 DIAG | HandleKey (Optimized) | Navigating from '{}' to '{}'",
            currentCellKey, targetCellKey), "antimouse_diagnostic.log")

        if (IsObject(StateMap['currentOverlay'])) {
            try {
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(targetCellKey)
                if (IsObject(boundaries)) {
                    ; Update active cell key FIRST
                    StateMap['activeCellKey'] := targetCellKey

                    ; Immediately calculate center for mouse movement - do this BEFORE UI updates for speed
                    centerX := boundaries.x + boundaries.w / 2
                    centerY := boundaries.y + boundaries.h / 2

                    ; Move cursor to center of target cell - do this EARLY
                    try {
                        MouseMove(centerX, centerY, 0)
                        LogToFile(Format("S1.7.1 DIAG | HandleKey (Optimized) | Moved cursor to ({}, {})", centerX,
                            centerY), "antimouse_diagnostic.log")
                    } catch as e {
                        LogToFile(Format("S1.7.1 ERROR | HandleKey (Optimized) | Error moving mouse: {}", e.Message),
                        "antimouse_diagnostic.log")
                    }

                    ; Update highlight
                    if (IsObject(highlight)) {
                        try {
                            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                            highlight.ForceShow() ; Ensure visible
                            LogToFile("S1.7.1 DIAG | HandleKey (Optimized) | Highlight updated & shown for " targetCellKey,
                                "antimouse_diagnostic.log")
                        } catch as e {
                            LogToFile(Format(
                                "S1.7.1 ERROR | HandleKey (Optimized) | Error updating/showing highlight: {}", e.Message
                            ), "antimouse_diagnostic.log")
                        }
                    }

                    ; --- Update SubGrid position to match --- START
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
                            LogToFile("S1.7.1 DIAG | HandleKey (Optimized) | SubGrid updated & shown for " targetCellKey,
                                "antimouse_diagnostic.log")
                        } catch as e {
                            LogToFile(Format(
                                "S1.7.1 ERROR | HandleKey (Optimized) | Error updating/showing subGrid: {}", e.Message
                            ), "antimouse_diagnostic.log")
                        }
                    }
                    ; --- Update SubGrid position to match --- END
                } else {
                    LogToFile("S1.7.1 ERROR | HandleKey (Optimized) | Failed to get boundaries for target cell " targetCellKey,
                        "antimouse_diagnostic.log")
                }
            } catch as e {
                LogToFile(Format("S1.7.1 ERROR | HandleKey (Optimized) | Error getting cell boundaries: {}", e.Message
                ), "antimouse_diagnostic.log")
            }
        }
    } else {
        LogToFile("S1.7.1 WARN | HandleKey (Optimized) | No valid target cell found from FindNearestCell.",
            "antimouse_diagnostic.log")
    }
    ; --- Always perform Nearest Cell Navigation --- END

    ; Restart cursor tracking
    SetTimer(TrackCursor, 50)

    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | Task: S1.7.1 | HandleKey (Optimized) END | key={} | Final State='{}'",
            A_TickCount, key, currentState), "antimouse_core.log")
    }
}

; Helper function to check if a key is a column key
ColKeyCheck(keyToCheck) {
    global StateMap
    for i, colKey in StateMap['activeColKeys'] {
        if (colKey = keyToCheck) {
            return true
        }
    }
    return false
}

; Helper function to check if a key is a row key
RowKeyCheck(keyToCheck) {
    global StateMap
    for i, rowKey in StateMap['activeRowKeys'] {
        if (rowKey = keyToCheck) {
            return true
        }
    }
    return false
}

; Validate index to ensure it's within valid bounds (grid-specific version)
GridValidateIndex(index, maxLength) {
    if (!index || index < 1) {
        return 1
    }
    if (index > maxLength) {
        return maxLength
    }
    return index
}
