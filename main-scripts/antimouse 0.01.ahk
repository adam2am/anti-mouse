; instead of destroying - hide+show, and other stuff
; actually 0.012 - improved flow

; broke clicking a lil bit tho
; also when pressed space then quickly pressing escape > its showing no gui to hide
; > angle to improve the tracking and not act if no gui to hide

#Requires AutoHotkey v2.0
SetCapsLockState("AlwaysOff")
CoordMode "Mouse", "Screen" ; Mouse coordinates relative to the virtual screen

; Global configuration
global showcaseDebug := false       ; Enable debug tooltips and delays
global selectedLayout := 3            ; Layout options: 1=User QWERTY/ASDF, 2=Home Row ASDF/JKL;, 3=WASD/QWER
global defaultTransparency := 180   ; Transparency level (0-255, 255=opaque)
global highlightColor := "33AAFF"   ; Highlight color for selected cells

; Finite State Machine state
global currentState := "IDLE"       ; Possible states: IDLE, GRID_VISIBLE, SUBGRID_ACTIVE, DRAGGING

; GUI instances for reuse
global highlight := ""              ; Single HighlightOverlay xcinstance (initialized later)
global subGrid := ""                ; Single SubGridOverlay instance (initialized later)

; Layout configurations
global layoutConfigs := Map(
    1, Map("cols", 10, "rows", 10, "colKeys", ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], "rowKeys", ["a", "s",
        "d", "f", "g", "h", "j", "k", "l", ";"]),
    2, Map("cols", 4, "rows", 4, "colKeys", ["a", "s", "d", "f"], "rowKeys", ["j", "k", "lq", ";"]),
    3, Map("cols", 4, "rows", 4, "colKeys", ["q", "w", "e", "r"], "rowKeys", ["a", "s", "d", "f"])
)

; Sub-grid configuration
global subGridKeys := ["7", "8", "9", "4", "5", "6", "1", "2", "3"]
global subGridRows := 3
global subGridCols := 3

; This section defines global variables and configurations, initializing the FSM state and placeholders for GUI reuse. Yes, implemented.

; Highlight Overlay Class with GUI Reuse
class HighlightOverlay {
    __New() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this.gui.BackColor := highlightColor
        this.x := 0
        this.y := 0
        this.width := 0
        this.height := 0
        borderSize := 3
        interiorColor := "000000"
        this.progress := this.gui.Add("Progress", "x" borderSize " y" borderSize " w0 h0 Background" interiorColor)
        WinSetTransColor(interiorColor " 255", this.gui)
    }

    Update(x, y, w, h) {
        this.x := x
        this.y := y
        this.width := w
        this.height := h
        borderSize := 3
        this.progress.Move(borderSize, borderSize, w - 2 * borderSize, h - 2 * borderSize)
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    }

    Hide() {
        this.gui.Hide()
    }

    Destroy() {
        try {
            ; Store the handle before destroying
            hwnd := this.gui.Hwnd

            ; First try to hide it
            this.gui.Hide()

            ; Then destroy it
            this.gui.Destroy()

            ; Force close if it still exists
            if (WinExist("ahk_id " hwnd)) {
                WinClose("ahk_id " hwnd)
                if (WinExist("ahk_id " hwnd)) {
                    WinKill("ahk_id " hwnd)
                }
            }
        } catch {
            ; Silently ignore errors
        }
    }
}

