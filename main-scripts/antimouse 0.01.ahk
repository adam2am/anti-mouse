#Requires AutoHotkey v2.0
SetCapsLockState("AlwaysOff")
CoordMode "Mouse", "Screen" ; Ensure mouse coordinates are relative to the virtual screen

global showcaseDebug := false ; Set to true to enable debug tooltips, delays, and border colors
global selectedLayout := 1 ; 1: User QWERTY/ASDF, 2: Home Row ASDF/JKL;, 3: WASD/QWER
global defaultTransparency := 180 ; Default transparency level (0-255, where 255 is opaque)
global highlightColor := "33AAFF" ; Color for highlighting selected cells
global directNavEnabled := true ; Enable direct navigation between cells using arrow keys

; Define Layout Configurations
global layoutConfigs := Map(
    1, Map( ; User's 10x10 QWERTY/ASDF layout
        "cols", 10,
        "rows", 10,
        "colKeys", ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        "rowKeys", ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"]
    ),
    2, Map( ; Roo's 4x4 Home Row ASDF/JKL; layout
        "cols", 4,
        "rows", 4,
        "colKeys", ["a", "s", "d", "f"],
        "rowKeys", ["j", "k", "l", ";"]
    ),
    3, Map( ; Roo's 4x4 WASD/QWER layout (Alternative)
        "cols", 4,
        "rows", 4,
        "colKeys", ["q", "w", "e", "r"],
        "rowKeys", ["a", "s", "d", "f"]
    )
)

; Define Sub-Grid Keys (Standard numbers 7-9, 4-6, 1-3)
global subGridKeys := [
    "7", "8", "9",
    "4", "5", "6",
    "1", "2", "3"
]
global subGridRows := 3
global subGridCols := 3

; ==============================================================================
; Highlight Overlay Class (Separate Window)
; ==============================================================================
class HighlightOverlay {
    __New(cellX, cellY, cellWidth, cellHeight) {
        ; Create a new separate window for the highlight
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this.gui.BackColor := highlightColor ; Use the global highlight color
        this.width := cellWidth
        this.height := cellHeight
        this.x := cellX
        this.y := cellY

        ; Make the interior transparent (just show a border)
        borderSize := 3
        interiorColor := "000000" ; Black interior that we'll make transparent

        ; Create interior rectangle that we'll make transparent
        this.gui.Add("Progress",
            "x" . borderSize . " y" . borderSize .
            " w" . (this.width - borderSize * 2) .
            " h" . (this.height - borderSize * 2) .
            " Background" . interiorColor)

        ; Make the center transparent, leaving just the border visible
        WinSetTransColor(interiorColor . " 255", this.gui)
    }

    Show() {
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", this.x, this.y, this.width, this.height))
    }

    Hide() {
        this.gui.Hide()
    }

    Destroy() {
        this.gui.Destroy()
    }
}

; ==============================================================================
; Row Overlay Class (Separate Window for each row)
; ==============================================================================
class RowOverlay {
    __New(monitorIndex, rowIndex, rowKey, left, top, width, rowHeight, colKeys, borderColor) {
        ; Create a new separate window for this row
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08")
        this.gui.BackColor := "000000" ; Black background

        ; Store dimensions
        this.width := width
        this.height := rowHeight
        this.x := left
        this.y := top
        this.rowKey := rowKey
        this.rowIndex := rowIndex
        this.monitorIndex := monitorIndex

        ; Set font size based on cell dimensions
        cellWidth := width // colKeys.Length
        fontSize := Max(4, Min(cellWidth, rowHeight) // 4)
        this.gui.SetFont("s" fontSize, "Arial")

        ; Add row border lines
        borderThickness := 1
        this.gui.Add("Progress", "x0 y0 w" this.width " h" borderThickness " Background" borderColor)
        this.gui.Add("Progress", "x0 y" (this.height - borderThickness) " w" this.width " h" borderThickness " Background" borderColor
        )

        ; Add cells within this row
        cellX := 0
        for colIndex, colKey in colKeys {
            ; Add cell label
            cellWidth := width // colKeys.Length
            cellKey := colKey . rowKey

            this.gui.Add("Text",
                "x" cellX " y0 w" cellWidth " h" this.height
                " Center +0x200 BackgroundTrans c" borderColor,
                monitorIndex ":" cellKey)

            ; Add vertical cell divider (except for first column)
            if (colIndex > 1) {
                this.gui.Add("Progress", "x" cellX " y0 w" borderThickness " h" this.height " Background" borderColor)
            }

            cellX += cellWidth
        }

        ; Make the window semi-transparent
        this.transparency := defaultTransparency
        WinSetTransColor("000000 " this.transparency, this.gui)
    }

    Show() {
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", this.x, this.y, this.width, this.height))
        WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
    }

    Hide() {
        this.gui.Hide()
    }

    Destroy() {
        this.gui.Destroy()
    }
}

; ==============================================================================
; Grid Overlay Class (Single window per monitor)
; ==============================================================================
class GridOverlay {
    __New(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys) {
        ; Create a single window for the entire grid
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08")
        this.gui.BackColor := "000000" ; Black background

        ; Store dimensions
        this.width := Right - Left
        this.height := Bottom - Top
        this.x := Left
        this.y := Top
        this.monitorIndex := monitorIndex

        ; Calculate cell dimensions
        this.cols := colKeys.Length
        this.rows := rowKeys.Length
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows

        ; Store keys for reference
        this.colKeys := colKeys
        this.rowKeys := rowKeys

        ; Prepare cell map
        this.cells := Map()

        ; Set reasonable font size
        fontSize := Max(8, Min(this.cellWidth, this.cellHeight) // 6)
        this.gui.SetFont("s" fontSize, "Arial")

        ; Choose colors
        this.borderColor := showcaseDebug ? "FF0000" : "444444"
        this.textColor := showcaseDebug ? "FF0000" : "FFFFFF"

        ; Add grid labels and minimal borders
        this.CreateGrid()

        ; Set transparency
        this.transparency := defaultTransparency
        WinSetTransColor("000000 " this.transparency, this.gui)
    }

    CreateGrid() {
        ; Use minimal drawing operations for speed
        borderThickness := 1

        ; Draw the cell labels and necessary borders only
        for colIndex, colKey in this.colKeys {
            for rowIndex, rowKey in this.rowKeys {
                cellKey := colKey . rowKey
                cellX := (colIndex - 1) * this.cellWidth
                cellY := (rowIndex - 1) * this.cellHeight

                ; Store cell information
                this.cells[cellKey] := {
                    x: cellX,
                    y: cellY,
                    w: this.cellWidth,
                    h: this.cellHeight,
                    absX: this.x + cellX,
                    absY: this.y + cellY
                }

                ; Add cell label - center both horizontally and vertically
                this.gui.Add("Text",
                    "x" cellX " y" cellY " w" this.cellWidth " h" this.cellHeight
                    " +0x200 Center BackgroundTrans c" this.textColor,
                    cellKey)
            }
        }

        ; Add minimal borders - just the outer border
        this.gui.Add("Progress", "x0 y0 w" this.width " h" borderThickness " Background" this.borderColor)
        this.gui.Add("Progress", "x0 y" (this.height - borderThickness) " w" this.width " h" borderThickness " Background" this
        .borderColor)
        this.gui.Add("Progress", "x0 y0 w" borderThickness " h" this.height " Background" this.borderColor)
        this.gui.Add("Progress", "x" (this.width - borderThickness) " y0 w" borderThickness " h" this.height " Background" this
        .borderColor)

        ; Add column dividers (vertical lines)
        for colIndex, colKey in this.colKeys {
            if (colIndex > 1) {
                cellX := (colIndex - 1) * this.cellWidth
                this.gui.Add("Progress", "x" cellX " y0 w" borderThickness " h" this.height " Background" this.borderColor
                )
            }
        }

        ; Add row dividers (horizontal lines)
        for rowIndex, rowKey in this.rowKeys {
            if (rowIndex > 1) {
                cellY := (rowIndex - 1) * this.cellHeight
                this.gui.Add("Progress", "x0 y" cellY " w" this.width " h" borderThickness " Background" this.borderColor
                )
            }
        }
    }

    Show() {
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", this.x, this.y, this.width, this.height))
        WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
    }

    Hide() {
        this.gui.Hide()
    }

    Destroy() {
        this.gui.Destroy()
    }

    GetCellBoundaries(cellKey) {
        if this.cells.Has(cellKey) {
            cell := this.cells[cellKey]
            return { x: this.x + cell.x, y: this.y + cell.y, w: cell.w, h: cell.h }
        }
        return false
    }

    ContainsPoint(x, y) {
        return (x >= this.x && x < this.x + this.width &&
            y >= this.y && y < this.y + this.height)
    }
}

; ==============================================================================
; Main Grid Overlay Class (Redesigned for maximum performance)
; ==============================================================================
class OverlayGUI {
    __New(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys) {
        ; Initialize properties
        this.width := Right - Left
        this.height := Bottom - Top
        this.monitorIndex := monitorIndex
        this.Left := Left
        this.Top := Top
        this.Right := Right
        this.Bottom := Bottom

        this.colKeys := colKeys
        this.rowKeys := rowKeys
        this.cols := this.colKeys.Length
        this.rows := this.rowKeys.Length
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows

        ; Create single grid overlay for this monitor
        this.gridOverlay := GridOverlay(
            monitorIndex,
            Left,
            Top,
            Right,
            Bottom,
            colKeys,
            rowKeys
        )

        ; We're reusing the cells map from the gridOverlay
        this.cells := this.gridOverlay.cells
    }

