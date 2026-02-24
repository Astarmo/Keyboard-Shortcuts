#Requires AutoHotkey v2.0

#SingleInstance Force

activeHotstrings := Map()

hotstringsFilePath := A_ScriptDir "\atajos.txt"
if !FileExist(hotstringsFilePath) {
    MsgBox "No se encontró el archivo: " hotstringsFilePath
    return
}

A_TrayMenu.Delete()
A_TrayMenu.Add("Abrir Menú", (*) => make_gui(hotstringsFilePath))
A_TrayMenu.Add("Salir", (*) => ExitApp())

enableHotstringsFromFile(hotstringsFilePath)
if (A_Args.Length = 0 || A_Args[1] != "auto")
    make_gui(hotstringsFilePath)
return


;### FUNCIONES ###

ActiveHotstringsToStr() {
    output := "ActiveHotstrings:`n"
    for hotstring1, pair in activeHotstrings {
        hotstring2 := pair[1]
        positions := pair[2]
        output .= "• [" hotstring1 " → " hotstring2 "]`n"
        for index, position in positions {
            output .= "`t[" position[1] ", " position[2] "]`n"
        }
        output .= "`n"
    }
    return output
}

;función para dividir un string en 2, separando con el primer needle -> que no esté dentro de comillas simples
hotstringSplit(str) {
    inQuotes := false
    for index, char in StrSplit(str) {
        if (char = "'") {
            inQuotes := !inQuotes
        }
        else if (char = "-" && !inQuotes && index < StrLen(str) && SubStr(str, index + 1, 1) = ">") {
            return [SubStr(str, 1, index - 1), SubStr(str, index + 2)]
        }
    }
    return [str, ""]
}

predecesor(hotstring1) {    ;prefijo de hotstring1 de mayor largo distinto de hotstring1
    res := ""
    largoMayor := 0
    for hotstringA in activeHotstrings {
        if (hotstringA != hotstring1 && InStr(hotstring1, hotstringA) = 1 && StrLen(hotstringA) > largoMayor) {
            res := hotstringA
            largoMayor := StrLen(hotstringA)
        }
    }
    return res
}

existeSucesor(hotstring1) {
    for hotstringA in activeHotstrings {
        if (hotstringA != hotstring1 && InStr(hotstringA, hotstring1) = 1) {
            return true
        }
    }
    return false
}

activarHotstring(hotstring1, hotstring2) {
    activeHotstrings[hotstring1] := [hotstring2, []]
    existeSucesorHotstring := existeSucesor(hotstring1)
    predecesorHotstring := predecesor(hotstring1)
    if (!existeSucesorHotstring && predecesorHotstring != "") {   ;es maximo
        hotstringA := predecesorHotstring
        hotstringB := activeHotstrings[hotstringA][1]
        Hotstring(":*?c:" hotstringA, , 0)
        Hotstring(":*?c:" hotstringA " ", hotstringB, 1)
        Hotstring(":*?c:" hotstring1, hotstring2, 1)
    }
    else if (existeSucesorHotstring) {   ;es intermedio o minimo
        Hotstring(":*?c:" hotstring1 " ", hotstring2, 1)
    }
    else {  ; es unico
        Hotstring(":*?c:" hotstring1, hotstring2, 1)
    }
}

desactivarHotstring(hotstring1) {
    activeHotstrings.Delete(hotstring1)
    existeSucesorHotstring := existeSucesor(hotstring1)
    predecesorHotstring := predecesor(hotstring1)
    if (!existeSucesorHotstring && predecesorHotstring != "") {   ;es maximo
        Hotstring(":*?c:" hotstring1, , 0)
        if (!existeSucesor(predecesorHotstring)) {  ;hotstring1 era el único maximo
            hotstringA := predecesorHotstring
            hotstringB := activeHotstrings[hotstringA][1]
            Hotstring(":*?c:" hotstringA " ", , 0)
            Hotstring(":*?c:" hotstringA, hotstringB, 1)
        }
    }
    else if (existeSucesorHotstring) {   ;es intermedio o minimo
        Hotstring(":*?c:" hotstring1 " ", , 0)
    }
    else {  ; es único
        Hotstring(":*?c:" hotstring1, , 0)
    }
}

