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
        global OFFSCREEN_X, OFFSCREEN_Y
        try {
            if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                ; Move off-screen instead of hiding
                this.gui.Show(Format("x{} y{} NoActivate", OFFSCREEN_X, OFFSCREEN_Y))
                ; LogToFile("GridOverlay.Hide: Successfully moved off-screen", "antimouse_core.log")
            }
        } catch {
            ; Silently ignore errors
        }
    }

    ; Destroy method commented out as it will not be used in the off-screen approach
    ; Destroy() {
    ;     try {
    ;         if (IsObject(this.gui)) {
    ;             hwnd := this.gui.Hwnd
    ;             this.gui.Hide()
    ;             this.gui.Destroy()
    ;
    ;             if (WinExist("ahk_id " hwnd)) {
    ;                 WinClose("ahk_id " hwnd)
    ;                 if (WinExist("ahk_id " hwnd)) {
    ;                     WinKill("ahk_id " hwnd)
    ;                 }
    ;             }
    ;         }
    ;     } catch {
    ;         ; Silently ignore errors
    ;     }
    ; }

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

    ; Destroy method commented out as it will not be used in the off-screen approach
    ; Destroy() {
    ;     this.gridOverlay.Destroy()
    ;     ; Clear references
    ;     this.gridOverlay := ""
    ;     this.cells := ""
    ; }

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
        this.currentLayout := "standard"  ; Track current layout type

        ; Add outer border controls (thicker)
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Top
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Bottom
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Left
        this.borderControls.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background777777")) ; Right

        ; Add cell border controls - will be updated based on layout
        ; Standard layout (2x2) borders
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Horizontal 1
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Vertical 1

        ; Ultra-fast layout (3x4) borders
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Horizontal 2
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Horizontal 3
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Vertical 2
        this.cellBorders.Push(this.gui.Add("Progress", "x0 y0 w0 h0 Background555555")) ; Vertical 3

        ; Add text controls for both layouts
        ; Standard layout (2x2) text controls
        loop 4 {
            this.textControls.Push(this.gui.Add("Text", "x0 y0 w0 h0 Center +0x200 BackgroundTrans cFFFF00",
                subGridKeys[A_Index]))
        }

        ; Ultra-fast layout (3x4) text controls
        loop 12 {
            this.textControls.Push(this.gui.Add("Text", "x0 y0 w0 h0 Center +0x200 BackgroundTrans cFFFF00",
                ultraFastSubGridKeys[A_Index]))
        }

        this.transparency := defaultTransparency + 20
        WinSetTransColor("222222 " this.transparency, this.gui)
    }

    Update(x, y, w, h) {
        this.x := x
        this.y := y
        this.width := w
        this.height := h
        this.subCellWidth := w // (this.currentLayout == "standard" ? 2 : 4)
        this.subCellHeight := h // (this.currentLayout == "standard" ? 2 : 3)

        borderThickness := 1
        fontSize := Max(16, Min(this.subCellWidth, this.subCellHeight) // 3)
        this.gui.SetFont("s" fontSize " bold", "Arial")

        ; Update outer borders
        this.borderControls[1].Move(0, 0, w, borderThickness)                   ; Top
        this.borderControls[2].Move(0, h - borderThickness, w, borderThickness) ; Bottom
        this.borderControls[3].Move(0, 0, borderThickness, h)                   ; Left
        this.borderControls[4].Move(w - borderThickness, 0, borderThickness, h) ; Right

        if (this.currentLayout == "standard") {
            this.UpdateStandardLayout()
        } else {
            this.UpdateUltraFastLayout()
        }
    }

    UpdateStandardLayout() {
        ; Update standard 2x2 layout
        cellHeight := this.height // 2
        cellWidth := this.width // 2

        ; Horizontal internal border
        this.cellBorders[1].Move(0, cellHeight, this.width, 1)
        ; Vertical internal border
        this.cellBorders[2].Move(cellWidth, 0, 1, this.height)

        ; Update text controls for standard layout
        index := 1
        loop 2 {
            row := A_Index - 1
            loop 2 {
                col := A_Index - 1
                this.textControls[index].Move(
                    col * cellWidth + (cellWidth // 4),
                    row * cellHeight + (cellHeight // 4),
                    cellWidth // 2,
                    cellHeight // 2
                )
                index++
            }
        }

        ; Hide ultra-fast layout borders and text controls
        loop 4 {
            this.cellBorders[A_Index + 2].Move(0, 0, 0, 0)
        }
        loop 12 {
            this.textControls[A_Index + 4].Move(0, 0, 0, 0)
        }
    }

    UpdateUltraFastLayout() {
        ; Update ultra-fast 3x4 layout
        cellHeight := this.height // 3
        cellWidth := this.width // 4

        ; Horizontal internal borders
        this.cellBorders[1].Move(0, cellHeight, this.width, 1)
        this.cellBorders[2].Move(0, cellHeight * 2, this.width, 1)

        ; Vertical internal borders
        this.cellBorders[3].Move(cellWidth, 0, 1, this.height)
        this.cellBorders[4].Move(cellWidth * 2, 0, 1, this.height)
        this.cellBorders[5].Move(cellWidth * 3, 0, 1, this.height)

        ; Update text controls for ultra-fast layout
        index := 5  ; Start after standard layout controls
        loop 3 {
            row := A_Index - 1
            loop 4 {
                col := A_Index - 1
                this.textControls[index].Move(
                    col * cellWidth + (cellWidth // 4),
                    row * cellHeight + (cellHeight // 4),
                    cellWidth // 2,
                    cellHeight // 2
                )
                index++
            }
        }

        ; Hide standard layout text controls
        loop 4 {
            this.textControls[A_Index].Move(0, 0, 0, 0)
        }
    }

    SwitchToStandard() {
        this.currentLayout := "standard"
        this.Update(this.x, this.y, this.width, this.height)
    }

    SwitchToUltraFast() {
        this.currentLayout := "ultrafast"
        this.Update(this.x, this.y, this.width, this.height)
    }

    Show() {
        try {
            LogToFile(Format(
                "Timestamp: {} | SubGridOverlay.Show: Attempting to show GUI with parameters x={}, y={}, w={}, h={}",
                A_TickCount, this.x, this.y, this.width, this.height) "`n", "antimouse_core.log")

            this.gui.Show(Format("x{} y{} w{} h{} NoActivate", this.x, this.y, this.width, this.height))
            LogToFile(Format("Timestamp: {} | SubGridOverlay.Show: GUI.Show() succeeded", A_TickCount) "`n",
            "antimouse_core.log")

            WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
            LogToFile(Format("Timestamp: {} | SubGridOverlay.Show: WinSetAlwaysOnTop succeeded", A_TickCount) "`n",
            "antimouse_core.log")
        } catch as e {
            ; Log any errors during Show
            LogToFile(Format("ERROR in SubGridOverlay.Show: {}", e.Message), "antimouse_core.log") ; Use safe logging
        }
    }

    Hide() {
        global OFFSCREEN_X, OFFSCREEN_Y
        try {
            if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                ; Move off-screen instead of hiding
                this.gui.Show(Format("x{} y{} NoActivate", OFFSCREEN_X, OFFSCREEN_Y))
                LogToFile("SubGridOverlay.Hide: Successfully moved off-screen", "antimouse_core.log")
            }
        } catch as e {
            LogToFile(Format("SubGridOverlay.Hide ERROR: {}", e.Message), "antimouse_core.log")
            ; Silently ignore errors
        }
    }

    GetTargetCoordinates(key) {
        if (this.currentLayout == "standard") {
            return this.GetStandardTargetCoordinates(key)
        } else {
            return this.GetUltraFastTargetCoordinates(key)
        }
    }

    GetStandardTargetCoordinates(key) {
        ; Standard 2x2 layout coordinates
        cellWidth := this.width // 2
        cellHeight := this.height // 2

        switch key {
            case "g": return { x: this.x + (cellWidth // 4), y: this.y + (cellHeight // 4) }
            case "h": return { x: this.x + cellWidth + (cellWidth // 4), y: this.y + (cellHeight // 4) }
            case "b": return { x: this.x + (cellWidth // 4), y: this.y + cellHeight + (cellHeight // 4) }
            case "n": return { x: this.x + cellWidth + (cellWidth // 4), y: this.y + cellHeight + (cellHeight // 4) }
            default: return false
        }
    }

    GetUltraFastTargetCoordinates(key) {
        ; Ultra-fast 3x4 layout coordinates
        cellWidth := this.width // 4
        cellHeight := this.height // 3

        ; Find the index of the key in ultraFastSubGridKeys
        keyIndex := 0
        for i, k in ultraFastSubGridKeys {
            if (k == key) {
                keyIndex := i
                break
            }
        }

        if (keyIndex == 0) {
            return false
        }

        ; Calculate row and column from index
        row := (keyIndex - 1) // 4
        col := Mod(keyIndex - 1, 4)

        return {
            x: this.x + (col * cellWidth) + (cellWidth // 4),
            y: this.y + (row * cellHeight) + (cellHeight // 4)
        }
    }

    ForceShow() {
        try {
            ; Use explicit position parameters for more reliable showing
            if (this.x && this.y && this.w && this.h) {
                this.gui.Show(Format("x{} y{} w{} h{} NA", this.x, this.y, this.w, this.h))
                WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
                LogToFile("SubGridOverlay.ForceShow: Successfully showed with explicit coordinates",
                    "antimouse_fix.log")
            } else {
                ; Fallback to basic show if coordinates aren't set
                this.gui.Show("NA")
                WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
                LogToFile("SubGridOverlay.ForceShow: Used basic Show(NA) - no coordinates available",
                    "antimouse_fix.log")
            }
            ; Force redraw for increased visibility
            if (WinExist("ahk_id " this.gui.Hwnd)) {
                WinRedraw("ahk_id " this.gui.Hwnd)
                LogToFile("SubGridOverlay.ForceShow: Sent WinRedraw", "antimouse_fix.log")
            }
            return true
        } catch as err {
            LogToFile(Format("ERROR: SubGridOverlay.ForceShow failed: {}", err.Message), "antimouse_fix.log")
            ; Last resort - try using WinShow directly
            try {
                WinShow("ahk_id " this.gui.Hwnd)
                LogToFile("SubGridOverlay.ForceShow: Used WinShow as fallback", "antimouse_fix.log")
                return true
            } catch {
                return false
            }
        }
    }
}

class HighlightOverlay {
    __New(color := "0099FF", alpha := 40) {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.gui.BackColor := color
        WinSetTransColor(color " " alpha, this.gui)
        this.color := color
        this.enabled := true
    }

    Update(x, y, w, h) {
        this.x := x
        this.y := y
        this.w := w
        this.h := h
        if (w > 0 && h > 0) {
            try {
                this.gui.Show("x" x " y" y " w" w " h" h " NoActivate")
                LogToFile(Format(
                    "5.13.1 DEBUG | HighlightOverlay.Update: Successfully showed at x={}, y={}, w={}, h={}",
                    x, y, w, h), "antimouse_fix.log")
            } catch as e {
                LogToFile(Format("5.13.1 DEBUG | HighlightOverlay.Update ERROR: {}", e.Message),
                "antimouse_fix.log")
            }
        } else {
            LogToFile(Format("5.13.1 DEBUG | HighlightOverlay.Update WARNING: Invalid dimensions w={}, h={}",
                w, h), "antimouse_fix.log")
        }
    }

    Hide() {
        global OFFSCREEN_X, OFFSCREEN_Y
        if (IsObject(this.gui)) {
            try {
                ; Move off-screen instead of hiding
                this.gui.Show(Format("x{} y{} NoActivate", OFFSCREEN_X, OFFSCREEN_Y))
                LogToFile("5.13.1 DEBUG | HighlightOverlay.Hide: Successfully moved off-screen", "antimouse_fix.log")
            } catch as e {
                LogToFile(Format("5.13.1 DEBUG | HighlightOverlay.Hide ERROR: {}", e.Message),
                "antimouse_fix.log")
            }
        } else {
            LogToFile("5.13.1 DEBUG | HighlightOverlay.Hide WARNING: gui is not an object",
                "antimouse_fix.log")
        }
    }

    ForceShow() {
        try {
            ; Clear any existing window styles that might be causing visibility issues
            if (WinExist("ahk_id " this.gui.Hwnd)) {
                WinShow("ahk_id " this.gui.Hwnd)
                LogToFile("HighlightOverlay.ForceShow: Used WinShow on existing window", "antimouse_fix.log")
            }

            ; Show using the most reliable method available based on context
            if (this.x && this.y && this.w && this.h) {
                ; Show with explicit coordinates for better positioning
                this.gui.Show(Format("x{} y{} w{} h{} NA", this.x, this.y, this.w, this.h))
                LogToFile("HighlightOverlay.ForceShow: Used explicit coordinates", "antimouse_fix.log")
            } else {
                ; Basic show if no coordinates available
                this.gui.Show("NA")
                LogToFile("HighlightOverlay.ForceShow: Used basic Show", "antimouse_fix.log")
            }

            ; Ensure window is on top and refresh its appearance
            WinSetAlwaysOnTop(true, "ahk_id " this.gui.Hwnd)
            WinRedraw("ahk_id " this.gui.Hwnd)

            return true
        } catch as err {
            LogToFile(Format("ERROR: HighlightOverlay.ForceShow failed: {}", err.Message), "antimouse_fix.log")
            return false
        }
    }
}
