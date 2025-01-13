; ---- Main Version with viable updates, 0.21 in a proces  ----
; this version is opiniated, anti-modular approach
; only caps as power button, nothing else
; -- this check is about adding a double capslock as a shift, then to make tab work as expected
#Requires AutoHotkey v2.0

; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state tracking
global g_ModifierState := {
    shift: false,
    ctrl: false,
    singleTapCaps: false,
    doubleTapCaps: false,
    holdCapsShiftModeActivate: false,
    capsLastPressTime: 0,
    capsPressStartTime: 0,
    capslockToggled: false,
    capsLockReleaseCount: 0,
    capsLockPressCount: 0,
    awaitingRelease: false,
    singleTapUsed: false,
    showcaseDebug: false,
    doubleTapHeld: false  ; New state to track if double tap is being held
}

; --- ToolTip Configuration --- (rest of the tooltip code remains the same)
global g_Tooltip := {
    x: 0,
    y: 0,
    textSingleTap: "Next key shifted (Release activated)",
    textDoubleTap: "Shift mode (Double-tap)",
    textHoldMode: "Shift mode (Hold)",
    colorNormal: "White",
    colorActive: "Red",
    font: "s12 Arial"
}

;
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

;

; Modified CapsLock handler with double tap hold detection
CapsLock:: {
    global g_ModifierState
    currentTime := A_TickCount

    g_ModifierState.capsPressStartTime := currentTime
    g_ModifierState.capsLockPressCount += 1

    ; Double-tap detection (200ms window)
    if (currentTime - g_ModifierState.capsLastPressTime < 200
        && g_ModifierState.capsLockReleaseCount > 0) {
        g_ModifierState.doubleTapCaps := true
        g_ModifierState.doubleTapHeld := true  ; Set the held state
        g_ModifierState.singleTapCaps := false
        g_ModifierState.singleTapUsed := false
        ShowTooltip(g_Tooltip.textDoubleTap, 0)
    } else {
        g_ModifierState.awaitingRelease := true
    }

    g_ModifierState.capsLastPressTime := currentTime
}

; Modified CapsLock Up handler
CapsLock Up:: {
    global g_ModifierState
    currentTime := A_TickCount
    pressDuration := currentTime - g_ModifierState.capsPressStartTime

    g_ModifierState.capsLockReleaseCount += 1

    ; Handle single tap
    if (g_ModifierState.awaitingRelease && !g_ModifierState.doubleTapCaps && pressDuration < 200) {
        g_ModifierState.singleTapCaps := true
        g_ModifierState.singleTapUsed := false
        ShowTooltip(g_Tooltip.textSingleTap)
    }

    ; Handle double tap release
    if (g_ModifierState.doubleTapHeld) {
        g_ModifierState.doubleTapCaps := false
        g_ModifierState.doubleTapHeld := false
        ShowTooltip()
    }

    g_ModifierState.awaitingRelease := false

    if (g_ModifierState.holdCapsShiftModeActivate) {
        g_ModifierState.holdCapsShiftModeActivate := false
        ShowTooltip()
    }

    SetTimer(ResetCapsLockCounts, -500)
}

ResetCapsLockCounts() {
    global g_ModifierState
    g_ModifierState.capsLockPressCount := 0
    g_ModifierState.capsLockReleaseCount := 0
}
; CapsLock release handler
; CapsLock up:: {
;     global g_ModifierState
;     g_ModifierState.capsLockUpDetected := true

;     if (g_ModifierState.doubleTapActive) {
;         g_ModifierState.doubleTapActive := false
;         ShowTooltip()
;     }
; }

; ~*Space up:: {
;     g_ModifierState.capsTabAsShift := false
; }

;
; added a HotIf so it's not fucking up the regular Tab behavior
#HotIf (GetKeyState("CapsLock", "P") and not GetKeyState("Shift", "P"))
; Space:: {
;     g_ModifierState.capsTabAsShift := true ; Set the flag when either CapsLock + Tab or Shift + Tab is pressed
;     ; Important: Prevent default Tab behavior
; }

h:: {
    global g_ModifierState

    g_ModifierState.holdCapsShiftModeActivate := true
    g_ModifierState.singleTapPending := false
    ShowTooltip(g_Tooltip.textHoldMode, 0)

    ; Wait for either key release
    while (GetKeyState("CapsLock", "P") && GetKeyState("h", "P"))
        Sleep(10)

    g_ModifierState.holdCapsShiftModeActivate := false
    ShowTooltip()
}
#HotIf

;
; Context-sensitive hotkeys when modifier is pressed
#HotIf GetKeyState("CapsLock", "P") and not (g_ModifierState.singleTapCaps or g_ModifierState.doubleTapCaps or
    g_ModifierState.holdCapsShiftModeActivate)
