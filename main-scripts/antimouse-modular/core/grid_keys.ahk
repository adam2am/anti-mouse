; ==============================================================================
; core/grid_keys.ahk - Grid Key Handling Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug, highlight, subGrid, stateTransitionDelay, stateTransitionTime
;global g_firstKeyPressed ; Explicitly track first key globally <<< Task 6.2: REMOVED
global enableVerboseLogging ; Added

; S1.6.3 FIX - Add function to find the nearest cell matching a given row or column key
FindNearestCell(currentCellKey, targetKey, isColKey) {
    global highlight, StateMap

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

; Handle a key press in GRID_VISIBLE state by either storing first key or completing cell selection
HandleKey(key, bypassStateCheck := false) {
    global currentState, highlight, subGrid, cellMemory, StateMap, showcaseDebug, enableUltraFast
    global enableVerboseLogging ; Added

    ; S1.2: Add lastKeypressTime for hover activation debounce
    StateMap['lastKeypressTime'] := A_TickCount

    ; <<< TASK 2.1 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.1 | HandleKey START | key={}, bypassStateCheck={}", A_TickCount, key,
            bypassStateCheck), "antimouse_core.log")
    }
    ; <<< TASK 2.1 CORE LOGGING END >>>

    initialFirstKey := StateMap['firstKey'] ; Store initial value for logging

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey | key='{}' | currentState='{}' | firstKey='{}'",
            A_TickCount, key, currentState, StateMap['firstKey']), "antimouse_core.log")
    }
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    ; Debounce check - ignore key presses too close to state transition
    ; timeSinceTransition := A_TickCount - stateTransitionTime
    ; if (timeSinceTransition < stateTransitionDelay) {
    ;     if (enableVerboseLogging) { ; <<< WRAPPED
    ;         ; FIX: Use safe logging
    ;         LogToFile(Format("Timestamp: {} | Task: 2.1 | HandleKey: Debounced ({}ms < {}ms). Exiting.", A_TickCount,
    ;             timeSinceTransition, stateTransitionDelay), "antimouse_core.log")
    ;     }
    ;     return ; Ignore the key press
    ; }

    ; State check (unless bypassed, e.g., by StartNewSelection)
    if (!bypassStateCheck && (currentState != State_GRID_VISIBLE || !IsObject(StateMap['currentOverlay']))) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Invalid state/overlay. currentState='{}', IsObject(currentOverlay)={}. Exiting.",
                A_TickCount, currentState, IsObject(StateMap['currentOverlay'])), "antimouse_core.log")
        }
        return
    }

    ; Determine if the key is a column or row key
    isColKey := false
    isRowKey := false
    colIndex := 0
    rowIndex := 0

    loop StateMap['activeColKeys'].Length {
        if (key == StateMap['activeColKeys'][A_Index]) {
            isColKey := true
            colIndex := A_Index
            break
        }
    }
    if (!isColKey) {
        loop StateMap['activeRowKeys'].Length {
            if (key == StateMap['activeRowKeys'][A_Index]) {
                isRowKey := true
                rowIndex := A_Index
                break
            }
        }
    }

    ; Check if the key is valid for the current grid
    invalidKey := !isColKey && !isRowKey
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Key type check for key='{}'. isColKey={}, isRowKey={}. InvalidCheck={}",
            A_TickCount, key, isColKey, isRowKey, invalidKey), "antimouse_core.log")
    }
    if (invalidKey) {
        if (showcaseDebug) {
            ToolTip("'" . key . "' is not a valid key for this layout.")
            SetTimer(() => ToolTip(), -1000) ; Clear tooltip after 1 second
        }
        return
    }

    ; Stop cursor tracking temporarily during key processing
    SetTimer(TrackCursor, 0)

    ; S1.6.3 FIX - Nearest Cell Navigation
    ; If user is already in a cell and presses a single key, navigate to nearest matching cell
    if (currentState == State_GRID_VISIBLE && StateMap['activeCellKey'] != "") {
        ; User is in State_GRID_VISIBLE but already has a selected cell (hovering)
        ; Try to find nearest cell matching the pressed key

        LogToFile(Format("S1.6.3 FIX | HandleKey | Nearest cell navigation triggered | key='{}'",
            key), "antimouse_fix.log")

        ; Find the nearest matching cell
        targetCellKey := FindNearestCell(StateMap['activeCellKey'], key, isColKey)

        if (targetCellKey != "") {
            ; Valid target cell found - navigate to it
            LogToFile(Format("S1.6.3 FIX | HandleKey | Navigating from '{}' to '{}'",
                StateMap['activeCellKey'], targetCellKey), "antimouse_fix.log")

            ; Get boundaries for the target cell
            if (IsObject(StateMap['currentOverlay'])) {
                try {
                    boundaries := StateMap['currentOverlay'].GetCellBoundaries(targetCellKey)

                    if (IsObject(boundaries)) {
                        ; Update active cell key
                        StateMap['activeCellKey'] := targetCellKey

                        ; Update highlight
                        if (IsObject(highlight)) {
                            try {
                                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                                LogToFile("S1.6.3 FIX | HandleKey | Successfully updated highlight",
                                    "antimouse_fix.log")

                                ; Ensure highlight is visible
                                try {
                                    if (IsObject(highlight) && highlight.HasMethod("ForceShow")) {
                                        highlight.ForceShow()
                                    } else {
                                        highlight.gui.Show("NA")
                                    }
                                    LogToFile("S1.6.3 FIX | HandleKey | Successfully showed highlight",
                                        "antimouse_fix.log")
                                } catch as e {
                                    LogToFile(Format("S1.6.3 FIX | HandleKey | Error showing highlight: {}",
                                        e.Message), "antimouse_fix.log")
                                }
                            } catch as e {
                                LogToFile(Format("S1.6.3 FIX | HandleKey | Error updating highlight: {}",
                                    e.Message), "antimouse_fix.log")
                            }
                        }

                        ; Move cursor to center of target cell
                        try {
                            centerX := boundaries.x + boundaries.w / 2
                            centerY := boundaries.y + boundaries.h / 2
                            MouseMove(centerX, centerY, 0)
                            LogToFile(Format("S1.6.3 FIX | HandleKey | Moved cursor to ({}, {})",
                                centerX, centerY), "antimouse_fix.log")
                        } catch as e {
                            LogToFile(Format("S1.6.3 FIX | HandleKey | Error moving mouse: {}",
                                e.Message), "antimouse_fix.log")
                        }

                        ; Restart cursor tracking
                        SetTimer(TrackCursor, 50)

                        ; Early return - we've handled the key
                        return
                    } else {
                        LogToFile("S1.6.3 FIX | HandleKey | Failed to get boundaries for target cell",
                            "antimouse_fix.log")
                    }
                } catch as e {
                    LogToFile(Format("S1.6.3 FIX | HandleKey | Error getting cell boundaries: {}",
                        e.Message), "antimouse_fix.log")
                }
            }
        } else {
            LogToFile("S1.6.3 FIX | HandleKey | No valid target cell found, continuing with standard key handling",
                "antimouse_fix.log")
        }
    }

    ; --- Process First or Second Key ---
    firstKeyBefore := StateMap['firstKey'] ; Store for logging
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Before firstKey check. StateMap['firstKey']='{}'",
            A_TickCount, StateMap['firstKey']), "antimouse_core.log")
    }

    if (StateMap['firstKey'] == "") {
        ; This is the first key press
        HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex)
    } else {
        ; This is the second key press
        HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex)
    }

    ; <<< TASK 2.1 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | HandleKey END | key={} | Final State='{}' | FirstKey was '{}' -> now '{}'",
            A_TickCount, key, currentState, firstKeyBefore, StateMap['firstKey']), "antimouse_core.log")
    }
    ; <<< TASK 2.1 CORE LOGGING END >>>
}

