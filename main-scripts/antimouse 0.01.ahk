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
        this.precisionControls := Map() ; Store dynamically added precision controls {key: ControlObj}

        ; --- Calculate and set main font size ---
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
        this.HidePrecisionTargets() ; Ensure precision targets are hidden too
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

    ShowPrecisionTargets(cellKey) {
        this.HidePrecisionTargets() ; Clear any existing ones first
        if (!this.cells.Has(cellKey)) {
            return
        }

        cellRel := this.cells[cellKey]
        precisionFontSize := Max(4, Min(cellRel.w, cellRel.h) // 6) ; Ensure minimum size 4
        padding := precisionFontSize // 2
        textColor := showcaseDebug ? "FF00FF" : "00FF00" ; Magenta/Green

        ; Calculate positions relative to the cell's top-left corner within the GUI
        xW := cellRel.x + padding
        yW := cellRel.y + padding
        xA := cellRel.x + padding
        yA := cellRel.y + cellRel.h - precisionFontSize - padding
        xS := cellRel.x + cellRel.w - precisionFontSize - padding
        yS := cellRel.y + cellRel.h - precisionFontSize - padding
        xD := cellRel.x + cellRel.w - precisionFontSize - padding
        yD := cellRel.y + padding

        ; Add small text controls inside the cell using the calculated precision font size
        this.gui.SetFont("s" precisionFontSize, "Arial") ; Set font for precision labels
        this.precisionControls["W"] := this.gui.Add("Text", "x" xW " y" yW " BackgroundTrans c" textColor, "W")
        this.precisionControls["A"] := this.gui.Add("Text", "x" xA " y" yA " BackgroundTrans c" textColor, "A")
        this.precisionControls["S"] := this.gui.Add("Text", "x" xS " y" yS " BackgroundTrans c" textColor, "S")
        this.precisionControls["D"] := this.gui.Add("Text", "x" xD " y" yD " BackgroundTrans c" textColor, "D")
        this.gui.SetFont("s" this.mainFontSize, "Arial") ; Reset font back to main size
    }

    HidePrecisionTargets() {
        if (this.precisionControls.Count > 0) {
            for key, controlObj in this.precisionControls {
                if (IsObject(controlObj) && controlObj.Hwnd) { ; Check if control is valid
                    try controlObj.Destroy() ; Destroy the control
                }
            }
            this.precisionControls.Clear() ; Clear the map
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
    static precisionTargetingActive := false ; Flag for precision input stage
    static targetedCellKey := "" ; Key of the cell targeted for precision (e.g., "es")
}

; ==============================================================================
; Global Helper Functions (Defined before use in hotkeys)
; ==============================================================================
Cleanup() {
    if (IsObject(State.currentOverlay) && State.precisionTargetingActive) {
        State.currentOverlay.HidePrecisionTargets() ; Ensure targets are cleared
    }
    for overlay in State.overlays {
        overlay.Hide() ; Hides GUI and precision targets via its Hide method
    }

    State.isVisible := false
    State.precisionTargetingActive := false
    State.firstKey := ""
    State.currentOverlay := ""
    State.activeColKeys := []
    State.activeRowKeys := []
    State.targetedCellKey := ""

    ToolTip() ; Clear tooltip
    SetTimer(TrackCursor, 0)
}

CancelPrecisionMode() {
    if (State.precisionTargetingActive && IsObject(State.currentOverlay)) {
        State.currentOverlay.HidePrecisionTargets()
        State.precisionTargetingActive := false
        State.targetedCellKey := ""
        State.firstKey := "" ; Reset key sequence
        State.isVisible := true ; Return to main grid visibility state
        ToolTip() ; Clear precision tooltip
    }
}

SwitchMonitor(monitorNum) {
    if (monitorNum > State.overlays.Length) {
        return
    }

    CancelPrecisionMode() ; Cancel precision if active before switching

    if (!State.isVisible) { ; Ensure overlays are visible if we cancelled precision
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
    ; Called only when State.isVisible is true and State.precisionTargetingActive is false
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

                ; Activate precision targeting for this cell
                State.currentOverlay.ShowPrecisionTargets(cellKey)
                State.precisionTargetingActive := true
                State.targetedCellKey := cellKey
                State.firstKey := "" ; Reset for next potential sequence
                ToolTip("Cell '" . cellKey . "' targeted. Use W/A/S/D for corner, or select new cell.")

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

MoveToCorner(corner) {
    ; Called only when State.precisionTargetingActive is true
    if (!State.precisionTargetingActive || !State.targetedCellKey || !IsObject(State.currentOverlay)) {
        return
    }

    boundaries := State.currentOverlay.GetCellBoundaries(State.targetedCellKey)
    if (!IsObject(boundaries)) {
        return
    } ; Should not happen if state is correct

    targetX := 0
    targetY := 0
    cell := boundaries

    switch corner {
        case "TL":
            targetX := cell.x
            targetY := cell.y
        case "BL":
            targetX := cell.x
            targetY := cell.y + cell.h - 1
        case "BR":
            targetX := cell.x + cell.w - 1
            targetY := cell.y + cell.h - 1
        case "TR":
            targetX := cell.x + cell.w - 1
            targetY := cell.y
    }

    MouseMove(targetX, targetY, 0)
    ToolTip("Moved to " . corner . " corner.")
    Sleep 500
    Cleanup() ; Finish the operation
}

StartNewSelection(firstKey) {
    ; Called only when State.precisionTargetingActive is true and a valid first key is pressed
    if (!State.precisionTargetingActive || !IsObject(State.currentOverlay)) {
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

    CancelPrecisionMode() ; Clear old precision targets & reset state

    ; Start the new selection process
    HandleKey(firstKey) ; Process the pressed key as the first key of a new sequence
}

TrackCursor() {
    if (!State.isVisible || State.precisionTargetingActive) {
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
    if (State.isVisible || State.precisionTargetingActive) {
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

; --- Hotkeys active only during main grid display (before precision targeting) ---
#HotIf State.isVisible && !State.precisionTargetingActive
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

; --- Hotkeys active only during precision targeting ---
#HotIf State.precisionTargetingActive
; Corner selection
w:: MoveToCorner("TL")
a:: MoveToCorner("BL")
s:: MoveToCorner("BR")
d:: MoveToCorner("TR")

; Start new cell selection (override precision targeting)
; Define all potential FIRST keys from all layouts here explicitly
; Layout 1 Col Keys
q:: StartNewSelection("q")
; w is used for corner selection
e:: StartNewSelection("e")
r:: StartNewSelection("r")
t:: StartNewSelection("t")
y:: StartNewSelection("y")
u:: StartNewSelection("u")
i:: StartNewSelection("i")
o:: StartNewSelection("o")
p:: StartNewSelection("p")
; Layout 2 Col Keys (also covers Layout 3 Row Keys)
; a is used for corner selection
; s is used for corner selection
; d is used for corner selection
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

; Monitor switching (override precision targeting)
1:: SwitchMonitor(1)
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)
#HotIf

; --- Hotkeys active during EITHER main grid OR precision input ---
#HotIf State.isVisible || State.precisionTargetingActive
Space:: {
    Click ; Clicks at current position (center or corner)
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