; ==============================================================================
; core/grid_keys.ahk - Grid Key Handling Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug, highlight, subGrid, stateTransitionDelay, stateTransitionTime
global g_firstKeyPressed ; Explicitly track first key globally
global enableVerboseLogging ; Added

; Handle a key press in GRID_VISIBLE state by either storing first key or completing cell selection
HandleKey(key, bypassStateCheck := false) {
    global currentState, highlight, subGrid, cellMemory, StateMap, showcaseDebug, enableUltraFast
    global enableVerboseLogging ; Added

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
        StateMap['currentOverlay'].Show()
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
            ; Determine row - check if we have a preserved row from previous cell
            if (StateMap.Has("preservedRowKey")) {
                preservedRowKey := StateMap["preservedRowKey"]
                targetRowIndex := 0
                loop StateMap['activeRowKeys'].Length {
                    if (preservedRowKey == StateMap['activeRowKeys'][A_Index]) {
                        targetRowIndex := A_Index
                        break
                    }
                }
                if (targetRowIndex > 0) {
                    LogToFile(Format("Task 6.1 Fallback | HandleFirstKey: Found preserved row at index {}",
                        targetRowIndex), "antimouse_core.log")
                } else {
                    targetRowIndex := StateMap.Get('lastSelectedRowIndex', 1)
                    LogToFile(Format(
                        "Task 6.1 Fallback | HandleFirstKey: Preserved row not found, using lastSelectedRowIndex {}",
                        targetRowIndex), "antimouse_core.log")
                }
            } else {
                targetRowIndex := StateMap.Get('lastSelectedRowIndex', 1)
                LogToFile(Format("Task 6.1 Fallback | HandleFirstKey: No preserved row, using lastSelectedRowIndex {}",
                    targetRowIndex), "antimouse_core.log")
            }
            targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length)
            targetCellKey := key . StateMap['activeRowKeys'][targetRowIndex]
            tooltipText := "First key: " key ". Select row."
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Timestamp: {} | Task: 6.1 Fallback | HandleFirstKey: First key is COLUMN='{}', guessing targetCellKey='{}'",
                    A_TickCount, key, targetCellKey), "antimouse_core.log")
            }
        } else { ; isRowKey
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex
            targetColIndex := StateMap.Get('currentColIndex', Ceil(StateMap['activeColKeys'].Length / 2))
            targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length)
            targetCellKey := StateMap['activeColKeys'][targetColIndex] . key
            tooltipText := "First key: " key ". Select column."
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Timestamp: {} | Task: 6.1 Fallback | HandleFirstKey: First key is ROW='{}', guessing targetCellKey='{}'",
                    A_TickCount, key, targetCellKey), "antimouse_core.log")
            }
        }
    }
    ; --- Task 6.1: Get Context from Hovered Cell --- END

    ; --- Use targetCellKey (calculated above) to update highlight/mouse ---
    boundaries := ""
    if (IsObject(StateMap['currentOverlay'])) {
        boundaries := StateMap['currentOverlay'].GetCellBoundaries(targetCellKey)
    }

    if (IsObject(boundaries) && boundaries.HasProp("x")) {
        targetCellX := boundaries.x
        targetCellY := boundaries.y
        targetCellW := boundaries.w
        targetCellH := boundaries.h

        ; Update highlight and move mouse to center of target cell
        if (IsObject(highlight) && targetCellW > 0) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format("Timestamp: {} | Task: 6.1 | GUI | Updating highlight for target cell: {}",
                    A_TickCount, targetCellKey), "antimouse_core.log")
            }
            highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format("Timestamp: {} | Task: 6.1 | MOUSE | Moving mouse to target cell center: x={}, y={}",
                    A_TickCount, targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2)),
                "antimouse_core.log")
            }
            MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
            Sleep(10) ; Short delay for visual update

            if (showcaseDebug) {
                ToolTip(tooltipText)
            }
        } else {
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format(
                    "Timestamp: {} | Task: 6.1 | WARNING | HandleFirstKey: Could not update highlight (highlight object: {}, targetCellW: {})",
                    A_TickCount, IsObject(highlight), targetCellW), "antimouse_core.log")
            }
        }
    } else {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 6.1 | WARNING | HandleFirstKey: Could not get boundaries for target cellKey '{}'",
                A_TickCount, targetCellKey), "antimouse_core.log")
        }
        if (IsObject(highlight)) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format("Timestamp: {} | Task: 6.1 | GUI | Hiding highlight (failed boundaries)", A_TickCount),
                "antimouse_core.log")
            }
            highlight.Hide()
        }
    }

    ; Re-enable cursor tracking
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 6.1 | TIMER | Enabling TrackCursor timer.", A_TickCount),
        "antimouse_core.log")
    }
    SetTimer(TrackCursor, 50)

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.2 | HandleFirstKey END | key={}, TargetCellKey='{}', currentState={}",
            A_TickCount, key, targetCellKey, currentState), "antimouse_core.log")
    }
}

