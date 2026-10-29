%% 第 17 讲：真实 C++ 电流驱动假设对象的最小普通位置闭环
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=17。
% MATLAB、pwsh、g++；无 Simulink 依赖。只运行现有 verification_runner 的 scenario=1。
% 参数来自该现有教学案例，单位 rad、s、A，不是实测机器人参数。
% C++ 与 MATLAB 各自从初值开始，电流各自推进对象，不共用后续状态或控制量。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第17讲_最小普通位置闭环');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',17,'matlab',version, ...
    'experiment','已有静止目标案例的真实 C++ 闭环与独立 MATLAB 闭环', ...
    'parameter_source','现有 verification_runner.cpp 的 scenario=1，教学假设，非实测', ...
    'learner_understanding_confirmed',false,'production_sources_modified',false, ...
    'reference_sources_modified',false,'existing_runner_modified',false, ...
    'production_cpp_executed',false,'reference_cpp_executed',false, ...
    'plant_state_advanced',true,'controller_output_drives_plant',true, ...
    'matlab_loop_reads_cpp_controls',false,'matlab_loop_reads_cpp_measurements',false, ...
    'hardware_commands_sent',false,'disturbance_included',false,'measurement_noise_included',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 只构建并执行现有静止目标案例，不重新运行整套库验收
host_script=fullfile(lesson_root,'tests','verify_lesson17.ps1');
[host_status,host_output]=system(sprintf('pwsh -NoProfile -File "%s"',host_script));
assert(host_status==0,'SMC:Lesson17:Host','主机闭环失败：\n%s',host_output);
host_report=jsondecode(fileread(fullfile(lesson_out,'主机闭环报告.json')));
assert(host_report.passed && host_report.production_cpp_executed && ...
    host_report.controller_output_drives_plant && host_report.scenario==1 && ...
    ~host_report.production_sources_modified && ~host_report.existing_runner_modified, ...
    'SMC:Lesson17:HostReport','真实 C++ 运行报告不满足本讲范围。');
cpp_data=readmatrix(fullfile(lesson_out,'真实C++闭环.csv'));
column_names={'time','target','target_rate','target_acc','position','rate','measurement', ...
    'measurement_rate','error','error_rate','s','request','output','limited','disturbance'};
assert(isequal(size(cpp_data),[8000,15]) && all(isfinite(cpp_data),'all'), ...
    'SMC:Lesson17:Data','真实闭环数据尺寸或有限性不符。');

