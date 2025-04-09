; Start a new selection process when a grid key is pressed while subgrid is active
StartNewSelection(key) {
    global currentState, subGrid, highlight, StateMap, g_firstKeyPressed ; Need g_firstKeyPressed too

    ; --- CORE LOGGING START ---
    FileAppend(Format("Timestamp: {} | StartNewSelection START | key={}", A_TickCount, key) "`n", "antimouse_core.log")
    ; --- CORE LOGGING END ---

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | StartNewSelection: key='{}', currentState='{}', g_firstKeyPressed='{}'",
        A_TickCount, key, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    ; Temporarily disable TrackCursor
    SetTimer(TrackCursor, 0)

    ; Check if the state is appropriate for starting anew
    if (currentState != State_SUBGRID_STANDARD && currentState != State_SUBGRID_ULTRAFAST) {
        FileAppend(Format(
            "Timestamp: {} | WARNING | StartNewSelection: Called in inappropriate state '{}'. Exiting.",
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

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | StartNewSelection: Resetting g_firstKeyPressed from '{}' to '{}'",
        A_TickCount, StateMap['firstKey'], g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    ; *** FIX: Transition state back to GRID_VISIBLE BEFORE calling HandleKey ***
    TransitionToState(State_GRID_VISIBLE)

    ; Force a small delay to ensure state transitions properly (might not be needed if state transition handles it)
    Sleep(10)

    ; Call HandleKey to process the key press as the start of a NEW selection
    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | StartNewSelection: Calling HandleKey('{}') in new state '{}'",
        A_TickCount, key, currentState) "`n", "antimouse_core.log") ; currentState should now be GRID_VISIBLE
    ; <<< ENHANCED DIAGNOSTIC LOGGING END ---

    HandleKey(key)

    ; TrackCursor re-enabled within HandleKey if it proceeds, otherwise enable here?
    ; SetTimer(TrackCursor, 50) ; Let HandleKey manage this
}
