param([Parameter(Mandatory=$true)][string]$InputCsv,[string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcOut = Join-Path $smcRepo 'build/教学/第23讲_速度误差累计与速度控制'
$smcNative = Join-Path $smcRepo 'build/lesson23_host'
New-Item -ItemType Directory -Force -Path $smcOut,$smcNative | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @('main/ALG_SMC.hpp','main/ALG_SMC.cpp','examples/velocity_verification_runner.cpp') |
    ForEach-Object { Join-Path $smcRepo $_ }
$smcBefore = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcOut '主机运行报告.json'
@{passed=$false;hashes=$smcBefore} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcExecutable = Join-Path $smcNative 'velocity_verification_runner.exe'
$smcArguments = @('-std=c++11','-O2','-Wall','-Wextra','-Wpedantic','-Werror','-fno-fast-math','-ffp-contract=off',
    '-I',(Join-Path $smcRepo 'main'),(Join-Path $smcRepo 'examples/velocity_verification_runner.cpp'),
    (Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcExecutable)
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcArguments
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 23 compile failed' }
    $smcInput = Join-Path $smcNative 'input.csv'
    $smcPoints = Join-Path $smcNative 'points.csv'
    Copy-Item -LiteralPath $InputCsv -Destination $smcInput -Force
    $smcPointLog = @(& $smcExecutable points $smcInput $smcPoints)
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 23 hand sequence failed' }
    $smcLoopLog = @(& $smcExecutable simulate $smcNative '1')
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 23 selected constant-speed case failed' }
    $smcLoop = Join-Path $smcNative 'velocity01.csv'
    if ([System.IO.File]::ReadAllLines($smcPoints).Length -ne 7 -or
        [System.IO.File]::ReadAllLines($smcLoop).Length -ne 8001) { throw 'Unexpected lesson 23 rows' }
    Copy-Item -LiteralPath $smcPoints -Destination (Join-Path $smcOut '真实C++六点输出.csv') -Force
    Copy-Item -LiteralPath $smcLoop -Destination (Join-Path $smcOut '真实C++恒速闭环.csv') -Force
    @($smcPointLog)+@($smcLoopLog) | Set-Content -LiteralPath (Join-Path $smcOut '主机运行.log') -Encoding UTF8
    $smcAfter = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBefore.Count; $smcIndex++) {
        if ($smcBefore[$smcIndex].Hash -ne $smcAfter[$smcIndex].Hash) { throw 'Source changed during lesson 23' }
    }
    @{passed=$true;lesson=23;compiler_version=(& $Compiler --version | Select-Object -First 1);
        cxx_standard=11;compile_arguments=$smcArguments;hashes=$smcAfter;
        shared_input_sha256=(Get-FileHash -LiteralPath $smcInput -Algorithm SHA256).Hash;
        point_count=6;scenario=1;closed_calc_count=8000;production_cpp_executed=$true;
        production_sources_modified=$false;existing_runner_modified=$false;
        reference_cpp_executed=$false;hardware_commands_sent=$false;
        parameter_source='六点沿用既有速度验证的明确点；闭环沿用既有恒速案例1，均为教学假设'} |
        ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
    Write-Output 'Lesson 23: six sequential points and the existing 8000-step constant-speed case completed.'
} finally { $env:PATH = $smcSavedPath }
