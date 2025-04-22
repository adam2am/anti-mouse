; ==============================================================================
; hotkeys.ahk - Hotkey Definitions for AntiMouse
; ==============================================================================

; --- CONSOLIDATED HOTKEYS for GRID_VISIBLE or SUBGRID_ACTIVE ---
; These hotkeys are active only when the grid or subgrid is visible.
; They call the ProcessKeyPress function (from core_logic.ahk) to handle the input based on the current state.
#HotIf currentState == State_GRID_VISIBLE || currentState == State_SUBGRID_STANDARD || currentState ==
    State_SUBGRID_ULTRAFAST
q:: ProcessKeyPress("q")
w:: ProcessKeyPress("w")
e:: ProcessKeyPress("e")
r:: ProcessKeyPress("r")
t:: ProcessKeyPress("t") ; Assuming 't' might be used in some layouts
y:: ProcessKeyPress("y") ; Assuming 'y' might be used in some layouts
u:: ProcessKeyPress("u")
i:: ProcessKeyPress("i")
o:: ProcessKeyPress("o")
p:: ProcessKeyPress("p")
a:: ProcessKeyPress("a")
s:: ProcessKeyPress("s")
d:: ProcessKeyPress("d")
f:: ProcessKeyPress("f")
g:: ProcessKeyPress("g") ; Handles Grid Nav / Subgrid Nav / Start New
h:: ProcessKeyPress("h") ; Handles Grid Nav / Subgrid Nav / Start New
j:: ProcessKeyPress("j")
k:: ProcessKeyPress("k")
l:: ProcessKeyPress("l")
`;:: ProcessKeyPress(";")
z:: ProcessKeyPress("z")
x:: ProcessKeyPress("x")
c:: ProcessKeyPress("c")
v:: ProcessKeyPress("v")
b:: ProcessKeyPress("b") ; Handles Grid Nav / Subgrid Nav / Start New
n:: ProcessKeyPress("n") ; Handles Grid Nav / Subgrid Nav / Start New
,:: ProcessKeyPress(",")
.:: ProcessKeyPress(".")
/:: ProcessKeyPress("/")
m:: ProcessKeyPress("m")

; Scan code versions for potentially problematic keys
SC033:: ProcessKeyPress(",") ; Comma
SC034:: ProcessKeyPress(".") ; Period
SC035:: ProcessKeyPress("/") ; Slash
SC032:: ProcessKeyPress("m") ; M
SC027:: ProcessKeyPress(";") ; Semicolon
SC022:: ProcessKeyPress("g") ; G
SC023:: ProcessKeyPress("h") ; H
SC031:: ProcessKeyPress("n") ; N
SC030:: ProcessKeyPress("b") ; B

; Add Escape key to trigger Cleanup (Context-Specific)
Escape:: {
    if (enableVerboseLogging) {
        LogToFile(Format("Timestamp: {} | Global Escape Hotkey Fired", A_TickCount), "antimouse_core.log")
    }
    ; Access global state and config needed
    global currentState, showcaseDebug, highlight, subGrid, StateMap, enableVerboseLogging

    ; Safely call Cleanup (function from activation.ahk)
    try {
        Cleanup()
    } catch as e {
        if (showcaseDebug)
            ToolTip("Error during standard Escape cleanup: " e.Message)
        if (enableVerboseLogging) {
            LogToFile(Format("Timestamp: {} | **** ERROR in Escape Hotkey Cleanup: {} ****", A_TickCount, e.Message),
            "antimouse_core.log")
        }
        ; If standard cleanup failed, attempt a more forceful cleanup
        try {
            if (enableVerboseLogging) {
                LogToFile(Format("Timestamp: {} | Escape Hotkey: Attempting forced cleanup...", A_TickCount),
                "antimouse_core.log")
            }
            currentState := State_IDLE ; Force state
            ForceCloseAllGuis()    ; Force close GUIs (function from utils.ahk)
            ; Reset object references manually as a last resort
            highlight := ""
            subGrid := ""
            if (IsSet(StateMap)) {
                StateMap['overlays'] := Map()
                StateMap['currentOverlay'] := ""
            }
            ToolTip() ; Clear tooltips
            SetTimer(TrackCursor, 0) ; Ensure tracking timer is off
            SetCapsLockState "AlwaysOff"
            if (showcaseDebug)
                ToolTip("Forced cleanup executed.")
            Sleep 500
            if (showcaseDebug)
                ToolTip()
            if (enableVerboseLogging) {
                LogToFile(Format("Timestamp: {} | Escape Hotkey: Forced cleanup finished.", A_TickCount),
                "antimouse_core.log")
            }
        } catch as force_e {
            ; Ignore errors during forced cleanup, maybe just basic tooltip clear
            if (enableVerboseLogging) {
                LogToFile(Format("Timestamp: {} | **** CRITICAL ERROR during forced Escape cleanup: {} ****",
                    A_TickCount, force_e.Message), "antimouse_core.log")
            }
            ToolTip("CRITICAL ERROR during forced cleanup: " force_e.Message)
            Sleep 1000
            ToolTip()
        }
    }
}

; Monitor switching hotkeys (active when grid is visible)
1:: SwitchMonitor(1) ; Function from core_logic.ahk
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
#HotIf

; --- HOTKEYS FOR IDLE STATE (Activation with CapsLock + Key) ---
; These activate the grid *and* potentially perform an initial action.
#HotIf GetKeyState('CapsLock', 'P') && (currentState == State_IDLE)
#HotIf

; --- HOTKEYS FOR CAPSLOCK HELD (Monitor Switch Activation/Switching) ---
; These handle CapsLock + Number keys.
; If IDLE, they activate the grid first, then switch.
; If already active, they just switch the monitor.
#HotIf GetKeyState('CapsLock', 'P')
1:: {
    global currentState, g_ModifierState ; Access state
    SetCapsLockState "AlwaysOff"
    SetTimer(TrackCursor, 0) ; Stop tracking during switch
    if (currentState == State_IDLE) {
        CapsLock_Q() ; Activate grid (function from activation.ahk)
        Sleep(100) ; Allow grid time to initialize fully
    }
    SwitchMonitor(1) ; Switch monitor (function from core_logic.ahk)
    g_ModifierState.inHoldMode := true ; Ensure hold mode is set for click on release
    SetTimer(TrackCursor, 50) ; Resume tracking
}
2:: {
    global currentState, g_ModifierState
    SetCapsLockState "AlwaysOff"
    SetTimer(TrackCursor, 0)
    if (currentState == State_IDLE) {
        CapsLock_Q()
        Sleep(100)
    }
    SwitchMonitor(2)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
3:: {
    global currentState, g_ModifierState
    SetCapsLockState "AlwaysOff"
    SetTimer(TrackCursor, 0)
    if (currentState == State_IDLE) {
        CapsLock_Q()
        Sleep(100)
    }
    SwitchMonitor(3)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
4:: {
    global currentState, g_ModifierState
    SetCapsLockState "AlwaysOff"
    SetTimer(TrackCursor, 0)
    if (currentState == State_IDLE) {
        CapsLock_Q()
        Sleep(100)
    }
    SwitchMonitor(4)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
#HotIf

; --- HOTKEYS FOR CAPSLOCK HELD (NON-INSTACLICK HOLD MODE, GRID ACTIVE) ---
; These use the CapsLock & syntax. They trigger when Caps is held, grid is active,
; *and* we are NOT in the specific `inHoldMode` (which is set by double-tap or activation keys).
; This allows CapsLock+Key to function as navigation when CapsLock is simply held down
; without the intention of performing an InstaClick on release.
#HotIf GetKeyState('CapsLock', 'P') && (currentState == State_GRID_VISIBLE || currentState == State_SUBGRID_STANDARD ||
    currentState == State_SUBGRID_ULTRAFAST) && !g_ModifierState.inHoldMode

; Monitor switching (using CapsLock & N when active but not intending an InstaClick)
; Note: These implicitly set inHoldMode upon execution because CapsLock & Key implies a hold intention.
CapsLock & 1:: {
    SetTimer(TrackCursor, 0)
    SwitchMonitor(1)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
CapsLock & 2:: {
    SetTimer(TrackCursor, 0)
    SwitchMonitor(2)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
CapsLock & 3:: {
    SetTimer(TrackCursor, 0)
    SwitchMonitor(3)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
CapsLock & 4:: {
    SetTimer(TrackCursor, 0)
    SwitchMonitor(4)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}

; Navigation (CapsLock & Key) - Call the same ProcessKeyPress function
CapsLock & q:: ProcessKeyPress("q")
CapsLock & w:: ProcessKeyPress("w")
CapsLock & e:: ProcessKeyPress("e")
CapsLock & r:: ProcessKeyPress("r")
CapsLock & t:: ProcessKeyPress("t")
CapsLock & y:: ProcessKeyPress("y")
CapsLock & u:: ProcessKeyPress("u")
CapsLock & i:: ProcessKeyPress("i")
CapsLock & o:: ProcessKeyPress("o")
CapsLock & p:: ProcessKeyPress("p")
CapsLock & a:: ProcessKeyPress("a")
CapsLock & s:: ProcessKeyPress("s")
CapsLock & d:: ProcessKeyPress("d")
CapsLock & f:: ProcessKeyPress("f")
CapsLock & g:: ProcessKeyPress("g")
CapsLock & h:: ProcessKeyPress("h")
CapsLock & j:: ProcessKeyPress("j")
CapsLock & k:: ProcessKeyPress("k")
CapsLock & l:: ProcessKeyPress("l")
CapsLock & `;:: ProcessKeyPress(";")
CapsLock & z:: ProcessKeyPress("z")
CapsLock & x:: ProcessKeyPress("x")
CapsLock & c:: ProcessKeyPress("c")
CapsLock & v:: ProcessKeyPress("v")
CapsLock & b:: ProcessKeyPress("b")
CapsLock & n:: ProcessKeyPress("n")
CapsLock & ,:: ProcessKeyPress(",")
CapsLock & .:: ProcessKeyPress(".")
CapsLock & /:: ProcessKeyPress("/")
CapsLock & m:: ProcessKeyPress("m")

