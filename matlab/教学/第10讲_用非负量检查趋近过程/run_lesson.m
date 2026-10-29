%% 第 10 讲：用 V=s²/2 检查理想趋近过程
% 入口：运行整个文件，或根目录 start.m 设置 mode='教学'、number=10。
% 仅依赖 MATLAB。教学假设：理想 sign 趋近律准确实现，到零后保持零。
% 单位 rad、s；参数沿用第 9 讲，不是第 8 讲度单位参数的换算。
% 不调用生产库，不模拟完整位置对象、电流、扰动或输出限制。

lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
lesson_out=fullfile(lesson_root,'build','教学','第10讲_用非负量检查趋近过程');
if ~isfolder(lesson_out), mkdir(lesson_out); end
lesson_report=struct('passed',false,'lesson',10,'matlab',version, ...
    'experiment','V=s²/2 的手算、变化率及理想分段曲线核对', ...
    'parameter_source','教学假设，非实测','learner_understanding_confirmed',false, ...
    'library_modified',false,'production_controller_executed',false, ...
    'closed_loop_simulated',false,'ideal_sign_rule',true,'zero_holding_assumed',true, ...
    'error_e_trajectory_simulated',false,'disturbance_included',false, ...
    'output_clipping_included',false);
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);

%% 五个手算点：V 单位 rad²/s²，V_rate 单位 rad²/s³
reaching_gain_per_s=1;           % K，1/s。
switching_gain_rad_s2=2;         % epsilon，rad/s²。
probe_s_rad_s=[-6,-2,0,2,6];
probe_s_rate_rad_s2=-reaching_gain_per_s*probe_s_rad_s ...
    -switching_gain_rad_s2*sign(probe_s_rad_s);
probe_v_rad2_s2=.5*probe_s_rad_s.^2;
probe_v_rate_rad2_s3=probe_s_rad_s.*probe_s_rate_rad_s2;
assert(isequal(probe_s_rate_rad_s2,[8,4,0,-4,-8]), ...
    'SMC:Lesson10:HandSRate','手算 s 变化率不符。');
assert(isequal(probe_v_rad2_s2,[18,2,0,2,18]), ...
    'SMC:Lesson10:HandV','V 手算不符。');
assert(isequal(probe_v_rate_rad2_s3,[-48,-8,0,-8,-48]), ...
    'SMC:Lesson10:HandVRate','V 变化率手算不符。');

%% 1201 个点核对展开式与非零处严格负号；不能用有限网格代替数学证明
grid_s_rad_s=(-600:600)'/100;
grid_s_rate_rad_s2=-reaching_gain_per_s*grid_s_rad_s ...
    -switching_gain_rad_s2*sign(grid_s_rad_s);
grid_product_rad2_s3=grid_s_rad_s.*grid_s_rate_rad_s2;
grid_expanded_rad2_s3=-reaching_gain_per_s*grid_s_rad_s.^2 ...
    -switching_gain_rad_s2*abs(grid_s_rad_s);
grid_difference_rad2_s3=grid_product_rad2_s3-grid_expanded_rad2_s3;
assert(max(abs(grid_difference_rad2_s3))<1e-12, ...
    'SMC:Lesson10:Identity','V_rate 的乘积式与展开式不一致。');
assert(all(grid_product_rad2_s3(grid_s_rad_s~=0)<0) && ...
    grid_product_rad2_s3(grid_s_rad_s==0)==0, ...
    'SMC:Lesson10:Sign','非零 s 处 V_rate 应严格为负，零点为零。');

%% 第 8 讲的理想分段准确曲线；这里改变了单位，独立声明教学参数
initial_s_rad_s=[6,-6,0];
duration_s=4;
plot_step_s=.01; % 只用于曲线取点，不是控制器周期。
time_s=(0:plot_step_s:duration_s)';
decay=exp(-reaching_gain_per_s*time_s);
unclipped_magnitude_rad_s=decay*(abs(initial_s_rad_s)+ ...
    switching_gain_rad_s2/reaching_gain_per_s)-switching_gain_rad_s2/reaching_gain_per_s;
exact_s_rad_s=max(unclipped_magnitude_rad_s,0).*sign(initial_s_rad_s);
exact_v_rad2_s2=.5*exact_s_rad_s.^2;
exact_s_rate_rad_s2=-reaching_gain_per_s*exact_s_rad_s ...
    -switching_gain_rad_s2*sign(exact_s_rad_s);
v_rate_from_rule_rad2_s3=exact_s_rad_s.*exact_s_rate_rad_s2;

% 独立从分段准确曲线求 V 的变化率；不在 s 的到达点宣称通常双侧导数存在。
branch_s_rate_rad_s2=-reaching_gain_per_s*decay ...
    *(abs(initial_s_rad_s)+switching_gain_rad_s2/reaching_gain_per_s).*sign(initial_s_rad_s);
