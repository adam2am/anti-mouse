# Plan: Refactor AntiMouse GUI Handling to Move Off-Screen

**Goal:** Improve activation/deactivation speed, particularly for re-activation, by reusing GUI objects instead of destroying and recreating them. Replace `Hide`/`Show` and `Destroy` calls with logic to move GUI windows to/from an off-screen position.

**Strategy:**

1. Modify GUI classes (`HighlightOverlay`, `SubGridOverlay`, `OverlayGUI`/`GridOverlay`) to support moving on/off screen.
2. Adapt activation logic (`CapsLock_Q`) to create GUIs only once (if they don't exist) and move them into position.
3. Adapt deactivation logic (`Cleanup`, `DeactivateGrid`) to move GUIs off-screen instead of destroying them.
4. Adapt state transition logic (`TransitionToState`) to move GUIs on/off screen instead of hiding/showing.
5. Review and adapt other code sections that manipulate GUI visibility.

---

## Implementation Steps

**Phase 1: Preparation & GUI Class Modification**

2. **Define Constants:** Add global constants for the off-screen position in `config.ahk` or `state.ahk`.
      ```ahk
      ; In state.ahk (or config.ahk)
      global OFFSCREEN_X := -10000
      global OFFSCREEN_Y := -10000
      ```
3. **Modify `gui_classes.ahk`:**
      - **`HighlightOverlay` Class:**
           - Remove the `Destroy()` method (or comment it out). Its logic will no longer be standard practice.
           - Modify the `Hide()` method to move the GUI off-screen:
                ```ahk
                Hide() {
                    global OFFSCREEN_X, OFFSCREEN_Y
                    if (IsObject(this.gui)) {
                        try {
                            ; Move off-screen without changing size (use current w/h if available)
                            this.gui.Show(Format("x{} y{} NoActivate", OFFSCREEN_X, OFFSCREEN_Y))
                            ; LogToFile(...) ; Optional logging
                        } catch as e {
                            ; Log error
                        }
                    }
                }
                ```
           - Ensure the `Update(x, y, w, h)` method correctly uses `gui.Show()` to both move _and_ show the highlight at the target position. It already does this, so it might just need error handling/logging updates.
           - The `__New()` constructor should remain largely the same, creating the GUI initially.
      - **`SubGridOverlay` Class:**
           - Remove/Comment out `Destroy()`.
           - Modify `Hide()` similar to `HighlightOverlay.Hide()`:
                ```ahk
                Hide() {
                    global OFFSCREEN_X, OFFSCREEN_Y
                    if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                        try {
                            this.gui.Show(Format("x{} y{} NoActivate", OFFSCREEN_X, OFFSCREEN_Y))
                            ; LogToFile(...) ; Optional logging
                        } catch {
                            ; Silently ignore errors or log
                        }
                    }
                }
                ```
           - Ensure `Update(x, y, w, h)` correctly prepares the layout _before_ the `Show()` method is called to move it on-screen.
           - Modify `Show()` to explicitly move the GUI to the stored `this.x`, `this.y` (it already does this via format string, ensure robustness).
      - **`OverlayGUI` / `GridOverlay` Classes:**
           - Remove/Comment out `Destroy()` in both classes.
           - Modify `Hide()` in `GridOverlay` (which `OverlayGUI` uses) similar to the others:
                ```ahk
                ; Inside GridOverlay class
                Hide() {
                    global OFFSCREEN_X, OFFSCREEN_Y
                    try {
                        if (IsObject(this.gui) && WinExist("ahk_id " this.gui.Hwnd)) {
                            ; Note: We don't need w/h here, just moving it
                            this.gui.Show(Format("x{} y{} NoActivate", OFFSCREEN_X, OFFSCREEN_Y))
                             ; LogToFile(...) ; Optional logging
                        }
                    } catch {
                        ; Silently ignore errors or log
                    }
                }
                ```
           - Ensure `Show()` in `GridOverlay` moves the GUI to the correct `this.x`, `this.y`, `this.width`, `this.height`. It already does this.

**Phase 2: Modify Activation Logic**

4. **Modify `activation.ahk::CapsLock_Q()`:**

      - **GUI Object Initialization:** Change how `highlight`, `subGrid`, and `overlays` are handled.

           - Before creating `highlight` and `subGrid`, check if they are already valid objects.

                ```ahk
                ; Replace highlight := HighlightOverlay() with:
                if (!IsObject(highlight)) {
                    LogToFile("Creating NEW HighlightOverlay instance.", "antimouse_core.log")
                    highlight := HighlightOverlay()
                    highlight.Hide() ; Move off-screen immediately after creation
                } else {
                     LogToFile("Reusing existing HighlightOverlay instance.", "antimouse_core.log")
                     highlight.Hide() ; Ensure it's off-screen initially
                }

                ; Replace subGrid := SubGridOverlay() with:
                if (!IsObject(subGrid)) {
                    LogToFile("Creating NEW SubGridOverlay instance.", "antimouse_core.log")
                    subGrid := SubGridOverlay()
                    subGrid.Hide() ; Move off-screen immediately after creation
                } else {
                    LogToFile("Reusing existing SubGridOverlay instance.", "antimouse_core.log")
                    subGrid.Hide() ; Ensure it's off-screen initially
                }
                ```

      - **Overlay Creation Loop:** Modify the loop that creates `OverlayGUI` objects.
           - Instead of always creating, check if `StateMap['overlays']` already contains enough valid overlay objects for the detected monitors.
           - If `StateMap['overlays]` is empty or needs resizing:
                - Loop through monitors.
                - Create `overlay := OverlayGUI(...)`.
                - Push to `StateMap['overlays']`.
                - Immediately call `overlay.Hide()` to move it off-screen _unless_ it's the one determined to be the `currentOverlay`.
           - If `StateMap['overlays]` exists and is correct size:
                - Loop through monitors.
                - Get the corresponding overlay from `StateMap['overlays'][A_Index]`.
                - If it's the `currentOverlay`, call `overlay.Show()` (which now moves it on-screen).
                - If it's _not_ the `currentOverlay`, call `overlay.Hide()` (which now moves it off-screen).
      - **Simplified Logic:** A potentially simpler way is to _always_ ensure `highlight`, `subGrid`, and the `StateMap['overlays']` array contain valid objects at script start (or after a forced cleanup). Then `CapsLock_Q` _only_ needs to move the relevant ones on/off screen. This requires careful initialization and cleanup handling. Let's stick with the check-and-create-if-needed approach first.
      - Remove the `Try/Catch` block specifically around `highlight := HighlightOverlay()` and `subGrid := SubGridOverlay()`, integrating the checks as above. The main `Try/Catch` for the whole function should remain.

**Phase 3: Modify Deactivation Logic**

5. **Modify `activation.ahk::Cleanup()`:**
      - Locate the `Destroy` calls for `overlay`, `highlight`, and `subGrid`.
      - Replace `overlay.Destroy()` inside the loop with `overlay.Hide()`.
      - Replace `highlight.Destroy()` with `highlight.Hide()`.
      - Replace `subGrid.Destroy()` with `subGrid.Hide()`.
      - _Keep_ the code that clears the references (e.g., `highlight := ""`, `subGrid := ""`, `StateMap['overlays'] := []`, `StateMap['currentOverlay'] := ""`) _only_ if you want a forced cleanup to require re-creation next time. For pure "move off-screen", you would _not_ clear these references, allowing `CapsLock_Q` to reuse them. Let's aim for reuse, so **remove** the lines that clear the object references.
6. **Modify `activation.ahk::DeactivateGrid()`:**
      - Apply the same changes as in `Cleanup()`: Replace `Destroy()` calls with `Hide()` calls.
      - Decide whether to keep or remove the lines clearing the object references (`highlight := ""`, etc.), consistent with the decision in `Cleanup()`. Let's remove them for reuse.

**Phase 4: Modify State Transitions & Other Visibility Toggles**

7. **Modify `core/state_transitions.ahk::TransitionToState()`:**
      - Review the "Exit actions for the OLD state" section. Calls like `overlay.Hide()` and `subGrid.Hide()` should now correctly move the relevant GUIs off-screen based on the modified class methods. No direct changes might be needed here if the class methods were updated correctly. Double-check the logic (e.g., ensuring overlays are hidden when moving from `GRID_VISIBLE` to `IDLE`).
      - Review the "Entry actions for the NEW state" section. Calls like `StateMap["currentOverlay"].Show()` and `subGrid.Show()` should now correctly move the GUIs on-screen.
8. **Modify `core/tracking.ahk::TrackCursor()`:**
      - Find the line `highlight.Hide()` when the cursor is not over any cell. This should now correctly move the highlight off-screen.
      - Ensure calls like `highlight.Update(...)` and subsequent `highlight.ForceShow()` (or equivalent show logic) correctly move the highlight _to_ the new cell position.
9. **Modify `hotkeys.ahk`:**
      - Review the `Space::` hotkey. It contains direct calls to `highlight.Hide()`, `subGrid.Hide()`, and `overlay.Hide()`. These should now use the modified `Hide()` methods to move things off-screen before the `Click` and subsequent `Cleanup()`.
      - Review the `CapsLock Up::` hotkey (InstaClick part). It also has direct `Hide()` calls. Ensure these use the modified methods.
      - Review the `Tab::` hotkey. It hides `subGrid` and `highlight` before switching. Ensure these use the modified `Hide()` methods.

**Phase 5: Testing and Refinement**

10. **Initial Testing:**
       - Test basic activation (`CapsLock_Q`): Does the grid appear correctly on the first activation?
       - Test basic deactivation (`Escape`): Does the grid disappear?
       - Test re-activation: Does the grid reappear _faster_ than before? Do the GUIs move correctly from off-screen?
       - Check Task Manager/Process Explorer: Do GUI processes persist when deactivated (as expected)?
11. **Scenario Testing:**
       - State transitions: GRID -> SUBGRID -> GRID (via key press), GRID -> SUBGRID -> GRID (via cursor move out), SUBGRID -> IDLE (via Space/Escape).
       - Monitor switching (`SwitchMonitor`, `CycleToNextMonitor`): Ensure overlays on different monitors move correctly on/off screen.
       - Ultra-Fast Mode: Test transitions if this mode is used.
       - Edge Cases: Rapid activation/deactivation, interactions with other windows, multi-monitor setups with different resolutions/layouts.
       - Error Handling: Test what happens if a GUI fails to be created or moved. Does the script recover? (Forced cleanup might still need `Destroy` logic).
12. **Refinement:**
       - Adjust off-screen coordinates if needed (`OFFSCREEN_X`, `OFFSCREEN_Y`).
       - Add/improve logging to trace GUI movements.
       - Address any visual glitches or performance issues.
       - Consider adding a "forced cleanup" mechanism (perhaps triggered differently) that _does_ destroy and clear the GUI objects if they become corrupted or if memory usage is a concern.

---

This plan focuses on replacing visibility toggles and destruction with moving the GUIs. Remember that `Gui.Show("x... y...")` is the command used in AHK v2 to both move _and_ show a GUI window. The modified `Hide()` methods will use `Gui.Show()` to move them off-screen.
