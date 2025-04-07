; ==============================================================================
; gui_classes.ahk - Definitions for GUI Overlay Classes
; ==============================================================================

; --- Highlight Overlay Class ---
; Displays a simple border highlight around the selected cell.

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

                ; Reverse display text only for "a" column in ergonomic mode (layout 2)
                displayText := (selectedLayout == 2 && colKey == "a") ? rowKey . colKey : cellKey

                this.gui.Add("Text", "x" cellX " y" cellY " w" this.cellWidth " h" this.cellHeight " +0x200 Center BackgroundTrans c" this
                    .textColor, displayText)
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
        try {
            if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                this.gui.Hide()
            }
        } catch {
            ; Silently ignore errors
        }
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

; --- Overlay GUI Class ---
; Wrapper class that holds a GridOverlay instance and provides monitor info.
; This acts as the main object stored in StateMap['overlays'].
class OverlayGUI {
    __New(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys) {
        ; Ensure all coordinates are numbers
        this.monitorIndex := Integer(monitorIndex)
        this.Left := Integer(Left)
        this.Top := Integer(Top)
        this.Right := Integer(Right)
        this.Bottom := Integer(Bottom)

        ; Calculate dimensions using the numeric coordinates
        this.width := this.Right - this.Left
        this.height := this.Bottom - this.Top

        this.colKeys := colKeys ; Store keys for reference if needed
        this.rowKeys := rowKeys
        this.cols := colKeys.Length
        this.rows := rowKeys.Length
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows

        ; Create the actual GUI element with the numeric coordinates
        this.gridOverlay := GridOverlay(this.monitorIndex, this.Left, this.Top, this.Right, this.Bottom, colKeys,
            rowKeys)

        ; Expose the cells map from the underlying GridOverlay for easier access
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
        ; Clear references
        this.gridOverlay := ""
        this.cells := ""
    }

    GetCellBoundaries(cellKey) {
        ; Delegate to the underlying GridOverlay
        return this.gridOverlay.GetCellBoundaries(cellKey)
    }

    ContainsPoint(x, y) {
        ; Check if absolute screen coordinates are within this overlay's monitor boundaries
        return (x >= this.Left && x < this.Right && y >= this.Top && y < this.Bottom)
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
        this.cellBorders := []
        this.textControls := []

        ; Add outer border controls (thicker)
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Top
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Bottom
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Left
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Right

        ; Add cell border controls
        ; Horizontal internal borders
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Horizontal 1
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Horizontal 2

        ; Vertical internal borders
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Vertical 1
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Vertical 2

        ; Add text controls for sub-cells - use Center and 0x200 for better vertical centering
        loop 4 {
            this.textControls.Push(this.gui.Add("Text", "x0 y0 w0 h0 Center +0x200 BackgroundTrans cFFFF00",
                subGridKeys[A_Index]))
        }
        this.transparency := defaultTransparency + 20
        WinSetTransColor("222222 " this.transparency, this.gui)
    }

    Update(x, y, w, h) {
        this.x := x
        this.y := y
        this.width := w
        this.height := h
        this.subCellWidth := w // 2
        this.subCellHeight := h // 2

        borderThickness := 1  ; Change from 2px to 1px
        fontSize := Max(16, Min(this.subCellWidth, this.subCellHeight) // 3)
        this.gui.SetFont("s" fontSize " bold", "Arial")

        ; Update outer borders (thicker)
        this.borderControls[1].Move(0, 0, w, borderThickness)                   ; Top
        this.borderControls[2].Move(0, h - borderThickness, w, borderThickness) ; Bottom
        this.borderControls[3].Move(0, 0, borderThickness, h)                   ; Left
        this.borderControls[4].Move(w - borderThickness, 0, borderThickness, h) ; Right

        ; Update internal cell borders
        cellHeight := h // 2
        cellWidth := w // 2

        ; Horizontal internal borders
        this.cellBorders[1].Move(0, cellHeight, w, borderThickness)                      ; Horizontal 1
        this.cellBorders[2].Move(0, cellHeight * 2, w, borderThickness)                  ; Horizontal 2

        ; Vertical internal borders
        this.cellBorders[3].Move(cellWidth, 0, borderThickness, h)                       ; Vertical 1
        this.cellBorders[4].Move(cellWidth * 2, 0, borderThickness, h)                   ; Vertical 2

        ; Update text controls - centered in each cell with proper numbering layout (b-n/g-h)
        index := 1
        loop 2 {
            row := A_Index - 1
            loop 2 {
                col := A_Index - 1
                subX := col * this.subCellWidth
                subY := row * this.subCellHeight

                ; Use full cell dimensions for better vertical centering with the +0x200 style
                this.textControls[index].Move(
                    subX,
                    subY,
                    this.subCellWidth,
                    this.subCellHeight
                )

                ; Force text to redraw with updated color
                this.textControls[index].Opt("cFFFF00")
                this.textControls[index].Text := subGridKeys[index]

                index += 1
            }
        }

        ; Ensure transparency is set correctly
        WinSetTransColor("222222 " this.transparency, this.gui)

        ; Show the window with updated parameters
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

        ; Force window to front to ensure visibility
        try {
            WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
        } catch {
        }

        ; Short delay to ensure rendering completes
        Sleep(10)
    }

    Hide() {
        try {
            if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                this.gui.Hide()
            }
        } catch {
            ; Silently ignore errors
        }
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

class HighlightOverlay {
    __New() {
        global highlightColor ; Explicitly import global

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
        try {
            if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                this.gui.Hide()
            }
        } catch {
            ; Silently ignore errors
        }
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
