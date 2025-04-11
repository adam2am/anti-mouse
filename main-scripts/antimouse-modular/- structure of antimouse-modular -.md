Okay, let's break down the logic flow of the AntiMouse script based on the provided code snippets.

## 1. Logical Function/Variable Flow

Here's a breakdown of the script's execution flow, focusing on key functions, variables, and state transitions:

**A. Initialization (`1main.ahk`)**

1.  **Environment Setup:** Sets AHK version, single instance, coordinates, ensures CapsLock is off.
2.  **Includes:** Loads modules in order: `config` -> `state` -> `utils`/`gui_classes` -> `memory_settings` -> `core/*` -> `activation` -> `settings_gui` -> `hotkeys`. This order is crucial for dependencies.
3.  **Load Persistent Data:**
    *   Calls `LoadSettings()` (`memory_settings.ahk`) -> Reads `antimouse_settings.ini` into global config variables (`selectedLayout`, `storePerMonitor`, `showcaseDebug`, `monitorMapping`, `defaultTransparency`, `highlightColor`, `instaClickMode`, `enableUltraFast`, `rowKeyHoldThreshold`, `keepGridVisible`).
    *   Calls `LoadCellMemory()` (`memory_settings.ahk`) -> Reads `cell_memory.txt` into the global `cellMemory` Map.
4.  **Apply Initial Config:** Sets global `activeColKeys`/`activeRowKeys` based on the `selectedLayout` loaded from settings and defined in `layoutConfigs` (`config.ahk`).
5.  **Start Timers:**
    *   `SetTimer(ProcessLogQueue, 300)` (`utils.ahk`): Starts the buffered logging timer.
    *   `SetTimer(ForceCapsLockOff, 250)` (`utils.ahk`): Starts the timer to keep CapsLock physically off.
6.  **Persist:** `Persistent()` makes the script stay running, waiting for hotkeys or timers. `currentState` starts as `State_IDLE`.

**B. Activation Flow (Example: CapsLock Double-Tap)**

1.  **Hotkey Trigger (`hotkeys.ahk`):**
    *   User presses CapsLock twice within `doubleCapsThreshold`.
    *   `CapsLock::` hotkey fires multiple times. It uses `g_ModifierState` (`state.ahk`) map (`capsPressedFirstTime`, `capsPressedSecondTime`, `lastCapsUpTime`, `capsFirstReleased`) to detect the double-tap.
    *   On successful detection, sets `g_ModifierState.inHoldMode = true`.
    *   Calls `CapsLock_Q()` (`activation.ahk`).
2.  **`CapsLock_Q()` (`activation.ahk`):**
    *   **Guard Checks:** Prevents double activation using `gridActivationInProgress` flag and timing. Checks if `currentState != State_IDLE`; if so, calls `Cleanup()` and exits.
    *   **State Reset:** Sets `gridActivationInProgress = true`. Resets relevant `StateMap` values (`firstKey`, `currentOverlay`, `activeCellKey`, etc.) and `g_firstKeyPressed`.
    *   **Load/Config:** Reloads `cellMemory`. Gets layout config (`layoutConfigs`, `selectedLayout`). Sets `StateMap['activeColKeys']`/`StateMap['activeRowKeys']`.
    *   **GUI Initialization:** Creates `HighlightOverlay` and `SubGridOverlay` instances (stored in `highlight`, `subGrid` globals).
    *   **Overlay Creation:** Loops through monitors, creates `OverlayGUI` instances (which contain `GridOverlay`) for each, shows them, and stores them in `StateMap['overlays']`. Determines `StateMap['currentOverlay']` based on initial mouse position (`startX`, `startY`).
    *   **Initial State Transition:** Calls `TransitionToState(State_GRID_VISIBLE)` (`core/state_transitions.ahk`). This sets `currentState` and runs entry actions for GRID_VISIBLE (showing main overlays, hiding highlight/subgrid).
    *   **Instant Subgrid Activation:**
        *   Calls `GetCurrentCell()` (`core/tracking.ahk`, which uses `GetCellAtPosition` from `core/positioning.ahk`) to find `initialCellKey` under the cursor.
        *   If `initialCellKey` found and boundaries (`currentOverlay.GetCellBoundaries`) are valid:
            *   Sets `StateMap['activeCellKey'] = initialCellKey`.
            *   Updates `highlight` position (`highlight.Update`).
            *   Updates `subGrid` position (`subGrid.Update`).
            *   Calls `TransitionToState(State_SUBGRID_STANDARD)`. This immediately changes the state again and runs entry actions for SUBGRID_STANDARD (showing highlight/subgrid, potentially hiding main overlays based on `keepGridVisible`).
    *   **Start Tracking:** Calls `SetTimer(TrackCursor, 50)` (`core/tracking.ahk`).
    *   **Cleanup Flag:** Resets `gridActivationInProgress` on success/failure.

