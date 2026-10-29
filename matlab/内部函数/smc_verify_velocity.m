function report=smc_verify_velocity(root,build_host)
% 速度库独立验证。single按库数值精度独立计算；另记录double累计对照。
% build_host=false仅供同次已构建的总验证调用，仍核对源码摘要。
    out=fullfile(root,'build','验证','速度控制');
    native=fullfile(root,'build','velocity_verification');
    if ~isfolder(out), mkdir(out); end
    if ~isfolder(native), mkdir(native); end
    report_path=fullfile(out,'验证报告.json');
    report=struct('passed',false,'matlab',version,'firmware_linked',false,'hardware_tested',false, ...
        'reference_cpp_executed',false,'matlab_loop_reads_cpp_controls',false);
    smc_teaching_report(report_path,report);
    if build_host
        [status,log]=system(sprintf('pwsh -NoProfile -File "%s"',fullfile(root,'tests','verify_host.ps1')));
        fid=fopen(fullfile(out,'主机验证.log'),'w','n','UTF-8'); assert(fid~=-1); fprintf(fid,'%s',log); fclose(fid);
        assert(status==0,'SMC:Velocity:Build','主机验证失败：%s',log);
    end
    host=jsondecode(fileread(fullfile(root,'build','host','host_verification.json')));
    assert(host.passed && host.test_count==13,'SMC:Velocity:HostReport','需要本版十三项主机测试。');
    for h=1:numel(host.hashes)
        [status,hash]=system(sprintf('pwsh -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',host.hashes(h).Path));
        assert(status==0 && strcmpi(strtrim(hash),host.hashes(h).Hash),'SMC:Velocity:Hash','构建源码已变化，请重新验证。');
    end
    runner=fullfile(root,'build','host','velocity_verification_runner.exe');
    numeric_abs=2e-5; numeric_rel=2e-5;

    %% 六个可手算的连续点；先累计后计算，边界与限幅分别检查
    hand_inputs=[0,0,.5,.5;0,0,.5,.5;0,0,-.5,.5;3,6,3,.5;0,0,-1,.5;0,1,1,.5];
    points=[zeros(6,1),repmat([2,2,3,4,2,-3,3],6,1),hand_inputs];
    configs=[3,4,6,2,.25;-3,4,6,2,.25;2,2,3,4,2;-2,2,3,4,2];
    n=(0:1023)';
    periods=repmat([.001;.005;.02],ceil(1024/3),1);
    inputs=[1.2*sin(.013*n),.4*cos(.031*n),.8*cos(.019*n),periods(1:1024)];
    for block=1:4
        points=[points;block*ones(1024,1),repmat([configs(block,:),-1.5,2.25],1024,1),inputs]; %#ok<AGROW>
    end
    points(:,2:end)=double(single(points(:,2:end)));
    input_names={'block','b','c','K','epsilon','phi','minimum','maximum', ...
        'target','target_acceleration','measurement','dt'};
    input_path=fullfile(native,'input.csv'); output_path=fullfile(native,'points.csv');
    writetable(array2table(points,'VariableNames',input_names),input_path);
    [status,log]=system(sprintf('"%s" points "%s" "%s"',runner,input_path,output_path));
    assert(status==0,'SMC:Velocity:Points','真实速度序列失败：%s',log);
    cpp=readmatrix(output_path); assert(isequal(size(cpp),[4102,8]) && all(isfinite(cpp),'all'));
    expected=zeros(4102,6); single_expected=zeros(4102,6); previous=-1; integral=0; single_integral=single(0);
    for row=1:size(points,1)
        if points(row,1)~=previous, integral=0; single_integral=single(0); previous=points(row,1); end
        [expected(row,:),integral]=velocity_formula(points(row,2:6),points(row,7:8),points(row,9:12),integral);
        [single_expected(row,:),single_integral]=velocity_formula(single(points(row,2:6)),single(points(row,7:8)), ...
            single(points(row,9:12)),single_integral);
    end
    double_delta=cpp(:,3:8)-expected;
    delta=cpp(:,3:8)-single_expected;
    allowed=numeric_abs+numeric_rel*abs(single_expected(:,1:5));
    bad=[abs(delta(:,1:5))>allowed,cpp(:,8)~=single_expected(:,6)];
    first=find(any(bad,2),1); report.first_sequence_exceeding_row=first;
    if ~isempty(first), smc_teaching_report(report_path,report); error('SMC:Velocity:Sequence','第%d行速度序列超差。',first); end
    hand=[.5,.25,1,-3,-3,0;.5,.5,1.5,-4.25,-3,1;-.5,.25,0,.5,.5,0; ...
        0,.25,.5,1.75,1.75,0;-1,-.25,-1.5,4.75,3,1;1,.25,1.5,-4.25,-3,1];
    assert(isequal(cpp(1:6,3:8),hand),'SMC:Velocity:Hand','六个连续手算点不符。');
    copyfile(input_path,fullfile(out,'共同输入序列.csv'));
    copyfile(output_path,fullfile(out,'真实C++逐次结果.csv'));
    result_names={'error','integral','s','request','output','limited'};
    writetable(array2table(expected,'VariableNames',result_names),fullfile(out,'独立double逐次结果.csv'));
    writetable(array2table(single_expected,'VariableNames',result_names),fullfile(out,'独立single逐次结果.csv'));
    writetable(array2table(delta,'VariableNames',result_names),fullfile(out,'逐次差值.csv'));
    writetable(array2table(double_delta,'VariableNames',result_names),fullfile(out,'与double累计的差值.csv'));
    report.sequence_count=4102; report.sequence_absolute_tolerance=numeric_abs; report.sequence_relative_tolerance=numeric_rel;
    report.sequence_max_numeric_difference=max(abs(delta(:,1:5)),[],1);
    report.sequence_double_difference_by_column=max(abs(double_delta(:,1:5)),[],1);
    report.numeric_reference='独立MATLAB single递推；double累计只作数值精度对照';
    report.sequence_discrete_flags_match_single=true;
    report.flag_reference='布尔标志按独立single公式的实际舍入检查';

    %% 六个真实闭环，MATLAB对象和控制器独立推进
    [status,log]=system(sprintf('"%s" simulate "%s"',runner,native));
    assert(status==0,'SMC:Velocity:Closed','真实速度闭环失败：%s',log);
    case_names={'恒定目标速度','运动目标速度','反向输入增益','输出受限','暂停复位与反转重启','持续外力'};
    cases=repmat(struct(),1,6); dt=.001;
    for scenario=1:6
        source=fullfile(native,sprintf('velocity%02d.csv',scenario)); cpp_loop=readmatrix(source);
        [reference,terminal_reference]=velocity_closed_reference(scenario);
        assert(isequal(size(cpp_loop),[8000,17]) && all(isfinite(cpp_loop),'all'));
        difference=cpp_loop-reference;
        % 状态/事件要求精确；限幅状态还以各自请求和输出的一致性检查。
        failed=abs(difference(:,1:11))>numeric_abs+numeric_rel*abs(reference(:,1:11));
        failed=[failed,cpp_loop(:,13:17)~=reference(:,13:17)];
        first=find(any(failed,2),1);
        if ~isempty(first)
            report.first_closed_exceeding_case=scenario; report.first_closed_exceeding_row=first;
            smc_teaching_report(report_path,report); error('SMC:Velocity:ClosedAlignment','案例%d第%d行闭环超差。',scenario,first);
        end
        b=3; bound=4;
        if scenario==3, b=-3; end
        if scenario==4, bound=.25; end
        active=cpp_loop(:,14)==1;
        assert(all(abs(cpp_loop(:,11))<=bound));
        assert(all(cpp_loop(active,12)==(cpp_loop(active,9)~=cpp_loop(active,10))));
        % 在相同的真实float测量上独立回放single，精确核对输出限幅标志。
        replay_integral=single(0);
        for row=1:8000
            if cpp_loop(row,15), replay_integral=single(0); end
            if active(row)
                [replay,replay_integral]=velocity_formula(single([b,4,6,2,.25]),single([-bound,bound]), ...
                    single([cpp_loop(row,2:3),cpp_loop(row,5),dt]),replay_integral);
                assert(isequal(double(replay(6)),cpp_loop(row,12)), ...
                    'SMC:Velocity:Flags','案例%d第%d行限幅标志不符。',scenario,row);
            end
        end
        acceleration=b*cpp_loop(:,11)+cpp_loop(:,17);
        next_position=cpp_loop(1:end-1,4)+cpp_loop(1:end-1,5)*dt+.5*acceleration(1:end-1)*dt^2;
        next_rate=cpp_loop(1:end-1,5)+acceleration(1:end-1)*dt;
        reconstruction=cpp_loop(2:end,4:5)-[next_position,next_rate];
        assert(max(abs(reconstruction),[],'all')<1e-12,'SMC:Velocity:Plant','对象没有使用真实执行电流。');
        terminal=[cpp_loop(end,4)+cpp_loop(end,5)*dt+.5*acceleration(end)*dt^2,cpp_loop(end,5)+acceleration(end)*dt];
        assert(all(abs(terminal-terminal_reference)<=numeric_abs+numeric_rel*abs(terminal_reference)));
        true_error=cpp_loop(:,5)-cpp_loop(:,2);
        final_limit=2e-5;
        % 运动目标每个区间只提供起点加速度，额外存在离散跟踪近似误差。
        if scenario==2, final_limit=2e-4; end
        % 强限幅案例累计继续增长，本讲不对8秒末值作收敛承诺。
        if scenario==4, final_limit=[]; end
        if ~isempty(final_limit)
            assert(abs(true_error(end))<final_limit,'SMC:Velocity:Final','案例%d末行速度误差超出预设检查值。',scenario);
        end
        if scenario==4, assert(any(cpp_loop(:,12)) && max(abs(cpp_loop(:,7)))>.25); end
        if scenario==5
            paused=1001:1500;
            assert(all(cpp_loop(paused,11)==0) && all(cpp_loop(paused,7)==0) && ...
                all(cpp_loop(paused,16)==0) && all(cpp_loop(paused,10)==cpp_loop(1000,10)) && ...
                cpp_loop(1001,15)==1 && abs(cpp_loop(1501,4))>1 && abs(cpp_loop(1501,5))>1);
        end
        if scenario==6
            % 恒定外力可由非零累计值对应的电流平衡；速度误差趋近零。
            assert(abs(cpp_loop(end,11)+.4/3)<2e-5 && abs(cpp_loop(end,7)-.4/(4*(6+2/.25)))<2e-5);
        end
        cases(scenario).name=case_names{scenario}; cases(scenario).rows=8000;
        cases(scenario).calc_count=nnz(active); cases(scenario).last_time_s=cpp_loop(end,1);
        cases(scenario).max_numeric_difference_by_column=max(abs(difference(:,1:11)),[],1);
        cases(scenario).max_current_difference_a=max(abs(difference(:,11)));
        cases(scenario).max_reconstruction_difference=max(abs(reconstruction),[],'all');
        cases(scenario).last_speed_error_rad_s=true_error(end);
        cases(scenario).final_speed_error_limit_rad_s=final_limit;
        cases(scenario).output_limited_count=nnz(cpp_loop(:,12));
        cases(scenario).peak_error_integral=max(abs(cpp_loop(:,7)));
        cases(scenario).terminal_at_8s=terminal; cases(scenario).reference_terminal_at_8s=terminal_reference;
        copyfile(source,fullfile(out,sprintf('案例%02d_真实C++.csv',scenario)));
        writematrix(reference,fullfile(out,sprintf('案例%02d_独立MATLAB.csv',scenario)));
        writematrix(difference,fullfile(out,sprintf('案例%02d_差值.csv',scenario)));
        smc_plot_velocity(cpp_loop,case_names{scenario},out,scenario);
    end
    report.library_hashes=host.hashes; report.case_count=6; report.cases=cases;
    report.closed_record_count=48000; report.closed_calc_count=sum([cases.calc_count]);
    report.state_transition_checks=6*7999; report.closed_absolute_tolerance=numeric_abs;
    report.closed_relative_tolerance=numeric_rel; report.reconstruction_tolerance=1e-12;
    report.single_replay_reads_cpp_measurements=true; % 仅用于位级状态标志，不是独立闭环参考。
    report.passed=true; smc_teaching_report(report_path,report);
    save(fullfile(out,'序列参数与数据.mat'),'points','expected','single_expected','delta','double_delta','allowed','report');
    fprintf('速度库验证通过：4102次序列、6组各8000行闭环，真实Calc共%d次。\n',report.closed_calc_count);
