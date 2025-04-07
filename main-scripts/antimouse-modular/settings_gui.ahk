; ==============================================================================
; settings_gui.ahk - Settings GUI Functionality
; ==============================================================================

; Import functions from memory_settings.ahk
global SaveSettings ; For saving settings to INI file

; --- Settings Hotstring Trigger ---
; This hotstring allows opening the settings GUI.
; It needs to be defined at the global scope.
#Hotstring EndChars `t `n
#Hotstring O
:*:;settings::
{
    ShowSettingsGUI()
    return
}

; --- Settings GUI Function ---
; Creates and displays the GUI window for configuring AntiMouse settings.
ShowSettingsGUI() {
    ; Access global variables needed for reading/writing settings
    global selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
    global defaultTransparency, highlightColor, instaClickMode, settingsFile ; Need settingsFile for saving
    global StateMap, highlight ; Need StateMap and highlight to apply some settings live
    global enableUltraFast, rowKeyHoldThreshold ; Ultra-Fast Subgrid settings

    ; Create settings GUI window
    settingsGui := Gui("+AlwaysOnTop +Resize", "Anti-Mouse Settings")
    settingsGui.SetFont("s10", "Segoe UI")

    ; --- General Settings Group ---
    settingsGui.Add("GroupBox", "x10 y10 w380 h130", "General Settings")

    settingsGui.Add("Text", "x20 y30 w120 h20", "Layout:")
    ; Populate dropdown with layout names
    layoutOptions := []
    for idx, config in layoutConfigs {
        layoutOptions.Push(idx ": " (config.Has("name") ? config.name : "Layout " idx))
    }
    ; Fallback if layoutConfigs isn't populated yet
    if (layoutOptions.Length == 0) {
        layoutOptions := ["1: User QWERTY/ASDF", "2: Ergonomics", "3: WASD/QWER", "4: Custom"]
    }
    layoutDropdown := settingsGui.Add("DropDownList", "x150 y30 w230 h20", layoutOptions)
    layoutDropdown.Choose(selectedLayout)

    settingsGui.Add("Text", "x20 y60 w120 h20", "Store Per Monitor:")
    storePerMonitorCheckbox := settingsGui.Add("Checkbox", "x150 y60 w230 h20",
        "Remember subcell positions per monitor")
    storePerMonitorCheckbox.Value := storePerMonitor

    settingsGui.Add("Text", "x20 y80 w120 h20", "Debug Mode:")
    debugCheckbox := settingsGui.Add("Checkbox", "x150 y80 w230 h20", "Show debug tooltips")
    debugCheckbox.Value := showcaseDebug

    settingsGui.Add("Text", "x20 y100 w120 h20", "Click Mode:")
    instaClickCheckbox := settingsGui.Add("Checkbox", "x150 y100 w230 h20", "InstaClick (release CapsLock to click)")
    instaClickCheckbox.Value := instaClickMode

    ; --- Ultra-Fast Subgrid Settings ---
    settingsGui.Add("GroupBox", "x10 y150 w380 h85", "Ultra-Fast Subgrid Options")

    settingsGui.Add("Text", "x20 y170 w120 h20", "Enable:")
    ultraFastCheckbox := settingsGui.Add("Checkbox", "x150 y170 w230 h20", "Enable Ultra-Fast Subgrid mode")
    ultraFastCheckbox.Value := enableUltraFast

    settingsGui.Add("Text", "x20 y195 w120 h20", "Hold Threshold:")
    holdThresholdSlider := settingsGui.Add("Slider", "x150 y195 w180 h20 Range50-500 TickInterval50",
        rowKeyHoldThreshold)
    holdThresholdText := settingsGui.Add("Text", "x340 y195 w40 h20 Right", rowKeyHoldThreshold) ; Show value
    settingsGui.Add("Text", "x150 y212 w230 h20 c777777", "Time in ms to hold row key before activation")

    ; Function to update the hold threshold text
    UpdateHoldThresholdText(*) {
        holdThresholdText.Value := holdThresholdSlider.Value
    }
    holdThresholdSlider.OnEvent("Change", UpdateHoldThresholdText)

    ; --- Monitor Mapping Group ---
    settingsGui.Add("GroupBox", "x10 y245 w380 h120", "Monitor Mapping (Physical -> Logical)")

    mapInputs := [] ; Array to hold the Edit controls for mapping
    monitorCount := MonitorGetCount() ; Get actual monitor count
    maxMonitors := Max(monitorCount, monitorMapping.Length, 4) ; Show controls for at least 4 or actual count

    loop maxMonitors {
        i := A_Index
        currentMapping := monitorMapping.Has(i) ? monitorMapping[i] : i ; Default to physical index if not mapped
        yPos := 265 + (i - 1) * 25
        settingsGui.Add("Text", "x20 y" yPos " w140 h20", "Physical Monitor " i ":")
        editCtrl := settingsGui.Add("Edit", "x170 y" yPos " w40 h20", currentMapping)
        settingsGui.Add("UpDown", "Range1-" maxMonitors, currentMapping) ; Allow mapping up to max monitors shown
        mapInputs.Push(editCtrl) ; Store the edit control
    }

    ; --- Appearance Group ---
    settingsGui.Add("GroupBox", "x10 y" (265 + 25 * maxMonitors + 10) " w380 h80", "Appearance")
    appearanceY := 265 + 25 * maxMonitors + 10 + 20 ; Calculate Y position based on monitor controls

    settingsGui.Add("Text", "x20 y" appearanceY " w130 h20", "Grid Transparency:")
    transparencySlider := settingsGui.Add("Slider", "x150 y" appearanceY " w180 h20 Range0-255 TickInterval20",
        defaultTransparency)
    transparencyText := settingsGui.Add("Text", "x340 y" appearanceY " w40 h20 Right", defaultTransparency) ; Show value

    ; Function to update the text next to the slider
    UpdateSliderText(*) {
        transparencyText.Value := transparencySlider.Value
    }
    transparencySlider.OnEvent("Change", UpdateSliderText)

    settingsGui.Add("Text", "x20 y" (appearanceY + 25) " w130 h20", "Highlight Color:")
    highlightColorEdit := settingsGui.Add("Edit", "x150 y" (appearanceY + 25) " w70 h20", highlightColor)
    ; TODO: Add a color picker button?

    ; --- Buttons ---
    buttonY := appearanceY + 25 + 30 ; Y position for buttons
    applyBtn := settingsGui.Add("Button", "x10 y" buttonY " w120 h30 Default", "&Apply && Save")
    resetBtn := settingsGui.Add("Button", "x140 y" buttonY " w120 h30", "&Reset to Default")
    closeBtn := settingsGui.Add("Button", "x270 y" buttonY " w120 h30", "&Close")

    ; --- Button Event Handlers ---

    ; Apply and Save Settings
    ApplySettings(*) {
        ; Access globals needed to update
        global selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
        global defaultTransparency, highlightColor, instaClickMode, StateMap, highlight
        global settingsFile, enableUltraFast, rowKeyHoldThreshold ; Ultra-Fast settings

        ; Update general settings from GUI controls
        selectedLayout := layoutDropdown.Value ; Get chosen index
        storePerMonitor := storePerMonitorCheckbox.Value
        showcaseDebug := debugCheckbox.Value
        instaClickMode := instaClickCheckbox.Value

        ; Update Ultra-Fast Subgrid settings
        enableUltraFast := ultraFastCheckbox.Value
        rowKeyHoldThreshold := holdThresholdSlider.Value

        ; Update monitor mapping from Edit controls
        newMapping := []
        loop mapInputs.Length {
            i := A_Index
            mapVal := mapInputs[i].Value
            if IsInteger(mapVal) && mapVal >= 1 {
                newMapping.Push(mapVal)
            } else {
                newMapping.Push(i) ; Default to physical index if invalid input
            }
        }
        ; Ensure the global array has the correct size if monitors were added/removed
        while (monitorMapping.Length < newMapping.Length) monitorMapping.Push(0)
            while (monitorMapping.Length > newMapping.Length) monitorMapping.Pop()
            ; Assign new values
                for i, val in newMapping {
                    monitorMapping[i] := val
                }

        ; Update appearance settings
        defaultTransparency := transparencySlider.Value
        highlightColor := highlightColorEdit.Value

        ; --- Apply some settings live (optional, requires GUI objects to be valid) ---
        try {
            ; Update grid transparency if overlays exist
            if (StateMap.Has("overlays") && StateMap['overlays'].Length > 0) {
                for overlay in StateMap['overlays'] {
                    if (IsObject(overlay) && IsObject(overlay.gridOverlay) && IsObject(overlay.gridOverlay.gui)) {
                        WinSetTransColor("000000 " defaultTransparency, overlay.gridOverlay.gui)
                    }
                }
            }
            ; Update highlight color if highlight object exists
            if (IsObject(highlight) && IsObject(highlight.gui)) {
                highlight.gui.BackColor := highlightColor
            }
        } catch {
            ; Silently ignore errors applying live settings
        }

        ; Save all settings to the INI file
        try {
            if (SaveSettings()) {
                MsgBox("Settings saved successfully!", "Settings Saved", 64) ; 64 = Info icon
            } else {
                MsgBox("Failed to save settings.", "Save Error", 16) ; 16 = Error icon
            }
        } catch as e {
            MsgBox("Error saving settings: " e.Message, "Save Error", 16) ; 16 = Error icon
        }
    }

    ; Reset Settings to Defaults
    ResetDefaults(*) {
        ; Reset GUI controls to default values
        layoutDropdown.Choose(2) ; Default layout index
        storePerMonitorCheckbox.Value := true
        debugCheckbox.Value := false
        instaClickCheckbox.Value := false

        ; Reset Ultra-Fast Subgrid settings
        ultraFastCheckbox.Value := true
        holdThresholdSlider.Value := 150
        UpdateHoldThresholdText() ; Update the threshold text display

        ; Reset monitor mapping inputs (example defaults)
        defaultMapping := [2, 1, 3, 4]
        loop mapInputs.Length {
            i := A_Index
            mapInputs[i].Value := defaultMapping.Has(i) ? defaultMapping[i] : i
        }

        ; Reset appearance inputs
        transparencySlider.Value := 180
        UpdateSliderText() ; Update the text display
        highlightColorEdit.Value := "33AAFF"
    }

    ; Close the Settings Window
    CloseSettings(*) {
        settingsGui.Destroy()
    }

    ; Assign event handlers to buttons and window events
    applyBtn.OnEvent("Click", ApplySettings)
    resetBtn.OnEvent("Click", ResetDefaults)
    closeBtn.OnEvent("Click", CloseSettings)
    settingsGui.OnEvent("Close", CloseSettings) ; Handle window close button
    settingsGui.OnEvent("Escape", CloseSettings) ; Handle Escape key

    ; Calculate final GUI height based on content
    guiHeight := buttonY + 30 + 10 ; Add button height and padding
    settingsGui.Show("w400 h" guiHeight)
}