**C. Key Processing Flow (Grid/Subgrid Active)**

1.  **Hotkey Trigger (`hotkeys.ahk`):** User presses a letter/symbol key (e.g., 'w', 'j', ';'). The corresponding hotkey (active via `#HotIf currentState != State_IDLE`) fires.
2.  **Central Router (`ProcessKeyPress` in `core/key_processing.ahk`):**
    *   Receives the `key`.
    *   Checks `currentState`:
        *   **`State_GRID_VISIBLE`:** Calls `HandleKey(key)` (`core/grid_keys.ahk`).
        *   **`State_SUBGRID_STANDARD`:**
            *   Checks `IsSubGridKey(key)` (g,h,b,n). If true, calls `ProcessStandardSubgridKey(key)` (`core/subgrid_keys.ahk`).
            *   If false, checks `CheckIfGridKey(key)`. If true, calls `StartNewSelection(key)` (`core/state_transitions.ahk`).
        *   **`State_SUBGRID_ULTRAFAST`:**
            *   Checks `IsUltraFastSubGridKey(key)` (qwer...). If true, calls `ProcessUltraFastKey(key)` (`core/subgrid_keys.ahk`).
            *   If false, checks `CheckIfGridKey(key)`. If true, calls `StartNewSelection(key)`.
        *   **`State_IDLE`:** Ignores.

**D. Grid Navigation Flow (`core/grid_keys.ahk`)**

1.  **`HandleKey(key)`:**
    *   Checks state (`GRID_VISIBLE`). Determines if `key` is Col/Row.
    *   Stops `TrackCursor`.
    *   Checks `g_firstKeyPressed`:
        *   If empty: Calls `HandleFirstKey()`.
        *   If set: Calls `HandleSecondKey()`.
2.  **`HandleFirstKey(key, ...)`:**
    *   Stores `key` in `g_firstKeyPressed` and `StateMap['firstKey']`.
    *   Guesses the other coordinate (row if col key pressed, col if row key pressed) using `StateMap['lastSelectedRowIndex']` or middle/default.
    *   Constructs `cellKey`.
    *   Gets `boundaries` for `cellKey` from `StateMap['currentOverlay']`.
    *   Updates `highlight` (`highlight.Update`) to show the *guessed* cell.
    *   Moves mouse (`MouseMove`) to the center of the guessed cell.
    *   Restarts `TrackCursor`.
3.  **`HandleSecondKey(key, ...)`:**
    *   Determines if `g_firstKeyPressed` and `key` form a valid sequence (Col->Row or Row->Col).
    *   **If Valid Sequence:**
        *   Constructs `finalCellKey`. Sets `proceedToSubgrid = true`. Sets `StateMap['currentRowIndex']` or `StateMap['currentColIndex']`. Updates `StateMap['lastSelectedRowIndex']` if a row key was the second key.
    *   **If Invalid Sequence (Col->Col or Row->Row):**
        *   Logs the issue.
        *   Resets `g_firstKeyPressed = ""`, `StateMap['firstKey'] = ""`.
        *   Calls `StartNewSelection(key)` to treat the second key as the *start* of a new selection. Returns early. (Robust Fix 5.10)
    *   **If `proceedToSubgrid`:**
        *   Gets `boundaries` for `finalCellKey`.
        *   If valid:
            *   Sets `StateMap['activeCellKey'] = finalCellKey`.
            *   Determines and sets `StateMap['activeRowKey']` (the row key involved in the selection, needed for ultra-fast).
            *   Clears `StateMap["preservedRowKey"]` (if it existed).
            *   Updates `highlight` for the final cell (`highlight.Update`).
            *   Updates `subGrid` geometry (`subGrid.Update`).
            *   Resets `g_firstKeyPressed = ""`, `StateMap['firstKey'] = ""`.
            *   Calls `TransitionToState(State_SUBGRID_STANDARD)`.
        *   If boundaries invalid: Resets `g_firstKeyPressed`, hides highlight.
    *   Restarts `TrackCursor`.

