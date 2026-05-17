@echo off
echo Compilation de Venom...
nim c -d:release --app:gui -o:Venom.exe src/main.nim
echo Termine.
pause
