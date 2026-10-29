%% 第 02 讲：误差与误差变化率
% 主题：相同位置误差不代表运动趋势相同；误差变化率是两种角速度之差。
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=2。
% 依赖：仅 MATLAB；不调用 C++ 控制库，不运行参考控制器。
% 所有参数为教学假设，角度单位 °，时间单位 s。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第02讲_误差与误差变化率');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',2,'matlab',version, ...
    'experiment','相同初始误差下的靠近与远离','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 两个场景有相同起点、相同静止目标，分别给定不同的角速度
target_initial_deg = 30;            % 目标初始角度，°。
target_rate_deg_s = 0;              % 目标角速度，°/s；主实验目标静止。
measurement_initial_deg = 20;       % 实际初始角度，°。
measurement_rates_deg_s = [5,-5];   % 两场景的实际恒定角速度，°/s。
duration_s = 1;                    % 本段只观察到 1 s，不越过目标。
plot_step_s = .01;                 % 绘图取点间隔，s；不是控制器周期。
time_s = (0:plot_step_s:duration_s)';
target_deg = target_initial_deg + time_s*target_rate_deg_s;
measurement_deg = measurement_initial_deg + time_s*measurement_rates_deg_s;

%% 本课程采用：误差 = 实际角度 - 目标角度
error_deg = measurement_deg - target_deg;
error_rates_deg_s = measurement_rates_deg_s - target_rate_deg_s;
error_rate_deg_s = repmat(error_rates_deg_s,numel(time_s),1);

%% 独立手算核对
% 起点：20-30=-10°；1s 后：25-30=-5°，15-30=-15°。
expected_initial_error_deg = [-10,-10];
expected_final_error_deg = [-5,-15];
expected_error_rates_deg_s = [5,-5];
assert(max(abs(error_deg(1,:)-expected_initial_error_deg))<1e-10, ...
    'SMC:Lesson02:Initial','两个场景的初始误差应同为 -10°。');
assert(max(abs(error_deg(end,:)-expected_final_error_deg))<1e-10, ...
    'SMC:Lesson02:Final','1 s 后的误差与手算不一致。');
assert(isequal(error_rates_deg_s,expected_error_rates_deg_s), ...
    'SMC:Lesson02:Rate','误差变化率与手算不一致。');
assert(all(diff(abs(error_deg(:,1)))<0) && all(diff(abs(error_deg(:,2)))>0), ...
    'SMC:Lesson02:Trend','本观察区间内，靠近场景误差大小应减少，远离场景应增加。');

%% 同一公式的小检查：实际和目标一起运动时，不可省掉目标角速度
moving_target_deg = 30 + 5*time_s;
moving_measurement_deg = 20 + 5*time_s;
moving_error_deg = moving_measurement_deg - moving_target_deg;
moving_error_rate_deg_s = 5-5;
assert(all(abs(moving_error_deg+10)<1e-10) && moving_error_rate_deg_s==0, ...
    'SMC:Lesson02:Moving','同方向同速度时，误差应保持 -10°，变化率为零。');

%% 图像：上图是误差的数值，下图是它的变化率
lesson_show_figure = usejava('desktop');
lesson_visibility = 'off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure = figure('Visible',lesson_visibility,'Color','w','Position',[80,80,1050,710]);
if ~lesson_show_figure
    lesson_figure_cleanup = onCleanup(@()close(lesson_figure));
end
tiledlayout(2,1);
nexttile;
plot(time_s,error_deg,'LineWidth',1.8);
xlabel('已经过的时间 / s'); ylabel('误差 / °');
title('初始误差相同：一个从 -10° 变到 -5°，另一个变到 -15°');
legend('实际速度 +5°/s：靠近目标','实际速度 -5°/s：远离目标','Location','southwest');
ylim([-17,0]); grid on;
nexttile;
plot(time_s,error_rate_deg_s,'LineWidth',1.8);
xlabel('已经过的时间 / s'); ylabel('误差变化率 / (°/s)');
title('目标静止：误差变化率分别为 +5°/s 和 -5°/s');
legend('误差数值增加，误差大小减少','误差数值减少，误差大小增加','Location','east');
ylim([-8,8]); grid on;
sgtitle('第02讲：误差与误差变化率（教学假设，无控制器）');
exportgraphics(lesson_figure,fullfile(lesson_out,'误差与误差变化率.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'误差与误差变化率.fig'));

lesson_table = array2table([time_s,target_deg,measurement_deg,error_deg,error_rate_deg_s, ...
    moving_target_deg,moving_measurement_deg,moving_error_deg], ...
    'VariableNames',{'time_s','fixed_target_deg','approach_angle_deg','depart_angle_deg', ...
    'approach_error_deg','depart_error_deg','approach_error_rate_deg_s','depart_error_rate_deg_s', ...
    'moving_target_deg','moving_measurement_deg','moving_error_deg'});
writetable(lesson_table,fullfile(lesson_out,'误差与误差变化率数据.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'target_initial_deg','target_rate_deg_s', ...
    'measurement_initial_deg','measurement_rates_deg_s','duration_s','plot_step_s', ...
    'time_s','target_deg','measurement_deg','error_deg','error_rate_deg_s', ...
    'moving_target_deg','moving_measurement_deg','moving_error_deg','moving_error_rate_deg_s');
lesson_report.target_initial_deg = target_initial_deg;
lesson_report.target_rate_deg_s = target_rate_deg_s;
lesson_report.measurement_initial_deg = measurement_initial_deg;
lesson_report.measurement_rates_deg_s = measurement_rates_deg_s;
lesson_report.duration_s = duration_s;
lesson_report.sample_count = numel(time_s);
lesson_report.actual_initial_error_deg = error_deg(1,:);
lesson_report.actual_final_error_deg = error_deg(end,:);
lesson_report.expected_final_error_deg = expected_final_error_deg;
lesson_report.error_rates_deg_s = error_rates_deg_s;
lesson_report.moving_case_error_deg = moving_error_deg(end);
lesson_report.moving_case_error_rate_deg_s = moving_error_rate_deg_s;
lesson_report.checks = {'共同初始误差','手算末值','手算误差变化率','靠近与远离趋势','目标运动时的速度之差'};
lesson_report.passed = true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第02讲实验通过：初始误差均为 -10°，1 s 后分别为 -5°、-15°。\n');
fprintf('目标和实际同为 +5°/s 时，误差保持 -10°，误差变化率为 0°/s。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_figure_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson02:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