; Scan code versions for CapsLock & Key
CapsLock & SC033:: ProcessKeyPress(",") ; Comma
CapsLock & SC034:: ProcessKeyPress(".") ; Period
CapsLock & SC035:: ProcessKeyPress("/") ; Slash
CapsLock & SC032:: ProcessKeyPress("m") ; M
CapsLock & SC027:: ProcessKeyPress(";") ; Semicolon
CapsLock & SC022:: ProcessKeyPress("g") ; G
CapsLock & SC023:: ProcessKeyPress("h") ; H
CapsLock & SC031:: ProcessKeyPress("n") ; N
CapsLock & SC030:: ProcessKeyPress("b") ; B

#HotIf

; --- Other Hotkeys (Space, Escape, Tab) ---
; These apply whenever the grid is active (GRID_VISIBLE or SUBGRID_ACTIVE).
#HotIf currentState != State_IDLE
Space:: {
    ; Access global state and config needed
    global currentState, highlight, subGrid, StateMap, showcaseDebug, enableVerboseLogging

    try {
        ; Save mouse position *before* any cleanup or state change
        MouseGetPos(&mouseX, &mouseY)

        ; Stop tracking and change state immediately to prevent race conditions
        SetTimer(TrackCursor, 0)
        currentState := State_IDLE ; Set state first

        ; Log the action
        LogToFile("Space Hotkey: Stopping TrackCursor and performing click", "antimouse_core.log")

        ; Explicitly remove tooltipsq
        ToolTip()

        ; --- TASK 5.6: Safe object handling ---
        ; Hide UI elements quickly, with robust type checking
        if (IsObject(highlight)) {
            LogToFile("Space Hotkey: Hiding highlight", "antimouse_core.log")
            highlight.Hide() ; Now moves highlight off-screen
        } else {
            LogToFile(Format("Space Hotkey: highlight is not an object (type: {})", Type(highlight)),
            "antimouse_core.log")
        }

        if (IsObject(subGrid)) {
            LogToFile("Space Hotkey: Hiding subGrid", "antimouse_core.log")
            subGrid.Hide() ; Now moves subGrid off-screen
        } else {
            LogToFile(Format("Space Hotkey: subGrid is not an object (type: {})", Type(subGrid)), "antimouse_core.log")
        }

        ; Safely handle overlays
        if (IsObject(StateMap) && StateMap.Has('overlays') && IsObject(StateMap['overlays'])) {
            for index, overlay in StateMap['overlays'] {
                if (IsObject(overlay)) {
                    LogToFile(Format("Space Hotkey: Hiding overlay {}", index), "antimouse_core.log")
                    overlay.Hide() ; Now moves overlay off-screen
                } else {
                    LogToFile(Format("Space Hotkey: overlay {} is not an object (type: {})",
                        index, Type(overlay)), "antimouse_core.log")
                }
            }
        } else {
            LogToFile("Space Hotkey: StateMap['overlays'] is not valid", "antimouse_core.log")
        }
        ; --- END TASK 5.6 ---

        Sleep(30) ; Small delay to ensure UI is hidden

        ; Perform the mouse click at the saved position
        LogToFile(Format("Space Hotkey: Clicking at ({}, {})", mouseX, mouseY), "antimouse_core.log")
        Click("Left")

        ; Perform full cleanup *after* the click
        Sleep(30) ; Delay before final cleanup
        LogToFile("Space Hotkey: Calling Cleanup()", "antimouse_core.log")
        Cleanup() ; Function from activation.ahk
    } catch as e {
        LogToFile(Format("Space Hotkey: ERROR - {}", e.Message), "antimouse_core.log")
        if (showcaseDebug) ToolTip("Error during Space action: " e.Message)
        ; Attempt cleanup even if there was an error during the click/hide phase
            try {
                Cleanup()
            } catch as cleanupError {
                LogToFile(Format("Space Hotkey: CLEANUP ERROR - {}", cleanupError.Message), "antimouse_core.log")
            }
    }
}

