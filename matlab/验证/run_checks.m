%% 普通位置滑模库：MATLAB 独立公式、真实 C++ 与闭环对象核对
% 入口：运行本文件或根目录 start.m；MATLAB，无 Simulink/MEX 依赖。
% 参数全部为教学假设：角度 rad，时间 s，输入 A。
% 需要可用的 PowerShell、g++、CMake、Ninja；不修改三个参考项目。
smc_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(smc_root,'matlab','内部函数'));
smc_out = fullfile(smc_root,'build','验证');
smc_raw = fullfile(smc_out,'原始数据');
if ~isfolder(smc_raw), mkdir(smc_raw); end
smc_report = struct('passed',false,'matlab',version,'firmware_linked',false,'hardware_tested',false);
smc_write_json(fullfile(smc_out,'验证报告.json'),smc_report);
smc_host_script = fullfile(smc_root,'tests','verify_host.ps1');
[smc_shell_status,smc_shell_paths] = system('where pwsh');
assert(smc_shell_status==0,'SMC:Shell','请将 PowerShell 7 的 pwsh 加入 PATH。');
smc_shell = strtrim(strtok(smc_shell_paths,newline));
[smc_status,smc_log] = system(sprintf('"%s" -NoProfile -ExecutionPolicy Bypass -File "%s"',smc_shell,smc_host_script));
smc_write_text(fullfile(smc_out,'主机构建与测试.log'),smc_log);
assert(smc_status==0,'SMC:Host','主机构建或测试失败，查看日志。');
smc_runner = fullfile(smc_root,'build','host','verification_runner.exe');

%% 第一层：可手算的基本公式
% b=2,c=2,k=3,epsilon=4,phi=2；e=.5,e_dot=0 -> s=1,u=-2.5。
[smc_hand,smc_hand_state] = smc_formula([2,2,3,4,2],[-100,100],[0,0,0,.5,0]);
assert(smc_hand==-2.5 && smc_hand_state(3)==1,'SMC:Hand','手算点不一致。');
[smc_feed,~] = smc_formula([2,2,3,4,2],[-100,100],[3,-4,6,3,-4]);
assert(smc_feed==3,'SMC:Feedforward','相同位置与速度下，应只剩目标加速度对应输入。');

%% 第二层：独立 double 公式与 C++ float 单次计算
smc_n = 4096;
smc_index = (0:smc_n-1)';
smc_config = [3*ones(smc_n,1),4*ones(smc_n,1),6*ones(smc_n,1),2*ones(smc_n,1),.25*ones(smc_n,1)];
smc_config(2:2:end,1) = -3;
smc_config(3:5:end,3) = 0; % 只保留切换趋近项。
smc_config(4:5:end,4) = 0; % 只保留线性趋近项。
smc_bounds = [-1.5*ones(smc_n,1),2.25*ones(smc_n,1)];
smc_input = [1.2*sin(.013*smc_index),.7*cos(.017*smc_index),.4*sin(.031*smc_index), ...
    .8*cos(.019*smc_index),.6*sin(.023*smc_index)];
% 增加零点、边界两侧、非零跟踪加速度等明确点。
smc_extra = [2,2,3,4,2,-100,100, 0,0,0,0,0; ...
    2,2,3,4,2,-100,100, 0,0,0,1,0; ...
    2,2,3,4,2,-100,100, 0,0,0,-1,0; ...
    2,2,3,4,2,-100,100, 0,0,0,.999999,0; ...
    2,2,3,4,2,-100,100, 0,0,0,1.000001,0; ...
    2,2,3,4,2,-100,100, 3,-4,6,3,-4];
smc_points = double(single([[smc_config,smc_bounds,smc_input];smc_extra]));
smc_names = {'input_gain','surface_gain','reaching_gain','switching_gain','boundary_width', ...
    'output_min','output_max','target','target_rate','target_acceleration','measurement','measurement_rate'};
smc_input_csv = fullfile(smc_raw,'points_input.csv');
smc_output_csv = fullfile(smc_raw,'points_cpp.csv');
writetable(array2table(smc_points,'VariableNames',smc_names),smc_input_csv);
[smc_status,smc_log] = system(sprintf('"%s" points "%s" "%s"',smc_runner,smc_input_csv,smc_output_csv));
assert(smc_status==0,'SMC:Points','C++ 单次计算失败：%s',smc_log);
smc_cpp = readmatrix(smc_output_csv);
smc_expected = zeros(size(smc_points,1),5);
for smc_i=1:size(smc_points,1)
    [~,smc_expected(smc_i,:)] = smc_formula(smc_points(smc_i,1:5),smc_points(smc_i,6:7),smc_points(smc_i,8:12));
end
assert(all(smc_cpp(:,1)==1),'SMC:Points','C++ 返回失败。');
% double 独立参考与 float 实现：绝对 1e-5 + 相对 3e-6。
smc_delta = abs(smc_cpp(:,2:6)-smc_expected);
assert(all(smc_delta <= 1e-5+3e-6*abs(smc_expected),'all'),'SMC:Alignment','单次公式核对超过容差。');
smc_expected_limited = smc_expected(:,4)~=smc_expected(:,5);
assert(all(smc_cpp(:,7)==smc_expected_limited),'SMC:Clipping','限幅标志不一致。');
smc_report.point_count = size(smc_points,1);
smc_report.point_max_absolute_error = max(smc_delta,[],1);

