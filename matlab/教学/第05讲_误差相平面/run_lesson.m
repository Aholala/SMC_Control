%% 第 05 讲：用一张图同时观察误差与误差变化率
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=5。
% 仅依赖 MATLAB；不调用控制库，不运行原开源控制器。
% 全部参数为教学假设；用恒定误差变化率构造可手算的运动。
% 相平面横轴为误差 °，纵轴为误差变化率 °/s；横轴不是时间。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第05讲_误差相平面');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',5,'matlab',version, ...
    'experiment','误差与误差变化率的坐标和运动路径','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 四个独立场景：负误差靠近/远离，正误差靠近/远离
target_deg = 30;                         % 主场景目标静止，°。
initial_error_deg = [-10,-10,10,10];     % e=实际角度-目标角度，°。
constant_error_rates_deg_s = [5,-5,-5,5]; % e_dot=实际角速度-目标角速度，°/s。
duration_s = 1;                         % 只观察这 1 s，四场景均不越过目标。
plot_step_s = .02;                      % 画图取点间隔，不是控制器周期。
time_s = (0:plot_step_s:duration_s)';
error_deg = initial_error_deg + time_s*constant_error_rates_deg_s;
error_rate_deg_s = repmat(constant_error_rates_deg_s,numel(time_s),1);
measurement_deg = target_deg + error_deg;
expected_final_error_deg = [-5,-15,5,15];

%% 手算末点、当前区间的靠近/远离，以及路径的水平运动方向
assert(isequal(error_deg(1,:),initial_error_deg),'SMC:Lesson05:Initial','起点坐标不符。');
assert(max(abs(error_deg(end,:)-expected_final_error_deg))<1e-10, ...
    'SMC:Lesson05:Final','1 s 后误差与手算不符。');
assert(all(diff(abs(error_deg(:,1)))<0) && all(diff(abs(error_deg(:,3)))<0), ...
    'SMC:Lesson05:Approach','A/C 在本区间应靠近零误差。');
assert(all(diff(abs(error_deg(:,2)))>0) && all(diff(abs(error_deg(:,4)))>0), ...
    'SMC:Lesson05:Depart','B/D 在本区间应远离零误差。');
assert(all(diff(error_deg(:,[1,4]))>0,'all') && all(diff(error_deg(:,[2,3]))<0,'all'), ...
    'SMC:Lesson05:Direction','正变化率应向右、负变化率应向左。');
assert(all(diff(error_rate_deg_s)==0,'all'), ...
    'SMC:Lesson05:Horizontal','本例变化率恒定，路径应为水平线。');

%% 固定误差点：给定整个区间误差 -10°、变化率 0°/s
fixed_error_deg = -10 + 0*time_s;
fixed_error_rate_deg_s = zeros(size(time_s));
assert(all(fixed_error_deg==-10) && all(fixed_error_rate_deg_s==0), ...
    'SMC:Lesson05:Fixed','固定误差点应保持 (-10,0)，但误差仍不为零。');

%% 原点不代表绝对静止：目标和实际一起以 +3°/s 运动，位置与速度始终相同
moving_target_deg = 30 + 3*time_s;
moving_measurement_deg = 30 + 3*time_s;
moving_origin_error_deg = moving_measurement_deg-moving_target_deg;
moving_origin_error_rate_deg_s = 3-3;
assert(all(moving_origin_error_deg==0) && moving_origin_error_rate_deg_s==0 && ...
    all(diff(moving_measurement_deg)>0), ...
    'SMC:Lesson05:Origin','原点表示误差和速度差为零，而非实际角度/速度都为零。');

%% 纵轴上的点不一定是原点：起点误差 0、变化率 +5°/s
passing_error_deg = 0 + 5*time_s;
passing_error_rate_deg_s = 5;
passing_check_time_s = .2;
passing_check_error_deg = passing_error_deg(1) + passing_error_rate_deg_s*passing_check_time_s;
assert(passing_error_deg(1)==0 && passing_error_rate_deg_s~=0 && ...
    abs(passing_check_error_deg-1)<1e-12, ...
    'SMC:Lesson05:Passing','本例从 (0,5) 出发，0.2 s 后误差应为 +1°。');

