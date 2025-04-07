# AntiMouse Script Structure and Logic Flow

This document outlines the modular structure of the refactored AntiMouse AutoHotkey script and its high-level logic flow.


## Directory Structure

All script modules reside within the `main-scripts/antimouse-modular/` directory:

```
main-scripts/antimouse-modular/
├── 1main.ahk             ; Main script entry point, includes, initialization
├── config.ahk            ; Global configuration variables (layouts, colors, paths, etc.)
├── state.ahk             ; State management (FSM, StateMap, GUI instances, memory)
├── utils.ahk             ; Utility functions (validation, GUI closing, type checks, CapsLock forcing)
├── gui_classes.ahk       ; Class definitions for GUI overlays (Highlight, SubGrid, Grid, OverlayGUI)
├── memory_settings.ahk   ; Functions for loading/saving cell memory and INI settings
├── core_logic.ahk        ; Core interaction logic (key handling, cursor tracking, monitor switching)
├── activation.ahk        ; Grid activation (CapsLock_Q) and cleanup logic
├── settings_gui.ahk      ; Settings GUI function and hotstring trigger
├── hotkeys.ahk           ; All hotkey definitions and #HotIf contexts
├── cell_memory.txt       ; Storage for remembered subcell positions
├── antimouse_settings.ini ; User configuration settings
└── debug_log.txt         ; Debug information (when debugging is enabled)
```


## Module Descriptions

*   **`1main.ahk`**: Initializes the script, sets global settings (`CoordMode`, `SetCapsLockState`), includes all other modules in the correct order, loads settings/memory, and starts the `ForceCapsLockOff` timer.

*   **`config.ahk`**: Centralizes all user-configurable and static settings like layout definitions, colors, file paths, timing thresholds, etc.

*   **`state.ahk`**: Declares and initializes global variables responsible for tracking the script's current state, including the Finite State Machine (`currentState`), the `StateMap` for dynamic grid info, GUI object placeholders (`highlight`, `subGrid`), and the `g_ModifierState` for CapsLock handling. Also contains variables for state transitions and grid activation prevention flags.

*   **`utils.ahk`**: Contains reusable helper functions like `ValidateIndex`, `ForceCloseAllGuis`, `IsInteger`, `IsNumber`, and the `ForceCapsLockOff` timer function.

*   **`gui_classes.ahk`**: Defines the object-oriented structure for the different GUI overlays used by the script, encapsulating their creation, update, hiding, and destruction logic.

*   **`memory_settings.ahk`**: Handles persistence. Contains functions (`LoadCellMemory`, `SaveCellMemory`, `LoadSettings`, `SaveSettings`) to read from and write to the `cell_memory.txt` and `antimouse_settings.ini` files.

*   **`core_logic.ahk`**: Implements the primary runtime logic, including functions to handle key presses within the grid/subgrid (`HandleKey`, `HandleSubGridKey`, `ProcessKeyPress`), determine cell positions (`GetCellAtPosition`), manage monitor switching (`SwitchMonitor`, `CycleToNextMonitor`), track the cursor (`TrackCursor`), and start new selections (`StartNewSelection`).

*   **`activation.ahk`**: Contains the main grid activation function (`CapsLock_Q`) responsible for initializing the state, creating GUI overlays, and transitioning to the `GRID_VISIBLE` state. Also includes the `Cleanup` function to reset the script to the `IDLE` state and destroy GUIs.

*   **`settings_gui.ahk`**: Defines the `ShowSettingsGUI` function to display the configuration window and the `:*:;settings::` hotstring to trigger it.

*   **`hotkeys.ahk`**: Defines all user-facing hotkeys using `#HotIf` directives to make them context-sensitive based on the `currentState` and `g_ModifierState`. This includes grid activation, navigation, monitor switching, CapsLock handling (tap, double-tap, hold), and functional keys (Space, Escape, Tab).



## Logic Flow

1.  **Initialization (`main.ahk`)**:
    *   Script starts, sets basic AHK settings.
    *   Includes all modules.
    *   `LoadSettings()` and `LoadCellMemory()` are called (from `memory_settings.ahk`).
    *   `ForceCapsLockOff` timer is started (function in `utils.ahk`).
    *   Script enters `IDLE` state (defined in `state.ahk`).
2.  **Idle State**:
    *   Script waits for activation hotkeys (defined in `hotkeys.ahk`).
    *   The `ForceCapsLockOff` timer runs periodically.
    *   `;settings` hotstring can trigger `ShowSettingsGUI` (from `settings_gui.ahk`).