**E. Subgrid Navigation Flow (`core/subgrid_keys.ahk`)**

1.  **`ProcessStandardSubgridKey(subKey)` / `ProcessUltraFastKey(key)`:**
    *   Checks state validity (`SUBGRID_STANDARD` or `SUBGRID_ULTRAFAST` / `inUltraFastMode`).
    *   Checks debounce (`stateTransitionDelay`).
    *   Calls `subGrid.GetTargetCoordinates(subKey)` or `subGrid.GetUltraFastTargetCoordinates(key)`.
    *   If coordinates valid:
        *   Moves mouse (`MouseMove`).
        *   Updates `StateMap['activeSubCellKey'] = subKey`.
        *   Calls `UpdateCellMemory(StateMap['activeCellKey'], subKey)` (possibly prefixed with "ultra:").
        *   In `ProcessUltraFastKey`, ensures `highlight` is shown over the main cell.
2.  **`UpdateCellMemory(cellKey, subCellKey)`:**
    *   Constructs `keyToUse` (e.g., "qj" or "1_qj" if `storePerMonitor`).
    *   Updates the `cellMemory` Map: `cellMemory[keyToUse] := subCellKey`.
    *   *(Note: `SaveCellMemory()` is not called here, happens on exit/deactivation).*

**F. Ultra-Fast Mode Flow**

1.  **Activation (`TrackCursor` in `core/tracking.ahk` - Inferred Logic):**
    *   When `currentState == State_SUBGRID_STANDARD`.
    *   User holds down a row key (e.g., 'j').
    *   `TrackCursor` (or a dedicated key-down handler, not fully shown) detects the row key is held.
    *   It starts tracking `StateMap['rowKeyHeldTime']`.
    *   If `A_TickCount - StateMap['rowKeyHeldTime'] > rowKeyHoldThreshold` and `enableUltraFast` is true:
        *   Sets `StateMap['inUltraFastMode'] = true`.
        *   Sets `StateMap['activeRowKey']` to the held key.
        *   Calls `subGrid.SwitchToUltraFast()`.
        *   Calls `TransitionToState(State_SUBGRID_ULTRAFAST)`.
2.  **Key Handling (`ProcessKeyPress` -> `ProcessUltraFastKey`):** As described in Section E.
3.  **Deactivation (`hotkeys.ahk`, `core/subgrid_keys.ahk`):**
    *   User releases the row key (e.g., 'j up').
    *   `j up::` hotkey calls `CheckRowKeyUpForUltraFast("j")`, which calls `HandleRowKeyRelease("j")`.
    *   **`HandleRowKeyRelease(key)`:**
        *   Checks if `enableUltraFast`, `StateMap['inUltraFastMode']` are true, and `key == StateMap['activeRowKey']`.
        *   If true:
            *   Sets `StateMap['inUltraFastMode'] = false`.
            *   Calls `subGrid.SwitchToStandard()`.
            *   Resets `StateMap['activeRowKey'] = ""`.
            *   **Crucially, it does *not* explicitly call `TransitionToState(State_SUBGRID_STANDARD)`.** The state likely changes back when `TrackCursor` runs and sees `inUltraFastMode` is false, or the next action implicitly handles it.

**G. State Transition: Subgrid -> Grid (`StartNewSelection` in `core/state_transitions.ahk`)**

1.  **Trigger:** User presses a grid key (e.g., 'q') while in `SUBGRID_STANDARD` or `SUBGRID_ULTRAFAST`. `ProcessKeyPress` routes this call.
2.  **Execution:**
    *   Stops `TrackCursor`.
    *   Safely preserves the *row* key from the previous selection (`StateMap['activeRowKey']` or from `StateMap['activeCellKey']`) into `StateMap["preservedRowKey"]`. (Task 5.8/5.10)
    *   Calls `TransitionToState(State_GRID_VISIBLE)`. This handles hiding `subGrid`/`highlight` and showing main overlays via its entry/exit actions.
    *   Clears selection state (`activeCellKey`, `activeSubCellKey`, `firstKey`, `activeRowKey`, `inUltraFastMode`, `g_firstKeyPressed`).
    *   Calls `HandleKey(key, true)`: Processes the pressed grid key (`q`) as the *first* key of a new selection, bypassing `HandleKey`'s own state check. `HandleKey` will restart `TrackCursor`.

