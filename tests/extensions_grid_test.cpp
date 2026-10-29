#include "extensions_test_support.hpp"

int main()
{
    int count=0;
    for(float b:{-3.0f,2.0f}) for(float e:{-1.0f,-.25f,-.01f,0.0f,.01f,.25f,1.0f})
    for(float v:{-1.0f,0.0f,1.0f}) for(float dt:{.001f,.125f})
    {
        SMC::PositionInput in; in.measurement=e; in.measurement_rate=v; in.target_acceleration=.75f; float u=0;
        auto ic=IConfig(); ic.input_gain=b; SMC::IntegralPosition integral; CHECK(integral.Init(ic,-2,3));
        SMC::PositionInput seed; seed.measurement=.25f; CHECK(integral.Calc(seed,.5f,u));
        CHECK(integral.Calc(in,dt,u));
        const double z=.125+double(e)*dt, s=v+2.0*e+z;
        const double request=(.75-2.0*v-e-3*s-4*Limit(s/2,-1,1))/b;
        Near(integral.GetErrorIntegral(),z); Near(integral.GetResult().sliding_variable,s,3e-6);
        Near(integral.GetResult().requested_output,request,3e-5); Near(u,Limit(request,-2,3),3e-5); ++count;
        for(float exponent:{.5f,1.0f,1.5f})
        {
            auto pc=PConfig(); pc.input_gain=b; pc.exponent=exponent;
            SMC::PowerPosition p; CHECK(p.Init(pc,-2,3) && p.Calc(in,u));
            const double sp=v+2.0*e;
            const double up=(.75-2.0*v-3*sp-4*std::pow(std::abs(sp),double(exponent))*Limit(sp/2,-1,1))/b;
            Near(p.GetResult().requested_output,up,3e-5); Near(u,Limit(up,-2,3),3e-5); ++count;
        }
        for(float exponent:{.5f,.75f})
        {
            auto tc=TConfig(); tc.input_gain=b; tc.exponent=exponent;
            SMC::TerminalPosition p; CHECK(p.Init(tc,-2,3) && p.Calc(in,u));
            const double magnitude=std::abs(double(e)); const bool outer=magnitude>=.25;
            const double term=outer ? 2*std::copysign(std::pow(magnitude,double(exponent)),double(e)) : 4.0*e;
            const double derivative=outer ? 2*exponent*std::pow(magnitude,double(exponent)-1) : 4;
            const double st=v+term, ut=(.75-derivative*v-3*st-4*Limit(st/2,-1,1))/b;
            CHECK(p.GetResult().terminal_branch==outer); Near(p.GetResult().sliding_variable,st,3e-6);
            Near(p.GetResult().requested_output,ut,3e-5); Near(u,Limit(ut,-2,3),3e-5); ++count;
        }
    }
    CHECK(count==504); std::cout << "extension_grid_cases=" << count << '\n';
}
