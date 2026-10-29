%% 第 04 讲：计算间隔与差分
% 入口：直接运行整个文件，或根目录 start.m 设置 mode='教学'、number=4。
% 依赖：仅 MATLAB；不调用 C++ 库或原开源控制器。
% 全部参数为教学假设；本讲只做运动量的时间换算，角度统一用 °。
% 两个方向：角度差/时间 -> 区间平均角速度；起点角速度*时间 -> 近似角度变化。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第04讲_计算间隔与差分');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',4,'matlab',version, ...
    'experiment','不同间隔下的差分与逐次更新','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 参数与独立手算结果
intervals_s = [.1,.05,.01];             % 三种固定计算/采样间隔，s。
duration_s = 1;                        % 观察时长，s。
initial_ramp_angle_deg = 10;           % 匀速场景初始角度，°。
constant_rate_deg_s = 30;              % 匀速场景角速度，°/s。
constant_acceleration_deg_s2 = 2;      % 变速场景角加速度，°/s²。
% 变速场景初始角度、速度均为零。
expected_ramp_increments_deg = [3,1.5,.3];
expected_final_angle_deg = [.9,.95,.99];   % 用区间起点速度逐次更新的末值。
expected_last_difference_rates_deg_s = [1.9,1.95,1.99];
lesson_samples = cell(1,numel(intervals_s));
first_ramp_increment_deg = zeros(size(intervals_s));
max_ramp_rate_difference_deg_s = zeros(size(intervals_s));
final_angle_deg = zeros(size(intervals_s));
final_angle_difference_deg = zeros(size(intervals_s));
last_difference_rate_deg_s = zeros(size(intervals_s));
max_average_rate_difference_deg_s = zeros(size(intervals_s));

for scenario=1:numel(intervals_s)
    dt_s = intervals_s(scenario);
    interval_count = round(duration_s/dt_s);
    assert(abs(interval_count*dt_s-duration_s)<1e-12,'SMC:Lesson04:Time','时长应为间隔的整数倍。');
    time_s = (0:interval_count)'*dt_s;

    %% 从相邻角度估计区间平均角速度
    ramp_angle_deg = initial_ramp_angle_deg + constant_rate_deg_s*time_s;
    ramp_difference_deg = diff(ramp_angle_deg);
    ramp_rate_deg_s = ramp_difference_deg/dt_s;
    first_ramp_increment_deg(scenario) = ramp_difference_deg(1);
    max_ramp_rate_difference_deg_s(scenario) = max(abs(ramp_rate_deg_s-constant_rate_deg_s));
    assert(abs(first_ramp_increment_deg(scenario)-expected_ramp_increments_deg(scenario))<1e-10, ...
        'SMC:Lesson04:Increment','原始角度差与手算不符。');
    assert(max_ramp_rate_difference_deg_s(scenario)<1e-10, ...
        'SMC:Lesson04:Ramp','角速度不变时，差分除以间隔应得到同样的角速度。');

    %% 从已知角加速度逐次更新速度和角度，两条公式都使用区间起点的旧值
    exact_rate_deg_s = constant_acceleration_deg_s2*time_s;
    exact_angle_deg = .5*constant_acceleration_deg_s2*time_s.^2;
    updated_rate_deg_s = zeros(size(time_s));
    updated_angle_deg = zeros(size(time_s));
    for sample=1:interval_count
        old_rate_deg_s = updated_rate_deg_s(sample);
        old_angle_deg = updated_angle_deg(sample);
        updated_rate_deg_s(sample+1) = old_rate_deg_s + constant_acceleration_deg_s2*dt_s;
        updated_angle_deg(sample+1) = old_angle_deg + old_rate_deg_s*dt_s;
    end
    final_angle_deg(scenario) = updated_angle_deg(end);
    final_angle_difference_deg(scenario) = updated_angle_deg(end)-exact_angle_deg(end);
    assert(max(abs(updated_rate_deg_s-exact_rate_deg_s))<1e-10, ...
        'SMC:Lesson04:Velocity','恒定角加速度下的速度更新应与准确值一致。');
    assert(abs(final_angle_deg(scenario)-expected_final_angle_deg(scenario))<1e-10, ...
        'SMC:Lesson04:Update','起点速度更新角度的末值与独立手算不符。');

    %% 变化速度下：后一个样本减前一个样本，再除间隔，得到区间平均而非末端瞬时速度
    difference_rate_deg_s = diff(exact_angle_deg)/dt_s;
    average_rate_deg_s = .5*(exact_rate_deg_s(1:end-1)+exact_rate_deg_s(2:end));
    last_difference_rate_deg_s(scenario) = difference_rate_deg_s(end);
    max_average_rate_difference_deg_s(scenario) = max(abs(difference_rate_deg_s-average_rate_deg_s));
    assert(max_average_rate_difference_deg_s(scenario)<1e-10, ...
        'SMC:Lesson04:Average','恒定角加速度下，角度差/间隔应等于区间两端速度平均值。');
    assert(abs(last_difference_rate_deg_s(scenario)-expected_last_difference_rates_deg_s(scenario))<1e-10, ...
        'SMC:Lesson04:LastRate','末段差分速度与手算不符。');
    assert(difference_rate_deg_s(end)<exact_rate_deg_s(end), ...
        'SMC:Lesson04:Instantaneous','本例末段平均速度应低于持续增加的末端速度。');

    lesson_samples{scenario} = struct('dt_s',dt_s,'time_s',time_s, ...
        'ramp_angle_deg',ramp_angle_deg,'ramp_rate_deg_s',ramp_rate_deg_s, ...
        'exact_rate_deg_s',exact_rate_deg_s,'exact_angle_deg',exact_angle_deg, ...
        'updated_rate_deg_s',updated_rate_deg_s,'updated_angle_deg',updated_angle_deg, ...
        'difference_rate_deg_s',difference_rate_deg_s);
    lesson_table = table(time_s,ramp_angle_deg,[NaN;ramp_difference_deg],[NaN;ramp_rate_deg_s], ...
        exact_angle_deg,exact_rate_deg_s,updated_angle_deg,updated_rate_deg_s,[NaN;difference_rate_deg_s], ...
        'VariableNames',{'time_s','ramp_angle_deg','ramp_difference_deg','ramp_average_rate_deg_s', ...
        'exact_angle_deg','exact_rate_deg_s','updated_angle_deg','updated_rate_deg_s','accelerating_average_rate_deg_s'});
    writetable(lesson_table,fullfile(lesson_out,sprintf('场景%d_数据.csv',scenario)));
