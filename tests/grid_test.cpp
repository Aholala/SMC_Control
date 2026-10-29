#include "test_support.hpp"
#include <algorithm>

int main()
{
    int checked = 0;
    for (float b : {-3.0f, 0.125f, 3.0f})
    for (float c : {0.5f, 4.0f})
    for (float k : {0.0f, 6.0f})
    for (float epsilon : {0.0f, 2.0f})
    for (float phi : {0.05f, 0.5f})
    for (float error : {-5.0f, -0.03f, 0.0f, 0.03f, 5.0f})
    for (float rate : {-2.0f, 0.0f, 2.0f})
    {
        if (k == 0 && epsilon == 0)
            continue;
        SMC::PositionConfig cfg;
        cfg.input_gain = b;
        cfg.surface_gain = c;
        cfg.reaching_gain = k;
        cfg.switching_gain = epsilon;
        cfg.boundary_width = phi;
        SMC::Position p;
        CHECK(p.Init(cfg, -2.0f, 3.0f));
        SMC::PositionInput in;
        in.measurement = error;
        in.measurement_rate = rate;
        in.target_acceleration = 0.75f;
        float u;
        CHECK(p.Calc(in, u));
        // Independent double-precision oracle over representable float inputs.
        const double s = double(rate) + double(c) * error;
        const double sat = std::max(-1.0, std::min(1.0, s / phi));
        const double request = (0.75 - double(c)*rate - double(k)*s - double(epsilon)*sat)/b;
        Near(p.GetResult().sliding_variable, s, 2e-6);
        Near(p.GetResult().requested_output, request, 2e-5);
        Near(u, std::max(-2.0, std::min(3.0, request)), 2e-5);
        CHECK(u >= -2 && u <= 3);
        ++checked;
    }
    CHECK(checked == 540);
    std::cout << "grid_points=" << checked << '\n';
}
