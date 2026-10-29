#include "../main/ALG_SMC.hpp"
#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>

static void Require(bool condition)
{
    if (!condition) { std::cerr << "Lesson 15 lifecycle check failed\n"; std::exit(1); }
}

static void Emit(int step, int operation, int returned, const SMC::Position& axis,
                 const SMC::PositionInput& in, float command)
{
    const SMC::PositionResult& result = axis.GetResult();
    const SMC::PositionConfig& config = axis.GetConfig();
    std::cout << step << ',' << operation << ',' << returned << ','
              << in.target << ',' << in.target_rate << ',' << in.target_acceleration << ','
              << in.measurement << ',' << in.measurement_rate << ',' << command << ','
              << axis.IsInitialized() << ',' << axis.HasResult() << ','
              << result.requested_output << ',' << result.output << ',' << result.sliding_variable << ','
              << config.input_gain << ',' << config.surface_gain << ',' << config.reaching_gain << ','
              << config.switching_gain << ',' << config.boundary_width << ','
              << axis.GetOutputMin() << ',' << axis.GetOutputMax() << '\n';
}

int main()
{
    SMC::Position axis;
    SMC::PositionConfig config;
    config.input_gain = 5;
    config.surface_gain = 0.5f;
    config.reaching_gain = 1;
    config.switching_gain = 2;
    config.boundary_width = 1;
    SMC::PositionInput in;
    in.target = 5;
    in.measurement = 6;
    float command = 17; // 调用方变量的观察标记；没有提交给任何设备。
    std::cout << std::setprecision(17);
    std::cout << "step_number,operation_code,return_code,target_deg,target_rate_deg_s,target_acceleration_deg_s2,measurement_deg,measurement_rate_deg_s,caller_command_a,is_initialized,has_result,result_requested_a,result_output_a,result_s_deg_s,input_gain_deg_s2_per_a,surface_gain_per_s,reaching_gain_per_s,switching_gain_deg_s2,boundary_width_deg_s,output_min_a,output_max_a\n";
    Require(!axis.IsInitialized() && !axis.HasResult());
    Emit(1, 0, -1, axis, in, command); // 仅观察，未调用 Calc。
    bool returned = axis.Init(config, -1000, 1000);
    Require(returned && !axis.HasResult() && command == 17);
    Emit(2, 1, returned, axis, in, command);
    returned = axis.Calc(in, command);
    Require(returned && axis.HasResult() && std::fabs(command + 0.3f) < 1e-6f);
    Emit(3, 2, returned, axis, in, command);
    const float before_reset = command;
    returned = axis.Calc(in, command);
    Require(returned && command == before_reset);
    Emit(4, 2, returned, axis, in, command);
    returned = axis.Reset();
    Require(returned && !axis.HasResult() && command == before_reset);
    Require(axis.GetResult().output == 0 && axis.GetResult().requested_output == 0);
    Require(axis.GetConfig().input_gain == 5 && axis.GetConfig().surface_gain == 0.5f &&
            axis.GetConfig().reaching_gain == 1 && axis.GetConfig().switching_gain == 2 &&
            axis.GetConfig().boundary_width == 1 && axis.GetOutputMin() == -1000 && axis.GetOutputMax() == 1000);
    Emit(5, 3, returned, axis, in, command);
    command = 0; // 调用方显式清理自己的变量；仍然没有设备提交动作。
    Emit(6, 4, -1, axis, in, command);
    returned = axis.Calc(in, command);
    Require(returned && axis.HasResult() && command == before_reset);
    Emit(7, 2, returned, axis, in, command);
    in.target = 0;
    in.measurement = 0;
    in.measurement_rate = 3;
    returned = axis.Calc(in, command);
    Require(returned && std::fabs(command + 1.3f) < 1e-6f);
    Emit(8, 2, returned, axis, in, command);
    return 0;
}
