; ==============================================================================
; core_logic.ahk - Core Grid Interaction, Navigation, and State Logic (Refactored)
; ==============================================================================

; This file used to contain various functions which have now been moved to
; separate files within the 'core/' subdirectory for better organization.
; See 1main.ahk for the updated #Include directives.

; Functions moved:
; - SwitchMonitor, CycleToNextMonitor -> core/monitor.ahk
; - GetCellAtPosition -> core/positioning.ahk
; - ProcessKeyPress -> core/key_processing.ahk
; - HandleKey -> core/grid_keys.ahk
; - HandleSubGridKey, HandleUltraFastKey, HandleRowKeyRelease -> core/subgrid_keys.ahk
; - StartNewSelection -> core/state_transitions.ahk
; - TrackCursor -> core/tracking.ahk

; #Include core\state_management.ahk
; #Include core\grid_keys.ahk
; #Include core\subgrid_keys.ahk

; Extract MoveMouseToCellCenter and MoveMouseToSubCell
; Functions moved to core/mouse_movement.ahk

; --- Monitor Switching ---
; (Functions moved to core/monitor.ahk)

; --- Cell Position Finding ---
; (Function moved to core/positioning.ahk)

; --- Key Handling Logic ---
; (Function moved to core/grid_keys.ahk)

; --- Subgrid Key Handling Logic ---
; (Functions moved to core/subgrid_keys.ahk)

; --- State Transition Logic ---

; Function to start a new selection cycle
; (Function moved to core/state_transitions.ahk)

; --- Key Processing Wrapper ---
; (Function moved to core/key_processing.ahk)

; --- Row Key Release Handling (Ultra-Fast) ---
; (Function moved to core/subgrid_keys.ahk)

; --- Cursor Tracking ---
; (Function moved to core/tracking.ahk)
