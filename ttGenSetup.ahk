#Requires AutoHotKey v2.0-a
#SingleInstance Force

;/////////////////////////////////////////////////////////////////////////////
; CONSTANTS
;/////////////////////////////////////////////////////////////////////////////
BEGIN := 1
SQ_FIELD_NUM := 10
RMK_FIELD_NUM := 9
ERROR_CODE := 0

posSqRngStrt := 4001
posSqRngEnd  := 4077
sqCode512_64 := 40

;/////////////////////////////////////////////////////////////////////////////
; GLOBAL VARIABLES
;/////////////////////////////////////////////////////////////////////////////
tmpFldr_ := ""
installDir_ := ""
ahkPath_ := ""
compilerPath_ := ""

;/////////////////////////////////////////////////////////////////////////////
; CLASSES, TYPE, & DATA STRUCTURES
;/////////////////////////////////////////////////////////////////////////////
;represents a .air file config line
class FlightPlan extends Map {
    ;initializes flight plan fields based on .air config line
    __New(line := unset){
        ;if default constructor
        if(!IsSet(line)){
            super.Set(
                "callsign", "", "acType", "", "engine", "", "rules", "",
                "depField", "", "arrField", "",
                "crzAlt", "", "route", "", "remarks", "",
                "sqCode", -1, "sqMode", "",
                "lat", 0, "lon", 0, "altitude", -1, "speed", -1, "heading", -1
            ) ;end super()

            Return ;//!!!EXIT FUNCTION HERE!!!//
        } ;end if default constructor

        fields := FlightPlan.getFieldArr(line)
        
        ;init constructor
        super.Set(
            "callsign", fields[1], "acType", fields[2], "engine", fields[3],
            "rules", fields[4], "depField", fields[5], "arrField", fields[6],
            "crzAlt", fields[7], "route", fields[8], "remarks", fields[9],
            "sqCode", fields[10], "sqMode", fields[11], "lat", fields[12],
            "lon", fields[13], "altitude", fields[14], "speed", fields[15],
            "heading", fields[16]
        ) ;end super()
        ;end init constructor
    } ;end __New(line)

    ToString(){
        return this["callsign"] ":" this["acType"] ":" this["engine"] ":" this["rules"] ":" this["depField"] ":" this["arrField"] ":" this["crzAlt"] ":" this["route"] ":" this["remarks"] ":" this["sqCode"] ":" this["sqMode"] ":" this["lat"] ":" this["lon"] ":" this["altitude"] ":" this["speed"] ":" this["heading"]
    } ;end ToString()

    ; checks line to ensure it is formatted properly
    ;   according to the .air file spec
    ; returns an array of fields in line
    ; the array will maintain the order of the fields as they are in line
    static getFieldArr(line){
        fields := StrSplit(line, ":",,17)

        ;if correct # of fields
        if (fields.Length != 16){
            MsgBox "Wrong number of fields (" . fields.Length .
                ")in .air config line: " . line . "...terminating...",
                "Malformed .air config line"
            Exit 1
        }

        Return fields
    } ;end getFields()
} ;end class FlightPlan

; this class really should not extend Map...
;   it should be a sibling of Map
; However, I do want to reuse a significant amount of the code in Map
;   and there isn't an easy way for me to copy Map's code to write a new class
;   So... I am extending it and overloading pieces I don't want
;   to make them throw errors
class Set extends Map {
    ;override Map's Set() to make key and value the same
    Set(keys*){
        for key in keys{
            if !(this.Has(key))
                super.Set(key, key)
        }

        return this
    } ;end Set(keys*)

    ;override Map's __New() to use Set's Set()
    __New(keys*){
        this.Set(keys*)
    } ;end __New

    ; DO NOT USE THE Get() METHOD
    Get(){
        newError := MethodError(
                'This value of type "' Type(this) . 
                '" has no method named "Get"',
                -2
            ) ;end PropertyError()
            throw newError
    } ;end Get()

    ; DO NOT USE THE __Item PROPERTY
    __Item[Key]{
        set{
            newError := PropertyError(
                'This value of type "' Type(this) . 
                '" has no property named "__Item"',
                -2
            ) ;end PropertyError()
            throw newError
        } ;end __Item() set
        get{
            newError := PropertyError(
                'This value of type "' Type(this) . 
                '" has no property named "__Item"',
                -2
            ) ;end PropertyError()
            throw newError
        } ;end __Item() set
    } ;end __Item[]
} ;end class Set

class SquawkCodeSet extends Set {
    ;Generates a sqCode in the give range
    ;  each digit is interpreted as a separate range
    ;rngStrt and rngEnd must be sqCodes
    ;  i.e. they should be 4 digit octal numbers
    ;rngEnd must be larger than rndStrt
    static generate(rngStrt, rngEnd){
        ;convert range to base for Random()
        rngStrt := baseCnvrt(rngStrt, 8, 10)
        rngEnd  := baseCnvrt(rngEnd, 8, 10)

        ;generate random num in range and convert back to octal for sqCode
        return baseCnvrt(Random(rngStrt, rngEnd), 10, 8)
    } ;end generate()

