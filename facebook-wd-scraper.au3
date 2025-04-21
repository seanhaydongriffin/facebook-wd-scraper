#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
;#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <GuiStatusBar.au3>
#include <GUIButton.au3>
;#include <ComboConstants.au3>
;#include <GuiComboBox.au3>
#Include <GDIPlus.au3>
#include <GuiListView.au3>
#include <Array.au3>
#include "wd_extra.au3"



Global $app_name = "facebook-wd-scraper"
Global $ini_filename = $app_name & ".ini"

Global $status_bar_elapsed_timer = -1
Local $aTimeZone = _Date_Time_GetTimeZoneInformation()
Local $iOffsetMinutes = -$aTimeZone[1]


Global $hGUI = GUICreate($app_name, 1024, 600, -1, -1, -1, $WS_EX_TOPMOST)

Global $past_week_checkbox = GUICtrlCreateCheckbox("Past Week", 20, 40, 80, 20)
Global $free_checkbox = GUICtrlCreateCheckbox("Free", 110, 40, 80, 20)
Global $half_checkbox = GUICtrlCreateCheckbox("Half", 200, 40, 80, 20)

Global $visible_listview = _GUICtrlListView_Create($hGUI, "", 20, 70, 990, 460)
_GUICtrlListView_SetExtendedListViewStyle($visible_listview, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT, $LVS_EX_SUBITEMIMAGES))
_GUICtrlListView_InsertColumn($visible_listview, 0, "Name", 200)
_GUICtrlListView_InsertColumn($visible_listview, 1, "Url", 0)
_GUICtrlListView_InsertColumn($visible_listview, 2, "When", 100)
_GUICtrlListView_InsertColumn($visible_listview, 3, "Message", 2000)

Global $hidden_listview = _GUICtrlListView_Create($hGUI, "", 20, 70, 990, 460)
WinSetState($hidden_listview, "", @SW_HIDE)
_GUICtrlListView_InsertColumn($hidden_listview, 0, "Name", 200)
_GUICtrlListView_InsertColumn($hidden_listview, 1, "Url", 0)
_GUICtrlListView_InsertColumn($hidden_listview, 2, "When", 100)
_GUICtrlListView_InsertColumn($hidden_listview, 3, "Message", 800)

Global $refresh_button = GUICtrlCreateButton("Refresh", 20, 550, 80, 20)
Global $visit_button = GUICtrlCreateButton("Visit", 110, 550, 80, 20)
Global $refresh_pages_no_posts_checkbox = GUICtrlCreateCheckbox("Refresh pages with no posts", 200, 550, 160, 20)

$hStatus = _GUICtrlStatusBar_Create($hGUI)
Local $aParts[4] = [100, 590, 640]
_GUICtrlStatusBar_SetParts($hStatus, $aParts)
_GUICtrlStatusBar_SetText($hStatus, "", 0)
_GUICtrlStatusBar_SetText($hStatus, "", 1)
_GUICtrlStatusBar_SetText($hStatus, "", 2)


RefreshListviews()



GUISetState(@SW_SHOW, $hGUI)


