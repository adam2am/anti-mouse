# AntiMouse Script (antimouse 0.01.ahk) Flow Analysis

## Logical Flow Decomposition

The script implements a keyboard-driven mouse control system using grid overlays. Its logic can be broken down as follows:

1.  **Initialization:**
    *   Sets global script properties (`#Requires`, `CoordMode`, `SetCapsLockState`).
    *   Starts a timer (`ForceCapsLockOff`) to ensure CapsLock remains off.
    *   Defines global configuration variables (debug mode, layout selection, colors, file paths, monitor mapping, etc.).
    *   Initializes the Finite State Machine (FSM) state to `IDLE`.
    *   Initializes state tracking variables (`StateMap`, `g_ModifierState` for CapsLock).
    *   Defines placeholders for reusable GUI instances (`highlight`, `subGrid`).
    *   Loads layout configurations (`layoutConfigs`) and subgrid keys (`subGridKeys`).
    *   Loads persistent settings (`LoadSettings`) and cell memory (`LoadCellMemory`) from files (`.ini`, `.txt`).

2.  **GUI Classes:**
    *   `HighlightOverlay`: Manages the single highlight rectangle GUI. Uses `Gui +AlwaysOnTop -Caption +ToolWindow`. Provides `Update` (move/resize/show) and `Hide`/`Destroy` methods.
    *   `SubGridOverlay`: Manages the 2x2 subgrid GUI displayed over the selected main grid cell. Uses `Gui +AlwaysOnTop -Caption +ToolWindow`. Creates text controls for subgrid keys (`g`, `h`, `b`, `n`) and border controls. Provides `Update`, `Hide`/`Destroy`, and `GetTargetCoordinates` (calculates center of a subcell).
    *   `GridOverlay`: Manages the main grid GUI for a single monitor. Uses `Gui +AlwaysOnTop -Caption +ToolWindow`. Creates text controls for each cell key (e.g., "qa") and border lines. Provides `Show`, `Hide`/`Destroy`, `GetCellBoundaries`, and `ContainsPoint`.
    *   `OverlayGUI`: A wrapper class primarily holding an instance of `GridOverlay`, providing a consistent interface.

3.  **State Management (FSM):**
    *   `currentState`: Tracks the script's mode (`IDLE`, `GRID_VISIBLE`, `SUBGRID_ACTIVE`).
    *   `StateMap`: A global `Map` object holding dynamic state like active overlays, selected keys, indices, etc.
    *   `g_ModifierState`: A global object tracking `CapsLock` press state (first press time, second press time, release time, hold mode status) for complex activation logic.
    *   Transitions are triggered by hotkeys (`CapsLock`, `Escape`, `Space`) and internal logic (`HandleKey`, `TrackCursor`).

4.  **Core Activation (`CapsLock_Q` function):**
    *   Triggered by `CapsLock` double-press or `CapsLock` + `q`.
    *   Prevents double activation using flags (`gridActivationInProgress`, `gridActivationTime`).
    *   Resets relevant state variables in `StateMap`.
    *   Loads cell memory.
    *   Gets the selected layout configuration.
    *   Initializes reusable `highlight` and `subGrid` GUI objects.
    *   Creates and shows `OverlayGUI` instances for each detected monitor, storing them in `StateMap['overlays']`.
    *   Determines the `currentOverlay` based on the initial mouse position.
    *   Sets `currentState` to `GRID_VISIBLE`.
    *   Starts the `TrackCursor` timer.

