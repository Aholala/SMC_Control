%% 第 11 讲：外力与参数误差下的首次趋近条件
% 入口：直接运行，或根目录 start.m 设置 mode='教学'、number=11。
% MATLAB 基础功能，无工具箱。所有参数为教学假设，角度 rad、时间 s、输入 A。
% 理想 sign 控制，不模拟生产库或完整位置对象，不包含输出限制、测量误差或延迟。
% 有扰动时不采用“到零后保持零”的约定：首次到零的曲线在零点终止。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第11讲_外力与参数误差下的趋近条件');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',11,'matlab',version, ...
    'experiment','有界扰动下的 V 变化率和非零分支首次趋近', ...
    'parameter_source','教学假设，非实测','learner_understanding_confirmed',false, ...
    'library_modified',false,'production_controller_executed',false, ...
    'closed_loop_position_simulated',false,'ideal_sign_rule',true, ...
    'zero_holding_assumed',false,'post_arrival_motion_simulated',false, ...
    'output_clipping_included',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 八个手算点：d 是额外角加速度，不能直接填入力矩
reaching_gain_per_s=1;
switching_gain_rad_s2=2;
probe_s_rad_s=[2,-2,.5,-.5,2,-2,1,-1];
probe_d_rad_s2=[1,-1,3,-3,3,-3,3,-3];
probe_s_rate_rad_s2=-reaching_gain_per_s*probe_s_rad_s ...
    -switching_gain_rad_s2*sign(probe_s_rad_s)+probe_d_rad_s2;
probe_v_rate_rad2_s3=probe_s_rad_s.*probe_s_rate_rad_s2;
assert(isequal(probe_s_rate_rad_s2,[-3,3,.5,-.5,-1,1,0,0]), ...
    'SMC:Lesson11:HandSRate','八个手算点的 s 变化率不符。');
assert(isequal(probe_v_rate_rad2_s3,[-6,-6,.25,.25,-2,-2,0,0]), ...
    'SMC:Lesson11:HandVRate','八个手算点的 V 变化率不符。');

%% 3615 个组合核对：241 个 s × 3 种上界 × 5 种扰动方向和比例
grid_s_values_rad_s=(-120:120)/20;
disturbance_bounds_rad_s2=[1,2,3];
disturbance_fractions=[-1,-.5,0,.5,1];
grid_rows=zeros(numel(grid_s_values_rad_s)*numel(disturbance_bounds_rad_s2) ...
    *numel(disturbance_fractions),8);
row=0;
for bound=disturbance_bounds_rad_s2
    for fraction=disturbance_fractions
        disturbance=bound*fraction;
        for point_s=grid_s_values_rad_s
            point_rate=-reaching_gain_per_s*point_s ...
                -switching_gain_rad_s2*sign(point_s)+disturbance;
            product=point_s*point_rate;
            expanded=-reaching_gain_per_s*point_s^2 ...
                -switching_gain_rad_s2*abs(point_s)+point_s*disturbance;
            upper=-reaching_gain_per_s*point_s^2 ...
                -(switching_gain_rad_s2-bound)*abs(point_s);
            row=row+1;
            grid_rows(row,:)=[point_s,bound,disturbance,point_rate,product,expanded,upper,product-expanded];
        end
    end
end
assert(row==3615 && max(abs(grid_rows(:,8)))<1e-12, ...
    'SMC:Lesson11:Identity','变化率展开式与乘积式不符。');
assert(all(grid_rows(:,5)<=grid_rows(:,7)+1e-12), ...
    'SMC:Lesson11:UpperBound','具体变化率超过理论上界。');
strict_or_equal=grid_rows(:,2)<=switching_gain_rad_s2 & grid_rows(:,1)~=0;
assert(all(grid_rows(strict_or_equal,5)<0), ...
    'SMC:Lesson11:Negative','D<=epsilon 且 s 非零时应严格为负。');
outside=abs(grid_rows(:,1))>max(0,(grid_rows(:,2)-switching_gain_rad_s2)/reaching_gain_per_s);
assert(all(grid_rows(outside,5)<0), ...
    'SMC:Lesson11:Outside','超过指定范围的非零 s 应向零运动。');
assert(any(grid_rows(:,2)==3 & grid_rows(:,5)>0), ...
    'SMC:Lesson11:Insufficient','应发现 D>epsilon 时 V 增大的反例。');
