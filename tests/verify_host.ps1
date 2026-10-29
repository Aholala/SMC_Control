param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcCmake = (Get-Command cmake -ErrorAction Stop).Source
$smcNinja = (Get-Command ninja -ErrorAction Stop).Source
$Compiler = $Compiler.Replace('\','/')
$smcNinja = $smcNinja.Replace('\','/')
$smcCtest = Join-Path (Split-Path -Parent $smcCmake) 'ctest.exe'
$smcBuild = Join-Path $smcRepo 'build/host'
New-Item -ItemType Directory -Path $smcBuild -Force | Out-Null
$smcReportPath = Join-Path $smcBuild 'host_verification.json'
'{"passed":false}' | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcHashes = @(Get-FileHash -LiteralPath (Join-Path $smcRepo 'main/ALG_SMC.hpp'),(Join-Path $smcRepo 'main/ALG_SMC.cpp') -Algorithm SHA256 | Select-Object Path,Hash)
@{passed=$false;hashes=$smcHashes} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $smcCmake --fresh -S $smcRepo -B $smcBuild -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DSMC_BUILD_EXAMPLES=ON "-DCMAKE_CXX_COMPILER=$Compiler" "-DCMAKE_MAKE_PROGRAM=$smcNinja"
    if ($LASTEXITCODE -ne 0) { throw 'Host configure failed' }
    & $smcCmake --build $smcBuild --parallel 2
    if ($LASTEXITCODE -ne 0) { throw 'Host build failed' }
    $smcOutput = & $smcCtest --test-dir $smcBuild --output-on-failure
    $smcExit = $LASTEXITCODE
    $smcOutput | Write-Output
    $smcOutput | Set-Content -LiteralPath (Join-Path $smcBuild 'host_tests.log') -Encoding UTF8
    if ($smcExit -ne 0) { throw 'Host tests failed' }
    & (Join-Path $smcBuild 'position_example.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Position example failed' }
    & (Join-Path $smcBuild 'velocity_example.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Velocity example failed' }
    $smcCount = [regex]::Match(($smcOutput -join "`n"), 'out of (\d+)').Groups[1].Value
    if (!$smcCount -or [int]$smcCount -ne 13) { throw 'Unexpected test count' }
    $smcReport = @{passed=$true;test_count=[int]$smcCount;grid_points=540;velocity_grid_points=1620;extension_grid_cases=504;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);cxx_standard=11;hashes=$smcHashes;firmware_linked=$false;hardware_tested=$false}
    $smcReport | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
} finally { $env:PATH = $smcSavedPath }
