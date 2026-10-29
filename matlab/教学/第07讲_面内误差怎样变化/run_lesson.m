%% 第 07 讲：如果一直满足滑模面关系，误差怎样变化
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=7。
% 仅依赖 MATLAB；不计算电流，不运行生产库或原控制器。
% 教学假设：从观察开始始终满足 e_dot=-c*e，c 为恒定正数。
% 准确关系 e(t)=e0*exp(-c*t)；数值更新用于独立对照，不作为精确面内轨迹。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第07讲_面内误差怎样变化');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',7,'matlab',version, ...
    'experiment','始终满足滑模面关系时的误差时间曲线','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false, ...
    'sliding_relation_assumed_maintained',true,'motor_current_computed',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 固定 c，与第 6 讲的直线相同；三个初始误差分别为正、负、零
surface_gain_per_s = .5;       % c，1/s，教学假设，不是实机配置。
initial_errors_deg = [10,-10,0];
duration_s = 8;
plot_step_s = .02;             % 准确曲线的画图取点间隔，不是控制器周期。
time_s = (0:plot_step_s:duration_s)';
decay_factor = exp(-surface_gain_per_s*time_s);
exact_error_deg = decay_factor*initial_errors_deg;
exact_error_rate_deg_s = -surface_gain_per_s*exact_error_deg;
exact_s_deg_s = exact_error_rate_deg_s+surface_gain_per_s*exact_error_deg;

%% 可直接检查的数学性质与手算点
assert(isequal(exact_error_deg(1,:),initial_errors_deg),'SMC:Lesson07:Initial','初始误差不符。');
assert(all(exact_s_deg_s==0,'all'),'SMC:Lesson07:Surface','准确曲线应始终满足 s=0。');
assert(all(exact_error_deg(:,1)>0) && all(exact_error_deg(:,2)<0) && ...
    all(exact_error_deg(:,3)==0),'SMC:Lesson07:Sign','正负初值应保持各自符号，零初值保持零。');
assert(all(diff(abs(exact_error_deg(:,1)))<0) && all(diff(abs(exact_error_deg(:,2)))<0), ...
    'SMC:Lesson07:Magnitude','非零初值的误差大小应持续减小。');
hand_times_s = [0,2,4,6,8];
hand_positive_errors_deg = [10,3.678794411714423,1.353352832366127,.497870683678639,.183156388887342];
calculated_hand_errors_deg = initial_errors_deg(1)*exp(-surface_gain_per_s*hand_times_s);
assert(max(abs(calculated_hand_errors_deg-hand_positive_errors_deg))<1e-12, ...
    'SMC:Lesson07:Hand','固定时刻的准确误差与参考数值不符。');
equal_interval_ratios = calculated_hand_errors_deg(2:end)./calculated_hand_errors_deg(1:end-1);
assert(max(abs(equal_interval_ratios-.3678794411714423))<1e-12, ...
    'SMC:Lesson07:Ratio','每过 2 s 应乘以同一个比例 exp(-1)。');

