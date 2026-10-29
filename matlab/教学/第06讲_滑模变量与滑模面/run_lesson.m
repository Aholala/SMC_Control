%% 第 06 讲：滑模变量与滑模面
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=6。
% 仅依赖 MATLAB；不调用控制库，不运行参考控制器。
% 全部参数为教学假设；只检查代数关系与点的位置，没有对象运动仿真。
% e 的单位为 °，e_dot 为 °/s，c 为 1/s，s=e_dot+c*e 为 °/s。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第06讲_滑模变量与滑模面');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',6,'matlab',version, ...
    'experiment','滑模变量数值与零值直线的区别','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 参数和手算点，列次序：上方、面上、下方、负误差面上、原点
surface_gain_per_s = .5;              % 教学系数 c，1/s；不是机器人默认值。
point_error_deg = [10,10,10,-10,0];   % e，°。
point_error_rate_deg_s = [-2,-5,-8,5,0]; % e_dot，°/s。
expected_s_deg_s = [3,0,-3,0,0];
expected_on_surface = [false,true,false,true,true];

%% s 是每个点算出的一个数；滑模面是 s=0 的所有点
point_s_deg_s = point_error_rate_deg_s + surface_gain_per_s*point_error_deg;
point_on_surface = point_s_deg_s==0;
required_error_rate_deg_s = -surface_gain_per_s*point_error_deg;
assert(isequal(point_s_deg_s,expected_s_deg_s),'SMC:Lesson06:Values','滑模变量与手算不符。');
assert(isequal(point_on_surface,expected_on_surface),'SMC:Lesson06:Membership','点是否在面上与手算不符。');
assert(point_error_rate_deg_s(1)>required_error_rate_deg_s(1) && point_s_deg_s(1)>0 && ...
    point_error_rate_deg_s(3)<required_error_rate_deg_s(3) && point_s_deg_s(3)<0, ...
    'SMC:Lesson06:Side','同一误差下，线上/下方与 s 的正负对应不符。');
assert(any(point_on_surface & point_error_deg~=0), ...
    'SMC:Lesson06:NonzeroError','面上应包含位置误差不为零的点。');
assert(point_on_surface(end) && point_error_deg(end)==0 && point_error_rate_deg_s(end)==0, ...
    'SMC:Lesson06:Origin','原点应在面上。');

%% 画出 e_dot=-c*e；这里画的是满足关系的点，不是时间轨迹
line_error_deg = (-16:.5:16)';
line_error_rate_deg_s = -surface_gain_per_s*line_error_deg;
line_s_deg_s = line_error_rate_deg_s + surface_gain_per_s*line_error_deg;
assert(all(line_s_deg_s==0),'SMC:Lesson06:Line','所画直线上应处处 s=0。');
assert(all(line_error_deg(line_error_deg>0).*line_error_rate_deg_s(line_error_deg>0)<0) && ...
    all(line_error_deg(line_error_deg<0).*line_error_rate_deg_s(line_error_deg<0)<0), ...
    'SMC:Lesson06:Signs','面上非零误差与变化率应方向相反。');

%% 图像：左侧几何关系，右侧同一 e=10° 的三种 s
lesson_show_figure = usejava('desktop');
lesson_visibility = 'off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure = figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1200,650]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
lesson_colors = [0.8,.15,.1;.1,.55,.2;.05,.35,.8];
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on;
plot(line_error_deg,line_error_rate_deg_s,'k-','LineWidth',1.8, ...
    'DisplayName','滑模面：误差变化率 = -0.5 × 误差');
xline(0,'Color',[.6,.6,.6],'HandleVisibility','off');
yline(0,'Color',[.6,.6,.6],'HandleVisibility','off');
plot([10,10],[-8,-2],'k:','LineWidth',1,'HandleVisibility','off');
for point=1:3
    plot(point_error_deg(point),point_error_rate_deg_s(point),'o', ...
        'Color',lesson_colors(point,:),'MarkerFaceColor',lesson_colors(point,:), ...
        'MarkerSize',8,'HandleVisibility','off');