; Tab key cycles through monitors when the grid is active
Tab:: {
    ; Access global objects needed
    global subGrid, highlight

    ; Temporarily disable TrackCursor completely during cycle
    SetTimer(TrackCursor, 0)

    ; Hide subgrid and highlight before switching to prevent visual artifacts
    if (IsObject(subGrid)) subGrid.Hide() ; Now moves subGrid off-screen
        if (IsObject(highlight)) highlight.Hide() ; Now moves highlight off-screen
            Sleep(20) ; Small delay

    ; Cycle to the next monitor (function from core_logic.ahk)
    CycleToNextMonitor()

    Sleep(30) ; Small delay before re-enabling tracking

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)
}
#HotIf

; --- CapsLock Handling (Single/Double Tap, Hold/Release) ---
; This handles the core logic for activating/deactivating the grid via CapsLock
; and managing the 'inHoldMode' for InstaClick functionality.

; Note: The '$' prefix might help prevent the hotkey triggering itself in some cases,
; but might not be strictly necessary with `SetCapsLockState "AlwaysOff"`. Keep if issues arise.
; $CapsLock::
CapsLock:: {
    ; Access global state and config
    global g_ModifierState, doubleCapsThreshold, instaClickMode, currentState, showcaseDebug,
        instaClickReleaseThreshold ; Added instaClickReleaseThreshold

    ; Ensure CapsLock's toggle state remains off
    SetCapsLockState "AlwaysOff"

    ; Update physical key state
    g_ModifierState.caps := GetKeyState("CapsLock", "P") ; Check physical state

    currentTime := A_TickCount

    ; --- First Press Detection ---
    if (g_ModifierState.capsPressedFirstTime == 0) {
        ; Initialize all state for first press
        g_ModifierState.capsPressedFirstTime := currentTime
        g_ModifierState.capsPressedSecondTime := 0
        g_ModifierState.inHoldMode := false          ; Reset hold mode on first press
        g_ModifierState.capsFirstReleased := false   ; Mark that this press hasn't been released yet
        if (showcaseDebug)
            ToolTip("CapsLock first press")
    }
    ; --- Second Press Detection ---
    ; Check if a first press was recorded and *released* before this press
    else if (g_ModifierState.capsPressedFirstTime > 0 && g_ModifierState.capsFirstReleased) {
        ; Check if this press is within the double-press time threshold
        if ((currentTime - g_ModifierState.lastCapsUpTime) < doubleCapsThreshold) {
            g_ModifierState.capsPressedSecondTime := currentTime
            g_ModifierState.inHoldMode := true ; Set hold mode on successful double-tap
            if (showcaseDebug) ToolTip("CapsLock double-tap - hold mode active")
            ; Activate grid immediately on the second press (if not already active)
                if (currentState == State_IDLE) {
                    try {
                        CapsLock_Q() ; Function from activation.ahk
                    } catch as e {
                        if (showcaseDebug) {
                            ToolTip("Error activating grid: " e.Message)
                            Sleep(1000)
                        }
                        ; Reset state on error
                        g_ModifierState.inHoldMode := false
                        g_ModifierState.capsPressedFirstTime := 0
                        g_ModifierState.capsPressedSecondTime := 0
                        g_ModifierState.capsFirstReleased := false
                    }
                }
        } else {
            ; Too much time passed since last release, treat this as a new first press
            g_ModifierState.capsPressedFirstTime := currentTime
            g_ModifierState.capsPressedSecondTime := 0
            g_ModifierState.inHoldMode := false
            g_ModifierState.capsFirstReleased := false
            if (showcaseDebug)
                ToolTip("CapsLock first press (reset)")
        }
    }

    ; Safeguard: Ensure CapsLock toggle state is off again
    SetCapsLockState "AlwaysOff"
    return false ; Block native CapsLock functionality
}

