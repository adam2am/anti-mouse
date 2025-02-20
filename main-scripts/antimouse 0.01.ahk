#Requires AutoHotkey v2.0
SetCapsLockState("AlwaysOff")

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
        return (x >= this.Left && x < this.Right && y >= this.Top && y < this.Bottom)
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

    ; Create overlays and detect initial monitor
    loop MonitorGetCount() {
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
        overlay := OverlayGUI(A_Index, Left, Top, Right, Bottom)
        overlay.Show()
        State.overlays.Push(overlay)
        ; Explicitly check if cursor is within this monitor's bounds
        if (overlay.ContainsPoint(startX, startY)) {
            State.currentOverlay := overlay
            ToolTip "Started on Monitor " overlay.monitorIndex " at X:" startX " Y:" startY
        }
    }

    ; Fallback: if no overlay contains the cursor (edge case), default to first monitor
    if (!State.currentOverlay && State.overlays.Length > 0) {
        State.currentOverlay := State.overlays[1]
        ToolTip "Fallback to Monitor 1"
    }

    State.isVisible := true
    SetTimer(TrackCursor, 50)
}

TrackCursor() {
    if (!State.isVisible)
        return

    MouseGetPos(&x, &y)
    for overlay in State.overlays {
        if (overlay.ContainsPoint(x, y)) {
            if (State.currentOverlay !== overlay) {
                State.currentOverlay := overlay
                ToolTip "Moved to Monitor " overlay.monitorIndex " at X:" x " Y:" y
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

    ; Switch to the requested monitor
    newOverlay := State.overlays[monitorNum]
    if (newOverlay) {
        State.currentOverlay := newOverlay
        ; Move cursor to center of the selected monitor
        centerX := newOverlay.Left + (newOverlay.width // 2)
        centerY := newOverlay.Top + (newOverlay.height // 2)
        MouseMove(centerX, centerY, 0)
        ToolTip "Switched to Monitor " newOverlay.monitorIndex " at X:" centerX " Y:" centerY
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
