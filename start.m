%% 滑模控制入口：教学、应用、库验证分别运行
% 当前已建立第 1～9 讲；number 表示讲次或应用目录编号。
% 库验证仍可直接运行 matlab/验证/run_checks.m。
mode = '教学';
number = 1;
smc_root = fileparts(mfilename('fullpath'));
switch mode
    case '教学'
        entries = dir(fullfile(smc_root,'matlab','教学',sprintf('第%02d讲_*',number)));
        assert(numel(entries)==1,'SMC:Lesson','当前已建立第 1～9 讲，请设置 number=1～9。');
        entry = fullfile(entries.folder,entries.name,'run_lesson.m');
    case '应用'
        entries = dir(fullfile(smc_root,'matlab','应用方案',sprintf('%02d_*',number)));
        assert(numel(entries)==1,'SMC:Application','当前应用目录编号为 1。');
        entry = fullfile(entries.folder,entries.name,'run_case.m');
    case '验证'
        entry = fullfile(smc_root,'matlab','验证','run_checks.m');
    otherwise
        error('SMC:Mode','mode 请选择：教学、应用、验证。');
end
fprintf('当前用途：%s；入口：%s\n',mode,entry);
run(entry);