; $CapsLock Up::
CapsLock Up:: {
    ; Access global state and config
    global g_ModifierState, instaClickMode, currentState, highlight, subGrid, StateMap, showcaseDebug,
        doubleCapsThreshold, instaClickReleaseThreshold ; Added instaClickReleaseThreshold

    ; Ensure CapsLock toggle state remains off
    SetCapsLockState "AlwaysOff"

    currentTime := A_TickCount
    g_ModifierState.lastCapsUpTime := currentTime
    g_ModifierState.capsFirstReleased := true ; Mark that a release occurred
    g_ModifierState.caps := false             ; Update physical state tracker

    ; --- InstaClick Handling ---
    ; Perform click if we were in hold mode AND held long enough after the 2nd tap
    if (g_ModifierState.inHoldMode && currentState != State_IDLE) {
        ; Check if enough time elapsed since the second tap to qualify as an intended hold-release
        if (g_ModifierState.capsPressedSecondTime > 0 && (currentTime - g_ModifierState.capsPressedSecondTime) >
        instaClickReleaseThreshold) {
            if (showcaseDebug) ToolTip("InstaClick Triggered (Hold > " instaClickReleaseThreshold "ms)")
                LogToFile(Format("Timestamp: {} | InstaClick Triggered: Held for {}ms > threshold {}",
                    currentTime, currentTime - g_ModifierState.capsPressedSecondTime, instaClickReleaseThreshold),
                "antimouse_core.log")
            try {
                mouseX := 0, mouseY := 0 ; Initialize target coordinates
                usedStoredTarget := false

                ; Check if we have a pre-calculated target from CapsLock & q
                if (StateMap.Has('instantClickTargetX') && StateMap['instantClickTargetX'] != "") {
                    mouseX := StateMap['instantClickTargetX']
                    mouseY := StateMap['instantClickTargetY']
                    StateMap['instantClickTargetX'] := "" ; Clear after use
                    StateMap['instantClickTargetY'] := "" ; Clear after use
                    usedStoredTarget := true
                    LogToFile(Format("Timestamp: {} | InstaClick: Using stored target ({}, {}) from Hold+Key",
                        currentTime, mouseX, mouseY), "antimouse_core.log")
                } else {
                    ; No stored target, get current mouse position (for double-tap clicks)
                    MouseGetPos(&mouseX, &mouseY)
                    LogToFile(Format("Timestamp: {} | InstaClick: Using current mouse position ({}, {})",
                        currentTime, mouseX, mouseY), "antimouse_core.log")
                }

                ; Save mouse position before cleanup potentially moves it
                ; MouseGetPos(&mouseX, &mouseY) ; << REMOVED - Determined above

                ; Stop tracking and set state to IDLE immediately
                SetTimer(TrackCursor, 0)
                currentState := State_IDLE

                ; Hide UI elements quickly
                if (IsObject(highlight)) {
                    highlight.Hide() ; Now moves highlight off-screen
                }
                if (IsObject(subGrid)) {
                    subGrid.Hide() ; Now moves subGrid off-screen
                }
                for overlay in StateMap['overlays'] {
                    if (IsObject(overlay)) {
                        overlay.Hide() ; Now moves overlay off-screen
                    }
                }
                Sleep(50) ; Slightly longer delay for UI hiding

                ; Perform the click AT THE DETERMINED LOCATION
                LogToFile(Format("Timestamp: {} | InstaClick: Clicking at ({}, {}). Stored Target Used: {}",
                    currentTime, mouseX, mouseY, usedStoredTarget), "antimouse_core.log")
                Click("Left") ; Use reliable Click command

                ; Perform full cleanup *after* the click
                Sleep(50) ; Delay before final cleanup
                Cleanup() ; Function from activation.ahk

            } catch as e {
                LogToFile(Format("Timestamp: {} | ERROR during InstaClick: {}", currentTime, e.Message),
                "antimouse_core.log")
                if (showcaseDebug) {
                    ToolTip("Error during InstaClick: " e.Message)
                    Sleep(1000)
                }
                ; Ensure cleanup happens even if click fails
                try Cleanup()
            }
        } else {
            ; Release was too fast after the second tap - likely just activating the grid, not intending a click.
            LogToFile(Format("Timestamp: {} | InstaClick Skipped: Release too fast ({}ms <= threshold {})",
                currentTime, currentTime - g_ModifierState.capsPressedSecondTime, instaClickReleaseThreshold),
            "antimouse_core.log")
            if (showcaseDebug) {
                ToolTip("Double-Tap Activation Release (No Click)")
            }
            ; Only reset state flags here, don't click or cleanup.
            ; Start tracking ONLY if this was a quick release (non-instaclick activation)
            SetTimer(TrackCursor, 50)
            LogToFile(Format("Timestamp: {} | CapsLock Up: Started TrackCursor after quick release.", currentTime),
            "antimouse_core.log")
        }

        ; Reset hold mode and press times regardless of whether click happened
        g_ModifierState.inHoldMode := false
        g_ModifierState.capsPressedFirstTime := 0
        g_ModifierState.capsPressedSecondTime := 0

    } else {
        ; --- Single Tap Handling ---
        ; If not in hold mode, check if this release corresponds to a single tap
        if (!g_ModifierState.inHoldMode && currentState != State_IDLE) {
            ; Check if enough time has passed since the first press to rule out a double-tap starting
            ; AND ensure capsPressedSecondTime wasn't set (meaning it wasn't a fast double-tap release handled above)
            if (g_ModifierState.capsPressedFirstTime > 0 && (currentTime - g_ModifierState.capsPressedFirstTime) >
            doubleCapsThreshold && g_ModifierState.capsPressedSecondTime == 0) {
                if (showcaseDebug) ToolTip("Single CapsLock tap detected - Cleaning up")
                    LogToFile(Format("Timestamp: {} | Single Tap Release Detected: Cleaning up", currentTime),
                    "antimouse_core.log")
                try {
                    Cleanup() ; Clean up grid on single tap release
                } catch as e {
                    LogToFile(Format("Timestamp: {} | ERROR during Single Tap Cleanup: {}", currentTime, e.Message),
                    "antimouse_core.log")
                    if (showcaseDebug) {
                        ToolTip("Error during cleanup: " e.Message)
                        Sleep(1000)
                    }
                }
                ; Reset press time after cleanup for single tap
                g_ModifierState.capsPressedFirstTime := 0
                g_ModifierState.capsPressedSecondTime := 0 ; Ensure this is also reset
            } else if (g_ModifierState.capsPressedFirstTime == 0) {
                ; This case might occur if CapsLock Up is detected without a prior Down event
                if (showcaseDebug) ToolTip("CapsLock Up detected without recorded press - Cleaning up")
                    LogToFile(Format("Timestamp: {} | Orphan CapsLock Up Detected: Cleaning up", currentTime),
                    "antimouse_core.log")
                try Cleanup()
            }
        }

        ; Reset hold mode flag if it wasn't already reset by click handling or quick release handling
        ; This handles the case where user held CapsLock (not double tap) and grid was already IDLE
        if (g_ModifierState.inHoldMode && currentState == State_IDLE) {
            LogToFile(Format("Timestamp: {} | Resetting residual holdMode flag in IDLE state", currentTime),
            "antimouse_core.log")
            g_ModifierState.inHoldMode := false
            g_ModifierState.capsPressedFirstTime := 0
            g_ModifierState.capsPressedSecondTime := 0
        }
    }
    return false ; Block native functionality
}

