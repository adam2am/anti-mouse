Okay, let's break down the `antimouse-modular` script's logic flow based on the provided files.

## 1. Logical Function/Variable Flow

Here's a detailed breakdown of the execution flow, referencing the provided code files:

**A. Initialization (`1main.ahk`)**

1.  **AHK Setup:** Sets version requirement (`v2.0`), forces single instance, sets coordinate mode to `Screen`, ensures CapsLock is off (`SetCapsLockState "AlwaysOff"`).
2.  **Includes:** Loads modules in a specific order:
    *   `config.ahk`: Static configurations (layouts, thresholds, colors, file paths).
    *   `state.ahk`: State definitions (`State_IDLE`, etc.) and global state variables (`currentState`, `StateMap`, `g_ModifierState`, `highlight`, `subGrid`, `cellMemory`).
    *   `utils.ahk`: Utility functions (`ValidateIndex`, `ForceCloseAllGuis`, `LogToFile`, `ProcessLogQueue`).
    *   `gui_classes.ahk`: Class definitions (`GridOverlay`, `OverlayGUI`, `SubGridOverlay`, `HighlightOverlay`).
    *   `memory_settings.ahk`: Functions (`LoadSettings`, `SaveSettings`, `LoadCellMemory`, `SaveCellMemory`).
    *   `core/monitor.ahk`: `SwitchMonitor`, `CycleToNextMonitor`.
    *   `core/positioning.ahk`: `GetCellAtPosition`.
    *   `core/key_processing.ahk`: `ProcessKeyPress`, `CheckIfGridKey`, `IsSubGridKey`, `IsUltraFastSubGridKey`.
    *   `core/grid_keys.ahk`: `HandleKey`, `HandleFirstKey`, `HandleSecondKey`.
    *   `core/subgrid_keys.ahk`: `ProcessStandardSubgridKey`, `ProcessUltraFastKey`, `UpdateCellMemory`, `HandleRowKeyRelease`.
    *   `core/state_transitions.ahk`: `TransitionToState`, `StartNewSelection`.
    *   `core/tracking.ahk`: `TrackCursor`, `GetCurrentCell`, `ResetLastTrackedKey`.
    *   `activation.ahk`: `CapsLock_Q`, `Cleanup`, `DeactivateGrid`.
    *   `settings_gui.ahk`: `ShowSettingsGUI`, settings hotstring `:*:;settings::`.
    *   `hotkeys.ahk`: All `#HotIf` context-sensitive and global hotkeys.
3.  **Load Persistent Data:**
    *   Calls `LoadSettings()` (`memory_settings.ahk`): Reads `antimouse_settings.ini` into global config variables (`selectedLayout`, `storePerMonitor`, `showcaseDebug`, `monitorMapping`, `defaultTransparency`, `highlightColor`, `instaClickMode`, `enableUltraFast`, `rowKeyHoldThreshold`, `keepGridVisible`, etc.). Uses defaults from `config.ahk` if the file or keys don't exist.
    *   Calls `LoadCellMemory()` (`memory_settings.ahk`): Reads `cell_memory.txt` line by line (`cellKey=subCellKey`) into the global `cellMemory` Map.
4.  **Apply Initial Layout Config:** Reads `colKeys` and `rowKeys` from `layoutConfigs[selectedLayout]` (`config.ahk`) into global `activeColKeys` and `activeRowKeys`. Includes fallback to layout 1 if `selectedLayout` is invalid.
5.  **Start Timers:**
    *   `SetTimer(ProcessLogQueue, 300)` (`utils.ahk`): Starts the buffered logging timer to write `g_logQueue` contents to files periodically.
    *   `SetTimer(ForceCapsLockOff, 250)` (`utils.ahk`): Starts the timer to periodically check and force CapsLock off if it's toggled on.
6.  **Persist:** `Persistent()` keeps the script running indefinitely, waiting for hotkeys or timer events. `currentState` begins as `State_IDLE` (defined in `state.ahk`).

**B. Activation Flow (Example: CapsLock Double-Tap)**

1.  **Hotkey Trigger (`hotkeys.ahk`):**
    *   User presses CapsLock twice within `doubleCapsThreshold`.
    *   `CapsLock::` hotkey fires on each press. It uses the `g_ModifierState` map (`capsPressedFirstTime`, `capsFirstReleased`, `lastCapsUpTime`, `capsPressedSecondTime`) defined in `state.ahk` to track presses and releases.
    *   On the *second* press within the threshold (after the first has been released), it detects the double-tap.
    *   Sets `g_ModifierState.inHoldMode = true`.
    *   Calls `CapsLock_Q()` (`activation.ahk`).
