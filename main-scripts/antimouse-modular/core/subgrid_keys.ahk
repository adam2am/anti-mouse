; ==============================================================================
; core/subgrid_keys.ahk - Subgrid Key Handling Logic (Standard & Ultra-Fast)
; ==============================================================================

HandleSubGridKey(subKey) {
    try {
        global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
            showcaseDebug, instaClickMode, g_ModifierState, highlight

        ; Special handling for instaclick mode - always handle key events even when CapsLock is held
        if (instaClickMode && g_ModifierState.inHoldMode) {
            ; Process key normally, even though CapsLock is being held
        }

        if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid)) {
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

; Handle key presses in Ultra-Fast mode
HandleUltraFastKey(key) {
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
        showcaseDebug, instaClickMode, g_ModifierState, highlight ; Added highlight global

    ; Only process in the correct state with a valid subgrid
    if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid) || !StateMap['inUltraFastMode']) {
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
                FileAppend(Format("Timestamp: {} | HandleUltraFastKey: Updating and Showing Highlight.", A_TickCount) "`n",
                "antimouse_core.log")
                highlight.Update(mainCellBoundaries.x, mainCellBoundaries.y, mainCellBoundaries.w,
                    mainCellBoundaries.h
                )
            }
        } else {
            FileAppend(Format(
                "Timestamp: {} | HandleUltraFastKey: WARNING - Highlight or currentOverlay object invalid.",
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