; --- Settings Hotstring ---
; Defined in settings_gui.ahk but triggered here if needed globally
; Hotstring definition moved to settings_gui.ahk to keep related code together.
; :*:;settings:: ShowSettingsGUI()

; --- ROW KEY UP EVENTS FOR ULTRA-FAST SUBGRID MODE ---
#HotIf currentState == State_SUBGRID_STANDARD && StateMap.Get("inUltraFastMode", false)

; Function to handle row key releases in ultra-fast mode
CheckRowKeyUpForUltraFast(key) {
    ; Simply forward to the core function that handles row key releases
    HandleRowKeyRelease(key)
}

; Row key up events
u up:: CheckRowKeyUpForUltraFast("u")
i up:: CheckRowKeyUpForUltraFast("i")
o up:: CheckRowKeyUpForUltraFast("o")
p up:: CheckRowKeyUpForUltraFast("p")
j up:: CheckRowKeyUpForUltraFast("j")
k up:: CheckRowKeyUpForUltraFast("k")
l up:: CheckRowKeyUpForUltraFast("l")
SC027 up:: CheckRowKeyUpForUltraFast(";") ; Semicolon
m up:: CheckRowKeyUpForUltraFast("m")
SC033 up:: CheckRowKeyUpForUltraFast(",") ; Comma
SC034 up:: CheckRowKeyUpForUltraFast(".") ; Period
SC035 up:: CheckRowKeyUpForUltraFast("/") ; Slash

