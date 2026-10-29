%% 第 14 讲：原参考 A 的真实 C++ 回放与公式逐句对照
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=14。
% 依赖 MATLAB、PowerShell 7 (pwsh)、g++；不依赖 Simulink。
% 原参考只读。C++ 编译真实原文件；MATLAB 独立重放运算并另作单位一致的计算。
% 教学单位 °、s、A。原代码输出仅记录数值，不据此声称原输出已映射到安培。
% 目标 r(t)=t² °；每种间隔调用三次，最终都是 t=1 s，前两次只建立历史。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第14讲_原参考代码与公式逐句对照');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',14,'matlab',version, ...
    'experiment','原参考真实 C++、独立逐次重放及统一单位的三种间隔对照', ...
    'parameter_source','教学假设，非原工程参数','learner_understanding_confirmed',false, ...
    'library_modified',false,'reference_sources_modified',false, ...
    'production_controller_executed',false,'original_cpp_executed',false, ...
    'plant_state_advanced',false,'hardware_simulated',false, ...
    'deadzone_branch_exercised',false,'output_clipping_exercised',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 真实编译与调用原参考，不复用可能过时的输出文件
host_script=fullfile(lesson_root,'tests','verify_reference_a.ps1');
[host_status,host_output]=system(sprintf('pwsh -NoProfile -File "%s"',host_script));
assert(host_status==0,'SMC:Lesson14:Host', ...
    '原参考编译或运行失败，请检查 pwsh、g++ 及主机脚本：\n%s',host_output);
host_report=jsondecode(fileread(fullfile(lesson_out,'原参考A主机编译报告.json')));
assert(host_report.passed && host_report.original_cpp_executed && ~host_report.reference_sources_modified, ...
    'SMC:Lesson14:HostReport','原函数真实运行报告不满足本讲要求。');
