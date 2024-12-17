; anti-mouse/testing stuff/RAlt state.ahk
#Requires AutoHotkey v2.0

*vk19::
{
    KeyWait "vk19"
    ToolTip "vk19 pressed."
    SetTimer RemoveToolTip, -2000
}

RemoveToolTip() {
    ToolTip
}