end
% 第一行的差分列无前一个样本，保存 NaN 表示没有定义，而不是编造零速度。
assert(all(diff(abs(final_angle_difference_deg))<0),'SMC:Lesson04:Step','本例缩小间隔后末角度差应减少。');

%% 图像：变化量与变化率、准确运动与逐次近似
lesson_show_figure = usejava('desktop');
lesson_visibility = 'off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure = figure('Visible',lesson_visibility,'Color','w','Position',[60,60,1200,820]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
lesson_interval_labels = {'0.10 s','0.05 s','0.01 s'};
tiledlayout(2,2);
nexttile; bar(first_ramp_increment_deg); xticks(1:3); xticklabels(lesson_interval_labels);
xlabel('采样间隔'); ylabel('相邻角度差 / °');
title('同为 30°/s：不同间隔产生不同角度差'); grid on;
nexttile;
bar(cellfun(@(s)s.ramp_rate_deg_s(1),lesson_samples)); xticks(1:3); xticklabels(lesson_interval_labels);
xlabel('采样间隔'); ylabel('角度差 / 间隔，单位 °/s');
title('除以各自间隔后，都得到 30°/s'); ylim([0,35]); grid on;
nexttile; hold on;
for scenario=1:numel(intervals_s)
    plot(lesson_samples{scenario}.time_s,lesson_samples{scenario}.updated_angle_deg,'LineWidth',1.5);
end
fine_time_s=linspace(0,duration_s,501)';
plot(fine_time_s,.5*constant_acceleration_deg_s2*fine_time_s.^2,'k--','LineWidth',1.6);
xlabel('时间 / s'); ylabel('角度 / °');
title('用区间起点速度更新：间隔越小，本例越接近准确值');
legend('间隔 0.10 s','间隔 0.05 s','间隔 0.01 s','准确关系','Location','northwest'); grid on;
nexttile; bar(last_difference_rate_deg_s); xticks(1:3); xticklabels(lesson_interval_labels); hold on;
yline(2,'k--','1 s 时刻的角速度为 2°/s');
xlabel('采样间隔'); ylabel('最后一个区间的平均角速度 / (°/s)');
title('速度在变：区间平均速度不同于区间末端速度'); ylim([0,2.4]); grid on;
sgtitle('第04讲：计算间隔与差分（教学假设，无控制器）');
exportgraphics(lesson_figure,fullfile(lesson_out,'计算间隔与差分.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'计算间隔与差分.fig'));

save(fullfile(lesson_out,'实验参数与数据.mat'),'intervals_s','duration_s', ...
    'initial_ramp_angle_deg','constant_rate_deg_s','constant_acceleration_deg_s2','lesson_samples');
lesson_report.intervals_s = intervals_s;
lesson_report.duration_s = duration_s;
lesson_report.constant_rate_deg_s = constant_rate_deg_s;
lesson_report.constant_acceleration_deg_s2 = constant_acceleration_deg_s2;
lesson_report.first_ramp_increments_deg = first_ramp_increment_deg;
lesson_report.max_ramp_rate_difference_deg_s = max_ramp_rate_difference_deg_s;
lesson_report.exact_final_angle_deg = 1;
lesson_report.updated_final_angles_deg = final_angle_deg;
lesson_report.final_angle_differences_deg = final_angle_difference_deg;
lesson_report.exact_final_rate_deg_s = 2;
lesson_report.last_interval_average_rates_deg_s = last_difference_rate_deg_s;
lesson_report.max_average_rate_difference_deg_s = max_average_rate_difference_deg_s;
lesson_report.checks = {'匀速角度差手算','差分时间归一化','恒定角加速度速度更新', ...
    '起点速度更新角度末值','区间平均与末端速度区分','减小间隔后的本例误差'};
lesson_report.passed = true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第04讲通过：三种间隔下角度差为 3°、1.5°、0.3°，除以间隔后均为 30°/s。\n');
fprintf('准确末角度 1°；逐次更新为 0.9°、0.95°、0.99°。\n');
fprintf('准确末速度 2°/s；末段差分速度为 1.9、1.95、1.99°/s。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson04:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
