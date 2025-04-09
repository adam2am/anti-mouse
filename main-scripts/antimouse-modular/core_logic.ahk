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
        if (showcaseDebug && currentState != "IDLE") {
            ToolTip("Invalid mapped monitor index: " mappedMonitor)
        }
        return
    }

    ; Temporarily disable cursor tracking during the switch
    SetTimer(TrackCursor, 0)

    ; Get the target overlay object
    newOverlay := StateMap['overlays'][mappedMonitor]
    if (!IsObject(newOverlay)) {
        if (showcaseDebug) {
            ToolTip("Target overlay object not found for monitor " mappedMonitor)
        }
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
    global StateMap, showcaseDebug ; Access global state

    ; Ensure we have a valid current overlay
    if (!IsObject(StateMap['currentOverlay'])) {
        if (showcaseDebug)
            ToolTip("GetCellAtPosition: No valid current overlay")
        return ""
    }

    ; Check if the point is within the current overlay's boundaries
    if (!StateMap['currentOverlay'].ContainsPoint(x, y)) {
        if (showcaseDebug)
            ToolTip("GetCellAtPosition: Point (" x "," y ") outside overlay bounds")
        return ""
    }

    ; Iterate through cells of the current overlay to find which one contains the point
    ; Use the cells map directly from the OverlayGUI object
    for cellKey, cellData in StateMap['currentOverlay'].cells {
        if (x >= cellData.absX && x < cellData.absX + cellData.w &&
            y >= cellData.absY && y < cellData.absY + cellData.h) {
            if (showcaseDebug)
                ToolTip("GetCellAtPosition: Found cell " cellKey " at (" x "," y ")")
            return cellKey ; Return the key (e.g., "qj")
        }
    }

    if (showcaseDebug)
        ToolTip("GetCellAtPosition: No cell found at (" x "," y ")")
    return ""
}

; --- Key Handling Logic ---

