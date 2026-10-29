%% 第 12 讲：符号切换、抖振与边界层连续处理
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=12。
% 只依赖 MATLAB；全部参数为教学假设，单位 rad、s、A。
% 实验一仅回放同一段测量误差，计算切换项电流贡献，不驱动对象。
% 实验二独立研究无测量误差、恒定扰动下的理想标量 s 关系。
% 不调用生产库，不模拟完整位置闭环、执行端动态或最终输出限幅。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第12讲_抖振与零附近的连续处理');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',12,'matlab',version, ...
    'experiment','同一测量误差的切换项回放与独立恒定扰动标量曲线', ...
    'parameter_source','教学假设，非实测','learner_understanding_confirmed',false, ...
    'library_modified',false,'production_controller_executed',false, ...
    'closed_loop_position_simulated',false,'measurement_replay_drives_plant',false, ...
    'only_switching_current_compared',true,'disturbance_curves_include_noise',false, ...
    'output_clipping_included',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 参数与七个手算点：phi=.1，sat 输入为没有单位的 s/phi
input_gain_rad_s2_per_a=5;
reaching_gain_per_s=1;
switching_gain_rad_s2=2;
boundary_widths_rad_s=[.02,.1,.5];
probe_width_rad_s=.1;
probe_s_rad_s=[-.2,-.1,-.01,0,.01,.1,.2];
probe_sign=sign(probe_s_rad_s);
probe_sat=lesson_sat(probe_s_rad_s/probe_width_rad_s);
probe_sign_current_a=-switching_gain_rad_s2/input_gain_rad_s2_per_a*probe_sign;
probe_sat_current_a=-switching_gain_rad_s2/input_gain_rad_s2_per_a*probe_sat;
assert(isequal(probe_sign,[-1,-1,-1,0,1,1,1]) && ...
    max(abs(probe_sat-[-1,-1,-.1,0,.1,1,1]))<1e-12, ...
    'SMC:Lesson12:HandFunction','符号函数或饱和函数手算点不符。');
assert(max(abs(probe_sign_current_a-[.4,.4,.4,0,-.4,-.4,-.4]))<1e-12 && ...
    max(abs(probe_sat_current_a-[.4,.4,.04,0,-.04,-.4,-.4]))<1e-12, ...
    'SMC:Lesson12:HandCurrent','切换项电流贡献手算不符。');

%% 每种宽度的边界、连接与正负对称；不把连续等同于连接处无折角
connection_step_fraction=1e-6;
connection_differences=zeros(1,3);
for width_index=1:numel(boundary_widths_rad_s)
    width=boundary_widths_rad_s(width_index);
    boundary_probes=width*[-2,-1,-.1,0,.1,1,2];
    values=lesson_sat(boundary_probes/width);
    assert(max(abs(values-[-1,-1,-.1,0,.1,1,1]))<1e-12 && ...
        max(abs(values+fliplr(values)))<1e-12, ...
        'SMC:Lesson12:Boundary','边界点或正负对称不符。');
    outside=abs(boundary_probes)>=width;
    assert(isequal(values(outside),sign(boundary_probes(outside))), ...
        'SMC:Lesson12:Outside','区域外应与符号函数相同。');
    normalized_neighbors=[-1-connection_step_fraction,-1,-1+connection_step_fraction, ...
        1-connection_step_fraction,1,1+connection_step_fraction];
    neighbors=lesson_sat(normalized_neighbors);
    connection_differences(width_index)=max(abs([diff(neighbors(1:3)),diff(neighbors(4:6))]));
    assert(connection_differences(width_index)<=connection_step_fraction+1e-12, ...
        'SMC:Lesson12:Connection','连接点附近不应出现有限跳变。');
end

%% 实验一：201 个测量值，同一段人为交替误差；不模拟 s 的真实运动
replay_interval_s=.01;
replay_duration_s=2;
replay_time_s=(0:replay_interval_s:replay_duration_s)';
noise_amplitude_rad_s=.01;
true_s_rad_s=zeros(size(replay_time_s));
noise_rad_s=noise_amplitude_rad_s*(-1).^(0:numel(replay_time_s)-1)';
measured_s_rad_s=true_s_rad_s+noise_rad_s;
replay_sign_current_a=-switching_gain_rad_s2/input_gain_rad_s2_per_a*sign(measured_s_rad_s);
replay_sat_currents_a=-switching_gain_rad_s2/input_gain_rad_s2_per_a ...
    *lesson_sat(measured_s_rad_s./boundary_widths_rad_s);
