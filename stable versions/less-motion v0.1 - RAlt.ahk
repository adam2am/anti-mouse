; with korean keyboard switch (RAlt) its kinda broken now
; I mean I dont want for this switch to work, right now its overlapping my functionality
; and not letting the script work while me holding the RAlt
#Requires AutoHotkey v2.0

; Global state tracking
global g_ModifierState := {
    shift: false,
    ctrl: false
}

; Suppress the default Alt menu behavior
RAlt::
{
    KeyWait "RAlt"
    return
}

#HotIf GetKeyState("RAlt", "P")

a:: {
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

s:: {
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
; Clipboard, Delete, and Other Shortcuts
c:: SendEvent "^c"
x:: SendEvent "^x"
v:: SendEvent "^v"
z:: SendEvent "^z"
f:: SendEvent "!f"  ; For fuzzy finder- jumper
m:: SendEvent "!m"  ; RAlt + M now sends Alt+M - for neovim escaping to normal mode
`;:: SendEvent "{Backspace}"
':: SendEvent "{Delete}"
/:: SendEvent "{Enter}"
#HotIf ; Reset context
