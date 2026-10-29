function [data,report]=smc_teaching_host(root,out,lesson,input_csv)
% 只负责构建、执行和读取真实 C++ 数据；独立公式在各讲入口中。
    script=fullfile(root,'tests','verify_teaching_20_22.ps1');
    command=sprintf('pwsh -NoProfile -File "%s" -Lesson %d',script,lesson);
    if nargin==4, command=sprintf('%s -InputCsv "%s"',command,input_csv); end
    [status,log]=system(command);
    fid=fopen(fullfile(out,'主机运行.log'),'w','n','UTF-8');
    assert(fid~=-1,'SMC:Teaching:Log','无法写入主机日志。');
    fprintf(fid,'%s',log); fclose(fid);
    assert(status==0,'SMC:Teaching:Host','第%d讲主机失败：%s',lesson,log);
    report=jsondecode(fileread(fullfile(out,'主机运行报告.json')));
    assert(report.passed && report.lesson==lesson && report.production_cpp_executed && ...
        ~report.production_sources_modified,'SMC:Teaching:HostReport','主机报告不符合本讲要求。');
    data=readmatrix(fullfile(out,'真实C++输出.csv'));
    assert(all(isfinite(data),'all'),'SMC:Teaching:Finite','真实输出存在无效数值。');
end
