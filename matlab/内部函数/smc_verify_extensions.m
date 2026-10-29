function report=smc_verify_extensions(root)
    points=[smc_extension_inputs(24);smc_extension_inputs(25);smc_extension_inputs(26);smc_extension_inputs(27)];
    out=fullfile(root,'build','验证','位置扩展');
    report=smc_extension_experiment(root,out,points,1:8);
    smc_teaching_report(fullfile(out,'验证报告.json'),report);
    fprintf('位置扩展验证通过：%d个公式点，8组共%d次真实Calc。\n',report.point_count,report.calc_count);
end
