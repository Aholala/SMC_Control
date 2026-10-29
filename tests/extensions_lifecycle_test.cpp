#include "extensions_test_support.hpp"

template<class Controller,class ConfigType> void Lifecycle(ConfigType config)
{
    Controller a,b; SMC::PositionInput in; in.measurement=.5f; float u=17,v=23;
    CHECK(!Calculate(a,in,u) && u==17 && !a.Reset());
    CHECK(!a.SetParameters(config) && !a.SetLimits(-1,1));
    CHECK(a.Init(config,-3,3) && b.Init(config,-1,2));
    CHECK(Calculate(a,in,u) && Calculate(b,in,v)); const Controller saved_b=b;
    CHECK(a.Reset() && !a.HasResult()); SameExtension(b,saved_b);
    CHECK(Calculate(a,in,u)); CHECK(a.SetParameters(config) && !a.HasResult());
    CHECK(a.SetLimits(0,0) && Calculate(a,in,u) && u==0);
    const Controller saved=a;
    config.input_gain=0; CHECK(!a.Init(config,-1,1) && !a.SetParameters(config));
    CHECK(!a.SetLimits(1,-1)); SameExtension(a,saved);
    CHECK(a.GetConfig().input_gain==saved.GetConfig().input_gain);
}
int main()
{
    Lifecycle<SMC::IntegralPosition>(IConfig()); Lifecycle<SMC::PowerPosition>(PConfig()); Lifecycle<SMC::TerminalPosition>(TConfig());
    SMC::IntegralPosition p; auto c=IConfig(); CHECK(p.Init(c,-1,1));
    SMC::PositionInput in; in.measurement=1; float u=0;
    CHECK(p.Calc(in,.5f,u) && p.Calc(in,.5f,u) && p.GetErrorIntegral()==1); // 未添加冻结/累计限幅。
    c.surface_gain=3; CHECK(p.SetParameters(c) && p.GetErrorIntegral()==1 && !p.HasResult());
    CHECK(p.Reset() && p.GetErrorIntegral()==0 && u==-1);
}
