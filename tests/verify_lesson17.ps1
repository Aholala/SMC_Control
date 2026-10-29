param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcLessonBuild = Join-Path $smcRepo 'build/教学/第17讲_最小普通位置闭环'
$smcExecutableBuild = Join-Path $smcRepo 'build/lesson17_host'
New-Item -ItemType Directory -Force -Path $smcLessonBuild,$smcExecutableBuild | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @('main/ALG_SMC.cpp','main/ALG_SMC.hpp','examples/verification_runner.cpp') |
    ForEach-Object { Join-Path $smcRepo $_ }
$smcBeforeHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcReportPath = Join-Path $smcLessonBuild '主机闭环报告.json'
@{passed=$false;hashes=$smcBeforeHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
$smcExecutable = Join-Path $smcExecutableBuild 'verification_runner.exe'
$smcArguments = @('-std=c++11','-O2','-Wall','-Wextra','-fno-fast-math','-ffp-contract=off',
    '-I',(Join-Path $smcRepo 'main'),(Join-Path $smcRepo 'examples/verification_runner.cpp'),
    (Join-Path $smcRepo 'main/ALG_SMC.cpp'),'-o',$smcExecutable)
$smcRunArguments = @('simulate',$smcExecutableBuild,'1')
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcArguments
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 17 compile failed' }
    $smcRunLog = @(& $smcExecutable @smcRunArguments)
    if ($LASTEXITCODE -ne 0) { throw 'Lesson 17 selected closed loop failed' }
    $smcSourceCsv = Join-Path $smcExecutableBuild 'case01.csv'
    $smcRows = [System.IO.File]::ReadAllLines($smcSourceCsv).Length - 1
    if ($smcRows -ne 8000) { throw 'Lesson 17 expected exactly 8000 controller calculations' }
    Copy-Item -LiteralPath $smcSourceCsv -Destination (Join-Path $smcLessonBuild '真实C++闭环.csv') -Force
    $smcRunLog | Set-Content -LiteralPath (Join-Path $smcLessonBuild 'C++闭环运行.log') -Encoding UTF8
    $smcAfterHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBeforeHashes.Count; $smcIndex++) {
        if ($smcBeforeHashes[$smcIndex].Hash -ne $smcAfterHashes[$smcIndex].Hash) { throw 'Lesson 17 source changed during experiment' }
    }
    @{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);
        cxx_standard=11;compile_arguments=$smcArguments;run_arguments=$smcRunArguments;hashes=$smcAfterHashes;
        production_sources_modified=$false;existing_runner_modified=$false;production_cpp_executed=$true;
        plant_state_advanced=$true;controller_output_drives_plant=$true;hardware_commands_sent=$false;
        reference_cpp_executed=$false;scenario=1;controller_call_count=$smcRows;dt_s=.001;duration_s=8;
        parameters=@{input_gain=3;surface_gain=4;reaching_gain=6;switching_gain=2;boundary_width=.25;
            output_min=-4;output_max=4;initial_position=-.2;initial_rate=0;target=.5};
        parameter_source='沿用现有 verification_runner.cpp 的静止目标教学案例，非实测'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcReportPath -Encoding UTF8
    Write-Output 'Lesson 17: existing static-target case, 8000 real C++ outputs driving the assumed plant.'
} finally { $env:PATH = $smcSavedPath }
