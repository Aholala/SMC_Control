%% 第 13 讲：输出限幅怎样改变当前时刻的趋近关系
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=13。
% MATLAB 基础功能；全部参数为教学假设，单位 rad、s、A。
% 先计算完整请求，再限幅，再经对象关系独立重建实际 s 变化率。
% 仅检查当前状态点，不推进对象、不运行生产库或完整位置闭环。
% 模型准确、输入即时执行；除单独的扰动反例，其余检查 d=0。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第13讲_输出限幅怎样改变趋近关系');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',13,'matlab',version, ...
    'experiment','请求电流、受限电流与独立对象代回的当前状态点检查', ...
    'parameter_source','教学假设，非实测','learner_understanding_confirmed',false, ...
    'library_modified',false,'production_controller_executed',false, ...
    'closed_loop_position_simulated',false,'plant_state_advanced',false, ...
    'continuous_sat_rule',true,'full_current_clipped',true, ...
    'hardware_current_measured',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 七个手算场景：b、e、error_rate、target_acceleration、lower、upper
surface_gain_per_s=.5;
reaching_gain_per_s=1;
switching_gain_rad_s2=2;
boundary_width_rad_s=.1;
cases=[5,1,0,0,-1,1; ...
       5,1,0,0,-.2,.2; ...
       5,-1,0,0,-.2,.2; ...
       5,1,2,0,-.2,.2; ...
       5,1,3,0,-.2,.2; ...
       5,0,0,2,-.2,.2; ...
       -5,1,0,0,-.2,.2];
case_s_rad_s=cases(:,3)+surface_gain_per_s*cases(:,2);
case_desired_rate_rad_s2=-reaching_gain_per_s*case_s_rad_s ...
    -switching_gain_rad_s2*lesson_sat(case_s_rad_s/boundary_width_rad_s);
case_requested_a=(cases(:,4)-surface_gain_per_s*cases(:,3) ...
    +case_desired_rate_rad_s2)./cases(:,1);
case_output_a=lesson_clip(case_requested_a,cases(:,5),cases(:,6));
case_limited=case_output_a~=case_requested_a;
% 独立对象路径：执行电流 -> 实际角加速度 -> 误差加速度 -> s 变化率。
case_plant_acceleration_rad_s2=cases(:,1).*case_output_a;
case_error_acceleration_rad_s2=case_plant_acceleration_rad_s2-cases(:,4);
case_actual_rate_rad_s2=case_error_acceleration_rad_s2+surface_gain_per_s*cases(:,3);
case_current_difference_a=case_output_a-case_requested_a;
case_rate_from_residual_rad_s2=case_desired_rate_rad_s2+cases(:,1).*case_current_difference_a;
case_v_rate_rad2_s3=case_s_rad_s.*case_actual_rate_rad_s2;
assert(max(abs(case_requested_a-[-.5;-.5;.5;-1.1;-1.4;.4;.5]))<1e-12 && ...
    max(abs(case_output_a-[-.5;-.2;.2;-.2;-.2;.2;.2]))<1e-12, ...
    'SMC:Lesson13:HandCurrent','七个场景的请求或执行电流与手算不符。');
assert(max(abs(case_desired_rate_rad_s2-[-2.5;-2.5;2.5;-4.5;-5.5;0;-2.5]))<1e-12 && ...
    max(abs(case_actual_rate_rad_s2-[-2.5;-1;1;0;.5;-1;-1]))<1e-12, ...
    'SMC:Lesson13:HandRate','期望或实际 s 变化率与手算不符。');
assert(max(abs(case_v_rate_rad2_s3-[-1.25;-.5;-.5;0;1.75;0;-.5]))<1e-12 && ...
    max(abs(case_actual_rate_rad_s2-case_rate_from_residual_rad_s2))<1e-12, ...
    'SMC:Lesson13:Residual','V 变化率或限幅差额恒等式不符。');
assert(isequal(case_limited,[false;true;true;true;true;true;true]) && ...
    case_s_rad_s(6)==0 && case_actual_rate_rad_s2(6)~=0, ...
    'SMC:Lesson13:Flags','限幅标记或加速目标例子不符。');

%% 1470 个状态点：两个方向 × 七个误差 × 七个变化率 × 三种目标加速度 × 五种范围
gain_values_rad_s2_per_a=[-5,5];
error_values_rad=[-2,-1,-.1,0,.1,1,2];
rate_values_rad_s=[-3,-2,-.5,0,.5,2,3];
target_acceleration_values_rad_s2=[-2,0,2];
output_ranges_a=[-1,1;-.2,.2;0,.2;0,0;-.2,.1];
[grid_gain,grid_error,grid_error_rate,grid_target_acc,grid_range_index]=ndgrid( ...
    gain_values_rad_s2_per_a,error_values_rad,rate_values_rad_s, ...
    target_acceleration_values_rad_s2,1:size(output_ranges_a,1));
