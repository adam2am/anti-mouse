#Requires AutoHotkey v2.0
; dynamic number in a hotstring detection.ahk
; idea - when /ga(*number) typed = different message boxes. /ga1 or /ga2 or whatever
; I want to make detect insta /ga+number so its instantly replacing as soon as number detected,
; Works, but feels like manually adding diff scenarios (:/ga1: :/ga2: etc) is faster anyway, idk

; Potential methods
; 1 vers - Loop + A_Index and Function
SendMode("Input")

; Dynamic Number Hotstring Detection with Instant Replacement
loop 9 {
    Hotstring(":*B0:ga" . A_Index, ShowNumberMessage) ; B0 option to remove backspacing
}

ShowNumberMessage(endingChar) {
    ; Extract the number from the hotstring trigger
    numberHere := SubStr(A_ThisHotkey, 4) ; random things
    MsgBox("You typed /ga" numberHere "! The number is " numberHere ".")
}

;
;
; 2 vers - InputHook
:*:/ga::
{
    input := InputHook("L3 T2")
    input.Start()
    input.Wait()

    if RegExMatch(input.Input, "(\d+)", &match) {
        MsgBox("You entered number: " match[1])
    }
}

;
;
; 3 vers
:X:/ga::
{
    global
    MsgBox("Hotstring /ga triggered!")
    ihUserInput := InputHook("V T0 L1"),
    ihUserInput.Start(),
    ihUserInput.Wait(),
    UserInput := ihUserInput.Input
    MsgBox("Input captured: " UserInput)
    if isNumber(UserInput) {
        SendInput("{BS}" . StrLen("/ga" . UserInput))
        if (UserInput = 1)
            MsgBox("Message for number 1")
        else if (UserInput = 2)
            MsgBox("Message for number 2")
        else
            MsgBox("Default message for number " UserInput)
    }
    return
}
