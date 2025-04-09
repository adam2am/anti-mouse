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

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format("Timestamp: {} | CapsLock_Q START | currentState={}", currentTime,
        currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Protect against double activation
        if (gridActivationInProgress || (currentTime - gridActivationTime < 300)) {
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
    if (currentState != "IDLE") {
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

        ; Explicitly initialize ultra-fast mode state variables
        StateMap['inUltraFastMode'] := false
        StateMap['activeRowKey'] := ""
        StateMap['rowKeyHeldTime'] := 0
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
            StateMap['activeColKeys'] := currentConfig["colKeys"] ; Use StateMap
            StateMap['activeRowKeys'] := currentConfig["rowKeys"] ; Use StateMap
        } else {
            ; Fallback to a basic layout if config is invalid
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
            highlight := HighlightOverlay()
            subGrid := SubGridOverlay()
        } catch as e {
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
                overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, StateMap['activeColKeys'], StateMap[
                    'activeRowKeys']) ; Use StateMap
                overlay.Show()
                StateMap['overlays'].Push(overlay) ; Use StateMap

                if (overlay.ContainsPoint(startX, startY)) {
                    StateMap['currentOverlay'] := overlay ; Use StateMap
                    foundMonitor := true
                }
            } catch as e {
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
        if (StateMap['overlays'].Length > 0 && IsObject(StateMap['currentOverlay'])) { ; Use StateMap
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format(
                "Timestamp: {} | CapsLock_Q: Setting currentState=GRID_VISIBLE (Before) | currentState={}", currentTime,
                currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
                currentState := "GRID_VISIBLE"
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format(
                "Timestamp: {} | CapsLock_Q: Set currentState=GRID_VISIBLE (After) | currentState={}", currentTime,
                currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
                SetTimer(TrackCursor, 50)
            gridActivationInProgress := false
        } else {
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
}

; --- Grid Cleanup ---

; Cleans up all GUI elements and resets the state to IDLE.
Cleanup() {
    FileAppend(Format("Timestamp: {} | Cleanup() Function START", A_TickCount) "`n", "antimouse_core.log") ; <<< CORE LOGGING
    ; Access global state
    global currentState, highlight, subGrid, StateMap, g_ModifierState, gridActivationInProgress, showcaseDebug

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format("Timestamp: {} | Cleanup START | currentState={}", currentTime, currentState) "`n",
    A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
    ; Prevent cleanup if already idle (avoids redundant actions)
        if (currentState == "IDLE") {
            gridActivationInProgress := false ; Still ensure this flag is reset
            return
        }

    ; --- Immediate State Reset ---
    ; Stop cursor tracking first to prevent interference
    SetTimer(TrackCursor, 0)
    ; Set state to IDLE immediately to prevent re-entry or conflicts
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | Cleanup: Setting currentState=IDLE (Before) | currentState={}", currentTime, currentState) "`n",
    A_ScriptDir "\debugRapidRefresh.log")
    ; <<< ADD LOGGING END >>>
        currentState := "IDLE"
    ; Reset flags
    g_ModifierState.inHoldMode := false
    gridActivationInProgress := false
    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format(
        "Timestamp: {} | Cleanup: Resetting State (Before) | firstKey={} | inUltraFastMode={} | activeRowKey={}",
        currentTime, StateMap['firstKey'], StateMap['inUltraFastMode'], StateMap['activeRowKey']) "`n", A_ScriptDir "\debugRapidRefresh.log"
    )
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
            highlight := ""
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
