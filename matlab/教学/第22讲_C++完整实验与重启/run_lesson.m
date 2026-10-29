%% 第22讲：真实C++闭环、输出限制与暂停后重新启动
% start.m: number=22。MATLAB、pwsh、g++，无Simulink或额外工具箱。
% 参数、初值、对象积分沿用已有verification_runner教学假设；重启流程仅在示例中。
lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(lesson_root,'matlab','内部函数'));
lesson_out=fullfile(lesson_root,'build','教学','第22讲_C++完整实验与重启');
if ~isfolder(lesson_out), mkdir(lesson_out); end
report_path=fullfile(lesson_out,'运行报告.json');
lesson_report=struct('passed',false,'lesson',22,'matlab',version, ...
    'learner_understanding_confirmed',false,'firmware_linked',false,'hardware_tested',false, ...
    'matlab_loop_reads_cpp_controls',false,'matlab_loop_reads_cpp_measurements',false);
smc_teaching_report(report_path,lesson_report);
absolute_tolerance=2e-5; relative_tolerance=2e-5; % 沿用既有完整闭环允许差，运行前固定。
reconstruction_tolerance=1e-12; final_error_limit_rad=2e-5;
dt=.001; count=8000;
case_names={'正向输入增益','反向输入增益','输出限制为正负1A','暂停复位与新目标重启'};
names={'time','target','target_rate','target_acc','position','rate','measurement','measurement_rate', ...
    'error','error_rate','s','request','caller_command','applied_command','limited', ...
    'enabled','calc_called','calc_success','reset_event','has_result'};
