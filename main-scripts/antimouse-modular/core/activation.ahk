; Start a new selection process when a grid key is pressed while subgrid is active
StartNewSelection(key) {
    global currentState, subGrid, highlight, StateMap, g_firstKeyPressed ; REMOVED keyProcessingLock

    ; --- CORE LOGGING START --- Task: 2.13 (Start New Selection Refinement)
    FileAppend(Format("Timestamp: {} | Task: 2.13 | StartNewSelection START | key={}", A_TickCount, key) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>> Task: 2.13
    FileAppend(Format(
        "Timestamp: {} | Task: 2.13 | DIAGNOSTIC | StartNewSelection: key='{}', currentState='{}', g_firstKeyPressed='{}'", ; REMOVED lock log
        A_TickCount, key, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    ; Temporarily disable TrackCursor
    SetTimer(TrackCursor, 0)

    ; Check if the state is appropriate for starting anew
    if (currentState != State_SUBGRID_STANDARD && currentState != State_SUBGRID_ULTRAFAST) {
        FileAppend(Format(
            "Timestamp: {} | Task: 2.13 | WARNING | StartNewSelection: Called in inappropriate state '{}'. Exiting.",
            A_TickCount, currentState) "`n", "antimouse_core.log")
        SetTimer(TrackCursor, 50) ; Re-enable tracking before returning
        return
    }

    ; Hide the subgrid and highlight first
    if (IsObject(subGrid)) {
        subGrid.Hide()
        FileAppend(Format("Timestamp: {} | Task: 2.13 | GUI | Hiding subGrid in StartNewSelection", A_TickCount) "`n",
        "antimouse_core.log")
    }
    if (IsObject(highlight)) {
        highlight.Hide()
        FileAppend(Format("Timestamp: {} | Task: 2.13 | GUI | Hiding highlight in StartNewSelection", A_TickCount) "`n",
        "antimouse_core.log")
    }

    ; Reset state variables BEFORE transitioning
    StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    g_firstKeyPressed := "" ; Explicitly reset the global first key tracker
    StateMap['firstKey'] := ""    ; Also reset in StateMap for consistency
    StateMap['activeRowKey'] := "" ; Reset active row key used for ultra-fast

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>> Task: 2.13
    FileAppend(Format(
        "Timestamp: {} | Task: 2.13 | DIAGNOSTIC | StartNewSelection: Resetting g_firstKeyPressed from '{}' to '{}'",
        A_TickCount, StateMap['firstKey'], g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    ; *** Transition state back to GRID_VISIBLE BEFORE calling HandleKey ***
    TransitionToState(State_GRID_VISIBLE)

    newState := currentState ; Get state *after* transition for logging

    ; Force a small delay - might still be useful
    Sleep(10)

    ; Call HandleKey to process the key press as the start of a NEW selection
    ; Pass 'true' to bypass HandleKey's initial state check
    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>> Task: 2.13
    FileAppend(Format(
        "Timestamp: {} | Task: 2.13 | DIAGNOSTIC | StartNewSelection: Calling HandleKey('{}', true) in state '{}' (after transition)",
        A_TickCount, key, newState) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    HandleKey(key, true) ; Pass true to bypass initial state check

    ; TrackCursor re-enabled within HandleKey if it proceeds
}

; Clean up all GUI elements and reset state to IDLE
Cleanup() {
    global currentState, highlight, subGrid, StateMap, g_ModifierState, gridActivationInProgress, activeCleanup

    ; --- CORE LOGGING START --- Task: 2.14 (Cleanup Refinement)
    FileAppend(Format("Timestamp: {} | Task: 2.14 | Cleanup START | Current State={}", A_TickCount, currentState) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; Prevent re-entry if cleanup is already running
    if (activeCleanup) {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | WARNING | Cleanup already in progress. Ignoring request.",
            A_TickCount) "`n", "antimouse_core.log")
        return
    }
    activeCleanup := true

    initialState := currentState ; Log the state before changing it

    ; Set state to IDLE immediately to prevent re-entry into active states
    currentState := State_IDLE
    if (initialState != State_IDLE) {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | STATE | Setting currentState = IDLE (from {}).", A_TickCount,
            initialState) "`n", "antimouse_core.log")
    }

    ; First stop the cursor tracking to prevent recreation
    FileAppend(Format("Timestamp: {} | Task: 2.14 | TIMER | Stopping TrackCursor timer.", A_TickCount) "`n",
    "antimouse_core.log")
    SetTimer(TrackCursor, 0)

    ; Clear any tooltips
    ToolTip()

    ; Reset instaclick flags for extra reliability
    if (g_ModifierState.inHoldMode) {
        FileAppend(Format("Timestamp: {} | Task: 3.1 | STATE | Resetting inHoldMode from true to false.", A_TickCount) "`n",
        "antimouse_core.log")
        g_ModifierState.inHoldMode := false
    }

    ; Reset grid activation flag
    if (gridActivationInProgress) {
        FileAppend(Format("Timestamp: {} | Task: 1.1 | STATE | Resetting gridActivationInProgress from true to false.",
            A_TickCount) "`n", "antimouse_core.log")
        gridActivationInProgress := false
    }

    ; Hide elements before destroying them - with error checking and logging
    hideStart := A_TickCount
    try {
        if (IsObject(highlight)) {
            FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding highlight.", A_TickCount) "`n",
            "antimouse_core.log")
            highlight.Hide()
        }
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | ERROR | Hiding highlight failed: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
    }

    try {
        if (IsObject(subGrid)) {
            FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding subGrid.", A_TickCount) "`n",
            "antimouse_core.log")
            subGrid.Hide()
        }
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding subGrid failed: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
    }

    try {
        if (IsObject(StateMap['overlays'])) {
            FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding main grid overlays.", A_TickCount) "`n",
            "antimouse_core.log")
            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    overlay.Hide()
                }
            }
        }
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Hiding main overlays failed: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
    }

    FileAppend(Format("Timestamp: {} | Task: 2.14 | PERF | GUI Hide phase took {} ms.", A_TickCount, A_TickCount -
        hideStart) "`n", "antimouse_core.log")

    ; Short delay to ensure GUIs have time to hide before destruction
    Sleep(30)

    ; Now destroy GUIs - with individual try/catch blocks and logging
    destroyStart := A_TickCount
    try {
        if (IsObject(highlight)) {
            FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Destroying highlight object.", A_TickCount) "`n",
            "antimouse_core.log")
            highlight.Destroy()
            highlight := "" ; Clear variable
        }
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | ERROR | Destroying highlight failed: {}", A_TickCount, e.Message
        ) "`n", "antimouse_core.log")
        highlight := "" ; Still try to clear variable
    }

    try {
        if (IsObject(subGrid)) {
            FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Destroying subGrid object.", A_TickCount) "`n",
            "antimouse_core.log")
            subGrid.Destroy()
            subGrid := "" ; Clear variable
        }
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | ERROR | Destroying subGrid failed: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
        subGrid := "" ; Still try to clear variable
    }

    try {
        if (IsObject(StateMap['overlays'])) {
            FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Destroying main grid overlay objects.", A_TickCount) "`n",
            "antimouse_core.log")
            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    overlay.Destroy()
                }
            }
            StateMap['overlays'] := [] ; Clear the array
            FileAppend(Format("Timestamp: {} | Task: 2.14 | STATE | Cleared StateMap overlays array.", A_TickCount) "`n",
            "antimouse_core.log")
        }
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | ERROR | Destroying main overlays failed: {}", A_TickCount, e.Message
        ) "`n", "antimouse_core.log")
        StateMap['overlays'] := [] ; Still try to clear array
    }
    StateMap['currentOverlay'] := "" ; Always clear current overlay ref

    FileAppend(Format("Timestamp: {} | Task: 2.14 | PERF | GUI Destroy phase took {} ms.", A_TickCount, A_TickCount -
        destroyStart) "`n", "antimouse_core.log")

    ; Reset remaining state map items that should be cleared on cleanup
    stateResetStart := A_TickCount
    StateMap['firstKey'] := ""
    StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    StateMap['currentColIndex'] := 0
    StateMap['currentRowIndex'] := 0
    StateMap['lastSelectedRowIndex'] := 0
    StateMap['activeRowKey'] := ""
    g_firstKeyPressed := "" ; Ensure global is also clear
    FileAppend(Format("Timestamp: {} | Task: 2.14 | STATE | StateMap and g_firstKeyPressed reset.", A_TickCount) "`n",
    "antimouse_core.log")
    FileAppend(Format("Timestamp: {} | Task: 2.14 | PERF | State Reset phase took {} ms.", A_TickCount, A_TickCount -
        stateResetStart) "`n", "antimouse_core.log")

    ; Force Close potentially remaining GUIs as a final safety net
    forceCloseStart := A_TickCount
    try {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | GUI | Attempting ForceCloseAllGuis (Safety Net).", A_TickCount) "`n",
        "antimouse_core.log")
        ForceCloseAllGuis()
    } catch as e {
        FileAppend(Format("Timestamp: {} | Task: 2.14 | ERROR | ForceCloseAllGuis failed: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
    }
    FileAppend(Format("Timestamp: {} | Task: 2.14 | PERF | Force Close phase took {} ms.", A_TickCount, A_TickCount -
        forceCloseStart) "`n", "antimouse_core.log")

    ; Final sleep to ensure cleanup is complete before releasing lock
    Sleep(10)

    ; Release the cleanup lock
    activeCleanup := false

    ; --- CORE LOGGING START --- Task: 2.14
    FileAppend(Format("Timestamp: {} | Task: 2.14 | Cleanup END | Final State={}", A_TickCount, currentState) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---
}