2.  **`CapsLock_Q()` (`activation.ahk`):**
    *   **Guard Checks:** Uses `gridActivationInProgress` flag and `gridActivationTime` timestamp to prevent rapid re-activation. If already active (`currentState != State_IDLE`), calls `Cleanup()` and exits.
    *   **State Reset:** Sets `gridActivationInProgress = true`, `gridActivationTime = A_TickCount`. Resets relevant `StateMap` values (`firstKey`, `currentOverlay`, `activeColKeys`, `activeRowKeys`, `activeCellKey`, etc.), ultra-fast state (`inUltraFastMode`, `activeRowKey`), and `g_firstKeyPressed` (though `g_firstKeyPressed` seems redundant with `StateMap['firstKey']`).
    *   **Load/Config:** Reloads `cellMemory` via `LoadCellMemory()`. Gets the layout configuration (`layoutConfigs[selectedLayout]`). Sets `StateMap['activeColKeys']` and `StateMap['activeRowKeys']`.
    *   **GUI Initialization:** Creates `HighlightOverlay` and `SubGridOverlay` instances using classes from `gui_classes.ahk`. Stores them in global `highlight` and `subGrid` variables.
    *   **Overlay Creation:**
        *   Loops through monitors (`MonitorGetCount`).
        *   For each monitor, creates an `OverlayGUI` instance (`gui_classes.ahk`). This class internally creates a `GridOverlay`.
        *   Shows the `OverlayGUI` (`overlay.Show()`).
        *   Pushes the `OverlayGUI` object into `StateMap['overlays']` (an array).
        *   Checks if the initial mouse position (`startX`, `startY`) is within the current monitor's overlay (`overlay.ContainsPoint`). If yes, sets `StateMap['currentOverlay']` to this overlay object.
        *   If no monitor contains the mouse, defaults `StateMap['currentOverlay']` to the first overlay (`StateMap['overlays'][1]`).
    *   **Initial State Transition:** Calls `TransitionToState(State_GRID_VISIBLE)` (`core/state_transitions.ahk`). This sets `currentState` and runs entry actions for `GRID_VISIBLE` (showing main overlays via `overlay.Show()` within the transition function, hiding `highlight`/`subGrid`).
    *   **Instant Subgrid Activation (Task 2.17 FIX):**
        *   Calls `GetCurrentCell()` (`core/tracking.ahk`), which gets mouse pos and calls `GetCellAtPosition(x, y)` (`core/positioning.ahk`).
        *   `GetCellAtPosition` loops through cells in `StateMap['currentOverlay'].cells` (exposed from the underlying `GridOverlay`) to find the cell key under the cursor.
        *   If `initialCellKey` is found:
            *   Gets cell boundaries using `StateMap['currentOverlay'].GetCellBoundaries(initialCellKey)`.
            *   If boundaries are valid:
                *   Sets `StateMap['activeCellKey'] = initialCellKey`.
                *   Updates `highlight` position/visibility (`highlight.Update`).
                *   Updates `subGrid` position/geometry (`subGrid.Update`). **Crucially, `subGrid.Update` also applies the current layout (`standard` or `ultrafast`) based on `this.currentLayout`.**
                *   Calls `TransitionToState(State_SUBGRID_STANDARD)`. This changes `currentState` again and runs entry actions for `SUBGRID_STANDARD` (showing `highlight`/`subGrid`, possibly hiding main overlays based on `keepGridVisible`).
    *   **Start Tracking:** Calls `SetTimer(TrackCursor, 50)` (`core/tracking.ahk`).
    *   **Cleanup Flag:** Resets `gridActivationInProgress = false` on success or failure (within `try`/`catch`/`finally`).

**C. Key Processing Flow (Grid/Subgrid Active)**

1.  **Hotkey Trigger (`hotkeys.ahk`):** User presses a letter/symbol key (e.g., 'w', 'j', ';', 'g', 'q'). The corresponding hotkey (active via `#HotIf currentState != State_IDLE`) fires.
2.  **Central Router (`ProcessKeyPress` in `core/key_processing.ahk`):**
    *   Receives the `key`.
    *   Checks `currentState`:
        *   **`State_GRID_VISIBLE`:** Calls `CheckIfGridKey(key)`. If true, calls `HandleKey(key)` (`core/grid_keys.ahk`).
        *   **`State_SUBGRID_STANDARD`:**
            *   Checks `IsSubGridKey(key)` (g,h,b,n). If true, calls `ProcessStandardSubgridKey(key)` (`core/subgrid_keys.ahk`).
            *   If false, checks `CheckIfGridKey(key)`. If true, calls `StartNewSelection(key)` (`core/state_transitions.ahk`).
        *   **`State_SUBGRID_ULTRAFAST`:**
            *   Checks `IsUltraFastSubGridKey(key)` (qwerasdfzxcv). If true, calls `ProcessUltraFastKey(key)` (`core/subgrid_keys.ahk`).
            *   If false, checks `CheckIfGridKey(key)`. If true, calls `StartNewSelection(key)`.
        *   **`State_IDLE`:** Ignores.
    *   Handles `navigationKey` (Escape by default) if `enableFreeNavigation` is true and in a subgrid state, transitioning back to `GRID_VISIBLE`.

**D. Grid Navigation Flow (`core/grid_keys.ahk`)**

1.  **`HandleKey(key, bypassStateCheck := false)`:**
    *   Checks state (`GRID_VISIBLE`, unless `bypassStateCheck` is true). Determines if `key` is Col/Row using `StateMap['activeColKeys']`/`StateMap['activeRowKeys']`.
    *   Stops `TrackCursor`.
    *   Checks `StateMap['firstKey']`:
        *   If empty: Calls `HandleFirstKey()`.
        *   If set: Calls `HandleSecondKey()`.
