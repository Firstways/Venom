import os, times, strutils

proc extractBrowserData() =
  let hackBrowser = getCurrentDir() / "hack-browser-data.exe"
  # Changement : dossier sur le Bureau au lieu de %TEMP%
  let outputDir = getEnv("USERPROFILE") / "Desktop" / "browser_data_export"
  
  if not fileExists(hackBrowser):
    echo "[-] hack-browser-data.exe non trouvé"
    return
  
  # Créer le dossier s'il n'existe pas
  if not dirExists(outputDir):
    createDir(outputDir)
  
  # Nettoyer l'ancien contenu (optionnel)
  for file in walkFiles(outputDir / "*"):
    removeFile(file)
  
  echo "[*] Extraction des données Chrome vers : ", outputDir
  
  # Utiliser un fichier batch pour éviter les problèmes d'espaces
  let batchFile = getTempDir() / "run_hack.bat"
  let batchContent = "@echo off\n" &
                    "cd /d \"" & getCurrentDir() & "\"\n" &
                    "\"" & hackBrowser & "\" -b chrome -f json --dir \"" & outputDir & "\"\n"
  writeFile(batchFile, batchContent)
  
  discard execShellCmd("\"" & batchFile & "\"")
  sleep(5000)
  
  removeFile(batchFile)
  
  if dirExists(outputDir):
    echo "[+] Extraction terminée !"
    echo "[+] Dossier : ", outputDir
    echo ""
    echo "Fichiers générés :"
    for file in walkFiles(outputDir / "*.json"):
      let size = getFileSize(file) div 1024
      echo "  - ", extractFilename(file), " (", size, " KB)"
    
    # Créer un fichier résumé dans le même dossier
    let summaryFile = outputDir / "summary.txt"
    var f = open(summaryFile, fmWrite)
    f.writeLine("EXTRACTION COMPLETE - " & getTime().format("yyyy-MM-dd HH:mm:ss"))
    f.writeLine(repeat("=", 60))
    f.close()
    
    echo ""
    echo "[*] Ouvre le dossier : ", outputDir
  else:
    echo "[-] Échec de l'extraction"

when isMainModule:
  extractBrowserData()