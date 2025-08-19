# zip-kits.ps1 — zip each folder inside .\kits as <folder>.zip (includes the folder as the top-level entry)
# Works on Windows PowerShell 5+ and PowerShell 7+
param([string]$KitsDir = "kits")

if (-not (Test-Path -LiteralPath $KitsDir -PathType Container)) {
  Write-Error "Directory '$KitsDir' not found."
  exit 1
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$dirs = Get-ChildItem -LiteralPath $KitsDir -Directory
if ($dirs.Count -eq 0) {
  Write-Host "No subfolders found in '$KitsDir'."
  exit 0
}

foreach ($d in $dirs) {
  $name = $d.Name
  $src  = Join-Path $KitsDir $name
  $dst  = Join-Path $KitsDir "$name.zip"

  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }

  # Create the zip; last arg $true = include the folder itself as the top-level entry
  [System.IO.Compression.ZipFile]::CreateFromDirectory(
    $src, $dst, [System.IO.Compression.CompressionLevel]::Optimal, $true
  )

  Write-Host "Zipped: $name -> $dst"
}
