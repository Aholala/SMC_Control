#include "../main/ALG_SMC.hpp"
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>

int main(int argc, char** argv)
{
    if (argc != 2) return 1;
    std::ofstream out(argv[1]);
    if (!out.good()) return 1;
    out << std::setprecision(17);
    out << "case_number,form_number,time_s,target_rad,target_rate_rad_s,true_target_acc_rad_s2,input_target_acc_rad_s2,position_rad,rate_rad_s,error_rad,error_rate_rad_s,s_rad_s,requested_a,output_a,limited\n";
    const double dt = 0.001;
    const int steps = 4000;
    SMC::PositionConfig config;
    config.input_gain = 3;
    config.surface_gain = 4;
    config.reaching_gain = 6;
    config.switching_gain = 2;
    config.boundary_width = 0.25f;
    for (int scenario = 1; scenario <= 3; ++scenario)
    {
        for (int form = 1; form <= 2; ++form)
        {
            SMC::Position controller;
            if (!controller.Init(config, -4, 4)) return 1;
            double position = 0;
            double rate = scenario == 2 ? 0.2 : 0;
            for (int index = 0; index < steps; ++index)
            {
                const double time = index * dt;
                const double target = scenario == 1 ? 0 : scenario == 2 ? 0.2*time : 0.2*time*time;
                const double target_rate = scenario == 1 ? 0 : scenario == 2 ? 0.2 : 0.4*time;
                const double target_acc = scenario == 3 ? 0.4 : 0;
                SMC::PositionInput in;
                in.target = static_cast<float>(target);
                in.target_rate = static_cast<float>(target_rate);
                // 第二组只在调用位置将目标加速度设为零；不添加或修改生产库模式。
                in.target_acceleration = static_cast<float>(form == 1 ? target_acc : 0);
                in.measurement = static_cast<float>(position);
                in.measurement_rate = static_cast<float>(rate);
                float command = 0;
                if (!controller.Calc(in, command) || controller.GetResult().limited) return 1;
                const SMC::PositionResult& result = controller.GetResult();
                out << scenario << ',' << form << ',' << time << ',' << target << ',' << target_rate << ','
                    << target_acc << ',' << in.target_acceleration << ',' << position << ',' << rate << ','
                    << result.error << ',' << result.error_rate << ',' << result.sliding_variable << ','
                    << result.requested_output << ',' << command << ',' << result.limited << '\n';
                // 两组使用相同对象和步进关系，但各自的电流推进各自的状态。
                const double acceleration = 3.0 * command;
                position += rate*dt + 0.5*acceleration*dt*dt;
                rate += acceleration*dt;
                if (!std::isfinite(position) || !std::isfinite(rate)) return 1;
            }
        }
    }
    if (!out.good()) return 1;
    std::cout << "3 target cases x 2 formulas x 4000 steps completed\n";
    return 0;
}
