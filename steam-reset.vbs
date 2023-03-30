Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "steam-reset.bat" & Chr(34), 0, False
Set WshShell = Nothing