; Handle the second key press, completing cell selection and transitioning to appropriate state
HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global StateMap, currentState, highlight, subGrid, showcaseDebug, enableUltraFast,
        rowKeyHoldThreshold
    global enableVerboseLogging ; Added

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.3 | HandleSecondKey START | key={}, isCol={}, isRow={}, firstKey='{}', currentState='{}'",
            A_TickCount, key, isColKey, isRowKey, StateMap['firstKey'], currentState), "antimouse_core.log")
    }
    ; <<< TASK 2.3 CORE LOGGING END >>>

    ; --- NEW: Check if overlay is visible ---
    if (IsObject(StateMap['currentOverlay'])) {
        if (enableVerboseLogging) {
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: DEBUG | HandleSecondKey: Checking overlay visibility for key '{}'",
                A_TickCount, key), "antimouse_core.log")
        }
        StateMap['currentOverlay'].Show()
    }
    ; --- END NEW ---

    ; Retrieve the first key pressed from StateMap
    firstKey := StateMap['firstKey']
    firstKeyIsCol := false
    firstKeyIsRow := false

    loop StateMap['activeColKeys'].Length {
        if (firstKey == StateMap['activeColKeys'][A_Index]) {
            firstKeyIsCol := true
            break
        }
    }
    if (!firstKeyIsCol) {
        loop StateMap['activeRowKeys'].Length {
            if (firstKey == StateMap['activeRowKeys'][A_Index]) {
                firstKeyIsRow := true
                break
            }
        }
    }

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.3 | HandleSecondKey: First key '{}' type: isCol={}, isRow={}",
            A_TickCount, firstKey, firstKeyIsCol, firstKeyIsRow), "antimouse_core.log")
    }
    ; <<< TASK 2.3 CORE LOGGING END >>>

    finalCellKey := ""
    proceedToSubgrid := false ; Flag to indicate if we should move to subgrid state

    ; Check if the key sequence is valid (Col -> Row or Row -> Col)
    if ((isColKey && firstKeyIsRow) || (isRowKey && firstKeyIsCol)) {
        ; Valid sequence
        if (isColKey) {
            ; Second key is Column, first key was Row
            finalCellKey := key . firstKey
            ; Store current column and row index in state
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex
        } else {
            ; Second key is Row, first key was Column
            finalCellKey := firstKey . key
            ; Store current column and row index in state
            StateMap['currentColIndex'] := colIndex
            StateMap['lastSelectedRowIndex'] := rowIndex
        }
        proceedToSubgrid := true

        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey: Valid sequence detected ({}->{}). finalCellKey='{}'",
                A_TickCount, firstKey, key, finalCellKey), "antimouse_core.log")
        }
    } else {
        ; Invalid sequence (Col -> Col or Row -> Row)
        ; --- TASK 5.10: Robust Fix - Start new selection instead of just changing first key ---
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 5.10 | HandleSecondKey: INVALID sequence ({}->{}). Calling StartNewSelection({})",
                A_TickCount, firstKey, key, key), "antimouse_core.log")
        }
        if (showcaseDebug) {
            ToolTip("Invalid key sequence: " . firstKey . " -> " . key)
            SetTimer(() => ToolTip(), -1000) ; Clear tooltip after 1 second
        }
        ; Clear the first key state since the sequence was invalid
        StateMap['firstKey'] := ""
        ; Start a new selection using the *current* key as the *first* key
        StartNewSelection(key) ; Make sure StartNewSelection is accessible
        return ; Exit HandleSecondKey early as StartNewSelection handles the rest
    }

    if (proceedToSubgrid) {
        ; Get boundaries for the finalized cell
        boundaries := Map()
        if (IsObject(StateMap['currentOverlay'])) {
            try {
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(finalCellKey)
            } catch as err {
                LogToFile(Format("Task: 5.10 | HandleSecondKey ERROR getting boundaries: {}", err.Message),
                "antimouse_core.log")
            }
        }

        if (IsObject(boundaries) && boundaries.HasProp("x")) {
            ; Successfully got boundaries, move to subgrid state
            StateMap['activeCellKey'] := finalCellKey

            ; <<< Task 3.1: Store active row key for potential ultra-fast mode >>>
            if (isRowKey) {
                StateMap['activeRowKey'] := key ; The second key was the row key
            } else { ; firstKeyIsRow
                StateMap['activeRowKey'] := firstKey ; The first key was the row key
            }
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format("Timestamp: {} | Task: 3.1 | HandleSecondKey: Stored activeRowKey='{}'", A_TickCount,
                    StateMap['activeRowKey']), "antimouse_core.log")
            }
            ; <<< End Task 3.1 >>>

            ; --- Task 5.8: Clear preserved row key after successful cell selection ---
            if (StateMap.Has("preservedRowKey")) {
                StateMap.Delete("preservedRowKey")
                if (enableVerboseLogging) { ; <<< WRAPPED
                    LogToFile(Format("Timestamp: {} | Task: 5.8 | HandleSecondKey: Cleared preservedRowKey",
                        A_TickCount), "antimouse_core.log")
                }
            }
            ; --- End Task 5.8 ---

            ; Move mouse to the center of the cell (optional, could be configured)
            ; MouseMove(boundaries.x + boundaries.w / 2, boundaries.y + boundaries.h / 2, 0)

            ; Update highlight and subgrid positions
            if (IsObject(highlight)) {
                try {
                    highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                } catch as err {
                    LogToFile(Format("Task: 5.10 | HandleSecondKey ERROR updating highlight: {}", err.Message),
                    "antimouse_core.log")
                }
            }
            if (IsObject(subGrid)) {
                try {
                    subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                } catch as err {
                    LogToFile(Format("Task: 5.10 | HandleSecondKey ERROR updating subGrid: {}", err.Message),
                    "antimouse_core.log")
                }
            }

            ; Reset the first key tracker
            StateMap['firstKey'] := ""

            ; Transition to the subgrid state
            try {
                TransitionToState(State_SUBGRID_STANDARD)
            } catch as err {
                LogToFile(Format("Task: 5.10 | HandleSecondKey ERROR transitioning state: {}", err.Message),
                "antimouse_core.log")
            }
        } else {
            ; Failed to get boundaries, something went wrong
            ; Reset the first key press state and potentially show an error
            StateMap['firstKey'] := ""
            if (IsObject(highlight)) {
                try {
                    highlight.Hide()
                } catch as err {
                    LogToFile(Format("Task: 5.10 | HandleSecondKey ERROR hiding highlight: {}", err.Message),
                    "antimouse_core.log")
                }
            }
            if (showcaseDebug) {
                ToolTip("Error: Could not find boundaries for cell '" . finalCellKey . "'")
                SetTimer(() => ToolTip(), -1000)
            }
            if (enableVerboseLogging) { ; <<< WRAPPED
                ; FIX: Use safe logging
                LogToFile(Format(
                    "Timestamp: {} | Task: 2.3 | HandleSecondKey: Failed to get boundaries for cell '{}'. Resetting firstKey.",
                    A_TickCount, finalCellKey), "antimouse_core.log")
            }
        }
    }

    ; Restart cursor tracking AFTER processing the key
    SetTimer(TrackCursor, 50) ; Adjust interval as needed

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.3 | HandleSecondKey END | key={} | Final State='{}' | FirstKey='{}'",
            A_TickCount, key, currentState, StateMap['firstKey']), "antimouse_core.log")
    }
    ; <<< TASK 2.3 CORE LOGGING END >>>
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
