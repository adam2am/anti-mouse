; ==============================================================================
; core/grid_keys.ahk - Grid Key Handling Logic
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug

; Handle a key press in GRID_VISIBLE state by either storing first key or completing cell selection
HandleKey(key) {
    ; --- CORE LOGGING START ---
    global StateMap
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
    if ((currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) && enableUltraFast && key ==
    StateMap['activeRowKey']) {
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
        ; Check if the same key is being processed too rapidly (likely auto-repeat)
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

        if (currentState != State_GRID_VISIBLE || !IsObject(StateMap['currentOverlay'])) { ; Use StateMap
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

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | HandleKey: Before firstKey check. Global g_firstKeyPressed='{}'",
            A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---

        ; Determine if this is the first key or the second key of a cell selection
        if (g_firstKeyPressed == "") {
            ; This is the FIRST key press - handle it by calling the dedicated function
            HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex)
        } else {
            ; This is the SECOND key press - handle it by calling the dedicated function
            HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex)
        }

        keyProcessingLock := false

    } catch Error as e {
        ; Log error information
        if (showcaseDebug) {
            errMsg := Format("Timestamp: {} | HandleKey ERROR: {} at line {}. File: {}",
                A_TickCount, e.Message, e.Line, e.File)
            FileAppend(errMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        ; Ensure lock is released in case of error
        keyProcessingLock := false
        ; Re-enable cursor tracking
        SetTimer(TrackCursor, 50)
    }
}

; Handle the first key press of a cell selection (column or row)
HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global g_firstKeyPressed, StateMap, currentState, showcaseDebug, highlight
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
        FileAppend(Format(
            "Timestamp: {} | DIAGNOSTIC | HandleFirstKey: First key is COLUMN='{}', guessing cellKey='{}'", A_TickCount,
            key, cellKey) "`n", "antimouse_core.log")
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
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleFirstKey: First key is ROW='{}', guessing cellKey='{}'",
            A_TickCount, key, cellKey) "`n", "antimouse_core.log")
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
            highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
            MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
            Sleep(10) ; Short delay for visual update

            if (showcaseDebug) {
                ToolTip(tooltipText)
            }
        } else {
            FileAppend(Format(
                "Timestamp: {} | WARNING | HandleFirstKey: Could not update highlight (highlight object: {}, targetCellW: {})",
                A_TickCount, IsObject(highlight), targetCellW) "`n", "antimouse_core.log")
        }
    } else {
        FileAppend(Format("Timestamp: {} | WARNING | HandleFirstKey: Could not get boundaries for guessed cellKey '{}'",
            A_TickCount, cellKey) "`n", "antimouse_core.log")
        ; Optionally hide highlight if boundaries fail?
        ; if (IsObject(highlight)) {
        ;     highlight.Hide()
        ; }
    }
    ; --- END RESTORED LOGIC ---

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)

    ; --- CORE LOGGING START ---
    ; Log the stored first key and the *guessed* cell key
    FileAppend(Format("Timestamp: {} | HandleFirstKey END | Stored g_firstKeyPressed='{}', Guessed cellKey='{}'",
        A_TickCount, g_firstKeyPressed, cellKey) "`n", "antimouse_core.log")
    ; --- CORE LOGGING END ---
}