grid_gain=grid_gain(:);
grid_error=grid_error(:);
grid_error_rate=grid_error_rate(:);
grid_target_acc=grid_target_acc(:);
grid_range_index=grid_range_index(:);
grid_lower_a=output_ranges_a(grid_range_index,1);
grid_upper_a=output_ranges_a(grid_range_index,2);
grid_s_rad_s=grid_error_rate+surface_gain_per_s*grid_error;
grid_desired_rate_rad_s2=-reaching_gain_per_s*grid_s_rad_s ...
    -switching_gain_rad_s2*lesson_sat(grid_s_rad_s/boundary_width_rad_s);
grid_requested_a=(grid_target_acc-surface_gain_per_s*grid_error_rate ...
    +grid_desired_rate_rad_s2)./grid_gain;
grid_output_a=lesson_clip(grid_requested_a,grid_lower_a,grid_upper_a);
grid_limited=grid_output_a~=grid_requested_a;
grid_actual_rate_rad_s2=grid_gain.*grid_output_a-grid_target_acc+surface_gain_per_s*grid_error_rate;
grid_current_difference_a=grid_output_a-grid_requested_a;
grid_residual_rate_rad_s2=grid_desired_rate_rad_s2+grid_gain.*grid_current_difference_a;
grid_difference_rad_s2=grid_actual_rate_rad_s2-grid_residual_rate_rad_s2;
grid_v_rate_rad2_s3=grid_s_rad_s.*grid_actual_rate_rad_s2;
grid_expanded_v_rate_rad2_s3=-reaching_gain_per_s*grid_s_rad_s.^2 ...
    -switching_gain_rad_s2*grid_s_rad_s.*lesson_sat(grid_s_rad_s/boundary_width_rad_s) ...
    +grid_s_rad_s.*grid_gain.*grid_current_difference_a;
assert(numel(grid_gain)==1470 && max(abs(grid_difference_rad_s2))<1e-12 && ...
    max(abs(grid_v_rate_rad2_s3-grid_expanded_v_rate_rad2_s3))<1e-12, ...
    'SMC:Lesson13:GridIdentity','网格点数或两条代回路径不符。');
inside=grid_requested_a>=grid_lower_a & grid_requested_a<=grid_upper_a;
assert(all(grid_output_a>=grid_lower_a & grid_output_a<=grid_upper_a) && ...
    isequal(grid_output_a(inside),grid_requested_a(inside)) && ...
    all(grid_limited==~inside), ...
    'SMC:Lesson13:Limits','范围、未限幅原值或限幅标记不符。');
assert(max(abs(grid_actual_rate_rad_s2(inside)-grid_desired_rate_rad_s2(inside)))<1e-12 && ...
    any(grid_limited & grid_v_rate_rad2_s3>0) && any(grid_limited & grid_v_rate_rad2_s3<0), ...
    'SMC:Lesson13:Direction','应同时存在受限后仍趋近和偏离的状态点。');
boundary_requests_a=[-.2,.2];
boundary_outputs_a=lesson_clip(boundary_requests_a,-.2,.2);
assert(isequal(boundary_requests_a,boundary_outputs_a) && ...
    ~any(boundary_requests_a~=boundary_outputs_a), ...
    'SMC:Lesson13:Boundary','恰好在边界的请求没有发生改变。');

%% 加入单独的额外扰动反例：B 场景，d=1.5<epsilon，但加上执行差额后仍偏离
extra_disturbance_rad_s2=1.5;
disturbed_actual_rate_rad_s2=cases(2,1)*case_output_a(2) ...
    +extra_disturbance_rad_s2-cases(2,4)+surface_gain_per_s*cases(2,3);
disturbed_rate_from_residual_rad_s2=case_desired_rate_rad_s2(2) ...
    +cases(2,1)*case_current_difference_a(2)+extra_disturbance_rad_s2;
assert(extra_disturbance_rad_s2<switching_gain_rad_s2 && ...
    abs(disturbed_actual_rate_rad_s2-.5)<1e-12 && ...
    abs(disturbed_actual_rate_rad_s2-disturbed_rate_from_residual_rad_s2)<1e-12 && ...
    abs(case_s_rad_s(2)*disturbed_actual_rate_rad_s2-.25)<1e-12, ...
    'SMC:Lesson13:Disturbance','有额外扰动时不能忽略限幅差额。');

