#Requires AutoHotkey v2.0

; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state tracking with more robust mode management
global g_ModifierState := {
    shift: false,
    ctrl: false,
    capslockToggled: false,
    capsLockJustReleased: false  ; Add this line to initialize the property
}

; --- ToolTip Configuration ---
global g_Tooltip := {
    ; Default position (will be adjusted dynamically)
    x: 0,
    y: 0,
    textOn: "CapsLock ON",
    textOff: "",
    colorOn: "Red",
    colorOff: "White",
    font: "s12 Arial"
}

; Function to get the monitor number where the mouse is
GetActiveMonitorNumber() {
    MouseGetPos(&x, &y)
    monitorCount := MonitorGetCount()

    loop monitorCount {
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
        if (x >= Left && x < Right && y >= Top && y < Bottom)
            return A_Index
    }
    return 1  ; Default to first monitor if no match found
}

; Function to toggle CapsLock and update tooltip to show w                      e have a Caps "ON"
ToggleCapsLock() {
    global g_ModifierState, g_Tooltip

    g_ModifierState.capslockToggled := !g_ModifierState.capslockToggled
    SetCapsLockState(g_ModifierState.capslockToggled ? "On" : "Off")

    if (g_ModifierState.capslockToggled) {
        ; Get the active monitor number
        activeMonitor := GetActiveMonitorNumber()

        ; Get monitor coordinates using MonitorGet
        MonitorGet(activeMonitor, &Left, &Top, &Right, &Bottom)

        ; Calculate tooltip position dynamically
        ToolTipX := Left + 50  ; 50 pixels from the left edge
        ToolTipY := Bottom - 100 ; 100 pixels from the bottom edge

        ; Set the font
        A_DefaultToolTipFont := g_Tooltip.font
        ; Display the tooltip
        ToolTip(g_Tooltip.textOn, ToolTipX, ToolTipY)
    } else {
        ; Hide the tooltip
        ToolTip()
    }
}

; --- Main CapsLock + Tab Logic ---
Tab::
{
    if GetKeyState("CapsLock", "P") {
        ToggleCapsLock()
        return  ; Prevent default tab behavior
    }
    Send "{Tab}"  ; Normal tab behavior when CapsLock is not pressed
}

CapsLock::
{
    if GetKeyState("Tab", "P") {
        ToggleCapsLock()
        return  ; Prevent default CapsLock behavior
    }
    ; You can add any default CapsLock behavior here if needed
}

; --- Modifier Key Modes ---
#HotIf GetKeyState("CapsLock", "P")

a::
{
    static lastPressTime := 0
    currentTime := A_TickCount

    ; Check for double-click
    if (currentTime - lastPressTime < 300) {
        ; Double-click detected, send Ctrl+A
        SendEvent "^a"
        lastPressTime := 0 ; Reset for next double-click
        return
    }

    global g_ModifierState
    g_ModifierState.shift := true
    startTime := A_TickCount
    lastPressTime := currentTime ; Update last press time for double-click detection
    KeyWait "a"
    g_ModifierState.shift := false

    ; Quick tap sends Ctrl+Shift+F11
    if (A_TickCount - startTime < 200) {
        SendEvent "^+{F11}"
    }
}

s::
{
    global g_ModifierState
    g_ModifierState.ctrl := true
    startTime := A_TickCount
    KeyWait "s"
    g_ModifierState.ctrl := false

    ; Quick tap sends Ctrl+Shift+F12
    if (A_TickCount - startTime < 200) {
        SendEvent "^+{F12}"
    }
}

; --- Navigation and Selection Logic ---
i::
j::
k::
l::
9::
0::
{
    global g_ModifierState
    key := A_ThisHotkey

    ; Update modifiers based on current key states
    g_ModifierState.ctrl := GetKeyState("s", "P")
    g_ModifierState.shift := GetKeyState("a", "P")

    baseMap := Map(
        "i", "{Up}",
        "j", "{Left}",
        "k", "{Down}",
        "l", "{Right}",
        "9", "{Home}",
        "0", "{End}"
    )

    ; Construct the output based on tracked modifiers
    output := ""
    if g_ModifierState.ctrl
        output .= "^"
    if g_ModifierState.shift
        output .= "+"
    output .= baseMap[key]

    SendEvent output
}
#HotIf ; Reset context

;-------.
;------- Clipboard, Delete, and Other Shortcuts
#HotIf GetKeyState("CapsLock", "P")

; default Ctrl+CXVZ to Caps+CXVZ
c:: SendEvent "^c"
x:: SendEvent "^x"
v:: SendEvent "^v"
z:: SendEvent "^z"

f:: SendEvent "!f"  ; For fuzzy finder- jumper
m:: SendEvent "!m"  ; CapsLock + M now sends Alt+M - for neovim escaping to normal mode

`;:: SendEvent "{Backspace}"
':: SendEvent "{Delete}"
/:: SendEvent "{Enter}"
#HotIf