#include "extensions_test_support.hpp"

int main()
{
    SMC::PositionInput in; in.measurement=.5f; float u=0;
    SMC::IntegralPosition integral; auto ic=IConfig(); CHECK(integral.Init(ic,-3,3));
    CHECK(integral.Calc(in,.5f,u)); Near(integral.GetErrorIntegral(),.25); Near(integral.GetResult().sliding_variable,1.25);
    Near(integral.GetResult().requested_output,-3.375); CHECK(u==-3 && integral.GetResult().limited);
    CHECK(integral.Calc(in,.5f,u)); Near(integral.GetErrorIntegral(),.5); Near(integral.GetResult().requested_output,-4);
    CHECK(integral.Reset() && integral.GetErrorIntegral()==0);
    ic.integral_gain=0; CHECK(integral.Init(ic,-100,100));
    SMC::Position ordinary; CHECK(ordinary.Init(Config(),-100,100));
    in.measurement=1; in.measurement_rate=-2; in.target_acceleration=1;
    float base=0; CHECK(integral.Calc(in,.5f,u) && ordinary.Calc(in,base)); CHECK(u==base);

    SMC::PowerPosition power; auto pc=PConfig(); CHECK(power.Init(pc,-100,100));
    in=SMC::PositionInput(); in.measurement=.5f;
    CHECK(power.Calc(in,u)); Near(u,-2.5); // s=1：线性项3和幂次项4*.5。
    in.measurement=2; CHECK(power.Calc(in,u)); Near(u,-10); // s=4，sqrt(s)=2。
    in.measurement=-2; CHECK(power.Calc(in,u)); Near(u,10);
    in=SMC::PositionInput(); in.target_acceleration=6; CHECK(power.Calc(in,u) && u==3); // s=0。

    SMC::TerminalPosition terminal; auto tc=TConfig(); CHECK(terminal.Init(tc,-100,100));
    in=SMC::PositionInput(); in.measurement=1; CHECK(terminal.Calc(in,u) && terminal.GetResult().terminal_branch); Near(u,-5);
    in.measurement=-1; CHECK(terminal.Calc(in,u)); Near(u,5);
    in.measurement=0; in.measurement_rate=1; CHECK(terminal.Calc(in,u) && !terminal.GetResult().terminal_branch); Near(u,-4.5);
    in.measurement=1e-30f; CHECK(terminal.Calc(in,u)); Near(u,-4.5);
    in.measurement=.25f; CHECK(terminal.Calc(in,u) && terminal.GetResult().terminal_branch); Near(u,-6);
    in.measurement=std::nextafter(.25f,0.0f); CHECK(terminal.Calc(in,u) && !terminal.GetResult().terminal_branch); Near(u,-7);
    in=SMC::PositionInput(); in.target_acceleration=6; CHECK(terminal.Calc(in,u) && u==3);

    // 角度单位换算时，非整数幂系数随Q^(1-a)一起变换，分支阈值随Q变换。
    const float scale=57.295779513f;
    in=SMC::PositionInput(); in.measurement=.5f; in.measurement_rate=-.3f; in.target_acceleration=.6f;
    CHECK(power.Init(pc,-100,100) && power.Calc(in,base));
    pc.input_gain*=scale; pc.power_gain*=std::pow(scale,1-pc.exponent); pc.boundary_width*=scale;
    SMC::PositionInput converted=in;
    converted.measurement*=scale; converted.measurement_rate*=scale; converted.target_acceleration*=scale;
    CHECK(power.Init(pc,-100,100) && power.Calc(converted,u)); Near(u,base,1e-5);
    CHECK(terminal.Init(tc,-100,100) && terminal.Calc(in,base));
    tc.input_gain*=scale; tc.terminal_gain*=std::pow(scale,1-tc.exponent);
    tc.switching_gain*=scale; tc.boundary_width*=scale; tc.transition_width*=scale;
    CHECK(terminal.Init(tc,-100,100) && terminal.Calc(converted,u)); Near(u,base,1e-5);
}