5.  **Key Handling & State Logic:**
    *   **`#HotIf` Contexts:** Hotkeys are defined within specific contexts based on `currentState` and sometimes `instaClickMode` / `g_ModifierState.inHoldMode`.
    *   **`GRID_VISIBLE` State:**
        *   `HandleKey(key)`: Processes grid navigation keys (column/row keys like `q`, `a`, etc.).
            *   *First Key:* Stores the key (`StateMap['firstKey']`), determines the target cell (using the pressed key and the last known row/column index), moves the cursor, updates the highlight, and waits for the second key.
            *   *Second Key:* If a valid pair (col->row or row->col) is pressed, determines the final `cellKey`, updates state indices, sets `currentState` to `SUBGRID_ACTIVE`, updates highlight, moves cursor, and shows the `subGrid`. If an invalid pair (col->col or row->row) is pressed, updates the *first* key state and waits for a new second key.
        *   `TrackCursor()`: Timer function. Gets mouse position, determines which monitor/cell the cursor is over. If the cell changes, updates `StateMap['activeCellKey']`, `currentColIndex`, `currentRowIndex`, updates the highlight, shows/updates the `subGrid`, and transitions `currentState` to `SUBGRID_ACTIVE`.
        *   Monitor Switching (`1`-`4`, `Tab`): Calls `SwitchMonitor` or `CycleToNextMonitor` to change `StateMap['currentOverlay']`, attempting to preserve the relative cell position and state.
        *   `Space`: Performs a left click at the current cursor position, calls `Cleanup`, sets `currentState` to `IDLE`.
        *   `Escape`: Calls `Cleanup`, sets `currentState` to `IDLE`.
    *   **`SUBGRID_ACTIVE` State:**
        *   `HandleSubGridKey(subKey)`: Processes subgrid keys (`g`, `h`, `b`, `n`). Calculates target coordinates using `subGrid.GetTargetCoordinates`, moves the mouse, updates `StateMap['activeSubCellKey']`, and saves the `cellKey` -> `subKey` mapping to `cellMemory` (and persists it to file via `SaveCellMemory`).
        *   `StartNewSelection(key)`: If a *grid* navigation key is pressed while the subgrid is active, it hides the subgrid, resets state variables (`activeCellKey`, `firstKey`), sets `currentState` back to `GRID_VISIBLE`, and calls `HandleKey` to process the pressed key as the *first* key of a new selection.
        *   `TrackCursor()`: Continues to track mouse movement over main grid cells, updating highlight/subgrid accordingly.
        *   Monitor Switching (`1`-`4`, `Tab`): Similar to `GRID_VISIBLE`, attempts to preserve state.
        *   `Space`: Performs a left click, calls `Cleanup`, sets `currentState` to `IDLE`.
        *   `Escape`: Calls `Cleanup`, sets `currentState` to `IDLE`.
    *   **`CapsLock` Hotkeys:**
        *   `CapsLock::` (Down): Detects first vs. second press based on timing and release status (`g_ModifierState`). Sets `inHoldMode` on a valid second press (or `CapsLock`+key combo). Activates grid (`CapsLock_Q`) on second press. Ensures `SetCapsLockState "AlwaysOff"`.
        *   `CapsLock Up::`: Updates `g_ModifierState`. If `inHoldMode` was true, performs an "InstaClick" (left click at current position) and cleans up. If not in hold mode (single tap), just cleans up (if the grid was active). Resets press time tracking.
        *   `CapsLock & key::` / `#HotIf GetKeyState('CapsLock', 'P')`: Defines hotkeys that trigger when CapsLock is held down (e.g., `CapsLock & q`, `CapsLock & 1`). These often activate the grid if not already active (`CapsLock_Q`) and then perform an action (like selecting the 'q' column or switching monitors). They also set `inHoldMode` to true.
    *   **InstaClick Mode:** If `instaClickMode` is true, the `#HotIf` conditions change slightly, allowing grid/subgrid navigation keys to function *without* the `CapsLock &` prefix while `g_ModifierState.inHoldMode` is true. The click still happens on `CapsLock Up`.

6.  **Helper Functions:**
    *   `Cleanup()`: Stops timers, hides/destroys all GUI elements (`highlight`, `subGrid`, all overlays), resets `currentState` to `IDLE`, clears tooltips, resets flags. Uses `ForceCloseAllGuis` as a fallback.
    *   `ForceCloseAllGuis()`: Attempts to forcefully close any lingering `AutoHotkeyGUI` windows.
    *   `LoadCellMemory()` / `SaveCellMemory()`: Reads/writes the `cellKey` -> `subKey` mapping from/to `cellMemoryFile`. Handles per-monitor keys if `storePerMonitor` is true.
    *   `LoadSettings()` / `SaveSettings()`: Reads/writes script settings from/to `settingsFile` (`.ini`).
    *   `SwitchMonitor(monitorNum)` / `CycleToNextMonitor()`: Changes the active overlay (`StateMap['currentOverlay']`), moves the mouse, updates UI, attempts to restore cell/subcell position based on remembered indices and `cellMemory`.
    *   `GetCellAtPosition(x, y)`: Returns the `cellKey` corresponding to the given screen coordinates within the `currentOverlay`.
    *   `ShowSettingsGUI()`: Creates and displays a GUI for modifying script settings. Triggered by `:*:;settings::`.

## User Experience Flow

1.  **Activation:**
    *   User double-presses `CapsLock` quickly.
    *   *OR* User holds `CapsLock` and presses `q`.
    *   Result: A semi-transparent grid overlay appears on all monitors. The grid corresponding to the monitor with the mouse cursor becomes active.

