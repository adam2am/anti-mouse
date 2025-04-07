; ==============================================================================
; core_logic.ahk - Core Grid Interaction, Navigation, and State Logic
; ==============================================================================

; --- Monitor Switching ---

; Switches focus and cursor to a specific monitor number.
SwitchMonitor(monitorNum) {
    ; Access global state and config
    global currentState, highlight, subGrid, monitorMapping, storePerMonitor, StateMap, showcaseDebug

    ; Apply monitor mapping from config
    if (!monitorMapping.Has(monitorNum)) {
        if (showcaseDebug) ToolTip("Invalid physical monitor number: " monitorNum)
            return
    }
    mappedMonitor := monitorMapping[monitorNum]

    ; Check if mapped monitor index is valid and grid is active
    if (mappedMonitor > StateMap['overlays'].Length || currentState == "IDLE") {
        if (showcaseDebug && currentState != "IDLE") ToolTip("Invalid mapped monitor index: " mappedMonitor)
            return
    }

    ; Temporarily disable cursor tracking during the switch
    SetTimer(TrackCursor, 0)

    ; Get the target overlay object
    newOverlay := StateMap['overlays'][mappedMonitor]
    if (!IsObject(newOverlay)) {
        if (showcaseDebug) ToolTip("Target overlay object not found for monitor " mappedMonitor)
            SetTimer(TrackCursor, 50) ; Re-enable tracking if switch fails
        return
    }

    ; Remember current position state before switching
    rememberedColIndex := StateMap['currentColIndex']
    rememberedRowIndex := StateMap['currentRowIndex']
    wasInSubgrid := currentState == "SUBGRID_ACTIVE"
    rememberedCellKey := StateMap['activeCellKey'] ; Remember the full cell key

    ; Hide UI elements during transition to prevent visual artifacts
    if (IsObject(highlight)) highlight.Hide()
        if (IsObject(subGrid)) subGrid.Hide()
            Sleep(20) ; Small delay for UI cleanup

    ; Update the current overlay in the state map
    StateMap['currentOverlay'] := newOverlay

    ; Attempt to restore position on the new monitor
    if (rememberedCellKey != "") { ; Use the remembered cell key
        ; Get boundaries for the *same cell key* on the *new* overlay
        boundaries := newOverlay.GetCellBoundaries(rememberedCellKey)

        if (IsObject(boundaries)) {
            ; Move cursor to the center of the corresponding cell on the new monitor
            centerX := boundaries.x + (boundaries.w // 2)
            centerY := boundaries.y + (boundaries.h // 2)
            MouseMove(centerX, centerY, 0)

            ; Update state BEFORE updating UI
            StateMap['activeCellKey'] := rememberedCellKey ; Keep the same cell key active
            ; Update indices based on the new overlay's keys (important if layouts differ)
            StateMap['currentColIndex'] := 0
            for i, k in StateMap['activeColKeys'] {
                if (SubStr(rememberedCellKey, 1, 1) = k) {
                    StateMap['currentColIndex'] := i
                    break
                }
            }
            StateMap['currentRowIndex'] := 0
            for i, k in StateMap['activeRowKeys'] {
                if (SubStr(rememberedCellKey, 2) = k) {
                    StateMap['currentRowIndex'] := i
                    StateMap['lastSelectedRowIndex'] := i
                    break
                }
            }

            ; Update highlight for the new cell position
            if (IsObject(highlight)) {
                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            }

            ; If we were in subgrid mode, update and potentially restore subgrid position
            if (wasInSubgrid && IsObject(subGrid)) {
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                currentState := "SUBGRID_ACTIVE" ; Ensure state is correct

                ; Check for remembered subcell (monitor-specific first, then general)
                rememberedSubCell := ""
                monitorCellKey := mappedMonitor . "_" . rememberedCellKey
                if (storePerMonitor && cellMemory.Has(monitorCellKey)) {
                    rememberedSubCell := cellMemory[monitorCellKey]
                } else if (cellMemory.Has(rememberedCellKey)) {
                    rememberedSubCell := cellMemory[rememberedCellKey]
                }

                ; If a subcell was remembered, move to it
                if (rememberedSubCell != "") {
                    HandleSubGridKey(rememberedSubCell) ; This function moves the mouse
                }
            }
        } else {
            ; If the exact cell doesn't exist (e.g., different layout size), move to center
            centerX := newOverlay.Left + (newOverlay.width // 2)
            centerY := newOverlay.Top + (newOverlay.height // 2)
            MouseMove(centerX, centerY, 0)
            StateMap['activeCellKey'] := "" ; Clear active cell if it couldn't be found
        }
    } else {
        ; No cell was active, just move to the center of the new monitor
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        MouseMove(centerX, centerY, 0)
    }

    if (showcaseDebug) {
        ToolTip("Switched to Monitor " mappedMonitor " (physical: " monitorNum ")")
        Sleep(1000)
        ToolTip()
    }

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)
}

; Cycles focus and cursor to the next available monitor.
CycleToNextMonitor() {
    ; Access global state
    global currentState, StateMap

    ; Don't cycle if idle or only one monitor overlay exists
    if (currentState == "IDLE" || StateMap['overlays'].Length <= 1) {
        return
    }

    ; Find the current monitor's physical index (needed for SwitchMonitor)
    currentOverlay := StateMap['currentOverlay']
    currentPhysicalIndex := 0
    for physIdx, mapIdx in monitorMapping {
        if (mapIdx == currentOverlay.monitorIndex) {
            currentPhysicalIndex := physIdx
            break
        }
    }

    if (currentPhysicalIndex == 0) {
        return ; Should not happen if state is consistent
    }
    ; Find the next physical monitor index in the mapping array
    nextPhysicalIndex := 0
    currentIndexInMapping := 0
    loop monitorMapping.Length {
        if (A_Index == currentPhysicalIndex) {
            currentIndexInMapping := A_Index
            break
        }
    }

    nextIndexInMapping := Mod(currentIndexInMapping, monitorMapping.Length) + 1

    ; Find the physical index corresponding to the next logical index
    loop monitorMapping.Length {
        if (A_Index == nextIndexInMapping) {
            nextPhysicalIndex := A_Index
            break
        }
    }

    ; Call SwitchMonitor with the next physical index
    SwitchMonitor(nextPhysicalIndex)
}

; --- Cell Position Finding ---

; Determines the cell key (e.g., "qj") at given absolute screen coordinates (x, y).
GetCellAtPosition(x, y) {
    global StateMap ; Access global state

    ; Ensure we have a valid current overlay
    if (!IsObject(StateMap['currentOverlay'])) {
        return ""
    }
    ; Check if the point is within the current overlay's boundaries
    if (!StateMap['currentOverlay'].ContainsPoint(x, y)) {
        return ""
    }

    ; Iterate through cells of the current overlay to find which one contains the point
    ; Use the cells map directly from the OverlayGUI object
    for cellKey, cellData in StateMap['currentOverlay'].cells {
        if (x >= cellData.absX && x < cellData.absX + cellData.w && y >= cellData.absY && y < cellData.absY + cellData.h
        ) {
            return cellKey ; Return the key (e.g., "qj")
        }
    }
    return ""
    ; Return empty string if no cell found at the position
}

; --- Key Handling Logic ---

; Handles key presses when the grid is visible (first or second key press).
HandleKey(key) {
    ; Access global state and config
    global currentState, highlight, subGrid, stateTransitionTime, stateTransitionDelay, StateMap,
        showcaseDebug

    ; IMPROVEMENT: Explicitly hide UI elements at the beginning to prevent artifacts
    if (IsObject(highlight)) highlight.Hide()
        if (IsObject(subGrid)) subGrid.Hide()
        ; IMPROVEMENT: Temporarily disable TrackCursor to prevent interference during key processing
            SetTimer(TrackCursor, 0)

    ; Ensure we are in the correct state and have a valid overlay
    if (currentState != "GRID_VISIBLE" || !IsObject(StateMap['currentOverlay'])) {
        SetTimer(TrackCursor, 50) ; Re-enable TrackCursor before returning
        return
    }

    ; Check if the pressed key is a valid column or row key for the current layout
    isColKey := false
    colIndex := 0
    for i, colKeyCheck in StateMap['activeColKeys'] {
        if (colKeyCheck = key) {
            isColKey := true
            colIndex := i
            break
        }
    }

    isRowKey := false
    rowIndex := 0
    for i, rowKeyCheck in StateMap['activeRowKeys'] {
        if (rowKeyCheck = key) {
            isRowKey := true
            rowIndex := i
            break
        }
    }

    ; If the key is not part of the grid layout, ignore it
    if (!isColKey && !isRowKey) {
        if (showcaseDebug) ToolTip("Invalid key for grid: " key)
            SetTimer(TrackCursor, 50) ; Re-enable TrackCursor
        return
    }

    cellKey := ""
    targetCellX := 0
    targetCellY := 0
    targetCellW := 0
    targetCellH := 0
    tooltipText := ""
    proceedToSubgrid := false

    if (StateMap['firstKey'] = "") {
        ; --- First Key Press ---
        StateMap['firstKey'] := key ; Store the first key

        if (isColKey) {
            ; First key is COLUMN
            StateMap['currentColIndex'] := colIndex
            ; Predict row based on last selection or default to 1
            targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1
            targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length) ; Use util function
            cellKey := key . StateMap['activeRowKeys'][targetRowIndex] ; Col + Row
            tooltipText := "Column: " key ". Select row."
        } else { ; isRowKey
            ; First key is ROW
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex ; Remember this row
            ; Predict column based on current or default to center
            targetColIndex := StateMap['currentColIndex'] ? StateMap[
                'currentColIndex'] : Ceil(StateMap['activeColKeys'].Length / 2)
            targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length) ; Use util function
            cellKey := StateMap['activeColKeys'][targetColIndex] . key ; Col + Row
            tooltipText := "Row: " key ". Select column."
        }

        boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
        if (IsObject(boundaries)) {
            targetCellX := boundaries.x
            targetCellY := boundaries.y
            targetCellW := boundaries.w
            targetCellH := boundaries.h
        }

        ; Update highlight, move cursor, and wait for the second key
        if (targetCellW > 0) {
            highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
            MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
            Sleep(10) ; Small delay
            if (showcaseDebug)
                ToolTip(tooltipText)
        }
        SetTimer(TrackCursor, 50) ; Re-enable tracking
        return ; Exit and wait for the second key

    } else {
        ; --- Second Key Press ---
        firstKeyWasCol := false
        for colKeyCheck in StateMap['activeColKeys'] {
            if (colKeyCheck = StateMap['firstKey']) {
                firstKeyWasCol := true
                break
            }
        }
        firstKeyWasRow := !firstKeyWasCol

        if (firstKeyWasCol && isRowKey) {
            ; Expected: Col -> Row
            cellKey := StateMap['firstKey'] . key ; Col + Row
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex ; Remember row
            proceedToSubgrid := true
            StateMap['firstKey'] := "" ; Reset first key state
        }
        else if (firstKeyWasRow && isColKey) {
            ; Expected: Row -> Col
            cellKey := key . StateMap['firstKey'] ; Col + Row (Consistent key format)
            StateMap['currentColIndex'] := colIndex
            proceedToSubgrid := true
            StateMap['firstKey'] := "" ; Reset first key state
        }
        else if (firstKeyWasCol && isColKey) {
            ; Unexpected: Col -> Col (Change column selection)
            StateMap['firstKey'] := key ; Update stored first key (the new column)
            StateMap['currentColIndex'] := colIndex
            targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap[
                'lastSelectedRowIndex'] : 1
            targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length)
            cellKey := key . StateMap['activeRowKeys'][targetRowIndex] ; New Col + Predicted Row
            tooltipText := "Column changed to: " key ". Select row."
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }
        }
        else if (firstKeyWasRow && isRowKey) {
            ; Unexpected: Row -> Row (Change row selection)
            StateMap['firstKey'] := key ; Update stored first key (the new row)
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex ; Remember new row
            targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] :
                Ceil(StateMap['activeColKeys'].Length / 2)
            targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length
            )
            cellKey := StateMap['activeColKeys'][targetColIndex] . key ; Predicted Col + New Row
            tooltipText := "Row changed to: " key ". Select column."
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }
        }
        else {
            ; Invalid sequence (should not happen if key validation is correct)
            StateMap['firstKey'] := "" ; Reset state
            SetTimer(TrackCursor, 50) ; Re-enable tracking
            return
        }

        ; If we are not proceeding to subgrid, it means we changed the first key (Col->Col or Row->Row)
        if (!proceedToSubgrid) {
            if (targetCellW > 0) {
                highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH //
                    2), 0)
                Sleep(10)
                if (showcaseDebug) {
                    ToolTip(tooltipText)
                }
            }
            SetTimer(TrackCursor, 50) ; Re-enable tracking
            return ; Wait for the *new* second key press
        }
    }

    ; --- Proceed to Subgrid State ---
    if (!proceedToSubgrid || cellKey = "") {
        StateMap['firstKey'] := "" ; Ensure reset if something went wrong
        SetTimer(TrackCursor, 50) ; Re-enable tracking
        return
    }

    boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
    if (IsObject(boundaries)) {
        StateMap['activeCellKey'] := cellKey ; Store the final selected cell
        stateTransitionTime := A_TickCount ; Record transition time
        currentState := "SUBGRID_ACTIVE" ; Change FSM state

        ; Update UI: Move cursor, show highlight, show subgrid
        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2
        ), 0)
        Sleep(40) ; Increased delay before showing subgrid
        subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)

        ; Check cell memory for a remembered subcell position for this cell
        rememberedSubCell := ""
        cellFound := false
        keyToCheck := ""

        ; Check monitor-specific key first if enabled
        if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
            monitorCellKey := StateMap['currentOverlay'].monitorIndex . "_" . cellKey
            if (cellMemory.Has(monitorCellKey)) {
                rememberedSubCell := cellMemory[monitorCellKey]
                cellFound := true
                keyToCheck := monitorCellKey
            }
        }

        ; Fall back to general cell key if no monitor-specific key found or not enabled
        if (!cellFound && cellMemory.Has(cellKey)) {
            rememberedSubCell := cellMemory[cellKey]
            cellFound := true
            keyToCheck := cellKey
        }

        ; If a position was remembered, move the mouse to it
        if (cellFound && rememberedSubCell != "") {
            if (showcaseDebug) ToolTip("Found memory: " keyToCheck " -> " rememberedSubCell
            )
                HandleSubGridKey(rememberedSubCell) ; Call subgrid handler to move mouse
        } else if (showcaseDebug) {
            ToolTip("No saved subcell for " cellKey)
        }

        if (showcaseDebug)
            ToolTip("Cell '" cellKey "' targeted. Use subgrid keys (" SubStr(
                subGridKeys.ToString(), 2, -1) ").")
    } else {
        if (showcaseDebug) {
            ToolTip("Could not get boundaries for cell: " cellKey)
        }
        StateMap['firstKey'] := "" ; Reset if boundaries failed
    }

    SetTimer(TrackCursor, 50) ; Re-enable tracking
}

