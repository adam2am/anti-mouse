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
    global StateMap
    ; --- CORE LOGGING START ---
    initialFirstKey := StateMap.Has("firstKey") ? StateMap["firstKey"] : "<Not Set>"
    FileAppend(Format("Timestamp: {} | HandleKey: Function ENTRY. initialFirstKey='{}'", A_TickCount, initialFirstKey) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---
    ; Access the dedicated global for first key tracking
    global g_firstKeyPressed
    ; Static variables for processing lock and auto-repeat prevention
    static keyProcessingLock := false
    static lastKeyProcessed := ""
    static lastKeyTime := 0
    static ignoreThreshold := 50 ; Ignore same key if pressed within 50ms

    ; Define currentTime at the beginning of the function
    currentTime := A_TickCount

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | HandleKey | key='{}' | currentState='{}' | g_firstKeyPressed='{}' | keyProcessingLock={}",
        A_TickCount, key, currentState, g_firstKeyPressed, keyProcessingLock) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        keyPhysicallyDown := (key != "") ? GetKeyState(key, "P") : "N/A"
        rowKeyPhysicallyDown := StateMap['activeRowKey'] != "" ? GetKeyState(StateMap['activeRowKey'], "P") : false
        logMsg := Format(
            "Timestamp: {} | HandleKey START | key={} | PhysicallyDown={} | currentState={} | firstKey={} | activeRowKey={} | activeRowKeyPhysicallyDown={} | inUltraFastMode={}",
            currentTime, key, keyPhysicallyDown, currentState, StateMap['firstKey'], StateMap[
                'activeRowKey'],
            rowKeyPhysicallyDown ? "DOWN" : "UP", StateMap['inUltraFastMode']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Prevent re-entry if already processing
    if (keyProcessingLock) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: Key processing locked, ignoring key='{}'",
            A_TickCount, key) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        if (showcaseDebug) {
            logMsg := Format("Timestamp: {} | HandleKey Locked - Ignoring key={}", currentTime, key)
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Special check for active row key - ignore auto-repeat if we're tracking it
    if (currentState == "SUBGRID_ACTIVE" && enableUltraFast && key == StateMap['activeRowKey']) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: Ignoring auto-repeat of row key='{}'",
            A_TickCount, key) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

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
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Ignoring rapid repeat of key='{}', lastKeyTime={}, diff={}ms",
                A_TickCount, key, lastKeyTime, currentTime - lastKeyTime) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

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
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Invalid state/overlay. currentState='{}', IsObject(currentOverlay)={}",
                A_TickCount, currentState, IsObject(StateMap['currentOverlay'])) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

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

        ; --- CORE LOGGING START ---
        FileAppend(Format(
            "Timestamp: {} | HandleKey: Key type check for key='{}'. isColKey={}, isRowKey={}. InvalidCheck={}",
            A_TickCount, key, isColKey, isRowKey, (!isColKey && !isRowKey)) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---
        if (!isColKey && !isRowKey) {
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Invalid key type for key='{}'. Not a col or row key.",
                A_TickCount, key) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

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

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | HandleKey: Before firstKey check. Global g_firstKeyPressed='{}'",
            A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; --- FIX: Check GLOBAL variable ---
        if (g_firstKeyPressed == "") {
            ; --- First Key Press ---
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Processing FIRST key press. Setting g_firstKeyPressed='{}'",
                A_TickCount, key) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format("Timestamp: {} | HandleKey: First Key Press | key={}", currentTime,
                key) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
            ; *** ASSIGN GLOBAL g_firstKeyPressed ***
                g_firstKeyPressed := key
            local newlySetFirstKey := key ; Store locally to use in this block

            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | HandleKey: Setting GLOBAL g_firstKeyPressed='{}'. Value is now '{}'",
                A_TickCount, newlySetFirstKey, g_firstKeyPressed) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---

            if (isColKey) {
                ; First key is COLUMN
                ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
                FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: First key is COLUMN='{}'",
                    A_TickCount, key) "`n", "antimouse_core.log")
                ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

                StateMap['currentColIndex'] := colIndex
                targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1
                targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length)
                cellKey := newlySetFirstKey . StateMap['activeRowKeys'][targetRowIndex] ; Use local var
                tooltipText := "First key: " newlySetFirstKey ". Select row."
            } else { ; isRowKey
                ; First key is ROW
                ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
                FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: First key is ROW='{}'",
                    A_TickCount, key) "`n", "antimouse_core.log")
                ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

                StateMap['currentRowIndex'] := rowIndex
                StateMap['lastSelectedRowIndex'] := rowIndex
                targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] : Ceil(StateMap[
                    'activeColKeys'
                    ].Length / 2)
                targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length)
                cellKey := StateMap['activeColKeys'][targetColIndex] . newlySetFirstKey ; Use local var
                tooltipText := "First key: " newlySetFirstKey ". Select column."
            }

            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            if (IsObject(boundaries)) {
                FileAppend(Format(
                    "Timestamp: {} | DIAGNOSTIC | HandleKey: Got cell boundaries for cellKey='{}'. x={}, y={}, w={}, h={}",
                    A_TickCount, cellKey, boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n",
                "antimouse_core.log")
            } else {
                FileAppend(Format(
                    "Timestamp: {} | DIAGNOSTIC | HandleKey: ERROR - Failed to get boundaries for cellKey='{}'",
                    A_TickCount, cellKey) "`n", "antimouse_core.log")
            }
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }

            ; Center cursor and wait for second key
            if (targetCellW > 0) {
                highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                ; --- RE-ENABLE CURSOR SNAPPING (HandleKey - First Key) ---
                MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
                Sleep(10)
                if (showcaseDebug) {
                    ToolTip(tooltipText)
                }
            }
            SetTimer(TrackCursor, 50)
            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | HandleKey: END of firstKey block. GLOBAL g_firstKeyPressed is now '{}'",
                A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return ; Wait for second key

        } else {
            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | ENTERED second key 'else' block. GLOBAL g_firstKeyPressed='{}'",
                A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            ; --- Second Key Press Logic Refactored ---
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format(
                "Timestamp: {} | HandleKey: Second Key Press | key={} | static firstKeyPressed={}", currentTime, key,
                firstKeyPressed) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
            ; --- FIX: Use static variable ---
                local firstKey := firstKeyPressed ; Use local var derived from static
            firstKeyWasCol := false
            for colKeyCheck in StateMap['activeColKeys'] {
                if (colKeyCheck = firstKey) {
                    firstKeyWasCol := true
                    break
                }
            }
            firstKeyWasRow := !firstKeyWasCol
            ; --- CORE LOGGING START ---
            FileAppend(Format(
                "Timestamp: {} | HandleKey: Before firstKeyWasCol loop. StateMap['activeColKeys'] type: {}",
                A_TickCount, Type(StateMap['activeColKeys'])) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            if (showcaseDebug) {
                logMsg := Format("Timestamp: {} | Second Key Check: firstKeyWasCol={} | firstKeyWasRow={}", currentTime,
                    firstKeyWasCol, firstKeyWasRow)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }

            ; --- CORE LOGGING START ---
            FileAppend(Format(
                "Timestamp: {} | HandleKey: Before Col->Row check: firstKey='{}', key='{}', firstKeyWasCol={}, isRowKey={}",
                A_TickCount, firstKey, key, firstKeyWasCol, isRowKey) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            if (firstKeyWasCol && isRowKey) {
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: ENTERED Col->Row block.", A_TickCount) "`n",
                "antimouse_core.log")
                ; --- CORE LOGGING END ---
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
                ; --- CORE LOGGING START ---
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Values before cellKey assignment (Col->Row): firstKey='{}', key='{}'.",
                    A_TickCount, firstKey, key) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                cellKey := firstKey . key
                proceedToSubgrid := true
                secondKeyWasRow := true
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: Determined Col->Row. proceedToSubgrid={}, cellKey={}",
                    A_TickCount, proceedToSubgrid, cellKey) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
            } else if (firstKeyWasRow && isColKey) {
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: ENTERED Row->Col block.", A_TickCount) "`n",
                "antimouse_core.log")
                ; --- CORE LOGGING END ---
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Row -> Col", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Valid: Row -> Col
                ; --- CORE LOGGING START ---
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Values before cellKey assignment (Row->Col): firstKey='{}', key='{}'.",
                    A_TickCount, firstKey, key) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                cellKey := key . firstKey
                proceedToSubgrid := true
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: Determined Row->Col. proceedToSubgrid={}, cellKey={}",
                    A_TickCount, proceedToSubgrid, cellKey) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
            } else if (firstKeyWasCol && isColKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Col -> Col (Change Col)", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Update First Key: Col -> Col
                ; --- FIX: Update static variable ---
                firstKeyPressed := key
                tooltipText := "Column changed to: " key ". Select row."
                updateFirstKeyOnly := true
            } else if (firstKeyWasRow && isRowKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Row -> Row (Change Row)", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Update First Key: Row -> Row
                ; --- FIX: Update static variable ---
                firstKeyPressed := key
                tooltipText := "Row changed to: " key ". Select column."
                updateFirstKeyOnly := true
            } else {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Invalid Sequence", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Invalid sequence (e.g., firstKey wasn't found in either col/row keys somehow?)
                ; --- FIX: Clear static variable ---
                firstKeyPressed := ""
                SetTimer(TrackCursor, 50)
                ; Ensure lock is released before returning
                keyProcessingLock := false
                return
            }

            ; --- Handle Outcome of Second Key Press ---
            if (updateFirstKeyOnly) {
                ; Only update the preview, don't proceed to subgrid yet
                ; <<< Re-enable mouse move for first key change preview >>>
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

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | BEFORE subgrid block check. proceedToSubgrid={}, cellKey={}",
            A_TickCount, proceedToSubgrid, cellKey) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; --- Proceed to Subgrid State (Only if proceedToSubgrid is true) ---
        if (proceedToSubgrid && cellKey != "") {
            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | HandleKey: >>> ENTERING proceedToSubgrid block for cellKey='{}'",
                A_TickCount, cellKey) "`n", "antimouse_core.log")
            overlayObj := StateMap['currentOverlay']
            overlayInfo := IsObject(overlayObj) ? "Type: " . Type(overlayObj) : "Not an object"
            FileAppend(Format(
                "Timestamp: {} | HandleKey: Current overlay info: {}. Attempting GetCellBoundaries...",
                A_TickCount, overlayInfo) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            ; <<< CORE LOGGING START >>>
            FileAppend(Format("Timestamp: {} | HandleKey: IsObject(boundaries) result = {}. Boundaries=({},{},{},{})",
                A_TickCount, IsObject(boundaries), boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n",
            "antimouse_core.log")
            ; <<< CORE LOGGING END >>>
            if (IsObject(boundaries)) {
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Boundaries OK. Setting currentState=SUBGRID_ACTIVE (Before={})",
                    A_TickCount, currentState) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                StateMap['activeCellKey'] := cellKey
                stateTransitionTime := currentTime
                currentState := "SUBGRID_ACTIVE"
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Set currentState=SUBGRID_ACTIVE (After={}).", A_TickCount,
                    currentState) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>

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

                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Attempting MouseMove to ({}, {})...", A_TickCount,
                    boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2)) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
                Sleep(40)
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Attempting subGrid.Update({}, {}, {}, {})...",
                    A_TickCount, boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Attempting subGrid.Show()...", A_TickCount) "`n",
                "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                subGrid.Show()
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Called subGrid.Show(). Current state: {}. Attempting PostMessage redraw...",
                    A_TickCount, currentState) "`n", "antimouse_core.log")
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

                ; <<< ADD LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Clearing static firstKeyPressed (Before). Current value = '{}'",
                    A_TickCount, firstKeyPressed) "`n", "antimouse_core.log")
                if (showcaseDebug) FileAppend(Format(
                    "Timestamp: {} | HandleKey: Clearing static firstKeyPressed (Before) | firstKeyPressed={}",
                    currentTime, firstKeyPressed) "`n", A_ScriptDir "\debugRapidRefresh.log")
                ; <<< ADD LOGGING END >>>
                ; --- FIX: Clear static variable ---
                    firstKeyPressed := ""
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Cleared static firstKeyPressed. Checking cell memory...",
                    A_TickCount) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
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
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: END of proceedToSubgrid block.", A_TickCount) "`n",
                "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
            } else {
                ; Failed to get boundaries
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: FAILED to get boundaries for cellKey='{}'. Resetting static firstKeyPressed.",
                    A_TickCount, cellKey) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                ; --- FIX: Clear static variable ---
                firstKeyPressed := ""
                if (showcaseDebug && proceedToSubgrid && cellKey == "") {
                    ToolTip("Error: Proceeding to subgrid but cellKey is empty")
                }
            }
        } else {
            ; This case should ideally not be reached if logic is sound, but reset firstKey as safety
            ; --- FIX: Clear static variable ---
            firstKeyPressed := ""
            if (showcaseDebug && proceedToSubgrid && cellKey == "") {
                ToolTip("Error: Proceeding to subgrid but cellKey is empty")
            }
        }

        SetTimer(TrackCursor, 50)

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | TrackCursor: Reached end of try block BEFORE catch/finally.", currentTime) "`n",
        "antimouse_core.log")
        ; --- CORE LOGGING END ---
    } catch as e {
        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | TrackCursor: **** ERROR **** {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; Attempt to cleanup on error
        Cleanup()
    } finally {
        ; Ensure the lock is always released
        trackingInProgress := false
    }
}

