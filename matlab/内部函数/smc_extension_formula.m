function [details,z]=smc_extension_formula(v,previous)
% 与C++分开的公式计算；输入为single时保持控制器的单精度递推。
    kind=double(v(1)); e=v(16)-v(13); edot=v(17)-v(14);
    z=previous; if v(19)==1, z=0*v(3); end
    outer=false;
    if kind==1
        z=z+e*v(18); s=edot+v(4)*e+v(5)*z;
        acc=v(15)-v(4)*edot; acc=acc-v(5)*e; acc=acc-v(7)*s;
        acc=acc-v(8)*max(-1,min(1,s/v(9)));
    elseif kind==2
        z=0*v(3); s=edot+v(4)*e;
        acc=v(15)-v(4)*edot; acc=acc-v(7)*s;
        acc=acc-v(5)*abs(s)^v(6)*max(-1,min(1,s/v(9)));
    elseif kind==3
        z=0*v(3); outer=~(abs(e)<v(10));
        if outer
            term=v(5)*abs(e)^v(6); if e<0, term=-term; end
            derivative=v(5)*v(6)*abs(e)^(v(6)-1);
        else
            term=v(4)*e; derivative=v(4);
        end
        s=edot+term;
        acc=v(15)-derivative*edot; acc=acc-v(7)*s; acc=acc-v(8)*max(-1,min(1,s/v(9)));
    else
        z=0*v(3); s=edot+v(4)*e;
        acc=v(15)-v(4)*edot; acc=acc-v(7)*s; acc=acc-v(8)*max(-1,min(1,s/v(9)));
    end
    request=acc/v(3); output=max(v(11),min(v(12),request));
    details=[e,edot,z,s,request,output,request~=output,outer];
end
