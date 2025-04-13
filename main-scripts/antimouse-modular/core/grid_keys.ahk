; ==============================================================================
; core/grid_keys.ahk - Grid Key Handling Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug, highlight, subGrid, stateTransitionDelay, stateTransitionTime
;global g_firstKeyPressed ; Explicitly track first key globally <<< Task 6.2: REMOVED
global enableVerboseLogging ; Added

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

    ; <<< TASK 2.2 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.2 | HandleFirstKey START | key={}, isCol={}, isRow={}, currentState={}",
            A_TickCount,
            key, isColKey, isRowKey, currentState), "antimouse_core.log")
    }
    ; <<< TASK 2.2 CORE LOGGING END >>>

    ; --- NEW: Check if overlay is visible ---
    if (IsObject(StateMap['currentOverlay'])) {
        if (enableVerboseLogging) {
            ; FIX: Use safe logging
            LogToFile(Format("Timestamp: {} | Task: DEBUG | HandleFirstKey: Checking overlay visibility for key '{}'",
                A_TickCount, key), "antimouse_core.log")
        }

        ; S1.1: Add try/catch for overlay.Show()
        try {
            StateMap['currentOverlay'].Show()
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR showing overlay: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
        }
    }
    ; --- END NEW ---

    currentTime := A_TickCount

    ; Store the first key pressed
    StateMap['firstKey'] := key

    targetCellKey := "" ; Renamed from cellKey for clarity
    hoveredCellKey := ""
    targetCellX := 0
    targetCellY := 0
    targetCellW := 0
    targetCellH := 0
    tooltipText := ""

    ; --- Task 6.1: Get Context from Hovered Cell --- START
    MouseGetPos(&currentX, &currentY)
    try {
        hoveredCellKey := GetCellAtPosition(currentX, currentY) ; Assumes GetCellAtPosition is available
    } catch as err {
        LogToFile(Format("Task 6.1 | HandleFirstKey ERROR calling GetCellAtPosition: {}", err.Message),
        "antimouse_core.log")
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
}

