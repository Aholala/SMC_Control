#include "test_support.hpp"

int main()
{
    SMC::Position p;
    SMC::PositionConfig c = Config();
    CHECK(p.Init(c, -1000.0f, 1000.0f));
    SMC::PositionInput in;
    float u = 123.0f;
    CHECK(p.Calc(in, u));
    Near(u, 0);

    // e=1, e_dot=-2, s=0, target_acc=1: u=(1+4)/2=2.5.
    in.measurement = 1;
    in.measurement_rate = -2;
    in.target_acceleration = 1;
    CHECK(p.Calc(in, u));
    Near(u, 2.5);
    Near(p.GetResult().sliding_variable, 0);

    // e=.5, e_dot=0, s=1, sat=.5: u=(-3-2)/2=-2.5.
    in = SMC::PositionInput();
    in.measurement = 0.5f;
    CHECK(p.Calc(in, u));
    Near(u, -2.5);
    in.measurement = 1;
    CHECK(p.Calc(in, u));
    Near(u, -5); // s=phi: u=(-6-4)/2.
    in.measurement = -1;
    CHECK(p.Calc(in, u));
    Near(u, 5);

    // Zero position error at nonzero speed still produces braking.
    in = SMC::PositionInput();
    in.measurement_rate = 1;
    CHECK(p.Calc(in, u));
    Near(u, -3.5);

    // Perfect moving-target tracking retains the required acceleration input.
    in.target = in.measurement = 3;
    in.target_rate = in.measurement_rate = -4;
    in.target_acceleration = 6;
    CHECK(p.Calc(in, u));
    Near(u, 3);
    c.input_gain = -2;
    CHECK(p.SetParameters(c));
    CHECK(p.Calc(in, u));
    Near(u, -3);

    c = Config();
    c.reaching_gain = 0;
    CHECK(p.SetParameters(c));
    in = SMC::PositionInput();
    in.measurement = 0.5f;
    CHECK(p.Calc(in, u));
    Near(u, -1);
    c.reaching_gain = 3;
    c.switching_gain = 0;
    CHECK(p.SetParameters(c));
    CHECK(p.Calc(in, u));
    Near(u, -1.5);

    // Unit conversion: degrees vs rad changes angle-scale parameters, not u.
    c = Config();
    CHECK(p.SetParameters(c));
    in.target = 0.2f;
    in.measurement = -0.3f;
    in.target_rate = 0.4f;
    in.measurement_rate = -0.5f;
    in.target_acceleration = 0.6f;
    CHECK(p.Calc(in, u));
    const float baseline = u;
    const float angle_scale = 57.295779513f;
    c.input_gain *= angle_scale;
    c.switching_gain *= angle_scale;
    c.boundary_width *= angle_scale;
    CHECK(p.SetParameters(c));
    in.target *= angle_scale;
    in.measurement *= angle_scale;
    in.target_rate *= angle_scale;
    in.measurement_rate *= angle_scale;
    in.target_acceleration *= angle_scale;
    CHECK(p.Calc(in, u));
    Near(u, baseline, 5e-6);

    // Changing output unit A -> mA requires b/1000 and limits*1000.
    c.input_gain /= 1000;
    CHECK(p.SetParameters(c));
    CHECK(p.SetLimits(-1000000, 1000000));
    CHECK(p.Calc(in, u));
    Near(u, baseline * 1000, 0.005);
}