replay_currents_a=[replay_sign_current_a,replay_sat_currents_a];
max_adjacent_changes_a=max(abs(diff(replay_currents_a,1,1)),[],1);
expected_adjacent_changes_a=[.8,.4,.08,.016];
assert(numel(replay_time_s)==201 && ...
    max(abs(max_adjacent_changes_a-expected_adjacent_changes_a))<1e-12, ...
    'SMC:Lesson12:NoiseChanges','同一测量误差下的相邻电流差值不符。');
reversal_counts=sum(replay_currents_a(1:end-1,:).*replay_currents_a(2:end,:)<0,1);
assert(isequal(reversal_counts,[200,200,200,200]), ...
    'SMC:Lesson12:Reversal','连续处理应减小本例幅度，不能宣称改变交替次数。');
assert(all(abs(measured_s_rad_s)<min(boundary_widths_rad_s)), ...
    'SMC:Lesson12:NoiseInside','本例测量误差应在所有连续区域内。');

%% 实验二：无测量误差，恒定扰动 d=1，初值零，三种 phi 下的准确标量曲线
constant_disturbance_rad_s2=1;
curve_initial_s_rad_s=0;
curve_duration_s=2;
curve_plot_step_s=.001; % 仅决定准确曲线取点，不是计算控制器的周期。
curve_time_s=(0:curve_plot_step_s:curve_duration_s)';
local_decay_gains_per_s=reaching_gain_per_s+switching_gain_rad_s2./boundary_widths_rad_s;
equilibrium_s_rad_s=constant_disturbance_rad_s2./local_decay_gains_per_s;
assert(max(abs(local_decay_gains_per_s-[101,21,5]))<1e-12 && ...
    max(abs(equilibrium_s_rad_s-[1/101,1/21,1/5]))<1e-12 && ...
    all(abs(equilibrium_s_rad_s)<boundary_widths_rad_s), ...
    'SMC:Lesson12:Equilibrium','平衡值手算或边界层条件不符。');
curve_s_rad_s=equilibrium_s_rad_s+(curve_initial_s_rad_s-equilibrium_s_rad_s) ...
    .*exp(-curve_time_s*local_decay_gains_per_s);
curve_rate_from_solution_rad_s2=-(curve_initial_s_rad_s-equilibrium_s_rad_s) ...
    .*local_decay_gains_per_s.*exp(-curve_time_s*local_decay_gains_per_s);
curve_rate_from_full_rule_rad_s2=-reaching_gain_per_s*curve_s_rad_s ...
    -switching_gain_rad_s2*lesson_sat(curve_s_rad_s./boundary_widths_rad_s) ...
    +constant_disturbance_rad_s2;
max_curve_rate_difference_rad_s2=max(abs(curve_rate_from_solution_rad_s2 ...
    -curve_rate_from_full_rule_rad_s2),[],'all');
assert(max_curve_rate_difference_rad_s2<1e-12 && ...
    max(abs(curve_s_rad_s(1,:)-curve_initial_s_rad_s))<1e-12, ...
    'SMC:Lesson12:Curve','准确曲线变化率或初值不符。');
assert(all(abs(curve_s_rad_s)<=boundary_widths_rad_s+1e-12,'all') && ...
    all(curve_s_rad_s>=0,'all') && all(curve_s_rad_s<=equilibrium_s_rad_s+1e-12,'all') && ...
    all(diff(curve_s_rad_s,1,1)>=-1e-12,'all'), ...
    'SMC:Lesson12:Internal','曲线必须始终在所推内部关系的适用区域内。');
equilibrium_rates_rad_s2=-reaching_gain_per_s*equilibrium_s_rad_s ...
    -switching_gain_rad_s2*lesson_sat(equilibrium_s_rad_s./boundary_widths_rad_s) ...
    +constant_disturbance_rad_s2;
assert(max(abs(equilibrium_rates_rad_s2))<1e-12, ...
    'SMC:Lesson12:Balance','平衡值代回完整 sat 关系后变化率应为零。');