; Handle the second key press, completing cell selection and transitioning to appropriate state
HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global StateMap, currentState, highlight, subGrid, showcaseDebug, enableUltraFast,
        rowKeyHoldThreshold
    global enableVerboseLogging ; Added

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format(
            "Timestamp: {} | Task: 2.3 | HandleSecondKey START | key={}, isCol={}, isRow={}, firstKey={}, currentState={} | highlight={}, subGrid={}",
            A_TickCount, key, isColKey, isRowKey, StateMap['firstKey'], currentState, IsObject(highlight), IsObject(
                subGrid)),
        "antimouse_core.log")
    }
    ; <<< TASK 2.3 CORE LOGGING END >>>

    currentTime := A_TickCount
    firstKey := StateMap['firstKey']
    firstIsColKey := false

    ; Check if the first key was a column
    loop StateMap['activeColKeys'].Length {
        if (firstKey == StateMap['activeColKeys'][A_Index]) {
            firstIsColKey := true
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format("Timestamp: {} | Task: 2.3 | First key '{}' is a column key", A_TickCount, firstKey),
                "antimouse_core.log")
            }
            break
        }
    }

    ; For clarity, also check if it's a row key
    firstIsRowKey := !firstIsColKey

    ; Handle invalid combinations (two cols or two rows)
    if ((firstIsColKey && isColKey) || (firstIsRowKey && isRowKey)) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | Invalid key combination! FirstKey='{}' ({}), SecondKey='{}' ({})",
                A_TickCount, firstKey, firstIsColKey ? "Col" : "Row", key, isColKey ? "Col" : "Row"),
            "antimouse_core.log")
        }

        ; Clear first key tracking and show a tooltip
        if (showcaseDebug) {
            tooltipText := "Invalid: Two " . (isColKey ? "column" : "row") . " keys in a row."
            ToolTip(tooltipText)
            SetTimer(() => ToolTip(), -1000) ; Clear tooltip after 1 second
        }

        ; Clear selection state and return to grid visible, without activating a cell
        ; S1.4: Clear firstKey BEFORE calling StartNewSelection to prevent recursion
        StateMap['firstKey'] := ""

        ; Task 5.10: Use try/catch to handle StartNewSelection errors safely
        ; S1.1: Add try/catch for StartNewSelection
        try {
            StartNewSelection(key)
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR in StartNewSelection: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
        }
        return
    }

    ; Determine cell key based on the order of keys pressed
    cellKey := ""
    if (firstIsColKey) {
        ; First key was column, second is row
        cellKey := firstKey . key
    } else {
        ; First key was row, second is column
        cellKey := key . firstKey
    }

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.3 | Calculated cellKey = {}", A_TickCount, cellKey),
        "antimouse_core.log")
    }

    ; Get cell boundaries
    ; S1.1: Add IsObject check and try/catch for GetCellBoundaries
    if (IsObject(StateMap['currentOverlay'])) {
        try {
            cellBoundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)

            if (IsObject(cellBoundaries)) {
                ; Store active cell selection
                StateMap['activeCellKey'] := cellKey

                ; Update the highlight to show the selected cell
                ; S1.1: Add IsObject check and try/catch for highlight.Update
                if (IsObject(highlight)) {
                    try {
                        highlight.Update(cellBoundaries.x, cellBoundaries.y, cellBoundaries.w, cellBoundaries.h)
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | ERROR updating highlight: {}", A_TickCount, e.Message) "`n",
                        "antimouse_core.log")
                    }
                } else {
                    LogToFile(Format("Timestamp: {} | WARNING: highlight is not an object in HandleSecondKey",
                        A_TickCount) "`n",
                    "antimouse_core.log")
                }

                ; --- Task 6.12: Move Cursor to Middle of Cell ---
                ; Calculate the center point of the cell
                centerX := cellBoundaries.x + cellBoundaries.w / 2
                centerY := cellBoundaries.y + cellBoundaries.h / 2

                ; Move cursor to the center of the cell
                try {
                    MouseMove(centerX, centerY, 0) ; 0 speed for instant movement
                    if (enableVerboseLogging) {
                        LogToFile(Format("Task 6.12 | HandleSecondKey: Moved cursor to cell center ({}, {})",
                            Round(centerX), Round(centerY)), "antimouse_core.log")
                    }
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR in MouseMove: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }
                ; --- End Task 6.12 ---

                ; Update subgrid position
                ; S1.1: Add IsObject check and try/catch for subGrid.Update
                if (IsObject(subGrid)) {
                    try {
                        subGrid.Update(cellBoundaries.x, cellBoundaries.y, cellBoundaries.w, cellBoundaries.h)
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | ERROR updating subGrid: {}", A_TickCount, e.Message) "`n",
                        "antimouse_core.log")
                    }
                } else {
                    LogToFile(Format("Timestamp: {} | WARNING: subGrid is not an object in HandleSecondKey",
                        A_TickCount) "`n",
                    "antimouse_core.log")
                }

                ; Show a tooltip with the selection info if debug is enabled
                if (showcaseDebug) {
                    tooltipText := "Selected cell: " . cellKey
                    ToolTip(tooltipText)
                    SetTimer(() => ToolTip(), -1000) ; Clear tooltip after 1 second
                }

                ; Track selection for most-used cells
                UpdateCellMemory(cellKey, "")

                ; Transition to the subgrid state
                ; S1.1: Add try/catch for TransitionToState
                try {
                    TransitionToState(State_SUBGRID_STANDARD)
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR in TransitionToState: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }

                ; Reset first key to prepare for next selection
                StateMap['firstKey'] := ""

                if (enableVerboseLogging) { ; <<< WRAPPED
                    LogToFile(Format(
                        "Timestamp: {} | Task: 2.3 | HandleSecondKey: Successfully transitioned to SUBGRID_STANDARD for key {}",
                        A_TickCount, key), "antimouse_core.log")
                }
            } else {
                ; Handle case where cell boundaries are undefined
                if (enableVerboseLogging) { ; <<< WRAPPED
                    LogToFile(Format("Timestamp: {} | Task: 2.3 | ERROR: Failed to get boundaries for cell '{}'",
                        A_TickCount, cellKey), "antimouse_core.log")
                }

                ; S1.4: Clear firstKey BEFORE calling StartNewSelection to prevent recursion
                StateMap['firstKey'] := ""

                ; Call StartNewSelection to reset state
                ; S1.1: Add try/catch for StartNewSelection
                try {
                    StartNewSelection(key)
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR in StartNewSelection: {}", A_TickCount, e.Message) "`n",
                    "antimouse_core.log")
                }
            }
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR getting cell boundaries: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")

            ; S1.4: Clear firstKey BEFORE calling StartNewSelection to prevent recursion
            StateMap['firstKey'] := ""

            ; Call StartNewSelection to reset state
            try {
                StartNewSelection(key)
            } catch as e2 {
                LogToFile(Format("Timestamp: {} | ERROR in StartNewSelection: {}", A_TickCount, e2.Message) "`n",
                "antimouse_core.log")
            }
        }
    } else {
        LogToFile(Format("Timestamp: {} | WARNING: currentOverlay is not an object in HandleSecondKey", A_TickCount) "`n",
        "antimouse_core.log")

        ; S1.4: Clear firstKey BEFORE calling StartNewSelection to prevent recursion
        StateMap['firstKey'] := ""

        ; S1.1: Add try/catch for StartNewSelection
        try {
            StartNewSelection(key)
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR in StartNewSelection: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
        }
    }

    ; Restart cursor tracking after key is handled
    SetTimer(TrackCursor, 50)

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format(
            "Timestamp: {} | Task: 2.3 | HandleSecondKey END | key={}, cellKey={}, TimeElapsed={}ms",
            A_TickCount, key, cellKey, A_TickCount - currentTime), "antimouse_core.log")
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