    ;Loop until generate NEW random sqCode
    genSet(rngStrt, rngEnd){
        Loop{
            newSqCode := SquawkCodeSet.generate(rngStrt, rngEnd)

            if !(this.Has(newSqCode)){
                this.Set(newSqCode)
                return newSqCode
            }
        } ;End Loop until assign new random sqCode
    } ;end genSet()
} ;end class SquawkCodeSet

;/////////////////////////////////////////////////////////////////////////////
; FUNCTION DEFINITIONS
;/////////////////////////////////////////////////////////////////////////////
baseCnvrt(value, from, to){
    if !(value and from and to)                 ;if mising data...
    {
        ;MsgBox, 4096 , , Missing Parameter! `n`nUse: Convert("Value", "From", "To") `n`nExample: `nConvert("55", "dec", "hex")
        MsgBox('Missing Parameter! `n`nUse: Convert("Value", "From", "To") `n`nExample: `nConvert("55", "dec", "hex")', 4096)
        Exit
    }                                                      ;else ....
    
    ;some names for number systems
    base2 := "Base2|Binary|Bin|Digital|Binär|Dual|Di|B"
    base3 := "Base3|Ternary|Triple|Trial|Ternär"
    base4 := "Base4|Quaternary|Quater|Tetral|Quaternär"
    base5 := "Base5|Quinary|Pental|Quinär"
    base6 := "Base6|Senary|Hexal|Senär"
    base7 := "Base7|Septenary|Peptal|Heptal"
    base8 := "Base8|Octal|Oktal|Oct|Okt|O"
    base9 := "Base9|Nonary|Nonal|Enneal"
    base10 := "Base10|Decimal|Dezimal|Denär|Dekal|Dec|Dez|D"
    base11 := "Base11|Undenary|Monodecimal|Monodezimal|Hendekal"
    base12 := "Base12|Duodecimal|Dedezimal|Dodekal"
    base13 := "Base13|Tridecimal|Tridezimal|Triskaidekal"
    base14 := "Base14|Tetradecimal|Tetradezimal|Tetrakaidekal"
    base15 := "Base15|Pentadecimal|Pentadezimal|Pentakaidekal"
    base16 := "Base16|Hexadecimal|Hexadezimal|Hektakaidekal|Hex|H"
    base17 := "Base17|Peptaldecimal|Peptaldezimal|Heptakaidekal"
    base18 := "Base18|Octaldecimal|Oktaldezimal|Octakaidekal|Oktakaidekal"
    base19 := "Base19|Nonarydecimal|Nonaldezimal|Enneakaidekal"
    base20 := "Base20|Vigesimal|Eikosal"
    base30 := "Base30|Triakontal"
    base40 := "Base40|Tettarakontal"
    base50 := "Base50|Pentekontal"
    base60 := "Base60|Sexagesimal|Hektakontal"
    
    ;StringReplace, value_form, value,(,,all
    value_form := StrReplace(value,"(")
    ;StringReplace, value_form, value_form ,),, all          ;if value is integer or letter when...
    value_form := StrReplace(value_form,")")
    if !IsAlnum(value_form)                                       ;...parenthesis are removed
    {                                                                           ; if not...
        ;MsgBox, 4096 , , Error! `n`nOnly alphanumeric Symbols will be accepted!
        MsgBox('Error! `n`nOnly alphanumeric Symbols will be accepted!',,4096)
        Exit
    }                                                           ;------------------------------------------------------------------------------------
    if (InStr(from, "base"))                                            ;if the word "base" is in "from"...
    {
        ;StringTrimLeft, base_check, from, 4                   ;...then cut "base" to have ONLY the number
        base_check := SubStr(from, 5)
        if !IsInteger(base_check)                               ;if "from" not integer now
        {
            ;MsgBox, 4096 , , Unknown Number System! `n`nUse Base + Number (example: Base16), `nor the name/shortcut (example: "Hexadecimal" or "Hex")
            MsgBox('Unknown Number System ' from ' ! `n`nUse Base + Number (example: Base16), `nor the name/shortcut (example: "Hexadecimal" or "Hex")',,4096)
            Exit
        }
        else                                                                  ;else replace the value from "from" 
            from := base_check                                       ;with the number in base_check
    }
    if (InStr(to, "base"))                                            ;if the word "base" is in "from"...
    {
        ;StringTrimLeft, base_check, from, 4                   ;...then cut "base" to have ONLY the number
        base_check := SubStr(to, 5)
        if !IsInteger(base_check)                               ;if "from" not integer now
        {
            ;MsgBox, 4096 , , Unknown Number System! `n`nUse Base + Number (example: Base16), `nor the name/shortcut (example: "Hexadecimal" or "Hex")
            MsgBox('Unknown Number System ' to ' ! `n`nUse Base + Number (example: Base16), `nor the name/shortcut (example: "Hexadecimal" or "Hex")',,4096)
            Exit
        }
        else                                                                  ;else replace the value from "from" 
            to := base_check                                       ;with the number in base_check
    }                                                          ;------------------------------------------------------------------------------------
    
    base_loop := 1
    Loop 60                                                ;check in a loop from 2 to 60 if the names from
    {                                                          ;the source / destination number system is in the Variable "base.."
        if isInteger(from)                               ;if "from" is integer...
            if isInteger(to)                               ;and "to" too...
                Break                                       ;...cancel the loop
        if (base_loop < 20)                            ;if base_loop < 20...
            base_loop++                                ;...increase by 1
        else                                                  ;else...
            base_loop += 10                           ;...increase by 10
        if (base_loop > 60)                            ;and if more then 60 ...
            Break                                           ;...cancel the loop
        base := base%base_loop%
        Loop Parse base, "|"                            ;split every base variable word by word
        {
            toB4 := to
            if (from = A_LoopField)                  ;if one of them identical with the name ...
                from := base_loop                     ;...from the source number system then save the number in "from"
            if (to = A_LoopField)                      ;        ...the same for the destination number system
                to := base_loop
        }
    }
    if !isInteger(to){
        MsgBox('Unknown Number System ' to ' ! `n`nUse Base + Number (example: Base16), `nor the name/shortcut (example: "Hexadecimal" or "Hex")',,4096)
        Exit
    }
    if !isInteger(from){
        MsgBox('Unknown Number System ' from ' ! `n`nUse Base + Number (example: Base16), `nor the name/shortcut (example: "Hexadecimal" or "Hex")',,4096)
        Exit
    }
    
    if (from < 11)                                        ;by source numer system to 10 (therefore Decimal)
        if !isInteger(value)                         ;letters are not allowed
        {                                                      ;else exit
            ;StringGetPos, seperator_1, base%from%, |, L1 ;position of the first seperator
            seperator_1 := InStr(base%from%, "|")
            ;StringGetPos, seperator_2, base%from%, |, L2 ;position of the second seperator...
            seperator_2 := InStr(base%from%, "|",,,2)
            ;StringMid, name_from, base%from%, (seperator_1 + 2), (seperator_2 - seperator_1 - 1)
            ;name_from := SubStr(base%from%, (seperator_1 + 1), (seperator_2 - seperator_1 - 1))
            ;MsgBox, 4096 , , Error! `nNo letters allowed in %name_from% system!
            name_from := SubStr(base%from%, 1, seperator_2-1)
            ;MsgBox, 4096 , , Error! `nNo letters allowed in %name_from% system!
            MsgBox('Error! `nNo letters allowed in ' name_from ' system!',,4096)
            Exit
        }
    
    con_letter := "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ;allowed letters
    ;result_dec= 
    result_dec := 0
    length := StrLen(value) ;count the characters
    counter := 0
    parenthesis := False    ;no parenthesis yet
    par_char := ""
    Loop length           ;loop by any character from "value"
    {
        ;StringMid, char, value, (length + 1 - A_Index), 1 ;process "backwards" the value, character by character
        char := SubStr(value, (length + 1 - A_Index), 1)
        if (char = ")")                                                   ;if there an right parenthesis ...
        {                                                                    ;      (notice, we work "backwards" at this time)
            if parenthesis                                              ;...although there was an right parenthesis before (without a left parenthesis) ...
            {                                                                ;...then exit
                ;MsgBox, 4096 , , Error!`nOnly "simple" parenthesis will be accepted!`n`nExample:`n57AH6(45)(48)G2 = accepted`n57AH6((45)(48))G2 = NOT accepted!
                MsgBox('Error!`nOnly "simple" parenthesis will be accepted!`n`nExample:`n57AH6(45)(48)G2 = accepted`n57AH6((45)(48))G2 = NOT accepted!',,4096)
                Exit
            }
            parenthesis := True                                     ;else memorize that we are between parenthesis now
            Continue                                                     ;...cancel the rest from the loop and continue from begin
        }
        else if (char = "(")                                            ;if there an right parenthesis ...
        {                                                                    ;      (notice, we work "backwards" at this time)
            if !parenthesis                                             ;...although there wasn´t a right parenthesis before...
            {                                                                ;...then exit
                ;MsgBox, 4096 , , Error!`nOnly "simple" parenthesis will be accepted!`n`nExample:`n57AH6(45)(48)G2 = accepted`n57AH6((45)(48))G2 = NOT accepted!
                MsgBox('Error!`nOnly "simple" parenthesis will be accepted!`n`nExample:`n57AH6(45)(48)G2 = accepted`n57AH6((45)(48))G2 = NOT accepted!',,4096)
                Exit
            }
            parenthesis := False                                   ;else memorize that we are NOT between parenthesis now
            if !par_char                                                ;if nothing between the parenthesis...
            {                                                               ;...then exit
                ;MsgBox, 4096 , , Error! `n No value between parenthesis!
                MsgBox('Error! `n No value between parenthesis!',,4096)
                Exit
            }
            char := par_char                                        ;else, all numbers between parenthesis are ONE character now
            par_char := ""
        }
        else if parenthesis                                          ;we are between parenthesis at this time...
        {
            if !isInteger(char)                                   ;...and there is some other than Integer, then cancel
            {
                ;MsgBox, 4096 , , Error! ´nBetween parenthesis only numbers will be accepted!
                MsgBox('Error! ´nBetween parenthesis only numbers will be accepted!',,4096)
                Exit
            }
            par_char := char . par_char                        ;else put every character between the parenthesis to ONE value
            Continue                                                    ;notice, because we work backwards in this loop, the next number will put BEFORE the previous number, ...
        }
        else if isAlpha(char)                                        ;if there a letter
        {
            ;StringGetPos, char_pos, con_letter, %char%          ;then check th position from this letter in "con_letter"
            char_pos := InStr(con_letter, char)
            MsgBox("char: " char "char_pos: " char_pos, "char:char_pos")
            ;StringReplace, char, char, %char%, %char_pos%   ;and replace the letter with the position-number
            ;char := StrReplace(char, char, char_pos)
            char := char_pos
            ;char += 10                                                            ;and add 10
            char += 9
            if (char >= from)
            {                                                                           ;if the number greater than the number system...
                ;StringGetPos, seperator_1, base%from%, |, L1  ;...Example: 18 in hexadecimal system
                seperator_1 := InStr(base%from%, "|")
                ;StringGetPos, seperator_2, base%from%, |, L2  ;then exit
                seperator_2 := InStr(base%from%, "|",,,2)
                ;StringMid, name_from, base%from%, (seperator_1 + 2), (seperator_2 - seperator_1 - 1)
                name_from := SubStr(base%from%, 1, seperator_2-1)
                char := from - 10
                ;StringMid, char, con_letter, %char%, 1
                char := SubStr(con_letter, char, 1)
                ;MsgBox, 4096 , , Error! `nOnly letters until "%char%" will be accepted in %name_from% system!
                MsgBox('Error! `nOnly letters until "' char '" will be accepted in ' name_from ' system!',,4096)
                Exit
            }
        }
        if (char >= from)   ;is the character at this position isn´t a letter, but a number which is...
        {                          ;...greater than the number system, then exit
            max_value := from - 1
            ;MsgBox, 4096 , , Error! `nOnly values from 0-%max_value% will be accepted in base%from% system!
            MsgBox('Error! `nOnly values from 0-' max_value ' will be accepted in base' from ' system!',,4096)
            Exit
        }
        result_dec += char * (from**counter)   ;convert source number system to decimale number system
        counter++                                        ;increase counter by one
    }
    if (to = 10)                                            ;if decimale system the destination number system
        Return result_dec                        ;then return the result
    ;result=                                                  ;else convert it to destination number system
    result := ""
    while (result_dec)
    {        
        char := Mod(result_dec , to)                        ; first number from destination number system
        if (char > 35)                                               ;if it greater than 35...
            char := "(" . char . ")"                               ;...put it between parenthesis
        else if (char > 9)                                          ;if it less than 36 , but greater than 9,
            ;StringMid, char, con_letter, (char - 9), 1    ;...replace it with a letter
            char := SubStr(con_letter, (char - 9), 1)
        result :=  char . result                                   ;combine the characters to the result
        result_dec := Floor(result_dec / to)               ;calculate the remain to continue the converting with this
    }
    Return result                                             ;return result
}