#HotIf

; --- GLOBAL HOTKEYS (Always Active) ---

; If Shift is held, deactivate (like Caps Up)
#HotIf WinActive("ahk_group AntiMouseOverlays") && GetKeyState("Shift", "P")
*~$CapsLock:: {
    global showcaseDebug ; Reference variable from config.ahk
    currentTime := A_TickCount
    if (showcaseDebug) {
        LogToFile(Format("Timestamp: {} | CapsLock+Shift Hotkey: Deactivating via Shift", currentTime),
        A_ScriptDir "\debugRapidRefresh.log")
    }
    TransitionToState(State_IDLE) ; Set state first
    DeactivateGrid(true) ; Force deactivation
}
#HotIf

; Deactivation Hotkey (Escape)
#HotIf WinActive("ahk_group AntiMouseOverlays")
~$Escape:: {
    global showcaseDebug ; Reference variable from config.ahk
    currentTime := A_TickCount
    LogToFile(Format("Timestamp: {} | Escape pressed, calling DeactivateGrid", A_TickCount), "antimouse_core.log"
    )
    TransitionToState(State_IDLE)
    DeactivateGrid(true)
}

; Mouse Click Deactivation
; Left Mouse Button
#HotIf WinActive("ahk_group AntiMouseOverlays")
*~$LButton:: {
    global showcaseDebug ; Reference variable from config.ahk
    currentTime := A_TickCount
    LogToFile(Format("Timestamp: {} | LButton pressed, calling DeactivateGrid", A_TickCount),
    "antimouse_core.log")
    TransitionToState(State_IDLE) ; Force state
    DeactivateGrid(true) ; Force deactivation
}

