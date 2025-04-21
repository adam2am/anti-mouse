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
    global OFFSCREEN_X, OFFSCREEN_Y ; For off-screen positioning

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

    ; If already active, clean up and exit (Toggle functionality)
    if (currentState != State_IDLE) {
        LogToFile(Format(
            "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: State not IDLE (state='{}'), calling Cleanup() for toggle",
            A_TickCount, currentState) "`n", "antimouse_core.log")
        Cleanup()
        gridActivationInProgress := false ; Reset flag after cleanup
        return
    }

    ; Try to activate (GUIs are assumed to be pre-initialized)
    try {
        LogToFile(Format("Timestamp: {} | CapsLock_Q: Activating pre-initialized GUIs", A_TickCount),
        "antimouse_core.log")

        ; --- 1. Reset State Variables (Keep this) ---
        LogToFile(Format("Timestamp: {} | CapsLock_Q: Resetting state variables.", A_TickCount), "antimouse_core.log")
        StateMap['firstKey'] := ""
        StateMap['currentOverlay'] := ""
        StateMap['activeCellKey'] := ""
        StateMap['activeSubCellKey'] := ""
        StateMap['currentColIndex'] := 0
        StateMap['currentRowIndex'] := 0
        StateMap['lastSelectedRowIndex'] := 0
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['rowKeyHeldTime'] := 0
        ; Do NOT reset StateMap['overlays'] here

        ; --- 2. Load Cell Memory (Keep this) ---
        LoadCellMemory()

        ; --- 3. Get Layout Keys (Keep this, needed for immediate subgrid) ---
        currentConfig := layoutConfigs.Has(selectedLayout) ? layoutConfigs[selectedLayout] : layoutConfigs[2]
        if (!IsObject(currentConfig) || !currentConfig.Has("colKeys") || !currentConfig.Has("rowKeys")) {
            LogToFile(Format("Timestamp: {} | ERROR: Invalid layout {} in CapsLock_Q", A_TickCount, selectedLayout),
            "antimouse_core.log")
            ToolTip("Error: Invalid layout configuration during activation.")
            Sleep(2000)
            ToolTip()
            Cleanup()
            gridActivationInProgress := false
            return
        }
        StateMap['activeColKeys'] := currentConfig["colKeys"] ; Still needed for logic
        StateMap['activeRowKeys'] := currentConfig["rowKeys"]

        ; --- 4. Find Current Monitor and Show Overlay (Modified) ---
        MouseGetPos(&startX, &startY)
        foundMonitor := false
        StateMap['currentOverlay'] := "" ; Reset before finding

        LogToFile(Format("Timestamp: {} | CapsLock_Q: Finding current monitor based on mouse ({}, {})", A_TickCount,
            startX, startY), "antimouse_core.log")

        if (!StateMap.Has('overlays') || !IsObject(StateMap['overlays']) || StateMap['overlays'].Length == 0) {
            LogToFile(Format("Timestamp: {} | ERROR: StateMap['overlays'] is not initialized or empty!", A_TickCount),
            "antimouse_core.log")
            ToolTip("Critical Error: GUI Overlays not initialized. Please restart script.")
            Sleep(3000)
            ToolTip()
            Cleanup()
            gridActivationInProgress := false
            return
        }

        for i, overlay in StateMap['overlays'] {
            if (!IsObject(overlay)) {
                LogToFile(Format("Timestamp: {} | WARNING: Invalid overlay object at index {} in StateMap['overlays']",
                    A_TickCount, i), "antimouse_core.log")
                continue ; Skip this invalid overlay
            }
            try {
                containsPointResult := overlay.ContainsPoint(startX, startY)
                if (containsPointResult) {
                    LogToFile(Format("Timestamp: {} | CapsLock_Q: Found active overlay: Monitor {}", A_TickCount, i),
                    "antimouse_core.log")
                    StateMap['currentOverlay'] := overlay
                    overlay.Show() ; Move this overlay on-screen
                    foundMonitor := true
                    ; Do not break here, ensure others are hidden
                } else {
                    overlay.Hide() ; Ensure non-active overlays are off-screen
                }
            } catch as e {
                LogToFile(Format("Timestamp: {} | ERROR checking/showing overlay {}: {}", A_TickCount, i, e.Message),
                "antimouse_core.log")
            }
        }

        ; Fallback if mouse isn't on any monitor (e.g., during monitor sleep/disconnect)
        if (!foundMonitor) {
            LogToFile(Format("Timestamp: {} | CapsLock_Q: Mouse not on any known monitor, defaulting to monitor 1",
                A_TickCount), "antimouse_core.log")
            if (IsObject(StateMap['overlays'][1])) {
                StateMap['currentOverlay'] := StateMap['overlays'][1]
                StateMap['currentOverlay'].Show()
                foundMonitor := true ; Mark as found for subsequent checks
            } else {
                LogToFile(Format("Timestamp: {} | ERROR: Fallback overlay (Monitor 1) is invalid!", A_TickCount),
                "antimouse_core.log")
                ToolTip("Critical Error: Default GUI Overlay (Monitor 1) is invalid.")
                Sleep(3000)
                ToolTip()
                Cleanup()
                gridActivationInProgress := false
                return
            }
        }

        ; --- 5. Validate GUI Objects (Simplified) ---
        ; We now assume highlight and subGrid exist, but currentOverlay must be valid
        if (!IsObject(StateMap['currentOverlay'])) {
            LogToFile(Format("Timestamp: {} | ERROR: Failed to set a valid currentOverlay after checking monitors.",
                A_TickCount), "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Critical error: Could not determine the active monitor overlay.")
                Sleep(2000)
                ToolTip()
            }
            Cleanup()
            gridActivationInProgress := false
            return
        }
        ; Also ensure highlight/subgrid are still valid objects before proceeding
        if (!IsObject(highlight) || !IsObject(subGrid)) {
            LogToFile(Format(
                "Timestamp: {} | ERROR: highlight or subGrid object became invalid! highlight={}, subGrid={}",
                A_TickCount, IsObject(highlight), IsObject(subGrid)), "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Critical error: Highlight or SubGrid object is missing.")
                Sleep(2000)
                ToolTip()
            }
            Cleanup()
            gridActivationInProgress := false
            return
        }

        LogToFile(Format("Timestamp: {} | CapsLock_Q: GUI objects validated. CurrentOverlay Monitor: {}", A_TickCount,
            StateMap['currentOverlay'].monitorIndex), "antimouse_core.log")

        ; --- 6. Transition to GRID_VISIBLE and Start Tracking (Keep this) ---
        TransitionToState(State_GRID_VISIBLE)
        LogToFile(Format("Timestamp: {} | CapsLock_Q: Transitioned to GRID_VISIBLE", A_TickCount), "antimouse_core.log"
        )

        ; --- 7. Immediate Subgrid Detection (Keep this) ---
        initialCellKey := GetCurrentCell()
        if (initialCellKey != "") {
            LogToFile(Format("Timestamp: {} | CapsLock_Q: Initial cell '{}' detected, attempting immediate subgrid.",
                A_TickCount, initialCellKey), "antimouse_core.log")
            if (IsObject(StateMap["currentOverlay"])) {
                try {
                    initialBoundaries := StateMap["currentOverlay"].GetCellBoundaries(initialCellKey)
                    if (IsObject(initialBoundaries)) {
                        StateMap["activeCellKey"] := initialCellKey
                        if (IsObject(highlight)) {
                            highlight.Update(initialBoundaries.x, initialBoundaries.y, initialBoundaries.w,
                                initialBoundaries.h)
                        }
                        if (IsObject(subGrid)) {
                            ; Ensure standard layout before updating
                            subGrid.SwitchToStandard()
                            subGrid.Update(initialBoundaries.x, initialBoundaries.y, initialBoundaries.w,
                                initialBoundaries.h)
                        }
                        TransitionToState(State_SUBGRID_STANDARD)
                        LogToFile(Format(
                            "Timestamp: {} | CapsLock_Q: Successfully transitioned to immediate SUBGRID_STANDARD for cell '{}'",
                            A_TickCount, initialCellKey), "antimouse_core.log")
                    } else {
                        LogToFile(Format("Timestamp: {} | WARNING: Failed to get boundaries for initial cell '{}'",
                            A_TickCount, initialCellKey), "antimouse_core.log")
                    }
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR during immediate subgrid boundary/update: {}", A_TickCount,
                        e.Message), "antimouse_core.log")
                }
            } else {
                LogToFile(Format("Timestamp: {} | WARNING: currentOverlay invalid during immediate subgrid check.",
                    A_TickCount), "antimouse_core.log")
            }
        }

        ; Start the tracking timer (Moved after immediate subgrid check)
        SetTimer(TrackCursor, 50)
        LogToFile(Format("Timestamp: {} | CapsLock_Q: TrackCursor timer started.", A_TickCount), "antimouse_core.log")

    } catch as e {
        ; Log error and clean up
        LogToFile(Format("Timestamp: {} | CapsLock_Q: FATAL ERROR during activation: {}", A_TickCount, e.Message),
        "antimouse_core.log")
        if (showcaseDebug) {
            ToolTip("Fatal Error during activation: " e.Message)
            Sleep(2000)
            ToolTip()
        }
        Cleanup() ; Attempt cleanup
    }

    ; Reset activation flag ONLY if successful or after cleanup
    gridActivationInProgress := false
    LogToFile(Format("Timestamp: {} | CapsLock_Q END. currentState={}", A_TickCount, currentState),
    "antimouse_core.log")
}

