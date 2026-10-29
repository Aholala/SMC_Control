#include "ALG_SMC.hpp"
#include <iostream>

int main()
{
    // 仅教学参数：rad、s、A；实际项目必须提供自己的参数及输出范围。
    SMC::VelocityConfig c;
    c.input_gain=2; c.surface_gain=2; c.reaching_gain=3;
    c.switching_gain=4; c.boundary_width=2;
    SMC::Velocity axis;
    if (!axis.Init(c,-3,3)) return 1;
    SMC::VelocityInput in;
    in.target=0; in.target_acceleration=0; in.measurement=.5f; in.dt=.5f;
    float command=0;
    if (!axis.Calc(in,command)) return 2;
    std::cout << "error=" << axis.GetResult().error << " integral=" << axis.GetErrorIntegral()
              << " command=" << command << '\n'; // e=.5,z=.25,s=1,u=-3。
    return 0;
}
