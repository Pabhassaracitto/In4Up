# PowerShell script để sửa tất cả include paths
$files = Get-ChildItem -Path "src" -Filter "*.cpp" -Recurse

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    
    # Thay thế các pattern include cũ
    $content = $content -replace '#include\s+"\.\.\/\.\.\/include\/UltraTimeStretch\.h"', '#include "UltraTimeStretch.h"'
    $content = $content -replace '#include\s+"\.\.\/\.\.\/include\/UltraTimeStretch_V2_Enhancements\.h"', '#include "UltraTimeStretch_V2_Enhancements.h"'
    $content = $content -replace '#include\s+"\.\.\/\.\.\/include\/SIMDOptimizations\.h"', '#include "SIMDOptimizations.h"'
    
    Set-Content -Path $file.FullName -Value $content -NoNewline
    Write-Host "Fixed: $($file.FullName)"
}

Write-Host "Done! All includes fixed."