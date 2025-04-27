#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "wd_extra.au3"

; ie. 8674
Local $debugging_port = $CmdLine[1]
Local $page_name = ""
Local $aTimeZone = _Date_Time_GetTimeZoneInformation()
Local $iOffsetMinutes = -$aTimeZone[1]
Local $found_empty_message = False

; connect to the mutex handler of facebook-wd-scraper
$mutex_handle = _WinAPI_OpenMutex($app_name)
;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $mutex_handle = ' & $mutex_handle & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
if $mutex_handle = 0 then
	ConsoleWrite("No mutex found, exiting." & @CRLF)
	Exit
EndIf
ConsoleWrite("Mutex found." & @CRLF)

CreateSession(True, $debugging_port)
;CreateSession(False, $debugging_port)

While True

	; wait for the mutex to be available
	$mutex_event = _WinAPI_WaitForSingleObject($mutex_handle, 20000)
	;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $mutex_event = ' & $mutex_event & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
	if $mutex_event <> 0 then
		ConsoleWrite("Could not get the mutex, exiting." & @CRLF)
		ExitLoop
	EndIf
	ConsoleWrite("Got the mutex." & @CRLF)

	; find a facebook post not yet discovered and write a pending update message for that
	Global $saved_pages_arr = IniReadSectionNames(@ScriptDir & "\" & $ini_filename)
	_ArrayDelete($saved_pages_arr, 0)
	_ArrayDelete($saved_pages_arr, _ArraySearch($saved_pages_arr, "Main"))
	_ArraySort($saved_pages_arr)
	$found_empty_message = False
	for $each in $saved_pages_arr
		$when = IniRead(@ScriptDir & "\" & $ini_filename, $each, "when", "")
		if StringLen($when) = 0 Then
			$found_empty_message = True
			$page_name = $each
			IniWrite(@ScriptDir & "\" & $ini_filename, $page_name, "message", "pending update from agent (PID " & @AutoItPID & ")")
			ExitLoop
		EndIf
	Next

	; release the mutex
	$result = _WinAPI_ReleaseMutex($mutex_handle)
	ConsoleWrite("Released the mutex." & @CRLF)

	if $found_empty_message = False Then
		ConsoleWrite("No more empty messages to scrape, exiting." & @CRLF)
		ExitLoop
	EndIf

	; navigate to the facebook page and get the data
	Navigate(IniRead(@ScriptDir & "\" & $ini_filename, $page_name, "url", ""))
	$source = _WD_GetSource(WDSessionFromPromptRemoteDebuggingPort())
	$json = ExtractJson($source)
	$creation_time = _jqExec($json, '[.. | select(type == "object" and has("creation_time")) | .creation_time] | first')
	Local $date = _DateAdd('s', Number($creation_time), "1970/01/01 00:00:00")
	$date = _DateAdd("n", $iOffsetMinutes, $date)
	$time_ago = TimeAgo($date)
	$text = _jqExec($json, '[.. | select(type == "object" and has("text")) | .text] | first')

	; wait for the mutex to be available
	$mutex_event = _WinAPI_WaitForSingleObject($mutex_handle, 20000)
	;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $mutex_event = ' & $mutex_event & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
	if $mutex_event <> 0 then
		ConsoleWrite("Could not get the mutex, exiting." & @CRLF)
		ExitLoop
	EndIf
	ConsoleWrite("Got the mutex." & @CRLF)

	; update the ini file
	if StringLen($creation_time) > 0 Then
		IniWrite(@ScriptDir & "\" & $ini_filename, $page_name, "when", $time_ago)
	EndIf
	if StringLen($text) > 0 Then
		$text = StringReplace(StringReplace($text, @LF, " "), @CRLF, " ")
		Local $sUTF8Text = StringToBinary($text, 4) ; Convert to UTF-8
		IniWrite(@ScriptDir & "\" & $ini_filename, $page_name, "message", $sUTF8Text)
	EndIf

	; release the mutex
	$result = _WinAPI_ReleaseMutex($mutex_handle)
	ConsoleWrite("Released the mutex." & @CRLF)
WEnd

ConsoleWrite("Detaching session..." & @CRLF)
DetachSession()


Func ExtractJson($sContent)
    ;Local $sContent = FileRead($sFile) ; Read entire file
    ;If @error Then Return SetError(1, 0, "")

    ; Find first occurrence of "post_id"
    Local $iPostIDPos = StringInStr($sContent, '"post_id"', 1)
    If $iPostIDPos = 0 Then Return SetError(2, 0, "")

    ; Search backward for @LF
    Local $iLFPos = StringInStr($sContent, @LF, 0, -1, $iPostIDPos)
    If $iLFPos = 0 Then Return SetError(3, 0, "")

    ; Search forward for '{"require":'
    Local $iRequirePos = StringInStr($sContent, '{"require":', 1, 1, $iLFPos)
    If $iRequirePos = 0 Then Return SetError(4, 0, "")

    ; Extract text from '{"require":' to the end of the line
    Local $iEndOfLinePos = StringInStr($sContent, @LF, 1, 1, $iRequirePos)
    If $iEndOfLinePos = 0 Then $iEndOfLinePos = StringLen($sContent) ; If no @LF, take full remaining text

    Return StringReplace(StringMid($sContent, $iRequirePos, $iEndOfLinePos - $iRequirePos), "</script>", "")
EndFunc

Func TimeAgo($sDateTime)
    Local $sNow = _NowCalc() ; Get current datetime
    Local $iMinutes = _DateDiff("n", $sDateTime, $sNow)
    Local $iHours = _DateDiff("h", $sDateTime, $sNow)
    Local $iDays = _DateDiff("D", $sDateTime, $sNow)
    Local $iWeeks = _DateDiff("w", $sDateTime, $sNow)
    Local $iMonths = _DateDiff("M", $sDateTime, $sNow)
    Local $iYears = _DateDiff("Y", $sDateTime, $sNow)

	Local $mins = "mins"
	Local $hrs = "hrs"
	Local $days = "days"
	Local $wks = "wks"
	Local $mths = "mths"
	Local $yrs = "yrs"

    If $iMinutes < 60 Then
		if $iMinutes = 1 Then $mins = "min"
        Return $iMinutes & " " & $mins
    ElseIf $iHours < 24 Then
		if $iHours = 1 Then $hrs = "hr"
        Return $iHours & " " & $hrs
    ElseIf $iDays < 7 Then
		if $iDays = 1 Then $days = "day"
        Return $iDays & " " & $days
    ElseIf $iWeeks < 4 Then
		if $iWeeks = 1 Then $wks = "wk"
        Return $iWeeks & " " & $wks
    ElseIf $iMonths < 12 Then
		if $iMonths = 1 Then $mths = "mth"
        Return $iMonths & " " & $mths
    Else
		if $iYears = 1 Then $yrs = "yr"
        Return $iYears & " " & $yrs
    EndIf
EndFunc