% 另核对无扰动的非零初值衰减：不把绘图浮点数的零值当成有限时间证明。
decay_initial_s_rad_s=.01;
decay_probe_time_s=.01;
zero_disturbance_s_rad_s=decay_initial_s_rad_s*exp(-local_decay_gains_per_s*decay_probe_time_s);
zero_disturbance_rate_rad_s2=-reaching_gain_per_s*zero_disturbance_s_rad_s ...
    -switching_gain_rad_s2*lesson_sat(zero_disturbance_s_rad_s./boundary_widths_rad_s);
assert(all(zero_disturbance_s_rad_s>0 & zero_disturbance_s_rad_s<decay_initial_s_rad_s) && ...
    max(abs(zero_disturbance_rate_rad_s2+local_decay_gains_per_s.*zero_disturbance_s_rad_s))<1e-12, ...
    'SMC:Lesson12:NoDisturbance','无扰动内部关系应为比例衰减。');

%% 图像：函数形状、相同测量误差、电流贡献、独立的无噪声扰动曲线
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1400,930]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
lesson_colors=[.1,.1,.1;.1,.45,.8;.85,.3,.1;.25,.6,.3];
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
width_labels={'φ=0.02','φ=0.1','φ=0.5'};
nexttile;
hold on;
static_s_rad_s=linspace(-.6,.6,1201)';
sat_handles=gobjects(1,3);
for width_index=1:3
    sat_handles(width_index)=plot(static_s_rad_s,lesson_sat(static_s_rad_s/boundary_widths_rad_s(width_index)), ...
        'Color',lesson_colors(width_index+1,:),'LineWidth',1.8);
end
% sign 放在上层以免重合部分完全被覆盖；空心端点不属于函数，实心原点才是 sign(0)。
sign_handle=plot([-.6,0,NaN,0,.6],[-1,-1,NaN,1,1],'k--','LineWidth',1.6);
plot([0,0],[-1,1],'ko','MarkerFaceColor','w','LineStyle','none','HandleVisibility','off');
plot(0,0,'ko','MarkerFaceColor','k','HandleVisibility','off');
xlabel('滑模变量 s / (rad/s)'); ylabel('函数返回值（无单位）');
title('sign 在零处跳变；sat 在零附近连续');
legend([sign_handle,sat_handles],[{'sign(s)'},width_labels],'Location','southeast');
xlim([-.6,.6]); ylim([-1.2,1.2]); grid on;
nexttile;
stairs(replay_time_s,measured_s_rad_s,'Color',[.55,.2,.65],'LineWidth',1.7); hold on;
plot(replay_time_s,true_s_rad_s,'k:','LineWidth',1.3);
xlabel('测量回放时间 / s'); ylabel('滑模变量 / (rad/s)');
title('人为交替测量误差：同一段 ±0.01 rad/s');
legend('供计算使用的 s','假设的真实 s=0','Location','northeast');
xlim([0,.12]); ylim([-.016,.019]); grid on;
nexttile;
hold on;
for method_index=1:4
    stairs(replay_time_s,replay_currents_a(:,method_index), ...
        'Color',lesson_colors(method_index,:),'LineWidth',1.5);
end
xlabel('测量回放时间 / s'); ylabel('仅切换项的电流贡献 / A');
title('幅度减小，交替仍在（不是完整控制电流）');
legend([{'sign'},width_labels],'Location','northeast','NumColumns',2);
xlim([0,.12]); ylim([-.48,.58]); grid on;
nexttile;
hold on;
for width_index=1:3
    plot(curve_time_s,curve_s_rad_s(:,width_index), ...
        'Color',lesson_colors(width_index+1,:),'LineWidth',1.8);
    yline(equilibrium_s_rad_s(width_index),':','Color',lesson_colors(width_index+1,:), ...
        'HandleVisibility','off');
