﻿#Requires AutoHotkey v2.0

; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state tracking
global g_ModifierState := {
    shift: false,
    ctrl: false,
    singleTapShift: false,
    singleTapCaps: false,
    doubleTapCaps: false,
    holdCapsShiftModeActivate: false,
    awaitingRelease: false,
    shiftLastPressTime: 0,
    shiftPressStartTime: 0,
    capslockToggled: false,
    showcaseDebug: false,
    singleTapShift: false,
    shiftPressTime: 0,
    shiftBeingHeld: false,
    shiftSingleTapUsed: false,
    capsSingleTapUsed: false,
    shiftTapTime: 0,
    capsTapTime: 0,
    capsLockReleaseCount: 0,
    capsLockPressCount: 0,
    capsLastPressTime: 0,
    capsPressStartTime: 0
}

; --- ToolTip Configuration ---
global g_Tooltip := {
    x: 0,
    y: 0,
    textSingleShiftTap: "Next key shifted (Shift single-tap)",
    textSinglecapsTap: "Next key shifted (caps single-tap)",
    textDoubleTap: "Double-tap mode active",
    colorNormal: "White",
    colorActive: "Red",
    font: "s12 Arial"
}

; Helper function for tooltip positioning
GetTooltipPosition() {
    MouseGetPos(&mouseX, &mouseY)
    monitorCount := MonitorGetCount()

    loop monitorCount {
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
        if (mouseX >= Left && mouseX < Right && mouseY >= Top && mouseY < Bottom) {
            return { x: Left + 50, y: Bottom - 100 }
        }
    }
    return { x: 50, y: A_ScreenHeight - 100 }
}

; Show tooltip with optional duration
ShowTooltip(text := "", duration := 1000) {
    if (text = "") {
        ToolTip()
        return
    }

    pos := GetTooltipPosition()
    ToolTip(text, pos.x, pos.y)

    if (duration > 0) {
        SetTimer () => ToolTip(), -duration
    }
}

; --- Shift Handling ---
~LShift:: {
    global g_ModifierState
    g_ModifierState.shiftPressTime := A_TickCount
    g_ModifierState.shiftBeingHeld := true
    ; Reset the used flag when shift is pressed again
    g_ModifierState.shiftSingleTapUsed := false
}

~LShift Up:: {
    global g_ModifierState
    pressTime := A_TickCount - g_ModifierState.shiftPressTime

    if (pressTime < 200
        && g_ModifierState.shiftBeingHeld
        && !g_ModifierState.shiftSingleTapUsed) {
        g_ModifierState.singleTapShift := true
        g_ModifierState.shiftTapTime := A_TickCount
        ShowTooltip(g_Tooltip.textSingleShiftTap)
    }
    g_ModifierState.shiftBeingHeld := false
}

; --- CapsLock Handling ---
CapsLock:: {
    global g_ModifierState
    currentTime := A_TickCount
    g_ModifierState.capsPressStartTime := currentTime
    ; Reset the used flag when caps is pressed again
    g_ModifierState.capsSingleTapUsed := false

    if (g_ModifierState.singleTapCaps && currentTime - g_ModifierState.capsLastPressTime >= 200) {
        g_ModifierState.singleTapCaps := false
        ShowTooltip()
    }

    g_ModifierState.capsLockPressCount += 1

    if (currentTime - g_ModifierState.capsLastPressTime < 200
        && g_ModifierState.capsLockReleaseCount > 0) {
        g_ModifierState.doubleTapCaps := true
        g_ModifierState.doubleTapHeld := true
        g_ModifierState.singleTapCaps := false
        ShowTooltip(g_Tooltip.textDoubleTap, 0)
    } else {
        g_ModifierState.awaitingRelease := true
    }

    g_ModifierState.capsLastPressTime := currentTime
}

CapsLock Up:: {
    global g_ModifierState
    currentTime := A_TickCount
    pressDuration := currentTime - g_ModifierState.capsPressStartTime

    g_ModifierState.capsLockReleaseCount += 1

    ; Handle single tap
    if (pressDuration < 200
        && !g_ModifierState.capsSingleTapUsed
        && !g_ModifierState.doubleTapCaps) {
        g_ModifierState.singleTapCaps := true
        g_ModifierState.capsTapTime := A_TickCount
        ShowTooltip(g_Tooltip.textSinglecapsTap)
    }

    g_ModifierState.awaitingRelease := false
    SetTimer(ResetCapsLockCounts, -500)
}

