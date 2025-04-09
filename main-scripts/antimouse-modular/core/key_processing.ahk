; ==============================================================================
; core/key_processing.ahk - Key Processing Wrapper Logic
; ==============================================================================

; Reference state constants defined in state.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST

; Central function called by hotkeys to route key presses to the appropriate handler based on the current state.
ProcessKeyPress(key) {
    global StateMap, currentState, showcaseDebug, g_firstKeyPressed ; Reference variables defined in state.ahk and config.ahk

    FileAppend(Format("Timestamp: {} | ProcessKeyPress START | key={} | currentState={}", A_TickCount, key,
        currentState) "`n", "antimouse_core.log")

    ; Simple state-based routing with no variable assignments that could cause problems
    if (currentState == State_GRID_VISIBLE) {
        ; When in grid visible state, directly route to HandleKey with no checks
        FileAppend(Format("Timestamp: {} | ProcessKeyPress: GRID_VISIBLE state - calling HandleKey for key='{}'",
            A_TickCount, key) "`n", "antimouse_core.log")
        HandleKey(key)
    }
    else if (currentState == State_SUBGRID_STANDARD) {
        ; For subgrid states, check if key is a grid key first
        if (CheckIfGridKey(key)) {
            FileAppend(Format(
                "Timestamp: {} | ProcessKeyPress: Grid key in SUBGRID_STANDARD - calling StartNewSelection",
                A_TickCount) "`n", "antimouse_core.log")
            StartNewSelection(key)
        } else {
            FileAppend(Format(
                "Timestamp: {} | ProcessKeyPress: Non-grid key in SUBGRID_STANDARD - calling HandleStandardSubgridKey",
                A_TickCount) "`n", "antimouse_core.log")
            HandleStandardSubgridKey(key)
        }
    }
    else if (currentState == State_SUBGRID_ULTRAFAST) {
        ; For ultra-fast subgrid, check if key is a grid key first
        if (CheckIfGridKey(key)) {
            FileAppend(Format(
                "Timestamp: {} | ProcessKeyPress: Grid key in SUBGRID_ULTRAFAST - calling StartNewSelection",
                A_TickCount) "`n", "antimouse_core.log")
            StartNewSelection(key)
        } else {
            FileAppend(Format(
                "Timestamp: {} | ProcessKeyPress: Non-grid key in SUBGRID_ULTRAFAST - calling HandleUltraFastKey",
                A_TickCount) "`n", "antimouse_core.log")
            HandleUltraFastKey(key)
        }
    }
    else if (currentState == State_IDLE) {
        FileAppend(Format("Timestamp: {} | ProcessKeyPress: Key press ignored in IDLE state",
            A_TickCount) "`n", "antimouse_core.log")
    }
    else {
        FileAppend(Format("Timestamp: {} | ProcessKeyPress: Unhandled state: '{}'",
            A_TickCount, currentState) "`n", "antimouse_core.log")
    }

    FileAppend(Format("Timestamp: {} | ProcessKeyPress END | key={} | currentState={}", A_TickCount, key, currentState) "`n",
    "antimouse_core.log")
}

; Helper function to check if a key is a grid key (column or row) - Used only in subgrid states
CheckIfGridKey(key) {
    global StateMap, showcaseDebug

    ; Safety check for state map objects
    if (!IsObject(StateMap) || !IsObject(StateMap['activeColKeys']) || !IsObject(StateMap['activeRowKeys'])) {
        FileAppend(Format("Timestamp: {} | CheckIfGridKey: StateMap or key arrays not valid objects",
            A_TickCount) "`n", "antimouse_core.log")
        return false
    }

    ; Check column keys
    for i, colKey in StateMap['activeColKeys'] {
        if (key == colKey) {
            return true
        }
    }

    ; Check row keys
    for i, rowKey in StateMap['activeRowKeys'] {
        if (key == rowKey) {
            return true
        }
    }

    return false
}

; Original IsGridKey left intact for compatibility with any other callers
IsGridKey(key) {
    return CheckIfGridKey(key)
}

; Handler for standard subgrid key presses (GHBN)
HandleStandardSubgridKey(key) {
    ; Simply call our actual implementation with a different name to avoid conflicts
    FileAppend(Format("Timestamp: {} | HandleStandardSubgridKey: Calling ProcessStandardSubgridKey for key='{}'",
        A_TickCount, key) "`n",
    "antimouse_core.log")
    ProcessStandardSubgridKey(key)
}

; Note: The HandleUltraFastKey is defined in subgrid_keys.ahk
