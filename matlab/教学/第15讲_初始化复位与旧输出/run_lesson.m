%% 第 15 讲：初始化、目标历史、复位与调用方旧输出
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=15。
% 依赖 MATLAB、pwsh、g++。调用真实原参考与当前库，MATLAB 独立核对。
% 教学单位 °、s、A；原参考仍有混合单位，原输出仅称数字。
% 仅观测调用事件，不推进对象状态、不发送硬件命令、不运行参考 C/B。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第15讲_初始化复位与旧输出');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',15,'matlab',version, ...
    'experiment','原参考历史状态与当前库复位行为的真实 C++ 和独立事件重放', ...
    'parameter_source','教学假设，非机器人参数','learner_understanding_confirmed',false, ...
    'reference_sources_modified',false,'production_sources_modified',false, ...
    'original_cpp_executed',false,'production_cpp_executed',false, ...
    'plant_state_advanced',false,'hardware_commands_sent',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 每次运行都先重新编译并获取真实数据，防止把旧 CSV 作为本轮证据
host_script=fullfile(lesson_root,'tests','verify_lesson15.ps1');
[host_status,host_output]=system(sprintf('pwsh -NoProfile -File "%s"',host_script));
assert(host_status==0,'SMC:Lesson15:Host','主机编译或回放失败：\n%s',host_output);
host_report=jsondecode(fileread(fullfile(lesson_out,'主机回放报告.json')));
assert(host_report.passed && host_report.original_cpp_executed && host_report.production_cpp_executed ...
    && ~host_report.reference_sources_modified && ~host_report.production_sources_modified, ...
    'SMC:Lesson15:HostReport','主机回放报告不满足本讲要求。');
raw_table=readtable(fullfile(lesson_out,'原参考A真实回放.csv'));
production_table=readtable(fullfile(lesson_out,'当前库真实回放.csv'));
assert(height(raw_table)==14 && height(production_table)==8 && sum(raw_table.called)==12, ...
    'SMC:Lesson15:Rows','观察事件或原函数调用次数不符。');
cpp_tolerance=5e-6; % 比较前固定，不在结果出现后放宽。
surface_gain_per_s=.5;
reaching_gain_per_s=1;
switching_gain_deg_s2=2;
raw_multiplier=.2;
raw_deadzone_deg=.1;
raw_limit_value=1000;
input_gain_deg_s2_per_a=5;
boundary_width_deg_s=1;

%% 独立重放原参考：静态存储初始历史为零；每个案例有自己的状态
saved_target=zeros(4,1);
saved_difference=zeros(4,1);
saved_output=zeros(4,1);
raw_expected_output=zeros(14,1);
raw_expected_before=zeros(14,1);
raw_refl_before=zeros(14,1);
raw_refl_after=zeros(14,1);
raw_dref_after=zeros(14,1);
raw_ddref_this_event=NaN(14,1);
raw_early_return=false(14,1);
for row=1:height(raw_table)
    scenario=raw_table.case_number(row);
    raw_expected_before(row)=saved_output(scenario);
    raw_refl_before(row)=saved_target(scenario);
    if raw_table.called(row)
        target=raw_table.target_deg(row);
        error_value=raw_table.measurement_deg(row)-target;
        ddref=(target-saved_target(scenario))-saved_difference(scenario);
        dref=target-saved_target(scenario);
        saved_difference(scenario)=dref;
        raw_ddref_this_event(row)=ddref;
        if abs(error_value)<raw_deadzone_deg
            saved_output(scenario)=0;
            raw_early_return(row)=true;
            % 原代码此处结束：不得继续更新 saved_target。
        else
            error_rate_value=raw_table.measurement_rate_deg_s(row)-dref;
            s_value=surface_gain_per_s*error_value+error_rate_value;
            requested=raw_multiplier*(ddref-surface_gain_per_s*error_rate_value ...
                -switching_gain_deg_s2*lesson_sat(s_value)-reaching_gain_per_s*s_value);
            saved_output(scenario)=max(-raw_limit_value,min(raw_limit_value,requested));
            assert(saved_output(scenario)==requested,'SMC:Lesson15:Clipping','本讲不应触发限幅。');
            saved_target(scenario)=target;
        end
    end
    % 未调用时，原代码的历史和输出全部保持。
    raw_expected_output(row)=saved_output(scenario);
    raw_refl_after(row)=saved_target(scenario);
    raw_dref_after(row)=saved_difference(scenario);
