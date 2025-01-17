#Requires AutoHotkey v2.0

; Create overlay GUI
class GridOverlay {
    static gui := false
    static cellSize := 100
    static rows := 10
    static cols := 16

    static LetterToNumber(letter) {
        return Ord(letter) - Ord("A")
    }

    static Show() {
        if !this.gui {
            this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
            this.gui.BackColor := "FFFFFF"
            this.gui.SetFont("s20", "Arial")

            ; Calculate screen dimensions
            monitorWidth := A_ScreenWidth
            monitorHeight := A_ScreenHeight

            ; Create semi-transparent overlay
            this.gui.Add("Picture", "w" monitorWidth " h" monitorHeight)

            ; Add grid labels
            letters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
            colLetters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]

            for row in letters {
                for col in colLetters {
                    x := this.LetterToNumber(col) * this.cellSize
                    y := this.LetterToNumber(row) * this.cellSize
                    this.gui.Add("Text", "x" x " y" y " w" this.cellSize " h" this.cellSize " Center", row col)
                }
            }

            this.gui.Opt("+E0x20") ; Click-through
            WinSetTransColor("FFFFFF 150", this.gui)
        }
        this.gui.Show("NoActivate")
    }

    static Hide() {
        if this.gui
            this.gui.Hide()
    }

    static GetCellPosition(cell) {
        if (StrLen(cell) != 2)
            return false

        row := SubStr(cell, 1, 1)
        col := SubStr(cell, 2, 1)

        x := this.LetterToNumber(col) * this.cellSize + this.cellSize / 2
        y := this.LetterToNumber(row) * this.cellSize + this.cellSize / 2

        return [x, y]
    }
}

#HotIf GetKeyState('CapsLock', 'P')
; Hotkey to activate grid
~Alt:: {
    static isActive := false
    static firstKey := ""

    if !isActive {
        GridOverlay.Show()
        isActive := true
        firstKey := ""

        ; Create input hook for capturing keystrokes
        ih := InputHook("L1")
        ih.Start()

        while isActive {
            if ih.Wait() {
                key := ih.Input

                if !firstKey {
                    firstKey := key
                    ih.Start()
                } else {
                    targetCell := firstKey key
                    pos := GridOverlay.GetCellPosition(targetCell)
                    if pos {
                        MouseMove(pos[1], pos[2])
                        isActive := false
                        GridOverlay.Hide()
                        break
                    }
                }
            }
        }
    }
}
#HotIf
; Space to click when grid is active
~Space:: {
    if WinExist("ahk_class AutoHotkeyGUI")
        Click
}

; Escape to cancel
~Escape:: {
    if WinExist("ahk_class AutoHotkeyGUI") {
        GridOverlay.Hide()
        return
    }
}
