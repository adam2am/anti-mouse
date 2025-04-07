; ==============================================================================
; main.ahk - Main Entry Point for AntiMouse Script
; ==============================================================================

; --- Script Settings ---
#Requires AutoHotkey v2.0       ; Specify required AutoHotkey version
#SingleInstance Force           ; Ensure only one instance of the script runs
SetWorkingDir A_ScriptDir       ; Set the working directory to the script's location
CoordMode "Mouse", "Screen"     ; Use screen coordinates for mouse commands
SetCapsLockState "AlwaysOff"    ; Ensure CapsLock starts (and stays) off

; --- Include Modules ---
; Order is important: Config and State first, then Utils/Classes, then Logic/Activation/Hotkeys.
#Include %A_ScriptDir%\config.ahk         ; Global configuration variables
#Include %A_ScriptDir%\state.ahk          ; Global state variables
#Include %A_ScriptDir%\utils.ahk          ; Utility functions
#Include %A_ScriptDir%\gui_classes.ahk    ; GUI class definitions
#Include %A_ScriptDir%\memory_settings.ahk ; Settings and memory management
#Include %A_ScriptDir%\core_logic.ahk     ; Core grid functionality
#Include %A_ScriptDir%\activation.ahk     ; Grid activation logic
#Include %A_ScriptDir%\settings_gui.ahk   ; Settings GUI logic
#Include %A_ScriptDir%\hotkeys.ahk        ; Hotkey definitions
; --- project structure : -structure.md -

; Make functions globally available
global LoadSettings, LoadCellMemory, CapsLock_Q, Cleanup, ForceCloseAllGuis

; --- Initialization ---
; Load settings and cell memory at script startup
LoadSettings()
LoadCellMemory()

; Start the timer to periodically force CapsLock off
SetTimer ForceCapsLockOff, 250

; --- Optional: Initial Debug Message ---
if (showcaseDebug) {
    ToolTip("AntiMouse Script Initialized (Debug Mode ON)")
    Sleep 2000
    ToolTip()
}

; --- Persistent Script ---
; Keep the script running until explicitly exited.
; All functionality is driven by hotkeys and timers defined in the included modules.

; --- Exit Handling (Optional) ---
; You could add an ExitApp hotkey here if desired, e.g.:
; F12:: ExitApp

; ==============================================================================
; End of main.ahk
; ==============================================================================