    Show() {
        ; Show the grid
        this.gridOverlay.Show()
    }

    Hide() {
        this.gridOverlay.Hide()
    }

    GetCellBoundaries(cellKey) {
        return this.gridOverlay.GetCellBoundaries(cellKey)
    }

    ContainsPoint(x, y) {
        return (x >= this.Left && x < this.Right && y >= this.Top && y < this.Bottom)
    }

    ShowSubGrid(cellKey) {
        ; We'll handle this through the SubGridOverlay class directly
    }

    HideSubGrid() {
        ; We'll handle this through the SubGridOverlay class directly
    }
}

; ==============================================================================
; Sub Grid Overlay Class (Separate Window)
; ==============================================================================
class SubGridOverlay {
    __New(cellX, cellY, cellWidth, cellHeight) {
        ; Create a new separate window for the sub-grid
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08")
        this.gui.BackColor := "222222" ; Slightly different color than main grid

        ; Store dimensions
        this.width := cellWidth
        this.height := cellHeight
        this.x := cellX
        this.y := cellY

        ; Calculate sub-cell dimensions
        this.subCellWidth := this.width // subGridCols
        this.subCellHeight := this.height // subGridRows

        ; Set font size based on cell dimensions
        subGridFontSize := Max(4, Min(this.subCellWidth, this.subCellHeight) // 3)
        textColor := showcaseDebug ? "00FFFF" : "FFFF00"
        this.gui.SetFont("s" subGridFontSize, "Arial")

        ; Add number labels (1-9)
        this.controls := Map()
        keyIndex := 0

        ; Add thin border around the entire sub-grid
        borderColor := showcaseDebug ? "FF0000" : "444444"
        borderThickness := 1
        this.gui.Add("Progress", "x0 y0 w" this.width " h" borderThickness " Background" borderColor)
        this.gui.Add("Progress", "x0 y" (this.height - borderThickness) " w" this.width " h" borderThickness " Background" borderColor
        )
        this.gui.Add("Progress", "x0 y0 w" borderThickness " h" this.height " Background" borderColor)
        this.gui.Add("Progress", "x" (this.width - borderThickness) " y0 w" borderThickness " h" this.height " Background" borderColor
        )

        loop subGridRows {
            row := A_Index - 1
            loop subGridCols {
                col := A_Index - 1
                if (keyIndex >= subGridKeys.Length) {
                    break
                }

                subX := col * this.subCellWidth
                subY := row * this.subCellHeight
                subKey := subGridKeys[keyIndex + 1]

                this.gui.Add("Text",
                    "x" subX " y" subY " w" this.subCellWidth " h" this.subCellHeight
                    " Center BackgroundTrans c" textColor,
                    StrReplace(subKey, "Numpad", ""))

                keyIndex += 1
            }
            if (keyIndex >= subGridKeys.Length) {
                break
            }
        }

        ; Make the window semi-transparent
        this.transparency := defaultTransparency + 20 ; Slightly more opaque than main grid
        WinSetTransColor("222222 " this.transparency, this.gui)
    }

    Show() {
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", this.x, this.y, this.width, this.height))
        WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
    }

    Hide() {
        this.gui.Hide()
    }

    Destroy() {
        this.gui.Destroy()
    }

    GetTargetCoordinates(subKey) {
        ; Find the index of the key in subGridKeys
        subKeyIndex := -1
        for index, key in subGridKeys {
            if (key = subKey) {
                subKeyIndex := index - 1 ; Get 0-based index
                break
            }
        }
        if (subKeyIndex = -1) {
            return false
        }

        ; Calculate row and column
        subRow := subKeyIndex // subGridCols
        subCol := Mod(subKeyIndex, subGridCols)

        ; Calculate center position within the sub-cell
        targetX := this.x + (subCol * this.subCellWidth) + (this.subCellWidth // 2)
        targetY := this.y + (subRow * this.subCellHeight) + (this.subCellHeight // 2)

        return { x: targetX, y: targetY }
    }
}

; ==============================================================================
; Global State Management
; ==============================================================================
class State {
    static overlays := []
    static isVisible := false ; Are main grids visible?
    static firstKey := ""
    static currentOverlay := ""
    static activeColKeys := []
    static activeRowKeys := []
    static subGridActive := false ; Flag for sub-grid input stage
    static activeCellKey := "" ; Key of the cell where sub-grid is active (e.g., "es")
    static activeSubCellKey := "" ; Numpad key of the last selected sub-cell
    static subGridOverlay := "" ; Reference to the current SubGridOverlay object
    static dragActive := false ; Flag for drag-and-drop operation
    static currentHighlight := "" ; Reference to the current highlight overlay
    static highlightedCellKey := "" ; Key of the currently highlighted cell (to prevent flickering)
    static statusBar := "" ; Reference to the status bar
    static currentColIndex := 0 ; Current column index for direct navigation
    static currentRowIndex := 0 ; Current row index for direct navigation
    static lastSelectedRowIndex := 0 ; Last successfully selected row index
}

; ==============================================================================
; Global Helper Functions (Defined before use in hotkeys)
; ==============================================================================

; Function to clean up highlights - completely rewritten to use the new HighlightOverlay
CleanupHighlight() {
    if (IsObject(State.currentHighlight)) {
        try {
            State.currentHighlight.Destroy()
        } catch {
            ; Silently ignore destruction errors
        }
        State.currentHighlight := ""
        State.highlightedCellKey := "" ; Also reset the tracked cell
    }
}

; Modified HighlightCell to check if we're already highlighting the same cell
HighlightCell(cellKey, boundaries) {
    if (!IsObject(boundaries)) {
        return
    }

    ; If the cell is already highlighted, don't recreate the highlight
    if (cellKey = State.highlightedCellKey && IsObject(State.currentHighlight)) {
        return
    }

    ; Always ensure previous highlight is gone FIRST
    CleanupHighlight()

    ; Create a new highlight overlay for this cell
    try {
        State.currentHighlight := HighlightOverlay(
            boundaries.x, boundaries.y,
            boundaries.w, boundaries.h
        )
        State.currentHighlight.Show()
        State.highlightedCellKey := cellKey ; Remember which cell we're highlighting
    } catch as e {
        if (showcaseDebug) {
            ToolTip("Highlight error: " . e.Message)
            Sleep 1500
            ToolTip()
        }
        State.highlightedCellKey := "" ; Clear the tracked cell on error
    }
}

Cleanup() {
    if (IsObject(State.subGridOverlay)) {
        State.subGridOverlay.Destroy() ; Destroy the separate sub-grid window if it exists
        State.subGridOverlay := ""
    }

    ; Clean up highlight if it exists
    CleanupHighlight()

    for overlay in State.overlays {
        try {
            overlay.Hide() ; Hides the grid overlay
        } catch {
            ; Silently ignore any errors
        }
    }

    ; Remove status bar - we're not using it anymore
    if (IsObject(State.statusBar)) {
        State.statusBar.Hide()
        State.statusBar := ""
    }

    State.isVisible := false
    State.subGridActive := false
    State.firstKey := ""
    State.currentOverlay := ""
    State.activeColKeys := []
    State.activeRowKeys := []
    State.activeCellKey := ""
    State.activeSubCellKey := ""
    State.dragActive := false
    State.currentColIndex := 0
    State.currentRowIndex := 0
    State.lastSelectedRowIndex := 0 ; Reset the last selected row index

    ToolTip() ; Clear tooltip
    SetTimer(TrackCursor, 0)
}

CancelSubGridMode() {
    if (State.subGridActive) {
        if (IsObject(State.subGridOverlay)) {
            State.subGridOverlay.Destroy() ; Destroy the separate sub-grid window
            State.subGridOverlay := ""
        }

        ; Clean up highlight borders if they exist
        CleanupHighlight()

        State.subGridActive := false
        State.activeCellKey := ""
        State.activeSubCellKey := ""
        State.firstKey := "" ; Reset key sequence
        State.isVisible := true ; Return to main grid visibility state
        ToolTip() ; Clear sub-grid tooltip
    }
}

SwitchMonitor(monitorNum) {
    if (monitorNum > State.overlays.Length) {
        return
    }

    CancelSubGridMode() ; Cancel sub-grid if active before switching

    if (!State.isVisible) { ; Ensure overlays are visible if we cancelled sub-grid
        for overlay in State.overlays {
            overlay.Show()
        }
        State.isVisible := true
    }

    newOverlay := State.overlays[monitorNum]
    if (newOverlay && State.currentOverlay !== newOverlay) {
        State.currentOverlay := newOverlay
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        if (showcaseDebug) {
            ToolTip("Switching to Monitor Index: " . newOverlay.monitorIndex . ". Target Coords: X=" . centerX . " Y=" .
                centerY, , , 2)
            Sleep 1500
            ToolTip(, , , 2)
        }
        MouseMove(centerX, centerY, 0)
    } else {
        ToolTip("Already on Monitor " . (newOverlay ? newOverlay.monitorIndex : "None"), 100, 100)
        Sleep 1000
        ToolTip()
    }
}

; Function to determine which cell contains a specific screen position
GetCellAtPosition(x, y) {
    if (!IsObject(State.currentOverlay)) {
        return ""
    }

    ; Check if position is within the overlay
    if (!State.currentOverlay.ContainsPoint(x, y)) {
        return ""
    }

    ; Check each cell in the overlay
    for colKey in State.activeColKeys {
        for rowKey in State.activeRowKeys {
            cellKey := colKey . rowKey
            boundaries := State.currentOverlay.GetCellBoundaries(cellKey)

            if (IsObject(boundaries)) {
                ; Check if position is within this cell
                if (x >= boundaries.x && x < boundaries.x + boundaries.w &&
                    y >= boundaries.y && y < boundaries.y + boundaries.h) {
                    return cellKey
                }
            }
        }
    }

    return "" ; No cell found at this position
}

; Update HandleKey to implement cell magnetization
HandleKey(key, activateSubGrid := false) {
    ; Called only when State.isVisible is true and State.subGridActive is false
    if (!IsObject(State.currentOverlay)) {
        return
    }

    ; Get currently active cell column and row keys (if any)
    if (State.highlightedCellKey != "") {
        currentColKey := SubStr(State.highlightedCellKey, 1, 1)
        currentRowKey := SubStr(State.highlightedCellKey, 2, 1)

        ; If the pressed key matches either the column or row of the current cell, do nothing
        if (key = currentColKey || key = currentRowKey) {
            ; Completely ignore this keypress - do absolutely nothing
            return
        }
    }

    ; Only clean up highlights if we're moving to a different cell
    ; We'll check this in each specific case below instead of doing it globally

    ; Check if the key is a valid column key
    isValidColKey := false
    colIndex := 0
    for i, colKey in State.activeColKeys {
        if (key = colKey) {
            isValidColKey := true
            colIndex := i
            break
        }
    }

    ; Check if the key is a valid row key
    isValidRowKey := false
    rowIndex := 0
    for i, rowKey in State.activeRowKeys {
        if (key = rowKey) {
            isValidRowKey := true
            rowIndex := i
            break
        }
    }

    ; Determine cell to select based on input
    cellKey := ""
    boundaries := ""

    ; If we have a first key already, check what kind of key was pressed
    if (State.firstKey != "") {
        if (isValidRowKey) {
            ; Process as second key (row)
            State.currentRowIndex := rowIndex
            State.lastSelectedRowIndex := rowIndex ; Remember this row for future column switches
            cellKey := State.firstKey . key
            boundaries := State.currentOverlay.GetCellBoundaries(cellKey)
            ; Highlight creation happens below in common code
        } else if (isValidColKey) {
            ; User pressed another column key - switch to the new column
            State.currentColIndex := colIndex
            State.firstKey := key

            ; Determine which row to target - use last selected row if available
            targetRowIndex := (State.lastSelectedRowIndex > 0) ? State.lastSelectedRowIndex : 1
            rowKey := State.activeRowKeys[targetRowIndex]
            firstCellInColKey := key . rowKey

            ; Check if we're already highlighting this exact cell - if not, update it
            if (firstCellInColKey != State.highlightedCellKey) {
                boundaries := State.currentOverlay.GetCellBoundaries(firstCellInColKey)
                if (IsObject(boundaries)) {
                    ; If using last selected row, move cursor to that cell's center
                    if (State.lastSelectedRowIndex > 0) {
                        targetX := boundaries.x + (boundaries.w // 2)
                        targetY := boundaries.y + (boundaries.h // 2)
                        MouseMove(targetX, targetY, 0)
                    } else {
                        ; Just move horizontally if no row was selected yet
                        MouseGetPos(, &currentY)
                        targetX := boundaries.x + (boundaries.w // 2)
                        MouseMove(targetX, currentY, 0)
                    }

                    ; Highlight the cell at the target row in the new column
                    HighlightCell(firstCellInColKey, boundaries)
                }
            }

            ; If we have a valid last row, always activate sub-grid immediately
            ; regardless of activateSubGrid parameter
            if (State.lastSelectedRowIndex > 0) {
                ; Clear existing sub-grid if any
                if (IsObject(State.subGridOverlay)) {
                    State.subGridOverlay.Destroy()
                    State.subGridOverlay := ""
                }

                ; Create and show sub-grid for this cell - even if the cell hasn't changed
                boundaries := State.currentOverlay.GetCellBoundaries(firstCellInColKey)
                if (IsObject(boundaries)) {
                    State.subGridOverlay := SubGridOverlay(
                        boundaries.x, boundaries.y,
                        boundaries.w, boundaries.h
                    )
                    State.subGridOverlay.Show()

                    ; Update state
                    State.subGridActive := true
                    State.activeCellKey := firstCellInColKey
                    State.firstKey := "" ; Reset for next potential sequence
                    ToolTip("Cell '" . firstCellInColKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
                    return
                }
            }

            ToolTip("First key: " . key . ". Select second key (row).")
            return ; Return early, waiting for row key
        } else {
            ; Invalid key
            ToolTip("Invalid key: '" . key . "' for current layout.")
            Sleep 1000
            ToolTip()
            CleanupHighlight()
            return
        }
    }
    ; No first key yet - could be either a column or row key
    else if (isValidColKey) {
        ; Process as first key (column)
        State.currentColIndex := colIndex

        ; Check if cursor is already in a cell and get its position
        MouseGetPos(&cursorX, &cursorY)
        cursorCellKey := GetCellAtPosition(cursorX, cursorY)

        ; If cursor is in a valid cell, extract the current row
        if (cursorCellKey != "") {
            currentRowKey := SubStr(cursorCellKey, 2, 1)

            ; Find the row index for the current cell
            currentRowIndex := 0
            for i, rKey in State.activeRowKeys {
                if (rKey = currentRowKey) {
                    currentRowIndex := i
                    break
                }
            }

            ; If we found a valid row, use it when switching columns
            if (currentRowIndex > 0) {
                State.currentRowIndex := currentRowIndex
                State.lastSelectedRowIndex := currentRowIndex

                ; Create the new target cell key with new column but same row
                targetCellKey := key . currentRowKey

                ; Get the boundaries for this target cell
                boundaries := State.currentOverlay.GetCellBoundaries(targetCellKey)

                if (IsObject(boundaries)) {
                    ; Highlight the cell
                    HighlightCell(targetCellKey, boundaries)

                    ; Move cursor to center of the target cell
                    targetX := boundaries.x + (boundaries.w // 2)
                    targetY := boundaries.y + (boundaries.h // 2)
                    MouseMove(targetX, targetY, 0)

                    ; Show sub-grid immediately for the target cell
                    if (IsObject(State.subGridOverlay)) {
                        State.subGridOverlay.Destroy()
                        State.subGridOverlay := ""
                    }

                    State.subGridOverlay := SubGridOverlay(
                        boundaries.x, boundaries.y,
                        boundaries.w, boundaries.h
                    )
                    State.subGridOverlay.Show()

                    ; Update state
                    State.subGridActive := true
                    State.activeCellKey := targetCellKey
                    State.firstKey := "" ; Reset for next potential sequence
                    ToolTip("Cell '" . targetCellKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
                    return
                }
            }
        }

        ; === OLD MAGNETIZATION FEATURE (ONLY WITHIN SAME COLUMN) ===
        ; Check if cursor is already in a cell of this column
        if (cursorCellKey != "" && SubStr(cursorCellKey, 1, 1) = key) {
            ; Extract the row key from the detected cell
            rowKey := SubStr(cursorCellKey, 2, 1)

            ; Find the row index
            for i, rKey in State.activeRowKeys {
                if (rKey = rowKey) {
                    rowIndex := i
                    break
                }
            }

            ; Set this as the last selected row
            if (rowIndex > 0) {
                State.currentRowIndex := rowIndex
                State.lastSelectedRowIndex := rowIndex

                ; Get cell boundaries
                boundaries := State.currentOverlay.GetCellBoundaries(cursorCellKey)
                if (IsObject(boundaries)) {
                    ; Highlight the cell
                    HighlightCell(cursorCellKey, boundaries)

                    ; Move cursor to center of the cell
                    targetX := boundaries.x + (boundaries.w // 2)
                    targetY := boundaries.y + (boundaries.h // 2)
                    MouseMove(targetX, targetY, 0)

                    ; Show sub-grid immediately
                    if (IsObject(State.subGridOverlay)) {
                        State.subGridOverlay.Destroy()
                        State.subGridOverlay := ""
                    }

                    State.subGridOverlay := SubGridOverlay(
                        boundaries.x, boundaries.y,
                        boundaries.w, boundaries.h
                    )
                    State.subGridOverlay.Show()

                    ; Update state
                    State.subGridActive := true
                    State.activeCellKey := cursorCellKey
                    State.firstKey := "" ; Reset for next potential sequence
                    ToolTip("Cell '" . cursorCellKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
                    return
                }
            }
        }
        ; === END OLD FEATURE ===

        ; If magnetization didn't happen, continue with normal behavior
        ; Determine which row to target - use last selected row if available
        targetRowIndex := (State.lastSelectedRowIndex > 0) ? State.lastSelectedRowIndex : 1
        rowKey := State.activeRowKeys[targetRowIndex]
        firstCellInColKey := key . rowKey

        ; Check if we're already highlighting this exact cell - if not, update it
        if (firstCellInColKey != State.highlightedCellKey) {
            boundaries := State.currentOverlay.GetCellBoundaries(firstCellInColKey)
            if (IsObject(boundaries)) {
                ; If using last selected row, move cursor to that cell's center
                if (State.lastSelectedRowIndex > 0) {
                    targetX := boundaries.x + (boundaries.w // 2)
                    targetY := boundaries.y + (boundaries.h // 2)
                    MouseMove(targetX, targetY, 0)
                } else {
                    ; Just move horizontally if no row was selected yet
                    MouseGetPos(, &currentY)
                    targetX := boundaries.x + (boundaries.w // 2)
                    MouseMove(targetX, currentY, 0)
                }

                ; Highlight the cell at the target row in the column
                HighlightCell(firstCellInColKey, boundaries)
            }
        }

        ; If we have a valid last row, always activate sub-grid immediately
        ; regardless of activateSubGrid parameter
        if (State.lastSelectedRowIndex > 0) {
            ; Clear existing sub-grid if any
            if (IsObject(State.subGridOverlay)) {
                State.subGridOverlay.Destroy()
                State.subGridOverlay := ""
            }

            ; Create and show sub-grid for this cell - even if the cell hasn't changed
            boundaries := State.currentOverlay.GetCellBoundaries(firstCellInColKey)
            if (IsObject(boundaries)) {
                State.subGridOverlay := SubGridOverlay(
                    boundaries.x, boundaries.y,
                    boundaries.w, boundaries.h
                )
                State.subGridOverlay.Show()

                ; Update state
                State.subGridActive := true
                State.activeCellKey := firstCellInColKey
                State.firstKey := "" ; Reset for next potential sequence
                ToolTip("Cell '" . firstCellInColKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
                return
            }
        }

        ; Clear any previous sub-grid (should not be active here, but good practice)
        if (State.subGridActive) {
            CancelSubGridMode()
        }

        State.firstKey := key
        ToolTip("First key: " . key . ". Select second key (row).")
        return ; Return early, waiting for row key
    }
    else if (isValidRowKey) {
        ; Process as direct row key - use the middle column as default
        State.currentRowIndex := rowIndex
        State.lastSelectedRowIndex := rowIndex ; Remember this row for future column switches

        ; Check if cursor is already in a cell and get its position
        MouseGetPos(&cursorX, &cursorY)
        cursorCellKey := GetCellAtPosition(cursorX, cursorY)

        ; If cursor is in a valid cell, extract the current column
        if (cursorCellKey != "") {
            currentColKey := SubStr(cursorCellKey, 1, 1)

            ; Find the column index for the current cell
            currentColIndex := 0
            for i, cKey in State.activeColKeys {
                if (cKey = currentColKey) {
                    currentColIndex := i
                    break
                }
            }

            ; If we found a valid column, use it with the new row key
            if (currentColIndex > 0) {
                State.currentColIndex := currentColIndex

                ; Create the new target cell key with same column but new row
                targetCellKey := currentColKey . key

                ; Get the boundaries for this target cell
                boundaries := State.currentOverlay.GetCellBoundaries(targetCellKey)

                if (IsObject(boundaries)) {
                    ; Highlight the cell
                    HighlightCell(targetCellKey, boundaries)

                    ; Move cursor to center of the target cell
                    targetX := boundaries.x + (boundaries.w // 2)
                    targetY := boundaries.y + (boundaries.h // 2)
                    MouseMove(targetX, targetY, 0)

                    ; Show sub-grid immediately for the target cell
                    if (IsObject(State.subGridOverlay)) {
                        State.subGridOverlay.Destroy()
                        State.subGridOverlay := ""
                    }

                    State.subGridOverlay := SubGridOverlay(
                        boundaries.x, boundaries.y,
                        boundaries.w, boundaries.h
                    )
                    State.subGridOverlay.Show()

                    ; Update state
                    State.subGridActive := true
                    State.activeCellKey := targetCellKey
                    State.firstKey := "" ; Reset for next potential sequence
                    ToolTip("Cell '" . targetCellKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
                    return
                }
            }
        }

        ; === OLD ROW MAGNETIZATION FEATURE ===
        ; Check if cursor is already in a cell of this row
        if (cursorCellKey != "" && SubStr(cursorCellKey, 2, 1) = key) {
            ; Extract the column key from the detected cell
            colKey := SubStr(cursorCellKey, 1, 1)

            ; Find the column index
            for i, cKey in State.activeColKeys {
                if (cKey = colKey) {
                    colIndex := i
                    break
                }
            }

            ; Set this as the current column
            if (colIndex > 0) {
                State.currentColIndex := colIndex

                ; Get cell boundaries
                boundaries := State.currentOverlay.GetCellBoundaries(cursorCellKey)
                if (IsObject(boundaries)) {
                    ; Highlight the cell
                    HighlightCell(cursorCellKey, boundaries)

                    ; Move cursor to center of the cell
                    targetX := boundaries.x + (boundaries.w // 2)
                    targetY := boundaries.y + (boundaries.h // 2)
                    MouseMove(targetX, targetY, 0)

                    ; Show sub-grid immediately
                    if (IsObject(State.subGridOverlay)) {
                        State.subGridOverlay.Destroy()
                        State.subGridOverlay := ""
                    }

                    State.subGridOverlay := SubGridOverlay(
                        boundaries.x, boundaries.y,
                        boundaries.w, boundaries.h
                    )
                    State.subGridOverlay.Show()

                    ; Update state
                    State.subGridActive := true
                    State.activeCellKey := cursorCellKey
                    State.firstKey := "" ; Reset for next potential sequence
                    ToolTip("Cell '" . cursorCellKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
                    return
                }
            }
        }
        ; === END OLD ROW FEATURE ===

        ; Use the middle column or the last used column if available
        if (State.currentColIndex > 0 && State.currentColIndex <= State.activeColKeys.Length) {
            colKey := State.activeColKeys[State.currentColIndex]
        } else {
            ; Use the middle column as default
            middleColIndex := Ceil(State.activeColKeys.Length / 2)
            colKey := State.activeColKeys[middleColIndex]
            State.currentColIndex := middleColIndex
        }

        cellKey := colKey . key
        boundaries := State.currentOverlay.GetCellBoundaries(cellKey)
        ; Highlight creation happens below in common code
    }
    else {
        ; Neither a valid column nor row key
        ToolTip("Invalid key: '" . key . "' for current layout.")
        Sleep 1000
        ToolTip()
        CleanupHighlight() ; Ensure no partial highlight remains on error
        return
    }

    ; ================================================================
    ; Common code for FINAL cell selection (after second key OR direct row key)
    ; ================================================================
    if (IsObject(boundaries)) {
        ; Highlight the final selected cell
        HighlightCell(cellKey, boundaries)

        ; Move mouse to center
        centerX := boundaries.x + (boundaries.w // 2)
        centerY := boundaries.y + (boundaries.h // 2)
        MouseMove(centerX, centerY, 0)

        ; Create and show a new separate SubGridOverlay window
        ; Destroy any old one first
        if (IsObject(State.subGridOverlay)) {
            State.subGridOverlay.Destroy()
            State.subGridOverlay := ""
        }
        State.subGridOverlay := SubGridOverlay(
            boundaries.x, boundaries.y,
            boundaries.w, boundaries.h
        )
        State.subGridOverlay.Show()

        State.subGridActive := true
        State.activeCellKey := cellKey
        State.firstKey := "" ; Reset for next potential sequence
        ToolTip("Cell '" . cellKey . "' targeted. Use 1-9 for sub-cell, or select new cell.")
    } else {
        ToolTip("Error getting boundaries for cell: " . cellKey)
        Sleep 1000
        ToolTip()
        State.firstKey := "" ; Reset on error
        CleanupHighlight() ; Ensure no partial highlight remains on error
    }
}

HandleSubGridKey(subKey) {
    ; Called only when State.subGridActive is true
    if (!State.subGridActive || !State.activeCellKey || !IsObject(State.subGridOverlay)) {
        return
    }

    ; Use the SubGridOverlay to get target coordinates
    targetCoords := State.subGridOverlay.GetTargetCoordinates(subKey)
    if (!IsObject(targetCoords)) {
        ToolTip("Invalid sub-grid key: " . subKey)
        Sleep 1000
        ToolTip()
        return
    }

    ; Move to the target coordinates
    MouseMove(targetCoords.x, targetCoords.y, 0)
    State.activeSubCellKey := subKey
    ToolTip("Moved to sub-cell " . StrReplace(subKey, "Numpad", "") . " within " . State.activeCellKey)
    ; --- DO NOT CALL Cleanup() HERE ---
}

StartNewSelection(key) {
    ; Called only when State.subGridActive is true and a key is pressed
    if (!State.subGridActive || !IsObject(State.currentOverlay)) {
        return
    }

    ; Check if we're clicking a key of the cell we're already in
    if (State.activeCellKey != "") {
        currentColKey := SubStr(State.activeCellKey, 1, 1)
        currentRowKey := SubStr(State.activeCellKey, 2, 1)

        ; If the pressed key matches either the column or row of the current cell, do nothing
        if (key = currentColKey || key = currentRowKey) {
            ; Completely ignore this keypress - do absolutely nothing
            return
        }
    }

    ; Check if the key is a valid column key
    isValidColKey := false
    for _, colKey in State.activeColKeys {
        if (key = colKey) {
            isValidColKey := true
            break
        }
    }

    ; Check if the key is a valid row key
    isValidRowKey := false
    for _, rowKey in State.activeRowKeys {
        if (key = rowKey) {
            isValidRowKey := true
            break
        }
    }

    ; If it's neither a valid column nor row key, show an error
    if (!isValidColKey && !isValidRowKey) {
        ToolTip("'" . key . "' is not a valid key for this layout.")
        Sleep 1000
        ToolTip()
        return
    }

    ; Add explicit cleanup of highlights before canceling sub-grid mode
    CleanupHighlight()
    CancelSubGridMode() ; Clear old sub-grid targets & reset state

    ; Start the new selection process with the pressed key
    HandleKey(key) ; This will handle both column and row keys correctly
}

TrackCursor() {
    if (!State.isVisible || State.subGridActive) { ; Don't track if sub-grid is active
        return
    }

    MouseGetPos(&x, &y)
    for overlay in State.overlays {
        if (overlay.ContainsPoint(x, y)) {
            if (State.currentOverlay !== overlay) {
                State.currentOverlay := overlay
                if (showcaseDebug) {
                    ToolTip("Switched to Monitor " . overlay.monitorIndex . " at X=" . x . " Y=" . y, , , 2)
                    Sleep 1500
                    ToolTip(, , , 2)
                }
            }
            return
        }
    }
}

; ==============================================================================
; Main Activation Hotkey (Global Scope)
; ==============================================================================

CapsLock & q:: {
    if (State.isVisible || State.subGridActive) {
        Cleanup()
        return
    }

    currentConfig := layoutConfigs[selectedLayout]
    if (!IsObject(currentConfig)) {
        ToolTip("Error: Invalid selectedLayout (" . selectedLayout . ")", , , 4)
        Sleep 2000
        ToolTip(, , , 4)
        return
    }

    ; We're not using the status bar anymore

    State.activeColKeys := currentConfig["colKeys"]
    State.activeRowKeys := currentConfig["rowKeys"]
    State.overlays := []
    MouseGetPos(&startX, &startY)

    if (showcaseDebug) {
        ToolTip("Start X=" . startX . " Y=" . startY, , , 2)
        Sleep 1500
        ToolTip(, , , 2)
    }

    foundMonitor := false
    loop MonitorGetCount() {
        ; Use MonitorGet to get full screen area including the taskbar
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)

        ; Also get work area to determine taskbar position
        MonitorGetWorkArea(A_Index, &WLeft, &WTop, &WRight, &WBottom)

        ; Create the overlay with stronger AlwaysOnTop settings
        overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, State.activeColKeys, State.activeRowKeys)

        ; Force this window to be truly topmost - no longer needed with individual cell windows
        overlay.Show()

        ; Individual cells already have proper settings for displaying above taskbar

        State.overlays.Push(overlay)
        if (!foundMonitor && overlay.ContainsPoint(startX, startY)) {
            State.currentOverlay := overlay
            foundMonitor := true
            if (showcaseDebug) {
                ToolTip("Detected Monitor " . overlay.monitorIndex . " at X=" . startX . " Y=" . startY, , , 2)
                Sleep 1500
                ToolTip(, , , 2)
            }
        }
    }

    if (!foundMonitor && State.overlays.Length > 0) {
        for overlay in State.overlays {
            if (overlay.ContainsPoint(0, 0)) {
                State.currentOverlay := overlay
                foundMonitor := true
                ToolTip("Fallback to Monitor " . overlay.monitorIndex . " (Primary)", 100, 100)
                Sleep 1000
                ToolTip()
                break
            }
        }
        if (!foundMonitor) {
            State.currentOverlay := State.overlays[1]
            foundMonitor := true
            ToolTip("Last Resort: Monitor 1", 100, 100)
            Sleep 1000
            ToolTip()
        }
    }

    if (foundMonitor) {
        State.isVisible := true
        SetTimer(TrackCursor, 50)
    } else {
        ToolTip("Error: No monitor detected (" . startX . ", " . startY . ").", 100, 100)
        Sleep 2000
        ToolTip()
        Cleanup()
    }
}

; ==============================================================================
; Hotkey Contexts and Definitions (Global Scope)
; ==============================================================================

; --- Hotkeys active only during main grid display (before sub-grid targeting) ---
#HotIf State.isVisible && !State.subGridActive
q:: HandleKey("q")
w:: HandleKey("w")
e:: HandleKey("e")
r:: HandleKey("r")
t:: HandleKey("t")
y:: HandleKey("y")
u:: HandleKey("u")
i:: HandleKey("i")
o:: HandleKey("o")
p:: HandleKey("p")
a:: HandleKey("a")
s:: HandleKey("s")
d:: HandleKey("d")
f:: HandleKey("f")
g:: HandleKey("g")
h:: HandleKey("h")
j:: HandleKey("j")
k:: HandleKey("k")
l:: HandleKey("l")
`;:: HandleKey(";")
1:: SwitchMonitor(1)
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
#HotIf

; --- Hotkeys active only during sub-grid targeting ---
#HotIf State.subGridActive
; Sub-grid selection
7:: HandleSubGridKey("7")
8:: HandleSubGridKey("8")
9:: HandleSubGridKey("9")
4:: HandleSubGridKey("4")
5:: HandleSubGridKey("5")
6:: HandleSubGridKey("6")
1:: HandleSubGridKey("1")
2:: HandleSubGridKey("2")
3:: HandleSubGridKey("3")

; Start new cell selection (override sub-grid targeting)
; Define all potential FIRST keys from all layouts here explicitly
; Layout 1 Col Keys
q:: StartNewSelection("q")
w:: StartNewSelection("w")
e:: StartNewSelection("e")
r:: StartNewSelection("r")
t:: StartNewSelection("t")
y:: StartNewSelection("y")
u:: StartNewSelection("u")
i:: StartNewSelection("i")
o:: StartNewSelection("o")
p:: StartNewSelection("p")
; Layout 2 Col Keys (also covers Layout 3 Row Keys)
a:: StartNewSelection("a")
s:: StartNewSelection("s")
d:: StartNewSelection("d")
f:: StartNewSelection("f")
; Layout 3 Col Keys already covered by Layout 1
; Layout 1 Row Keys (if they could be first keys in another layout)
g:: StartNewSelection("g")
h:: StartNewSelection("h")
; Layout 2 Row Keys (if they could be first keys)
j:: StartNewSelection("j")
k:: StartNewSelection("k")
l:: StartNewSelection("l")
`;:: StartNewSelection(";")

; Monitor switching is handled in the main grid context only now.
#HotIf

; --- Hotkeys active during EITHER main grid OR sub-grid targeting ---
#HotIf State.isVisible || State.subGridActive
Space:: {
    if (showcaseDebug) {
        ToolTip("Space pressed - executing click at current position")
        Sleep 500
    }

    ; Store current mouse position
    MouseGetPos(&mouseX, &mouseY)

    ; First hide all GUI elements so they don't interfere with the click
    for overlay in State.overlays {
        try {
            overlay.Hide()
        } catch {
            ; Silently ignore any errors
        }
    }

    if (IsObject(State.subGridOverlay)) {
        try {
            State.subGridOverlay.Hide()
        } catch {
            ; Silently ignore any errors
        }
    }

    ; Clean up highlight if it exists
    if (IsObject(State.currentHighlight)) {
        try {
            State.currentHighlight.Hide()
        } catch {
            ; Silently ignore any errors
        }
    }

    ; Perform the mouse click on the actual application beneath
    MouseClick "Left", mouseX, mouseY, 1, 0

    ; Now perform the full cleanup
    Cleanup()
}
RButton:: {
    Click "Right"
    Cleanup()
}
MButton:: {
    Click "Middle"  ; Middle-click at current position
    Cleanup()
}
d:: {
    Click 2  ; Double-click at current position
    Cleanup()
}

; Drag and drop operations
v:: {
    if (!State.dragActive) {
        Click "Down"  ; Press and hold left mouse button
        State.dragActive := true
        ToolTip("Drag started. Navigate to destination and press 'b' to release.")
    }
}
b:: {
    if (State.dragActive) {
        Click "Up"  ; Release left mouse button
        State.dragActive := false
        Cleanup()
    }
}

; Transparency control
[:: {
    ; Decrease transparency (make more transparent)
    if (IsObject(State.currentOverlay) && State.currentOverlay.gridOverlay.transparency > 50) {
        State.currentOverlay.gridOverlay.transparency -= 20
        WinSetTransColor("000000 " State.currentOverlay.gridOverlay.transparency, "ahk_id " State.currentOverlay.gridOverlay
            .gui.Hwnd)
        if (IsObject(State.subGridOverlay)) {
            State.subGridOverlay.transparency -= 20
            WinSetTransColor("222222 " State.subGridOverlay.transparency, "ahk_id " State.subGridOverlay.gui.Hwnd)
        }
        ToolTip("Transparency: " . Round((State.currentOverlay.gridOverlay.transparency / 255) * 100) . "%")
        Sleep 500
        ToolTip()
    }
}
]:: {
    ; Increase transparency (make more opaque)
    if (IsObject(State.currentOverlay) && State.currentOverlay.gridOverlay.transparency < 235) {
        State.currentOverlay.gridOverlay.transparency += 20
        WinSetTransColor("000000 " State.currentOverlay.gridOverlay.transparency, "ahk_id " State.currentOverlay.gridOverlay
            .gui.Hwnd)
        if (IsObject(State.subGridOverlay)) {
            State.subGridOverlay.transparency += 20
            WinSetTransColor("222222 " State.subGridOverlay.transparency, "ahk_id " State.subGridOverlay.gui.Hwnd)
        }
        ToolTip("Transparency: " . Round((State.currentOverlay.gridOverlay.transparency / 255) * 100) . "%")
        Sleep 500
        ToolTip()
    }
}

Escape:: {
    Cleanup()
}
#HotIf

; --- Direct navigation between cells using arrow keys (when not in sub-grid mode) ---
#HotIf State.isVisible && !State.subGridActive && directNavEnabled
Up:: {
    ; Navigate to the cell above the current one
    if (State.currentColIndex > 0 && State.currentRowIndex > 1) { ; Ensure a column is active
        ; --- Cleanup highlight before navigating ---
        CleanupHighlight()

        ; Move up one row
        newRowIndex := State.currentRowIndex - 1
        colKey := State.activeColKeys[State.currentColIndex]
        rowKey := State.activeRowKeys[newRowIndex]

        ; Simulate pressing the keys
        if (State.firstKey != "") {
            ; If a column was already selected (via key press or previous Left/Right nav),
            ; just select the new row in that column.
            HandleKey(rowKey)
        } else {
            ; If no column key was pressed yet (e.g., just activated),
            ; select the current column first, then the new row.
            HandleKey(colKey) ; This will now highlight the cell in current column at last used row
            HandleKey(rowKey) ; This will cleanup first highlight and highlight final cell + show subgrid
        }
    }
}
Down:: {
    ; Navigate to the cell below the current one
    if (State.currentColIndex > 0 && State.currentRowIndex < State.activeRowKeys.Length) { ; Ensure a column is active
        ; --- Cleanup highlight before navigating ---
        CleanupHighlight()

        ; Move down one row
        newRowIndex := State.currentRowIndex + 1
        colKey := State.activeColKeys[State.currentColIndex]
        rowKey := State.activeRowKeys[newRowIndex]

        ; Simulate pressing the keys
        if (State.firstKey != "") {
            HandleKey(rowKey)
        } else {
            HandleKey(colKey) ; This will now highlight the cell in current column at last used row
            HandleKey(rowKey)
        }
    }
}
Left:: {
    ; Navigate to the cell to the left of the current one
    if (State.currentColIndex > 1) {
        ; --- Cleanup highlight before navigating ---
        CleanupHighlight()

        ; Move left one column
        newColIndex := State.currentColIndex - 1
        colKey := State.activeColKeys[newColIndex]

        ; Cancel subgrid if active (shouldn't be in this context, but safe)
        if (State.subGridActive) {
            CancelSubGridMode() ; This also calls CleanupHighlight
        }

        ; Start a new selection with the new column key and activate sub-grid if we have a lastSelectedRowIndex
        HandleKey(colKey, State.lastSelectedRowIndex > 0)
    }
}
Right:: {
    ; Navigate to the cell to the right of the current one
    if (State.currentColIndex < State.activeColKeys.Length) {
        ; --- Cleanup highlight before navigating ---
        CleanupHighlight()

        ; Move right one column
        newColIndex := State.currentColIndex + 1
        colKey := State.activeColKeys[newColIndex]

        ; Cancel subgrid if active (shouldn't be in this context, but safe)
        if (State.subGridActive) {
            CancelSubGridMode()
        }

        ; Start a new selection with the new column key and activate sub-grid if we have a lastSelectedRowIndex
        HandleKey(colKey, State.lastSelectedRowIndex > 0)
    }
}
#HotIf

; --- Hotkeys active only during sub-grid targeting for scrolling ---
#HotIf State.subGridActive
; Scroll up/down/left/right
Up:: {
    MouseClick "WheelUp", , , 3  ; Scroll up 3 clicks
}
Down:: {
    MouseClick "WheelDown", , , 3  ; Scroll down 3 clicks
}
Left:: {
    MouseClick "WheelLeft", , , 3  ; Scroll left 3 clicks
}
Right:: {
    MouseClick "WheelRight", , , 3  ; Scroll right 3 clicks
}
#HotIf