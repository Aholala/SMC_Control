#ifndef SMC_TEST_SUPPORT_HPP
#define SMC_TEST_SUPPORT_HPP
#include "ALG_SMC.hpp"
#include <cmath>
#include <cstdlib>
#include <iostream>

#define CHECK(condition) do { if (!(condition)) { \
    std::cerr << __FILE__ << ':' << __LINE__ << " check failed: " #condition << '\n'; \
    std::exit(1); } } while (false)

inline void Near(double actual, double expected, double absolute = 1e-6, double relative = 2e-6)
{
    CHECK(std::isfinite(actual));
    CHECK(std::abs(actual - expected) <= absolute + relative * std::abs(expected));
}

inline SMC::PositionConfig Config()
{
    SMC::PositionConfig c;
    c.input_gain = 2.0f;
    c.surface_gain = 2.0f;
    c.reaching_gain = 3.0f;
    c.switching_gain = 4.0f;
    c.boundary_width = 2.0f;
    return c;
}

inline void Same(const SMC::PositionResult& a, const SMC::PositionResult& b)
{
    CHECK(a.error == b.error && a.error_rate == b.error_rate &&
          a.sliding_variable == b.sliding_variable &&
          a.requested_output == b.requested_output && a.output == b.output &&
          a.limited == b.limited);
}
#endif
