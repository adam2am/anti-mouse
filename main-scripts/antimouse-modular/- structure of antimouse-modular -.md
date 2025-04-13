## 1. Logical Function/Variable Flow (Validation and Refinement)

The logical flow described in the `structure of antimouse-modular -.md` file appears quite comprehensive and accurate based on the provided code snippets. Let's highlight key aspects and potential nuances found directly in the code:

**A. Initialization (`1main.ahk`, `config.ahk`, `state.ahk`, `memory_settings.ahk`)**

*   **Order:** Correctly identifies the `#Include` order and the loading sequence: config -> state -> utils -> classes -> memory -> core modules -> activation -> settings GUI -> hotkeys.
*   **Data Loading:** `LoadSettings()` correctly reads the `.ini` file into global variables (`selectedLayout`, `storePerMonitor`, `showcaseDebug`, `monitorMapping`, etc., defined in `config.ahk` and potentially overridden by the `.ini`). `LoadCellMemory()` correctly reads `cell_memory.txt` into the `cellMemory` Map.
*   **Layout Application:** `activeColKeys` and `activeRowKeys` are correctly populated based on `selectedLayout` from `layoutConfigs` (defined in `config.ahk`). The fallback to layout 1 (though the code shows layout 2 in `activation.ahk` fallback) is noted. `1main.ahk` uses `selectedLayout` directly to set `activeColKeys`/`activeRowKeys`, while `activation.ahk` re-reads `layoutConfigs[selectedLayout]` into `StateMap`.
*   **Timers:** `ProcessLogQueue` (`utils.ahk`) and `ForceCapsLockOff` (`utils.ahk`) timers are correctly identified.
*   **Persistence:** `Persistent()` keeps the script running, starting in `State_IDLE`.

**B. Activation Flow (`hotkeys.ahk`, `activation.ahk`, `state.ahk`, `core/tracking.ahk`, `core/positioning.ahk`, `core/state_transitions.ahk`)**

*   **Trigger:** The `CapsLock::` hotkey logic using `g_ModifierState` map (`capsPressedFirstTime`, `capsFirstReleased`, etc.) for double-tap detection is accurately described.
*   **`CapsLock_Q()`:**
    *   **Guards:** `gridActivationInProgress` and `gridActivationTime` prevent rapid re-activation. Correctly handles cleanup if already active.
    *   **State Reset:** Resets `StateMap` keys (`firstKey`, `activeCellKey`, etc.) and ultra-fast state (`inUltraFastMode`).
    *   **Config/Memory:** Reloads `cellMemory`, gets layout config, sets `StateMap['activeColKeys']`/`StateMap['activeRowKeys']`.
    *   **GUI Init:** Creates `HighlightOverlay` and `SubGridOverlay` instances (`gui_classes.ahk`), storing them in globals `highlight` and `subGrid`.
    *   **Overlay Creation:** Loops monitors, creates `OverlayGUI` instances (`gui_classes.ahk`), shows them, populates `StateMap['overlays']`, and determines `StateMap['currentOverlay']` based on mouse position (fallback to first).
    *   **Initial State:** `TransitionToState(State_GRID_VISIBLE)` is called.
    *   **Instant Subgrid Activation:** This is a key point correctly identified. `GetCurrentCell()` (`tracking.ahk`) -> `GetCellAtPosition()` (`positioning.ahk`) is called. If a cell is found, `StateMap['activeCellKey']` is set, `highlight.Update` and `subGrid.Update` are called, and crucially `TransitionToState(State_SUBGRID_STANDARD)` follows immediately.
    *   **Tracking:** `SetTimer(TrackCursor, 50)` is started.
    *   **Flags:** `gridActivationInProgress` is reset.

**C. Key Processing Flow (`hotkeys.ahk`, `core/key_processing.ahk`)**

