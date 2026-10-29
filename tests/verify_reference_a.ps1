param([string]$Compiler = $env:SMC_CXX)
$ErrorActionPreference = 'Stop'
$smcRepo = Split-Path -Parent $PSScriptRoot
$smcLessonBuild = Join-Path $smcRepo 'build/教学/第14讲_原参考代码与公式逐句对照'
New-Item -ItemType Directory -Force -Path $smcLessonBuild | Out-Null
if (!$Compiler) { $Compiler = (Get-Command g++ -ErrorAction Stop).Source }
$smcSources = @(
    (Join-Path $smcRepo 'SMC_Controller/SMC/slidingmodec.cpp'),
    (Join-Path $smcRepo 'SMC_Controller/SMC/slidingmodec.h'),
    (Join-Path $smcRepo 'examples/reference_a_runner.cpp'),
    (Join-Path $smcRepo 'examples/reference_a_host/stm32f4xx_hal.h')
)
$smcBeforeHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
$smcBuildReportPath = Join-Path $smcLessonBuild '原参考A主机编译报告.json'
@{passed=$false;hashes=$smcBeforeHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcBuildReportPath -Encoding UTF8
$smcExecutableBuild = Join-Path $smcRepo 'build/reference_a_host'
New-Item -ItemType Directory -Force -Path $smcExecutableBuild | Out-Null
$smcExecutable = Join-Path $smcExecutableBuild 'reference_a_runner.exe'
$smcCsv = Join-Path $smcLessonBuild '原参考A真实C++输出.csv'
$smcArguments = @('-std=c++11','-O2','-Wall','-Wextra',
    '-I',(Join-Path $smcRepo 'examples/reference_a_host'),
    (Join-Path $smcRepo 'examples/reference_a_runner.cpp'),
    (Join-Path $smcRepo 'SMC_Controller/SMC/slidingmodec.cpp'),'-o',$smcExecutable)
$smcSavedPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $Compiler) + ';' + $env:PATH
    & $Compiler @smcArguments
    if ($LASTEXITCODE -ne 0) { throw 'Reference A host compile failed' }
    $smcOutput = @(& $smcExecutable)
    if ($LASTEXITCODE -ne 0 -or $smcOutput.Count -ne 10) { throw 'Reference A replay failed' }
    [System.IO.File]::WriteAllLines($smcCsv,[string[]]$smcOutput,[System.Text.UTF8Encoding]::new($false))
    $smcAfterHashes = @(Get-FileHash -LiteralPath $smcSources -Algorithm SHA256 | Select-Object Path,Hash)
    for ($smcIndex=0; $smcIndex -lt $smcBeforeHashes.Count; $smcIndex++) {
        if ($smcBeforeHashes[$smcIndex].Hash -ne $smcAfterHashes[$smcIndex].Hash) { throw 'Source changed during reference replay' }
    }
    $smcReport = @{passed=$true;compiler=$Compiler;compiler_version=(& $Compiler --version | Select-Object -First 1);
        arguments=$smcArguments;hashes=$smcAfterHashes;reference_sources_modified=$false;
        original_cpp_executed=$true;production_controller_executed=$false;
        hardware_simulated=$false;cxx_standard=11;case_count=3;output_row_count=9;
        initialization='独立静态存储对象，构造前零初始化';parameter_source='教学假设，非原工程参数'}
    $smcReport | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smcBuildReportPath -Encoding UTF8
    Write-Output 'Reference A: compiled unchanged original C++, replayed 3 cases / 9 calls.'
} finally { $env:PATH = $smcSavedPath }