[all_cpp,host]=smc_teaching_host(lesson_root,lesson_out,22);
assert(isequal(size(all_cpp),[32000,21]),'SMC:Lesson22:Size','预期四组各8000行。');
cases=repmat(struct(),1,4);
all_matlab=zeros(size(all_cpp)); all_delta=zeros(size(all_cpp));
all_reconstruction=zeros(4*(count-1),4);
for scenario=1:4
    selected=all_cpp(:,1)==scenario; cpp=all_cpp(selected,2:end);
    assert(isequal(size(cpp),[count,20]),'SMC:Lesson22:Case','案例行数不符。');
    b=3; bound=4;
    if scenario==2, b=-3; end
    if scenario==3, bound=1; end
    config=[b,4,6,2,.25]; bounds=[-bound,bound];
    % 独立函数仅接收参数、初值与操作时刻；不接收C++控制量或测量。
    [expected,matlab_terminal]=lesson_independent_loop(scenario,config,bounds,dt,count,[-.2,0]);
    delta=cpp-expected;
    failed=abs(delta(:,1:14))>absolute_tolerance+relative_tolerance*abs(expected(:,1:14));
    failed=[failed,cpp(:,15:20)~=expected(:,15:20)];
    bad_row=find(any(failed,2),1);
    if ~isempty(bad_row)
        bad_column=find(failed(bad_row,:),1);
        lesson_report.first_exceeding_case=scenario;
        lesson_report.first_exceeding_row=bad_row;
        lesson_report.first_exceeding_field=names{bad_column};
        smc_teaching_report(report_path,lesson_report);
        error('SMC:Lesson22:Alignment','案例%d第%d行字段%s超差。',scenario,bad_row,names{bad_column});
    end
    assert(max(abs(cpp(:,1)-(0:count-1)'*dt))<1e-12 && ...
        isequal(cpp(:,5:6),cpp(:,7:8)) && all(cpp(:,3:4)==0,'all'), ...
        'SMC:Lesson22:Conditions','时间、理想测量或静止目标变化率不符。');
    assert(all(abs(cpp(:,14))<=bound) && any(cpp(:,15)==1) && any(cpp(:,15)==0), ...
        'SMC:Lesson22:Limit','实际执行电流越界或未同时覆盖受限与未受限。');
    % 以实际执行列14重建下一状态，不能误用仍被保留的调用方变量列13。
    acceleration=b*cpp(:,14);
    next_position=cpp(1:end-1,5)+cpp(1:end-1,6)*dt+.5*acceleration(1:end-1)*dt^2;
    next_rate=cpp(1:end-1,6)+acceleration(1:end-1)*dt;
    reconstruction=cpp(2:end,5:6)-[next_position,next_rate];
    assert(max(abs(reconstruction),[],'all')<reconstruction_tolerance, ...
        'SMC:Lesson22:Plant','相邻对象状态不是由实际施加电流推进得到。');
    terminal=[cpp(end,5)+cpp(end,6)*dt+.5*acceleration(end)*dt^2,cpp(end,6)+acceleration(end)*dt];
    assert(all(abs(terminal-matlab_terminal)<=absolute_tolerance+relative_tolerance*abs(matlab_terminal)), ...
        'SMC:Lesson22:Terminal','8秒状态与独立闭环不符。');
    true_error=cpp(:,5)-cpp(:,2);
    assert(abs(true_error(end))<final_error_limit_rad,'SMC:Lesson22:Final','本案例末行误差超过预设检查值。');
    if scenario==4
        stopped=1001:1500; restart=1501;
        assert(nnz(cpp(:,17))==7500 && nnz(cpp(:,19))==1 && cpp(1001,19)==1 && ...
            all(cpp(stopped,14)==0) && all(cpp(stopped,16:18)==0,'all') && ...
            all(cpp(stopped,20)==0) && all(cpp(stopped,9:12)==0,'all') && ...
            all(cpp(stopped,13)==cpp(1000,13)) && ...
            abs(cpp(1500,5)-cpp(1001,5))>1e-4 && ...
            abs(cpp(restart,5)+.2)>1e-3 && cpp(restart,20)==1 && ...
            cpp(restart,2)==-.3 && cpp(restart,17)==1 && ...
            abs(cpp(restart,13)-cpp(1000,13))>1e-3, ...
            'SMC:Lesson22:Restart','暂停、外部旧值、物理运动或重启数据路径不符。');
    else
        assert(all(cpp(:,16:18)==1,'all') && all(cpp(:,19)==0) && all(cpp(:,20)==1), ...
            'SMC:Lesson22:Enabled','连续运行案例出现未声明的暂停。');
    end
    all_matlab(selected,:)=[scenario*ones(count,1),expected];
    all_delta(selected,:)=[scenario*ones(count,1),delta];
    rows=(scenario-1)*(count-1)+(1:count-1);
    all_reconstruction(rows,:)=[scenario*ones(count-1,1),cpp(2:end,1),reconstruction];
    cases(scenario).name=case_names{scenario};
    cases(scenario).config=config; cases(scenario).output_limits_a=bounds;
    cases(scenario).row_count=count; cases(scenario).calc_count=nnz(cpp(:,17));
    cases(scenario).limited_calc_count=nnz(cpp(:,15)&cpp(:,17));
    cases(scenario).max_numeric_difference_by_column=max(abs(delta),[],1);
    cases(scenario).max_applied_current_difference_a=max(abs(delta(:,14)));
    cases(scenario).max_position_difference_rad=max(abs(delta(:,5)));
    cases(scenario).max_reconstruction_difference=max(abs(reconstruction),[],'all');
    cases(scenario).last_record_position_error_rad=true_error(end);
    cases(scenario).last_record_time_s=cpp(end,1);
    cases(scenario).cpp_terminal_state_at_8s=terminal;
    cases(scenario).matlab_terminal_state_at_8s=matlab_terminal;
    lesson_plot(cpp,scenario,case_names{scenario},lesson_out);
end
positive=all_cpp(all_cpp(:,1)==1,2:end); negative=all_cpp(all_cpp(:,1)==2,2:end);
assert(max(abs(positive(:,5:6)-negative(:,5:6)),[],'all')<1e-12 && ...
    max(abs(positive(:,14)+negative(:,14)))<1e-12, ...
    'SMC:Lesson22:Direction','匹配模型下b反向后未得到相反电流与相同运动。');
writetable(array2table(all_matlab,'VariableNames',[{'scenario'},names]),fullfile(lesson_out,'独立MATLAB闭环.csv'));
writetable(array2table(all_delta,'VariableNames',[{'scenario'},names]),fullfile(lesson_out,'两套闭环逐次差值.csv'));
writetable(array2table(all_reconstruction,'VariableNames', ...
    {'scenario','next_time_s','position_difference_rad','rate_difference_rad_s'}),fullfile(lesson_out,'实际电流与相邻状态核对.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'all_cpp','all_matlab','all_delta','all_reconstruction', ...
    'cases','dt','count','absolute_tolerance','relative_tolerance','reconstruction_tolerance','final_error_limit_rad');
lesson_report.compiler=host.compiler_version; lesson_report.source_hashes=host.hashes;
lesson_report.production_sources_modified=false; lesson_report.plant_state_advanced=true;
lesson_report.controller_output_drives_plant=true; lesson_report.column_order=names;
lesson_report.dt_s=dt; lesson_report.duration_s=8; lesson_report.case_count=4;
lesson_report.record_count=32000; lesson_report.calc_count=sum([cases.calc_count]);
lesson_report.state_transition_checks=4*(count-1); lesson_report.cases=cases;
lesson_report.absolute_tolerance=absolute_tolerance; lesson_report.relative_tolerance=relative_tolerance;
lesson_report.reconstruction_tolerance=reconstruction_tolerance;
lesson_report.final_error_check_rad=final_error_limit_rad;
lesson_report.restart_times_s=[1,1.5]; lesson_report.pause_has_zero_applied_current=true;
lesson_report.pause_retains_physical_state=true; lesson_report.first_exceeding_row=[];
lesson_report.parameter_source='沿用verification_runner的b、c、K、epsilon、phi、初值与积分；暂停流程为本讲显式教学假设';
lesson_report.passed=true; smc_teaching_report(report_path,lesson_report);
fprintf('第22讲通过：四组32000行，%d次真实Calc，%d组相邻状态核对。\n', ...
    lesson_report.calc_count,lesson_report.state_transition_checks);
fprintf('四组施加电流最大差：'); fprintf(' %.3g', [cases.max_applied_current_difference_a]); fprintf(' A。\n');

function [data,terminal]=lesson_independent_loop(scenario,config,bounds,dt,count,initial)
    position=initial(1); rate=initial(2); caller=0; result=zeros(1,6); has=false;
    data=zeros(count,20);
    for index=0:count-1
        enabled=~(scenario==4 && index>=1000 && index<1500);
        reset=scenario==4 && index==1000;
        target=.5; if scenario==4 && index>=1500, target=-.3; end
        if reset, result=zeros(1,6); has=false; end
        if enabled
            input=double(single([target,0,0,position,rate]));
            e=input(4)-input(1); edot=input(5)-input(2); s=edot+config(2)*e;
            request=(input(3)-config(2)*edot-config(3)*s ...
                -config(4)*max(-1,min(1,s/config(5))))/config(1);
            caller=max(bounds(1),min(bounds(2),request));
            result=[e,edot,s,request,caller,request~=caller]; has=true;
        end
        applied=0; if enabled, applied=caller; end
        data(index+1,:)=[index*dt,target,0,0,position,rate,position,rate, ...
            result(1:4),caller,applied,result(6),enabled,enabled,enabled,reset,has];
        acceleration=config(1)*applied;
        position=position+rate*dt+.5*acceleration*dt^2;
        rate=rate+acceleration*dt;
    end
    terminal=[position,rate];
end
function lesson_plot(data,scenario,name,out)
    visible='off'; if usejava('desktop'), visible='on'; end
    fig=figure('Visible',visible,'Color','w','Position',[60,50,1250,800]);
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    nexttile; plot(data(:,1),data(:,2),'k--',data(:,1),data(:,5),'LineWidth',1.5); grid on;
    xlabel('时间 / s'); ylabel('角度 / rad'); title('真实C++电流推进对象'); legend('目标','对象','Location','best');
    nexttile; plot(data(:,1),data(:,5)-data(:,2),'LineWidth',1.5); grid on;
    xlabel('时间 / s'); ylabel('对象位置误差 / rad'); title('目标改变时误差也随之改变');
    nexttile; plot(data(:,1),data(:,12),'--',data(:,1),data(:,13),':', ...
        data(:,1),data(:,14),'LineWidth',1.3); grid on;
    xlabel('时间 / s'); ylabel('电流 / A'); title('诊断无效时，请求列的零值不代表新计算');
    legend('保存的请求','调用方变量','实际施加','Location','best');
    nexttile;
    if scenario==4
        stairs(data(:,1),data(:,16),'LineWidth',1.5); hold on;
        stairs(data(:,1),data(:,20),'--','LineWidth',1.2); ylim([-.1,1.2]);
        ylabel('状态 / 0或1'); title('1s复位并暂停，1.5s在现有物理状态重启');
        legend('启用','结果有效','Location','best');
    else
        plot(data(:,1),data(:,11),'LineWidth',1.5); ylabel('滑模变量 / (rad/s)'); title('s与位置误差分别记录');
    end
    xlabel('时间 / s'); grid on;
    sgtitle(sprintf('第22讲：%s（教学对象，非实机）',name));
    exportgraphics(fig,fullfile(out,sprintf('案例%02d_完整实验.png',scenario)),'Resolution',130);
    savefig(fig,fullfile(out,sprintf('案例%02d_完整实验.fig',scenario)));
    if ~usejava('desktop'), close(fig); end
end
