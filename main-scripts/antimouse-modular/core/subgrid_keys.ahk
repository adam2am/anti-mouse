; ==============================================================================
; core/subgrid_keys.ahk - Subgrid Key Handling Logic (Standard & Ultra-Fast)
; ==============================================================================

; Reference state constants and variables defined in state.ahk and config.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST, State_CELL_SELECTED
global StateMap, currentState, showcaseDebug, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay
global instaClickMode, g_ModifierState, highlight
global enableVerboseLogging ; Added

; Legacy function - renamed to avoid conflicts
HandleSubGridKey(subKey) {
    ; THIS IS LEGACY - Use ProcessStandardSubgridKey or ProcessUltraFastSubgridKey
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format(
            "Timestamp: {} | WARNING: Legacy HandleSubGridKey called for key '{}'. Redirecting based on state.",
            A_TickCount, subKey) "`n", "antimouse_core.log")
    }
    if (currentState == State_SUBGRID_STANDARD) {
        ProcessStandardSubgridKey(subKey)
    } else if (currentState == State_SUBGRID_ULTRAFAST) {
        ProcessUltraFastSubgridKey(subKey)
    }
}

; --- Standard Subgrid Key Processing ---
ProcessStandardSubgridKey(subKey) {
    global currentState, subGrid, StateMap, stateTransitionTime, stateTransitionDelay, showcaseDebug, highlight,
        enableVerboseLogging ; Added enableVerboseLogging

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.11 | ProcessStandardSubgridKey START | subKey={}", A_TickCount,
            subKey) "`n", "antimouse_core.log")
    }

    if (currentState != State_SUBGRID_STANDARD || !IsObject(subGrid)) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 2.11 | ProcessStandardSubgridKey: Invalid state ('{}') or subGrid object. Exiting.",
                A_TickCount, currentState) "`n", "antimouse_core.log")
        }
        return
    }

    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition < stateTransitionDelay) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 2.11 | ProcessStandardSubgridKey: Debounced ({}ms < {}ms). Exiting.",
                A_TickCount, timeSinceTransition, stateTransitionDelay) "`n", "antimouse_core.log")
        }
        return
    }

    targetCoords := subGrid.GetTargetCoordinates(subKey)
    if (!IsObject(targetCoords)) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | Task: 2.11 | ProcessStandardSubgridKey: Invalid subKey '{}'. Exiting.",
                A_TickCount, subKey) "`n", "antimouse_core.log")
        }
        if (showcaseDebug) {
            ToolTip("Invalid sub-key: " subKey)
            SetTimer(() => ToolTip(), -1000)
        }
        return
    }

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.11 | DIAGNOSTIC | Moving mouse to subgrid coords: x={}, y={}",
            A_TickCount, targetCoords.x, targetCoords.y) "`n", "antimouse_core.log")
    }
    MouseMove(targetCoords.x, targetCoords.y, 0)
    StateMap['activeSubCellKey'] := subKey

    UpdateCellMemory(StateMap['activeCellKey'], subKey)

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format(
            "Timestamp: {} | Task: 5.0 | ProcessStandardSubgridKey: Placeholder for mouse click at ({}, {}).",
            A_TickCount, targetCoords.x, targetCoords.y) "`n", "antimouse_core.log")
    }

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.11 | ProcessStandardSubgridKey END | subKey={} | State after={}",
            A_TickCount, subKey, currentState) "`n", "antimouse_core.log")
    }
}

; --- Ultra-Fast Subgrid Key Processing ---
ProcessUltraFastSubgridKey(subKey) {
    global currentState, subGrid, StateMap, showcaseDebug, highlight, enableVerboseLogging ; Added enableVerboseLogging

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.12 | ProcessUltraFastSubgridKey START | subKey={}", A_TickCount,
            subKey) "`n", "antimouse_core.log")
    }

    if (currentState != State_SUBGRID_ULTRAFAST || !StateMap['inUltraFastMode']) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 2.12 | ProcessUltraFastSubgridKey: Invalid state ('{}') or not inUltraFastMode. Exiting.",
                A_TickCount, currentState) "`n", "antimouse_core.log")
        }
        return
    }

    targetCoords := subGrid.GetTargetCoordinates(subKey, true)
    if (!IsObject(targetCoords)) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | Task: 2.12 | ProcessUltraFastSubgridKey: Invalid ultra-fast subKey '{}'. Exiting.",
                A_TickCount, subKey) "`n", "antimouse_core.log")
        }
        if (showcaseDebug) {
            ToolTip("Invalid ultra-fast sub-key: " subKey)
            SetTimer(() => ToolTip(), -1000)
        }
        return
    }

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.12 | DIAGNOSTIC | Moving mouse to subgrid coords: x={}, y={}",
            A_TickCount, targetCoords.x, targetCoords.y) "`n", "antimouse_core.log")
    }
    MouseMove(targetCoords.x, targetCoords.y, 0)
    StateMap['activeSubCellKey'] := subKey

    UpdateCellMemory(StateMap['activeCellKey'], subKey)

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format(
            "Timestamp: {} | Task: 5.0 | ProcessUltraFastSubgridKey: Placeholder for mouse click at ({}, {}).",
            A_TickCount, targetCoords.x, targetCoords.y) "`n", "antimouse_core.log")
    }

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 2.12 | ProcessUltraFastSubgridKey END | subKey={} | State after={}",
            A_TickCount, subKey, currentState) "`n", "antimouse_core.log")
    }
}

