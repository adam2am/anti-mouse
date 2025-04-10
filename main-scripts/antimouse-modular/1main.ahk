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
; #Include %A_ScriptDir%\core_logic.ahk     ; Core grid functionality (REMOVED - Refactored into core/)
; --- Core Logic Modules ---
#Include %A_ScriptDir%\core\monitor.ahk          ; Monitor switching
#Include %A_ScriptDir%\core\positioning.ahk      ; Cell position finding
#Include %A_ScriptDir%\core\key_processing.ahk   ; Key press routing
#Include %A_ScriptDir%\core\grid_keys.ahk        ; Main grid key handling
#Include %A_ScriptDir%\core\subgrid_keys.ahk     ; Subgrid & ultra-fast key handling
#Include %A_ScriptDir%\core\state_transitions.ahk ; State transition functions (StartNewSelection)
#Include %A_ScriptDir%\core\tracking.ahk         ; Cursor tracking and highlight logic
; --- End Core Logic Modules ---
#Include %A_ScriptDir%\activation.ahk     ; Grid activation logic
#Include %A_ScriptDir%\settings_gui.ahk   ; Settings GUI logic
#Include %A_ScriptDir%\hotkeys.ahk        ; Hotkey definitions
; --- project structure : -structure.md -

; Make functions globally available
; Declare layout-specific key arrays globally
global LoadSettings, LoadCellMemory, CapsLock_Q, Cleanup, ForceCloseAllGuis
global activeColKeys, activeRowKeys
; Export grid key handling functions for global use
global HandleKey, HandleFirstKey, HandleSecondKey, StartNewSelection, ProcessStandardSubgridKey, HandleUltraFastKey,
    GridValidateIndex

; ==============================================================================
; Global Variables & Initialization
; ==============================================================================
; REMOVED: global g_logQueue := [] ; Buffered logger queue - Now defined in utils.ahk

; Start the log processing timer - Uses the implementation from utils.ahk
SetTimer(ProcessLogQueue, 300) ; Process queue every 300ms

; REMOVED: Old ProcessLogQueue implementation that's now in utils.ahk

; --- Settings & Configuration ---
#Include config.ahk

; --- Initialization ---
; Load settings and cell memory at script startup
LoadSettings()

; Set active key arrays based on the loaded layout
; Check if selectedLayout exists in layoutConfigs, default to layout 1 if not
if !layoutConfigs.Has(selectedLayout) {
    if (showcaseDebug) {
        ToolTip("Warning: selectedLayout '" selectedLayout "' not found in layoutConfigs. Defaulting to layout 1.")
        Sleep 3000
        ToolTip()
    }
    selectedLayout := 1 ; Fallback to a default layout ID
}
activeColKeys := layoutConfigs[selectedLayout].Get("colKeys")
activeRowKeys := layoutConfigs[selectedLayout].Get("rowKeys")

LoadCellMemory()

; Start the timer to periodically force CapsLock off
SetTimer ForceCapsLockOff, 250

; --- Optional: Initial Debug Message ---
if (showcaseDebug) {
    ToolTip("AntiMouse Script Initialized (Debug Mode ON)")
    Sleep 2000
    ToolTip()
}

; --- MAIN Execution START ---
Persistent() ; Keep the script running

; --- Exit Handling (Optional) ---
; You could add an ExitApp hotkey here if desired, e.g.:
; F12:: ExitApp

; ==============================================================================
; End of main.ahk
; ==============================================================================
