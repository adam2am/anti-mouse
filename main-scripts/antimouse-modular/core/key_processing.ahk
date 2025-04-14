; ==============================================================================
; core/key_processing.ahk - Key Processing Wrapper Logic
; ==============================================================================

; Reference state constants defined in state.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST

; Reference state constants and variables defined in state.ahk and config.ahk
; --- Task 6.2: Consolidate firstKey State Variable ---
; global StateMap, currentState, showcaseDebug, g_firstKeyPressed <<< REMOVED
global StateMap, currentState, showcaseDebug ; <<< UPDATED
global enableVerboseLogging ; Added
global enableFreeNavigation, navigationKey ; Settings

; S1.5.3 FIX: Explicitly reference UI objects to fix navigation regression
global highlight, subGrid ; Explicitly declare these globals for key processing module

; Central function called by hotkeys to route key presses to the appropriate handler based on the current state.
ProcessKeyPress(key) {
    global StateMap, currentState, showcaseDebug ; Reference variables defined in state.ahk and config.ahk
    global enableVerboseLogging ; Added
    global navigationKey, enableFreeNavigation ; Task 2.16: Free Cell Navigation
    global highlight, subGrid ; S1.5.3 FIX: Explicitly reference UI objects again to ensure they're accessible

    ; S1.5.1 DIAGNOSTIC: Enhanced execution path tracing
    LogToFile(Format(
        "S1.5.1 DIAGNOSTIC | ProcessKeyPress ENTRY | key='{}' | currentState='{}' | firstKey='{}' | IsObject(highlight)={} | IsObject(subGrid)={} | IsObject(currentOverlay)={}",
        key, currentState, StateMap.Get('firstKey', ""), IsObject(highlight), IsObject(subGrid), IsObject(StateMap.Get(
            'currentOverlay', ""))),
    "antimouse_diagnostic.log")

    ; S1.5.3 FIX: Log global objects state to diagnose reference issues
    LogToFile(Format("S1.5.3 FIX | ProcessKeyPress | Check global objects: highlight={}, subGrid={}, StateMap={}",
        IsObject(highlight), IsObject(subGrid), IsObject(StateMap)), "antimouse_fix.log")

    if (enableVerboseLogging) { ; <<< WRAPPED
        ; FIX: Use safe logging
        LogToFile(Format("Timestamp: {} | ProcessKeyPress START | key={} | currentState={}", A_TickCount, key,
            currentState), "antimouse_core.log")
    }

    ; --- Task 2.16: Free Cell Navigation - Handle navigation key (Escape) ---
    if (enableFreeNavigation && key == navigationKey) {
        ; Check if we're in a subgrid state
        if (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST) {
            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Timestamp: {} | Task: 2.16 | FREE-NAVIGATION: Navigation key pressed, returning to main grid",
                    A_TickCount) "`n", "antimouse_core.log")
            }

            ; Reset selection state
            StateMap["firstKey"] := ""
            StateMap["activeCellKey"] := ""
            StateMap["activeSubCellKey"] := ""

            ; Return to the main grid
            TransitionToState(State_GRID_VISIBLE)
            return
        }
    }

    ; Process based on current state
    if (currentState = State_GRID_VISIBLE) {
        ; S1.5.1 DIAGNOSTIC: Grid key check path tracing
        LogToFile(Format(
            "S1.5.1 DIAGNOSTIC | ProcessKeyPress - GRID_VISIBLE state | About to check if '{}' is a grid key",
            key), "antimouse_diagnostic.log")

        ; Process grid key press
        isGridKey := CheckIfGridKey(key)

        ; S1.5.1 DIAGNOSTIC: Grid key check result
        LogToFile(Format("S1.5.1 DIAGNOSTIC | ProcessKeyPress - CheckIfGridKey result | key='{}' is grid key: {}",
            key, isGridKey), "antimouse_diagnostic.log")

        if (isGridKey) {
            ; S1.5.1 DIAGNOSTIC: About to call HandleKey
            LogToFile(Format("S1.5.1 DIAGNOSTIC | ProcessKeyPress - About to call HandleKey for key='{}'",
                key), "antimouse_diagnostic.log")

            HandleKey(key)

            ; S1.5.1 DIAGNOSTIC: After HandleKey execution
            LogToFile(Format(
                "S1.5.1 DIAGNOSTIC | ProcessKeyPress - After HandleKey | firstKey='{}' | currentState='{}'",
                StateMap.Get('firstKey', ""), currentState), "antimouse_diagnostic.log")
        }
    }
    else if (currentState = State_SUBGRID_STANDARD) {
        ; S1.5.1 DIAGNOSTIC: Subgrid standard state path
        LogToFile(Format(
            "S1.5.1 DIAGNOSTIC | ProcessKeyPress - SUBGRID_STANDARD state | Checking if '{}' is a subgrid key",
            key), "antimouse_diagnostic.log")

        ; First check if it's a valid subgrid key
        if (IsSubGridKey(key)) {
            LogToFile(Format(
                "S1.5.1 DIAGNOSTIC | ProcessKeyPress - '{}' is a valid subgrid key, calling ProcessStandardSubgridKey",
                key), "antimouse_diagnostic.log")
            ProcessStandardSubgridKey(key)
            return
        }

        ; If not a subgrid key, check if it's a grid key
        isGridKey := CheckIfGridKey(key)
        if (isGridKey) {
            ; Task 5.10: ROBUST FIX - Always start a new selection with grid keys when in subgrid state
            ; This simplifies the flow and prevents crashes during multiple key presses (A->S->P)

            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Timestamp: {} | Task: 5.10 | ROBUST FIX | ProcessKeyPress: Grid key '{}' in SUBGRID_STANDARD - Starting new selection",
                    A_TickCount, key), "antimouse_core.log")
            }

            ; S1.5.1 DIAGNOSTIC: Starting new selection from subgrid state
            LogToFile(Format(
                "S1.5.1 DIAGNOSTIC | ProcessKeyPress - Grid key '{}' in SUBGRID_STANDARD - Calling StartNewSelection",
                key), "antimouse_diagnostic.log")

            ; Start new selection with this key - no checking if it's part of current cell
            StartNewSelection(key)
            return
        }
    }
    else if (currentState = State_SUBGRID_ULTRAFAST) {
        ; S1.5.1 DIAGNOSTIC: Ultrafast state path
        LogToFile(Format("S1.5.1 DIAGNOSTIC | ProcessKeyPress - SUBGRID_ULTRAFAST state | Checking key '{}'",
            key), "antimouse_diagnostic.log")

        ; First check if it's a valid ultrafast subgrid key
        if (IsUltraFastSubGridKey(key)) {
            LogToFile(Format(
                "S1.5.1 DIAGNOSTIC | ProcessKeyPress - '{}' is a valid ultrafast key, calling ProcessUltraFastKey",
                key), "antimouse_diagnostic.log")
            ProcessUltraFastKey(key)
            return
        }

        ; If not an ultrafast key, check if it's a grid key
        isGridKey := CheckIfGridKey(key)
        if (isGridKey) {
            ; Task 5.10: ROBUST FIX - Always start a new selection with grid keys when in subgrid state
            ; This simplifies the flow and prevents crashes during multiple key presses (A->S->P)

            if (enableVerboseLogging) {
                LogToFile(Format(
                    "Timestamp: {} | Task: 5.10 | ROBUST FIX | ProcessKeyPress: Grid key '{}' in SUBGRID_ULTRAFAST - Starting new selection",
                    A_TickCount, key), "antimouse_core.log")
            }

            ; S1.5.1 DIAGNOSTIC: Starting new selection from ultrafast state
            LogToFile(Format(
                "S1.5.1 DIAGNOSTIC | ProcessKeyPress - Grid key '{}' in SUBGRID_ULTRAFAST - Calling StartNewSelection",
                key), "antimouse_diagnostic.log")

            ; Start new selection with this key - no checking if it's part of current cell
            StartNewSelection(key)
            return
        }
    }
    else if (currentState == State_IDLE) {
        ; S1.5.1 DIAGNOSTIC: Idle state path
        LogToFile(Format("S1.5.1 DIAGNOSTIC | ProcessKeyPress - IDLE state | Key '{}' ignored",
            key), "antimouse_diagnostic.log")

        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | ProcessKeyPress: Key press ignored in IDLE state",
                A_TickCount) "`n", "antimouse_core.log")
        }
    }
    else {
        ; S1.5.1 DIAGNOSTIC: Unknown state path
        LogToFile(Format("S1.5.1 DIAGNOSTIC | ProcessKeyPress - UNKNOWN state '{}' | Key '{}' ignored",
            currentState, key), "antimouse_diagnostic.log")

        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | ProcessKeyPress: Unhandled state: '{}'",
                A_TickCount, currentState) "`n", "antimouse_core.log")
        }
    }

    ; S1.5.1 DIAGNOSTIC: ProcessKeyPress exit path
    LogToFile(Format(
        "S1.5.1 DIAGNOSTIC | ProcessKeyPress EXIT | key='{}' | currentState='{}' | firstKey='{}' | IsObject(highlight)={} | IsObject(subGrid)={}",
        key, currentState, StateMap.Get('firstKey', ""), IsObject(highlight), IsObject(subGrid)),
    "antimouse_diagnostic.log")

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | ProcessKeyPress END | key={} | currentState={}", A_TickCount, key,
            currentState) "`n",
        "antimouse_core.log")
    }
}