; Right Mouse Button
#HotIf WinActive("ahk_group AntiMouseOverlays")
*~$RButton:: {
    global showcaseDebug ; Reference variable from config.ahk
    currentTime := A_TickCount
    LogToFile(Format("Timestamp: {} | RButton pressed, calling DeactivateGrid", A_TickCount),
    "antimouse_core.log")
    TransitionToState(State_IDLE) ; Force state
    DeactivateGrid(true) ; Force deactivation
}

; --- Activation via Tap + Key (e.g., Tap Caps, then press Q) ---
#HotIf currentState == State_IDLE
q:: {
    global g_ModifierState, doubleCapsThreshold, showcaseDebug
    currentTime := A_TickCount

    ; Check if CapsLock was released very recently (indicates a tap sequence)
    if (g_ModifierState.capsFirstReleased && (currentTime - g_ModifierState.lastCapsUpTime < doubleCapsThreshold)) {
        LogToFile(Format("Timestamp: {} | Tap+Q Activation Detected (Time since CapsUp: {}ms)",
            currentTime, currentTime - g_ModifierState.lastCapsUpTime), "antimouse_core.log")
        if (showcaseDebug) {
            ToolTip("Tap+Q Activation")
        }

        ; Activate the grid
        CapsLock_Q()

        ; Reset CapsLock state flags to prevent interference with subsequent actions
        g_ModifierState.capsPressedFirstTime := 0
        g_ModifierState.capsPressedSecondTime := 0
        g_ModifierState.capsFirstReleased := false
        g_ModifierState.inHoldMode := false ; Ensure hold mode is off for tap activation

        ; We don't snap to Q column here, just activate the grid.
        ; The original CapsLock+Q hotkey handled snapping.
        ; We could add snap logic here if needed, but let's start simple.

    } else {
        ; Just a normal 'q' key press while IDLE and CapsLock wasn't recently tapped
        Send "q" ; Send the original key press
    }
}
#HotIf

