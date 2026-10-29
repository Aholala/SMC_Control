#include "velocity_test_support.hpp"

int main()
{
    SMC::Velocity p;
    SMC::VelocityConfig c=VelocityConfig();
    CHECK(p.Init(c,-100,100));
    SMC::VelocityInput in; in.dt=.5f; in.measurement=.5f;
    float u=17;
    CHECK(p.Calc(in,u));
    // 更新顺序：z=.25,s=1,u=(-1-3-2)/2=-3。
    CHECK(p.GetErrorIntegral()==.25f && p.GetResult().sliding_variable==1 && u==-3);
    CHECK(!p.GetResult().limited);
    CHECK(p.Calc(in,u));
    CHECK(p.GetErrorIntegral()==.5f && p.GetResult().sliding_variable==1.5f && u==-4.25f);
    CHECK(p.Reset() && p.GetErrorIntegral()==0);
    in.target=in.measurement=3; in.target_acceleration=6;
    CHECK(p.Calc(in,u) && u==3 && p.GetErrorIntegral()==0);
    c.input_gain=-2; CHECK(p.SetParameters(c));
    CHECK(p.Calc(in,u) && u==-3);
    CHECK(p.SetLimits(-3,3) && p.Calc(in,u) && !p.GetResult().limited);
    CHECK(p.SetLimits(0,0) && p.Calc(in,u) && u==0 && p.GetResult().limited);

    c=VelocityConfig(); CHECK(p.Init(c,-1,2));
    in=SMC::VelocityInput(); in.dt=.5f; in.measurement=1;
    CHECK(p.Calc(in,u));
    CHECK(p.GetErrorIntegral()==.5f && u==-1 && p.GetResult().limited);
    CHECK(p.Calc(in,u) && p.GetErrorIntegral()==1); // 输出受限仍按参考公式继续累计。
    in.measurement=-1; CHECK(p.Calc(in,u));
    CHECK(p.GetErrorIntegral()==.5f && u==1);

    // 只有线性或只有切换趋近项均有效；非常小的phi不先执行溢出的s/phi。
    c=VelocityConfig(); c.reaching_gain=0; c.boundary_width=1e-30f;
    CHECK(p.Init(c,-100,100) && p.Calc(in,u)); Near(u,3);
    c.reaching_gain=3; c.switching_gain=0; CHECK(p.Init(c,-100,100));
    CHECK(p.Calc(in,u)); Near(u,4);

    // 单位改变时，速度/加速度和相应参数一同换算。
    c=VelocityConfig(); CHECK(p.Init(c,-100,100));
    in.target=.2f; in.measurement=-.3f; in.target_acceleration=.6f; in.dt=.125f;
    CHECK(p.Calc(in,u)); const float baseline=u;
    const float scale=57.295779513f;
    c.input_gain*=scale; c.switching_gain*=scale; c.boundary_width*=scale;
    CHECK(p.Init(c,-100,100));
    in.target*=scale; in.measurement*=scale; in.target_acceleration*=scale;
    CHECK(p.Calc(in,u)); Near(u,baseline,5e-6);
    c.input_gain/=1000; CHECK(p.Init(c,-100000,100000));
    CHECK(p.Calc(in,u)); Near(u,baseline*1000,.005);
}
