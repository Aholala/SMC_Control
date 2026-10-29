function report=smc_extension_experiment(root,out,points,scenarios)
% 当前生产库的真实输出与MATLAB独立single递推，模型double独立推进。
    if ~isfolder(out), mkdir(out); end
    path=fullfile(out,'数值核对报告.json');
    report=struct('passed',false,'matlab',version,'firmware_linked',false,'hardware_tested',false, ...
        'reference_cpp_executed',false,'matlab_loop_reads_cpp_controls',false,'matlab_loop_reads_cpp_measurements',false);
    smc_teaching_report(path,report);
    abs_tol=3e-5; rel_tol=3e-5; % 新增pow与长序列比较；运行前固定。
    input_names={'kind','block','b','c','extra','exponent','K','epsilon','phi','delta', ...
        'minimum','maximum','target','target_rate','target_acc','measurement','measurement_rate','dt','operation'};
    input_path=fullfile(out,'共同输入.csv');
    writetable(array2table(points,'VariableNames',input_names),input_path);
    selected=strjoin(arrayfun(@num2str,scenarios,'UniformOutput',false),',');
    [status,log]=system(sprintf('pwsh -NoProfile -File "%s" -InputCsv "%s" -OutputDirectory "%s" -Scenarios "%s"', ...
        fullfile(root,'tests','verify_extensions.ps1'),input_path,out,selected));
    assert(status==0,'SMC:Extensions:Host','主机实验失败：%s',log);
    host=jsondecode(fileread(fullfile(out,'主机运行报告.json')));
    cpp=readmatrix(fullfile(out,'真实C++公式点.csv'));
    assert(host.passed && isequal(size(cpp),[size(points,1),11]) && all(isfinite(cpp),'all'));
    assert(isequal(cpp(:,1:3),[(1:size(points,1))',points(:,1:2)]));
    expected=zeros(size(points,1),8); double_reference=expected; z=single(0); zd=0; old=[-1,-1];
    for row=1:size(points,1)
        if ~isequal(points(row,1:2),old), z=single(0); zd=0; old=points(row,1:2); end
        [r,z]=smc_extension_formula(single(points(row,:)),z); expected(row,:)=double(r);
        [double_reference(row,:),zd]=smc_extension_formula(points(row,:),zd);
    end
    delta=cpp(:,4:11)-expected;
    bad=[abs(delta(:,1:6))>abs_tol+rel_tol*abs(expected(:,1:6)),delta(:,7:8)~=0];
    first=find(any(bad,2),1); report.first_point_exceeding_row=first;
    if ~isempty(first), smc_teaching_report(path,report); error('SMC:Extensions:Points','第%d个公式点超差。',first); end
    names={'error','error_rate','integral','s','request','output','limited','terminal_branch'};
    writetable(array2table(expected,'VariableNames',names),fullfile(out,'独立single公式.csv'));
    writetable(array2table(double_reference,'VariableNames',names),fullfile(out,'独立double对照.csv'));
    writetable(array2table(delta,'VariableNames',names),fullfile(out,'公式点差值.csv'));
    case_names={'普通位置与持续外力','位置累计与持续外力','位置累计与强限幅','位置累计暂停重启', ...
        '混合幂次趋近','普通位置同条件对照','终端分段位置','终端分段反向输入'};
    columns={'time','target','target_rate','target_acc','position','rate','error','error_rate','integral', ...
        's','request','caller','applied','limited','terminal_branch','enabled','called','reset','has_result','disturbance'};
    cases=repmat(struct(),1,numel(scenarios));
    for which=1:numel(scenarios)
        scenario=scenarios(which); data=readmatrix(fullfile(out,sprintf('案例%02d_真实C++.csv',scenario)));
        [reference,terminal_reference]=independent_loop(scenario);
        assert(isequal(size(data),[8000,20]) && all(isfinite(data),'all'));
        difference=data-reference;
        bad=[abs(difference(:,1:13))>abs_tol+rel_tol*abs(reference(:,1:13)), ...
            difference(:,14:19)~=0,abs(difference(:,20))>1e-12];
        first=find(any(bad,2),1);
        if ~isempty(first)
            report.first_closed_case=scenario; report.first_closed_row=first;
            report.first_closed_field=columns{find(bad(first,:),1)};
            smc_teaching_report(path,report);
            error('SMC:Extensions:Closed','案例%d第%d行字段%s超差。',scenario,first,report.first_closed_field);
        end
        [v,b,bound]=case_config(scenario); dt=.001;
        acceleration=b*data(:,13)+data(:,20);
        rebuilt=[data(1:end-1,5)+data(1:end-1,6)*dt+.5*acceleration(1:end-1)*dt^2, ...
            data(1:end-1,6)+acceleration(1:end-1)*dt];
        reconstruction=data(2:end,5:6)-rebuilt;
        assert(max(abs(reconstruction),[],'all')<1e-12,'SMC:Extensions:Plant','案例%d相邻状态重建失败。',scenario);
        assert(all(abs(data(:,13))<=bound),'SMC:Extensions:Limit','案例%d越过单精度输出范围。',scenario);
        active=data(:,17)==1;
        assert(all(data(active,14)==(data(active,11)~=data(active,12))));
        terminal=[data(end,5)+data(end,6)*dt+.5*acceleration(end)*dt^2,data(end,6)+acceleration(end)*dt];
        assert(all(abs(terminal-terminal_reference)<=abs_tol+rel_tol*abs(terminal_reference)));
        position_error=data(:,5)-data(:,2);
        if scenario==1, assert(abs(position_error(end)-.4/(4*(6+2/.25)))<3e-6); end
        if scenario==2, assert(abs(position_error(end))<1e-3); end
        if scenario==3, assert(any(data(:,14)) && max(abs(data(:,9)))>.1); end
        if scenario==4
            paused=1001:1500;
            assert(all(data(paused,13)==0) && all(data(paused,9)==0) && all(data(paused,19)==0) && ...
                all(data(paused,12)==data(1000,12)) && data(1001,18)==1 && abs(position_error(end))<1e-3);
        end
        if scenario>=5, assert(abs(position_error(end))<2e-5); end
        cases(which).scenario=scenario; cases(which).name=case_names{scenario}; cases(which).config_row=double(v);
        cases(which).rows=8000; cases(which).calc_count=nnz(active);
        cases(which).max_current_difference=max(abs(difference(:,13)));
        cases(which).max_numeric_difference_by_column=max(abs(difference(:,1:13)),[],1);
        cases(which).max_reconstruction_difference=max(abs(reconstruction),[],'all');
        cases(which).last_position_error=position_error(end); cases(which).peak_integral=max(abs(data(:,9)));
        cases(which).limited_steps=nnz(data(:,14)); cases(which).terminal_steps=nnz(data(:,15));
        cases(which).terminal_state_at_8s=terminal; cases(which).reference_terminal_state_at_8s=terminal_reference;
        writetable(array2table(reference,'VariableNames',columns),fullfile(out,sprintf('案例%02d_独立MATLAB.csv',scenario)));
        writetable(array2table(difference,'VariableNames',columns),fullfile(out,sprintf('案例%02d_差值.csv',scenario)));
        plot_case(data,case_names{scenario},out,scenario);
    end
    report.source_hashes=host.hashes; report.input_sha256=host.input_sha256; report.compiler=host.compiler_version;
    report.point_count=size(points,1); report.max_point_difference_by_column=max(abs(delta),[],1);
    report.max_double_reference_difference=max(abs(cpp(:,4:9)-double_reference(:,1:6)),[],1);
    report.absolute_tolerance=abs_tol; report.relative_tolerance=rel_tol;
    report.scenarios=scenarios; report.cases=cases; report.record_count=8000*numel(scenarios);
    report.calc_count=sum([cases.calc_count]); report.state_transition_checks=7999*numel(scenarios);
    report.passed=true; smc_teaching_report(path,report);
    save(fullfile(out,'实验参数与数据.mat'),'points','cpp','expected','double_reference','delta','report');
end

function [v,b,bound]=case_config(scenario)
    kind=0; if scenario>=2 && scenario<=4, kind=1; elseif scenario==5, kind=2; elseif scenario>=7, kind=3; end
    b=3; if scenario==8, b=-3; end
    bound=4; if scenario==3, bound=double(single(.2)); end
    extra=2; if kind==1, extra=4; end
    v=single([kind,0,b,4,extra,.5,6,2,.25,.25,-bound,bound,zeros(1,7)]);
end
function [data,terminal]=independent_loop(scenario)
    [v,b,~]=case_config(scenario); dt=.001; position=-.2; rate=0; z=single(0); caller=0;
    data=zeros(8000,20); values=zeros(1,8); has=false;
    for index=0:7999
        enabled=~(scenario==4 && index>=1000 && index<1500); reset=scenario==4 && index==1000;
        if reset, z=single(0); values=zeros(1,8); has=false; end
        target=.5; if scenario==4 && index>=1500, target=-.3; end
        v(13:19)=single([target,0,0,position,rate,dt,0]);
        if enabled
            [values,z]=smc_extension_formula(v,z); values=double(values); caller=values(6); has=true;
        end
        applied=0; if enabled, applied=caller; end
        disturbance=0; if scenario<=3 && index>=2000, disturbance=.4; end
        data(index+1,:)=[index*dt,target,0,0,position,rate,values(1:5),caller,applied, ...
            values(7:8),enabled,enabled,reset,has,disturbance];
        acceleration=b*applied+disturbance;
        position=position+rate*dt+.5*acceleration*dt*dt; rate=rate+acceleration*dt;
    end
    terminal=[position,rate];
end
function plot_case(data,name,out,scenario)
    fig=figure('Visible','off','Color','w','Position',[60,60,1150,760]); cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    nexttile; plot(data(:,1),data(:,2),'k--',data(:,1),data(:,5),'LineWidth',1.3); grid on;
    xlabel('时间 / s'); ylabel('角度 / rad'); title('目标与真实对象'); legend('目标','实际','Location','best');
    nexttile; plot(data(:,1),data(:,5)-data(:,2),'LineWidth',1.3); grid on;
    xlabel('时间 / s'); ylabel('位置误差 / rad'); title('末值按真实结果记录');
    nexttile;
    if scenario>=2 && scenario<=4
        plot(data(:,1),data(:,9),'LineWidth',1.3); ylabel('位置误差累计 / (rad·s)'); title('直接累计，不增加累计限幅');
    else
        plot(data(:,1),data(:,10),'LineWidth',1.3); ylabel('滑模变量 / (rad/s)'); title('实际使用的滑模变量');
    end
    xlabel('时间 / s'); grid on;
    nexttile; request=data(:,11); request(data(:,19)==0)=NaN;
    plot(data(:,1),request,'--',data(:,1),data(:,13),'LineWidth',1.2); grid on;
    xlabel('时间 / s'); ylabel('电流 / A'); title('请求与实际施加，失效诊断不绘制'); legend('请求','施加','Location','best');
    sgtitle([name,'（教学假设，非实机）']);
    base=fullfile(out,sprintf('案例%02d',scenario)); exportgraphics(fig,[base,'.png'],'Resolution',130); savefig(fig,[base,'.fig']);
end