; --- Grid Cleanup ---

; Cleans up all GUI elements and resets the state to IDLE.
Cleanup() {
    global currentState, highlight, subGrid, StateMap, showcaseDebug, enableVerboseLogging, gridActivationInProgress,
        g_ModifierState, OFFSCREEN_X, OFFSCREEN_Y

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

    ; 4. Move GUI objects off-screen instead of destroying them
    try {
        ; 4.1 First move overlays off-screen one by one
        if (StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            LogToFile(Format("Timestamp: {} | CLEANUP: Moving {} overlays off-screen",
                A_TickCount, StateMap['overlays'].Length) "`n", "antimouse_core.log")

            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    try {
                        LogToFile(Format("Timestamp: {} | CLEANUP: Moving overlay {} off-screen",
                            A_TickCount, i) "`n", "antimouse_core.log")
                        overlay.Hide() ; Now moves it off-screen instead of destroying
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | WARNING: Error moving overlay {} off-screen: {}",
                            A_TickCount, i, e.Message) "`n", "antimouse_core.log")
                    }
                }
            }
            ; Keep overlay references in the array instead of clearing
            LogToFile(Format("Timestamp: {} | CLEANUP: Overlays moved off-screen and preserved", A_TickCount) "`n",
            "antimouse_core.log")
        }

        ; 4.2 Next move highlight off-screen
        if (IsObject(highlight)) {
            try {
                LogToFile(Format("Timestamp: {} | CLEANUP: Moving highlight off-screen",
                    A_TickCount) "`n", "antimouse_core.log")
                highlight.Hide() ; Now moves it off-screen instead of destroying
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error moving highlight off-screen: {}",
                    A_TickCount, e.Message) "`n", "antimouse_core.log")
            }
            ; Keep highlight reference instead of clearing
            LogToFile(Format("Timestamp: {} | CLEANUP: Highlight moved off-screen and preserved", A_TickCount) "`n",
            "antimouse_core.log")
        }

        ; 4.3 Finally move subgrid off-screen
        if (IsObject(subGrid)) {
            try {
                LogToFile(Format("Timestamp: {} | CLEANUP: Moving subGrid off-screen",
                    A_TickCount) "`n", "antimouse_core.log")
                subGrid.Hide() ; Now moves it off-screen instead of destroying
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error moving subGrid off-screen: {}",
                    A_TickCount, e.Message) "`n", "antimouse_core.log")
            }
            ; Keep subgrid reference instead of clearing
            LogToFile(Format("Timestamp: {} | CLEANUP: SubGrid moved off-screen and preserved", A_TickCount) "`n",
            "antimouse_core.log")
        }

        ; 4.4 Clear current overlay reference but keep the overlays array
        StateMap['currentOverlay'] := ""
        LogToFile(Format("Timestamp: {} | CLEANUP: currentOverlay reference cleared but overlays preserved",
            A_TickCount) "`n", "antimouse_core.log")
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Exception during GUI movement off-screen: {}",
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
        g_ModifierState, saveMemoryOnExit, cellMemory, showcaseDebug, enableVerboseLogging, gridActivationInProgress,
        OFFSCREEN_X, OFFSCREEN_Y

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

    ; 4. Move GUI objects off-screen instead of destroying them
    try {
        ; 4.1 First move overlays off-screen one by one
        if (StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Moving {} overlays off-screen",
                currentTime, StateMap['overlays'].Length) "`n", "antimouse_core.log")

            for i, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    try {
                        overlay.Hide() ; Now moves off-screen instead of destroying
                        LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Moved overlay {} off-screen",
                            currentTime, i) "`n", "antimouse_core.log")
                    } catch as e {
                        LogToFile(Format("Timestamp: {} | WARNING: Error moving overlay {} off-screen: {}",
                            currentTime, i, e.Message) "`n", "antimouse_core.log")
                    }
                }
            }
            ; Keep overlay references instead of clearing
        }
        StateMap['currentOverlay'] := "" ; Clear current overlay reference but keep array

        ; 4.2 Next move subgrid off-screen
        if (IsObject(subGrid)) {
            try {
                subGrid.Hide() ; Now moves off-screen instead of destroying
                LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Moved subGrid off-screen",
                    currentTime) "`n", "antimouse_core.log")
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error moving subGrid off-screen: {}",
                    currentTime, e.Message) "`n", "antimouse_core.log")
            }
            ; Keep subGrid reference
        }

        ; 4.3 Finally move highlight off-screen
        if (IsObject(highlight)) {
            try {
                highlight.Hide() ; Now moves off-screen instead of destroying
                LogToFile(Format("Timestamp: {} | DEACTIVATEGRID: Moved highlight off-screen",
                    currentTime) "`n", "antimouse_core.log")
            } catch as e {
                LogToFile(Format("Timestamp: {} | WARNING: Error moving highlight off-screen: {}",
                    currentTime, e.Message) "`n", "antimouse_core.log")
            }
            ; Keep highlight reference
        }
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR: Exception during GUI movement off-screen: {}",
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

