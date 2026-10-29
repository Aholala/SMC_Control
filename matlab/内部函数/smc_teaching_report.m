function smc_teaching_report(path,value)
% 第20～22讲共用的文件输出，不包含任何控制算法。
    fid=fopen(path,'w','n','UTF-8');
    assert(fid~=-1,'SMC:Teaching:File','无法写入报告。');
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
end
