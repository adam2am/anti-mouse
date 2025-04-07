; ==============================================================================
; memory_settings.ahk - Functions for Loading/Saving Cell Memory & Settings
; ==============================================================================

; Access global config variables
global settingsFile, cellMemoryFile, layoutConfigs ; Import from config.ahk
global showcaseDebug ; For debug messages

; --- Cell Memory Management ---

; Loads the remembered cell->subcell mappings from the specified file.
LoadCellMemory() {
    global cellMemory, cellMemoryFile, showcaseDebug ; Access global state and config

    ; Clear existing memory first to ensure a fresh load
    cellMemory := Map()

    try {
        if (FileExist(cellMemoryFile)) {
            fileContent := FileRead(cellMemoryFile)
            lines := StrSplit(fileContent, "`n", "`r") ; Split by newline or carriage return

            loadedCount := 0
            for line in lines {
                if (Trim(line) = "") { ; Skip empty lines
                    continue
                }

                parts := StrSplit(line, "=") ; Expect format: cellKey=subCellKey
                if (parts.Length >= 2) {
                    cellKey := Trim(parts[1])
                    subCellKey := Trim(parts[2])
                    if (cellKey != "" && subCellKey != "") { ; Ensure valid keys
                        cellMemory[cellKey] := subCellKey
                        loadedCount += 1
                    }
                }
            }

            if (showcaseDebug) {
                ToolTip("Loaded " loadedCount " cell memories from " cellMemoryFile)
                Sleep(1500)
                ToolTip()
            }
        } else {
            if (showcaseDebug) {
                ToolTip("Cell memory file not found: " cellMemoryFile)
                Sleep(1500)
                ToolTip()
            }
            ; No error if file doesn't exist, just start with empty memory
        }
    } catch as e {
        if (showcaseDebug) {
            ToolTip("Error loading cell memory: " e.Message)
            Sleep(1500)
            ToolTip()
        }
        ; Continue with empty memory if loading fails
        cellMemory := Map()
    }
}

; Saves the current cell->subcell mappings to the specified file.
SaveCellMemory() {
    global cellMemory, cellMemoryFile, showcaseDebug ; Access global state and config

    try {
        fileContent := ""
        savedCount := 0
        for cellKey, subCellKey in cellMemory {
            if (cellKey != "" && subCellKey != "") { ; Ensure we don't save empty keys/values
                fileContent .= cellKey "=" subCellKey "`n"
                savedCount += 1
            }
        }

        ; Ensure the directory exists before writing
        SplitPath(cellMemoryFile, &fileName, &fileDir)
        if (!DirExist(fileDir) && fileDir != "") {
            DirCreate(fileDir)
        }

        ; Write the file content
        file := FileOpen(cellMemoryFile, "w", "UTF-8") ; Open in write mode, UTF-8 encoding
        if (!IsObject(file)) {
            throw Error("Failed to open file for writing: " cellMemoryFile)
        }
        file.Write(fileContent)
        file.Close()

        if (showcaseDebug) {
            ToolTip("Saved " savedCount " cell memories to " cellMemoryFile)
            Sleep(1500)
            ToolTip()
        }
    } catch as e {
        ; Show error message to user if saving fails
        MsgBox("Error saving cell memory: " e.Message, "Save Error", "IconError")
        if (showcaseDebug) {
            ToolTip("Error saving cell memory: " e.Message)
            Sleep(2000)
            ToolTip()
        }
    }
}

; --- Application Settings Management ---

