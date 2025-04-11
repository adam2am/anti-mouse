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

; Central function called by hotkeys to route key presses to the appropriate handler based on the current state.
ProcessKeyPress(key) {
    global StateMap, currentState, showcaseDebug, g_firstKeyPressed ; Reference variables defined in state.ahk and config.ahk
    global enableVerboseLogging ; Added
    global navigationKey, enableFreeNavigation ; Task 2.16: Free Cell Navigation

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
        ; Process grid key press
        isGridKey := CheckIfGridKey(key)
        if (isGridKey) {
            HandleKey(key)
        }
    }
    else if (currentState = State_SUBGRID_STANDARD) {
        ; First check if it's a valid subgrid key
        if (IsSubGridKey(key)) {
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

            ; Start new selection with this key - no checking if it's part of current cell
            StartNewSelection(key)
            return
        }
    }
    else if (currentState = State_SUBGRID_ULTRAFAST) {
        ; First check if it's a valid ultrafast subgrid key
        if (IsUltraFastSubGridKey(key)) {
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

            ; Start new selection with this key - no checking if it's part of current cell
            StartNewSelection(key)
            return
        }
    }
    else if (currentState == State_IDLE) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | ProcessKeyPress: Key press ignored in IDLE state",
                A_TickCount) "`n", "antimouse_core.log")
        }
    }
    else {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | ProcessKeyPress: Unhandled state: '{}'",
                A_TickCount, currentState) "`n", "antimouse_core.log")
        }
    }

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | ProcessKeyPress END | key={} | currentState={}", A_TickCount, key,
            currentState) "`n",
        "antimouse_core.log")
    }
}

; Check if key is a valid grid key (column or row key)
CheckIfGridKey(key) {
    global StateMap, showcaseDebug

    ; Get active keys from StateMap
    activeColKeys := StateMap["activeColKeys"]
    activeRowKeys := StateMap["activeRowKeys"]

    isGridKey := false

    ; Check if key is in active column or row keys
    for index, colKey in activeColKeys {
        if (colKey = key) {
            isGridKey := true
            break
        }
    }

    if (!isGridKey) {
        for index, rowKey in activeRowKeys {
            if (rowKey = key) {
                isGridKey := true
                break
            }
        }
    }

    if (showcaseDebug) {
        LogToFile(Format("CheckIfGridKey: Key '{}' is a grid key: {}", key, isGridKey), "antimouse_keypress.log")
    }

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
