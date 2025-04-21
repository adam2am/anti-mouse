; ==============================================================================
; S1.6.1_fix.ahk - Fix for Missing Highlight during navigation
; ==============================================================================

/*
This file addresses Task S1.6.1 - Fix Missing Highlight:
Ensure the highlight overlay appears and updates correctly during both hover and key navigation.

Issues identified:
1. Highlight sometimes fails to appear after key navigation
2. Highlight sometimes fails to update properly during hover
3. Inconsistent visibility when transitioning between states

The fixes ensure that:
a) Highlight object existence is verified before any operation
b) Update operations are properly followed by Show operations
c) Add ForceShow method to guarantee visibility
d) Improve error handling and logging
*/

; ======================
; FIXES FOR tracking.ahk
; ======================

; 1. Add ForceShow method to HighlightOverlay class (if not already present)
/*
ForceShow() {
    try {
        this.gui.Show("NA")
        return true
    } catch as err {
        LogToFile(Format("ERROR: highlight.ForceShow failed: {}", err.Message), "antimouse_fix.log")
        return false
    }
}
*/

; 2. Modify the highlight update section in TrackCursor for GRID_VISIBLE state
; Find the section that looks like:
/*
if (IsObject(boundaries)) {
    ; --- Task 1.6: Update and show the highlight for the new cell ---
    if (IsObject(highlight)) {
        try {
            highlight.Update(boundaries.x, boundaries.y, boundaries.w, boundaries.h)

            ; --- 5.13.1: VISUAL DEBUGGING ---
            LogToFile("5.13.1 DEBUG | TrackCursor - Successfully called highlight.Update()",
                "antimouse_fix.log")

            ; Force visibility check
            try {
                highlight.ForceShow() ; Method added for debugging

                ; --- 5.13.1: VISUAL DEBUGGING ---
                LogToFile(
                    "5.13.1 DEBUG | TrackCursor - Successfully called highlight.ForceShow()",
                    "antimouse_fix.log")
            } catch as err {
                ; Try a fallback showing method if ForceShow fails
                try {
                    highlight.gui.Show()
*/
; ENHANCEMENT: Add this block after highlight.Update():
LogToFile("S1.6.1 FIX | TrackCursor | Ensuring highlight visibility", "antimouse_fix.log")
; Ensure highlight is visible after update
try {
    ; First try to use ForceShow if available
    if (IsFunc(highlight.ForceShow.Bind(highlight))) {
        highlight.ForceShow()
        LogToFile("S1.6.1 FIX | TrackCursor | Used highlight.ForceShow()", "antimouse_fix.log")
    } else {
        ; Fallback to regular Show if ForceShow unavailable
        highlight.gui.Show("NA")
        LogToFile("S1.6.1 FIX | TrackCursor | Used highlight.gui.Show()", "antimouse_fix.log")
    }
} catch as visErr {
    LogToFile(Format("S1.6.1 FIX | TrackCursor | ERROR forcing highlight visibility: {}",
        visErr.Message), "antimouse_fix.log")

    ; Last-resort attempt to make highlight visible
    try {
        WinShow("ahk_id " highlight.gui.Hwnd)
        LogToFile("S1.6.1 FIX | TrackCursor | Used WinShow as last resort", "antimouse_fix.log")
    } catch {
        ; Nothing more we can try at this point
    }
}

; ======================
; FIXES FOR grid_keys.ahk
; ======================

; 1. Enhance HandleFirstKey to ensure highlight appears after update
; After the highlight.Update() call, add:
LogToFile("S1.6.1 FIX | HandleFirstKey | Ensuring highlight visibility", "antimouse_fix.log")

