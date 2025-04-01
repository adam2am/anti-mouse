#Requires AutoHotkey v2.0
SetCapsLockState("AlwaysOff")
CoordMode "Mouse", "Screen" ; Ensure mouse coordinates are relative to the virtual screen

global showcaseDebug := false ; Set to true to enable debug tooltips and delays

class OverlayGUI {
    __New(monitorIndex, Left, Top, Right, Bottom) {
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

        this.cols := 13
        this.rows := 13
        this.cellWidth := this.width // this.cols
        this.cellHeight := this.height // this.rows

        this.cells := Map()
        this.gui.SetFont("s" Min(this.cellWidth, this.cellHeight) // 4, "Arial")
        this.gui.Add("Picture", "w" this.width " h" this.height)

        colLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]
        rowLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]

        for colIndex, firstLetter in colLetters {
            x := (colIndex - 1) * this.cellWidth
            for rowIndex, secondLetter in rowLetters {
                y := (rowIndex - 1) * this.cellHeight
                cellKey := firstLetter secondLetter
                this.cells[cellKey] := {
                    x: Left + x + (this.cellWidth // 2),
                    y: Top + y + (this.cellHeight // 2)
                }
                this.gui.Add("Text",
                    "x" x " y" y
                    " w" this.cellWidth " h" this.cellHeight
                    " Center BackgroundTrans cWhite",
                    monitorIndex ":" firstLetter secondLetter)
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
        this.gui.Hide()
    }

    MoveToCellCenter(cellKey) {
        if this.cells.Has(cellKey) {
            coord := this.cells[cellKey]
            MouseMove(coord.x, coord.y, 0)  ; Absolute coordinates
            return true
        }
        ToolTip "Cell not found: " cellKey
        return false
    }

    ContainsPoint(x, y) {
        checkResult := (x >= this.Left && x < this.Right && y >= this.Top && y < this.Bottom)
        ; DEBUG: Show the exact check being performed
        if (showcaseDebug) {
            ToolTip("Checking Monitor " this.monitorIndex ": Point(" x "," y ") in Bounds(" this.Left "," this.Top "," this
                .Right "," this.Bottom ")? -> " checkResult, , , 3) ; Use ToolTip ID 3
            Sleep 1500 ; Give time to read
            ToolTip(, , , 3) ; Clear tooltip 3
        }
        ; Validation: Uncomment to log point and boundaries for debugging
        ; ToolTip "Checking X=" x " Y=" y " vs L=" this.Left " T=" this.Top " R=" Right " B=" Bottom
        return checkResult
    }
}

class State {
    static overlays := []
    static isVisible := false
    static firstKey := ""
    static currentOverlay := ""
}

CapsLock & h:: {
    if (State.isVisible) {
        for overlay in State.overlays
            overlay.Hide()
        State.isVisible := false
        State.firstKey := ""
        State.currentOverlay := ""
        ToolTip
        SetTimer(TrackCursor, 0)
        return
    }

    State.overlays := []
    MouseGetPos(&startX, &startY)
    ; Validation: Display initial cursor position for debugging
    ToolTip "Start X=" startX " Y=" startY, 100, 100

    loop MonitorGetCount() {
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
        ; DEBUG: Show assigned index and coordinates
        if (showcaseDebug) {
            ToolTip("Monitor " A_Index " assigned: L=" Left " T=" Top " R=" Right " B=" Bottom, , , 1) ; Use ToolTip ID 1
            Sleep 1500 ; Give time to read the tooltip
            ToolTip(, , , 1) ; Clear tooltip 1
        }
        ; Validation: Log monitor boundaries to ensure they're correct
        ; ToolTip "Monitor " A_Index ": L=" Left " T=" Top " R=" Right " B=" Bottom, 200, 100 + (A_Index * 20)

        overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom)
        overlay.Show()
        State.overlays.Push(overlay)

        if (overlay.ContainsPoint(startX, startY)) {
            State.currentOverlay := overlay
            ; Validation: Confirm detected monitor
            ToolTip "Detected Monitor " overlay.monitorIndex " at X=" startX " Y=" startY, 100, 100
        }
    }

    ; Improved Fallback: Default to primary monitor (contains 0,0) if detection fails
    if (!State.currentOverlay && State.overlays.Length > 0) {
        for overlay in State.overlays {
            if (overlay.ContainsPoint(0, 0)) {
                State.currentOverlay := overlay
                ToolTip "Fallback to Monitor " overlay.monitorIndex " (Primary)", 100, 100
                break
            }
        }
        if (!State.currentOverlay) {
            State.currentOverlay := State.overlays[1]
            ToolTip "Last Resort: Monitor 1", 100, 100
        }
    }

    if (State.currentOverlay) {
        State.isVisible := true
        SetTimer(TrackCursor, 50)
    } else {
        ToolTip "Error: No monitor detected", 100, 100
    }
}

TrackCursor() {
    if (!State.isVisible)
        return

    MouseGetPos(&x, &y)
    for overlay in State.overlays {
        if (overlay.ContainsPoint(x, y)) {
            if (State.currentOverlay !== overlay) {
                State.currentOverlay := overlay
                ; Validation: Confirm monitor switch detection
                ; ToolTip "Switched to Monitor " overlay.monitorIndex " at X=" x " Y=" y, 100, 100
            }
            return
        }
    }
}

#HotIf State.isVisible

A:: HandleKey("A")
B:: HandleKey("B")
C:: HandleKey("C")
D:: HandleKey("D")
E:: HandleKey("E")
F:: HandleKey("F")
G:: HandleKey("G")
H:: HandleKey("H")
I:: HandleKey("I")
J:: HandleKey("J")
K:: HandleKey("K")
L:: HandleKey("L")
M:: HandleKey("M")

1:: SwitchMonitor(1)
2:: SwitchMonitor(2)
3:: SwitchMonitor(3)
4:: SwitchMonitor(4)

Space:: {
    Click
    Cleanup()
}

RButton:: {
    Click "Right"
    Cleanup()
}

Escape:: {
    Cleanup()
}

Cleanup() {
    for overlay in State.overlays
        overlay.Hide()
    State.isVisible := false
    State.firstKey := ""
    State.currentOverlay := ""
    ToolTip
    SetTimer(TrackCursor, 0)
}

SwitchMonitor(monitorNum) {
    if (!State.isVisible || monitorNum > State.overlays.Length)
        return

    newOverlay := State.overlays[monitorNum]
    if (newOverlay && State.currentOverlay !== newOverlay) { ; Only move if switching monitors
        State.currentOverlay := newOverlay
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        ; DEBUG: Show target monitor index and calculated center coordinates
        if (showcaseDebug) {
            ToolTip("Switching to Monitor Index: " newOverlay.monitorIndex ". Target Coords: X=" centerX " Y=" centerY, , ,
                2) ; Use ToolTip ID 2
            Sleep 1500 ; Give time to read the tooltip
            ToolTip(, , , 2) ; Clear tooltip 2
        }
        ; Validation: Log calculated center to ensure it's within monitor bounds
        ; ToolTip "Switch to Monitor " newOverlay.monitorIndex " Center X=" centerX " Y=" centerY, 100, 100

        MouseMove(centerX, centerY, 0)
    } else {
        ; Validation: Confirm no movement when already on the target monitor
        ToolTip "Already on Monitor " (newOverlay ? newOverlay.monitorIndex : "None"), 100, 100
    }
}

#HotIf

HandleKey(key) {
    if (!State.isVisible || !State.currentOverlay)
        return

    if (State.firstKey = "") {
        State.firstKey := key
        ToolTip "First key: " key " on Monitor " State.currentOverlay.monitorIndex
    } else {
        cellKey := State.firstKey key
        if (State.currentOverlay.MoveToCellCenter(cellKey)) {
            ToolTip "Moved to: " cellKey " on Monitor " State.currentOverlay.monitorIndex
            Sleep 1000
            ToolTip
        }
        State.firstKey := ""
    }
}
