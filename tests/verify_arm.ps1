param([string]$Compiler)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
if (!$Compiler) { $Compiler = (Get-Command arm-none-eabi-g++ -ErrorAction Stop).Source }
$smcAr = Join-Path (Split-Path -Parent $Compiler) 'arm-none-eabi-ar.exe'
$smcNm = Join-Path (Split-Path -Parent $Compiler) 'arm-none-eabi-nm.exe'
$smcBuild = Join-Path $smcRepo 'build/arm'
New-Item -ItemType Directory -Path $smcBuild -Force | Out-Null
$smcHashes = @(Get-FileHash -LiteralPath (Join-Path $smcRepo 'main/ALG_SMC.hpp'),(Join-Path $smcRepo 'main/ALG_SMC.cpp') -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcBuild 'verification.json'
@{passed=$false;hashes=$smcHashes} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcTargets = @(@{Name='m4';Cpu='cortex-m4';Fpu='fpv4-sp-d16'},@{Name='m7';Cpu='cortex-m7';Fpu='fpv5-d16'})
$smcResults = @()
foreach ($smcTarget in $smcTargets) {
    $smcOut = Join-Path $smcBuild $smcTarget.Name
    New-Item -ItemType Directory -Path $smcOut -Force | Out-Null
    $smcObject = Join-Path $smcOut 'ALG_SMC.o'
    & $Compiler -std=c++11 -O2 -Wall -Wextra -Wpedantic -Werror -ffp-contract=off -fno-fast-math -fno-exceptions -fno-rtti -mthumb -mfloat-abi=hard "-mcpu=$($smcTarget.Cpu)" "-mfpu=$($smcTarget.Fpu)" -I (Join-Path $smcRepo 'main') -c (Join-Path $smcRepo 'main/ALG_SMC.cpp') -o $smcObject
    if ($LASTEXITCODE -ne 0) { throw 'ARM compile failed' }
    $smcArchive = Join-Path $smcOut 'libsmc.a'
    # 归档只有一个固定对象，不引入示例或测试。
    & $smcAr rcs $smcArchive $smcObject
    if ($LASTEXITCODE -ne 0) { throw 'ARM archive failed' }
    $smcUndefined = & $smcNm -u $smcObject
    if ($LASTEXITCODE -ne 0) { throw 'ARM symbol inspection failed' }
    ($smcUndefined -join "`n") | Set-Content -LiteralPath (Join-Path $smcOut 'undefined_symbols.txt') -Encoding UTF8
    if (($smcUndefined -join "`n") -match 'HAL_|osDelay|malloc|operator new|_Zn[aw]') { throw 'Unexpected hardware or allocator symbol' }
    $smcResults += @{cpu=$smcTarget.Cpu;fpu=$smcTarget.Fpu;float_abi='hard';archive=$smcArchive;object_bytes=(Get-Item -LiteralPath $smcObject).Length;passed=$true}
    Write-Output "ARM_LIBRARY_PASS $($smcTarget.Name)"
}
@{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);targets=$smcResults;hashes=$smcHashes;firmware_linked=$false;hardware_tested=$false} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
