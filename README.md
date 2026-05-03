# Venom
## Compilation 
** version.cpp**
```cmd
i686-w64-mingw32-g++ -shared version.cpp version.def -luser32 -o version.dll
```
**test.cpp**
```cmd
g++ test.cpp -o test.exe   
```
** test des exports de fonction **
```cmd
objdump -p version.dll
```
