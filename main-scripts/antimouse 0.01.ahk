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
global selectedLayout := 2            ; Layout options: 1=User QWERTY/ASDF, 2=ergonomics for diff hands, 3=WASD/QWER
global defaultTransparency := 180   ; Transparency level (0-255, 255=opaque)
global highlightColor := "33AAFF"   ; Highlight color for selected cells
global monitorMapping := [2, 1, 3, 4] ; Map physical monitor index to logical: [physical1, physical2, physical3, physical4]
global cellMemoryFile := A_ScriptDir "\cell_memory.txt" ; File to store cell-subcell selections
global settingsFile := A_ScriptDir "\antimouse_settings.ini" ; File to store settings
global storePerMonitor := true      ; Store subcell positions per monitor

; Finite State Machine state
global currentState := "IDLE"       ; Possible states: IDLE, GRID_VISIBLE, SUBGRID_ACTIVE, DRAGGING
global stateTransitionTime := 0     ; Timestamp of the last state transition
global stateTransitionDelay := 50   ; Minimum time (ms) between state transitions to prevent leakage

; Double CapsLock variables - declare them globally here
global capsLockPressedTime := 0
global doubleCapsThreshold := 400   ; Time in ms for double CapsLock detection

; Global State Map (replaces State class)
global StateMap := Map(
    "overlays", [],
    "currentOverlay", "",
    "activeColKeys", [],
    "activeRowKeys", [],
    "firstKey", "",
    "activeCellKey", "",
    "activeSubCellKey", "",
    "currentColIndex", 0,
    "currentRowIndex", 0,
    "lastSelectedRowIndex", 0
)

; GUI instances for reuse
global highlight := ""              ; Single HighlightOverlay xcinstance (initialized later)
global subGrid := ""                ; Single SubGridOverlay instance (initialized later)

; Cell memory for remembering subgrid positions
global cellMemory := Map()          ; Maps cell keys to subcell keys

; Layout configurations
global layoutConfigs := Map(
    1, Map("cols", 8, "rows", 10, "colKeys", ["q", "w", "e", "r", "u", "i", "o", "p"], "rowKeys", ["a", "s",
        "d", "f", "g", "h", "j", "k", "l", ";"]),
    2, Map("cols", 12, "rows", 11, "colKeys", ["q", "w", "e", "r", "a", "s", "d", "f", "z", "x", "c", "v",
    ],
    "rowKeys", ["u", "i", "o", "p", "j", "k", "l", ";", "m", ".", "/"]),
    3, Map("cols", 4, "rows", 4, "colKeys", ["a", "s", "d", "f"], "rowKeys", ["j", "k", "lq", ";"]),
    4, Map("cols", 4, "rows", 4, "colKeys", ["q", "w", "e", "r"], "rowKeys", ["a", "s", "d", "f"])
)

; Sub-grid configuration
global subGridKeys := ["g", "h", "b", "n"]
global subGridRows := 2
global subGridCols := 2

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

        ; Try to close by class name
        WinClose("ahk_class AutoHotkeyGUI")
        Sleep(30)

        ; Try more forceful closing if any remain
        WinClose("ahk_class AutoHotkeyGUI")
        Sleep(10)

        ; Final aggressive attempt - kill any remaining windows
        WinClose("SubGrid ahk_class AutoHotkeyGUI")

        ; Force kill as last resort
        try {
            WinKill("ahk_class AutoHotkeyGUI")
        } catch {
        }

        ; Reset detection setting
        DetectHiddenWindows(false)
    } catch {
        ; Silently ignore errors
    }
}

Cleanup() {
    global currentState, highlight, subGrid, StateMap

    ; If already cleaned up, don't attempt again
    if (currentState == "IDLE") {
        return
    }

    ; First stop the cursor tracking to prevent recreation
    SetTimer(TrackCursor, 0)

    ; Clear any tooltips
    ToolTip()

    ; Set state to IDLE immediately to prevent re-entry
    currentState := "IDLE"

    ; Hide elements before destroying them - with error checking
    try {
        if (IsObject(highlight)) {
            highlight.Hide()
        }
    } catch {
    }

    try {
        if (IsObject(subGrid)) {
            subGrid.Hide()
        }
    } catch {
    }

    try {
        for overlay in StateMap['overlays'] { ; Use StateMap
            if (IsObject(overlay)) {
                overlay.Hide()
            }
        }
    } catch {
    }

    ; Small delay to ensure GUIs have time to hide
    Sleep(20)

    ; Now destroy GUIs - with individual try/catch blocks
    try {
        if (IsObject(highlight)) {
            highlight.Destroy()
            highlight := ""
        }
    } catch {
    }

    try {
        if (IsObject(subGrid)) {
            subGrid.Destroy()
            subGrid := ""
        }
    } catch {
    }

    try {
        for i, overlay in StateMap['overlays'] { ; Use StateMap
            if (IsObject(overlay)) {
                overlay.Destroy()
            }
        }
        StateMap['overlays'] := [] ; Reset using StateMap
    } catch {
    }

    ; Forcefully close any remaining GUIs
    try {
        ForceCloseAllGuis()
    } catch {
    }

    ; Reset state variables using StateMap
    StateMap['firstKey'] := ""
    StateMap['currentOverlay'] := ""
    StateMap['activeColKeys'] := []
    StateMap['activeRowKeys'] := []
    StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    StateMap['currentColIndex'] := 0
    StateMap['currentRowIndex'] := 0
    StateMap['lastSelectedRowIndex'] := 0
}

; Helper function to load cell memory from file
LoadCellMemory() {
    global cellMemory, cellMemoryFile, showcaseDebug

    ; Clear existing memory first
    cellMemory := Map()

    try {
        if (FileExist(cellMemoryFile)) {
            fileContent := FileRead(cellMemoryFile)
            lines := StrSplit(fileContent, "`n", "`r")

            loadedCount := 0
            for line in lines {
                if (Trim(line) = "") {
                    continue
                }

                parts := StrSplit(line, "=")
                if (parts.Length >= 2) {
                    cellKey := Trim(parts[1])
                    subCellKey := Trim(parts[2])
                    if (cellKey != "" && subCellKey != "") {
                        cellMemory[cellKey] := subCellKey
                        loadedCount += 1
                    }
                }
            }

            if (showcaseDebug) {
                ToolTip("Loaded " loadedCount " cell memories from " cellMemoryFile)
                Sleep(1500)
                ToolTip()
            }
        } else {
            if (showcaseDebug) {
                ToolTip("Cell memory file not found: " cellMemoryFile)
                Sleep(1500)
                ToolTip()
            }
        }
    } catch as e {
        if (showcaseDebug) {
            ToolTip("Error loading cell memory: " e.Message)
            Sleep(1500)
            ToolTip()
        }
    }
}

