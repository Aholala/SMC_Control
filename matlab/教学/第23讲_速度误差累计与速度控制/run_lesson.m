%% 第23讲：速度误差的累计、现有速度公式与一个恒速实验
% start.m: mode='教学', number=23。MATLAB、pwsh、g++；无额外工具箱。
% 六点只演示累计，不是物理运动；恒速案例才由真实C++输出推进对象。
% 使用已精简的生产库，不修改算法，不添加累计限幅或额外保护。
lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(lesson_root,'matlab','内部函数'));
lesson_out=fullfile(lesson_root,'build','教学','第23讲_速度误差累计与速度控制');
if ~isfolder(lesson_out), mkdir(lesson_out); end
report_path=fullfile(lesson_out,'运行报告.json');
report=struct('passed',false,'lesson',23,'matlab',version, ...
    'learner_understanding_confirmed',false,'production_sources_modified',false, ...
    'reference_sources_modified',false,'new_production_algorithm_added',false, ...
    'integral_limit_added',false,'firmware_linked',false,'hardware_tested',false);
smc_teaching_report(report_path,report);
point_tolerance=1e-6; closed_absolute_tolerance=2e-5; closed_relative_tolerance=2e-5;

%% 先给独立输入和手算答案，再调用真实库
point_config=[2,2,3,4,2]; point_bounds=[-3,3];
inputs=[0,0,.5,.5;0,0,.5,.5;0,0,-.5,.5;3,6,3,.5;0,0,-1,.5;0,1,1,.5];
% 输入列：目标速度、目标加速度、实际速度、dt。
hand=[.5,.25,1,-3,-3,0;.5,.5,1.5,-4.25,-3,1;-.5,.25,0,.5,.5,0; ...
    0,.25,.5,1.75,1.75,0;-1,-.25,-1.5,4.75,3,1;1,.25,1.5,-4.25,-3,1];
point_names={'block','b','c','K','epsilon','phi','minimum','maximum', ...
    'target','target_acceleration','measurement','dt'};
points=[zeros(6,1),repmat([point_config,point_bounds],6,1),inputs];
input_path=fullfile(lesson_out,'六点共同输入.csv');
writetable(array2table(points,'VariableNames',point_names),input_path);
[status,log]=system(sprintf('pwsh -NoProfile -File "%s" -InputCsv "%s"', ...
    fullfile(lesson_root,'tests','verify_lesson23.ps1'),input_path));
assert(status==0,'SMC:Lesson23:Host','第23讲主机运行失败：%s',log);
host=jsondecode(fileread(fullfile(lesson_out,'主机运行报告.json')));
assert(host.passed && host.point_count==6 && host.closed_calc_count==8000 && ...
    ~host.production_sources_modified && ~host.existing_runner_modified);