worst_direction=grid_rows(:,3)==grid_rows(:,2).*sign(grid_rows(:,1)) & grid_rows(:,1)~=0;
assert(max(abs(grid_rows(worst_direction,5)-grid_rows(worst_direction,7)))<1e-12, ...
    'SMC:Lesson11:WorstDirection','最不利方向应达到所推上界。');

%% 参数误差代回：控制器使用 b0，真实对象使用 b_actual；只检查当前时刻
surface_gain_per_s=.5;
nominal_input_gain_rad_s2_per_a=5;
actual_input_gain_rad_s2_per_a=4;
external_disturbance_rad_s2=1;
point_error_rad=1;
point_error_rate_rad_s=0;
point_target_acceleration_rad_s2=0;
point_sliding_variable_rad_s=point_error_rate_rad_s+surface_gain_per_s*point_error_rad;
point_nominal_rate_rad_s2=-reaching_gain_per_s*point_sliding_variable_rad_s ...
    -switching_gain_rad_s2*sign(point_sliding_variable_rad_s);
point_command_a=(point_target_acceleration_rad_s2 ...
    -surface_gain_per_s*point_error_rate_rad_s+point_nominal_rate_rad_s2) ...
    /nominal_input_gain_rad_s2_per_a;
point_actual_rate_rad_s2=actual_input_gain_rad_s2_per_a*point_command_a ...
    +external_disturbance_rad_s2-point_target_acceleration_rad_s2 ...
    +surface_gain_per_s*point_error_rate_rad_s;
point_residual_rad_s2=(actual_input_gain_rad_s2_per_a-nominal_input_gain_rad_s2_per_a) ...
    *point_command_a+external_disturbance_rad_s2;
assert(abs(point_command_a+.5)<1e-12 && abs(point_residual_rad_s2-1.5)<1e-12 && ...
    abs(point_actual_rate_rad_s2+1)<1e-12 && ...
    abs(point_actual_rate_rad_s2-point_nominal_rate_rad_s2-point_residual_rad_s2)<1e-12, ...
    'SMC:Lesson11:GainError','输入增益偏差的独立代回不符。');
% 反向实际增益、无外力：同一输入反而使 V 增加，不能保证任意参数偏差都可抵消。
reversed_actual_rate_rad_s2=-5*point_command_a;
assert(abs(reversed_actual_rate_rad_s2-2.5)<1e-12 && ...
    point_sliding_variable_rad_s*reversed_actual_rate_rad_s2>0, ...
    'SMC:Lesson11:Reverse','反向输入增益应提供不满足趋近的反例。');
zero_s_rad_s=0;
zero_disturbance_rad_s2=1;
zero_s_rate_rad_s2=-reaching_gain_per_s*zero_s_rad_s ...
    -switching_gain_rad_s2*sign(zero_s_rad_s)+zero_disturbance_rad_s2;
assert(zero_s_rate_rad_s2==1 && zero_s_rad_s*zero_s_rate_rad_s2==0, ...
    'SMC:Lesson11:Zero','零点 V_rate 为零不等于能保持 s=0。');

%% 四条正侧准确曲线：仅研究 s>0 分支；第一条到零即停止
duration_s=5;
plot_step_s=.01; % 准确曲线的取点间隔，不是控制器周期。
time_s=(0:plot_step_s:duration_s)';
case_initial_s_rad_s=[6,6,6,.5];
case_disturbance_rad_s2=[1,2,3,3];
case_names={'d=1，初始 s=6（首次到零即停止）', ...
    'd=2，初始 s=6（逐渐趋零）','d=3，初始 s=6（向 1 减小）', ...
    'd=3，初始 s=0.5（向 1 增大）'};
% log 是 exp 的反函数，解 7*exp(-K*t)-1=0；不是按仿真采样夹零。
first_arrival_s=log(1+reaching_gain_per_s*case_initial_s_rad_s(1) ...
    /(switching_gain_rad_s2-case_disturbance_rad_s2(1)))/reaching_gain_per_s;
arrival_upper_bound_s=case_initial_s_rad_s(1) ...
    /(switching_gain_rad_s2-case_disturbance_rad_s2(1));
