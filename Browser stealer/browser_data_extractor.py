import os
import json

output_dir = os.environ['TEMP'] + r"\browser_data"
cookies_file = os.path.join(output_dir, "chrome_default_cookie.json")

if os.path.exists(cookies_file):
    with open(cookies_file, 'r', encoding='utf-8') as f:
        cookies = json.load(f)
    
    print(f"[+] {len(cookies)} cookies extraits avec succès !")
    print("=" * 60)
    
    # Afficher les 10 premiers cookies
    for i, cookie in enumerate(cookies[:10]):
        print(f"\n[{i+1}] {cookie.get('domain', 'N/A')}")
        print(f"    Nom: {cookie.get('name', 'N/A')}")
        print(f"    Valeur: {cookie.get('value', 'N/A')[:50]}..." if len(cookie.get('value', '')) > 50 else f"    Valeur: {cookie.get('value', 'N/A')}")
        print(f"    Sécurisé: {cookie.get('secure', False)}")
        print(f"    HttpOnly: {cookie.get('httpOnly', False)}")
    
    # Sauvegarder dans un fichier lisible
    output_file = os.environ['TEMP'] + r"\chrome_cookies_clean.txt"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("COOKIES EXTRACTED FROM CHROME\n")
        f.write("=" * 80 + "\n\n")
        
        for cookie in cookies:
            f.write(f"Domain: {cookie.get('domain', 'N/A')}\n")
            f.write(f"Name: {cookie.get('name', 'N/A')}\n")
            f.write(f"Value: {cookie.get('value', 'N/A')}\n")
            f.write(f"Path: {cookie.get('path', 'N/A')}\n")
            f.write(f"Secure: {cookie.get('secure', False)}\n")
            f.write(f"HttpOnly: {cookie.get('httpOnly', False)}\n")
            f.write("-" * 40 + "\n")
    
    print(f"\n[+] Cookies sauvegardés dans: {output_file}")
    
else:
    print("[-] Fichier non trouvé")
    
    # Lister les fichiers disponibles
    if os.path.exists(output_dir):
        files = os.listdir(output_dir)
        print(f"[*] Fichiers disponibles dans {output_dir}:")
        for f in files:
            print(f"    - {f}") 