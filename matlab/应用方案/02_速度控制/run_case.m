%% 速度控制独立应用：仅运行所选案例，不重跑整套验收
% 先运行 matlab/验证/run_velocity_checks.m 或 run_checks.m。
% scenario: 1恒速、2变化速度、3反向b、4输出受限、5暂停重启、6持续外力。
scenario=1;
velocity_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(velocity_root,'matlab','内部函数'));
velocity_out=fullfile(velocity_root,'build','应用','速度控制');
velocity_native=fullfile(velocity_root,'build','velocity_application');
if ~isfolder(velocity_out), mkdir(velocity_out); end
if ~isfolder(velocity_native), mkdir(velocity_native); end
velocity_report=struct('passed',false,'scenario',scenario,'matlab',version,'firmware_linked',false,'hardware_tested',false);
smc_teaching_report(fullfile(velocity_out,'应用报告.json'),velocity_report);
assert(ismember(scenario,1:6),'SMC:Velocity:Scenario','scenario需为1～6。');
velocity_host_path=fullfile(velocity_root,'build','host','host_verification.json');
assert(isfile(velocity_host_path),'SMC:Velocity:Build','请先运行速度或完整库验证。');
velocity_host=jsondecode(fileread(velocity_host_path));
assert(velocity_host.passed && velocity_host.test_count==13,'SMC:Velocity:Host','需要本版十三项主机测试。');
for velocity_index=1:numel(velocity_host.hashes)
    [velocity_status,velocity_hash]=system(sprintf('pwsh -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',velocity_host.hashes(velocity_index).Path));
    assert(velocity_status==0 && strcmpi(strtrim(velocity_hash),velocity_host.hashes(velocity_index).Hash), ...
        'SMC:Velocity:StaleBuild','源码已改变，请先重新运行库验证。');
end
velocity_runner=fullfile(velocity_root,'build','host','velocity_verification_runner.exe');
[velocity_status,velocity_log]=system(sprintf('"%s" simulate "%s" %d',velocity_runner,velocity_native,scenario));
assert(velocity_status==0,'SMC:Velocity:Application','应用运行失败：%s',velocity_log);
velocity_csv=fullfile(velocity_native,sprintf('velocity%02d.csv',scenario));
velocity_data=readmatrix(velocity_csv);
assert(isequal(size(velocity_data),[8000,17]) && all(isfinite(velocity_data),'all'));
velocity_names={'恒定目标速度','运动目标速度','反向输入增益','输出受限','暂停复位与反转重启','持续外力'};
smc_plot_velocity(velocity_data,velocity_names{scenario},velocity_out,scenario);
copyfile(velocity_csv,fullfile(velocity_out,sprintf('案例%02d_真实C++.csv',scenario)));
velocity_report.library_hashes=velocity_host.hashes; velocity_report.rows=8000;
velocity_report.calc_count=nnz(velocity_data(:,14));
velocity_report.last_speed_error_rad_s=velocity_data(end,5)-velocity_data(end,2);
velocity_report.parameter_source='教学假设，非实测；见速度控制数学规格与接入说明';
velocity_report.config=[3,4,6,2,.25]; velocity_report.output_limits_a=[-4,4];
if scenario==3, velocity_report.config(1)=-3; end
if scenario==4, velocity_report.output_limits_a=[-.25,.25]; end
velocity_report.dt_s=.001; velocity_report.duration_s=8;
velocity_report.passed=true; smc_teaching_report(fullfile(velocity_out,'应用报告.json'),velocity_report);
save(fullfile(velocity_out,sprintf('案例%02d_参数与数据.mat',scenario)),'velocity_data','velocity_report');
fprintf('速度应用案例%d已运行：%s\n',scenario,velocity_names{scenario});
