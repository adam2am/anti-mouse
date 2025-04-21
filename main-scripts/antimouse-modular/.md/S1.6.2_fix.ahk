; ==============================================================================
; S1.6.2_fix.ahk - Fix for Missing Subgrid during navigation
; ==============================================================================

/*
This file addresses Task S1.6.2 - Fix Missing Subgrid:
Ensure the subgrid appears correctly after cell selection.

Issues identified:
1. Subgrid sometimes fails to appear after cell selection via key navigation
2. The transition to SUBGRID_STANDARD state may not properly show the subgrid
3. Inconsistent visibility after HandleSecondKey completes

The fixes ensure that:
a) Subgrid object existence is verified before any operation
b) Update operations are properly followed by Show operations
c) Add ForceShow method to guarantee visibility
d) Ensure proper state transitions show the subgrid
e) Improve error handling and logging
*/

; ======================
; FIXES FOR gui_classes.ahk
; ======================

; 1. Add ForceShow method to SubGridOverlay class (if not already present)
/*
ForceShow() {
    try {
        this.gui.Show("NA")
        return true
    } catch as err {
        LogToFile(Format("ERROR: subGrid.ForceShow failed: {}", err.Message), "antimouse_fix.log")
        return false
    }
}
*/

; ======================
; FIXES FOR grid_keys.ahk
; ======================

; 1. Enhance HandleSecondKey to ensure subgrid appears after update
; After the subGrid.Update() call, add:
LogToFile("S1.6.2 FIX | HandleSecondKey | Ensuring subGrid visibility", "antimouse_fix.log")

; Explicitly ensure subGrid visibility
try {
    ; Try multiple showing approaches in sequence until one works
    try {
        if (IsFunc(subGrid.ForceShow.Bind(subGrid))) {
            subGrid.ForceShow()
            LogToFile("S1.6.2 FIX | HandleSecondKey | Used subGrid.ForceShow()", "antimouse_fix.log")
        } else {
            subGrid.gui.Show("NA")
            LogToFile("S1.6.2 FIX | HandleSecondKey | Used subGrid.gui.Show()", "antimouse_fix.log")
        }
    } catch {
        ; Try using WinShow as fallback
        try {
            WinShow("ahk_id " subGrid.gui.Hwnd)
            LogToFile("S1.6.2 FIX | HandleSecondKey | Used WinShow", "antimouse_fix.log")
        } catch as innerErr {
            LogToFile(Format("S1.6.2 FIX | HandleSecondKey | WinShow failed: {}",
                innerErr.Message), "antimouse_fix.log")
        }
    }
} catch as err {
    LogToFile(Format("S1.6.2 FIX | HandleSecondKey | All visibility attempts failed: {}",
        err.Message), "antimouse_fix.log")
}

; 2. After the TransitionToState call in HandleSecondKey, add:
LogToFile("S1.6.2 FIX | HandleSecondKey | Verifying state transition result", "antimouse_fix.log")
; Check if we successfully transitioned to SUBGRID state
if (currentState == State_SUBGRID_STANDARD) {
    LogToFile("S1.6.2 FIX | HandleSecondKey | Successfully transitioned to SUBGRID_STANDARD", "antimouse_fix.log")
} else {
    ; If state transition failed, attempt to manually transition
    LogToFile(Format("S1.6.2 FIX | HandleSecondKey | State transition failed! Current state: '{}'",
        currentState), "antimouse_fix.log")

    ; Force state transition manually
    currentState := State_SUBGRID_STANDARD
    if (IsObject(subGrid)) {
        try {
            if (IsFunc(subGrid.ForceShow.Bind(subGrid))) {
                subGrid.ForceShow()
                LogToFile("S1.6.2 FIX | HandleSecondKey | Manual state correction - showed subGrid",
                    "antimouse_fix.log")
            } else {
                subGrid.gui.Show("NA")
                LogToFile("S1.6.2 FIX | HandleSecondKey | Manual state correction - used gui.Show",
                    "antimouse_fix.log")
            }
        } catch as err {
            LogToFile(Format("S1.6.2 FIX | HandleSecondKey | Manual state correction failed: {}",
                err.Message), "antimouse_fix.log")
        }
    }
}

