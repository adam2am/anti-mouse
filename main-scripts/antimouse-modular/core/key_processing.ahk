; ==============================================================================
; core/key_processing.ahk - Key Processing Wrapper Logic
; ==============================================================================

; Central function called by hotkeys to route key presses to the appropriate handler based on the current state.
ProcessKeyPress(key) {
    global StateMap
    FileAppend(Format("Timestamp: {} | ProcessKeyPress START | key={} | currentState={}", A_TickCount, key,
        currentState) "`n", "antimouse_core.log") ; <<< CORE LOGGING
    global currentState, subGridKeys, instaClickMode,
        g_ModifierState, StateMap, enableUltraFast, ultraFastSubGridKeys, showcaseDebug, g_firstKeyPressed

    ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
    FileAppend(Format(
        "Timestamp: {} | DIAGNOSTIC | ProcessKeyPress | key='{}' | currentState='{}' | g_firstKeyPressed='{}' | activeCellKey='{}'",
        A_TickCount, key, currentState, g_firstKeyPressed, StateMap['activeCellKey']) "`n", "antimouse_core.log")

    ; Check if currentOverlay exists and is valid
    if (IsObject(StateMap['currentOverlay'])) {
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | currentOverlay is valid object", A_TickCount) "`n",
        "antimouse_core.log")
    } else {
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | ERROR: currentOverlay is NOT a valid object", A_TickCount) "`n",
        "antimouse_core.log")
    }
    ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

    ; <<< ADD LOGGING START >>>
    if (showcaseDebug) {
        ; Get physical key state
        keyPhysicallyDown := GetKeyState(key, "P")
        logMsg := Format(
            "Timestamp: {} | ProcessKeyPress START | key={} | PhysicallyDown={} | currentState={} | rowKeyHeldTime={} | activeRowKey={}",
            A_TickCount, key, keyPhysicallyDown ? "DOWN" : "UP", currentState, StateMap['rowKeyHeldTime'], StateMap[
                'activeRowKey']
        )
        FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
    }
    ; <<< ADD LOGGING END >>>

    ; Special handling for instaclick mode - allow key events even when CapsLock is held for the click
    if (instaClickMode && g_ModifierState.inHoldMode) {
        ; Allow processing even if CapsLock is physically down for the click release
    }

    if (currentState == "GRID_VISIBLE") {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | Calling HandleKey with key='{}'", A_TickCount, key) "`n",
        "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

        HandleKey(key) ; Process as first or second grid key
    } else if (currentState == "SUBGRID_ACTIVE") {
        ; Check if key is the active row key that we're already tracking (for ultra-fast)
        if (enableUltraFast && key == StateMap['activeRowKey']) {
            ; We're already tracking this key being held, don't process it again
            ; This prevents auto-repeat from disrupting the hold tracking
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) {
                keyPhysicallyDown := GetKeyState(key, "P")
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignoring repeat of active row key | key={} | PhysicallyDown={}",
                    A_TickCount, key, keyPhysicallyDown ? "DOWN" : "UP"
                )
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; <<< ADD LOGGING END >>>
            return
        }

        ; Check if we're in ultra-fast mode and key is valid for it
        if (enableUltraFast && StateMap['inUltraFastMode']) {
            for i, ultraKey in ultraFastSubGridKeys {
                if (key == ultraKey) {
                    HandleUltraFastKey(key)
                    return ; Handled by ultra-fast logic
                }
            }
            ; If it wasn't an ultra-fast key, but we are in ultra-fast mode, ignore the key.
            ; (This prevents standard subgrid keys from working during ultra-fast mode).
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) {
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignored key '{}' while in UltraFastMode (expected ultra-key or row-release).",
                    A_TickCount, key)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; <<< ADD LOGGING END >>>
            return
        }

        ; --- If NOT in ultra-fast mode, check for standard subgrid keys ---
        isStandardSubGridKey := false
        for i, subKey in subGridKeys {
            if (key == subKey) {
                isStandardSubGridKey := true
                break
            }
        }

        if (isStandardSubGridKey) {
            HandleSubGridKey(key) ; Process standard subgrid selection
        } else {
            ; --- FIX: Check if key is a valid grid key (column or row key) ---
            isGridKey := false

            ; Check column keys
            for i, colKey in StateMap['activeColKeys'] {
                if (key == colKey) {
                    isGridKey := true
                    break
                }
            }

            ; Check row keys
            if (!isGridKey) {
                for i, rowKey in StateMap['activeRowKeys'] {
                    if (key == rowKey) {
                        isGridKey := true
                        break
                    }
                }
            }

            ; If it's a grid key, call StartNewSelection to go back to grid selection mode
            if (isGridKey) {
                ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
                FileAppend(Format(
                    "Timestamp: {} | DIAGNOSTIC | ProcessKeyPress: Detected grid key '{}' while in SUBGRID_ACTIVE. Calling StartNewSelection.",
                    A_TickCount, key) "`n", "antimouse_core.log")
                ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>

                StartNewSelection(key)
                return
            }

            ; If it's neither a subgrid key nor a grid key, ignore it
            ; <<< ADD LOGGING START >>>
            if (showcaseDebug) {
                logMsg := Format(
                    "Timestamp: {} | ProcessKeyPress: Ignored key '{}' while in SUBGRID_ACTIVE (standard).",
                    A_TickCount, key)
                FileAppend(logMsg "`n", A_ScriptDir "\debugRapidRefresh.log")
            }
            ; <<< ADD LOGGING END >>>
            ; --- ADD EXPLICIT RETURN ---
            return ; Explicitly stop processing for this invalid key in this state.
        }
    } else {
        ; <<< ENHANCED DIAGNOSTIC LOGGING START >>>
        FileAppend(Format("Timestamp: {} | DIAGNOSTIC | WARNING: Key press '{}' received in invalid state: '{}'",
            A_TickCount, key, currentState) "`n", "antimouse_core.log")
        ; <<< ENHANCED DIAGNOSTIC LOGGING END >>>
    }
    ; Do nothing if currentState is IDLE (should be handled by activation hotkeys)
}
