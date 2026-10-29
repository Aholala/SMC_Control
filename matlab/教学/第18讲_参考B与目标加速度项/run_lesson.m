%% 第 18 讲：参考 B 普通位置省略项与当前完整式的单位一致对照
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=18。
% MATLAB、pwsh、g++；真实当前库各自驱动六个对象，参考 B 仅查源码、不编译运行。
% 角度 rad，时间 s，电流 A。只在调用处改变 target_acceleration，生产库不改。
% 静止、匀速、匀加速三个目标；相同模型、系数、匹配初值、步长和限制。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第18讲_参考B与目标加速度项');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',18,'matlab',version, ...
    'experiment','单位一致的完整式与省略目标加速度式，各自闭环与独立 MATLAB 对照', ...
    'parameter_source','沿用第17讲控制参数，目标与匹配初值为教学假设', ...
    'learner_understanding_confirmed',false,'production_sources_modified',false, ...
    'reference_sources_modified',false,'production_cpp_executed',false, ...
    'reference_b_cpp_executed',false,'controller_output_drives_plant',true, ...
    'matlab_loop_reads_cpp_measurements',false,'matlab_loop_reads_cpp_controls',false, ...
    'hardware_commands_sent',false,'disturbance_included',false,'measurement_noise_included',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 真实编译当前库；两式使用相同接口，不添加生产模式
host_script=fullfile(lesson_root,'tests','verify_lesson18.ps1');
[host_status,host_output]=system(sprintf('pwsh -NoProfile -File "%s"',host_script));
assert(host_status==0,'SMC:Lesson18:Host','主机对照失败：\n%s',host_output);
host_report=jsondecode(fileread(fullfile(lesson_out,'主机对照报告.json')));
assert(host_report.passed && host_report.production_cpp_executed && ...
    ~host_report.reference_b_cpp_executed && ~host_report.production_sources_modified && ...
    ~host_report.reference_sources_modified,'SMC:Lesson18:HostReport','主机对照范围不符。');
cpp_data=readmatrix(fullfile(lesson_out,'真实C++两式闭环.csv'));
column_names={'case_number','form_number','time_s','target_rad','target_rate_rad_s', ...
    'true_target_acc_rad_s2','input_target_acc_rad_s2','position_rad','rate_rad_s', ...
    'error_rad','error_rate_rad_s','s_rad_s','requested_a','output_a','limited'};
assert(isequal(size(cpp_data),[24000,15]) && all(isfinite(cpp_data),'all'), ...
    'SMC:Lesson18:Rows','应有 24000 次有限的真实控制计算结果。');

%% 参数与容差在比较前固定
config=[3,4,6,2,.25]; % b、c、K、epsilon、phi；与第17讲一致。
output_limits_a=[-4,4];
dt_s=.001;
steps_per_loop=4000;
absolute_tolerance=2e-5;
relative_tolerance=2e-5;
same_point_tolerance=1e-12;
equilibrium_tolerance_rad=3e-6;
full_final_error_limit_rad=2e-5;
target_acceleration_rad_s2=.4;

%% 同一个状态点的请求差：54 点，检查的是限幅前公式，不要求均可在 ±4 A 下执行
[point_b,point_e,point_rate,point_acc]=ndgrid([-3,3],[-.5,0,.5],[-1,0,1],[-.4,0,.4]);
point_b=point_b(:); point_e=point_e(:); point_rate=point_rate(:); point_acc=point_acc(:);
point_s=point_rate+config(2)*point_e;
point_common=-config(2)*point_rate-config(3)*point_s-config(4)*lesson_sat(point_s/config(5));
point_full_request=(point_acc+point_common)./point_b;
point_omit_request=point_common./point_b;
point_difference_residual=point_full_request-point_omit_request-point_acc./point_b;
assert(numel(point_b)==54 && max(abs(point_difference_residual))<same_point_tolerance, ...
    'SMC:Lesson18:SamePoint','同状态点的请求差应为目标加速度除以输入增益。');
hand_full_a=target_acceleration_rad_s2/config(1);
hand_omit_a=0;
assert(abs(hand_full_a-2/15)<same_point_tolerance && ...
    abs(config(1)*hand_full_a-target_acceleration_rad_s2)<same_point_tolerance && ...
    config(1)*hand_omit_a-target_acceleration_rad_s2==-.4, ...
    'SMC:Lesson18:Hand','零误差加速目标的输入与代回手算不符。');