; Loads application settings from the specified INI file.
LoadSettings() {
    ; Access global config variables that will be loaded/updated
    global settingsFile, selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
    global defaultTransparency, highlightColor, instaClickMode
    global enableUltraFast, rowKeyHoldThreshold ; Ultra-Fast Subgrid settings

    try {
        if (FileExist(settingsFile)) {
            ; Load general settings, providing current value as default
            loadedLayout := IniRead(settingsFile, "General", "Layout", selectedLayout)
            ; Validate loaded layout
            if (IsInteger(loadedLayout) && loadedLayout >= 1 && loadedLayout <= layoutConfigs.Length) {
                selectedLayout := loadedLayout
            }

            storePerMonitor := IniRead(settingsFile, "General", "StorePerMonitor", storePerMonitor)
            showcaseDebug := IniRead(settingsFile, "General", "Debug", showcaseDebug)
            instaClickMode := IniRead(settingsFile, "General", "InstaClickMode", instaClickMode)

            ; Load Ultra-Fast Subgrid settings
            enableUltraFast := IniRead(settingsFile, "UltraFast", "Enable", enableUltraFast)
            loadedThreshold := IniRead(settingsFile, "UltraFast", "HoldThreshold", rowKeyHoldThreshold)
            if (IsInteger(loadedThreshold) && loadedThreshold >= 50 && loadedThreshold <= 500) {
                rowKeyHoldThreshold := loadedThreshold
            }

            ; Load monitor mapping
            for i, _ in monitorMapping {
                ; Validate loaded mapping value
                loadedMapping := IniRead(settingsFile, "MonitorMapping", "Monitor" i, monitorMapping[i])
                if (IsInteger(loadedMapping) && loadedMapping >= 1) { ; Basic validation
                    monitorMapping[i] := loadedMapping
                }
            }

            ; Load appearance settings
            loadedTransparency := IniRead(settingsFile, "Appearance", "Transparency", defaultTransparency)
            ; Validate transparency range
            if (IsInteger(loadedTransparency) && loadedTransparency >= 0 && loadedTransparency <= 255) {
                defaultTransparency := loadedTransparency
            }

            highlightColor := IniRead(settingsFile, "Appearance", "HighlightColor", highlightColor)

            if (showcaseDebug) {
                ToolTip("Settings loaded from " settingsFile)
                Sleep(1000)
                ToolTip()
            }
        }
        ; No error if file doesn't exist, just use default values
    } catch as e {
        MsgBox("Error loading settings: " e.Message, "Load Error", "IconError")
        ; Continue with default settings if loading fails
    }
}

; Saves the current application settings to the specified INI file.
SaveSettings() {
    ; Access global config variables to be saved
    global settingsFile, selectedLayout, storePerMonitor, showcaseDebug, monitorMapping
    global defaultTransparency, highlightColor, instaClickMode
    global enableUltraFast, rowKeyHoldThreshold ; Ultra-Fast Subgrid settings

    try {
        ; Ensure the directory exists before writing
        SplitPath(settingsFile, &fileName, &fileDir)
        if (!DirExist(fileDir) && fileDir != "") {
            DirCreate(fileDir)
        }

        ; Save general settings
        IniWrite(selectedLayout, settingsFile, "General", "Layout")
        IniWrite(storePerMonitor, settingsFile, "General", "StorePerMonitor")
        IniWrite(showcaseDebug, settingsFile, "General", "Debug")
        IniWrite(instaClickMode, settingsFile, "General", "InstaClickMode")

        ; Save Ultra-Fast Subgrid settings
        IniWrite(enableUltraFast, settingsFile, "UltraFast", "Enable")
        IniWrite(rowKeyHoldThreshold, settingsFile, "UltraFast", "HoldThreshold")

        ; Save monitor mapping
        for i, mapping in monitorMapping {
            IniWrite(mapping, settingsFile, "MonitorMapping", "Monitor" i)
        }

        ; Save appearance settings
        IniWrite(defaultTransparency, settingsFile, "Appearance", "Transparency")
        IniWrite(highlightColor, settingsFile, "Appearance", "HighlightColor")

        if (showcaseDebug) {
            ToolTip("Settings saved to " settingsFile)
            Sleep(1000)
            ToolTip()
        }

        return true ; Indicate success
    } catch as e {
        MsgBox("Error saving settings: " e.Message, "Save Error", "IconError")
        return false ; Indicate failure
    }
}
