%% 第 09 讲：从运动关系与趋近律推导控制输入
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=9。
% 仅依赖 MATLAB；只检查当前时刻的代数关系，不运行生产库或闭环对象。
% 教学假设：theta_ddot=b*u，无额外扰动，无输出限制，模型系数准确。
% 统一单位：角度 rad，时间 s，电流输入 A；所有参数为教学假设。
% 使用第 8 讲的理想 sign 形式，实际库的连续处理不在本轮运行。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第09讲_从运动关系推导控制输入');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',9,'matlab',version, ...
    'experiment','先计算控制输入，再经独立对象关系重建 s 变化率', ...
    'parameter_source','教学假设，非实测','learner_understanding_confirmed',false, ...
    'library_modified',false,'production_controller_executed',false, ...
    'closed_loop_simulated',false,'ideal_sign_rule',true,'disturbance_included',false, ...
    'output_clipping_included',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 固定教学参数；epsilon=2 rad/s² 是本讲新假设，不是第 8 讲 2°/s² 的单位转换
surface_gain_per_s=.5;       % c，1/s。
reaching_gain_per_s=1;       % K，1/s。
switching_gain_rad_s2=2;     % epsilon，rad/s²。

% A 静止位置偏差；B 同位置偏差但带负速度；C 匹配加速目标；
% D 与 A 相反的位置误差；E 与 A 相同运动坐标但反向输入增益。
input_gains_rad_s2_per_a=[5,5,5,5,-5];
measurement_rad=[1,1,2,-1,1];
measurement_rate_rad_s=[0,-1,.5,0,0];
target_rad=[0,0,2,0,0];
target_rate_rad_s=[0,0,.5,0,0];
target_acceleration_rad_s2=[0,0,1,0,0];
expected_command_a=[-.5,.6,.2,.5,.5];
expected_desired_s_rate_rad_s2=[-2.5,2.5,0,2.5,-2.5];

%% 由目标、测量与期望规则计算输入
error_rad=measurement_rad-target_rad;
error_rate_rad_s=measurement_rate_rad_s-target_rate_rad_s;
sliding_variable_rad_s=error_rate_rad_s+surface_gain_per_s*error_rad;
desired_s_rate_rad_s2=-reaching_gain_per_s*sliding_variable_rad_s ...
    -switching_gain_rad_s2*sign(sliding_variable_rad_s);
command_a=(target_acceleration_rad_s2-surface_gain_per_s*error_rate_rad_s ...
    +desired_s_rate_rad_s2)./input_gains_rad_s2_per_a;
assert(max(abs(command_a-expected_command_a))<1e-12, ...
    'SMC:Lesson09:HandInput','控制输入与手算不符。');
assert(max(abs(desired_s_rate_rad_s2-expected_desired_s_rate_rad_s2))<1e-12, ...
    'SMC:Lesson09:HandRate','期望 s 变化率与手算不符。');

%% 独立代回：先算对象产生的加速度，再算误差加速度，最后计算 s 的变化率
plant_acceleration_rad_s2=input_gains_rad_s2_per_a.*command_a;
error_acceleration_rad_s2=plant_acceleration_rad_s2-target_acceleration_rad_s2;
reconstructed_s_rate_rad_s2=error_acceleration_rad_s2+surface_gain_per_s*error_rate_rad_s;
substitution_difference_rad_s2=reconstructed_s_rate_rad_s2-desired_s_rate_rad_s2;
assert(max(abs(substitution_difference_rad_s2))<1e-12, ...
    'SMC:Lesson09:Substitution','代回模型后没有实现期望 s 变化率。');
assert(error_rad(3)==0 && error_rate_rad_s(3)==0 && abs(command_a(3)-.2)<1e-12, ...
    'SMC:Lesson09:MovingTarget','匹配加速目标时仍应产生相应输入。');
assert(abs(command_a(1)+command_a(5))<1e-12 && ...
    abs(plant_acceleration_rad_s2(1)-plant_acceleration_rad_s2(5))<1e-12, ...
    'SMC:Lesson09:Direction','反向增益应对应反向输入、相同的模型加速度。');

%% 两个已知缺项的检查：记录失败量，不把错误公式混进生产库
missing_division_command_a=target_acceleration_rad_s2(1) ...
    -surface_gain_per_s*error_rate_rad_s(1)+desired_s_rate_rad_s2(1);
missing_division_s_rate_rad_s2=input_gains_rad_s2_per_a(1)*missing_division_command_a ...
    -target_acceleration_rad_s2(1)+surface_gain_per_s*error_rate_rad_s(1);
missing_division_residual_rad_s2=missing_division_s_rate_rad_s2-desired_s_rate_rad_s2(1);
assert(abs(missing_division_residual_rad_s2+10)<1e-12, ...
    'SMC:Lesson09:MissingGain','漏除 b 的错误应被代回检查发现。');

missing_target_acc_command_a=(-surface_gain_per_s*error_rate_rad_s(3) ...
    +desired_s_rate_rad_s2(3))/input_gains_rad_s2_per_a(3);
missing_target_acc_s_rate_rad_s2=input_gains_rad_s2_per_a(3)*missing_target_acc_command_a ...
    -target_acceleration_rad_s2(3)+surface_gain_per_s*error_rate_rad_s(3);
missing_target_acc_residual_rad_s2=missing_target_acc_s_rate_rad_s2-desired_s_rate_rad_s2(3);
assert(abs(missing_target_acc_residual_rad_s2+1)<1e-12, ...
    'SMC:Lesson09:MissingTargetAcc','漏掉目标加速度的错误应在加速目标点被发现。');

