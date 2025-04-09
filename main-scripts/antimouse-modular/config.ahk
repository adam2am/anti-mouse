; ==============================================================================
; config.ahk - Global Static Configuration Settings
; ==============================================================================

; --- General Behavior ---
global showcaseDebug := false       ; Enable debug tooltips and delays
global selectedLayout := 2            ; Layout options: 1=User QWERTY/ASDF, 2=ergonomics for diff hands, 3=WASD/QWER
global storePerMonitor := true      ; Store subcell positions per monitor
global instaClickMode := false      ; Track if we're in instaclick mode (hold-release click)
global doubleCapsThreshold := 400   ; Time in ms for double CapsLock detection
global stateTransitionDelay := 50   ; Minimum time (ms) between state transitions to prevent leakage
global saveMemoryOnExit := true     ; Save cell memory when deactivating grid
global keepGridVisible := false     ; Keep grid visible when showing subgrid for easier multi-cell navigation

; --- Ultra-Fast Subgrid Settings ---
global enableUltraFast := true      ; Enable/disable Ultra-Fast Subgrid mode
global rowKeyHoldThreshold := 150   ; Time in ms to detect a row key hold
global ultraFastSubGridKeys := ["q", "w", "e", "r", "a", "s", "d", "f", "z", "x", "c", "v"]  ; Ultra-fast grid keys
global ultraFastRows := 3           ; Number of rows in ultra-fast grid
global ultraFastCols := 4           ; Number of columns in ultra-fast grid

; --- Appearance ---
global defaultTransparency := 180   ; Transparency level (0-255, 255=opaque)
global highlightColor := "33AAFF"   ; Highlight color for selected cells

; --- File Paths ---
global cellMemoryFile := A_ScriptDir "\cell_memory.txt" ; File to store cell-subcell selections
global settingsFile := A_ScriptDir "\antimouse_settings.ini" ; File to store settings

; --- Monitor Mapping ---
; Map physical monitor index to logical: [physical1, physical2, physical3, physical4]
; Example: If physical monitor 2 is your main, set monitorMapping := [2, 1, 3, 4]
global monitorMapping := [2, 1, 3, 4]

; --- Layout Configurations ---
; Defines the grid dimensions and key mappings for different layouts.
global layoutConfigs := Map(
    1, Map("cols", 8, "rows", 10, "colKeys", ["q", "w", "e", "r", "u", "i", "o", "p"], "rowKeys", ["a", "s",
        "d", "f", "g", "h", "j", "k", "l", ";"]),
    2, Map("cols", 12, "rows", 11, "colKeys", ["q", "w", "e", "r", "a", "s", "d", "f", "z", "x", "c", "v",
    ],
    "rowKeys", ["u", "i", "o", "p", "j", "k", "l", ";", "m", ".", "/"]),
    3, Map("cols", 4, "rows", 4, "colKeys", ["a", "s", "d", "f"], "rowKeys", ["j", "k", "lq", ";"]),
    4, Map("cols", 4, "rows", 4, "colKeys", ["q", "w", "e", "r"], "rowKeys", ["a", "s", "d", "f"])
)

; --- Sub-grid Configuration ---
global subGridKeys := ["g", "h", "b", "n"] ; Keys used to select sub-cells
global subGridRows := 2                     ; Number of rows in the sub-grid
global subGridCols := 2                     ; Number of columns in the sub-grid
