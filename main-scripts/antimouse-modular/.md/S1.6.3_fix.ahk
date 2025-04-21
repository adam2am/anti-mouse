; ==============================================================================
; S1.6.3_fix.ahk - Implementation for Nearest Cell Navigation
; ==============================================================================

/*
This file addresses Task S1.6.3 - Implement Nearest Cell Navigation:
Add logic to find and navigate to the nearest cell with matching row/column when a single key is pressed.

When the user is already in a cell and presses a single key (row or column), this logic will:
1. Find the cell closest to the current cell that matches the pressed key
2. Navigate to that cell immediately
3. Update the highlight and state accordingly

This improves the user experience by allowing single-key navigation to nearby cells
rather than requiring full two-key sequences for every movement.
*/

; Function to find the nearest cell matching a given row or column key
FindNearestCell(currentCellKey, targetKey, isColKey) {
    global highlight, StateMap

    ; Log the request
    LogToFile(Format("S1.6.3 FIX | FindNearestCell | Current cell: '{}', Target key: '{}', isColKey: {}",
        currentCellKey, targetKey, isColKey), "antimouse_fix.log")

    ; Ensure we have a valid current cell
    if (currentCellKey == "" || StrLen(currentCellKey) != 2) {
        LogToFile("S1.6.3 FIX | FindNearestCell | Invalid current cell key", "antimouse_fix.log")
        return ""
    }

    ; Extract current col and row keys from currentCellKey
    currentColKey := SubStr(currentCellKey, 1, 1)
    currentRowKey := SubStr(currentCellKey, 2, 1)

    ; Get array of available keys
    colKeys := StateMap['activeColKeys']
    rowKeys := StateMap['activeRowKeys']

    ; Log keys
    LogToFile(Format("S1.6.3 FIX | FindNearestCell | Current: col='{}', row='{}', Available cols={}, rows={}",
        currentColKey, currentRowKey, colKeys.Length, rowKeys.Length), "antimouse_fix.log")

    ; Find new cell key based on the target key type
    if (isColKey) {
        ; Target is a column key, keep the same row
        newCellKey := targetKey . currentRowKey
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Moving to cell with same row: '{}'",
            newCellKey), "antimouse_fix.log")
    } else {
        ; Target is a row key, keep the same column
        newCellKey := currentColKey . targetKey
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Moving to cell with same column: '{}'",
            newCellKey), "antimouse_fix.log")
    }

    ; Verify the new cell key exists
    cellExists := false
    for _, colKey in colKeys {
        for _, rowKey in rowKeys {
            if (newCellKey == colKey . rowKey) {
                cellExists := true
                break
            }
        }
        if (cellExists)
            break
    }

    if (cellExists) {
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Found valid target cell: '{}'",
            newCellKey), "antimouse_fix.log")
        return newCellKey
    } else {
        LogToFile(Format("S1.6.3 FIX | FindNearestCell | Target cell '{}' does not exist",
            newCellKey), "antimouse_fix.log")
        return ""
    }
}

; ======================
; FIXES FOR grid_keys.ahk
; ======================

; 1. Enhance HandleKey function to detect and use nearest cell navigation
; Add this code block after the key type detection (isColKey, isRowKey) but before HandleFirstKey/HandleSecondKey calls:

if (currentState == State_GRID_VISIBLE && StateMap['activeCellKey'] != "") {
    ; User is in State_GRID_VISIBLE but already has a selected cell (hovering)
    ; Try to find nearest cell matching the pressed key

    LogToFile(Format("S1.6.3 FIX | HandleKey | Nearest cell navigation triggered | key='{}'",
        key), "antimouse_fix.log")

    ; Find the nearest matching cell
    targetCellKey := FindNearestCell(StateMap['activeCellKey'], key, isColKey)

    if (targetCellKey != "") {
        ; Valid target cell found - navigate to it
        LogToFile(Format("S1.6.3 FIX | HandleKey | Navigating from '{}' to '{}'",
            StateMap['activeCellKey'], targetCellKey), "antimouse_fix.log")

        ; Get boundaries for the target cell
        if (IsObject(StateMap['currentOverlay'])) {
            try {
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(targetCellKey)

                if (IsObject(boundaries)) {
                    ; Update active cell key
                    StateMap['activeCellKey'] := targetCellKey

                    ; Update highlight
                    if (IsObject(highlight)) {
                        try {
                            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                            LogToFile("S1.6.3 FIX | HandleKey | Successfully updated highlight", "antimouse_fix.log")

                            ; Ensure highlight is visible
                            try {
                                highlight.Show()
                                LogToFile("S1.6.3 FIX | HandleKey | Successfully showed highlight", "antimouse_fix.log"
                                )
                            } catch as e {
                                LogToFile(Format("S1.6.3 FIX | HandleKey | Error showing highlight: {}",
                                    e.Message), "antimouse_fix.log")
                            }
                        } catch as e {
                            LogToFile(Format("S1.6.3 FIX | HandleKey | Error updating highlight: {}",
                                e.Message), "antimouse_fix.log")
                        }
                    }

                    ; Move cursor to center of target cell
                    try {
                        centerX := boundaries.x + boundaries.w / 2
                        centerY := boundaries.y + boundaries.h / 2
                        MouseMove(centerX, centerY, 0)
                        LogToFile(Format("S1.6.3 FIX | HandleKey | Moved cursor to ({}, {})",
                            centerX, centerY), "antimouse_fix.log")
                    } catch as e {
                        LogToFile(Format("S1.6.3 FIX | HandleKey | Error moving mouse: {}",
                            e.Message), "antimouse_fix.log")
                    }

                    ; Restart cursor tracking
                    SetTimer(TrackCursor, 50)

                    ; Early return - we've handled the key
                    return
                } else {
                    LogToFile("S1.6.3 FIX | HandleKey | Failed to get boundaries for target cell", "antimouse_fix.log")
                }
            } catch as e {
                LogToFile(Format("S1.6.3 FIX | HandleKey | Error getting cell boundaries: {}",
                    e.Message), "antimouse_fix.log")
            }
        }
    } else {
        LogToFile("S1.6.3 FIX | HandleKey | No valid target cell found, continuing with standard key handling",
            "antimouse_fix.log")
    }
}

; ======================
; IMPLEMENTATION NOTES
; ======================

/*
To implement this fix:

1. Add the FindNearestCell helper function to determine the target cell
2. Update HandleKey in grid_keys.ahk to detect when a user is already in a cell
   and try to navigate to the nearest matching cell before standard key handling
3. Update highlight and move cursor when a match is found

This change enhances navigation by allowing single-key movement to nearby cells,
making the interface more intuitive and responsive.
*/
