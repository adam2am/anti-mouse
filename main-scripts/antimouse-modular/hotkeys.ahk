; ==============================================================================
; hotkeys.ahk - Hotkey Definitions for AntiMouse
; ==============================================================================

; --- CONSOLIDATED HOTKEYS for GRID_VISIBLE or SUBGRID_ACTIVE ---
; These hotkeys are active only when the grid or subgrid is visible.
; They call the ProcessKeyPress function (from core_logic.ahk) to handle the input based on the current state.
#HotIf currentState == "GRID_VISIBLE" || currentState == "SUBGRID_ACTIVE"
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

; Monitor switching hotkeys (active when grid is visible)
1:: SwitchMonitor(1) ; Function from core_logic.ahk
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
#HotIf ; End context for grid/subgrid active state

; --- HOTKEYS FOR IDLE STATE (Activation with CapsLock + Key) ---
; These activate the grid *and* potentially perform an initial action.
#HotIf GetKeyState('CapsLock', 'P') && (currentState == "IDLE")
q:: {
    ; Access global state needed for this specific hotkey logic
    global currentState, StateMap, highlight, showcaseDebug

    ; Ensure CapsLock stays off (redundant but safe)
    SetCapsLockState "AlwaysOff"

    ; Get current mouse position *before* activating grid
    MouseGetPos(&cursorX, &cursorY)

    ; First, activate the grid using the function from activation.ahk
    CapsLock_Q()

    ; If grid activation was successful, immediately snap to the 'q' column
    if (currentState == "GRID_VISIBLE") {
        ; Find 'q' column index in the currently active layout keys
        qColIndex := 0
        for i, colKey in StateMap['activeColKeys'] {
            if (colKey == "q") {
                qColIndex := i
                break
            }
        }

        ; If 'q' column exists in the layout
        if (qColIndex > 0) {
            ; Determine the target row based on cursor position or last selection
            rowIndex := 0
            if (IsObject(StateMap['currentOverlay']) && StateMap['currentOverlay'].ContainsPoint(cursorX, cursorY)) {
                ; Find the row nearest to the current cursor Y position in the 'q' column
                bestDistance := 99999
                bestRowIndex := 0
                for i, rowKey in StateMap['activeRowKeys'] {
                    cellKey := "q" . rowKey
                    boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)
                    if (IsObject(boundaries)) {
                        cellCenterY := boundaries.y + (boundaries.h // 2)
                        distance := Abs(cellCenterY - cursorY)
                        if (distance < bestDistance) {
                            bestDistance := distance
                            bestRowIndex := i
                        }
                    }
                }
                if (bestRowIndex > 0) {
                    rowIndex := bestRowIndex
                }
            }

            ; Fallback if no suitable row found based on cursor position
            if (rowIndex == 0) {
                rowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : Ceil(StateMap[
                    'activeRowKeys'].Length / 2)
            }

            ; Validate the determined row index
            rowIndex := ValidateIndex(rowIndex, StateMap['activeRowKeys'].Length) ; Function from utils.ahk

            ; Set state variables for the selected cell
            StateMap['firstKey'] := "q" ; Mark 'q' as the first key pressed
            StateMap['currentColIndex'] := qColIndex
            StateMap['currentRowIndex'] := rowIndex
            StateMap['lastSelectedRowIndex'] := rowIndex ; Remember this row

            ; Construct the cell key and get its boundaries
            rowKey := StateMap['activeRowKeys'][rowIndex]
            cellKey := "q" . rowKey
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey)

            if (IsObject(boundaries)) {
                ; Move cursor to the center of the target cell
                MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
                ; Update the highlight overlay
                if (IsObject(highlight)) {
                    highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                }
                if (showcaseDebug)
                    ToolTip("Selected cell: " cellKey)
            }
        }
    }
    ; Set inHoldMode so releasing CapsLock triggers a click (handled in CapsLock Up)
    g_ModifierState.inHoldMode := true
}
#HotIf ; End context for IDLE state activation