*   **Trigger:** Hotkeys defined with `#HotIf currentState != State_IDLE` trigger `ProcessKeyPress()`.
*   **`ProcessKeyPress()`:** The routing logic based on `currentState` is accurately described:
    *   `GRID_VISIBLE`: `CheckIfGridKey` -> `HandleKey`.
    *   `SUBGRID_STANDARD`: `IsSubGridKey` -> `ProcessStandardSubgridKey`, OR `CheckIfGridKey` -> `StartNewSelection`.
    *   `SUBGRID_ULTRAFAST`: `IsUltraFastSubGridKey` -> `ProcessUltraFastKey`, OR `CheckIfGridKey` -> `StartNewSelection`.
    *   `IDLE`: Ignore.
    *   **Navigation Key (`Escape`):** Correctly identified handling for `enableFreeNavigation` in subgrid states -> `TransitionToState(GRID_VISIBLE)`.

**D. Grid Navigation Flow (`core/grid_keys.ahk`, `core/state_transitions.ahk`, `core/positioning.ahk`)**

*   **`HandleKey()`:** Correctly identifies the logic: check state, determine key type, stop tracker, check `StateMap['firstKey']`.
*   **`HandleFirstKey()`:** Stores `key` in `StateMap['firstKey']`. The contextual guessing (Task 6.1) using `GetCellAtPosition()` and `hoveredCellKey` is accurately described, along with the fallback using `preservedRowKey` (from `StartNewSelection`), `lastSelectedRowIndex`, or defaults. Updates `highlight` and moves mouse. Restarts tracker.
*   **`HandleSecondKey()`:** Retrieves `firstKey`, checks sequence validity.
    *   **Valid:** Constructs `finalCellKey`, sets `proceedToSubgrid`, updates indices.
    *   **Invalid (Col->Col/Row->Row):** Correctly identifies the "Robust Fix 5.10" where it resets `StateMap['firstKey']` and calls `StartNewSelection(key)` (treating the second key as a new first key).
    *   **Proceed:** Gets boundaries, sets `StateMap['activeCellKey']`, determines/sets `StateMap['activeRowKey']`, clears `preservedRowKey`, updates `highlight`/`subGrid`, resets `StateMap['firstKey']`, calls `TransitionToState(State_SUBGRID_STANDARD)`. Restarts tracker.

**E. Subgrid Navigation Flow (`core/subgrid_keys.ahk`, `gui_classes.ahk`, `memory_settings.ahk`)**

*   **`ProcessStandardSubgridKey()` / `ProcessUltraFastKey()`:** State/debounce checks are correct. Calls `subGrid.GetTargetCoordinates()`/`GetUltraFastTargetCoordinates()` (from `gui_classes.ahk`). Mouse move, `StateMap['activeSubCellKey']` update, `UpdateCellMemory()` call (with "ultra:" prefix for ultra-fast). `ProcessUltraFastKey` also calls `highlight.Update` to keep the main cell highlight visible.
*   **`UpdateCellMemory()`:** Constructs key based on `storePerMonitor`, updates `cellMemory` map. Correctly notes `SaveCellMemory()` is not called here.

**F. Ultra-Fast Mode Flow (`core/subgrid_keys.ahk`, `gui_classes.ahk`, `hotkeys.ahk`, `core/state_transitions.ahk`)**

