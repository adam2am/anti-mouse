#Requires AutoHotkey v2.0
; Ensure CapsLock doesn't accidentally get turned on
SetCapsLockState("AlwaysOff")

; Global state
class State {
    static isGridActive := false
    static firstKey := ""
    static currentColumn := ""
    static cellReached := false
}

class GridOverlay {
    static gui := false
    static cells := Map()
    static columnCenters := Map()

    static Show() {
        if !this.gui {
            ; Calculate grid dimensions based on screen
            monitorWidth := A_ScreenWidth
            monitorHeight := A_ScreenHeight

            cols := 13  ; Number of columns (AA, BA, CA, etc.)
            rows := 13  ; Number of rows (AA, AB, AC, etc.)

            cellWidth := monitorWidth // cols
            cellHeight := monitorHeight // rows

            this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
            this.gui.BackColor := "000000"
            this.gui.SetFont("s" Min(cellWidth, cellHeight) // 4, "Arial")

            ; Create semi-transparent overlay
            this.gui.Add("Picture", "w" monitorWidth " h" monitorHeight)

            ; First letters (horizontal columns AA, BA, CA, etc.)
            colLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]
            ; Second letters (vertical rows AA, AB, AC, etc.)
            rowLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]

            ; Loop through horizontal positions first (columns)
            for horizIndex, firstLetter in colLetters {
                x := (horizIndex - 1) * cellWidth
                ; Store column center positions for instant movement
                this.columnCenters[firstLetter] := x + cellWidth / 2

                ; Then through vertical positions (rows)
                for vertIndex, secondLetter in rowLetters {
                    y := (vertIndex - 1) * cellHeight

                    ; Create cell key with first letter from column, second letter from row
                    cellKey := firstLetter secondLetter
                    this.cells[cellKey] := {
                        x: x + cellWidth / 2,
                        y: y + cellHeight / 2
                    }

                    ; Display coordinates with first letter from column, second letter from row
                    this.gui.Add("Text",
                        "x" x " y" y
                        " w" cellWidth " h" cellHeight
                        " Center BackgroundTrans c0099FF",
                        firstLetter secondLetter)
                }
            }

            this.gui.Opt("+E0x20")  ; Click-through
            WinSetTransColor("000000 200", this.gui)
        }

        this.gui.Show("NoActivate")
        this.ResetState()
    }

    static Hide() {
        if this.gui {
            this.gui.Hide()
            this.ResetState()
        }
    }

    static ResetState() {
        State.isGridActive := true
        State.firstKey := ""
        State.currentColumn := ""
        State.cellReached := false
    }

    static MoveToColumn(letter) {
        if this.columnCenters.Has(letter) {
            MouseGetPos(&currentX, &currentY)
            MouseMove(this.columnCenters[letter], currentY)
            State.currentColumn := letter
            return true
        }
        return false
    }

    static MoveTo(cell) {
        if this.cells.Has(cell) {
            pos := this.cells[cell]
            MouseMove(pos.x, pos.y)
            ; Reset state after successful movement to allow new movements
            this.ResetState()
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
        ; Move to column immediately on first key press
        if GridOverlay.MoveToColumn(key) {
            State.firstKey := key
        }
        return
    }

    ; Create and move to target cell
    targetCell := State.currentColumn key
    GridOverlay.MoveTo(targetCell)
}
