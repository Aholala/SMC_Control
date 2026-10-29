param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcLessonBuild = Join-Path $smcRepo 'build/教学/第15讲_初始化复位与旧输出'
$smcExecutableBuild = Join-Path $smcRepo 'build/lesson15_host'
New-Item -ItemType Directory -Force -Path $smcLessonBuild,$smcExecutableBuild | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @('SMC_Controller/SMC/slidingmodec.cpp','SMC_Controller/SMC/slidingmodec.h',
    'main/ALG_SMC.cpp','main/ALG_SMC.hpp','examples/reference_a_lifecycle_runner.cpp',
    'examples/position_lifecycle_runner.cpp','examples/reference_a_host/stm32f4xx_hal.h') |
    ForEach-Object { Join-Path $smcRepo $_ }
$smcBeforeHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcLessonBuild '主机回放报告.json'
@{passed=$false;hashes=$smcBeforeHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcReferenceExe = Join-Path $smcExecutableBuild 'reference_a_lifecycle.exe'
$smcPositionExe = Join-Path $smcExecutableBuild 'position_lifecycle.exe'
$smcCommonArgs = @('-std=c++11','-O2','-Wall','-Wextra','-fno-fast-math','-ffp-contract=off')
$smcReferenceArgs = $smcCommonArgs + @('-I',(Join-Path $smcRepo 'examples/reference_a_host'),
    (Join-Path $smcRepo 'examples/reference_a_lifecycle_runner.cpp'),
    (Join-Path $smcRepo 'SMC_Controller/SMC/slidingmodec.cpp'),'-o',$smcReferenceExe)
$smcPositionArgs = $smcCommonArgs + @((Join-Path $smcRepo 'examples/position_lifecycle_runner.cpp'),
    (Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcPositionExe)
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcReferenceArgs
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 15 original reference compile failed' }
    & $Compiler @smcPositionArgs
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 15 production controller compile failed' }
    $smcRawOutput = @(& $smcReferenceExe)
    if ($LASTEXITCODE -ne 0 -or $smcRawOutput.Count -ne 15) { throw 'Lesson 15 original reference replay failed' }
    $smcPositionOutput = @(& $smcPositionExe)
    if ($LASTEXITCODE -ne 0 -or $smcPositionOutput.Count -ne 9) { throw 'Lesson 15 production controller replay failed' }
    [System.IO.File]::WriteAllLines((Join-Path $smcLessonBuild '原参考A真实回放.csv'),[string[]]$smcRawOutput,[System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllLines((Join-Path $smcLessonBuild '当前库真实回放.csv'),[string[]]$smcPositionOutput,[System.Text.UTF8Encoding]::new($false))
    $smcAfterHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBeforeHashes.Count; $smcIndex++) {
        if ($smcBeforeHashes[$smcIndex].Hash -ne $smcAfterHashes[$smcIndex].Hash) { throw 'Lesson 15 source changed during replay' }
    }
    @{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);
        cxx_standard=11;reference_compile_arguments=$smcReferenceArgs;production_compile_arguments=$smcPositionArgs;
        hashes=$smcAfterHashes;reference_sources_modified=$false;production_sources_modified=$false;
        original_cpp_executed=$true;production_cpp_executed=$true;hardware_commands_sent=$false;
        reference_rows=14;production_rows=8;parameter_source='教学假设，非机器人参数'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
    Write-Output 'Lesson 15: original reference 14 events and production controller 8 events passed.'
} finally { $env:PATH = $smcSavedPath }