cpp_points=readmatrix(fullfile(lesson_out,'真实C++六点输出.csv'));
assert(isequal(size(cpp_points),[6,8]) && all(isfinite(cpp_points),'all') && ...
    isequal(cpp_points(:,1:2),[(1:6)',zeros(6,1)]));
expected=zeros(6,6); z=0;
for step=1:6
    [expected(step,:),z]=lesson_formula(point_config,point_bounds,inputs(step,:),z);
end
point_delta=cpp_points(:,3:8)-expected;
assert(max(abs(expected-hand),[],'all')<1e-12 && max(abs(point_delta),[],'all')<point_tolerance, ...
    'SMC:Lesson23:Hand','六点手算或真实C++序列不一致。');
% 用完整请求代回理想连续公式；受限电流不冒充完整请求。
continuous_s_rate=point_config(1)*expected(:,4)-inputs(:,2)+point_config(2)*expected(:,1);
desired_s_rate=-point_config(3)*expected(:,3) ...
    -point_config(4)*max(-1,min(1,expected(:,3)/point_config(5)));
assert(max(abs(continuous_s_rate-desired_s_rate))<1e-12);
assert(expected(2,2)==.5 && expected(3,3)==0 && expected(3,1)~=0 && ...
    expected(4,1)==0 && expected(4,2)==.25 && expected(4,5)==1.75, ...
    'SMC:Lesson23:Integral','累计、s=0与当前速度误差的区别不符。');

%% 只运行一个既有恒速案例：目标2rad/s，初始速度与角度为0
cpp=readmatrix(fullfile(lesson_out,'真实C++恒速闭环.csv'));
assert(isequal(size(cpp),[8000,17]) && all(isfinite(cpp),'all'));
config=[3,4,6,2,.25]; bounds=[-4,4]; dt=.001; count=8000; target=2;
column_names={'time','target','target_acc','position','rate','error','integral','s', ...
    'request','caller','applied','limited','enabled','calc_called','reset_event','has_result','disturbance'};
assert(all(cpp(:,2)==target) && all(cpp(:,3)==0) && all(cpp(:,13:14)==1,'all') && ...
    all(cpp(:,15)==0) && all(cpp(:,16)==1) && all(cpp(:,17)==0) && ...
    max(abs(cpp(:,1)-(0:count-1)'*dt))<1e-12);
% 理想小数手算第一拍；真实float计算用预先给定容差比较。
first_z=-2*dt; first_s=-2+4*first_z;
first_request=(-4*(-2)-6*first_s+2)/3;
assert(abs(first_request-22.048/3)<1e-12 && abs(cpp(1,9)-first_request)<1e-5 && ...
    cpp(1,11)==4 && cpp(1,12)==1 && abs(cpp(2,4)-.000006)<1e-12 && abs(cpp(2,5)-.012)<1e-12);
[reference,reference_terminal]=lesson_independent_loop(config,bounds,dt,count,target);
closed_delta=cpp-reference;
allowed=closed_absolute_tolerance+closed_relative_tolerance*abs(reference(:,1:11));
bad=[abs(closed_delta(:,1:11))>allowed,cpp(:,12:17)~=reference(:,12:17)];
first_bad=find(any(bad,2),1); report.first_closed_exceeding_row=first_bad;
if ~isempty(first_bad)
    report.first_closed_exceeding_column=find(bad(first_bad,:),1);
    smc_teaching_report(report_path,report); error('SMC:Lesson23:Alignment','恒速实验第%d行超差。',first_bad);
end
% 对象真正使用受限输出；7999组相邻状态再独立重建。
acceleration=config(1)*cpp(:,11);
reconstructed=[cpp(1:end-1,4)+cpp(1:end-1,5)*dt+.5*acceleration(1:end-1)*dt^2, ...
    cpp(1:end-1,5)+acceleration(1:end-1)*dt];
reconstruction_delta=cpp(2:end,4:5)-reconstructed;
assert(max(abs(reconstruction_delta),[],'all')<1e-12 && all(abs(cpp(:,11))<=4) && ...
    all(cpp(:,12)==(cpp(:,9)~=cpp(:,11))) && any(cpp(:,12)) && any(~cpp(:,12)));
true_speed_error=cpp(:,5)-target;
assert(abs(true_speed_error(end))<2e-5 && max(abs(true_speed_error(end-1000:end)))<2e-5);
late_rows=(count-1000):count;
late_angle_change=cpp(late_rows(end),4)-cpp(late_rows(1),4);
expected_late_angle_change=target*(cpp(late_rows(end),1)-cpp(late_rows(1),1));
assert(late_angle_change>1.9 && abs(late_angle_change-expected_late_angle_change)<2e-5, ...
    'SMC:Lesson23:Meaning','后1秒应保持约2rad/s，同时角度继续增加约2rad。');
terminal=[cpp(end,4)+cpp(end,5)*dt+.5*acceleration(end)*dt^2,cpp(end,5)+acceleration(end)*dt];
assert(all(abs(terminal-reference_terminal)<=closed_absolute_tolerance+closed_relative_tolerance*abs(reference_terminal)));

%% 单位不同的量分轴绘制；手算点序号不作为物理时间
fig=figure('Visible',lesson_visibility(),'Color','w','Position',[50,50,1150,760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile; bar(expected(:,1)); xlabel('手算序号'); ylabel('速度误差 / (rad/s)'); title('当前误差可以相同，也可以反向'); ylim([-1.2,1.2]); grid on;
nexttile; stairs((0:6)',[0;expected(:,2)],'LineWidth',1.5,'Marker','o'); xlabel('手算序号（0为初值）');
ylabel('速度误差累计值 / rad'); title('先加上本次误差×dt，直接累计'); ylim([-.35,.6]); xlim([-.2,6.3]); xticks(0:6); grid on;
nexttile; bar(expected(:,3)); xlabel('手算序号'); ylabel('滑模变量 / (rad/s)'); title('s=e+c×累计值'); ylim([-1.8,1.8]); grid on;
nexttile; bar(cpp_points(:,6:7)); xlabel('手算序号'); ylabel('电流 / A'); title('真实C++请求与受限输出');
legend('请求','输出','Location','best'); ylim([-5.2,5.2]); grid on;
sgtitle('第23讲：六个连续手算点（用于读公式，不是物理运动轨迹）');
exportgraphics(fig,fullfile(lesson_out,'速度误差累计与手算.png'),'Resolution',130);
savefig(fig,fullfile(lesson_out,'速度误差累计与手算.fig')); if ~usejava('desktop'), close(fig); end
fig=figure('Visible',lesson_visibility(),'Color','w','Position',[60,60,1150,760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile; plot(cpp(:,1),cpp(:,2),'k--',cpp(:,1),cpp(:,5),'LineWidth',1.5); grid on;
xlabel('时间 / s'); ylabel('角速度 / (rad/s)'); title('目标是保持2rad/s'); legend('目标','实际','Location','best');
nexttile; plot(cpp(:,1),cpp(:,4),'LineWidth',1.5); grid on;
xlabel('时间 / s'); ylabel('对象角度 / rad'); title('速度稳定后，角度仍持续增加'); ylim([0,18]);
nexttile; plot(cpp(:,1),cpp(:,7),'LineWidth',1.5); grid on;
xlabel('时间 / s'); ylabel('速度误差累计值 / rad'); title('这个累计值不等于实际角度');
nexttile; plot(cpp(:,1),cpp(:,9),'--',cpp(:,1),cpp(:,11),'LineWidth',1.3); grid on;
xlabel('时间 / s'); ylabel('电流 / A'); title('对象由真实C++的受限电流推进'); legend('请求','执行','Location','best');
sgtitle('第23讲：一个既有恒速闭环（教学假设，非实机）');
exportgraphics(fig,fullfile(lesson_out,'恒速与持续转角.png'),'Resolution',130);
savefig(fig,fullfile(lesson_out,'恒速与持续转角.fig')); if ~usejava('desktop'), close(fig); end

result_names={'error_rad_s','integral_rad','s_rad_s','request_a','output_a','limited'};
writetable(array2table(expected,'VariableNames',result_names),fullfile(lesson_out,'独立六点结果.csv'));
writetable(array2table(point_delta,'VariableNames',result_names),fullfile(lesson_out,'六点逐列差值.csv'));
writetable(array2table(reference,'VariableNames',column_names),fullfile(lesson_out,'独立MATLAB恒速闭环.csv'));
writetable(array2table(closed_delta,'VariableNames',column_names),fullfile(lesson_out,'恒速闭环逐列差值.csv'));
writetable(array2table([cpp(2:end,1),reconstruction_delta],'VariableNames', ...
    {'next_time_s','position_difference_rad','rate_difference_rad_s'}),fullfile(lesson_out,'真实电流与相邻状态核对.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'point_config','point_bounds','inputs','hand','expected','point_delta', ...
    'cpp','reference','closed_delta','config','bounds','dt','target','point_tolerance', ...
    'closed_absolute_tolerance','closed_relative_tolerance','reconstruction_delta','terminal','reference_terminal');
report.compiler=host.compiler_version; report.source_hashes=host.hashes;
report.shared_input_sha256=host.shared_input_sha256;
report.point_config=point_config; report.point_bounds=point_bounds; report.point_count=6;
report.point_max_numeric_difference=max(abs(point_delta),[],'all');
report.request_substitution_checks=6; report.point_tolerance=point_tolerance;
report.closed_config=config; report.closed_output_bounds=bounds; report.dt_s=dt; report.duration_s=8;
report.closed_calc_count=count; report.closed_max_current_difference_a=max(abs(closed_delta(:,11)));
report.closed_max_numeric_difference_by_column=max(abs(closed_delta),[],1);
report.closed_reference='控制器single按库精度独立计算，对象double独立推进，不读取C++后续测量/电流';
report.closed_absolute_tolerance=closed_absolute_tolerance; report.closed_relative_tolerance=closed_relative_tolerance;
report.state_transition_checks=count-1; report.max_reconstruction_difference=max(abs(reconstruction_delta),[],'all');
report.last_record_time_s=cpp(end,1); report.last_speed_error_rad_s=true_speed_error(end);
report.late_angle_interval_s=cpp(late_rows(end),1)-cpp(late_rows(1),1);
report.late_actual_angle_change_rad=late_angle_change; report.late_expected_angle_change_rad=expected_late_angle_change;
report.terminal_state_at_8s=terminal; report.reference_terminal_state_at_8s=reference_terminal;
report.parameter_source='沿用现有速度验证六个明确点及恒速案例1，全部是教学假设';
report.passed=true; smc_teaching_report(report_path,report);
fprintf('第23讲通过：六个累计手算点、8000次真实速度闭环；电流最大差%.3g A。\n',report.closed_max_current_difference_a);
fprintf('末行速度误差%.3g rad/s；后1秒实际转角%.9g rad，目标关系为2rad。\n',true_speed_error(end),late_angle_change);

function [details,integral]=lesson_formula(config,bounds,input,previous)
    error=input(3)-input(1);
    integral=previous+error*input(4);
    sliding=error+config(2)*integral;
    request=(input(2)-config(2)*error-config(3)*sliding ...
        -config(4)*max(-1,min(1,sliding/config(5))))/config(1);
    command=max(bounds(1),min(bounds(2),request));
    details=[error,integral,sliding,request,command,request~=command];
end
function [data,terminal]=lesson_independent_loop(config,bounds,dt,count,target)
    position=0; rate=0; integral=single(0); data=zeros(count,17);
    for index=0:count-1
        input=single([target,0,rate,dt]);
        [details,integral]=lesson_formula(single(config),single(bounds),input,integral);
        details=double(details); command=details(5);
        data(index+1,:)=[index*dt,target,0,position,rate,details(1:4),command,command,details(6),1,1,0,1,0];
        acceleration=config(1)*command;
        position=position+rate*dt+.5*acceleration*dt*dt; rate=rate+acceleration*dt;
    end
    terminal=[position,rate];
end
function visibility=lesson_visibility()
    visibility='off'; if usejava('desktop'), visibility='on'; end
end
