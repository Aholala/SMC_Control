#include "test_support.hpp"
#include <limits>

int main()
{
    const float nan = std::numeric_limits<float>::quiet_NaN();
    const float inf = std::numeric_limits<float>::infinity();
    const float maximum = std::numeric_limits<float>::max();
    SMC::Position p;
    CHECK(p.Init(Config(), -5, 6));
    SMC::PositionInput in;
    in.target = 1;
    float u;
    CHECK(p.Calc(in, u));
    const SMC::PositionResult saved = p.GetResult();

    const float bad_numbers[] = {nan, inf, -inf};
    float SMC::PositionConfig::* const fields[] = {
        &SMC::PositionConfig::input_gain, &SMC::PositionConfig::surface_gain,
        &SMC::PositionConfig::reaching_gain, &SMC::PositionConfig::switching_gain,
        &SMC::PositionConfig::boundary_width};
    for (auto field : fields)
        for (float value : bad_numbers)
        {
            SMC::PositionConfig c = Config();
            c.*field = value;
            CHECK(!p.SetParameters(c) && !p.Init(c, -5, 6));
            Same(saved, p.GetResult());
        }
    for (auto field : fields)
    {
        SMC::PositionConfig c = Config();
        c.*field = -1;
        if (field != &SMC::PositionConfig::input_gain)
            CHECK(!p.SetParameters(c));
    }
    for (auto field : {&SMC::PositionConfig::input_gain,
                       &SMC::PositionConfig::surface_gain,
                       &SMC::PositionConfig::boundary_width})
    {
        SMC::PositionConfig c = Config();
        c.*field = 0;
        CHECK(!p.SetParameters(c));
    }
    SMC::PositionConfig c = Config();
    c.reaching_gain = c.switching_gain = 0;
    CHECK(!p.SetParameters(c));
    for (float value : bad_numbers)
    {
        CHECK(!p.SetLimits(value, 6) && !p.SetLimits(-5, value));
        Same(saved, p.GetResult());
    }

    float SMC::PositionInput::* const inputs[] = {
        &SMC::PositionInput::target, &SMC::PositionInput::target_rate,
        &SMC::PositionInput::target_acceleration, &SMC::PositionInput::measurement,
        &SMC::PositionInput::measurement_rate};
    for (auto field : inputs)
        for (float value : bad_numbers)
        {
            SMC::PositionInput bad = in;
            bad.*field = value;
            u = 31;
            CHECK(!p.Calc(bad, u) && u == 31 && p.HasResult());
            Same(saved, p.GetResult());
        }

    in.target = -maximum;
    in.measurement = maximum; // Error subtraction overflows.
    u = 31;
    CHECK(!p.Calc(in, u) && u == 31);
    Same(saved, p.GetResult());
    in = SMC::PositionInput();
    in.measurement = maximum / 2; // c*e or subsequent s gain overflows.
    CHECK(!p.Calc(in, u) && u == 31);
    Same(saved, p.GetResult());

    c = Config();
    c.input_gain = 1e-30f;
    CHECK(p.SetParameters(c));
    in = SMC::PositionInput();
    in.target_acceleration = maximum / 2;
    CHECK(!p.Calc(in, u) && u == 31 && !p.HasResult()); // Reject before clipping infinity.

    c = Config();
    c.surface_gain = maximum;
    CHECK(p.SetParameters(c));
    in = SMC::PositionInput();
    in.measurement_rate = 2;
    CHECK(!p.Calc(in, u) && u == 31); // rate-term multiplication overflow.
}
