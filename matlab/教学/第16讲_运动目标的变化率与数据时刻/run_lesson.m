%% 第 16 讲：运动目标变化率的来源、本拍差分与旧拍混用
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=16。
% MATLAB、pwsh、g++；无 Simulink 或符号求导工具箱依赖。
% 教学参数，单位 °、s、A；目标角度数值为 t³。
% 测量数据预先给定，不由输出驱动对象生成；仅调用当前库，不运行参考 C。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第16讲_运动目标的变化率与数据时刻');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',16,'matlab',version, ...
    'experiment','准确目标变化率、本拍差分及旧拍速度混用的同输入回放', ...
    'parameter_source','教学假设，非机器人参数','learner_understanding_confirmed',false, ...
    'production_sources_modified',false,'reference_sources_modified',false, ...
    'production_cpp_executed',false,'reference_cpp_executed',false, ...
    'plant_state_advanced',false,'hardware_commands_sent',false, ...
    'measurement_noise_included',false,'variable_intervals_simulated',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 先运行真实当前库；本轮不读取过时 CSV 代替重新计算
host_script=fullfile(lesson_root,'tests','verify_lesson16.ps1');
[host_status,host_output]=system(sprintf('pwsh -NoProfile -File "%s"',host_script));
assert(host_status==0,'SMC:Lesson16:Host','主机编译或回放失败：\n%s',host_output);
host_report=jsondecode(fileread(fullfile(lesson_out,'主机回放报告.json')));
assert(host_report.passed && host_report.production_cpp_executed && ...
    ~host_report.production_sources_modified && ~host_report.reference_cpp_executed, ...
    'SMC:Lesson16:HostReport','真实 C++ 报告不满足本讲范围。');