; Handle the first key press of a cell selection (column or row)
HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global StateMap, currentState, showcaseDebug, highlight
    global enableVerboseLogging ; Added

    ; S1.5.1 DIAGNOSTIC: Enhanced first key debugging
    LogToFile(Format(
        "S1.5.1 DIAGNOSTIC | HandleFirstKey ENTRY | key='{}' | isColKey={}, isRowKey={} | currentState='{}'",
        key, isColKey, isRowKey, currentState), "antimouse_diagnostic.log")

    ; <<< TASK 2.2 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.2 | HandleFirstKey START | key={}, isCol={}, isRow={}, currentState={}",
            A_TickCount,
            key, isColKey, isRowKey, currentState), "antimouse_core.log")
    }
    ; <<< TASK 2.2 CORE LOGGING END >>>

    ; --- 5.13.1: VISUAL DEBUGGING START ---
    ; Display prominent tooltip showing we're in HandleFirstKey
    ToolTip("VISUAL DEBUG: HandleFirstKey for key '" key "' (" (isColKey ? "Column" : isRowKey ? "Row" : "Unknown") " key)",
    10, 10)
    ; --- 5.13.1: VISUAL DEBUGGING END ---

    ; --- NEW: Check if overlay is visible ---
    if (IsObject(StateMap['currentOverlay'])) {
        if (enableVerboseLogging) {
            ; FIX: Use safe logging
            LogToFile(Format("Timestamp: {} | Task: DEBUG | HandleFirstKey: Checking overlay visibility for key '{}'",
                A_TickCount, key), "antimouse_core.log")
        }

        ; S1.5.1 DIAGNOSTIC: Check overlay visibility
        LogToFile(Format(
            "S1.5.1 DIAGNOSTIC | HandleFirstKey - checking overlay visibility | IsObject(currentOverlay)={}",
            IsObject(StateMap['currentOverlay'])), "antimouse_diagnostic.log")

        ; S1.1: Add try/catch for overlay.Show()
        try {
            StateMap['currentOverlay'].Show()
            ; S1.5.1 DIAGNOSTIC: Overlay show success
            LogToFile("S1.5.1 DIAGNOSTIC | HandleFirstKey - overlay.Show() success", "antimouse_diagnostic.log")

            ; --- 5.13.1: VISUAL DEBUGGING ---
            LogToFile("5.13.1 DEBUG | HandleFirstKey - Successfully called overlay.Show()", "antimouse_fix.log")
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR showing overlay: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
            ; S1.5.1 DIAGNOSTIC: Overlay show error
            LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleFirstKey - ERROR showing overlay: {}", e.Message),
            "antimouse_diagnostic.log")

            ; --- 5.13.1: VISUAL DEBUGGING ---
            LogToFile(Format("5.13.1 DEBUG | HandleFirstKey - ERROR showing overlay: {}", e.Message),
            "antimouse_fix.log")
            ToolTip("ERROR: Failed to show overlay: " e.Message, 10, 40)
        }
    } else {
        ; S1.5.1 DIAGNOSTIC: Missing overlay
        LogToFile("S1.5.1 DIAGNOSTIC | HandleFirstKey - ERROR: currentOverlay is not an object",
            "antimouse_diagnostic.log")

        ; --- 5.13.1: VISUAL DEBUGGING ---
        LogToFile("5.13.1 DEBUG | HandleFirstKey - ERROR: currentOverlay is not an object", "antimouse_fix.log")
        ToolTip("ERROR: currentOverlay is not a valid object", 10, 40)
    }
    ; --- END NEW ---

    currentTime := A_TickCount

    ; Store the first key pressed
    StateMap['firstKey'] := key
    ; S1.5.1 DIAGNOSTIC: First key stored
    LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleFirstKey - Stored firstKey='{}'", key),
    "antimouse_diagnostic.log")

    targetCellKey := "" ; Renamed from cellKey for clarity
    hoveredCellKey := ""
    targetCellX := 0
    targetCellY := 0
    targetCellW := 0
    targetCellH := 0
    tooltipText := ""

    ; --- Task 6.1: Get Context from Hovered Cell --- START
    MouseGetPos(&currentX, &currentY)

    ; --- 5.13.1: VISUAL DEBUGGING ---
    LogToFile(Format("5.13.1 DEBUG | HandleFirstKey - Current mouse position: x={}, y={}", currentX, currentY),
    "antimouse_fix.log")

    try {
        hoveredCellKey := GetCellAtPosition(currentX, currentY) ; Assumes GetCellAtPosition is available

        ; --- 5.13.1: VISUAL DEBUGGING ---
        LogToFile(Format("5.13.1 DEBUG | HandleFirstKey - GetCellAtPosition returned: '{}'", hoveredCellKey),
        "antimouse_fix.log")
    } catch as e {
        ; --- 5.13.1: VISUAL DEBUGGING ---
        LogToFile(Format("5.13.1 DEBUG | HandleFirstKey - ERROR in GetCellAtPosition: {}", e.Message),
        "antimouse_fix.log")
        hoveredCellKey := ""
    }

    if (hoveredCellKey != "" && StrLen(hoveredCellKey) == 2) {
        ; Context Found: Calculate target based on hovered cell
        hoveredCol := SubStr(hoveredCellKey, 1, 1)
        hoveredRow := SubStr(hoveredCellKey, 2, 1)

        if (isColKey) {
            targetCellKey := key . hoveredRow ; Use pressed Col + hovered Row
            StateMap['currentColIndex'] := colIndex ; Still update state
            tooltipText := "First key: " key " (Col). Hovered: " hoveredCellKey ". Target: " targetCellKey ". Select row."
            LogToFile(Format("Task 6.1 | HandleFirstKey: Context found '{}'. Pressed Col '{}'. Target: '{}'",
                hoveredCellKey, key, targetCellKey), "antimouse_core.log")
        } else { ; isRowKey
            targetCellKey := hoveredCol . key ; Use hovered Col + pressed Row
            StateMap['currentRowIndex'] := rowIndex ; Still update state
            StateMap['lastSelectedRowIndex'] := rowIndex ; Remember last row
            tooltipText := "First key: " key " (Row). Hovered: " hoveredCellKey ". Target: " targetCellKey ". Select column."
            LogToFile(Format("Task 6.1 | HandleFirstKey: Context found '{}'. Pressed Row '{}'. Target: '{}'",
                hoveredCellKey, key, targetCellKey), "antimouse_core.log")
        }
    } else {
        ; Context Not Found (Cursor outside grid or GetCell failed): Fallback to original guess logic
        LogToFile(Format("Task 6.1 | HandleFirstKey: Context NOT found (hovered='{}'). Falling back to guess.",
            hoveredCellKey), "antimouse_core.log")
        if (isColKey) {
            ; First key is COLUMN
            StateMap['currentColIndex'] := colIndex
            tooltipText := "First key: " key " (Col). Select row."

            ; Highlight the cells for this column
            if (IsObject(StateMap['currentOverlay'])) {
                ; S1.1: Add try/catch for overlay.HighlightCol
                try {
                    StateMap['currentOverlay'].HighlightCol(key, colIndex)
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR highlighting column: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }
            }
        } else { ; isRowKey
            ; First key is ROW
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex ; Remember last row

            tooltipText := "First key: " key " (Row). Select column."

            ; Highlight the cells for this row
            if (IsObject(StateMap['currentOverlay'])) {
                ; S1.1: Add try/catch for overlay.HighlightRow
                try {
                    StateMap['currentOverlay'].HighlightRow(key, rowIndex)
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR highlighting row: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }
            }
        }
    }
    ; --- Task 6.1: Get Context from Hovered Cell --- END

    if (showcaseDebug) {
        if (hoveredCellKey != "") {
            tooltipText .= " (Context: " hoveredCellKey ")"
        }
        ToolTip(tooltipText)
        SetTimer(() => ToolTip(), -1000) ; Clear tooltip after 1 second
    }

    ; Restart cursor tracking after key is handled
    SetTimer(TrackCursor, 50)

    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.2 | HandleFirstKey END | key={}, targetCellKey={}, TimeElapsed={}ms",
            A_TickCount, key, targetCellKey, A_TickCount - currentTime), "antimouse_core.log")
    }

    ; S1.5.1 DIAGNOSTIC: Exit logging
    LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleFirstKey EXIT | firstKey='{}' | targetCellKey='{}' | TimeElapsed={}ms",
        key, targetCellKey, A_TickCount - currentTime), "antimouse_diagnostic.log")

    ; --- 5.13.1: VISUAL DEBUGGING END ---
    LogToFile(Format("5.13.1 DEBUG | HandleFirstKey EXIT for key '{}'", key), "antimouse_fix.log")
}

