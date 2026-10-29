#ifndef SMC_EXTENSIONS_TEST_SUPPORT_HPP
#define SMC_EXTENSIONS_TEST_SUPPORT_HPP
#include "test_support.hpp"
#include <algorithm>
#include <limits>

inline SMC::IntegralPositionConfig IConfig()
{ SMC::IntegralPositionConfig c; c.input_gain=2; c.surface_gain=2; c.integral_gain=1; c.reaching_gain=3; c.switching_gain=4; c.boundary_width=2; return c; }
inline SMC::PowerPositionConfig PConfig()
{ SMC::PowerPositionConfig c; c.input_gain=2; c.surface_gain=2; c.reaching_gain=3; c.power_gain=4; c.exponent=.5f; c.boundary_width=2; return c; }
inline SMC::TerminalPositionConfig TConfig()
{ SMC::TerminalPositionConfig c; c.input_gain=2; c.linear_surface_gain=4; c.terminal_gain=2; c.exponent=.5f; c.reaching_gain=3; c.switching_gain=4; c.boundary_width=2; c.transition_width=.25f; return c; }
inline bool Calculate(SMC::IntegralPosition& p,const SMC::PositionInput& in,float& u) { return p.Calc(in,.125f,u); }
inline bool Calculate(SMC::PowerPosition& p,const SMC::PositionInput& in,float& u) { return p.Calc(in,u); }
inline bool Calculate(SMC::TerminalPosition& p,const SMC::PositionInput& in,float& u) { return p.Calc(in,u); }
template<class Controller> void SameExtension(const Controller& a,const Controller& b)
{
    CHECK(a.IsInitialized()==b.IsInitialized() && a.HasResult()==b.HasResult());
    CHECK(a.GetOutputMin()==b.GetOutputMin() && a.GetOutputMax()==b.GetOutputMax());
    const auto& x=a.GetResult(); const auto& y=b.GetResult();
    CHECK(x.error==y.error && x.error_rate==y.error_rate && x.sliding_variable==y.sliding_variable &&
          x.requested_output==y.requested_output && x.output==y.output && x.limited==y.limited);
}
inline double Limit(double x,double lo,double hi) { return std::max(lo,std::min(hi,x)); }
#endif
