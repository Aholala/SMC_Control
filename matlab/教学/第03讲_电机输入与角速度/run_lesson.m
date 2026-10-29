%% 第 03 讲：电机输入怎样改变角速度
% 入口：直接运行整个文件，或根目录 start.m 设置 mode='教学'、number=3。
% 依赖：仅 MATLAB；不调用控制器，不需要 C++、Simulink 或其他工具箱。
% 全部参数为教学假设，非真实电机参数。
% 假设：固定转轴、恒定惯量、实际电流立即生效，力矩与电流成正比，
% 忽略摩擦、重力等额外力矩；Kt 和 J 均对应同一转轴。

lesson_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out = fullfile(lesson_root,'build','教学','第03讲_电机输入与角速度');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report = struct('passed',false,'lesson',3,'matlab',version, ...
    'experiment','电流、力矩、惯量和角加速度的关系','parameter_source','教学假设，非实测', ...
    'learner_understanding_confirmed',false,'library_modified',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 每列为一个场景：基准、电流加倍、惯量加倍、反向电流
current_a = [.2,.4,.2,-.2];                 % 恒定实际电流，A。
torque_constants_nm_per_a = [.1,.1,.1,.1]; % 同一轴上的转矩常数，N*m/A。
inertias_kg_m2 = [.02,.02,.04,.02];        % 同一轴上的物理转动惯量，kg*m^2。
initial_rate_rad_s = 0;                    % 初始角速度，rad/s。
initial_angle_rad = 0;                     % 初始角度，rad。
duration_s = 1;                           % 观察时长，s。
plot_step_s = .01;                        % 绘图取点间隔，不是控制器周期。
time_s = (0:plot_step_s:duration_s)';

%% 力矩 T=Kt*I；角加速度 alpha=T/J；输入增益 b=Kt/J
torque_nm = torque_constants_nm_per_a.*current_a;
acceleration_rad_s2 = torque_nm./inertias_kg_m2;
input_gains_rad_s2_per_a = torque_constants_nm_per_a./inertias_kg_m2;
inverse_input_gains_a_s2_per_rad = 1./input_gains_rad_s2_per_a;

%% 角加速度恒定时的准确关系，不做逐次近似更新
rate_rad_s = initial_rate_rad_s + time_s*acceleration_rad_s2;
angle_rad = initial_angle_rad + initial_rate_rad_s*time_s + .5*(time_s.^2)*acceleration_rad_s2;
acceleration_plot = repmat(acceleration_rad_s2,numel(time_s),1);

%% 独立手算点与基本比例关系
% 基准：.1 N*m/A *.2 A=.02 N*m；.02/.02=1 rad/s^2。
% 从静止开始持续 1 s：末速度 1 rad/s；平均速度 .5 rad/s，转角 .5 rad。
expected_torque_nm = [.02,.04,.02,-.02];
expected_acceleration_rad_s2 = [1,2,.5,-1];
expected_final_rate_rad_s = [1,2,.5,-1];
expected_final_angle_rad = [.5,1,.25,-.5];
assert(max(abs(torque_nm-expected_torque_nm))<1e-12,'SMC:Lesson03:Torque','力矩手算不一致。');
assert(max(abs(acceleration_rad_s2-expected_acceleration_rad_s2))<1e-12, ...
    'SMC:Lesson03:Acceleration','角加速度手算不一致。');
assert(max(abs(rate_rad_s(end,:)-expected_final_rate_rad_s))<1e-12, ...
    'SMC:Lesson03:Rate','末速度手算不一致。');
assert(max(abs(angle_rad(end,:)-expected_final_angle_rad))<1e-12, ...
    'SMC:Lesson03:Angle','末角度手算不一致。');
assert(abs(acceleration_rad_s2(2)-2*acceleration_rad_s2(1))<1e-12 && ...
    abs(acceleration_rad_s2(3)-.5*acceleration_rad_s2(1))<1e-12, ...
    'SMC:Lesson03:Scaling','电流和惯量的比例关系不符。');
assert(max(abs(acceleration_rad_s2-input_gains_rad_s2_per_a.*current_a))<1e-12, ...
    'SMC:Lesson03:InputGain','输入增益与物理模型不一致。');
% 物理惯量 .02 kg*m^2 与逆输入增益 .2 A*s^2/rad 不同。
assert(abs(inverse_input_gains_a_s2_per_rad(1)-.2)<1e-12, ...
    'SMC:Lesson03:InverseGain','逆输入增益换算不正确。');

%% 同一理想模型的零电流检查：零加速度不意味着零角速度
coast_initial_rate_rad_s = 2;
coast_initial_angle_rad = .1;
coast_current_a = 0;
coast_acceleration_rad_s2 = input_gains_rad_s2_per_a(1)*coast_current_a;
coast_rate_rad_s = coast_initial_rate_rad_s + time_s*coast_acceleration_rad_s2;
coast_angle_rad = coast_initial_angle_rad + coast_initial_rate_rad_s*time_s ...
    + .5*coast_acceleration_rad_s2*time_s.^2;
assert(all(coast_rate_rad_s==2) && abs(coast_angle_rad(end)-2.1)<1e-12, ...
    'SMC:Lesson03:ZeroCurrent','无额外力矩的理想模型中，零电流应保持原速度。');

%% 图像：恒定角加速度，变化的角速度与角度
lesson_show_figure = usejava('desktop');
lesson_visibility = 'off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure = figure('Visible',lesson_visibility,'Color','w','Position',[80,60,1050,870]);
if ~lesson_show_figure, lesson_cleanup = onCleanup(@()close(lesson_figure)); end
lesson_labels = {'基准：I=0.2 A，J=0.02','电流加倍：I=0.4 A，J=0.02', ...
    '惯量加倍：I=0.2 A，J=0.04','反向：I=-0.2 A，J=0.02'};
tiledlayout(3,1);
nexttile; plot(time_s,acceleration_plot,'LineWidth',1.7);
xlabel('时间 / s'); ylabel('角加速度 / (rad/s²)');
title('先由电流产生力矩，再由力矩和惯量决定角加速度');
ylim([-1.5,2.5]); legend(lesson_labels,'Location','eastoutside'); grid on;
nexttile; plot(time_s,rate_rad_s,'LineWidth',1.7);
xlabel('时间 / s'); ylabel('角速度 / (rad/s)');
title('从静止开始：角速度按恒定变化率改变'); grid on;
nexttile; plot(time_s,angle_rad,'LineWidth',1.7);
xlabel('时间 / s'); ylabel('角度 / rad');
title('角速度不断变化，角度也随之改变'); grid on;
sgtitle('第03讲：电机输入与角速度（教学假设，无控制器）');
exportgraphics(lesson_figure,fullfile(lesson_out,'电机输入与角速度.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'电机输入与角速度.fig'));

lesson_parameters = table(current_a',torque_constants_nm_per_a',inertias_kg_m2', ...
    torque_nm',acceleration_rad_s2',input_gains_rad_s2_per_a',inverse_input_gains_a_s2_per_rad', ...
    'VariableNames',{'current_a','torque_constant_nm_per_a','inertia_kg_m2','torque_nm', ...
    'acceleration_rad_s2','input_gain_rad_s2_per_a','inverse_input_gain_a_s2_per_rad'});
writetable(lesson_parameters,fullfile(lesson_out,'场景参数.csv'));
lesson_data = array2table([time_s,rate_rad_s,angle_rad], ...
    'VariableNames',{'time_s','base_rate_rad_s','double_current_rate_rad_s', ...
    'double_inertia_rate_rad_s','reverse_rate_rad_s','base_angle_rad', ...
    'double_current_angle_rad','double_inertia_angle_rad','reverse_angle_rad'});
writetable(lesson_data,fullfile(lesson_out,'角速度与角度数据.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'lesson_parameters','time_s','rate_rad_s', ...
    'angle_rad','initial_rate_rad_s','initial_angle_rad','duration_s','plot_step_s', ...
    'coast_rate_rad_s','coast_angle_rad');
lesson_report.current_a = current_a;
lesson_report.torque_constants_nm_per_a = torque_constants_nm_per_a;
lesson_report.inertias_kg_m2 = inertias_kg_m2;
lesson_report.acceleration_rad_s2 = acceleration_rad_s2;
lesson_report.input_gains_rad_s2_per_a = input_gains_rad_s2_per_a;
lesson_report.inverse_input_gains_a_s2_per_rad = inverse_input_gains_a_s2_per_rad;
lesson_report.actual_final_rate_rad_s = rate_rad_s(end,:);
lesson_report.actual_final_angle_rad = angle_rad(end,:);
lesson_report.expected_final_rate_rad_s = expected_final_rate_rad_s;
lesson_report.expected_final_angle_rad = expected_final_angle_rad;
lesson_report.zero_current_rate_rad_s = coast_rate_rad_s(end);
lesson_report.zero_current_angle_rad = coast_angle_rad(end);
lesson_report.duration_s = duration_s;
lesson_report.sample_count = numel(time_s);
lesson_report.checks = {'力矩手算','角加速度手算','末速度','末角度','电流和惯量比例', ...
    '输入增益','物理惯量与逆输入增益','零电流不等于零速度'};
lesson_report.passed = true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第03讲实验通过：基准角加速度 1 rad/s²，1 s 后角速度 1 rad/s，角度 0.5 rad。\n');
fprintf('基准物理惯量 0.02 kg*m²；输入增益 5 rad/(s²*A)；逆输入增益 0.2 A*s²/rad。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson03:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