; Handle the second key press, completing cell selection and transitioning to appropriate state
HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex) {
    global g_firstKeyPressed, StateMap, currentState, highlight, subGrid, cellMemory, storePerMonitor, showcaseDebug
    currentTime := A_TickCount

    ; --- CORE LOGGING START ---
    FileAppend(Format(
        "Timestamp: {} | HandleSecondKey START | key='{}', g_firstKeyPressed='{}', isColKey={}, isRowKey={}",
        A_TickCount, key, g_firstKeyPressed, isColKey, isRowKey) "`n", "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        FileAppend(Format("Timestamp: {} | HandleSecondKey: Second Key Press | key={} | firstKey={}",
            currentTime, key, g_firstKeyPressed) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Local variable to track if this was a row key (important for later subgrid activation)
    secondKeyWasRow := isRowKey

    ; Determine the cell key based on order of key presses
    cellKey := ""
    if (isColKey) {
        ; If first key was a row key and second key is a column key
        if (RowKeyCheck(g_firstKeyPressed)) {
            cellKey := key . g_firstKeyPressed
        } else {
            ; Both keys are column keys - invalid selection
            FileAppend(Format("Timestamp: {} | HandleSecondKey: Invalid - both keys are column keys",
                A_TickCount) "`n", "antimouse_core.log")
            g_firstKeyPressed := key  ; Treat this as a new first key
            HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex)
            return
        }
    } else { ; isRowKey
        ; If first key was a column key and second key is a row key
        if (ColKeyCheck(g_firstKeyPressed)) {
            cellKey := g_firstKeyPressed . key
        } else {
            ; Both keys are row keys - invalid selection
            FileAppend(Format("Timestamp: {} | HandleSecondKey: Invalid - both keys are row keys",
                A_TickCount) "`n", "antimouse_core.log")
            g_firstKeyPressed := key  ; Treat this as a new first key
            HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex)
            return
        }
    }

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleSecondKey: Computed cellKey='{}'",
        A_TickCount, cellKey) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; Store the selected cell key in StateMap
    StateMap['activeCellKey'] := cellKey

    ; Get cell boundaries for positioning
    FileAppend(Format(
        "Timestamp: {} | DEBUG: HandleSecondKey - Getting boundaries for cellKey='{}'. currentOverlay IsObject={}",
        A_TickCount, cellKey, IsObject(StateMap['currentOverlay'])) "`n", "antimouse_core.log")
    boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
    FileAppend(Format("Timestamp: {} | DEBUG: HandleSecondKey - Got boundaries. IsObject(boundaries)={}",
        A_TickCount, IsObject(boundaries)) "`n", "antimouse_core.log")

    ; Update highlight with these boundaries
    FileAppend(Format("Timestamp: {} | DEBUG: HandleSecondKey - Checking highlight object. IsObject(highlight)={}",
        A_TickCount, IsObject(highlight)) "`n", "antimouse_core.log")
    if (IsObject(highlight) && IsObject(boundaries)) {
        FileAppend(Format("Timestamp: {} | DEBUG: HandleSecondKey - Updating highlight.", A_TickCount) "`n",
        "antimouse_core.log")
        try {
            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        } catch as e {
            FileAppend(Format("Timestamp: {} | ERROR: HandleSecondKey - highlight.Update failed: {}", A_TickCount, e.Message
            ) "`n", "antimouse_core.log")
        }
        FileAppend(Format(
            "Timestamp: {} | DEBUG: HandleSecondKey - Highlight update completed (Show is part of Update).",
            A_TickCount) "`n",
        "antimouse_core.log")
    } else {
        FileAppend(Format(
            "Timestamp: {} | DEBUG: HandleSecondKey - Skipping highlight update (highlight or boundaries invalid).",
            A_TickCount) "`n", "antimouse_core.log")
    }

    ; --- Actions moved from CELL_SELECTED entry ---
    if (IsObject(boundaries)) {
        ; Position mouse in the center of the cell
        targetX := boundaries.x + (boundaries.w // 2)
        targetY := boundaries.y + (boundaries.h // 2)
        FileAppend(Format("Timestamp: {} | DEBUG: HandleSecondKey - Moving mouse to x={}, y={}",
            A_TickCount, targetX, targetY) "`n", "antimouse_core.log")
        MouseMove(targetX, targetY, 0)

        ; Configure subgrid with the cell boundaries
        if (IsObject(subGrid)) {
            FileAppend(Format(
                "Timestamp: {} | DEBUG: HandleSecondKey - Updating subGrid with boundaries x={}, y={}, w={}, h={}",
                A_TickCount, boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n", "antimouse_core.log")
            subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            FileAppend(Format("Timestamp: {} | DEBUG: HandleSecondKey - subGrid.Update completed successfully",
                A_TickCount) "`n", "antimouse_core.log")
        } else {
            FileAppend(Format(
                "Timestamp: {} | ERROR: HandleSecondKey - subGrid is not a valid object when trying to update",
                A_TickCount) "`n", "antimouse_core.log")
        }
    } else {
        FileAppend(Format(
            "Timestamp: {} | DEBUG: HandleSecondKey - Skipping MouseMove/subGrid.Update (boundaries invalid).",
            A_TickCount) "`n", "antimouse_core.log")
    }
    ; --- End of moved actions ---

    ; Check cell memory for remembered subcell if available
    local memoryKey := storePerMonitor ? StateMap['currentMonitorIndex'] . "_" . cellKey : cellKey
    local subCellFromMemory := ""
    if (cellMemory.Has(memoryKey)) {
        subCellFromMemory := cellMemory[memoryKey]
    }

    ; Save that the second key was a row key (important for ultrafast mode)
    if (secondKeyWasRow) {
        StateMap['activeRowKey'] := key
    } else {
        StateMap['activeRowKey'] := ""
    }

    ; Reset first key as selection is now complete
    g_firstKeyPressed := ""

    ; --- Determine target state (Standard for now, Ultra-Fast TBD) ---
    finalTargetState := State_SUBGRID_STANDARD
    ; TODO: Add logic here later to check for row key hold and set finalTargetState = State_SUBGRID_ULTRAFAST if needed

    FileAppend(Format(
        "Timestamp: {} | DEBUG: HandleSecondKey - About to transition directly to state '{}' with cellKey='{}'",
        A_TickCount, finalTargetState, cellKey) "`n", "antimouse_core.log")

    ; Transition directly to the determined subgrid state
    TransitionToState(finalTargetState)

    ; Remove transition to CELL_SELECTED and related debug logs
    ; ENHANCED DEBUG: Add before transition to CELL_SELECTED
    ; FileAppend(Format(
    ;     "Timestamp: {} | DEBUG: HandleSecondKey - About to transition to CELL_SELECTED state with cellKey='{}'",
    ;     A_TickCount, cellKey) "`n", "antimouse_core.log")

    ; Transition to CELL_SELECTED state
    ; TransitionToState(State_CELL_SELECTED)

    ; ENHANCED DEBUG: Add after transition to CELL_SELECTED
    ; FileAppend(Format("Timestamp: {} | DEBUG: HandleSecondKey - After transition to CELL_SELECTED, currentState='{}'",
    ;     A_TickCount, currentState) "`n", "antimouse_core.log")

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)

    ; --- CORE LOGGING START ---
    FileAppend(Format("Timestamp: {} | HandleSecondKey END | cellKey='{}', secondKeyWasRow={}, activeRowKey='{}'",
        A_TickCount, cellKey, secondKeyWasRow, StateMap['activeRowKey']) "`n", "antimouse_core.log")
    ; --- CORE LOGGING END ---
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