%% 第 4 讲的起点变化率更新：独立逐次计算，再与准确解比较
update_intervals_s = [.2,.1,.02];
numerical_samples = cell(1,numel(update_intervals_s));
numerical_final_errors_deg = zeros(size(update_intervals_s));
numerical_max_differences_deg = zeros(size(update_intervals_s));
for scenario=1:numel(update_intervals_s)
    dt_s = update_intervals_s(scenario);
    count = round(duration_s/dt_s);
    assert(abs(count*dt_s-duration_s)<1e-12,'SMC:Lesson07:Duration','时长应为更新间隔整数倍。');
    numerical_time_s = (0:count)'*dt_s;
    numerical_error_deg = zeros(size(numerical_time_s));
    numerical_error_deg(1) = initial_errors_deg(1);
    for sample=1:count
        old_error_deg = numerical_error_deg(sample);
        current_error_rate_deg_s = -surface_gain_per_s*old_error_deg;
        numerical_error_deg(sample+1) = old_error_deg+current_error_rate_deg_s*dt_s;
    end
    exact_at_samples_deg = initial_errors_deg(1)*exp(-surface_gain_per_s*numerical_time_s);
    numerical_difference_deg = numerical_error_deg-exact_at_samples_deg;
    numerical_final_errors_deg(scenario) = numerical_error_deg(end);
    numerical_max_differences_deg(scenario) = max(abs(numerical_difference_deg));
    assert(all(numerical_error_deg>0) && all(diff(numerical_error_deg)<0), ...
        'SMC:Lesson07:Numerical','本例选定间隔下的近似误差应保持正值并减小。');
    numerical_samples{scenario} = struct('dt_s',dt_s,'time_s',numerical_time_s, ...
        'error_deg',numerical_error_deg,'exact_error_deg',exact_at_samples_deg, ...
        'difference_deg',numerical_difference_deg);
    numerical_table = table(numerical_time_s,numerical_error_deg,exact_at_samples_deg,numerical_difference_deg, ...
        'VariableNames',{'time_s','updated_error_deg','exact_error_deg','difference_deg'});
    writetable(numerical_table,fullfile(lesson_out,sprintf('逐次计算%d_数据.csv',scenario)));
end
assert(all(diff(numerical_max_differences_deg)<0), ...
    'SMC:Lesson07:Refinement','本例减小更新间隔后，最大数值差应减少。');
assert(all(numerical_max_differences_deg>0), ...
    'SMC:Lesson07:Approximation','不能把起点更新与准确解视作完全相同。');
assert(abs(exact_error_deg(end,1)-.183156388887342)<1e-12 && exact_error_deg(end,1)~=0, ...
    'SMC:Lesson07:Nonzero','8 s 后的准确误差仍非零。');

%% 图像：面内时间曲线、相平面轨迹、近似误差、固定时长的缩小比例
lesson_show_figure = usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[60,60,1200,830]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
lesson_colors=lines(3);
tiledlayout(2,2);
nexttile;
plot(time_s,exact_error_deg,'LineWidth',1.8);
xlabel('时间 / s'); ylabel('误差 / °');
title('准确解：正负误差逐渐接近零，零误差保持零');
legend('初始 +10°','初始 -10°','初始 0°','Location','northeast'); grid on;
nexttile; hold on;
line_error_deg=linspace(-11,11,101)';
plot(line_error_deg,-surface_gain_per_s*line_error_deg,'k--','LineWidth',1,'HandleVisibility','off');
for scenario=1:2
    plot(exact_error_deg(:,scenario),exact_error_rate_deg_s(:,scenario), ...
        'Color',lesson_colors(scenario,:),'LineWidth',2,'HandleVisibility','off');
    plot(exact_error_deg(1,scenario),exact_error_rate_deg_s(1,scenario),'o', ...
        'Color',lesson_colors(scenario,:),'MarkerFaceColor',lesson_colors(scenario,:), ...
        'MarkerSize',7,'HandleVisibility','off');
    plot(exact_error_deg(end,scenario),exact_error_rate_deg_s(end,scenario),'s', ...
        'Color',lesson_colors(scenario,:),'MarkerSize',7,'HandleVisibility','off');
    quiver(exact_error_deg(31,scenario),exact_error_rate_deg_s(31,scenario), ...
        exact_error_deg(61,scenario)-exact_error_deg(31,scenario), ...
        exact_error_rate_deg_s(61,scenario)-exact_error_rate_deg_s(31,scenario),0, ...
        'Color',lesson_colors(scenario,:),'LineWidth',2,'MaxHeadSize',.7,'HandleVisibility','off');
