; ==============================================================================
; activation.ahk - Grid Activation and Cleanup Logic
; ==============================================================================

; --- Grid Activation ---

; Main function to activate the grid overlays. Called by activation hotkeys.
; Helper function to reuse the CapsLock & q code
CapsLock_Q() {
    ; import from gui_classes.ahk
    global currentState, highlight, subGrid, cellMemory, StateMap
    global selectedLayout, layoutConfigs, showcaseDebug ; Also ensure these are global
    global gridActivationInProgress, gridActivationTime ; For preventing double activation
    global enableVerboseLogging ; Added enableVerboseLogging

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        LogToFile(Format("Timestamp: {} | CapsLock_Q START | currentState={} | firstKey={}", A_TickCount,
            currentState, StateMap['firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
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
        if (showcaseDebug) {
            LogToFile(Format("Timestamp: {} | CapsLock_Q: Already Active, Calling Cleanup", currentTime
            ) "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
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
        if (showcaseDebug) {
            LogToFile(Format(
                "Timestamp: {} | CapsLock_Q: Resetting State (Before) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
                currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n",
            A_ScriptDir "\debugRapidRefresh.log"
            )
        }
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
        if (showcaseDebug) {
            LogToFile(Format(
                "Timestamp: {} | CapsLock_Q: Reset State (After) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
                currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n",
            A_ScriptDir "\debugRapidRefresh.log"
            )
        }
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

            ; S1.3: Check objects after creation
            if (!IsObject(highlight) || !IsObject(subGrid)) {
                LogToFile(Format("Timestamp: {} | ERROR: Failed to create GUI objects, highlight={}, subGrid={}",
                    A_TickCount, IsObject(highlight), IsObject(subGrid)) "`n", "antimouse_core.log")
                ToolTip("Error initializing GUI objects")
                Sleep(2000)
                ToolTip()
                Cleanup()
                gridActivationInProgress := false
                return
            }
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR: Failed to initialize GUI: {}", A_TickCount, e.Message) "`n",
            "antimouse_core.log")
            ToolTip("Error initializing GUI: " e.Message)
            Sleep(2000)
            ToolTip()
            gridActivationInProgress := false
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
                    try {
                        overlay.Show()
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | ERROR: Failed to show overlay: {}", A_TickCount, e.Message) "`n",
                        "antimouse_core.log")
                    }
                    StateMap['overlays'].Push(overlay) ; Use StateMap

                    ; S1.1: Add try/catch for ContainsPoint method
                    containsPointResult := false
                    try {
                        containsPointResult := overlay.ContainsPoint(startX, startY)
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | ERROR: ContainsPoint failed: {}", A_TickCount, e.Message) "`n",
                        "antimouse_core.log")
                    }

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

        ; S1.3: Check if all required GUI objects were created successfully
        ; Comprehensive validation of all critical objects before proceeding
        if (!IsObject(highlight)) {
            LogToFile(Format("Timestamp: {} | ERROR: highlight object is invalid after creation",
                A_TickCount) "`n", "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Critical error: highlight object is invalid")
                Sleep(2000)
                ToolTip()
            }
            Cleanup()
            gridActivationInProgress := false
            return
        }

        if (!IsObject(subGrid)) {
            LogToFile(Format("Timestamp: {} | ERROR: subGrid object is invalid after creation",
                A_TickCount) "`n", "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Critical error: subGrid object is invalid")
                Sleep(2000)
                ToolTip()
            }
            Cleanup()
            gridActivationInProgress := false
            return
        }

        if (StateMap['overlays'].Length == 0) {
            LogToFile(Format("Timestamp: {} | ERROR: No overlay GUIs were created successfully",
                A_TickCount) "`n", "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Critical error: Failed to create any overlay GUIs")
                Sleep(2000)
                ToolTip()
            }
            Cleanup()
            gridActivationInProgress := false
            return
        }

        if (!IsObject(StateMap['currentOverlay'])) {
            LogToFile(Format("Timestamp: {} | ERROR: currentOverlay object is invalid after creation",
                A_TickCount) "`n", "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Critical error: currentOverlay object is invalid")
                Sleep(2000)
                ToolTip()
            }
            Cleanup()
            gridActivationInProgress := false
            return
        }

        LogToFile(Format(
            "Timestamp: {} | S1.3: All GUI objects validated successfully: highlight={}, subGrid={}, overlays.Length={}, currentOverlay={}",
            A_TickCount, IsObject(highlight), IsObject(subGrid), StateMap['overlays'].Length, IsObject(StateMap[
                'currentOverlay'])) "`n", "antimouse_core.log")

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
                ; S1.1: Add IsObject check before GetCellBoundaries
                if (IsObject(StateMap["currentOverlay"])) {
                    try {
                        initialBoundaries := StateMap["currentOverlay"].GetCellBoundaries(initialCellKey)
                        if (IsObject(initialBoundaries)) {
                            if (enableVerboseLogging) {
                                LogToFile(Format(
                                    "Timestamp: {} | Task: 2.17 FIX | CapsLock_Q: Initial cell '{}' detected. boundaries=({},{},{},{}). Updating highlight & subgrid, then transitioning.",
                                    A_TickCount, initialCellKey, initialBoundaries.x, initialBoundaries.y,
                                    initialBoundaries.w,
                                    initialBoundaries.h) "`n", "antimouse_core.log")
                            }
                            StateMap["activeCellKey"] := initialCellKey
                            ; S1.1: Add IsObject check for highlight
                            if (IsObject(highlight)) {
                                try {
                                    highlight.Update(initialBoundaries.x, initialBoundaries.y, initialBoundaries.w,
                                        initialBoundaries.h)
                                } catch as e {
                                    LogToFile(Format("Timestamp: {} | ERROR: Failed to update highlight: {}",
                                        A_TickCount, e.Message) "`n",
                                    "antimouse_core.log")
                                }
                                ; Highlight is shown by Update method itself
                            } else {
                                LogToFile(Format("Timestamp: {} | WARNING: highlight object invalid", A_TickCount) "`n",
                                "antimouse_core.log")
                            }
                            ; Update subgrid position *before* showing it in the transition
                            ; S1.1: Add IsObject check for subGrid
                            if (IsObject(subGrid)) {
                                try {
                                    subGrid.Update(initialBoundaries.x, initialBoundaries.y, initialBoundaries.w,
                                        initialBoundaries.h)
                                } catch as e {
                                    LogToFile(Format("Timestamp: {} | ERROR: Failed to update subGrid: {}", A_TickCount,
                                        e.Message) "`n",
                                    "antimouse_core.log")
                                }
                            } else {
                                LogToFile(Format("Timestamp: {} | WARNING: subGrid object invalid", A_TickCount) "`n",
                                "antimouse_core.log")
                            }

                            ; Transition to subgrid state
                            TransitionToState(State_SUBGRID_STANDARD)
                        } else {
                            LogToFile(Format("Timestamp: {} | WARNING: Initial boundaries invalid", A_TickCount) "`n",
                            "antimouse_core.log")
                        }
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | ERROR: GetCellBoundaries failed: {}", A_TickCount, e.Message) "`n",
                        "antimouse_core.log")
                    }
                } else {
                    LogToFile(Format("Timestamp: {} | WARNING: currentOverlay object invalid", A_TickCount) "`n",
                    "antimouse_core.log")
                }
            }
            ; <<< END Task 2.17 FIX >>>

            ; Start the tracking timer - 50ms interval is a good balance between responsiveness and performance
            SetTimer(TrackCursor, 50)
        } else {
            LogToFile(Format("Timestamp: {} | CapsLock_Q: Condition FALSE. Grid activation FAILED.",
                A_TickCount) "`n", "antimouse_core.log") ; <<< CORE LOGGING (Adjusted)
            if (showcaseDebug) {
                ToolTip("Failed to create overlays. Cleaning up...")
                Sleep(2000)
                ToolTip()
            }
            ; Clean up and reset if overlay creation failed
            Cleanup()
        }
    } catch as e {
        ; Log error and clean up
        LogToFile(Format("Timestamp: {} | CapsLock_Q: ERROR during initialization: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
        if (showcaseDebug) {
            ToolTip("Error during initialization: " e.Message)
            Sleep(2000)
            ToolTip()
        }
        Cleanup()
    }

    ; Reset activation flag
    gridActivationInProgress := false
}

; --- Grid Cleanup ---

; Cleans up all GUI elements and resets the state to IDLE.
Cleanup() {
    global currentState, highlight, subGrid, StateMap, showcaseDebug, enableVerboseLogging, gridActivationInProgress,
        g_ModifierState

    ; <<< Enhanced Logging for Cleanup START >>>
    LogToFile(Format("Timestamp: {} | CLEANUP BEGIN | currentState={} | firstKey={}",
        A_TickCount, currentState, StateMap['firstKey']) "`n", "antimouse_core.log")
    if (showcaseDebug) {
        LogToFile(Format("Timestamp: {} | Cleanup CALLED | currentState={} | firstKey={}",
            A_TickCount, currentState, StateMap['firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< Enhanced Logging for Cleanup END >>>

    ; 1. Stop tracking timer first - ensures no more cursor updates during cleanup
    try {
        SetTimer(TrackCursor, 0)
        LogToFile(Format("Timestamp: {} | CLEANUP: TrackCursor timer stopped", A_TickCount) "`n", "antimouse_core.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | WARNING: Failed to stop TrackCursor timer: {}",
            A_TickCount, e.Message) "`n", "antimouse_core.log")
    }

    ; 2. Transition to IDLE state (handles hiding GUI elements)
    if (currentState != State_IDLE) {
        try {
            LogToFile(Format("Timestamp: {} | CLEANUP: Transitioning to IDLE state", A_TickCount) "`n",
            "antimouse_core.log")
            TransitionToState(State_IDLE)
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR: Failed to transition to IDLE state: {}",
                A_TickCount, e.Message) "`n", "antimouse_core.log")
        }
    }

    ; 3. Reset flags and state variables
    try {
        LogToFile(Format("Timestamp: {} | CLEANUP: Resetting state variables and flags", A_TickCount) "`n",
        "antimouse_core.log")

        ; Reset activation flags
        gridActivationInProgress := false

        ; Reset CapsLock hold mode state
        g_ModifierState.inHoldMode := false

        ; Reset all StateMap variables
        StateMap['firstKey'] := ""
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['rowKeyHeldTime'] := 0
        StateMap['activeCellKey'] := ""
        StateMap['activeSubCellKey'] := ""
        StateMap['currentColIndex'] := 0
        StateMap['currentRowIndex'] := 0
        StateMap['lastSelectedRowIndex'] := 0
        StateMap['lastKeypressTime'] := 0 ; Used for debouncing hover activation

        LogToFile(Format("Timestamp: {} | CLEANUP: All flags and state variables reset", A_TickCount) "`n",
        "antimouse_core.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Failed to reset state variables: {}",
            A_TickCount, e.Message) "`n", "antimouse_core.log")
    }

    ; 4. Destroy GUI objects in a specific order with proper checks
    try {
        ; 4.1 First destroy overlays one by one
        if (StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            LogToFile(Format("Timestamp: {} | CLEANUP: Destroying {} overlays",
                A_TickCount, StateMap['overlays'].Length) "`n", "antimouse_core.log")

            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    try {
                        LogToFile(Format("Timestamp: {} | CLEANUP: Hiding/Destroying overlay {}",
                            A_TickCount, i) "`n", "antimouse_core.log")
                        overlay.Hide()
                        overlay.Destroy()
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | WARNING: Error destroying overlay {}: {}",
                            A_TickCount, i, e.Message) "`n", "antimouse_core.log")
                    }
                }
            }
            ; Clear overlay array after destroying all overlays
            StateMap['overlays'] := []
            LogToFile(Format("Timestamp: {} | CLEANUP: Overlays array cleared", A_TickCount) "`n", "antimouse_core.log"
            )
        }

        ; 4.2 Next destroy highlight
        if (IsObject(highlight)) {
            try {
                LogToFile(Format("Timestamp: {} | CLEANUP: Hiding/Destroying highlight",
                    A_TickCount) "`n", "antimouse_core.log")
                highlight.Hide()
                highlight.Destroy()
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error destroying highlight: {}",
                    A_TickCount, e.Message) "`n", "antimouse_core.log")
            }
            ; Clear highlight reference
            highlight := ""
            LogToFile(Format("Timestamp: {} | CLEANUP: Highlight reference cleared", A_TickCount) "`n",
            "antimouse_core.log")
        }

        ; 4.3 Finally destroy subgrid
        if (IsObject(subGrid)) {
            try {
                LogToFile(Format("Timestamp: {} | CLEANUP: Hiding/Destroying subGrid",
                    A_TickCount) "`n", "antimouse_core.log")
                subGrid.Hide()
                subGrid.Destroy()
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error destroying subGrid: {}",
                    A_TickCount, e.Message) "`n", "antimouse_core.log")
            }
            ; Clear subgrid reference
            subGrid := ""
            LogToFile(Format("Timestamp: {} | CLEANUP: SubGrid reference cleared", A_TickCount) "`n",
            "antimouse_core.log")
        }

        ; 4.4 Clear current overlay reference
        StateMap['currentOverlay'] := ""
        LogToFile(Format("Timestamp: {} | CLEANUP: currentOverlay reference cleared", A_TickCount) "`n",
        "antimouse_core.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Exception during GUI destruction: {}",
            A_TickCount, e.Message) "`n", "antimouse_core.log")
    }

    ; 5. Use ForceCloseAllGuis as a last resort/safety mechanism only
    try {
        ; Only if ShowcaseDebug is enabled, perform the extra ForceCloseAllGuis step
        if (showcaseDebug) {
            LogToFile(Format("Timestamp: {} | CLEANUP: Running ForceCloseAllGuis as final safety check",
                A_TickCount) "`n", "antimouse_core.log")
            ForceCloseAllGuis()
        }
    } catch as e {
        LogToFile(Format("Timestamp: {} | WARNING: Error in ForceCloseAllGuis: {}",
            A_TickCount, e.Message) "`n", "antimouse_core.log")
    }

    ; Final state confirmation
    LogToFile(Format("Timestamp: {} | CLEANUP COMPLETE | highlight={}, subGrid={}, overlays.Length={}",
        A_TickCount, IsObject(highlight), IsObject(subGrid),
        StateMap.Has('overlays') ? StateMap['overlays'].Length : 0) "`n", "antimouse_core.log")
}

