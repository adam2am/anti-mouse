; ==============================================================================
; core/positioning.ahk - Cell Position Finding Logic
; ==============================================================================

; Determines the cell key (e.g., "qj") at given absolute screen coordinates (x, y).
GetCellAtPosition(x, y) {
    global StateMap, showcaseDebug ; Reference variables defined in state.ahk and config.ahk

    ; Ensure we have a valid current overlay
    if (!IsObject(StateMap['currentOverlay'])) {
        if (showcaseDebug)
            ToolTip("GetCellAtPosition: No valid current overlay")
        return ""
    }

    ; Check if the point is within the current overlay's boundaries
    if (!StateMap['currentOverlay'].ContainsPoint(x, y)) {
        if (showcaseDebug)
            ToolTip("GetCellAtPosition: Point (" x "," y ") outside overlay bounds")
        return ""
    }

    ; Iterate through cells of the current overlay to find which one contains the point
    ; Use the cells map directly from the OverlayGUI object
    for cellKey, cellData in StateMap['currentOverlay'].cells {
        if (x >= cellData.absX && x < cellData.absX + cellData.w &&
            y >= cellData.absY && y < cellData.absY + cellData.h) {
            if (showcaseDebug)
                ToolTip("GetCellAtPosition: Found cell " cellKey " at (" x "," y ")")
            return cellKey ; Return the key (e.g., "qj")
        }
    }

    if (showcaseDebug)
        ToolTip("GetCellAtPosition: No cell found at (" x "," y ")")
    return ""
}