%% 第三层：真实 C++ 控制器驱动假设对象，再与 MATLAB 独立闭环比较
[smc_status,smc_log] = system(sprintf('"%s" simulate "%s"',smc_runner,smc_raw));
assert(smc_status==0,'SMC:Simulation','C++ 闭环失败：%s',smc_log);
smc_write_text(fullfile(smc_out,'C++闭环运行.log'),smc_log);
smc_case_names = {'静止目标','运动目标','持续外力','反向输入增益','测量噪声与输出限制'};
smc_cases = repmat(struct(),1,5);
for smc_case=1:5
    smc_data = readmatrix(fullfile(smc_raw,sprintf('case%02d.csv',smc_case)));
    smc_reference = smc_closed_reference(smc_case);
    assert(isequal(size(smc_data),size(smc_reference)),'SMC:Size','闭环数据行列不一致。');
    assert(all(isfinite(smc_data),'all'),'SMC:Finite','C++ 闭环出现非有限值。');
    smc_diff = abs(smc_data-smc_reference);
    % 闭环含连续 8000 次计算及独立对象反馈，允许累计数值差异。
    assert(all(smc_diff<=2e-5+2e-5*abs(smc_reference),'all'),'SMC:ClosedAlignment','闭环逐次核对超过容差。');
    smc_bound = 4;
    if smc_case==5, smc_bound=1; end
    assert(all(abs(smc_data(:,13))<=smc_bound),'SMC:Limit','输出超出明确范围。');
    smc_true_error = smc_data(:,5)-smc_data(:,2);
    smc_final_error = abs(smc_true_error(end));
    if smc_case==3
        assert(smc_final_error<.009,'SMC:Disturbance','持续外力下误差超过该假设实验界限。');
        smc_equilibrium = .4/(4*(6+2/.25));
        assert(abs(smc_true_error(end)-smc_equilibrium)<3e-6,'SMC:Equilibrium','持续外力下的末值不符合本模型理论平衡误差。');
    elseif smc_case==5
        assert(smc_final_error<.005,'SMC:Noise','噪声实验末值误差超过假设界限。');
    else
        assert(smc_final_error<2e-5,'SMC:Tracking','无扰动实验末值误差超限。');
    end
    smc_cases(smc_case).name = smc_case_names{smc_case};
    smc_cases(smc_case).steps = size(smc_data,1);
    smc_cases(smc_case).max_alignment_error = max(smc_diff,[],'all');
    smc_cases(smc_case).final_position_error = smc_final_error;
    smc_cases(smc_case).peak_output = max(abs(smc_data(:,13)));
    smc_cases(smc_case).limited_steps = nnz(smc_data(:,14));
    smc_plot_position(smc_data,smc_case_names{smc_case},smc_out,smc_case);
end
smc_report.cases = smc_cases;
smc_report.assumptions = '教学假设；瞬时执行输入；double 运动对象；dt=0.001s；非实测电机参数';
smc_report.library_hashes = jsondecode(fileread(fullfile(smc_root,'build','host','host_verification.json'))).hashes;
% 扩展分支独立验证；使用本次已经完成的十三项主机构建。
smc_report.velocity = smc_verify_velocity(smc_root,false);
smc_report.extensions = smc_verify_extensions(smc_root);
smc_report.passed = true;
smc_write_json(fullfile(smc_out,'验证报告.json'),smc_report);
save(fullfile(smc_out,'验证数据.mat'),'smc_points','smc_expected','smc_delta','smc_report');
fprintf('SMC MATLAB 验证通过：位置%d个公式点、5组闭环；速度4102次序列、6组闭环。\n',smc_report.point_count);
fprintf('报告目录：%s\n',smc_out);

function [command,details] = smc_formula(config,bounds,input)
% 按规格独立 double 计算，不调用 C++，不用 C++ 输出充当公式参考。
    e = input(4)-input(1);
    rate_error = input(5)-input(2);
    s = rate_error+config(2)*e;
    request = (input(3)-config(2)*rate_error-config(3)*s ...
        -config(4)*max(-1,min(1,s/config(5))))/config(1);
    command = max(bounds(1),min(bounds(2),request));
    details = [e,rate_error,s,request,command];
end

function data = smc_closed_reference(scenario)
% 独立 MATLAB 对象与控制计算；输入量化为与 C++ 接口相同的 single。
    dt=.001; count=8000; position=-.2; rate=0;
    gain=3; bound=4;
    if scenario==4, gain=-3; end
    if scenario==5, bound=1; end
    config=[gain,4,6,2,.25];
    data=zeros(count,15);
    for index=0:count-1
        t=index*dt; target=.5; target_rate=0; target_acc=0;
        if scenario==2 || scenario==5
            target=.25*sin(.8*t)+.15*cos(.45*t);
            target_rate=.2*cos(.8*t)-.0675*sin(.45*t);
            target_acc=-.16*sin(.8*t)-.030375*cos(.45*t);
        end
        disturbance=0;
        if scenario==3 && index>=2000, disturbance=.4; end
        measured=position; measured_rate=rate;
        if scenario==5
            measured=measured+.001*sin(71*t);
            measured_rate=measured_rate+.01*cos(53*t);
        end
        input=double(single([target,target_rate,target_acc,measured,measured_rate]));
        [command,details]=smc_formula(config,[-bound,bound],input);
        data(index+1,:)=[t,target,target_rate,target_acc,position,rate,measured,measured_rate, ...
            details(1:4),command,details(4)~=command,disturbance];
        acceleration=gain*command+disturbance;
        position=position+rate*dt+.5*acceleration*dt^2;
        rate=rate+acceleration*dt;
    end
end

function smc_write_text(path,value)
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:File','无法写入日志。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',value);
end

function smc_write_json(path,value)
    smc_write_text(path,jsonencode(value,'PrettyPrint',true));
end
