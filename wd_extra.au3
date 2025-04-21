#include-once
#include "wd_cdp.au3"
#include "wd_helper.au3"
#include "wd_capabilities.au3"
;#include "Toast.au3"
#include <GuiStatusBar.au3>
#include <Date.au3>
;#include "JsonAJ.au3"
#include "jq.au3"

Global Const $ByCSSSelector = $_WD_LOCATOR_ByCSSSelector
Global Const $ByXPath = $_WD_LOCATOR_ByXPath
Global Const $ByLinkText = $_WD_LOCATOR_ByLinkText
Global Const $ByPartialLinkText = $_WD_LOCATOR_ByPartialLinkText
Global Const $ByTagName = $_WD_LOCATOR_ByTagName
Global Const $debug_text_size = 200

Global $hStatus
Global $ini_filename
Global $prompt

Func CreateSession($headless = False, $remote_debugging_port = 0, $debug_flag = 0)
	; running chrome with:
	; chrome.exe --remote-debugging-port=9222
	;Local $remote_debugging_port = 9222
	;Local $remote_debugging_port = 8674

	Local $_remote_debugging_port = $remote_debugging_port
	;if $_remote_debugging_port = 0 Then $_remote_debugging_port = IniRead($ini_filename, $prompt, "RemoteDebuggingPort", 8674)
	if $_remote_debugging_port = 0 Then $_remote_debugging_port = IniRead($ini_filename, "Main", "RemoteDebuggingPort", 8674)

	Local $_web_driver_pid_port_session = StringRegExp(IniRead($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPIDPort9515Session0"), "WebDriverPID(.*?)Port(.*?)Session(.*)", 1)
	$_WD_PORT = $_web_driver_pid_port_session[1]

	; close any chromedrivers that:
	;	- have a webdriver pid that was used for this remote debugging port previously
	;	- were created greater than 8 hours ago (too old and considered not needed any more)
	;	- have no child (chrome) browsers attached to them
	WDCloseDriverBrowsersWithPID($_web_driver_pid_port_session[0])
	WDCloseDriverBrowsersOlderThan(8)
	WDCloseDriversWithNoBrowsers()



	;if StringLen($wd_session) = 0 Then

		ShowDebug($debug_flag, "Creating the browser ...")

		_WD_DebugSwitch($_WD_DEBUG_None)
		_WD_Option('Driver', 'chromedriver.exe')
		_WD_Option('Port', Number($_web_driver_pid_port_session[1]))
		_WD_Option('driverparams', '--verbose --port=' & $_web_driver_pid_port_session[1] & ' --log-path="' & @ScriptDir & '\chrome.log"')
		_WD_Option('driverclose', False)
		_WD_Option('driverdetect', False)
		_WD_CapabilitiesStartup()
		_WD_CapabilitiesAdd('alwaysMatch', 'chrome')
		_WD_CapabilitiesAdd('w3c', True)
		_WD_CapabilitiesAdd('detach', "false")
		_WD_CapabilitiesAdd('excludeSwitches', 'enable-automation')
		_WD_CapabilitiesAdd('binary', IniRead($ini_filename, "Main", "BrowserBinary", "C:\Users\sgriffin\.cache\selenium\chrome\win64\117.0.5938.149\chrome.exe"))
		_WD_CapabilitiesAdd('prefs', 'credentials_enable_service', False)
		;_WD_CapabilitiesAdd('args', '--remote-debugging-port=' & $_remote_debugging_port & ' --headless')

		if $headless = True Then _WD_CapabilitiesAdd('args', '--headless')

		Local $iWebDriverPID = _WD_Startup()
		If @error Then
			ShowDebug($debug_flag, "Creating the browser ... Error. See chrome.log")
			Return
		EndIf
		IniWrite($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPID" & $iWebDriverPID & "Port" & $_web_driver_pid_port_session[1] & "Session" & $_web_driver_pid_port_session[2])

		Local $s_Capabilities = _WD_CapabilitiesGet()
		Local $wd_session = _WD_CreateSession($s_Capabilities)
		If @error Then
			ShowDebug($debug_flag, "Creating the browser ... Error. See chrome.log")
			Return
		EndIf
		IniWrite($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPID" & $iWebDriverPID & "Port" & $_web_driver_pid_port_session[1] & "Session" & $wd_session)

		ShowDebug($debug_flag, "Creating the browser ... Done")
	;EndIf
EndFunc


Func AttachSession($remote_debugging_port = 0, $debug_flag = 0)
	;MsgBox(0, "WebAssist AI", "AttachSession")
	; running chrome with:
	; chrome.exe --remote-debugging-port=9222
	;Local $remote_debugging_port = 9222
	;Local $remote_debugging_port = 8674

	Local $_remote_debugging_port = $remote_debugging_port
	;if $_remote_debugging_port = 0 Then $_remote_debugging_port = IniRead($ini_filename, $prompt, "RemoteDebuggingPort", 8674)
	if $_remote_debugging_port = 0 Then $_remote_debugging_port = IniRead($ini_filename, "Main", "RemoteDebuggingPort", 8674)

	Local $_web_driver_pid_port_session = StringRegExp(IniRead($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPIDPort9515Session0"), "WebDriverPID(.*?)Port(.*?)Session(.*)", 1)
	$_WD_PORT = $_web_driver_pid_port_session[1]

	if StringLen($_web_driver_pid_port_session[2]) > 0 Then

		ShowDebug($debug_flag, "Attaching to the browser ...")

		_WD_DebugSwitch($_WD_DEBUG_None)
		_WD_Option('Driver', 'chromedriver.exe')
		_WD_Option('Port', $_web_driver_pid_port_session[1])
		_WD_Option('driverparams', '--port=' & $_web_driver_pid_port_session[1])
		_WD_Option('driverclose', False)
		_WD_Option('driverdetect', False)
		_WD_CapabilitiesStartup()
		_WD_CapabilitiesAdd('firstMatch', 'chrome')
		_WD_CapabilitiesAdd('w3c', True)
		_WD_CapabilitiesAdd('binary', IniRead($ini_filename, "Main", "BrowserBinary", ""))
		_WD_CapabilitiesAdd('debuggerAddress', '127.0.0.1:' & $_remote_debugging_port)
		_WD_CapabilitiesDump(@ScriptLineNumber & ' :WebDriver:Capabilities:')

		Local $iWebDriverPID = _WD_Startup()
		If @error Then
			ShowDebug($debug_flag, "Attaching to the browser ... Error. See chrome.log")
			Return
		EndIf
		IniWrite($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPID" & $iWebDriverPID & "Port" & $_web_driver_pid_port_session[1] & "Session" & $_web_driver_pid_port_session[2])

		Local $s_Capabilities = _WD_CapabilitiesGet()
		Local $wd_session = _WD_CreateSession($s_Capabilities)
		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $wd_session = ' & $wd_session & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
		If @error Then
			ShowDebug($debug_flag, "Attaching to the browser ... Error. See chrome.log")
			Return
		EndIf
		IniWrite($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPID" & $iWebDriverPID & "Port" & $_web_driver_pid_port_session[1] & "Session" & $wd_session)

		ShowDebug($debug_flag, "Attaching to the browser ... Done")
	EndIf
EndFunc

Func DetachSession($debug_flag = 0)
	;if StringLen($wd_session) > 0 Then



	;if $remote_debugging_port_session.Exists(IniRead($ini_filename, $prompt, "RemoteDebuggingPort", 8674)) = True Then
		ShowDebug($debug_flag, "Detaching from the browser ...")
		_WD_DeleteSession(WDSessionFromPromptRemoteDebuggingPort())
		_WD_Shutdown()
		;$remote_debugging_port_session.Remove(IniRead($ini_filename, $prompt, "RemoteDebuggingPort", 8674))
		ShowDebug($debug_flag, "Detaching from the browser ... Done")
	;EndIf
EndFunc

Func Navigate($sURL, $debug_flag = 0)
	;ShowDebug($debug_flag, "Navigating to " & StringLeft($sURL, $debug_text_size) & " ...")

	if StringLeft($sURL, 4) == 'http' Then
		_WD_Navigate(WDSessionFromPromptRemoteDebuggingPort(), $sURL)
	Else
		Local $url = _WD_Action(WDSessionFromPromptRemoteDebuggingPort(), 'url')
		Local $domain = StringLeft($url, StringInStr($url, ".com") + StringLen(".com") - 1)
		_WD_Navigate(WDSessionFromPromptRemoteDebuggingPort(), $domain & $sURL)
	EndIf

	;ShowDebug($debug_flag, "Navigating to " & StringLeft($sURL, $debug_text_size) & " ... Done")
EndFunc

Func LoadWait($iTimeout, $debug_flag = 0)
	ShowDebug($debug_flag, "Waiting for page to load ...")
	_WD_LoadWait(WDSessionFromPromptRemoteDebuggingPort(), Default, $iTimeout)
	ShowDebug($debug_flag, "Waiting for page to load ... Done")
EndFunc


Func Network($data)

	$result = _WD_CDPExecuteCommand2(WDSessionFromPromptRemoteDebuggingPort(), $data)
	Return $result

EndFunc







Func Find($sStrategy, $sSelector, $waitTimeout = Default, $debug_flag = 0)
	Local $sElement
	Local $finding_element_message

	if $waitTimeout = Default Then
		$finding_element_message = "Finding " & StringLeft($sSelector, $debug_text_size) & " ..."
		;ShowDebug($debug_flag, $finding_element_message)
		$sElement = _WD_FindElement(WDSessionFromPromptRemoteDebuggingPort(), $sStrategy, $sSelector)
;		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $sElement = ' & $sElement & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
	Else
		$finding_element_message = "Finding " & StringLeft($sSelector, $debug_text_size) & " with timeout ..."
		;ShowDebug($debug_flag, $finding_element_message)
		$sElement = _WD_WaitElement(WDSessionFromPromptRemoteDebuggingPort(), $sStrategy, $sSelector, Default, $waitTimeout)
	EndIf

	if StringLen($sElement) = 0 Then
		$finding_element_message = "Did not find " & StringLeft($sSelector, $debug_text_size)
		ShowDebug($debug_flag, $finding_element_message)
		;AttachSession(0, 1)
		;if $waitTimeout = Default Then
		;	$sElement = _WD_FindElement(WDSessionFromPromptRemoteDebuggingPort(), $sStrategy, $sSelector)
		;Else
		;	$sElement = _WD_WaitElement(WDSessionFromPromptRemoteDebuggingPort(), $sStrategy, $sSelector, Default, $waitTimeout)
		;EndIf

		;if StringLen($sElement) = 0 Then
			;ShowDebug($debug_flag, $finding_element_message & " Error")
			Return SetError(1, 0, $sElement)
		;EndIf
	EndIf

	;ShowDebug($debug_flag, $finding_element_message & " Done")
	Return $sElement
EndFunc

Func SetValue($sElement, $sValue, $debug_flag = 0)
	ShowDebug($debug_flag, "Setting the value to " & StringLeft($sValue, $debug_text_size) & " ...")
	_WD_SetElementValue(WDSessionFromPromptRemoteDebuggingPort(), $sElement, $sValue)
	ShowDebug($debug_flag, "Setting the value to " & StringLeft($sValue, $debug_text_size) & " ... Done")
EndFunc

Func Click($sElement, $debug_flag = 0)
	ShowDebug($debug_flag, "Clicking the element ...")
	_WD_ElementAction(WDSessionFromPromptRemoteDebuggingPort(), $sElement, "CLICK")
	ShowDebug($debug_flag, "Clicking the element ... Done")
EndFunc

Func FindAndDisplayed($sStrategy, $sSelector, $waitTimeout = Default, $debug_flag = 0)
	Local $sElement = Find($sStrategy, $sSelector, $waitTimeout)
	return _WD_ElementAction(WDSessionFromPromptRemoteDebuggingPort(), $sElement, "DISPLAYED")
EndFunc

Func FindAndInnerHtml($sStrategy, $sSelector, $waitTimeout = Default, $debug_flag = 0)
	Local $sElement = Find($sStrategy, $sSelector, $waitTimeout)
	return _WD_ElementAction(WDSessionFromPromptRemoteDebuggingPort(), $sElement, "property", "innerHTML")
EndFunc

Func FindAndText($sStrategy, $sSelector, $waitTimeout = Default, $debug_flag = 0)
	Local $sElement = Find($sStrategy, $sSelector, $waitTimeout)
	if @error = 0 Then return _WD_ElementAction(WDSessionFromPromptRemoteDebuggingPort(), $sElement, "text", "")
	Return ""
EndFunc

Func FindAndSetValue($sStrategy, $sSelector, $sValue, $waitTimeout = Default, $debug_flag = 0)
	Local $sElement = Find($sStrategy, $sSelector, $waitTimeout)
	SetValue($sElement, $sValue)
	Return $sElement
EndFunc

Func FindAndClick($sStrategy, $sSelector, $waitTimeout = Default, $debug_flag = 0)
	Local $sElement = Find($sStrategy, $sSelector, $waitTimeout)
	Click($sElement)
	Return $sElement
EndFunc

Func ShowDebug($debug_flag, $debug_text)
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $debug_text = ' & $debug_text & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
	;if $debug_flag = 0 then _Toast_Show(0, StringReplace($ini_filename, ".ini", ""), $debug_text, 5, False)
	;if $debug_flag = 1 then _GUICtrlStatusBar_SetText($hStatus, $debug_text, 1)
EndFunc




Func WDSessionFromPromptRemoteDebuggingPort($remote_debugging_port = 0)
	Local $_remote_debugging_port = $remote_debugging_port
	;if $_remote_debugging_port = 0 Then $_remote_debugging_port = IniRead($ini_filename, $prompt, "RemoteDebuggingPort", 8674)
	if $_remote_debugging_port = 0 Then $_remote_debugging_port = IniRead($ini_filename, "Main", "RemoteDebuggingPort", 8674)

	Local $_web_driver_pid_port_session = StringRegExp(IniRead($ini_filename, "Main", "RemoteDebuggingPort" & $_remote_debugging_port, "WebDriverPIDPort9515Session0"), "WebDriverPID(.*?)Port(.*?)Session(.*)", 1)
	$_WD_PORT = $_web_driver_pid_port_session[1]
	Return $_web_driver_pid_port_session[2]
EndFunc


Func _CloseChromeDriverBrowsersWithPID($pid)
	Local $aData = _WinAPI_EnumChildProcess($pid)

	If IsArray($aData) Then
		For $j = 0 To UBound($aData) - 1
			If $aData[$j][1] == 'chrome.exe' Then
				ProcessClose($aData[$j][0])
				ProcessWaitClose($aData[$j][0], 5)
			EndIf
		Next
	EndIf

	if _WinAPI_GetProcessName($pid) == 'chromedriver.exe' Then
		ProcessClose($pid)
		ProcessWaitClose($pid, 5)
	EndIf
EndFunc


Func WDCloseDriverBrowsersWithPID($pid)
	Local $aProcessList[2][2]
	$aProcessList[0][0] = 1
	$aProcessList[1][1] = $pid

	For $i = 1 To $aProcessList[0][0]
		_CloseChromeDriverBrowsersWithPID($aProcessList[$i][1])
	Next
EndFunc

Func WDCloseDriverBrowsersOlderThan($hours)
	Local $aProcessList = ProcessList("chromedriver.exe")

	For $i = 1 To $aProcessList[0][0]
		Local $aFT = _WinAPI_GetProcessTimes($aProcessList[$i][1])
        Local $tFT = _Date_Time_FileTimeToLocalFileTime($aFT[0])
		Local $tCalcStr = _Date_Time_FileTimeToStr($tFT, 1)
		Local $ageInHours = _DateDiff("h", $tCalcStr, _NowCalc())

		if $ageInHours > $hours Then _CloseChromeDriverBrowsersWithPID($aProcessList[$i][1])
	Next
EndFunc


Func WDCloseDriversWithNoBrowsers()
	Local $aProcessList = ProcessList("chromedriver.exe")

	For $i = 1 To $aProcessList[0][0]

		Local $pid = $aProcessList[$i][1]
		Local $chrome_found = False
		Local $aData = _WinAPI_EnumChildProcess($pid)

		If IsArray($aData) Then
			For $j = 0 To UBound($aData) - 1
				If $aData[$j][1] == 'chrome.exe' Then
					$chrome_found = True
				EndIf
			Next
		EndIf

		if $chrome_found = False and _WinAPI_GetProcessName($pid) == 'chromedriver.exe' Then
			ProcessClose($pid)
			ProcessWaitClose($pid, 5)
		EndIf
	Next
EndFunc