HandleKey(key) {
    ; Static variables for processing lock and auto-repeat prevention
    static keyProcessingLock := false
    static lastKeyProcessed := ""
    static lastKeyTime := 0
    static ignoreThreshold := 50 ; Ignore same key if pressed within 50ms

    ; Define currentTime at the beginning of the function
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        keyPhysicallyDown := GetKeyState(key, "P")
        logMsg := Format(
            "Timestamp: {} | HandleKey START | key={} | PhysicallyDown={} | currentState={} | firstKey={} | activeRowKey={} | inUltraFastMode={}",
            currentTime, key, keyPhysicallyDown ? "DOWN" : "UP", currentState, StateMap['firstKey'], StateMap[
                'activeRowKey'], StateMap['inUltraFastMode']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Prevent re-entry if already processing
    if (keyProcessingLock) {
        if (showcaseDebug) {
            logMsg := Format("Timestamp: {} | HandleKey Locked - Ignoring key={}", currentTime, key)
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Special check for active row key - ignore auto-repeat if we're tracking it
    if (currentState == "SUBGRID_ACTIVE" && enableUltraFast && key == StateMap['activeRowKey']) {
        if (showcaseDebug) {
            keyPhysicallyDown := GetKeyState(key, "P")
            logMsg := Format(
                "Timestamp: {} | HandleKey: Ignoring auto-repeat of active row key | key={} | PhysicallyDown={}",
                currentTime, key, keyPhysicallyDown ? "DOWN" : "UP")
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Set lock
    keyProcessingLock := true

    try {
        ; currentTime already defined at the top of the function

        ; Check if the same key is being processed too rapidly (likely auto-repeat)
        ; Note: This check might become less critical with the lock, but kept for safety
        if (key = lastKeyProcessed && (currentTime - lastKeyTime < ignoreThreshold)) {
            if (showcaseDebug) {
                logMsg := Format("Timestamp: {} | Ignored rapid repeat: key={}", currentTime, key)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return ; Ignore this key press
        }

        ; Update last key processed *before* handling the logic
        ; Update time immediately
        lastKeyProcessed := key
        lastKeyTime := currentTime

        global currentState, highlight, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, StateMap,
            storePerMonitor, showcaseDebug, instaClickMode, g_ModifierState, enableUltraFast, rowKeyHoldThreshold

        ; Special handling for instaclick mode - always handle key events even when CapsLock is held
        if (instaClickMode && g_ModifierState.inHoldMode) {
            ; Process key normally, even though CapsLock is being held
        }

        ; IMPROVEMENT: Explicit hiding at the beginning
        if (IsObject(highlight)) {
            highlight.Hide()
        }
        if (IsObject(subGrid)) {
            subGrid.Hide()
        }

        ; IMPROVEMENT: Temporarily disable TrackCursor to prevent interference
        SetTimer(TrackCursor, 0)

        if (currentState != "GRID_VISIBLE" || !IsObject(StateMap['currentOverlay'])) { ; Use StateMap
            ; Re-enable TrackCursor before returning
            SetTimer(TrackCursor, 50)
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return
        }

        ; Check if key is a valid column or row key
        isColKey := false
        colIndex := 0
        for i, colKeyCheck in StateMap['activeColKeys'] { ; Use StateMap
            if (colKeyCheck = key) {
                isColKey := true
                colIndex := i
                break
            }
        }

        isRowKey := false
        rowIndex := 0
        for i, rowKeyCheck in StateMap['activeRowKeys'] { ; Use StateMap
            if (rowKeyCheck = key) {
                isRowKey := true
                rowIndex := i
                break
            }
        }

        if (!isColKey && !isRowKey) {
            if (showcaseDebug) {
                ToolTip("Invalid key: " key)
                Sleep 1000
                ToolTip()
            }
            SetTimer(TrackCursor, 50)
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return
        }

        cellKey := ""
        targetCellX := 0
        targetCellY := 0
        targetCellW := 0
        targetCellH := 0
        tooltipText := ""
        proceedToSubgrid := false
        updateFirstKeyOnly := false
        secondKeyWasRow := false

        if (StateMap['firstKey'] = "") {
            ; --- First Key Press ---
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format("Timestamp: {} | HandleKey: First Key Press | key={}", currentTime,
                key) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
                StateMap['firstKey'] := key
            if (isColKey) {
                ; First key is COLUMN
                StateMap['currentColIndex'] := colIndex
                targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1
                targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length)
                cellKey := key . StateMap['activeRowKeys'][targetRowIndex]
                tooltipText := "First key: " key ". Select row."
            } else { ; isRowKey
                ; First key is ROW
                StateMap['currentRowIndex'] := rowIndex
                StateMap['lastSelectedRowIndex'] := rowIndex
                targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] : Ceil(StateMap[
                    'activeColKeys'
                    ].Length / 2)
                targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length)
                cellKey := StateMap['activeColKeys'][targetColIndex] . key
                tooltipText := "First key: " key ". Select column."
            }

            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }

            ; Center cursor and wait for second key
            if (targetCellW > 0) {
                highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
                Sleep(10)
                if (showcaseDebug) {
                    ToolTip(tooltipText)
                }
            }
            SetTimer(TrackCursor, 50)
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return ; Wait for second key

        } else {
            ; --- Second Key Press Logic Refactored ---
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format("Timestamp: {} | HandleKey: Second Key Press | key={} | firstKey={}",
                currentTime, key, StateMap['firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
                firstKey := StateMap['firstKey']
            firstKeyWasCol := false
            for colKeyCheck in StateMap['activeColKeys'] {
                if (colKeyCheck = firstKey) {
                    firstKeyWasCol := true
                    break
                }
            }
            firstKeyWasRow := !firstKeyWasCol
            if (showcaseDebug) {
                logMsg := Format("Timestamp: {} | Second Key Check: firstKeyWasCol={} | firstKeyWasRow={}", currentTime,
                    firstKeyWasCol, firstKeyWasRow)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }

            if (firstKeyWasCol && isRowKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Col -> Row", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")

                    ; Check if this row key is physically held down
                    rowKeyIsPhysicallyDown := GetKeyState(key, "P")
                    logMsg := Format("Timestamp: {} | Row key '{}' physical state: {}",
                        currentTime, key, rowKeyIsPhysicallyDown ? "DOWN" : "UP")
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Valid: Col -> Row
                cellKey := firstKey . key
                proceedToSubgrid := true
                secondKeyWasRow := true
            } else if (firstKeyWasRow && isColKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Row -> Col", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Valid: Row -> Col
                cellKey := key . firstKey
                proceedToSubgrid := true
            } else if (firstKeyWasCol && isColKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Col -> Col (Change Col)", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Update First Key: Col -> Col
                StateMap['firstKey'] := key
                tooltipText := "Column changed to: " key ". Select row."
                updateFirstKeyOnly := true
            } else if (firstKeyWasRow && isRowKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Row -> Row (Change Row)", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Update First Key: Row -> Row
                StateMap['firstKey'] := key
                tooltipText := "Row changed to: " key ". Select column."
                updateFirstKeyOnly := true
            } else {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Invalid Sequence", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Invalid sequence (e.g., firstKey wasn't found in either col/row keys somehow?)
                StateMap['firstKey'] := ""
                SetTimer(TrackCursor, 50)
                ; Ensure lock is released before returning
                keyProcessingLock := false
                return
            }

            ; --- Handle Outcome of Second Key Press ---
            if (updateFirstKeyOnly) {
                ; Only update the preview, don't proceed to subgrid yet
                if (targetCellW > 0) {
                    highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                    MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
                    Sleep(10)
                    if (showcaseDebug) {
                        ToolTip(tooltipText)
                    }
                }
                SetTimer(TrackCursor, 50)
                keyProcessingLock := false
                return ; Wait for the *new* second key
            }
        }

        ; --- Proceed to Subgrid State (Only if proceedToSubgrid is true) ---
        if (proceedToSubgrid && cellKey != "") {
            ; <<< CORE LOGGING START >>>
            FileAppend(Format("Timestamp: {} | HandleKey: Attempting GetCellBoundaries for cellKey={}", A_TickCount,
                cellKey) "`n", "antimouse_core.log")
            ; <<< CORE LOGGING END >>>
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            ; <<< CORE LOGGING START >>>
            FileAppend(Format("Timestamp: {} | HandleKey: IsObject(boundaries) result = {}", A_TickCount, IsObject(
                boundaries)) "`n", "antimouse_core.log")
            ; <<< CORE LOGGING END >>>
            if (IsObject(boundaries)) {
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Boundaries OK. Setting currentState=SUBGRID_ACTIVE (Before)",
                    A_TickCount) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                StateMap['activeCellKey'] := cellKey
                stateTransitionTime := currentTime
                currentState := "SUBGRID_ACTIVE"

                ; Set ultra-fast tracking info *if applicable*
                if (enableUltraFast && secondKeyWasRow) {
                    ; Check if this row key is physically held down before setting track variables
                    rowKeyIsPhysicallyDown := GetKeyState(key, "P")
                    ; <<< ADD LOGGING START >>>
                    if (showcaseDebug)
                        FileAppend(Format(
                            "Timestamp: {} | HandleKey: Setting UltraFast Vars | key={} | currentTime={} | PhysicallyDown={}",
                            currentTime, key, currentTime, rowKeyIsPhysicallyDown) "`n", A_ScriptDir "\debugRapidRefresh.log"
                        )
                    ; <<< ADD LOGGING END >>>
                    StateMap['rowKeyHeldTime'] := currentTime
                    StateMap['activeRowKey'] := key
                    ; <<< ADD LOGGING START >>>
                    if (showcaseDebug)
                        FileAppend(Format(
                            "Timestamp: {} | HandleKey: Set UltraFast Vars | activeRowKey={} | rowKeyHeldTime={}",
                            currentTime, StateMap['activeRowKey'], StateMap['rowKeyHeldTime']) "`n", A_ScriptDir "\debugRapidRefresh.log"
                        )
                    ; <<< ADD LOGGING END >>>
                }

                MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
                Sleep(40)
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Calling subGrid.Update()", A_TickCount) "`n",
                "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Calling subGrid.Show()", A_TickCount) "`n",
                "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                subGrid.Show()
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Called subGrid.Show(). Current state: {}", A_TickCount,
                    currentState) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>

                ; Force redraw
                try {
                    if (WinExist("SubGrid ahk_class AutoHotkeyGUI")) {
                        winHnd := WinGetID("SubGrid ahk_class AutoHotkeyGUI")
                        if (winHnd) {
                            PostMessage(0x000F, 0, 0, , "ahk_id " winHnd)  ; WM_PAINT message
                        }
                    }
                } catch {
                }

                ; *** Clear firstKey ONLY AFTER successfully entering subgrid state ***
                ; <<< ADD LOGGING START >>>
                if (showcaseDebug) FileAppend(Format(
                    "Timestamp: {} | HandleKey: Clearing firstKey (Before) | firstKey={}", currentTime, StateMap[
                        'firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
                ; <<< ADD LOGGING END >>>
                    StateMap['firstKey'] := ""
                ; <<< ADD LOGGING START >>>
                if (showcaseDebug) FileAppend(Format(
                    "Timestamp: {} | HandleKey: Cleared firstKey (After) | firstKey={}", currentTime, StateMap[
                        'firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
                ; <<< ADD LOGGING END >>>
                ; Check if we have a remembered subcell for this cell
                    cellFound := false

                ; First check monitor-specific key if enabled
                if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                    monitorCellKey := StateMap['currentOverlay'].monitorIndex . "_" . cellKey
                    if (cellMemory.Has(monitorCellKey)) {
                        rememberedSubCell := cellMemory[monitorCellKey]
                        cellFound := true
                        if (showcaseDebug) {
                            ToolTip("Found monitor-specific subcell: " monitorCellKey " -> " rememberedSubCell)
                            Sleep(500)
                        }
                    }
                }

                ; Fall back to general cell key if no monitor-specific key found
                if (!cellFound && cellMemory.Has(cellKey)) {
                    rememberedSubCell := cellMemory[cellKey]
                    cellFound := true
                    if (showcaseDebug) {
                        ToolTip("Found general subcell: " cellKey " -> " rememberedSubCell)
                        Sleep(500)
                    }
                }

                ; Move to the remembered subcell position if found
                if (cellFound && rememberedSubCell != "") {
                    HandleSubGridKey(rememberedSubCell)
                } else if (showcaseDebug) {
                    ToolTip("No saved subcell found for " cellKey)
                    Sleep(500)
                }

                if (showcaseDebug) {
                    ToolTip("Cell '" cellKey "' targeted. Use b-h.")
                }
            } else {
                ; Failed to get boundaries
                StateMap['firstKey'] := ""
                if (showcaseDebug && proceedToSubgrid && cellKey == "") {
                    ToolTip("Error: Proceeding to subgrid but cellKey is empty")
                }
            }
        } else {
            ; This case should ideally not be reached if logic is sound, but reset firstKey as safety
            StateMap['firstKey'] := ""
            if (showcaseDebug && proceedToSubgrid && cellKey == "") {
                ToolTip("Error: Proceeding to subgrid but cellKey is empty")
            }
        }

        SetTimer(TrackCursor, 50)

    } finally {
        ; Ensure the lock is always released
        keyProcessingLock := false
        ; <<< ADD LOGGING START >>>
        if (showcaseDebug)
            FileAppend(Format("Timestamp: {} | HandleKey FINALLY: Lock Released", currentTime) "`n",
            A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
    }
}

HandleSubGridKey(subKey) {
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
        showcaseDebug, instaClickMode, g_ModifierState

    ; Special handling for instaclick mode - always handle key events even when CapsLock is held
    if (instaClickMode && g_ModifierState.inHoldMode) {
        ; Process key normally, even though CapsLock is being held
    }

    if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid)) {
        return
    }

    ; Ensure enough time has passed since state transition to prevent accidental keypresses
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition < stateTransitionDelay) {
        Sleep(stateTransitionDelay - timeSinceTransition)
    }

    targetCoords := subGrid.GetTargetCoordinates(subKey)
    if (IsObject(targetCoords)) {
        MouseMove(targetCoords.x, targetCoords.y, 0)
        StateMap['activeSubCellKey'] := subKey

        ; Remember this subcell for the current cell
        activeCell := StateMap['activeCellKey']
        if (activeCell != "") {
            keyToSave := ""

            ; Determine the key to use based on the storePerMonitor setting
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                keyToSave := StateMap['currentOverlay'].monitorIndex . "_" . activeCell
            } else {
                keyToSave := activeCell
            }

            ; Update the memory map
            if (keyToSave != "") {
                cellMemory[keyToSave] := subKey
                if (showcaseDebug) {
                    ToolTip("Memory updated: " keyToSave " -> " subKey)
                    Sleep(500)
                }
                ; Save the entire map to file
                SaveCellMemory()
            }
        }

        if (showcaseDebug) {
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                ToolTip("Moved to sub-cell " subKey " in " activeCell " on monitor " StateMap['currentOverlay'].monitorIndex
                )
            } else {
                ToolTip("Moved to sub-cell " subKey " in " activeCell)
            }
        }
    } else {
        if (showcaseDebug) {
            ToolTip("Invalid sub-key: " subKey)
            Sleep 1000
            ToolTip()
        }
    }
}

; Handle key presses in Ultra-Fast mode
HandleUltraFastKey(key) {
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
        showcaseDebug, instaClickMode, g_ModifierState

    ; Only process in the correct state with a valid subgrid
    if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid) || !StateMap['inUltraFastMode']) {
        return
    }

    ; Ensure enough time has passed since state transition to prevent accidental keypresses
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition < stateTransitionDelay) {
        Sleep(stateTransitionDelay - timeSinceTransition)
    }

    ; Get coordinates for the key in the ultra-fast grid
    targetCoords := subGrid.GetUltraFastTargetCoordinates(key)
    if (IsObject(targetCoords)) {
        ; Move the mouse to the target position
        MouseMove(targetCoords.x, targetCoords.y, 0)
        StateMap['activeSubCellKey'] := key

        ; Remember this ultrafast subcell for the current cell
        activeCell := StateMap['activeCellKey']
        if (activeCell != "") {
            keyToSave := ""

            ; Determine the key to use based on the storePerMonitor setting
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                keyToSave := StateMap['currentOverlay'].monitorIndex . "_" . activeCell
            } else {
                keyToSave := activeCell
            }

            ; Update the memory map - append "ultra:" prefix to know it's an ultra-fast key
            if (keyToSave != "") {
                cellMemory[keyToSave] := "ultra:" . key
                if (showcaseDebug) {
                    ToolTip("Memory updated with ultra-fast key: " keyToSave " -> ultra:" key)
                    Sleep(500)
                }
                ; Save the entire map to file
                SaveCellMemory()
            }
        }

        if (showcaseDebug) {
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                ToolTip("Moved to ultra-fast cell " key " in " activeCell " on monitor " StateMap['currentOverlay']
                    .monitorIndex
                )
            } else {
                ToolTip("Moved to ultra-fast cell " key " in " activeCell)
            }
        }
    } else {
        if (showcaseDebug) {
            ToolTip("Invalid ultra-fast key: " key)
            Sleep(1000)
            ToolTip()
        }
    }
}

