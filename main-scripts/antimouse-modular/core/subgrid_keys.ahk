; ==============================================================================
; core/subgrid_keys.ahk - Subgrid Key Handling Logic (Standard & Ultra-Fast)
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug

; Legacy function - renamed to avoid conflicts
HandleSubGridKey(subKey) {
    try {
        global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
            showcaseDebug, instaClickMode, g_ModifierState, highlight

        ; Special handling for instaclick mode - always handle key events even when CapsLock is held
        if (instaClickMode && g_ModifierState.inHoldMode) {
            ; Process key normally, even though CapsLock is being held
        }

        if (currentState != State_SUBGRID_STANDARD || !IsObject(subGrid)) {
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

; NEW FUNCTION WITH DIFFERENT NAME: This is the actual implementation for standard subgrid keys
ProcessStandardSubgridKey(key) {
    global currentState, StateMap, showcaseDebug, cellMemory, storePerMonitor, highlight

    ; --- CORE LOGGING START ---
    FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey START | key='{}'", A_TickCount, key) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; Get current time for logging
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey | key={} | currentState={}",
            currentTime, key, currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Verify we're in the correct state
    if (currentState != State_SUBGRID_STANDARD) {
        FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey: Wrong state='{}', expected '{}'",
            A_TickCount, currentState, State_SUBGRID_STANDARD) "`n", "antimouse_core.log")
        return
    }

    ; Verify we have an active cell
    if (!StateMap.Has('activeCellKey') || StateMap['activeCellKey'] == "") {
        FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey: No active cell key", A_TickCount) "`n",
        "antimouse_core.log")
        return
    }

    ; Get the cell boundaries
    boundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
    if (!IsObject(boundaries)) {
        FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey: Failed to get boundaries for cell '{}'",
            A_TickCount, StateMap['activeCellKey']) "`n", "antimouse_core.log")
        return
    }

    ; Calculate target position based on the GHBN key
    targetX := 0
    targetY := 0
    validKey := true

    ; Map GHBN keys to positions
    if (key = "g") {
        ; Upper left (1/4, 1/4)
        targetX := boundaries.x + (boundaries.w // 4)
        targetY := boundaries.y + (boundaries.h // 4)
    } else if (key = "h") {
        ; Upper right (3/4, 1/4)
        targetX := boundaries.x + (boundaries.w * 3 // 4)
        targetY := boundaries.y + (boundaries.h // 4)
    } else if (key = "b") {
        ; Lower left (1/4, 3/4)
        targetX := boundaries.x + (boundaries.w // 4)
        targetY := boundaries.y + (boundaries.h * 3 // 4)
    } else if (key = "n") {
        ; Lower right (3/4, 3/4)
        targetX := boundaries.x + (boundaries.w * 3 // 4)
        targetY := boundaries.y + (boundaries.h * 3 // 4)
    } else {
        validKey := false
    }

    ; If it's a valid subgrid key, move the mouse and update memory
    if (validKey) {
        ; Store subcell choice in memory
        StateMap['activeSubCellKey'] := key

        ; Create the key for cell memory
        memoryKey := storePerMonitor ? StateMap['currentMonitorIndex'] . "_" . StateMap['activeCellKey'] : StateMap[
            'activeCellKey']

        ; Remember this subcell choice for this cell
        cellMemory[memoryKey] := key

        ; Move mouse to target position
        MouseMove(targetX, targetY, 0)

        ; Log the action
        FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey: Moved to subkey='{}' at x={}, y={}",
            A_TickCount, key, targetX, targetY) "`n", "antimouse_core.log")

        ; Hide the subgrid after selection
        TransitionToState(State_IDLE)
    } else {
        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) {
            FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey: Invalid subgrid key '{}'",
                currentTime, key) "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        ; <<< ADD LOGGING END >>>
    }

    ; --- CORE LOGGING END ---
    FileAppend(Format("Timestamp: {} | ProcessStandardSubgridKey END | key='{}', validKey={}",
        A_TickCount, key, validKey) "`n", "antimouse_core.log")
}

; Handle key presses in Ultra-Fast mode (this is the main implementation)
ProcessUltraFastKey(key) {
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
        showcaseDebug, instaClickMode, g_ModifierState, highlight ; Added highlight global

    ; --- CORE LOGGING START ---
    FileAppend(Format("Timestamp: {} | ProcessUltraFastKey START | key='{}'", A_TickCount, key) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; Only process in the correct state with a valid subgrid
    if (currentState != State_SUBGRID_ULTRAFAST || !IsObject(subGrid) || !StateMap['inUltraFastMode']) {
        ; Log the reason and return
        FileAppend(Format(
            "Timestamp: {} | ProcessUltraFastKey: Invalid state or missing objects - state='{}', subGrid={}, inUltraFastMode={}",
            A_TickCount, currentState, IsObject(subGrid), StateMap['inUltraFastMode']) "`n", "antimouse_core.log")
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
                FileAppend(Format("Timestamp: {} | ProcessUltraFastKey: Updating and Showing Highlight.", A_TickCount) "`n",
                "antimouse_core.log")
                highlight.Update(mainCellBoundaries.x, mainCellBoundaries.y, mainCellBoundaries.w,
                    mainCellBoundaries.h
                )
            }
        } else {
            FileAppend(Format(
                "Timestamp: {} | ProcessUltraFastKey: WARNING - Highlight or currentOverlay object invalid.",
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

    ; --- CORE LOGGING END ---
    FileAppend(Format("Timestamp: {} | ProcessUltraFastKey END | key='{}'", A_TickCount, key) "`n",
    "antimouse_core.log")
}

; Routing function - called by ProcessKeyPress to route to the main implementation
HandleUltraFastKey(key) {
    ; Simply call our actual implementation
    FileAppend(Format("Timestamp: {} | HandleUltraFastKey: Calling ProcessUltraFastKey for key='{}'",
        A_TickCount, key) "`n", "antimouse_core.log")
    ProcessUltraFastKey(key)
}

; Handles the release of a row key in Ultra-Fast mode, switching back to standard mode
HandleRowKeyRelease(key) {
    global subGrid, StateMap, showcaseDebug, enableUltraFast, currentState ; Added currentState

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