2.  **Targeting a Cell (Keyboard):**
    *   User presses a *column key* (e.g., `q`, `w`, `e`...). The cursor jumps to the center of the corresponding cell in the last-used row (or middle row), and the cell is highlighted.
    *   User then presses a *row key* (e.g., `a`, `s`, `d`...). The specific cell (e.g., `qa`) is now fully selected. A 2x2 subgrid overlay appears over this cell.
    *   *Alternatively:* User presses a row key first, then a column key.
    *   *Correction:* If the user presses the same *type* of key twice (e.g., `q` then `w`), the column selection changes, and the script waits for a row key.

3.  **Targeting a Cell (Mouse):**
    *   After activation, the user moves the mouse cursor over any cell in the active grid.
    *   Result: That cell is highlighted, and the 2x2 subgrid appears over it.

4.  **Refining Target (Subgrid):**
    *   With the subgrid visible over a cell, the user presses a *subgrid key* (`g`, `h`, `b`, or `n`).
    *   Result: The mouse cursor jumps to the center of the corresponding quadrant within the selected cell. This subcell choice is remembered for the main cell.

5.  **Performing Action (Click):**
    *   **Option 1 (Space):** After targeting a cell/subcell, the user presses `Space`.
        *   Result: A left mouse click occurs at the final cursor position. The grid and subgrid disappear.
    *   **Option 2 (InstaClick):** User activates by double-pressing `CapsLock` or holding `CapsLock`+key, targets a cell/subcell using *other* keys while *still holding* `CapsLock`, and then *releases* `CapsLock`.
        *   Result: A left mouse click occurs at the final cursor position upon releasing `CapsLock`. The grid/subgrid disappear. (If `instaClickMode` setting is false, releasing CapsLock after `CapsLock`+key activation might still click due to `inHoldMode` being set).

6.  **Canceling:**
    *   At any point after activation, the user presses `Escape`.
    *   Result: The grid and subgrid disappear without any action being performed.

7.  **Switching Monitors:**
    *   While the grid is active, the user presses `1`, `2`, `3`, or `4` (potentially requiring `CapsLock` held, depending on state/mode).
        *   Result: The focus switches to the grid on the specified monitor. The script attempts to select the same relative cell as was selected on the previous monitor.
    *   While the grid is active, the user presses `Tab`.
        *   Result: The focus cycles to the next monitor's grid.

8.  **Starting a New Selection:**
    *   While the subgrid is visible over a cell, the user presses a *main grid key* (e.g., `q`, `a`) instead of a subgrid key.
    *   Result: The subgrid disappears, and the pressed key is treated as the *first* key of a *new* cell selection.

9.  **Changing Settings:**
    *   User types the exact sequence `;settings` followed by a space, tab, or enter.
    *   Result: A settings window appears, allowing modification of layout, colors, behavior, etc.

## Ratings

**Logic Flow Rating:**

*   **Straightforwardness/Robustness:** **5/10**
    *   The FSM (`IDLE`, `GRID_VISIBLE`, `SUBGRID_ACTIVE`) provides a decent structure.
    *   GUI class reuse (`HighlightOverlay`, `SubGridOverlay`) is good practice.
    *   However, the `CapsLock` activation logic (`g_ModifierState`, double-press timing, hold detection) is complex and appears sensitive (comments in the code suggest issues, e.g., lines 4-6).
    *   Heavy reliance on global variables and the `StateMap` makes state tracking potentially difficult to debug and maintain.
    *   Multiple complex `#HotIf` conditions for different states and modes (`instaClickMode`) increase complexity and potential for conflicts or unexpected behavior.
    *   The need for `ForceCloseAllGuis` suggests potential issues with reliable GUI cleanup, possibly leading to orphaned windows.
    *   State transitions (especially involving `TrackCursor` and key presses simultaneously) require careful timing and disabling/enabling timers (`SetTimer(TrackCursor, 0)`), which can be fragile.
*   **Scalability:** **4/10**
    *   Adding new layouts is relatively easy by modifying `layoutConfigs`.
    *   Adding new actions beyond clicking (e.g., right-click, drag) would require significant changes to the FSM, state handling (`StateMap`), and hotkey logic.
    *   The current 2x2 subgrid is hardcoded; changing its size or keys would require modifying `SubGridOverlay` and related logic (`HandleSubGridKey`).
    *   The reliance on global state makes it harder to isolate components or add substantially new features without potentially impacting existing ones.
    *   Performance might degrade with significantly larger grids or more complex GUI elements due to the way overlays and tracking are handled.