; Handles key presses when the subgrid is active.
HandleSubGridKey(subKey) {
    ; Access global state and config
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay,
        storePerMonitor, StateMap, showcaseDebug

    ; Ensure we are in the correct state and have a valid subgrid object
    if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid)) {
        return
    }

    ; Prevent processing keys too quickly after entering subgrid state
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition < stateTransitionDelay) {
        Sleep(stateTransitionDelay - timeSinceTransition)
    }

    ; Check if the pressed key is a valid subgrid key
    isValidSubKey := false
    for i, k in subGridKeys {
        if (k = subKey) {
            isValidSubKey := true
            break
        }
    }

    if (!isValidSubKey) {
        if (showcaseDebug) ToolTip("Invalid subgrid key: " subKey)
            return
    }

    ; Get the target coordinates for the subkey within the subgrid
    targetCoords := subGrid.GetTargetCoordinates(subKey)
    if (IsObject(targetCoords)) {
        MouseMove(targetCoords.x, targetCoords.y, 0) ; Move the mouse
        StateMap['activeSubCellKey'] := subKey ; Update state

        ; Remember this subcell selection for the current active cell
        activeCell := StateMap['activeCellKey']
        if (activeCell != "") {
            keyToSave := ""
            ; Determine the key for saving based on storePerMonitor setting
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                keyToSave := StateMap['currentOverlay'].monitorIndex . "_" .
                    activeCell
            } else {
                keyToSave := activeCell
            }

            ; Update the cell memory map and save it
            if (keyToSave != "" && cellMemory.Has(keyToSave) ? cellMemory[
                keyToSave] != subKey : true) { ; Only save if changed
                cellMemory[keyToSave] := subKey
                if (showcaseDebug) ToolTip("Memory updated: " keyToSave " -> " subKey
                )
                    SaveCellMemory() ; Save the entire map to file
            }
        }

        if (showcaseDebug) {
            monitorInfo := (storePerMonitor && IsObject(StateMap[
                'currentOverlay'])) ? " on monitor " StateMap['currentOverlay']
                .monitorIndex : ""
            ToolTip("Moved to sub-cell " subKey " in " activeCell monitorInfo)
        }
    } else {
        if (showcaseDebug) {
            ToolTip(
                "Could not get target coordinates for sub-key: " subKey)
        }
    }
}

