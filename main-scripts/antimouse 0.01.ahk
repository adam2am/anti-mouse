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
        this.controlsToDestroy := Map() ; Store controls pending destruction
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

        ; --- Pre-create Sub-Grid Controls (Hidden) ---
        ; Use a smaller font size for sub-grid controls (half of main font size)
        subGridFontSize := Max(4, this.mainFontSize // 2)
        textColor := showcaseDebug ? "00FFFF" : "FFFF00"
        this.gui.SetFont("s" subGridFontSize, "Arial")
        for index, subKey in subGridKeys {
            ctrl := this.gui.Add("Text", "x-1 y-1 w0 h0 Hidden Center BackgroundTrans c" textColor, StrReplace(subKey,
                "Numpad", ""))
            this.subGridControls[subKey] := ctrl
        }
        this.gui.SetFont("s" this.mainFontSize, "Arial") ; Reset to main font size
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
        ; --- REMOVE DESTRUCTION LOGIC START ---
        /*
        if (this.controlsToDestroy.Count > 0) {
            for key, controlObj in this.controlsToDestroy {
                if (IsObject(controlObj) && controlObj.Hwnd) {
                    try { controlObj.Destroy() } catch {}
                }
            }
            this.controlsToDestroy.Clear()
        }
        */
        ; --- REMOVE DESTRUCTION LOGIC END ---

        if (!this.cells.Has(cellKey)) {
            return
        }

        cellRel := this.cells[cellKey]
        subCellW := cellRel.w // subGridCols
        subCellH := cellRel.h // subGridRows
        if (subCellW <= 0 || subCellH <= 0) {
            return ; Cell too small
        }

        subGridFontSize := Max(4, this.mainFontSize // 2) ; Match the size used in constructor
        textColor := showcaseDebug ? "00FFFF" : "FFFF00" ; Use appropriate color

        DllCall("SendMessage", "Ptr", this.gui.Hwnd, "UInt", 0x000B, "Int", 0, "Int", 0) ; WM_SETREDRAW = 0x000B
        this.gui.SetFont("s" subGridFontSize, "Arial") ; Set font for sub-grid controls

        keyIndex := 0
        loop subGridRows {
            row := A_Index - 1
            loop subGridCols {
                col := A_Index - 1
                if (keyIndex >= subGridKeys.Length) {
                    break
                }

                subX := cellRel.x + col * subCellW
                subY := cellRel.y + row * subCellH
                subKey := subGridKeys[keyIndex + 1]

                ; --- MODIFY EXISTING CONTROL ---
                if this.subGridControls.Has(subKey) {
                    ctrl := this.subGridControls[subKey]
                    if IsObject(ctrl) {
                        ctrl.Text := StrReplace(subKey, "Numpad", "")
                        ctrl.Move(subX, subY, subCellW, subCellH)
                        ctrl.Visible := true
                    }
                }
                /* --- REMOVE OLD CONTROL CREATION ---
                this.subGridControls[subKey] := this.gui.Add("Text",
                    "x" subX " y" subY " w" subCellW " h" subCellH
                    " Center BackgroundTrans c" textColor,
                    StrReplace(subKey, "Numpad", ""))
                */

                /* --- REMOVE LINES --- (Already commented out) */

                keyIndex += 1
            }
            if (keyIndex >= subGridKeys.Length) {
                break
            }
        }

        this.gui.SetFont("s" this.mainFontSize, "Arial") ; Reset font for main labels
        DllCall("SendMessage", "Ptr", this.gui.Hwnd, "UInt", 0x000B, "Int", 1, "Int", 0) ; WM_SETREDRAW = 0x000B
        WinRedraw(this.gui.Hwnd) ; Keep this redraw for now
    }

    HideSubGrid() {
        ; --- REMOVE QUEUE LOGIC START ---
        /*
        this.controlsToDestroy := this.subGridControls
        this.subGridControls := Map() ; Clear the active map
        */
        ; --- REMOVE QUEUE LOGIC END ---

        ; --- HIDE PRE-EXISTING CONTROLS ---
        if (this.subGridControls.Count > 0) { ; Check if controls exist
            needsRedraw := false
            DllCall("SendMessage", "Ptr", this.gui.Hwnd, "UInt", 0x000B, "Int", 0, "Int", 0) ; WM_SETREDRAW = 0x000B

            for subKey, controlObj in this.subGridControls {
                if (IsObject(controlObj) && controlObj.Hwnd && controlObj.Visible) {
                    try {
                        controlObj.Visible := false
                        needsRedraw := true
                    } catch {
                        ; Ignore errors
                    }
                }
            }

            if (needsRedraw) {
                DllCall("SendMessage", "Ptr", this.gui.Hwnd, "UInt", 0x000B, "Int", 1, "Int", 0) ; WM_SETREDRAW = 0x000B
                ; No explicit WinRedraw needed here usually
            }
        }
    }
}

; ==============================================================================
; Sub Grid Overlay Class (Separate Window)
; ==============================================================================
class SubGridOverlay {
    __New(cellX, cellY, cellWidth, cellHeight) {
        ; Create a new separate window for the sub-grid
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
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
        WinSetTransColor("222222 220", this.gui)
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
}

; ==============================================================================
; Global Helper Functions (Defined before use in hotkeys)
; ==============================================================================
Cleanup() {
    if (IsObject(State.subGridOverlay)) {
        State.subGridOverlay.Destroy() ; Destroy the separate sub-grid window if it exists
        State.subGridOverlay := ""
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
    if (State.subGridActive) {
        if (IsObject(State.subGridOverlay)) {
            State.subGridOverlay.Destroy() ; Destroy the separate sub-grid window
            State.subGridOverlay := ""
        }
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
            ; --- MOUSE MOVE ON FIRST KEY START ---
            firstRowKey := State.activeRowKeys[1] ; Get the first key defined for rows
            firstCellInColKey := key . firstRowKey
            boundaries := State.currentOverlay.GetCellBoundaries(firstCellInColKey)
            if (IsObject(boundaries)) {
                MouseGetPos(, &currentY) ; Get current mouse Y
                targetX := boundaries.x + (boundaries.w // 2) ; Center of the first cell in the column
                MouseMove(targetX, currentY, 0) ; Move instantly horizontally
            }
            ; --- MOUSE MOVE ON FIRST KEY END ---

            ; Clear any previous sub-grid if it exists (logic moved slightly)
            if (State.subGridActive) {
                State.currentOverlay.HideSubGrid()
                State.subGridActive := false
                State.activeCellKey := ""
            }

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
                ; Clear any existing sub-grid first
                if (State.subGridActive && IsObject(State.subGridOverlay)) {
                    State.subGridOverlay.Destroy()
                    State.subGridOverlay := ""
                }

                ; Move mouse to center
                centerX := boundaries.x + (boundaries.w // 2)
                centerY := boundaries.y + (boundaries.h // 2)
                MouseMove(centerX, centerY, 0)

                ; Create and show a new separate SubGridOverlay window
                State.subGridOverlay := SubGridOverlay(
                    boundaries.x, boundaries.y,
                    boundaries.w, boundaries.h
                )
                State.subGridOverlay.Show()

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
#HotIf State.isVisible || State.subGridActive ; <--- ADD THIS CONDITION
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
#HotIf ; <--- ADD THIS TO CLOSE THE NEW CONDITION
#HotIf ; This one closes the outer context if needed, or does nothing if already closed.
