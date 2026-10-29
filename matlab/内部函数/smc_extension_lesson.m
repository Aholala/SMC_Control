function report=smc_extension_lesson(root,lesson)
% 每讲独立运行所需案例，不重复维护另一份C++算法。
    titles={'位置误差累计与持续外力','混合幂次趋近规律','有限时间面内关系','零附近与分段切换'};
    course_title=titles{lesson-23}; out=fullfile(root,'build','教学',sprintf('第%02d讲_%s',lesson,course_title));
    if ~isfolder(out), mkdir(out); end
    report_path=fullfile(out,'运行报告.json');
    smc_teaching_report(report_path,struct('passed',false,'lesson',lesson,'learner_understanding_confirmed',false));
    sets={[1,2,3,4],[5,6],7,[7,8]}; scenarios=sets{lesson-23}; points=smc_extension_inputs(lesson);
    report=smc_extension_experiment(root,out,points,scenarios);
    cpp=readmatrix(fullfile(out,'真实C++公式点.csv'));
    if lesson==24
        hand=[.5,0,.25,1.25,-3.375,-3,1,0;.5,0,.5,1.5,-4,-3,1,0; ...
            -.5,0,.25,-.75,2.125,2.125,0,0;0,0,.25,.25,2.375,2.375,0,0; ...
            .5,0,.25,1.25,-3.375,-3,1,0;.5,0,.5,1.5,-4,-3,1,0; ...
            .5,1,.75,2.75,-7.375,-3,1,0;0,0,0,0,3,3,0,0];
        assert(isequal(cpp(1:8,4:11),hand),'SMC:Lesson24:Hand','八个连续手算点不符。');
        a=readmatrix(fullfile(out,'案例01_真实C++.csv')); b=readmatrix(fullfile(out,'案例02_真实C++.csv'));
        limited=readmatrix(fullfile(out,'案例03_真实C++.csv'));
        assert(abs(b(end,5)-b(end,2))<.2*abs(a(end,5)-a(end,2)));
        report.hand_point_count=8; report.baseline_last_error=a(end,5)-a(end,2);
        report.integral_last_error=b(end,5)-b(end,2); report.strong_limit_last_error=limited(end,5)-limited(end,2);
        fig=new_figure(); tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
        nexttile; plot(a(:,1),a(:,5)-a(:,2),b(:,1),b(:,5)-b(:,2),'LineWidth',1.3); grid on;
        xlabel('时间 / s'); ylabel('位置误差 / rad'); title('同一外力、对象、初值和输出范围'); legend('普通位置','位置累计','Location','best');
        nexttile; plot(b(:,1),b(:,9),'LineWidth',1.3); grid on; xlabel('时间 / s'); ylabel('累计 / (rad·s)'); title('速度与位置的累计单位不同');
        nexttile; plot(limited(:,1),limited(:,5)-limited(:,2),'LineWidth',1.3); grid on; xlabel('时间 / s'); ylabel('位置误差 / rad'); title('输出改为正负0.2A后，8s内未收敛');
        nexttile; plot(limited(:,1),limited(:,9),'LineWidth',1.3); grid on; xlabel('时间 / s'); ylabel('累计 / (rad·s)'); title('累计按公式增长，不额外截断或冻结');
        finish_figure(fig,out,'位置累计与持续外力');
    elseif lesson==25
        assert(max(abs(cpp(1:6,8:9)-[-2.5,-2.5;-10,-3;10,3;3,3;-.5,-.5;.5,.5]),[],'all')<1e-6);
        scalar_s=linspace(-4,4,1601)'; K=3; G=4; exponent=.5; phi=.25;
        q=max(-1,min(1,scalar_s/phi)); ordinary=-K*scalar_s-G*q;
        power=-K*scalar_s-G*abs(scalar_s).^exponent.*q;
        assert(all(scalar_s.*ordinary<=0) && all(scalar_s.*power<=0));
        assert((-3*4-4*sqrt(4))==-20 && (-3*.25-4*sqrt(.25))==-2.75);
        data_power=readmatrix(fullfile(out,'案例05_真实C++.csv')); baseline=readmatrix(fullfile(out,'案例06_真实C++.csv'));
        report.scalar_parameters=[K,G,exponent,phi]; report.scalar_points=numel(scalar_s);
        report.mixed_reaching_law_retained=true; report.smoothed_law_finite_time_claim=false;
        writematrix([scalar_s,ordinary,power],fullfile(out,'独立趋近变化率.csv'));
        fig=new_figure(); tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
        nexttile; plot(scalar_s,ordinary,scalar_s,power,'LineWidth',1.3); grid on; xlabel('s / (rad/s)'); ylabel('s变化率 / (rad/s²)'); title('保留线性项，再改变另一项'); legend('固定切换强度','混合幂次','Location','best');
        nexttile; plot(scalar_s,ordinary,scalar_s,power,'LineWidth',1.3); xlim([-.25,.25]); grid on; xlabel('s / (rad/s)'); ylabel('s变化率 / (rad/s²)'); title('这组数值下，小s时幂次项不一定更强');
        nexttile; plot(baseline(:,1),baseline(:,5)-baseline(:,2),data_power(:,1),data_power(:,5)-data_power(:,2),'LineWidth',1.3); grid on; xlabel('时间 / s'); ylabel('位置误差 / rad'); title('相同对象与限制下的完整闭环'); legend('普通','混合幂次','Location','best');
        nexttile; plot(baseline(:,1),baseline(:,10),data_power(:,1),data_power(:,10),'LineWidth',1.3); grid on; xlabel('时间 / s'); ylabel('s / (rad/s)'); title('不预设某一形式整体更好');
        finish_figure(fig,out,'混合幂次趋近规律');
    elseif lesson==26
        assert(max(abs(cpp(1:6,9)-[5;-5;-1;-6;-4.5;3]))<1e-6);
        t=(0:.001:1.5)'; beta=2; exponent=.5; initial=1; delta=.25; linear_gain=4;
        T=initial^(1-exponent)/(beta*(1-exponent));
        root=max(initial^(1-exponent)-beta*(1-exponent)*t,0);
        positive=root.^(1/(1-exponent)); negative=-positive;
        derivative=-beta*root.^(exponent/(1-exponent));
        relation=-beta*sqrt(positive);
        assert(max(abs(derivative-relation))<1e-12 && all(positive(t>=T)==0) && all(positive(t<T)>0));
        entering=(initial^(1-exponent)-delta^(1-exponent))/(beta*(1-exponent));
        hybrid=positive; after=t>=entering; hybrid(after)=delta*exp(-linear_gain*(t(after)-entering));
        linear=initial*exp(-linear_gain*t);
        assert(all(hybrid>0) && abs(T-1)<1e-12 && hybrid(t==T)>0);
        report.ideal_terminal_time_s=T; report.hybrid_manifold_error_at_T=hybrid(t==T);
        report.finite_time_statement='只对已在理想纯终端面上的连续关系成立；生产分段公式不承诺有限时间到零';
        writematrix([t,positive,negative,linear,hybrid,derivative],fullfile(out,'理想面内关系.csv'));
        fig=new_figure(); tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
        nexttile; plot(t,positive,t,negative,'LineWidth',1.4); xline(T,'k--'); grid on; xlabel('时间 / s'); ylabel('误差 / rad'); title('理想纯终端面内：正负初值都在T=1s到零'); legend('+1rad','-1rad','Location','best');
        nexttile; plot(t,positive,t,linear,t,hybrid,'LineWidth',1.4); xline(T,'k--'); grid on; xlabel('时间 / s'); ylabel('误差 / rad'); title('普通内区保留正残差，不继承纯终端结论'); legend('纯终端面内','普通面内','分段面内','Location','best');
        finish_figure(fig,out,'有限时间与分段面内关系');
    else
        lo=double(single(.25)-eps(single(.25))/2); hi=double(single(.25)+eps(single(.25)));
        lower=find(points(:,16)==lo & points(:,17)==1); equal=find(points(:,16)==.25 & points(:,17)==1);
        upper=find(points(:,16)==hi & points(:,17)==1);
        assert(cpp(lower,11)==0 && cpp(equal,11)==1 && cpp(upper,11)==1);
        assert(abs(cpp(equal,8)-cpp(lower,8)-1)<1e-5 && abs(cpp(equal,7)-cpp(lower,7))<1e-6);
        zero=points(:,16)==0;
        assert(all(isfinite(cpp(zero,:)),'all') && all(cpp(zero,11)==0) && ...
            abs(cpp(find(zero & points(:,17)==1,1),9)+4.5)<1e-6);
        magnitude=logspace(-30,0,241)'; raw_derivative=2*.5*magnitude.^(-.5);
        actual_derivative=raw_derivative; actual_derivative(magnitude<.25)=4;
        raw_zero_rest=0-2*.5*0^(-.5)*0; raw_zero_moving=0-2*.5*0^(-.5)*1;
        assert(~isfinite(raw_zero_rest) && ~isfinite(raw_zero_moving));
        a=readmatrix(fullfile(out,'案例07_真实C++.csv')); b=readmatrix(fullfile(out,'案例08_真实C++.csv'));
        assert(max(abs(a(:,5:6)-b(:,5:6)),[],'all')<1e-12 && max(abs(a(:,13)+b(:,13)))<1e-12);
        report.zero_input_count=nnz(zero); report.switch_request_jump_a=cpp(equal,8)-cpp(lower,8);
        report.zero_branch_is_linear=true; report.raw_zero_expression_is_undefined=true;
        report.matched_direction_check_passed=true;
        writematrix([magnitude,raw_derivative,actual_derivative],fullfile(out,'原式负幂与实际分支系数.csv'));
        writematrix([points([lower;equal;upper],16),cpp([lower;equal;upper],7:11)],fullfile(out,'阈值两侧实际结果.csv'));
        fig=new_figure(); tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
        nexttile; loglog(magnitude,raw_derivative,magnitude,actual_derivative,'LineWidth',1.4); grid on;
        xlabel('|e| / rad（按倍数分格）'); ylabel('乘速度误差的系数 / (1/s)'); title('先选内区分支，零处不计算负幂'); legend('原始负幂系数','实际分段系数','Location','best');
        nexttile; plot(1:3,cpp([lower;equal;upper],8),'o-','LineWidth',1.4); ylim([-7.5,-5.5]); grid on; xticks(1:3); xticklabels({'阈值下邻数','恰好阈值','阈值上邻数'});
        ylabel('请求电流 / A'); title('s接续不等于电流接续，本例跳变约1A');
        finish_figure(fig,out,'零附近与分段切换');
    end
    report.lesson=lesson; report.learner_understanding_confirmed=false;
    report.integral_clamp_added=false; report.production_finite_time_guarantee=false;
    report.passed=true; smc_teaching_report(report_path,report);
    fprintf('第%d讲通过：%d公式点，%d组闭环；讲义主题：%s。\n',lesson,report.point_count,numel(scenarios),course_title);
end
function fig=new_figure()
    fig=figure('Visible','off','Color','w','Position',[60,60,1150,760]);
end
function finish_figure(fig,out,name)
    sgtitle([name,'（声明条件下的教学实验）']);
    exportgraphics(fig,fullfile(out,[name,'.png']),'Resolution',130);
    savefig(fig,fullfile(out,[name,'.fig'])); close(fig);
end