end
text(10.7,-1.5,'上方：s=+3','Color',lesson_colors(1,:),'FontSize',10);
text(10.7,-4.6,'面上：s=0','Color',lesson_colors(2,:),'FontSize',10);
text(10.7,-8.6,'下方：s=-3','Color',lesson_colors(3,:),'FontSize',10);
plot(-10,5,'o','Color',lesson_colors(2,:),'MarkerFaceColor',lesson_colors(2,:), ...
    'MarkerSize',8,'HandleVisibility','off');
text(-10,3.8,'(-10,5)，s=0','HorizontalAlignment','center', ...
    'Color',lesson_colors(2,:),'FontSize',10);
plot(0,0,'kp','MarkerFaceColor','k','MarkerSize',10,'HandleVisibility','off');
text(.7,.7,'原点','FontSize',10);
xlim([-18,18]); ylim([-11,11]);
xlabel('误差 e / °'); ylabel('误差变化率 / (°/s)');
title('滑模面是零值关系；本图没有模拟运动');
legend('Location','northwest'); grid on;
nexttile;
lesson_bars = bar(point_s_deg_s(1:3),'FaceColor','flat');
lesson_bars.CData = lesson_colors;
xticks(1:3); xticklabels({'变化率 -2°/s','变化率 -5°/s','变化率 -8°/s'});
ylabel('滑模变量 s / (°/s)'); xlabel('三个点的位置误差都为 +10°');
title('s 是一个数：变化率 + 0.5 × 误差');
ylim([-4,4]); yline(0,'k-'); grid on;
for point=1:3
    offset = .35;
    if point_s_deg_s(point)<0, offset=-.45; end
    text(point,point_s_deg_s(point)+offset,sprintf('%+g',point_s_deg_s(point)), ...
        'HorizontalAlignment','center','FontSize',11);
end
sgtitle('第06讲：滑模变量与滑模面（教学系数 c=0.5 /s）');
exportgraphics(lesson_figure,fullfile(lesson_out,'滑模变量与滑模面.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'滑模变量与滑模面.fig'));

lesson_points = table(point_error_deg',point_error_rate_deg_s',point_s_deg_s',point_on_surface', ...
    'VariableNames',{'error_deg','error_rate_deg_s','sliding_variable_deg_s','on_surface'});
writetable(lesson_points,fullfile(lesson_out,'手算点与滑模变量.csv'));
lesson_line = table(line_error_deg,line_error_rate_deg_s,line_s_deg_s, ...
    'VariableNames',{'error_deg','error_rate_deg_s','sliding_variable_deg_s'});
writetable(lesson_line,fullfile(lesson_out,'滑模面上的点.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s', ...
    'point_error_deg','point_error_rate_deg_s','point_s_deg_s','point_on_surface', ...
    'required_error_rate_deg_s','line_error_deg','line_error_rate_deg_s','line_s_deg_s');
lesson_report.surface_gain_per_s = surface_gain_per_s;
lesson_report.point_errors_deg = point_error_deg;
lesson_report.point_error_rates_deg_s = point_error_rate_deg_s;
lesson_report.expected_s_deg_s = expected_s_deg_s;
lesson_report.actual_s_deg_s = point_s_deg_s;
lesson_report.on_surface = point_on_surface;
lesson_report.line_point_count = numel(line_error_deg);
lesson_report.max_line_s_magnitude_deg_s = max(abs(line_s_deg_s));
lesson_report.on_surface_nonzero_position_error_exists = any(point_on_surface & point_error_deg~=0);
lesson_report.checks = {'手算滑模变量','零值点集合','同一误差下的上方与下方', ...
    '面上位置误差可以非零','原点在面上','整条直线满足 s=0','面上非零误差与变化率反向'};
lesson_report.passed = true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第06讲通过：c=0.5 /s，e=10°，变化率 -2/-5/-8°/s 对应 s=3/0/-3°/s。\n');
fprintf('已核对滑模面上的 65 个点，以及 s=0 但位置误差非零的情况。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson06:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