end
raw_difference=raw_table.raw_output_value-raw_expected_output;
max_raw_difference=max(abs(raw_difference));
assert(max_raw_difference<cpp_tolerance && ...
    max(abs(raw_table.output_before_value-raw_expected_before))<cpp_tolerance, ...
    'SMC:Lesson15:RawAlignment','原参考真实 C++ 与独立事件重放不符。');
expected_hand=[2.8;-1.3;-.3;-.3;0;0;1.4;-.3;-.3;-.3;2.8;-1.3;-.3;0];
assert(max(abs(raw_expected_output-expected_hand))<1e-12, ...
    'SMC:Lesson15:RawHand','原参考启动、死区、暂停或通过目标的手算不符。');
deadzone_rows=raw_table.case_number==2;
assert(isequal(raw_refl_after(deadzone_rows),[0;0;0;3]) && ...
    isequal(raw_dref_after(deadzone_rows),[0;1;2;3]) && sum(raw_early_return)==3, ...
    'SMC:Lesson15:History','死区返回应只推进部分目标历史。');
paused=raw_table.called==0;
assert(all(raw_table.case_number(paused)==3) && ...
    max(abs(raw_table.raw_output_value(paused)+.3))<cpp_tolerance && ...
    all(raw_refl_after(paused)==0 & raw_dref_after(paused)==0), ...
    'SMC:Lesson15:Pause','暂停调用不应自动清输出或推进历史。');

%% 独立重放当前库与调用方变量：操作 0观察、1Init、2Calc、3Reset、4调用方赋零
assert(isequal(production_table.operation_code,[0;1;2;2;3;4;2;2]) && ...
    isequal(production_table.return_code,[-1;1;1;1;1;-1;1;1]), ...
    'SMC:Lesson15:Operations','当前库事件顺序或成功返回值不符。');
expected_initialized=false;
expected_has_result=false;
expected_command=17;
expected_result_requested=0;
expected_result_output=0;
expected_result_s=0;
production_expected=zeros(8,6);
for row=1:height(production_table)
    operation=production_table.operation_code(row);
    switch operation
        case 0
            % 仅观察默认对象；不在未初始化时读取未定义的数据或执行控制。
        case 1
            expected_initialized=true;
            expected_has_result=false;
            expected_result_requested=0;
            expected_result_output=0;
            expected_result_s=0;
        case 2
            assert(expected_initialized,'SMC:Lesson15:InitOrder','计算之前必须成功初始化。');
            error_deg=production_table.measurement_deg(row)-production_table.target_deg(row);
            error_rate_deg_s=production_table.measurement_rate_deg_s(row)-production_table.target_rate_deg_s(row);
            expected_result_s=error_rate_deg_s+surface_gain_per_s*error_deg;
            expected_result_requested=(production_table.target_acceleration_deg_s2(row) ...
                -surface_gain_per_s*error_rate_deg_s-reaching_gain_per_s*expected_result_s ...
                -switching_gain_deg_s2*lesson_sat(expected_result_s/boundary_width_deg_s)) ...
                /input_gain_deg_s2_per_a;
            expected_result_output=max(-1000,min(1000,expected_result_requested));
            expected_command=expected_result_output;
            expected_has_result=true;
        case 3
            expected_has_result=false;
            expected_result_requested=0;
            expected_result_output=0;
            expected_result_s=0;
            % expected_command 不属于控制器内部，Reset 不得代为赋值。
        case 4
            expected_command=0;
    end
    production_expected(row,:)=[expected_command,expected_initialized,expected_has_result, ...
        expected_result_requested,expected_result_output,expected_result_s];
