; Start a new selection process when a grid key is pressed while subgrid is active
StartNewSelection(key) {
    global currentState, subGrid, highlight, StateMap, g_firstKeyPressed, keyProcessingLock ; Need lock too

    ; --- CORE LOGGING START --- Task: 2.13 (Start New Selection Refinement)
    FileAppend(Format("Timestamp: {} | Task: 2.13 | StartNewSelection START | key={}", A_TickCount, key) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>> Task: 2.13
    FileAppend(Format(
        "Timestamp: {} | Task: 2.13 | DIAGNOSTIC | StartNewSelection: key='{}', currentState='{}', g_firstKeyPressed='{}', lock={}",
        A_TickCount, key, currentState, g_firstKeyPressed, keyProcessingLock) "`n", "antimouse_core.log")
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
    }
    if (IsObject(highlight)) {
        highlight.Hide()
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

    ; *** FIX 1: Explicitly reset key processing lock ***
    keyProcessingLock := 0
    FileAppend(Format("Timestamp: {} | Task: 2.13 | DIAGNOSTIC | StartNewSelection: Reset keyProcessingLock to 0",
        A_TickCount) "`n", "antimouse_core.log")

    ; *** FIX 2: Transition state back to GRID_VISIBLE BEFORE calling HandleKey ***
    TransitionToState(State_GRID_VISIBLE)

    ; Get the state *after* transition to log correctly
    newState := currentState

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
