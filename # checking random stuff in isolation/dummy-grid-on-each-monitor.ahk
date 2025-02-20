#Requires AutoHotkey v2.0

#Requires AutoHotkey v2.0

; Create the overlay GUI class
class OverlayGUI {
    __New() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        this.gui.BackColor := "FFFFFF"
        this.gui.Opt("+E0x20")  ; Click-through
    }

    Show(x, y, w, h) {
        this.gui.Show(Format("x{} y{} w{} h{}", x, y, w, h))
    }

    Hide() {
        this.gui.Hide()
    }
}

; Store overlay GUIs
overlays := []

; Hotkey: CapsLock + H
CapsLock & h:: {
    ; Toggle state
    static isVisible := false

    if (isVisible) {
        ; Hide all overlays
        for overlay in overlays
            overlay.Hide()
        isVisible := false
        return
    }

    ; Clear existing overlays
    overlays := []

    ; Get monitor info
    monitorCount := MonitorGetCount()

    ; Create overlay for each monitor
    loop monitorCount {
        ; Variables to store monitor dimensions
        Left := 0
        Top := 0
        Right := 0
        Bottom := 0

        ; Get monitor bounds
        MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)

        width := Right - Left
        height := Bottom - Top

        ; Create new overlay
        overlay := OverlayGUI()
        overlay.Show(Left, Top, width, height)
        overlays.Push(overlay)
    }

    isVisible := true
}