cpp_table=readtable(fullfile(lesson_out,'当前库三种变化率真实回放.csv'));
cpp_tolerance=5e-6;
hand_tolerance=1e-10;
surface_gain_per_s=.5;
reaching_gain_per_s=1;
switching_gain_deg_s2=2;
input_gain_deg_s2_per_a=5;
boundary_width_deg_s=1;
output_limits_a=[-10,10];
interval_s=.1;
time_s=(2:12)'*interval_s;
assert(height(cpp_table)==33 && ...
    isequal(cpp_table.method_number,repmat((1:3)',11,1)) && ...
    max(abs(cpp_table.time_s-repelem(time_s,3)))<hand_tolerance && ...
    all(cpp_table.limited==0), ...
    'SMC:Lesson16:Rows','样本顺序、时刻或未限幅条件不符。');

%% MATLAB 独立生成目标与两段差分，再核对 C++ 真正收到的输入
target_deg=time_s.^3;
previous_target_deg=(time_s-interval_s).^3;
earlier_target_deg=(time_s-2*interval_s).^3;
exact_rate_deg_s=3*time_s.^2;
exact_acceleration_deg_s2=6*time_s;
current_difference_rate_deg_s=(target_deg-previous_target_deg)/interval_s;
previous_difference_rate_deg_s=(previous_target_deg-earlier_target_deg)/interval_s;
current_difference_acceleration_deg_s2=(target_deg-2*previous_target_deg+earlier_target_deg)/interval_s^2;
assert(max(abs(current_difference_rate_deg_s-(3*time_s.^2-3*time_s*interval_s+interval_s^2)))<hand_tolerance && ...
    max(abs(previous_difference_rate_deg_s-(3*time_s.^2-9*time_s*interval_s+7*interval_s^2)))<hand_tolerance && ...
    max(abs(current_difference_acceleration_deg_s2-6*(time_s-interval_s)))<hand_tolerance, ...
    'SMC:Lesson16:DifferenceIdentity','三次目标的差分展开式不符。');
method_rates_deg_s=[exact_rate_deg_s,current_difference_rate_deg_s,previous_difference_rate_deg_s];
method_accelerations_deg_s2=[exact_acceleration_deg_s2, ...
    current_difference_acceleration_deg_s2,current_difference_acceleration_deg_s2];
expected_inputs=[repelem(target_deg,3),reshape(method_rates_deg_s',[],1), ...
    reshape(method_accelerations_deg_s2',[],1),repelem(target_deg+1,3),repelem(exact_rate_deg_s,3)];
actual_inputs=[cpp_table.target_deg,cpp_table.target_rate_deg_s,cpp_table.target_acceleration_deg_s2, ...
    cpp_table.measurement_deg,cpp_table.measurement_rate_deg_s];
input_differences=actual_inputs-expected_inputs;
assert(all(abs(input_differences)<cpp_tolerance,'all'), ...
    'SMC:Lesson16:Inputs','C++ 输入构造与 MATLAB 独立目标公式不符。');

%% 再使用同一组输入独立计算控制量，逐次比较 C++ 真实结果
matlab_error_deg=cpp_table.measurement_deg-cpp_table.target_deg;
matlab_error_rate_deg_s=cpp_table.measurement_rate_deg_s-cpp_table.target_rate_deg_s;
matlab_s_deg_s=matlab_error_rate_deg_s+surface_gain_per_s*matlab_error_deg;
matlab_requested_a=(cpp_table.target_acceleration_deg_s2-surface_gain_per_s*matlab_error_rate_deg_s ...
    -reaching_gain_per_s*matlab_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(matlab_s_deg_s/boundary_width_deg_s))/input_gain_deg_s2_per_a;
matlab_output_a=max(output_limits_a(1),min(output_limits_a(2),matlab_requested_a));
actual_results=[cpp_table.error_deg,cpp_table.error_rate_deg_s,cpp_table.s_deg_s,cpp_table.requested_a,cpp_table.output_a];
expected_results=[matlab_error_deg,matlab_error_rate_deg_s,matlab_s_deg_s,matlab_requested_a,matlab_output_a];
result_differences=actual_results-expected_results;
assert(all(abs(result_differences)<cpp_tolerance,'all'), ...
    'SMC:Lesson16:Controller','真实当前库结果与独立公式不符。');
at_one_second=abs(cpp_table.time_s-1)<hand_tolerance;
assert(sum(at_one_second)==3 && ...
    max(abs(cpp_table.target_rate_deg_s(at_one_second)-[3;2.71;2.17]))<cpp_tolerance && ...
    max(abs(cpp_table.target_acceleration_deg_s2(at_one_second)-[6;5.4;5.4]))<cpp_tolerance && ...
    max(abs(cpp_table.error_rate_deg_s(at_one_second)-[0;.29;.83]))<cpp_tolerance && ...
    max(abs(cpp_table.output_a(at_one_second)-[.9;.577;.331]))<cpp_tolerance, ...
    'SMC:Lesson16:CurrentHand','t=1 s 的目标变化率、误差变化率或电流手算不符。');

%% 四种简单目标在 t=1、h=.1 时的手算：每行是 r_k、r_(k-1)、r_(k-2)
hand_target_values_deg=[2,2,2;2,1.8,1.6;1,.81,.64;1,.729,.512];
hand_exact_rate_deg_s=[0;2;2;3];
hand_exact_acceleration_deg_s2=[0;0;2;6];
hand_current_rate_deg_s=(hand_target_values_deg(:,1)-hand_target_values_deg(:,2))/interval_s;
hand_previous_rate_deg_s=(hand_target_values_deg(:,2)-hand_target_values_deg(:,3))/interval_s;
hand_current_acceleration_deg_s2=(hand_target_values_deg(:,1)-2*hand_target_values_deg(:,2) ...
    +hand_target_values_deg(:,3))/interval_s^2;
assert(max(abs(hand_current_rate_deg_s-[0;2;1.9;2.71]))<hand_tolerance && ...
    max(abs(hand_previous_rate_deg_s-[0;2;1.7;2.17]))<hand_tolerance && ...
    max(abs(hand_current_acceleration_deg_s2-[0;0;2;5.4]))<hand_tolerance, ...
    'SMC:Lesson16:SimpleTargets','四种简单目标的手算差分不符。');

%% 固定 t=1，三个不同但各自固定的间隔；没有变间隔或噪声实验
sweep_intervals_s=[.2,.1,.05];
sweep_previous_deg=(1-sweep_intervals_s).^3;
sweep_earlier_deg=(1-2*sweep_intervals_s).^3;
sweep_current_rate_deg_s=(1-sweep_previous_deg)./sweep_intervals_s;
sweep_previous_rate_deg_s=(sweep_previous_deg-sweep_earlier_deg)./sweep_intervals_s;
sweep_acceleration_deg_s2=(1-2*sweep_previous_deg+sweep_earlier_deg)./sweep_intervals_s.^2;
sweep_current_error_rate_deg_s=3-sweep_current_rate_deg_s;
sweep_previous_error_rate_deg_s=3-sweep_previous_rate_deg_s;
sweep_current_s_deg_s=surface_gain_per_s+sweep_current_error_rate_deg_s;
sweep_previous_s_deg_s=surface_gain_per_s+sweep_previous_error_rate_deg_s;
sweep_current_a=(sweep_acceleration_deg_s2-surface_gain_per_s*sweep_current_error_rate_deg_s ...
    -reaching_gain_per_s*sweep_current_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(sweep_current_s_deg_s/boundary_width_deg_s))/input_gain_deg_s2_per_a;
sweep_mixed_a=(sweep_acceleration_deg_s2-surface_gain_per_s*sweep_previous_error_rate_deg_s ...
    -reaching_gain_per_s*sweep_previous_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(sweep_previous_s_deg_s/boundary_width_deg_s))/input_gain_deg_s2_per_a;
exact_current_at_one_a=(6-reaching_gain_per_s*.5-switching_gain_deg_s2*.5)/input_gain_deg_s2_per_a;
assert(max(abs(sweep_current_a-[.292,.577,.73675]))<hand_tolerance && ...
    max(abs(sweep_mixed_a-[.004,.331,.53725]))<hand_tolerance && ...
    abs(exact_current_at_one_a-.9)<hand_tolerance, ...
    'SMC:Lesson16:Intervals','三个间隔的单位一致电流手算不符。');

%% 图像：给定目标、速度来源、加速度近似，以及真实当前库的三组电流
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1400,930]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
method_colors=[.1,.45,.8;.85,.3,.1;.25,.6,.3];
method_labels={'准确变化率','本拍速度差分 + 本拍加速度差分','旧拍速度差分 + 本拍加速度差分'};
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(time_s,target_deg,'-o','Color',method_colors(1,:),'LineWidth',1.8);
xlabel('给定目标的时间 / s'); ylabel('目标角度 / °');
title('教学目标 r=t³（给定数据，不是控制后运动）'); grid on;
nexttile;
colororder(method_colors);
plot(time_s,method_rates_deg_s,'-o','LineWidth',1.5);
xlabel('当前观察时刻 / s'); ylabel('提供的目标角速度 / (°/s)');
title('本拍差分仍有近似误差，旧拍又多用一段旧信息');
legend('准确当前速度','本拍速度差分','上一拍速度差分','Location','northwest'); grid on;
nexttile;
plot(time_s,[exact_acceleration_deg_s2,current_difference_acceleration_deg_s2],'-o','LineWidth',1.5);
xlabel('当前观察时刻 / s'); ylabel('提供的目标角加速度 / (°/s²)');
title('t³ 的本拍加速度差分等于 6(t-h)');
legend('准确当前加速度','差分加速度（后两组共用）','Location','northwest'); grid on;
nexttile;
hold on;
for method=1:3
    rows=cpp_table.method_number==method;
    plot(cpp_table.time_s(rows),cpp_table.output_a(rows),'-o', ...
        'Color',method_colors(method,:),'LineWidth',1.5);
end
xlabel('相同输入回放的当前时刻 / s'); ylabel('真实 C++ 请求电流 / A');
title('同一生产公式，只改变提供的目标变化率');
legend(method_labels,'Location','northwest','FontSize',9); grid on;
sgtitle('第16讲：运动目标的变化率与数据时刻（教学假设，无对象运动反馈）');
exportgraphics(lesson_figure,fullfile(lesson_out,'运动目标的变化率与数据时刻.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'运动目标的变化率与数据时刻.fig'));

comparison_table=cpp_table;
comparison_table.matlab_error_deg=matlab_error_deg;
comparison_table.matlab_error_rate_deg_s=matlab_error_rate_deg_s;
comparison_table.matlab_s_deg_s=matlab_s_deg_s;
comparison_table.matlab_requested_a=matlab_requested_a;
comparison_table.cpp_minus_matlab_current_a=result_differences(:,5);
writetable(comparison_table,fullfile(lesson_out,'当前库与MATLAB逐次核对.csv'));
target_table=table(time_s,target_deg,exact_rate_deg_s,current_difference_rate_deg_s, ...
    previous_difference_rate_deg_s,exact_acceleration_deg_s2,current_difference_acceleration_deg_s2);
writetable(target_table,fullfile(lesson_out,'目标变化率独立计算.csv'));
hand_table=table({'固定2';'2t';'t²';'t³'},hand_exact_rate_deg_s,hand_current_rate_deg_s, ...
    hand_previous_rate_deg_s,hand_exact_acceleration_deg_s2,hand_current_acceleration_deg_s2, ...
    'VariableNames',{'target_formula','exact_rate_deg_s','current_difference_rate_deg_s', ...
    'previous_difference_rate_deg_s','exact_acceleration_deg_s2','current_difference_acceleration_deg_s2'});
writetable(hand_table,fullfile(lesson_out,'四种目标手算核对.csv'));
interval_table=table(sweep_intervals_s',sweep_current_a',sweep_mixed_a',exact_current_at_one_a*ones(3,1), ...
    'VariableNames',{'interval_s','current_difference_current_a','mixed_previous_rate_current_a','exact_rates_current_a'});
writetable(interval_table,fullfile(lesson_out,'固定时刻的三种间隔.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s','reaching_gain_per_s', ...
    'switching_gain_deg_s2','input_gain_deg_s2_per_a','boundary_width_deg_s','output_limits_a', ...
    'interval_s','cpp_tolerance','hand_tolerance','comparison_table','target_table','hand_table','interval_table');
lesson_report.production_cpp_executed=true;
lesson_report.compiler=host_report.compiler_version;
lesson_report.source_hashes=host_report.hashes;
lesson_report.method_count=3;
lesson_report.observation_time_count=numel(time_s);
lesson_report.production_calc_count=height(cpp_table);
lesson_report.interval_s=interval_s;
lesson_report.cpp_comparison_tolerance=cpp_tolerance;
lesson_report.matlab_hand_tolerance=hand_tolerance;
lesson_report.input_column_order={'target_deg','target_rate_deg_s','target_acceleration_deg_s2','measurement_deg','measurement_rate_deg_s'};
lesson_report.max_input_numeric_differences_by_column=max(abs(input_differences),[],1);
lesson_report.result_column_order={'error_deg','error_rate_deg_s','s_deg_s','requested_a','output_a'};
lesson_report.max_result_numeric_differences_by_column=max(abs(result_differences),[],1);
lesson_report.max_cpp_matlab_current_difference_a=max(abs(result_differences(:,5)));
lesson_report.currents_at_one_second_a=cpp_table.output_a(at_one_second)';
lesson_report.sweep_intervals_s=sweep_intervals_s;
lesson_report.sweep_current_difference_currents_a=sweep_current_a;
lesson_report.sweep_mixed_currents_a=sweep_mixed_a;
lesson_report.exact_current_at_one_second_a=exact_current_at_one_a;
lesson_report.reference_c_order_is_only_source_checked=true;
lesson_report.measurement_sequence_generated_by_controller=false;
lesson_report.output_clipping_occurred=false;
lesson_report.checks={'33 次真实当前库回放','目标数据独立构造','当前与旧拍差分展开式', ...
    '每次误差、s 与电流独立核对','t=1 的三种变化率及电流手算', ...
    '四种简单目标的差分手算','三个固定间隔的电流比较','所有点没有限幅'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第16讲通过：33 次真实 C++ 与独立公式核对，电流最大差 %.3g A。\n', ...
    max(abs(result_differences(:,5))));
fprintf('t=1 s：准确、本拍差分、混用旧拍速度的电流为 .9/.577/.331 A。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function output=lesson_sat(value)
    output=max(-1,min(1,value));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson16:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