corregirInconsistencias(hotstringsFilePath) {
    eliminarDuplicadosDentroDeCategoria(lines) {
        seenPairs := Map()
        filteredLines := []

        for line in lines {
            line := Trim(line)
            if (line = "" || InStr(line, ":") = 0 || InStr(line, "->") = 0) {
                continue
            }

            state := Trim(StrSplit(line, ":", , 2)[1])
            hsPair := Trim(StrSplit(line, ":", , 2)[2])
            hsPair := hotstringSplit(hsPair)
            hotstring1 := SubStr(Trim(hsPair[1]), 2, -1)
            hotstring2 := SubStr(Trim(hsPair[2]), 2, -1)

            if (!seenPairs.Has(hotstring1)) {
                seenPairs[hotstring1] := []
            }

            if (seenPairs[hotstring1].Length = 0) {
                seenPairs[hotstring1].Push([hotstring2, state])
                newLine := (state = "1" ? "1" : "0") ": '" hotstring1 "' -> '" hotstring2 "'"
                filteredLines.Push(newLine)
            } else {
                isDuplicate := false
                for idx, pair in seenPairs[hotstring1] {
                    if (pair[1] = hotstring2) {
                        isDuplicate := true
                        if (state = "1" && pair[2] = "0") { ; el estado de la asociación es 1 en la línea actual y 0 en la línea ya vista, por lo que se corrige a 1
                            seenPairs[hotstring1][idx][2] := "1"
                            for i, existingLine in filteredLines {
                                if (InStr(existingLine, "'" hotstring1 "' -> '" hotstring2 "'")) {
                                    filteredLines[i] := "1: '" hotstring1 "' -> '" hotstring2 "'"
                                    break
                                }
                            }
                        }
                        break
                    }
                }
                
                if (!isDuplicate) {
                    newLine := state ": '" hotstring1 "' -> '" hotstring2 "'"
                    seenPairs[hotstring1].Push([hotstring2, state])
                    filteredLines.Push(newLine)
                }
            }
        }

        return filteredLines
    }

    desactivarHotstringsConSalidasDiferentes(hotstringsFilePath) {
        fileText := FileRead(hotstringsFilePath, "UTF-8-RAW")
        categories := StrSplit(fileText, "`n`n")
        output := ""

        for categoryIndex, category in categories {
            lines := StrSplit(category, "`n")
            categoryName := lines[1]
            lines.RemoveAt(1)

            lines := eliminarDuplicadosDentroDeCategoria(lines)

            entries := []
            hotstringIndices := Map()
            for line in lines {
                line := Trim(line)
                if (line = "" || InStr(line, ":") = 0 || InStr(line, "->") = 0) {
                    continue
                }

                state := Trim(StrSplit(line, ":", , 2)[1])
                hsPair := Trim(StrSplit(line, ":", , 2)[2])
                hsPair := hotstringSplit(hsPair)
                hotstring1 := SubStr(Trim(hsPair[1]), 2, -1)
                hotstring2 := SubStr(Trim(hsPair[2]), 2, -1)

                entries.Push([state, hotstring1, hotstring2])
                if (!hotstringIndices.Has(hotstring1)) {
                    hotstringIndices[hotstring1] := []
                }
                hotstringIndices[hotstring1].Push(entries.Length)
            }

            output .= categoryName "`n"
            for hotstring1, indices in hotstringIndices {
                activeCount := 0
                for _, idx in indices {
                    if (entries[idx][1] = "1") {
                        activeCount += 1
                    }
                }
                if (activeCount > 1) {
                    for _, idx in indices {
                        entries[idx][1] := "0"
                    }
                }
            }
            for _, entry in entries {
                newLine := entry[1] ": '" entry[2] "' -> '" entry[3] "'"
                output .= newLine "`n"
            }
            output .= "`n"
        }

        if (StrLen(output) > 0)
            output := SubStr(output, 1, -2)

        FileDelete(hotstringsFilePath)
        FileAppend(output, hotstringsFilePath, "UTF-8-RAW")
    }

    if !FileExist(hotstringsFilePath) {
        return
    }
    desactivarHotstringsConSalidasDiferentes(hotstringsFilePath)
}