cleanNExit(errCode:=0){
    if ((errCode & 1) || (errCode & 2))
        ExitApp errCode
    try{
        DirDelete tmpFldr_, 1
    }
    catch Any as err {
            MsgBox Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
            , type(err), err.Message, err.File, err.Line, err.What, err.Stack), "Delete Folder Error... terminating"
            
            errCode += 4
    }

    ExitApp errCode
} ;end cleanNExit()

gen_tmpFldr(){
    i := 0
    while true{
        tmpFldr_ := A_Temp "\" A_ScriptName "_" A_NowUTC "_" DllCall("GetCurrentProcessId") "_" i "_tmp"
        if (DirExist(tmpFldr_)){
            MsgBox("exists: " tmpFldr_, "Foler exists... trying again")
            i++
            continue
        }

        try{
            DirCreate tmpFldr_
        }
        catch OSError as err {
             MsgBox Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nNumber:`t{6}`nStack:`n{7}"
                , type(err), err.Message, err.File, err.Line, err.What, err.Number, err.Stack), "Create Folder OSError... terminating"
            ExitApp
        }

        ;//if no error creating tmpFldr_
        MsgBox(tmpFldr_, "Created folder")
        return tmpFldr_
    }
} ;end gen_tmpFldr()

/*
;returns path of the installed compiler
installCompiler(path){
    MsgBox(path, "path")
    if (DirExist(path)){
        MsgBox("exists: " path, "Foler exists... terminating...")
        ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ; allow option to choose install location
        ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        cleanNExit()
    }

    try{
        DirCreate path
    }
    catch OSError as err {
            MsgBox Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nNumber:`t{6}`nStack:`n{7}"
            , type(err), err.Message, err.File, err.Line, err.What, err.Number, err.Stack), "Create Folder OSError... terminating"
        cleanNExit()
    }

    FileInstall "Compiler\Ahk2Exe.exe", path "\Ahk2Exe.exe"
    FileInstall "Compiler\ANSI 32-bit.bin", path "\ANSI 32-bit.bin"
    FileInstall "Compiler\AutoHotkeySC.bin", path "\AutoHotkeySC.bin"
    FileInstall "Compiler\Unicode 32-bit.bin", path "\Unicode 32-bit.bin"
    FileInstall "Compiler\Unicode 64-bit.bin", path "\Unicode 64-bit.bin"

    return path "\Ahk2Exe.exe"
} ;end installCompiler()
*/