end

function [details,integral]=velocity_formula(config,bounds,input,previous)
    e=input(3)-input(1);
    integral=previous+e*input(4);
    s=e+config(2)*integral;
    request=(input(2)-config(2)*e-config(3)*s-config(4)*max(-1,min(1,s/config(5))))/config(1);
    output=max(bounds(1),min(bounds(2),request));
    details=[e,integral,s,request,output,request~=output];
end

function [data,terminal]=velocity_closed_reference(scenario)
    dt=.001; position=0; rate=0; integral=single(0); caller=0; details=zeros(1,6); has=false;
    b=3; bound=4;
    if scenario==3, b=-3; end
    if scenario==4, bound=.25; end
    data=zeros(8000,17);
    for index=0:7999
        t=index*dt; target=2; target_acc=0;
        if scenario==2
            target=.8*sin(.8*t)+.5*cos(.45*t);
            target_acc=.64*cos(.8*t)-.225*sin(.45*t);
        end
        if scenario==5 && index>=1500, target=-1; end
        enabled=~(scenario==5 && index>=1000 && index<1500);
        reset=scenario==5 && index==1000;
        if reset, integral=single(0); details=zeros(1,6); has=false; end
        if enabled
            input=single([target,target_acc,rate,dt]);
            [details,integral]=velocity_formula(single([b,4,6,2,.25]),single([-bound,bound]),input,integral);
            details=double(details); % 对象仍独立使用double推进，不把整行观测降为single。
            caller=details(5); has=true;
        end
        applied=0; if enabled, applied=caller; end
        disturbance=0; if scenario==6 && index>=2000, disturbance=.4; end
        data(index+1,:)=[t,target,target_acc,position,rate,details(1:4),caller,applied, ...
            details(6),enabled,enabled,reset,has,disturbance];
        acceleration=b*applied+disturbance;
        position=position+rate*dt+.5*acceleration*dt^2; rate=rate+acceleration*dt;
    end
    terminal=[position,rate];
end