; Helper function to save cell memory to file
SaveCellMemory() {
    global cellMemory, cellMemoryFile, showcaseDebug

    try {
        fileContent := ""
        savedCount := 0
        for cellKey, subCellKey in cellMemory {
            if (cellKey != "" && subCellKey != "") { ; Ensure we don't save empty keys/values
                fileContent .= cellKey "=" subCellKey "`n"
                savedCount += 1
            }
        }

        ; Ensure directory exists
        SplitPath(cellMemoryFile, &fileName, &fileDir)
        if (!FileExist(fileDir) && fileDir != "") {
            DirCreate(fileDir)
        }

        ; Write the file
        file := FileOpen(cellMemoryFile, "w", "UTF-8")
        if (!IsObject(file)) {
            throw Error("Failed to open file for writing: " cellMemoryFile)
        }
        file.Write(fileContent)
        file.Close()

        if (showcaseDebug) {
            ToolTip("Saved " savedCount " cell memories to " cellMemoryFile)
            Sleep(1500)
            ToolTip()
        }
    } catch as e {
        MsgBox("Error saving cell memory: " e.Message, "Save Error", "IconError")
        if (showcaseDebug) {
            ToolTip("Error saving cell memory: " e.Message)
            Sleep(2000)
            ToolTip()
        }
    }
}

; New function to load settings from INI file
LoadSettings() {
    global settingsFile, selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
    global defaultTransparency, highlightColor

    try {
        if (FileExist(settingsFile)) {
            ; Load general settings
            loadedLayout := IniRead(settingsFile, "General", "Layout", selectedLayout)
            ; Make sure the loaded layout is a valid integer between 1 and 4
            if (IsInteger(loadedLayout) && loadedLayout >= 1 && loadedLayout <= 4) {
                selectedLayout := loadedLayout
            }

            storePerMonitor := IniRead(settingsFile, "General", "StorePerMonitor", storePerMonitor)
            showcaseDebug := IniRead(settingsFile, "General", "Debug", showcaseDebug)

            ; Load monitor mapping
            for i, _ in monitorMapping {
                monitorMapping[i] := IniRead(settingsFile, "MonitorMapping", "Monitor" i, monitorMapping[i])
            }

            ; Load appearance settings
            loadedTransparency := IniRead(settingsFile, "Appearance", "Transparency", defaultTransparency)
            if (IsInteger(loadedTransparency) && loadedTransparency >= 0 && loadedTransparency <= 255) {
                defaultTransparency := loadedTransparency
            }

            highlightColor := IniRead(settingsFile, "Appearance", "HighlightColor", highlightColor)

            if (showcaseDebug) {
                ToolTip("Settings loaded from " settingsFile)
                Sleep(1000)
                ToolTip()
            }
        }
    } catch as e {
        MsgBox("Error loading settings: " e.Message)
    }
}

; Helper function to check if a value is an integer
IsInteger(value) {
    return IsNumber(value) && Floor(value) = value
}

; Helper function that checks if a value is a number
IsNumber(value) {
    if value is number
        return true
    return false
}

; New function to save settings to INI file
SaveSettings() {
    global settingsFile, selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
    global defaultTransparency, highlightColor

    try {
        ; Ensure directory exists
        SplitPath(settingsFile, &fileName, &fileDir)
        if (!FileExist(fileDir) && fileDir != "") {
            DirCreate(fileDir)
        }

        ; Save general settings
        IniWrite(selectedLayout, settingsFile, "General", "Layout")
        IniWrite(storePerMonitor, settingsFile, "General", "StorePerMonitor")
        IniWrite(showcaseDebug, settingsFile, "General", "Debug")

        ; Save monitor mapping
        for i, mapping in monitorMapping {
            IniWrite(mapping, settingsFile, "MonitorMapping", "Monitor" i)
        }

        ; Save appearance settings
        IniWrite(defaultTransparency, settingsFile, "Appearance", "Transparency")
        IniWrite(highlightColor, settingsFile, "Appearance", "HighlightColor")

        if (showcaseDebug) {
            ToolTip("Settings saved to " settingsFile)
            Sleep(1000)
            ToolTip()
        }

        return true
    } catch as e {
        MsgBox("Error saving settings: " e.Message)
        return false
    }
}

