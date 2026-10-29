#ifndef SMC_VELOCITY_TEST_SUPPORT_HPP
#define SMC_VELOCITY_TEST_SUPPORT_HPP
#include "test_support.hpp"

inline SMC::VelocityConfig VelocityConfig()
{
    SMC::VelocityConfig c;
    c.input_gain=2; c.surface_gain=2; c.reaching_gain=3;
    c.switching_gain=4; c.boundary_width=2;
    return c;
}

inline void SameVelocity(const SMC::Velocity& actual, const SMC::Velocity& saved)
{
    const SMC::VelocityConfig& a=actual.GetConfig();
    const SMC::VelocityConfig& b=saved.GetConfig();
    CHECK(a.input_gain==b.input_gain && a.surface_gain==b.surface_gain &&
          a.reaching_gain==b.reaching_gain && a.switching_gain==b.switching_gain && a.boundary_width==b.boundary_width);
    CHECK(actual.IsInitialized()==saved.IsInitialized() && actual.HasResult()==saved.HasResult());
    CHECK(actual.GetErrorIntegral()==saved.GetErrorIntegral());
    CHECK(actual.GetOutputMin()==saved.GetOutputMin() && actual.GetOutputMax()==saved.GetOutputMax());
    const SMC::VelocityResult& r=actual.GetResult();
    const SMC::VelocityResult& s=saved.GetResult();
    CHECK(r.error==s.error && r.error_integral==s.error_integral && r.sliding_variable==s.sliding_variable &&
          r.requested_output==s.requested_output && r.output==s.output &&
          r.limited==s.limited);
}
#endif
