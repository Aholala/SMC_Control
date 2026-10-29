function smc_plot_velocity(data,name,out,index)
% 仅绘图；库计算、对象运动与实际通信分别处理。
    fig=figure('Visible','off','Color','w','Position',[50,50,1250,880]);
    cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
    tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
    nexttile; plot(data(:,1),data(:,2),'k--',data(:,1),data(:,5),'LineWidth',1.4); grid on;
    xlabel('时间 / s'); ylabel('角速度 / (rad/s)'); title('目标量是角速度'); legend('目标','实际','Location','best');
    nexttile; plot(data(:,1),data(:,4),'LineWidth',1.4); grid on;
    xlabel('时间 / s'); ylabel('对象角度 / rad'); title('保持非零速度时角度继续变化');
    nexttile; plot(data(:,1),data(:,5)-data(:,2),'LineWidth',1.3); grid on;
    xlabel('时间 / s'); ylabel('速度误差 / (rad/s)'); title('实际速度减目标速度');
    nexttile; plot(data(:,1),data(:,7),'LineWidth',1.3); grid on;
    xlabel('时间 / s'); ylabel('速度误差累计值 / rad'); title('按误差×时间直接累计，不加累计限幅');
    nexttile; request=data(:,9); request(data(:,16)==0)=NaN;
    plot(data(:,1),request,'--',data(:,1),data(:,10),':',data(:,1),data(:,11),'LineWidth',1.2); grid on;
    xlabel('时间 / s'); ylabel('电流 / A'); title('诊断无效期间不画请求；实际施加单独记录');
    legend('请求','调用方变量','实际施加','Location','best');
    nexttile;
    if index==5
        stairs(data(:,1),data(:,13),'LineWidth',1.3); hold on;
        stairs(data(:,1),data(:,16),'--','LineWidth',1.2); ylim([-.1,1.2]);
        ylabel('状态 / 0或1'); title('暂停清累计，保留物理角度和速度'); legend('启用','结果有效','Location','best');
    else
        plot(data(:,1),data(:,8),'LineWidth',1.3); ylabel('滑模变量 / (rad/s)'); title('s=速度误差+c×累计值');
    end
    xlabel('时间 / s'); grid on;
    sgtitle(['速度滑模：',name,'（教学对象，非实机）']);
    base=fullfile(out,sprintf('%02d_%s',index,name));
    exportgraphics(fig,[base,'.png'],'Resolution',130); savefig(fig,[base,'.fig']);
end