%% 60 组代回核对，覆盖两种增益方向、正负误差和目标加速度
grid_rows=[];
for gain=[-5,5]
    for point_error=[-2,-1,0,1,2]
        for point_error_rate=[-1,0,1]
            for target_acc=[0,1]
                point_s=point_error_rate+surface_gain_per_s*point_error;
                point_desired=-reaching_gain_per_s*point_s-switching_gain_rad_s2*sign(point_s);
                point_u=(target_acc-surface_gain_per_s*point_error_rate+point_desired)/gain;
                point_plant_acc=gain*point_u;
                point_error_acc=point_plant_acc-target_acc;
                point_actual_s_rate=point_error_acc+surface_gain_per_s*point_error_rate;
                grid_rows(end+1,:)=[gain,point_error,point_error_rate,target_acc,point_s, ...
                    point_u,point_desired,point_actual_s_rate,point_actual_s_rate-point_desired]; %#ok<SAGROW>
            end
        end
    end
end
assert(size(grid_rows,1)==60 && max(abs(grid_rows(:,9)))<1e-12, ...
    'SMC:Lesson09:Grid','60 组代回结果不符。');

%% 图像：输入与 s 变化率分开画，不能当成同一物理量
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1200,650]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
bar(command_a,'FaceColor',[.1,.45,.8]);
xticks(1:5); xticklabels({'A','B','C','D','E'});
xlabel('手算场景（说明见讲义）'); ylabel('算出的电流输入 u / A');
title('从运动关系和期望规则计算输入'); ylim([-.8,.9]); yline(0,'k-','HandleVisibility','off'); grid on;
for point=1:5
    offset=.07;
    if command_a(point)<0, offset=-.09; end
    text(point,command_a(point)+offset,sprintf('%+.1f',command_a(point)), ...
        'HorizontalAlignment','center','FontSize',11);
end
nexttile;
bar([desired_s_rate_rad_s2',reconstructed_s_rate_rad_s2']);
xticks(1:5); xticklabels({'A','B','C','D','E'});
xlabel('相同的五个手算场景'); ylabel('s 的变化率 / (rad/s²)');
title('把输入代回对象：结果与期望一致');
legend('期望变化率','代回模型的变化率','Location','northwest');
ylim([-4,4]); yline(0,'k-','HandleVisibility','off'); grid on;
sgtitle('第09讲：从运动关系推导控制输入（教学假设，逐点代回，非闭环仿真）');
exportgraphics(lesson_figure,fullfile(lesson_out,'从运动关系推导控制输入.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'从运动关系推导控制输入.fig'));

case_table=table(input_gains_rad_s2_per_a',measurement_rad',measurement_rate_rad_s', ...
    target_rad',target_rate_rad_s',target_acceleration_rad_s2',error_rad',error_rate_rad_s', ...
    sliding_variable_rad_s',command_a',plant_acceleration_rad_s2',error_acceleration_rad_s2', ...
    desired_s_rate_rad_s2',reconstructed_s_rate_rad_s2',substitution_difference_rad_s2', ...
    'VariableNames',{'input_gain_rad_s2_per_a','measurement_rad','measurement_rate_rad_s', ...
    'target_rad','target_rate_rad_s','target_acceleration_rad_s2','error_rad','error_rate_rad_s', ...
    's_rad_s','command_a','plant_acceleration_rad_s2','error_acceleration_rad_s2', ...
    'desired_s_rate_rad_s2','reconstructed_s_rate_rad_s2','difference_rad_s2'});
writetable(case_table,fullfile(lesson_out,'五个手算场景.csv'));
grid_table=array2table(grid_rows,'VariableNames',{'input_gain_rad_s2_per_a','error_rad', ...
    'error_rate_rad_s','target_acceleration_rad_s2','s_rad_s','command_a', ...
    'desired_s_rate_rad_s2','reconstructed_s_rate_rad_s2','difference_rad_s2'});
writetable(grid_table,fullfile(lesson_out,'60组代回核对.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'surface_gain_per_s','reaching_gain_per_s', ...
    'switching_gain_rad_s2','case_table','grid_table','missing_division_residual_rad_s2', ...
    'missing_target_acc_residual_rad_s2');
lesson_report.surface_gain_per_s=surface_gain_per_s;
lesson_report.reaching_gain_per_s=reaching_gain_per_s;
lesson_report.switching_gain_rad_s2=switching_gain_rad_s2;
lesson_report.input_gains_rad_s2_per_a=input_gains_rad_s2_per_a;
lesson_report.expected_commands_a=expected_command_a;
lesson_report.actual_commands_a=command_a;
lesson_report.desired_s_rates_rad_s2=desired_s_rate_rad_s2;
lesson_report.reconstructed_s_rates_rad_s2=reconstructed_s_rate_rad_s2;
lesson_report.max_hand_substitution_difference_rad_s2=max(abs(substitution_difference_rad_s2));
lesson_report.grid_point_count=size(grid_rows,1);
lesson_report.max_grid_substitution_difference_rad_s2=max(abs(grid_rows(:,9)));
lesson_report.missing_division_residual_rad_s2=missing_division_residual_rad_s2;
lesson_report.missing_target_acc_residual_rad_s2=missing_target_acc_residual_rad_s2;
lesson_report.checks={'五个输入手算点','期望变化率手算','输入经对象模型代回', ...
    '匹配加速目标所需输入','反向模型增益','漏除输入增益的错误检查', ...
    '漏掉目标加速度的错误检查','60 组代回核对'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第09讲通过：A/B/C/D/E 电流输入为 -0.5/0.6/0.2/0.5/0.5 A。\n');
fprintf('五个手算点和 60 组代回核对通过；未模拟闭环或运行生产库。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson09:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