%% 相平面与普通时间图：同一组运动数据，两种横轴
lesson_show_figure = usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure = figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1220,650]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
lesson_names = {'A：负误差，靠近','B：负误差，远离','C：正误差，靠近','D：正误差，远离'};
lesson_colors = lines(4);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on;
for scenario=1:4
    plot(error_deg(:,scenario),error_rate_deg_s(:,scenario),'Color',lesson_colors(scenario,:), ...
        'LineWidth',2,'DisplayName',lesson_names{scenario});
    plot(error_deg(1,scenario),error_rate_deg_s(1,scenario),'o', ...
        'Color',lesson_colors(scenario,:),'MarkerFaceColor',lesson_colors(scenario,:), ...
        'MarkerSize',6,'HandleVisibility','off');
    plot(error_deg(end,scenario),error_rate_deg_s(end,scenario),'s', ...
        'Color',lesson_colors(scenario,:),'MarkerSize',6,'HandleVisibility','off');
    quiver(error_deg(20,scenario),error_rate_deg_s(20,scenario), ...
        error_deg(32,scenario)-error_deg(20,scenario),0,0,'Color',lesson_colors(scenario,:), ...
        'LineWidth',2,'MaxHeadSize',1.3,'HandleVisibility','off');
    text(initial_error_deg(scenario),constant_error_rates_deg_s(scenario)+.7, ...
        sprintf('%c 起点 (%g,%g)',char('A'+scenario-1),initial_error_deg(scenario), ...
        constant_error_rates_deg_s(scenario)),'HorizontalAlignment','center', ...
        'Color',lesson_colors(scenario,:),'FontSize',9);
end
xline(0,'Color',[.3,.3,.3],'HandleVisibility','off');
yline(0,'Color',[.3,.3,.3],'HandleVisibility','off');
plot(-10,0,'ko','MarkerFaceColor',[.5,.5,.5],'HandleVisibility','off');
text(-10,.7,'固定误差点 (-10,0)','HorizontalAlignment','center','FontSize',9);
plot(0,0,'kp','MarkerFaceColor','k','MarkerSize',10,'HandleVisibility','off');
text(.7,.7,'原点 (0,0)','FontSize',9);
plot(0,5,'kx','MarkerSize',9,'LineWidth',1.5,'HandleVisibility','off');
text(0,6.5,'经过目标的位置点 (0,5)','HorizontalAlignment','center','FontSize',9);
xlim([-18,18]); ylim([-8,8]);
xlabel('误差 e / °（横轴不是时间）'); ylabel('误差变化率 / (°/s)');
title('相平面：圆点为起点，方点为 1 s 后，箭头表示先后'); grid on;
nexttile; hold on;
for scenario=1:4
    plot(time_s,error_deg(:,scenario),'Color',lesson_colors(scenario,:),'LineWidth',2, ...
        'DisplayName',lesson_names{scenario});
end
yline(0,'Color',[.3,.3,.3],'HandleVisibility','off');
xlabel('时间 / s'); ylabel('误差 e / °');
title('时间图：同一组误差数据');
legend('Location','eastoutside'); ylim([-18,18]); grid on;
sgtitle('第05讲：用相平面观察误差运动（教学假设，无控制器）');
exportgraphics(lesson_figure,fullfile(lesson_out,'误差相平面.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'误差相平面.fig'));

lesson_table = array2table([time_s,error_deg,error_rate_deg_s], ...
    'VariableNames',{'time_s','a_error_deg','b_error_deg','c_error_deg','d_error_deg', ...
    'a_error_rate_deg_s','b_error_rate_deg_s','c_error_rate_deg_s','d_error_rate_deg_s'});
writetable(lesson_table,fullfile(lesson_out,'误差运动数据.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'target_deg','initial_error_deg', ...
    'constant_error_rates_deg_s','duration_s','plot_step_s','time_s','error_deg', ...
    'error_rate_deg_s','measurement_deg','fixed_error_deg','fixed_error_rate_deg_s', ...
    'moving_target_deg','moving_measurement_deg','moving_origin_error_deg', ...
    'moving_origin_error_rate_deg_s','passing_error_deg','passing_error_rate_deg_s', ...
    'passing_check_time_s','passing_check_error_deg');
lesson_report.target_deg = target_deg;
lesson_report.initial_errors_deg = initial_error_deg;
lesson_report.constant_error_rates_deg_s = constant_error_rates_deg_s;
lesson_report.expected_final_errors_deg = expected_final_error_deg;
lesson_report.actual_final_errors_deg = error_deg(end,:);
lesson_report.duration_s = duration_s;
lesson_report.sample_count = numel(time_s);
lesson_report.fixed_error_point = [-10,0];
lesson_report.moving_origin_actual_rate_deg_s = 3;
lesson_report.moving_origin_error_deg = moving_origin_error_deg(end);
lesson_report.moving_origin_error_rate_deg_s = moving_origin_error_rate_deg_s;
lesson_report.passing_initial_point = [0,5];
lesson_report.passing_error_at_0_2_s_deg = passing_check_error_deg;
lesson_report.checks = {'手算起末坐标','本区间靠近与远离','正负变化率决定水平运动方向', ...
    '恒定变化率对应水平路径','固定非零误差点','原点不等于实际静止','零位置误差不等于零速度差'};
lesson_report.passed = true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第05讲实验通过：1 s 后 A/B/C/D 误差分别为 -5°、-15°、5°、15°。\n');
fprintf('已核对固定误差点、随运动目标保持在原点，以及从 (0,5) 经过目标的情况。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson05:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