**User Experience Rating (per scenario):**

*   **Scenario: Basic Click (Activate -> Select Cell -> Select Subcell -> Space)**
    *   Speed: **6/10** (Requires activation + 2 grid keys + 1 subgrid key + Space = 5+ key presses)
    *   Preciseness: **8/10** (Subgrid allows fine-tuning within a cell)
    *   Less Motions: **7/10** (Keyboard-centric, minimal mouse movement needed after activation)
    *   *Overall UX:* **7/10** - Functional but requires several steps. Remembering cell/subcell keys is crucial.
*   **Scenario: InstaClick (Activate -> Select Cell -> Select Subcell -> Release CapsLock)**
    *   Speed: **7/10** (Activation + 2 grid keys + 1 subgrid key, release CapsLock = 4+ presses + hold/release) - Slightly faster than Space if CapsLock is already held.
    *   Preciseness: **8/10** (Same as above)
    *   Less Motions: **7/10** (Same as above)
    *   *Overall UX:* **7/10** - Offers a slightly faster click mechanism but relies on holding CapsLock, which might feel unnatural or conflict with typing habits. The complexity of the CapsLock state machine might lead to inconsistent activation/clicking.
*   **Scenario: Mouse Targeting (Activate -> Move Mouse -> Space/Release CapsLock)**
    *   Speed: **5/10** (Activation + Mouse movement + Click action) - Speed depends heavily on mouse travel distance.
    *   Preciseness: **6/10** (Limited by the main grid cell size; subgrid isn't used in this flow unless the user pauses over a cell).
    *   Less Motions: **3/10** (Requires significant mouse movement).
    *   *Overall UX:* **4/10** - Less efficient than keyboard targeting for users comfortable with the keys. Might be useful for initial coarse positioning.
*   **Scenario: Monitor Switching (Activate -> ... -> Switch Key -> ... -> Click)**
    *   Speed: **5/10** (Adds an extra key press `1-4` or `Tab` to the flow).
    *   Preciseness: **8/10** (Preciseness maintained after switch).
    *   Less Motions: **6/10** (Still primarily keyboard-driven, but adds one more key).
    *   *Overall UX:* **6/10** - Necessary for multi-monitor setups, but adds a step. The attempt to maintain relative position is good but might feel slightly disjointed.

## Brainstorming Options & Winner (Overall UX Improvement)

**Goal:** Improve Speed, Preciseness, and Reduce Motions.

**Options:**

1.  **Direct Subcell Selection:** Instead of Cell -> Subcell, use modifier keys (e.g., Shift, Alt) with the *second* grid key press to directly target a subcell quadrant.
    *   *Pros:* Reduces one key press (4 presses total: Activate -> ColKey -> Mod+RowKey -> Click). Improves speed.
    *   *Cons:* Requires learning modifier combinations. Might conflict with existing OS/app shortcuts. Increases cognitive load slightly.
2.  **Adaptive Grid Density:** Start with a coarse grid. The first key press selects a large region. The second key press shows a finer grid *within* that region. Repeat for subgrid.
    *   *Pros:* Potentially higher precision with fewer initial keys to memorize. Scales better to large screens.
    *   *Cons:* Increases the number of steps/key presses (Activate -> RegionKey -> CellKey -> SubcellKey -> Click). Slower. More complex logic.
3.  **Single-Key Cell Selection (Chorded):** Press and *hold* a column key, then press a row key *while holding* the column key to select the cell. Release both. Then press subgrid key + click key.
    *   *Pros:* Reduces cell selection to a single "chord" action (feels like 2 presses). Potentially faster.
    *   *Cons:* Requires holding keys, which can be less ergonomic. Timing sensitive. Might conflict with OS key repeat. Needs careful implementation.
4.  **Predictive Subcell (Memory Only):** Eliminate the explicit subgrid step. When a cell is selected (Col+Row), immediately move the cursor to the *last remembered* subcell position for that cell (from `cellMemory`). If no memory exists, default to the center. Click with Space/Release Caps.
    *   *Pros:* Fastest option (Activate -> ColKey -> RowKey -> Click = 4 presses). Minimal motions if memory is accurate.
    *   *Cons:* Precision relies entirely on memory being correct or the center being acceptable. No visual feedback for subcell selection. Requires a way to *update* memory if the prediction is wrong (maybe a dedicated "re-learn subcell" hotkey?).
5.  **Combined Activation/Selection Key:** Use modifier + grid key to both activate *and* make the first selection step. E.g., `Alt+Q` activates and selects the Q column. Then press row key -> subcell key -> click.
    *   *Pros:* Reduces one key press from the standard flow (4 presses total).
    *   *Cons:* Requires learning modifier combinations. Potential conflicts. CapsLock activation becomes redundant or needs rethinking.

**Winner & Rationale:**

**Option 4: Predictive Subcell (Memory Only)** seems like the best balance for achieving the core goals, *assuming* the user primarily clicks in consistent locations within cells.

*   **Speed:** Highest potential speed (4 presses).
*   **Preciseness:** High *if* memory is accurate for the user's workflow. Defaults to center otherwise.
*   **Less Motions:** Minimal motions, purely keyboard-driven after activation.

**Why it wins:** It directly addresses the "less motions" and "speed" criteria by removing an entire step (subgrid key press) for the most common case (clicking where you last clicked in that cell). The reliance on memory aligns with the script's existing memory feature.

**Caveats/Refinements Needed for Option 4:**
*   A mechanism to *correct* or *update* the remembered subcell position is essential when the prediction is wrong. This could be a dedicated hotkey (e.g., `CapsLock + M` while hovering over the correct spot after cell selection) or automatically updating memory if the user manually moves the mouse *before* clicking after a cell selection.
*   Clearer visual feedback might be needed *after* the cell selection to indicate where the cursor jumped based on memory (e.g., a brief flash or different highlight).
*   The default behavior (center of the cell if no memory) needs to be reliable.

This approach prioritizes optimizing the common case for speed and efficiency, acknowledging that occasional corrections might be needed.




# Brainstorming Options & Winner 1.0: (Sub-Cell Precision & Key Conflicts)

**Goal:** Increase sub-cell precision (3x3 minimum, 4x4/5x5 desirable) and resolve key conflicts between sub-cell keys, main grid keys, and monitor keys, while allowing easy "start new selection".

**Options:**



## --- nope ---
1.  **Numeric Keypad Subgrid (3x3):**
    *   **Mechanism:** After cell selection (Col+Row), use `Numpad1`-`Numpad9` to select the 3x3 sub-cell. `Numpad5` is center.
    *   **Pros:** Intuitive mapping, 3x3 precision, keys spatially separate, no conflict with main grid/monitor keys, main grid keys (`q`,`a`...) clearly start new selection.
    *   **Cons:** Requires Numpad, less ergonomic (hand movement).
    *   **Rating:** Speed: 7/10 (4 presses), Precision: 8/10 (3x3), Less Motions: 6/10. **Overall: 7/10**
        >> too far away from finger position, especially for regular big keyboards, doesnt fit

3.  **Two-Key Subgrid Sequence (4x4):**
    *   **Mechanism:** After cell selection, enter subgrid mode. Press a sub-column key (e.g., `1,2,3,4`) then a sub-row key (e.g., `q,w,e,r`).
    *   **Pros:** Higher 4x4 precision (16 points), keys distinct *within sub-mode*.
    *   **Cons:** Slower (5 presses total), higher cognitive load, potential conflict with monitor keys (`1-4`).
    *   **Rating:** Speed: 5/10 (5 presses), Precision: 9/10 (4x4), Less Motions: 7/10. **Overall: 7/10**
        >> conflict with existing 1234 and when


5.  **Modal Subgrid Keys (Distinct Set):**
    *   **Mechanism:** After cell selection, enter subgrid mode. A distinct set of keys becomes active for subgrid selection (e.g., `uio`, `jkl`, `m,.` for 3x3, or include `p`, `;`, `/` etc. for 4x4). These keys are chosen because they are less likely to be the *first* key pressed in main grid navigation for the specified layout. Pressing any *other* main grid key (like `q`, `w`, `a`, `s`) immediately starts a new selection.
    *   **Keys (3x3 Example):** `uio` (top), `jkl` (mid), `m,.` (bot).
    *   **Pros:** No modifier needed, uses single key presses, clear separation (subgrid keys select subcell, other main keys start new selection), avoids monitor key conflict, keeps hands near home row.
    *   **Cons:** Requires learning the dedicated subgrid key map. Might still feel slightly close to main grid keys depending on layout. 3x3 precision initially (can be expanded).
    *   **Rating:** Speed: 7/10 (4 presses), Precision: 8/10 (3x3), Less Motions: 8/10. **Overall: 8/10**
        >> flawed if user missclicked and now cant move, gotta start somehow again?


6.  **Visual Subgrid + Number Keys (Non-Numpad):**
    *   **Mechanism:** After cell selection, display a 3x3 visual subgrid overlay with numbers 1-9 shown in the cells. Press the corresponding number row key (`1`-`9`) to select the subcell.
    *   **Pros:** Intuitive visual mapping, 3x3 precision, single key press for subcell.
    *   **Cons:** Conflicts directly with monitor switching keys (`1`-`4`). Requires looking at the overlay. Number row keys can be less ergonomic than home row.
    *   **Rating:** Speed: 7/10 (4 presses), Precision: 8/10 (3x3), Less Motions: 6/10. **Overall: 6/10** (Due to monitor key conflict).
        >> conflicting with monitor switch (1/2/3/4)
        >> too far, not intuitive numbers 65789



## +++ okayish + winner +++ [
2.  **Modifier + Home Row Subgrid (3x3):**
    *   **Mechanism:** After cell selection, use `Alt` + home row cluster (e.g., `Alt+w/e/r`, `Alt+s/d/f`, `Alt+x/c/v`) for 3x3 sub-cells.
    *   **Pros:** Keeps hands on home row (ergonomic), 3x3 precision, modifier clearly separates subgrid mode (main keys start new selection), avoids Numpad/monitor key conflicts.
    *   **Cons:** Requires modifier press, potential `Alt+` conflicts in apps.
    *   **Rating:** Speed: 7/10 (4 presses), Precision: 8/10 (3x3), Less Motions: 8/10. **Overall: 7.5/10**
        >> seems okayish, now just see how it feels in action, alt as a hold?
        >> potentially can remove TAB? but if we holding caps and releasing it, its flawed?

2. 1. Or if smth being held like caps+Q being held = we activate subgrid second layer     
        >> so if we just press Q > L = QL cell, its centered, but now if we also hold Q = subgrid will not follow the regular qwer
            but if we release holding caps+colKey/rowKey = now we can use those default keys as altered (qwer/asd/uio/jkl)?
            potential big cognitive load and less simplicityЙ
            also potentially more clicks, which might be not suitable
            

2. 2. Or somehow also can make use of the keys we already pressing (freed = not in use = can take the role) 
        like if its a Q/L => we can make Q=left, QL=mid(its default), L=right 
]