%% 固定 E 的当前状态，只改变对称范围 L；横轴不是时间
sweep_limit_a=(0:.01:1.5)';
sweep_requested_a=case_requested_a(5)*ones(size(sweep_limit_a));
sweep_output_a=lesson_clip(sweep_requested_a,-sweep_limit_a,sweep_limit_a);
sweep_actual_rate_rad_s2=cases(5,1)*sweep_output_a-cases(5,4)+surface_gain_per_s*cases(5,3);
sweep_v_rate_rad2_s3=case_s_rad_s(5)*sweep_actual_rate_rad_s2;
sweep_reference_limits_a=[.2,.3,.4,1.4];
sweep_reference_rates_rad_s2=[.5,0,-.5,-5.5];
for reference_index=1:numel(sweep_reference_limits_a)
    point=find(abs(sweep_limit_a-sweep_reference_limits_a(reference_index))<1e-12,1);
    assert(~isempty(point) && abs(sweep_actual_rate_rad_s2(point) ...
        -sweep_reference_rates_rad_s2(reference_index))<1e-12, ...
        'SMC:Lesson13:SweepHand','改变限幅的手算点不符。');
end
assert(all(sweep_actual_rate_rad_s2(sweep_limit_a<.3-1e-12)>0) && ...
    all(sweep_actual_rate_rad_s2(sweep_limit_a>.3+1e-12)<0) && ...
    max(abs(sweep_actual_rate_rad_s2(sweep_limit_a>=1.4)-case_desired_rate_rad_s2(5)))<1e-12, ...
    'SMC:Lesson13:SweepDirection','趋近方向或完整实现请求的条件不符。');

%% 图像：限幅映射、当前状态点与固定状态的范围比较，全部不是运动轨迹
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[50,50,1400,930]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
mapping_request_a=linspace(-1.5,1.5,301)';
plot(mapping_request_a,mapping_request_a,'k--','LineWidth',1.2); hold on;
plot(mapping_request_a,lesson_clip(mapping_request_a,-.2,.2),'Color',[.1,.45,.8],'LineWidth',2);
yline(-.2,':','HandleVisibility','off'); yline(.2,':','HandleVisibility','off');
xlabel('公式请求电流 / A'); ylabel('限幅后执行电流 / A');
title('最终输出限幅：本图允许 -0.2～+0.2 A');
legend('不改变请求','限幅后','Location','northwest'); grid on;
nexttile;
bar([case_requested_a,case_output_a]);
xticks(1:7); xticklabels({'A','B','C','D','E','F','G'});
xlabel('手算场景（见讲义）'); ylabel('完整电流 / A');
title('分别记录完整请求与执行值');
legend('请求电流','执行电流','Location','southwest'); grid on;
nexttile;
bar([case_desired_rate_rad_s2,case_actual_rate_rad_s2]);
xticks(1:7); xticklabels({'A','B','C','D','E','F','G'});
xlabel('相同的七个当前状态'); ylabel('s 的变化率 / (rad/s²)');
title('实际变化率可能为零或改变方向');
legend('期望变化率','代回对象的实际变化率','Location','southwest');
yline(0,'k-','HandleVisibility','off'); grid on;
nexttile;
plot(sweep_limit_a,sweep_v_rate_rad2_s3,'Color',[.1,.45,.8],'LineWidth',2); hold on;
yline(0,'k-','HandleVisibility','off');
yline(case_s_rad_s(5)*case_desired_rate_rad_s2(5),'--','期望 V 变化率', ...
    'Color',[.85,.3,.1],'HandleVisibility','off','LabelHorizontalAlignment','left');
xline(.3,':','L=0.3：当前变化率为零','HandleVisibility','off','LabelVerticalAlignment','bottom');
xline(1.4,':','L=1.4：请求可完整执行','HandleVisibility','off','LabelVerticalAlignment','bottom');
plot(.2,case_v_rate_rad2_s3(5),'o','MarkerFaceColor',[.85,.3,.1], ...
    'Color',[.85,.3,.1],'HandleVisibility','off');