; Sub-Grid Overlay Class with GUI Reuse
class SubGridOverlay {
    __New() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow", "SubGrid")
        this.gui.BackColor := "222222"
        this.x := 0
        this.y := 0
        this.width := 0
        this.height := 0
        this.subCellWidth := 0
        this.subCellHeight := 0
        this.borderControls := []
        this.textControls := []
        ; Add border controls
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background444444")) ; Top
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background444444")) ; Bottom
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background444444")) ; Left
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background444444")) ; Right
        ; Add text controls for sub-cells
        loop 9 {
            this.textControls.Push(this.gui.Add("Text", "x0 y0 w0 h0 Center BackgroundTrans cFFFF00", subGridKeys[
                A_Index]))
        }
        this.transparency := defaultTransparency + 20
        WinSetTransColor("222222 " this.transparency, this.gui)
    }

    Update(x, y, w, h) {
        this.x := x
        this.y := y
        this.width := w
        this.height := h
        this.subCellWidth := w // 3
        this.subCellHeight := h // 3
        fontSize := Max(4, Min(this.subCellWidth, this.subCellHeight) // 3)
        this.gui.SetFont("s" fontSize, "Arial")
        ; Update borders
        this.borderControls[1].Move(0, 0, w, 1)         ; Top
        this.borderControls[2].Move(0, h - 1, w, 1)    ; Bottom
        this.borderControls[3].Move(0, 0, 1, h)        ; Left
        this.borderControls[4].Move(w - 1, 0, 1, h)    ; Right
        ; Update text controls
        index := 1
        loop 3 {
            row := A_Index - 1
            loop 3 {
                col := A_Index - 1
                subX := col * this.subCellWidth
                subY := row * this.subCellHeight
                this.textControls[index].Move(subX, subY, this.subCellWidth, this.subCellHeight)
                index += 1
            }
        }
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    }

    Hide() {
        this.gui.Hide()
    }

    Destroy() {
        try {
            if (IsObject(this.gui)) {
                ; Store handle before destroying the GUI
                hwnd := this.gui.Hwnd

                ; Try normal destroy first
                this.gui.Destroy()

                ; Additional: force close the window if it still exists
                if (WinExist("ahk_id " hwnd)) {
                    WinClose("ahk_id " hwnd)
                    if (WinExist("ahk_id " hwnd)) {
                        WinKill("ahk_id " hwnd)
                    }
                }
            }
        } catch {
            ; Silently ignore errors
        }
    }

    GetTargetCoordinates(subKey) {
        subKeyIndex := -1
        for i, key in subGridKeys {
            if (key = subKey) {
                subKeyIndex := i - 1
                break
            }
        }
        if (subKeyIndex = -1) {
            return false
        }
        subRow := subKeyIndex // subGridCols
        subCol := Mod(subKeyIndex, subGridCols)
        targetX := this.x + (subCol * this.subCellWidth) + (this.subCellWidth // 2)
        targetY := this.y + (subRow * this.subCellHeight) + (this.subCellHeight // 2)
        return { x: targetX, y: targetY }
    }
}

; Grid Overlay Class (unchanged for simplicity)
class GridOverlay {
    __New(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys) {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08")
        this.gui.BackColor := "000000"
        this.width := Right - Left
        this.height := Bottom - Top
        this.x := Left
        this.y := Top
        this.monitorIndex := monitorIndex
        this.cols := colKeys.Length
        this.rows := rowKeys.Length
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows
        this.colKeys := colKeys
        this.rowKeys := rowKeys
        this.cells := Map()
        fontSize := Max(8, Min(this.cellWidth, this.cellHeight) // 6)
        this.gui.SetFont("s" fontSize, "Arial")
        this.borderColor := showcaseDebug ? "FF0000" : "444444"
        this.textColor := showcaseDebug ? "FF0000" : "FFFFFF"
        this.CreateGrid()
        this.transparency := defaultTransparency
        WinSetTransColor("000000 " this.transparency, this.gui)
    }

    CreateGrid() {
        borderThickness := 1
        for colIndex, colKey in this.colKeys {
            for rowIndex, rowKey in this.rowKeys {
                cellKey := colKey . rowKey
                cellX := (colIndex - 1) * this.cellWidth
                cellY := (rowIndex - 1) * this.cellHeight
                this.cells[cellKey] := { x: cellX, y: cellY, w: this.cellWidth, h: this.cellHeight, absX: this.x +
                    cellX, absY: this.y + cellY }
                this.gui.Add("Text", "x" cellX " y" cellY " w" this.cellWidth " h" this.cellHeight " +0x200 Center BackgroundTrans c" this
                    .textColor, cellKey)
            }
        }
        this.gui.Add("Progress", "x0 y0 w" this.width " h" borderThickness " Background" this.borderColor)
        this.gui.Add("Progress", "x0 y" (this.height - borderThickness) " w" this.width " h" borderThickness " Background" this
        .borderColor)
        this.gui.Add("Progress", "x0 y0 w" borderThickness " h" this.height " Background" this.borderColor)
        this.gui.Add("Progress", "x" (this.width - borderThickness) " y0 w" borderThickness " h" this.height " Background" this
        .borderColor)
        for colIndex, _ in this.colKeys {
            if (colIndex > 1) {
                cellX := (colIndex - 1) * this.cellWidth
                this.gui.Add("Progress", "x" cellX " y0 w" borderThickness " h" this.height " Background" this.borderColor
                )
            }
        }
        for rowIndex, _ in this.rowKeys {
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
        try {
            if (IsObject(this.gui)) {
                hwnd := this.gui.Hwnd
                this.gui.Hide()
                this.gui.Destroy()

                if (WinExist("ahk_id " hwnd)) {
                    WinClose("ahk_id " hwnd)
                    if (WinExist("ahk_id " hwnd)) {
                        WinKill("ahk_id " hwnd)
                    }
                }
            }
        } catch {
            ; Silently ignore errors
        }
    }

    GetCellBoundaries(cellKey) {
        if this.cells.Has(cellKey) {
            cell := this.cells[cellKey]
            return { x: this.x + cell.x, y: this.y + cell.y, w: cell.w, h: cell.h }
        }
        return false
    }

    ContainsPoint(x, y) {
        return (x >= this.x && x < this.x + this.width && y >= this.y && y < this.y + this.height)
    }
}

; OverlayGUI Class (wrapper for GridOverlay)
class OverlayGUI {
    __New(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys) {
        this.width := Right - Left
        this.height := Bottom - Top
        this.monitorIndex := monitorIndex
        this.Left := Left
        this.Top := Top
        this.Right := Right
        this.Bottom := Bottom
        this.colKeys := colKeys
        this.rowKeys := rowKeys
        this.cols := colKeys.Length
        this.rows := rowKeys.Length
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows
        this.gridOverlay := GridOverlay(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys)
        this.cells := this.gridOverlay.cells
    }

    Show() {
        this.gridOverlay.Show()
    }

    Hide() {
        this.gridOverlay.Hide()
    }

    Destroy() {
        this.gridOverlay.Destroy()
    }

    GetCellBoundaries(cellKey) {
        return this.gridOverlay.GetCellBoundaries(cellKey)
    }

    ContainsPoint(x, y) {
        return (x >= this.Left && x < this.Right && y >= this.Top && y < this.Bottom)
    }
}

; This section defines classes with GUI reuse for HighlightOverlay and SubGridOverlay, keeping GridOverlay and OverlayGUI largely unchanged. Yes, implemented.

class State {
    static overlays := []           ; Array of OverlayGUI instances per monitor
    static currentOverlay := ""     ; Current active OverlayGUI
    static activeColKeys := []      ; Current layout column keys
    static activeRowKeys := []      ; Current layout row keys
    static firstKey := ""           ; First key in two-key cell selection
    static activeCellKey := ""      ; Current selected cell key (e.g., "es")
    static activeSubCellKey := ""   ; Current sub-cell key (e.g., "5")
    static currentColIndex := 0     ; Current column index
    static currentRowIndex := 0     ; Current row index
    static lastSelectedRowIndex := 0 ; Last selected row index
}

; This section defines a simplified State class for managing application state within the FSM framework. Yes, implemented.

; Helper function to ensure index is within valid range
ValidateIndex(index, arrayLength) {
    if (index < 1)
        return 1
    if (index > arrayLength)
        return arrayLength
    return index
}

ForceCloseAllGuis() {
    ; Force close any stray GUIs that might be left
    try {
        DetectHiddenWindows(true)
        WinClose("ahk_class AutoHotkeyGUI")
        Sleep(30)
        WinClose("ahk_class AutoHotkeyGUI")
    } catch {
        ; Silently ignore errors
    }
}

Cleanup() {
    global currentState, highlight, subGrid

    ; First stop the cursor tracking to prevent recreation
    SetTimer(TrackCursor, 0)

    ; Hide elements before destroying them
    if (IsObject(highlight)) {
        highlight.Hide()
    }

    if (IsObject(subGrid)) {
        subGrid.Hide()
    }

    for overlay in State.overlays {
        overlay.Hide()
    }

    ; Small delay to ensure GUIs have time to hide
    Sleep(20)

    ; Now destroy GUIs
    if (IsObject(highlight)) {
        highlight.Destroy()
    }

    if (IsObject(subGrid)) {
        subGrid.Destroy()
    }

    for overlay in State.overlays {
        try {
            overlay.Destroy()
        } catch {
            ; Silently ignore errors
        }
    }

    ; Forcefully close any remaining GUIs
    ForceCloseAllGuis()

    ; Reset state variables
    State.firstKey := ""
    State.currentOverlay := ""
    State.activeColKeys := []
    State.activeRowKeys := []
    State.activeCellKey := ""
    State.activeSubCellKey := ""
    State.currentColIndex := 0
    State.currentRowIndex := 0
    State.lastSelectedRowIndex := 0

    ; Reset the FSM state to IDLE
    currentState := "IDLE"

    ; Clear tooltips
    ToolTip()
}

SwitchMonitor(monitorNum) {
    global currentState, highlight, subGrid

    if (monitorNum > State.overlays.Length || currentState == "IDLE") {
        return
    }

    newOverlay := State.overlays[monitorNum]
    if (newOverlay && State.currentOverlay !== newOverlay) {
        ; Update state
        State.currentOverlay := newOverlay

        ; Calculate center position
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)

        ; Move cursor to center of new monitor
        MouseMove(centerX, centerY, 0)

        ; Reset any active cell highlighting
        State.activeCellKey := ""

        ; Update the TrackCursor once immediately to detect any cell at the new position
        try {
            TrackCursor()
        } catch {
            ; Ignore any errors during this initial tracking
        }

        if (showcaseDebug) {
            ToolTip("Switched to Monitor " monitorNum)
            Sleep(1000)
            ToolTip()
        }
    }
}

GetCellAtPosition(x, y) {
    if (!IsObject(State.currentOverlay)) {
        return ""
    }
    if (!State.currentOverlay.ContainsPoint(x, y)) {
        return ""
    }
    for colKey in State.activeColKeys {
        for rowKey in State.activeRowKeys {
            cellKey := colKey . rowKey
            boundaries := State.currentOverlay.GetCellBoundaries(cellKey)
            if (IsObject(boundaries) && x >= boundaries.x && x < boundaries.x + boundaries.w && y >= boundaries.y && y <
            boundaries.y + boundaries.h) {
                return cellKey
            }
        }
    }
    return ""
}

HandleKey(key) {
    global currentState, highlight, subGrid

    ; IMPROVEMENT: Explicit hiding at the beginning
    if (IsObject(highlight)) {
        highlight.Hide()
    }
    if (IsObject(subGrid)) {
        subGrid.Hide()
    }

    ; IMPROVEMENT: Temporarily disable TrackCursor to prevent interference
    SetTimer(TrackCursor, 0)

    if (currentState != "GRID_VISIBLE" || !IsObject(State.currentOverlay)) {
        ; Re-enable TrackCursor before returning
        SetTimer(TrackCursor, 50)
        return
    }

    ; Check if key is in column keys
    isColKey := false
    for _, colKey in State.activeColKeys {
        if (colKey = key) {
            isColKey := true
            break
        }
    }

    ; Check if key is in row keys
    isRowKey := false
    for _, rowKey in State.activeRowKeys {
        if (rowKey = key) {
            isRowKey := true
            break
        }
    }

    if (!isColKey && !isRowKey) {
        ToolTip("Invalid key: " key)
        Sleep 1000
        ToolTip()
        ; Re-enable TrackCursor before returning
        SetTimer(TrackCursor, 50)
        return
    }

    ; Handle first key (usually column selection)
    if (State.firstKey = "") {
        if (isColKey) {
            ; Store the column key for two-key selection
            State.firstKey := key

            ; Find the index of this column key
            for i, k in State.activeColKeys {
                if (k = key) {
                    State.currentColIndex := i
                    break
                }
            }

            ; Use last row if one was selected, otherwise use first row
            rowIndex := State.lastSelectedRowIndex ? State.lastSelectedRowIndex : 1
            rowIndex := ValidateIndex(rowIndex, State.activeRowKeys.Length)
            cellKey := key . State.activeRowKeys[rowIndex]
            boundaries := State.currentOverlay.GetCellBoundaries(cellKey)

            if (IsObject(boundaries)) {
                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)

                ; Move the cursor to the center of the highlighted cell
                MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
                ; IMPROVEMENT: Small sleep after MouseMove
                Sleep(10)

                ToolTip("First key: " key ". Select row.")
            }
            ; Re-enable TrackCursor before returning
            SetTimer(TrackCursor, 50)
            return
        }
        else if (isRowKey) {
            ; Direct row selection without column first
            for i, k in State.activeRowKeys {
                if (k = key) {
                    State.currentRowIndex := i
                    State.lastSelectedRowIndex := i
                    break
                }
            }

            ; Use middle column if no column was previously selected
            colIndex := State.currentColIndex ? State.currentColIndex : Ceil(State.activeColKeys.Length / 2)
            colIndex := ValidateIndex(colIndex, State.activeColKeys.Length)
            colKey := State.activeColKeys[colIndex]
            cellKey := colKey . key
        }
    }
    else if (isRowKey) {
        ; Complete two-key selection with row
        for i, k in State.activeRowKeys {
            if (k = key) {
                State.currentRowIndex := i
                State.lastSelectedRowIndex := i
                break
            }
        }
        cellKey := State.firstKey . key
        State.firstKey := ""  ; Reset first key after completing selection
    }
    else {
        ; IMPROVEMENT: Simplified column switching logic
        ; Changed column in middle of selection - immediately update firstKey and highlight
        State.firstKey := key
        for i, k in State.activeColKeys {
            if (k = key) {
                State.currentColIndex := i
                break
            }
        }

        ; Use last row if one was selected, otherwise use first row
        rowIndex := State.lastSelectedRowIndex ? State.lastSelectedRowIndex : 1
        rowIndex := ValidateIndex(rowIndex, State.activeRowKeys.Length)
        cellKey := key . State.activeRowKeys[rowIndex]

        ; Immediately highlight the new column's cell
        boundaries := State.currentOverlay.GetCellBoundaries(cellKey)
        if (IsObject(boundaries)) {
            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
            ; IMPROVEMENT: Small sleep after MouseMove
            Sleep(10)
            ToolTip("Column changed to: " key ". Select row.")
        }
        ; Re-enable TrackCursor and return
        SetTimer(TrackCursor, 50)
        return
    }

    ; Process the final cell selection
    boundaries := State.currentOverlay.GetCellBoundaries(cellKey)
    if (IsObject(boundaries)) {
        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
        ; IMPROVEMENT: Small sleep after MouseMove
        Sleep(10)
        State.activeCellKey := cellKey
        currentState := "SUBGRID_ACTIVE"
        ToolTip("Cell '" cellKey "' targeted. Use 1-9.")
    }

    ; Re-enable TrackCursor
    SetTimer(TrackCursor, 50)
}

HandleSubGridKey(subKey) {
    global currentState, subGrid
    if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid)) {
        return
    }
    targetCoords := subGrid.GetTargetCoordinates(subKey)
    if (IsObject(targetCoords)) {
        MouseMove(targetCoords.x, targetCoords.y, 0)
        State.activeSubCellKey := subKey
        ToolTip("Moved to sub-cell " subKey " in " State.activeCellKey)
    } else {
        ToolTip("Invalid sub-key: " subKey)
        Sleep 1000
        ToolTip()
    }
}

