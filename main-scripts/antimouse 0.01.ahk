#Requires AutoHotkey v2.0
; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state
class State {
    static isGridActive := false
    static firstKey := ""
    static currentColumn := ""
    static cellReached := false
    static currentMonitor := 1
}

class GridOverlay {
    static guis := Map()
    static cells := Map()
    static columnCenters := Map()
    static monitorInfo := Map()

    static Init() {
        this.guis.Clear()  ; Clear existing GUIs
        this.cells.Clear() ; Clear existing cells
        this.columnCenters.Clear()
        this.monitorInfo.Clear()

        loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &Left, &Top, &Right, &Bottom)
            this.monitorInfo[A_Index] := {
                left: Left,
                top: Top,
                right: Right,
                bottom: Bottom,
                width: Right - Left,
                height: Bottom - Top
            }
        }
    }

    static Show() {
        this.Init()  ; Always reinitialize when showing

        for monitorIndex, info in this.monitorInfo {
            this.CreateMonitorGrid(monitorIndex, info)
        }

        currentMonitor := this.GetCurrentMonitor()
        State.currentMonitor := currentMonitor

        for index, gui in this.guis {
            gui.gui.Show("NoActivate")
        }

        State.isGridActive := true
        this.ResetState()
    }

    static CreateMonitorGrid(monitorIndex, monitorInfo) {
        global thisGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        cols := 13
        rows := 13
        cellWidth := monitorInfo.width // cols
        cellHeight := monitorInfo.height // rows

        thisGui.BackColor := "000000"
        thisGui.SetFont("s" Min(cellWidth, cellHeight) // 4, "Arial")

        ; Create semi-transparent overlay
        thisGui.Add("Picture", "w" monitorInfo.width " h" monitorInfo.height)

        ; Create column highlight overlay (initially hidden)
        columnHighlight := thisGui.Add("Progress",
            "x0 y0 w" cellWidth " h" monitorInfo.height " Hidden Background00FF00")

        ; Create cell highlight overlay (initially hidden)
        cellHighlight := thisGui.Add("Progress",
            "x0 y0 w" cellWidth " h" cellHeight " Hidden Background0099FF")

        ; First letters (horizontal columns)
        ; todo: potential layout here is Tab, q,w,e,r,t,y,u,i,o,p,[,]
        colLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]
        ; Second letters (vertical rows)
        rowLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]

        ; Store GUI information
        this.guis[monitorIndex] := {
            gui: thisGui,
            columnHighlight: columnHighlight,
            cellHighlight: cellHighlight
        }

        ; Loop through horizontal positions first (columns)
        for horizIndex, firstLetter in colLetters {
            x := (horizIndex - 1) * cellWidth

            ; Store column center positions for instant movement
            this.columnCenters[monitorIndex "_" firstLetter] := {
                x: x + cellWidth / 2 + monitorInfo.left,
                width: cellWidth,
                left: x
            }

            ; Then through vertical positions (rows)
            for vertIndex, secondLetter in rowLetters {
                y := (vertIndex - 1) * cellHeight

                ; Create cell key with monitor index and coordinates
                cellKey := monitorIndex "_" firstLetter secondLetter
                this.cells[cellKey] := {
                    x: x + cellWidth / 2 + monitorInfo.left,
                    y: y + cellHeight / 2 + monitorInfo.top,
                    left: x,
                    top: y,
                    width: cellWidth,
                    height: cellHeight
                }

                ; Display coordinates with monitor number
                thisGui.Add("Text",
                    "x" x " y" y
                    " w" cellWidth " h" cellHeight
                    " Center BackgroundTrans cWhite",
                    monitorIndex ":" firstLetter secondLetter)
            }
        }

        thisGui.Opt("+E0x20")  ; Click-through
        WinSetTransColor("000000 200", thisGui)

        ; Position the GUI on the correct monitor
        thisGui.Move(monitorInfo.left, monitorInfo.top)
    }

    static GetCurrentMonitor() {
        MouseGetPos(&mouseX, &mouseY)
        for index, info in this.monitorInfo {
            if (mouseX >= info.left && mouseX < info.right &&
                mouseY >= info.top && mouseY < info.bottom) {
                return index
            }
        }
        return 1  ; Default to first monitor
    }

    static Hide() {
        if this.guis.Count {
            for index, gui in this.guis {
                gui.gui.Hide()
            }
            this.ResetState()
            State.isGridActive := false  ; Ensure grid mode is completely disabled
        }
    }

    static ResetState() {
        State.firstKey := ""
        State.currentColumn := ""
        State.cellReached := false
        this.HideHighlights()
    }

    static HideHighlights() {
        for index, gui in this.guis {
            gui.columnHighlight.Visible := false
            gui.cellHighlight.Visible := false
        }
    }

    static HighlightColumn(letter) {
        if this.columnCenters.Has(State.currentMonitor "_" letter) {
            col := this.columnCenters[State.currentMonitor "_" letter]
            this.guis[State.currentMonitor].columnHighlight.Move(col.left, 0)
            this.guis[State.currentMonitor].columnHighlight.Visible := true
        }
    }

    static HighlightCell(cell) {
        if this.cells.Has(State.currentMonitor "_" cell) {
            pos := this.cells[State.currentMonitor "_" cell]
            this.guis[State.currentMonitor].cellHighlight.Move(pos.left, pos.top)
            this.guis[State.currentMonitor].cellHighlight.Visible := true
        }
    }

    static MoveToColumn(letter) {
        if this.columnCenters.Has(State.currentMonitor "_" letter) {
            col := this.columnCenters[State.currentMonitor "_" letter]
            MouseMove(col.x, this.monitorInfo[State.currentMonitor].top + this.monitorInfo[State.currentMonitor].height /
                2)
            this.HighlightColumn(letter)
            State.currentColumn := letter
            return true
        }
        return false
    }

    static MoveTo(cell) {
        if this.cells.Has(State.currentMonitor "_" cell) {
            pos := this.cells[State.currentMonitor "_" cell]
            MouseMove(pos.x, pos.y)
            this.HighlightCell(cell)
            State.cellReached := true
            return true
        }
        return false
    }
}

#HotIf GetKeyState('CapsLock', 'P')
SetCapsLockState("AlwaysOff")

Alt:: {
    if !State.isGridActive {
        GridOverlay.Show()
    }
}
#HotIf

; Define hotkeys that only work when grid is active
#HotIf State.isGridActive

; Handle letter keys
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
N:: HandleKey("N")
O:: HandleKey("O")
P:: HandleKey("P")

; Handle number keys for monitor selection
1:: SelectMonitor(1)
2:: SelectMonitor(2)
3:: SelectMonitor(3)
4:: SelectMonitor(4)

; Click handlers
Space:: {
    Click
    GridOverlay.Hide()
}

RButton:: {
    Click "Right"
    GridOverlay.Hide()
}

; Cancel grid
Escape:: GridOverlay.Hide()

#HotIf

SelectMonitor(number) {
    if (number <= MonitorGetCount()) {
        State.currentMonitor := number
        if (State.currentColumn != "") {
            GridOverlay.MoveToColumn(State.currentColumn)
        }
    }
}

HandleKey(key) {
    if State.firstKey = "" {
        if GridOverlay.MoveToColumn(key) {
            State.firstKey := key
        }
    } else if !State.cellReached {
        targetCell := State.firstKey key
        GridOverlay.MoveTo(targetCell)
    }
}
