; anti-mouse/testing stuff/RAlt state.ahk
; checking custom button being pressed
; CapsLock just to verify the state of a ToolTip if it's on in general
#Requires AutoHotkey v2.0

CapsLock::
*vk19::
{
    KeyWait "vk19"
    ToolTip "vk19 pressed."
    SetTimer RemoveToolTip, -2000
}

RemoveToolTip() {
    ToolTip
}