end
production_actual=[production_table.caller_command_a,production_table.is_initialized, ...
    production_table.has_result,production_table.result_requested_a, ...
    production_table.result_output_a,production_table.result_s_deg_s];
production_difference=production_actual-production_expected;
max_production_difference=max(abs(production_difference),[],'all');
assert(max_production_difference<cpp_tolerance, ...
    'SMC:Lesson15:ProductionAlignment','当前库真实状态、输出或公式与独立重放不符。');
config_actual=[production_table.input_gain_deg_s2_per_a,production_table.surface_gain_per_s, ...
    production_table.reaching_gain_per_s,production_table.switching_gain_deg_s2, ...
    production_table.boundary_width_deg_s,production_table.output_min_a,production_table.output_max_a];
assert(all(config_actual(2:end,:)==[5,.5,1,2,1,-1000,1000],'all') && ...
    isequal(production_expected(:,1),[17;17;-.3;-.3;-.3;0;-.3;-1.3]) && ...
    isequal(production_expected(:,3),[0;0;1;1;0;0;1;1]), ...
    'SMC:Lesson15:Reset','配置保留、调用方命令或诊断有效性不符。');
assert(abs(production_table.caller_command_a(3)-production_table.caller_command_a(7))<cpp_tolerance && ...
    production_table.has_result(5)==0 && production_table.result_output_a(5)==0 && ...
    abs(production_table.caller_command_a(5)+.3)<cpp_tolerance, ...
    'SMC:Lesson15:Restart','复位后应清诊断、保留调用方变量，同输入重算结果一致。');

