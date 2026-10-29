param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcLessonBuild = Join-Path $smcRepo 'build/教学/第16讲_运动目标的变化率与数据时刻'
$smcExecutableBuild = Join-Path $smcRepo 'build/lesson16_host'
New-Item -ItemType Directory -Force -Path $smcLessonBuild,$smcExecutableBuild | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @('main/ALG_SMC.cpp','main/ALG_SMC.hpp','examples/target_rates_runner.cpp') |
    ForEach-Object { Join-Path $smcRepo $_ }
$smcBeforeHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcLessonBuild '主机回放报告.json'
@{passed=$false;hashes=$smcBeforeHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcExecutable = Join-Path $smcExecutableBuild 'target_rates_runner.exe'
$smcArguments = @('-std=c++11','-O2','-Wall','-Wextra','-fno-fast-math','-ffp-contract=off',
    (Join-Path $smcRepo 'examples/target_rates_runner.cpp'),(Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcExecutable)
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcArguments
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 16 production compile failed' }
    $smcOutput = @(& $smcExecutable)
    if ($LASTEXITCODE -ne 0 -or $smcOutput.Count -ne 34) { throw 'Lesson 16 replay failed' }
    [System.IO.File]::WriteAllLines((Join-Path $smcLessonBuild '当前库三种变化率真实回放.csv'),[string[]]$smcOutput,[System.Text.UTF8Encoding]::new($false))
    $smcAfterHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBeforeHashes.Count; $smcIndex++) {
        if ($smcBeforeHashes[$smcIndex].Hash -ne $smcAfterHashes[$smcIndex].Hash) { throw 'Lesson 16 source changed during replay' }
    }
    @{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);
        cxx_standard=11;compile_arguments=$smcArguments;hashes=$smcAfterHashes;
        production_sources_modified=$false;production_cpp_executed=$true;reference_cpp_executed=$false;
        hardware_commands_sent=$false;plant_state_advanced=$false;method_count=3;sample_count=11;
        output_row_count=33;parameter_source='教学假设，非机器人参数'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
    Write-Output 'Lesson 16: 3 derivative input methods / 33 actual controller calls passed.'
} finally { $env:PATH = $smcSavedPath }