; --- Helper Functions ---
UpdateCellMemory(cellKey, subCellKey) {
    global cellMemory, storePerMonitor, StateMap, enableVerboseLogging ; Added enableVerboseLogging
    keyToUse := cellKey
    if (storePerMonitor) {
        ; Safety check for currentOverlay
        if (!IsObject(StateMap['currentOverlay'])) {
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format(
                    "Timestamp: {} | Task: 4.0 | UpdateCellMemory: WARNING - currentOverlay not valid object.",
                    A_TickCount) "`n", "antimouse_core.log")
            }
            return ; Cannot determine monitor index
        }
        monitorIndex := StateMap['currentOverlay'].monitorIndex
        keyToUse := monitorIndex "_" cellKey
    }
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | Task: 4.0 | UpdateCellMemory: Storing key='{}', subCellKey='{}'",
            A_TickCount,
            keyToUse, subCellKey) "`n", "antimouse_core.log")
    }
    cellMemory[keyToUse] := subCellKey
    ; Consider deferring SaveCellMemory() call if performance is an issue
}

; Handle key presses in Ultra-Fast mode (this is the main implementation)
ProcessUltraFastKey(key) {
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
        showcaseDebug, instaClickMode, g_ModifierState, highlight ; Added highlight global

    ; --- CORE LOGGING START ---
    LogToFile(Format("Timestamp: {} | ProcessUltraFastKey START | key='{}'", A_TickCount, key) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; Only process in the correct state with a valid subgrid
    if (currentState != State_SUBGRID_ULTRAFAST || !IsObject(subGrid) || !StateMap['inUltraFastMode']) {
        ; Log the reason and return
        LogToFile(Format(
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
                LogToFile(Format("Timestamp: {} | ProcessUltraFastKey: Updating and Showing Highlight.", A_TickCount) "`n",
                "antimouse_core.log")
                highlight.Update(mainCellBoundaries.x, mainCellBoundaries.y, mainCellBoundaries.w,
                    mainCellBoundaries.h
                )
            }
        } else {
            LogToFile(Format(
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
    LogToFile(Format("Timestamp: {} | ProcessUltraFastKey END | key='{}'", A_TickCount, key) "`n",
    "antimouse_core.log")
}

; Routing function - called by ProcessKeyPress to route to the main implementation
HandleUltraFastKey(key) {
    ; Simply call our actual implementation
    LogToFile(Format("Timestamp: {} | HandleUltraFastKey: Calling ProcessUltraFastKey for key='{}'",
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
        LogToFile(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Log Check condition
    if (showcaseDebug) {
        logMsg := Format(
            "Timestamp: {} | HandleRowKeyRelease: Check condition: enableUltraFast={}, inUltraFastMode={}, activeRowKey={}",
            A_TickCount, enableUltraFast, StateMap['inUltraFastMode'], StateMap['activeRowKey'])
        LogToFile(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }

    ; Only proceed if we're in Ultra-Fast mode and this is the key that activated it
    if (!enableUltraFast || !StateMap['inUltraFastMode'] || key != StateMap['activeRowKey']) {
        ; Log condition failed if applicable
        if (showcaseDebug && StateMap['inUltraFastMode']) {
            logMsg := Format(
                "Timestamp: {} | HandleRowKeyRelease: Condition FAILED for key={}. Expected activeRowKey={}",
                A_TickCount, key, StateMap['activeRowKey'])
            LogToFile(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Log Deactivation confirmation
    if (showcaseDebug) {
        logMsg := Format("Timestamp: {} | HandleRowKeyRelease: Deactivating ultra-fast mode for key={}", A_TickCount,
            key)
        LogToFile(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }

    ; Switch back to standard mode
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) LogToFile(Format(
        "Timestamp: {} | HandleRowKeyRelease: Setting inUltraFastMode=false (Before) | inUltraFastMode={}", A_TickCount,
        StateMap['inUltraFastMode']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
        StateMap['inUltraFastMode'] := false
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) LogToFile(Format(
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
    if (showcaseDebug) LogToFile(Format(
        "Timestamp: {} | HandleRowKeyRelease: Clearing activeRowKey (Before) | activeRowKey={}", A_TickCount, StateMap[
            'activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
        StateMap['activeRowKey'] := ""
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) LogToFile(Format(
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