Local $iMsg = 0
While 1
	$iMsg = GUIGetMsg(1)
	Switch $iMsg[0]

		Case $past_week_checkbox, $free_checkbox, $half_checkbox
			_GUICtrlListView_BeginUpdate($visible_listview)
			_GUICtrlListView_DeleteAllItems($visible_listview)

			If GUICtrlRead($past_week_checkbox) = $GUI_CHECKED or _
				GUICtrlRead($free_checkbox) = $GUI_CHECKED Or _
				GUICtrlRead($half_checkbox) = $GUI_CHECKED Then

				for $i = 0 to _GUICtrlListView_GetItemCount($hidden_listview) - 1
					$item_arr = _GUICtrlListView_GetItemTextArray($hidden_listview, $i)
					$index = _GUICtrlListView_AddItem($visible_listview, $item_arr[1])
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[2], 1)
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[3], 2)
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[4], 3)
				Next

				For $i = _GUICtrlListView_GetItemCount($visible_listview) - 1 To 0 Step -1
					$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview, $i)
					;if GUICtrlRead($past_week_checkbox) = $GUI_CHECKED and StringRegExp($item_arr[3], "\d+[dh]") = False Then
					if GUICtrlRead($past_week_checkbox) = $GUI_CHECKED and (StringInStr($item_arr[3], "wk") > 0 or StringInStr($item_arr[3], "mth") > 0 Or StringInStr($item_arr[3], "yr") > 0) Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
					if GUICtrlRead($free_checkbox) = $GUI_CHECKED and StringInStr($item_arr[4], "free") = 0 Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
					if GUICtrlRead($half_checkbox) = $GUI_CHECKED and StringInStr($item_arr[4], "half") = 0 Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
				Next

			EndIf

			If GUICtrlRead($past_week_checkbox) = $GUI_UNCHECKED And _
				GUICtrlRead($free_checkbox) = $GUI_UNCHECKED And _
				GUICtrlRead($half_checkbox) = $GUI_UNCHECKED Then
				for $i = 0 to _GUICtrlListView_GetItemCount($hidden_listview) - 1
					$item_arr = _GUICtrlListView_GetItemTextArray($hidden_listview, $i)
					$index = _GUICtrlListView_AddItem($visible_listview, $item_arr[1])
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[2], 1)
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[3], 2)
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[4], 3)
				Next
			EndIf

			_GUICtrlListView_EndUpdate($visible_listview)

		Case $refresh_button

			GUICtrlSetState($past_week_checkbox, $GUI_UNCHECKED)
			GUICtrlSetState($free_checkbox, $GUI_UNCHECKED)
			RefreshListviews()

			if GUICtrlRead($refresh_pages_no_posts_checkbox) = $GUI_UNCHECKED Then
				_GUICtrlListView_BeginUpdate($visible_listview)
				for $i = 0 to _GUICtrlListView_GetItemCount($visible_listview) - 1
					_GUICtrlListView_SetItemText($visible_listview, $i, "", 2)
					_GUICtrlListView_SetItemText($visible_listview, $i, "", 3)
				Next
				_GUICtrlListView_EndUpdate($visible_listview)
			EndIf

			$status_bar_elapsed_timer = TimerInit()
			UpdateStatusBarAndElapsedTime("creating session ...")
			CreateSession(True, 8674)
			UpdateStatusBarAndElapsedTime("creating session ... done")

			$max_pages = _GUICtrlListView_GetItemCount($hidden_listview)
			;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $max_pages = ' & $max_pages & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

			for $i = 0 to $max_pages - 1

				UpdateStatusBarAndElapsedTime("FB page " & ($i + 1) & " of " & $max_pages, 0)

				$item_arr = _GUICtrlListView_GetItemTextArray($hidden_listview, $i)

				if GUICtrlRead($refresh_pages_no_posts_checkbox) = $GUI_UNCHECKED Or (GUICtrlRead($refresh_pages_no_posts_checkbox) = $GUI_CHECKED And StringLen($item_arr[3]) = 0) Then

					ShowDebug(0, $item_arr[1])

					UpdateStatusBarAndElapsedTime("navigating to page " & $item_arr[2] & " ...")
					Navigate($item_arr[2])
					UpdateStatusBarAndElapsedTime("navigating to page " & $item_arr[2] & " ... done")

					UpdateStatusBarAndElapsedTime("finding the post text ...")

					;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $iOffsetMinutes = ' & $iOffsetMinutes & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

					$source = _WD_GetSource(WDSessionFromPromptRemoteDebuggingPort())
					$json = ExtractJson($source)