; Resets the state from SUBGRID_ACTIVE back to GRID_VISIBLE and processes the key as the start of a new selection.
StartNewSelection(key) {
    ; Access global state
    global currentState, subGrid, highlight, StateMap

    ; IMPROVEMENT: Temporarily disable TrackCursor
    SetTimer(TrackCursor, 0)

    ; Only proceed if we are actually in the subgrid state
    if (currentState != "SUBGRID_ACTIVE") {
        SetTimer(TrackCursor, 50) ; Re-enable TrackCursor before returning
        return
    }

    ; Hide the subgrid and highlight first
    if (IsObject(subGrid)) subGrid.Hide()
        if (IsObject(highlight)) highlight.Hide() ; Hide highlight too
        ; Reset relevant state variables before handling the new key
            StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    StateMap['firstKey'] := ""
    currentState := "GRID_VISIBLE" ; Transition back to grid selection state

    Sleep(10) ; Force a small delay to ensure state transitions properly

    ; Call HandleKey to process the pressed key as the *first* key of a new selection
    HandleKey(key)

    ; Note: TrackCursor is re-enabled within HandleKey
}

; --- Cursor Tracking ---

; Monitors the mouse cursor position and updates the active cell/highlight/subgrid accordingly.
TrackCursor() {
    ; Access global state and config
    global currentState, highlight, subGrid, StateMap, showcaseDebug

    ; Ignore tracking if idle or dragging (dragging state not fully implemented here)
    if (currentState == "IDLE" || currentState == "DRAGGING") {
        return
    }

    try {
        MouseGetPos(&x, &y) ; Get current absolute mouse coordinates

        ; --- Monitor Change Detection ---
        previousOverlay := StateMap['currentOverlay']
        changedMonitor := false
        activeMonitorFound := false

        for overlay in StateMap['overlays'] {
            if (!IsObject(overlay)) {
                continue ; Skip invalid overlay objects
            }
            try {
                if (overlay.ContainsPoint(x, y)) {
                    activeMonitorFound := true
                    if (StateMap['currentOverlay'] !== overlay) {
                        ; Cursor moved to a different monitor's overlay
                        StateMap['currentOverlay'] := overlay
                        changedMonitor := true
                        if (showcaseDebug) ToolTip("Cursor moved to Monitor " overlay.monitorIndex)
                        ; When changing monitors via cursor, reset the active cell
                        ; This differs from hotkey switching where we try to preserve the cell
                            StateMap['activeCellKey'] := ""
                        StateMap['activeSubCellKey'] := ""
                        StateMap['firstKey'] := "" ; Reset first key too
                        ; Hide UI elements until a new cell is identified on this monitor
                        if (IsObject(highlight)) {
                            highlight.Hide()
                        }
                        if (IsObject(subGrid)) {
                            subGrid.Hide()
                        }
                    }
                    break ; Found the active monitor, no need to check others
                }
            } catch as e_inner {
                ; Skip this overlay if an error occurs (e.g., ContainsPoint fails)
                if (showcaseDebug) {
                    ToolTip("Error checking overlay " overlay.monitorIndex ": " e_inner.Message)
                }
                ; Cannot use 'continue' as it's a keyword, just let the loop proceed (AHK v2 doesn't have continue in the same way as v1 within loops like this, the loop naturally proceeds)
            }
        }

        ; If cursor is outside all known monitor overlays, do nothing further
        if (!activeMonitorFound) {
            ; Optionally hide UI if cursor leaves all grids
            ; if (IsObject(highlight)) highlight.Hide()
            ; if (IsObject(subGrid)) subGrid.Hide()
            ; StateMap['activeCellKey'] := "" ; Consider clearing active cell
            return
        }

        ; --- Cell Change Detection (within the current monitor) ---
        ; Only proceed if we have a valid current overlay
        if (!IsObject(StateMap['currentOverlay'])) {
            return
        }

        try {
            currentCellKey := GetCellAtPosition(x, y) ; Find cell at current cursor pos

            ; Update UI and state only if the cell under the cursor has changed
            if (currentCellKey != "" && currentCellKey != StateMap[
                'activeCellKey']) {
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(
                    currentCellKey)

                if (IsObject(boundaries)) {
                    try {
                        ; Update highlight and subgrid position (subgrid remains hidden unless state is SUBGRID_ACTIVE)
                        if (IsObject(highlight)) {
                            highlight.Update(boundaries.x, boundaries.y,
                                boundaries.w, boundaries.h)
                        }
                        ; Update subgrid position even if hidden, so it appears correctly if state changes
                        if (IsObject(subGrid)) {
                            subGrid.Update(boundaries.x, boundaries.y,
                                boundaries.w, boundaries.h)
                        }

                        ; Update the active cell key in the state
                        StateMap['activeCellKey'] := currentCellKey

                        ; If we were just selecting the grid, moving the mouse over a cell
                        ; should activate the subgrid state for that cell.
                        if (currentState == "GRID_VISIBLE") {
                            currentState := "SUBGRID_ACTIVE"
                            stateTransitionTime := A_TickCount ; Update transition time
                            if (IsObject(subGrid)) {
                                subGrid.gui.Show() ; Explicitly show subgrid
                            }
                        }

                        ; Update current row/column indices based on the new cell
                        colChar := SubStr(currentCellKey, 1, 1)
                        rowChar := SubStr(currentCellKey, 2) ; Handle multi-char row keys if any

                        for i, k in StateMap['activeColKeys'] {
                            if (colChar = k) {
                                StateMap['currentColIndex'] := i
                                break
                            }
                        }
                        for i, k in StateMap['activeRowKeys'] {
                            if (rowChar = k) {
                                StateMap['currentRowIndex'] := i
                                StateMap['lastSelectedRowIndex'] := i
                                break
                            }
                        }

                        if (showcaseDebug) {
                            ToolTip("Cursor over Cell: " currentCellKey " (Col:" StateMap[
                                'currentColIndex'] " Row:" StateMap['currentRowIndex'] ")")
                        }
                    } catch as e_gui_update {
                        if (showcaseDebug) {
                            ToolTip("Error updating GUI in TrackCursor: " e_gui_update.Message)
                        }
                    }
                }
            } else if (currentCellKey == "" && StateMap['activeCellKey'] != "") {
                ; Cursor moved off a cell but still within the overlay
                StateMap['activeCellKey'] := "" ; Clear active cell
                if (IsObject(highlight))
                    highlight.Hide()
                if (IsObject(subGrid))
                    subGrid.Hide()
                ; Consider if state should revert to GRID_VISIBLE here? Maybe not, keep SUBGRID_ACTIVE?
                ; If reverting: currentState := "GRID_VISIBLE"
            }
        } catch as e_cell_track {
            if (showcaseDebug)
                ToolTip("Error in cell tracking logic: " e_cell_track.Message)
        }
    } catch as e_main {
        if (showcaseDebug)
            ToolTip("Error in TrackCursor main try: " e_main.Message)
        ; Consider stopping the timer if errors persist
        ; SetTimer(TrackCursor, 0)
    }
}