**H. Cursor Tracking (`TrackCursor` in `core/tracking.ahk`)**

1.  **Timer Execution:** Runs every ~50ms when `currentState` is not `IDLE`. Uses static `trackingInProgress` to prevent re-entry.
2.  **Subgrid States (`SUBGRID_STANDARD` / `SUBGRID_ULTRAFAST`):**
    *   Gets `activeCellKey` boundaries from `StateMap['currentOverlay']`.
    *   Checks if cursor `(x,y)` is inside these boundaries.
    *   If **NOT**: Calls `StartNewSelection("")` to transition back to `GRID_VISIBLE`.
3.  **Grid Visible State (`GRID_VISIBLE`):**
    *   Calls `GetCellAtPosition(x, y)`.
    *   Compares `currentCellKey` with static `lastTrackedCellKey_GridVisible`.
    *   **If Changed:**
        *   If `currentCellKey` is valid (not empty):
            *   Gets boundaries.
            *   Updates `highlight` (`highlight.Update`) to show hover.
            *   **!!! Automatic Subgrid Activation (Hover - Original Behavior, potentially modified/disabled by Task 5.10 check):** If `g_firstKeyPressed == ""` (no keys being processed), it sets `StateMap["activeCellKey"] = currentCellKey`, updates `subGrid.Update()`, calls `TransitionToState(State_SUBGRID_STANDARD)`, updates `lastTrackedCellKey_GridVisible`, and **returns early**.
        *   If `currentCellKey` is empty (cursor outside cells): Hides `highlight`.
        *   Updates `lastTrackedCellKey_GridVisible`.
4.  **Finally Block:** Resets `trackingInProgress = false`.

**I. Cleanup/Deactivation**

1.  **Triggers:** `Escape` hotkey, `Space` hotkey (after click), `CapsLock Up` (single tap release), `LButton`/`RButton` click while active, errors during activation.
2.  **`Escape::` Hotkey (`hotkeys.ahk`):** Calls `Cleanup()`. Includes robust error handling with a forced cleanup attempt (`ForceCloseAllGuis`, manual state/variable reset) if standard `Cleanup()` fails.
3.  **`Space::` Hotkey (`hotkeys.ahk`):**
    *   Saves mouse pos. Stops `TrackCursor`. Sets `currentState = State_IDLE`.
    *   Hides GUIs (`highlight`, `subGrid`, `overlays`).
    *   Performs `Click("Left")`.
    *   Calls `Cleanup()`.
4.  **`Cleanup()` (`activation.ahk`):**
    *   Checks if already `IDLE`.
    *   Stops `TrackCursor`. Calls `TransitionToState(State_IDLE)` (handles initial GUI hiding).
    *   Resets flags (`g_ModifierState.inHoldMode`, `gridActivationInProgress`).
    *   Resets `StateMap` selection keys (`firstKey`, `activeCellKey`, etc.) and `g_firstKeyPressed`.
    *   Resets ultra-fast state (`inUltraFastMode`, `activeRowKey`).
    *   Explicitly hides GUIs again (best effort).
    *   Waits (`Sleep(30)`).
    *   Destroys GUI objects (`highlight.Destroy()`, etc.) and clears global variables (`highlight = ""`, etc.). Clears `StateMap['overlays']`.
    *   Calls `ForceCloseAllGuis()` (`utils.ahk`) as a final safety net.
5.  **`DeactivateGrid()` (`activation.ahk`):** Called by LButton/RButton clicks. Similar to `Cleanup` but includes debounce (`stateTransitionDelay`), calls `TransitionToState(State_IDLE)`, and handles `SaveCellMemory()`.

**J. Monitor Switching (`core/monitor.ahk`)**

