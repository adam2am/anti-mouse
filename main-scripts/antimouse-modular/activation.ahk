; ==============================================================================
; activation.ahk - Grid Activation and Cleanup Logic
; ==============================================================================

; --- Grid Activation ---

; Main function to activate the grid overlays. Called by activation hotkeys.
CapsLock_Q() {
    ; Access global state and config
    global currentState, highlight, subGrid, cellMemory, StateMap
    global selectedLayout, layoutConfigs, showcaseDebug, monitorMapping ; Config needed for layout/overlays
    global gridActivationInProgress, gridActivationTime ; State needed for double activation check

    ; --- Double Activation Prevention ---
    currentTime := A_TickCount
    ; Check if activation is already running or happened very recently
    if (gridActivationInProgress || (currentTime - gridActivationTime < 300)) {
        if (showcaseDebug) {
            ToolTip("Grid activation already in progress or too recent, ignoring duplicate request")
            Sleep(500) ; Show tooltip longer
            ToolTip()
        }
        return ; Exit if activation is already happening
    }

    ; Set activation flag and timestamp
    gridActivationInProgress := true
    gridActivationTime := currentTime

    ; --- Cleanup if Already Active (Shouldn't happen if called from IDLE, but safeguard) ---
    if (currentState != "IDLE") {
        if (showcaseDebug) ToolTip("Warning: CapsLock_Q called when not IDLE. Cleaning up.")
            Cleanup()
        ; Reset flag and exit after cleanup
        gridActivationInProgress := false
        return
    }

    ; --- Initialization ---
    try {
        ; Reset all relevant state variables using StateMap
        StateMap['firstKey'] := ""
        StateMap['currentOverlay'] := ""
        StateMap['activeColKeys'] := []
        StateMap['activeRowKeys'] := []
        StateMap['activeCellKey'] := ""
        StateMap['activeSubCellKey'] := ""
        StateMap['currentColIndex'] := 0
        StateMap['currentRowIndex'] := 0
        StateMap['lastSelectedRowIndex'] := 0
        StateMap['overlays'] := [] ; Clear any previous overlay objects

        ; Load cell memory from file (uses function from memory_settings.ahk)
        LoadCellMemory()

        ; Get configured layout from config.ahk
        if (!layoutConfigs.Has(selectedLayout)) {
            if (showcaseDebug) {
                ToolTip("Invalid layout (" selectedLayout ") in config, falling back to layout 2")
            }
            selectedLayout := 2 ; Fallback to a default layout
        }
        currentConfig := layoutConfigs[selectedLayout]

        ; Validate layout configuration structure
        if (!IsObject(currentConfig) || !currentConfig.Has("colKeys") || !currentConfig.Has("rowKeys") || !IsObject(
            currentConfig["colKeys"]) || !IsObject(currentConfig["rowKeys"])) {
            throw Error("Invalid layout configuration structure for layout: " selectedLayout)
        }

        ; Set up active keys in state map
        StateMap['activeColKeys'] := currentConfig["colKeys"]
        StateMap['activeRowKeys'] := currentConfig["rowKeys"]

        ; Get current mouse position to determine starting monitor
        MouseGetPos(&startX, &startY)
        foundMonitor := false

        ; Initialize reusable GUI elements (Highlight and SubGrid)
        ; Ensure previous instances are destroyed if they somehow exist
        if (IsObject(highlight)) {
            highlight.Destroy()
            highlight := ""
        }
        if (IsObject(subGrid)) {
            subGrid.Destroy()
            subGrid := ""
        }

        ; Create new instances with proper error handling
        try {
            highlight := HighlightOverlay() ; Create new instance (class from gui_classes.ahk)
        } catch as e {
            throw Error("Failed to create HighlightOverlay: " e.Message)
        }

        try {
            subGrid := SubGridOverlay()     ; Create new instance (class from gui_classes.ahk)
        } catch as e {
            throw Error("Failed to create SubGridOverlay: " e.Message)
        }

        ; --- Create Overlays for Each Monitor ---
        monitorCount := MonitorGetCount()
        if (showcaseDebug)
            ToolTip("Found " monitorCount " monitors")

        ; Initialize monitor mapping if needed
        if (!IsObject(monitorMapping) || monitorMapping.Length == 0) {
            monitorMapping := [1] ; At least map the primary monitor
            if (showcaseDebug)
                ToolTip("Warning: No monitor mapping found, defaulting to primary monitor")
        }

        loop monitorCount {
            ; Initialize local variables at the start of each loop iteration
            local overlay := "", Left := 0, Top := 0, Right := 0, Bottom := 0
            physicalMonitorIndex := A_Index

            if (showcaseDebug)
                ToolTip("Processing monitor " physicalMonitorIndex)

            ; Check if this physical monitor should be used based on mapping
            logicalMonitorIndex := 0
            for physIdx, logIdx in monitorMapping {
                if (physIdx == physicalMonitorIndex) {
                    logicalMonitorIndex := Integer(logIdx) ; Ensure we get a number
                    break
                }
            }

            ; Skip if this physical monitor is not mapped or mapped to 0/invalid
            if (logicalMonitorIndex <= 0) {
                if (showcaseDebug)
                    ToolTip("Skipping monitor " physicalMonitorIndex ": not mapped")
                continue
            }

            try {
                ; Get monitor coordinates
                if (!MonitorGet(physicalMonitorIndex, &Left, &Top, &Right, &Bottom)) {
                    if (showcaseDebug)
                        ToolTip("Failed to get monitor " physicalMonitorIndex " coordinates")
                    continue
                }

                ; Convert coordinates to numbers immediately
                Left := Integer(Left)
                Top := Integer(Top)
                Right := Integer(Right)
                Bottom := Integer(Bottom)

                if (showcaseDebug) {
                    ToolTip("Creating overlay for monitor " physicalMonitorIndex " -> " logicalMonitorIndex " at " Left "," Top "," Right "," Bottom
                    )
                    ToolTip("Types: Left=" Type(Left) ", Top=" Type(Top) ", Right=" Type(Right) ", Bottom=" Type(Bottom
                    ) ", logicalMonitorIndex=" Type(logicalMonitorIndex))
                }

                ; Validate monitor coordinates
                if (Left >= Right || Top >= Bottom) {
                    if (showcaseDebug)
                        ToolTip("Invalid monitor coordinates for monitor " physicalMonitorIndex)
                    continue
                }

                ; Create OverlayGUI instance with numeric coordinates
                try {
                    overlay := OverlayGUI(Integer(logicalMonitorIndex), Left, Top, Right, Bottom, StateMap[
                        'activeColKeys'],
                    StateMap['activeRowKeys'])
                } catch as e {
                    if (showcaseDebug) {
                        ToolTip("Error in OverlayGUI constructor: " e.Message)
                        ToolTip("Constructor args: monitorIndex=" Type(logicalMonitorIndex) ", Left=" Type(Left) ", Top=" Type(
                            Top) ", Right=" Type(Right) ", Bottom=" Type(Bottom))
                    }
                    throw e
                }

                ; Verify overlay was created successfully
                if (!IsObject(overlay)) {
                    if (showcaseDebug)
                        ToolTip("Failed to create overlay object for monitor " physicalMonitorIndex)
                    continue
                }

                overlay.Show()
                StateMap['overlays'].Push(overlay)

                if (showcaseDebug)
                    ToolTip("Successfully created overlay for monitor " physicalMonitorIndex)

                ; Determine if the cursor starts on this monitor
                if (overlay.ContainsPoint(startX, startY)) {
                    StateMap['currentOverlay'] := overlay
                    foundMonitor := true
                    if (showcaseDebug)
                        ToolTip("Found cursor on monitor " physicalMonitorIndex)
                }
            } catch as e {
                if (showcaseDebug) {
                    ToolTip("Error creating overlay for monitor " physicalMonitorIndex ": " e.Message)
                    ToolTip("Error details: " e.File ":" e.Line " - " e.What)
                }
                ; Attempt to clean up partially created overlay if possible
                if (IsObject(overlay))
                    overlay.Destroy()
                overlay := ""
            }
            Sleep(50) ; Small delay between monitor processing
        }

        ; If cursor wasn't found on any *active* overlay, default to the first one created
        if (!foundMonitor && StateMap['overlays'].Length > 0) {
            StateMap['currentOverlay'] := StateMap['overlays'][1]
        }

        ; --- Final State Update and Timer Start ---
        if (StateMap['overlays'].Length > 0 && IsObject(StateMap['currentOverlay'])) {
            currentState := "GRID_VISIBLE" ; Update FSM state
            SetTimer(TrackCursor, 50)      ; Start cursor tracking (function from core_logic.ahk)
            gridActivationInProgress := false ; Reset activation flag *after* successful initialization
            if (showcaseDebug)
                ToolTip("Grid activated. State: GRID_VISIBLE")
        } else {
            ; If no overlays were successfully created, clean up and report error
            throw Error("Failed to create any grid overlays.")
        }

    } catch as e {
        ; --- Error Handling during Initialization ---
        Cleanup() ; Attempt cleanup on any error
        gridActivationInProgress := false ; Reset activation flag on failure
        MsgBox("Error initializing AntiMouse: " e.Message, "Initialization Error", 16)
        if (showcaseDebug)
            ToolTip("Error initializing: " e.Message)
    }
}

; --- Grid Cleanup ---

; Cleans up all GUI elements and resets the state to IDLE.
Cleanup() {
    ; Access global state
    global currentState, highlight, subGrid, StateMap, g_ModifierState, gridActivationInProgress

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
    ; Reset flags
    g_ModifierState.inHoldMode := false
    gridActivationInProgress := false
    StateMap['firstKey'] := "" ; Clear partial selections

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