; --- Key Processing Wrapper ---

; Central function called by hotkeys to route key presses to the appropriate handler based on the current state.
ProcessKeyPress(key) {
    ; Access global state and config
    global currentState, subGridKeys, instaClickMode,
        g_ModifierState

    ; Special handling for instaclick mode - allow key events even when CapsLock is held for the click
    if (instaClickMode && g_ModifierState.inHoldMode) {
        ; Allow processing even if CapsLock is physically down for the click release
    }
    ; If not in instaclick hold mode, check if CapsLock is physically pressed (for standard Caps+Key navigation)
    ; This check might be redundant if #HotIf contexts are set up correctly, but acts as a safeguard.
    ; else if (GetKeyState("CapsLock", "P")) {
    ;     ; Allow processing if CapsLock is held for navigation (handled by CapsLock & key hotkeys)
    ; }

    if (currentState == "GRID_VISIBLE") {
        HandleKey(key) ; Process as first or second grid key
    } else if (currentState == "SUBGRID_ACTIVE") {
        ; Check if the key is a subgrid navigation key
        isSubGridKey := false
        for i, subKey in subGridKeys {
            if (key == subKey) {
                isSubGridKey := true
                break
            }
        }

        if (isSubGridKey) {
            HandleSubGridKey(key) ; Process subgrid selection
        } else {
            ; If not a subgrid key, assume it's intended to start a new grid selection
            StartNewSelection(key)
        }
    }
    ; Do nothing if currentState is IDLE (should be handled by activation hotkeys)
}