installAHK(path){
    MsgBox(path, "path")
    if (DirExist(path)){
        MsgBox("exists: " path, "Foler exists... terminating...")
        ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ; allow option to choose install location
        ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        cleanNExit()
    }

    try{
        DirCreate path`
    }
    catch OSError as err {
            MsgBox Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nNumber:`t{6}`nStack:`n{7}"
            , type(err), err.Message, err.File, err.Line, err.What, err.Number, err.Stack), "Create Folder OSError... terminating"
        cleanNExit()
    }

    FileInstall "AutoHotkey_1.1.33.10_setup.exe", path "\AutoHotkey_1.1.33.10_setup.exe"
    RunWait '"' path '\AutoHotkey_1.1.33.10_setup.exe" /S /D="' path '" /E'
    MsgBox("Here0.0.1", "Here")
    ExitApp
    FileInstall "AutoHotkey64.exe", path "\AutoHotkey.exe"
    FileInstall "AutoHotkey64.exe", path "\AutoHotkey64.exe"

    return path
} ;installAHK

uninstallAHK(){
    RunWait ahkPath_ installDir_ "\Installer.ahk /Uninstall",,"Hide"
}

/*
;returns the text of field at fieldNum
getField(line, fieldNum){
    ;positions are inclusive
    fieldStrtPos := InStr(line, ":",,,fieldNum - 1) + 1
    fieldEndPos  := InStr(line, ":",,,fieldNum)     - 1
    fieldLen := fieldEndPos - fieldStrtPos + 1
    
    Return SubStr(line, fieldStrtPos, fieldLen)
} ;end getField()

;returns line after replacing field at fieldNum with replacement
rplcField(line, fieldNum, replacement){
    ;line = EJA397:C680:J:I:KBOI:KASE:41000:BOI ROARR LYONS TWF J15 TCH J173 EKR TRUEL DBL:/v/:0000:S:43.566068:-116.243207:2871:0:0
    ;fieldNum = SQ_FIELD_NUM = 10
    preStrEndPos := InStr(line, ":",,,fieldNum - 1)
    preStr  := SubStr(line, BEGIN, preStrEndPos)
    ;preStr = EJA397:C680:J:I:KBOI:KASE:41000:BOI ROARR LYONS TWF J15 TCH J173 EKR TRUEL DBL:/v/:

    postStrStrtPos := InStr(line, ":",,,SQ_FIELD_NUM)
    postStr := SubStr(line, postStrStrtPos,)
    ;postStr = :S:43.566068:-116.243207:2871:0:0

    Return preStr replacement postStr
} ;end rplcField

rplcSq(line, sqCode){
    preStrEndPos := InStr(line, ":",,,SQ_FIELD_NUM - 1)
    preStr  := SubStr(line, BEGIN, preStrEndPos)

    postStrStrtPos := InStr(line, ":",,,SQ_FIELD_NUM)
    postStr := SubStr(line, postStrStrtPos,)

    ;write the following to file
    ;preStr + sqCode + postStr
    Return preStr sqCode postStr
} ;end rplcSq

; getNrplcRmks(line){
;     rmkStartPos := InStr(line, ":",,,)
;     SubStr(line, )
; } ;end getNrplcRmks

;write a setup script for this a/c
genSetup(rmks, sqCode){
    ;print the following
} ;end genSetup
*/

