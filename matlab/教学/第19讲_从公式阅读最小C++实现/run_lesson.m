%% 第 19 讲：公式、中间项与现有 C++ 的最小调用
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=19。
% MATLAB、pwsh、g++；无 Simulink 或其他工具箱依赖。
% 仅六个正常数值点，不推进对象、不执行下一讲的无效输入与多实例实验。
% 控制参数取自既有 test_support.hpp Config，单位 rad、s、A；范围显式设为 ±3 A。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第19讲_从公式阅读最小C++实现');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',19,'matlab',version, ...
    'experiment','六个可手算点的公式到现有 C++ 映射与独立 MATLAB 比较', ...
    'parameter_source','既有 test_support.hpp Config 教学参数，输出范围本讲显式提供', ...
    'learner_understanding_confirmed',false,'production_sources_modified',false, ...
    'reference_sources_modified',false,'production_cpp_executed',false,'reference_cpp_executed',false, ...
    'plant_state_advanced',false,'hardware_commands_sent',false, ...
    'new_production_algorithm_added',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 先取真实生产库输出，避免只执行 MATLAB 公式就称为已验证 C++
host_script=fullfile(lesson_root,'tests','verify_lesson19.ps1');
[host_status,host_output]=system(sprintf('pwsh -NoProfile -File "%s"',host_script));
assert(host_status==0,'SMC:Lesson19:Host','主机编译或运行失败：\n%s',host_output);
host_report=jsondecode(fileread(fullfile(lesson_out,'主机运行报告.json')));
assert(host_report.passed && host_report.production_cpp_executed && ...
    ~host_report.production_sources_modified && host_report.controller_call_count==6, ...
    'SMC:Lesson19:HostReport','主机报告不满足本讲范围。');
