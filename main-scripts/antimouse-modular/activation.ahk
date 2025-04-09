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
    global g_firstKeyPressed ; Add explicit global reference
    global enableVerboseLogging ; Added enableVerboseLogging

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug)
        FileAppend(Format("Timestamp: {} | CapsLock_Q START | currentState={} | firstKey={}", A_TickCount,
            currentState, StateMap['firstKey']) "`n", A_ScriptDir "\debugRapidRefresh.log")
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q START | currentState='{}' | g_firstKeyPressed='{}'",
            A_TickCount, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    }
    ; <<< ADD LOGGING END >>>
    ; Protect against double activation
    if (gridActivationInProgress || (currentTime - gridActivationTime < 300)) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Activation already in progress, ignoring",
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
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: State not IDLE (state='{}'), calling Cleanup()",
            A_TickCount, currentState) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format("Timestamp: {} | CapsLock_Q: Already Active, Calling Cleanup", currentTime
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
        FileAppend(Format(
            "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Resetting state variables. Before: firstKey='{}', g_firstKeyPressed='{}'",
            A_TickCount, StateMap['firstKey'], g_firstKeyPressed) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format(
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

        ; Explicitly reset the global g_firstKeyPressed variable
        g_firstKeyPressed := ""

        ; Explicitly initialize ultra-fast mode state variables
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['rowKeyHeldTime'] := 0

        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format(
            "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: State variables reset. After: firstKey='{}', g_firstKeyPressed='{}'",
            A_TickCount, StateMap['firstKey'], g_firstKeyPressed) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        ; <<< ADD LOGGING START >>>
        if (showcaseDebug) FileAppend(Format(
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
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Setting active keys from config. Cols={}, Rows={}",
                A_TickCount, currentConfig["colKeys"].Length, currentConfig["rowKeys"].Length) "`n",
            "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            StateMap['activeColKeys'] := currentConfig["colKeys"] ; Use StateMap
            StateMap['activeRowKeys'] := currentConfig["rowKeys"] ; Use StateMap
        } else {
            ; Fallback to a basic layout if config is invalid
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Using fallback layout",
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
            FileAppend(Format("Timestamp: {} | DEBUG: About to initialize highlight and subGrid", A_TickCount) "`n",
            "antimouse_core.log")

            highlight := HighlightOverlay()
            FileAppend(Format("Timestamp: {} | DEBUG: HighlightOverlay created successfully", A_TickCount) "`n",
            "antimouse_core.log")

            subGrid := SubGridOverlay()
            FileAppend(Format("Timestamp: {} | DEBUG: SubGridOverlay created successfully, IsObject(subGrid)={}",
                A_TickCount, IsObject(subGrid)) "`n", "antimouse_core.log")
        } catch as e {
            FileAppend(Format("Timestamp: {} | ERROR: Failed to initialize GUI: {}", A_TickCount, e.Message) "`n",
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
                FileAppend(Format("Timestamp: {} | CapsLock_Q: Creating OverlayGUI for Monitor {}", A_TickCount,
                    A_Index) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, StateMap['activeColKeys'], StateMap[
                    'activeRowKeys']) ; Use StateMap
                FileAppend(Format("Timestamp: {} | CapsLock_Q: OverlayGUI created. IsObject(overlay) = {}", A_TickCount,
                    IsObject(overlay)) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                if (IsObject(overlay)) { ; Only proceed if overlay created successfully
                    overlay.Show()
                    StateMap['overlays'].Push(overlay) ; Use StateMap

                    containsPointResult := overlay.ContainsPoint(startX, startY)
                    FileAppend(Format("Timestamp: {} | CapsLock_Q: Monitor {} ContainsPoint({}, {}) = {}", A_TickCount,
                        A_Index, startX, startY, containsPointResult) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                    if (containsPointResult) {
                        StateMap['currentOverlay'] := overlay ; Use StateMap
                        foundMonitor := true
                        FileAppend(Format("Timestamp: {} | CapsLock_Q: Set currentOverlay to Monitor {}", A_TickCount,
                            A_Index) "`n", "antimouse_core.log") ; <<< CORE LOGGING
                    }
                }
            } catch as e {
                FileAppend(Format("Timestamp: {} | CapsLock_Q: ERROR creating overlay for Monitor {}: {}", A_TickCount,
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
        FileAppend(Format(
            "Timestamp: {} | CapsLock_Q: Checking condition: overlays.Length={}, IsObject(currentOverlay)={}",
            A_TickCount, StateMap['overlays'].Length, IsObject(StateMap['currentOverlay'])) "`n", "antimouse_core.log") ; <<< CORE LOGGING
        if (StateMap['overlays'].Length > 0 && IsObject(StateMap['currentOverlay'])) { ; Use StateMap
            FileAppend(Format("Timestamp: {} | CapsLock_Q: Condition TRUE. Grid activated. Attempting instant subgrid.",
                A_TickCount) "`n", "antimouse_core.log") ; <<< CORE LOGGING (Adjusted)

            ; Replace direct assignment with TransitionToState
            TransitionToState(State_GRID_VISIBLE) ; Use transition function instead of direct assignment

            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Set currentState via TransitionToState to 'GRID_VISIBLE'",
                A_TickCount) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            ; Enable cursor tracking timer AFTER grid is fully set up
            try {
                FileAppend(Format("Timestamp: {} | CapsLock_Q: Attempting SetTimer(TrackCursor, 50).", A_TickCount)
                "`n", "antimouse_core.log")
                SetTimer(TrackCursor, 50)
                FileAppend(Format("Timestamp: {} | CapsLock_Q: SetTimer(TrackCursor, 50) called successfully.",
                    A_TickCount) "`n", "antimouse_core.log")
            } catch as e {
                FileAppend(Format("Timestamp: {} | CapsLock_Q: ERROR setting TrackCursor timer: {}", A_TickCount,
                    e.Message) "`n", "antimouse_core.log")
                if (showcaseDebug) {
                    ToolTip("Error starting cursor tracker: " e.Message)
                }
            }

            gridActivationInProgress := false
        } else {
            FileAppend(Format("Timestamp: {} | CapsLock_Q: Condition FALSE. Calling Cleanup().", A_TickCount) "`n",
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
    FileAppend(Format("Timestamp: {} | CapsLock_Q FINISHED | currentState={}", A_TickCount, currentState) "`n",
    "antimouse_core.log") ; <<< CORE LOGGING
}

; --- Grid Cleanup ---

; Cleans up all GUI elements and resets the state to IDLE.
Cleanup() {
    FileAppend(Format("Timestamp: {} | Cleanup() Function START", A_TickCount) "`n", "antimouse_core.log") ; <<< CORE LOGGING
    ; Access global state
    global currentState, highlight, subGrid, StateMap, g_ModifierState, gridActivationInProgress, showcaseDebug
    global enableVerboseLogging ; Added enableVerboseLogging

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format("Timestamp: {} | Cleanup START | currentState={}", currentTime, currentState) "`n",
    A_ScriptDir "\debugRapidRefresh.log")
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | Cleanup START | currentState={}", currentTime, currentState) "`n",
            "antimouse_core.log")
        }
    ; <<< ADD LOGGING END >>>
    ; Prevent cleanup if already idle (avoids redundant actions)
    if (currentState == State_IDLE) {
        gridActivationInProgress := false ; Still ensure this flag is reset
        return
    }

    ; --- Immediate State Reset ---
    ; Stop cursor tracking first to prevent interference
    SetTimer(TrackCursor, 0)
    ; Set state to IDLE immediately to prevent re-entry or conflicts
    TransitionToState(State_IDLE) ; Use the transition function
    FileAppend(Format("Timestamp: {} | Cleanup: Set currentState = {}. Attempting short Sleep...", A_TickCount,
        currentState) "`n", "antimouse_core.log") ; <<< CORE LOGGING (Adjusted)
    Sleep(10) ; Attempt to allow AHK to process state change
    FileAppend(Format("Timestamp: {} | Cleanup: Finished Sleep.", A_TickCount) "`n", "antimouse_core.log") ; <<< CORE LOGGING (Adjusted)

    ; Reset flags
    g_ModifierState.inHoldMode := false
    gridActivationInProgress := false
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | Cleanup: Resetting State (Before) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
        currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log"
    )
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Cleanup: Resetting State (Before) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
                currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n",
            A_ScriptDir "\debugRapidRefresh.log"
            )
        }
    ; <<< ADD LOGGING END >>>
    StateMap['firstKey'] := "" ; Clear partial selections

    ; --- Reset Ultra-Fast Mode State ---
    StateMap['inUltraFastMode'] := false ; Ensure ultra-fast mode is deactivated
    StateMap['activeRowKey'] := "" ; Clear the active row key
    StateMap['rowKeyHeldTime'] := 0 ; Reset the hold time
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | Cleanup: Reset State (After) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
        currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log"
    )
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format(
                "Timestamp: {} | Cleanup: Reset State (After) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
                currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n",
            A_ScriptDir "\debugRapidRefresh.log"
            )
        }
    ; <<< ADD LOGGING END >>>
    ; Clear any lingering tooltips
    ToolTip()

    ; --- Hide GUI Elements (Best Effort) ---
    ; Use try/catch for each element as they might already be destroyed or invalid
    try {
        if (IsObject(highlight)) {
            highlight.Hide()
        }
    } catch { ; Ignore error
    }
    try {
        if (IsObject(subGrid)) {
            subGrid.Hide()
        }
    } catch { ; Ignore error
    }
    try {
        for overlay in StateMap['overlays'] {
            if (IsObject(overlay)) {
                try {
                    overlay.Hide()
                } catch { ; Ignore error hiding single overlay
                }
            }
        }
    } catch { ; Ignore error iterating overlays
    }

    Sleep(30) ; Short delay to allow GUIs time to hide visually

    ; --- Destroy GUI Elements (Best Effort) ---
    try {
        if (IsObject(highlight)) {
            highlight.Destroy()
        }
    } catch { ; Ignore error
    }
    try {
        if (IsObject(subGrid)) {
            subGrid.Destroy()
            subGrid := ""
        }
    } catch { ; Ignore error
    }
    try {
        for overlay in StateMap['overlays'] {
            if (IsObject(overlay)) {
                try {
                    overlay.Destroy()
                } catch { ; Ignore error destroying single overlay
                }
            }
        }
    } catch { ; Ignore error iterating overlays
    }

    ; --- Reset Global Object References ---
    highlight := ""
    subGrid := ""
    StateMap['overlays'] := []
    StateMap['currentOverlay'] := ""
    ; Keep other StateMap elements like keys, indices as they are reset on next activation

    ; --- Force Close Any Remaining GUIs ---
    ; Use utility function as a final safeguard
    try {
        ForceCloseAllGuis() ; Function from utils.ahk
    } catch { ; Ignore error
    }
    Sleep(10) ; Final small delay
    if (showcaseDebug)
        ToolTip("Cleanup complete. State: IDLE")
}

; Deactivate the grid and clean up
DeactivateGrid(forced := false) {
    global subGrid, highlight, currentState, StateMap, gridActivationTime, stateTransitionDelay,
        g_ModifierState, saveMemoryOnExit, cellMemory, showcaseDebug, enableVerboseLogging ; Added enableVerboseLogging

    currentTime := A_TickCount
    if (showcaseDebug) {
        FileAppend(Format("Timestamp: {} | DeactivateGrid START | forced={} | currentState={}", currentTime, forced,
            currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING START >>>
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format("Timestamp: {} | DeactivateGrid called | forced={}, currentState={}", A_TickCount, forced,
            currentState) "`n", "antimouse_core.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Check if deactivation is happening too quickly after activation
    ; Use stateTransitionDelay to prevent accidental immediate closure
    if (!forced && (currentTime - gridActivationTime < stateTransitionDelay)) {
        if (showcaseDebug) {
            FileAppend(Format("Timestamp: {} | DeactivateGrid: Debounced (Activation too recent)", currentTime) "`n",
            A_ScriptDir "\debugRapidRefresh.log")
        }
        if (enableVerboseLogging) { ; <<< WRAPPED
            FileAppend(Format("Timestamp: {} | DeactivateGrid debounced.", A_TickCount) "`n", "antimouse_core.log")
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
            FileAppend(Format("Timestamp: {} | DeactivateGrid: Saving cell memory.", A_TickCount) "`n",
            "antimouse_core.log")
        }
        SaveCellMemory()
    }
    if (showcaseDebug) {
        FileAppend(Format("Timestamp: {} | DeactivateGrid END | currentState={}", A_TickCount, currentState) "`n",
        A_ScriptDir "\debugRapidRefresh.log")
    }
    if (enableVerboseLogging) { ; <<< WRAPPED
        FileAppend(Format("Timestamp: {} | DeactivateGrid END | currentState={}", A_TickCount, currentState) "`n",
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
    global g_firstKeyPressed ; Add explicit global reference
}

; --- Cell Memory Management --- START ---
; <<< REMOVE START >>>
; ... existing code ...
; <<< REMOVE END >>>
; --- Cell Memory Management --- END ---