2.  **`HandleFirstKey(key, isColKey, colIndex, isRowKey, rowIndex)`:**
    *   Stores `key` in `StateMap['firstKey']`.
    *   **Contextual Guessing (Task 6.1):**
        *   Gets current mouse position (`currentX`, `currentY`).
        *   Calls `GetCellAtPosition(currentX, currentY)` to find `hoveredCellKey`.
        *   If `hoveredCellKey` found: Uses the *other* coordinate from the hovered cell (e.g., if `key` is Col, use Row from `hoveredCellKey`).
        *   If no `hoveredCellKey`: Falls back to guessing the other coordinate using `StateMap["preservedRowKey"]` (if available from `StartNewSelection`), then `StateMap['lastSelectedRowIndex']`, or defaults (middle/1).
    *   Constructs `targetCellKey` based on the guess/context.
    *   Gets `boundaries` for `targetCellKey` from `StateMap['currentOverlay'].GetCellBoundaries()`.
    *   Updates `highlight` (`highlight.Update`) to show the *guessed* cell.
    *   Moves mouse (`MouseMove`) to the center of the guessed cell.
    *   Restarts `TrackCursor`.
3.  **`HandleSecondKey(key, isColKey, colIndex, isRowKey, rowIndex)`:**
    *   Retrieves `firstKey` from `StateMap`. Determines if `firstKey` was Col or Row.
    *   Checks if `firstKey` and `key` form a valid sequence (Col->Row or Row->Col).
    *   **If Valid Sequence:**
        *   Constructs `finalCellKey`. Sets `proceedToSubgrid = true`. Updates `StateMap['currentRowIndex']` or `StateMap['currentColIndex']`. Updates `StateMap['lastSelectedRowIndex']` if a row key was the second key.
    *   **If Invalid Sequence (Col->Col or Row->Row):**
        *   Logs the issue.
        *   Resets `StateMap['firstKey'] = ""`.
        *   Calls `StartNewSelection(key)` (`core/state_transitions.ahk`) to treat the second key as the *start* of a new selection. Returns early. (Robust Fix 5.10)
    *   **If `proceedToSubgrid`:**
        *   Gets `boundaries` for `finalCellKey`.
        *   If valid:
            *   Sets `StateMap['activeCellKey'] = finalCellKey`.
            *   Determines and sets `StateMap['activeRowKey']` (the row key involved in the selection, needed for ultra-fast).
            *   Clears `StateMap["preservedRowKey"]` if it exists (`StateMap.Delete`).
            *   Updates `highlight` for the final cell (`highlight.Update`).
            *   Updates `subGrid` geometry (`subGrid.Update`).
            *   Resets `StateMap['firstKey'] = ""`.
            *   Calls `TransitionToState(State_SUBGRID_STANDARD)` (`core/state_transitions.ahk`).
        *   If boundaries invalid: Resets `StateMap['firstKey']`, hides highlight.
    *   Restarts `TrackCursor`.

**E. Subgrid Navigation Flow (`core/subgrid_keys.ahk`)**

1.  **`ProcessStandardSubgridKey(subKey)` / `ProcessUltraFastKey(key)`:**
    *   Checks state validity (`SUBGRID_STANDARD` or `SUBGRID_ULTRAFAST` / `inUltraFastMode`).
    *   Checks debounce (`stateTransitionDelay` vs `stateTransitionTime`).
    *   Calls `subGrid.GetTargetCoordinates(subKey)` or `subGrid.GetUltraFastTargetCoordinates(key)` (`gui_classes.ahk`). These methods calculate the target x,y based on the *current* subgrid layout (`standard` or `ultrafast`).
    *   If coordinates valid:
        *   Moves mouse (`MouseMove`).
        *   Updates `StateMap['activeSubCellKey'] = subKey`.
        *   Calls `UpdateCellMemory(StateMap['activeCellKey'], subKey)` (prefixing with "ultra:" in `ProcessUltraFastKey`).
        *   In `ProcessUltraFastKey`, ensures `highlight` is shown over the main cell by calling `highlight.Update` with the main cell's boundaries.