end
xline(0,'Color',[.6,.6,.6],'HandleVisibility','off');
yline(0,'Color',[.6,.6,.6],'HandleVisibility','off');
plot(0,0,'kp','MarkerFaceColor','k','MarkerSize',8,'HandleVisibility','off');
text(-10,3.9,'起点 (-10,5)','Color',lesson_colors(2,:),'HorizontalAlignment','left');
text(10,-3.9,'起点 (10,-5)','Color',lesson_colors(1,:),'HorizontalAlignment','right');
xlabel('误差 e / °'); ylabel('误差变化率 / (°/s)');
title('假设始终在面上：箭头朝向原点，8 s 后仍未到原点');
xlim([-12,12]); ylim([-6,6]); grid on;
nexttile; hold on;
for scenario=1:numel(update_intervals_s)
    plot(numerical_samples{scenario}.time_s,numerical_samples{scenario}.difference_deg,'LineWidth',1.6);
end
xlabel('时间 / s'); ylabel('逐次计算减准确解 / °');
title('起点变化率更新是近似；本例减小间隔后更接近准确解');
legend('间隔 0.20 s','间隔 0.10 s','间隔 0.02 s','Location','southeast'); grid on;
nexttile;
bar(equal_interval_ratios); xticks(1:4); xticklabels({'0~2 s','2~4 s','4~6 s','6~8 s'});
xlabel('相同的 2 s 区间'); ylabel('区间末误差 / 区间初误差');
title('指数衰减：每过 2 s 都乘约 0.368'); ylim([0,.5]); grid on;
sgtitle('第07讲：面内误差怎样变化（教学假设 c=0.5 /s，不含到达过程）');
exportgraphics(lesson_figure,fullfile(lesson_out,'面内误差怎样变化.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'面内误差怎样变化.fig'));

exact_table=array2table([time_s,exact_error_deg,exact_error_rate_deg_s,exact_s_deg_s], ...
    'VariableNames',{'time_s','positive_error_deg','negative_error_deg','zero_error_deg', ...
    'positive_error_rate_deg_s','negative_error_rate_deg_s','zero_error_rate_deg_s', ...
    'positive_s_deg_s','negative_s_deg_s','zero_s_deg_s'});
writetable(exact_table,fullfile(lesson_out,'准确面内运动数据.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s','initial_errors_deg', ...
    'duration_s','plot_step_s','time_s','exact_error_deg','exact_error_rate_deg_s', ...
    'exact_s_deg_s','hand_times_s','calculated_hand_errors_deg','equal_interval_ratios', ...
    'update_intervals_s','numerical_samples');
lesson_report.surface_gain_per_s=surface_gain_per_s;
lesson_report.initial_errors_deg=initial_errors_deg;
lesson_report.duration_s=duration_s;
lesson_report.hand_times_s=hand_times_s;
lesson_report.positive_errors_at_hand_times_deg=calculated_hand_errors_deg;
lesson_report.equal_2s_interval_ratios=equal_interval_ratios;
lesson_report.exact_final_errors_deg=exact_error_deg(end,:);
lesson_report.exact_final_error_rates_deg_s=exact_error_rate_deg_s(end,:);
lesson_report.max_exact_s_magnitude_deg_s=max(abs(exact_s_deg_s),[],'all');
lesson_report.update_intervals_s=update_intervals_s;
lesson_report.numerical_final_errors_deg=numerical_final_errors_deg;
lesson_report.numerical_max_differences_deg=numerical_max_differences_deg;
lesson_report.checks={'初始值','准确曲线的零滑模变量','正负初值及零初值', ...
    '误差大小减小','固定时刻参考值','相等时长的固定比例','独立逐次计算与准确解', ...
    '减小间隔后的本例差异','有限观察时长末值仍非零'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第07讲通过：初始 10°，2/4/6/8 s 后约为 3.678794/1.353353/0.497871/0.183156°。\n');
fprintf('每 2 s 的比例约为 0.367879；逐次计算的差异随本例间隔减小而减少。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson07:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