StartNewSelection(key) {
    global currentState, subGrid, highlight

    ; IMPROVEMENT: Temporarily disable TrackCursor
    SetTimer(TrackCursor, 0)

    if (currentState != "SUBGRID_ACTIVE") {
        ; Re-enable TrackCursor before returning
        SetTimer(TrackCursor, 50)
        return
    }

    ; Hide the subgrid first
    if (IsObject(subGrid)) {
        subGrid.Hide()
    }

    ; Hide highlight as well
    if (IsObject(highlight)) {
        highlight.Hide()
    }

    ; Reset state before handling the new key
    State.activeCellKey := ""
    State.activeSubCellKey := ""
    State.firstKey := ""
    currentState := "GRID_VISIBLE"

    ; Force a small delay to ensure state transitions properly
    Sleep(10)

    ; Call HandleKey to process the key press
    HandleKey(key)

    ; TrackCursor re-enabled in HandleKey
}

TrackCursor() {
    global currentState, highlight, subGrid

    ; Ignore if we're in the IDLE state or dragging
    if (currentState == "IDLE" || currentState == "DRAGGING") {
        return
    }

    try {
        ; Get current mouse position
        MouseGetPos(&x, &y)

        ; Check if we moved to a different monitor
        for overlay in State.overlays {
            if (!IsObject(overlay)) {
                continue
            }

            try {
                if (overlay.ContainsPoint(x, y) && State.currentOverlay !== overlay) {
                    State.currentOverlay := overlay
                    if (showcaseDebug) {
                        ToolTip("Switched to Monitor " overlay.monitorIndex)
                        Sleep(1000)
                        ToolTip()
                    }
                    break
                }
            } catch {
                ; Skip this overlay if there's an error
                continue
            }
        }

        ; Only proceed if we have a valid current overlay
        if (!IsObject(State.currentOverlay)) {
            return
        }

        ; Check if cursor is over a cell
        try {
            currentCellKey := GetCellAtPosition(x, y)

            ; Only update if the cell changed and we have valid boundaries
            if (currentCellKey && currentCellKey != State.activeCellKey) {
                boundaries := State.currentOverlay.GetCellBoundaries(currentCellKey)

                if (IsObject(boundaries)) {
                    ; Get the cell center position
                    centerX := boundaries.x + (boundaries.w // 2)
                    centerY := boundaries.y + (boundaries.h // 2)

                    ; Update the highlight and sub-grid
                    try {
                        if (IsObject(highlight)) {
                            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                        }

                        if (IsObject(subGrid)) {
                            subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                        }

                        ; Update the active cell
                        State.activeCellKey := currentCellKey

                        ; If we're in the grid visible state, switch to subgrid active
                        if (currentState == "GRID_VISIBLE") {
                            currentState := "SUBGRID_ACTIVE"
                        }

                        ; Extract column and row characters
                        colChar := SubStr(currentCellKey, 1, 1)
                        rowChar := SubStr(currentCellKey, 2, 1)

                        ; Update column index based on current cell
                        colIndex := 0
                        for i, k in State.activeColKeys {
                            if (colChar = k) {
                                colIndex := i
                                State.currentColIndex := i  ; Update the current column index
                                break
                            }
                        }

                        ; Update row index based on current cell
                        rowIndex := 0
                        for i, k in State.activeRowKeys {
                            if (rowChar = k) {
                                rowIndex := i
                                State.currentRowIndex := i
                                State.lastSelectedRowIndex := i  ; Remember this row
                                break
                            }
                        }

                        ; Debug output if needed
                        if (showcaseDebug) {
                            ToolTip("Cell: " currentCellKey " Col:" colIndex " Row:" rowIndex)
                            Sleep(500)
                            ToolTip()
                        }
                    } catch as e {
                        if (showcaseDebug) {
                            ToolTip("Error updating GUI: " e.Message)
                            Sleep(1000)
                            ToolTip()
                        }
                    }
                }
            }
        } catch as e {
            if (showcaseDebug) {
                ToolTip("Error in cell tracking: " e.Message)
                Sleep(1000)
                ToolTip()
            }
        }
    } catch as e {
        if (showcaseDebug) {
            ToolTip("Error in TrackCursor: " e.Message)
            Sleep(1000)
            ToolTip()
        }
    }
}

; This section includes a simplified Cleanup function, monitor switching, cell position checking, and key handling functions updated for FSM and GUI reuse. Yes, implemented.

CapsLock & q:: {
    global currentState, highlight, subGrid

    ; If already active, clean up and exit
    if (currentState != "IDLE") {
        Cleanup()
        return
    }

    ; Try to initialize
    try {
        ; IMPROVEMENT: Explicitly reset all state variables
        State.firstKey := ""
        State.currentOverlay := ""
        State.activeColKeys := []
        State.activeRowKeys := []
        State.activeCellKey := ""
        State.activeSubCellKey := ""
        State.currentColIndex := 0
        State.currentRowIndex := 0
        State.lastSelectedRowIndex := 0
        State.overlays := []

        ; Get configured layout
        currentConfig := layoutConfigs[selectedLayout]
        if (!IsObject(currentConfig)) {
            ToolTip("Invalid layout: " selectedLayout)
            Sleep(2000)
            ToolTip()
            return
        }

        ; Set up state
        State.activeColKeys := currentConfig["colKeys"]
        State.activeRowKeys := currentConfig["rowKeys"]

        ; Get current mouse position
        MouseGetPos(&startX, &startY)
        foundMonitor := false

        ; Initialize reusable GUI elements
        try {
            highlight := HighlightOverlay()
            subGrid := SubGridOverlay()
        } catch as e {
            ToolTip("Error initializing GUI: " e.Message)
            Sleep(2000)
            ToolTip()
            return
        }

        ; Create overlay for each monitor
        loop MonitorGetCount() {
            try {
                MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
                overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, State.activeColKeys, State.activeRowKeys)
                overlay.Show()
                State.overlays.Push(overlay)

                if (overlay.ContainsPoint(startX, startY)) {
                    State.currentOverlay := overlay
                    foundMonitor := true
                }
            } catch as e {
                if (showcaseDebug) {
                    ToolTip("Error creating overlay for monitor " A_Index ": " e.Message)
                    Sleep(2000)
                    ToolTip()
                }
                ; Continue with next monitor
            }
        }

        ; If no monitor found for current position, use first overlay
        if (!foundMonitor && State.overlays.Length > 0) {
            State.currentOverlay := State.overlays[1]
        }

        ; Only continue if overlay creation was successful
        if (State.overlays.Length > 0 && IsObject(State.currentOverlay)) {
            currentState := "GRID_VISIBLE"
            SetTimer(TrackCursor, 50)
        } else {
            ; Clean up and show error if unsuccessful
            Cleanup()
            ToolTip("Failed to create grid overlays")
            Sleep(2000)
            ToolTip()
        }
    } catch as e {
        ; Handle any uncaught errors
        Cleanup()
        if (showcaseDebug) {
            ToolTip("Error initializing: " e.Message)
            Sleep(2000)
            ToolTip()
        }
    }
}

#HotIf currentState == "GRID_VISIBLE" || currentState == "SUBGRID_ACTIVE"
q:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("q")
    } else {
        StartNewSelection("q")
    }
}
w:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("w")
    } else {
        StartNewSelection("w")
    }
}
e:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("e")
    } else {
        StartNewSelection("e")
    }
}
r:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("r")
    } else {
        StartNewSelection("r")
    }
}
t:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("t")
    } else {
        StartNewSelection("t")
    }
}
y:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("y")
    } else {
        StartNewSelection("y")
    }
}
u:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("u")
    } else {
        StartNewSelection("u")
    }
}
i:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("i")
    } else {
        StartNewSelection("i")
    }
}
o:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("o")
    } else {
        StartNewSelection("o")
    }
}
p:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("p")
    } else {
        StartNewSelection("p")
    }
}
a:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("a")
    } else {
        StartNewSelection("a")
    }
}
s:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("s")
    } else {
        StartNewSelection("s")
    }
}
d:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("d")
    } else {
        StartNewSelection("d")
    }
}
f:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("f")
    } else {
        StartNewSelection("f")
    }
}
g:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("g")
    } else {
        StartNewSelection("g")
    }
}
h:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("h")
    } else {
        StartNewSelection("h")
    }
}
j:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("j")
    } else {
        StartNewSelection("j")
    }
}
k:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("k")
    } else {
        StartNewSelection("k")
    }
}
l:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("l")
    } else {
        StartNewSelection("l")
    }
}
`;:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey(";")
    } else {
        StartNewSelection(";")
    }
}
#HotIf

#HotIf currentState == "SUBGRID_ACTIVE"
1:: HandleSubGridKey("1")
2:: HandleSubGridKey("2")
3:: HandleSubGridKey("3")
4:: HandleSubGridKey("4")
5:: HandleSubGridKey("5")
6:: HandleSubGridKey("6")
7:: HandleSubGridKey("7")
8:: HandleSubGridKey("8")
9:: HandleSubGridKey("9")
#HotIf

#HotIf currentState == "GRID_VISIBLE"
1:: SwitchMonitor(1)
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
#HotIf

#HotIf currentState != "IDLE"
Space:: {
    try {
        ; Save mouse position before any cleanup
        MouseGetPos(&mouseX, &mouseY)

        ; First stop tracking and change state to prevent issues
        SetTimer(TrackCursor, 0)

        ; Hide elements immediately
        if (IsObject(highlight))
            highlight.Hide()
        if (IsObject(subGrid))
            subGrid.Hide()

        ; Small delay to ensure UI elements are hidden
        Sleep(10)

        ; Now perform the mouse click
        MouseClick("Left", mouseX, mouseY, 1, 0)

        ; Clean up after the click
        Cleanup()
    } catch as e {
        if (showcaseDebug) {
            ToolTip("Error: " e.Message)
            Sleep(1000)
            ToolTip()
        }
        ; Still try to clean up if there's an error
        Cleanup()
    }
}

RButton:: {
    try {
        ; Save position before cleanup
        MouseGetPos(&mouseX, &mouseY)

        ; Hide UI elements first
        if (IsObject(highlight))
            highlight.Hide()
        if (IsObject(subGrid))
            subGrid.Hide()

        ; Short delay
        Sleep(10)

        ; Perform right click
        MouseClick("Right", mouseX, mouseY, 1, 0)

        ; Clean up
        Cleanup()
    } catch {
        Cleanup()
    }
}

MButton:: {
    try {
        ; Save position before cleanup
        MouseGetPos(&mouseX, &mouseY)

        ; Hide UI elements first
        if (IsObject(highlight))
            highlight.Hide()
        if (IsObject(subGrid))
            subGrid.Hide()

        ; Short delay
        Sleep(10)

        ; Perform middle click
        MouseClick("Middle", mouseX, mouseY, 1, 0)

        ; Clean up
        Cleanup()
    } catch {
        Cleanup()
    }
}

v:: {
    if (currentState != "DRAGGING") {
        try {
            Click("Down")
            currentState := "DRAGGING"
            ToolTip("Drag started. Press 'b' to release.")
        } catch {
            ; If click fails, reset state
            currentState := "GRID_VISIBLE"
            ToolTip("Failed to start dragging")
            Sleep(1000)
            ToolTip()
        }
    }
}

b:: {
    if (currentState == "DRAGGING") {
        try {
            Click("Up")
            Cleanup()
        } catch {
            ; If click fails, still try to cleanup
            Cleanup()
        }
    }
}

Escape:: Cleanup()
#HotIf

; Monitor switching hotkeys that work regardless of grid state
CapsLock & 1:: {
    global currentState

    ; If grid not active, activate it first
    if (currentState == "IDLE") {
        CapsLock_Q()  ; Call the grid activation function
        Sleep(100)  ; Short delay to ensure grid is initialized
    }

    ; Now switch to monitor 1
    SwitchMonitor(1)
}

CapsLock & 2:: {
    global currentState

    ; If grid not active, activate it first
    if (currentState == "IDLE") {
        CapsLock_Q()  ; Call the grid activation function
        Sleep(100)  ; Short delay to ensure grid is initialized
    }

    ; Now switch to monitor 2
    SwitchMonitor(2)
}

CapsLock & 3:: {
    global currentState

    ; If grid not active, activate it first
    if (currentState == "IDLE") {
        CapsLock_Q()  ; Call the grid activation function
        Sleep(100)  ; Short delay to ensure grid is initialized
    }

    ; Now switch to monitor 3
    SwitchMonitor(3)
}

CapsLock & 4:: {
    global currentState

    ; If grid not active, activate it first
    if (currentState == "IDLE") {
        CapsLock_Q()  ; Call the grid activation function
        Sleep(100)  ; Short delay to ensure grid is initialized
    }

    ; Now switch to monitor 4
    SwitchMonitor(4)
}

; Helper function to reuse the CapsLock & q code
CapsLock_Q() {
    global currentState, highlight, subGrid

    ; If already active, clean up and exit
    if (currentState != "IDLE") {
        Cleanup()
        return
    }

    ; Try to initialize
    try {
        ; IMPROVEMENT: Explicitly reset all state variables
        State.firstKey := ""
        State.currentOverlay := ""
        State.activeColKeys := []
        State.activeRowKeys := []
        State.activeCellKey := ""
        State.activeSubCellKey := ""
        State.currentColIndex := 0
        State.currentRowIndex := 0
        State.lastSelectedRowIndex := 0
        State.overlays := []

        ; Get configured layout
        currentConfig := layoutConfigs[selectedLayout]
        if (!IsObject(currentConfig)) {
            ToolTip("Invalid layout: " selectedLayout)
            Sleep(2000)
            ToolTip()
            return
        }

        ; Set up state
        State.activeColKeys := currentConfig["colKeys"]
        State.activeRowKeys := currentConfig["rowKeys"]

        ; Get current mouse position
        MouseGetPos(&startX, &startY)
        foundMonitor := false

        ; Initialize reusable GUI elements
        try {
            highlight := HighlightOverlay()
            subGrid := SubGridOverlay()
        } catch as e {
            ToolTip("Error initializing GUI: " e.Message)
            Sleep(2000)
            ToolTip()
            return
        }

        ; Create overlay for each monitor
        loop MonitorGetCount() {
            try {
                MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
                overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, State.activeColKeys, State.activeRowKeys)
                overlay.Show()
                State.overlays.Push(overlay)

                if (overlay.ContainsPoint(startX, startY)) {
                    State.currentOverlay := overlay
                    foundMonitor := true
                }
            } catch as e {
                if (showcaseDebug) {
                    ToolTip("Error creating overlay for monitor " A_Index ": " e.Message)
                    Sleep(2000)
                    ToolTip()
                }
                ; Continue with next monitor
            }
        }

        ; If no monitor found for current position, use first overlay
        if (!foundMonitor && State.overlays.Length > 0) {
            State.currentOverlay := State.overlays[1]
        }

        ; Only continue if overlay creation was successful
        if (State.overlays.Length > 0 && IsObject(State.currentOverlay)) {
            currentState := "GRID_VISIBLE"
            SetTimer(TrackCursor, 50)
        } else {
            ; Clean up and show error if unsuccessful
            Cleanup()
            ToolTip("Failed to create grid overlays")
            Sleep(2000)
            ToolTip()
        }
    } catch as e {
        ; Handle any uncaught errors
        Cleanup()
        if (showcaseDebug) {
            ToolTip("Error initializing: " e.Message)
            Sleep(2000)
            ToolTip()
        }
    }
}

; This section consolidates hotkey definitions using FSM states, initializing GUI instances on activation. Yes, implemented.
