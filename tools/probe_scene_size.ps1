Add-Type -AssemblyName System.Drawing
$paths = @(
  'C:\Users\slimboiliu\TheTiny-PipSaga\assets\scene\test',
  'C:\Users\slimboiliu\TheTiny-PipSaga\assets\player\test'
)
foreach ($p in $paths) {
  Get-ChildItem $p -Filter *.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    Write-Host ("{0}`t{1}x{2}" -f $_.Name, $img.Width, $img.Height)
    $img.Dispose()
  }
}
