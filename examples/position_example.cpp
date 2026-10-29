#include "ALG_SMC.hpp"
#include <iostream>

int main()
{
    // 仅为教学假设：角度 rad、时间 s、输出 A。不是任意真实电机参数。
    SMC::PositionConfig config;
    config.input_gain = 3.0f;
    config.surface_gain = 4.0f;
    config.reaching_gain = 6.0f;
    config.switching_gain = 2.0f;
    config.boundary_width = 0.25f;
    SMC::Position axis;
    if (!axis.Init(config, -4.0f, 4.0f))
        return 1;

    SMC::PositionInput input;
    input.target = 0.5f;
    input.target_rate = 0.0f; // 此例目标静止；运动目标须显式填写变化率。
    input.target_acceleration = 0.0f;
    input.measurement = 0.0f;
    input.measurement_rate = 0.0f;
    float command = 0.0f;
    if (!axis.Calc(input, command))
        return 2; // 实际项目在这里执行本任务的失败策略，不提交旧 command。
    std::cout << "request=" << axis.GetResult().requested_output
              << " command=" << command << " limited=" << axis.GetResult().limited << '\n';
    return 0;
}