end
xlabel('理想关系的时间 / s'); ylabel('滑模变量 s / (rad/s)');
title('独立实验：无测量误差，恒定 d=1 rad/s²');
legend(width_labels,'Location','east');
xlim([0,curve_duration_s]); ylim([-.005,.225]); grid on;
sgtitle('第12讲：抖振与零附近的连续处理（测量回放与理想曲线，教学假设）');
exportgraphics(lesson_figure,fullfile(lesson_out,'抖振与零附近的连续处理.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'抖振与零附近的连续处理.fig'));

probe_table=table(probe_s_rad_s',probe_sign',probe_sat',probe_sign_current_a',probe_sat_current_a', ...
    'VariableNames',{'s_rad_s','sign_value','sat_value_phi_0p1','sign_switch_current_a','sat_switch_current_a'});
writetable(probe_table,fullfile(lesson_out,'七个手算点.csv'));
replay_table=array2table([replay_time_s,true_s_rad_s,noise_rad_s,measured_s_rad_s,replay_currents_a], ...
    'VariableNames',{'time_s','true_s_rad_s','noise_rad_s','measured_s_rad_s', ...
    'sign_switch_current_a','phi_0p02_switch_current_a','phi_0p1_switch_current_a','phi_0p5_switch_current_a'});
writetable(replay_table,fullfile(lesson_out,'同一测量误差的切换项回放.csv'));
curve_table=array2table([curve_time_s,curve_s_rad_s,curve_rate_from_full_rule_rad_s2], ...
    'VariableNames',{'time_s','phi_0p02_s_rad_s','phi_0p1_s_rad_s','phi_0p5_s_rad_s', ...
    'phi_0p02_s_rate_rad_s2','phi_0p1_s_rate_rad_s2','phi_0p5_s_rate_rad_s2'});
writetable(curve_table,fullfile(lesson_out,'无测量误差的恒定扰动曲线.csv'));
summary_table=table(boundary_widths_rad_s',max_adjacent_changes_a(2:4)', ...
    reversal_counts(2:4)',local_decay_gains_per_s',equilibrium_s_rad_s', ...
    'VariableNames',{'phi_rad_s','replay_max_adjacent_switch_current_change_a', ...
    'replay_reversal_count','decay_gain_per_s','separate_disturbance_equilibrium_s_rad_s'});
writetable(summary_table,fullfile(lesson_out,'三种宽度的分别比较.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'input_gain_rad_s2_per_a','reaching_gain_per_s', ...
    'switching_gain_rad_s2','boundary_widths_rad_s','probe_width_rad_s','noise_amplitude_rad_s', ...
    'replay_interval_s','replay_duration_s','curve_initial_s_rad_s','curve_duration_s', ...
    'curve_plot_step_s','constant_disturbance_rad_s2','decay_initial_s_rad_s','decay_probe_time_s', ...
    'probe_table','replay_table','curve_table','summary_table');
lesson_report.input_gain_rad_s2_per_a=input_gain_rad_s2_per_a;
lesson_report.reaching_gain_per_s=reaching_gain_per_s;
lesson_report.switching_gain_rad_s2=switching_gain_rad_s2;
lesson_report.boundary_widths_rad_s=boundary_widths_rad_s;
lesson_report.replay_interval_s=replay_interval_s;
lesson_report.replay_duration_s=replay_duration_s;
lesson_report.noise_amplitude_rad_s=noise_amplitude_rad_s;
lesson_report.replay_sample_count=numel(replay_time_s);
lesson_report.method_order={'sign','phi=.02','phi=.1','phi=.5'};
lesson_report.max_adjacent_switch_current_changes_a=max_adjacent_changes_a;
lesson_report.reversal_counts=reversal_counts;
lesson_report.constant_disturbance_rad_s2=constant_disturbance_rad_s2;
lesson_report.curve_duration_s=curve_duration_s;
lesson_report.curve_plot_step_s=curve_plot_step_s;
lesson_report.local_decay_gains_per_s=local_decay_gains_per_s;
lesson_report.equilibrium_s_rad_s=equilibrium_s_rad_s;
lesson_report.equilibrium_is_not_position_error=true;
lesson_report.max_curve_rate_difference_rad_s2=max_curve_rate_difference_rad_s2;
lesson_report.max_equilibrium_rate_residual_rad_s2=max(abs(equilibrium_rates_rad_s2));
lesson_report.checks={'七个手算点','三种宽度的边界连接、对称与外部一致', ...
    '201 点相同测量误差回放','相邻电流差值手算','交替次数没有减少', ...
    '恒定扰动平衡值手算','准确曲线独立求导及完整 sat 代回', ...
    '曲线始终处于所推内部关系范围','无扰动的非零初值比例衰减'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第12讲通过：同一交替误差下，相邻切换项电流差为 .8/.4/.08/.016 A。\n');
fprintf('无测量误差、d=1 时，三种宽度的 s 平衡值为 %.9f/%.9f/%.9f rad/s。\n',equilibrium_s_rad_s);
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function value=lesson_sat(normalized_input)
    value=min(1,max(-1,normalized_input));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson12:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