v_rate_from_curve_rad2_s3=exact_s_rad_s.*branch_s_rate_rad_s2;
v_rate_from_curve_rad2_s3(exact_s_rad_s==0)=0;
assert(max(abs(v_rate_from_curve_rad2_s3-v_rate_from_rule_rad2_s3),[],'all')<1e-12, ...
    'SMC:Lesson10:CurveRate','准确曲线的 V 变化率不满足规则。');
assert(max(abs(exact_s_rad_s(1,:)-initial_s_rad_s))<1e-12 && ...
    isequal(exact_v_rad2_s2(1,:),[18,18,0]), ...
    'SMC:Lesson10:Initial','曲线初值不符。');
assert(max(abs(exact_s_rad_s(:,1)+exact_s_rad_s(:,2)))<1e-12 && ...
    max(abs(exact_v_rad2_s2(:,1)-exact_v_rad2_s2(:,2)))<1e-12, ...
    'SMC:Lesson10:Mirror','正负 s 应相反，V 应相同。');
assert(all(diff(exact_v_rad2_s2,1,1)<=1e-12,'all') && ...
    all(exact_v_rad2_s2>=0,'all') && all(exact_v_rad2_s2(end,:)==0), ...
    'SMC:Lesson10:Monotonic','准确曲线的 V 应非负、不增加并到零。');
v_upper_bound_rad2_s2=exp(-2*reaching_gain_per_s*time_s)*exact_v_rad2_s2(1,:);
assert(all(exact_v_rad2_s2<=v_upper_bound_rad2_s2+1e-12,'all'), ...
    'SMC:Lesson10:Bound','V 超过理论指数上界。');

%% V=0 不等于位置误差 e=0：单个状态点，不生成 e 的运动轨迹
surface_gain_per_s=.5;
on_surface_error_rad=1;
on_surface_error_rate_rad_s=-.5;
on_surface_s_rad_s=on_surface_error_rate_rad_s+surface_gain_per_s*on_surface_error_rad;
assert(on_surface_s_rad_s==0 && .5*on_surface_s_rad_s^2==0 && on_surface_error_rad~=0, ...
    'SMC:Lesson10:Surface','应存在 V=0、位置误差非零的状态点。');

%% 不增加不保证到零：这个恒定反例不满足本讲趋近律
constant_counterexample_s_rad_s=2;
constant_counterexample_v_rad2_s2=.5*constant_counterexample_s_rad_s^2;
constant_counterexample_v_rate_rad2_s3=0;
assert(constant_counterexample_v_rad2_s2==2 && ...
    constant_counterexample_v_rate_rad2_s3==0, ...
    'SMC:Lesson10:Constant','恒定非零反例不符。');

%% 一步近似不等于准确运动：固定当前 rate=-4，分别前进一步
step_initial_s_rad_s=2;
step_initial_rate_rad_s2=-4;
step_dt_s=[.1,1,1.25];
step_next_s_rad_s=step_initial_s_rad_s+step_initial_rate_rad_s2*step_dt_s;
step_next_v_rad2_s2=.5*step_next_s_rad_s.^2;
assert(max(abs(step_next_s_rad_s-[1.6,-2,-3]))<1e-12 && ...
    max(abs(step_next_v_rad2_s2-[1.28,2,4.5]))<1e-12, ...
    'SMC:Lesson10:Step','一步近似手算结果不符。');

%% 图像：准确 s 曲线与 V 曲线；正负初值的 V 重合，用不同线型表示
lesson_show_figure=usejava('desktop');
lesson_visibility='off';
if lesson_show_figure, lesson_visibility='on'; end
lesson_figure=figure('Visible',lesson_visibility,'Color','w','Position',[60,70,1200,650]);
if ~lesson_show_figure, lesson_cleanup=onCleanup(@()close(lesson_figure)); end
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(time_s,exact_s_rad_s(:,1),'Color',[.1,.45,.8],'LineWidth',2); hold on;
plot(time_s,exact_s_rad_s(:,2),'--','Color',[.85,.3,.1],'LineWidth',2);
plot(time_s,exact_s_rad_s(:,3),':','Color',[.3,.3,.3],'LineWidth',1.8);
xlabel('时间 / s'); ylabel('滑模变量 s / (rad/s)');
title('正负两侧都朝 s=0 运动');
legend('初始 s=+6','初始 s=-6','初始 s=0','Location','northeast');
xlim([0,duration_s]); ylim([-7,7]); grid on;
nexttile;
plot(time_s,exact_v_rad2_s2(:,1),'Color',[.1,.45,.8],'LineWidth',2.8); hold on;
plot(time_s,exact_v_rad2_s2(:,2),'--','Color',[.85,.3,.1],'LineWidth',1.6);
plot(time_s,exact_v_rad2_s2(:,3),':','Color',[.3,.3,.3],'LineWidth',1.8);
plot(time_s,v_upper_bound_rad2_s2(:,1),'-.','Color',[.25,.6,.3],'LineWidth',1.5);
xlabel('时间 / s'); ylabel('非负读数 V / (rad²/s²)');
title('正负初值的 V 曲线重合，并低于指数上界');
legend('初始 s=+6 对应 V','初始 s=-6 对应 V','初始 s=0 对应 V', ...
    '18 exp(-2t) 上界','Location','northeast');