; Explicitly ensure highlight visibility
try {
    ; Try multiple showing approaches in sequence until one works
    try {
        if (IsFunc(highlight.ForceShow.Bind(highlight))) {
            highlight.ForceShow()
            LogToFile("S1.6.1 FIX | HandleFirstKey | Used highlight.ForceShow()", "antimouse_fix.log")
        } else {
            highlight.gui.Show("NA")
            LogToFile("S1.6.1 FIX | HandleFirstKey | Used highlight.gui.Show()", "antimouse_fix.log")
        }
    } catch {
        ; Try using WinShow as fallback
        try {
            WinShow("ahk_id " highlight.gui.Hwnd)
            LogToFile("S1.6.1 FIX | HandleFirstKey | Used WinShow", "antimouse_fix.log")
        } catch as innerErr {
            LogToFile(Format("S1.6.1 FIX | HandleFirstKey | WinShow failed: {}",
                innerErr.Message), "antimouse_fix.log")
        }
    }
} catch as err {
    LogToFile(Format("S1.6.1 FIX | HandleFirstKey | All visibility attempts failed: {}",
        err.Message), "antimouse_fix.log")
}

; 2. Similar enhancement for HandleSecondKey
; After the highlight.Update() call, add:
LogToFile("S1.6.1 FIX | HandleSecondKey | Ensuring highlight visibility", "antimouse_fix.log")

; Explicitly ensure highlight visibility
try {
    ; Try multiple showing approaches in sequence until one works
    try {
        if (IsFunc(highlight.ForceShow.Bind(highlight))) {
            highlight.ForceShow()
            LogToFile("S1.6.1 FIX | HandleSecondKey | Used highlight.ForceShow()", "antimouse_fix.log")
        } else {
            highlight.gui.Show("NA")
            LogToFile("S1.6.1 FIX | HandleSecondKey | Used highlight.gui.Show()", "antimouse_fix.log")
        }
    } catch {
        ; Try using WinShow as fallback
        try {
            WinShow("ahk_id " highlight.gui.Hwnd)
            LogToFile("S1.6.1 FIX | HandleSecondKey | Used WinShow", "antimouse_fix.log")
        } catch as innerErr {
            LogToFile(Format("S1.6.1 FIX | HandleSecondKey | WinShow failed: {}",
                innerErr.Message), "antimouse_fix.log")
        }
    }
} catch as err {
    LogToFile(Format("S1.6.1 FIX | HandleSecondKey | All visibility attempts failed: {}",
        err.Message), "antimouse_fix.log")
}

; ======================
; FIXES FOR state_transitions.ahk
; ======================

; 1. Modify TransitionToState function to ensure highlight visibility when entering SUBGRID states
; Find the section where it transitions to SUBGRID_STANDARD or SUBGRID_ULTRAFAST, add:
if (newState == State_SUBGRID_STANDARD || newState == State_SUBGRID_ULTRAFAST) {
    if (IsObject(highlight)) {
        LogToFile("S1.6.1 FIX | TransitionToState | Ensuring highlight visibility in subgrid state",
            "antimouse_fix.log")

        ; Explicitly make highlight visible during transition to subgrid
        try {
            if (IsFunc(highlight.ForceShow.Bind(highlight))) {
                highlight.ForceShow()
                LogToFile("S1.6.1 FIX | TransitionToState | Used highlight.ForceShow()", "antimouse_fix.log")
            } else {
                highlight.gui.Show("NA")
                LogToFile("S1.6.1 FIX | TransitionToState | Used highlight.gui.Show()", "antimouse_fix.log")
            }
        } catch as err {
            LogToFile(Format("S1.6.1 FIX | TransitionToState | Error showing highlight: {}",
                err.Message), "antimouse_fix.log")
        }
    }
}

; ======================
; IMPLEMENTATION NOTES
; ======================

/*
To implement these fixes:

1. Add the ForceShow method to HighlightOverlay class if not present
2. Update tracking.ahk to ensure highlight visibility after updates
3. Update grid_keys.ahk to ensure highlight visibility in both HandleFirstKey and HandleSecondKey
4. Update state_transitions.ahk to ensure highlight visibility during state transitions

These changes ensure that the highlight correctly appears and updates during both
hover navigation and key-based navigation, resolving the visibility issues.
*/