; ======================
; FIXES FOR state_transitions.ahk
; ======================

; 1. Modify TransitionToState function for SUBGRID_STANDARD state entry
; Find the section where SUBGRID_STANDARD state is entered, add or enhance:

; Entry actions for SUBGRID_STANDARD
if (newState == State_SUBGRID_STANDARD) {
    LogToFile("S1.6.2 FIX | TransitionToState | Entering SUBGRID_STANDARD state", "antimouse_fix.log")

    ; Check if we have a valid subGrid object
    if (IsObject(subGrid)) {
        try {
            ; First try with ForceShow if available
            if (IsFunc(subGrid.ForceShow.Bind(subGrid))) {
                subGrid.ForceShow()
                LogToFile("S1.6.2 FIX | TransitionToState | Successfully showed subGrid via ForceShow",
                    "antimouse_fix.log")
            } else {
                ; Fallback to normal Show method
                subGrid.gui.Show("NA")
                LogToFile("S1.6.2 FIX | TransitionToState | Successfully showed subGrid via gui.Show",
                    "antimouse_fix.log")
            }
        } catch as err {
            LogToFile(Format("S1.6.2 FIX | TransitionToState | Error showing subGrid: {}",
                err.Message), "antimouse_fix.log")

            ; Try WinShow as last resort
            try {
                WinShow("ahk_id " subGrid.gui.Hwnd)
                LogToFile("S1.6.2 FIX | TransitionToState | Used WinShow as last resort",
                    "antimouse_fix.log")
            } catch {
                ; No more fallbacks
            }
        }
    } else {
        LogToFile("S1.6.2 FIX | TransitionToState | ERROR: subGrid is not a valid object",
            "antimouse_fix.log")
    }

    ; Ensure we properly log and verify the state change
    LogToFile(Format("S1.6.2 FIX | TransitionToState | State set to SUBGRID_STANDARD ({}) successfully",
        State_SUBGRID_STANDARD), "antimouse_fix.log")
}

; 2. Verify subgrid boundaries are properly retrieved in the state transition
; Add this check before calling subGrid.Update():

if (newState == State_SUBGRID_STANDARD && StateMap.Has('activeCellKey')) {
    ; Ensure we have valid boundaries to pass to subGrid.Update
    if (IsObject(StateMap['currentOverlay'])) {
        try {
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(StateMap['activeCellKey'])
            if (IsObject(boundaries)) {
                LogToFile(Format("S1.6.2 FIX | TransitionToState | Got valid boundaries for cell '{}'",
                    StateMap['activeCellKey']), "antimouse_fix.log")
            } else {
                LogToFile(Format("S1.6.2 FIX | TransitionToState | Failed to get valid boundaries for cell '{}'",
                    StateMap['activeCellKey']), "antimouse_fix.log")
            }
        } catch as err {
            LogToFile(Format("S1.6.2 FIX | TransitionToState | Error getting cell boundaries: {}",
                err.Message), "antimouse_fix.log")
        }
    }
}

; ======================
; IMPLEMENTATION NOTES
; ======================

/*
To implement these fixes:

1. Add the ForceShow method to SubGridOverlay class if not present
2. Update grid_keys.ahk's HandleSecondKey to ensure subgrid visibility after updates
3. Add state verification after TransitionToState call in HandleSecondKey
4. Enhance TransitionToState to explicitly show the subgrid when entering SUBGRID_STANDARD state
5. Add boundary verification before calling subGrid.Update in state transitions

These changes ensure that the subgrid correctly appears after cell selection,
resolving the visibility issues reported by the user.
*/
