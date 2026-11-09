param(
  [string]$BuildDirectory = "build/windows/x64/runner/Release"
)

$ErrorActionPreference = "Stop"

$expectedExe = Join-Path $BuildDirectory "in4up.exe"
if (Test-Path -LiteralPath $expectedExe -PathType Leaf) {
  $exe = Get-Item -LiteralPath $expectedExe
} else {
  $exe = Get-ChildItem -Path "build/windows" -Recurse -Filter "in4up.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
}
if (-not $exe) {
  throw "Windows build has no in4up.exe under '$BuildDirectory'."
}

$backend = Join-Path $exe.DirectoryName "in4up_ai_native.dll"
if (-not (Test-Path -LiteralPath $backend -PathType Leaf)) {
  throw "Native Gemma backend missing beside in4up.exe: $backend"
}

$file = Get-Item -LiteralPath $backend
if ($file.Length -lt 65536) {
  throw "Native Gemma backend is unexpectedly small ($($file.Length) bytes): $backend"
}

$dumpbin = Get-Command "dumpbin.exe" -ErrorAction Stop
$exports = & $dumpbin.Source /exports $backend 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "dumpbin could not inspect the native Gemma DLL:`n$exports"
}

$requiredSymbols = @(
  "in4up_ai_create",
  "in4up_ai_generate",
  "in4up_ai_free_string",
  "in4up_ai_destroy"
)
foreach ($symbol in $requiredSymbols) {
  if ($exports -notmatch "\b$([regex]::Escape($symbol))\b") {
    throw "Native Gemma DLL does not export '$symbol': $backend"
  }
}

$dependencies = & $dumpbin.Source /dependents $backend 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "dumpbin could not inspect the native Gemma DLL dependencies:`n$dependencies"
}
if ($dependencies -match "(?i)\b(?:llama|ggml[^\s]*)\.dll\b") {
  throw "Native Gemma DLL depends on a separate llama/ggml DLL; the release bundle must be self-contained:`n$dependencies"
}

Write-Host "Verified native Gemma backend: $backend ($($file.Length) bytes)"
Write-Host "Required FFI exports are present: $($requiredSymbols -join ', ')"
