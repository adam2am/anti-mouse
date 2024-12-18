; ---- Main Version with viable updates, 0.21 in a proces  ----
; this version is opiniated, anti-modular approach
; only caps as power button, nothing else
; -- this check is about adding a double capslock as a shift, then to make tab work as expected
#Requires AutoHotkey v2.0

; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state tracking with more robust mode management
global g_ModifierState := {
    shift: false,
    ctrl: false,
    capslockToggled: false,
    capsLockJustReleased: false,  ; Add this line to initialize the property
    doubleCapsShift: false,
    capsLockUpDetected: false
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

; --- Double-tap Caps Lock for Shift, detecting with Upside Caps in between ---
CapsLock:: {
    static lastPressTime := 0
    currentTime := A_TickCount

    ; Double-click detection
    if (currentTime - lastPressTime < 300) {
        ; Double-tap detected ONLY if CapsLock was released between taps
        if (g_ModifierState.capsLockUpDetected) {
            g_ModifierState.doubleCapsShift := true
            ToolTip("Double-Caps Shift ON", A_ScreenWidth / 2, A_ScreenHeight / 2)
            SetTimer(() => ToolTip(), -1000)
            g_ModifierState.capsLockUpDetected := false ; Reset for next double-tap
        }
        lastPressTime := 0
    } else {
        ; Single tapD
        g_ModifierState.capsLockUpDetected := false ; Reset if single tap
        lastPressTime := currentTime
    }
}

CapsLock up:: {
    g_ModifierState.capsLockUpDetected := true ; Mark that CapsLock was released

    ; Introduce a delay before turning off the modifier state
    SetTimer(DisableDoubleCapsShift, -50)
}

DisableDoubleCapsShift() {
    if g_ModifierState.doubleCapsShift {
        g_ModifierState.doubleCapsShift := false
        ToolTip("Double-Caps Shift OFF", A_ScreenWidth / 2, A_ScreenHeight / 2)
        SetTimer(() => ToolTip(), -1000)
    }
}

; --- Handle Tab Key ---
*Tab::
{
    ; If CapsLock is also pressed, it's a modifier combination
    if GetKeyState("CapsLock", "P") {
        ToggleCapsLock()
        ; Handle CapsLock + Tab behavior here (e.g., custom action)
        ; Currently, it does nothing, but you can add your desired action
        return ; Prevent default Tab behavior when CapsLock is pressed
    } else {
        SendEvent "{Tab}"
    }
}

; Context-sensitive hotkeys when modifier is pressed
#HotIf GetKeyState("CapsLock", "P") and not g_ModifierState.doubleCapsShift

a::
{
    static lastPressTime := 0
    currentTime := A_TickCount

    ; Double-click detection => Ctrl-A a quick All-Selection
    if (currentTime - lastPressTime < 300) {
        SendInput("^a")
        lastPressTime := 0
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

    static lastPressTime := 0
    currentTime := A_TickCount

    ; Double-click detection => Ctrl S as a Quick-Save
    if (currentTime - lastPressTime < 300) {
        SendInput("^s")
        lastPressTime := 0
        return
    }

    global g_ModifierState
    g_ModifierState.ctrl := true
    startTime := A_TickCount
    lastPressTime := currentTime
    KeyWait "s"
    g_ModifierState.ctrl := false

    ; Quick tap action
    if (A_TickCount - startTime < 200) {
        SendInput("^+{F12}")
    }
}

; Navigation and Selection Logic
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

c:: SendEvent "^c"
x:: SendEvent "^x"
v:: SendEvent "^v"
z:: SendEvent "^z"
y:: SendEvent "^y"

f:: SendEvent "!f"  ; For fuzzy finder- jumper
m:: SendEvent "!m"  ; CapsLock + M now sends Alt+M - for neovim escaping to normal mode

`;:: SendEvent "{Backspace}"
ж:: SendEvent "{Backspace}"
':: SendEvent "{Delete}"
/:: SendEvent "{Enter}"
#HotIf

; Shifted-Hotkeys for every key has to be shifted when double caps (shift) is on
#HotIf g_ModifierState.doubleCapsShift
a::
b::
c::
d::
e::
f::
g::
h::
i::
j::
k::
l::
m::
n::
o::
p::
q::
r::
s::
t::
u::
v::
w::
x::
y::
z::
0::
1::
2::
3::
4::
5::
6::
7::
8::
9::
F1::
F2::
F3::
F4::
F5::
F6::
F7::
F8::
F9::
F10::
F11::
F12::
-::
=::
[::
]::
\::
`;::
'::
,::
.::
/::
Numpad0::
Numpad1::
Numpad2::
Numpad3::
Numpad4::
Numpad5::
Numpad6::
Numpad7::
Numpad8::
Numpad9::
NumpadDot::
NumpadDiv::
NumpadMult::
NumpadAdd::
NumpadSub::
NumpadEnter::
Space::
Tab::
{
    key := A_ThisHotkey
    SendEvent("+" key) ; Send shifted character
}
#HotIf