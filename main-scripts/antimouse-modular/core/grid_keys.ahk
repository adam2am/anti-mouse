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
        FileAppend(Format("Timestamp: {} | Task: 2.1 | HandleKey START | key={}, bypassStateCheck={}", A_TickCount, key,
            bypassStateCheck) "`n", "antimouse_core.log")
    }
    ; <<< TASK 2.1 CORE LOGGING END >>>

    initialFirstKey := g_firstKeyPressed ; Store initial value for logging

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey | key='{}' | currentState='{}' | g_firstKeyPressed='{}'",
            A_TickCount, key, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    }
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    ; Debounce check - ignore key presses too close to state transition
    ; timeSinceTransition := A_TickCount - stateTransitionTime
    ; if (timeSinceTransition < stateTransitionDelay) {
    ;     if (enableVerboseLogging) { ; <<< WRAPPED
    ;         FileAppend(Format("Timestamp: {} | Task: 2.1 | HandleKey: Debounced ({}ms < {}ms). Exiting.", A_TickCount,
    ;             timeSinceTransition, stateTransitionDelay) "`n", "antimouse_core.log")
    ;     }
    ;     return ; Ignore the key press
    ; }

    ; State check (unless bypassed, e.g., by StartNewSelection)
    if (!bypassStateCheck && (currentState != State_GRID_VISIBLE || !IsObject(StateMap['currentOverlay']))) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Invalid state/overlay. currentState='{}', IsObject(currentOverlay)={}. Exiting.",
                A_TickCount, currentState, IsObject(StateMap['currentOverlay'])) "`n", "antimouse_core.log")
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
        FileAppend(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Key type check for key='{}'. isColKey={}, isRowKey={}. InvalidCheck={}",
            A_TickCount, key, isColKey, isRowKey, invalidKey) "`n", "antimouse_core.log")
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
        FileAppend(Format(
            "Timestamp: {} | Task: 2.1 | DIAGNOSTIC | HandleKey: Before firstKey check. Global g_firstKeyPressed='{}'",
            A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
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
        FileAppend(Format(
            "Timestamp: {} | Task: 2.1 | HandleKey END | key={} | Final State='{}' | FirstKey was '{}' -> now '{}'",
            A_TickCount, key, currentState, firstKeyBefore, g_firstKeyPressed) "`n", "antimouse_core.log")
    }
    ; <<< TASK 2.1 CORE LOGGING END >>>
}

; Handle the first key press of a cell selection (column or row)
HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global g_firstKeyPressed, StateMap, currentState, showcaseDebug, highlight
    global enableVerboseLogging ; Added

    ; <<< TASK 2.2 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format(
            "Timestamp: {} | Task: 2.2 | HandleFirstKey START | key={}, isCol={}, isRow={}, currentState={}",
            A_TickCount,
            key, isColKey, isRowKey, currentState) "`n", "antimouse_core.log")
    }
    ; <<< TASK 2.2 CORE LOGGING END >>>

    ; --- NEW: Check if overlay is visible ---
    if (IsObject(StateMap['currentOverlay'])) {
        if (enableVerboseLogging) {
            FileAppend(Format("Timestamp: {} | Task: DEBUG | HandleFirstKey: Checking overlay visibility for key '{}'",
                A_TickCount, key) "`n", "antimouse_core.log")
        }
        StateMap['currentOverlay'].Show()
    }
    ; --- END NEW ---

    currentTime := A_TickCount

    ; Store the first key pressed
    g_firstKeyPressed := key
    StateMap['firstKey'] := key

    cellKey := ""
    targetCellX := 0
    targetCellY := 0
    targetCellW := 0
    targetCellH := 0
    tooltipText := ""

    if (isColKey) {
        ; First key is COLUMN
        StateMap['currentColIndex'] := colIndex
        ; Guess the row based on last selected or default to 1
        targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1
        targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length)
        ; Construct the guessed cell key (Col + Guessed Row)
        cellKey := key . StateMap['activeRowKeys'][targetRowIndex]
        tooltipText := "First key: " key ". Select row."
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>> Task: 2.2
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.2 | DIAGNOSTIC | HandleFirstKey: First key is COLUMN='{}', guessing cellKey='{}'",
                A_TickCount, key, cellKey) "`n", "antimouse_core.log")
        }
        ; <<< ENHANCED DIAGNOSTIC LOGGING END ---
    } else { ; isRowKey
        ; First key is ROW
        StateMap['currentRowIndex'] := rowIndex
        StateMap['lastSelectedRowIndex'] := rowIndex ; Remember last row
        ; Guess the column based on last selected or default to middle
        targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] : Ceil(StateMap['activeColKeys'].Length /
            2)
        targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length)
        ; Construct the guessed cell key (Guessed Col + Row)
        cellKey := StateMap['activeColKeys'][targetColIndex] . key
        tooltipText := "First key: " key ". Select column."
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>> Task: 2.2
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.2 | DIAGNOSTIC | HandleFirstKey: First key is ROW='{}', guessing cellKey='{}'",
                A_TickCount, key, cellKey) "`n", "antimouse_core.log")
        }
        ; <<< ENHANCED DIAGNOSTIC LOGGING END ---
    }

    ; --- RESTORED MouseMove and Highlight logic ---
    boundaries := ""
    if (IsObject(StateMap['currentOverlay'])) {
        boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
    }

    if (IsObject(boundaries)) {
        targetCellX := boundaries.x
        targetCellY := boundaries.y
        targetCellW := boundaries.w
        targetCellH := boundaries.h

        ; Update highlight and move mouse to center of guessed cell
        if (IsObject(highlight) && targetCellW > 0) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format("Timestamp: {} | Task: 2.2 | GUI | Updating highlight for guessed cell: {}",
                    A_TickCount,
                    cellKey) "`n", "antimouse_core.log")
            }
            highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format("Timestamp: {} | Task: 2.2 | MOUSE | Moving mouse to guessed cell center: x={}, y={}",
                    A_TickCount, targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2)) "`n",
                "antimouse_core.log")
            }
            MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
            Sleep(10) ; Short delay for visual update

            if (showcaseDebug) {
                ToolTip(tooltipText)
            }
        } else {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format(
                    "Timestamp: {} | Task: 2.2 | WARNING | HandleFirstKey: Could not update highlight (highlight object: {}, targetCellW: {})",
                    A_TickCount, IsObject(highlight), targetCellW) "`n", "antimouse_core.log")
            }
        }
    } else {
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.2 | WARNING | HandleFirstKey: Could not get boundaries for guessed cellKey '{}'",
                A_TickCount, cellKey) "`n", "antimouse_core.log")
        }
        ; Optionally hide highlight if boundaries fail?
        if (IsObject(highlight)) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format("Timestamp: {} | Task: 2.2 | GUI | Hiding highlight (failed boundaries)", A_TickCount
                ) "`n",
                "antimouse_core.log")
            }
            highlight.Hide()
        }
    }
    ; --- END RESTORED LOGIC ---

    ; Re-enable cursor tracking
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format("Timestamp: {} | Task: 2.2 | TIMER | Enabling TrackCursor timer.", A_TickCount) "`n",
        "antimouse_core.log")
    }
    SetTimer(TrackCursor, 50)

    ; <<< TASK 2.2 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format(
            "Timestamp: {} | Task: 2.2 | HandleFirstKey END | Stored g_firstKeyPressed='{}', Guessed cellKey='{}'",
            A_TickCount, g_firstKeyPressed, cellKey) "`n", "antimouse_core.log")
    }
    ; <<< TASK 2.2 CORE LOGGING END >>>
}

