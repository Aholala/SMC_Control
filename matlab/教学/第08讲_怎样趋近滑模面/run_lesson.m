%% 第 08 讲：还没到滑模面时，s 应怎样变化
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=8。
% 仅依赖 MATLAB；不调用库、不计算电流、不模拟完整误差系统。
% 教学假设：理想规则 s_dot=-K*s-epsilon*sign(s) 被准确实现。
% 到零后采用理想保持零的约定。实际库零附近为连续处理，不能套用本例性质。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第08讲_怎样趋近滑模面');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',8,'matlab',version, ...
    'experiment','理想符号函数趋近规则的方向和 s 时间曲线', ...
    'parameter_source','教学假设，非实测','learner_understanding_confirmed',false, ...
    'library_modified',false,'production_controller_executed',false, ...
    'ideal_sign_rule',true,'zero_holding_assumed',true);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 量与参数：s 为 °/s，s 的变化率为 °/s²
reaching_gain_per_s=1;               % K，1/s，教学参数。
switching_gain_deg_s2=2;             % epsilon，°/s²，教学参数。
probe_s_deg_s=[-6,-2,0,2,6];
expected_sign_values=[-1,-1,0,1,1];
expected_probe_rates_deg_s2=[8,4,0,-4,-8];
probe_sign_values=sign(probe_s_deg_s);
probe_rates_deg_s2=-reaching_gain_per_s*probe_s_deg_s ...
    -switching_gain_deg_s2*probe_sign_values;
assert(isequal(probe_sign_values,expected_sign_values),'SMC:Lesson08:Sign','符号函数定义不符。');
assert(isequal(probe_rates_deg_s2,expected_probe_rates_deg_s2),'SMC:Lesson08:Rate','手算变化率不符。');
assert(all(probe_rates_deg_s2(probe_s_deg_s>0)<0) && ...
    all(probe_rates_deg_s2(probe_s_deg_s<0)>0),'SMC:Lesson08:Direction','两侧应朝零改变。');
assert(probe_rates_deg_s2(probe_s_deg_s==0)==0,'SMC:Lesson08:Zero','理想零值约定不符。');

%% 第 4 讲的一步近似：仅检查选定小步在两侧的方向，不模拟到零后的离散切换
one_step_dt_s=.1;
one_step_initial_s_deg_s=[-2,2];
one_step_rates_deg_s2=[4,-4];
one_step_final_s_deg_s=one_step_initial_s_deg_s+one_step_rates_deg_s2*one_step_dt_s;
assert(max(abs(one_step_final_s_deg_s-[-1.6,1.6]))<1e-12, ...
    'SMC:Lesson08:Step','选定一步的手算值不符。');

%% 理想分段准确曲线：到达前解非零分支，到达后保持零
initial_s_deg_s=[6,-6,0];
duration_s=4;
plot_step_s=.01; % 只决定准确曲线的取点时刻，不作为控制器周期。
time_s=(0:plot_step_s:duration_s)';
decay=exp(-reaching_gain_per_s*time_s);
unclipped_magnitude_deg_s=decay*(abs(initial_s_deg_s)+ ...
    switching_gain_deg_s2/reaching_gain_per_s)-switching_gain_deg_s2/reaching_gain_per_s;
magnitude_deg_s=max(unclipped_magnitude_deg_s,0);
exact_s_deg_s=magnitude_deg_s.*repmat(sign(initial_s_deg_s),numel(time_s),1);
desired_s_rate_deg_s2=-reaching_gain_per_s*exact_s_deg_s-switching_gain_deg_s2*sign(exact_s_deg_s);

% 独立对照准确曲线非零分支的解析变化率；不在到达瞬间强行断言双侧导数存在。
branch_rate_deg_s2=-reaching_gain_per_s*(decay*(abs(initial_s_deg_s)+ ...
    switching_gain_deg_s2/reaching_gain_per_s)).*repmat(sign(initial_s_deg_s),numel(time_s),1);
nonzero_branch=magnitude_deg_s>0;
assert(max(abs(branch_rate_deg_s2(nonzero_branch)-desired_s_rate_deg_s2(nonzero_branch)))<1e-12, ...
    'SMC:Lesson08:Branch','到达前准确曲线的变化率与期望规则不符。');
assert(max(abs(exact_s_deg_s(1,:)-initial_s_deg_s))<1e-12, ...
    'SMC:Lesson08:Initial','初始值不符。');
assert(all(exact_s_deg_s(:,1)>=0) && all(exact_s_deg_s(:,2)<=0) && ...
    all(exact_s_deg_s(:,3)==0),'SMC:Lesson08:Symmetry','曲线应正负对称并按约定保持零。');
assert(max(abs(exact_s_deg_s(:,1)+exact_s_deg_s(:,2)))<1e-12, ...
    'SMC:Lesson08:Mirror','正负初值的曲线应互为相反数。');
assert(all(diff(abs(exact_s_deg_s(:,1)))<=1e-12), ...
    'SMC:Lesson08:Magnitude','理想曲线的大小不应增加。');
at_1s=find(abs(time_s-1)<1e-12,1);
assert(abs(exact_s_deg_s(at_1s,1)-.943035529371539)<1e-12, ...
    'SMC:Lesson08:HandTime','1 s 时的参考值不符。');

