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

class SubGridOverlay {
    __New() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08")
        this.gui.BackColor := "000000"
        this.width := 0
        this.height := 0
        this.x := 0
        this.y := 0
        this.cells := Map()
        this.borderColor := showcaseDebug ? "FF0000" : "444444"
        this.textColor := showcaseDebug ? "FF0000" : "FFFFFF"
        this.transparency := defaultTransparency
        WinSetTransColor("000000 " this.transparency, this.gui)
    }

    Update(x, y, w, h, colKeys, rowKeys) {
        this.x := x
        this.y := y
        this.width := w
        this.height := h
        this.cols := colKeys.Length
        this.rows := rowKeys.Length
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows
        this.colKeys := colKeys
        this.rowKeys := rowKeys
        this.cells := Map()

        ; Clear existing controls
        for _, ctrl in this.gui.Controls {
            ctrl.Destroy()
        }

        ; Create new grid
        fontSize := Max(8, Min(this.cellWidth, this.cellHeight) // 6)
        this.gui.SetFont("s" fontSize, "Arial")

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

        ; Add borders
        this.gui.Add("Progress", "x0 y0 w" this.width " h" borderThickness " Background" this.borderColor)
        this.gui.Add("Progress", "x0 y" (this.height - borderThickness) " w" this.width " h" borderThickness " Background" this
        .borderColor)
        this.gui.Add("Progress", "x0 y0 w" borderThickness " h" this.height " Background" this.borderColor)
        this.gui.Add("Progress", "x" (this.width - borderThickness) " y0 w" borderThickness " h" this.height " Background" this
        .borderColor)

        ; Add grid lines
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

        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", this.x, this.y, this.width, this.height))
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