; Handle the second key press, completing cell selection and transitioning to appropriate state
HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global g_firstKeyPressed, StateMap, currentState, highlight, subGrid, showcaseDebug, enableUltraFast,
        rowKeyHoldThreshold
    global enableVerboseLogging ; Added

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format(
            "Timestamp: {} | Task: 2.3 | HandleSecondKey START | key={}, isCol={}, isRow={}, currentState={}, firstKey={}",
            A_TickCount, key, isColKey, isRowKey, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    }
    ; <<< TASK 2.3 CORE LOGGING END >>>

    ; --- NEW: Check if overlay is visible ---
    if (IsObject(StateMap['currentOverlay'])) {
        if (enableVerboseLogging) {
            FileAppend(Format("Timestamp: {} | Task: DEBUG | HandleSecondKey: Checking overlay visibility for key '{}'",
                A_TickCount, key) "`n", "antimouse_core.log")
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
            FileAppend(Format("Timestamp: {} | Task: 2.3 | DIAGNOSTIC | HandleSecondKey: Valid Col->Row. cellKey='{}'",
                A_TickCount, finalCellKey) "`n", "antimouse_core.log")
        }
    }
    else if (firstKeyWasRow && isColKey) {
        ; Expected: Row -> Col
        finalCellKey := key . g_firstKeyPressed ; Store as Column first, then row
        StateMap['currentColIndex'] := colIndex
        proceedToSubgrid := true
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Task: 2.3 | DIAGNOSTIC | HandleSecondKey: Valid Row->Col. cellKey='{}'",
                A_TickCount, finalCellKey) "`n", "antimouse_core.log")
        }
    }
    else if (firstKeyWasCol && isColKey) {
        ; Unexpected: Col -> Col (Change column)
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | DIAGNOSTIC | HandleSecondKey: Invalid Col->Col. Changing first key from '{}' to '{}'",
                A_TickCount, g_firstKeyPressed, key) "`n", "antimouse_core.log")
        }
        g_firstKeyPressed := key ; Update stored col key
        StateMap['firstKey'] := key
        HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex) ; Re-run first key logic
        ; <<< TASK 2.3 CORE LOGGING START >>>
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey END | Invalid Col->Col. Reran HandleFirstKey.",
                A_TickCount) "`n", "antimouse_core.log")
        }
        ; <<< TASK 2.3 CORE LOGGING END >>>
        return ; Exit after handling as first key
    }
    else if (firstKeyWasRow && isRowKey) {
        ; Unexpected: Row -> Row (Change row)
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | DIAGNOSTIC | HandleSecondKey: Invalid Row->Row. Changing first key from '{}' to '{}'",
                A_TickCount, g_firstKeyPressed, key) "`n", "antimouse_core.log")
        }
        g_firstKeyPressed := key ; Update stored row key
        StateMap['firstKey'] := key
        HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex) ; Re-run first key logic
        ; <<< TASK 2.3 CORE LOGGING START >>>
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey END | Invalid Row->Row. Reran HandleFirstKey.",
                A_TickCount) "`n", "antimouse_core.log")
        }
        ; <<< TASK 2.3 CORE LOGGING END >>>
        return ; Exit after handling as first key
    }
    else {
        ; Should not happen if initial checks are correct
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | WARNING | HandleSecondKey: Invalid sequence logic error. firstKey='{}', key='{}'",
                A_TickCount, g_firstKeyPressed, key) "`n", "antimouse_core.log")
        }
        g_firstKeyPressed := "" ; Reset first key
        StateMap['firstKey'] := ""
        ; <<< TASK 2.3 CORE LOGGING START >>>
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Task: 2.3 | HandleSecondKey END | Logic error. Reset first key.",
                A_TickCount) "`n", "antimouse_core.log")
        }
        ; <<< TASK 2.3 CORE LOGGING END >>>
        return
    }

    ; If not proceeding (invalid sequence handled above), exit
    if (!proceedToSubgrid || finalCellKey == "") {
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | HandleSecondKey END | Not proceeding to subgrid (handled invalid sequence).",
                A_TickCount) "`n", "antimouse_core.log")
        }
        return
    }

    ; --- Proceed to Subgrid State ---
    boundaries := ""
    if (IsObject(StateMap['currentOverlay'])) {
        boundaries := StateMap['currentOverlay'].GetCellBoundaries(finalCellKey)
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Task: 2.3 | DIAGNOSTIC | Getting boundaries for cellKey='{}'",
                A_TickCount,
                finalCellKey) "`n", "antimouse_core.log")
        }
    }

    if (IsObject(boundaries)) {
        StateMap['activeCellKey'] := finalCellKey
        StateMap['activeRowKey'] := isRowKey ? key : g_firstKeyPressed ; Store the row key used
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Task: 2.3 | STATE | Set activeCellKey='{}', activeRowKey='{}'",
                A_TickCount,
                finalCellKey, StateMap['activeRowKey']) "`n", "antimouse_core.log")
        }

        ; Update highlight and move mouse before transitioning state
        if (IsObject(highlight)) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format("Timestamp: {} | Task: 2.3 | GUI | Updating highlight for final cell: {}",
                    A_TickCount,
                    finalCellKey) "`n", "antimouse_core.log")
            }
            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        }
        targetX := boundaries.x + (boundaries.w // 2)
        targetY := boundaries.y + (boundaries.h // 2)
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Task: 2.3 | MOUSE | Moving mouse to final cell center: x={}, y={}",
                A_TickCount, targetX, targetY) "`n", "antimouse_core.log")
        }
        MouseMove(targetX, targetY, 0)
        Sleep(10) ; Short delay after moving mouse

        ; Update subgrid GUI geometry *before* showing it via state transition
        if (IsObject(subGrid)) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format("Timestamp: {} | Task: 2.3 | GUI | Updating subGrid geometry for cell: {}",
                    A_TickCount,
                    finalCellKey) "`n", "antimouse_core.log")
            }
            subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        } else {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format(
                    "Timestamp: {} | Task: 2.11 | WARNING | subGrid object invalid, cannot update geometry.",
                    A_TickCount) "`n", "antimouse_core.log")
            }
        }

        ; Reset the first key tracker *before* transitioning
        g_firstKeyPressed := ""
        StateMap['firstKey'] := ""
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Task: 2.3 | STATE | Reset g_firstKeyPressed.", A_TickCount) "`n",
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
            FileAppend(Format(
                "Timestamp: {} | Task: 2.3 | WARNING | Could not get boundaries for cellKey '{}'. Resetting first key.",
                A_TickCount, finalCellKey) "`n", "antimouse_core.log")
        }
        g_firstKeyPressed := "" ; Reset first key
        StateMap['firstKey'] := ""
        if (IsObject(highlight)) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                FileAppend(Format("Timestamp: {} | Task: 2.3 | GUI | Hiding highlight (failed boundaries)", A_TickCount
                ) "`n",
                "antimouse_core.log")
            }
            highlight.Hide()
        }
    }

    ; Re-enable cursor tracking AFTER state transition and GUI updates
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format("Timestamp: {} | Task: 2.3 | TIMER | Enabling TrackCursor timer.", A_TickCount) "`n",
        "antimouse_core.log")
    }
    SetTimer(TrackCursor, 50)

    ; <<< TASK 2.3 CORE LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format("Timestamp: {} | Task: 2.3 | HandleSecondKey END | key={} | cellKey='{}' | Proceeded={}",
            A_TickCount, key, finalCellKey, proceedToSubgrid) "`n", "antimouse_core.log")
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
