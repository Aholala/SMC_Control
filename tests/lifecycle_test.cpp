#include "test_support.hpp"

int main()
{
    SMC::Position p;
    SMC::PositionInput in;
    float u = 17;
    CHECK(!p.IsInitialized() && !p.HasResult());
    CHECK(!p.Calc(in, u) && u == 17);
    CHECK(!p.Reset() && !p.SetParameters(Config()) && !p.SetLimits(-1, 1));
    CHECK(p.Init(Config(), -4, 3));
    CHECK(p.IsInitialized() && !p.HasResult());
    in.target = 5;
    CHECK(p.Calc(in, u) && p.HasResult());
    CHECK(u == 3);
    CHECK(p.Reset() && !p.HasResult());
    CHECK(p.GetResult().output == 0 && p.GetResult().requested_output == 0);
    CHECK(p.GetOutputMin() == -4 && p.GetOutputMax() == 3);
    CHECK(p.Calc(in, u) && u == 3); // No historical prime/first-sample transient.

    SMC::PositionConfig c = Config();
    c.input_gain = -2;
    CHECK(p.SetParameters(c) && !p.HasResult());
    CHECK(p.GetOutputMin() == -4 && p.GetOutputMax() == 3);
    CHECK(p.Calc(in, u) && u == -4);
    CHECK(p.SetLimits(-1, 2) && !p.HasResult());
    CHECK(p.GetConfig().input_gain == -2);
    CHECK(p.Calc(in, u) && u == -1);

    // Independent local instances and interleaving cannot share a history.
    SMC::Position other;
    CHECK(other.Init(Config(), -100, 100));
    float other_u = 0;
    CHECK(other.Calc(in, other_u));
    CHECK(other_u > 0);
    CHECK(p.Calc(in, u) && u == -1);
    CHECK(other.Reset() && !other.HasResult() && p.HasResult());

    const SMC::PositionResult saved = p.GetResult();
    c.input_gain = 0;
    CHECK(!p.Init(c, -3, 3));
    CHECK(!p.SetParameters(c));
    CHECK(!p.SetLimits(2, -2));
    Same(saved, p.GetResult());
    CHECK(p.GetConfig().input_gain == -2 && p.GetOutputMin() == -1);
    CHECK(p.HasResult());

    // Explicit reinitialization replaces config and bounds, clears diagnostics.
    CHECK(p.Init(Config(), -7, 8));
    CHECK(!p.HasResult() && p.GetConfig().input_gain == 2);
    CHECK(p.GetOutputMin() == -7 && p.GetOutputMax() == 8);
}
