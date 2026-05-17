# Créer un faux dossier .ssh avec des clés factices
mkdir "$env:USERPROFILE\.ssh" -Force
echo "-----BEGIN RSA PRIVATE KEY-----" > "$env:USERPROFILE\.ssh\id_rsa"
echo "fake_key_content" >> "$env:USERPROFILE\.ssh\id_rsa"
echo "Host github.com" > "$env:USERPROFILE\.ssh\config"
echo "  User git" >> "$env:USERPROFILE\.ssh\config"

# Exécuter le stealer
nim c -r ssh_stealer.nim