2.  **`UpdateCellMemory(cellKey, subCellKey)`:**
    *   Constructs `keyToUse` (e.g., "qj" or "1_qj" if `storePerMonitor` is true, using `StateMap['currentOverlay'].monitorIndex`).
    *   Updates the `cellMemory` Map: `cellMemory[keyToUse] := subCellKey`.
    *   *(Note: `SaveCellMemory()` is not called here. It's called in `DeactivateGrid` and potentially on script exit).*

**F. Ultra-Fast Mode Flow**

1.  **Activation (Inferred Logic, likely in `TrackCursor` or key down handler - *not explicitly shown in provided files*):**
    *   When `currentState == State_SUBGRID_STANDARD`.
    *   User holds down a row key (e.g., 'j').
    *   A timer or key-down handler detects the row key is held.
    *   It starts tracking `StateMap['rowKeyHeldTime']`.
    *   If `A_TickCount - StateMap['rowKeyHeldTime'] > rowKeyHoldThreshold` and `enableUltraFast` is true:
        *   Sets `StateMap['inUltraFastMode'] = true`.
        *   Sets `StateMap['activeRowKey']` to the held key.
        *   Calls `subGrid.SwitchToUltraFast()` (`gui_classes.ahk`). This sets `subGrid.currentLayout = "ultrafast"` and calls `subGrid.Update` to redraw with the 3x4 layout.
        *   Calls `TransitionToState(State_SUBGRID_ULTRAFAST)` (`core/state_transitions.ahk`). This runs entry actions (shows `highlight`, shows `subGrid` which is now ultra-fast layout, handles `keepGridVisible`).
2.  **Key Handling (`ProcessKeyPress` -> `ProcessUltraFastKey`):** As described in Section E.
3.  **Deactivation (`hotkeys.ahk`, `core/subgrid_keys.ahk`):**
    *   User releases the row key (e.g., 'j up').
    *   `j up::` hotkey (`hotkeys.ahk`) is active via `#HotIf currentState == State_SUBGRID_STANDARD && StateMap.Get("inUltraFastMode", false)`. It calls `CheckRowKeyUpForUltraFast("j")`, which calls `HandleRowKeyRelease("j")`.
    *   **`HandleRowKeyRelease(key)` (`core/subgrid_keys.ahk`):**
        *   Checks if `enableUltraFast`, `StateMap['inUltraFastMode']` are true, and `key == StateMap['activeRowKey']`.
        *   If true:
            *   Sets `StateMap['inUltraFastMode'] = false`.
            *   Calls `subGrid.SwitchToStandard()` (`gui_classes.ahk`). This sets `subGrid.currentLayout = "standard"` and calls `subGrid.Update` to redraw with the 2x2 layout.
            *   Resets `StateMap['activeRowKey'] = ""`.
            *   **Crucially, it does *not* explicitly call `TransitionToState(State_SUBGRID_STANDARD)`.** The `currentState` remains `SUBGRID_ULTRAFAST` until the next interaction or `TrackCursor` cycle potentially changes it (e.g., cursor moves out, user presses grid key). The `#HotIf` condition for the `up` event itself checks `State_SUBGRID_STANDARD`, which seems contradictory to the expected state (`SUBGRID_ULTRAFAST`) when the key is released. This might rely on the state changing back *before* the `up` event fully processes, or it might be a bug/oversight. Let's assume it's intended to work somehow, perhaps the `TrackCursor` check handles it implicitly.

**G. State Transition: Subgrid -> Grid (`StartNewSelection` in `core/state_transitions.ahk`)**

1.  **Trigger:** User presses a grid key (e.g., 'q') while in `SUBGRID_STANDARD` or `SUBGRID_ULTRAFAST`. `ProcessKeyPress` routes this call. Can also be triggered by `TrackCursor` when the cursor leaves the active cell's boundaries (passing `key = ""`).
2.  **Execution:**
    *   Stops `TrackCursor`.
    *   **Context Preservation (Task 5.8/5.10):** Safely gets `prevActiveCellKey` and `prevActiveRowKey` from `StateMap`. If `prevActiveCellKey` exists, stores its first char in `StateMap["preservedColKey"]` and its second char (or `prevActiveRowKey` if set) in `StateMap["preservedRowKey"]`. Clears these preserved keys if no previous cell existed.
    *   Calls `TransitionToState(State_GRID_VISIBLE)`. This handles hiding `subGrid`/`highlight` and showing main overlays (if not `keepGridVisible`).
    *   Clears selection state safely (`activeCellKey`, `activeSubCellKey`, `firstKey`, `activeRowKey`, `inUltraFastMode`). Also resets `g_firstKeyPressed`.
    *   If `key != ""`: Calls `HandleKey(key, true)` to process the pressed grid key (`q`) as the *first* key of a new selection, bypassing `HandleKey`'s own state check. `HandleKey` will restart `TrackCursor`.
    *   If `key == ""`: Restarts `TrackCursor`.

**H. Cursor Tracking (`TrackCursor` in `core/tracking.ahk`)**

1.  **Timer Execution:** Runs every ~50ms when `currentState` is not `IDLE`. Uses static `trackingInProgress` to prevent re-entry. Uses static `lastTrackedCellKey_GridVisible`.
2.  **Subgrid States (`SUBGRID_STANDARD` / `SUBGRID_ULTRAFAST`):**
    *   Gets `activeCellKey` boundaries from `StateMap['currentOverlay']`.
    *   Checks if cursor `(x,y)` is inside these boundaries (`cursorInsideCell`).
    *   If **NOT**: Calls `StartNewSelection("")` to transition back to `GRID_VISIBLE`.
3.  **Grid Visible State (`GRID_VISIBLE`):**
    *   Calls `GetCellAtPosition(x, y)` (`core/positioning.ahk`).
    *   Compares `currentCellKey` with static `lastTrackedCellKey_GridVisible`.
    *   **If Changed:**
        *   If `currentCellKey` is valid (not empty):
            *   Gets boundaries. Updates `highlight` (`highlight.Update`) to show hover.
            *   **!!! HOVER ACTIVATION REMOVED (Task 5.10):** The code block that previously checked `StateMap['firstKey'] == ""` and called `TransitionToState(State_SUBGRID_STANDARD)` upon hover is commented out or removed. Highlight updates, but the state does not change automatically just by hovering.
        *   If `currentCellKey` is empty (cursor outside cells): Hides `highlight`.
        *   Updates `lastTrackedCellKey_GridVisible = currentCellKey`.
4.  **Finally Block:** Resets `trackingInProgress = false`.

**I. Cleanup/Deactivation**

1.  **Triggers:** `Escape` hotkey, `Space` hotkey, `CapsLock Up` (single tap release), `LButton`/`RButton` click while active (`WinActive("ahk_group AntiMouseOverlays")`), Shift+CapsLock, errors.
2.  **`Escape::` Hotkey (`hotkeys.ahk` - context-specific `#HotIf`):** Calls `Cleanup()` (`activation.ahk`). Includes robust `try/catch` with a forced cleanup attempt (`ForceCloseAllGuis`, manual state/variable reset) if standard `Cleanup()` fails.
3.  **`Space::` Hotkey (`hotkeys.ahk` - context-specific `#HotIf`):**
    *   Saves mouse pos. Stops `TrackCursor`. Sets `currentState = State_IDLE` *first*.
    *   Safely hides GUIs (`highlight`, `subGrid`, `overlays`) with `IsObject` checks.
    *   Performs `Click("Left")`.
    *   Calls `Cleanup()` (`activation.ahk`).
4.  **`~$LButton::` / `~$RButton::` / `*~$CapsLock::` (with Shift) Hotkeys (`hotkeys.ahk` - global `#HotIf WinActive`):** Call `TransitionToState(State_IDLE)` *first*, then call `DeactivateGrid(true)` (`activation.ahk`). `true` forces deactivation, bypassing debounce.
5.  **`Cleanup()` (`activation.ahk`):**
    *   Checks if already `IDLE`.
    *   Stops `TrackCursor`. Calls `TransitionToState(State_IDLE)` (handles initial GUI hiding).
    *   Resets flags (`g_ModifierState.inHoldMode`, `gridActivationInProgress`).
    *   Resets `StateMap` selection keys (`firstKey`, `activeCellKey`, etc.), clears `preservedRowKey`.
    *   Resets ultra-fast state (`inUltraFastMode`, `activeRowKey`).
    *   Explicitly hides GUIs again (best effort, with `IsObject` checks).
    *   Waits (`Sleep(30)`).
    *   Destroys GUI objects (`highlight.Destroy()`, `subGrid.Destroy()`, loops through `StateMap['overlays']` calling `overlay.Destroy()`).
    *   Clears global GUI object variables (`highlight = ""`, `subGrid = ""`). Clears `StateMap['overlays'] = []`, `StateMap['currentOverlay'] = ""`.
    *   Calls `ForceCloseAllGuis()` (`utils.ahk`) as a final safety net.
6.  **`DeactivateGrid(forced := false)` (`activation.ahk`):**
    *   Checks debounce (`stateTransitionDelay` vs `gridActivationTime`) unless `forced` is true.
    *   Stops `TrackCursor`.
    *   Destroys overlays in `StateMap['overlays']` and clears the array/current overlay.
    *   Destroys `subGrid`, `highlight` and clears globals.
    *   Resets `StateMap` selection keys and ultra-fast state.
    *   Resets `g_ModifierState.inHoldMode`.
    *   Calls `TransitionToState(State_IDLE)`.
    *   If `saveMemoryOnExit` is true, calls `SaveCellMemory()` (`memory_settings.ahk`).

**J. Monitor Switching (`core/monitor.ahk`)**

1.  **Triggers:**
    *   `Tab::` hotkey (`hotkeys.ahk` - context-specific `#HotIf`) calls `CycleToNextMonitor()`.
    *   `1::` / `2::` etc. hotkeys (`hotkeys.ahk` - context-specific `#HotIf`) call `SwitchMonitor(N)`.
    *   `CapsLock & 1::` / `CapsLock & 2::` etc. (`hotkeys.ahk` - `#HotIf GetKeyState('CapsLock', 'P') && active && !g_ModifierState.inHoldMode`) call `SwitchMonitor(N)`.
    *   `CapsLock + 1::` / `CapsLock + 2::` etc. (`hotkeys.ahk` - `#HotIf GetKeyState('CapsLock', 'P')`) checks if `IDLE`, calls `CapsLock_Q()` if needed, then calls `SwitchMonitor(N)`.
2.  **`SwitchMonitor(monitorNum)`:**
    *   Applies `monitorMapping` to get `mappedMonitor`. Validates index against `StateMap['overlays'].Length`. Checks if already on target monitor.
    *   Stops `TrackCursor`.
    *   Gets `newOverlay = StateMap['overlays'][mappedMonitor]`.
    *   Hides elements on old monitor (`currentOverlay.Hide()`, `highlight.Hide()`, `subGrid.Hide()`).
    *   Updates `StateMap['currentOverlay'] = newOverlay`.
    *   Shows `newOverlay`.
    *   Moves mouse (`MouseMove`) to the center of the new monitor's work area.
    *   Resets selection state (`firstKey`, `activeCellKey`, `activeSubCellKey`, `inUltraFastMode`, `activeRowKey`). Also resets `g_firstKeyPressed`.
    *   Calls `TransitionToState(State_GRID_VISIBLE)`.
    *   Starts `TrackCursor`.
3.  **`CycleToNextMonitor()`:**
    *   Finds the `currentPhysicalIndex` corresponding to `StateMap['currentOverlay'].monitorIndex` by iterating through `monitorMapping`.
    *   Gets a sorted list of all physical indices from `monitorMapping.OwnKeys()`.
    *   Finds the position of `currentPhysicalIndex` in the sorted list.
    *   Calculates the next index in the sorted list (wrapping around).
    *   Gets the `nextPhysicalIndex` from the sorted list.
    *   Calls `SwitchMonitor(nextPhysicalIndex)`.

**K. Settings (`settings_gui.ahk`, `memory_settings.ahk`)**

1.  **Trigger:** `:*:;settings::` hotstring (`settings_gui.ahk`) calls `ShowSettingsGUI()`.
2.  **`ShowSettingsGUI()`:** Creates the `settingsGui` (`Gui(...)`), adds controls (GroupBox, Text, DropDownList, Checkbox, Slider, Edit, Button). Populates controls with current global config values (`selectedLayout`, `storePerMonitor`, etc.). Sets up event handlers (`OnEvent`) for buttons and sliders. Shows the GUI.
3.  **Apply Button (`ApplySettings` function called via `applyBtn.OnEvent`)**:
    *   Reads values from GUI controls (`layoutDropdown.Value`, `storePerMonitorCheckbox.Value`, etc.).
    *   Updates the corresponding global config variables.
    *   Constructs `newMapping` array from monitor Edit controls and updates the global `monitorMapping` array.
    *   Attempts to apply some visual settings live (grid transparency via `WinSetTransColor` on overlays, highlight color via `highlight.gui.BackColor`). Includes `try/catch`.
    *   Calls `SaveSettings()` (`memory_settings.ahk`). Displays success/error MsgBox.
4.  **`SaveSettings()` (`memory_settings.ahk`):** Writes current global config variables (`selectedLayout`, `storePerMonitor`, etc.) to `antimouse_settings.ini` using `IniWrite`. Includes `try/catch` and directory creation. Returns `true` on success, `false` on failure.

---

### How Subgrids are Activated:

1.  **Instant Activation (On Initial Grid Display):** In `CapsLock_Q` (`activation.ahk`), immediately after `TransitionToState(State_GRID_VISIBLE)`, it calls `GetCurrentCell()`. If the cursor is already inside a cell, it gets boundaries, sets `StateMap['activeCellKey']`, updates `highlight` and `subGrid` positions, and calls `TransitionToState(State_SUBGRID_STANDARD)`.
2.  **Grid Navigation Completion:** In `HandleSecondKey` (`core/grid_keys.ahk`), after a valid two-key sequence (Col->Row or Row->Col) is detected and boundaries are valid, it sets `StateMap['activeCellKey']`, updates `highlight`/`subGrid`, and calls `TransitionToState(State_SUBGRID_STANDARD)`.
3.  **~~Cursor Hover (Tracking):~~** ~~Previously, `TrackCursor` (`core/tracking.ahk`) would check if the cursor moved into a new cell while in `GRID_VISIBLE` and `StateMap['firstKey'] == ""`, then transition to `SUBGRID_STANDARD`. **This behavior appears to have been intentionally removed or commented out based on the "Task 5.10 | REMOVED HOVER ACTIVATION" comments in `tracking.ahk`.** The highlight still follows the cursor, but hovering alone no longer activates the subgrid.~~ *(Correction based on re-reading `tracking.ahk`: The code for hover activation was *present* but commented out in the provided snippet. Assuming the comments reflect the intended state, hover activation is disabled).*

---

### Potential Conflicts / Lack of Sense:

1.  **~~Race Condition: `TrackCursor` vs. Key Handling (Hover Activation):~~** *(See note above - If hover activation *is* enabled, this is relevant)* If a user presses the second grid key *just as* `TrackCursor` decides to transition state due to hover, the `HandleSecondKey` logic might run in the wrong state or conflict. The check `StateMap['firstKey'] == ""` in `TrackCursor` aims to mitigate this, but the potential timing issue remains. Similarly, if the cursor leaves the subgrid cell (`TrackCursor` calls `StartNewSelection`) at the *exact* moment the user presses a grid key (`ProcessKeyPress` calls `StartNewSelection`), `StartNewSelection` might be called twice.
2.  **Rapid Double Transition in `CapsLock_Q`:** The `IDLE` -> `GRID_VISIBLE` -> `SUBGRID_STANDARD` transition within `CapsLock_Q` if the cursor starts inside a cell is efficient but slightly complex, potentially masking edge cases compared to determining the final target state first and transitioning once.
3.  **Implicit Ultra-Fast State Reversion:** `HandleRowKeyRelease` resets the `inUltraFastMode` flag and calls `subGrid.SwitchToStandard()` but *doesn't* call `TransitionToState(State_SUBGRID_STANDARD)`. The state only changes back when `TrackCursor` detects the cursor left the cell or the user presses a grid key (`StartNewSelection`) or deactivates. This means the internal state (`currentState`) can be `SUBGRID_ULTRAFAST` while the flag (`inUltraFastMode`) and GUI (`subGrid.currentLayout`) are already "standard". This seems inconsistent. Furthermore, the `#HotIf` condition for the `up` key event (`#HotIf currentState == State_SUBGRID_STANDARD && StateMap.Get("inUltraFastMode", false)`) is contradictory – it requires the state to be STANDARD *while* the ultra-fast mode flag is true, which shouldn't normally happen if the state transitions correctly upon entering ultra-fast mode. This strongly suggests a potential bug or reliance on leaky state management.
4.  **`g_firstKeyPressed` vs. `StateMap['firstKey']`:** These seem to track the same thing. `g_firstKeyPressed` is primarily used and reset within `core/grid_keys.ahk` and `StartNewSelection`. `StateMap['firstKey']` is reset in more places (`CapsLock_Q`, `Cleanup`, `SwitchMonitor`, `HandleSecondKey`, `StartNewSelection`). They *should* stay synchronized due to resets in `HandleSecondKey` and `StartNewSelection`, but the redundancy increases complexity and potential for divergence if code is modified carelessly. Consolidating seems better.
5.  **Context Preservation (`StartNewSelection`):** The logic preserves the *row* and *column* keys separately into `StateMap["preservedRowKey"]` / `StateMap["preservedColKey"]`. `HandleFirstKey` then uses `preservedRowKey` (but not `preservedColKey` explicitly, although it might be implicitly used via `StateMap.Get('currentColIndex', ...)` if the previous state set it). This preservation helps maintain context when moving between cells but adds complexity.
6.  **State Loss on Monitor Switch:** `SwitchMonitor` explicitly resets the selection (`firstKey`, `activeCellKey`, etc.) and transitions to `GRID_VISIBLE`. Any subgrid interaction or partial grid selection is lost.

### Optimization & Scalability:

*   **Optimization:**
    *   **Good:** Modular structure aids understanding. Classes (`gui_classes.ahk`) encapsulate GUI logic. `StateMap` centralizes dynamic state. Buffered logging (`utils.ahk`) prevents I/O blocking. GUI reuse in `SubGridOverlay` is smart.
    *   **Areas for Improvement:** Heavy reliance on `global` variables could be reduced (though common in AHK v2). Frequent `IsObject` checks add safety but overhead. `TrackCursor` runs constantly when active; could potentially use event-based hooks (`MouseMove`) for hover detection if needed, or adaptive timing. Minimize `Sleep` where possible. The `ForceCloseAllGuis` function is a bit brute-force; more targeted destruction in `Cleanup`/`DeactivateGrid` is better.
*   **Scalability:**
    *   **Good:** The modular structure is highly scalable for adding features within existing paradigms. Adding new layouts is easy (`config.ahk`). Adding new states requires updating `ProcessKeyPress`, `TransitionToState`, and potentially `TrackCursor`.
    *   **Areas for Improvement:** The interaction logic between `TrackCursor`, `TransitionToState`, `HandleKey`/`HandleSecondKey`, and `StartNewSelection` is quite tightly coupled, especially around state resets and context preservation (`preservedRowKey`). Adding significantly different interaction modes (e.g., drag-select) would require careful weaving into this core logic. The CapsLock activation logic (`hotkeys.ahk`, `g_ModifierState`) is intricate and specific; extending it to other modifiers might be complex. The implicit state change in Ultra-Fast mode deactivation hinders predictability.

---

## 2. Mermaid Diagrams

### High-Level State Diagram

```mermaid
stateDiagram-v2
    direction LR
    [*] --> IDLE : Init / Cleanup / Deactivate

    IDLE --> GRID_VISIBLE : Activate (CapsLock_Q, No Cell Hover)
    IDLE --> SUBGRID_STANDARD : Activate (CapsLock_Q, Cell Hover)

    state GRID_VISIBLE {
        [*] --> WaitForKey : Entry / New Selection Start
        WaitForKey --> FirstKeySelected : Grid Key (1st) / HandleFirstKey
        FirstKeySelected --> WaitForKey : Invalid 2nd Key / HandleSecondKey -> StartNewSelection(key)
        FirstKeySelected --> SUBGRID_STANDARD : Valid 2nd Key / HandleSecondKey -> TransitionToState
        [*] --> HoverTracking : TrackCursor Timer
        HoverTracking --> HighlightUpdate : Cursor Moves Into Cell / TrackCursor
        HighlightUpdate --> HoverTracking : Cursor Stays In Cell
        HoverTracking --> HighlightHide : Cursor Leaves Cells / TrackCursor
        HighlightHide --> HoverTracking : Cursor Outside Cells
        %% Note: Hover activation to SUBGRID_STANDARD seems disabled based on comments %%
        %% HoverTracking --> SUBGRID_STANDARD : Cursor Enters Cell (No Key Held) / TrackCursor -> TransitionToState %%
    }

    state SUBGRID_STANDARD {
         [*] --> Ready : Entry / TransitionToState
         Ready --> Ready : Subgrid Key (g,h,b,n) / ProcessStandardSubgridKey
         Ready --> GRID_VISIBLE : Grid Key / ProcessKeyPress -> StartNewSelection
         Ready --> GRID_VISIBLE : Navigation Key (Esc) / ProcessKeyPress -> TransitionToState
         Ready --> SUBGRID_ULTRAFAST : Row Key Held > Threshold / (Inferred Timer/Hook) -> TransitionToState
         [*] --> CellTracking : TrackCursor Timer
         CellTracking --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
         CellTracking --> Ready : Cursor Inside Cell
    }

     state SUBGRID_ULTRAFAST {
         [*] --> Ready : Entry / TransitionToState
         Ready --> Ready : UltraFast Key (qwer...) / ProcessUltraFastKey
         Ready --> GRID_VISIBLE : Grid Key / ProcessKeyPress -> StartNewSelection
         Ready --> GRID_VISIBLE : Navigation Key (Esc) / ProcessKeyPress -> TransitionToState
         %% Note: State doesn't explicitly change back on release, flag/GUI changes %%
         Ready --> SUBGRID_ULTRAFAST : Row Key Release / HandleRowKeyRelease (Sets Flag, Changes GUI, *No State Transition*)
         [*] --> CellTracking : TrackCursor Timer
         CellTracking --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
         CellTracking --> Ready : Cursor Inside Cell
     }


    GRID_VISIBLE --> IDLE : Cleanup (Esc/Space/Tap/Click/Shift+Caps) / DeactivateGrid
    SUBGRID_STANDARD --> IDLE : Cleanup (Esc/Space/Click/Shift+Caps) / DeactivateGrid
    SUBGRID_ULTRAFAST --> IDLE : Cleanup (Esc/Space/Click/Shift+Caps) / DeactivateGrid

    GRID_VISIBLE --> GRID_VISIBLE : Monitor Switch / SwitchMonitor -> TransitionToState(GRID_VISIBLE)
    SUBGRID_STANDARD --> GRID_VISIBLE : Monitor Switch / SwitchMonitor -> TransitionToState(GRID_VISIBLE)
    SUBGRID_ULTRAFAST --> GRID_VISIBLE : Monitor Switch / SwitchMonitor -> TransitionToState(GRID_VISIBLE)
```

### Activation Flow (`CapsLock_Q` focus)

```mermaid
graph TD
    subgraph User Action
        A[Double-Tap CapsLock] --> B(hotkeys.ahk: CapsLock:: Detects Double-Tap);
    end

    subgraph Activation Logic [activation.ahk: CapsLock_Q()]
        B -- Sets g_ModifierState.inHoldMode=true --> C{Guard Checks (In Progress? Not IDLE?)};
        C -- Yes --> D[Cleanup()] --> Z[End];
        C -- No --> E[Set Flags / Reset StateMap / Load Memory];
        E --> G[Init GUIs: highlight = new HighlightOverlay(), subGrid = new SubGridOverlay()];
        G --> H[Loop Monitors: Create/Show Overlays (OverlayGUI), Find Current -> StateMap['overlays'], StateMap['currentOverlay']];
        H --> I{Overlays OK?};
        I -- No --> D;
        I -- Yes --> J[TransitionToState(State_GRID_VISIBLE)];
        J --> K[GetCurrentCell()];
        K --> L{Cell Found?};
        L -- No --> M[SetTimer(TrackCursor, 50)] --> Y[Grid Ready];
        L -- Yes --> N[Get Boundaries];
        N --> O{Boundaries OK?};
        O -- No --> M;
        O -- Yes --> P[Set StateMap['activeCellKey']];
        P --> Q[highlight.Update(...)];
        Q --> R[subGrid.Update(...)];
        R --> S[TransitionToState(State_SUBGRID_STANDARD)];
        S --> M;
    end

    subgraph Final State
        Y --> Z;
    end
```

### Key Press Routing (`ProcessKeyPress` focus)

```mermaid
graph TD
    A[Hotkey Trigger (e.g., 'w', 'g', 'q')] --> B(core/key_processing.ahk: ProcessKeyPress);
    B --> Nav{Nav Key ('Escape')?};
    Nav -- Yes --> NavCheckState{In Subgrid?};
    NavCheckState -- Yes --> NavAction[Reset State -> TransitionToState(GRID_VISIBLE)] --> XEnd[End];
    NavCheckState -- No --> C{currentState?};
    Nav -- No --> C;

    C -- GRID_VISIBLE --> D{CheckIfGridKey?};
    D -- Yes --> E[HandleKey(key)] --> XEnd;
    D -- No --> Ignore[Ignore Key] --> XEnd;

    C -- SUBGRID_STANDARD --> F{IsSubGridKey (g,h,b,n)?};
    F -- Yes --> G[ProcessStandardSubgridKey(key)] --> XEnd;
    F -- No --> H{CheckIfGridKey?};
    H -- Yes --> I[StartNewSelection(key)] --> XEnd;
    H -- No --> Ignore;

    C -- SUBGRID_ULTRAFAST --> J{IsUltraFastSubGridKey (qwer...)?};
    J -- Yes --> K[ProcessUltraFastKey(key)] --> XEnd;
    J -- No --> L{CheckIfGridKey?};
    L -- Yes --> I;
    L -- No --> Ignore;

    C -- IDLE --> Ignore;
```

### Subgrid Activation Summary Table

| Activation Method         | Triggering Function/File                  | State Before | State After        | Key Logic Involved                                                   | Notes                                                                                                |
| :------------------------ | :---------------------------------------- | :----------- | :----------------- | :------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| **Instant (On Activate)** | `CapsLock_Q` (`activation.ahk`)           | `IDLE`       | `SUBGRID_STANDARD` | `GetCurrentCell`, `GetCellBoundaries`, `TransitionToState` x2        | Only if cursor starts within a cell when grid is activated. Transitions `IDLE`->`GRID`->`SUBGRID`. |
| **Grid Navigation**     | `HandleSecondKey` (`core/grid_keys.ahk`)    | `GRID_VISIBLE` | `SUBGRID_STANDARD` | Valid Col->Row or Row->Col sequence, `GetCellBoundaries`, `TransitionToState` | Standard way to select a cell and enter its subgrid after two key presses.                       |
| **~~Cursor Hover~~**      | `TrackCursor` (`core/tracking.ahk`)       | `GRID_VISIBLE` | `SUBGRID_STANDARD` | Cursor moves into cell, `StateMap['firstKey'] == ""` (CHECK IF ENABLED) | Automatic activation by hovering. **Appears disabled based on code comments.**                     |
| **Ultra-Fast Mode**     | (Inferred Timer/Hook)                     | `SUBGRID_STANDARD` | `SUBGRID_ULTRAFAST` | Row key held > `rowKeyHoldThreshold`, `subGrid.SwitchToUltraFast`, `TransitionToState` | Activates the 3x4 subgrid layout.                                                                  |