#include "velocity_test_support.hpp"

int main()
{
    SMC::Velocity a,b;
    SMC::VelocityInput in; in.dt=.5f; in.measurement=.5f;
    float u=17,v=23;
    CHECK(!a.Calc(in,u) && u==17 && !a.Reset());
    CHECK(!a.SetParameters(VelocityConfig()) && !a.SetLimits(-1,1));
    CHECK(!a.Init(SMC::VelocityConfig(),-3,3) && !a.IsInitialized());
    CHECK(a.Init(VelocityConfig(),-4,3) && !a.HasResult());
    SMC::VelocityConfig c=VelocityConfig(); c.input_gain=-2;
    CHECK(b.Init(c,-1,2));
    CHECK(a.Calc(in,u) && u==-3 && b.Calc(in,v) && v==2);
    const SMC::Velocity saved_b=b;
    CHECK(a.Calc(in,u) && u==-4);
    CHECK(a.Reset() && !a.HasResult() && a.GetErrorIntegral()==0 && u==-4);
    SameVelocity(b,saved_b);
    CHECK(a.Calc(in,u) && u==-3 && a.GetErrorIntegral()==.25f);
    CHECK(a.SetParameters(c) && !a.HasResult() && a.GetErrorIntegral()==.25f);
    CHECK(a.GetOutputMin()==-4 && a.GetOutputMax()==3);
    CHECK(a.Calc(in,u) && u==3 && a.GetErrorIntegral()==.5f);
    CHECK(a.SetLimits(-1,1) && !a.HasResult() && a.GetErrorIntegral()==.5f);
    CHECK(a.Calc(in,u) && u==1 && a.HasResult() && a.GetErrorIntegral()==.75f);
    const SMC::Velocity saved=a;
    c.input_gain=0;
    CHECK(!a.Init(c,-3,3) && !a.SetParameters(c));
    CHECK(!a.SetLimits(2,-2));
    SameVelocity(a,saved); SameVelocity(b,saved_b);
    CHECK(a.Init(VelocityConfig(),-7,8) && !a.HasResult() && a.GetErrorIntegral()==0);
    CHECK(a.GetOutputMin()==-7 && a.GetOutputMax()==8);
    CHECK(b.Reset() && b.GetErrorIntegral()==0 && v==2);
}
