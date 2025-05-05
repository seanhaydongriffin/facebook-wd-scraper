#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <GuiStatusBar.au3>
#include <GUIButton.au3>
;#include <ComboConstants.au3>
;#include <GuiComboBox.au3>
#Include <GDIPlus.au3>
#include <GuiListView.au3>
#include <Array.au3>
#include "wd_extra.au3"
#include "Curl.au3"
#include "Json.au3"


Global $status_bar_elapsed_timer = -1
Local $aTimeZone = _Date_Time_GetTimeZoneInformation()
Local $iOffsetMinutes = -$aTimeZone[1]
$hFont = _WinAPI_CreateFont(18, 8, 0, 0, $FW_NORMAL, False, False, False, $DEFAULT_CHARSET, $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $DEFAULT_QUALITY, 0, "Arial")

Global $hGUI = GUICreate($app_name, 1024, 800, -1, -1, -1, $WS_EX_TOPMOST)

Global $past_week_checkbox = GUICtrlCreateCheckbox("Past Week", 20, 40, 80, 20)
Global $free_checkbox = GUICtrlCreateCheckbox("Free", 110, 40, 80, 20)
Global $half_checkbox = GUICtrlCreateCheckbox("Half", 200, 40, 80, 20)
Global $special_checkbox = GUICtrlCreateCheckbox("Special", 290, 40, 80, 20)
Global $offer_checkbox = GUICtrlCreateCheckbox("Offer", 380, 40, 80, 20)

Global $visible_listview = _GUICtrlListView_Create($hGUI, "", 20, 70, 990, 460)
_GUICtrlListView_SetExtendedListViewStyle($visible_listview, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT, $LVS_EX_SUBITEMIMAGES))
_GUICtrlListView_InsertColumn($visible_listview, 0, "Name", 200)
_GUICtrlListView_InsertColumn($visible_listview, 1, "Url", 0)
_GUICtrlListView_InsertColumn($visible_listview, 2, "When", 100)
_GUICtrlListView_InsertColumn($visible_listview, 3, "Message", 2000)
_WinAPI_SetFont($visible_listview, $hFont, True)

Global $hidden_listview = _GUICtrlListView_Create($hGUI, "", 20, 70, 990, 460)
WinSetState($hidden_listview, "", @SW_HIDE)
_GUICtrlListView_InsertColumn($hidden_listview, 0, "Name", 200)
_GUICtrlListView_InsertColumn($hidden_listview, 1, "Url", 0)
_GUICtrlListView_InsertColumn($hidden_listview, 2, "When", 100)
_GUICtrlListView_InsertColumn($hidden_listview, 3, "Message", 800)

Global $detail_edit = GUICtrlCreateEdit("", 20, 550, 990, 180, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_WANTRETURN))
GUICtrlSetFont(-1, 12)

Global $refresh_button = GUICtrlCreateButton("Refresh", 20, 750, 80, 20)
Global $visit_button = GUICtrlCreateButton("Visit", 110, 750, 80, 20)
Global $refresh_pages_no_posts_checkbox = GUICtrlCreateCheckbox("Refresh pages with no posts", 200, 750, 160, 20)
Global $send_to_sheets_button = GUICtrlCreateButton("Send To Sheets", 370, 750, 100, 20)

$hStatus = _GUICtrlStatusBar_Create($hGUI)
Local $aParts[4] = [100, 590, 640]
_GUICtrlStatusBar_SetParts($hStatus, $aParts)
_GUICtrlStatusBar_SetText($hStatus, "", 0)
_GUICtrlStatusBar_SetText($hStatus, "", 1)
_GUICtrlStatusBar_SetText($hStatus, "", 2)


RefreshListviews()



GUISetState(@SW_SHOW, $hGUI)


GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")

