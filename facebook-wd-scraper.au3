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


Global $hGUI = GUICreate($app_name, 1024, 600, -1, -1, -1)

Global $past_week_checkbox = GUICtrlCreateCheckbox("Past Week", 20, 40, 80, 20)
Global $free_checkbox = GUICtrlCreateCheckbox("Free", 110, 40, 80, 20)

Global $visible_listview = _GUICtrlListView_Create($hGUI, "", 20, 70, 990, 460)
_GUICtrlListView_SetExtendedListViewStyle($visible_listview, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT, $LVS_EX_SUBITEMIMAGES))
_GUICtrlListView_InsertColumn($visible_listview, 0, "Name", 200)
_GUICtrlListView_InsertColumn($visible_listview, 1, "Url", 0)
_GUICtrlListView_InsertColumn($visible_listview, 2, "When", 100)
_GUICtrlListView_InsertColumn($visible_listview, 3, "Message", 800)

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



Global $saved_pages_arr = IniReadSectionNames(@ScriptDir & "\" & $ini_filename)
_ArrayDelete($saved_pages_arr, 0)
_ArrayDelete($saved_pages_arr, _ArraySearch($saved_pages_arr, "Main"))
;_ArrayDisplay($saved_pages_arr)

; Add items

for $each in $saved_pages_arr
	$index = _GUICtrlListView_AddItem($visible_listview, $each)
	_GUICtrlListView_AddSubItem($visible_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "url", ""), 1)
	_GUICtrlListView_AddSubItem($visible_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "when", ""), 2)
	_GUICtrlListView_AddSubItem($visible_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 3)
	$index = _GUICtrlListView_AddItem($hidden_listview, $each)
	_GUICtrlListView_AddSubItem($hidden_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "url", ""), 1)
	_GUICtrlListView_AddSubItem($hidden_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "when", ""), 2)
	_GUICtrlListView_AddSubItem($hidden_listview, $index, IniRead(@ScriptDir & "\" & $ini_filename, $each, "message", ""), 3)
Next


GUISetState(@SW_SHOW, $hGUI)


Local $iMsg = 0
While 1
	$iMsg = GUIGetMsg(1)
	Switch $iMsg[0]

		Case $past_week_checkbox, $free_checkbox
			_GUICtrlListView_BeginUpdate($visible_listview)
			_GUICtrlListView_DeleteAllItems($visible_listview)

			If GUICtrlRead($past_week_checkbox) = $GUI_CHECKED or GUICtrlRead($free_checkbox) = $GUI_CHECKED Then

				for $i = 0 to _GUICtrlListView_GetItemCount($hidden_listview) - 1
					$item_arr = _GUICtrlListView_GetItemTextArray($hidden_listview, $i)
					$index = _GUICtrlListView_AddItem($visible_listview, $item_arr[1])
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[2], 1)
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[3], 2)
					_GUICtrlListView_AddSubItem($visible_listview, $index, $item_arr[4], 3)
				Next

				For $i = _GUICtrlListView_GetItemCount($visible_listview) - 1 To 0 Step -1
					$item_arr = _GUICtrlListView_GetItemTextArray($visible_listview, $i)
					if GUICtrlRead($past_week_checkbox) = $GUI_CHECKED and StringRegExp($item_arr[3], "\d+[dh]") = False Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
					if GUICtrlRead($free_checkbox) = $GUI_CHECKED and StringInStr($item_arr[4], "free") = 0 Then
						_GUICtrlListView_DeleteItem($visible_listview, $i)
						ContinueLoop
					EndIf
				Next

			EndIf

			If GUICtrlRead($past_week_checkbox) = $GUI_UNCHECKED And GUICtrlRead($free_checkbox) = $GUI_UNCHECKED Then
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

			_GUICtrlListView_BeginUpdate($visible_listview)
			for $i = 0 to _GUICtrlListView_GetItemCount($visible_listview) - 1
				_GUICtrlListView_SetItemText($visible_listview, $i, "", 2)
				_GUICtrlListView_SetItemText($visible_listview, $i, "", 3)
			Next
			_GUICtrlListView_EndUpdate($visible_listview)

			_GUICtrlListView_BeginUpdate($hidden_listview)
			for $i = 0 to _GUICtrlListView_GetItemCount($hidden_listview) - 1
				_GUICtrlListView_SetItemText($hidden_listview, $i, "", 2)
				_GUICtrlListView_SetItemText($hidden_listview, $i, "", 3)
				$item_arr = _GUICtrlListView_GetItemTextArray($hidden_listview, $i)
				IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "when", "")
				IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "message", "")
			Next
			_GUICtrlListView_EndUpdate($hidden_listview)

			$status_bar_elapsed_timer = TimerInit()
			UpdateStatusBarAndElapsedTime("creating session ...")
			CreateSession(True, 8674)
			UpdateStatusBarAndElapsedTime("creating session ... done")

			$max_pages = _GUICtrlListView_GetItemCount($hidden_listview)

			for $i = 0 to $max_pages - 1

				UpdateStatusBarAndElapsedTime("FB page " & ($i + 1) & " of " & $max_pages, 0)

				$item_arr = _GUICtrlListView_GetItemTextArray($hidden_listview, $i)

				ShowDebug(0, $item_arr[1])

				UpdateStatusBarAndElapsedTime("navigating to page " & $item_arr[2] & " ...")
				Navigate($item_arr[2])
				UpdateStatusBarAndElapsedTime("navigating to page " & $item_arr[2] & " ... done")

				UpdateStatusBarAndElapsedTime("finding the post text ...")

				$text2 = FindAndText($ByXPath, "//div[@data-ad-rendering-role='story_message']/../../preceding-sibling::div[1]")
				ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $text2 = ' & $text2 & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
				if StringLen($text2) > 0 Then
					$text_arr = StringSplit($text2, @LF, $STR_ENTIRESPLIT + $STR_NOCOUNT)
					_GUICtrlListView_SetItemText($hidden_listview, $i, $text_arr[1], 2)
					_GUICtrlListView_SetItemText($visible_listview, $i, $text_arr[1], 2)
					IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "when", $text_arr[1])
				EndIf

				$text = FindAndText($ByXPath, "//div[@data-ad-rendering-role='story_message']")
				ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $text = ' & $text & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
				if StringLen($text2) > 0 Then
					$text = StringReplace(StringReplace($text, @LF, " "), @CRLF, " ")
					_GUICtrlListView_SetItemText($hidden_listview, $i, $text, 3)
					_GUICtrlListView_SetItemText($visible_listview, $i, $text, 3)
					IniWrite(@ScriptDir & "\" & $ini_filename, $item_arr[1], "message", $text)
				EndIf

				UpdateStatusBarAndElapsedTime("finding the post text ... done")
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






Func UpdateStatusBarAndElapsedTime($message, $part = 1)
	_GUICtrlStatusBar_SetText($hStatus, $message, $part)
	if $status_bar_elapsed_timer = -1 Then Return
	Local $iElapsed = TimerDiff($status_bar_elapsed_timer) / 1000 ; Convert to seconds
    Local $sTimeFormatted = StringFormat("%02d:%02d", $iElapsed / 60, Mod($iElapsed, 60))
	_GUICtrlStatusBar_SetText($hStatus, $sTimeFormatted, 2)
EndFunc



