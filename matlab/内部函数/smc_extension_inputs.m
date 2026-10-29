function rows=smc_extension_inputs(lesson)
% 共用列：[kind block b c extra exponent K epsilon phi delta min max r rdot rddot theta omega dt operation]。
% kind=0普通、1位置累计、2混合幂次、3终端/普通分段；operation=1先Reset再Calc。
    rows=zeros(0,19);
    if lesson==24
        cfg=[1,0,2,2,1,0,3,4,2,0,-3,3];
        inputs=[0,0,0,.5,0,.5,0;0,0,0,.5,0,.5,0;0,0,0,-.5,0,.5,0; ...
            0,0,6,0,0,.5,0;0,0,0,.5,0,.5,1;0,0,0,.5,0,.5,0; ...
            0,0,0,.5,1,.5,0;0,0,6,0,0,.5,1];
        rows=[repmat(cfg,size(inputs,1),1),inputs];
    elseif lesson==25
        cfg=[2,0,2,2,4,.5,3,0,2,0,-3,3];
        inputs=[0,0,0,.5,0,.125,0;0,0,0,2,0,.125,0;0,0,0,-2,0,.125,0; ...
            0,0,6,0,0,.125,0;0,0,0,.125,0,.125,0;0,0,0,-.125,0,.125,0];
        rows=[repmat(cfg,size(inputs,1),1),inputs];
    elseif lesson==26
        cfg=[3,0,2,4,2,.5,3,4,2,.25,-100,100];
        e=[-1;1;-.25;.25;0;0]; v=[0;0;1;1;1;0]; acc=[0;0;0;0;0;6];
        rows=[repmat(cfg,numel(e),1),zeros(numel(e),2),acc,e,v,.125*ones(numel(e),1),zeros(numel(e),1)];
    elseif lesson==27
        cfg=[3,0,2,4,2,.5,3,4,2,.25,-100,100];
        mag=10.^linspace(-30,-2,113)';
        lo=double(single(.25)-eps(single(.25))/2); hi=double(single(.25)+eps(single(.25)));
        e=[-flipud(mag);0;mag;-hi;-.25;-lo;lo;.25;hi];
        for v=[0,1]
            inputs=[zeros(numel(e),3),e,v*ones(numel(e),1),.125*ones(numel(e),1),zeros(numel(e),1)];
            rows=[rows;repmat(cfg,numel(e),1),inputs]; %#ok<AGROW>
        end
    else
        error('SMC:Extensions:Lesson','讲次应为24～27。');
    end
    if lesson~=27
        n=(0:1023)'; periods=repmat([.001;.005;.02],ceil(1024/3),1);
        inputs=[1.2*sin(.013*n),.7*cos(.017*n),.4*sin(.031*n), ...
            .8*cos(.019*n),.6*sin(.023*n),periods(1:1024),zeros(1024,1)];
        if lesson==24, cfg=[1,1,3,4,4,0,6,2,.25,0,-1.5,2.25]; end
        if lesson==25, cfg=[2,1,3,4,2,.5,6,0,.25,0,-1.5,2.25]; end
        if lesson==26, cfg=[3,1,3,4,2,.5,6,2,.25,.25,-1.5,2.25]; end
        rows=[rows;repmat(cfg,1024,1),inputs];
    end
    rows=double(single(rows));
end
