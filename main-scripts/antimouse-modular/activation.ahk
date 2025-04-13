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
    global currentState, highlight, subGrid, StateMap, showcaseDebug, enableVerboseLogging

    ; <<< LOGGING START >>>
    if (showcaseDebug) {
        LogToFile(Format("Timestamp: {} | Cleanup CALLED | currentState={} | firstKey={}",
            A_TickCount, currentState, StateMap['firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< LOGGING END >>>

    ; Stop tracking
    SetTimer(TrackCursor, 0)

    ; Transition to IDLE state (should handle hiding things)
    if (currentState != State_IDLE) {
        TransitionToState(State_IDLE)
    }

    ; Clean up overlay GUIs and other objects if they exist
    try {
        ; S1.2: Improve cleanup with proper ordering and checks

        ; Reset state variables
        StateMap['firstKey'] := ""
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['rowKeyHeldTime'] := 0
        StateMap['activeCellKey'] := ""
        StateMap['activeSubCellKey'] := ""

        ; Log before destruction
        if (enableVerboseLogging) {
            LogToFile(Format("Timestamp: {} | DIAGNOSTIC | Cleanup: About to destroy overlays, count={}",
                A_TickCount, StateMap.Has('overlays') ? StateMap['overlays'].Length : 0) "`n", "antimouse_core.log")
        }

        ; Destroy overlays
        if (StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    try {
                        LogToFile(Format("Timestamp: {} | DIAGNOSTIC | Cleanup: Destroying overlay {}",
                            A_TickCount, i) "`n", "antimouse_core.log")
                        overlay.Hide()
                        overlay.Destroy()
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | WARNING: Error destroying overlay {}: {}",
                            A_TickCount, i, e.Message) "`n", "antimouse_core.log")
                    }
                }
            }
            StateMap['overlays'] := []
        }

        ; Destroy highlight
        if (IsObject(highlight)) {
            try {
                LogToFile(Format("Timestamp: {} | DIAGNOSTIC | Cleanup: Destroying highlight",
                    A_TickCount) "`n", "antimouse_core.log")
                highlight.Hide()
                highlight.Destroy()
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error destroying highlight: {}",
                    A_TickCount, e.Message) "`n", "antimouse_core.log")
            }
            highlight := ""
        }

        ; Destroy subgrid
        if (IsObject(subGrid)) {
            try {
                LogToFile(Format("Timestamp: {} | DIAGNOSTIC | Cleanup: Destroying subGrid",
                    A_TickCount) "`n", "antimouse_core.log")
                subGrid.Hide()
                subGrid.Destroy()
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error destroying subGrid: {}",
                    A_TickCount, e.Message) "`n", "antimouse_core.log")
            }
            subGrid := ""
        }

        ; Clear current overlay reference
        StateMap['currentOverlay'] := ""

        ; Only use ForceCloseAllGuis as a last resort cleanup
        if (showcaseDebug) {
            LogToFile(Format("Timestamp: {} | Cleanup: ForceCloseAllGuis() called as final safety",
                A_TickCount) "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        ForceCloseAllGuis()

    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Exception in Cleanup: {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
        ; Final fallback - force close all GUIs
        ForceCloseAllGuis()
    }

    ; Final state confirmation
    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | DIAGNOSTIC | Cleanup: Complete. highlight={}, subGrid={}, overlays.Length={}",
            A_TickCount, IsObject(highlight), IsObject(subGrid),
            StateMap.Has('overlays') ? StateMap['overlays'].Length : 0) "`n", "antimouse_core.log")
    }
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