xlabel('对称允许范围的大小 L / A（不是时间）'); ylabel('实际 V 变化率 / (rad²/s³)');
title('固定 E 状态：V 增加、减小与完整实现请求');
xlim([0,1.5]); grid on;
sgtitle('第13讲：输出限幅怎样改变趋近关系（当前状态代回，教学假设）');
exportgraphics(lesson_figure,fullfile(lesson_out,'输出限幅怎样改变趋近关系.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'输出限幅怎样改变趋近关系.fig'));

case_table=array2table([cases,case_s_rad_s,case_requested_a,case_output_a,double(case_limited), ...
    case_desired_rate_rad_s2,case_actual_rate_rad_s2,case_current_difference_a, ...
    case_rate_from_residual_rad_s2,case_v_rate_rad2_s3], ...
    'VariableNames',{'input_gain_rad_s2_per_a','error_rad','error_rate_rad_s', ...
    'target_acceleration_rad_s2','output_min_a','output_max_a','s_rad_s', ...
    'requested_a','output_a','limited','desired_s_rate_rad_s2','actual_s_rate_rad_s2', ...
    'current_difference_a','s_rate_from_residual_rad_s2','v_rate_rad2_s3'});
writetable(case_table,fullfile(lesson_out,'七个手算场景.csv'));
grid_table=array2table([grid_gain,grid_error,grid_error_rate,grid_target_acc, ...
    grid_lower_a,grid_upper_a,grid_s_rad_s,grid_requested_a,grid_output_a,double(grid_limited), ...
    grid_desired_rate_rad_s2,grid_actual_rate_rad_s2,grid_residual_rate_rad_s2, ...
    grid_difference_rad_s2,grid_v_rate_rad2_s3], ...
    'VariableNames',{'input_gain_rad_s2_per_a','error_rad','error_rate_rad_s', ...
    'target_acceleration_rad_s2','output_min_a','output_max_a','s_rad_s', ...
    'requested_a','output_a','limited','desired_s_rate_rad_s2','actual_s_rate_rad_s2', ...
    's_rate_from_residual_rad_s2','difference_rad_s2','v_rate_rad2_s3'});
writetable(grid_table,fullfile(lesson_out,'1470组执行差额核对.csv'));
sweep_table=table(sweep_limit_a,sweep_requested_a,sweep_output_a,sweep_actual_rate_rad_s2, ...
    sweep_v_rate_rad2_s3,'VariableNames',{'symmetric_limit_a','requested_a','output_a', ...
    'actual_s_rate_rad_s2','v_rate_rad2_s3'});
writetable(sweep_table,fullfile(lesson_out,'固定E状态改变允许范围.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s','reaching_gain_per_s', ...
    'switching_gain_rad_s2','boundary_width_rad_s','gain_values_rad_s2_per_a', ...
    'error_values_rad','rate_values_rad_s','target_acceleration_values_rad_s2','output_ranges_a', ...
    'extra_disturbance_rad_s2','disturbed_actual_rate_rad_s2','case_table','grid_table','sweep_table');
lesson_report.surface_gain_per_s=surface_gain_per_s;
lesson_report.reaching_gain_per_s=reaching_gain_per_s;
lesson_report.switching_gain_rad_s2=switching_gain_rad_s2;
lesson_report.boundary_width_rad_s=boundary_width_rad_s;
lesson_report.hand_case_count=size(cases,1);
lesson_report.grid_point_count=numel(grid_gain);
lesson_report.output_ranges_a=output_ranges_a;
lesson_report.max_grid_s_rate_difference_rad_s2=max(abs(grid_difference_rad_s2));
lesson_report.max_grid_v_rate_difference_rad2_s3=max(abs(grid_v_rate_rad2_s3-grid_expanded_v_rate_rad2_s3));
lesson_report.case_requested_a=case_requested_a';
lesson_report.case_output_a=case_output_a';
lesson_report.case_desired_s_rate_rad_s2=case_desired_rate_rad_s2';
lesson_report.case_actual_s_rate_rad_s2=case_actual_rate_rad_s2';
lesson_report.case_v_rate_rad2_s3=case_v_rate_rad2_s3';
lesson_report.extra_disturbance_rad_s2=extra_disturbance_rad_s2;
lesson_report.disturbed_actual_s_rate_rad_s2=disturbed_actual_rate_rad_s2;
lesson_report.range_sweep_point_count=numel(sweep_limit_a);
lesson_report.sweep_zero_rate_limit_a=.3;
lesson_report.sweep_full_request_limit_a=1.4;
lesson_report.checks={'七个完整电流与变化率手算点','1470 组独立对象代回与差额恒等式', ...
    'V 变化率展开式','输出范围与未限幅原值','请求恰好在边界不改变', ...
    '两种输入增益方向','限幅后仍趋近和偏离的反例','加速目标匹配不能保持', ...
    '额外扰动不能覆盖执行差额','固定状态下 151 个输出范围点'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第13讲通过：七个手算场景、1470 组执行差额恒等式及 151 个范围点核对通过。\n');
fprintf('E 场景请求 -1.4 A、执行 -0.2 A，实际 s 变化率为 +0.5 rad/s²。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function output=lesson_clip(request,lower,upper)
    output=max(lower,min(upper,request));
end

function output=lesson_sat(normalized_input)
    output=max(-1,min(1,normalized_input));
end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson13:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