*   **Activation (Inferred but Accurate):** The description matches the likely implementation based on `rowKeyHoldThreshold`, `enableUltraFast`, setting `StateMap['inUltraFastMode']`, `StateMap['activeRowKey']`, calling `subGrid.SwitchToUltraFast()`, and `TransitionToState(State_SUBGRID_ULTRAFAST)`. *The triggering mechanism (timer/hook) is not explicitly detailed in the provided files but the described logic flow is sound.*
*   **Key Handling:** `ProcessKeyPress` -> `ProcessUltraFastKey` is correct.
*   **Deactivation:**
    *   Trigger: `[key] up::` hotkey -> `CheckRowKeyUpForUltraFast` -> `HandleRowKeyRelease`.
    *   `HandleRowKeyRelease()`: Checks flags/key, sets `StateMap['inUltraFastMode'] = false`, calls `subGrid.SwitchToStandard()`, resets `StateMap['activeRowKey']`.
    *   **Conflict/Issue:** The analysis correctly identifies the **critical point**: `HandleRowKeyRelease` *doesn't* explicitly call `TransitionToState(State_SUBGRID_STANDARD)`. It also correctly points out the **contradictory `#HotIf` condition** (`#HotIf currentState == State_SUBGRID_STANDARD && StateMap.Get("inUltraFastMode", false)`) on the `up` hotkey, which suggests a potential bug or flaw in state management. The analysis notes this might rely on `TrackCursor` or other implicit mechanisms, which is a good observation of the potential problem.
    *   **UPDATE:** Looking at the end of `HandleRowKeyRelease` in `subgrid_keys.ahk`, it *does* now include `TransitionToState(State_SUBGRID_STANDARD)` (Task 6.8 Explicit Ultra-Fast Transition). This resolves the conflict noted in the original analysis. The `#HotIf` condition in `hotkeys.ahk`, however, *still* checks for `State_SUBGRID_STANDARD && StateMap.Get("inUltraFastMode", false)`. This `#HotIf` condition seems problematic as `inUltraFastMode` should be false *after* the transition to STANDARD. It perhaps should have checked `currentState == State_SUBGRID_ULTRAFAST`? Or the transition happens *before* the `up` event's condition is fully evaluated? Let's assume the transition works as intended now, but the hotkey condition remains slightly odd.

**G. State Transition: Subgrid -> Grid (`StartNewSelection` in `core/state_transitions.ahk`)**

*   **Trigger:** Grid key press in subgrid state (via `ProcessKeyPress`) or cursor leaving cell boundaries (via `TrackCursor`).
*   **Execution:** Stops tracker. Context preservation (`preservedColKey`, `preservedRowKey`) logic is accurately described. `TransitionToState(State_GRID_VISIBLE)`. Clears relevant `StateMap` keys (`activeCellKey`, `firstKey`, `activeRowKey`, `inUltraFastMode`, etc.). Calls `HandleKey(key, true)` if triggered by a key press, otherwise restarts `TrackCursor`.

**H. Cursor Tracking (`TrackCursor` in `core/tracking.ahk`, `core/positioning.ahk`, `core/state_transitions.ahk`)**

*   **Execution:** Runs periodically when not `IDLE`. Uses `trackingInProgress` flag. Uses `lastTrackedCellKey_GridVisible`.
*   **Subgrid States:** Correctly identifies checking boundaries and calling `StartNewSelection("")` if cursor leaves the cell.
*   **Grid Visible State:** Calls `GetCellAtPosition`, compares with `lastTrackedCellKey_GridVisible`.
    *   **If Changed:** If valid cell, updates `highlight`.
    *   **Hover Activation:** Correctly notes that the code block for automatic hover activation (`TransitionToState(State_SUBGRID_STANDARD)`) is **commented out/removed (Task 5.10 | REMOVED HOVER ACTIVATION)** in the provided `tracking.ahk` snippet. Highlight follows, state doesn't change on hover alone.
    *   **If Outside:** Hides `highlight`.
*   **Finally:** Resets `trackingInProgress`.

**I. Cleanup/Deactivation (`hotkeys.ahk`, `activation.ahk`, `utils.ahk`, `core/state_transitions.ahk`)**

*   **Triggers:** Correctly listed (`Escape`, `Space`, `CapsLock Up` single tap, clicks on overlays, `Shift+CapsLock`).
*   **Handlers:**
    *   `Escape::`: Calls `Cleanup()`, includes robust `try/catch` with `ForceCloseAllGuis`.
    *   `Space::`: Saves pos, stops tracker, **sets `currentState = State_IDLE` first**, hides GUIs (safely), `Click("Left")`, calls `Cleanup()`.
    *   `*~$LButton::` / `*~$RButton::` / `*~$CapsLock::` (with Shift): **Calls `TransitionToState(State_IDLE)` first**, then `DeactivateGrid(true)`.
    *   `Cleanup()`: Stops timer, calls `TransitionToState(State_IDLE)`, resets flags/StateMap keys (including `preservedRowKey`), resets ultra-fast state, hides/destroys GUIs (safely with `IsObject`), clears globals, calls `ForceCloseAllGuis()`.
    *   `DeactivateGrid()`: Debounce check, stops timer, destroys GUIs, resets StateMap/flags, calls `TransitionToState(State_IDLE)`, optionally calls `SaveCellMemory()`.