1.  **Triggers:** `Tab` hotkey (`CycleToNextMonitor`), `Number` hotkey while active (`SwitchMonitor`), `CapsLock + Number` hotkey (`SwitchMonitor`, potentially activating grid first).
2.  **`SwitchMonitor(monitorNum)`:**
    *   Applies `monitorMapping`. Validates index. Checks if already on target.
    *   Stops `TrackCursor`.
    *   Gets `newOverlay`.
    *   Hides elements on old monitor (`currentOverlay.Hide()`, `highlight.Hide()`, `subGrid.Hide()`).
    *   Updates `StateMap['currentOverlay'] = newOverlay`.
    *   Shows `newOverlay`.
    *   Moves mouse (`MouseMove`) to the center of the new monitor.
    *   Resets selection state (`firstKey`, `activeCellKey`, `activeRowKey`, etc.)
    *   Calls `TransitionToState(State_GRID_VISIBLE)`.
    *   Starts `TrackCursor`.
3.  **`CycleToNextMonitor()`:** Determines current physical index, finds next mapped physical index in sorted list, calls `SwitchMonitor()`.

**K. Settings (`settings_gui.ahk`, `memory_settings.ahk`)**

1.  **Trigger:** `:*:;settings::` hotstring calls `ShowSettingsGUI()`.
2.  **`ShowSettingsGUI()`:** Creates GUI, populates controls with current global config values.
3.  **Apply Button:** Reads values from GUI controls, updates global config variables, calls `SaveSettings()`. Tries to apply some visual settings (transparency, highlight color) live.
4.  **`SaveSettings()`:** Writes current global config variables to `antimouse_settings.ini`.

---

### How Subgrids are Activated:

1.  **Instant Activation (On Initial Grid Display):** During `CapsLock_Q`, after transitioning to `GRID_VISIBLE`, the script immediately checks `GetCurrentCell()`. If the cursor is already inside a cell, it performs another transition straight to `SUBGRID_STANDARD`.
2.  **Grid Navigation Completion:** After a valid two-key sequence (Col->Row or Row->Col) is detected in `HandleSecondKey`, it calls `TransitionToState(State_SUBGRID_STANDARD)`.
3.  **Cursor Hover (Tracking):** While in `GRID_VISIBLE`, the `TrackCursor` timer periodically checks `GetCellAtPosition`. If the cursor moves *into* a cell (`currentCellKey` becomes non-empty and different from `lastTrackedCellKey_GridVisible`) **and** no grid keys are being processed (`g_firstKeyPressed == ""`, Task 5.10 check), it calls `TransitionToState(State_SUBGRID_STANDARD)`.

### Potential Conflicts / Lack of Sense:

1.  **Race Condition: `TrackCursor` vs. Key Handling:**
    *   `TrackCursor` can change state (`GRID_VISIBLE` -> `SUBGRID_STANDARD` on hover).
    *   `HandleKey`/`HandleSecondKey` also change state.
    *   If a user presses the second grid key *just as* `TrackCursor` decides to transition state due to hover, the intended `HandleSecondKey` logic might run in the wrong state or conflict with the transition initiated by `TrackCursor`. The `g_firstKeyPressed == ""` check in `TrackCursor` (Task 5.10) aims to mitigate this hover activation conflict, but the general potential for timer vs. hotkey interaction remains.
    *   Similarly, if the cursor leaves the subgrid cell (`TrackCursor` calls `StartNewSelection`) at the *exact* moment the user presses a grid key (`ProcessKeyPress` calls `StartNewSelection`), `StartNewSelection` might be called twice, potentially causing redundant actions or state inconsistencies.
2.  **Rapid Double Transition in `CapsLock_Q`:** The `IDLE` -> `GRID_VISIBLE` -> `SUBGRID_STANDARD` transition within a single function call (`CapsLock_Q`) if the cursor starts inside a cell feels slightly complex and might hide subtle bugs compared to determining the target state first and transitioning once.
3.  **Implicit Ultra-Fast State Reversion:** `HandleRowKeyRelease` resets the `inUltraFastMode` flag and changes the subgrid GUI layout but *doesn't* call `TransitionToState(State_SUBGRID_STANDARD)`. The state change back seems reliant on `TrackCursor` noticing the flag change or subsequent actions. This could lead to a brief period where the state is `SUBGRID_ULTRAFAST` but the flag/GUI are standard, or vice-versa, depending on timing. An explicit transition might be safer.
4.  **`g_firstKeyPressed` vs. `StateMap['firstKey']`:** Having two variables (`g_firstKeyPressed` in `state.ahk` / `grid_keys.ahk` and `StateMap['firstKey']`) to track the first key seems redundant and increases the chance of them becoming desynchronized. `StateMap['firstKey']` is reset in more places (activation, cleanup), while `g_firstKeyPressed` is mainly managed within `grid_keys.ahk` and `StartNewSelection`. Consolidating to one might be cleaner.
5.  **Invalid Grid Sequence Handling:** The robust fix (Task 5.10) in `HandleSecondKey` calls `StartNewSelection(key)` when an invalid sequence (Col->Col or Row->Row) occurs. This is safe but might feel slightly abrupt to the user compared to the previous behavior of just changing the first key. However, the previous behavior could lead to complex state issues.
6.  **State Preservation on Monitor Switch:** `SwitchMonitor` explicitly transitions to `GRID_VISIBLE` and resets selection state. While simple, it means any ongoing selection or subgrid context is lost when switching monitors. Preserving/restoring state might be desired but adds complexity.

