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

    ; Define currentTime at the beginning for all code paths
    currentTime := A_TickCount

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q START | currentState='{}' | g_firstKeyPressed='{}'",
        A_TickCount, currentState, g_firstKeyPressed) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) FileAppend(Format("Timestamp: {} | CapsLock_Q START | currentState={}", currentTime,
        currentState) "`n", A_ScriptDir "\debugRapidRefresh.log")
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
    if (currentState != "IDLE") {
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
            currentState := "GRID_VISIBLE" ; Set temporarily

            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format("Timestamp: {} | DIAGNOSTIC | CapsLock_Q: Set currentState = 'GRID_VISIBLE'",
                A_TickCount) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            ; --- BEGIN INSTANT SUBGRID LOGIC ---
            initialCellKey := GetCellAtPosition(startX, startY)
            FileAppend(Format("Timestamp: {} | CapsLock_Q: Cell at initial cursor ({},{}): '{}'", A_TickCount, startX,
                startY, initialCellKey) "`n", "antimouse_core.log")

            if (initialCellKey != "") {
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(initialCellKey)
                if (IsObject(boundaries)) {
                    FileAppend(Format(
                        "Timestamp: {} | CapsLock_Q: Got boundaries for initial cell. Updating & Showing Subgrid.",
                        A_TickCount) "`n", "antimouse_core.log")
                    StateMap['activeCellKey'] := initialCellKey
                    stateTransitionTime := A_TickCount ; Use current time for transition

                    ; Update and show subgrid
                    subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                    subGrid.Show()

                    ; --- Isolate Highlight calls ---
                    try {
                        FileAppend(Format("Timestamp: {} | CapsLock_Q: Attempting highlight.Update/Show.", A_TickCount) "`n",
                        "antimouse_core.log")
                        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                    } catch as e {
                        FileAppend(Format("Timestamp: {} | CapsLock_Q: **** ERROR during highlight.Update/Show: {}",
                            A_TickCount, e.Message) "`n", "antimouse_core.log")
                    }
                    ; ----------------------------

                    ; Update state to SUBGRID_ACTIVE
                    ; --- Isolate state assignment ---
                    try {
                        FileAppend(Format(
                            "Timestamp: {} | CapsLock_Q: Attempting to set currentState = SUBGRID_ACTIVE.", A_TickCount
                        ) "`n", "antimouse_core.log")
                        currentState := "SUBGRID_ACTIVE"
                        FileAppend(Format("Timestamp: {} | CapsLock_Q: Successfully set currentState = {}.",
                            A_TickCount, currentState) "`n", "antimouse_core.log")
                    } catch as state_e {
                        FileAppend(Format(
                            "Timestamp: {} | CapsLock_Q: **** ERROR setting currentState = SUBGRID_ACTIVE: {}.",
                            A_TickCount, state_e.Message) "`n", "antimouse_core.log")
                        ; Allow script to continue to see if memory check also errors
                    }
                    ; ---------------------------------
                    ; FileAppend(Format("Timestamp: {} | CapsLock_Q: Set state to SUBGRID_ACTIVE for cell '{}'", A_TickCount, initialCellKey) "`n", "antimouse_core.log") ; Moved inside try block

                    ; Optional: Check cell memory
                    try {
                        rememberedSubCell := ""
                        cellFound := false
                        if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                            monitorCellKey := StateMap['currentOverlay'].monitorIndex . "_" . initialCellKey
                            if (cellMemory.Has(monitorCellKey)) {
                                rememberedSubCell := cellMemory[monitorCellKey]
                                cellFound := true
                            }
                        }
                        if (!cellFound && cellMemory.Has(initialCellKey)) {
                            rememberedSubCell := cellMemory[initialCellKey]
                            cellFound := true
                        }
                        if (cellFound && rememberedSubCell != "") {
                            FileAppend(Format(
                                "Timestamp: {} | CapsLock_Q: Found remembered subcell '{}'. Preparing to call handler.",
                                A_TickCount, rememberedSubCell) "`n", "antimouse_core.log")
                            ; --- FIX: Handle ultra: prefix ---
                            if (SubStr(rememberedSubCell, 1, 6) == "ultra:") {
                                actualSubCellKey := SubStr(rememberedSubCell, 7)
                                HandleUltraFastKey(actualSubCellKey)
                            } else {
                                HandleSubGridKey(rememberedSubCell) ; Handle standard subcell
                            }
                            ; --- END FIX ---
                        } else {
                            ; If no memory, just move cursor to center of main cell
                            FileAppend(Format("Timestamp: {} | CapsLock_Q: No remembered subcell. Moving to center.",
                                A_TickCount) "`n", "antimouse_core.log")
                            ; --- REMOVED CURSOR SNAPPING (Activation - No Memory) ---
                            ; MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
                        }
                    } catch as mem_e {
                        FileAppend(Format(
                            "Timestamp: {} | CapsLock_Q: **** ERROR during cell memory check/call: {}. Staying SUBGRID_ACTIVE.",
                            A_TickCount, mem_e.Message) "`n", "antimouse_core.log")
                        ; Don't cleanup here, allow state to persist for debugging
                    }
                    ; ---------------------------------------------------------

                } else {
                    FileAppend(Format(
                        "Timestamp: {} | CapsLock_Q: Failed to get boundaries for initial cell '{}'. Staying GRID_VISIBLE.",
                        A_TickCount, initialCellKey) "`n", "antimouse_core.log")
                    currentState := "GRID_VISIBLE" ; Revert if boundary fails
                }
            } else {
                FileAppend(Format(
                    "Timestamp: {} | CapsLock_Q: No initial cell found under cursor. Staying GRID_VISIBLE.",
                    A_TickCount) "`n", "antimouse_core.log")
                currentState := "GRID_VISIBLE" ; Stay in grid mode if no cell found
            }
            ; --- END INSTANT SUBGRID LOGIC ---

            ; --- Isolate SetTimer call ---
            try {
                FileAppend(Format("Timestamp: {} | CapsLock_Q: Attempting SetTimer(TrackCursor, 50).", A_TickCount) "`n",
                "antimouse_core.log")
                SetTimer(TrackCursor, 50)
                FileAppend(Format("Timestamp: {} | CapsLock_Q: SetTimer(TrackCursor, 50) called successfully.",
                    A_TickCount) "`n", "antimouse_core.log")
            } catch as timer_e {
                FileAppend(Format(
                    "Timestamp: {} | CapsLock_Q: **** ERROR calling SetTimer(TrackCursor): {}. Staying SUBGRID_ACTIVE.",
                    A_TickCount, timer_e.Message) "`n", "antimouse_core.log")
                ; Don't cleanup
            }
            ; -----------------------------

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
    currentState := "IDLE"
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
