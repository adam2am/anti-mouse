; ==============================================================================
; core/grid_keys.ahk - Grid Key Handling Logic
; ==============================================================================

HandleKey(key) {
    global StateMap
    ; --- CORE LOGGING START ---
    initialFirstKey := StateMap.Has("firstKey") ? StateMap["firstKey"] : "<Not Set>"
    FileAppend(Format("Timestamp: {} | HandleKey: Function ENTRY. initialFirstKey='{}'", A_TickCount, initialFirstKey) "`n",
    "antimouse_core.log")
    ; --- CORE LOGGING END ---
    ; Access the dedicated global for first key tracking
    global g_firstKeyPressed
    ; Static variables for processing lock and auto-repeat prevention
    static keyProcessingLock := false
    static lastKeyProcessed := ""
    static lastKeyTime := 0
    static ignoreThreshold := 50 ; Ignore same key if pressed within 50ms

    ; Define currentTime at the beginning of the function
    currentTime := A_TickCount

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | HandleKey | key='{}' | currentState='{}' | g_firstKeyPressed='{}' | keyProcessingLock={}",
        A_TickCount, key, currentState, g_firstKeyPressed, keyProcessingLock) "`n", "antimouse_core.log")
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        keyPhysicallyDown := (key != "") ? GetKeyState(key, "P") : "N/A"
        rowKeyPhysicallyDown := StateMap['activeRowKey'] != "" ? GetKeyState(StateMap['activeRowKey'], "P") : false
        logMsg := Format(
            "Timestamp: {} | HandleKey START | key={} | PhysicallyDown={} | currentState={} | firstKey={} | activeRowKey={} | activeRowKeyPhysicallyDown={} | inUltraFastMode={}",
            currentTime, key, keyPhysicallyDown, currentState, StateMap['firstKey'], StateMap[
                'activeRowKey'],
            rowKeyPhysicallyDown ? "DOWN" : "UP", StateMap['inUltraFastMode']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Prevent re-entry if already processing
    if (keyProcessingLock) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: Key processing locked, ignoring key='{}'",
            A_TickCount, key) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        if (showcaseDebug) {
            logMsg := Format("Timestamp: {} | HandleKey Locked - Ignoring key={}", currentTime, key)
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Special check for active row key - ignore auto-repeat if we're tracking it
    if (currentState == "SUBGRID_ACTIVE" && enableUltraFast && key == StateMap['activeRowKey']) {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: Ignoring auto-repeat of row key='{}'",
            A_TickCount, key) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        if (showcaseDebug) {
            keyPhysicallyDown := GetKeyState(key, "P")
            logMsg := Format(
                "Timestamp: {} | HandleKey: Ignoring auto-repeat of active row key | key={} | PhysicallyDown={}",
                currentTime, key, keyPhysicallyDown ? "DOWN" : "UP")
            FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
        }
        return
    }

    ; Set lock
    keyProcessingLock := true

    try {
        ; currentTime already defined at the top of the function

        ; Check if the same key is being processed too rapidly (likely auto-repeat)
        ; Note: This check might become less critical with the lock, but kept for safety
        if (key = lastKeyProcessed && (currentTime - lastKeyTime < ignoreThreshold)) {
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Ignoring rapid repeat of key='{}', lastKeyTime={}, diff={}ms",
                A_TickCount, key, lastKeyTime, currentTime - lastKeyTime) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            if (showcaseDebug) {
                logMsg := Format("Timestamp: {} | Ignored rapid repeat: key={}", currentTime, key)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return ; Ignore this key press
        }

        ; Update last key processed *before* handling the logic
        ; Update time immediately
        lastKeyProcessed := key
        lastKeyTime := currentTime

        global currentState, highlight, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, StateMap,
            storePerMonitor, showcaseDebug, instaClickMode, g_ModifierState, enableUltraFast, rowKeyHoldThreshold

        ; Special handling for instaclick mode - always handle key events even when CapsLock is held
        if (instaClickMode && g_ModifierState.inHoldMode) {
            ; Process key normally, even though CapsLock is being held
        }

        ; IMPROVEMENT: Explicit hiding at the beginning
        if (IsObject(highlight)) {
            highlight.Hide()
        }
        if (IsObject(subGrid)) {
            subGrid.Hide()
        }

        ; IMPROVEMENT: Temporarily disable TrackCursor to prevent interference
        SetTimer(TrackCursor, 0)

        if (currentState != "GRID_VISIBLE" || !IsObject(StateMap['currentOverlay'])) { ; Use StateMap
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Invalid state/overlay. currentState='{}', IsObject(currentOverlay)={}",
                A_TickCount, currentState, IsObject(StateMap['currentOverlay'])) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            ; Re-enable TrackCursor before returning
            SetTimer(TrackCursor, 50)
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return
        }

        ; Check if key is a valid column or row key
        isColKey := false
        colIndex := 0
        for i, colKeyCheck in StateMap['activeColKeys'] { ; Use StateMap
            if (colKeyCheck = key) {
                isColKey := true
                colIndex := i
                break
            }
        }

        isRowKey := false
        rowIndex := 0
        for i, rowKeyCheck in StateMap['activeRowKeys'] { ; Use StateMap
            if (rowKeyCheck = key) {
                isRowKey := true
                rowIndex := i
                break
            }
        }

        ; --- CORE LOGGING START ---
        FileAppend(Format(
            "Timestamp: {} | HandleKey: Key type check for key='{}'. isColKey={}, isRowKey={}. InvalidCheck={}",
            A_TickCount, key, isColKey, isRowKey, (!isColKey && !isRowKey)) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---
        if (!isColKey && !isRowKey) {
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Invalid key type for key='{}'. Not a col or row key.",
                A_TickCount, key) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            if (showcaseDebug) {
                ToolTip("Invalid key: " key)
                Sleep 1000
                ToolTip()
            }
            SetTimer(TrackCursor, 50)
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return
        }

        cellKey := ""
        targetCellX := 0
        targetCellY := 0
        targetCellW := 0
        targetCellH := 0
        tooltipText := ""
        proceedToSubgrid := false
        updateFirstKeyOnly := false
        secondKeyWasRow := false

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | HandleKey: Before firstKey check. Global g_firstKeyPressed='{}'",
            A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; --- FIX: Check GLOBAL variable ---
        if (g_firstKeyPressed == "") {
            ; --- First Key Press ---
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            FileAppend(Format(
                "Timestamp: {} | DIAGNOSTIC | HandleKey: Processing FIRST key press. Setting g_firstKeyPressed='{}'",
                A_TickCount, key) "`n", "antimouse_core.log")
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format("Timestamp: {} | HandleKey: First Key Press | key={}", currentTime,
                key) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
            ; *** ASSIGN GLOBAL g_firstKeyPressed ***
                g_firstKeyPressed := key
            local newlySetFirstKey := key ; Store locally to use in this block

            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | HandleKey: Setting GLOBAL g_firstKeyPressed='{}'. Value is now '{}'",
                A_TickCount, newlySetFirstKey, g_firstKeyPressed) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---

            if (isColKey) {
                ; First key is COLUMN
                ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
                FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: First key is COLUMN='{}'",
                    A_TickCount, key) "`n", "antimouse_core.log")
                ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

                StateMap['currentColIndex'] := colIndex
                targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1
                targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length)
                cellKey := newlySetFirstKey . StateMap['activeRowKeys'][targetRowIndex] ; Use local var
                tooltipText := "First key: " newlySetFirstKey ". Select row."
            } else { ; isRowKey
                ; First key is ROW
                ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
                FileAppend(Format("Timestamp: {} | DIAGNOSTIC | HandleKey: First key is ROW='{}'",
                    A_TickCount, key) "`n", "antimouse_core.log")
                ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

                StateMap['currentRowIndex'] := rowIndex
                StateMap['lastSelectedRowIndex'] := rowIndex
                targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] : Ceil(StateMap[
                    'activeColKeys'
                    ].Length / 2)
                targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length)
                cellKey := StateMap['activeColKeys'][targetColIndex] . newlySetFirstKey ; Use local var
                tooltipText := "First key: " newlySetFirstKey ". Select column."
            }

            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
            if (IsObject(boundaries)) {
                FileAppend(Format(
                    "Timestamp: {} | DIAGNOSTIC | HandleKey: Got cell boundaries for cellKey='{}'. x={}, y={}, w={}, h={}",
                    A_TickCount, cellKey, boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n",
                "antimouse_core.log")
            } else {
                FileAppend(Format(
                    "Timestamp: {} | DIAGNOSTIC | HandleKey: ERROR - Failed to get boundaries for cellKey='{}'",
                    A_TickCount, cellKey) "`n", "antimouse_core.log")
            }
            ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }

            ; Center cursor and wait for second key
            if (targetCellW > 0) {
                highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                ; --- RE-ENABLE CURSOR SNAPPING (HandleKey - First Key) ---
                MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
                Sleep(10)
                if (showcaseDebug) {
                    ToolTip(tooltipText)
                }
            }
            SetTimer(TrackCursor, 50)
            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | HandleKey: END of firstKey block. GLOBAL g_firstKeyPressed is now '{}'",
                A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            ; Ensure lock is released before returning
            keyProcessingLock := false
            return ; Wait for second key

        } else {
            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | ENTERED second key 'else' block. GLOBAL g_firstKeyPressed='{}'",
                A_TickCount, g_firstKeyPressed) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            ; --- Second Key Press Logic Refactored ---
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) FileAppend(Format(
                "Timestamp: {} | HandleKey: Second Key Press | key={} | static firstKeyPressed={}", currentTime, key,
                firstKeyPressed) "`n", A_ScriptDir "\debugRapidRefresh.log")
            ; <<< ADD LOGGING END >>>
            ; --- FIX: Use static variable ---
                local firstKey := firstKeyPressed ; Use local var derived from static
            firstKeyWasCol := false
            for colKeyCheck in StateMap['activeColKeys'] {
                if (colKeyCheck = firstKey) {
                    firstKeyWasCol := true
                    break
                }
            }
            firstKeyWasRow := !firstKeyWasCol
            ; --- CORE LOGGING START ---
            FileAppend(Format(
                "Timestamp: {} | HandleKey: Before firstKeyWasCol loop. StateMap['activeColKeys'] type: {}",
                A_TickCount, Type(StateMap['activeColKeys'])) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            if (showcaseDebug) {
                logMsg := Format("Timestamp: {} | Second Key Check: firstKeyWasCol={} | firstKeyWasRow={}", currentTime,
                    firstKeyWasCol, firstKeyWasRow)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }

            ; --- CORE LOGGING START ---
            FileAppend(Format(
                "Timestamp: {} | HandleKey: Before Col->Row check: firstKey='{}', key='{}', firstKeyWasCol={}, isRowKey={}",
                A_TickCount, firstKey, key, firstKeyWasCol, isRowKey) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            if (firstKeyWasCol && isRowKey) {
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: ENTERED Col->Row block.", A_TickCount) "`n",
                "antimouse_core.log")
                ; --- CORE LOGGING END ---
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Col -> Row", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")

                    ; Check if this row key is physically held down
                    rowKeyIsPhysicallyDown := GetKeyState(key, "P")
                    logMsg := Format("Timestamp: {} | Row key '{}' physical state: {}",
                        currentTime, key, rowKeyIsPhysicallyDown ? "DOWN" : "UP")
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Valid: Col -> Row
                ; --- CORE LOGGING START ---
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Values before cellKey assignment (Col->Row): firstKey='{}', key='{}'.",
                    A_TickCount, firstKey, key) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                cellKey := firstKey . key
                proceedToSubgrid := true
                secondKeyWasRow := true
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: Determined Col->Row. proceedToSubgrid={}, cellKey={}",
                    A_TickCount, proceedToSubgrid, cellKey) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
            } else if (firstKeyWasRow && isColKey) {
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: ENTERED Row->Col block.", A_TickCount) "`n",
                "antimouse_core.log")
                ; --- CORE LOGGING END ---
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Row -> Col", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Valid: Row -> Col
                ; --- CORE LOGGING START ---
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Values before cellKey assignment (Row->Col): firstKey='{}', key='{}'.",
                    A_TickCount, firstKey, key) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
                cellKey := key . firstKey
                proceedToSubgrid := true
                ; --- CORE LOGGING START ---
                FileAppend(Format("Timestamp: {} | HandleKey: Determined Row->Col. proceedToSubgrid={}, cellKey={}",
                    A_TickCount, proceedToSubgrid, cellKey) "`n", "antimouse_core.log")
                ; --- CORE LOGGING END ---
            } else if (firstKeyWasCol && isColKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Col -> Col (Change Col)", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Update First Key: Col -> Col
                ; --- FIX: Update static variable ---
                firstKeyPressed := key
                tooltipText := "Column changed to: " key ". Select row."
                updateFirstKeyOnly := true
            } else if (firstKeyWasRow && isRowKey) {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Row -> Row (Change Row)", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Update First Key: Row -> Row
                ; --- FIX: Update static variable ---
                firstKeyPressed := key
                tooltipText := "Row changed to: " key ". Select column."
                updateFirstKeyOnly := true
            } else {
                if (showcaseDebug) {
                    logMsg := Format("Timestamp: {} | Branch: Invalid Sequence", currentTime)
                    FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
                }
                ; Invalid sequence (e.g., firstKey wasn't found in either col/row keys somehow?)
                ; --- FIX: Clear static variable ---
                firstKeyPressed := ""
                SetTimer(TrackCursor, 50)
                ; Ensure lock is released before returning
                keyProcessingLock := false
                return
            }

            ; --- Handle Outcome of Second Key Press ---
            if (updateFirstKeyOnly) {
                ; Only update the preview, don't proceed to subgrid yet
                ; <<< Re-enable mouse move for first key change preview >>>
                if (targetCellW > 0) {
                    highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                    MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
                    Sleep(10)
                    if (showcaseDebug) {
                        ToolTip(tooltipText)
                    }
                }
                SetTimer(TrackCursor, 50)
                keyProcessingLock := false
                return ; Wait for the *new* second key
            }
        }

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | BEFORE subgrid block check. proceedToSubgrid={}, cellKey={}",
            A_TickCount, proceedToSubgrid, cellKey) "`n", "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; --- Proceed to Subgrid State (Only if proceedToSubgrid is true) ---
        if (proceedToSubgrid && cellKey != "") {
            ; --- CORE LOGGING START ---
            FileAppend(Format("Timestamp: {} | HandleKey: >>> ENTERING proceedToSubgrid block for cellKey='{}'",
                A_TickCount, cellKey) "`n", "antimouse_core.log")
            overlayObj := StateMap['currentOverlay']
            overlayInfo := IsObject(overlayObj) ? "Type: " . Type(overlayObj) : "Not an object"
            FileAppend(Format(
                "Timestamp: {} | HandleKey: Current overlay info: {}. Attempting GetCellBoundaries...",
                A_TickCount, overlayInfo) "`n", "antimouse_core.log")
            ; --- CORE LOGGING END ---
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
            ; <<< CORE LOGGING START >>>
            FileAppend(Format("Timestamp: {} | HandleKey: IsObject(boundaries) result = {}. Boundaries=({},{},{},{})",
                A_TickCount, IsObject(boundaries), boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n",
            "antimouse_core.log")
            ; <<< CORE LOGGING END >>>
            if (IsObject(boundaries)) {
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Boundaries OK. Setting currentState=SUBGRID_ACTIVE (Before={})",
                    A_TickCount, currentState) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                StateMap['activeCellKey'] := cellKey
                stateTransitionTime := currentTime
                currentState := "SUBGRID_ACTIVE"
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Set currentState=SUBGRID_ACTIVE (After={}).", A_TickCount,
                    currentState) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>

                ; Set ultra-fast tracking info *if applicable*
                if (enableUltraFast && secondKeyWasRow) {
                    ; Check if this row key is physically held down before setting track variables
                    rowKeyIsPhysicallyDown := GetKeyState(key, "P")
                    ; <<< ADD LOGGING START >>>
                    if (showcaseDebug)
                        FileAppend(Format(
                            "Timestamp: {} | HandleKey: Setting UltraFast Vars | key={} | currentTime={} | PhysicallyDown={}",
                            currentTime, key, currentTime, rowKeyIsPhysicallyDown) "`n", A_ScriptDir "\debugRapidRefresh.log"
                        )
                    ; <<< ADD LOGGING END >>>
                    StateMap['rowKeyHeldTime'] := currentTime
                    StateMap['activeRowKey'] := key
                    ; <<< ADD LOGGING START >>>
                    if (showcaseDebug)
                        FileAppend(Format(
                            "Timestamp: {} | HandleKey: Set UltraFast Vars | activeRowKey={} | rowKeyHeldTime={}",
                            currentTime, StateMap['activeRowKey'], StateMap['rowKeyHeldTime']) "`n", A_ScriptDir "\debugRapidRefresh.log"
                        )
                    ; <<< ADD LOGGING END >>>
                }

                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Attempting MouseMove to ({}, {})...", A_TickCount,
                    boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2)) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
                Sleep(40)
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Attempting subGrid.Update({}, {}, {}, {})...",
                    A_TickCount, boundaries.x, boundaries.y, boundaries.w, boundaries.h) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Attempting subGrid.Show()...", A_TickCount) "`n",
                "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                subGrid.Show()
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Called subGrid.Show(). Current state: {}. Attempting PostMessage redraw...",
                    A_TickCount, currentState) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>

                ; Force redraw
                try {
                    if (WinExist("SubGrid ahk_class AutoHotkeyGUI")) {
                        winHnd := WinGetID("SubGrid ahk_class AutoHotkeyGUI")
                        if (winHnd) {
                            PostMessage(0x000F, 0, 0, , "ahk_id " winHnd)  ; WM_PAINT message
                        }
                    }
                } catch {
                }

                ; <<< ADD LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: Clearing static firstKeyPressed (Before). Current value = '{}'",
                    A_TickCount, firstKeyPressed) "`n", "antimouse_core.log")
                if (showcaseDebug) FileAppend(Format(
                    "Timestamp: {} | HandleKey: Clearing static firstKeyPressed (Before) | firstKeyPressed={}",
                    currentTime, firstKeyPressed) "`n", A_ScriptDir "\debugRapidRefresh.log")
                ; <<< ADD LOGGING END >>>
                ; --- FIX: Clear static variable ---
                    firstKeyPressed := ""
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: Cleared static firstKeyPressed. Checking cell memory...",
                    A_TickCount) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                ; Check if we have a remembered subcell for this cell
                cellFound := false

                ; First check monitor-specific key if enabled
                if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
                    monitorCellKey := StateMap['currentOverlay'].monitorIndex . "_" . cellKey
                    if (cellMemory.Has(monitorCellKey)) {
                        rememberedSubCell := cellMemory[monitorCellKey]
                        cellFound := true
                        if (showcaseDebug) {
                            ToolTip("Found monitor-specific subcell: " monitorCellKey " -> " rememberedSubCell)
                            Sleep(500)
                        }
                    }
                }

                ; Fall back to general cell key if no monitor-specific key found
                if (!cellFound && cellMemory.Has(cellKey)) {
                    rememberedSubCell := cellMemory[cellKey]
                    cellFound := true
                    if (showcaseDebug) {
                        ToolTip("Found general subcell: " cellKey " -> " rememberedSubCell)
                        Sleep(500)
                    }
                }

                ; Move to the remembered subcell position if found
                if (cellFound && rememberedSubCell != "") {
                    HandleSubGridKey(rememberedSubCell)
                } else if (showcaseDebug) {
                    ToolTip("No saved subcell found for " cellKey)
                    Sleep(500)
                }

                if (showcaseDebug) {
                    ToolTip("Cell '" cellKey "' targeted. Use b-h.")
                }
                ; <<< CORE LOGGING START >>>
                FileAppend(Format("Timestamp: {} | HandleKey: END of proceedToSubgrid block.", A_TickCount) "`n",
                "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
            } else {
                ; Failed to get boundaries
                ; <<< CORE LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | HandleKey: FAILED to get boundaries for cellKey='{}'. Resetting static firstKeyPressed.",
                    A_TickCount, cellKey) "`n", "antimouse_core.log")
                ; <<< CORE LOGGING END >>>
                ; --- FIX: Clear static variable ---
                firstKeyPressed := ""
                if (showcaseDebug && proceedToSubgrid && cellKey == "") {
                    ToolTip("Error: Proceeding to subgrid but cellKey is empty")
                }
            }
        } else {
            ; This case should ideally not be reached if logic is sound, but reset firstKey as safety
            ; --- FIX: Clear static variable ---
            firstKeyPressed := ""
            if (showcaseDebug && proceedToSubgrid && cellKey == "") {
                ToolTip("Error: Proceeding to subgrid but cellKey is empty")
            }
        }

        SetTimer(TrackCursor, 50)

        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | TrackCursor: Reached end of try block BEFORE catch/finally.", currentTime) "`n",
        "antimouse_core.log")
        ; --- CORE LOGGING END ---
    } catch as e {
        ; --- CORE LOGGING START ---
        FileAppend(Format("Timestamp: {} | TrackCursor: **** ERROR **** {}", A_TickCount, e.Message) "`n",
        "antimouse_core.log")
        ; --- CORE LOGGING END ---
        ; Attempt to cleanup on error
        Cleanup()
    } finally {
        ; Ensure the lock is always released
        trackingInProgress := false
    }
}