### Optimization & Scalability:

*   **Optimization:**
    *   **Good:** Using classes for GUIs, central `StateMap`, modular files. Buffered logging (`ProcessLogQueue`) avoids frequent file I/O bottlenecks. Reusing GUI controls in `SubGridOverlay` is efficient.
    *   **Areas for Improvement:** Heavy reliance on `global` could be reduced by passing state objects (like `StateMap`) explicitly. Minimizing `Sleep()` calls. The `TrackCursor` timer runs constantly when active; could potentially be optimized (e.g., only run when needed, or use different intervals). The numerous checks for `IsObject()` add safety but also overhead.
*   **Scalability:**
    *   **Good:** The modular structure is excellent for scalability. Adding new layouts is data-driven (`config.ahk`). Adding new states is feasible by updating `ProcessKeyPress` and `TransitionToState`.
    *   **Areas for Improvement:** The tight coupling between `TrackCursor`, `TransitionToState`, `HandleKey`, and `StartNewSelection` (especially around automatic subgrid activation/deactivation and state resets) might become complex to manage if significantly more states or interactions are added. The CapsLock handling logic in `hotkeys.ahk` is intricate and might be hard to modify or extend significantly. Adding completely new *types* of interaction (e.g., drag modes) would require careful integration into the existing state machine and key processing logic.

---

## 2. Mermaid Diagrams

### High-Level State Diagram

```mermaid
stateDiagram-v2
    direction LR
    [*] --> IDLE : Init / Cleanup / Deactivate

    IDLE --> GRID_VISIBLE : Activate (No Cell Hover)
    IDLE --> SUBGRID_STANDARD : Activate (Cell Hover - Instant)

    state GRID_VISIBLE {
        [*] --> WaitForKey : Entry / New Selection
        WaitForKey --> FirstKeySelected : Grid Key (1st) / HandleFirstKey
        FirstKeySelected --> WaitForKey : Invalid 2nd Key / HandleSecondKey -> StartNewSelection(key)
        FirstKeySelected --> SUBGRID_STANDARD : Valid 2nd Key / HandleSecondKey
        [*] --> HoverTracking : TrackCursor Timer
        HoverTracking --> SUBGRID_STANDARD : Cursor Enters Cell (No Key Held) / TrackCursor
        HoverTracking --> HighlightUpdate : Cursor Enters Cell (Key Held) / TrackCursor
        HighlightUpdate --> HoverTracking
        HoverTracking --> HighlightHide : Cursor Leaves Cells / TrackCursor
        HighlightHide --> HoverTracking
    }

    state SUBGRID_STANDARD {
         [*] --> Ready : Entry
         Ready --> Ready : Subgrid Key / ProcessStandardSubgridKey
         Ready --> GRID_VISIBLE : Grid Key / StartNewSelection
         Ready --> SUBGRID_ULTRAFAST : Row Key Held > Threshold / TrackCursor (Inferred)
         [*] --> CellTracking : TrackCursor Timer
         CellTracking --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
         CellTracking --> Ready : Cursor Inside Cell
    }

     state SUBGRID_ULTRAFAST {
         [*] --> Ready : Entry
         Ready --> Ready : UltraFast Key / ProcessUltraFastKey
         Ready --> GRID_VISIBLE : Grid Key / StartNewSelection
         Ready --> SUBGRID_STANDARD : Row Key Release / HandleRowKeyRelease (Implicit State Change via Flag)
         [*] --> CellTracking : TrackCursor Timer
         CellTracking --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
         CellTracking --> Ready : Cursor Inside Cell
     }


    GRID_VISIBLE --> IDLE : Cleanup (Esc/Space/Tap) / Deactivate
    SUBGRID_STANDARD --> IDLE : Cleanup (Esc/Space) / Deactivate
    SUBGRID_ULTRAFAST --> IDLE : Cleanup (Esc/Space) / Deactivate

    GRID_VISIBLE --> GRID_VISIBLE : Monitor Switch
    SUBGRID_STANDARD --> GRID_VISIBLE : Monitor Switch
    SUBGRID_ULTRAFAST --> GRID_VISIBLE : Monitor Switch
```