%% 明确采用原案例参数；不从运行结果反推或放宽检查条件
input_gain_rad_s2_per_a=3;
surface_gain_per_s=4;
reaching_gain_per_s=6;
switching_gain_rad_s2=2;
boundary_width_rad_s=.25;
output_limits_a=[-4,4];
dt_s=.001;
step_count=8000;
initial_position_rad=-.2;
initial_rate_rad_s=0;
target_rad=.5;
absolute_tolerance=2e-5;
relative_tolerance=2e-5;
state_reconstruction_tolerance=1e-12;
final_record_error_limit_rad=2e-5;
final_record_rate_limit_rad_s=2e-5;
assert(max(abs(cpp_data(:,1)-(0:step_count-1)'*dt_s))<1e-12 && ...
    all(cpp_data(:,2)==target_rad) && all(cpp_data(:,3:4)==0,'all') && ...
    all(cpp_data(:,15)==0) && isequal(cpp_data(:,5:6),cpp_data(:,7:8)), ...
    'SMC:Lesson17:Case','目标、时间、无扰动或理想测量前提不符。');

%% 第一步手算：先核对请求、限幅与下一时刻运动，再看整段曲线
hand_error_rad=initial_position_rad-target_rad;
hand_s_rad_s=surface_gain_per_s*hand_error_rad;
hand_request_a=(-reaching_gain_per_s*hand_s_rad_s ...
    -switching_gain_rad_s2*lesson_sat(hand_s_rad_s/boundary_width_rad_s))/input_gain_rad_s2_per_a;
hand_output_a=4;
hand_acceleration_rad_s2=input_gain_rad_s2_per_a*hand_output_a;
hand_next_position_rad=initial_position_rad+.5*hand_acceleration_rad_s2*dt_s^2;
hand_next_rate_rad_s=hand_acceleration_rad_s2*dt_s;
assert(abs(hand_error_rad+.7)<1e-12 && abs(hand_s_rad_s+2.8)<1e-12 && ...
    abs(hand_request_a-18.8/3)<1e-12 && abs(hand_next_position_rad+.199994)<1e-12 && ...
    abs(hand_next_rate_rad_s-.012)<1e-12, ...
    'SMC:Lesson17:Hand','第一步手算关系不符。');
assert(max(abs(cpp_data(1,[5,6])-[-.2,0]))<1e-12 && ...
    abs(cpp_data(1,12)-hand_request_a)<1e-5 && ...
    cpp_data(1,13)==4 && cpp_data(1,14)==1 && ...
    abs(cpp_data(2,5)-hand_next_position_rad)<1e-12 && ...
    abs(cpp_data(2,6)-hand_next_rate_rad_s)<1e-12, ...
    'SMC:Lesson17:FirstStep','真实 C++ 闭环的第一步不满足手算。');

%% 从真实 C++ 当时的受限电流重建下一时刻，确认数据路径闭合
cpp_acceleration_rad_s2=input_gain_rad_s2_per_a*cpp_data(:,13);
reconstructed_position_rad=cpp_data(1:end-1,5)+cpp_data(1:end-1,6)*dt_s ...
    +.5*cpp_acceleration_rad_s2(1:end-1)*dt_s^2;
reconstructed_rate_rad_s=cpp_data(1:end-1,6)+cpp_acceleration_rad_s2(1:end-1)*dt_s;
position_reconstruction_difference_rad=cpp_data(2:end,5)-reconstructed_position_rad;
rate_reconstruction_difference_rad_s=cpp_data(2:end,6)-reconstructed_rate_rad_s;
assert(max(abs(position_reconstruction_difference_rad))<state_reconstruction_tolerance && ...
    max(abs(rate_reconstruction_difference_rad_s))<state_reconstruction_tolerance, ...
    'SMC:Lesson17:FeedbackPath','相邻对象状态不是由前一状态与真实执行电流推进得到。');
assert(all(cpp_data(:,13)>=output_limits_a(1) & cpp_data(:,13)<=output_limits_a(2)) && ...
    all(cpp_data(:,14)==(cpp_data(:,12)~=cpp_data(:,13))) && ...
    any(cpp_data(:,14)==1) && any(cpp_data(:,14)==0), ...
    'SMC:Lesson17:Limits','请求、执行值或限幅标记不符。');

%% 独立 MATLAB 闭环：函数只接收参数，不接收 C++ 电流、测量或轨迹
[matlab_data,matlab_terminal_state]=lesson_independent_loop( ...
    [input_gain_rad_s2_per_a,surface_gain_per_s,reaching_gain_per_s, ...
    switching_gain_rad_s2,boundary_width_rad_s],output_limits_a, ...
    dt_s,step_count,target_rad,[initial_position_rad,initial_rate_rad_s]);
closed_loop_difference=cpp_data-matlab_data;
allowed_difference=absolute_tolerance+relative_tolerance*abs(matlab_data);
assert(all(abs(closed_loop_difference)<=allowed_difference,'all'), ...
    'SMC:Lesson17:IndependentLoop','两套独立闭环的逐次数值差超过预先约定容差。');
true_position_error_rad=cpp_data(:,5)-cpp_data(:,2);
assert(abs(true_position_error_rad(end))<final_record_error_limit_rad && ...
    abs(cpp_data(end,6))<final_record_rate_limit_rad_s, ...
    'SMC:Lesson17:FinalRecord','本教学案例末次记录的误差或速度超出检查条件。');

% CSV 最后记录为 7.999 s 的更新前状态；最后一个电流再推进到 8 s。
cpp_terminal_position_rad=cpp_data(end,5)+cpp_data(end,6)*dt_s ...
    +.5*cpp_acceleration_rad_s2(end)*dt_s^2;
cpp_terminal_rate_rad_s=cpp_data(end,6)+cpp_acceleration_rad_s2(end)*dt_s;
cpp_terminal_state=[cpp_terminal_position_rad,cpp_terminal_rate_rad_s];
assert(all(abs(cpp_terminal_state-matlab_terminal_state) ...
    <=absolute_tolerance+relative_tolerance*abs(matlab_terminal_state)), ...
    'SMC:Lesson17:Terminal','8 s 的对象状态重建与独立闭环不符。');

%% 曲线都来自实际 C++ 闭环；位置误差使用对象角度减目标，不隐藏末值偏差
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1300,880]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(cpp_data(:,1),cpp_data(:,2),'k--',cpp_data(:,1),cpp_data(:,5),'LineWidth',1.8);
xlabel('时间 / s'); ylabel('角度 / rad');
title('目标静止，对象由真实 C++ 电流驱动');
legend('目标角度','对象角度','Location','southeast'); grid on;
nexttile;
plot(cpp_data(:,1),true_position_error_rad,'Color',[.85,.3,.1],'LineWidth',1.8);
xlabel('时间 / s'); ylabel('对象位置误差 θ-r / rad');
title('对象角度改变后，下一次测量随之改变');
yline(0,'k:','HandleVisibility','off'); grid on;
nexttile;
plot(cpp_data(:,1),cpp_data(:,11),'Color',[.25,.6,.3],'LineWidth',1.8);
xlabel('时间 / s'); ylabel('滑模变量 s / (rad/s)');
title('s 与位置误差分别观察'); yline(0,'k:','HandleVisibility','off'); grid on;
nexttile;
plot(cpp_data(:,1),cpp_data(:,12),'--',cpp_data(:,1),cpp_data(:,13),'LineWidth',1.5);
xlabel('时间 / s'); ylabel('完整电流 / A');
title('对象实际使用受限输出，初始请求超过上限');
legend('请求电流','执行电流','Location','northeast');
yline(4,'k:','HandleVisibility','off'); yline(-4,'k:','HandleVisibility','off'); grid on;
sgtitle('第17讲：最小普通位置闭环（单个既有教学案例，非实机）');
exportgraphics(lesson_figure,fullfile(lesson_out,'最小普通位置闭环.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'最小普通位置闭环.fig'));

writetable(array2table(matlab_data,'VariableNames',column_names),fullfile(lesson_out,'独立MATLAB闭环.csv'));
difference_names=cellfun(@(name)['cpp_minus_matlab_',name],column_names,'UniformOutput',false);
writetable(array2table(closed_loop_difference,'VariableNames',difference_names), ...
    fullfile(lesson_out,'两套闭环逐次差值.csv'));
reconstruction_table=table(cpp_data(2:end,1),position_reconstruction_difference_rad, ...
    rate_reconstruction_difference_rad_s,'VariableNames', ...
    {'next_time_s','position_difference_rad','rate_difference_rad_s'});
writetable(reconstruction_table,fullfile(lesson_out,'真实电流与相邻状态核对.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'input_gain_rad_s2_per_a','surface_gain_per_s', ...
    'reaching_gain_per_s','switching_gain_rad_s2','boundary_width_rad_s','output_limits_a', ...
    'dt_s','step_count','initial_position_rad','initial_rate_rad_s','target_rad', ...
    'absolute_tolerance','relative_tolerance','state_reconstruction_tolerance', ...
    'cpp_data','matlab_data','closed_loop_difference','true_position_error_rad', ...
    'cpp_terminal_state','matlab_terminal_state');
lesson_report.production_cpp_executed=true;
lesson_report.compiler=host_report.compiler_version;
lesson_report.source_hashes=host_report.hashes;
lesson_report.scenario=1;
lesson_report.production_calc_count=step_count;
lesson_report.dt_s=dt_s;
lesson_report.duration_s=step_count*dt_s;
lesson_report.last_record_time_s=cpp_data(end,1);
lesson_report.column_order=column_names;
lesson_report.max_cpp_matlab_numeric_differences_by_column=max(abs(closed_loop_difference),[],1);
lesson_report.absolute_tolerance=absolute_tolerance;
lesson_report.relative_tolerance=relative_tolerance;
lesson_report.max_current_difference_a=max(abs(closed_loop_difference(:,13)));
lesson_report.max_position_difference_rad=max(abs(closed_loop_difference(:,5)));
lesson_report.max_rate_difference_rad_s=max(abs(closed_loop_difference(:,6)));
lesson_report.max_position_reconstruction_difference_rad=max(abs(position_reconstruction_difference_rad));
lesson_report.max_rate_reconstruction_difference_rad_s=max(abs(rate_reconstruction_difference_rad_s));
lesson_report.initial_request_a=cpp_data(1,12);
lesson_report.initial_output_a=cpp_data(1,13);
lesson_report.limited_steps=nnz(cpp_data(:,14));
lesson_report.last_record_position_error_rad=true_position_error_rad(end);
lesson_report.last_record_rate_rad_s=cpp_data(end,6);
lesson_report.cpp_terminal_time_s=step_count*dt_s;
lesson_report.cpp_terminal_state_reconstructed_from_last_interval=cpp_terminal_state;
lesson_report.matlab_terminal_state=matlab_terminal_state;
lesson_report.terminal_state_order={'position_rad','rate_rad_s'};
lesson_report.checks={'第一步请求、限幅与运动手算','8000 次真实控制器输出驱动对象', ...
    '7999 组相邻状态由当时真实电流重建','理想测量确实来自对象状态', ...
    'MATLAB 独立闭环逐次核对','请求、受限输出与限幅标记', ...
    '末次记录误差与速度','末行 7.999 s 与推进后的 8 s 状态分开'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第17讲通过：8000 次真实 C++ 闭环，电流最大差 %.3g A，位置最大差 %.3g rad。\n', ...
    lesson_report.max_current_difference_a,lesson_report.max_position_difference_rad);
fprintf('末行 t=%.3f s，对象位置误差 %.3g rad；限幅 %d 次。\n', ...
    cpp_data(end,1),true_position_error_rad(end),lesson_report.limited_steps);
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function [data,terminal_state]=lesson_independent_loop(config,bounds,dt,count,target,initial_state)
    % 只接受声明的参数与初值；后续测量和电流全部在本函数内部独立生成。
    position=initial_state(1);
    rate=initial_state(2);
    data=zeros(count,15);
    for index=1:count
        time=(index-1)*dt;
        input=double(single([target,0,0,position,rate]));
        error=input(4)-input(1);
        error_rate=input(5)-input(2);
        sliding=error_rate+config(2)*error;
        request=(input(3)-config(2)*error_rate-config(3)*sliding ...
            -config(4)*max(-1,min(1,sliding/config(5))))/config(1);
        command=max(bounds(1),min(bounds(2),request));
        data(index,:)=[time,target,0,0,position,rate,position,rate, ...
            error,error_rate,sliding,request,command,request~=command,0];
        acceleration=config(1)*command;
        position=position+rate*dt+.5*acceleration*dt^2;
        rate=rate+acceleration*dt;
    end
    terminal_state=[position,rate];
end

function output=lesson_sat(value)
    output=max(-1,min(1,value));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson17:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
