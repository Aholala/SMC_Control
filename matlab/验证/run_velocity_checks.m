%% 单独验证速度控制；参数均为教学假设，MATLAB、pwsh、g++、CMake、Ninja。
velocity_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(velocity_root,'matlab','内部函数'));
velocity_report=smc_verify_velocity(velocity_root,true);