; --- HOTKEYS FOR CAPSLOCK HELD (Monitor Switch Activation/Switching) ---
; These handle CapsLock + Number keys.
; If IDLE, they activate the grid first, then switch.
; If already active, they just switch the monitor.
#HotIf GetKeyState('CapsLock', 'P')
1:: {
    global currentState, g_ModifierState ; Access state
    SetCapsLockState "AlwaysOff"
    SetTimer(TrackCursor, 0) ; Stop tracking during switch
    if (currentState == "IDLE") {
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
    if (currentState == "IDLE") {
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
    if (currentState == "IDLE") {
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
    if (currentState == "IDLE") {
        CapsLock_Q()
        Sleep(100)
    }
    SwitchMonitor(4)
    g_ModifierState.inHoldMode := true
    SetTimer(TrackCursor, 50)
}
#HotIf ; End context for CapsLock held

; --- HOTKEYS FOR CAPSLOCK HELD (NON-INSTACLICK HOLD MODE, GRID ACTIVE) ---
; These use the CapsLock & syntax. They trigger when Caps is held, grid is active,
; *and* we are NOT in the specific `inHoldMode` (which is set by double-tap or activation keys).
; This allows CapsLock+Key to function as navigation when CapsLock is simply held down
; without the intention of performing an InstaClick on release.
#HotIf GetKeyState('CapsLock', 'P') && (currentState == "GRID_VISIBLE" || currentState == "SUBGRID_ACTIVE") && !
g_ModifierState.inHoldMode

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

#HotIf ; End context for CapsLock held (non-InstaClick mode)

; --- Other Hotkeys (Space, Escape, Tab) ---
; These apply whenever the grid is active (GRID_VISIBLE or SUBGRID_ACTIVE).
#HotIf currentState != "IDLE"
Space:: {
    ; Access global state and config needed
    global currentState, highlight, subGrid, StateMap, showcaseDebug

    try {
        ; Save mouse position *before* any cleanup or state change
        MouseGetPos(&mouseX, &mouseY)

        ; Stop tracking and change state immediately to prevent race conditions
        SetTimer(TrackCursor, 0)
        currentState := "IDLE" ; Set state first

        ; Explicitly remove tooltips
        ToolTip()

        ; Hide UI elements quickly
        if (IsObject(highlight)) highlight.Hide()
            if (IsObject(subGrid)) subGrid.Hide()
                for overlay in StateMap['overlays'] {
                    if (IsObject(overlay))
                        overlay.Hide()
                }

        Sleep(30) ; Small delay to ensure UI is hidden

        ; Perform the mouse click at the saved position
        ; Using Click() is generally more reliable than MouseClick for simple clicks
        Click("Left")
        ; Fallback if Click fails (less common in v2 but possible)
        ; if GetKeyState("LButton", "P") != 1 {
        ;     MouseClick("Left", mouseX, mouseY, 1, 0)
        ; }

        ; Perform full cleanup *after* the click
        Sleep(30) ; Delay before final cleanup
        Cleanup() ; Function from activation.ahk
    } catch as e {
        if (showcaseDebug) ToolTip("Error during Space action: " e.Message)
        ; Attempt cleanup even if there was an error during the click/hide phase
            Cleanup()
    }
}

Escape:: {
    ; Access global state and config needed
    global currentState, showcaseDebug

    ; Safely call Cleanup (function from activation.ahk)
    try {
        Cleanup()
    } catch as e {
        if (showcaseDebug) ToolTip("Error during Escape cleanup: " e.Message)
        ; If standard cleanup failed, attempt a more forceful cleanup
            try {
                currentState := "IDLE" ; Force state
                ForceCloseAllGuis()    ; Force close GUIs (function from utils.ahk)
                ; Reset object references manually as a last resort
                highlight := ""
                subGrid := ""
                StateMap['overlays'] := []
                StateMap['currentOverlay'] := ""
                ToolTip() ; Clear tooltips
            } catch {
                ; Ignore errors during forced cleanup
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
    if (IsObject(subGrid)) subGrid.Hide()
        if (IsObject(highlight)) highlight.Hide()
            Sleep(20) ; Small delay

    ; Cycle to the next monitor (function from core_logic.ahk)
    CycleToNextMonitor()

    Sleep(30) ; Small delay before re-enabling tracking

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)
}
#HotIf ; End context for grid active state

; --- CapsLock Handling (Single/Double Tap, Hold/Release) ---
; This handles the core logic for activating/deactivating the grid via CapsLock
; and managing the 'inHoldMode' for InstaClick functionality.

; Note: The '$' prefix might help prevent the hotkey triggering itself in some cases,
; but might not be strictly necessary with `SetCapsLockState "AlwaysOff"`. Keep if issues arise.
; $CapsLock::
CapsLock:: {
    ; Access global state and config
    global g_ModifierState, doubleCapsThreshold, instaClickMode, currentState, showcaseDebug

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
                if (currentState == "IDLE") {
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
        doubleCapsThreshold

    ; Ensure CapsLock toggle state remains off
    SetCapsLockState "AlwaysOff"

    currentTime := A_TickCount
    g_ModifierState.lastCapsUpTime := currentTime
    g_ModifierState.capsFirstReleased := true ; Mark that a release occurred
    g_ModifierState.caps := false             ; Update physical state tracker

    ; --- InstaClick Handling ---
    ; Perform click if we were in hold mode (set by double-tap or Caps+Key activation)
    if (g_ModifierState.inHoldMode && currentState != "IDLE") {
        if (showcaseDebug) ToolTip("InstaClick: Clicking & Cleaning up")
            try {
                ; Save mouse position before cleanup potentially moves it
                MouseGetPos(&mouseX, &mouseY)

                ; Stop tracking and set state to IDLE immediately
                SetTimer(TrackCursor, 0)
                currentState := "IDLE"

                ; Hide UI elements quickly
                if (IsObject(highlight)) {
                    highlight.Hide()
                }
                if (IsObject(subGrid)) {
                    subGrid.Hide()
                }
                for overlay in StateMap['overlays'] {
                    if (IsObject(overlay)) {
                        overlay.Hide()
                    }
                }
                Sleep(50) ; Slightly longer delay for UI hiding

                ; Perform the click
                Click("Left") ; Use reliable Click command

                ; Perform full cleanup *after* the click
                Sleep(50) ; Delay before final cleanup
                Cleanup() ; Function from activation.ahk

            } catch as e {
                if (showcaseDebug) {
                    ToolTip("Error during InstaClick: " e.Message)
                    Sleep(1000)
                }
                ; Ensure cleanup happens even if click fails
                try Cleanup()
            }

        ; Reset hold mode and press times after click/cleanup
        g_ModifierState.inHoldMode := false
        g_ModifierState.capsPressedFirstTime := 0
        g_ModifierState.capsPressedSecondTime := 0

    } else {
        ; --- Single Tap Handling ---
        ; If not in hold mode, check if this release corresponds to a single tap
        if (!g_ModifierState.inHoldMode && currentState != "IDLE") {
            ; Check if enough time has passed since the first press to rule out a double-tap starting
            if (g_ModifierState.capsPressedFirstTime > 0 && (currentTime - g_ModifierState.capsPressedFirstTime
            ) > doubleCapsThreshold) {
                if (showcaseDebug) ToolTip("Single CapsLock tap detected - Cleaning up")
                    try {
                        Cleanup() ; Clean up grid on single tap release
                    } catch as e {
                        if (showcaseDebug) {
                            ToolTip("Error during cleanup: " e.Message)
                            Sleep(1000)
                        }
                    }
                ; Reset press time after cleanup for single tap
                g_ModifierState.capsPressedFirstTime := 0
                g_ModifierState.capsPressedSecondTime := 0
            } else if (g_ModifierState.capsPressedFirstTime == 0) {
                ; This case might occur if CapsLock Up is detected without a prior Down event
                if (showcaseDebug) ToolTip("CapsLock Up detected without recorded press - Cleaning up")
                    try Cleanup()
            }
        }

        ; Reset hold mode flag if it wasn't already reset by click handling
        if (g_ModifierState.inHoldMode && currentState == "IDLE") {
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
#HotIf currentState == "SUBGRID_ACTIVE" && StateMap['inUltraFastMode']

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