StartNewSelection(key) {
    global currentState, subGrid, highlight, StateMap, enableUltraFast, showcaseDebug

    ; Define currentTime at the beginning
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        ; Get physical key state
        keyPhysicallyDown := GetKeyState(key, "P")
        rowKeyPhysicallyDown := StateMap['activeRowKey'] != "" ? GetKeyState(StateMap['activeRowKey'], "P") : false
        logMsg := Format(
            "Timestamp: {} | StartNewSelection START | key={} | PhysicallyDown={} | currentState={} | firstKey={} | activeRowKey={} | activeRowKeyPhysicallyDown={} | inUltraFastMode={}",
            currentTime, key, keyPhysicallyDown ? "DOWN" : "UP", currentState, StateMap['firstKey'], StateMap[
                'activeRowKey'],
            rowKeyPhysicallyDown ? "DOWN" : "UP", StateMap['inUltraFastMode']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; IMPROVEMENT: Temporarily disable TrackCursor
    SetTimer(TrackCursor, 0)

    if (currentState != "SUBGRID_ACTIVE") {
        ; Re-enable TrackCursor before returning
        SetTimer(TrackCursor, 50)
        return
    }

    ; If in Ultra-Fast mode and this is the held row key, ignore
    if (enableUltraFast && StateMap['inUltraFastMode'] && key == StateMap['activeRowKey']) {
        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format("Timestamp: {} | StartNewSelection: Ignoring held row key press | key={}",
            currentTime, key) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
            SetTimer(TrackCursor, 50) ; Re-enable tracker
        return
    }

    ; If not in UltraFast mode yet but this is the active row key being held, don't reset
    if (enableUltraFast && key == StateMap['activeRowKey'] && GetKeyState(key, "P")) {
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
    StateMap['inUltraFastMode'] := false ; Exit ultra-fast mode
    StateMap['activeRowKey'] := "" ; Clear active row key
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | StartNewSelection: Reset State (After) | inUltraFastMode={} | activeRowKey={}", currentTime,
        StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
        if (showcaseDebug) FileAppend(Format(
            "Timestamp: {} | StartNewSelection: Setting currentState=GRID_VISIBLE (Before) | currentState={}",
            currentTime, currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
            currentState := "GRID_VISIBLE"
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | StartNewSelection: Set currentState=GRID_VISIBLE (After) | currentState={}", currentTime,
        currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Force a small delay to ensure state transitions properly
        Sleep(10)

    ; Call HandleKey to process the key press
    HandleKey(key)

    ; TrackCursor re-enabled in HandleKey
}

; --- Cursor Tracking ---

; Monitors the mouse cursor position and updates the active cell/highlight/subgrid accordingly.
TrackCursor() {
    ; Access global state and config
    global currentState, highlight, subGrid, StateMap, showcaseDebug, enableUltraFast, rowKeyHoldThreshold

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        logMsg := Format(
            "Timestamp: {} | TrackCursor START | currentState={} | firstKey={} | activeRowKey={} | inUltraFastMode={}",
            A_TickCount, currentState, StateMap['firstKey'], StateMap['activeRowKey'], StateMap['inUltraFastMode'])
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Ignore tracking if idle or dragging ...
    if (currentState == "IDLE" || currentState == "DRAGGING") {
        return
    }

    ; --- Check for Ultra-Fast Mode Activation ---
    if (enableUltraFast && currentState == "SUBGRID_ACTIVE" &&
        StateMap['activeRowKey'] != "" && !StateMap['inUltraFastMode']) {
        ; Get physical state of the row key using GetKeyState
        rowKeyPhysicallyDown := GetKeyState(StateMap['activeRowKey'], "P")

        ; Calculate how long the row key has been held
        heldTime := A_TickCount - StateMap['rowKeyHeldTime']

        ; Detailed logging before the check
        if (showcaseDebug) {
            logMsg := Format(
                "Timestamp: {} | TrackCursor Check: CurrentTick={}, HeldTimeStart={}, CalculatedHeldTime={}, Threshold={}, ActiveRowKey={}, PhysicallyDown={}, State={}",
                A_TickCount, A_TickCount, StateMap['rowKeyHeldTime'], heldTime, rowKeyHoldThreshold, StateMap[
                    'activeRowKey'], rowKeyPhysicallyDown, currentState)
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }

        ; Add debug output to help diagnose timing
        if (showcaseDebug) {
            static lastDebugTime := 0
            currentTime := A_TickCount

            ; Only show debug tooltip every 300ms to avoid flicker
            if (currentTime - lastDebugTime > 300) {
                lastDebugTime := currentTime
                ToolTip("Row key " StateMap['activeRowKey'] " held for " heldTime "ms (needs " rowKeyHoldThreshold "ms) - PhysicallyDown: " rowKeyPhysicallyDown
                )
            }
        }

        ; Check if key is physically down and we've held long enough to trigger ultra-fast mode
        if (rowKeyPhysicallyDown && heldTime >= rowKeyHoldThreshold) {
            ; Add explicit feedback when hold is detected
            if (showcaseDebug) {
                logMsg := Format("Timestamp: {} | TrackCursor: Hold Threshold Met! ({} >= {}), Key is physically down",
                    A_TickCount, heldTime, rowKeyHoldThreshold)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                ToolTip("Hold detected! Switching to ultra-fast...")
                Sleep(300) ; Brief pause to show tooltip
            }

            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format("Timestamp: {} | TrackCursor: Setting inUltraFastMode=true (Before)",
                A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
                StateMap['inUltraFastMode'] := true
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format("Timestamp: {} | TrackCursor: Set inUltraFastMode=true (After)",
                A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
            ; Update subgrid display
                if (IsObject(subGrid)) {
                    subGrid.SwitchToUltraFast()
                    subGrid.Show() ; Explicitly show the updated subgrid

                    ; Force redraw
                    try {
                        if (WinExist("SubGrid ahk_class AutoHotkeyGUI")) {
                            winHnd := WinGetID("SubGrid ahk_class AutoHotkeyGUI")
                            if (winHnd) {
                                PostMessage(0x000F, 0, 0, , "ahk_id " winHnd)  ; WM_PAINT message
                            }
                        }
                    } catch {
                    }
                }

            if (showcaseDebug) {
                ToolTip("Ultra-Fast mode activated! Row key " StateMap['activeRowKey'] " held for " heldTime "ms")
                Sleep(1000)
                ToolTip()
            }
        }
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

                            ; Always show subgrid if we're in SUBGRID_ACTIVE state
                            if (currentState == "SUBGRID_ACTIVE" || currentState == "SUBGRID_PREVIEW") {
                                subGrid.Show()

                                ; Force redraw to ensure visibility
                                try {
                                    if (WinExist("SubGrid ahk_class AutoHotkeyGUI")) {
                                        winHnd := WinGetID("SubGrid ahk_class AutoHotkeyGUI")
                                        if (winHnd) {
                                            PostMessage(0x000F, 0, 0, , "ahk_id " winHnd)  ; WM_PAINT message
                                        }
                                    }
                                } catch {
                                }
                            }
                        }

                        ; Update the active cell key in the state
                        StateMap['activeCellKey'] := currentCellKey

                        ; If we were just selecting the grid, moving the mouse over a cell
                        ; should activate the subgrid state for that cell,
                        ; *** BUT ONLY IF a key sequence isn't already in progress ***
                        if (currentState == "GRID_VISIBLE" && StateMap['firstKey'] == "") {
                            ; <<< ADD LOGGING START >>>
                            if (showcaseDebug) FileAppend(Format(
                                "Timestamp: {} | TrackCursor: Setting currentState=SUBGRID_ACTIVE (Mouse Move, no firstKey - Before)",
                                A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
                            ; <<< ADD LOGGING END >>>
                                currentState := "SUBGRID_ACTIVE"
                            ; <<< ADD LOGGING START >>>
                            if (showcaseDebug) FileAppend(Format(
                                "Timestamp: {} | TrackCursor: Set currentState=SUBGRID_ACTIVE (Mouse Move, no firstKey - After)",
                                A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
                            ; <<< ADD LOGGING END >>>
                                stateTransitionTime := A_TickCount ; Update transition time
                            if (IsObject(subGrid)) {
                                subGrid.Show() ; Use proper Show method
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
                ; <<< ADD LOGGING START >>>
                if (showcaseDebug) FileAppend(Format(
                    "Timestamp: {} | TrackCursor: Clearing activeCellKey (Moved Off Cell)", A_TickCount) "`n",
                A_ScriptDir "\debugRapidRefresh.log")
                ; <<< ADD LOGGING END >>>
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
        g_ModifierState, StateMap, enableUltraFast, ultraFastSubGridKeys, showcaseDebug

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        ; Get physical key state
        keyPhysicallyDown := GetKeyState(key, "P")
        logMsg := Format(
            "Timestamp: {} | ProcessKeyPress START | key={} | PhysicallyDown={} | currentState={} | rowKeyHeldTime={} | activeRowKey={}",
            A_TickCount, key, keyPhysicallyDown ? "DOWN" : "UP", currentState, StateMap['rowKeyHeldTime'], StateMap[
                'activeRowKey']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Special handling for instaclick mode - allow key events even when CapsLock is held for the click
    if (instaClickMode && g_ModifierState.inHoldMode) {
        ; Allow processing even if CapsLock is physically down for the click release
    }

    if (currentState == "GRID_VISIBLE") {
        HandleKey(key) ; Process as first or second grid key
    } else if (currentState == "SUBGRID_ACTIVE") {
        ; Check if key is the active row key that we're already tracking
        if (enableUltraFast && key == StateMap['activeRowKey']) {
            ; We're already tracking this key being held, don't process it again
            ; This prevents auto-repeat from disrupting the hold tracking
            if (showcaseDebug) {
                keyPhysicallyDown := GetKeyState(key, "P")
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignoring repeat of active row key | key={} | PhysicallyDown={}",
                    A_TickCount, key, keyPhysicallyDown ? "DOWN" : "UP"
                )
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            return
        }

        ; Check if we're in ultra-fast mode
        if (enableUltraFast && StateMap['inUltraFastMode']) {
            ; Check if key is an ultra-fast subgrid key
            for i, ultraKey in ultraFastSubGridKeys {
                if (key == ultraKey) {
                    HandleUltraFastKey(key)
                    return
                }
            }

            ; Check if it's the active row key being held
            if (key == StateMap['activeRowKey']) {
                ; Just ignore, user is still holding the row key
                return
            }
        }

        ; If not handled by ultra-fast mode, continue with standard logic
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

; Handles the release of a row key in Ultra-Fast mode, switching back to standard mode
HandleRowKeyRelease(key) {
    global subGrid, StateMap, showcaseDebug, enableUltraFast

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        logMsg := Format(
            "Timestamp: {} | HandleRowKeyRelease START | key={} | currentState={} | activeRowKey={} | inUltraFastMode={}",
            A_TickCount, key, currentState, StateMap['activeRowKey'], StateMap['inUltraFastMode'])
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Log Check condition
    if (showcaseDebug) {
        logMsg := Format(
            "Timestamp: {} | HandleRowKeyRelease: Check condition: enableUltraFast={}, inUltraFastMode={}, activeRowKey={}",
            A_TickCount, enableUltraFast, StateMap['inUltraFastMode'], StateMap['activeRowKey'])
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }

    ; Only proceed if we're in Ultra-Fast mode and this is the key that activated it
    if (!enableUltraFast || !StateMap['inUltraFastMode'] || key != StateMap['activeRowKey']) {
        ; Log condition failed if applicable
        if (showcaseDebug && StateMap['inUltraFastMode']) {
            logMsg := Format(
                "Timestamp: {} | HandleRowKeyRelease: Condition FAILED for key={}. Expected activeRowKey={}",
                A_TickCount, key, StateMap['activeRowKey'])
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Log Deactivation confirmation
    if (showcaseDebug) {
        logMsg := Format("Timestamp: {} | HandleRowKeyRelease: Deactivating ultra-fast mode for key={}", A_TickCount,
            key)
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }

    ; Switch back to standard mode
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | HandleRowKeyRelease: Setting inUltraFastMode=false (Before) | inUltraFastMode={}", A_TickCount,
        StateMap['inUltraFastMode']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
        StateMap['inUltraFastMode'] := false
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | HandleRowKeyRelease: Set inUltraFastMode=false (After) | inUltraFastMode={}", A_TickCount,
        StateMap['inUltraFastMode']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Update the subgrid UI
        if (IsObject(subGrid)) {
            subGrid.SwitchToStandard()

            ; Force redraw
            try {
                if (WinExist("SubGrid ahk_class AutoHotkeyGUI")) {
                    winHnd := WinGetID("SubGrid ahk_class AutoHotkeyGUI")
                    if (winHnd) {
                        PostMessage(0x000F, 0, 0, , "ahk_id " winHnd)  ; WM_PAINT message
                    }
                }
            } catch {
            }
        }

    ; Reset state
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | HandleRowKeyRelease: Clearing activeRowKey (Before) | activeRowKey={}", A_TickCount, StateMap[
            'activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
        StateMap['activeRowKey'] := ""
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | HandleRowKeyRelease: Cleared activeRowKey (After) | activeRowKey={}", A_TickCount, StateMap[
            'activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Original Tooltip
        if (showcaseDebug) {
            ToolTip("Ultra-Fast mode deactivated - row key " key " released")
            Sleep(500)
            ToolTip()
        }
}