xlim([0,duration_s]); ylim([-.6,20]); grid on;
sgtitle('第10讲：用 V=s²/2 检查趋近过程（理想关系，教学假设）');
exportgraphics(lesson_figure,fullfile(lesson_out,'用非负量检查趋近过程.png'),'Resolution',130);
savefig(lesson_figure,fullfile(lesson_out,'用非负量检查趋近过程.fig'));

probe_table=table(probe_s_rad_s',probe_s_rate_rad_s2',probe_v_rad2_s2',probe_v_rate_rad2_s3', ...
    'VariableNames',{'s_rad_s','s_rate_rad_s2','v_rad2_s2','v_rate_rad2_s3'});
writetable(probe_table,fullfile(lesson_out,'五个手算点.csv'));
grid_table=table(grid_s_rad_s,grid_product_rad2_s3,grid_expanded_rad2_s3,grid_difference_rad2_s3, ...
    'VariableNames',{'s_rad_s','product_v_rate_rad2_s3','expanded_v_rate_rad2_s3','difference_rad2_s3'});
writetable(grid_table,fullfile(lesson_out,'1201点变化率核对.csv'));
curve_table=array2table([time_s,exact_s_rad_s,exact_v_rad2_s2, ...
    v_rate_from_rule_rad2_s3,v_upper_bound_rad2_s2(:,1)],'VariableNames', ...
    {'time_s','positive_s_rad_s','negative_s_rad_s','zero_s_rad_s', ...
    'positive_v_rad2_s2','negative_v_rad2_s2','zero_v_rad2_s2', ...
    'positive_v_rate_rad2_s3','negative_v_rate_rad2_s3','zero_v_rate_rad2_s3', ...
    'positive_v_upper_bound_rad2_s2'});
writetable(curve_table,fullfile(lesson_out,'理想曲线与V.csv'));
step_table=table(step_dt_s',step_next_s_rad_s',step_next_v_rad2_s2', ...
    'VariableNames',{'step_dt_s','next_s_rad_s','next_v_rad2_s2'});
writetable(step_table,fullfile(lesson_out,'一步近似的边界例子.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'reaching_gain_per_s','switching_gain_rad_s2', ...
    'initial_s_rad_s','duration_s','plot_step_s','surface_gain_per_s', ...
    'on_surface_error_rad','on_surface_error_rate_rad_s','probe_table','grid_table', ...
    'curve_table','step_table','v_rate_from_curve_rad2_s3');
lesson_report.reaching_gain_per_s=reaching_gain_per_s;
lesson_report.switching_gain_rad_s2=switching_gain_rad_s2;
lesson_report.probe_s_rad_s=probe_s_rad_s;
lesson_report.probe_v_rad2_s2=probe_v_rad2_s2;
lesson_report.probe_v_rate_rad2_s3=probe_v_rate_rad2_s3;
lesson_report.grid_point_count=numel(grid_s_rad_s);
lesson_report.max_grid_difference_rad2_s3=max(abs(grid_difference_rad2_s3));
lesson_report.max_curve_rate_difference_rad2_s3= ...
    max(abs(v_rate_from_curve_rad2_s3-v_rate_from_rule_rad2_s3),[],'all');
lesson_report.initial_s_rad_s=initial_s_rad_s;
lesson_report.duration_s=duration_s;
lesson_report.plot_step_s=plot_step_s;
lesson_report.final_v_rad2_s2=exact_v_rad2_s2(end,:);
lesson_report.on_surface_error_rad=on_surface_error_rad;
lesson_report.step_dt_s=step_dt_s;
lesson_report.step_next_v_rad2_s2=step_next_v_rad2_s2;
lesson_report.checks={'五个手算点','1201 点变化率恒等式及负号','准确曲线的变化率', ...
    '初值与正负对称','沿曲线 V 非负且不增加','指数上界', ...
    'V 为零但位置误差非零','不增加不保证到零','一步近似与连续结论的区别'};
lesson_report.passed=true;
lesson_write_json(fullfile(lesson_out,'运行报告.json'),lesson_report);
fprintf('第10讲通过：s=-6/-2/0/2/6 时 V=18/2/0/2/18，V_rate=-48/-8/0/-8/-48。\n');
fprintf('1201 点、准确曲线、指数上界及边界例子核对通过。\n');
fprintf('输出目录：%s\n',lesson_out);
if ~lesson_show_figure, clear lesson_cleanup; end

function lesson_write_json(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Lesson10:File','无法写入运行报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
