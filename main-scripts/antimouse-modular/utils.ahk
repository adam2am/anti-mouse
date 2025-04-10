; ==============================================================================
; utils.ahk - General Utility Functions
; ==============================================================================

; Reference global variables defined in config.ahk
global showcaseDebug ; Reference the variable defined in config.ahk

; --- Index Validation ---
; Helper function to ensure an index is within the valid range of an array's length.
ValidateIndex(index, arrayLength) {
    if (index < 1)
        return 1
    if (index > arrayLength)
        return arrayLength
    return index
}

; --- GUI Cleanup ---
; Forcefully closes all AutoHotkey GUI windows. Used during cleanup or error recovery.
ForceCloseAllGuis() {
    try {
        DetectHiddenWindows(true) ; Include hidden windows

        ; Try closing by generic class name first
        WinClose("ahk_class AutoHotkeyGUI")
        Sleep(30) ; Give time to close

        ; Try again if some remain
        WinClose("ahk_class AutoHotkeyGUI")
        Sleep(10)

        ; Try closing specific types if known titles exist (like "SubGrid")
        WinClose("SubGrid ahk_class AutoHotkeyGUI")
        WinClose("Highlight ahk_class AutoHotkeyGUI") ; Assuming HighlightOverlay might have a title
        WinClose("Grid ahk_class AutoHotkeyGUI")

        ; Force kill any remaining AHK GUI windows by iterating through existing ones
        hwnd := WinExist("ahk_class AutoHotkeyGUI")
        while (hwnd) {
            WinKill("ahk_id " hwnd)
            Sleep(10) ; Small delay between kills
            hwnd := WinExist("ahk_class AutoHotkeyGUI") ; Check for the next one
        }

        ; Final loop as a safeguard
        loop 3 {
            hwnd := WinExist("ahk_class AutoHotkeyGUI")
            if (!hwnd)
                break ; Exit if no more windows found
            WinKill("ahk_id " hwnd)
            Sleep(10)
        }

        DetectHiddenWindows(false) ; Reset detection setting
    } catch {
        ; Silently ignore errors during forced cleanup
    }
}

; --- Type Checking ---
; Helper function to check if a value is an integer.
IsInteger(value) {
    return IsNumber(value) && Floor(value) = value
}

; Helper function that checks if a value is a number (built-in check).
IsNumber(value) {
    if value is number
        return true
    return false
}

; --- CapsLock Management ---
; Timer function to forcibly keep CapsLock turned off.
ForceCapsLockOff() {
    ; Reference to global variable from config.ahk
    global showcaseDebug
    static lastCheck := 0
    currentTime := A_TickCount

    ; Only check periodically (e.g., every 250ms) to reduce overhead
    if (currentTime - lastCheck < 250)
        return

    lastCheck := currentTime

    ; Force CapsLock off if it gets turned on somehow
    if (GetKeyState("CapsLock", "T")) { ; Check toggle state
        SetCapsLockState "AlwaysOff"
        if (showcaseDebug) ; Use global config
            ToolTip("Forcing CapsLock off")
    }
}

; --- Task 5.5: Safe Logging Mechanism ---
; Global log queue to buffer log messages before writing to file
global g_logQueue := []
global enableVerboseLogging := true  ; Making it easier to enable/disable logging globally

; Safe logging function that uses a queue instead of direct file access
LogToFile(message, filename := "antimouse_core.log") {
    ; Format with timestamp if not already formatted
    if (!InStr(message, "Timestamp:")) {
        formattedMessage := Format("Timestamp: {} | {}", A_TickCount, message)
    } else {
        formattedMessage := message
    }

    ; Add to queue
    g_logQueue.Push({ file: filename, msg: formattedMessage "`n" })
}

; Process log queue (called on a timer)
ProcessLogQueue() {
    global g_logQueue  ; Add global reference to access the log queue
    static processing := false

    ; Prevent re-entry
    if (processing || g_logQueue.Length == 0) {
        return
    }

    processing := true

    try {
        ; Take a copy of the queue and clear it
        queueCopy := g_logQueue.Clone()
        g_logQueue := []

        ; Group messages by filename
        fileGroups := Map()
        for entry in queueCopy {
            if (!fileGroups.Has(entry.file)) {
                fileGroups[entry.file] := []
            }
            fileGroups[entry.file].Push(entry.msg)
        }

        ; Write each group to its file
        for filename, messages in fileGroups {
            try {
                ; Join messages and write in one operation
                combinedMsg := ""
                for msg in messages {
                    combinedMsg .= msg
                }

                ; Use FileOpen for better control
                file := FileOpen(filename, "a", "UTF-8")
                if (IsObject(file)) {
                    file.Write(combinedMsg)
                    file.Close()
                }
            } catch as e {
                ; If we can't write to this file, add an error to the queue for the next attempt
                g_logQueue.Push({ file: "antimouse_error.log", msg: Format(
                    "Timestamp: {} | ERROR: Failed to write to {}: {}`n",
                    A_TickCount, filename, e.Message) })
            }
        }
    } catch as e {
        ; Emergency fallback logging for queue processor errors
        try {
            FileAppend(Format("Timestamp: {} | CRITICAL: Error in ProcessLogQueue: {}`n",
                A_TickCount, e.Message), "antimouse_error.log")
        } catch {
            ; Silently fail if even this fails
        }
    } finally {
        processing := false
    }
}

; --- End Task 5.5 ---