Local $iMsg = 0
While 1
	$iMsg = GUIGetMsg(1)
	Switch $iMsg[0]

		Case $past_week_checkbox, $free_checkbox, $half_checkbox, $special_checkbox, $offer_checkbox
			_GUICtrlListView_BeginUpdate($visible_listview)
			_GUICtrlListView_DeleteAllItems($visible_listview)

			If GUICtrlRead($past_week_checkbox) = $GUI_CHECKED or _
				GUICtrlRead($free_checkbox) = $GUI_CHECKED Or _
				GUICtrlRead($half_checkbox) = $GUI_CHECKED Or _
				GUICtrlRead($special_checkbox) = $GUI_CHECKED Or _
				GUICtrlRead($offer_checkbox) = $GUI_CHECKED Then

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
					if GUICtrlRead($special_checkbox) = $GUI_CHECKED and StringInStr($item_arr[4], "special") = 0 Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
					if GUICtrlRead($offer_checkbox) = $GUI_CHECKED and StringInStr($item_arr[4], "offer") = 0 Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
					ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $item_arr[4] = ' & $item_arr[4] & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
				Next

			EndIf

			If GUICtrlRead($past_week_checkbox) = $GUI_UNCHECKED And _
				GUICtrlRead($free_checkbox) = $GUI_UNCHECKED And _
				GUICtrlRead($half_checkbox) = $GUI_UNCHECKED And _
				GUICtrlRead($special_checkbox) = $GUI_UNCHECKED And _
				GUICtrlRead($offer_checkbox) = $GUI_UNCHECKED Then
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
			Global $saved_pages_arr = IniReadSectionNames(@ScriptDir & "\" & $ini_filename)
			_ArrayDelete($saved_pages_arr, 0)
			_ArrayDelete($saved_pages_arr, _ArraySearch($saved_pages_arr, "Main"))
			_ArraySort($saved_pages_arr)

			if GUICtrlRead($refresh_pages_no_posts_checkbox) = $GUI_UNCHECKED Then
				; clear the when and messages for all facebook pages in the ini file
				for $each in $saved_pages_arr
					IniWrite(@ScriptDir & "\" & $ini_filename, $each, "when", "")
					IniWrite(@ScriptDir & "\" & $ini_filename, $each, "message", "")
				Next
			Else
				; clear any uncomplete updates from the agents
				for $each in $saved_pages_arr
					Local $when = IniRead(@ScriptDir & "\" & $ini_filename, $each, "when", "")
					Local $sDecodedText = BinaryToString(IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 4) ; Convert back to Unicode
					if $when == "-" Or $sDecodedText == "update in progress by agent ..." Or StringLeft($sDecodedText, 10) == "jq: error:" Then
						IniWrite(@ScriptDir & "\" & $ini_filename, $each, "when", "")
						IniWrite(@ScriptDir & "\" & $ini_filename, $each, "message", "")
						for $i = 0 to _GUICtrlListView_GetItemCount($visible_listview) - 1
							$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview, $i)
							if $item_arr[1] == $each Then
								_GUICtrlListView_SetItemText($visible_listview, $i, "", 2)
								_GUICtrlListView_SetItemText($visible_listview, $i, "", 3)
								_GUICtrlListView_SetItemText($hidden_listview, $i, "", 2)
								_GUICtrlListView_SetItemText($hidden_listview, $i, "", 3)
							EndIf
						Next
					EndIf
				Next
			EndIf

			; update the listviews with the ini file data
			RefreshListviews()

			; start a mutex to control the agents
			$mutex_handle = _WinAPI_CreateMutex($app_name)
			_WinAPI_ReleaseMutex($mutex_handle)

			Local $pids[0]

			$pid = Run(@ScriptDir & "\facebook-wd-scraper-agent.exe 8674", @ScriptDir, @SW_MINIMIZE)
			_ArrayAdd($pids, $pid)
			$pid = Run(@ScriptDir & "\facebook-wd-scraper-agent.exe 8675", @ScriptDir, @SW_MINIMIZE)
			_ArrayAdd($pids, $pid)
			$pid = Run(@ScriptDir & "\facebook-wd-scraper-agent.exe 8676", @ScriptDir, @SW_MINIMIZE)
			_ArrayAdd($pids, $pid)
;			$pid = Run(@ScriptDir & "\facebook-wd-scraper-agent.exe 8677", @ScriptDir, @SW_MINIMIZE)
;			_ArrayAdd($pids, $pid)
;			$pid = Run(@ScriptDir & "\facebook-wd-scraper-agent.exe 8678", @ScriptDir, @SW_MINIMIZE)
;			_ArrayAdd($pids, $pid)

			; while agents exist
			While True
				Local $agents_exist = False
				for $pid in $pids
					if ProcessExists($pid) <> 0 Then $agents_exist = True
				Next
				if $agents_exist = False Then ExitLoop
				sleep(3000)

				; update the listviews with the ini file data updated by the agents

				for $i = 0 to _GUICtrlListView_GetItemCount($visible_listview) - 1
					$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview, $i)
					$when = IniRead(@ScriptDir & "\" & $ini_filename, $item_arr[1], "when", "")
					Local $sDecodedText = BinaryToString(IniRead(@ScriptDir & "\" & $ini_filename, $item_arr[1], "message", ""), 4) ; Convert back to Unicode
					$sDecodedText = StringReplace($sDecodedText, @CRLF, " ")
					$sDecodedText = StringReplace($sDecodedText, @CR, " ")
					$sDecodedText = StringReplace($sDecodedText, @LF, " ")
					$sDecodedText = StringReplace($sDecodedText, Chr(10), " ")
					$sDecodedText = StringRegExpReplace($sDecodedText, "\s+", " ")

					if $item_arr[3] <> $when Then
						_GUICtrlListView_SetItemText($visible_listview, $i, $when, 2)
						_GUICtrlListView_SetItemText($hidden_listview, $i, $when, 2)
					EndIf
					if $item_arr[4] <> $sDecodedText Then
						_GUICtrlListView_SetItemText($visible_listview, $i, $sDecodedText, 3)
						_GUICtrlListView_SetItemText($hidden_listview, $i, $sDecodedText, 3)
					EndIf
				Next
			WEnd


		Case $visit_button

			$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview)
			CreateSession(False, 8674)
			Navigate($item_arr[2])

			; check if facebook has redirected the browser to "www.facebook.com/login" and if so navigation to the facebook page again
			$url = _WD_Action(WDSessionFromPromptRemoteDebuggingPort(), "URL")
			if StringInStr($url, "www.facebook.com/login") > 0 then Navigate($item_arr[2])

		Case $send_to_sheets_button

			Local $header_list = Curl_Slist_Append(0, "Content-Type: application/x-www-form-urlencoded")
			$payload = "client_id=" & IniRead(@ScriptDir & "\" & $ini_filename, "Main", "GoogleOAuthClientId", "") & "&client_secret=" & IniRead(@ScriptDir & "\" & $ini_filename, "Main", "GoogleOAuthClientSecret", "") & "&refresh_token=" & IniRead(@ScriptDir & "\" & $ini_filename, "Main", "GoogleOAuthRefreshToken", "") & "&grant_type=refresh_token"
			Local $response = Curl_Post("https://oauth2.googleapis.com/token", $header_list, $payload)
			Local $access_token = StringRegExp($response, '"access_token": "(.*?)"', 1)
			ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $access_token[0] = ' & $access_token[0] & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

			$items_count = _GUICtrlListView_GetItemCount($visible_listview)
			$sheets_range = "Sheet1!A1:C" & ($items_count + 2)
			$sheets_json = '{"range": "' & $sheets_range & '", "values": [["As of: ' & DateNow() & '", "' & TimeNow() & '", ""], ["Name", "When", "Message"]'
			For $i = 0 to $items_count - 1
				$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview, $i)
				$sheets_json = $sheets_json & ', ["' & Json_StringEncode($item_arr[1]) & '", "' & Json_StringEncode($item_arr[3]) & '", "' & Json_StringEncode($item_arr[4]) & '"]'
			Next
			$sheets_json = $sheets_json & ']}'
			ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $sheets_json = ' & $sheets_json & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

			Local $header_list = Curl_Slist_Append(0, "Content-Type: application/json")
			$header_list = Curl_Slist_Append($header_list, "Authorization: Bearer " & $access_token[0])
			Local $response = Curl_Put("https://sheets.googleapis.com/v4/spreadsheets/1u5U-qHRRk_OIhM3LuvJDhmkyPPmWjh338mPuQaTTBZw/values/" & $sheets_range & "?valueInputOption=RAW", $header_list, $sheets_json)
			ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $response = ' & $response & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console


		Case $GUI_EVENT_CLOSE
			;If $iMsg[1] = $element_details_gui Then GUISetState(@SW_HIDE, $element_details_gui)
			If $iMsg[1] = $hGUI Then ExitLoop
	EndSwitch
WEnd

GUIDelete($hGUI)


Func WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	Local $hWndListView = $visible_listview
	If Not IsHWnd($visible_listview) Then $hWndListView = GUICtrlGetHandle($visible_listview)

	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	Local $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	Local $iCode = DllStructGetData($tNMHDR, "Code")
	Switch $hWndFrom
		Case $hWndListView
			Switch $iCode
				Case $LVN_ITEMCHANGED ; An item has changed
					$arr = _GUICtrlListView_GetItemTextArray($visible_listview)
					if $arr[0] > 0 Then
						GUICtrlSetData($detail_edit, $arr[4])
					EndIf
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_NOTIFY


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
		$sDecodedText = StringReplace($sDecodedText, @CRLF, " ")
		$sDecodedText = StringReplace($sDecodedText, @CR, " ")
		$sDecodedText = StringReplace($sDecodedText, @LF, " ")
		$sDecodedText = StringReplace($sDecodedText, Chr(10), " ")
		$sDecodedText = StringRegExpReplace($sDecodedText, "\s+", " ")
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
		$sDecodedText = StringReplace($sDecodedText, @CRLF, " ")
		$sDecodedText = StringReplace($sDecodedText, @CR, " ")
		$sDecodedText = StringReplace($sDecodedText, @LF, " ")
		$sDecodedText = StringReplace($sDecodedText, Chr(10), " ")
		$sDecodedText = StringRegExpReplace($sDecodedText, "\s+", " ")
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


Func Curl_Post($url, $Slist, $Post = "")
	Local $Curl = Curl_Easy_Init()
	If Not $Curl Then Return

	Local $Html = $Curl ; any number as identify
	Local $Header = $Curl + 1 ; any number as identify

	Curl_Easy_Setopt($Curl, $CURLOPT_URL, $url)
	Curl_Easy_Setopt($Curl, $CURLOPT_FOLLOWLOCATION, 1)
	;Curl_Easy_Setopt($Curl, $CURLOPT_PROXY, "127.0.0.1:8888")
	Curl_Easy_Setopt($Curl, $CURLOPT_WRITEFUNCTION, Curl_DataWriteCallback())
	Curl_Easy_Setopt($Curl, $CURLOPT_WRITEDATA, $Html)
	Curl_Easy_Setopt($Curl, $CURLOPT_HEADERFUNCTION, Curl_DataWriteCallback())
	Curl_Easy_Setopt($Curl, $CURLOPT_HEADERDATA, $Header)
	Curl_Easy_Setopt($Curl, $CURLOPT_HTTPHEADER, $Slist)
	Curl_Easy_Setopt($Curl, $CURLOPT_TIMEOUT, 30)
	Curl_Easy_Setopt($Curl, $CURLOPT_POST, 1)
	if StringLen($Post) > 0 Then Curl_Easy_Setopt($Curl, $CURLOPT_COPYPOSTFIELDS, $Post)

 	Curl_Easy_Setopt($Curl, $CURLOPT_SSL_VERIFYPEER, 0)

	Local $Code = Curl_Easy_Perform($Curl)
	Local $response = ""

	If $Code = $CURLE_OK Then
 		$response = BinaryToString(Curl_Data_Get($Html))
	Else
		ConsoleWrite(Curl_Easy_StrError($Code) & @LF)
	EndIf

	Curl_Easy_Cleanup($Curl)
	Curl_Data_Cleanup($Header)
	Curl_Data_Cleanup($Html)

	return $response
EndFunc

Func Curl_Put($url, $Slist, $Post = "")
	Local $Curl = Curl_Easy_Init()
	If Not $Curl Then Return

	Local $Html = $Curl ; any number as identify
	Local $Header = $Curl + 1 ; any number as identify

	Curl_Easy_Setopt($Curl, $CURLOPT_URL, $url)
	Curl_Easy_Setopt($Curl, $CURLOPT_FOLLOWLOCATION, 1)
	;Curl_Easy_Setopt($Curl, $CURLOPT_PROXY, "127.0.0.1:8888")
	Curl_Easy_Setopt($Curl, $CURLOPT_WRITEFUNCTION, Curl_DataWriteCallback())
	Curl_Easy_Setopt($Curl, $CURLOPT_WRITEDATA, $Html)
	Curl_Easy_Setopt($Curl, $CURLOPT_HEADERFUNCTION, Curl_DataWriteCallback())
	Curl_Easy_Setopt($Curl, $CURLOPT_HEADERDATA, $Header)
	Curl_Easy_Setopt($Curl, $CURLOPT_HTTPHEADER, $Slist)
	Curl_Easy_Setopt($Curl, $CURLOPT_TIMEOUT, 30)
	Curl_Easy_Setopt($Curl, $CURLOPT_CUSTOMREQUEST, "PUT")

	if StringLen($Post) > 0 Then
		Local $JsonBuffer = DllStructCreate("char[" & StringLen($Post) + 1 & "]")  ; Allocates memory
		DllStructSetData($JsonBuffer, 1, $Post)  ; Stores JSON safely in buffer
		Curl_Easy_Setopt($Curl, $CURLOPT_POSTFIELDS, DllStructGetPtr($JsonBuffer))  ; Pass clean buffer
		Curl_Easy_Setopt($Curl, $CURLOPT_POSTFIELDSIZE, StringLen($Post))
	EndIf

 	Curl_Easy_Setopt($Curl, $CURLOPT_SSL_VERIFYPEER, 0)

	Local $Code = Curl_Easy_Perform($Curl)
	Local $response = ""

	If $Code = $CURLE_OK Then
 		$response = BinaryToString(Curl_Data_Get($Html))
	Else
		ConsoleWrite(Curl_Easy_StrError($Code) & @LF)
	EndIf

	Curl_Easy_Cleanup($Curl)
	Curl_Data_Cleanup($Header)
	Curl_Data_Cleanup($Html)

	return $response
EndFunc

func DateNow()
	Local $sMonthNames = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
	Local $aMonths = StringSplit($sMonthNames, "|")
	Return StringFormat("%d %s %d", @MDAY, $aMonths[@MON], @YEAR)
EndFunc

Func TimeNow()
	Local $iHour = @HOUR
	Local $sSuffix = "AM"
	If $iHour >= 12 Then
		$sSuffix = "PM"
		If $iHour > 12 Then $iHour -= 12  ; Convert to 12-hour format
	ElseIf $iHour = 0 Then
		$iHour = 12  ; Midnight should be "12 AM"
	EndIf
	Return StringFormat("%d:%02d %s", $iHour, @MIN, $sSuffix)
EndFunc
