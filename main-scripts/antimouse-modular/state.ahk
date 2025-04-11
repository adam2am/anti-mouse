; ==============================================================================
; state.ahk - Application State Management
; ==============================================================================

; --- Finite State Machine (FSM) ---
; Define distinct states for clarity
global State_IDLE := "IDLE"
global State_GRID_VISIBLE := "GRID_VISIBLE"
global State_CELL_SELECTED := "CELL_SELECTED" ; Transient state after 2nd key, before subgrid/move
global State_SUBGRID_STANDARD := "SUBGRID_STANDARD"
global State_SUBGRID_ULTRAFAST := "SUBGRID_ULTRAFAST"

global currentState := State_IDLE   ; Current state of the application (uses defined constants)
global stateTransitionTime := 0     ; Timestamp of the last state transition
global gridActivationInProgress := false  ; Flag to prevent double activation
global gridActivationTime := 0      ; Timestamp of last grid activation attempt

; --- CapsLock State ---
global capsLockPressedTime := 0     ; Used for double CapsLock detection (though doubleCapsThreshold is in config)

; --- Global State Map ---
; Centralized map to hold dynamic state information during grid operation.
global StateMap := Map(
    "overlays", [],             ; Array of OverlayGUI objects for each monitor
    "currentOverlay", "",       ; The OverlayGUI object for the currently active monitor
    "activeColKeys", [],        ; Array of column keys for the current layout
    "activeRowKeys", [],        ; Array of row keys for the current layout
    "firstKey", "",             ; Stores the first key pressed (column or row)
    "activeCellKey", "",        ; The key of the currently selected cell (e.g., "qj")
    "activeSubCellKey", "",     ; The key of the currently selected sub-cell (e.g., "g")
    "currentColIndex", 0,       ; Index of the currently selected column
    "currentRowIndex", 0,       ; Index of the currently selected row
    "lastSelectedRowIndex", 0,  ; Remembers the last row selected to improve flow
    "rowKeyHeldTime", 0,        ; Timestamp when row key was pressed (for Ultra-Fast mode)
    "activeRowKey", "",         ; Currently held row key (for Ultra-Fast mode)
    "inUltraFastMode", false    ; Whether Ultra-Fast Subgrid mode is active
)

; --- GUI Instances ---
; These are initialized later during grid activation but declared globally for reuse.
global highlight := ""              ; Single HighlightOverlay instance
global subGrid := ""                ; Single SubGridOverlay instance

; --- Cell Memory ---
; Maps cell keys (e.g., "qj" or "1_qj" if storePerMonitor is true) to subcell keys (e.g., "g").
; Loaded from cellMemoryFile at startup.
global cellMemory := Map()

; --- Modifier Key State (Specifically for CapsLock Handling) ---
; Tracks the state of CapsLock presses for single tap, double tap, and hold detection.
global g_ModifierState := {
    caps: false,                ; Is CapsLock currently physically pressed?
    capsFirstReleased: false,   ; Flag to track if the first press was released (for double-tap logic)
    lastCapsUpTime: 0,          ; Timestamp of the last CapsLock release
    capsPressedFirstTime: 0,    ; Timestamp of the first CapsLock press in a potential sequence
    capsPressedSecondTime: 0,   ; Timestamp of the second CapsLock press (if double-tap detected)
    inHoldMode: false           ; Is the script currently in a CapsLock "hold" mode (e.g., after double-tap or activation key)?
}

; --- Other State Variables ---
; (Add any other state-related variables here if needed)
global qmove := true ; Related to CapsLock+Q activation, might be refactored later
