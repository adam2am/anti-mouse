#Requires AutoHotkey v2.0.18+
; fix the syntax 

; idea is to make a hotkey for each api key
; based on a number and give element from the array back
; Global API key array (Remember to replace with your actual key
global gAPIKeys := ["YOUR_ACTUAL_API_KEY_HERE1", "YOUR_ACTUAL_API_KEY_HERE2", "YOUR_ACTUAL_API_KEY_HERE3"]

:*R:/\.пф(\d)::
:*R:/ga(\d)::
{
    PasteAPIKey(StrGetAt(A_ThisHotkey, StrLen(A_ThisHotkey)))
}

PasteAPIKey(apiKeyNumber) {
    global gAPIKeys

    ; Validate apiKeyNumber
    if (apiKeyNumber < 1 || apiKeyNumber > gAPIKeys.Length) {
        MsgBox "Invalid API key number: " apiKeyNumber
        return
    }

    ; Store the current clipboard content
    OldClip := A_ClipboardAll

    ; Copy the API key to the clipboard
    A_Clipboard := gAPIKeys[apiKeyNumber]

    ; Wait for the clipboard to contain data
    ClipWait 0.5
    if ErrorLevel {
        MsgBox "Error: Clipboard did not receive the key in 0.5 seconds."
        A_Clipboard := OldClip
        return
    }

    ; Send Ctrl+V to paste
    Send "^v"

    ; Restore the original clipboard content
    Sleep 50
    A_Clipboard := OldClip
}
