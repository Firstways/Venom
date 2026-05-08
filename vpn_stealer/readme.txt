# Créer un dossier factice
mkdir "$env:USERPROFILE\OpenVPN\config" -Force

# Créer un faux fichier .ovpn
@"
client
dev tun
proto udp
remote vpn.example.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
auth-user-pass
"@ > "$env:USERPROFILE\OpenVPN\config\example.ovpn"