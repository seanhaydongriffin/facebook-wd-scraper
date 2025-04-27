#include-once
#include <StringConstants.au3>
#include <Date.au3>
#include <Array.au3>
#include <File.au3>
#include <WinAPIProc.au3>

; #INDEX# =======================================================================================================================
; Title .........: jq UDF
; AutoIt Version : 3.3.14.5+
; Language ......: English
; Description ...: Powerful and flexible JSON processing UDF based on jq
; Author ........: TheXman
; Resources .....: jq Home Page:         https://stedolan.github.io/jq/
;                  jq Download:          https://stedolan.github.io/jq/download/
;                  jq Manual:            https://stedolan.github.io/jq/manual/
;                  jq Wiki:              https://github.com/stedolan/jq/wiki  (jq FAQ, jq Cookbook, jq Advanced Topics)
;                  jq Examples:          https://shapeshed.com/jq-json/
;                  jq Online Playground: https://jqplay.org/
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _jqInit($sExePath = Default)
; _jqPrettyPrintJson($sJson, $iIndent = Default, $bUseTabs = False)
; _jqPrettyPrintJsonFile($sJsonFile, $iIndent = Default, $bUseTabs = False)
; _jqCompactPrintJson($sJson)
; _jqCompactPrintJsonFile($sJsonFile)
; _jqDump($sJson, $iNotationType = $_jq_NOTATION_TYPE_DOT)
; _jqDumpFile($sJsonFile, $iNotationType = $_jq_NOTATION_TYPE_DOT)
; _jqUdfVersion()
; _jqVersion()
; _jqExec($sJson, $sFilter, $sOptions = Default, $sWorkingDir = Default)
; _jqExecFile($sJsonFile, $sFilter, $sOptions = Default, $sWorkingDir = Default)
; _jqEnableDebugLogging()
; _jqDisableDebugLogging()
; ===============================================================================================================================

; #INTERNAL_USE_ONLY#============================================================================================================
; __jqConvertDumpToDotNotation($sCmdOutput)
; __jqBracketToDotNotation($sNotation)
; __jqWriteLogLine([$sMsg = ""])
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Const $__JQ_UDF_VERSION = "1.7.4", _
      $__JQ_DEBUG_FILE  = @ScriptDir & "\jq_debug_log.txt"
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global $__jq_gbDebugging     = False, _
       $__jq_gsJqExeFilePath = "", _
	   $__jq_gs32or64        = (@OSArch = "x64" ? "64" : "32")
; ===============================================================================================================================

; #ENUMS# ===================================================================================================================
Enum $_jq_NOTATION_TYPE_DOT, _
     $_jq_NOTATION_TYPE_BRACKET
; ===============================================================================================================================


