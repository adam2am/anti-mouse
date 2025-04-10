; ==============================================================================
; core/monitor.ahk - Monitor Switching Logic
; ==============================================================================

; Reference state constants defined in state.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST
; Reference state variables and config
global currentState, highlight, subGrid, monitorMapping, storePerMonitor, StateMap, showcaseDebug, cellMemory
global enableVerboseLogging ; Added

; Switches focus and cursor to a specific monitor number.
SwitchMonitor(monitorNum) {
    ; Access global state and config variables defined in state.ahk and config.ahk
    global currentState, highlight, subGrid, monitorMapping, storePerMonitor, StateMap, showcaseDebug, cellMemory,
        enableVerboseLogging ; Added enableVerboseLogging

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor START | monitorNum={} | currentState={}", A_TickCount,
            monitorNum,
            currentState) "`n", "antimouse_core.log")
    }

    ; Apply monitor mapping from config
    if (!monitorMapping.Has(monitorNum)) {
        if (showcaseDebug) ToolTip("Invalid physical monitor number: " monitorNum)
            if (enableVerboseLogging) { ; <<< WRAPPED
                LogToFile(Format("Timestamp: {} | SwitchMonitor: Invalid physical monitor number {}. Exiting.",
                    A_TickCount,
                    monitorNum) "`n", "antimouse_core.log")
            }
        return
    }
    mappedMonitor := monitorMapping[monitorNum]
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor: Mapped physical monitor {} to logical monitor {}.",
            A_TickCount,
            monitorNum, mappedMonitor) "`n", "antimouse_core.log")
    }

    ; Check if mapped monitor index is valid and grid is active
    if (mappedMonitor > StateMap['overlays'].Length || currentState == State_IDLE) {
        if (showcaseDebug && currentState != State_IDLE) {
            ToolTip("Invalid mapped monitor index: " mappedMonitor)
        }
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | SwitchMonitor: Invalid mapped index {} or grid not active (State={}). Exiting.",
                A_TickCount, mappedMonitor, currentState) "`n", "antimouse_core.log")
        }
        return
    }

    ; Check if already on the target monitor
    if (IsObject(StateMap['currentOverlay']) && StateMap['currentOverlay'].monitorIndex == mappedMonitor) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | SwitchMonitor: Already on target monitor {}. Exiting.", A_TickCount,
                mappedMonitor) "`n", "antimouse_core.log")
        }
        return ; Already on the correct monitor
    }

    ; Temporarily disable cursor tracking during the switch
    SetTimer(TrackCursor, 0)

    ; Get the target overlay object
    newOverlay := StateMap['overlays'][mappedMonitor]
    if (!IsObject(newOverlay)) {
        if (showcaseDebug) {
            ToolTip("Target overlay object not found for monitor " mappedMonitor)
        }
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format(
                "Timestamp: {} | SwitchMonitor: ERROR - Target overlay object not found for monitor {}. Aborting switch.",
                A_TickCount, mappedMonitor) "`n", "antimouse_core.log")
        }
        SetTimer(TrackCursor, 50) ; Re-enable tracking if switch fails
        return
    }

    ; Remember current position state before switching
    rememberedColIndex := StateMap['currentColIndex']
    rememberedRowIndex := StateMap['currentRowIndex']
    wasInSubgrid := (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST)
    rememberedCellKey := StateMap['activeCellKey'] ; Remember the full cell key

    ; --- Hide elements on the OLD monitor --- (Safety measure)
    if (IsObject(StateMap['currentOverlay'])) {
        StateMap['currentOverlay'].Hide() ; Hide the overlay itself
    }
    if (IsObject(highlight)) {
        highlight.Hide() ; Hide highlight
    }
    if (IsObject(subGrid)) {
        subGrid.Hide() ; Hide subgrid
    }

    ; Update current overlay reference
    StateMap['currentOverlay'] := newOverlay
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor: Set currentOverlay to Monitor {}.", A_TickCount,
            mappedMonitor)
        "`n", "antimouse_core.log")
    }

    ; --- Show elements on the NEW monitor --- (Before moving mouse)
    newOverlay.Show()
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor: Shown overlay for Monitor {}.", A_TickCount, mappedMonitor) "`n",
        "antimouse_core.log")
    }

    ; Move mouse to the center of the new monitor
    monX := 0, monY := 0, monW := 0, monH := 0
    MonitorGetWorkArea(mappedMonitor, &monX, &monY, &monW, &monH)
    centerX := monX + (monW // 2)
    centerY := monY + (monH // 2)
    MouseMove(centerX, centerY, 0)
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor: Moved mouse to center of Monitor {}: ({}, {}).", A_TickCount,
            mappedMonitor, centerX, centerY) "`n", "antimouse_core.log")
    }

    ; --- Restore State on New Monitor --- (Based on what state we were in)
    StateMap['firstKey'] := "" ; Always reset partial selection
    g_firstKeyPressed := ""
    StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    StateMap['inUltraFastMode'] := false
    StateMap['activeRowKey'] := ""

    ; Transition to GRID_VISIBLE state on the new monitor
    ; This ensures the grid is shown correctly, and subgrids/highlights are hidden initially.
    TransitionToState(State_GRID_VISIBLE)
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor: Transitioned to GRID_VISIBLE on new monitor.", A_TickCount) "`n",
        "antimouse_core.log")
    }

    ; Potentially restore highlight or subgrid based on remembered state (Optional/Complex)
    ; For now, just start fresh in GRID_VISIBLE on the new monitor.
    ; Example (if restoring highlight was needed):
    ; if (!wasInSubgrid && rememberedCellKey != "") { ... GetCellAtPosition(centerX, centerY) ... highlight.Update(...) ... }

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)

    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | SwitchMonitor END | New Monitor={} | State={}", A_TickCount, mappedMonitor,
            currentState) "`n", "antimouse_core.log")
    }
}

; Cycles focus and cursor to the next available monitor.
CycleToNextMonitor() {
    ; Access global state variables defined in state.ahk
    global currentState, StateMap, monitorMapping

    ; Don't cycle if idle or only one monitor overlay exists
    if (currentState == State_IDLE || StateMap['overlays'].Length <= 1) {
        return
    }

    ; Find the current monitor's physical index (needed for SwitchMonitor)
    currentOverlay := StateMap['currentOverlay']
    currentPhysicalIndex := 0
    for physIdx, mapIdx in monitorMapping {
        if (mapIdx == currentOverlay.monitorIndex) {
            currentPhysicalIndex := physIdx
            break
        }
    }

    if (currentPhysicalIndex == 0) {
        return ; Should not happen if state is consistent
    }

    ; --- Simpler Logic for finding next physical index ---
    allPhysicalIndices := []
    for physIdx in monitorMapping.OwnKeys() {
        allPhysicalIndices.Push(Integer(physIdx)) ; Ensure they are numbers for sorting
    }
    allPhysicalIndices.Sort()

    currentIndexInSorted := -1
    loop allPhysicalIndices.Length {
        if (allPhysicalIndices[A_Index] == currentPhysicalIndex) {
            currentIndexInSorted := A_Index
            break
        }
    }

    if (currentIndexInSorted == -1) {
        return ; Current index not found?
    }

    nextIndexInSorted := Mod(currentIndexInSorted, allPhysicalIndices.Length) + 1
    nextPhysicalIndex := allPhysicalIndices[nextIndexInSorted]
    ; --- End Simpler Logic ---

    ; Call SwitchMonitor with the next physical index
    SwitchMonitor(nextPhysicalIndex)
}
