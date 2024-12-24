#Requires AutoHotkey v2.0
; #12m #5w #2024
; dynamic number in a hotstring detection, idea - when /ga+number typed = different api key
SendMode("Input")
global showcaseDebug := false
global gAPIKeys := ["YOUR_ACTUAL_API_KEY_HERE1",
    "YOUR_ACTUAL_API_KEY_HERE2",
    "YOUR_ACTUAL_API_KEY_HERE3"]

loop 9 {
    Hotstring(":*://ga" . A_Index, PasteAPIKey)
}

PasteAPIKey(hotstringInfo) {
    global gAPIKeys, showcaseDebug
    if showcaseDebug { ; - showing whats being passed -
        MsgBox ("//ga+number & PasteAPIKey - hit, hotstringInfo is: " hotstringInfo)
    }

    ; pasting based on a order from array
    if RegExMatch(hotstringInfo, "/\/ga(\d+)", &matches) {
        apiKeyNumber := Integer(matches[1])
        if showcaseDebug {
            MsgBox ("extracting a number: " apiKeyNumber)
        }

        if apiKeyNumber >= 1 && apiKeyNumber <= gAPIKeys.Length {
            pasteApiFromArray(apiKeyNumber)
        } else if showcaseDebug {
            MsgBox("Invalid API key number: " apiKeyNumber)
        }
    }
}

pasteApiFromArray(apiKeyNumber) { ; instead of Send = faster way with a clipboard
    global gAPIKeys
    OldClip := A_Clipboard
    A_Clipboard := gAPIKeys[apiKeyNumber]
    ClipWait 40 ; Further reduced ClipWait
    Send "^v"
    A_Clipboard := OldClip
}