curves=cell(1,4);
curve_rows=[];
max_curve_rate_difference_rad_s2=0;
for case_index=1:4
    curve_time=time_s;
    if case_index==1
        curve_time=[time_s(time_s<first_arrival_s);first_arrival_s];
    end
    offset=(case_disturbance_rad_s2(case_index)-switching_gain_rad_s2)/reaching_gain_per_s;
    curve_s=offset+(case_initial_s_rad_s(case_index)-offset)*exp(-reaching_gain_per_s*curve_time);
    curve_rate=-reaching_gain_per_s*(case_initial_s_rad_s(case_index)-offset) ...
        *exp(-reaching_gain_per_s*curve_time);
    arrival_endpoint=false(size(curve_time));
    if case_index==1
        assert(abs(curve_s(end))<1e-12 && all(curve_s(1:end-1)>0), ...
            'SMC:Lesson11:Arrival','到达端点必须来自正侧准确曲线的零点。');
        curve_s(end)=0; % 仅消除解析零点的舍入误差；不生成到达后的数据。
        arrival_endpoint(end)=true;
    end
    nonzero=~arrival_endpoint;
    actual_rate=-reaching_gain_per_s*curve_s(nonzero) ...
        -switching_gain_rad_s2*sign(curve_s(nonzero))+case_disturbance_rad_s2(case_index);
    difference=max(abs(curve_rate(nonzero)-actual_rate));
    max_curve_rate_difference_rad_s2=max(max_curve_rate_difference_rad_s2,difference);
    assert(difference<1e-12,'SMC:Lesson11:CurveRate','正侧准确曲线变化率不符。');
    mirrored_s=-curve_s(nonzero);
    mirrored_rate=-reaching_gain_per_s*mirrored_s ...
        -switching_gain_rad_s2*sign(mirrored_s)-case_disturbance_rad_s2(case_index);
    assert(max(abs(mirrored_rate+actual_rate))<1e-12, ...
        'SMC:Lesson11:Mirror','负初值配负扰动应得到镜像运动。');
    curve_rate(arrival_endpoint)=NaN; % 此处不提供通常意义的变化率。
    curves{case_index}=struct('time_s',curve_time,'s_rad_s',curve_s);
    curve_rows=[curve_rows;case_index*ones(size(curve_time)),curve_time, ...
        case_disturbance_rad_s2(case_index)*ones(size(curve_time)),curve_s, ...
        .5*curve_s.^2,curve_rate,double(arrival_endpoint)]; %#ok<AGROW>
end
assert(abs(first_arrival_s-1.945910149055313)<1e-12 && first_arrival_s<arrival_upper_bound_s, ...
    'SMC:Lesson11:ArrivalBound','首次到达时刻或理论上界不符。');
assert(all(curves{2}.s_rad_s>0) && all(diff(curves{2}.s_rad_s)<0), ...
    'SMC:Lesson11:Equal','D=epsilon 的最不利恒定例子应逐渐趋零。');
assert(all(curves{3}.s_rad_s>1) && all(diff(curves{3}.s_rad_s)<0) && ...
    all(curves{4}.s_rad_s<1) && all(diff(curves{4}.s_rad_s)>0), ...
    'SMC:Lesson11:Equilibrium','D>epsilon 的两条曲线应从两侧接近非零平衡值。');

%% 图像：左图固定扰动的准确曲线，右图不同 D 的最不利 V_rate 上界
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1350,680]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
hold on;
case_colors=[.1,.45,.8;.25,.6,.3;.85,.3,.1;.55,.25,.7];
for case_index=1:4
    plot(curves{case_index}.time_s,curves{case_index}.s_rad_s, ...
        'Color',case_colors(case_index,:),'LineWidth',2);
end
yline(1,'k:','非零平衡值 1','HandleVisibility','off','LabelHorizontalAlignment','left');
plot(first_arrival_s,0,'o','Color',case_colors(1,:),'MarkerFaceColor',case_colors(1,:), ...
    'MarkerSize',7,'HandleVisibility','off');
xlabel('时间 / s'); ylabel('滑模变量 s / (rad/s)');
title('恒定扰动：到零、逐渐趋零或接近非零值');
legend(case_names,'Location','northeast','FontSize',9);
xlim([0,duration_s]); ylim([-.2,6.5]); grid on;
nexttile;
magnitude_rad_s=(0:.01:3)';
upper_curves=-reaching_gain_per_s*magnitude_rad_s.^2 ...
    -magnitude_rad_s*(switching_gain_rad_s2-disturbance_bounds_rad_s2);