cpp_data=readmatrix(fullfile(lesson_out,'真实C++六点输出.csv'));
assert(isequal(size(cpp_data),[6,12]) && all(isfinite(cpp_data),'all') && ...
    isequal(cpp_data(:,1),(1:6)'), 'SMC:Lesson19:Rows','预期六个有序、有限的真实计算结果。');

%% 输入与手算答案独立写出，不从 C++ 输出生成预期结果
input_gain_rad_s2_per_a=2;
surface_gain_per_s=2;
reaching_gain_per_s=3;
switching_gain_rad_s2=4;
boundary_width_rad_s=2;
output_limits_a=[-3,3];
cpp_tolerance=1e-6;
hand_tolerance=1e-12;
inputs=[0,0,0,.5,0;0,0,0,1,0;0,0,0,-.5,0;3,-4,6,3,-4;0,0,0,0,1;0,0,1,1,-2];
% 手算列：e、error_rate、s、request、output、limited。
hand_results=[.5,0,1,-2.5,-2.5,0;1,0,2,-5,-3,1;-.5,0,-1,2.5,2.5,0; ...
    0,0,0,3,3,0;0,1,1,-3.5,-3,1;1,-2,0,2.5,2.5,0];
assert(max(abs(cpp_data(:,2:6)-inputs),[],'all')<hand_tolerance, ...
    'SMC:Lesson19:Inputs','真实调用输入与本讲六个手算点不符。');

%% MATLAB 按公式独立计算中间项，不给生产库增加暴露内部变量的接口
error_rad=inputs(:,4)-inputs(:,1);
error_rate_rad_s=inputs(:,5)-inputs(:,2);
position_term_rad_s=surface_gain_per_s*error_rad;
sliding_variable_rad_s=error_rate_rad_s+position_term_rad_s;
saturation=max(-1,min(1,sliding_variable_rad_s/boundary_width_rad_s));
rate_term_rad_s2=surface_gain_per_s*error_rate_rad_s;
reaching_term_rad_s2=reaching_gain_per_s*sliding_variable_rad_s;
switching_term_rad_s2=switching_gain_rad_s2*saturation;
requested_acceleration_rad_s2=inputs(:,3)-rate_term_rad_s2-reaching_term_rad_s2-switching_term_rad_s2;
requested_a=requested_acceleration_rad_s2/input_gain_rad_s2_per_a;
output_a=max(output_limits_a(1),min(output_limits_a(2),requested_a));
limited=output_a~=requested_a;
matlab_results=[error_rad,error_rate_rad_s,sliding_variable_rad_s,requested_a,output_a,double(limited)];
assert(max(abs(matlab_results-hand_results),[],'all')<hand_tolerance, ...
    'SMC:Lesson19:Hand','独立公式与预先给定的六点手算不符。');
cpp_minus_matlab=cpp_data(:,7:12)-matlab_results;
assert(max(abs(cpp_minus_matlab),[],'all')<cpp_tolerance, ...
    'SMC:Lesson19:Alignment','真实 C++ 与独立公式不符。');
assert(max(abs(saturation-[.5;1;-.5;0;.5;0]))<hand_tolerance && ...
    isequal(limited,[false;true;false;false;true;false]), ...
    'SMC:Lesson19:Saturation','连续处理量或限幅标志手算不符。');
assert(rate_term_rad_s2(1)==0 && reaching_term_rad_s2(1)==3 && ...
    switching_term_rad_s2(1)==2 && requested_acceleration_rad_s2(1)==-5 && ...
    requested_a(1)==-2.5, 'SMC:Lesson19:MainPoint','点 A 的加速度项与电流换算不符。');

%% 两张图分开使用加速度与电流单位，横轴都是算式项或独立手算点
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1250,660]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
signed_acceleration_terms=[inputs(1,3),-rate_term_rad_s2(1),-reaching_term_rad_s2(1),-switching_term_rad_s2(1)];
bar(signed_acceleration_terms,'FaceColor',[.1,.45,.8]);
xticks(1:4); xticklabels({'目标加速度','-c×ė','-K×s','-ε×sat'});
xlabel('点 A 的四个有符号项'); ylabel('请求角加速度项 / (rad/s²)');
title('MATLAB 独立中间项：0-0-3-2=-5');
ylim([-4,1]); yline(0,'k-','HandleVisibility','off'); grid on;
for item=1:4
    offset=.18;
    if signed_acceleration_terms(item)<0, offset=-.25; end
    label_value=signed_acceleration_terms(item);
    if label_value==0, label_value=0; end % 不把浮点负零显示为 -0。
    text(item,signed_acceleration_terms(item)+offset,sprintf('%g',label_value), ...
        'HorizontalAlignment','center','FontSize',11);
end
nexttile;
bar(cpp_data(:,10:11));
xticks(1:6); xticklabels({'A','B','C','D','E','F'});
xlabel('六个手算点（不是时间轨迹）'); ylabel('真实 C++ 电流 / A');
title('同一生产函数的请求与受限输出');
legend('请求电流','输出电流','Location','southwest');
ylim([-6,4]);
yline(3,'k:','HandleVisibility','off'); yline(-3,'k:','HandleVisibility','off'); grid on;
sgtitle('第19讲：公式对应现有 C++（手算、独立计算与真实库输出）');
exportgraphics(lesson_figure,fullfile(lesson_out,'从公式阅读最小C++实现.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'从公式阅读最小C++实现.fig'));

intermediate_table=table((1:6)',error_rad,error_rate_rad_s,position_term_rad_s,sliding_variable_rad_s, ...
    saturation,rate_term_rad_s2,reaching_term_rad_s2,switching_term_rad_s2,requested_acceleration_rad_s2, ...
    requested_a,output_a,limited,'VariableNames',{'case_number','error_rad','error_rate_rad_s', ...
    'position_term_rad_s','s_rad_s','saturation','rate_term_rad_s2','reaching_term_rad_s2', ...
    'switching_term_rad_s2','requested_acceleration_rad_s2','requested_a','output_a','limited'});
writetable(intermediate_table,fullfile(lesson_out,'独立公式逐项计算.csv'));
result_names={'error_rad','error_rate_rad_s','s_rad_s','requested_a','output_a','limited'};
comparison_names=[{'case_number'},cellfun(@(name)['cpp_',name],result_names,'UniformOutput',false), ...
    cellfun(@(name)['matlab_',name],result_names,'UniformOutput',false), ...
    cellfun(@(name)['difference_',name],result_names,'UniformOutput',false)];
writetable(array2table([(1:6)',cpp_data(:,7:12),matlab_results,cpp_minus_matlab], ...
    'VariableNames',comparison_names),fullfile(lesson_out,'六点C++与MATLAB逐列核对.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'input_gain_rad_s2_per_a','surface_gain_per_s', ...
    'reaching_gain_per_s','switching_gain_rad_s2','boundary_width_rad_s','output_limits_a', ...
    'cpp_tolerance','hand_tolerance','inputs','hand_results','cpp_data','matlab_results', ...
    'cpp_minus_matlab','intermediate_table');
lesson_report.production_cpp_executed=true;
lesson_report.compiler=host_report.compiler_version;
lesson_report.source_hashes=host_report.hashes;
lesson_report.controller_call_count=6;
lesson_report.config_order={'input_gain','surface_gain','reaching_gain','switching_gain','boundary_width'};
lesson_report.config=[2,2,3,4,2];
lesson_report.output_limits_a=output_limits_a;
lesson_report.result_column_order=result_names;
lesson_report.cpp_comparison_tolerance=cpp_tolerance;
lesson_report.matlab_hand_tolerance=hand_tolerance;
lesson_report.max_numeric_difference_by_column=max(abs(cpp_minus_matlab),[],1);
lesson_report.max_current_difference_a=max(abs(cpp_minus_matlab(:,5)));
lesson_report.cpp_requested_currents_a=cpp_data(:,10)';
lesson_report.cpp_output_currents_a=cpp_data(:,11)';
lesson_report.cpp_limited=logical(cpp_data(:,12)');
lesson_report.main_point_requested_acceleration_rad_s2=requested_acceleration_rad_s2(1);
lesson_report.main_point_output_a=cpp_data(1,11);
lesson_report.intermediate_terms_are_independent_matlab_values=true;
lesson_report.checks={'主手算点的逐项公式','六个输入与预设手算答案', ...
    '真实 C++ 误差、s、请求与输出逐列核对','连续处理阈值与最终电流限幅分开', ...
    '边界请求未改变时标志为 false','目标加速度与速度误差仍参与计算', ...
    '只增加调用例子，不增加生产算法实现'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第19讲通过：六个真实 C++ 点与独立公式核对，电流最大差 %.3g A。\n', ...
    lesson_report.max_current_difference_a);
fprintf('点 A：括号内请求角加速度 -5 rad/s²，除以 b=2 后电流 -2.5 A。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson19:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
