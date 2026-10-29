%% 第 01 讲：角度与角速度
% 教学主题：角度描述位置，角速度描述位置变化的快慢与方向。
% 入口：直接运行整个文件，或根目录 start.m（默认教学、第 1 讲）。
% 依赖：仅 MATLAB，无需 C++、Simulink 或额外工具箱。
% 所有参数为教学假设，不是参考开源的实机参数。
% 只给定恒定角速度，不计算电流、控制输出或任何滑模算法。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第01讲_角度与角速度');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',1,'matlab',version, ...
    'experiment','给定恒定角速度计算角度','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 参数：每个名称的单位和含义
initial_angle_deg = 10;           % 初始角度，°，相对本讲选定的零方向。
angular_rates_deg_s = [30,0,-30]; % 三个独立场景的恒定角速度，°/s。
duration_s = 2;                  % 观察时长，s。
plot_step_s = 0.02;              % 图像取点间隔，s；不是控制器运行周期。
time_s = (0:plot_step_s:duration_s)';

%% 恒定角速度时：当前角度 = 初始角度 + 角速度 × 已经过的时间
% 列时间乘以行角速度，得到三种场景各自的角度列。
angle_deg = initial_angle_deg + time_s*angular_rates_deg_s;
rate_deg_s = repmat(angular_rates_deg_s,numel(time_s),1);

%% 先手算核对，再观察图像
% 手算：10+30*2=70；10+0*2=10；10-30*2=-50，单位均为 °。
expected_final_deg = [70,10,-50];
assert(max(abs(angle_deg(end,:)-expected_final_deg))<1e-10, ...
    'SMC:Lesson01:Endpoint','末次角度与手算不一致。');
assert(all(angle_deg(1,:)==initial_angle_deg),'SMC:Lesson01:Initial','初始角度不一致。');
assert(all(angle_deg(:,2)==initial_angle_deg),'SMC:Lesson01:Still','角速度为零时角度应保持不变。');
assert(all(diff(angle_deg(:,1))>0) && all(diff(angle_deg(:,3))<0), ...
    'SMC:Lesson01:Direction','正负角速度对应的变化方向不正确。');

%% 图像：相同起点，不同速度
lesson_show_figure = usejava('desktop');
lesson_visibility = 'off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure = figure('Visible',lesson_visibility,'Color','w','Position',[80,80,1050,710]);
if ~lesson_show_figure
    lesson_figure_cleanup = onCleanup(@()close(lesson_figure));
end
tiledlayout(2,1);
nexttile;
plot(time_s,angle_deg,'LineWidth',1.8);
xlabel('已经过的时间 / s'); ylabel('角度 / °');
title('相同的初始角度，不同的恒定角速度');
legend('正向：+30°/s','静止：0°/s','反向：-30°/s','Location','northwest'); grid on;
nexttile;
plot(time_s,rate_deg_s,'LineWidth',1.8);
xlabel('已经过的时间 / s'); ylabel('角速度 / (°/s)');
title('本实验直接给定角速度，并保持不变');
legend('正向：+30°/s','静止：0°/s','反向：-30°/s','Location','northeast');
ylim([-40,40]); grid on;
sgtitle('第01讲：角度与角速度（教学假设，无控制器）');
exportgraphics(lesson_figure,fullfile(lesson_out,'角度与角速度.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'角度与角速度.fig'));

%% 保存中文说明对应的数据和运行记录
lesson_table = array2table([time_s,angle_deg,rate_deg_s], ...
    'VariableNames',{'time_s','positive_angle_deg','stationary_angle_deg','negative_angle_deg', ...
    'positive_rate_deg_s','stationary_rate_deg_s','negative_rate_deg_s'});
writetable(lesson_table,fullfile(lesson_out,'角度与角速度数据.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'initial_angle_deg','angular_rates_deg_s', ...
    'duration_s','plot_step_s','time_s','angle_deg','rate_deg_s');
lesson_report.initial_angle_deg = initial_angle_deg;
lesson_report.angular_rates_deg_s = angular_rates_deg_s;
lesson_report.duration_s = duration_s;
lesson_report.plot_step_s = plot_step_s;
lesson_report.sample_count = numel(time_s);
lesson_report.expected_final_deg = expected_final_deg;
lesson_report.actual_final_deg = angle_deg(end,:);
lesson_report.max_endpoint_difference_deg = max(abs(angle_deg(end,:)-expected_final_deg));
lesson_report.checks = {'手算末值','初始角度','零速度角度不变','正负速度方向'};
lesson_report.passed = true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第01讲实验通过：2 s 后三种角度分别为 %.1f°、%.1f°、%.1f°。\n',angle_deg(end,:));
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_figure_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson01:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
