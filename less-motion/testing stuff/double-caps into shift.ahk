#Requires AutoHotkey v2.0

; Global state to track modifier
global g_ModifierState := {
    doubleCapsShift: false,
    capsLockUpDetected: false
}

; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Double-tap CapsLock detection
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
        ; Single tap
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

; Hotkeys for letters and numbers
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
{
    key := A_ThisHotkey
    SendEvent("+" key) ; Send shifted character
}
#HotIf