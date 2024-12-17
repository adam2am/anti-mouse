;0.21 in a process, this check is about adding a capslock lock if the powerButton gonna be the capslock
#Requires AutoHotkey v2.0

; Global state tracking with more robust mode management
global g_ModifierState := {
    shift: false,
    ctrl: false,
    powerButtonToggled: false,
    powerButtonReleased: false  ; Add this line to initialize the property
}

; Configuration Section
global Config := {
    ; Choose your modifier key. Options:
    ; "RAlt" - Right Alt key
    ; "CapsLock" - CapsLock key
    ; "LWin" - Left Windows key
    ; You can add more keys as needed
    ; ---- I have a custom vk19 for a KR layout ----
    powerButton: "vk19"
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

; Dynamically handle the modifier key
Hotkey(Config.powerButton, CallbackFunc)

CallbackFunc(*) {
    KeyWait(Config.powerButton)
}

; Context-sensitive hotkeys when modifier is pressed
#HotIf GetKeyState(Config.powerButton, "P")

a::
{
    static lastPressTime := 0
    currentTime := A_TickCount

    ; Double-click detection
    if (currentTime - lastPressTime < 300) {
        SendInput("^a")
        lastPressTime := 0
        return
    }

    global g_ModifierState
    g_ModifierState.shift := true
    startTime := A_TickCount
    lastPressTime := currentTime

    KeyWait("a")
    g_ModifierState.shift := false

    ; Quick tap action
    if (A_TickCount - startTime < 200) {
        SendInput("^+{F11}")
    }
}

s::
{

    static lastPressTime := 0
    currentTime := A_TickCount

    ; Double-click detection
    if (currentTime - lastPressTime < 300) {
        SendInput("^a")
        lastPressTime := 0
        return
    }

    global g_ModifierState
    g_ModifierState.ctrl := true
    startTime := A_TickCount
    lastPressTime := currentTime
    KeyWait("s")
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

    ; Update modifiers
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

    SendInput(output)
}

; Shortcuts
c:: SendInput("^c")
x:: SendInput("^x")
v:: SendInput("^v")
z:: SendInput("^z")

f:: SendInput("!f")
m:: SendInput("!m")

`;:: SendInput("{Backspace}")
':: SendInput("{Delete}")
/:: SendInput("{Enter}")

#HotIf ; Reset context
