#include "../main/ALG_SMC.hpp"
#include <iomanip>
#include <iostream>

int main()
{
    // 参数取自既有 tests/test_support.hpp 的 Config，单位 rad、s、A。
    // 本讲显式选择输出范围 ±3 A，全部数值仅用于教学。
    SMC::PositionConfig config;
    config.input_gain = 2;
    config.surface_gain = 2;
    config.reaching_gain = 3;
    config.switching_gain = 4;
    config.boundary_width = 2;
    SMC::Position axis;
    if (!axis.Init(config, -3, 3)) return 1;

    // 每行：目标角度、目标速度、目标加速度、测量角度、测量速度。
    const float inputs[6][5] = {
        {0, 0, 0, 0.5f, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, -0.5f, 0},
        {3, -4, 6, 3, -4},
        {0, 0, 0, 0, 1},
        {0, 0, 1, 1, -2}
    };
    std::cout << std::setprecision(17);
    std::cout << "case_number,target_rad,target_rate_rad_s,target_acc_rad_s2,measurement_rad,measurement_rate_rad_s,error_rad,error_rate_rad_s,s_rad_s,requested_a,output_a,limited\n";
    for (int index = 0; index < 6; ++index)
    {
        SMC::PositionInput in;
        in.target = inputs[index][0];
        in.target_rate = inputs[index][1];
        in.target_acceleration = inputs[index][2];
        in.measurement = inputs[index][3];
        in.measurement_rate = inputs[index][4];
        float command = 0;
        if (!axis.Calc(in, command)) return 2;
        SMC::PositionResult result = axis.GetResult();
        std::cout << index + 1 << ',' << in.target << ',' << in.target_rate << ','
                  << in.target_acceleration << ',' << in.measurement << ',' << in.measurement_rate << ','
                  << result.error << ',' << result.error_rate << ',' << result.sliding_variable << ','
                  << result.requested_output << ',' << command << ',' << result.limited << '\n';
    }
    return 0;
}