; #FUNCTION# ====================================================================================================================
; Name...........: _jqInit
; Description ...: Initialize jq processing environment
; Syntax.........: _jqInit([ExePath = Default])
; Parameters ....: ExePath - [Optional] Path to jq executable. Default is "", which means to search for exe.
;                            e.g.: "C:\Utils\jq\jq-win64.exe"
; Return values .: Success - A string containing the path of the jq executable
;                  Failure - Returns "" and sets @error:
;                  |1  - Unable to find executable
;                  |2  - Supplied exe path does not exist
;                  |3  - Error occurred searching for executable
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......: If no path is passed, or the Default keyword is passed, then the function will search the current directory
;                  and then the directories in the PATH environment variable in order to find the executable.  The function will
;                  look for the 32-bit file on 32-bit OSes and the 64-bit file on 64-bit OSes.  If a jq file path is passed, it
;                  will be used.
; ===============================================================================================================================
Func _jqInit($sExePath = Default)

	Local $aResult[0]

	Local $iPid      = 0, _
	      $iExitCode = 0

	Local $sCmdOutput = ""


	;If $__jq_gsJqExeFilePath already set, then return the value
	If $__jq_gsJqExeFilePath <> "" Then Return $__jq_gsJqExeFilePath

	;Initialize Default parameters
	If $sExePath = Default Then $sExePath = ""

	;If a log file exists, delete it
	If FileExists($__JQ_DEBUG_FILE) Then FileDelete($__JQ_DEBUG_FILE)

	;Set global exe path
	Select
		Case StringStripWS($sExePath, $STR_STRIPLEADING + $STR_STRIPTRAILING ) <> "" ;Exe path was provided
			If $__jq_gbDebugging Then __jqWriteLogLine(StringFormat('Exe path supplied to _jqInit = "%s"', $sExePath))

			;If exe path does not exist
			If Not FileExists($sExePath) Then Return SetError(2, 0, "")

			;Set global var and return
			$__jq_gsJqExeFilePath = $sExePath
		Case FileExists(StringFormat(@ScriptDir & "\jq-win%s.exe", $__jq_gs32or64))  ;Exe is in @ScriptDir
			If $__jq_gbDebugging Then __jqWriteLogLine("Found jq executable in script directory")

			;Set global var
			$__jq_gsJqExeFilePath = StringFormat(@ScriptDir & "\jq-win%s.exe", $__jq_gs32or64)
		Case Else                                                                    ;Search for exe
			If $__jq_gbDebugging Then __jqWriteLogLine("Searching for jq exe...")

			;Search for exe in PATH
			$iPid = Run(StringFormat('WHERE "$PATH:jq-win%s.exe"', $__jq_gs32or64), @ScriptDir, @SW_HIDE, $STDERR_MERGED)
			If @error Then Return SetError(3, 0, "")

			;Wait for command to close and get exit code and output
			ProcessWaitClose($iPid, 10)
			$iExitCode  = @extended
			$sCmdOutput = StdoutRead($iPid)

			;If exe not found
			If $iExitCode Then
				If $__jq_gbDebugging Then __jqWriteLogLine("jq executable not found")
				Return SetError(1, 0, "")
			EndIf

			;Parse first line from output
			$aResult = StringRegExp($sCmdOutput, ".*", $STR_REGEXPARRAYMATCH)
			If Not IsArray($aResult) Then Return SetError(1, 0, "")

			;Set global var
			If $__jq_gbDebugging Then __jqWriteLogLine(StringFormat('jq executable found = "%s"', $aResult[0]))
			$__jq_gsJqExeFilePath = $aResult[0]
	EndSelect

	Return $__jq_gsJqExeFilePath
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqEnableDebugLogging
; Description ...: Enable debug logging
; Syntax.........: __jqEnableDebugLogging()
; Author ........: TheXman
; Remarks .......: The debug is created in the script directory
; ===============================================================================================================================
Func _jqEnableDebugLogging()
	$__jq_gbDebugging = True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqDisableDebugLogging
