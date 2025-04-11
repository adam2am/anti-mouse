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
    global currentState, highlight, subGrid, cellMemory, StateMap, g_firstKeyPressed, showcaseDebug, enableUltraFast
    global enableVerboseLogging ; Added

    ; <<< TASK 2.1 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.1 | HandleKey START | key={}, bypassStateCheck={}", A_TickCount, key,
            bypassStateCheck), "antimouse_core.log")
    }
    ; <<< TASK 2.1 CORE LOGGING END >>>

    initialFirstKey := g_firstKeyPressed ; Store initial value for logging

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey | key='{}' | currentState='{}' | g_firstKeyPressed='{}'",
            A_TickCount, key, currentState, g_firstKeyPressed), "antimouse_core.log")
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
    firstKeyBefore := g_firstKeyPressed ; Store for logging
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Before firstKey check. Global g_firstKeyPressed='{}'",
            A_TickCount, g_firstKeyPressed), "antimouse_core.log")
    }

    if (g_firstKeyPressed == "") {
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
            A_TickCount, key, currentState, firstKeyBefore, g_firstKeyPressed), "antimouse_core.log")
    }
    ; <<< TASK 2.1 CORE LOGGING END >>>
}

; Handle the first key press of a cell selection (column or row)
HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global g_firstKeyPressed, StateMap, currentState, showcaseDebug, highlight
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
    g_firstKeyPressed := key ; Still needed for HandleSecondKey logic
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

    if (IsObject(boundaries)) {
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
    global g_firstKeyPressed, StateMap, currentState, highlight, subGrid, showcaseDebug, enableUltraFast,
        rowKeyHoldThreshold
    global enableVerboseLogging ; Added

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format(
            "Timestamp: {} | Task: 2.3 | HandleSecondKey START | key={}, isCol={}, isRow={}, currentState={}, firstKey={}",
            A_TickCount, key, isColKey, isRowKey, currentState, g_firstKeyPressed), "antimouse_core.log")
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

    ; Initialize variables
    cellKey := ""
    finalCellKey := ""
    proceedToSubgrid := false
    tooltipText := ""

    ; Determine if the first key was a column key
    firstKeyWasCol := false
    for colKeyCheck in StateMap['activeColKeys'] {
        if (colKeyCheck = g_firstKeyPressed) {
            firstKeyWasCol := true
            break
        }
    }
    firstKeyWasRow := !firstKeyWasCol ; Assume it must be one or the other

    ; Process based on key combination validity
    if (firstKeyWasCol && isRowKey) {
        ; Expected: Col -> Row
        finalCellKey := g_firstKeyPressed . key ; Column first, then row
        StateMap['currentRowIndex'] := rowIndex
        StateMap['lastSelectedRowIndex'] := rowIndex
        proceedToSubgrid := true
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | DIAGNOSTIC | HandleSecondKey: Valid Col->Row. cellKey='{}'",
                A_TickCount, finalCellKey), "antimouse_core.log")
        }
    }
    else if (firstKeyWasRow && isColKey) {
        ; Expected: Row -> Col
        finalCellKey := key . g_firstKeyPressed ; Store as Column first, then row
        StateMap['currentColIndex'] := colIndex
        proceedToSubgrid := true
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | DIAGNOSTIC | HandleSecondKey: Valid Row->Col. cellKey='{}'",
                A_TickCount, finalCellKey), "antimouse_core.log")
        }
    }
    else if (firstKeyWasCol && isColKey) {
        ; Unexpected: Col -> Col (Change column)
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 5.10 | ROBUST FIX | HandleSecondKey: Invalid Col->Col. Starting new selection with key '{}'",
                A_TickCount, key), "antimouse_core.log")
        }

        ; ROBUST FIX: Instead of changing g_firstKeyPressed and calling HandleFirstKey,
        ; reset state and start a completely new selection
        g_firstKeyPressed := ""  ; Reset first key
        StateMap['firstKey'] := ""

        ; Start a new selection with this key
        StartNewSelection(key)

        ; <<< TASK 2.3 CORE LOGGING START >>>
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey END | Invalid Col->Col. Called StartNewSelection.",
                A_TickCount), "antimouse_core.log")
        }
        ; <<< TASK 2.3 CORE LOGGING END >>>
        return ; Exit after handling as new selection
    }
    else if (firstKeyWasRow && isRowKey) {
        ; Unexpected: Row -> Row (Change row)
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 5.10 | ROBUST FIX | HandleSecondKey: Invalid Row->Row. Starting new selection with key '{}'",
                A_TickCount, key), "antimouse_core.log")
        }

        ; ROBUST FIX: Instead of changing g_firstKeyPressed and calling HandleFirstKey,
        ; reset state and start a completely new selection
        g_firstKeyPressed := ""  ; Reset first key
        StateMap['firstKey'] := ""

        ; Start a new selection with this key
        StartNewSelection(key)

        ; <<< TASK 2.3 CORE LOGGING START >>>
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey END | Invalid Row->Row. Called StartNewSelection.",
                A_TickCount), "antimouse_core.log")
        }
        ; <<< TASK 2.3 CORE LOGGING END >>>
        return ; Exit after handling as new selection
    }
    else {
        ; Should not happen if initial checks are correct
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | WARNING | HandleSecondKey: Invalid sequence logic error. firstKey='{}', key='{}'",
                A_TickCount, g_firstKeyPressed, key), "antimouse_core.log")
        }
        g_firstKeyPressed := "" ; Reset first key
        StateMap['firstKey'] := ""
        ; <<< TASK 2.3 CORE LOGGING START >>>
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format("Timestamp: {} | Task: 2.3 | HandleSecondKey END | Logic error. Reset first key.",
                A_TickCount), "antimouse_core.log")
        }
        ; <<< TASK 2.3 CORE LOGGING END >>>
        return
    }

    ; If not proceeding (invalid sequence handled above), exit
    if (!proceedToSubgrid || finalCellKey == "") {
        if (enableVerboseLogging) { ; <<< WRAPPED
            ; FIX: Use safe logging
            LogToFile(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey END | Not proceeding to subgrid (handled invalid sequence).",
                A_TickCount), "antimouse_core.log")
        }
        return
    }

    ; If proceeding to the subgrid, handle it
    if (proceedToSubgrid) {
        ; Get cell boundaries for the final cell key
        boundaries := IsObject(StateMap['currentOverlay']) ? StateMap['currentOverlay'].GetCellBoundaries(
            finalCellKey) :
            ""

        if (IsObject(boundaries)) {
            ; Store the cell for subgrid activation
            StateMap['activeCellKey'] := finalCellKey

            ; Store the row key (used for ultra-fast mode and row preservation)
            if (isRowKey) {
                StateMap['activeRowKey'] := key
            } else {
                StateMap['activeRowKey'] := StateMap.Get('firstKey', '') ; Use .Get for safety
            }

            ; --- TASK 5.8: Clear preserved row key after successful cell selection ---
            ; Now that we've selected a complete cell, we can clear the preserved row key
            if (StateMap.Has("preservedRowKey")) {
                LogToFile("Task 5.8 | HandleSecondKey: Clearing preservedRowKey after successful cell selection",
                    "antimouse_core.log")
                StateMap.Delete("preservedRowKey")
            }
            ; --- END TASK 5.8 ---

            ; FIX: Use safe logging
            LogToFile(Format("Timestamp: {} | Task: 2.3 | STATE | Set activeCellKey='{}', activeRowKey='{}'",
                A_TickCount, finalCellKey, StateMap.Get('activeRowKey', '')), "antimouse_core.log")

            ; Update highlight to show the selected cell
            if (IsObject(highlight)) {
                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            }

            ; Update subgrid GUI geometry *before* showing it via state transition
            if (IsObject(subGrid)) {
                if (enableVerboseLogging) { ; <<< WRAPPED
                    ; FIX: Use safe logging
                    LogToFile(Format("Timestamp: {} | Task: 2.3 | GUI | Updating subGrid geometry for cell: {}",
                        A_TickCount,
                        finalCellKey), "antimouse_core.log")
                }
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            } else {
                if (enableVerboseLogging) { ; <<< WRAPPED
                    ; FIX: Use safe logging
                    LogToFile(Format(
                        "Timestamp: {} | Task: 5.10 | WARNING | subGrid object invalid, cannot update geometry.",
                        A_TickCount), "antimouse_core.log")
                }
            }

            ; Reset the first key tracker *before* transitioning
            g_firstKeyPressed := ""
            StateMap['firstKey'] := ""
            if (enableVerboseLogging) { ; <<< WRAPPED
                ; FIX: Use safe logging
                LogToFile(Format("Timestamp: {} | Task: 2.3 | STATE | Reset g_firstKeyPressed.", A_TickCount),
                "antimouse_core.log")
            }

            ; Transition to the appropriate subgrid state
            ; TODO: Add logic here to decide between SUBGRID_STANDARD and SUBGRID_ULTRAFAST
            ; based on rowKeyHoldThreshold if enableUltraFast is true.
            ; For now, always transition to standard.
            targetState := State_SUBGRID_STANDARD
            TransitionToState(targetState)

        } else {
            if (enableVerboseLogging) { ; <<< WRAPPED
                ; FIX: Use safe logging
                LogToFile(Format(
                    "Timestamp: {} | Task: 2.3 | WARNING | Could not get boundaries for cellKey '{}'. Resetting first key.",
                    A_TickCount, finalCellKey), "antimouse_core.log")
            }
            g_firstKeyPressed := "" ; Reset first key
            StateMap['firstKey'] := ""
            if (IsObject(highlight)) {
                if (enableVerboseLogging) { ; <<< WRAPPED
                    ; FIX: Use safe logging
                    LogToFile(Format("Timestamp: {} | Task: 2.3 | GUI | Hiding highlight (failed boundaries)",
                        A_TickCount
                    ), "antimouse_core.log")
                }
                highlight.Hide()
            }
        }
    }

    ; Re-enable cursor tracking
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.3 | TIMER | Enabling TrackCursor timer.", A_TickCount),
        "antimouse_core.log")
    }
    SetTimer(TrackCursor, 50)

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | Task: 2.3 | HandleSecondKey END", A_TickCount), "antimouse_core.log")
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
