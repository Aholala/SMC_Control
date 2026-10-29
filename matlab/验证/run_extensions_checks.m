%% 单独验证位置扩展；MATLAB、pwsh、g++、CMake、Ninja，无额外工具箱。
extension_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(extension_root,'matlab','内部函数'));
[extension_status,extension_log]=system(sprintf('pwsh -NoProfile -File "%s"',fullfile(extension_root,'tests','verify_host.ps1')));
assert(extension_status==0,'SMC:Extensions:Build','主机测试失败：%s',extension_log);
extension_report=smc_verify_extensions(extension_root);