SwitchMonitor(monitorNum) {
    global currentState, highlight, subGrid, monitorMapping, storePerMonitor, StateMap

    ; Apply monitor mapping
    mappedMonitor := monitorMapping[monitorNum]
    if (mappedMonitor > StateMap['overlays'].Length || currentState == "IDLE") { ; Use StateMap
        return
    }

    ; Temporarily disable tracking
    SetTimer(TrackCursor, 0)

    ; Get the new overlay
    newOverlay := StateMap['overlays'][mappedMonitor] ; Use StateMap
    if (!newOverlay) {
        ; Re-enable tracking if no valid overlay
        SetTimer(TrackCursor, 50)
        return
    }

    ; Save current position state
    rememberedColIndex := StateMap['currentColIndex'] ; Use StateMap
    rememberedRowIndex := StateMap['currentRowIndex'] ; Use StateMap
    wasInSubgrid := currentState == "SUBGRID_ACTIVE"

    ; Hide UI elements during transition to prevent visual artifacts
    if (IsObject(highlight)) {
        highlight.Hide()
    }
    if (IsObject(subGrid)) {
        subGrid.Hide()
    }

    ; Small delay for UI cleanup
    Sleep(20)

    ; Update state
    StateMap['currentOverlay'] := newOverlay ; Use StateMap

    ; Only attempt to position if we had a valid position
    if (rememberedColIndex > 0 && rememberedRowIndex > 0) {
        ; Ensure indices are valid for new overlay
        colIndex := Min(rememberedColIndex, StateMap['activeColKeys'].Length) ; Use StateMap
        rowIndex := Min(rememberedRowIndex, StateMap['activeRowKeys'].Length) ; Use StateMap

        ; Get the cell key
        colKey := StateMap['activeColKeys'][colIndex] ; Use StateMap
        rowKey := StateMap['activeRowKeys'][rowIndex] ; Use StateMap
        cellKey := colKey . rowKey

        ; Get boundaries for that cell
        boundaries := newOverlay.GetCellBoundaries(cellKey)

        if (IsObject(boundaries)) {
            ; Move to the center of the cell
            centerX := boundaries.x + (boundaries.w // 2)
            centerY := boundaries.y + (boundaries.h // 2)
            MouseMove(centerX, centerY, 0)

            ; Update state BEFORE updating UI
            StateMap['activeCellKey'] := cellKey ; Use StateMap

            ; Update highlight
            if (IsObject(highlight)) {
                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            }

            ; Update subgrid if we were in subgrid mode
            if (wasInSubgrid && IsObject(subGrid)) {
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                ; Force state to SUBGRID_ACTIVE to ensure proper rendering
                currentState := "SUBGRID_ACTIVE"

                ; Check if we have a remembered subcell for this cell and monitor
                if (storePerMonitor) {
                    monitorCellKey := mappedMonitor . "_" . cellKey
                    if (cellMemory.Has(monitorCellKey)) {
                        rememberedSubCell := cellMemory[monitorCellKey]
                        ; Move to remembered subcell position
                        HandleSubGridKey(rememberedSubCell)
                    } else if (cellMemory.Has(cellKey)) {
                        ; Fall back to general cell memory if no monitor-specific memory exists
                        rememberedSubCell := cellMemory[cellKey]
                        HandleSubGridKey(rememberedSubCell)
                    }
                } else if (cellMemory.Has(cellKey)) {
                    rememberedSubCell := cellMemory[cellKey]
                    ; Move to remembered subcell position
                    HandleSubGridKey(rememberedSubCell)
                }
            }
        } else {
            ; If can't get boundaries, just move to center of monitor
            centerX := newOverlay.Left + (newOverlay.width // 2)
            centerY := newOverlay.Top + (newOverlay.height // 2)
            MouseMove(centerX, centerY, 0)
        }
    } else {
        ; No valid position remembered, move to center
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        MouseMove(centerX, centerY, 0)
    }

    if (showcaseDebug) {
        ToolTip("Switched to Monitor " mappedMonitor " (physical: " monitorNum ")")
        Sleep(1000)
        ToolTip()
    }

    ; Re-enable tracking
    SetTimer(TrackCursor, 50)
}

; New function to cycle through monitors
CycleToNextMonitor() {
    global currentState, highlight, subGrid, storePerMonitor, StateMap

    if (currentState == "IDLE" || StateMap['overlays'].Length <= 1) { ; Use StateMap
        return
    }

    ; Temporarily disable tracking
    SetTimer(TrackCursor, 0)

    ; Find current monitor index and cell position
    currentMonitorIndex := 0
    for i, overlay in StateMap['overlays'] { ; Use StateMap
        if (overlay == StateMap['currentOverlay']) { ; Use StateMap
            currentMonitorIndex := i
            break
        }
    }

    ; Remember current position
    rememberedColIndex := StateMap['currentColIndex'] ; Use StateMap
    rememberedRowIndex := StateMap['currentRowIndex'] ; Use StateMap
    wasInSubgrid := currentState == "SUBGRID_ACTIVE"

    ; Calculate next monitor index with wrap-around
    nextMonitorIndex := currentMonitorIndex + 1
    if (nextMonitorIndex > StateMap['overlays'].Length) { ; Use StateMap
        nextMonitorIndex := 1
    }

    ; Get the new overlay
    newOverlay := StateMap['overlays'][nextMonitorIndex] ; Use StateMap
    if (!newOverlay) {
        ; Re-enable tracking if no valid overlay
        SetTimer(TrackCursor, 50)
        return
    }

    ; Update state
    StateMap['currentOverlay'] := newOverlay ; Use StateMap

    ; Only attempt to position if we had a valid position
    if (rememberedColIndex > 0 && rememberedRowIndex > 0) {
        ; Ensure indices are valid for new overlay
        colIndex := Min(rememberedColIndex, StateMap['activeColKeys'].Length) ; Use StateMap
        rowIndex := Min(rememberedRowIndex, StateMap['activeRowKeys'].Length) ; Use StateMap

        ; Get the cell key
        colKey := StateMap['activeColKeys'][colIndex] ; Use StateMap
        rowKey := StateMap['activeRowKeys'][rowIndex] ; Use StateMap
        cellKey := colKey . rowKey

        ; Get boundaries for that cell
        boundaries := newOverlay.GetCellBoundaries(cellKey)

        if (IsObject(boundaries)) {
            ; Move to the center of the cell
            centerX := boundaries.x + (boundaries.w // 2)
            centerY := boundaries.y + (boundaries.h // 2)
            MouseMove(centerX, centerY, 0)

            ; Update state BEFORE updating UI
            StateMap['activeCellKey'] := cellKey ; Use StateMap

            ; Update highlight
            if (IsObject(highlight)) {
                highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
            }

            ; Update subgrid if we were in subgrid mode
            if (wasInSubgrid && IsObject(subGrid)) {
                subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
                ; Force state to SUBGRID_ACTIVE to ensure proper rendering
                currentState := "SUBGRID_ACTIVE"

                ; Check if we have a remembered subcell for this cell and monitor
                if (storePerMonitor) {
                    monitorCellKey := nextMonitorIndex . "_" . cellKey
                    if (cellMemory.Has(monitorCellKey)) {
                        rememberedSubCell := cellMemory[monitorCellKey]
                        ; Move to remembered subcell position
                        HandleSubGridKey(rememberedSubCell)
                    } else if (cellMemory.Has(cellKey)) {
                        ; Fall back to general cell memory if no monitor-specific memory exists
                        rememberedSubCell := cellMemory[cellKey]
                        HandleSubGridKey(rememberedSubCell)
                    }
                } else if (cellMemory.Has(cellKey)) {
                    rememberedSubCell := cellMemory[cellKey]
                    ; Move to remembered subcell position
                    HandleSubGridKey(rememberedSubCell)
                }
            }
        } else {
            ; If can't get boundaries, just move to center of monitor
            centerX := newOverlay.Left + (newOverlay.width // 2)
            centerY := newOverlay.Top + (newOverlay.height // 2)
            MouseMove(centerX, centerY, 0)

            ; Hide UI elements
            if (IsObject(highlight)) {
                highlight.Hide()
            }
            if (IsObject(subGrid)) {
                subGrid.Hide()
            }
        }
    } else {
        ; No valid position remembered, move to center
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        MouseMove(centerX, centerY, 0)
    }

    if (showcaseDebug) {
        ToolTip("Switched to Monitor " nextMonitorIndex)
    }

    ; Re-enable tracking
    SetTimer(TrackCursor, 50)
}

GetCellAtPosition(x, y) {
    global StateMap
    if (!IsObject(StateMap['currentOverlay'])) { ; Use StateMap
        return ""
    }
    if (!StateMap['currentOverlay'].ContainsPoint(x, y)) { ; Use StateMap
        return ""
    }

    ; Use a consistent order (column, then row) when checking cells
    for colKey in StateMap['activeColKeys'] { ; Use StateMap
        for rowKey in StateMap['activeRowKeys'] { ; Use StateMap
            cellKey := colKey . rowKey ; Always column then row
            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey) ; Use StateMap
            if (IsObject(boundaries) && x >= boundaries.x && x < boundaries.x + boundaries.w && y >= boundaries.y && y <
            boundaries.y + boundaries.h) {
                return cellKey
            }
        }
    }
    return ""
}

HandleKey(key) {
    global currentState, highlight, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, StateMap,
        storePerMonitor, showcaseDebug

    ; IMPROVEMENT: Explicit hiding at the beginning
    if (IsObject(highlight)) {
        highlight.Hide()
    }
    if (IsObject(subGrid)) {
        subGrid.Hide()
    }

    ; IMPROVEMENT: Temporarily disable TrackCursor to prevent interference
    SetTimer(TrackCursor, 0)

    if (currentState != "GRID_VISIBLE" || !IsObject(StateMap['currentOverlay'])) { ; Use StateMap
        ; Re-enable TrackCursor before returning
        SetTimer(TrackCursor, 50)
        return
    }

    ; Check if key is a valid column or row key
    isColKey := false
    colIndex := 0
    for i, colKeyCheck in StateMap['activeColKeys'] { ; Use StateMap
        if (colKeyCheck = key) {
            isColKey := true
            colIndex := i
            break
        }
    }

    isRowKey := false
    rowIndex := 0
    for i, rowKeyCheck in StateMap['activeRowKeys'] { ; Use StateMap
        if (rowKeyCheck = key) {
            isRowKey := true
            rowIndex := i
            break
        }
    }

    if (!isColKey && !isRowKey) {
        if (showcaseDebug) {
            ToolTip("Invalid key: " key)
            Sleep 1000
            ToolTip()
        }
        SetTimer(TrackCursor, 50)
        return
    }

    cellKey := ""
    targetCellX := 0
    targetCellY := 0
    targetCellW := 0
    targetCellH := 0
    tooltipText := ""
    proceedToSubgrid := false

    if (StateMap['firstKey'] = "") { ; Use StateMap
        ; --- First Key Press ---
        StateMap['firstKey'] := key ; Use StateMap

        if (isColKey) {
            ; First key is COLUMN
            StateMap['currentColIndex'] := colIndex ; Use StateMap
            targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1 ; Use StateMap
            targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length) ; Use StateMap
            cellKey := key . StateMap['activeRowKeys'][targetRowIndex] ; Use StateMap
            tooltipText := "First key: " key ". Select row."
        } else { ; isRowKey
            ; First key is ROW
            StateMap['currentRowIndex'] := rowIndex ; Use StateMap
            StateMap['lastSelectedRowIndex'] := rowIndex ; Use StateMap
            targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] : Ceil(StateMap['activeColKeys'
                ].Length / 2) ; Use StateMap
            targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length) ; Use StateMap
            cellKey := StateMap['activeColKeys'][targetColIndex] . key ; Use StateMap
            tooltipText := "First key: " key ". Select column."
        }

        boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey) ; Use StateMap
        if (IsObject(boundaries)) {
            targetCellX := boundaries.x
            targetCellY := boundaries.y
            targetCellW := boundaries.w
            targetCellH := boundaries.h
        }

        ; Center cursor and wait for second key
        if (targetCellW > 0) {
            highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
            MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
            Sleep(10)
            if (showcaseDebug) {
                ToolTip(tooltipText)
            }
        }
        SetTimer(TrackCursor, 50)
        return ; Wait for second key

    } else {
        ; --- Second Key Press ---
        firstKeyWasCol := false
        for colKeyCheck in StateMap['activeColKeys'] { ; Use StateMap
            if (colKeyCheck = StateMap['firstKey']) { ; Use StateMap
                firstKeyWasCol := true
                break
            }
        }
        firstKeyWasRow := !firstKeyWasCol ; Assume it must be one or the other if firstKey != ""

        if (firstKeyWasCol && isRowKey) {
            ; Expected: Col -> Row
            cellKey := StateMap['firstKey'] . key ; Use StateMap - column first, then row
            StateMap['currentRowIndex'] := rowIndex ; Use StateMap
            StateMap['lastSelectedRowIndex'] := rowIndex ; Use StateMap
            proceedToSubgrid := true
            StateMap['firstKey'] := "" ; Reset using StateMap
        }
        else if (firstKeyWasRow && isColKey) {
            ; Expected: Row -> Col
            ; IMPORTANT: Always store cell keys as column+row for consistency
            cellKey := key . StateMap['firstKey'] ; Use StateMap - column first, then row
            StateMap['currentColIndex'] := colIndex ; Use StateMap
            proceedToSubgrid := true
            StateMap['firstKey'] := "" ; Reset using StateMap
        }
        else if (firstKeyWasCol && isColKey) {
            ; Unexpected: Col -> Col (Change column)
            StateMap['firstKey'] := key ; Update stored col key using StateMap
            StateMap['currentColIndex'] := colIndex ; Use StateMap
            targetRowIndex := StateMap['lastSelectedRowIndex'] ? StateMap['lastSelectedRowIndex'] : 1 ; Use StateMap
            targetRowIndex := ValidateIndex(targetRowIndex, StateMap['activeRowKeys'].Length) ; Use StateMap
            cellKey := key . StateMap['activeRowKeys'][targetRowIndex] ; Use StateMap
            tooltipText := "Column changed to: " key ". Select row."

            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey) ; Use StateMap
            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }
        }
        else if (firstKeyWasRow && isRowKey) {
            ; Unexpected: Row -> Row (Change row)
            StateMap['firstKey'] := key ; Update stored row key using StateMap
            StateMap['currentRowIndex'] := rowIndex ; Use StateMap
            StateMap['lastSelectedRowIndex'] := rowIndex ; Use StateMap
            targetColIndex := StateMap['currentColIndex'] ? StateMap['currentColIndex'] : Ceil(StateMap['activeColKeys'
                ].Length / 2) ; Use StateMap
            targetColIndex := ValidateIndex(targetColIndex, StateMap['activeColKeys'].Length) ; Use StateMap
            cellKey := StateMap['activeColKeys'][targetColIndex] . key ; Use StateMap
            tooltipText := "Row changed to: " key ". Select column."

            boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey) ; Use StateMap
            if (IsObject(boundaries)) {
                targetCellX := boundaries.x
                targetCellY := boundaries.y
                targetCellW := boundaries.w
                targetCellH := boundaries.h
            }
        }
        else {
            ; Invalid sequence (e.g., firstKey wasn't found in either col/row keys somehow?)
            StateMap['firstKey'] := "" ; Use StateMap
            SetTimer(TrackCursor, 50)
            return
        }

        ; If not proceeding to subgrid, it means we changed the first key (col->col or row->row)
        if (!proceedToSubgrid) {
            if (targetCellW > 0) {
                highlight.Update(targetCellX, targetCellY, targetCellW, targetCellH)
                MouseMove(targetCellX + (targetCellW // 2), targetCellY + (targetCellH // 2), 0)
                Sleep(10)
                if (showcaseDebug) {
                    ToolTip(tooltipText)
                }
            }
            SetTimer(TrackCursor, 50)
            return ; Wait for the *new* second key
        }
    }

    ; --- Proceed to Subgrid State (if proceedToSubgrid is true) ---
    if (!proceedToSubgrid || cellKey = "") {
        StateMap['firstKey'] := "" ; Ensure reset if something went wrong using StateMap
        SetTimer(TrackCursor, 50)
        return
    }

    boundaries := StateMap['currentOverlay'].GetCellBoundaries(cellKey) ; Use StateMap
    if (IsObject(boundaries)) {
        StateMap['activeCellKey'] := cellKey ; Use StateMap
        stateTransitionTime := A_TickCount
        currentState := "SUBGRID_ACTIVE"

        highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)
        MouseMove(boundaries.x + (boundaries.w // 2), boundaries.y + (boundaries.h // 2), 0)
        Sleep(40) ; Increased delay
        subGrid.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)

        ; Ensure subgrid is visible - use a more compatible approach
        try {
            ; Force redraw by temporarily changing the window's style
            if (WinExist("SubGrid ahk_class AutoHotkeyGUI")) {
                winHwnd := WinGetID("SubGrid ahk_class AutoHotkeyGUI")
                if (winHwnd) {
                    ; Force window to redraw by sending a redraw message
                    PostMessage(0x000F, 0, 0, , "ahk_id " winHwnd)  ; WM_PAINT message
                }
            }
        } catch {
        }

        ; Check if we have a remembered subcell for this cell
        rememberedSubCell := ""
        cellFound := false

        ; First check monitor-specific key if enabled
        if (storePerMonitor && IsObject(StateMap['currentOverlay'])) {
            monitorCellKey := StateMap['currentOverlay'].monitorIndex . "_" . cellKey
            if (cellMemory.Has(monitorCellKey)) {
                rememberedSubCell := cellMemory[monitorCellKey]
                cellFound := true
                if (showcaseDebug) {
                    ToolTip("Found monitor-specific subcell: " monitorCellKey " -> " rememberedSubCell)
                    Sleep(500)
                }
            }
        }

        ; Fall back to general cell key if no monitor-specific key found
        if (!cellFound && cellMemory.Has(cellKey)) {
            rememberedSubCell := cellMemory[cellKey]
            cellFound := true
            if (showcaseDebug) {
                ToolTip("Found general subcell: " cellKey " -> " rememberedSubCell)
                Sleep(500)
            }
        }

        ; Move to the remembered subcell position if found
        if (cellFound && rememberedSubCell != "") {
            HandleSubGridKey(rememberedSubCell)
        } else if (showcaseDebug) {
            ToolTip("No saved subcell found for " cellKey)
            Sleep(500)
        }

        if (showcaseDebug) {
            ToolTip("Cell '" cellKey "' targeted. Use b-h.")
        }
    }

    SetTimer(TrackCursor, 50)
}

HandleSubGridKey(subKey) {
    global currentState, subGrid, cellMemory, stateTransitionTime, stateTransitionDelay, storePerMonitor, StateMap,
        showcaseDebug

    if (currentState != "SUBGRID_ACTIVE" || !IsObject(subGrid)) {
        return
    }

    ; Ensure enough time has passed since state transition to prevent accidental keypresses
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition < stateTransitionDelay) {
        Sleep(stateTransitionDelay - timeSinceTransition)
    }

    targetCoords := subGrid.GetTargetCoordinates(subKey)
    if (IsObject(targetCoords)) {
        MouseMove(targetCoords.x, targetCoords.y, 0)
        StateMap['activeSubCellKey'] := subKey ; Use StateMap

        ; Remember this subcell for the current cell
        activeCell := StateMap['activeCellKey']
        if (activeCell != "") { ; Use StateMap
            keyToSave := ""

            ; Determine the key to use based on the storePerMonitor setting
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) { ; Use StateMap
                keyToSave := StateMap['currentOverlay'].monitorIndex . "_" . activeCell
            } else {
                keyToSave := activeCell
            }

            ; Update the memory map
            if (keyToSave != "") {
                cellMemory[keyToSave] := subKey
                if (showcaseDebug) {
                    ToolTip("Memory updated: " keyToSave " -> " subKey)
                    Sleep(500)
                }
                ; Save the entire map to file
                SaveCellMemory()
            }
        }

        if (showcaseDebug) {
            if (storePerMonitor && IsObject(StateMap['currentOverlay'])) { ; Use StateMap
                ToolTip("Moved to sub-cell " subKey " in " activeCell " on monitor " StateMap['currentOverlay'].monitorIndex
                ) ; Use StateMap
            } else {
                ToolTip("Moved to sub-cell " subKey " in " activeCell) ; Use StateMap
            }
        }
    } else {
        if (showcaseDebug) {
            ToolTip("Invalid sub-key: " subKey)
            Sleep 1000
            ToolTip()
        }
    }
}

StartNewSelection(key) {
    global currentState, subGrid, highlight, StateMap

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

    ; Reset state before handling the new key using StateMap
    StateMap['activeCellKey'] := ""
    StateMap['activeSubCellKey'] := ""
    StateMap['firstKey'] := ""
    currentState := "GRID_VISIBLE"

    ; Force a small delay to ensure state transitions properly
    Sleep(10)

    ; Call HandleKey to process the key press
    HandleKey(key)

    ; TrackCursor re-enabled in HandleKey
}

TrackCursor() {
    global currentState, highlight, subGrid, StateMap

    ; Ignore if we're in the IDLE state or dragging
    if (currentState == "IDLE" || currentState == "DRAGGING") {
        return
    }

    try {
        ; Get current mouse position
        MouseGetPos(&x, &y)

        ; Check if we moved to a different monitor
        previousOverlay := StateMap['currentOverlay'] ; Use StateMap
        changedMonitor := false

        for overlay in StateMap['overlays'] { ; Use StateMap
            if (!IsObject(overlay)) {
                continue
            }

            try {
                if (overlay.ContainsPoint(x, y) && StateMap['currentOverlay'] !== overlay) { ; Use StateMap
                    StateMap['currentOverlay'] := overlay ; Use StateMap
                    changedMonitor := true

                    ; Don't clear active cell when changing monitors via hot keys
                    ; This is done to preserve position when switching monitors
                    ; StateMap['activeCellKey'] := "" ; Use StateMap

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

        ; If monitor changed, hide subgrid until cell is determined ONLY if no active cell
        if (changedMonitor && StateMap['activeCellKey'] == "" && IsObject(subGrid)) { ; Use StateMap
            subGrid.Hide()

            ; Also hide highlight until new cell is determined
            if (IsObject(highlight)) {
                highlight.Hide()
            }
        }

        ; Only proceed if we have a valid current overlay
        if (!IsObject(StateMap['currentOverlay'])) { ; Use StateMap
            return
        }

        ; Check if cursor is over a cell
        try {
            currentCellKey := GetCellAtPosition(x, y)

            ; Only update if the cell changed and we have valid boundaries
            if (currentCellKey && currentCellKey != StateMap['activeCellKey']) { ; Use StateMap
                boundaries := StateMap['currentOverlay'].GetCellBoundaries(currentCellKey) ; Use StateMap

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
                        StateMap['activeCellKey'] := currentCellKey ; Use StateMap

                        ; If we're in the grid visible state, switch to subgrid active
                        if (currentState == "GRID_VISIBLE") {
                            currentState := "SUBGRID_ACTIVE"
                        }

                        ; Extract column and row characters
                        colChar := SubStr(currentCellKey, 1, 1)
                        rowChar := SubStr(currentCellKey, 2, 1)

                        ; Update column index based on current cell
                        colIndex := 0
                        for i, k in StateMap['activeColKeys'] { ; Use StateMap
                            if (colChar = k) {
                                colIndex := i
                                StateMap['currentColIndex'] := i  ; Update the current column index ; Use StateMap
                                break
                            }
                        }

                        ; Update row index based on current cell
                        rowIndex := 0
                        for i, k in StateMap['activeRowKeys'] { ; Use StateMap
                            if (rowChar = k) {
                                rowIndex := i
                                StateMap['currentRowIndex'] := i ; Use StateMap
                                StateMap['lastSelectedRowIndex'] := i  ; Remember this row ; Use StateMap
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
`:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey(";")
    } else {
        StartNewSelection(";")
    }
}
z:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("z")
    } else {
        StartNewSelection("z")
    }
}
x:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("x")
    } else {
        StartNewSelection("x")
    }
}
c:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("c")
    } else {
        StartNewSelection("c")
    }
}
v:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("v")
    } else {
        StartNewSelection("v")
    }
}
,:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey(",")
    } else {
        StartNewSelection(",")
    }
}
.:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey(".")
    } else {
        StartNewSelection(".")
    }
}
/:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("/")
    } else {
        StartNewSelection("/")
    }
}
m:: {
    if (currentState == "GRID_VISIBLE") {
        HandleKey("m")
    } else {
        StartNewSelection("m")
    }
}

; Add scan code versions of these keys for layout independence
SC033:: {  ; Comma key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey(",")
    } else {
        StartNewSelection(",")
    }
}

SC034:: {  ; Period key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey(".")
    } else {
        StartNewSelection(".")
    }
}

SC035:: {  ; Slash key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey("/")
    } else {
        StartNewSelection("/")
    }
}

SC032:: {  ; M key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey("m")
    } else {
        StartNewSelection("m")
    }
}

SC027:: {  ; Semicolon key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey(";")
    } else {
        StartNewSelection(";")
    }
}

SC022:: {  ; G key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey("g")
    } else if (currentState == "SUBGRID_ACTIVE") {
        HandleSubGridKey("g")
    } else {
        StartNewSelection("g")
    }
}

SC023:: {  ; H key scan code
    if (currentState == "GRID_VISIBLE") {
        HandleKey("h")
    } else if (currentState == "SUBGRID_ACTIVE") {
        HandleSubGridKey("h")
    } else {
        StartNewSelection("h")
    }
}

; Add number keys for monitor switching
1:: SwitchMonitor(1)
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
#HotIf

#HotIf currentState == "SUBGRID_ACTIVE"
b:: {
    ; Add a guard to prevent key leakage during state transitions
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition >= stateTransitionDelay) {
        HandleSubGridKey("b")
    }
}
n:: {
    ; Add a guard to prevent key leakage during state transitions
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition >= stateTransitionDelay) {
        HandleSubGridKey("n")
    }
}
g:: {
    ; Add a guard to prevent key leakage during state transitions
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition >= stateTransitionDelay) {
        HandleSubGridKey("g")
    }
}
h:: {
    ; Add a guard to prevent key leakage during state transitions
    timeSinceTransition := A_TickCount - stateTransitionTime
    if (timeSinceTransition >= stateTransitionDelay) {
        HandleSubGridKey("h")
    }
}

; Add number keys for monitor switching
1:: SwitchMonitor(1)
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
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

        ; Explicitly remove tooltips
        ToolTip()

        ; Hide elements immediately
        if (IsObject(highlight))
            highlight.Hide()
        if (IsObject(subGrid))
            subGrid.Hide()

        ; Hide all grid overlays to prevent visual artifacts
        for overlay in StateMap['overlays'] {
            if (IsObject(overlay))
                overlay.Hide()
        }

        ; Small delay to ensure UI elements are hidden
        Sleep(30)

        ; Forcefully set state to prevent conflicts
        currentState := "IDLE"

        ; Now perform the mouse click - revert to the more reliable MouseClick
        MouseClick("Left", mouseX, mouseY, 1, 0)

        ; Ensure cleanup happens after the click
        Sleep(30)

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

Escape:: {
    ; Safely call Cleanup with additional try/catch
    try {
        Cleanup()
    } catch as e {
        ; If cleanup failed, force critical cleanup
        try {
            ; Force state to IDLE
            currentState := "IDLE"

            ; Kill any leftover GUIs
            ForceCloseAllGuis()

            ; Reset objects
            highlight := ""
            subGrid := ""
            StateMap['overlays'] := []
            StateMap['currentOverlay'] := ""

            ; Clear tooltips
            ToolTip()
        } catch {
        }
    }
}

; Add Tab key to cycle through monitors
Tab:: {
    ; Temporarily disable TrackCursor completely
    SetTimer(TrackCursor, 0)

    ; Hide subgrid and highlight before switching to prevent visual artifacts
    if (IsObject(subGrid)) {
        subGrid.Hide()
    }
    if (IsObject(highlight)) {
        highlight.Hide()
    }

    ; Small delay to ensure UI is hidden
    Sleep(20)

    ; Now cycle
    CycleToNextMonitor()

    ; Add a small delay before re-enabling cursor tracking
    Sleep(30)

    ; Re-enable cursor tracking
    SetTimer(TrackCursor, 50)
}
#HotIf

global g_ModifierState := {
    caps: false,
    capsFirstReleased: false,
    lastCapsUpTime: 0,
    capsPressedFirstTime: 0,
    capsPressedSecondTime: 0
}
; CapsLock handler for single tap + press activation
CapsLock:: {
    global g_ModifierState, doubleCapsThreshold

    ; Update CapsLock state
    g_ModifierState.caps := GetKeyState("CapsLock", "P")

    currentTime := A_TickCount

    ; First press detection
    if (g_ModifierState.capsPressedFirstTime == 0) {
        g_ModifierState.capsPressedFirstTime := currentTime
        ToolTip("CapsLock 111first press detected")
    }
    ; Second press detection - check if we already have a first press recorded
    else if (g_ModifierState.capsPressedFirstTime > 0) {
        ; Check if this is within the double-press threshold
        if ((currentTime - g_ModifierState.capsPressedFirstTime) < doubleCapsThreshold) {
            g_ModifierState.capsPressedSecondTime := currentTime
            ToolTip("CapsLock 222second press detected")

            ; Activate grid immediately on second press
            CapsLock_Q()

            ; Reset state after activation
            g_ModifierState.capsPressedFirstTime := 0
            g_ModifierState.capsPressedSecondTime := 0
        } else {
            ; Too much time passed, treat as new first press
            g_ModifierState.capsPressedFirstTime := currentTime
            g_ModifierState.capsPressedSecondTime := 0
            ToolTip("CapsLock first press (reset)")
        }
    }

    ; Show debug tooltip if enabled
    if showcaseDebug {
        ToolTip(g_ModifierState.caps ? "CapsLock held detected" : "CapsLock not held")
    }

    ; Important: Return to avoid toggling CapsLock state
    return
}

CapsLock Up:: {
    ToolTip('Capslock UP')
    global g_ModifierState

    currentTime := A_TickCount
    g_ModifierState.lastCapsUpTime := currentTime
    g_ModifierState.capsFirstReleased := true
    g_ModifierState.caps := false

}

; turned out autohotkey is making combo (caps&1) - prio, instead of just a single caps
; ==> so I gave it a hotif physical caps > now holding singular key(caps) can be tracked
#HotIf g_ModifierState.caps
; Monitor switching hotkeys that work regardless of grid state
CapsLock & 1:: {
    global currentState

    ; Temporarily disable tracking
    SetTimer(TrackCursor, 0)

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

    ; Temporarily disable tracking
    SetTimer(TrackCursor, 0)

    ; If grid not active, activate it first
    if (currentState == "IDLE") {
        CapsLock_Q()  ; Call the grid activation function
        Sleep(100)  ; Short delay to bensure grid is initialized
    }

    ; Now switch to monitor 2
    SwitchMonitor(2)
}

CapsLock & 3:: {
    global currentState

    ; Temporarily disable tracking
    SetTimer(TrackCursor, 0)

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

    ; Temporarily disable tracking
    SetTimer(TrackCursor, 0)

    ; If grid not active, activate it first
    if (currentState == "IDLE") {
        CapsLock_Q()  ; Call the grid activation function
        Sleep(100)  ; Short delay to ensure grid is initialized
    }

    ; Now switch to monitor 4
    SwitchMonitor(4)
}

; Keep CapsLock & q (optional for backwards compatibility)
CapsLock & q:: {
    CapsLock_Q()
}
#HotIf

; Helper function to reuse the CapsLock & q code
CapsLock_Q() {
    global currentState, highlight, subGrid, cellMemory, StateMap
    global selectedLayout, layoutConfigs, showcaseDebug ; Also ensure these are global

    ; If already active, clean up and exit
    if (currentState != "IDLE") {
        Cleanup()
        return
    }

    ; Try to initialize
    try {
        ; IMPROVEMENT: Explicitly reset all state variables using StateMap
        StateMap['firstKey'] := ""
        StateMap['currentOverlay'] := ""
        StateMap['activeColKeys'] := []
        StateMap['activeRowKeys'] := []
        StateMap['activeCellKey'] := ""
        StateMap['activeSubCellKey'] := ""
        StateMap['currentColIndex'] := 0
        StateMap['currentRowIndex'] := 0
        StateMap['lastSelectedRowIndex'] := 0
        StateMap['overlays'] := []

        ; Load cell memory from file
        LoadCellMemory()

        ; Get configured layout
        currentConfig := layoutConfigs[selectedLayout]
        if (!IsObject(currentConfig)) {
            ; Fall back to default layout if the selected one is invalid
            selectedLayout := 2
            currentConfig := layoutConfigs[2]
            if (showcaseDebug) {
                ToolTip("Invalid layout selected, falling back to layout 2")
                Sleep(2000)
                ToolTip()
            }
        }

        ; Set up state - ensure we have valid data
        if (IsObject(currentConfig) && currentConfig.Has("colKeys") && currentConfig.Has("rowKeys") &&
        IsObject(currentConfig["colKeys"]) && IsObject(currentConfig["rowKeys"])) {
            StateMap['activeColKeys'] := currentConfig["colKeys"] ; Use StateMap
            StateMap['activeRowKeys'] := currentConfig["rowKeys"] ; Use StateMap
        } else {
            ; Fallback to a basic layout if config is invalid
            StateMap['activeColKeys'] := ["q", "w", "e", "r"] ; Use StateMap
            StateMap['activeRowKeys'] := ["a", "s", "d", "f"] ; Use StateMap
            if (showcaseDebug) {
                ToolTip("Invalid layout configuration, using fallback layout")
                Sleep(2000)
                ToolTip()
            }
        }

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
        monitorCount := MonitorGetCount()
        loop monitorCount {
            try {
                MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
                overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, StateMap['activeColKeys'], StateMap[
                    'activeRowKeys']) ; Use StateMap
                overlay.Show()
                StateMap['overlays'].Push(overlay) ; Use StateMap

                if (overlay.ContainsPoint(startX, startY)) {
                    StateMap['currentOverlay'] := overlay ; Use StateMap
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
        if (!foundMonitor && StateMap['overlays'].Length > 0) { ; Use StateMap
            StateMap['currentOverlay'] := StateMap['overlays'][1] ; Use StateMap
        }

        ; Only continue if overlay creation was successful
        if (StateMap['overlays'].Length > 0 && IsObject(StateMap['currentOverlay'])) { ; Use StateMap
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

; Add settings hotstring - make sure it's enabled
#Hotstring EndChars `t `n
#Hotstring O
:*:;settings::
{
    ShowSettingsGUI()
    return
}

; Function to show settings GUI
ShowSettingsGUI() {
    global selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
    global defaultTransparency, highlightColor

    ; Create settings GUI
    settingsGui := Gui("+AlwaysOnTop +Resize", "Anti-Mouse Settings")
    settingsGui.SetFont("s10", "Segoe UI")

    ; General settings
    settingsGui.Add("GroupBox", "x10 y10 w380 h100", "General Settings")

    settingsGui.Add("Text", "x20 y30 w120 h20", "Layout:")
    layoutDropdown := settingsGui.Add("DropDownList", "x150 y30 w230 h20",
        ["1: User QWERTY/ASDF", "2: Ergonomics for diff hands", "3: WASD/QWER", "4: Custom"])
    layoutDropdown.Choose(selectedLayout)

    settingsGui.Add("Text", "x20 y60 w120 h20", "Store Per Monitor:")
    storePerMonitorCheckbox := settingsGui.Add("Checkbox", "x150 y60 w230 h20",
        "Remember subcell positions per monitor")
    storePerMonitorCheckbox.Value := storePerMonitor

    settingsGui.Add("Text", "x20 y80 w120 h20", "Debug Mode:")
    debugCheckbox := settingsGui.Add("Checkbox", "x150 y80 w230 h20", "Show debug tooltips")
    debugCheckbox.Value := showcaseDebug

    ; Monitor mapping
    settingsGui.Add("GroupBox", "x10 y120 w380 h120", "Monitor Mapping")

    ; Create monitor input controls
    mapInputs := []
    for i, mapping in monitorMapping {
        ; Calculate y position
        y := 140 + (i - 1) * 25
        settingsGui.Add("Text", "x20 y" y " w140 h20", "Physical Monitor " i ":")
        mapInputs.Push(settingsGui.Add("Edit", "x170 y" y " w40 h20", mapping))
        settingsGui.Add("UpDown", "Range1-4", mapping)
    }

    ; Appearance
    settingsGui.Add("GroupBox", "x10 y250 w380 h80", "Appearance")

    settingsGui.Add("Text", "x20 y270 w130 h20", "Transparency:")
    transparencySlider := settingsGui.Add("Slider", "x150 y270 w230 h20 Range0-255 TickInterval20", defaultTransparency
    )

    transparencyText := settingsGui.Add("Text", "x150 y295 w50 h20", defaultTransparency)

    ; Update transparency text when slider changes (using function defined first)
    UpdateSliderText(*) {
        transparencyText.Value := transparencySlider.Value
    }
    transparencySlider.OnEvent("Change", UpdateSliderText)

    settingsGui.Add("Text", "x200 y295 w130 h20", "Highlight Color:")
    highlightColorEdit := settingsGui.Add("Edit", "x340 y295 w50 h20", highlightColor)

    ; Buttons
    applyBtn := settingsGui.Add("Button", "x10 y340 w120 h30", "Apply")
    resetBtn := settingsGui.Add("Button", "x140 y340 w120 h30", "Reset to Default")
    closeBtn := settingsGui.Add("Button", "x270 y340 w120 h30", "Close")

    ; Define button functions
    ApplySettings(*) {
        ; Need to access globals
        global selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
        global defaultTransparency, highlightColor

        ; Update general settings
        selectedLayout := layoutDropdown.Value
        storePerMonitor := storePerMonitorCheckbox.Value
        showcaseDebug := debugCheckbox.Value

        ; Update monitor mapping
        for i, _ in monitorMapping {
            monitorMapping[i] := mapInputs[i].Value
        }

        ; Update appearance
        defaultTransparency := transparencySlider.Value
        highlightColor := highlightColorEdit.Value

        ; Apply changes immediately
        for overlay in StateMap['overlays'] {
            if (IsObject(overlay) && IsObject(overlay.gridOverlay) && IsObject(overlay.gridOverlay.gui)) {
                try {
                    ; Update transparency in active overlays
                    WinSetTransColor("000000 " defaultTransparency, overlay.gridOverlay.gui)
                } catch {
                    ; Silently ignore errors
                }
            }
        }

        ; Update highlight color if possible
        if (IsObject(highlight) && IsObject(highlight.gui)) {
            try {
                highlight.gui.BackColor := highlightColor
            } catch {
                ; Silently ignore errors
            }
        }

        ; Save settings to INI file
        if (SaveSettings()) {
            MsgBox("Settings saved successfully!")
        }
    }

    ResetDefaults(*) {
        ; Reset dropdown and checkboxes
        layoutDropdown.Choose(2)  ; Default layout
        storePerMonitorCheckbox.Value := true
        debugCheckbox.Value := false

        ; Reset monitor mapping
        if (mapInputs.Length >= 4) {
            mapInputs[1].Value := 2
            mapInputs[2].Value := 1
            mapInputs[3].Value := 3
            mapInputs[4].Value := 4
        }

        ; Reset appearance
        transparencySlider.Value := 180
        UpdateSliderText()
        highlightColorEdit.Value := "33AAFF"
    }

    CloseSettings(*) {
        settingsGui.Destroy()
    }

    ; Set event handlers
    applyBtn.OnEvent("Click", ApplySettings)
    resetBtn.OnEvent("Click", ResetDefaults)
    closeBtn.OnEvent("Click", CloseSettings)
    settingsGui.OnEvent("Close", CloseSettings)
    settingsGui.OnEvent("Escape", CloseSettings)

    ; Show the settings GUI
    settingsGui.Show("w400 h380")
}

; Load settings at script startup
LoadSettings()
LoadCellMemory()