import os, strutils, times, json, winim

proc wcharToString(arr: openArray[WCHAR]): string =
  for c in arr:
    if c == WCHAR(0): break
    result.add(char(c))

proc nullTerminated(arr: openArray[char]): string =
  for c in arr:
    if c == '\0': break
    result.add(c)

proc getOSInfo(): string =
  var hKey: HKEY
  var version, build = ""
  if RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", 0, KEY_READ, addr hKey) == ERROR_SUCCESS:
    var buf: array[256, WCHAR]
    var bufSize = DWORD(sizeof(buf))
    if RegQueryValueExW(hKey, "ProductName", nil, nil, cast[PBYTE](addr buf[0]), addr bufSize) == ERROR_SUCCESS:
      version = wcharToString(buf)
    bufSize = DWORD(sizeof(buf))
    if RegQueryValueExW(hKey, "CurrentBuild", nil, nil, cast[PBYTE](addr buf[0]), addr bufSize) == ERROR_SUCCESS:
      build = wcharToString(buf)
    RegCloseKey(hKey)
  let arch = if getEnv("PROCESSOR_ARCHITECTURE") == "AMD64": "x64" else: "x86"
  result = "OS: " & version & " (Build " & build & ")\n"
  result &= "Architecture: " & arch & "\n"
  # result &= "Hostname: " & getEnv("COMPUTERNAME") & "\n"
  # result &= "Domain: " & getEnv("USERDOMAIN") & "\n"

proc getUsername():string=
  let username =  getEnv("USERNAME") 
  return username

proc getHardwareInfo(): string =
  var hKey: HKEY
  var cpu = ""
  if RegOpenKeyEx(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", 0, KEY_READ, addr hKey) == ERROR_SUCCESS:
    var buf: array[256, WCHAR]
    var bufSize = DWORD(sizeof(buf))
    if RegQueryValueExW(hKey, "ProcessorNameString", nil, nil, cast[PBYTE](addr buf[0]), addr bufSize) == ERROR_SUCCESS:
      cpu = wcharToString(buf)
    RegCloseKey(hKey)
  var memStatus: MEMORYSTATUSEX
  memStatus.dwLength = DWORD(sizeof(memStatus))
  GlobalMemoryStatusEx(addr memStatus)
  var disks = ""
  for drive in 'C'..'Z':
    let path = $drive & ":\\"
    if dirExists(path):
      var freeBytes, totalBytes: ULARGE_INTEGER
      if GetDiskFreeSpaceEx(path, addr freeBytes, addr totalBytes, nil):
        disks &= "  " & $drive & ": " & $(totalBytes.QuadPart div (1024*1024*1024)) & " GB\n"
  result = "CPU: " & cpu & "\n"
  result &= "RAM Total: " & $(memStatus.ullTotalPhys div (1024*1024*1024)) & " GB\n"
  result &= "RAM Available: " & $(memStatus.ullAvailPhys div (1024*1024*1024)) & " GB\n"
  result &= "Disks:\n" & disks

proc getMacAddress(): string =

  var mac = ""
  var adapterInfo: array[16384, byte]
  var adapterSize = DWORD(len(adapterInfo))
  if GetAdaptersInfo(cast[PIP_ADAPTER_INFO](addr adapterInfo[0]), addr adapterSize) == ERROR_SUCCESS:
    var adapter = cast[PIP_ADAPTER_INFO](addr adapterInfo[0])
    while adapter != nil:
      if adapter.Type == IF_TYPE_ETHERNET_CSMACD or adapter.Type == IF_TYPE_IEEE80211:
        for i in 0..5:
          mac &= toHex(int(adapter.Address[i]), 2)
          if i < 5: mac &= ":"
        break
      adapter = adapter.Next
  result = mac


proc getIpInfo():string=
  var localIP = ""
  var hostname: array[256, char]
  if gethostname(addr hostname[0], 256) == 0:
    let he = gethostbyname(addr hostname[0])
    if he != nil:
      let addrList = cast[ptr ptr IN_ADDR](he.h_addr_list)
      if addrList != nil and addrList[] != nil:
        let inAddr: IN_ADDR = addrList[][]
        localIP = $inet_ntoa(inAddr)
  result = localIP


proc getInstalledSoftware(): string =
  let regPaths = [
    "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
    "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
  ]
  for regPath in regPaths:
    var hKey: HKEY
    if RegOpenKeyEx(HKEY_LOCAL_MACHINE, regPath, 0, KEY_READ, addr hKey) == ERROR_SUCCESS:
      var index = DWORD(0)
      var subKeyName: array[256, WCHAR]
      var subKeyLen = DWORD(len(subKeyName))
      while RegEnumKeyExW(hKey, index, addr subKeyName[0], addr subKeyLen, nil, nil, nil, nil) == ERROR_SUCCESS:
        var hSubKey: HKEY
        if RegOpenKeyExW(hKey, addr subKeyName[0], 0, KEY_READ, addr hSubKey) == ERROR_SUCCESS:
          var displayName: array[512, WCHAR]
          var nameLen = DWORD(sizeof(displayName))
          if RegQueryValueExW(hSubKey, "DisplayName", nil, nil, cast[PBYTE](addr displayName[0]), addr nameLen) == ERROR_SUCCESS:
            let name = wcharToString(displayName)
            if name.len > 0:
              result &= "  - " & name & "\n"
          RegCloseKey(hSubKey)
        inc index
        subKeyLen = DWORD(len(subKeyName))
      RegCloseKey(hKey)

proc getActiveProcesses(): string =
  let hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
  if hSnapshot == HANDLE(-1): return
  var pe32: PROCESSENTRY32W
  pe32.dwSize = DWORD(sizeof(pe32))
  if Process32FirstW(hSnapshot, addr pe32) != 0:
    while true:
      result &= "  - " & wcharToString(pe32.szExeFile) & " (PID: " & $pe32.th32ProcessID & ")\n"
      if Process32NextW(hSnapshot, addr pe32) == 0: break
  discard CloseHandle(hSnapshot)

proc getAntivirus(): string =
  let paths = [
    ("SOFTWARE\\Microsoft\\Windows Defender", "Windows Defender"),
    ("SOFTWARE\\Avast Software", "Avast"),
    ("SOFTWARE\\ESET", "ESET"),
    ("SOFTWARE\\KasperskyLab", "Kaspersky"),
    ("SOFTWARE\\McAfee", "McAfee"),
    ("SOFTWARE\\Symantec", "Symantec"),
    ("SOFTWARE\\Bitdefender", "Bitdefender")
  ]
  for (regPath, name) in paths:
    var hKey: HKEY
    if RegOpenKeyEx(HKEY_LOCAL_MACHINE, regPath, 0, KEY_READ, addr hKey) == ERROR_SUCCESS:
      result &= "  - " & name & "\n"
      RegCloseKey(hKey)

proc getSystemInfo*(): JsonNode =
  result = %*{
    "timestamp": getTime().format("yyyy-MM-dd HH:mm:ss"),
    "hostname": getEnv("COMPUTERNAME"),
    "os": getOSInfo(),
    "user":getEnv("USERNAME"),
    "hardware": getHardwareInfo(),
    "ip": getIpInfo(),
    "Mac":getMacAddress(),
    "software": getInstalledSoftware(),
    "processes": getActiveProcesses(),
    "antivirus": getAntivirus()
  }

when isMainModule:
  let info = getSystemInfo()
  let outputFile = getTempDir() & "system_info_" & $getCurrentProcessId() & ".json"
  writeFile(outputFile, pretty(info))
  echo "[+] Sauvegardé: ", outputFile