; Deactivate the grid and clean up
DeactivateGrid(forced := false) {
    global subGrid, highlight, currentState, StateMap, gridActivationTime, stateTransitionDelay,
        g_ModifierState, saveMemoryOnExit, cellMemory, showcaseDebug, enableVerboseLogging, gridActivationInProgress

    currentTime := A_TickCount

    ; Enhanced logging for DeactivateGrid
    LogToFile(Format("Timestamp: {} | DEACTIVATEGRID BEGIN | forced={}, currentState={}",
        currentTime, forced, currentState) "`n", "antimouse_core.log")

    if (showcaseDebug) {
        LogToFile(Format("DeactivateGrid START | forced={} | currentState={}", forced,
            currentState), A_ScriptDir "\debugRapidRefresh.log")
    }

    ; 1. Check debounce (prevent accidental immediate deactivation)
    if (!forced && (currentTime - gridActivationTime < stateTransitionDelay)) {
        LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Debounced (Activation too recent)",
            currentTime) "`n", "antimouse_core.log")

        if (showcaseDebug) {
            LogToFile(Format("DeactivateGrid: Debounced (Activation too recent)"),
            A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; 2. Stop cursor tracking first
    try {
        SetTimer(TrackCursor, 0)
        LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: TrackCursor timer stopped",
            currentTime) "`n", "antimouse_core.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | WARNING: Failed to stop TrackCursor timer: {}",
            currentTime, e.Message) "`n", "antimouse_core.log")
    }

    ; 3. Reset grid activation flag
    gridActivationInProgress := false

    ; 4. Destroy GUI objects in a specific order with proper checks
    try {
        ; 4.1 First destroy overlays one by one
        if (StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Destroying {} overlays",
                currentTime, StateMap['overlays'].Length) "`n", "antimouse_core.log")

            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    try {
                        overlay.Destroy()
                        LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Destroyed overlay {}",
                            currentTime, i) "`n", "antimouse_core.log")
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | WARNING: Error destroying overlay {}: {}",
                            currentTime, i, e.Message) "`n", "antimouse_core.log")
                    }
                }
            }
            StateMap['overlays'] := [] ; Clear the array
        }
        StateMap['currentOverlay'] := "" ; Clear current overlay reference

        ; 4.2 Next destroy subgrid
        if (IsObject(subGrid)) {
            try {
                subGrid.Destroy()
                LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Destroyed subGrid",
                    currentTime) "`n", "antimouse_core.log")
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error destroying subGrid: {}",
                    currentTime, e.Message) "`n", "antimouse_core.log")
            }
            subGrid := ""
        }

        ; 4.3 Finally destroy highlight
        if (IsObject(highlight)) {
            try {
                highlight.Destroy()
                LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Destroyed highlight",
                    currentTime) "`n", "antimouse_core.log")
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error destroying highlight: {}",
                    currentTime, e.Message) "`n", "antimouse_core.log")
            }
            highlight := ""
        }
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Exception during GUI destruction: {}",
            currentTime, e.Message) "`n", "antimouse_core.log")
    }

    ; 5. Reset StateMap values
    try {
        LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Resetting state variables",
            currentTime) "`n", "antimouse_core.log")

        StateMap["firstKey"] := ""
        StateMap["activeCellKey"] := ""
        StateMap["activeSubCellKey"] := ""
        StateMap["currentColIndex"] := 0
        StateMap["currentRowIndex"] := 0
        StateMap["rowKeyHeldTime"] := 0
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['lastKeypressTime'] := 0 ; Used for debouncing hover activation
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Failed to reset state variables: {}",
            currentTime, e.Message) "`n", "antimouse_core.log")
    }

    ; 6. Reset CapsLock hold mode state
    g_ModifierState.inHoldMode := false

    ; 7. Transition to IDLE state
    try {
        TransitionToState(State_IDLE)
        LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Transitioned to IDLE state",
            currentTime) "`n", "antimouse_core.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Failed to transition to IDLE state: {}",
            currentTime, e.Message) "`n", "antimouse_core.log")
    }

    ; 8. Save cell memory if needed
    if (saveMemoryOnExit) {
        try {
            LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Saving cell memory",
                currentTime) "`n", "antimouse_core.log")
            SaveCellMemory()
        } catch as e {
            LogToFile(Format("Timestamp: {} | ERROR: Failed to save cell memory: {}",
                currentTime, e.Message) "`n", "antimouse_core.log")
        }
    }

    ; Final logging
    LogToFile(Format("Timestamp: {} | DEACTIVATEGRID COMPLETE | currentState={}",
        currentTime, currentState) "`n", "antimouse_core.log")

    if (showcaseDebug) {
        LogToFile(Format("Timestamp: {} | DeactivateGrid END | currentState={}",
            currentTime, currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
}

; Activates the grid overlay for the current monitor
ActivateGrid() {
    ; Explicitly list required global variables
    global currentState, highlight, subGrid, cellMemory, StateMap
    global selectedLayout, layoutConfigs, showcaseDebug, storePerMonitor ; Config-related globals
    global gridActivationInProgress, gridActivationTime, g_ModifierState ; State tracking globals
}

; --- Cell Memory Management --- END ---
