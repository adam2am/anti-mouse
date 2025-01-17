#Requires AutoHotkey v2.0
; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state
class State {
    static isGridActive := false
    static firstKey := ""
}

class GridOverlay {
    static gui := false
    static cells := Map()

    static Show() {
        if !this.gui {
            ; Calculate grid dimensions based on screen
            monitorWidth := A_ScreenWidth
            monitorHeight := A_ScreenHeight

            cols := 16  ; Number of columns (A-P)
            rows := 10  ; Number of rows (A-J)

            cellWidth := monitorWidth // cols
            cellHeight := monitorHeight // rows

            this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
            this.gui.BackColor := "000000"
            this.gui.SetFont("s" Min(cellWidth, cellHeight) // 4, "Arial")

            ; Create semi-transparent overlay
            this.gui.Add("Picture", "w" monitorWidth " h" monitorHeight)

            ; First letters (vertical columns A-J)
            colLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
            ; Second letters (horizontal rows A-P)
            rowLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]

            ; Loop through horizontal positions first
            for horizIndex, horizLetter in rowLetters {
                ; Then through vertical positions
                for vertIndex, vertLetter in colLetters {
                    x := (horizIndex - 1) * cellWidth
                    y := (vertIndex - 1) * cellHeight

                    ; Create cell key with vertical letter first
                    cellKey := vertLetter horizLetter
                    this.cells[cellKey] := {
                        x: x + cellWidth / 2,
                        y: y + cellHeight / 2
                    }

                    ; Display vertical letter first (AA, BA, CA, etc.)
                    this.gui.Add("Text",
                        "x" x " y" y
                        " w" cellWidth " h" cellHeight
                        " Center BackgroundTrans c0099FF",
                        vertLetter horizLetter)
                }
            }

            this.gui.Opt("+E0x20")  ; Click-through
            WinSetTransColor("000000 200", this.gui)
        }

        this.gui.Show("NoActivate")
        State.isGridActive := true
        State.firstKey := ""
    }

    static Hide() {
        if this.gui {
            this.gui.Hide()
            State.isGridActive := false
            State.firstKey := ""
        }
    }

    static MoveTo(cell) {
        if this.cells.Has(cell) {
            pos := this.cells[cell]
            MouseMove(pos.x, pos.y)
            return true
        }
        return false
    }
}

; Main hotkey to activate grid
CapsLock & Alt:: {
    if !State.isGridActive {
        GridOverlay.Show()
    }
}

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

HandleKey(key) {
    if State.firstKey = "" {
        State.firstKey := key
        return
    }

    targetCell := State.firstKey key
    if GridOverlay.MoveTo(targetCell) {
        State.firstKey := ""
    }
}
