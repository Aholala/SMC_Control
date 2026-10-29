%% 独立位置控制应用演示：先运行 matlab/验证/run_checks.m 完成构建与验证
% 真实 C++ 库产生控制量；对象与全部参数均为教学假设，不是实机配置。
% 1 静止目标；2 运动目标；3 持续外力；4 反向输入增益；5 测量噪声与输出限制。
scenario = 1;
smc_app_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(smc_app_root,'matlab','内部函数'));
smc_app_runner = fullfile(smc_app_root,'build','host','verification_runner.exe');
assert(isfile(smc_app_runner),'SMC:Build','请先运行 matlab/验证/run_checks.m 构建并验证库。');
assert(ismember(scenario,1:5),'SMC:Case','scenario 请选择 1~5。');
smc_app_output = fullfile(smc_app_root,'build','应用','位置控制');
if ~isfolder(smc_app_output), mkdir(smc_app_output); end
[smc_app_status,smc_app_log] = system(sprintf('"%s" simulate "%s" %d',smc_app_runner,smc_app_output,scenario));
assert(smc_app_status==0,'SMC:Run','应用运行失败：%s',smc_app_log);
smc_app_data = readmatrix(fullfile(smc_app_output,sprintf('case%02d.csv',scenario)));
smc_app_names = {'静止目标','运动目标','持续外力','反向输入增益','测量噪声与输出限制'};
smc_plot_position(smc_app_data,smc_app_names{scenario},smc_app_output,scenario);
smc_app_parameters = struct('source','教学假设，非实测', ...
    'angle_unit','rad','input_unit','A','time_unit','s','dt',.001,'duration',8, ...
    'input_gain',3,'surface_gain',4,'reaching_gain',6,'switching_gain',2,'boundary_width',.25, ...
    'output_limit',4,'initial_position',-.2,'initial_rate',0,'scenario',scenario);
if scenario==4, smc_app_parameters.input_gain=-3; end
if scenario==5, smc_app_parameters.output_limit=1; end
save(fullfile(smc_app_output,sprintf('case%02d_参数与数据.mat',scenario)),'smc_app_parameters','smc_app_data');
fprintf('应用演示已运行，输出目录：%s\n',smc_app_output);