; Handle the second key press, completing cell selection and transitioning to appropriate state
HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global StateMap, currentState, highlight, subGrid, showcaseDebug, enableUltraFast,
        rowKeyHoldThreshold
    global enableVerboseLogging ; Added

    ; --- 5.13.1: VISUAL DEBUGGING START ---
    ToolTip("VISUAL DEBUG: HandleSecondKey for key '" key "' (" (isColKey ? "Column" : isRowKey ? "Row" : "Unknown") " key)",
    10, 10)
    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey ENTRY | key='{}' | isColKey={}, isRowKey={} | firstKey='{}'",
        key, isColKey, isRowKey, StateMap['firstKey']), "antimouse_fix.log")
    ; --- 5.13.1: VISUAL DEBUGGING END ---

    ; S1.5.1 DIAGNOSTIC: Enhanced second key debugging
    LogToFile(Format(
        "S1.5.1 DIAGNOSTIC | HandleSecondKey ENTRY | key='{}' | isColKey={}, isRowKey={} | firstKey='{}' | currentState='{}' | highlight={}, subGrid={}",
        key, isColKey, isRowKey, StateMap['firstKey'], currentState, IsObject(highlight), IsObject(subGrid)),
    "antimouse_diagnostic.log")

    ; --- First Key Analysis Logic ---
    firstKey := StateMap['firstKey']
    firstKeyIsCol := false
    firstKeyIsRow := false
    firstKeyColIndex := 0
    firstKeyRowIndex := 0

    ; Determine if the first key was a column or row key
    if (firstKey != "") {
        loop StateMap['activeColKeys'].Length {
            if (firstKey == StateMap['activeColKeys'][A_Index]) {
                firstKeyIsCol := true
                firstKeyColIndex := A_Index
                break
            }
        }
        if (!firstKeyIsCol) {
            loop StateMap['activeRowKeys'].Length {
                if (firstKey == StateMap['activeRowKeys'][A_Index]) {
                    firstKeyIsRow := true
                    firstKeyRowIndex := A_Index
                    break
                }
            }
        }

        ; S1.5.1 DIAGNOSTIC: First key type check
        LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleSecondKey - firstKey '{}' is a {}", firstKey,
            firstKeyIsCol ? "COLUMN key" : firstKeyIsRow ? "ROW key" : "UNKNOWN key"), "antimouse_diagnostic.log")
        LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleSecondKey - firstKey '{}' type: isColKey={}, isRowKey={}",
            firstKey, firstKeyIsCol, firstKeyIsRow), "antimouse_diagnostic.log")
    } else {
        if (enableVerboseLogging) {
            LogToFile(Format("Timestamp: {} | HandleSecondKey: WARNING - firstKey is empty!", A_TickCount) "`n",
            "antimouse_core.log")
        }
        ; S1.5.1 DIAGNOSTIC: Empty first key
        LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleSecondKey - ERROR: firstKey is empty!"),
        "antimouse_diagnostic.log")

        ; --- 5.13.1: VISUAL DEBUGGING ---
        LogToFile("5.13.1 DEBUG | HandleSecondKey - ERROR: firstKey is empty!", "antimouse_fix.log")
        ToolTip("ERROR: firstKey is empty in HandleSecondKey!", 10, 40)

        return ; Cannot proceed without a valid first key
    }

    ; --- Check for Valid Sequence ---
    ; Only proceed if one key is a column and one key is a row
    invalidSequence := false
    targetCellKey := ""

    if (firstKeyIsCol && isRowKey) {
        ; Valid sequence: First Col, Second Row (e.g., Q->J = QJ)
        colKey := firstKey
        rowKey := key
        colIdx := firstKeyColIndex
        rowIdx := rowIndex
    } else if (firstKeyIsRow && isColKey) {
        ; Valid sequence: First Row, Second Col (e.g., J->Q = QJ)
        colKey := key
        rowKey := firstKey
        colIdx := colIndex
        rowIdx := firstKeyRowIndex
    } else {
        ; Invalid sequence: Both are column keys (e.g., Q->W) or both are row keys (e.g., J->K)
        invalidSequence := true
        ; S1.5.1 DIAGNOSTIC: Invalid sequence
        LogToFile(Format(
            "S1.5.1 DIAGNOSTIC | HandleSecondKey - INVALID SEQUENCE | firstKey='{}' ({}), secondKey='{}' ({})",
            firstKey, firstKeyIsCol ? "Col" : "Row", key, isColKey ? "Col" : "Row"), "antimouse_diagnostic.log")

        ; --- 5.13.1: VISUAL DEBUGGING ---
        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - INVALID SEQUENCE | firstKey='{}' ({}), secondKey='{}' ({})",
            firstKey, firstKeyIsCol ? "Col" : "Row", key, isColKey ? "Col" : "Row"), "antimouse_fix.log")
        ToolTip("INVALID SEQUENCE: Both keys are " (isColKey ? "column" : "row") " keys", 10, 40)
    }

    if (invalidSequence) {
        if (enableVerboseLogging) {
            LogToFile(Format(
                "Timestamp: {} | HandleSecondKey: Invalid sequence: Both keys are {} keys ('{}'->'{}'). Starting new selection.",
                A_TickCount, isColKey ? "column" : "row", firstKey, key) "`n", "antimouse_core.log")
        }

        ; Reset first key and start a new selection with the current key
        StateMap['firstKey'] := ""
        try {
            StartNewSelection(key)
        } catch as e {
            ; S1.5.1 DIAGNOSTIC: StartNewSelection error
            LogToFile(Format("S1.5.1 DIAGNOSTIC | HandleSecondKey - ERROR in StartNewSelection: {}", e.Message),
            "antimouse_diagnostic.log")

            ; --- 5.13.1: VISUAL DEBUGGING ---
            LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR in StartNewSelection: {}", e.Message),
            "antimouse_fix.log")
            ToolTip("ERROR in StartNewSelection: " e.Message, 10, 70)
        }
        return
    }

    ; --- Valid Sequence: Construct Cell Key and Set State ---
    targetCellKey := colKey . rowKey

    ; --- 5.13.1: VISUAL DEBUGGING ---
    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - VALID SEQUENCE | Target cell: '{}'", targetCellKey),
    "antimouse_fix.log")
    ToolTip("VALID SEQUENCE: Target cell is " targetCellKey, 10, 40)

    ; Determine if we should proceed to subgrid stage
    proceedToSubgrid := true

    if (proceedToSubgrid) {
        ; Store selected indices and keys for hover context use
        StateMap['activeCellKey'] := targetCellKey
        StateMap['lastSelectedColIndex'] := colIdx
        StateMap['lastSelectedRowIndex'] := rowIdx

        ; Get the visual boundaries for the selected cell
        try {
            if (IsObject(StateMap['currentOverlay'])) {
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(targetCellKey)

                ; --- 5.13.1: VISUAL DEBUGGING ---
                if (IsObject(boundaries)) {
                    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - Got boundaries for '{}': x={}, y={}, w={}, h={}",
                        targetCellKey, boundaries.x, boundaries.y, boundaries.w, boundaries.h), "antimouse_fix.log")
                } else {
                    LogToFile("5.13.1 DEBUG | HandleSecondKey - FAILED to get boundaries for '" targetCellKey "'",
                        "antimouse_fix.log")
                    ToolTip("ERROR: Failed to get boundaries for cell " targetCellKey, 10, 70)
                }

                if (IsObject(boundaries)) {
                    ; Update highlight position
                    if (IsObject(highlight)) {
                        try {
                            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                            LogToFile(Format(
                                "Timestamp: {} | HandleSecondKey: Updated highlight to cell '{}'",
                                A_TickCount, targetCellKey) "`n", "antimouse_core.log")

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            LogToFile("5.13.1 DEBUG | HandleSecondKey - Successfully called highlight.Update()",
                                "antimouse_fix.log")

                            ; Force visibility check
                            try {
                                if (IsObject(highlight) && highlight.HasMethod("ForceShow")) {
                                    highlight.ForceShow()
                                } else {
                                    highlight.gui.Show()
                                }
                            } catch as e {
                                ; Try a fallback showing method if ForceShow doesn't exist
                                try {
                                    highlight.gui.Show()
                                } catch as innerE {
                                    LogToFile(Format(
                                        "5.13.1 DEBUG | HandleSecondKey - ERROR forcing highlight show: {}", innerE.Message
                                    ),
                                    "antimouse_fix.log")
                                }
                            }
                        } catch as e {
                            if (enableVerboseLogging) {
                                LogToFile(Format("Timestamp: {} | HandleSecondKey: ERROR updating highlight: {}",
                                    A_TickCount, e.Message) "`n", "antimouse_core.log")
                            }

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR updating highlight: {}", e.Message
                            ),
                            "antimouse_fix.log")
                            ToolTip("ERROR: Failed to update highlight: " e.Message, 10, 100)
                        }
                    } else {
                        if (enableVerboseLogging) {
                            LogToFile(Format("Timestamp: {} | HandleSecondKey: highlight is not a valid object",
                                A_TickCount) "`n", "antimouse_core.log")
                        }

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile("5.13.1 DEBUG | HandleSecondKey - ERROR: highlight is not a valid object",
                            "antimouse_fix.log")
                        ToolTip("ERROR: highlight is not a valid object", 10, 130)
                    }

                    ; Update subgrid position
                    if (IsObject(subGrid)) {
                        try {
                            subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                            LogToFile(Format(
                                "Timestamp: {} | HandleSecondKey: Updated subGrid to cell '{}'", A_TickCount,
                                targetCellKey) "`n", "antimouse_core.log")

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            LogToFile("5.13.1 DEBUG | HandleSecondKey - Successfully called subGrid.Update()",
                                "antimouse_fix.log")

                            ; Force visibility check
                            try {
                                subGrid.ForceShow() ; Assuming this method exists or add it to the class
                            } catch as e {
                                ; Try a fallback showing method if ForceShow doesn't exist
                                try {
                                    subGrid.gui.Show()
                                } catch as innerE {
                                    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR forcing subGrid show: {}",
                                        innerE.Message),
                                    "antimouse_fix.log")
                                }
                            }
                        } catch as e {
                            if (enableVerboseLogging) {
                                LogToFile(Format(
                                    "Timestamp: {} | HandleSecondKey: ERROR updating subGrid: {}", A_TickCount,
                                    e.Message) "`n", "antimouse_core.log")
                            }

                            ; --- 5.13.1: VISUAL DEBUGGING ---
                            LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR updating subGrid: {}", e.Message),
                            "antimouse_fix.log")
                            ToolTip("ERROR: Failed to update subGrid: " e.Message, 10, 160)
                        }
                    } else {
                        if (enableVerboseLogging) {
                            LogToFile(Format("Timestamp: {} | HandleSecondKey: subGrid is not a valid object",
                                A_TickCount) "`n", "antimouse_core.log")
                        }

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile("5.13.1 DEBUG | HandleSecondKey - ERROR: subGrid is not a valid object",
                            "antimouse_fix.log")
                        ToolTip("ERROR: subGrid is not a valid object", 10, 190)
                    }

                    ; --- 5.13.1: VISUAL DEBUGGING - Check mouse position before move ---
                    MouseGetPos(&beforeX, &beforeY)
                    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - Before mouse move: x={}, y={}", beforeX, beforeY
                    ),
                    "antimouse_fix.log")

                    ; Move the mouse to the center of the selected cell
                    try {
                        centerX := boundaries.x + (boundaries.w // 2)
                        centerY := boundaries.y + (boundaries.h // 2)
                        MouseMove(centerX, centerY, 0)

                        ; --- 5.13.1: VISUAL DEBUGGING - Check mouse position after move ---
                        MouseGetPos(&afterX, &afterY)
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - MOUSEMOVE to: x={}, y={}", centerX, centerY),
                        "antimouse_fix.log")
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - After mouse move: x={}, y={}", afterX,
                            afterY),
                        "antimouse_fix.log")

                        if (afterX != centerX || afterY != centerY) {
                            LogToFile(Format(
                                "5.13.1 DEBUG | HandleSecondKey - WARNING: Mouse position mismatch after move!"),
                            "antimouse_fix.log")
                            ToolTip("WARNING: Mouse move failed - position mismatch", 10, 220)
                        }

                        if (enableVerboseLogging) {
                            LogToFile(Format(
                                "Timestamp: {} | HandleSecondKey: Moved mouse to center of cell '{}': {}, {}",
                                A_TickCount, targetCellKey, centerX, centerY) "`n", "antimouse_core.log")
                        }
                    } catch as e {
                        if (enableVerboseLogging) {
                            LogToFile(Format("Timestamp: {} | HandleSecondKey: ERROR moving mouse: {}",
                                A_TickCount, e.Message) "`n", "antimouse_core.log")
                        }

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR moving mouse: {}", e.Message),
                        "antimouse_fix.log")
                        ToolTip("ERROR: Failed to move mouse: " e.Message, 10, 250)
                    }

                    ; --- Task 6.13: Explicitly Add MouseMove to HandleSecondKey ---
                    ; This ensures the mouse moves to the center of the cell (redundant but ensures it happens)
                    try {
                        centerX := boundaries.x + (boundaries.w // 2)
                        centerY := boundaries.y + (boundaries.h // 2)
                        MouseMove(centerX, centerY, 0)

                        ; --- 5.13.1: VISUAL DEBUGGING - Check if second MouseMove worked ---
                        MouseGetPos(&afterX2, &afterY2)
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - SECOND MOUSEMOVE to: x={}, y={}", centerX,
                            centerY),
                        "antimouse_fix.log")
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - After second mouse move: x={}, y={}",
                            afterX2, afterY2),
                        "antimouse_fix.log")

                        if (enableVerboseLogging) {
                            LogToFile(Format(
                                "Timestamp: {} | Task 6.13 | HandleSecondKey: Explicitly moved mouse to center of cell: {}, {}",
                                A_TickCount, centerX, centerY) "`n", "antimouse_core.log")
                        }
                    } catch as e {
                        if (enableVerboseLogging) {
                            LogToFile(Format(
                                "Timestamp: {} | Task 6.13 | HandleSecondKey: ERROR in explicit mouse move: {}",
                                A_TickCount, e.Message) "`n", "antimouse_core.log")
                        }

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR in second mouse move: {}", e.Message),
                        "antimouse_fix.log")
                    }

                    ; Transition to subgrid state
                    try {
                        LogToFile(Format(
                            "Timestamp: {} | HandleSecondKey: Transitioning to SUBGRID_STANDARD after selecting cell '{}'",
                            A_TickCount, targetCellKey) "`n", "antimouse_core.log")
                        TransitionToState(State_SUBGRID_STANDARD)

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile(
                            "5.13.1 DEBUG | HandleSecondKey - Successfully called TransitionToState(SUBGRID_STANDARD)",
                            "antimouse_fix.log")
                    } catch as e {
                        if (enableVerboseLogging) {
                            LogToFile(Format(
                                "Timestamp: {} | HandleSecondKey: ERROR in state transition: {}", A_TickCount,
                                e.Message) "`n", "antimouse_core.log")
                        }

                        ; --- 5.13.1: VISUAL DEBUGGING ---
                        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - ERROR in TransitionToState: {}", e.Message),
                        "antimouse_fix.log")
                        ToolTip("ERROR: Failed to transition state: " e.Message, 10, 280)
                    }
                } else {
                    if (enableVerboseLogging) {
                        LogToFile(Format(
                            "Timestamp: {} | HandleSecondKey: Failed to get boundaries for cell '{}'",
                            A_TickCount, targetCellKey) "`n", "antimouse_core.log")
                    }

                    ; --- 5.13.1: VISUAL DEBUGGING ---
                    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - Failed to get boundaries for cell '{}'",
                        targetCellKey),
                    "antimouse_fix.log")
                    ToolTip("ERROR: Failed to get boundaries for cell " targetCellKey, 10, 310)
                }
            } else {
                if (enableVerboseLogging) {
                    LogToFile(Format("Timestamp: {} | HandleSecondKey: currentOverlay is not a valid object",
                        A_TickCount) "`n", "antimouse_core.log")
                }

                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile("5.13.1 DEBUG | HandleSecondKey - ERROR: currentOverlay is not a valid object",
                    "antimouse_fix.log")
                ToolTip("ERROR: currentOverlay is not a valid object", 10, 340)
            }
        } catch as e {
            if (enableVerboseLogging) {
                LogToFile(Format("Timestamp: {} | HandleSecondKey: CRITICAL ERROR: {}", A_TickCount, e.Message) "`n",
                "antimouse_core.log")
            }

            ; --- 5.13.1: VISUAL DEBUGGING ---
            LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - CRITICAL ERROR: {}", e.Message),
            "antimouse_fix.log")
            ToolTip("CRITICAL ERROR: " e.Message, 10, 370)
        }
    }

    ; Reset for next selection
    StateMap['firstKey'] := ""

    ; Set timer to clear tooltips after 5 seconds
    SetTimer(() => ToolTip(), -5000)

    ; --- 5.13.1: VISUAL DEBUGGING END ---
    LogToFile(Format("5.13.1 DEBUG | HandleSecondKey EXIT for key '{}'", key), "antimouse_fix.log")
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