% |s| 到零之前的减少速率至少 epsilon，因此到达不晚于 |s0|/epsilon。
arrival_bound_s=abs(initial_s_deg_s(1))/switching_gain_deg_s2;
assert(arrival_bound_s==3 && all(exact_s_deg_s(time_s>=arrival_bound_s,1)==0), ...
    'SMC:Lesson08:Bound','理想到达曲线与 3 s 上限不符。');
first_zero_sample=find(exact_s_deg_s(:,1)==0,1);
assert(first_zero_sample>1 && all(exact_s_deg_s(first_zero_sample:end,1)==0), ...
    'SMC:Lesson08:Holding','到达后应按本例约定保持零。');
arrival_bracket_s=[time_s(first_zero_sample-1),time_s(first_zero_sample)];
assert(unclipped_magnitude_deg_s(first_zero_sample-1,1)>0 && ...
    unclipped_magnitude_deg_s(first_zero_sample,1)<0,'SMC:Lesson08:Bracket','取点到达区间不符。');

%% 图像：先看当前变化方向，再看期望规则下的理想 s 曲线
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1200,640]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
lesson_bars=bar(probe_rates_deg_s2,'FaceColor','flat');
lesson_bars.CData=[.85,.3,.1;.85,.3,.1;.5,.5,.5;.1,.45,.8;.1,.45,.8];
xticks(1:5); xticklabels({'-6','-2','0','+2','+6'});
xlabel('当前滑模变量 s / (°/s)'); ylabel('规则要求的 s 变化率 / (°/s²)');
title('s<0 时要求增加；s>0 时要求减少');
ylim([-10,10]); yline(0,'k-'); grid on;
for point=1:numel(probe_s_deg_s)
    offset=.5;
    if probe_rates_deg_s2(point)<0, offset=-.7; end
    point_label=sprintf('%+g',probe_rates_deg_s2(point));
    if probe_rates_deg_s2(point)==0, point_label='0'; end
    text(point,probe_rates_deg_s2(point)+offset,point_label, ...
        'HorizontalAlignment','center','FontSize',11);
end
nexttile;
colororder([.1,.45,.8;.85,.3,.1;.5,.5,.5]);
plot(time_s,exact_s_deg_s,'LineWidth',1.8);
xlabel('时间 / s'); ylabel('滑模变量 s / (°/s)');
title('理想规则准确实现：到零后按约定保持零');
legend('初始 s=+6','初始 s=-6','初始 s=0','Location','northeast');
xlim([0,duration_s]); ylim([-7,7]); grid on;
sgtitle('第08讲：怎样趋近滑模面（理想符号函数，非生产库仿真）');
exportgraphics(lesson_figure,fullfile(lesson_out,'怎样趋近滑模面.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'怎样趋近滑模面.fig'));

probe_table=table(probe_s_deg_s',probe_sign_values',probe_rates_deg_s2', ...
    'VariableNames',{'s_deg_s','sign_s','desired_s_rate_deg_s2'});
writetable(probe_table,fullfile(lesson_out,'手算点与变化方向.csv'));
curve_table=array2table([time_s,exact_s_deg_s,desired_s_rate_deg_s2], ...
    'VariableNames',{'time_s','positive_s_deg_s','negative_s_deg_s','zero_s_deg_s', ...
    'positive_desired_s_rate_deg_s2','negative_desired_s_rate_deg_s2','zero_desired_s_rate_deg_s2'});
writetable(curve_table,fullfile(lesson_out,'理想趋近曲线数据.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'reaching_gain_per_s', ...
    'switching_gain_deg_s2','probe_s_deg_s','probe_sign_values','probe_rates_deg_s2', ...
    'one_step_dt_s','one_step_initial_s_deg_s','one_step_final_s_deg_s', ...
    'initial_s_deg_s','duration_s','plot_step_s','time_s','exact_s_deg_s', ...
    'desired_s_rate_deg_s2','arrival_bound_s','arrival_bracket_s');
lesson_report.reaching_gain_per_s=reaching_gain_per_s;
lesson_report.switching_gain_deg_s2=switching_gain_deg_s2;
lesson_report.probe_s_deg_s=probe_s_deg_s;
lesson_report.actual_probe_rates_deg_s2=probe_rates_deg_s2;
lesson_report.expected_probe_rates_deg_s2=expected_probe_rates_deg_s2;
lesson_report.initial_s_deg_s=initial_s_deg_s;
lesson_report.duration_s=duration_s;
lesson_report.plot_step_s=plot_step_s;
lesson_report.positive_s_at_1s_deg_s=exact_s_deg_s(at_1s,1);
lesson_report.positive_arrival_bound_s=arrival_bound_s;
lesson_report.positive_arrival_sample_bracket_s=arrival_bracket_s;
lesson_report.arrival_bracket_is_not_exact_arrival_time=true;
lesson_report.final_s_deg_s=exact_s_deg_s(end,:);
lesson_report.error_e_not_simulated=true;
lesson_report.checks={'符号函数定义','手算变化率','零两侧方向','选定一步的近似', ...
    '分段解初值与到达前变化率','正负对称','大小不增加','1 s 参考值', ...
    '理想到达时间上限','到零保持约定','取点到达区间'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第08讲通过：s=-6/-2/0/2/6 时，规定的变化率为 8/4/0/-4/-8°/s²。\n');
fprintf('正初值理想曲线的到达时刻位于 %.2f~%.2f s；这不是精确到达时刻。\n',arrival_bracket_s);
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson08:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
