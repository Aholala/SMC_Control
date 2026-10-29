param([Parameter(Mandatory=$true)][string]$InputCsv,
      [Parameter(Mandatory=$true)][string]$OutputDirectory,
      [string]$Scenarios='1,2,3,4,5,6,7,8',[string]$Compiler=$env:SMC_CXX)
$ErrorActionPreference='Stop'
$smcRepo=Split-Path -Parent $PSScriptRoot
$smcNative=Join-Path $smcRepo 'build/extensions_host'
New-Item -ItemType Directory -Force -Path $smcNative,$OutputDirectory | Out-Null
if (!$Compiler) { $Compiler=(Get-Command g++ -ErrorAction Stop).Source }
$smcPaths=@('main/ALG_SMC.hpp','main/ALG_SMC.cpp','examples/extensions_verification_runner.cpp') | ForEach-Object {Join-Path $smcRepo $_}
$smcBefore=@(Get-FileHash -LiteralPath $smcPaths -Algorithm SHA256 | Select-Object Path,Hash)
$smcReport=Join-Path $OutputDirectory '主机运行报告.json'
@{passed=$false;hashes=$smcBefore} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReport -Encoding UTF8
$smcExe=Join-Path $smcNative 'extensions_verification_runner.exe'
$smcCompile=@('-std=c++11','-O2','-Wall','-Wextra','-Wpedantic','-Werror','-fno-fast-math','-ffp-contract=off',
    '-I',(Join-Path $smcRepo 'main'),(Join-Path $smcRepo 'examples/extensions_verification_runner.cpp'),
    (Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcExe)
$smcSavedPath=$env:PATH
try {
    $env:PATH=(Split-Path -Parent $Compiler)+';'+$env:PATH
    & $Compiler @smcCompile
    if ($LASTEXITCODE -ne 0) {throw 'Extension compile failed'}
    $smcInput=Join-Path $smcNative 'input.csv'; $smcPoints=Join-Path $smcNative 'points.csv'
    Copy-Item -LiteralPath $InputCsv -Destination $smcInput -Force
    $smcLog=@(& $smcExe points $smcInput $smcPoints)
    if ($LASTEXITCODE -ne 0) {throw 'Extension point calculation failed'}
    $smcPointCount=[System.IO.File]::ReadAllLines($smcInput).Length-1
    if ([System.IO.File]::ReadAllLines($smcPoints).Length-1 -ne $smcPointCount) {throw 'Point count mismatch'}
    Copy-Item -LiteralPath $smcPoints -Destination (Join-Path $OutputDirectory '真实C++公式点.csv') -Force
    $smcSelected=@($Scenarios.Split(',') | ForEach-Object {[int]$_})
    foreach($smcScenario in $smcSelected) {
        if ($smcScenario -lt 1 -or $smcScenario -gt 8) {throw 'Unknown scenario'}
        $smcLog+=@(& $smcExe simulate $smcNative $smcScenario)
        if ($LASTEXITCODE -ne 0) {throw "Extension scenario $smcScenario failed"}
        $smcCsv=Join-Path $smcNative ('extension{0:d2}.csv' -f $smcScenario)
        if ([System.IO.File]::ReadAllLines($smcCsv).Length -ne 8001) {throw 'Unexpected loop length'}
        Copy-Item -LiteralPath $smcCsv -Destination (Join-Path $OutputDirectory ('案例{0:d2}_真实C++.csv' -f $smcScenario)) -Force
    }
    $smcAfter=@(Get-FileHash -LiteralPath $smcPaths -Algorithm SHA256 | Select-Object Path,Hash)
    for($smcI=0;$smcI -lt $smcBefore.Count;$smcI++) {if($smcBefore[$smcI].Hash -ne $smcAfter[$smcI].Hash) {throw 'Source changed during verification'}}
    $smcLog | Set-Content -LiteralPath (Join-Path $OutputDirectory '主机运行.log') -Encoding UTF8
    @{passed=$true;compiler_version=(& $Compiler --version | Select-Object -First 1);cxx_standard=11;
        hashes=$smcAfter;compile_arguments=$smcCompile;scenarios=$smcSelected;point_count=$smcPointCount;
        input_sha256=(Get-FileHash -LiteralPath $smcInput -Algorithm SHA256).Hash;
        production_cpp_executed=$true;reference_cpp_executed=$false;hardware_tested=$false;firmware_linked=$false} |
        ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $smcReport -Encoding UTF8
    Write-Output "Extension points=$smcPointCount scenarios=$Scenarios passed."
} finally {$env:PATH=$smcSavedPath}