**J. Monitor Switching (`core/monitor.ahk`, `hotkeys.ahk`)**

*   **Triggers:** `Tab::` -> `CycleToNextMonitor()`. `N::` / `CapsLock & N::` / `CapsLock + N::` -> `SwitchMonitor(N)`. Logic seems correct.
*   **`SwitchMonitor()`:** Applies mapping, validates, stops tracker, hides old elements, updates `StateMap['currentOverlay']`, shows new overlay, moves mouse, **resets selection state (`firstKey`, `activeCellKey`, etc.)**, calls `TransitionToState(State_GRID_VISIBLE)`, starts tracker.
*   **`CycleToNextMonitor()`:** Logic for finding current physical index, sorting physical indices, finding the next index, and calling `SwitchMonitor` is accurately described.

**K. Settings (`settings_gui.ahk`, `memory_settings.ahk`)**

*   **Trigger:** `:*:;settings::` -> `ShowSettingsGUI()`.
*   **`ShowSettingsGUI()`:** GUI creation, populating controls, event handlers (`applyBtn.OnEvent`, etc.).
*   **Apply Button:** Reads controls, updates globals (`selectedLayout`, `storePerMonitor`, etc.), constructs/updates `monitorMapping`, attempts live updates (transparency, highlight color), calls `SaveSettings()`.
*   **`SaveSettings()`:** Writes globals to `.ini` using `IniWrite`.

---

### How Subgrids are Activated (Verified):

1.  **Instant Activation (On Initial Grid Display):** Yes, in `CapsLock_Q` (`activation.ahk`), after `TransitionToState(GRID_VISIBLE)`, `GetCurrentCell()` is called. If the cursor is in a cell, `TransitionToState(SUBGRID_STANDARD)` is called immediately.
2.  **Grid Navigation Completion:** Yes, in `HandleSecondKey` (`core/grid_keys.ahk`), after a valid two-key sequence, `TransitionToState(SUBGRID_STANDARD)` is called.
3.  **~~Cursor Hover (Tracking)~~:** **No.** The analysis correctly identifies that this code is commented out in `tracking.ahk` (Task 5.10). Hovering only updates the highlight.

---

### Potential Conflicts / Lack of Sense (Verified/Refined):

1.  **~~Race Condition: `TrackCursor` vs. Key Handling (Hover Activation)~~:** Less relevant now hover activation is disabled. The potential for `StartNewSelection` being called twice (once by `TrackCursor` if cursor leaves, once by `ProcessKeyPress` if a grid key is hit simultaneously) might still exist but is less likely to cause major issues than hover activation conflicts.
2.  **Rapid Double Transition in `CapsLock_Q`:** Yes, `IDLE` -> `GRID_VISIBLE` -> `SUBGRID_STANDARD` happens quickly. This is efficient but slightly less explicit than determining the target state first. Seems acceptable.
3.  **~~Implicit Ultra-Fast State Reversion~~:** **Resolved.** `HandleRowKeyRelease` now explicitly calls `TransitionToState(State_SUBGRID_STANDARD)`. The `#HotIf` condition (`#HotIf currentState == State_SUBGRID_STANDARD && StateMap.Get("inUltraFastMode", false)`) in `hotkeys.ahk` for the `up` event remains questionable, as `inUltraFastMode` should be false *by the time* the state is `STANDARD`. This might work due to timing or might be a latent issue if state transitions aren't instant.
4.  **`g_firstKeyPressed` vs. `StateMap['firstKey']`:** The analysis correctly identifies this redundancy. `g_firstKeyPressed` seems to have been removed or replaced by `StateMap['firstKey']` in later refactoring according to comments like "Task 6.2: Consolidate firstKey State Variable" in `grid_keys.ahk` and `monitor.ahk`. The provided markdown analysis might be based on a slightly earlier version where both existed. Assuming consolidation is complete, this conflict is resolved.
5.  **Context Preservation (`StartNewSelection`):** Yes, `preservedRowKey` and `preservedColKey` are used. `HandleFirstKey` uses `preservedRowKey` for fallback guessing. Seems functional, adds complexity but aids usability.
6.  **State Loss on Monitor Switch:** Yes, `SwitchMonitor` explicitly resets selection state and goes to `GRID_VISIBLE`. This is a clear design choice, losing context upon switching.

