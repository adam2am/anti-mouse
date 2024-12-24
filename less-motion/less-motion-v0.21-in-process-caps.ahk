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
    capsLockUpDetected: false,
    capsTabAsShift: false,
    showcaseDebug: false,
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

; Function to toggle CapsLock and update tooltip to show we have a Caps "ON"
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
            ; ToolTip("Double-Caps Shift ON", A_ScreenWidth / 2, A_ScreenHeight / 2)
            ; SetTimer(() => ToolTip(), -1000)
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
        ; ToolTip("Double-Caps Shift OFF", A_ScreenWidth / 2, A_ScreenHeight / 2)
        ; SetTimer(() => ToolTip(), -1000)
    }
}

; added a HotIf so it's not fucking up the regular Tab behavior
#HotIf GetKeyState("CapsLock", "P") and not g_ModifierState.doubleCapsShift and not GetKeyState("Alt", "P")
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
#HotIf

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

vk43:: SendEvent "^c" ; default Ctrl+c / vim-like yonk is regular windows undo = Ctrl+Y
vk58:: SendEvent "^x" ; x
vk56:: SendEvent "^v" ; v
vk5A:: SendEvent "^z" ; z
vk55:: SendEvent "^z" ; vim-like Ctrl+u
vk59:: SendEvent "^y" ; y
vkC0:: SendEvent "^``" ; ` - terminal like behavior

vk46:: SendEvent "!f"  ; f - For fuzzy finder- jumper
vk4D:: SendEvent "!m"  ; m - CapsLock + M now sends Alt+M - for neovim escaping to normal mode

vkBF:: SendEvent "{Enter}" ; /
vkDE:: SendEvent "{Backspace}" ; '
vkDB:: SendEvent "{Delete}" ; [
vk44:: SendEvent "{Delete}" ; d

#HotIf

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
    )
)

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
#HotIf g_ModifierState.doubleCapsShift

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

; Function to send shifted key with layout translation
SendShiftedKey(key) {
    try {
        ; Translate the key first
        translatedKey := TranslateKey(key)
        ; Send the shifted version of the translated key
        SendEvent("+" translatedKey)
    } catch as err {
        ; Silently handle any sending errors
    }
}
