#include "test_support.hpp"

int main()
{
    SMC::Position p;
    CHECK(p.Init(Config(), -1, 2));
    SMC::PositionInput in;
    in.target = 10;
    float u;
    CHECK(p.Calc(in, u));
    CHECK(u == 2 && p.GetResult().limited && p.GetResult().requested_output > u);
    in.target = -10;
    CHECK(p.Calc(in, u));
    CHECK(u == -1 && p.GetResult().limited && p.GetResult().requested_output < u);
    CHECK(p.SetLimits(0, 0));
    CHECK(p.Calc(in, u) && u == 0 && p.GetResult().limited);
    CHECK(p.SetLimits(2, 2));
    in = SMC::PositionInput();
    CHECK(p.Calc(in, u) && u == 2 && p.GetResult().limited);
    CHECK(p.Reset() && !p.HasResult()); // Reset value 0 is diagnostic, not a command.
    CHECK(p.GetOutputMin() == 2);
    CHECK(p.SetLimits(-5, 5));
    in.measurement = 1;
    CHECK(p.Calc(in, u));
    CHECK(u == -5 && !p.GetResult().limited); // Equal to bound is not clipping.

    // Very small positive phi is valid: clipping s/phi must not overflow.
    SMC::PositionConfig c = Config();
    c.boundary_width = 1e-30f;
    CHECK(p.SetParameters(c));
    CHECK(p.Calc(in, u));
    Near(p.GetResult().requested_output, -5);
}