---

### Optimization & Scalability (Verified):

*   **Optimization:** The assessment seems fair. Modularity, classes, `StateMap`, buffered logging are good. `global`s, `IsObject`, constant `TrackCursor`, `Sleep`, `ForceCloseAllGuis` are areas for potential minor improvements.
*   **Scalability:** Assessment is accurate. Adding layouts/states is relatively straightforward due to modularity. Adding fundamentally new interaction modes would be complex due to the tight coupling in the core state/key/tracking logic. The CapsLock activation logic is intricate.

---

## 2. Mermaid Diagrams

Based on the verified flow and the provided code:

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
        %% Hover activation to SUBGRID_STANDARD is DISABLED %%
    }

    state SUBGRID_STANDARD {
         [*] --> Ready : Entry / TransitionToState
         Ready --> Ready : Subgrid Key (g,h,b,n) / ProcessStandardSubgridKey
         Ready --> GRID_VISIBLE : Grid Key / ProcessKeyPress -> StartNewSelection
         Ready --> GRID_VISIBLE : Navigation Key (Esc) / ProcessKeyPress -> TransitionToState(GRID_VISIBLE)
         Ready --> SUBGRID_ULTRAFAST : Row Key Held > Threshold / (Inferred Timer/Hook) -> TransitionToState
         [*] --> CellTracking : TrackCursor Timer
         CellTracking --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
         CellTracking --> Ready : Cursor Inside Cell
    }

     state SUBGRID_ULTRAFAST {
         [*] --> Ready : Entry / TransitionToState
         Ready --> Ready : UltraFast Key (qwer...) / ProcessUltraFastKey
         Ready --> GRID_VISIBLE : Grid Key / ProcessKeyPress -> StartNewSelection
         Ready --> GRID_VISIBLE : Navigation Key (Esc) / ProcessKeyPress -> TransitionToState(GRID_VISIBLE)
         Ready --> SUBGRID_STANDARD : Row Key Release / HandleRowKeyRelease -> TransitionToState(SUBGRID_STANDARD) %% Explicit Transition (Task 6.8) %%
         [*] --> CellTracking : TrackCursor Timer
         CellTracking --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
         CellTracking --> Ready : Cursor Inside Cell
     }


    GRID_VISIBLE --> IDLE : Cleanup (Esc/Space/Tap/Click/Shift+Caps) / DeactivateGrid / TransitionToState(IDLE)
    SUBGRID_STANDARD --> IDLE : Cleanup (Esc/Space/Click/Shift+Caps) / DeactivateGrid / TransitionToState(IDLE)
    SUBGRID_ULTRAFAST --> IDLE : Cleanup (Esc/Space/Click/Shift+Caps) / DeactivateGrid / TransitionToState(IDLE)

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
    A[Hotkey Trigger (e.g., 'w', 'g', 'q', 'Escape')] --> B(core/key_processing.ahk: ProcessKeyPress);
    B --> Nav{Nav Key ('Escape')?};
    Nav -- Yes --> NavCheckState{In Subgrid State?};
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
| **~~Cursor Hover~~**      | `TrackCursor` (`core/tracking.ahk`)       | `GRID_VISIBLE` | `SUBGRID_STANDARD` | Cursor moves into cell, `StateMap['firstKey'] == ""` (CHECK IF ENABLED) | Automatic activation by hovering. **Disabled based on code comments (Task 5.10).**                   |
| **Ultra-Fast Mode**     | (Inferred Timer/Hook + `core/subgrid_keys.ahk`) | `SUBGRID_STANDARD` | `SUBGRID_ULTRAFAST` | Row key held > `rowKeyHoldThreshold`, `subGrid.SwitchToUltraFast`, `TransitionToState` | Activates the 3x4 subgrid layout. Trigger mechanism inferred.                                      |