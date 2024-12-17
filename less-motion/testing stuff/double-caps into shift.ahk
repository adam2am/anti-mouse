; doesnt work yet, just a draft
#Requires AutoHotkey v2.0

; Initialize a global variable to track the application state
global g_state := {
    isDoubleCapsShift: false,
    lastCapsLockPressTime: 0
}

; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; --- Double-tap Caps Lock for Shift ---
~CapsLock::
{
    static lastPressTime := 0
    currentTime := A_TickCount

    if (currentTime - lastPressTime < 300) {  ; Double-tap within 300ms
        g_state.isDoubleCapsShift := true
        g_state.lastCapsLockPressTime := 0 ; Reset global last press time
        SendEvent "{Shift down}"
        ToolTip("Double-Caps Shift ON", A_ScreenWidth / 2, A_ScreenHeight / 2)
    } else {
        g_state.lastCapsLockPressTime := currentTime ; Update global last press time
    }
}

~CapsLock up::
{
    if (g_state.isDoubleCapsShift) {
        if (A_TickCount - g_state.lastCapsLockPressTime > 300) {  ; Inactivity timeout (was activated more than 300ms ago)
            SetTimer(EndDoubleCapsShift, -1000) ; Turn off after 1 sec of inactivity
        } else {
            SetTimer(EndDoubleCapsShift, -100) ; Turn off quickly if no other keys are pressed
        }
    }
}

EndDoubleCapsShift() {
    g_state.isDoubleCapsShift := false
    SendEvent "{Shift up}"
    ToolTip("Double-Caps Shift OFF", A_ScreenWidth / 2, A_ScreenHeight / 2)
    SetTimer(() => ToolTip(), -1000)
}

; ------- Handle Shifted Keys When in Double-Caps Shift Mode -------
#HotIf g_state.isDoubleCapsShift
*a:: SendEvent "{Blind}{Shift down}a{Shift up}"
*b:: SendEvent "{Blind}{Shift down}b{Shift up}"
*c:: SendEvent "{Blind}{Shift down}c{Shift up}"
*d:: SendEvent "{Blind}{Shift down}d{Shift up}"
*e:: SendEvent "{Blind}{Shift down}e{Shift up}"
*f:: SendEvent "{Blind}{Shift down}f{Shift up}"
*g:: SendEvent "{Blind}{Shift down}g{Shift up}"
*h:: SendEvent "{Blind}{Shift down}h{Shift up}"
*i:: SendEvent "{Blind}{Shift down}i{Shift up}"
*j:: SendEvent "{Blind}{Shift down}j{Shift up}"
*k:: SendEvent "{Blind}{Shift down}k{Shift up}"
*l:: SendEvent "{Blind}{Shift down}l{Shift up}"
*m:: SendEvent "{Blind}{Shift down}m{Shift up}"
*n:: SendEvent "{Blind}{Shift down}n{Shift up}"
*o:: SendEvent "{Blind}{Shift down}o{Shift up}"
*p:: SendEvent "{Blind}{Shift down}p{Shift up}"
*q:: SendEvent "{Blind}{Shift down}q{Shift up}"
*r:: SendEvent "{Blind}{Shift down}r{Shift up}"
*s:: SendEvent "{Blind}{Shift down}s{Shift up}"
*t:: SendEvent "{Blind}{Shift down}t{Shift up}"
*u:: SendEvent "{Blind}{Shift down}u{Shift up}"
*v:: SendEvent "{Blind}{Shift down}v{Shift up}"
*w:: SendEvent "{Blind}{Shift down}w{Shift up}"
*x:: SendEvent "{Blind}{Shift down}x{Shift up}"
*y:: SendEvent "{Blind}{Shift down}y{Shift up}"
*z:: SendEvent "{Blind}{Shift down}z{Shift up}"
*0:: SendEvent "{Blind}{Shift down}0{Shift up}"
*1:: SendEvent "{Blind}{Shift down}1{Shift up}"
*2:: SendEvent "{Blind}{Shift down}2{Shift up}"
*3:: SendEvent "{Blind}{Shift down}3{Shift up}"
*4:: SendEvent "{Blind}{Shift down}4{Shift up}"
*5:: SendEvent "{Blind}{Shift down}5{Shift up}"
*6:: SendEvent "{Blind}{Shift down}6{Shift up}"
*7:: SendEvent "{Blind}{Shift down}7{Shift up}"
*8:: SendEvent "{Blind}{Shift down}8{Shift up}"
*9:: SendEvent "{Blind}{Shift down}9{Shift up}"
*`:: SendEvent "{Blind}{Shift down}`{Shift up}"
*,:: SendEvent "{Blind}{Shift down},{Shift up}"
*.:: SendEvent "{Blind}{Shift down}.{Shift up}"
*/:: SendEvent "{Blind}{Shift down}/{Shift up}"
*[:: SendEvent "{Blind}{Shift down}{[}{Shift up}"
*]:: SendEvent "{Blind}{Shift down}{]}{Shift up}"
*`;:: SendEvent "{Blind}{Shift down};{Shift up}"
*':: SendEvent "{Blind}{Shift down}'{Shift up}"
*Enter:: SendEvent "{Blind}{Shift down}{Enter}{Shift up}"
*Space:: SendEvent "{Blind}{Shift down}{Space}{Shift up}"
*Backspace:: SendEvent "{Blind}{Shift down}{Backspace}{Shift up}"
*Delete:: SendEvent "{Blind}{Shift down}{Delete}{Shift up}"
*-:: SendEvent "{Blind}{Shift down}-{Shift up}"
*=:: SendEvent "{Blind}{Shift down}={Shift up}"
*+:: SendEvent "{Blind}{Shift down}+{Shift up}"
*|:: SendEvent "{Blind}{Shift down}|{Shift up}"
#HotIf