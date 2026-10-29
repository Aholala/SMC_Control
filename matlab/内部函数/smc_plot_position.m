function smc_plot_position(data,name,output_dir,index)
% 仅为实验画图，不属于生产算法，也不作为独立运行入口。
    f=figure('Visible','off','Color','w','Position',[80,80,1100,780]);
    cleanup=onCleanup(@()close(f)); %#ok<NASGU>
    tiledlayout(2,2);
    nexttile; plot(data(:,1),data(:,2),'--',data(:,1),data(:,5));
    xlabel('时间 / s'); ylabel('角度 / rad'); title('目标与真实角度'); legend('目标','真实角度'); grid on;
    nexttile; plot(data(:,1),data(:,5)-data(:,2));
    xlabel('时间 / s'); ylabel('真实误差 / rad'); title('真实位置误差'); grid on;
    nexttile; plot(data(:,1),data(:,12),'--',data(:,1),data(:,13));
    xlabel('时间 / s'); ylabel('控制输入 / A'); title('请求与受限输出'); legend('请求','受限输出'); grid on;
    nexttile; plot(data(:,1),data(:,11));
    xlabel('时间 / s'); ylabel('滑模变量 / (rad/s)'); title('滑模变量'); grid on;
    sgtitle(['教学假设实验：',name,'（不代表实机）']);
    base=fullfile(output_dir,sprintf('%02d_%s',index,name));
    exportgraphics(f,[base,'.png'],'Resolution',130);
    savefig(f,[base,'.fig']);
end
