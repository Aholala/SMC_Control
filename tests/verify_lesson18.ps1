param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcLessonBuild = Join-Path $smcRepo 'build/教学/第18讲_参考B与目标加速度项'
$smcExecutableBuild = Join-Path $smcRepo 'build/lesson18_host'
New-Item -ItemType Directory -Force -Path $smcLessonBuild,$smcExecutableBuild | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @('main/ALG_SMC.cpp','main/ALG_SMC.hpp','examples/acceleration_term_runner.cpp',
    'Sliding/code/Sliding.cpp','Sliding/code/Sliding.hpp','Sliding/Documentation/SMC_Doc.tex') |
    ForEach-Object { Join-Path $smcRepo $_ }
$smcBeforeHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcLessonBuild '主机对照报告.json'
@{passed=$false;hashes=$smcBeforeHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcExecutable = Join-Path $smcExecutableBuild 'acceleration_term_runner.exe'
$smcRawCsv = Join-Path $smcExecutableBuild 'acceleration_term.csv'
$smcArguments = @('-std=c++11','-O2','-Wall','-Wextra','-fno-fast-math','-ffp-contract=off',
    (Join-Path $smcRepo 'examples/acceleration_term_runner.cpp'),(Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcExecutable)
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcArguments
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 18 compile failed' }
    $smcRunLog = @(& $smcExecutable $smcRawCsv)
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 18 controlled comparison failed' }
    $smcRowCount = [System.IO.File]::ReadAllLines($smcRawCsv).Length - 1
    if ($smcRowCount -ne 24000) { throw 'Lesson 18 expected 24000 controller calculations' }
    Copy-Item -LiteralPath $smcRawCsv -Destination (Join-Path $smcLessonBuild '真实C++两式闭环.csv') -Force
    $smcRunLog | Set-Content -LiteralPath (Join-Path $smcLessonBuild 'C++对照运行.log') -Encoding UTF8
    $smcAfterHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBeforeHashes.Count; $smcIndex++) {
        if ($smcBeforeHashes[$smcIndex].Hash -ne $smcAfterHashes[$smcIndex].Hash) { throw 'Lesson 18 source changed during comparison' }
    }
    @{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);
        cxx_standard=11;compile_arguments=$smcArguments;hashes=$smcAfterHashes;
        production_sources_modified=$false;reference_sources_modified=$false;production_cpp_executed=$true;
        reference_b_cpp_executed=$false;hardware_commands_sent=$false;controller_output_drives_plant=$true;
        target_case_count=3;formula_count=2;steps_per_loop=4000;controller_call_count=24000;
        dt_s=.001;duration_per_loop_s=4;parameter_source='沿用第17讲控制参数；目标与匹配初值为教学假设'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
    Write-Output 'Lesson 18: 3 targets / 2 formulas / 24000 actual production controller calls passed.'
} finally { $env:PATH = $smcSavedPath }
