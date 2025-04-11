; ==============================================================================
; activation.ahk - Grid Activation and Cleanup Logic
; ==============================================================================

; --- Grid Activation ---

; Main function to activate the grid overlays. Called by activation hotkeys.
; Helper function to reuse the CapsLock & q code
CapsLock_Q() {
    global currentState, highlight, subGrid, cellMemory, StateMap
    global selectedLayout, layoutConfigs, showcaseDebug ; Also ensure these are global
    global gridActivationInProgress, gridActivationTime ; For preventing double activation
    global enableVerboseLogging ; Added enableVerboseLogging

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug)
        LogToFile(Format("Timestamp: {} | CapsLock_Q START | currentState={} | firstKey={}", A_TickCount,
            currentState, StateMap['firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q START | currentState='{}' | firstKey='{}'",
            A_TickCount, currentState, StateMap['firstKey']) "`n", "antimouse_core.log")
    }
    ; <<< ADD LOGGING END >>>
    ; Protect against double activation
    if (gridActivationInProgress || (currentTime - gridActivationTime < 300)) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        LogToFile(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Activation already in progress, ignoring",
            A_TickCount) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        if (showcaseDebug) {
            ToolTip("Grid activation already in progress, ignoring duplicate request")
            Sleep(200)
            ToolTip()
        }
        return
    }

    ; Set activation flag and timestamp
    gridActivationInProgress := true
    gridActivationTime := currentTime

    ; If already active, clean up and exit
    if (currentState != State_IDLE) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        LogToFile(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: State not IDLE (state='{}'), calling Cleanup()",
            A_TickCount, currentState) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) LogToFile(Format("Timestamp: {} | CapsLock_Q: Already Active, Calling Cleanup", currentTime
        ) "`n", A_ScriptDir "\debugRapidRefresh.log")
        ; <<< ADD LOGGING END >>>
            Cleanup()
        gridActivationInProgress := false
        return
    }

    ; Try to initialize
    try {
        ; IMPROVEMENT: Explicitly reset all state variables using StateMap
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        LogToFile(Format(
            "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Resetting state variables. Before: firstKey='{}'",
            A_TickCount, StateMap['firstKey']) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) LogToFile(Format(
            "Timestamp: {} | CapsLock_Q: Resetting State (Before) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
            currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log"
        )
        ; <<< ADD LOGGING END >>>
            StateMap['firstKey'] := ""
        StateMap['currentOverlay'] := ""
        StateMap['activeColKeys'] := []
        StateMap['activeRowKeys'] := []
        StateMap['activeCellKey'] := ""
        StateMap['activeSubCellKey'] := ""
        StateMap['currentColIndex'] := 0
        StateMap['currentRowIndex'] := 0
        StateMap['lastSelectedRowIndex'] := 0
        StateMap['overlays'] := []

        ; Explicitly initialize ultra-fast mode state variables
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['rowKeyHeldTime'] := 0

        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        LogToFile(Format(
            "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: State variables reset. After: firstKey='{}'",
            A_TickCount, StateMap['firstKey']) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) LogToFile(Format(
            "Timestamp: {} | CapsLock_Q: Reset State (After) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
            currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log"
        )
        ; <<< ADD LOGGING END >>>
        ; Load cell memory from file
            LoadCellMemory()

        ; Get configured layout
        currentConfig := layoutConfigs[selectedLayout]
        if (!IsObject(currentConfig)) {
            ; Fall back to default layout if the selected one is invalid
            selectedLayout := 2
            currentConfig := layoutConfigs[2]
            if (showcaseDebug) {
                ToolTip("Invalid layout selected, falling back to layout 2")
                Sleep(2000)
                ToolTip()
            }
        }

        ; Set up state - ensure we have valid data
        if (IsObject(currentConfig) && currentConfig.Has("colKeys") && currentConfig.Has("rowKeys") &&
        IsObject(currentConfig["colKeys"]) && IsObject(currentConfig["rowKeys"])) {
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            LogToFile(Format(
                "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Setting active keys from config. Cols={}, Rows={}",
                A_TickCount, currentConfig["colKeys"].Length, currentConfig["rowKeys"].Length) "`n",
            "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            StateMap['activeColKeys'] := currentConfig["colKeys"] ; Use StateMap
            StateMap['activeRowKeys'] := currentConfig["rowKeys"] ; Use StateMap
        } else {
            ; Fallback to a basic layout if config is invalid
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            LogToFile(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Using fallback layout",
                A_TickCount) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            StateMap['activeColKeys'] := ["q", "w", "e", "r"] ; Use StateMap
            StateMap['activeRowKeys'] := ["a", "s", "d", "f"] ; Use StateMap
            if (showcaseDebug) {
                ToolTip("Invalid layout configuration, using fallback layout")
                Sleep(2000)
                ToolTip()
            }
        }

        ; Get current mouse position
        MouseGetPos(&startX, &startY)
        foundMonitor := false

        ; Initialize reusable GUI elements
        try {
            LogToFile(Format("Timestamp: {} | DEBUG: About to initialize highlight and subGrid", A_TickCount) "`n",
            "antimouse_core.log")

            highlight := HighlightOverlay()
            LogToFile(Format("Timestamp: {} | DEBUG: HighlightOverlay created successfully", A_TickCount) "`n",
            "antimouse_core.log")

            subGrid := SubGridOverlay()
            LogToFile(Format("Timestamp: {} | DEBUG: SubGridOverlay created successfully, IsObject(subGrid)={}",
                A_TickCount, IsObject(subGrid)) "`n", "antimouse_core.log")
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR: Failed to initialize GUI: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
            ToolTip("Error initializing GUI: " e.Message)
            Sleep(2000)
            ToolTip()
            return
        }

        ; Create overlay for each monitor
        monitorCount := MonitorGetCount()
        loop monitorCount {
            try {
                MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
                LogToFile(Format("Timestamp: {} | CapsLock_Q: Creating OverlayGUI for Monitor {}", A_TickCount,
                    A_Index) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, StateMap['activeColKeys'], StateMap[
                    'activeRowKeys']) ; Use StateMap
                LogToFile(Format("Timestamp: {} | CapsLock_Q: OverlayGUI created. IsObject(overlay) = {}", A_TickCount,
                    IsObject(overlay)) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                if (IsObject(overlay)) { ; Only proceed if overlay created successfully
                    overlay.Show()
                    StateMap['overlays'].Push(overlay) ; Use StateMap

                    containsPointResult := overlay.ContainsPoint(startX, startY)
                    LogToFile(Format("Timestamp: {} | CapsLock_Q: Monitor {} ContainsPoint({}, {}) = {}", A_TickCount,
                        A_Index, startX, startY, containsPointResult) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                    if (containsPointResult) {
                        StateMap['currentOverlay'] := overlay ; Use StateMap
                        foundMonitor := true
                        LogToFile(Format("Timestamp: {} | CapsLock_Q: Set currentOverlay to Monitor {}", A_TickCount,
                            A_Index) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                    }
                }
            } catch as e {
                LogToFile(Format("Timestamp: {} | CapsLock_Q: ERROR creating overlay for Monitor {}: {}", A_TickCount,
                    A_Index, e.Message) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                if (showcaseDebug) {
                    ToolTip("Error creating overlay for monitor " A_Index ": " e.Message)
                    Sleep(2000)
                    ToolTip()
                }
                ; Continue with next monitor
            }
        }

        ; If no monitor found for current position, use first overlay
        if (!foundMonitor && StateMap['overlays'].Length > 0) { ; Use StateMap
            StateMap['currentOverlay'] := StateMap['overlays'][1] ; Use StateMap
        }

        ; Only continue if overlay creation was successful
        LogToFile(Format(
            "Timestamp: {} | CapsLock_Q: Checking condition: overlays.Length={}, IsObject(currentOverlay)={}",
            A_TickCount, StateMap['overlays'].Length, IsObject(StateMap['currentOverlay'])) "`n", "antimouse_core.log") ; <<< CORE LOGGING
        if (StateMap['overlays'].Length > 0 && IsObject(StateMap['currentOverlay'])) { ; Use StateMap
            LogToFile(Format("Timestamp: {} | CapsLock_Q: Condition TRUE. Grid activated. Attempting instant subgrid.",
                A_TickCount) "`n", "antimouse_core.log") ; <<< CORE LOGGING (Adjusted)

            ; Replace direct assignment with TransitionToState
            TransitionToState(State_GRID_VISIBLE) ; Use transition function instead of direct assignment

            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            LogToFile(Format(
                "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Set currentState via TransitionToState to 'GRID_VISIBLE'",
                A_TickCount) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            ; <<< Task 2.17 FIX: Immediate Subgrid Detection >>>
            initialCellKey := GetCurrentCell() ; Ensure GetCurrentCell is globally accessible or included
            if (initialCellKey != "") {
                initialBoundaries := StateMap["currentOverlay"].GetCellBoundaries(initialCellKey)
                if (IsObject(initialBoundaries)) {
                    if (enableVerboseLogging) {
                        LogToFile(Format(
                            "Timestamp: {} | Task: 2.17 FIX | CapsLock_Q: Initial cell '{}' detected. boundaries=({},{},{},{}). Updating highlight & subgrid, then transitioning.",
                            A_TickCount, initialCellKey, initialBoundaries.x, initialBoundaries.y, initialBoundaries.w,
                            initialBoundaries.h) "`n", "antimouse_core.log")
                    }
                    StateMap["activeCellKey"] := initialCellKey
                    if (IsObject(highlight)) {
                        highlight.Update(initialBoundaries.x, initialBoundaries.y, initialBoundaries.w,
                            initialBoundaries.h)
                        ; Highlight is shown by Update method itself
                    }
                    ; Update subgrid position *before* showing it in the transition
                    if (IsObject(subGrid)) {
                        subGrid.Update(initialBoundaries.x, initialBoundaries.y, initialBoundaries.w, initialBoundaries
                            .h)
                        if (enableVerboseLogging) {
                            LogToFile(Format("Timestamp: {} | Task: 2.17 FIX | CapsLock_Q: subGrid updated.",
                                A_TickCount) "`n", "antimouse_core.log")
                        }
                    }
                    TransitionToState(State_SUBGRID_STANDARD)
                } else {
                    if (enableVerboseLogging) {
                        LogToFile(Format(
                            "Timestamp: {} | Task: 2.17 FIX | CapsLock_Q: Failed to get boundaries for initial cell '{}'.",
                            A_TickCount, initialCellKey) "`n", "antimouse_core.log")
                    }
                }
            } else {
                if (enableVerboseLogging) {
                    LogToFile(Format(
                        "Timestamp: {} | Task: 2.17 FIX | CapsLock_Q: No initial cell detected under cursor.",
                        A_TickCount) "`n", "antimouse_core.log")
                }
            }
            ; <<< Task 2.17 FIX END >>>

            ; Enable cursor tracking timer AFTER grid is fully set up
            try {
                LogToFile(Format("Timestamp: {} | CapsLock_Q: Attempting SetTimer(TrackCursor, 50).", A_TickCount)
                "`n", "antimouse_core.log")
                SetTimer(TrackCursor, 50)
                LogToFile(Format("Timestamp: {} | CapsLock_Q: SetTimer(TrackCursor, 50) called successfully.",
                    A_TickCount) "`n", "antimouse_core.log")
            } catch as e {
                LogToFile(Format("Timestamp: {} | CapsLock_Q: ERROR setting TrackCursor timer: {}", A_TickCount,
                    e.Message) "`n", "antimouse_core.log")
                if (showcaseDebug) {
                    ToolTip("Error starting cursor tracker: " e.Message)
                }
            }

            gridActivationInProgress := false
        } else {
            LogToFile(Format("Timestamp: {} | CapsLock_Q: Condition FALSE. Calling Cleanup().", A_TickCount) "`n",
            "antimouse_core.log") ; <<< CORE LOGGING
            ; Clean up and show error if unsuccessful
            Cleanup()
            ; Reset activation flag after failure
            gridActivationInProgress := false
            ToolTip("Failed to create grid overlays")
            Sleep(2000)
            ToolTip()
        }
    } catch as e {
        ; Handle any uncaught errors
        Cleanup()
        ; Reset activation flag after any exception
        gridActivationInProgress := false
        if (showcaseDebug) {
            ToolTip("Error initializing: " e.Message)
            Sleep(2000)
            ToolTip()
        }
    }
    LogToFile(Format("Timestamp: {} | CapsLock_Q FINISHED | currentState={}", A_TickCount, currentState) "`n",
    "antimouse_core.log") ; <<< CORE LOGGING
}

; --- Grid Cleanup ---

; Cleans up all GUI elements and resets the state to IDLE.
Cleanup() {
    LogToFile("Cleanup() Function START", "antimouse_core.log")
    ; Access global state
    global currentState, highlight, subGrid, StateMap, g_ModifierState, gridActivationInProgress, showcaseDebug
    global enableVerboseLogging

    ; Prevent cleanup if already idle (avoids redundant actions)
    if (currentState == State_IDLE) {
        gridActivationInProgress := false ; Still ensure this flag is reset
        LogToFile("Cleanup: Already in IDLE state, exiting early", "antimouse_core.log")
        return
    }

    ; --- Immediate State Reset ---
    ; Stop cursor tracking first to prevent interference
    SetTimer(TrackCursor, 0)
    LogToFile("Cleanup: Stopped TrackCursor timer", "antimouse_core.log")

    ; Set state to IDLE immediately to prevent re-entry or conflicts
    ; --- TASK 5.7: Add safer state transition with error handling ---
    try {
        ; First set the state directly as a fallback in case TransitionToState fails
        currentState := State_IDLE
        LogToFile("Cleanup: Directly set currentState = IDLE", "antimouse_core.log")

        ; Then try to use the transition function which handles GUI cleanup
        try {
            LogToFile("Cleanup: Calling TransitionToState(IDLE)", "antimouse_core.log")
            TransitionToState(State_IDLE)
        } catch as e {
            LogToFile(Format("Cleanup: ERROR calling TransitionToState: {}", e.Message), "antimouse_core.log")
        }
    } catch as e {
        LogToFile(Format("Cleanup: ERROR during state transition: {}", e.Message), "antimouse_core.log")
        ; Ensure we're in IDLE state even if transition failed
        currentState := State_IDLE
    }

    LogToFile(Format("Cleanup: Final state = {}. Attempting short Sleep...", currentState), "antimouse_core.log")
    Sleep(10) ; Attempt to allow AHK to process state change
    LogToFile("Cleanup: Finished Sleep.", "antimouse_core.log")

    ; Reset flags
    g_ModifierState.inHoldMode := false
    gridActivationInProgress := false

    LogToFile(Format(
        "Cleanup: Resetting State (Before) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
        StateMap.Get("firstKey", "[N/A]"),
        StateMap.Get("inUltraFastMode", "[N/A]"),
        StateMap.Get("activeRowKey", "[N/A]")
    ), "antimouse_core.log")

    ; --- TASK 5.6: Ensure we reset all state variables ---
    StateMap['firstKey'] := "" ; Clear partial selections
    StateMap['activeCellKey'] := "" ; Clear the active cell
    StateMap['activeSubCellKey'] := "" ; Clear the active subcell

    ; --- TASK 5.8: Clear any preserved row information ---
    if (StateMap.Has("preservedRowKey")) {
        LogToFile("Task 5.8: Clearing preservedRowKey in Cleanup", "antimouse_core.log")
        StateMap.Delete("preservedRowKey")
    }
    ; --- END TASK 5.8 ---

    ; --- Reset Ultra-Fast Mode State ---
    StateMap['inUltraFastMode'] := false ; Ensure ultra-fast mode is deactivated
    StateMap['activeRowKey'] := "" ; Clear the active row key
    StateMap['rowKeyHeldTime'] := 0 ; Reset the hold time

    ; --- Task 5.10: ROBUST FIX --- END
    LogToFile(Format(
        "Cleanup: Reset State (After) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
        StateMap.Get('firstKey', "(not set)"), StateMap.Get('inUltraFastMode', "(not set)"), StateMap.Get(
            'activeRowKey', "(not set)")
    ), "antimouse_core.log")

    ; Explicitly hide GUIs again, just in case (best effort)
    ToolTip()

    ; --- Hide GUI Elements (Best Effort) ---
    ; Use try/catch for each element with proper object validation
    try {
        if (IsObject(highlight)) {
            LogToFile("Cleanup: Hiding highlight", "antimouse_core.log")
            highlight.Hide()
        } else {
            LogToFile(Format("Cleanup: highlight is not an object (type: {})", Type(highlight)), "antimouse_core.log")
        }
    } catch as e {
        LogToFile(Format("Cleanup: Error hiding highlight: {}", e.Message), "antimouse_core.log")
    }

    try {
        if (IsObject(subGrid)) {
            LogToFile("Cleanup: Hiding subGrid", "antimouse_core.log")
            subGrid.Hide()
        } else {
            LogToFile(Format("Cleanup: subGrid is not an object (type: {})", Type(subGrid)), "antimouse_core.log")
        }
    } catch as e {
        LogToFile(Format("Cleanup: Error hiding subGrid: {}", e.Message), "antimouse_core.log")
    }

    try {
        if (IsObject(StateMap) && StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            for index, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    LogToFile(Format("Cleanup: Hiding overlay {}", index), "antimouse_core.log")
                    try {
                        overlay.Hide()
                    } catch as e {
                        LogToFile(Format("Cleanup: Error hiding overlay {}: {}", index, e.Message),
                        "antimouse_core.log")
                    }
                } else {
                    LogToFile(Format("Cleanup: overlay {} is not an object (type: {})",
                        index, Type(overlay)), "antimouse_core.log")
                }
            }
        } else {
            LogToFile("Cleanup: StateMap['overlays'] is not a valid array", "antimouse_core.log")
        }
    } catch as e {
        LogToFile(Format("Cleanup: Error iterating overlays: {}", e.Message), "antimouse_core.log")
    }

    Sleep(30) ; Short delay to allow GUIs time to hide visually

    ; --- Destroy GUI Elements (Best Effort) ---
    try {
        if (IsObject(highlight)) {
            LogToFile("Cleanup: Destroying highlight", "antimouse_core.log")
            highlight.Destroy()
        }
    } catch as e {
        LogToFile(Format("Cleanup: Error destroying highlight: {}", e.Message), "antimouse_core.log")
    }

    try {
        if (IsObject(subGrid)) {
            LogToFile("Cleanup: Destroying subGrid", "antimouse_core.log")
            subGrid.Destroy()
        }
    } catch as e {
        LogToFile(Format("Cleanup: Error destroying subGrid: {}", e.Message), "antimouse_core.log")
    }

    try {
        if (IsObject(StateMap) && StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            for index, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    LogToFile(Format("Cleanup: Destroying overlay {}", index), "antimouse_core.log")
                    try {
                        overlay.Destroy()
                    } catch as e {
                        LogToFile(Format("Cleanup: Error destroying overlay {}: {}", index, e.Message),
                        "antimouse_core.log")
                    }
                }
            }
        }
    } catch as e {
        LogToFile(Format("Cleanup: Error destroying overlays: {}", e.Message), "antimouse_core.log")
    }

    ; --- Reset Global Object References ---
    highlight := ""
    subGrid := ""
    StateMap['overlays'] := []
    StateMap['currentOverlay'] := ""
    LogToFile("Cleanup: Reset object references to empty", "antimouse_core.log")

    ; --- Force Close Any Remaining GUIs ---
    try {
        LogToFile("Cleanup: Calling ForceCloseAllGuis() for safety", "antimouse_core.log")
        ForceCloseAllGuis() ; Function from utils.ahk
    } catch as e {
        LogToFile(Format("Cleanup: Error in ForceCloseAllGuis: {}", e.Message), "antimouse_core.log")
    }

    LogToFile("Cleanup: Complete", "antimouse_core.log")
}

; Deactivate the grid and clean up
DeactivateGrid(forced := false) {
    global subGrid, highlight, currentState, StateMap, gridActivationTime, stateTransitionDelay,
        g_ModifierState, saveMemoryOnExit, cellMemory, showcaseDebug, enableVerboseLogging ; Added enableVerboseLogging

    currentTime := A_TickCount
    if (showcaseDebug) {
        LogToFile(Format("DeactivateGrid START | forced={} | currentState={}", forced,
            currentState), A_ScriptDir "\debugRapidRefresh.log")
    }

    ; Log the function call
    if (enableVerboseLogging) {
        LogToFile(Format("DeactivateGrid called | forced={}, currentState={}", forced,
            currentState), "antimouse_core.log")
    }

    ; Check if deactivation is happening too quickly after activation
    ; Use stateTransitionDelay to prevent accidental immediate closure
    if (!forced && (currentTime - gridActivationTime < stateTransitionDelay)) {
        if (showcaseDebug) {
            LogToFile(Format("DeactivateGrid: Debounced (Activation too recent)"),
            A_ScriptDir "\debugRapidRefresh.log")
        }
        if (enableVerboseLogging) {
            LogToFile("DeactivateGrid debounced.", "antimouse_core.log")
        }
        return
    }

    ; Stop cursor tracking
    SetTimer(TrackCursor, 0)

    ; Destroy overlays - use StateMap consistently
    if (IsObject(StateMap["overlays"])) {
        for _, overlay in StateMap["overlays"] {
            if (IsObject(overlay)) {
                overlay.Destroy()
            }
        }
    }
    StateMap["overlays"] := [] ; Clear the array
    StateMap["currentOverlay"] := ""

    ; Destroy subgrid and highlight if they exist
    if (IsObject(subGrid)) {
        subGrid.Destroy()
        subGrid := ""
    }
    if (IsObject(highlight)) {
        highlight.Destroy()
        highlight := ""
    }

    ; Reset StateMap values
    StateMap["firstKey"] := ""
    StateMap["activeCellKey"] := ""
    StateMap["activeSubCellKey"] := ""
    StateMap["currentColIndex"] := 0
    StateMap["currentRowIndex"] := 0
    StateMap["rowKeyHeldTime"] := 0
    StateMap['inUltraFastMode'] := false
    StateMap['activeRowKey'] := ""

    ; Reset CapsLock hold mode state
    g_ModifierState.inHoldMode := false

    ; Reset state
    TransitionToState(State_IDLE)

    ; Save cell memory if needed
    if (saveMemoryOnExit) {
        if (enableVerboseLogging) { ; <<< WRAPPED
            LogToFile(Format("Timestamp: {} | DeactivateGrid: Saving cell memory.", A_TickCount) "`n",
            "antimouse_core.log")
        }
        SaveCellMemory()
    }
    if (showcaseDebug) {
        LogToFile(Format("Timestamp: {} | DeactivateGrid END | currentState={}", A_TickCount, currentState) "`n",
        A_ScriptDir "\debugRapidRefresh.log")
    }
    if (enableVerboseLogging) { ; <<< WRAPPED
        LogToFile(Format("Timestamp: {} | DeactivateGrid END | currentState={}", A_TickCount, currentState) "`n",
        "antimouse_core.log")
    }

    ; Restore CapsLock state if needed (TBD)
}

; Activates the grid overlay for the current monitor
ActivateGrid() {
    ; Explicitly list required global variables
    global currentState, highlight, subGrid, cellMemory, StateMap
    global selectedLayout, layoutConfigs, showcaseDebug, storePerMonitor ; Config-related globals
    global gridActivationInProgress, gridActivationTime, g_ModifierState ; State tracking globals
}

; --- Cell Memory Management --- END ---