enableHotstringsFromFile(hotstringsFilePath) {
    if !FileExist(hotstringsFilePath) {
        MsgBox "No se encontró el archivo: " hotstringsFilePath
        return
    }

    corregirInconsistencias(hotstringsFilePath)

    file := FileOpen(hotstringsFilePath, "r", "UTF-8-RAW")
    lines := StrSplit(FileRead(hotstringsFilePath, "UTF-8-RAW"), "`n", "`r")
    file.Close()

    for line in lines {
        line := Trim(line)

        if (InStr(line, ":") = 0 || InStr(line, "->") = 0) {
            continue
        }

        state := Trim(StrSplit(line, ":", , 2)[1])
        if (state) {
            hsPair := Trim(StrSplit(line, ":", , 2)[2])
            
            hsPair := hotstringSplit(hsPair)
            hotstring1 := SubStr(Trim(hsPair[1]), 2, -1)
            hotstring2 := SubStr(Trim(hsPair[2]), 2, -1)

            activarHotstring(hotstring1, hotstring2)
        }
    }
}

make_gui(hotstringsFilePath) {
    
    height := 400

    goo := Gui("+Resize", "h" height)
    goo.BackColor := 0xE0E0E0
    goo.Title := "Notación Matemática"
    goo.separacionEntreColumnas := goo.separacionEntreCheckboxes := 0
    separacionEntreColumnas := 20
    separacionEntreCheckboxes := 20
    goo.OnEvent("Size", GuiSize)

    if !FileExist(hotstringsFilePath) {
        MsgBox "No se encontró el archivo: " hotstringsFilePath
        return
    }

    file := FileOpen(hotstringsFilePath, "r", "UTF-8-RAW")
    fileText := StrReplace(FileRead(hotstringsFilePath, "UTF-8-RAW"), "`r")
    file.Close()
    categories := StrSplit(fileText, "`n`n")

    checkBoxes := []

    for mainIndex, category in categories {
        lines := StrSplit(category, "`n")

        goo.SetFont('s10 bold cBlack', 'Segoe UI Symbol')
        mainCbText := SubStr(lines[1], 2, -1)
        mainCb := goo.AddCheckbox(, StrReplace(mainCbText, "&", "&&"))
        mainCb.Value := 1

        checkBoxes.Push([mainCb, []])
        lines.RemoveAt(1)

        for subIndex, line in lines {
            line := Trim(line)
            if (line = "" || InStr(line, ":") = 0 || InStr(line, "->") = 0) {
                continue
            }

            goo.SetFont('s10 norm cBlack', 'Segoe UI Symbol')
            subCbText := Trim(StrSplit(line, ":", , 2)[2])
            subCbValue := Trim(StrSplit(line, ":", , 2)[1])
            hsPair := hotstringSplit(subCbText)
            hotstring1 := SubStr(Trim(hsPair[1]), 2, -1)
            hotstring2 := SubStr(Trim(hsPair[2]), 2, -1)
            subCbText := "'" hotstring1 "' → '" hotstring2 "'"
            subCb := goo.AddCheckbox(, StrReplace(subCbText, "&", "&&"))
            subCb.Value := subCbValue
            if subCb.Value {
                if (!activeHotstrings.Has(hotstring1)) {
                    activeHotstrings[hotstring1] := [hotstring2, []]
                }
                activeHotstrings[hotstring1][2].Push([mainIndex, subIndex])
            }            

            mainCb.Value &= subCb.Value
            checkBoxes[-1][2].Push([hotstring1, hotstring2, subCb])

            clickSubCbEnv(checkBoxes, mainIndex, subIndex, hotstringsFilePath)
        }

        clickMainCbEnv(checkBoxes, mainIndex, hotstringsFilePath)
    }

    autoStartCb := goo.AddCheckbox(, "Autoencendido")
    autoStartCb.Value := isAutoStartEnabled()
    autoStartCb.OnEvent("Click", (*) => toggleAutoStart(autoStartCb.Value))

    goo.Show()
    save(checkBoxes, hotstringsFilePath)

    return

    isAutoStartEnabled() {
        startupLnk := A_Startup "\Notación Matemática.lnk"
        return FileExist(startupLnk) != "" ? 1 : 0
    }

    toggleAutoStart(enable) {
        startupLnk := A_Startup "\Notación Matemática.lnk"
        scriptPath := A_ScriptFullPath
        if enable {
            FileCreateShortcut(scriptPath, startupLnk, , "auto")
        } else if FileExist(startupLnk) {
            FileDelete(startupLnk)
        }
    }

    GuiSize(guiObj, MinMax, Width, Height) {
        separacionEntreColumnas := 15
        sangria := 15
        separacionEntreCheckboxes := 5
        separacionEntreCategorias := 15
        
        left0 := separacionEntreColumnas
        up0 := separacionEntreCheckboxes

        left := left0
        up := up0
        right := left
        down := up
        for mainIndex, _ in checkBoxes {
            mainCheckbox := checkBoxes[mainIndex][1]
            mainCheckbox.GetPos(, , &w, &h)
            down := up + h
            if (down > height) {
                left := right + separacionEntreColumnas
                up := up0
                right := left
                down := up + h
            }
            right := Max(right, left + w)
            mainCheckbox.Move(left, up)
            mainCheckbox.Opt("+Redraw")
            up := down
            up += separacionEntreCheckboxes

            left += sangria
            for m in checkBoxes[mainIndex][2] {
                subCheckbox := m[3]
                subCheckbox.GetPos(, , &w, &h)
                down := up + h
                if (down > height) {
                    left := right + separacionEntreColumnas + sangria
                    up := up0
                    right := left
                    down := up + h
                }
                right := Max(right, left + w)
                subCheckbox.Move(left, up)
                subCheckbox.Opt("+Redraw")
                up := down
                up += separacionEntreCheckboxes
            }
            left -= sangria
            if (up != up0) {
                up += separacionEntreCategorias
            }
        }
        autoStartCb.GetPos(, , &w, &h)
        down := up + h
        if (down > height) {
            left := right + separacionEntreColumnas
            up := up0
            right := left
            down := up + h
        }
        right := Max(right, left + w)
        up := Height - h - separacionEntreCheckboxes
        autoStartCb.Move(left, up)
        autoStartCb.Opt("+Redraw")

        guiObj.Move(, , right + separacionEntreColumnas, )
    }

    save(checkBoxes, hotstringsFilePath) {
        output := ""
        for main in checkBoxes {
            mainCheckbox := main[1]
            output .= "[" StrReplace(mainCheckbox.Text, "&&", "&") "]`n"
            for m in main[2] {
                subCheckbox := m[3]
                hotstring1 := m[1]
                hotstring2 := m[2]
                output .= (subCheckbox.Value ? "1" : "0") ": '" hotstring1 "' -> '" hotstring2 "'`n"
            }
            output .= "`n"
        }
        if (StrLen(output) > 0)
            output := SubStr(output, 1, -2)
        file := FileOpen(hotstringsFilePath, "w", "UTF-8-RAW")
        FileDelete(hotstringsFilePath)
        FileAppend(output, hotstringsFilePath, "UTF-8-RAW")
        file.Close()
    }

    
    actualizarValorMainCheckbox(mainIndex) {
        mainCheckbox := checkBoxes[mainIndex][1]
        valor := 1
        for c in checkBoxes[mainIndex][2] {
            subCheckbox := c[3]
            valor &= subCheckbox.Value
        }
        mainCheckbox.Value := valor
    }

    tieneAsociacionDistinta(hotstring1, hotstring2) {
        return activeHotstrings.Has(hotstring1) && activeHotstrings[hotstring1][1] != hotstring2
    }

    reemplazarAsociacion(hotstring1, hotstring2nuevo) {
        return MsgBox("¿Desea reemplazar '" hotstring1 "' → '" activeHotstrings[hotstring1][1] "' por '" hotstring1 "' → '" hotstring2nuevo "'?", , "Y/N")
    }

    activarCheckbox(mainIndex, subIndex){
        subCheckbox := checkBoxes[mainIndex][2][subIndex][3]
        hotstring1 := checkBoxes[mainIndex][2][subIndex][1]
        hotstring2 := checkBoxes[mainIndex][2][subIndex][2]

        mainCheckbox := checkBoxes[mainIndex][1]
        
        if (tieneAsociacionDistinta(hotstring1, hotstring2) && reemplazarAsociacion(hotstring1, hotstring2) = "No") {
            subCheckbox.Value := 0
            mainCheckbox.Value := 0
        }
        else {
            desactivarOtrasCheckboxes(hotstring1, hotstring2)
            subCheckbox.Value := 1
            if (!activeHotstrings.Has(hotstring1)) {
                activarHotstring(hotstring1, hotstring2)
            }

            ; agregar la checkbox a la lista de checkboxes activas de hotstring1 si no está ya en la lista
            checkBoxYaActivada := false
            for pair in activeHotstrings[hotstring1][2] {
                if (pair[1] = mainIndex && pair[2] = subIndex) {
                    checkBoxYaActivada := true
                    break
                }
            }
            if (!checkBoxYaActivada) {
                activeHotstrings[hotstring1][2].Push([mainIndex, subIndex])
            }

            if mainCheckbox.Value = 0
                actualizarValorMainCheckbox(mainIndex)
        }
    }

    desactivarCheckbox(mainIndex, subIndex){
        subCheckbox := checkBoxes[mainIndex][2][subIndex][3]
        subCheckbox.Value := 0
        hotstring1 := checkBoxes[mainIndex][2][subIndex][1]
        if (activeHotstrings.Has(hotstring1)) {
            for index, pair in activeHotstrings[hotstring1][2] {
                if (pair[1] = mainIndex && pair[2] = subIndex) {
                    activeHotstrings[hotstring1][2].RemoveAt(index)
                    break
                }
            }
            if (activeHotstrings[hotstring1][2].Length = 0) {
                desactivarHotstring(hotstring1)
            }
        }

        mainCheckbox := checkBoxes[mainIndex][1]
        mainCheckbox.Value := 0
    }
    
    desactivarOtrasCheckboxes(hotstring1, hotstring2) {
        if (activeHotstrings.Has(hotstring1) && activeHotstrings[hotstring1][1] != hotstring2) {
            for index, pair in activeHotstrings[hotstring1][2] {
                desactivarCheckbox(pair[1], pair[2])
            }
        }
    }


    clickMainCbEnv(checkBoxes, mainIndex, hotstringsFilePath) {
        mainCheckbox := checkBoxes[mainIndex][1]
        mainCheckbox.OnEvent('Click', (*) => clickMainCb(checkBoxes, mainIndex, hotstringsFilePath))

        clickMainCb(checkBoxes, mainIndex, hotstringsFilePath) {
            mainCheckbox := checkBoxes[mainIndex][1]
            if (mainCheckbox.Value) {
                for subIndex, _ in checkBoxes[mainIndex][2] {
                    activarCheckbox(mainIndex, subIndex)
                }
            }
            else {
                for subIndex, _ in checkBoxes[mainIndex][2] {
                    desactivarCheckbox(mainIndex, subIndex)
                }
            }
            save(checkBoxes, hotstringsFilePath)
        }
    }
    
    clickSubCb(checkBoxes, mainIndex, subIndex, hotstringsFilePath) {
        subCheckbox := checkBoxes[mainIndex][2][subIndex][3]
        if subCheckbox.Value
            activarCheckbox(mainIndex, subIndex)
        else
            desactivarCheckbox(mainIndex, subIndex)

        save(checkBoxes, hotstringsFilePath)
    }

    clickSubCbEnv(checkBoxes, mainIndex, subIndex, hotstringsFilePath) {
        subCheckbox := checkBoxes[mainIndex][2][subIndex][3]
        subCheckbox.OnEvent('Click', (*) => clickSubCb(checkBoxes, mainIndex, subIndex, hotstringsFilePath))
    }
}