host_table=readtable(fullfile(lesson_out,'原参考A真实C++输出.csv'));
assert(height(host_table)==9 && isequal(host_table.case_number,repelem((1:3)',3)) && ...
    isequal(host_table.sample_number,repmat((1:3)',3,1)), ...
    'SMC:Lesson14:Rows','预期三个独立案例，每个按顺序调用三次。');

%% 与 C++ 回放一致的教学参数；原数值宽度 1 对应统一对照 phi=1°/s
surface_gain_per_s=.5;
reaching_gain_per_s=1;
switching_gain_deg_s2=2;
input_gain_deg_s2_per_a=5;
boundary_width_deg_s=1;
raw_multiplier_value=.2;
raw_deadzone_value=0;
raw_output_limit_value=1000;
cpp_comparison_tolerance=5e-6; % 预先固定；原 C++ float 与 MATLAB double 的数值精度不同。

%% 独立按原源码顺序重放九次：不加 h，不改 J，不修正提前返回逻辑
raw_refl=zeros(3,1);
raw_dref_history=zeros(3,1);
replay_dref=zeros(9,1);
replay_ddref=zeros(9,1);
replay_s=zeros(9,1);
replay_output=zeros(9,1);
for row=1:height(host_table)
    scenario=host_table.case_number(row);
    target=host_table.target_deg(row);
    measurement=host_table.measurement_deg(row);
    measured_rate=host_table.measurement_rate_deg_s(row);
    error_value=measurement-target;
    ddref=(target-raw_refl(scenario))-raw_dref_history(scenario);
    dref=target-raw_refl(scenario);
    raw_dref_history(scenario)=dref;
    assert(abs(error_value)>=raw_deadzone_value && error_value>.9, ...
        'SMC:Lesson14:Branch','本讲只核对未提前返回的分支。');
    sliding=surface_gain_per_s*error_value+(measured_rate-dref);
    requested=raw_multiplier_value*(ddref-surface_gain_per_s*(measured_rate-dref) ...
        -switching_gain_deg_s2*lesson_sat(sliding)-reaching_gain_per_s*sliding);
    output=max(-raw_output_limit_value,min(raw_output_limit_value,requested));
    assert(output==requested,'SMC:Lesson14:Clipping','本讲参数不应触发最终限幅。');
    raw_refl(scenario)=target;
    replay_dref(row)=dref;
    replay_ddref(row)=ddref;
    replay_s(row)=sliding;
    replay_output(row)=output;
end
cpp_difference=host_table.raw_cpp_output_value-replay_output;
max_cpp_difference=max(abs(cpp_difference));
assert(max_cpp_difference<cpp_comparison_tolerance, ...
    'SMC:Lesson14:CppAlignment','独立原写法重放与真实原 C++ 结果不符。');

%% 独立目标公式：在同一个 t=1 s，按三种间隔取相邻目标值
intervals_s=[.01,.1,1];
observation_time_s=1;
target_deg=observation_time_s^2;
previous_target_deg=(observation_time_s-intervals_s).^2;
previous_previous_target_deg=(observation_time_s-2*intervals_s).^2;
raw_first_difference_deg=target_deg-previous_target_deg;
raw_second_difference_deg=target_deg-2*previous_target_deg+previous_previous_target_deg;
target_rate_from_difference_deg_s=raw_first_difference_deg./intervals_s;
target_acceleration_from_difference_deg_s2=raw_second_difference_deg./intervals_s.^2;
assert(max(abs(raw_first_difference_deg-[.0199,.19,1]))<1e-12 && ...
    max(abs(raw_second_difference_deg-[.0002,.02,2]))<1e-12 && ...
    max(abs(target_rate_from_difference_deg_s-[1.99,1.9,1]))<1e-12 && ...
    max(abs(target_acceleration_from_difference_deg_s2-2))<1e-12, ...
    'SMC:Lesson14:DifferenceHand','原目标差或时间换算后的手算不符。');
final_rows=host_table.sample_number==3;
final_cpp_output=host_table.raw_cpp_output_value(final_rows)';
assert(max(abs(replay_dref(final_rows)'-raw_first_difference_deg))<cpp_comparison_tolerance && ...
    max(abs(replay_ddref(final_rows)'-raw_second_difference_deg))<cpp_comparison_tolerance && ...
    max(abs(final_cpp_output-[-1.09399,-1.039,-.4]))<cpp_comparison_tolerance, ...
    'SMC:Lesson14:FinalRaw','原 C++ 最后一拍的差分或输出手算不符。');

%% 单位一致的对照：准确变化率与差分近似分开，不把它们写进原代码
measurement_deg=2;
measurement_rate_deg_s=2;
error_deg=measurement_deg-target_deg;
exact_target_rate_deg_s=2*observation_time_s;
exact_target_acceleration_deg_s2=2;
exact_error_rate_deg_s=measurement_rate_deg_s-exact_target_rate_deg_s;
exact_s_deg_s=surface_gain_per_s*error_deg+exact_error_rate_deg_s;
exact_current_a=(exact_target_acceleration_deg_s2-surface_gain_per_s*exact_error_rate_deg_s ...
    -reaching_gain_per_s*exact_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(exact_s_deg_s/boundary_width_deg_s))/input_gain_deg_s2_per_a;
difference_error_rate_deg_s=measurement_rate_deg_s-target_rate_from_difference_deg_s;
difference_s_deg_s=surface_gain_per_s*error_deg+difference_error_rate_deg_s;
difference_current_a=(target_acceleration_from_difference_deg_s2 ...
    -surface_gain_per_s*difference_error_rate_deg_s-reaching_gain_per_s*difference_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(difference_s_deg_s/boundary_width_deg_s))/input_gain_deg_s2_per_a;
assert(abs(exact_current_a-.1)<1e-12 && ...
    max(abs(difference_current_a-[.093,.03,-.4]))<1e-12, ...
    'SMC:Lesson14:UnifiedHand','统一单位后的电流手算不符。');
exact_rate_from_plant_deg_s2=input_gain_deg_s2_per_a*exact_current_a ...
    -exact_target_acceleration_deg_s2+surface_gain_per_s*exact_error_rate_deg_s;
exact_desired_rate_deg_s2=-reaching_gain_per_s*exact_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(exact_s_deg_s/boundary_width_deg_s);
assert(abs(exact_rate_from_plant_deg_s2-exact_desired_rate_deg_s2)<1e-12, ...
    'SMC:Lesson14:ExactSubstitution','准确变化率的电流代回对象后不满足期望关系。');

%% J 与倒数：静止目标，e=1°、error_rate=0，phi=1°/s
coefficient_example_s_deg_s=surface_gain_per_s;
bracket_deg_s2=-reaching_gain_per_s*coefficient_example_s_deg_s ...
    -switching_gain_deg_s2*lesson_sat(coefficient_example_s_deg_s/boundary_width_deg_s);
divide_current_a=bracket_deg_s2/input_gain_deg_s2_per_a;
inverse_multiply_current_a=(1/input_gain_deg_s2_per_a)*bracket_deg_s2;
wrong_same_gain_output_value=input_gain_deg_s2_per_a*bracket_deg_s2;
assert(abs(bracket_deg_s2+1.5)<1e-12 && abs(divide_current_a+.3)<1e-12 && ...
    abs(divide_current_a-inverse_multiply_current_a)<1e-12 && ...
    abs(wrong_same_gain_output_value+7.5)<1e-12, ...
    'SMC:Lesson14:Inverse','对象输入系数和括号外乘法系数应互为倒数。');

%% 图像：不同单位分开画；原输出列只标数值，不擅自赋予安培单位
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1400,930]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
interval_labels={'0.01','0.1','1'};
nexttile;
bar(raw_first_difference_deg,'FaceColor',[.1,.45,.8]);
xticks(1:3); xticklabels(interval_labels);
xlabel('计算间隔 h / s'); ylabel('原 dref：目标角度差 / °');
title('同一目标运动，原 dref 随间隔改变'); grid on;
nexttile;
bar(final_cpp_output,'FaceColor',[.85,.3,.1]);
xticks(1:3); xticklabels(interval_labels);
xlabel('计算间隔 h / s'); ylabel('原 C++ 输出数字（不赋予 A 单位）');
title('三个案例最后一拍都是 t=1 s 的相同运动数据'); grid on;
nexttile;
bar([target_rate_from_difference_deg_s',exact_target_rate_deg_s*ones(3,1)]);
xticks(1:3); xticklabels(interval_labels);
xlabel('计算间隔 h / s'); ylabel('目标角速度 / (°/s)');
title('除以 h 后单位一致，区间平均仍不等于当前速度');
legend('相邻差 / h','准确当前速度','Location','southwest'); grid on;
nexttile;
bar([difference_current_a',exact_current_a*ones(3,1)]);
xticks(1:3); xticklabels(interval_labels);
xlabel('计算间隔 h / s'); ylabel('统一单位的请求电流 / A');
title('差分近似与准确变化率仍需分开');
legend('使用变化率差分近似','使用准确变化率','Location','southwest');
yline(0,'k-','HandleVisibility','off'); grid on;
sgtitle('第14讲：原代码、单位换算与准确变化率分别核对（教学参数）');
exportgraphics(lesson_figure,fullfile(lesson_out,'原参考代码与公式逐句对照.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'原参考代码与公式逐句对照.fig'));

replay_table=host_table;
replay_table.matlab_raw_dref=replay_dref;
replay_table.matlab_raw_ddref=replay_ddref;
replay_table.matlab_raw_s_value=replay_s;
replay_table.matlab_raw_output_value=replay_output;
replay_table.cpp_minus_matlab_value=cpp_difference;
writetable(replay_table,fullfile(lesson_out,'原C++与MATLAB逐次比较.csv'));
comparison_table=table(intervals_s',raw_first_difference_deg',raw_second_difference_deg', ...
    target_rate_from_difference_deg_s',target_acceleration_from_difference_deg_s2', ...
    final_cpp_output',difference_current_a',exact_current_a*ones(3,1), ...
    'VariableNames',{'interval_s','raw_dref_deg','raw_ddref_deg','difference_target_rate_deg_s', ...
    'difference_target_acceleration_deg_s2','raw_cpp_output_value', ...
    'unit_consistent_difference_current_a','exact_derivatives_current_a'});
writetable(comparison_table,fullfile(lesson_out,'三种间隔的独立比较.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s','reaching_gain_per_s', ...
    'switching_gain_deg_s2','input_gain_deg_s2_per_a','boundary_width_deg_s', ...
    'raw_multiplier_value','raw_deadzone_value','raw_output_limit_value','cpp_comparison_tolerance', ...
    'observation_time_s','measurement_deg','measurement_rate_deg_s','bracket_deg_s2', ...
    'divide_current_a','inverse_multiply_current_a','wrong_same_gain_output_value','replay_table','comparison_table');
lesson_report.original_cpp_executed=true;
lesson_report.compiler=host_report.compiler_version;
lesson_report.source_hashes=host_report.hashes;
lesson_report.original_cpp_call_count=height(host_table);
lesson_report.intervals_s=intervals_s;
lesson_report.source_uses_static_zero_initialized_instances=true;
lesson_report.cpp_comparison_tolerance=cpp_comparison_tolerance;
lesson_report.max_cpp_matlab_difference_value=max_cpp_difference;
lesson_report.final_cpp_output_values=final_cpp_output;
lesson_report.unit_consistent_difference_currents_a=difference_current_a;
lesson_report.exact_derivatives_current_a=exact_current_a;
lesson_report.raw_output_has_validated_ampere_mapping=false;
lesson_report.input_gain_deg_s2_per_a=input_gain_deg_s2_per_a;
lesson_report.code_multiplier_value=raw_multiplier_value;
lesson_report.boundary_width_deg_s=boundary_width_deg_s;
lesson_report.correct_coefficient_example_current_a=divide_current_a;
lesson_report.wrong_coefficient_example_output_value=wrong_same_gain_output_value;
lesson_report.checks={'九次真实原 C++ 与独立重放比较','三个间隔的目标差手算', ...
    '一次除以 h、二次除以 h²','原 C++ 末拍输出手算','统一单位的差分近似电流', ...
    '准确变化率电流及对象代回','对象系数与乘法系数倒数关系', ...
    '来源未修改、未经过死区返回及限幅'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第14讲通过：原参考 C++ 九次调用与独立重放最大差 %.3g。\n',max_cpp_difference);
fprintf('统一单位的差分电流为 .093/.03/-.4 A，准确变化率电流均为 .1 A。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function output=lesson_sat(input_value)
    output=max(-1,min(1,input_value));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson14:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