colororder(case_colors(1:3,:));
plot(magnitude_rad_s,upper_curves,'LineWidth',2);
yline(0,'k-','HandleVisibility','off');
xline(1,'k:','D=3 时的分界','HandleVisibility','off','LabelVerticalAlignment','bottom');
xlabel('滑模变量的大小 |s| / (rad/s)'); ylabel('V 变化率的上界 / (rad²/s³)');
title('上界由负变正的区域不再保证趋近');
legend('D=1 < ε','D=2 = ε','D=3 > ε','Location','southwest');
xlim([0,3]); grid on;
sgtitle('第11讲：外力与参数误差下的趋近条件（理想 sign，教学假设）');
exportgraphics(lesson_figure,fullfile(lesson_out,'外力与参数误差下的趋近条件.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'外力与参数误差下的趋近条件.fig'));

probe_table=table(probe_s_rad_s',probe_d_rad_s2',probe_s_rate_rad_s2',probe_v_rate_rad2_s3', ...
    'VariableNames',{'s_rad_s','disturbance_rad_s2','s_rate_rad_s2','v_rate_rad2_s3'});
writetable(probe_table,fullfile(lesson_out,'八个手算点.csv'));
grid_table=array2table(grid_rows,'VariableNames',{'s_rad_s','disturbance_bound_rad_s2', ...
    'disturbance_rad_s2','s_rate_rad_s2','v_rate_rad2_s3','expanded_v_rate_rad2_s3', ...
    'upper_bound_v_rate_rad2_s3','difference_rad2_s3'});
writetable(grid_table,fullfile(lesson_out,'3615组扰动上界核对.csv'));
curve_table=array2table(curve_rows,'VariableNames',{'case_number','time_s','disturbance_rad_s2', ...
    's_rad_s','v_rad2_s2','s_rate_rad_s2','arrival_endpoint'});
writetable(curve_table,fullfile(lesson_out,'非零分支准确曲线.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'reaching_gain_per_s','switching_gain_rad_s2', ...
    'disturbance_bounds_rad_s2','case_initial_s_rad_s','case_disturbance_rad_s2', ...
    'duration_s','plot_step_s','first_arrival_s','arrival_upper_bound_s', ...
    'surface_gain_per_s','nominal_input_gain_rad_s2_per_a','actual_input_gain_rad_s2_per_a', ...
    'external_disturbance_rad_s2','point_command_a','point_residual_rad_s2', ...
    'point_actual_rate_rad_s2','probe_table','grid_table','curve_table');
lesson_report.reaching_gain_per_s=reaching_gain_per_s;
lesson_report.switching_gain_rad_s2=switching_gain_rad_s2;
lesson_report.disturbance_bounds_rad_s2=disturbance_bounds_rad_s2;
lesson_report.grid_point_count=row;
lesson_report.max_grid_identity_difference_rad2_s3=max(abs(grid_rows(:,8)));
lesson_report.max_upper_bound_violation_rad2_s3=max([0;grid_rows(:,5)-grid_rows(:,7)]);
lesson_report.max_curve_rate_difference_rad_s2=max_curve_rate_difference_rad_s2;
lesson_report.first_arrival_s=first_arrival_s;
lesson_report.arrival_upper_bound_s=arrival_upper_bound_s;
lesson_report.duration_s=duration_s;
lesson_report.plot_step_s=plot_step_s;
lesson_report.curve_final_s_rad_s=cellfun(@(curve)curve.s_rad_s(end),curves);
lesson_report.nominal_input_gain_rad_s2_per_a=nominal_input_gain_rad_s2_per_a;
lesson_report.actual_input_gain_rad_s2_per_a=actual_input_gain_rad_s2_per_a;
lesson_report.gain_error_point_residual_rad_s2=point_residual_rad_s2;
lesson_report.gain_error_point_actual_rate_rad_s2=point_actual_rate_rad_s2;
lesson_report.gain_error_point_is_not_global_bound=true;
lesson_report.checks={'八个手算点','3615 组恒等式与扰动上界','最不利扰动达到上界', ...
    '小于、等于、大于 epsilon 的符号条件','输入增益误差独立代回','方向反例', ...
    '零点不能直接保持','准确曲线变化率与镜像','首次到达及上界','非零平衡值两侧运动'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第11讲通过：八个手算点、3615 组扰动上界与参数误差代回核对通过。\n');
fprintf('d=1 的首次到零时刻 %.9f s，曲线在此终止；未模拟到达后的运动。\n',first_arrival_s);
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson11:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