;					ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $json = ' & $json & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

					$creation_time = _jqExec($json, '[.. | select(type == "object" and has("creation_time")) | .creation_time] | first')
					Local $date = _DateAdd('s', Number($creation_time), "1970/01/01 00:00:00")
					$date = _DateAdd("n", $iOffsetMinutes, $date)
					$time_ago = TimeAgo($date)

					if StringLen($creation_time) > 0 Then
						_GUICtrlListView_SetItemText($hidden_listview, $i, $time_ago, 2)
						_GUICtrlListView_SetItemText($visible_listview, $i, $time_ago, 2)
						IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "when", $time_ago)
					EndIf

					$text = _jqExec($json, '[.. | select(type == "object" and has("text")) | .text] | first')
					;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $text = ' & $text & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

					if StringLen($text) > 0 Then
						$text = StringReplace(StringReplace($text, @LF, " "), @CRLF, " ")
						_GUICtrlListView_SetItemText($hidden_listview, $i, $text, 3)
						_GUICtrlListView_SetItemText($visible_listview, $i, $text, 3)

						Local $sUTF8Text = StringToBinary($text, 4) ; Convert to UTF-8
						IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "message", $sUTF8Text)

;						IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "message", $text)


					EndIf

					UpdateStatusBarAndElapsedTime("finding the post text ... done")
				EndIf
			Next

			UpdateStatusBarAndElapsedTime("", 0)

			UpdateStatusBarAndElapsedTime("detaching session ...")
			DetachSession()
			UpdateStatusBarAndElapsedTime("detaching session ... done")
			$status_bar_elapsed_timer = -1

		Case $visit_button

			$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview)
			CreateSession(False, 8674)
			Navigate($item_arr[2])


		Case $GUI_EVENT_CLOSE
			;If $iMsg[1] = $element_details_gui Then GUISetState(@SW_HIDE, $element_details_gui)
			If $iMsg[1] = $hGUI Then ExitLoop
	EndSwitch
WEnd

GUIDelete($hGUI)



Func RefreshListviews()


	Global $saved_pages_arr = IniReadSectionNames(@ScriptDir & "\" & $ini_filename)
	_ArrayDelete($saved_pages_arr, 0)
	_ArrayDelete($saved_pages_arr, _ArraySearch($saved_pages_arr, "Main"))
	;_ArrayDisplay($saved_pages_arr)
	_ArraySort($saved_pages_arr)

	_GUICtrlListView_BeginUpdate($visible_listview)
	_GUICtrlListView_DeleteAllItems($visible_listview)
	for $each in $saved_pages_arr
		$index = _GUICtrlListView_AddItem($visible_listview, $each)
		_GUICtrlListView_AddSubItem($visible_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "url", ""), 1)
		_GUICtrlListView_AddSubItem($visible_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "when", ""), 2)

		Local $sDecodedText = BinaryToString(IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 4) ; Convert back to Unicode
		_GUICtrlListView_AddSubItem($visible_listview, $index, $sDecodedText, 3)

		;_GUICtrlListView_AddSubItem($visible_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 3)


	Next
	_GUICtrlListView_EndUpdate($visible_listview)

	_GUICtrlListView_BeginUpdate($hidden_listview)
	_GUICtrlListView_DeleteAllItems($hidden_listview)
	for $each in $saved_pages_arr
		$index = _GUICtrlListView_AddItem($hidden_listview, $each)
		_GUICtrlListView_AddSubItem($hidden_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "url", ""), 1)
		_GUICtrlListView_AddSubItem($hidden_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "when", ""), 2)


		Local $sDecodedText = BinaryToString(IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 4) ; Convert back to Unicode
		_GUICtrlListView_AddSubItem($hidden_listview, $index, $sDecodedText, 3)

		;_GUICtrlListView_AddSubItem($hidden_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 3)


	Next
	_GUICtrlListView_EndUpdate($hidden_listview)

EndFunc





Func UpdateStatusBarAndElapsedTime($message, $part = 1)
	_GUICtrlStatusBar_SetText($hStatus, $message, $part)
	if $status_bar_elapsed_timer = -1 Then Return
	Local $iElapsed = TimerDiff($status_bar_elapsed_timer) / 1000 ; Convert to seconds
    Local $sTimeFormatted = StringFormat("%02d:%02d", $iElapsed / 60, Mod($iElapsed, 60))
	_GUICtrlStatusBar_SetText($hStatus, $sTimeFormatted, 2)
EndFunc


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

