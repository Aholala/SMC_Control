#include "../SMC_Controller/SMC/slidingmodec.h"
#include <iomanip>
#include <iostream>

// 原构造函数未设置的成员依靠静态存储的零初始化获得确定初值。
static SMC startup(0.5f, 1.0f, 5.0f, 0.1f, 1000.0f, 0.2f, 2.0f);
static SMC deadzone(0.5f, 1.0f, 0.0f, 0.1f, 1000.0f, 0.2f, 2.0f);
static SMC pause_resume(0.5f, 1.0f, 0.0f, 0.1f, 1000.0f, 0.2f, 2.0f);
static SMC pass_target(0.5f, 1.0f, 0.0f, 0.1f, 1000.0f, 0.2f, 2.0f);

static void Replay(SMC& axis, int scenario, int step, bool call,
                   float target, float measurement, float rate)
{
    const float before = axis.u;
    axis.ref = target;
    if (call) axis.SMC_Tick(measurement, rate);
    std::cout << scenario << ',' << step << ',' << call << ',' << target << ','
              << measurement << ',' << rate << ',' << before << ',' << axis.u << '\n';
}

int main()
{
    std::cout << std::setprecision(17);
    std::cout << "case_number,step_number,called,target_deg,measurement_deg,measurement_rate_deg_s,output_before_value,raw_output_value\n";
    Replay(startup, 1, 1, true, 5, 6, 0);
    Replay(startup, 1, 2, true, 5, 6, 0);
    Replay(startup, 1, 3, true, 5, 6, 0);
    Replay(deadzone, 2, 1, true, 0, 1, 0);
    Replay(deadzone, 2, 2, true, 1, 1, 0);
    Replay(deadzone, 2, 3, true, 2, 2, 0);
    Replay(deadzone, 2, 4, true, 3, 4, 0);
    Replay(pause_resume, 3, 1, true, 0, 1, 0);
    Replay(pause_resume, 3, 2, false, 5, 6, 0);
    Replay(pause_resume, 3, 3, false, 5, 6, 0);
    Replay(pause_resume, 3, 4, true, 5, 6, 0);
    Replay(pause_resume, 3, 5, true, 5, 6, 0);
    Replay(pause_resume, 3, 6, true, 5, 6, 0);
    Replay(pass_target, 4, 1, true, 0, 0, 3);
    return 0;
}