; Description ...: Disable debug logging
; Syntax.........: __jqDisableDebugLogging()
; Author ........: TheXman
; Remarks .......: The debug is created in the script directory
; ===============================================================================================================================
Func _jqDisableDebugLogging()
	$__jq_gbDebugging = False
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqPrettyPrintJson
; Description ...: Pretty prints the supplied JSON string
; Syntax.........: _jqPrettyPrintJson(Json[, Indent = Default[, UseTabs = False]])
; Parameters ....: Json    - String; JSON to be formatted
;                  Indent  - [Optional] Integer; Number of spaces to indent (Default = 2)
;                  UseTabs - [Optional] Boolean; Use tabs for indention instead of spaces.  Overrides $iIndent. See remarks.
; Return values .: Success - String; Formatted JSON
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......: If $bUseTabs is True, then $iIndent is ignored.  In other words, tab indention overrides space indention.
; ===============================================================================================================================
Func _jqPrettyPrintJson($sJson, $iIndent = Default, $bUseTabs = False)

	Local $sCmdOutput  = "",  $sOptions = ""


	;Set defaults
	If $iIndent = Default Then $iIndent = 2

	;If $iIndent is not an integer, then default it to 2
	If Not IsInt($iIndent) Then $iIndent = 2

	;If no json was supplied
	If StringStripWS($sJson, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then Return SetError(2, 0, "ERROR: No JSON data provided")

	;Set options
	If $bUseTabs Then
		$sOptions = "--tab"
	Else
		$sOptions = "--indent " & $iIndent
	EndIf

	;Execute jq
	$sCmdOutput  = _jqExec($sJson, ".", $sOptions)
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;All is good
	Return $sCmdOutput
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqPrettyPrintJsonFile
; Description ...: Pretty prints the supplied JSON file
; Syntax.........: _jqPrettyPrintJsonFile(JsonFile[, Indent = Default[, UseTabs = False]])
; Parameters ....: JsonFile - String; Path of JSON file to be formatted
;                  Indent   - [Optional] Integer; Number of spaces to indent (Default = 2)
;                  UseTabs  - [Optional] Boolean; Use tabs for indention instead of spaces.  Overrides $iIndent. See remarks.
; Return values .: Success - String; Formatted JSON
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......: If $bUseTabs is True, then $iIndent is ignored.  In other words, tab indention overrides space indention.
; ===============================================================================================================================
Func _jqPrettyPrintJsonFile($sJsonFile, $iIndent = Default, $bUseTabs = False)

	Local $sCmdOutput  = "",  $sOptions = ""


	;Set defaults
	If $iIndent = Default Then $iIndent = 2

	;If $iIndent is not an integer, then default it to 2
	If Not IsInt($iIndent) Then $iIndent = 2

	;If no json was supplied
	If StringStripWS($sJsonFile, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then Return SetError(2, 0, "ERROR: No JSON file provided")

	;Set options
	If $bUseTabs Then
		$sOptions = "--tab"
	Else
		$sOptions = "--indent " & $iIndent
	EndIf

	;Execute jq
	$sCmdOutput  = _jqExecFile($sJsonFile, ".", $sOptions)
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;All is good
	Return $sCmdOutput
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqCompactPrintJson
; Description ...: Compacts and prints the supplied JSON
; Syntax.........: _jqCompactPrintJson(Json)
; Parameters ....: Json    - String; JSON to be formatted
; Return values .: Success - String; Formatted JSON
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......:
; ===============================================================================================================================
Func _jqCompactPrintJson($sJson)

	Local $sCmdOutput = ""


	;If no json was supplied
	If StringStripWS($sJson, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then Return SetError(2, 0, "ERROR: No JSON data provided")

	;Execute jq
	$sCmdOutput  = _jqExec($sJson, ".", "-c")
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;All is good
	Return $sCmdOutput

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqCompactPrintJsonFile
; Description ...: Compacts and prints the supplied JSON file
; Syntax.........: _jqCompactPrintJsonFile(JsonFile)
; Parameters ....: JsonFile - String; Path of JSON file to be formatted
; Return values .: Success - String; Formatted JSON
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......:
; ===============================================================================================================================
Func _jqCompactPrintJsonFile($sJsonFile)

	Local $sCmdOutput = ""


	;If no json was supplied
	If StringStripWS($sJsonFile, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then Return SetError(2, 0, "ERROR: No JSON file provided")

	;Execute jq
	$sCmdOutput  = _jqExecFile($sJsonFile, ".", "-c")
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;All is good
	Return $sCmdOutput

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqDump
; Description ...: Dumps all of the scalar paths and their values
; Syntax.........: _jqDump($sJson, $iNotationType = $_jq_NOTATION_TYPE_DOT)
; Parameters ....: Json          - String; JSON to be formatted
;                  NotationType  - [Optional] Enum; $_jq_NOTATION_TYPE_DOT (0) or $_jq_NOTATION_TYPE_BRACKET (1)
; Return values .: Success - String; Dump of all the scalar paths and their values
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
;                  |3  - Invalid notation type
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......:
; ===============================================================================================================================
Func _jqDump($sJson, $iNotationType = $_jq_NOTATION_TYPE_DOT)

	Local $sCmdOutput = ''


	;If no json was supplied
	If StringStripWS($sJson, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then Return SetError(2, 0, "ERROR: No JSON data provided")

	;If invalid notation type
	If Not ($iNotationType = $_jq_NOTATION_TYPE_DOT Or $iNotationType = $_jq_NOTATION_TYPE_Bracket) Then  Return SetError(3, 0, "ERROR: Unrecognized notation type.")

	;Execute jq to dump all scalar paths and their values (paths are returned in bracket-notation)
	$sCmdOutput  = _
		_jqExec( _
			$sJson, _
			'path(.. | select(type != "array" and type != "object")) as $p | ($p | tostring) + " = " + (getpath($p) | tostring)' _
		)
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;If dot-notation requested, then convert output
	If $sCmdOutput <> "" And $iNotationType = $_jq_NOTATION_TYPE_DOT Then $sCmdOutput = __jqConvertDumpToDotNotation($sCmdOutput)

	;All is good
	Return $sCmdOutput

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqDumpFile
; Description ...: Dumps all of the scalar paths and their values from a JSON file
; Syntax.........: _jqDump(JsonFile)
; Parameters ....: JsonFile      - String; Path of file containing JSON
;                  NotationType  - [Optional] Enum; $_jq_NOTATION_TYPE_DOT (0) or $_jq_NOTATION_TYPE_BRACKET (1)
; Return values .: Success - String; Dump of all the scalar paths and their values
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
;                  |3  - Invalid notation type
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......:
; ===============================================================================================================================
Func _jqDumpFile($sJsonFile, $iNotationType = $_jq_NOTATION_TYPE_DOT)

	Local $sCmdOutput = ""


	;If no json was supplied
	If StringStripWS($sJsonFile, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then Return SetError(2, 0, "ERROR: No JSON file provided")

	;If invalid notation type
	If Not ($iNotationType = $_jq_NOTATION_TYPE_DOT Or $iNotationType = $_jq_NOTATION_TYPE_Bracket) Then  Return SetError(3, 0, "ERROR: Unrecognized notation type.")

	;Execute jq
	$sCmdOutput  = _
		_jqExecFile( _
			$sJsonFile, _
			'path(.. | select(type != "array" and type != "object")) as $p | ($p | tostring) + " = " + (getpath($p) | tostring)' _
		)
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;If dot-notation requested, then convert output
	If $sCmdOutput <> "" And $iNotationType = $_jq_NOTATION_TYPE_DOT Then $sCmdOutput = __jqConvertDumpToDotNotation($sCmdOutput)

	;All is good
	Return $sCmdOutput

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqUdfVersion
; Description ...: Output jq UDF version
; Syntax.........: _jqUdfVersion()
; Parameters ....: None
; Return values .: Success - String; jq UDF version number
;                  Failure - String; Blank ("")
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......:
; ===============================================================================================================================
Func _jqUdfVersion()
	Return $__JQ_UDF_VERSION
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqVersion
; Description ...: Output jq version
; Syntax.........: _jqVersion()
; Parameters ....: None
; Return values .: Success - String; jq version number
;                  Failure - Returns error message and sets @error:
;                  |1  - Bad return code from jq. @extended = jq return code
;                  |2  - No JSON data provided
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......:
; ===============================================================================================================================
Func _jqVersion()

	Local $sCmdOutput = ""


	;Execute jq
	$sCmdOutput  = _jqExec("", "", "--version")
	If @error Then Return SetError(1, @extended, $sCmdOutput)

	;All is good
	Return $sCmdOutput

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqExec
; Description ...: Executes jq using supplied parameters
; Syntax.........: _jqExec(Json, Filter[, Options = "-r"[, WorkingDir = Default]])
; Parameters ....: Json       - String; JSON string to process
;                  Filter     - String: jq filter used to process JSON
;                  Options    - [Optional] String; jq command options  (Default = "-r" for raw output)
;                  WorkingDir - [Optional] String; Working directory in which to execute command  (Default = @WorkingDir)
; Return values .: Success - String containing the jq command output
;                  Failure - String containing the jq command output, @error set to non-zero, and @extended set to jq return code
;                  |1  - Unable to execute jq
;                  |2  - Bad return code from jq. @extended set to jq return code
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......: This function saves the supplied JSON in a temp file and then calls the _jqExecFile with the rest of the
;                  parameters.
; ===============================================================================================================================
Func _jqExec($sJson, $sFilter, $sOptions = Default, $sWorkingDir = Default)

	Local $sCmdOutput      = "", _
		  $sTempJsonFile   = _TempFile(@TempDir)

	Local $iError      = 0, _
		  $iExtended   = 0


	;Set defaults
	If $sOptions    = Default Then $sOptions    = "-r"
	If $sWorkingDir = Default Then $sWorkingDir = @WorkingDir

	;Write JSON to temp file
	FileWrite($sTempJsonFile, $sJson)

	;Call _jqExecFile with temp JSON file and the rest of the parameters
	$sCmdOutput = _jqExecFile($sTempJsonFile, $sFilter, $sOptions, $sWorkingDir)
	If @error Then
		;Save values
		$iError    = @error
		$iExtended = @extended

		;Delete temp file
		FileDelete($sTempJsonFile)

		;Return values from _jqExecFile()
		Return SetError($iError, $iExtended, $sCmdOutput)
	EndIf

	;Delete temp files
	FileDelete($sTempJsonFile)

	;All is good
	Return $sCmdOutput

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _jqExecFile
; Description ...: Executes jq using supplied parameters
; Syntax.........: _jqExecFile(JsonFile, Filter[, Options = "-r"[, WorkingDir = Default]])
; Parameters ....: JsonFile   - String; Path to file containing the JSON to be process
;                  Filter     - String; jq filter used to process JSON
;                  Options    - [Optional] String: jq command options  (Default = "-r" for raw output)
;                  WorkingDir - [Optional] String: Working directory in which to execute command  (Default = @WorkingDir)
; Return values .: Success - String containing the jq command output
;                  Failure - String containing the jq command output, @error set to non-zero, and @extended set to jq return code
;                  |1  - Unable to execute jq
;                  |2  - Bad return code from jq. @extended set to jq return code
;                  |3  - JSON file does not exist
; Author ........: TheXman
; Modified ......: N/A
; Remarks .......: See jq manual for more information regarding filters and options.
;                  jq Manual: https://stedolan.github.io/jq/manual/
; ===============================================================================================================================
Func _jqExecFile($sJsonFile, $sFilter, $sOptions = Default, $sWorkingDir = Default)
	;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $sFilter = ' & $sFilter & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
	;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $sJsonFile = ' & $sJsonFile & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

	Local $sCmdOutput      = "", _
		  $sCmdLine        = "", _
		  $sTempFilterFile = _TempFile(@TempDir), _
		  $sTempOutputFile = _TempFile(@TempDir)

	Local $iReturnCode = 0


	;Ensure jq exe path is set
	_jqInit()
	If @error Then Return SetError(1, 0, "ERROR: JQ exe file not found.  Use _jqInit() to set the exe file path.")

	;Set parameter defaults
	If $sOptions    = Default Then $sOptions    = "-r"
	If $sWorkingDir = Default Then $sWorkingDir = @WorkingDir

	;Verify file existence
	If Not FileExists($sJsonFile) Then Return SetError(3, 0, "ERROR: JSON file does not exist")

	;Write filter to temp file
	FileWrite($sTempFilterFile, $sFilter)

	;Build command line (exe [options] -f "filter_file" "json_file" > "output_file" 2>&1)
	$sCmdLine = StringFormat('"%s"', $__jq_gsJqExeFilePath)
	If $sOptions <> "" Then $sCmdLine &= StringFormat(' %s', $sOptions)
	If Not StringRegExp($sOptions, "(?:-f|--from-file)\b") Then $sCmdLine &= StringFormat(' -f "%s"', $sTempFilterFile)
	$sCmdLine &= StringFormat(' "%s"'       , $sJsonFile)
	$sCmdLine &= StringFormat(' > "%s" 2>&1', $sTempOutputFile)

	If $__jq_gbDebugging Then __jqWriteLogLine("jq Command: " & $sCmdLine)

	;Execute jq
	$iReturnCode = RunWait(@ComSpec & " /c " & StringFormat('"%s"', $sCmdLine), $sWorkingDir, @SW_HIDE)
	;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : StringFormat(''"%s"'', $sCmdLine) = ' & StringFormat('"%s"', $sCmdLine) & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
	;Exit
	If @error Then
		FileDelete($sTempFilterFile)
		FileDelete($sTempOutputFile)
		Return SetError(1, 0, "ERROR: Unable to execute jq")
	EndIf
	If $__jq_gbDebugging Then __jqWriteLogLine("jq Command Return Code: " & $iReturnCode)

	;Get output from file and remove trailing CRLF from output
	$sCmdOutput = FileRead($sTempOutputFile)
	;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $sCmdOutput = ' & $sCmdOutput & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

	$sCmdOutput = StringRegExpReplace($sCmdOutput, "(?s)\r?\n$", "")

	;Delete temp files
	FileDelete($sTempFilterFile)
	FileDelete($sTempOutputFile)

	;If bad return code
	If $iReturnCode <> 0 Then
		If $__jq_gbDebugging Then __jqWriteLogLine("jq Command Output     : " & $sCmdOutput)
		Return SetError(2, $iReturnCode, $sCmdOutput)
	EndIf

	;All is good
	Return $sCmdOutput

EndFunc


;=========================  INTERNAL FUNCTIONS  ========================


; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __jqConvertDumpToDotNotation
; Description ...: Convert a bracket-notation string to a dot-notation string
; Syntax.........: __jqConvertDumpToDotNotation($sCmdOutput)
; Parameters ....: CmdOutput  - String; Bracket-notation output from jqDump
; Return values .: Success - Converted string
;                  Failure - Empty string, @error set to non-zero
;                  |1  - Passed string is not a valid bracket-notation string
; Author ........: TheXman
; Remarks .......:
; ===============================================================================================================================
Func __jqConvertDumpToDotNotation($sCmdOutput)
	Local $sDotNotation = ""
	Local $aDumpLines[0][2]

	;Split lines into an array
	_ArrayAdd($aDumpLines, $sCmdOutput, 0, " = ")
	If @error Then Return SetError(1, 0, "ERROR: Unable to output convert to dot-notation.")

	;Spin thru array converting paths to dot-notation
	For $i = 0 To UBound($aDumpLines) - 1
		$aDumpLines[$i][0] = __jqBracketToDotNotation($aDumpLines[$i][0])
	Next

	;Convert array back to string
	$sDotNotation = _ArrayToString($aDumpLines, " = ")

	Return $sDotNotation
EndFunc

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __jqBracketToDotNotation($sNotation)
; Description ...: Convert a bracket-notation string to a dot-notation string
; Syntax.........: __jqWriteLogLine([$sMsg = ""])
; Parameters ....: BracketNotation  - String; Bracket-notation string to convert
; Return values .: Success - Converted string
;                  Failure - Empty string, @error set to non-zero
;                  |1  - Passed string is not a valid bracket-notation string
; Author ........: TheXman
; Remarks .......: Bracket-notation example: ["a", "b", 0, "c"] will be converted to .a.b[0].c
; ===============================================================================================================================
Func __jqBracketToDotNotation($sBracketNotation)
	Local $sDotNotation = ""
	Local $aResult, $aNotations

	;Make sure the passed string is a valid bracket-notation string
	$aResult = StringRegExp($sBracketNotation, "^\[(.+)]$", $STR_REGEXPARRAYMATCH)
	If @error Then Return SetError(1, 0, "")

	;Split notations into an array
	$aNotations = StringSplit($aResult[0], ",")

	;For each notation
	For $i = 1 To $aNotations[0]
		;If notation is a string
		If StringLeft($aNotations[$i], 1) = '"' Then
			;If there are no embedded spaces, then remove beginning and ending quotes
			If Not StringRegExp($aNotations[$i], " ") Then $aNotations[$i] = StringRegExpReplace($aNotations[$i], '^"|"$', "")

			;Append dot-notation
			$sDotNotation &= "." & $aNotations[$i]
		Else ;it's an array index (number)
			;Append index specifier
			$sDotNotation &= "[" & $aNotations[$i] & "]"
		EndIf
	Next

	Return $sDotNotation
EndFunc

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __jqWriteLogLine
; Description ...: Write
; Syntax.........: __jqWriteLogLine([$sMsg = ""])
; Parameters ....: Msg  - [Optional]; String; Log message
; Author ........: TheXman
; Remarks .......:
; ===============================================================================================================================
Func __jqWriteLogLine($sMsg = "")
	FileWriteLine( _
		$__JQ_DEBUG_FILE, _
		StringFormat("%s\t%s", StringReplace(_NowCalc(), "/", "-"), $sMsg) _
	)
EndFunc
