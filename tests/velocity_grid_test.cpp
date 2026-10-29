#include "velocity_test_support.hpp"
#include <algorithm>

int main()
{
    int count=0;
    for (float b:{-3.0f,.125f,3.0f})
    for (float c:{.5f,4.0f})
    for (float k:{0.0f,6.0f})
    for (float epsilon:{0.0f,2.0f})
    for (float phi:{.05f,.5f})
    for (float e:{-5.0f,-.03f,0.0f,.03f,5.0f})
    for (float dt:{.001f,.05f,.5f})
    for (float seed:{-1.0f,0.0f,1.0f})
    {
        if (k==0 && epsilon==0) continue;
        SMC::VelocityConfig config;
        config.input_gain=b; config.surface_gain=c; config.reaching_gain=k;
        config.switching_gain=epsilon; config.boundary_width=phi;
        SMC::Velocity p; CHECK(p.Init(config,-2,3));
        SMC::VelocityInput in; in.measurement=seed; in.dt=.5f;
        float u=0; CHECK(p.Calc(in,u));
        const double previous=double(seed)*.5;
        in.measurement=e; in.dt=dt; in.target_acceleration=.75f;
        CHECK(p.Calc(in,u));
        const double integral_request=previous+double(e)*dt;
        const double z=integral_request;
        const double s=e+double(c)*z;
        const double request=(.75-double(c)*e-double(k)*s-double(epsilon)*std::max(-1.0,std::min(1.0,s/phi)))/b;
        Near(p.GetErrorIntegral(),z,2e-6); Near(p.GetResult().sliding_variable,s,3e-6);
        Near(p.GetResult().requested_output,request,3e-5); Near(u,std::max(-2.0,std::min(3.0,request)),3e-5);
        CHECK(u>=-2 && u<=3); ++count;
    }
    CHECK(count==1620); std::cout << "velocity_grid_points=" << count << '\n';
}
