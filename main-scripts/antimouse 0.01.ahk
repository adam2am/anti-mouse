#Requires AutoHotkey v2.0
SetCapsLockState("AlwaysOff")
CoordMode "Mouse", "Screen" ; Ensure mouse coordinates are relative to the virtual screen

global showcaseDebug := false ; Set to true to enable debug tooltips, delays, and border colors
global selectedLayout := 1 ; 1: User QWERTY/ASDF, 2: Home Row ASDF/JKL;, 3: WASD/QWER

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
; Main Grid Overlay Class
; ==============================================================================
class OverlayGUI {
    __New(monitorIndex, Left, Top, Right, Bottom, colKeys, rowKeys) {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this.gui.BackColor := "000000"
        this.gui.Opt("+E0x20")

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

        this.cells := Map() ; Store cell boundary info relative to GUI
        this.subGridControls := Map() ; Store dynamically added sub-grid controls {key: ControlObj}
        this.mainFontSize := Max(4, Min(this.cellWidth, this.cellHeight) // 4) ; Ensure minimum size 4
        this.gui.SetFont("s" this.mainFontSize, "Arial")

        borderThickness := 1
        borderColor := showcaseDebug ? "FF0000" : "FFFFFF"

        ; --- Add Outer Border ---
        this.gui.Add("Progress", "x0 y0 w" this.width " h" borderThickness " Background" borderColor)
        this.gui.Add("Progress", "x0 y" (this.height - borderThickness) " w" this.width " h" borderThickness " Background" borderColor
        )
        this.gui.Add("Progress", "x0 y0 w" borderThickness " h" this.height " Background" borderColor)
        this.gui.Add("Progress", "x" (this.width - borderThickness) " y0 w" borderThickness " h" this.height " Background" borderColor
        )

        ; --- Add Cells, Labels, and Borders ---
        for colIndex, firstKey in this.colKeys {
            cellX := (colIndex - 1) * this.cellWidth
            for rowIndex, secondKey in this.rowKeys {
                cellY := (rowIndex - 1) * this.cellHeight
                cellKey := firstKey . secondKey

                this.cells[cellKey] := { x: cellX, y: cellY, w: this.cellWidth, h: this.cellHeight }

                ; --- Add Main Cell Text Label FIRST ---
                this.gui.Add("Text",
                    "x" cellX " y" cellY " w" this.cellWidth " h" this.cellHeight
                    " Center BackgroundTrans c" borderColor,
                    monitorIndex ":" cellKey)

                ; --- Add Inner Cell Borders AFTER Text ---
                if (rowIndex > 1) {
                    this.gui.Add("Progress", "x" cellX " y" cellY " w" this.cellWidth " h" borderThickness " Background" borderColor
                    )
                }
                if (colIndex > 1) {
                    this.gui.Add("Progress", "x" cellX " y" cellY " w" borderThickness " h" this.cellHeight " Background" borderColor
                    )
                }
            }
        }

        WinSetTransColor("000000 200", this.gui)
        this.x := Left
        this.y := Top
    }

    Show() {
        this.gui.Show(Format("x{} y{} NoActivate", this.x, this.y))
    }

    Hide() {
        this.HideSubGrid() ; Ensure sub-grid targets are hidden too
        this.gui.Hide()
    }

    GetCellBoundaries(cellKey) {
        if this.cells.Has(cellKey) {
            cellRel := this.cells[cellKey]
            return { x: this.Left + cellRel.x, y: this.Top + cellRel.y, w: cellRel.w, h: cellRel.h }
        }
        return false
    }

    ContainsPoint(x, y) {
        checkResult := (x >= this.Left && x < this.Right && y >= this.Top && y < this.Bottom)
        if (showcaseDebug) {
            ToolTip("Checking Monitor " this.monitorIndex ": Point(" x "," y ") in Bounds(" this.Left "," this.Top "," this
                .Right "," this.Bottom ")? -> " checkResult, , , 3)
            Sleep 1500
            ToolTip(, , , 3)
        }
        return checkResult
    }

    ShowSubGrid(cellKey) {
        this.HideSubGrid() ; Clear any existing ones first
        if (!this.cells.Has(cellKey)) {
            return
        }

        cellRel := this.cells[cellKey]
        subCellW := cellRel.w // subGridCols
        subCellH := cellRel.h // subGridRows
        if (subCellW <= 0 || subCellH <= 0) {
            return ; Cell too small
        }
        subGridFontSize := Max(4, Min(subCellW, subCellH) // 3) ; Adjust font size for sub-grid
        textColor := showcaseDebug ? "00FFFF" : "FFFF00" ; Cyan/Yellow for sub-grid
        borderSubColor := showcaseDebug ? "808080" : "404040" ; Gray for sub-grid lines

        this.gui.SetFont("s" subGridFontSize, "Arial")

        keyIndex := 0
        loop subGridRows {
            row := A_Index - 1 ; 0-based row index
            loop subGridCols {
                col := A_Index - 1 ; 0-based col index
                if (keyIndex >= subGridKeys.Length) {
                    break ; Safety break inner loop
                }
                subX := cellRel.x + col * subCellW
                subY := cellRel.y + row * subCellH
                subKey := subGridKeys[keyIndex + 1] ; 1-based index

                ; Add sub-grid label
                this.subGridControls[subKey] := this.gui.Add("Text",
                    "x" subX " y" subY " w" subCellW " h" subCellH
                    " Center BackgroundTrans c" textColor,
                    StrReplace(subKey, "Numpad", "")) ; Display "7" instead of "Numpad7"

                ; Add sub-grid lines (optional, can make it busy)
                if (row > 0) {
                    lineCtrl := this.gui.Add("Progress", "x" subX " y" subY " w" subCellW " h" 1 " Background" borderSubColor
                    )
                    this.subGridControls[subKey "_hline" row] := lineCtrl ; Store line control too
                }
                if (col > 0) {
                    lineCtrl := this.gui.Add("Progress", "x" subX " y" subY " w" 1 " h" subCellH " Background" borderSubColor
                    )
                    this.subGridControls[subKey "_vline" col] := lineCtrl ; Store line control too
                }

                keyIndex += 1
            }
            if (keyIndex >= subGridKeys.Length) {
                break ; Safety break outer loop
            }
        }
        this.gui.SetFont("s" this.mainFontSize, "Arial") ; Reset font for main labels
    }

    HideSubGrid() {
        if (this.subGridControls.Count > 0) {
            for key, controlObj in this.subGridControls {
                if (IsObject(controlObj) && controlObj.Hwnd) { ; Check if control is valid
                    try controlObj.Destroy() ; Destroy the control
                }
            }
            this.subGridControls.Clear() ; Clear the map
        }
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
}

; ==============================================================================
; Global Helper Functions (Defined before use in hotkeys)
; ==============================================================================
Cleanup() {
    if (IsObject(State.currentOverlay) && State.subGridActive) {
        State.currentOverlay.HideSubGrid() ; Ensure targets are cleared
    }
    for overlay in State.overlays {
        overlay.Hide() ; Hides GUI and sub-grid targets via its Hide method
    }

    State.isVisible := false
    State.subGridActive := false
    State.firstKey := ""
    State.currentOverlay := ""
    State.activeColKeys := []
    State.activeRowKeys := []
    State.activeCellKey := ""
    State.activeSubCellKey := ""

    ToolTip() ; Clear tooltip
    SetTimer(TrackCursor, 0)
}

CancelSubGridMode() {
    if (State.subGridActive && IsObject(State.currentOverlay)) {
        State.currentOverlay.HideSubGrid()
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

HandleKey(key) {
    ; Called only when State.isVisible is true and State.subGridActive is false
    if (!IsObject(State.currentOverlay)) {
        return
    }

    if (State.firstKey = "") {
        ; --- First Key Input ---
        isValidFirstKey := false
        for _, colKey in State.activeColKeys {
            if (key = colKey) {
                isValidFirstKey := true
                break
            }
        }
        if (isValidFirstKey) {
            State.firstKey := key
            ToolTip("First key: " . key . ". Select second key (row).")
        } else {
            ToolTip("Invalid first key: '" . key . "' for current layout.")
            Sleep 1000
            ToolTip()
        }
    } else {
        ; --- Second Key Input ---
        isValidSecondKey := false
        for _, rowKey in State.activeRowKeys {
            if (key = rowKey) {
                isValidSecondKey := true
                break
            }
        }
        if (isValidSecondKey) {
            cellKey := State.firstKey . key
            boundaries := State.currentOverlay.GetCellBoundaries(cellKey)

            if (IsObject(boundaries)) {
                ; Move mouse to center
                centerX := boundaries.x + (boundaries.w // 2)
                centerY := boundaries.y + (boundaries.h // 2)
                MouseMove(centerX, centerY, 0)

                ; Activate sub-grid targeting for this cell
                State.currentOverlay.ShowSubGrid(cellKey)
                State.subGridActive := true
                State.activeCellKey := cellKey
                State.firstKey := "" ; Reset for next potential sequence
                ToolTip("Cell '" . cellKey . "' targeted. Use Numpad 1-9 for sub-cell, or select new cell.")

            } else {
                ToolTip("Error getting boundaries for cell: " . cellKey)
                Sleep 1000
                ToolTip()
                State.firstKey := "" ; Reset on error
            }
        } else {
            ToolTip("Invalid second key: '" . key . "' for first key '" . State.firstKey . "'.")
            Sleep 1000
            ToolTip()
            ; Don't reset firstKey, allow user to try a different second key
        }
    }
}

HandleSubGridKey(subKey) {
    ; Called only when State.subGridActive is true
    if (!State.subGridActive || !State.activeCellKey || !IsObject(State.currentOverlay)) {
        return
    }

    mainBoundaries := State.currentOverlay.GetCellBoundaries(State.activeCellKey)
    if (!IsObject(mainBoundaries)) {
        return
    }

    ; Find the index of the pressed Numpad key in our defined list
    subKeyIndex := -1
    for index, keyName in subGridKeys {
        if (keyName = subKey) {
            subKeyIndex := index - 1 ; Get 0-based index
            break
        }
    }
    if (subKeyIndex = -1) {
        ToolTip("Invalid sub-grid key: " . subKey)
        Sleep 1000
        ToolTip()
        return ; Not a valid sub-grid key
    }

    ; Calculate row and column within the 3x3 sub-grid
    subRow := subKeyIndex // subGridCols
    subCol := Mod(subKeyIndex, subGridCols)

    ; Calculate sub-cell dimensions
    subCellW := mainBoundaries.w // subGridCols
    subCellH := mainBoundaries.h // subGridRows
    if (subCellW <= 0 || subCellH <= 0) {
        return ; Cell too small
    }
    ; Calculate target sub-cell center coordinates
    targetX := mainBoundaries.x + (subCol * subCellW) + (subCellW // 2)
    targetY := mainBoundaries.y + (subRow * subCellH) + (subCellH // 2)

    MouseMove(targetX, targetY, 0)
    State.activeSubCellKey := subKey ; Remember last sub-cell selected
    ToolTip("Moved to sub-cell " . StrReplace(subKey, "Numpad", "") . " within " . State.activeCellKey) ; Use StrReplace
    ; --- DO NOT CALL Cleanup() HERE ---
}

StartNewSelection(firstKey) {
    ; Called only when State.subGridActive is true and a valid first key is pressed
    if (!State.subGridActive || !IsObject(State.currentOverlay)) {
        return
    }

    ; Check if the pressed key is actually a valid *first* key for the current layout
    isValid := false
    for _, colKey in State.activeColKeys {
        if (firstKey = colKey) {
            isValid := true
            break
        }
    }
    if (!isValid) {
        ToolTip("'" . firstKey . "' is not a valid first key for this layout.")
        Sleep 1000
        ToolTip()
        return ; Ignore if not a valid first key
    }

    CancelSubGridMode() ; Clear old sub-grid targets & reset state

    ; Start the new selection process
    HandleKey(firstKey) ; Process the pressed key as the first key of a new sequence
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
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
        if (showcaseDebug) {
            ToolTip("Monitor " . A_Index . " assigned: L=" . Left . " T=" . Top . " R=" . Right . " B=" . Bottom, , , 1
            )
            Sleep 1500
            ToolTip(, , , 1)
        }
        overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom, State.activeColKeys, State.activeRowKeys)
        overlay.Show()
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
Space:: {
    Click ; Clicks at current mouse position
    Cleanup()
}
RButton:: {
    Click "Right"
    Cleanup()
}
Escape:: {
    Cleanup()
}
#HotIf