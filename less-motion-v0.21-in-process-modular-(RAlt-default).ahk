#Requires AutoHotkey v2.0

; Configuration Section
global Config := {
    ; Choose your modifier key. Options:
    ; "RAlt" - Right Alt key
    ; "CapsLock" - CapsLock key
    ; "LWin" - Left Windows key
    ; You can add more keys as needed
    ModifierKey: "RAlt"
}

; Global state tracking
global State := {
    shift: false,
    ctrl: false
}

; Dynamically handle the modifier key
Hotkey(Config.ModifierKey, CallbackFunc)

CallbackFunc(*) {
    KeyWait(Config.ModifierKey)
}

; Context-sensitive hotkeys when modifier is pressed
#HotIf GetKeyState(Config.ModifierKey, "P")

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

    State.shift := true
    startTime := A_TickCount
    lastPressTime := currentTime
    KeyWait("a")
    State.shift := false

    ; Quick tap action
    if (A_TickCount - startTime < 200) {
        SendInput("^+{F11}")
    }
}

s::
{
    State.ctrl := true
    startTime := A_TickCount
    KeyWait("s")
    State.ctrl := false
    i
    ; Quick tap action
    if (A_iTickCount - startTime < 200) {
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
    key := A_ThisHotkey

    ; Update modifiers
    State.ctrl := GetKeyState("s", "P")
    State.shift := GetKeyState("a", "P")

    baseMap := Map(
        "i", "{Up}",
        "j", "{Left}",
        "k", "{Down}",
        "l", "{Right}",
        "9", "{Home}",
        "0", "{End}"
    )

    ; Construct output with modifiers
    output := ""
    if (State.ctrl) {
        output .= "^"
    }
    if (State.shift) {
        output .= "+"
    }
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