; Check if key is a valid grid key (column or row key)
CheckIfGridKey(key) {
    global StateMap, showcaseDebug

    ; S1.5.1 DIAGNOSTIC: CheckIfGridKey entry
    LogToFile(Format("S1.5.1 DIAGNOSTIC | CheckIfGridKey ENTRY | key='{}' | Have activeColKeys={}, activeRowKeys={}",
        key, StateMap.Has("activeColKeys"), StateMap.Has("activeRowKeys")), "antimouse_diagnostic.log")

    ; Get active keys from StateMap
    activeColKeys := StateMap["activeColKeys"]
    activeRowKeys := StateMap["activeRowKeys"]

    isGridKey := false

    ; Check if key is in active column or row keys
    for index, colKey in activeColKeys {
        if (colKey = key) {
            isGridKey := true
            LogToFile(Format("S1.5.1 DIAGNOSTIC | CheckIfGridKey found | '{}' is a COLUMN key at index {}",
                key, index), "antimouse_diagnostic.log")
            break
        }
    }

    if (!isGridKey) {
        for index, rowKey in activeRowKeys {
            if (rowKey = key) {
                isGridKey := true
                LogToFile(Format("S1.5.1 DIAGNOSTIC | CheckIfGridKey found | '{}' is a ROW key at index {}",
                    key, index), "antimouse_diagnostic.log")
                break
            }
        }
    }

    if (showcaseDebug) {
        LogToFile(Format("CheckIfGridKey: Key '{}' is a grid key: {}", key, isGridKey), "antimouse_keypress.log")
    }

    ; S1.5.1 DIAGNOSTIC: CheckIfGridKey exit
    LogToFile(Format("S1.5.1 DIAGNOSTIC | CheckIfGridKey EXIT | key='{}' is grid key: {}",
        key, isGridKey), "antimouse_diagnostic.log")

    return isGridKey
}

; Helper function to check if a key is a valid subgrid key
IsSubGridKey(key) {
    ; In standard subgrid, GHBN are the valid keys
    return key == "g" || key == "h" || key == "b" || key == "n"
}

; Helper function to check if a key is a valid ultrafast subgrid key
IsUltraFastSubGridKey(key) {
    ; In ultrafast subgrid, QWERASDFZXCV are valid keys
    validKeys := "qwerasdfzxcv"
    return InStr(validKeys, key) > 0
}

; Original IsGridKey left intact for compatibility with any other callers
IsGridKey(key) {
    return CheckIfGridKey(key)
}

; Handler for standard subgrid key presses (GHBN)
HandleStandardSubgridKey(key) {
    ; Simply call our actual implementation with a different name to avoid conflicts
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | HandleStandardSubgridKey: Calling ProcessStandardSubgridKey for key='{}'",
            A_TickCount, key) "`n",
        "antimouse_core.log")
    }
    ProcessStandardSubgridKey(key)
}

; Note: The HandleUltraFastKey is defined in subgrid_keys.ahk

; <<< --- REMOVED DUPLICATE HandleKey FUNCTION --- >>>
