%% 第21讲：同一输入序列的逐列比较，首个超差位置可定位
% start.m: number=21。MATLAB、pwsh、g++，无额外工具箱。
% 不是对象运动实验；每个block内持续调用同一个现有生产库实例。
lesson_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(lesson_root,'matlab','内部函数'));
lesson_out=fullfile(lesson_root,'build','教学','第21讲_MATLAB与C++逐次核对');
if ~isfolder(lesson_out), mkdir(lesson_out); end
report_path=fullfile(lesson_out,'运行报告.json');
lesson_report=struct('passed',false,'lesson',21,'matlab',version, ...
    'learner_understanding_confirmed',false,'firmware_linked',false,'hardware_tested',false);
smc_teaching_report(report_path,lesson_report);
absolute_tolerance=1e-5; relative_tolerance=3e-6; % 运行前固定，与既有库公式核对一致。

%% 16个明确点，包含±phi内外最邻近的float输入；再加入四组各1024点
down=double(single(1)-eps(single(1))/2); up=double(single(1)+eps(single(1)));
explicit_inputs=[0,0,0,0,0;0,0,0,.5,0;0,0,0,1,0;0,0,0,-.5,0; ...
    3,-4,6,3,-4;0,0,0,0,1;0,0,1,1,-2;0,0,0,down,0;0,0,0,up,0; ...
    0,0,0,-down,0;0,0,0,-1,0;0,0,0,-up,0;0,0,-6,0,0; ...
    0,0,0,1,-2;1,2,3,1,2;0,0,6,0,0];
points=[zeros(16,1),repmat([2,2,3,4,2,-3,3],16,1),explicit_inputs];
index=(0:1023)';
inputs=[1.2*sin(.013*index),.7*cos(.017*index),.4*sin(.031*index), ...
    .8*cos(.019*index),.6*sin(.023*index)];
configs=[2,2,3,4,2;-2,2,3,4,2;3,4,6,2,.25;-3,4,6,2,.25];
for block=1:4
    points=[points;block*ones(1024,1),repmat([configs(block,:),-1.5,2.25],1024,1),inputs]; %#ok<AGROW>
end
points(:,2:13)=double(single(points(:,2:13))); % 两边收到相同的float可表示输入。
point_names={'block','b','c','K','epsilon','phi','minimum','maximum', ...
    'target','target_rate','target_acceleration','measurement','measurement_rate'};
input_csv=fullfile(lesson_out,'共同输入序列.csv');
writetable(array2table(points,'VariableNames',point_names),input_csv);
[cpp,host]=smc_teaching_host(lesson_root,lesson_out,21,input_csv);
assert(isequal(size(cpp),[4112,9]) && isequal(cpp(:,1),(1:4112)') && ...
    isequal(cpp(:,2),points(:,1)) && all(cpp(:,3)==1),'SMC:Lesson21:Rows','序号、分组或成功标志不符。');

%% 独立double公式，不读取C++计算结果来生成预期
e=points(:,12)-points(:,9); edot=points(:,13)-points(:,10);
s=edot+points(:,3).*e;
request=(points(:,11)-points(:,3).*edot-points(:,4).*s ...
    -points(:,5).*max(-1,min(1,s./points(:,6))))./points(:,2);
output=max(points(:,7),min(points(:,8),request));
expected=[e,edot,s,request,output,double(request~=output)];
delta=cpp(:,4:9)-expected;
allowed=absolute_tolerance+relative_tolerance*abs(expected(:,1:5));
failed=[abs(delta(:,1:5))>allowed,delta(:,6)~=0];
first_bad_row=find(any(failed,2),1);
lesson_report.first_exceeding_row=first_bad_row;
result_names={'error_rad','error_rate_rad_s','s_rad_s','request_a','output_a','limited'};
if ~isempty(first_bad_row)
    first_bad_column=find(failed(first_bad_row,:),1);
    lesson_report.first_exceeding_field=result_names{first_bad_column};
    smc_teaching_report(report_path,lesson_report);
    error('SMC:Lesson21:Alignment','首个超差在第%d行，字段%s。',first_bad_row,result_names{first_bad_column});
end
% 预先给定的六个精确小点，对错误方向、少项或错误限幅保持敏感。
assert(isequal(cpp([2,3,4,5,6,7],8),[-2.5;-3;2.5;3;-3;2.5]) && ...
    cpp(13,7)==-3 && cpp(13,9)==0 && cpp(16,7)==3 && cpp(16,9)==0, ...
    'SMC:Lesson21:Hand','明确点的手算电流或等于边界的标志不符。');
assert(any(cpp(:,9)==1) && any(cpp(:,9)==0),'SMC:Lesson21:Coverage','需要同时含受限和未受限计算。');
ratio=max(abs(delta(:,1:5))./allowed,[],2);
first_numeric=find(any(delta(:,1:5)~=0,2),1);
fig=figure('Visible',lesson_visibility(),'Color','w','Position',[80,70,1100,700]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(cpp(:,1),delta(:,4:5),'LineWidth',1); grid on;
xlabel('输入序号'); ylabel('C++减MATLAB / A'); title('请求与输出的数值差，未把近似相等写成逐位相同');
legend('请求电流差','输出电流差','Location','best');
nexttile; plot(cpp(:,1),ratio,'LineWidth',1); yline(1,'r--'); ylim([0,1.1]); grid on;
xlabel('输入序号'); ylabel('本行最大（绝对差÷允许差）'); title('五个数值字段都需不超过1；限幅标志要求完全一致');
sgtitle('第21讲：4112次真实C++与独立MATLAB逐次核对');
exportgraphics(fig,fullfile(lesson_out,'MATLAB与C++逐次核对.png'),'Resolution',130);
savefig(fig,fullfile(lesson_out,'MATLAB与C++逐次核对.fig'));
if ~usejava('desktop'), close(fig); end
writetable(array2table(expected,'VariableNames',result_names),fullfile(lesson_out,'独立MATLAB结果.csv'));
writetable(array2table(delta,'VariableNames',result_names),fullfile(lesson_out,'逐列差值.csv'));
writetable(array2table(allowed,'VariableNames',result_names(1:5)),fullfile(lesson_out,'逐列允许差.csv'));
save(fullfile(lesson_out,'实验参数与数据.mat'),'points','configs','cpp','expected','delta','allowed', ...
    'absolute_tolerance','relative_tolerance');
lesson_report.compiler=host.compiler_version; lesson_report.source_hashes=host.hashes;
lesson_report.common_input_sha256=host.input_csv_sha256;
lesson_report.call_count=4112; lesson_report.block_count=5;
lesson_report.result_column_order=result_names;
lesson_report.absolute_tolerance=absolute_tolerance; lesson_report.relative_tolerance=relative_tolerance;
lesson_report.max_absolute_difference_by_column=max(abs(delta),[],1);
lesson_report.max_output_difference_a=max(abs(delta(:,5)));
lesson_report.max_normalized_difference=max(ratio);
lesson_report.first_nonzero_numeric_difference_row=first_numeric;
lesson_report.limited_flags_exact=true; lesson_report.production_sources_modified=false;
lesson_report.plant_state_advanced=false;
lesson_report.passed=true; smc_teaching_report(report_path,lesson_report);
fprintf('第21讲通过：4112次计算，输出最大差%.3g A，最大允许差占比%.3g。\n', ...
    lesson_report.max_output_difference_a,lesson_report.max_normalized_difference);

function visibility=lesson_visibility()
    visibility='off'; if usejava('desktop'), visibility='on'; end
end