a:: {
    static lastPressTime := 0
    currentTime := A_TickCount
    ; Double-click detection => Ctrl-A a quick All-Selection
    if (currentTime - lastPressTime < 300) {
        SendInput("^a")
        lastPressTime := 0
        return
    }
    ;
    global g_ModifierState
    g_ModifierState.shift := true
    startTime := A_TickCount
    lastPressTime := currentTime ; Update last press time for double-click detection
    KeyWait "a"
    g_ModifierState.shift := false
    ;
    ; Quick tap sends Ctrl+Shift+F11
    if (A_TickCount - startTime < 200) {
        SendEvent "^+{F11}"
    }
}
;
s:: {
    static lastPressTime := 0
    currentTime := A_TickCount
    ; Double-click detection => Ctrl S as a Quick-Save
    if (currentTime - lastPressTime < 300) {
        SendInput("^s")
        lastPressTime := 0
        return
    }
    ;
    global g_ModifierState
    g_ModifierState.ctrl := true
    startTime := A_TickCount
    lastPressTime := currentTime

    KeyWait "s"
    g_ModifierState.ctrl := false
    ;
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
0:: {
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
vk43:: SendEvent "^c" ; default Ctrl+c / vim-like yonk is regular windows undo = Ctrl+Y
vk58:: SendEvent "^x" ; x
vk56:: SendEvent "^v" ; v
vk5A:: SendEvent "^z" ; z
vk55:: SendEvent "^z" ; u > vim-like Ctrl+undo/

vk31:: SendEvent "!1"  ; 1
vk32:: SendEvent "!2"  ; 2
vk33:: SendEvent "!3"  ; 3
vk34:: SendEvent "!4"  ; 4
vk35:: SendEvent "!5"  ; 5
vk36:: SendEvent "!6"  ; 6
vk37:: SendEvent "!7"  ; 7
vk38:: SendEvent "!8"  ; 8

vk59:: SendEvent "^y" ; y
vkC0:: SendEvent "^``" ; ` - terminal like behavior
vk46:: SendEvent "!f"  ; f - For fuzzy finder- jumper
vk4D:: SendEvent "!m"  ; m - CapsLock + M now sends Alt+M - for neovim escaping to normal mode
vkBF:: {
    if not GetKeyState("s", "P") and not GetKeyState("a", "P") {
        SendEvent "{Enter}"
    }
    else if GetKeyState("s", "P") and not GetKeyState("a", "P") {
        SendEvent "^{Enter}"
    }
    else if not GetKeyState("s", "P") and GetKeyState("a", "P") {
        SendEvent "+{Enter}"
    }
    else if GetKeyState("s", "P") and GetKeyState("a", "P") {
        SendEvent "+^{Enter}"
    }
}

vkDE:: SendEvent "{Backspace}" ; '
vkDB:: SendEvent "{Delete}" ; [
vk44:: SendEvent "{Delete}" ; d
#HotIf

;
; Function to get current keyboard layout
GetCurrentLayout() {
    activeWnd := WinExist("A")
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", activeWnd, "Ptr", 0)
    layout := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    return Format("{:08X}", layout & 0xFFFF)
}
; Mapping for different layouts
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
; Function to translate key based on current layout
TranslateKey(key) {
    currentLayout := GetCurrentLayout()

    ; If layout has a mapping, try to translate
    if (layoutMappings.Has(currentLayout)) {
        layoutMap := layoutMappings[currentLayout]
        if (layoutMap.Has(key)) {
            return layoutMap[key]
        }
    }

    ; If no translation, return original key
    return key
}
; Double Caps Shift Modifier State (assume this is defined elsewhere)
#HotIf g_ModifierState.singleTapCaps or g_ModifierState.doubleTapCaps or g_ModifierState.holdCapsShiftModeActivate

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
vkC0:: SendShiftedKey("``")  ; `
vkDE:: SendShiftedKey("'")  ; '
vkBC:: SendShiftedKey(",")  ; ,
vkBE:: SendShiftedKey(".")  ; .
vkBF:: SendShiftedKey("/")  ; /

;

; Modified SendShiftedKey function to handle held double tap
SendShiftedKey(key) {
    global g_ModifierState
    try {
        translatedKey := TranslateKey(key)

        ; If in single tap mode and hasn't been used yet
        if (g_ModifierState.singleTapCaps && !g_ModifierState.singleTapUsed) {
            SendEvent("+" translatedKey)
            g_ModifierState.singleTapUsed := true ; Set it IMMEDIATELY after sending
            g_ModifierState.singleTapCaps := false ; Reset the flag here too for extra safety
            ShowTooltip()
        }
        ; If in double tap mode and being held
        else if (g_ModifierState.doubleTapCaps && g_ModifierState.doubleTapHeld) {
            SendEvent("+" translatedKey)
        }
        ; Normal key press (no modifiers)
        else {
            SendEvent(translatedKey)
        }
    } catch as err {
        ; Silently handle any sending errors
    }
}
#HotIf

; Clear single-tap mode after any key press
#HotIf g_ModifierState.singleTapCaps
*:: {
    global g_ModifierState
    g_ModifierState.singleTapCaps := false
    ShowTooltip()
}
#HotIf