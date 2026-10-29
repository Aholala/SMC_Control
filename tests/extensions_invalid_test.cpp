#include "extensions_test_support.hpp"

template<class Controller,class ConfigType> void Invalid(ConfigType config)
{
    Controller p; CHECK(p.Init(config,-5,6));
    SMC::PositionInput in; in.measurement=.5f; float u=0; CHECK(Calculate(p,in,u));
    const Controller saved=p;
    const float bad[]={std::numeric_limits<float>::quiet_NaN(),std::numeric_limits<float>::infinity(),-std::numeric_limits<float>::infinity()};
    float SMC::PositionInput::* const fields[]={&SMC::PositionInput::target,&SMC::PositionInput::target_rate,
        &SMC::PositionInput::target_acceleration,&SMC::PositionInput::measurement,&SMC::PositionInput::measurement_rate};
    for(auto field:fields) for(float value:bad)
    { auto input=in; input.*field=value; u=31; CHECK(!Calculate(p,input,u) && u==31); SameExtension(p,saved); }
    for(float value:bad) { config.input_gain=value; CHECK(!p.SetParameters(config)); SameExtension(p,saved); }
}
int main()
{
    Invalid<SMC::IntegralPosition>(IConfig()); Invalid<SMC::PowerPosition>(PConfig()); Invalid<SMC::TerminalPosition>(TConfig());
    SMC::PowerPosition power; auto pc=PConfig(); pc.exponent=0; CHECK(!power.Init(pc,-1,1));
    SMC::TerminalPosition terminal; auto tc=TConfig(); tc.exponent=1; CHECK(!terminal.Init(tc,-1,1));
    tc=TConfig(); tc.transition_width=0; CHECK(!terminal.Init(tc,-1,1));
    SMC::IntegralPosition integral; CHECK(integral.Init(IConfig(),-1,1));
    SMC::PositionInput in; in.measurement=.5f; float u=0; CHECK(integral.Calc(in,.125f,u));
    const auto saved=integral; const float z=integral.GetErrorIntegral();
    for(float dt:{0.0f,-1.0f,std::numeric_limits<float>::infinity()})
    { u=31; CHECK(!integral.Calc(in,dt,u) && u==31 && integral.GetErrorIntegral()==z); SameExtension(integral,saved); }
}