%% 独立执行六个 MATLAB 闭环；各自持有状态，不读取 C++ 后续电流或测量
matlab_data=lesson_independent_comparison(config,output_limits_a,dt_s,steps_per_loop);
comparison_difference=cpp_data-matlab_data;
assert(all(abs(comparison_difference)<=absolute_tolerance+relative_tolerance*abs(matlab_data),'all'), ...
    'SMC:Lesson18:Alignment','六个独立闭环的逐次数值差超过预先约定容差。');
assert(all(cpp_data(:,15)==0) && all(cpp_data(:,14)>=output_limits_a(1) & ...
    cpp_data(:,14)<=output_limits_a(2)), ...
    'SMC:Lesson18:Limits','本讲对照不应发生限幅。');

%% 六组都检查调用顺序与“真实执行电流 -> 下一状态”的对象关系
summary_rows=zeros(6,7);
max_position_reconstruction_difference_rad=0;
max_rate_reconstruction_difference_rad_s=0;
summary_index=0;
for scenario=1:3
    for form=1:2
        data=cpp_data(cpp_data(:,1)==scenario & cpp_data(:,2)==form,:);
        assert(size(data,1)==steps_per_loop && ...
            max(abs(data(:,3)-(0:steps_per_loop-1)'*dt_s))<1e-12 && ...
            data(1,8)==0 && data(1,9)==(.2*(scenario==2)), ...
            'SMC:Lesson18:Grouping','每个闭环应有相同时间点与声明的匹配初值。');
        if form==1
            assert(max(abs(data(:,7)-data(:,6)))<1e-6, ...
                'SMC:Lesson18:FullInput','完整式应提供真实目标加速度的 float 近似值。');
        else
            assert(all(data(:,7)==0),'SMC:Lesson18:OmittedInput','省略组只将目标加速度输入设为零。');
        end
        acceleration=config(1)*data(1:end-1,14);
        expected_next_position=data(1:end-1,8)+data(1:end-1,9)*dt_s+.5*acceleration*dt_s^2;
        expected_next_rate=data(1:end-1,9)+acceleration*dt_s;
        position_difference=max(abs(data(2:end,8)-expected_next_position));
        rate_difference=max(abs(data(2:end,9)-expected_next_rate));
        assert(position_difference<1e-12 && rate_difference<1e-12, ...
            'SMC:Lesson18:Plant','对象后续状态必须来自当时实际 C++ 电流。');
        max_position_reconstruction_difference_rad=max(max_position_reconstruction_difference_rad,position_difference);
        max_rate_reconstruction_difference_rad_s=max(max_rate_reconstruction_difference_rad_s,rate_difference);
        summary_index=summary_index+1;
        summary_rows(summary_index,:)=[scenario,form,data(end,3),data(end,8)-data(end,4), ...
            data(end,9)-data(end,5),data(end,14),max(abs(data(:,14)))];
    end
end
for scenario=1:2
    full=cpp_data(cpp_data(:,1)==scenario & cpp_data(:,2)==1,:);
    omit=cpp_data(cpp_data(:,1)==scenario & cpp_data(:,2)==2,:);
    assert(isequal(full(:,3:end),omit(:,3:end)), ...
        'SMC:Lesson18:ZeroTargetAcceleration','目标加速度为零时两式应得到相同轨迹。');
end

%% 匀加速案例的理想平衡偏差，使用对象角度减目标，不用舍入后的诊断误差代替
accelerating_full=cpp_data(cpp_data(:,1)==3 & cpp_data(:,2)==1,:);
accelerating_omit=cpp_data(cpp_data(:,1)==3 & cpp_data(:,2)==2,:);
full_true_error_rad=accelerating_full(:,8)-accelerating_full(:,4);
omit_true_error_rad=accelerating_omit(:,8)-accelerating_omit(:,4);
expected_equilibrium_error_rad=-target_acceleration_rad_s2/(config(2)*(config(3)+config(4)/config(5)));
expected_equilibrium_s_rad_s=config(2)*expected_equilibrium_error_rad;
assert(abs(expected_equilibrium_error_rad+1/140)<same_point_tolerance && ...
    abs(expected_equilibrium_s_rad_s)<config(5) && ...
    all(abs(accelerating_omit(:,12))<config(5)), ...
    'SMC:Lesson18:Region','理想平衡值与实际取点必须处于所推线性区域内。');
assert(abs(full_true_error_rad(end))<full_final_error_limit_rad && ...
    abs(omit_true_error_rad(end)-expected_equilibrium_error_rad)<equilibrium_tolerance_rad && ...
    abs(accelerating_full(1,14)-hand_full_a)<1e-6 && accelerating_omit(1,14)==0, ...
    'SMC:Lesson18:AcceleratingCase','匀加速初值或末行偏差不符合本实验检查条件。');

%% 图像只画匀加速案例；静止、匀速案例的相同轨迹保留在数据与报告中
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1350,900]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
full_color=[.1,.45,.8]; omit_color=[.85,.3,.1];
nexttile;
plot(accelerating_full(:,3),accelerating_full(:,4),'k--','LineWidth',1.5); hold on;
plot(accelerating_full(:,3),accelerating_full(:,8),'Color',full_color,'LineWidth',1.8);
plot(accelerating_omit(:,3),accelerating_omit(:,8),'Color',omit_color,'LineWidth',1.5);
xlabel('时间 / s'); ylabel('角度 / rad'); title('相同匀加速目标，各自电流驱动各自对象');
legend('目标','完整式对象','省略式对象','Location','northwest'); grid on;
nexttile;
plot(accelerating_full(:,3),full_true_error_rad,'Color',full_color,'LineWidth',1.8); hold on;
plot(accelerating_omit(:,3),omit_true_error_rad,'Color',omit_color,'LineWidth',1.8);
yline(expected_equilibrium_error_rad,'k--','理想省略式偏差','HandleVisibility','off', ...
    'LabelHorizontalAlignment','left');
xlabel('时间 / s'); ylabel('对象位置误差 / rad'); title('省略式可继续运动，但留下相对目标的偏差');
legend('完整式','省略式','Location','east'); grid on;
nexttile;
plot(accelerating_full(:,3),accelerating_full(:,12),'Color',full_color,'LineWidth',1.8); hold on;
plot(accelerating_omit(:,3),accelerating_omit(:,12),'Color',omit_color,'LineWidth',1.8);
yline(expected_equilibrium_s_rad_s,'k--','理想省略式 s','HandleVisibility','off', ...
    'LabelHorizontalAlignment','left');
xlabel('时间 / s'); ylabel('滑模变量 s / (rad/s)'); title('相同目标加速度下的两种 s 变化关系');
legend('完整式','省略式','Location','east'); grid on;
nexttile;
plot(accelerating_full(:,3),accelerating_full(:,14),'Color',full_color,'LineWidth',1.8); hold on;
plot(accelerating_omit(:,3),accelerating_omit(:,14),'Color',omit_color,'LineWidth',1.8);
xlabel('时间 / s'); ylabel('真实 C++ 执行电流 / A');
title('各自反馈不同后，电流差并非始终等于目标加速度/b');
legend('完整式','省略式','Location','southeast'); grid on;
sgtitle('第18讲：只比较目标加速度项（单位一致的教学对照，不是原B整套复现）');
exportgraphics(lesson_figure,fullfile(lesson_out,'参考B与目标加速度项.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'参考B与目标加速度项.fig'));

writetable(array2table(matlab_data,'VariableNames',column_names),fullfile(lesson_out,'独立MATLAB两式闭环.csv'));
summary_table=array2table(summary_rows,'VariableNames',{'case_number','form_number','last_record_time_s', ...
    'last_object_error_rad','last_object_error_rate_rad_s','last_output_a','max_output_magnitude_a'});
writetable(summary_table,fullfile(lesson_out,'六个闭环末行比较.csv'));
point_table=table(point_b,point_e,point_rate,point_acc,point_full_request,point_omit_request, ...
    point_difference_residual,'VariableNames',{'input_gain_rad_s2_per_a','error_rad','error_rate_rad_s', ...
    'target_acceleration_rad_s2','full_request_a','omit_request_a','difference_identity_residual_a'});
writetable(point_table,fullfile(lesson_out,'54个同状态请求差核对.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'config','output_limits_a','dt_s','steps_per_loop', ...
    'absolute_tolerance','relative_tolerance','equilibrium_tolerance_rad','cpp_data','matlab_data', ...
    'comparison_difference','summary_table','point_table','expected_equilibrium_error_rad','expected_equilibrium_s_rad_s');
lesson_report.production_cpp_executed=true;
lesson_report.compiler=host_report.compiler_version;
lesson_report.source_hashes=host_report.hashes;
lesson_report.target_case_count=3;
lesson_report.formula_count=2;
lesson_report.steps_per_loop=steps_per_loop;
lesson_report.production_calc_count=size(cpp_data,1);
lesson_report.dt_s=dt_s;
lesson_report.last_record_time_s=cpp_data(end,3);
lesson_report.config_order={'input_gain','surface_gain','reaching_gain','switching_gain','boundary_width'};
lesson_report.config=config;
lesson_report.column_order=column_names;
lesson_report.max_numeric_differences_by_column=max(abs(comparison_difference),[],1);
lesson_report.max_current_difference_a=max(abs(comparison_difference(:,14)));
lesson_report.max_position_difference_rad=max(abs(comparison_difference(:,8)));
lesson_report.absolute_tolerance=absolute_tolerance;
lesson_report.relative_tolerance=relative_tolerance;
lesson_report.same_state_point_count=numel(point_b);
lesson_report.max_same_state_request_identity_residual_a=max(abs(point_difference_residual));
lesson_report.max_position_reconstruction_difference_rad=max_position_reconstruction_difference_rad;
lesson_report.max_rate_reconstruction_difference_rad_s=max_rate_reconstruction_difference_rad_s;
lesson_report.expected_omit_equilibrium_error_rad=expected_equilibrium_error_rad;
lesson_report.accelerating_full_last_object_error_rad=full_true_error_rad(end);
lesson_report.accelerating_omit_last_object_error_rad=omit_true_error_rad(end);
lesson_report.zero_acceleration_cases_identical=true;
lesson_report.output_clipping_occurred=false;
lesson_report.form_2_is_normalized_omission_not_original_reference_b=true;
lesson_report.checks={'参考B文档与实际省略语句核查','54个同状态点请求差恒等式', ...
    '24000 次真实当前库闭环与独立 MATLAB 对齐','六组对象相邻状态重建', ...
    '静止与匀速两式轨迹相同','匀加速初始输入手算','匀加速省略式理想偏差及适用区域', ...
    '各组相同参数、匹配初值且没有限幅'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第18讲通过：24000 次真实当前库调用，电流最大差 %.3g A。\n',lesson_report.max_current_difference_a);
fprintf('匀加速末行对象误差：完整式 %.9g rad，省略式 %.9g rad；理想省略偏差 %.9g rad。\n', ...
    full_true_error_rad(end),omit_true_error_rad(end),expected_equilibrium_error_rad);
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function data=lesson_independent_comparison(config,bounds,dt,count)
    data=zeros(6*count,15);
    row=0;
    for scenario=1:3
        for form=1:2
            position=0;
            rate=.2*(scenario==2);
            for index=0:count-1
                time=index*dt;
                if scenario==1
                    target=0; target_rate=0; target_acc=0;
                elseif scenario==2
                    target=.2*time; target_rate=.2; target_acc=0;
                else
                    target=.2*time^2; target_rate=.4*time; target_acc=.4;
                end
                provided_acc=target_acc*(form==1);
                input=double(single([target,target_rate,provided_acc,position,rate]));
                error=input(4)-input(1);
                error_rate=input(5)-input(2);
                sliding=error_rate+config(2)*error;
                request=(input(3)-config(2)*error_rate-config(3)*sliding ...
                    -config(4)*max(-1,min(1,sliding/config(5))))/config(1);
                command=max(bounds(1),min(bounds(2),request));
                row=row+1;
                data(row,:)=[scenario,form,time,target,target_rate,target_acc,input(3), ...
                    position,rate,error,error_rate,sliding,request,command,request~=command];
                acceleration=config(1)*command;
                position=position+rate*dt+.5*acceleration*dt^2;
                rate=rate+acceleration*dt;
            end
        end
    end
end

function output=lesson_sat(value)
    output=max(-1,min(1,value));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson18:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
