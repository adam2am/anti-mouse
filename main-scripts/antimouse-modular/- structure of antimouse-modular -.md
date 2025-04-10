/main-scripts/antimouse-modular/
├── - structure of antimouse-modular -.md (This file)
├── 1main.ahk ; Main entry point, initialization, includes
├── activation.ahk ; Grid activation (CapsLock_Q) and cleanup logic (Cleanup, DeactivateGrid)
├── antimouse_core.log ; Core diagnostic log file
├── antimouse_settings.ini ; User settings storage
├── cell_memory.txt ; Stores remembered cell->subcell mappings
├── config.ahk ; Global configuration variables (layouts, keys, thresholds)
├── core/ ; Directory for refactored core logic modules
│ ├── grid_keys.ahk ; Handles main grid key presses (HandleKey, HandleFirstKey, HandleSecondKey)
│ ├── key_processing.ahk ; Routes key presses based on state (ProcessKeyPress, CheckIfGridKey)
│ ├── monitor.ahk ; Monitor switching logic (SwitchMonitor, CycleToNextMonitor)
│ ├── positioning.ahk ; Cell finding logic (GetCellAtPosition - assumed, not provided but referenced)
│ ├── state_transitions.ahk ; Handles transitions between states (TransitionToState, StartNewSelection)
│ ├── subgrid_keys.ahk ; Handles subgrid/ultra-fast key presses and row release (ProcessStandardSubgridKey, ProcessUltraFastKey, HandleRowKeyRelease, UpdateCellMemory)
│ └── tracking.ahk ; Cursor tracking timer logic (TrackCursor, GetCurrentCell, ResetLastTrackedKey)
├── debugRapidRefresh.log ; Debug log for rapid events
├── debug_log.txt ; General debug log (potentially unused/legacy)
├── gui_classes.ahk ; Class definitions for GUI overlays (OverlayGUI, SubGridOverlay, HighlightOverlay)
├── hotkeys.ahk ; All hotkey definitions (#HotIf contexts, CapsLock logic)
├── memory_settings.ahk ; Functions for loading/saving settings and cell memory (Load/SaveSettings, Load/SaveCellMemory)
├── settings_gui.ahk ; Settings GUI creation and handling (ShowSettingsGUI)
├── state.ahk ; Global state variables (currentState, StateMap, etc.)
└── utils.ahk ; Utility functions (validation, GUI cleanup, ForceCapsLockOff, etc.)
## Core Concepts

*   **States:** The script operates in distinct states defined in `state.ahk`: `IDLE`, `GRID_VISIBLE`, `SUBGRID_STANDARD`, `SUBGRID_ULTRAFAST`. State transitions drive the script's behavior, managed by `TransitionToState` in `core/state_transitions.ahk`.
*   **Overlays:** Transparent GUI windows (`OverlayGUI` wrapping `GridOverlay`, `SubGridOverlay`, `HighlightOverlay` defined in `gui_classes.ahk`) are displayed over monitors to show grid lines, cell keys, and selection highlights.
*   **StateMap:** A central `Map` object (`state.ahk`) holding dynamic state during grid operation (active keys, selected indices, GUI objects, ultra-fast mode status, etc.).
*   **Two-Key Selection:** Main grid cells are selected using a two-key sequence (Column Key + Row Key or Row Key + Column Key), handled primarily in `core/grid_keys.ahk`.
*   **Subgrids:** Once a main cell is selected, a smaller subgrid (standard 2x2 or ultra-fast 3x4, configured in `config.ahk` and managed by `SubGridOverlay` class) appears within that cell for finer mouse positioning. Keys handled in `core/subgrid_keys.ahk`.
*   **Cell Memory:** The script remembers the last selected subcell for each main cell (optionally per monitor, configured via `storePerMonitor`), loaded/saved by `memory_settings.ahk` into `cellMemory` (`state.ahk`) and updated by `UpdateCellMemory` in `core/subgrid_keys.ahk`.
*   **Ultra-Fast Mode:** Holding a row key (defined in `config.ahk`) during subgrid selection can trigger a larger 3x4 subgrid layout (`ultraFastSubGridKeys` in `config.ahk`) for faster selection. Triggered by `TrackCursor` (`core/tracking.ahk`) based on `rowKeyHoldThreshold` (`config.ahk`), keys handled by `ProcessUltraFastKey`, and deactivated by `HandleRowKeyRelease` (`core/subgrid_keys.ahk`).
*   **Activation:** Primarily triggered via CapsLock (double-tap or hold+key), managed by detailed hotkey logic in `hotkeys.ahk` using `g_ModifierState` (`state.ahk`) and timing (`doubleCapsThreshold` from `config.ahk`). `CapsLock_Q()` (`activation.ahk`) is the core activation function.
*   **Cleanup:** `Cleanup()` in `activation.ahk` is responsible for resetting state, hiding/destroying GUIs, and stopping timers. Triggered by Escape, Space (after click), or activation errors. `DeactivateGrid()` (`activation.ahk`) provides a more controlled deactivation path, potentially debounced.

## Logical Flow Description

1.  **Initialization (`1main.ahk`)**
    *   Sets AHK environment (`#Requires`, `#SingleInstance`, `CoordMode`, etc.).
    *   Includes all necessary modules in a specific order (Config -> State -> Utils/Classes -> Memory -> Core Logic -> Activation -> Settings -> Hotkeys).
    *   Calls `LoadSettings()` and `LoadCellMemory()` from `memory_settings.ahk`.
    *   Sets `activeColKeys`/`activeRowKeys` based on `selectedLayout`.
    *   Starts `ForceCapsLockOff` timer (`utils.ahk`).
    *   Script becomes persistent, driven by hotkeys and timers.

2.  **Activation (Example: CapsLock Double-Tap)**
    *   `CapsLock` hotkey (`hotkeys.ahk`) detects double-tap using `g_ModifierState` and timing (`doubleCapsThreshold`). Sets `g_ModifierState.inHoldMode = true`.
    *   Calls `CapsLock_Q()` (`activation.ahk`).
    *   `CapsLock_Q()`:
        *   Checks `gridActivationInProgress` flag and timing to prevent double activation. Sets the flag.
        *   Checks if `currentState != State_IDLE`; if so, calls `Cleanup()` and exits.
        *   Resets relevant `StateMap` variables (`firstKey`, `currentOverlay`, keys, indices, etc.) and `g_firstKeyPressed`.
        *   Loads `cellMemory`.
        *   Gets layout config (`layoutConfigs`, `selectedLayout` from `config.ahk`).
        *   Initializes `highlight` and `subGrid` GUI objects (`gui_classes.ahk`).
        *   Creates and shows `OverlayGUI` for each monitor, storing them in `StateMap['overlays']`. Determines `StateMap['currentOverlay']` based on initial mouse position (`startX`, `startY`).
        *   **Calls `TransitionToState(State_GRID_VISIBLE)`**.
        *   **Instant Subgrid Activation Logic:**
            *   Calls `GetCurrentCell()` (`core/tracking.ahk`, which calls `GetCellAtPosition` from `core/positioning.ahk`) to find the cell under the cursor (`initialCellKey`).
            *   If `initialCellKey` is found:
                *   Gets cell boundaries via `StateMap["currentOverlay"].GetCellBoundaries(initialCellKey)`.
                *   If boundaries are valid:
                    *   Sets `StateMap["activeCellKey"] = initialCellKey`.
                    *   Updates `highlight` overlay position (`highlight.Update`).
                    *   Updates `subGrid` overlay position (`subGrid.Update`).
                    *   **Calls `TransitionToState(State_SUBGRID_STANDARD)`**. (Note: This transitions *again* immediately after the GRID_VISIBLE transition).
                    *   *Memory check for remembered subcell is implicit; subgrid appears, mouse doesn't move automatically unless triggered by another action.*
            *   If no cell found or boundaries fail: State remains `GRID_VISIBLE` (from the first transition).
        *   Starts `TrackCursor` timer (`core/tracking.ahk`).
        *   Resets `gridActivationInProgress` flag upon success or failure.

3.  **Key Handling (`ProcessKeyPress` in `core/key_processing.ahk`)**
    *   Called by most letter/symbol hotkeys defined in `hotkeys.ahk` (when state is not `IDLE`).
    *   Uses `currentState` for routing:
    *   **If `currentState == State_GRID_VISIBLE`:** Calls `HandleKey(key)` (`core/grid_keys.ahk`).
    *   **If `currentState == State_SUBGRID_STANDARD`:**
        *   Calls `CheckIfGridKey(key)` (`core/key_processing.ahk`).
        *   If TRUE: Calls `StartNewSelection(key)` (`core/state_transitions.ahk`) to reset to grid view and process the key.
        *   If FALSE: Calls `HandleStandardSubgridKey(key)` (which calls `ProcessStandardSubgridKey` in `core/subgrid_keys.ahk`).
    *   **If `currentState == State_SUBGRID_ULTRAFAST`:**
        *   Calls `CheckIfGridKey(key)`.
        *   If TRUE: Calls `StartNewSelection(key)`.
        *   If FALSE: Calls `HandleUltraFastKey(key)` (which calls `ProcessUltraFastKey` in `core/subgrid_keys.ahk`).
    *   **If `currentState == State_IDLE`:** Ignores key press (activation handled by specific CapsLock hotkeys).

4.  **Grid Navigation (`HandleKey`, `HandleFirstKey`, `HandleSecondKey` in `core/grid_keys.ahk`)**
    *   Uses `g_firstKeyPressed` global (`state.ahk`) to track sequence.
    *   `HandleKey()` checks debounce (`stateTransitionDelay`), state validity, determines if key is Col/Row, calls `HandleFirstKey` or `HandleSecondKey`.
    *   `HandleFirstKey()`: Stores key in `g_firstKeyPressed` and `StateMap['firstKey']`. Guesses target cell based on `lastSelectedRowIndex` or middle column. Gets boundaries, updates `highlight`, moves mouse. Starts `TrackCursor`.
    *   `HandleSecondKey()`:
        *   Checks if first key was Col/Row and current key is the opposite (valid sequence).
        *   If valid: Determines `finalCellKey`, sets `proceedToSubgrid = true`.
        *   If invalid (Col->Col or Row->Row): Updates `g_firstKeyPressed`/`StateMap['firstKey']` to the *new* key and calls `HandleFirstKey()` again, effectively changing the first key selection.
        *   If other invalid sequence: Resets `g_firstKeyPressed`.
    *   **If `proceedToSubgrid`:**
        *   Gets boundaries for `finalCellKey`.
        *   If boundaries valid:
            *   Sets `StateMap['activeCellKey'] = finalCellKey`.
            *   Stores the actual row key used in `StateMap['activeRowKey']`.
            *   Updates `highlight`, moves mouse to cell center.
            *   Updates `subGrid` geometry (`subGrid.Update`).
            *   Resets `g_firstKeyPressed` / `StateMap['firstKey']`.
            *   **Calls `TransitionToState(State_SUBGRID_STANDARD)`**.
            *   *Memory check/automatic subcell move is not explicit here; user needs to press a subgrid key.*
        *   Starts `TrackCursor`.

5.  **Subgrid Navigation (`ProcessStandardSubgridKey`/`ProcessUltraFastKey` in `core/subgrid_keys.ahk`)**
    *   Checks state validity and debounce (`stateTransitionDelay`).
    *   Calls `subGrid.GetTargetCoordinates(subKey)` or `subGrid.GetUltraFastTargetCoordinates(subKey)`.
    *   If coordinates valid:
        *   Moves mouse (`MouseMove`).
        *   Updates `StateMap['activeSubCellKey']`.
        *   Calls `UpdateCellMemory(StateMap['activeCellKey'], subKey)` (potentially prefixed with "ultra:"). `UpdateCellMemory` handles `storePerMonitor` logic and saves to `cellMemory` map. *Note: `SaveCellMemory()` (writing to file) is not explicitly called here, relies on `saveMemoryOnExit` during cleanup or other triggers.*
        *   In `ProcessUltraFastKey`, it also ensures the `highlight` is shown over the main cell.

6.  **Ultra-Fast Mode (`TrackCursor` in `core/tracking.ahk`, `HandleRowKeyRelease` in `core/subgrid_keys.ahk`)**
    *   `TrackCursor` (Logic not fully shown, inferred): When `SUBGRID_STANDARD` and `StateMap['activeRowKey']` is held, checks if time held > `rowKeyHoldThreshold`. If yes: sets `StateMap['inUltraFastMode'] = true`, calls `subGrid.SwitchToUltraFast()`, and calls `TransitionToState(State_SUBGRID_ULTRAFAST)`.
    *   Row Key Up Hotkeys (`u up::`, etc. in `hotkeys.ahk`): Call `CheckRowKeyUpForUltraFast(key)`, which calls `HandleRowKeyRelease(key)` (`core/subgrid_keys.ahk`).
    *   `HandleRowKeyRelease()`: Checks if `enableUltraFast`, `inUltraFastMode` are true and released key matches `activeRowKey`. If yes: sets `StateMap['inUltraFastMode'] = false`, calls `subGrid.SwitchToStandard()`, resets `StateMap['activeRowKey']`. *It does not explicitly transition state back to `SUBGRID_STANDARD` here, relies on `TrackCursor` or other actions.*

7.  **State Transition: Subgrid -> Grid (`StartNewSelection` in `core/state_transitions.ahk`)**
    *   Called by `ProcessKeyPress` when a grid key (Col/Row) is pressed during `SUBGRID_STANDARD` or `SUBGRID_ULTRAFAST`.
    *   Stops `TrackCursor`.
    *   Hides `subGrid` and `highlight`.
    *   Resets state (`activeCellKey`, `activeSubCellKey`, `firstKey`, `g_firstKeyPressed`, `activeRowKey`, `inUltraFastMode`).
    *   **Calls `TransitionToState(State_GRID_VISIBLE)`**.
    *   Calls `HandleKey(key, true)` *after* the transition to process the pressed grid key as the start of a new selection (passes `true` to bypass `HandleKey`'s own state check). `HandleKey` restarts `TrackCursor`.

8.  **Cursor Tracking (`TrackCursor` in `core/tracking.ahk`)**
    *   Runs periodically (e.g., 50ms) when grid/subgrid is active (state check at start). Uses `trackingInProgress` static var to prevent re-entry.
    *   **If `SUBGRID_STANDARD` or `SUBGRID_ULTRAFAST`:** Gets `activeCellKey` boundaries from `StateMap['currentOverlay']`. Checks if cursor `(x,y)` is still inside. If *not*: calls `StartNewSelection("")` to return to grid mode.
    *   **If `GRID_VISIBLE`:**
        *   Calls `GetCellAtPosition(x, y)`.
        *   Compares `currentCellKey` with `lastTrackedCellKey_GridVisible`.
        *   If changed:
            *   If `currentCellKey` is valid: Gets boundaries. Updates `highlight` (`highlight.Update`). **Sets `StateMap["activeCellKey"] = currentCellKey`. Updates `subGrid` position (`subGrid.Update`). Calls `TransitionToState(State_SUBGRID_STANDARD)`. Updates `lastTrackedCellKey_GridVisible` and *returns early* to avoid race conditions.**
            *   If `currentCellKey` is empty (outside cells): Hides `highlight`. Updates `lastTrackedCellKey_GridVisible`.
        *   *Ultra-Fast Trigger Logic (Inferred):* Checks if `StateMap['activeRowKey']` is set and held -> activates ultra-fast if threshold met.
    *   Resets `trackingInProgress` flag in `finally` block.

9.  **Cleanup (`Cleanup` in `activation.ahk`)**
    *   Sets `activeCleanup` flag (not explicitly defined in provided code, assumed).
    *   Sets `currentState = State_IDLE` immediately.
    *   Stops `TrackCursor` timer.
    *   Resets flags (`g_ModifierState.inHoldMode`, `gridActivationInProgress`).
    *   Hides GUIs (`highlight`, `subGrid`, `overlays`).
    *   Waits (`Sleep(30)`).
    *   Destroys GUI objects (`highlight.Destroy()`, `subGrid.Destroy()`, iterates `StateMap['overlays']`), clears variables (`highlight = ""`, `subGrid = ""`, `StateMap['overlays'] = []`, `StateMap['currentOverlay'] = ""`).
    *   Resets other `StateMap` values (`firstKey`, `activeCellKey`, etc.) and `g_firstKeyPressed`.
    *   Calls `ForceCloseAllGuis()` (`utils.ahk`) as a safeguard.
    *   Resets `activeCleanup` flag.

10. **Monitor Switching (`core/monitor.ahk`, `hotkeys.ahk`)**
    *   Hotkeys (Tab, CapsLock+Number, Number while grid active) call `CycleToNextMonitor()` or `SwitchMonitor(monitorNum)`.
    *   `SwitchMonitor()`: Applies `monitorMapping` (`config.ahk`). Checks validity. Checks if already on target. Stops `TrackCursor`. Gets `newOverlay`. Hides elements on old monitor. Updates `StateMap['currentOverlay']`. Shows `newOverlay`. Moves mouse to center. Resets selection state (`firstKey`, `activeCellKey`, etc.). **Calls `TransitionToState(State_GRID_VISIBLE)`**. Starts `TrackCursor`.
    *   `CycleToNextMonitor()`: Determines current physical index, finds next in sorted list of mapped physical indices, calls `SwitchMonitor()` with the next physical index.

## Logical Flow Diagrams

### High-Level State Diagram

```mermaid
stateDiagram-v2
    [*] --> IDLE : Script Start / Cleanup / DeactivateGrid
    IDLE --> GRID_VISIBLE : Activate (CapsLock_Q) / No cell under cursor
    IDLE --> SUBGRID_STANDARD : Activate (CapsLock_Q) / Cell under cursor (Instant Subgrid)

    GRID_VISIBLE --> SUBGRID_STANDARD : Second Grid Key (Valid Sequence) / HandleSecondKey
    GRID_VISIBLE --> SUBGRID_STANDARD : Cursor Moves Into Cell / TrackCursor

    SUBGRID_STANDARD --> GRID_VISIBLE : Grid Key Press / StartNewSelection
    SUBGRID_STANDARD --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
    SUBGRID_STANDARD --> SUBGRID_ULTRAFAST : Row Key Held > Threshold / TrackCursor (Inferred)
    SUBGRID_STANDARD --> IDLE : Cleanup (Escape / Space) / DeactivateGrid

    SUBGRID_ULTRAFAST --> GRID_VISIBLE : Grid Key Press / StartNewSelection
    SUBGRID_ULTRAFAST --> GRID_VISIBLE : Cursor Leaves Cell / TrackCursor -> StartNewSelection
    SUBGRID_ULTRAFAST --> SUBGRID_STANDARD : Row Key Release / HandleRowKeyRelease + TrackCursor (Inferred state change)
    SUBGRID_ULTRAFAST --> IDLE : Cleanup (Escape / Space) / DeactivateGrid

    state GRID_VISIBLE {
        direction LR
        [*] --> Tracking : TrackCursor Timer
        Tracking --> [*] : No Change
        Tracking --> HighlightUpdate : Cursor moves to new cell
        Tracking --> HighlightHide : Cursor leaves cells
        HighlightUpdate --> SUBGRID_STANDARD : Auto-transition
        HighlightHide --> Tracking
        [*] --> FirstKeyHandling : Grid Key Press (1st) / HandleFirstKey
        FirstKeyHandling --> WaitingForSecondKey
        WaitingForSecondKey --> SecondKeyHandling : Grid Key Press (2nd) / HandleSecondKey
        SecondKeyHandling --> SUBGRID_STANDARD : Valid Sequence
        SecondKeyHandling --> FirstKeyHandling : Invalid Sequence (Change 1st Key)
    }
    state SUBGRID_STANDARD {
        [*] --> WaitingForKey
        WaitingForKey --> SubgridKeyHandling : Subgrid Key Press / ProcessStandardSubgridKey
        SubgridKeyHandling --> MouseMove/MemoryUpdate --> WaitingForKey
        WaitingForKey --> GRID_VISIBLE : Grid Key Press / StartNewSelection
        [*] --> Tracking : TrackCursor Timer
        Tracking --> [*] : Still Inside Cell
        Tracking --> GRID_VISIBLE : Cursor Leaves Cell
        Tracking --> SUBGRID_ULTRAFAST : Row Key Held Long Enough
    }
    state SUBGRID_ULTRAFAST {
        [*] --> WaitingForKey
        WaitingForKey --> UltraFastKeyHandling : UltraFast Key Press / ProcessUltraFastKey
        UltraFastKeyHandling --> MouseMove/MemoryUpdate --> WaitingForKey
        WaitingForKey --> GRID_VISIBLE : Grid Key Press / StartNewSelection
        [*] --> Tracking : TrackCursor Timer
        Tracking --> [*] : Still Inside Cell
        Tracking --> GRID_VISIBLE : Cursor Leaves Cell
        [*] --> SUBGRID_STANDARD : Row Key Release / HandleRowKeyRelease
    }
```
### Activation Flow (CapsLock_Q)
```flowchart TD
    A[Activation Triggered (e.g., CapsLock)] --> B{Already Active?};
    B -- Yes --> C[Cleanup()] --> Z[End];
    B -- No --> D{Activation Flag Set/OK?};
    D -- No (Too Soon) --> Z;
    D -- Yes --> E[Set Flag / Reset State / Load Memory];
    E --> F[Init GUIs (Highlight/SubGrid)];
    F --> G[Create Overlays / Find Current];
    G --> H{Overlays Created?};
    H -- No --> I[Cleanup() / Error] --> Z;
    H -- Yes --> J[TransitionToState(GRID_VISIBLE)];
    J --> K[GetCurrentCell()];
    K --> L{Cell Found?};
    L -- No --> M[Start TrackCursor] --> Z;
    L -- Yes --> N[Get Cell Boundaries];
    N --> O{Boundaries Valid?};
    O -- No --> M;
    O -- Yes --> P[Set activeCellKey];
    P --> Q[Update Highlight];
    Q --> R[Update SubGrid Position];
    R --> S[TransitionToState(SUBGRID_STANDARD)];
    S --> M;
```
### Key Processing Flow (ProcessKeyPress)
```flowchart TD
    A[Key Press Hotkey (Active)] --> B[ProcessKeyPress(key)];
    B --> C{currentState?};
    C -- GRID_VISIBLE --> D[HandleKey(key)] --> Z[End];
    C -- SUBGRID_STANDARD --> E{CheckIfGridKey(key)?};
    E -- Yes --> F[StartNewSelection(key)] --> Z;
    E -- No --> G[HandleStandardSubgridKey(key)] --> Z;
    C -- SUBGRID_ULTRAFAST --> H{CheckIfGridKey(key)?};
    H -- Yes --> I[StartNewSelection(key)] --> Z;
    H -- No --> J[HandleUltraFastKey(key)] --> Z;
    C -- IDLE --> K[Ignore / Activation Hotkey?] --> Z;
    C -- Other --> L[Log Error] --> Z;
```

### Subgrid Activation Detail
```graph TD
    subgraph ActivationPath [Initial Activation (CapsLock_Q)]
        A1[GetCellAtPosition] --> A2{Cell Found?}
        A2 -- Yes --> A3[Get Boundaries] --> A4{OK?}
        A4 -- Yes --> A5[Set activeCellKey] --> A6[Update Highlight/Subgrid Pos] --> A7[TransitionToState(SUBGRID_STANDARD)] --> A_End[(Subgrid Active - No Key Yet)]
        A2 -- No --> A_Fail[(Grid Visible)]
        A4 -- No --> A_Fail
    end

    subgraph NavigationPath [Grid Navigation (HandleSecondKey)]
        B1[Second Key Press] --> B2{Valid Sequence?}
        B2 -- Yes --> B3[Get Boundaries] --> B4{OK?}
        B4 -- Yes --> B5[Set activeCellKey] --> B6[Update Highlight/Subgrid Pos] --> B7[TransitionToState(SUBGRID_STANDARD)] --> B_End[(Subgrid Active - No Key Yet)]
        B2 -- No --> B_Fail[(Update First Key / Reset)]
        B4 -- No --> B_Reset[(Reset First Key)]
    end
```

### Potential Conflicts & Optimizations
#### State Management & Globals:
- Conflict: Heavy reliance on numerous global variables (currentState, StateMap elements, g_firstKeyPressed, highlight, subGrid) increases complexity. g_firstKeyPressed is reset in multiple places (CapsLock_Q, HandleSecondKey, StartNewSelection, SwitchMonitor, Cleanup), making its state potentially fragile if transitions are interrupted. The StateMap helps centralize, but its direct manipulation across many functions can still be hard to track.

- Optimization: Continue encapsulating state within StateMap. Ensure critical state changes are atomic or happen within well-defined transitions. Consider explicitly passing necessary state objects (like StateMap) to functions instead of relying solely on global. Reduce redundant resets of g_firstKeyPressed if possible, perhaps tying its lifecycle more strictly to the GRID_VISIBLE state.

#### Timing/Race Conditions:
- Conflict: The TrackCursor timer (50ms) runs concurrently with hotkey handlers.
TrackCursor can call StartNewSelection if the cursor leaves the subgrid cell at the same time a user presses a grid key (which also calls StartNewSelection). This could lead to double execution or state conflicts.
TrackCursor can automatically transition GRID_VISIBLE -> SUBGRID_STANDARD when the cursor enters a cell. If the user presses the first grid key just before this transition completes, HandleFirstKey might run in GRID_VISIBLE, but the state immediately changes underneath it, potentially causing issues when waiting for the second key. The return after transition in TrackCursor helps mitigate this, but it's a sensitive area.
The use of Sleep() (e.g., in HandleSecondKey, Cleanup) can pause execution, potentially allowing other events (like the timer) to queue up or run unexpectedly.

- Optimization: Use Critical where necessary to prevent timer interruptions during sensitive state updates or GUI manipulations. Minimize Sleep(). Re-evaluate the logic where TrackCursor automatically transitions to SUBGRID_STANDARD. Perhaps TrackCursor should only update the highlight in GRID_VISIBLE, and the transition only happens upon the second key press in HandleSecondKey. This simplifies the flow but removes the "instant subgrid on hover" feature. Alternatively, make the TrackCursor transition logic extremely robust with checks before and after TransitionToState. Remove the stateTransitionDelay debounce if possible by ensuring state transitions are handled more atomically.

#### Subgrid Activation Logic:
- Conflict: In CapsLock_Q, the script transitions IDLE -> GRID_VISIBLE and then immediately GRID_VISIBLE -> SUBGRID_STANDARD if a cell is found. This rapid double transition might be unnecessary or hide subtle issues. The state is SUBGRID_STANDARD before the TrackCursor timer is even started.

- Optimization: Refactor CapsLock_Q to determine the final target state (GRID_VISIBLE or SUBGRID_STANDARD) before making the single call to TransitionToState. This makes the initial state setting cleaner.


#### Ultra-Fast Mode Transitions:
- Conflict: HandleRowKeyRelease resets flags (inUltraFastMode, activeRowKey) and updates the subgrid GUI (SwitchToStandard) but doesn't explicitly call TransitionToState(State_SUBGRID_STANDARD). The state likely changes back implicitly via TrackCursor detecting the conditions have changed, which might be delayed or less predictable.

- Optimization: Consider adding an explicit TransitionToState(State_SUBGRID_STANDARD) call within HandleRowKeyRelease after resetting the flags and updating the GUI for a more immediate and clear state change.

#### Error Handling:
- Conflict: Error handling is mixed (try/catch with silent ignore, MsgBox, ToolTip, logging). Errors during GUI operations (e.g., getting boundaries, updating overlays) might leave the script in an inconsistent visual or logical state. Cleanup() is robust but might be called frequently if minor errors occur.

- Optimization: Standardize error logging. For critical failures (e.g., cannot create overlays), ensure a full Cleanup and potentially user notification. For less critical GUI update failures, log the error but try to maintain a stable state (e.g., hide the problematic element). Add more checks for IsObject() before using GUI elements, especially in TrackCursor.

### Code Clarity/Redundancy:
Redundancy: GUI hiding/destruction logic is present in Cleanup, DeactivateGrid, StartNewSelection, and SwitchMonitor. Consolidating this into helper functions within utils.ahk or gui_classes.ahk could improve maintainability.

Clarity: The difference between g_firstKeyPressed and StateMap['firstKey'] seems redundant; using only StateMap['firstKey'] might be cleaner. The CapsLock logic in hotkeys.ahk is complex but seems necessary for the desired single/double/hold behavior.

#### Scalability:
Good: The modular structure (separating config, state, utils, classes, core logic, activation, hotkeys) is a significant improvement over a monolithic script. Using StateMap centralizes dynamic data. Layouts are data-driven via layoutConfigs.

Areas for Improvement: Adding significantly different interaction modes might require modifying ProcessKeyPress and potentially TransitionToState. Tighter coupling exists between TrackCursor, TransitionToState, and HandleKey regarding the automatic subgrid activation. Refactoring these interactions could improve scalability if more complex tracking behaviors are needed.