## --- meh +++

4.  **Layer Shift Subgrid (Home Row 4x4):**
    *   **Mechanism:** After cell selection, *hold* a layer key (e.g., `Tab` or `AppsKey`, *not* Space/CapsLock). While held, `qwer`, `asdf`, `zxcv`, `1234` map to a 4x4 subgrid. Release layer key to select (or tap grid key while holding).
    *   **Pros:** Reuses familiar keys, 4x4 precision, keeps hands on home row, layer key separates mode.
    *   **Cons:** Requires holding a key, overloading keys is potentially confusing, needs clear cancel mechanism (`Escape` while holding layer key?). Using `Tab` conflicts with monitor cycling. `AppsKey` might be better if available.
    *   **Rating (AppsKey layer, tap grid key):** Speed: 6/10 (4 presses + hold), Precision: 9/10 (4x4), Less Motions: 8/10. **Overall: 7.5/10**
        >> not working with a mode of holding a caps for fast release







2.  **Modifier + Home Row Subgrid (3x3):** Overall: 7.5/10 (User: okayish, Alt hold? TAB conflict?)
3.  **Two-Key Subgrid Sequence (4x4):** Overall: 7/10 (User: nope, conflict 1-4) 
4.  **Layer Shift Subgrid (Home Row 4x4):** Overall: 7.5/10 (User: nope, conflicts with Caps-hold release)
5.  **Modal Subgrid Keys (Distinct Set):** Overall: 8/10 (User: nope, flawed if missclicked = sequence startin over)
6.  **Visual Subgrid + Number Keys (Non-Numpad):** Overall: 6/10 (User: nope, conflict 1-4 + not intuitive, numbers too far away)

**Winner 1.0:** Option 2.0: Modifier(ex:Alt) + Homerow (Distinct Set qwer/asdf)
    Option 2.1: holding a cell keys
    but in both options concerns about smoothness

    potential suggestions: when colKey of targeted cell held > making uiojklm,. in use = no hand conflict
    and when rowCey of a targeted cell being held > making colKey in use = no hand or keys conflict when being held
    should be less cognitive load compared to alt pressed in on 2.0

---

## Brainstorming Options & Winner 2.0: (Sub-Cell Precision & Key Conflicts):
