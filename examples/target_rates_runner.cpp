#include "../main/ALG_SMC.hpp"
#include <cstdlib>
#include <iomanip>
#include <iostream>

static double Target(double time) { return time * time * time; }

int main()
{
    SMC::PositionConfig config;
    config.input_gain = 5;
    config.surface_gain = 0.5f;
    config.reaching_gain = 1;
    config.switching_gain = 2;
    config.boundary_width = 1;
    SMC::Position controller;
    if (!controller.Init(config, -10, 10)) return 1;
    const double interval = 0.1;
    std::cout << std::setprecision(17);
    std::cout << "sample_number,method_number,time_s,interval_s,target_deg,target_rate_deg_s,target_acceleration_deg_s2,measurement_deg,measurement_rate_deg_s,error_deg,error_rate_deg_s,s_deg_s,requested_a,output_a,limited\n";
    for (int sample = 0; sample < 11; ++sample)
    {
        const double time = (sample + 2) * interval;
        const double target = Target(time);
        const double previous = Target(time - interval);
        const double earlier = Target(time - 2 * interval);
        const double exact_rate = 3 * time * time;
        const double exact_acceleration = 6 * time;
        const double current_difference_rate = (target - previous) / interval;
        const double previous_difference_rate = (previous - earlier) / interval;
        const double current_difference_acceleration = (target - 2 * previous + earlier) / (interval * interval);
        for (int method = 1; method <= 3; ++method)
        {
            SMC::PositionInput in;
            in.target = static_cast<float>(target);
            in.measurement = static_cast<float>(target + 1);
            in.measurement_rate = static_cast<float>(exact_rate);
            in.target_rate = static_cast<float>(method == 1 ? exact_rate :
                                               method == 2 ? current_difference_rate : previous_difference_rate);
            in.target_acceleration = static_cast<float>(method == 1 ? exact_acceleration : current_difference_acceleration);
            float command = 0;
            if (!controller.Calc(in, command) || controller.GetResult().limited) return 1;
            const SMC::PositionResult& result = controller.GetResult();
            // 给定测量回放，输出不会反过来推进对象；三个方法只改变目标变化率输入。
            std::cout << sample + 1 << ',' << method << ',' << time << ',' << interval << ','
                      << in.target << ',' << in.target_rate << ',' << in.target_acceleration << ','
                      << in.measurement << ',' << in.measurement_rate << ',' << result.error << ','
                      << result.error_rate << ',' << result.sliding_variable << ','
                      << result.requested_output << ',' << command << ',' << result.limited << '\n';
        }
    }
    return 0;
}