%% 四张图的序号均为观察事件，不是物理时间；原输出数字与当前电流分开
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1400,930]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
startup_rows=raw_table.case_number==1;
bar(raw_table.raw_output_value(startup_rows),'FaceColor',[.85,.3,.1]);
xticks(1:3); xticklabels({'第一次','第二次','第三次'});
xlabel('相同输入，目标一直为 5°'); ylabel('原参考输出数字（无 A 单位）');
title('非零目标、零历史：输入相同，前三拍结果不同'); grid on;
nexttile;
plot(1:4,raw_table.target_deg(deadzone_rows),'-o','LineWidth',1.8); hold on;
plot(1:4,raw_refl_after(deadzone_rows),'--s','LineWidth',1.8);
xticks(1:4); xticklabels({'计算','死区返回','死区返回','离开死区'});
xlabel('原参考的四次调用事件'); ylabel('目标角度 / °');
title('MATLAB 重建：死区期间 refl 未更新');
legend('本次目标 ref','调用后保存的 refl','Location','northwest'); grid on;
nexttile;
pause_rows=raw_table.case_number==3;
bar(raw_table.raw_output_value(pause_rows),'FaceColor',[.1,.45,.8]);
xticks(1:6); xticklabels({'先计算','暂停','暂停','恢复1','恢复2','恢复3'});
xlabel('暂停时将目标改为 5°，没有调用原函数'); ylabel('原参考输出数字（无 A 单位）');
title('不调用时旧输出保留，恢复后仍受旧历史影响'); grid on;
nexttile;
display_rows=3:7; % 不在图中展示默认观察标记 17，以免掩盖 .3 A 量级变化。
bar([production_table.caller_command_a(display_rows),production_table.result_output_a(display_rows)]);
xticks(1:5); xticklabels({'计算','再算','Reset','外部赋零','重算'});
xlabel('当前库与调用方的五个独立事件'); ylabel('数值 / A');
title('Reset 清诊断；调用方变量另行清理');
legend('调用方命令变量','内部诊断数字','Location','southwest');
text(3,-.04,'诊断无效','HorizontalAlignment','center','FontSize',10);
text(4,-.04,'诊断无效','HorizontalAlignment','center','FontSize',10);
ylim([-.42,.08]); grid on;
sgtitle('第15讲：初始化、复位与旧输出（真实 C++ 观察与独立事件重放）');
exportgraphics(lesson_figure,fullfile(lesson_out,'初始化复位与旧输出.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'初始化复位与旧输出.fig'));

raw_replay_table=raw_table;
raw_replay_table.matlab_expected_output_value=raw_expected_output;
raw_replay_table.matlab_refl_before_deg=raw_refl_before;
raw_replay_table.matlab_refl_after_deg=raw_refl_after;
raw_replay_table.matlab_dref_after_deg=raw_dref_after;
raw_replay_table.matlab_ddref_this_event_deg=raw_ddref_this_event;
raw_replay_table.matlab_early_return=raw_early_return;
raw_replay_table.cpp_minus_matlab_value=raw_difference;
writetable(raw_replay_table,fullfile(lesson_out,'原参考A与独立历史重放.csv'));
production_replay_table=production_table;
production_replay_table.matlab_command_a=production_expected(:,1);
production_replay_table.matlab_has_result=production_expected(:,3);
production_replay_table.matlab_result_output_a=production_expected(:,5);
production_replay_table.cpp_minus_matlab_command_a=production_difference(:,1);
writetable(production_replay_table,fullfile(lesson_out,'当前库与独立事件重放.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s','reaching_gain_per_s', ...
    'switching_gain_deg_s2','raw_multiplier','raw_deadzone_deg','raw_limit_value', ...
    'input_gain_deg_s2_per_a','boundary_width_deg_s','cpp_tolerance', ...
    'raw_replay_table','production_replay_table','production_expected','production_difference');
lesson_report.original_cpp_executed=true;
lesson_report.production_cpp_executed=true;
lesson_report.compiler=host_report.compiler_version;
lesson_report.source_hashes=host_report.hashes;
lesson_report.reference_event_count=height(raw_table);
lesson_report.reference_actual_call_count=sum(raw_table.called);
lesson_report.production_event_count=height(production_table);
lesson_report.production_calc_count=sum(production_table.operation_code==2);
lesson_report.cpp_comparison_tolerance=cpp_tolerance;
lesson_report.max_raw_cpp_matlab_difference_value=max_raw_difference;
lesson_report.max_production_cpp_matlab_difference_value=max_production_difference;
lesson_report.raw_startup_output_values=raw_table.raw_output_value(startup_rows)';
lesson_report.raw_deadzone_output_values=raw_table.raw_output_value(deadzone_rows)';
lesson_report.command_after_reset_a=production_table.caller_command_a(5);
lesson_report.diagnostic_after_reset_a=production_table.result_output_a(5);
lesson_report.has_result_after_reset=logical(production_table.has_result(5));
lesson_report.raw_output_has_validated_ampere_mapping=false;
lesson_report.static_zero_initialized_reference_instances=true;
lesson_report.indeterminate_local_reference_instance_executed=false;
lesson_report.reference_b_or_c_executed=false;
lesson_report.checks={'原参考 14 个事件独立重放','非零目标启动三拍手算', ...
    '死区期间只更新部分历史','暂停调用保留旧输出与历史','位置匹配但仍有速度的原返回', ...
    '当前库 8 个事件独立重放','默认与初始化尚无计算结果','复位保留参数和范围', ...
    '复位清诊断但不改调用方变量','调用方赋零与复位分开','同输入重新计算结果一致'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第15讲通过：原参考 14 事件、当前库 8 事件与独立重放一致。\n');
fprintf('最大差：原参考 %.3g，当前库 %.3g；Reset 后调用方变量仍为 %.3f A。\n', ...
    max_raw_difference,max_production_difference,production_table.caller_command_a(5));
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function output=lesson_sat(value)
    output=max(-1,min(1,value));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson15:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