; ==============================================================================
; GUI Initialization (Called at Startup)
; ==============================================================================
InitializeGUIs() {
    global highlight, subGrid, StateMap, layoutConfigs, selectedLayout, OFFSCREEN_X, OFFSCREEN_Y, showcaseDebug,
        enableVerboseLogging

    LogToFile(Format("Timestamp: {} | InitializeGUIs START", A_TickCount), "antimouse_core.log")

    ; Ensure config is loaded before accessing layouts
    if (!IsObject(layoutConfigs) || layoutConfigs.Count == 0) {
        LogToFile(Format("Timestamp: {} | ERROR in InitializeGUIs: layoutConfigs not loaded!", A_TickCount),
        "antimouse_core.log")
        MsgBox("Error: Layout configurations not loaded before GUI initialization. Exiting.")
        ExitApp()
        return ; Added return for clarity
    }

    ; --- 1. Initialize Highlight Overlay ---
    try {
        if (!IsObject(highlight)) {
            LogToFile(Format("Timestamp: {} | InitializeGUIs: Creating HighlightOverlay", A_TickCount),
            "antimouse_core.log")
            highlight := HighlightOverlay()
            highlight.Hide() ; Move off-screen immediately
            LogToFile(Format("Timestamp: {} | InitializeGUIs: HighlightOverlay created and hidden", A_TickCount),
            "antimouse_core.log")
        } else {
            LogToFile(Format("Timestamp: {} | InitializeGUIs: HighlightOverlay already exists, ensuring hidden",
                A_TickCount), "antimouse_core.log")
            highlight.Hide()
        }
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR creating/hiding HighlightOverlay: {}", A_TickCount, e.Message),
        "antimouse_core.log")
        MsgBox("Error initializing Highlight Overlay: " e.Message ". Exiting.")
        ExitApp()
        return ; Added return for clarity
    }

    ; --- 2. Initialize SubGrid Overlay ---
    try {
        if (!IsObject(subGrid)) {
            LogToFile(Format("Timestamp: {} | InitializeGUIs: Creating SubGridOverlay", A_TickCount),
            "antimouse_core.log")
            subGrid := SubGridOverlay()
            subGrid.Hide() ; Move off-screen immediately
            LogToFile(Format("Timestamp: {} | InitializeGUIs: SubGridOverlay created and hidden", A_TickCount),
            "antimouse_core.log")
        } else {
            LogToFile(Format("Timestamp: {} | InitializeGUIs: SubGridOverlay already exists, ensuring hidden",
                A_TickCount), "antimouse_core.log")
            subGrid.Hide()
        }
    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR creating/hiding SubGridOverlay: {}", A_TickCount, e.Message),
        "antimouse_core.log")
        MsgBox("Error initializing SubGrid Overlay: " e.Message ". Exiting.")
        ExitApp()
        return ; Added return for clarity
    }

    ; --- 3. Initialize Monitor Overlays ---
    try {
        LogToFile(Format("Timestamp: {} | InitializeGUIs: Preparing monitor overlays", A_TickCount),
        "antimouse_core.log")
        monitorCount := MonitorGetCount()
        LogToFile(Format("Timestamp: {} | InitializeGUIs: Detected {} monitors", A_TickCount, monitorCount),
        "antimouse_core.log")

        ; Get configured layout keys
        currentConfig := layoutConfigs.Has(selectedLayout) ? layoutConfigs[selectedLayout] : layoutConfigs[2] ; Default to 2 if invalid
        if (!IsObject(currentConfig) || !currentConfig.Has("colKeys") || !currentConfig.Has("rowKeys")) {
            LogToFile(Format("Timestamp: {} | ERROR in InitializeGUIs: Invalid layout config for layout {}",
                A_TickCount, selectedLayout), "antimouse_core.log")
            MsgBox("Error: Invalid layout configuration detected during GUI initialization. Exiting.")
            ExitApp()
            return ; Added return for clarity
        }
        colKeys := currentConfig["colKeys"]
        rowKeys := currentConfig["rowKeys"]
        LogToFile(Format("Timestamp: {} | InitializeGUIs: Using layout {} ({}x{})", A_TickCount, selectedLayout,
            colKeys.Length, rowKeys.Length), "antimouse_core.log")

        ; Ensure StateMap['overlays'] is an array
        if (!StateMap.Has('overlays') || !IsObject(StateMap['overlays'])) {
            StateMap['overlays'] := []
        }

        existingOverlays := StateMap['overlays']
        newOverlays := []

        ; Create or update overlays for each monitor
        loop monitorCount {
            monitorIndex := A_Index
            MonitorGet(monitorIndex, &Left, &Top, &Right, &Bottom)
            LogToFile(Format("Timestamp: {} | InitializeGUIs: Processing Monitor {} ({},{},{},{})", A_TickCount,
                monitorIndex, Left, Top, Right, Bottom), "antimouse_core.log")

            overlay := ""
            ; Check if an overlay for this index already exists
            if (monitorIndex <= existingOverlays.Length && IsObject(existingOverlays[monitorIndex])) {
                overlay := existingOverlays[monitorIndex]
                ; TODO: Check if layout/monitor bounds changed and recreate if necessary? For now, assume reuse is okay.
                LogToFile(Format("Timestamp: {} | InitializeGUIs: Reusing overlay for Monitor {}", A_TickCount,
                    monitorIndex), "antimouse_core.log")
            } else {
                LogToFile(Format("Timestamp: {} | InitializeGUIs: Creating new overlay for Monitor {}", A_TickCount,
                    monitorIndex), "antimouse_core.log")
                overlay := OverlayGUI(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys)
                if (!IsObject(overlay)) {
                    LogToFile(Format(
                        "Timestamp: {} | ERROR in InitializeGUIs: Failed to create OverlayGUI for Monitor {}",
                        A_TickCount, monitorIndex), "antimouse_core.log")
                    MsgBox("Error creating overlay for Monitor " monitorIndex ". Exiting.")
                    ExitApp()
                    return ; Added return for clarity
                }
            }

            overlay.Hide() ; Ensure it starts hidden (off-screen)
            newOverlays.Push(overlay) ; Add to the new list
        }

        ; Replace the old overlays array with the potentially updated one
        StateMap['overlays'] := newOverlays
        LogToFile(Format("Timestamp: {} | InitializeGUIs: Finished creating/updating {} overlays. All hidden.",
            A_TickCount, StateMap['overlays'].Length), "antimouse_core.log")

    } catch as e {
        LogToFile(Format("Timestamp: {} | ERROR initializing Monitor Overlays: {}", A_TickCount, e.Message),
        "antimouse_core.log")
        MsgBox("Error initializing Monitor Overlays: " e.Message ". Exiting.")
        ExitApp()
        return ; Added return for clarity
    }

    LogToFile(Format("Timestamp: {} | InitializeGUIs COMPLETE", A_TickCount), "antimouse_core.log")
}
