param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcLessonBuild = Join-Path $smcRepo 'build/教学/第19讲_从公式阅读最小C++实现'
$smcExecutableBuild = Join-Path $smcRepo 'build/lesson19_host'
New-Item -ItemType Directory -Force -Path $smcLessonBuild,$smcExecutableBuild | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @('main/ALG_SMC.cpp','main/ALG_SMC.hpp','examples/position_formula_walkthrough.cpp',
    'tests/test_support.hpp') | ForEach-Object { Join-Path $smcRepo $_ }
$smcBeforeHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcLessonBuild '主机运行报告.json'
@{passed=$false;hashes=$smcBeforeHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcExecutable = Join-Path $smcExecutableBuild 'position_formula_walkthrough.exe'
$smcArguments = @('-std=c++11','-O2','-Wall','-Wextra','-fno-fast-math','-ffp-contract=off',
    (Join-Path $smcRepo 'examples/position_formula_walkthrough.cpp'),(Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcExecutable)
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcArguments
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 19 compile failed' }
    $smcOutput = @(& $smcExecutable)
    if ($LASTEXITCODE -ne 0 -or $smcOutput.Count -ne 7) { throw 'Lesson 19 expected six successful calculations' }
    [System.IO.File]::WriteAllLines((Join-Path $smcLessonBuild '真实C++六点输出.csv'),[string[]]$smcOutput,[System.Text.UTF8Encoding]::new($false))
    $smcAfterHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBeforeHashes.Count; $smcIndex++) {
        if ($smcBeforeHashes[$smcIndex].Hash -ne $smcAfterHashes[$smcIndex].Hash) { throw 'Lesson 19 source changed during example' }
    }
    @{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);
        cxx_standard=11;compile_arguments=$smcArguments;hashes=$smcAfterHashes;
        production_sources_modified=$false;production_cpp_executed=$true;reference_cpp_executed=$false;
        controller_call_count=6;plant_state_advanced=$false;hardware_commands_sent=$false;
        parameter_source='既有 test_support.hpp Config 的教学参数；本讲输出范围 ±3 A'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
    Write-Output 'Lesson 19: six hand-checkable calls to the existing production controller completed.'
} finally { $env:PATH = $smcSavedPath }
