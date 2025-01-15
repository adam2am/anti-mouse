#Requires AutoHotkey v2.0

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
    capsPressStartTime: 0,
    lastProcessedTime: 0,
    shiftLockoutActive: false,
    capsLockoutActive: false,
    ;
    shiftedKeyHerePressed1sttime: false,
    shiftedProcessBegin: false,
    navigationModeVisited: false,
    shiftedKeyPressedCount: 0,
    shiftLastShiftedKeyTime: 0,
    capsLastShiftedKeyTime: 0
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

;------------------------ keybindings area ----------------------------
;
;
;
;
;
;
; RShift:: {
;     if not GetKeyState("s", "P") and not GetKeyState("a", "P")
;         SendEvent "{Enter}"
;     else if GetKeyState("s", "P") and not GetKeyState("a", "P")
;         SendEvent "^{Enter}"
;     else if not GetKeyState("s", "P") and GetKeyState("a", "P")
;         SendEvent "+{Enter}"
;     else if GetKeyState("s", "P") and GetKeyState("a", "P")
;         SendEvent "+^{Enter}"
; }
;

#HotIf GetKeyState("LShift", "P")
*:: {
    global g_ModifierState
    ; Handle Shift cleanup
    g_ModifierState.singleTapShift := false
}

#HotIf

; --- Shift Handling ---
~LShift:: {
    global g_ModifierState
    g_ModifierState.shiftPressTime := A_TickCount
    g_ModifierState.shiftBeingHeld := true
    g_ModifierState.shiftSingleTapUsed := false
    g_ModifierState.shiftKeyProcessed := false  ; New flag to track if a key has been processed
}

;
;
~LShift Up:: {
    global g_ModifierState
    pressTime := A_TickCount - g_ModifierState.shiftPressTime

    if (pressTime < 200
        && g_ModifierState.shiftBeingHeld
        && !g_ModifierState.shiftSingleTapUsed
        && !g_ModifierState.shiftKeyProcessed) {  ; Only activate if no key was processed
        g_ModifierState.singleTapShift := true
        g_ModifierState.shiftTapTime := A_TickCount
        ShowTooltip(g_Tooltip.textSingleShiftTap)
    }
    g_ModifierState.shiftBeingHeld := false
}