; --- Activation via Hold Caps + Q (for InstaClick on Release) ---
#HotIf currentState == State_IDLE
CapsLock & q:: {
    ; Access global state needed
    global currentState, StateMap, highlight, showcaseDebug, g_ModifierState

    LogToFile(Format("Timestamp: {} | Hold+Q Activation Detected", A_TickCount), "antimouse_core.log")

    ; Ensure CapsLock stays off
    SetCapsLockState "AlwaysOff"

    ; Get current mouse position *before* activating grid (for potential snapping)
    MouseGetPos(&cursorX, &cursorY)

    ; Activate the grid
    CapsLock_Q()

    ; --- Optional: Snap to Q column logic (restored from previous version) ---
    if (currentState == State_GRID_VISIBLE) {
        qColIndex := 0
        for i, colKey in StateMap['activeColKeys'] {
            if (colKey == "q") {
                qColIndex := i
                break
            }
        }
        if (qColIndex > 0) {
            rowIndex := 0
            initialCellKey := GetCellAtPosition(cursorX, cursorY) ; Check initial cell
            LogToFile(Format("Timestamp: {} | Hold+Q Snap: Initial cursor check -> cell '{}'", A_TickCount,
                initialCellKey), "antimouse_core.log")

            ; --- Same Row Priority Logic ---
            if (initialCellKey != "" && StateMap.Has('activeRowKeys') && StateMap['activeRowKeys'].Length > 0) {
                initialRowKey := SubStr(initialCellKey, StrLen(initialCellKey)) ; Get last char (row key)
                foundRowIndex := false
                for i, rowKey in StateMap['activeRowKeys'] {
                    if (rowKey == initialRowKey) {
                        rowIndex := i
                        foundRowIndex := true
                        LogToFile(Format(
                            "Timestamp: {} | Hold+Q Snap: Prioritizing row '{}' (index {}) from initial cell '{}'",
                            A_TickCount, initialRowKey, rowIndex, initialCellKey), "antimouse_core.log")
                        break
                    }
                }
                if (!foundRowIndex) {
                    LogToFile(Format(
                        "Timestamp: {} | Hold+Q Snap Warning: Extracted row '{}' not found in activeRowKeys!",
                        A_TickCount, initialRowKey), "antimouse_core.log")
                }
            }
            ; --- End Same Row Priority ---

            ; --- Fallback Logic (Nearest Y / Middle) ---
            if (rowIndex == 0) { ; Only run fallback if same row priority didn't find a valid index
                LogToFile(Format("Timestamp: {} | Hold+Q Snap: Using fallback logic (Nearest Y / Middle)", A_TickCount),
                "antimouse_core.log")
                if (IsObject(StateMap['currentOverlay']) && StateMap['currentOverlay'].ContainsPoint(cursorX, cursorY)) {
                    bestDistance := 99999, bestRowIndex := 0
                    LogToFile(Format("Timestamp: {} | Hold+Q Snap Fallback: Checking rows for nearest Y to {}",
                        A_TickCount, cursorY), "antimouse_core.log")
                    for i, rowKey in StateMap['activeRowKeys'] {
                        cellKey := "q" . rowKey
                        boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
                        if (IsObject(boundaries)) {
                            cellCenterY := boundaries.y + (boundaries.h // 2)
                            distance := Abs(cellCenterY - cursorY)
                            LogToFile(Format(
                                "Timestamp: {} | Hold+Q Snap Fallback: Row '{}' (idx {}), CenterY={}, Dist={}",
                                A_TickCount, rowKey, i, cellCenterY, distance), "antimouse_core.log")
                            if (distance < bestDistance) {
                                bestDistance := distance, bestRowIndex := i
                            }
                        }
                    }
                    if (bestRowIndex > 0) {
                        rowIndex := bestRowIndex
                        LogToFile(Format("Timestamp: {} | Hold+Q Snap Fallback: Nearest row index is {}", A_TickCount,
                            rowIndex), "antimouse_core.log")
                    }
                }
                if (rowIndex == 0) {
                    lastIdx := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 0
                    middleIdx := Ceil(StateMap['activeRowKeys'].Length / 2)
                    rowIndex := lastIdx ? lastIdx : middleIdx
                    LogToFile(Format("Timestamp: {} | Hold+Q Snap Fallback: Using middle/last row index: {}",
                        A_TickCount, rowIndex), "antimouse_core.log")
                }
            }
            ; --- End Fallback Logic ---

            rowIndex := ValidateIndex(rowIndex, StateMap['activeRowKeys'].Length)
            LogToFile(Format("Timestamp: {} | Hold+Q Snap: Final validated rowIndex = {}", A_TickCount, rowIndex),
            "antimouse_core.log")
            if (rowIndex > 0) { ; Ensure we have a valid row index before proceeding
                ; --- REMOVE StateMap updates that imply standard grid navigation ---
                ; StateMap['firstKey'] := "q"
                ; StateMap['currentColIndex'] := qColIndex
                ; StateMap['currentRowIndex'] := rowIndex
                StateMap['lastSelectedRowIndex'] := rowIndex ; Keep this one for potential future use

                rowKey := StateMap['activeRowKeys'][rowIndex]
                cellKey := "q" . rowKey
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
                if (IsObject(boundaries)) {
                    targetX := boundaries.x + (boundaries.w // 2)
                    targetY := boundaries.y + (boundaries.h // 2)

                    ; --- STORE Target Coords instead of moving mouse/setting firstKey ---
                    StateMap['instantClickTargetX'] := targetX
                    StateMap['instantClickTargetY'] := targetY
                    LogToFile(Format("Timestamp: {} | Hold+Q Snap: Stored instant click target ({}, {}) for cell '{}'",
                        A_TickCount, targetX, targetY, cellKey), "antimouse_core.log")

                    ; Update highlight visually, but don't change state logic
                    if (IsObject(highlight)) {
                        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                    }
                    if (showcaseDebug) {
                        ToolTip("Target: " cellKey)
                    }
                } else {
                    LogToFile(Format("Timestamp: {} | Hold+Q Snap Error: Failed to get boundaries for target cell '{}'",
                        A_TickCount, cellKey), "antimouse_core.log")
                }
            } else {
                LogToFile(Format("Timestamp: {} | Hold+Q Snap Error: Failed to determine valid row index", A_TickCount),
                "antimouse_core.log")
            }
        }
    }
    ; --- End Optional Snap Logic ---

    ; CRITICAL: Set inHoldMode for this activation type to enable InstaClick on release
    g_ModifierState.inHoldMode := true
    LogToFile(Format("Timestamp: {} | Hold+Q: Set inHoldMode=true", A_TickCount), "antimouse_core.log")
}
#HotIf