chgAHKLocButtonNames(){
    if !WinExist("AHK Locaiton?")
        return ; keep waiting
    SetTimer , 0
    WinActivate
    ControlSetText "&Abort", "C:\Program Files\AutoHotkey"
    ControlSetText "&Retry", "Select the location"
    ControlSetText "&Ignore", "Not installed"
} ;end chgAHKLocButtonNames()

/* autoFindAHK(){
    if !FileExist("C:\Program Files\AutoHotkey") || !FileExist(){

    }
} ;end autoFindAHK()

chkAHKInstallation(){
    autoFindAHK()

    SetTimer chgAHKLocButtonNames, 50
    response := MsgBox("Where do you have AHKv2 installed?", "AHK Location?", "2 Icon? 4096")
    if (response = "Abort"){ ;C:\Program Files\AutoHotkey
        installDir_ := "C:\Program Files\AutoHotkey"
    }
    else if (response = "Retry"){ ;Select the location
        response := MsgBox("
        (
            This feature is currently unavailable.
            Continuing as if AHKv2 is not installed.
        )", "Unavailable!", "6 Iconi 4096 T5")

        if (response = "Cancel"){
            MsgBox("Aborting!", "Aborting!", "0 Icon! 4096 T5")
            Exit
        }
        else if (response = "TryAgain"){
            
        }
        else if (response = "Continue"){

        }
    }
    else if (response = "Ignore"){ ;Not installed

    }
} ;end chkAHKInstallation() */