HandleSubGridKey(subKey) {
    try {
        global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
            showcaseDebug, instaClickMode, g_ModifierState, highlight

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

            ; --- Ensure Highlight is shown on subgrid nav ---
            if (IsObject(highlight) && IsObject(StateMap['currentOverlay'])) {
                ; Get boundaries directly from currentOverlay instead of trying to use non-existent GetMainCellBoundaries
                mainCellBoundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
                if (IsObject(mainCellBoundaries)) {
                    FileAppend(Format("Timestamp: {} | HandleSubGridKey: Updating and Showing Highlight.", A_TickCount) "`n",
                    "antimouse_core.log")
                    highlight.Update(mainCellBoundaries.x, mainCellBoundaries.y, mainCellBoundaries.w,
                        mainCellBoundaries.h
                    )
                }
            } else {
                FileAppend(Format(
                    "Timestamp: {} | HandleSubGridKey: WARNING - Highlight or currentOverlay object invalid.",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            ; -----------------------------------------------

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
    } catch as hsg_e {
        FileAppend(Format("Timestamp: {} | **** ERROR inside HandleSubGridKey: {}", A_TickCount, hsg_e.Message) "`n",
        "antimouse_core.log")
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

        ; --- Ensure Highlight is shown on ultra-fast nav ---
        if (IsObject(highlight) && IsObject(StateMap['currentOverlay'])) {
            ; Get boundaries directly from currentOverlay
            mainCellBoundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
            if (IsObject(mainCellBoundaries)) {
                FileAppend(Format("Timestamp: {} | HandleUltraFastKey: Updating and Showing Highlight.", A_TickCount) "`n",
                "antimouse_core.log")
                highlight.Update(mainCellBoundaries.x, mainCellBoundaries.y, mainCellBoundaries.w,
                    mainCellBoundaries.h
                )
            }
        } else {
            FileAppend(Format(
                "Timestamp: {} | HandleUltraFastKey: WARNING - Highlight or currentOverlay object invalid.",
                A_TickCount) "`n", "antimouse_core.log")
        }
        ; -----------------------------------------------

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
    FileAppend(Format("Timestamp: {} | StartNewSelection START | key={}", A_TickCount, key) "`n", "antimouse_core.log") ; <<< CORE LOGGING
    global currentState, subGrid, highlight, StateMap, enableUltraFast, showcaseDebug, g_firstKeyPressed

    ; Define currentTime at the beginning
    currentTime := A_TickCount

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | StartNewSelection: key='{}', currentState='{}', g_firstKeyPressed='{}'",
        A_TickCount, key, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        ; Get physical key state - ONLY if key is not empty
        keyPhysicallyDown := (key != "") ? GetKeyState(key, "P") : "N/A"
        rowKeyPhysicallyDown := StateMap['activeRowKey'] != "" ? GetKeyState(StateMap['activeRowKey'], "P") : false
        logMsg := Format(
            "Timestamp: {} | StartNewSelection START | key={} | PhysicallyDown={} | currentState={} | firstKey={} | activeRowKey={} | activeRowKeyPhysicallyDown={} | inUltraFastMode={}",
            currentTime, key, keyPhysicallyDown, currentState, StateMap['firstKey'], StateMap[
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

    ; If in Ultra-Fast mode and this is the held row key, ignore - ONLY if key is not empty
    if (enableUltraFast && StateMap['inUltraFastMode'] && key != "" && key == StateMap['activeRowKey']) {
        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format("Timestamp: {} | StartNewSelection: Ignoring held row key press | key={}",
            currentTime, key) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
            SetTimer(TrackCursor, 50) ; Re-enable tracker
        return
    }

    ; If not in UltraFast mode but this is the active row key being held, don't reset - ONLY if key is not empty
    if (enableUltraFast && key != "" && key == StateMap['activeRowKey'] && GetKeyState(key, "P")) {
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

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format("Timestamp: {} | DIAGNOSTIC | StartNewSelection: Resetting g_firstKeyPressed from '{}' to ''",
        A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; Explicitly reset g_firstKeyPressed to ensure new key selection works
    g_firstKeyPressed := ""

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
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | StartNewSelection: Transitioning from SUBGRID_ACTIVE to GRID_VISIBLE",
                A_TickCount) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    currentState := "GRID_VISIBLE"

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | StartNewSelection: Set currentState=GRID_VISIBLE (After) | currentState={}", currentTime,
        currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Force a small delay to ensure state transitions properly
        Sleep(10)

    ; Call HandleKey to process the key press - ONLY if key is not empty
    if (key != "") {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | StartNewSelection: Calling HandleKey('{}') with clean state",
            A_TickCount, key) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        HandleKey(key)
    } else {
        ; If key was empty (called from TrackCursor), just ensure state is GRID_VISIBLE and restart tracker
        currentState := "GRID_VISIBLE"
        SetTimer(TrackCursor, 50)
    }

    ; TrackCursor re-enabled in HandleKey OR above
}

; --- Cursor Tracking ---

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
        global currentState, highlight, subGrid, StateMap, showcaseDebug, enableUltraFast, rowKeyHoldThreshold

        ; Get current mouse position
        MouseGetPos(&x, &y)

        ; --- CORE LOGGING START ---
        ; currentTime := A_TickCount ; Defined earlier if needed
        ; activeCellKey := StateMap.Has('activeCellKey') ? StateMap['activeCellKey'] : ""
        ; activeRowKey := StateMap.Has('activeRowKey') ? StateMap['activeRowKey'] : ""
        ; inUltraFastMode := StateMap.Has('inUltraFastMode') ? StateMap['inUltraFastMode'] : false
        ; FileAppend(Format("Timestamp: {} | TrackCursor START | State={} | Mouse=({},{}) | ActiveCell={} | ActiveRowKey={} | UltraFastMode={}", currentTime, currentState, x, y, activeCellKey, activeRowKey, inUltraFastMode) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---

        ; Only track if grid or subgrid is potentially active
        if (currentState != "GRID_VISIBLE" && currentState != "SUBGRID_ACTIVE") {
            trackingInProgress := false
            return
        }

        activeCellBoundaries := Map()
        cursorInsideCell := false

        ; Get boundaries if subgrid is active
        if (currentState == "SUBGRID_ACTIVE" && StateMap.Has('activeCellKey') && StateMap['activeCellKey'] != "" &&
        IsObject(StateMap['currentOverlay'])) {
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
            if (IsObject(boundaries)) {
                activeCellBoundaries := boundaries
                cursorInsideCell := (x >= boundaries.x && x < boundaries.x + boundaries.w && y >= boundaries.y && y <
                    boundaries.y + boundaries.h)
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | TrackCursor: Subgrid Active. CellBounds=({},{},{},{}) | Inside={}",
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

        ; --- Ultra-Fast Mode Check (Only when SUBGRID_ACTIVE) ---
        rowKeyIsHeld := false
        rowKeyHeldDuration := 0
        if (currentState == "SUBGRID_ACTIVE" && enableUltraFast && StateMap['activeRowKey'] != "") {
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
        if (currentState == "SUBGRID_ACTIVE") {
            if (!cursorInsideCell) {
                ; --- CORE LOGGING START ---
                FileAppend(Format(
                    "Timestamp: {} | TrackCursor: Cursor left cell boundaries. Calling StartNewSelection().",
                    A_TickCount) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                ; Mouse moved outside the active subgrid cell's boundaries, reset to main grid selection
                StartNewSelection("") ; Pass empty key as it's not a key press trigger
            }
        } else if (currentState == "GRID_VISIBLE") {
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

    } catch as e {
        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | TrackCursor: **** ERROR **** {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; Attempt to cleanup on error
        Cleanup()
    } finally {
        ; Ensure the lock is always released
        trackingInProgress := false
    }
}

; --- Key Processing Wrapper ---

; Central function called by hotkeys to route key presses to the appropriate handler based on the current state.
ProcessKeyPress(key) {
    global StateMap
    FileAppend(Format("Timestamp: {} | ProcessKeyPress START | key={} | currentState={}", A_TickCount, key,
        currentState) "`n", "antimouse_core.log") ; <<< CORE LOGGING
    global currentState, subGridKeys, instaClickMode,
        g_ModifierState, StateMap, enableUltraFast, ultraFastSubGridKeys, showcaseDebug, g_firstKeyPressed

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | ProcessKeyPress | key='{}' | currentState='{}' | g_firstKeyPressed='{}' | activeCellKey='{}'",
        A_TickCount, key, currentState, g_firstKeyPressed, StateMap['activeCellKey']) "`n", "antimouse_core.log")

    ; Check if currentOverlay exists and is valid
    if (IsObject(StateMap['currentOverlay'])) {
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | currentOverlay is valid object", A_TickCount) "`n",
        "antimouse_core.log")
    } else {
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | ERROR: currentOverlay is NOT a valid object", A_TickCount) "`n",
        "antimouse_core.log")
    }
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

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
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | Calling HandleKey with key='{}'", A_TickCount, key) "`n",
        "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        HandleKey(key) ; Process as first or second grid key
    } else if (currentState == "SUBGRID_ACTIVE") {
        ; Check if key is the active row key that we're already tracking (for ultra-fast)
        if (enableUltraFast && key == StateMap['activeRowKey']) {
            ; We're already tracking this key being held, don't process it again
            ; This prevents auto-repeat from disrupting the hold tracking
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) {
                keyPhysicallyDown := GetKeyState(key, "P")
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignoring repeat of active row key | key={} | PhysicallyDown={}",
                    A_TickCount, key, keyPhysicallyDown ? "DOWN" : "UP"
                )
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; <<< ADD LOGGING END >>>
            return
        }

        ; Check if we're in ultra-fast mode and key is valid for it
        if (enableUltraFast && StateMap['inUltraFastMode']) {
            for i, ultraKey in ultraFastSubGridKeys {
                if (key == ultraKey) {
                    HandleUltraFastKey(key)
                    return ; Handled by ultra-fast logic
                }
            }
            ; If it wasn't an ultra-fast key, but we are in ultra-fast mode, ignore the key.
            ; (This prevents standard subgrid keys from working during ultra-fast mode).
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) {
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignored key '{}' while in UltraFastMode (expected ultra-key or row-release).",
                    A_TickCount, key)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; <<< ADD LOGGING END >>>
            return
        }

        ; --- If NOT in ultra-fast mode, check for standard subgrid keys ---
        isStandardSubGridKey := false
        for i, subKey in subGridKeys {
            if (key == subKey) {
                isStandardSubGridKey := true
                break
            }
        }

        if (isStandardSubGridKey) {
            HandleSubGridKey(key) ; Process standard subgrid selection
        } else {
            ; --- FIX: Check if key is a valid grid key (column or row key) ---
            isGridKey := false

            ; Check column keys
            for i, colKey in StateMap['activeColKeys'] {
                if (key == colKey) {
                    isGridKey := true
                    break
                }
            }

            ; Check row keys
            if (!isGridKey) {
                for i, rowKey in StateMap['activeRowKeys'] {
                    if (key == rowKey) {
                        isGridKey := true
                        break
                    }
                }
            }

            ; If it's a grid key, call StartNewSelection to go back to grid selection mode
            if (isGridKey) {
                ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | DIAGNOSTIC | ProcessKeyPress: Detected grid key '{}' while in SUBGRID_ACTIVE. Calling StartNewSelection.",
                    A_TickCount, key) "`n", "antimouse_core.log")
                ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

                StartNewSelection(key)
                return
            }

            ; If it's neither a subgrid key nor a grid key, ignore it
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) {
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignored key '{}' while in SUBGRID_ACTIVE (standard).",
                    A_TickCount, key)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; <<< ADD LOGGING END >>>
            ; --- ADD EXPLICIT RETURN ---
            return ; Explicitly stop processing for this invalid key in this state.
        }
    } else {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | WARNING: Key press '{}' received in invalid state: '{}'",
            A_TickCount, key, currentState) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>
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
