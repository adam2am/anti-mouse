; ==============================================================================
; core/monitor.ahk - Monitor Switching Logic
; ==============================================================================

; Reference state constants defined in state.ahk
global State_IDLE, State_GRID_VISIBLE, State_SUBGRID_STANDARD, State_SUBGRID_ULTRAFAST

; Switches focus and cursor to a specific monitor number.
SwitchMonitor(monitorNum) {
    ; Access global state and config variables defined in state.ahk and config.ahk
    global currentState, highlight, subGrid, monitorMapping, storePerMonitor, StateMap, showcaseDebug, cellMemory

    ; Apply monitor mapping from config
    if (!monitorMapping.Has(monitorNum)) {
        if (showcaseDebug) ToolTip("Invalid physical monitor number: " monitorNum)
            return
    }
    mappedMonitor := monitorMapping[monitorNum]

    ; Check if mapped monitor index is valid and grid is active
    if (mappedMonitor > StateMap['overlays'].Length || currentState == State_IDLE) {
        if (showcaseDebug && currentState != State_IDLE) {
            ToolTip("Invalid mapped monitor index: " mappedMonitor)
        }
        return
    }

    ; Temporarily disable cursor tracking during the switch
    SetTimer(TrackCursor, 0)

    ; Get the target overlay object
    newOverlay := StateMap['overlays'][mappedMonitor]
    if (!IsObject(newOverlay)) {
        if (showcaseDebug) {
            ToolTip("Target overlay object not found for monitor " mappedMonitor)
        }
        SetTimer(TrackCursor, 50) ; Re-enable tracking if switch fails
        return
    }

    ; Remember current position state before switching
    rememberedColIndex := StateMap['currentColIndex']
    rememberedRowIndex := StateMap['currentRowIndex']
    wasInSubgrid := (currentState == State_SUBGRID_STANDARD || currentState == State_SUBGRID_ULTRAFAST)
    rememberedCellKey := StateMap['activeCellKey'] ; Remember the full cell key

    ; Hide UI elements during transition to prevent visual artifacts
    if (IsObject(highlight)) highlight.Hide()
        if (IsObject(subGrid)) subGrid.Hide()
            Sleep(20) ; Small delay for UI cleanup

    ; Update the current overlay in the state map
    StateMap['currentOverlay'] := newOverlay

    ; Attempt to restore position on the new monitor
    if (rememberedCellKey != "") { ; Use the remembered cell key
        ; Get boundaries for the *same cell key* on the *new* overlay
        boundaries := newOverlay.GetCellBoundaries(rememberedCellKey)

        if (IsObject(boundaries)) {
            ; Move cursor to the center of the corresponding cell on the new monitor
            centerX := boundaries.x + (boundaries.w // 2)
            centerY := boundaries.y + (boundaries.h // 2)
            MouseMove(centerX, centerY, 0)

            ; Update state BEFORE updating UI
            StateMap['activeCellKey'] := rememberedCellKey ; Keep the same cell key active
            ; Update indices based on the new overlay's keys (important if layouts differ)
            StateMap['currentColIndex'] := 0
            for i, k in StateMap['activeColKeys'] {
                if (SubStr(rememberedCellKey, 1, 1) = k) {
                    StateMap['currentColIndex'] := i
                    break
                }
            }
            StateMap['currentRowIndex'] := 0
            for i, k in StateMap['activeRowKeys'] {
                if (SubStr(rememberedCellKey, 2) = k) {
                    StateMap['currentRowIndex'] := i
                    StateMap['lastSelectedRowIndex'] := i
                    break
                }
            }

            ; Update highlight for the new cell position
            if (IsObject(highlight)) {
                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            }

            ; If we were in subgrid mode, update and potentially restore subgrid position
            if (wasInSubgrid && IsObject(subGrid)) {
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                TransitionToState(State_SUBGRID_STANDARD) ; Tentative: Restore to standard subgrid. May need refinement for ultra-fast.

                ; Check for remembered subcell (monitor-specific first, then general)
                rememberedSubCell := ""
                monitorCellKey := mappedMonitor . "_" . rememberedCellKey
                if (storePerMonitor && cellMemory.Has(monitorCellKey)) {
                    rememberedSubCell := cellMemory[monitorCellKey]
                } else if (cellMemory.Has(rememberedCellKey)) {
                    rememberedSubCell := cellMemory[rememberedCellKey]
                }

                ; If a subcell was remembered, move to it
                if (rememberedSubCell != "") {
                    ; FIX: Check for ultra: prefix when restoring subcell memory
                    if (SubStr(rememberedSubCell, 1, 6) == "ultra:") {
                        actualSubCellKey := SubStr(rememberedSubCell, 7)
                        HandleUltraFastKey(actualSubCellKey)
                    } else {
                        HandleSubGridKey(rememberedSubCell) ; Handle standard subcell
                    }
                }
            }
        } else {
            ; If the exact cell doesn't exist (e.g., different layout size), move to center
            centerX := newOverlay.Left + (newOverlay.width // 2)
            centerY := newOverlay.Top + (newOverlay.height // 2)
            MouseMove(centerX, centerY, 0)
            StateMap['activeCellKey'] := "" ; Clear active cell if it couldn't be found
        }
    } else {
        ; No cell was active, just move to the center of the new monitor
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        MouseMove(centerX, centerY, 0)
    }

    if (showcaseDebug) {
        ToolTip("Switched to Monitor " mappedMonitor " (physical: " monitorNum ")")
        Sleep(1000)
        ToolTip()
    }

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)
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