ResetCapsLockCounts() {
    global g_ModifierState
    g_ModifierState.capsLockPressCount := 0
    g_ModifierState.capsLockReleaseCount := 0
}

; Context-sensitive hotkeys when modifier is pressed
#HotIf GetKeyState("CapsLock", "P")
a:: {
    static lastPressTime := 0
    currentTime := A_TickCount

    if (currentTime - lastPressTime < 300) {
        SendInput("^a")
        lastPressTime := 0
        return
    }

    global g_ModifierState
    g_ModifierState.shift := true
    startTime := A_TickCount
    lastPressTime := currentTime
    KeyWait "a"
    g_ModifierState.shift := false

    if (A_TickCount - startTime < 200) {
        SendEvent "^+{F11}"
    }
}

s:: {
    static lastPressTime := 0
    currentTime := A_TickCount

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
0:: {
    global g_ModifierState
    key := A_ThisHotkey
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

    output := ""
    if g_ModifierState.ctrl
        output .= "^"
    if g_ModifierState.shift
        output .= "+"
    output .= baseMap[key]
    SendEvent output
}

; Standard shortcuts
vk43:: SendEvent "^c" ; c
vk58:: SendEvent "^x" ; x
vk56:: SendEvent "^v" ; v
vk5A:: SendEvent "^z" ; z
vk55:: SendEvent "^z" ; u
vk31:: SendEvent "!1" ; 1
vk32:: SendEvent "!2" ; 2
vk33:: SendEvent "!3" ; 3
vk34:: SendEvent "!4" ; 4
vk35:: SendEvent "!5" ; 5
vk36:: SendEvent "!6" ; 6
vk37:: SendEvent "!7" ; 7
vk38:: SendEvent "!8" ; 8
vk59:: SendEvent "^y" ; y
vkC0:: SendEvent "^``" ; `
vk46:: SendEvent "!f" ; f
vk4D:: SendEvent "!m" ; m

; Special handling for forward slash
*vkBF:: {
    if not GetKeyState("s", "P") and not GetKeyState("a", "P")
        SendEvent "{Enter}"
    else if GetKeyState("s", "P") and not GetKeyState("a", "P")
        SendEvent "^{Enter}"
    else if not GetKeyState("s", "P") and GetKeyState("a", "P")
        SendEvent "+{Enter}"
    else if GetKeyState("s", "P") and GetKeyState("a", "P")
        SendEvent "+^{Enter}"
}

vkDE:: SendEvent "{Backspace}" ; '
vkDB:: SendEvent "{Delete}"    ; [
vk44:: SendEvent "{Delete}"    ; d
#HotIf

; Layout handling functions
GetCurrentLayout() {
    activeWnd := WinExist("A")
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", activeWnd, "Ptr", 0)
    layout := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    return Format("{:08X}", layout & 0xFFFF)
}

global layoutMappings := Map(
    "00000409", Map(  ; English (US)
        "б", ",",
        "Б", "<",
        "ю", ".",
        "Ю", ">",
        "х", "[",
        "Х", "{",
        "ъ", "]",
        "Ъ", "}",
        "ж", ";",
        "Ж", ":",
        "э", "'",
        "Э", '"',
        ".", "/",
        ",", "?"
    ),
    "00000419", Map(  ; Russian
        ",", "б",
        "<", "Б",
        ".", "ю",
        ">", "Ю",
        "[", "х",
        "{", "Х",
        "]", "ъ",
        "}", "Ъ",
        ";", "ж",
        ":", "Ж",
        "'", "э",
        '"', "Э",
        "/", ".",
        "?", ","
    ))

TranslateKey(key) {
    currentLayout := GetCurrentLayout()
    if (layoutMappings.Has(currentLayout)) {
        layoutMap := layoutMappings[currentLayout]
        if (layoutMap.Has(key)) {
            return layoutMap[key]
        }
    }
    return key
}

; Shifted key handling for both single-tap modes
#HotIf g_ModifierState.singleTapShift or g_ModifierState.singleTapCaps or g_ModifierState.doubleTapCaps
; Alphabet (a-z)
vk41:: SendShiftedKey("a")  ; a
vk42:: SendShiftedKey("b")  ; b
vk43:: SendShiftedKey("c")  ; c
vk44:: SendShiftedKey("d")  ; d
vk45:: SendShiftedKey("e")  ; e
vk46:: SendShiftedKey("f")  ; f
vk47:: SendShiftedKey("g")  ; g
vk48:: SendShiftedKey("h")  ; h
vk49:: SendShiftedKey("i")  ; i
vk4A:: SendShiftedKey("j")  ; j
vk4B:: SendShiftedKey("k")  ; k
vk4C:: SendShiftedKey("l")  ; l
vk4D:: SendShiftedKey("m")  ; m
vk4E:: SendShiftedKey("n")  ; n
vk4F:: SendShiftedKey("o")  ; o
vk50:: SendShiftedKey("p")  ; p
vk51:: SendShiftedKey("q")  ; q
vk52:: SendShiftedKey("r")  ; r
vk53:: SendShiftedKey("s")  ; s
vk54:: SendShiftedKey("t")  ; t
vk55:: SendShiftedKey("u")  ; u
vk56:: SendShiftedKey("v")  ; v
vk57:: SendShiftedKey("w")  ; w
vk58:: SendShiftedKey("x")  ; x
vk59:: SendShiftedKey("y")  ; y
vk5A:: SendShiftedKey("z")  ; z

; Numbers and Symbols
vk30:: SendShiftedKey("0")  ; 0
vk31:: SendShiftedKey("1")  ; 1
vk32:: SendShiftedKey("2")  ; 2
vk33:: SendShiftedKey("3")  ; 3
vk34:: SendShiftedKey("4")  ; 4
vk35:: SendShiftedKey("5")  ; 5
vk36:: SendShiftedKey("6")  ; 6
vk37:: SendShiftedKey("7")  ; 7
vk38:: SendShiftedKey("8")  ; 8
vk39:: SendShiftedKey("9")  ; 9
vkBD:: SendShiftedKey("-")  ; -
vkBB:: SendShiftedKey("=")  ; =
vkDB:: SendShiftedKey("[")  ; [
vkDD:: SendShiftedKey("]")  ; ]
vkDC:: SendShiftedKey("\")  ; \
vkC0:: SendShiftedKey("``") ; `
vkDE:: SendShiftedKey("'")  ; '
vkBC:: SendShiftedKey(",")  ; ,
vkBE:: SendShiftedKey(".")  ; .
vkBF:: SendShiftedKey("/")  ; /

SendShiftedKey(key) {
    global g_ModifierState
    try {
        translatedKey := TranslateKey(key)

        ; Handle shift single-tap
        if (g_ModifierState.singleTapShift && !g_ModifierState.shiftSingleTapUsed) {
            if (A_TickCount - g_ModifierState.shiftTapTime > 1000) {
                g_ModifierState.singleTapShift := false
                ShowTooltip()
                SendInput(key)
                return
            }
            SendInput("+" . key)
            g_ModifierState.singleTapShift := false
            g_ModifierState.shiftSingleTapUsed := true
            ShowTooltip()
            return
        }

        ; Handle caps single-tap
        if (g_ModifierState.singleTapCaps && !g_ModifierState.capsSingleTapUsed) {
            if (A_TickCount - g_ModifierState.capsTapTime > 1000) {
                g_ModifierState.singleTapCaps := false
                ShowTooltip()
                SendInput(key)
                return
            }
            SendInput("+" . key)
            g_ModifierState.singleTapCaps := false
            g_ModifierState.capsSingleTapUsed := true
            ShowTooltip()
            return
        }

        ; Default behavior
        SendInput(key)
    } catch as err {
        ; Handle any errors
    }
}

; Cleanup hotkey for both shift and caps single-tap modes
#HotIf g_ModifierState.singleTapShift || g_ModifierState.singleTapCaps
*:: {
    global g_ModifierState
    g_ModifierState.singleTapCaps := false
    g_ModifierState.singleTapShift := false
    ShowTooltip()
}
#HotIf