ttGenSetup(){
    ;for each line of original file
    ;gen squawk code
    ;write line to new file with generated squawk code
    ;gen setup script lines and write to script file

    ;after loop
    ;del orig file
    ;rename new file to orig file name

    ; MsgBox("here")
    ; test := FlightPlan("N691L:B06:H:I:KBOI:KBOI:0:`:/v/:0000:S:43.563432:-116.239255:2871:0:0")
    ; MsgBox('test["callsign"] : ' . test["callsign"], "Successfully created object")
    ; Exit 0

    ;if wrong # of args
    if (A_Args.Length = 0){
        MsgBox ("Incorrect # of arguments."
            . " Usage: drag a file(s) onto this script..."
            . " Terminating..."
        )
    } ;end if wrong # of args

    fileLst := []
    ; For each param (or file dropped onto a script):
    ; check if .air file and get full path
    for n, givenPath in A_Args{
        Loop Files, givenPath  ; Include files and directories.
            if (RegExMatch(A_LoopFileFullPath, ".air$",,-4) != 0)
                fileLst.Push(A_LoopFileFullPath)
    } ;end for each param

    ;for each .air file
    for n, file in fileLst{
        SplitPath file,,&fileDir,,&tmpFileName
        tmpFilePath := tmpFldr_ "\" tmpFileName ".ahk"

        fpList := []
        sqCodeSet := SquawkCodeSet()
        ;FOR EACH LINE IN CURRENT FILE
        ;  init fpList and keep track of sqCodes
        Loop Read, file{
            newFP  := FlightPlan(A_LoopReadLine)
            sqCode := newFP["sqCode"]
            sqCodeSet.Set()
            fpList.Push(newFP)
        }

        ;FOR EACH FLIGHT PLAN IN CURRENT FILE
        for fpIdx, fp in fpList{
            callsign := fp["callsign"]
            sqCode   := fp["sqCode"]
            sqCodeSet.Set(sqCode)

            rmks := fp["remarks"]
            rmks := StrReplace(rmks, "/v/", "")
            cmdLst := StrSplit(rmks, ";", " `t`n`r")
            fp["remarks"] := "/v/"

            textCommScriptPrefix  := "textComm" callsign "(){"
            textCommScriptBody    := ""
            textCommScriptPostfix := "`n}`n`n"

            scopeScriptPrefix  := "scope" callsign "(){"
            scopeScriptBody    := ""
            scopeScriptPostfix := "`n}`n`n"

            ;FOR EACH command in remarks
            for idx, cmd in cmdLst{
                if ((StrLen(cmd) == 0) OR (cmd == "/v/"))
                    continue

                cmd := StrReplace(cmd, "+", "{NumpadAdd}")
                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                ; SHOULD CHECK FOR CMD ID STRINGS AT ***BEGINNING*** OF CMD SPECIFICALLY
                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                if (InStr(cmd, "sqAssign ") || InStr(cmd, "assignSq ")){ ;assign sqCode
                    cmd := StrReplace(cmd, "sqAssign ", "{F9}" callsign " ")
                    cmd := StrReplace(cmd, "assignSq ", "{F9}" callsign " ")
                    scopeScriptBody .= '`n  SendEvent "' cmd '{Enter}"'
                    scopeScriptBody .= '`n  Sleep 100'
                    continue
                }
                else if (InStr(cmd, "{F9}" callsign " ")){ ;assign sqCode
                    scopeScriptBody .= '`n  SendInput "' cmd '{Enter}"'
                    continue
                }
                if (InStr(cmd, "ldrDir ")){ ;set leader line direction
                    cmd := StrReplace(cmd, "ldrDir ", "{F7}l")
                    cmd .= " " callsign
                    scopeScriptBody .= '`n  SendInput "' cmd '{Enter}"'
                    continue
                }
                else if (InStr(cmd, "{F7}l")){ ;set leader line direction
                    scopeScriptBody .= '`n  SendInput "' cmd '{Enter}"'
                    continue
                }
                if (InStr(cmd, "equip ")){ ;chng acType to include equip type suffix
                    fp["acType"] .= StrReplace(cmd, "equip ", "/")
                    continue
                }
                if (InStr(cmd, "genSq")) { ;generate a sqCode, make a/c squawk it, and assign that code to them
                    newSqCode := sqCodeSet.genSet(posSqRngStrt, posSqRngEnd)
                    fp["sqCode"] := newSqCode
                    cmdLst.Push("assignSq " newSqCode)
                    continue
                }
                if (InStr(cmd, "genWrongSq")) { ;generate a sqCode, make a/c squawk it, and assign that code to them
                    newSqCode := sqCodeSet.genSet(posSqRngStrt, posSqRngEnd)
                    fp["sqCode"] := newSqCode + 1
                    cmdLst.Push("assignSq " newSqCode)
                    continue
                }

                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                ; ADD WHITE LIST FOR COMMANDS
                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                textCommScriptBody .= '`n  SendEvent "' cmd '{Enter}"'
            } ;FOR EACH command in remarks

            if (textCommScriptBody != ""){
                textCommScriptPrefix  := (
                    "textComm" callsign "(){"
                    '`n  SetKeyDelay 0, 0'
                    '`n  SendEvent "' callsign '"'
                    '`n  Sleep 10'
                    '`n  SetKeyDelay 100, 100'
                    '`n  SendEvent "{NumpadAdd}"'
                    '`n  SetKeyDelay 0, 0`n'
                )

                textCommScriptPostfix := (
                    '`n`n  Sleep 100'
                    "`n}`n`n"
                )
            } ;end if textCommScriptBody not empty

            ;// Write generated script to script file
            ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            ; DO MORE EFFICIENT FILE APPENDING
            ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            FileAppend textCommScriptPrefix textCommScriptBody textCommScriptPostfix, tmpFilePath, "`n"
            FileAppend scopeScriptPrefix scopeScriptBody scopeScriptPostfix, tmpFilePath, "`n"
            ;FileOpen(tmpFldr_ "\" )
            ;MsgBox(textCommScriptPrefix textCommScriptBody textCommScriptPostfix, "Generated Script")
        } ;END FOR EACH FLIGHT PLAN IN CURRENT FILE

        /*
        ;for each line in current file
        Loop Read, file{
            newFP := FlightPlan(A_LoopReadLine)
            callsign := newFP["callsign"]
            sqCode   := newFP["sqCode"]
            sqCodeSet.Set(sqCode)

            rmks := newFP["remarks"]
            cmdLst := StrSplit(rmks, ";", " `t`n`r")
            newFP["remarks"] := "/v/"
            fpList.Push(newFP)

            textCommScriptPrefix  := "textComm" callsign "(){"
            textCommScriptBody    := ""
            textCommScriptPostfix := "`n}`n`n"

            scopeScriptPrefix  := "scope" callsign "(){"
            scopeScriptBody    := ""
            scopeScriptPostfix := "`n}`n`n"

            ;FOR EACH command in remarks
            for idx, cmd in cmdLst{
                if ((StrLen(cmd) == 0) OR (cmd == "/v/"))
                    continue

                cmd := StrReplace(cmd, "+", "{NumpadAdd}")
                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                ; SHOULD CHECK FOR CMD ID STRINGS AT ***BEGINNING*** OF CMD SPECIFICALLY
                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                if (InStr(cmd, "sqAssign") || InStr(cmd, "assignSq")){ ;assign sqCode
                    cmd := StrReplace(cmd, "sqAssign", "{F9}" callsign " ")
                    cmd := StrReplace(cmd, "assignSq", "{F9}" callsign " ")
                    scopeScriptBody .= '`n  SendEvent "' cmd '{Enter}"'
                    scopeScriptBody .= '`n  Sleep 100'
                    continue
                }
                else if (InStr(cmd, "{F9}" callsign " ")){ ;assign sqCode
                    scopeScriptBody .= '`n  SendInput "' cmd '{Enter}"'
                    continue
                }
                if (InStr(cmd, "ldrDir")){ ;set leader line direction
                    cmd := StrReplace(cmd, "ldrDir ", "{F7}l")
                    cmd .= " " callsign
                    scopeScriptBody .= '`n  SendInput "' cmd '{Enter}"'
                    continue
                }
                else if (InStr(cmd, "{F7}l")){ ;set leader line direction
                    scopeScriptBody .= '`n  SendInput "' cmd '{Enter}"'
                    continue
                }
                if (InStr(cmd, "equip")){ ;chng acType to include equip type suffix
                    newFP["acType"] .= StrReplace(cmd, "equip ", "")
                }
                if (InStr(cmd, "genSq")) { ;generate a sqCode, make a/c squawk it, and assign that code to them
                    newFP["sqCode"] := SubStr(cmd, -1, )
                }

                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                ; ADD WHITE LIST FOR COMMANDS
                ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                textCommScriptBody .= '`n  SendEvent "' cmd '{Enter}"'
            } ;FOR EACH command in remarks

            if (textCommScriptBody != ""){
                textCommScriptPrefix  := (
                    "textComm" callsign "(){"
                    '`n  SetKeyDelay 0, 0'
                    '`n  SendEvent "' callsign '"'
                    '`n  Sleep 10'
                    '`n  SetKeyDelay 100, 100'
                    '`n  SendEvent "{NumpadAdd}"'
                    '`n  SetKeyDelay 0, 0`n'
                )

                textCommScriptPostfix := (
                    '`n`n  Sleep 100'
                    "`n}`n`n"
                )
            } ;end if textCommScriptBody not empty

            ;// Write generated script to script file
            ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            ; DO MORE EFFICIENT FILE APPENDING
            ;////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            FileAppend textCommScriptPrefix textCommScriptBody textCommScriptPostfix, tmpFilePath, "`n"
            FileAppend scopeScriptPrefix scopeScriptBody scopeScriptPostfix, tmpFilePath, "`n"
            ;FileOpen(tmpFldr_ "\" )
            ;MsgBox(textCommScriptPrefix textCommScriptBody textCommScriptPostfix, "Generated Script")
        } ;end for each line in current file
        */

        mainFuncScript := 'main(){`n'
        for fp in fpList
            mainFuncScript .= '  textComm' fp["callsign"] '()`n'
        mainFuncScript .= '`n  SendInput "{Tab}"`n'
        for fp in fpList
            mainFuncScript .= '`n  scope' fp["callsign"] '()'
        mainFuncScript .= '`n`n  response := MsgBox("Run setup again?", "Completed Setup", "4096 YesNo T5")'
        mainFuncScript .= '`n  return response'
        mainFuncScript .= '`n} `;end main()`n`n'
        FileAppend mainFuncScript, tmpFilePath, "`n"

        ttSetupScript  := (
            ':O:ttSetup::{`n'
            '  Loop{`n'
            '    response := main()`n'
            '    SendEvent "{Tab}"`n'
            '  } Until (response != "yes")`n'
            '} `;end :O:ttSetup::`n`n'
        )
        FileAppend ttSetupScript, tmpFilePath, "`n"
        try{
            FileCopy tmpFilePath, fileDir "\*.*" 
        }
        catch Any as err{
            MsgBox(Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
            , type(err), err.Message, err.File, err.Line, err.What, err.Stack) "`n`nUnable to copy generated .ahk file. It can be found in " tmpFldr_
            , "Copy Error... continuing", "4096")

            ERROR_CODE += 1
        }
        ;RunWait(compilerPath " /in " fileDir "\" tmpFileName ".ahk /out " fileDir "\" tmpFileName ".exe")
        MsgBox("Here0.0.0", "Here")
        RunWait('"' compilerPath_ '" /in "' fileDir '\' tmpFileName '.ahk" /out "' fileDir '\' tmpFileName '.exe" /base "' installDir_ '\AutoHotkey64.exe"')

        ;// Update .air file config line with new remarks
        SplitPath file, &tmpFileName, &fileDir
        tmpFilePath := tmpFldr_ "\" "fixed_" tmpFileName
        for fp in fpList
            FileAppend String(fp) "`n", tmpFilePath, "`n"
        try{
            FileCopy tmpFilePath, fileDir "\*.*" 
        }
        catch Any as err{
            MsgBox(Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
            , type(err), err.Message, err.File, err.Line, err.What, err.Stack) "`n`nUnable to copy fixed .air file. It can be found in " tmpFldr_
            , "Copy Error... continuing", "4096")

            ERROR_CODE += 2
        }
    } ;end for each .air file
} ;end ttGenSetup()

;/////////////////////////////////////////////////////////////////////////////
; MAIN / AUTO-execute
;/////////////////////////////////////////////////////////////////////////////
tmpFldr_ := gen_tmpFldr()
;compilerPath := installCompiler(tmpFldr_ "\Compiler")

installDir_ := installAHK(tmpFldr_ "\AHK")
ahkPath_ := installDir_ "\AutoHotkey.exe"
compilerPath_ := installDir_ "\Compiler\Ahk2Exe.exe"

ttGenSetup()

cleanNExit(ERROR_CODE)