;
; Modified CapsLock handler with strict tracking
CapsLock:: {
    global g_ModifierState
    currentTime := A_TickCount
    g_ModifierState.capsPressStartTime := currentTime
    g_ModifierState.capsSingleTapUsed := false
    g_ModifierState.capsKeyProcessed := false  ; New flag to track if a key has been processed

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
    g_ModifierState.navigationModeVisited := false

    if (pressDuration < 200
        && !g_ModifierState.capsSingleTapUsed
        && !g_ModifierState.capsKeyProcessed
        && !g_ModifierState.doubleTapCaps) {
        g_ModifierState.singleTapCaps := true
        g_ModifierState.capsTapTime := A_TickCount
        ShowTooltip(g_Tooltip.textSinglecapsTap)
    }

    g_ModifierState.awaitingRelease := false
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
    g_ModifierState.navigationModeVisited := true

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
    g_ModifierState.navigationModeVisited := true
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
    g_ModifierState.navigationModeVisited := true
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

vkDC:: SendEvent "{Backspace}" ; \
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
vk41::
vk42::
vk43::
vk44::
vk45::
vk46::
vk47::
vk48::
vk49::
vk4A::
vk4B::
vk4C::
vk4D::
vk4E::
vk4F::
vk50::
vk51::
vk52::
vk53::
vk54::
vk55::
vk56::
vk57::
vk58::
vk59::
vk5A::
; numbers
vk30::
vk31::
vk32::
vk33::
vk34::
vk35::
vk36::
vk37::
vk38::
vk39::
; symbols
vkBD::
vkBB::
vkDB::
vkDD::
vkDC::
vkC0::
vkDE::
vkBC::
vkBE::
vkBF::
{
    keyMap := Map(
        "vk41", "a",
        "vk42", "b",
        "vk43", "c",
        "vk44", "d",
        "vk45", "e",
        "vk46", "f",
        "vk47", "g",
        "vk48", "h",
        "vk49", "i",
        "vk4A", "j",
        "vk4B", "k",
        "vk4C", "l",
        "vk4D", "m",
        "vk4E", "n",
        "vk4F", "o",
        "vk50", "p",
        "vk51", "q",
        "vk52", "r",
        "vk53", "s",
        "vk54", "t",
        "vk55", "u",
        "vk56", "v",
        "vk57", "w",
        "vk58", "x",
        "vk59", "y",
        "vk5A", "z",
        ; numbers
        "vk30", "0",
        "vk31", "1",
        "vk32", "2",
        "vk33", "3",
        "vk34", "4",
        "vk35", "5",
        "vk36", "6",
        "vk37", "7",
        "vk38", "8",
        "vk39", "9",
        ;symbols
        "vkBD", "-",
        "vkBB", "=",
        "vkDB", "[",
        "vkDD", "]",
        "vkDC", "\",
        "vkC0", "``",
        "vkDE", "'",
        "vkBC", ",",
        "vkBE", ".",
        "vkBF", "/"
    )
    global g_ModifierState

    g_ModifierState.shiftedKeyPressedCount += 1
    SendShiftedKey(keyMap[A_ThisHotkey], g_ModifierState.shiftedKeyPressedCount)
}

;
SendShiftedKey(key, shiftedKeyPressedCount) {
    global g_ModifierState
    static lockoutDuration := 300
    currentTime := A_TickCount

    if ((shiftedKeyPressedCount == 1) and not g_ModifierState.shiftedProcessBegin) {
        ;MsgBox("shiftedKeyPressedCount == 1, got through if") == all good, getting through if

        g_ModifierState.shiftedProcessBegin := true

        ;
        ; Check if a shifted key has already been processed in this sequence 2nd time (first time via shiftedkeyPressedCount == 1)
        ; this way it's adding smoothness to typing
        if (g_ModifierState.shiftSingleTapUsed or g_ModifierState.capsSingleTapUsed) {
            SendInput(key)
            g_ModifierState.shiftedProcessBegin := false
            g_ModifierState.singleTapShift := false
            g_ModifierState.capsSingleTapUsed := false
            g_ModifierState.shiftSingleTapUsed := false
            g_ModifierState.shiftedKeyPressedCount := 0
            return
        }

        ; Process single shift tap
        if (g_ModifierState.singleTapShift) {
            SendInput("+" . key)
            g_ModifierState.shiftLastShiftedKeyTime := currentTime
            g_ModifierState.singleTapShift := false
            g_ModifierState.shiftSingleTapUsed := true
            g_ModifierState.shiftedProcessBegin := false
            ShowTooltip()
            g_ModifierState.shiftedKeyPressedCount := 0
            return
        }

        ; Process single caps tap
        if (g_ModifierState.singleTapCaps) {
            SendInput("+" . key)
            g_ModifierState.capsLastShiftedKeyTime := currentTime
            g_ModifierState.singleTapCaps := false
            g_ModifierState.capsSingleTapUsed := true
            g_ModifierState.shiftedProcessBegin := false
            ShowTooltip()
            g_ModifierState.singleTapCaps := false
            g_ModifierState.shiftedKeyPressedCount := 0
            return
        }
        g_ModifierState.shiftedProcessBegin := false

    } else {
        ; Default behavior
        SendInput(key)
        g_ModifierState.singleTapShift := false
        g_ModifierState.singleTapCaps := false
        g_ModifierState.doubleTapCaps := false
        g_ModifierState.shiftedKeyPressedCount := 0

    }
}

; Function to unlock shift single-tap mode
UnlockShiftSingleTap() {
    global g_ModifierState
    g_ModifierState.shiftSingleTapLock := false
    g_ModifierState.shiftKeyProcessed := false
    g_ModifierState.shiftSingleTapUsed := false
}
; Function to unlock caps single-tap mode
UnlockCapsSingleTap() {
    global g_ModifierState
    g_ModifierState.capsSingleTapLock := false
    g_ModifierState.capsKeyProcessed := false
    g_ModifierState.capsSingleTapUsed := false
}
; Function to reset shift state
ResetShiftState() {
    global g_ModifierState
    g_ModifierState.shiftKeyProcessed := false
    g_ModifierState.shiftSingleTapUsed := false
}
; Function to reset caps state
ResetCapsState() {
    global g_ModifierState
    g_ModifierState.capsKeyProcessed := false
    g_ModifierState.capsSingleTapUsed := false
}
; Cleanup hotkey for both shift and caps single-tap modes
; Modified cleanup hotkey with immediate state locking
; Modified cleanup hotkey for both Shift and Caps
#HotIf g_ModifierState.singleTapShift || g_ModifierState.singleTapCaps
*:: {
    global g_ModifierState
    ; Handle Shift cleanup
    if (g_ModifierState.singleTapShift && !g_ModifierState.shiftKeyProcessed) {
        g_ModifierState.shiftKeyProcessed := true
        g_ModifierState.singleTapShift := false
        g_ModifierState.shiftSingleTapUsed := true
    }
    ; Handle Caps cleanup
    if (g_ModifierState.singleTapCaps && !g_ModifierState.capsKeyProcessed) {
        g_ModifierState.capsKeyProcessed := true
        g_ModifierState.singleTapCaps := false
        g_ModifierState.capsSingleTapUsed := true
    }
    ShowTooltip()
}
#HotIf