3.  **Activation (e.g., CapsLock double-tap or CapsLock+Q)**:
    *   Relevant hotkey in `hotkeys.ahk` triggers `CapsLock_Q` (from `activation.ahk`).
    *   `CapsLock_Q` checks for duplicate activation requests using `gridActivationInProgress` flag.
    *   It resets state, loads memory, creates GUI instances (`HighlightOverlay`, `SubGridOverlay` from `gui_classes.ahk`).
    *   Creates `OverlayGUI` for each monitor, attempts to identify current monitor.
    *   Shows GUIs, sets `currentState` to `GRID_VISIBLE`, and starts the `TrackCursor` timer (function in `core_logic.ahk`).
4.  **Grid Visible State (`GRID_VISIBLE`)**:
    *   `TrackCursor` monitors mouse position. If the cursor moves over a cell, it updates `StateMap['activeCellKey']`, potentially transitions to `SUBGRID_ACTIVE`, and updates the highlight/subgrid GUIs.
    *   Grid navigation keys (q, w, a, s, etc.) trigger `ProcessKeyPress` -> `HandleKey` (from `core_logic.ahk`).
        *   First key press: Selects a column or row, moves cursor/highlight, waits for the second key. `StateMap['firstKey']` is set.
        *   Second key press: Completes cell selection. `StateMap['activeCellKey']` is set, state transitions to `SUBGRID_ACTIVE`, subgrid GUI is updated/shown. `StateMap['firstKey']` is cleared.
    *   Monitor switching keys (1-4, Tab, CapsLock+N) trigger `SwitchMonitor` or `CycleToNextMonitor` (from `core_logic.ahk`).
    *   `Escape` or single `CapsLock` tap triggers `Cleanup` (from `activation.ahk`).
    *   `Space` triggers click at the current subgrid/cell center and then `Cleanup`.
5.  **Subgrid Active State (`SUBGRID_ACTIVE`)**:
    *   `TrackCursor` continues to monitor mouse position. If the cursor moves to a *different* cell, state remains `SUBGRID_ACTIVE`, but `activeCellKey` and GUIs update.
    *   Subgrid navigation keys (g, h, b, n) trigger `ProcessKeyPress` -> `HandleSubGridKey` (from `core_logic.ahk`), moving the cursor to the subcell center and potentially saving the selection via `SaveCellMemory`.
    *   *Other* grid keys (q, w, a, s, etc.) trigger `ProcessKeyPress` -> `StartNewSelection` (from `core_logic.ahk`), which resets state back to `GRID_VISIBLE` and processes the key as the *first* key of a new selection.
    *   Monitor switching keys work as in `GRID_VISIBLE`.
    *   `Escape`, single `CapsLock` tap, or `Space` trigger cleanup/click+cleanup as in `GRID_VISIBLE`.
6.  **InstaClick (Hold Mode)**:
    *   Entering hold mode (`g_ModifierState.inHoldMode = true`) is typically triggered by CapsLock double-tap, CapsLock+Q, or CapsLock+MonitorNumber (`hotkeys.ahk`).
    *   When `CapsLock Up` occurs while `inHoldMode` is true and the state is not `IDLE`, a left click is performed at the current cursor position, followed by `Cleanup`.
    *   `instaClickMode` setting (from config) allows processing key events even when CapsLock is physically held for the click release.
7.  **Monitor Switching**:
    *   Can be triggered directly via hotkeys (1-4 when grid is active, or CapsLock+1-4 from any state).
    *   When switching monitors, the script attempts to preserve the same cell position on the new monitor.
    *   If cursor tracking detects movement to a different monitor, it can also trigger monitor switching and reset cell selection.
8.  **Cleanup (`activation.ahk`)**:
    *   Called by `Escape`, `Space`, single `CapsLock` tap, or on error.
    *   Stops `TrackCursor` timer.
    *   Sets `currentState` to `IDLE`.
    *   Resets relevant state flags (`inHoldMode`, `firstKey`, `gridActivationInProgress`, etc.).
    *   Hides and destroys all GUI elements (`highlight`, `subGrid`, all overlays).
    *   Resets global GUI object variables (`highlight`, `subGrid`, `StateMap['overlays']`).
    *   Calls `ForceCloseAllGuis` (from `utils.ahk`) as a final measure.

This modular structure separates concerns, making the script easier to understand, maintain, and extend.