### Activation Flow (CapsLock_Q focus)

```mermaid
graph TD
    subgraph Activation Trigger [User Action]
        A[Double-Tap CapsLock] --> B(hotkeys.ahk: CapsLock::);
    end

    subgraph Activation Logic [activation.ahk: CapsLock_Q()]
        B --> C{Already Active?};
        C -- Yes --> D[Cleanup()] --> Z[End];
        C -- No --> E{Debounce Check};
        E -- Fail --> Z;
        E -- OK --> F[Set Flag / Reset State / Load Memory];
        F --> G[Init GUIs: Highlight/SubGrid];
        G --> H[Create/Show Overlays / Find Current];
        H --> I{Overlays OK?};
        I -- No --> D;
        I -- Yes --> J[TransitionToState(GRID_VISIBLE)];
        J --> K[GetCurrentCell()];
        K --> L{Cell Found?};
        L -- No --> M[Start TrackCursor] --> Y[Grid Ready];
        L -- Yes --> N[Get Boundaries];
        N --> O{Boundaries OK?};
        O -- No --> M;
        O -- Yes --> P[Set activeCellKey];
        P --> Q[Update Highlight];
        Q --> R[Update SubGrid Position];
        R --> S[TransitionToState(SUBGRID_STANDARD)];
        S --> M;
    end

    subgraph Final State
        Y --> Z;
    end
```

### Key Press Routing (ProcessKeyPress)

```mermaid
graph TD
    A[Hotkey Trigger (e.g., 'w')] --> B(core/key_processing.ahk: ProcessKeyPress);
    B --> C{currentState?};
    C -- GRID_VISIBLE --> D[HandleKey(key)];
    C -- SUBGRID_STANDARD --> E{IsSubGridKey?};
    E -- Yes --> F[ProcessStandardSubgridKey(key)];
    E -- No --> G{CheckIfGridKey?};
    G -- Yes --> H[StartNewSelection(key)];
    G -- No --> Z[Ignore];
    C -- SUBGRID_ULTRAFAST --> I{IsUltraFastSubGridKey?};
    I -- Yes --> J[ProcessUltraFastKey(key)];
    I -- No --> K{CheckIfGridKey?};
    K -- Yes --> H;
    K -- No --> Z;
    C -- IDLE --> Z;

    subgraph Endpoints
      D --> X[Grid Action / State Change];
      F --> Y[Subgrid Action];
      H --> W[Reset to Grid / State Change];
      J --> Y;
      Z --> ZEnd[No Action];
    end
```

### Subgrid Activation Summary Table

| Activation Method        | Triggering Function/File        | State Before        | State After           | Key Logic Involved                                     | Notes                                                              |
| :----------------------- | :------------------------------ | :------------------ | :-------------------- | :----------------------------------------------------- | :----------------------------------------------------------------- |
| **Instant (On Activate)** | `CapsLock_Q` (activation.ahk) | `IDLE`              | `SUBGRID_STANDARD`    | `GetCurrentCell`, `GetCellBoundaries`                  | Only if cursor starts within a cell when grid is activated.        |
| **Grid Navigation**     | `HandleSecondKey` (grid_keys.ahk) | `GRID_VISIBLE`      | `SUBGRID_STANDARD`    | Valid Col->Row or Row->Col sequence                    | Standard way to select a cell and enter its subgrid.             |
| **Cursor Hover**        | `TrackCursor` (tracking.ahk)    | `GRID_VISIBLE`      | `SUBGRID_STANDARD`    | Cursor moves into a cell, `g_firstKeyPressed == ""` | Automatic activation by hovering. (Task 5.10 may modify this). |