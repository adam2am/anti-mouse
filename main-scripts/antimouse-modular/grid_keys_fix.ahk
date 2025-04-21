; ==========================================================================
; FIXED VERSION OF GRID_KEYS.AHK PROBLEM AREA
; ==========================================================================
; This file contains a fixed version of the problematic code in HandleSecondKey
; Copy and paste the sections below to replace the corresponding parts in
; main-scripts/antimouse-modular/core/grid_keys.ahk
; ==========================================================================

; ----------------------------------------------------------------------
; REPLACEMENT FOR THE SECTION STARTING WITH:
; "if (IsObject(StateMap['currentOverlay'])) {"
; ----------------------------------------------------------------------

if (IsObject(StateMap['currentOverlay'])) {
    ; Get boundaries for the target cell key
    boundaries := StateMap['currentOverlay'].GetCellBoundaries(targetCellKey)

    ; Check if we have valid boundaries
    if (IsObject(boundaries)) {
        LogToFile(Format("5.13.1 DEBUG | HandleSecondKey - Got boundaries for '{}': x={}, y={}, w={}, h={}",
            targetCellKey, boundaries.x, boundaries.y, boundaries.w, boundaries.h), "antimouse_fix.log")

        ; === UPDATE HIGHLIGHT ===
        if (IsObject(highlight)) {
            LogToFile("S1.6.1 FIX | Updating highlight for cell: " targetCellKey, "antimouse_fix.log")
            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            highlight.ForceShow()
        } else {
            LogToFile("S1.6.1 FIX | highlight object not valid", "antimouse_fix.log")
        }

        ; === UPDATE SUBGRID ===
        if (IsObject(subGrid)) {
            LogToFile("S1.6.2 FIX | Updating subgrid for cell: " targetCellKey, "antimouse_fix.log")
            subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            subGrid.ForceShow()
            WinSetAlwaysOnTop(true, "ahk_id " subGrid.gui.Hwnd)

            ; Call TransitionToState for reliable subgrid visibility
            TransitionToState(State_SUBGRID_STANDARD)
            LogToFile("S1.6.2 FIX | Subgrid update complete", "antimouse_fix.log")
        } else {
            LogToFile("S1.6.2 FIX | subGrid object not valid", "antimouse_fix.log")
        }

        ; === MOVE MOUSE TO CELL CENTER ===
        LogToFile("S1.6.3 FIX | Moving mouse to center of cell: " targetCellKey, "antimouse_fix.log")
        centerX := boundaries.x + (boundaries.w // 2)
        centerY := boundaries.y + (boundaries.h // 2)
        MouseMove(centerX, centerY, 0)

        ; Log mouse position for debugging
        MouseGetPos(&afterX, &afterY)
        LogToFile(Format("S1.6.3 FIX | Mouse position after move: x={}, y={}", afterX, afterY),
        "antimouse_fix.log")
    } else {
        LogToFile("S1.6.3 FIX | Failed to get boundaries for cell: " targetCellKey, "antimouse_fix.log")
    }
} else {
    LogToFile("S1.6.3 FIX | currentOverlay is not a valid object", "antimouse_fix.log")
}
