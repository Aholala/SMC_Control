%% 第20讲：两个对象的初始化、失败保留与复位
% start.m: mode='教学', number=20。MATLAB、pwsh、g++，无额外工具箱。
% 参数沿用第19讲；对象B的 b=-2，范围[-1,2] A，均为教学假设。
lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(lesson_root,'matlab','内部函数'));
lesson_out=fullfile(lesson_root,'build','教学','第20讲_初始化失败与多个实例');
if ~isfolder(lesson_out), mkdir(lesson_out); end
report_path=fullfile(lesson_out,'运行报告.json');
lesson_report=struct('passed',false,'lesson',20,'matlab',version, ...
    'learner_understanding_confirmed',false,'firmware_linked',false,'hardware_tested',false);
smc_teaching_report(report_path,lesson_report);
[cpp,host]=smc_teaching_host(lesson_root,lesson_out,20);
assert(isequal(size(cpp),[29,37]),'SMC:Lesson20:Size','预期29个操作和两个完整状态。');

%% 独立写出的操作顺序与返回预期，不从 C++ 输出生成答案
events=[1,2,1;1,3,0;1,4,1;1,5,1;1,1,0;1,1,1;2,1,2; ...
    1,2,1;2,2,1;1,2,3;2,2,6;1,2,4;1,2,5;1,4,0;1,5,0;1,1,0; ...
    1,3,0;2,2,1;1,2,1;1,4,2;1,2,1;1,5,1;1,2,1;1,5,2;1,2,2; ...
    2,3,0;1,2,7;1,1,1;1,2,1];
expected_success=[0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1]';
assert(isequal(cpp(:,1:5),[(1:29)',events,expected_success]), ...
    'SMC:Lesson20:Schedule','操作顺序或返回值与预设不符。');
% 每对象16列：initialized,has,command,b,c,K,epsilon,phi,min,max,e,edot,s,request,output,limited。
states=zeros(2,16); states(:,3)=[17;23];
expected=zeros(29,37);
for step=1:29
    id=events(step,1); operation=events(step,2); variant=events(step,3);
    previous=states;
    if expected_success(step)
        if operation==1
            bounds=[-3,3]; if variant==2, bounds=[-1,2]; end
            states(id,[1,4:10])=[1,lesson_config(variant),bounds];
            states(id,[2,11:16])=0;
        elseif operation==2
            input=zeros(1,5);
            if variant==1, input(4)=.5; end
            if variant==2, input(3)=6; end
            if variant==7, input=[0,0,1,1,-2]; end
            config=states(id,4:8);
            e=input(4)-input(1); edot=input(5)-input(2); s=edot+config(2)*e;
            request=(input(3)-config(2)*edot-config(3)*s ...
                -config(4)*max(-1,min(1,s/config(5))))/config(1);
            output=max(states(id,9),min(states(id,10),request));
            states(id,2:3)=[1,output];
            states(id,11:16)=[e,edot,s,request,output,request~=output];
        elseif operation==3
            states(id,[2,11:16])=0; % 不改调用方command，不改配置。
        elseif operation==4
            states(id,4:8)=lesson_config(variant); states(id,[2,11:16])=0;
        elseif operation==5
            bounds=[-1,1]; if variant==2, bounds=[2,2]; end
            states(id,9:10)=bounds; states(id,[2,11:16])=0;
        end
    end
    expected(step,:)=[step,events(step,:),expected_success(step),states(1,:),states(2,:)];
    other=3-id;
    columns=5+(other-1)*16+(1:16);
    assert(isequal(cpp(step,columns),previous(other,:)), ...
        'SMC:Lesson20:Independence','第%d步影响了另一个对象。',step);
    if ~expected_success(step)
        assert(isequal(cpp(step,6:37),[previous(1,:),previous(2,:)]), ...
            'SMC:Lesson20:FailureHold','第%d步失败却改变了对象或外部变量。',step);
    end
end
delta=cpp-expected;
assert(max(abs(delta),[],'all')<1e-6,'SMC:Lesson20:State','完整状态与独立预期不符。');
assert(cpp(17,7)==0 && cpp(17,8)==-2.5 && cpp(17,20)==0 && ...
    cpp(18,24)==2 && cpp(25,19)==-3 && cpp(25,20)==2 && cpp(25,21)==1, ...
    'SMC:Lesson20:Key','复位、固定输出范围或实例独立的关键点不符。');

%% 图中17/23仅用于观察外部变量是否被保留，不是设备命令
fig=figure('Visible',lesson_visibility(),'Color','w','Position',[80,70,1100,680]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile; stairs(cpp(:,1),cpp(:,[8,24]),'LineWidth',1.5); grid on;
xlabel('操作序号'); ylabel('调用方变量 / A'); title('17/23是观察标记；失败和复位均保留外部变量');
legend('对象A的变量','对象B的变量','Location','northeast');
nexttile; stairs(cpp(:,1),cpp(:,[7,23]),'LineWidth',1.5); grid on; ylim([-.15,1.25]);
xlabel('操作序号'); ylabel('最近结果是否有效（0/1）'); title('A的复位不改变B；HasResult不代表本次调用成功');
legend('A.HasResult','B.HasResult','Location','southeast');
sgtitle('第20讲：两个对象的完整状态核对（未发送设备命令）');
exportgraphics(fig,fullfile(lesson_out,'初始化失败与多个实例.png'),'Resolution',130);
savefig(fig,fullfile(lesson_out,'初始化失败与多个实例.fig'));
if ~usejava('desktop'), close(fig); end
names=readtable(fullfile(lesson_out,'真实C++输出.csv')).Properties.VariableNames;
writetable(array2table(expected,'VariableNames',names),fullfile(lesson_out,'独立预期状态.csv'));
writetable(array2table(delta,'VariableNames',names),fullfile(lesson_out,'完整状态差值.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'events','expected_success','expected','cpp','delta');
lesson_report.compiler=host.compiler_version; lesson_report.source_hashes=host.hashes;
lesson_report.operation_count=29; lesson_report.rejected_operation_count=nnz(~expected_success);
lesson_report.calc_attempt_count=nnz(events(:,2)==2);
lesson_report.max_state_difference=max(abs(delta),[],'all');
lesson_report.independence_checks=29; lesson_report.production_sources_modified=false;
lesson_report.failed_operations_preserve_both_snapshots=true;
lesson_report.reset_does_not_modify_caller_command=true;
lesson_report.checks={'未初始化拒绝','无效配置和倒置范围','NaN和正负无穷输入', ...
    '有限输入相减溢出','失败保持完整状态和调用方输出','复位只清结果', ...
    '成功改参改范围和重新初始化清结果','固定范围不等于停机','两个实例交替调用'};
lesson_report.passed=true; smc_teaching_report(report_path,lesson_report);
fprintf('第20讲通过：29个操作、%d次拒绝、两个完整状态最大差%.3g。\n', ...
    lesson_report.rejected_operation_count,lesson_report.max_state_difference);

function config=lesson_config(variant)
    b=2; if variant==2, b=-2; end
    config=[b,2,3,4,2];
end
function visibility=lesson_visibility()
    visibility='off'; if usejava('desktop'), visibility='on'; end
end
