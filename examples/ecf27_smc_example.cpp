// ECF27 接入教程的主机示例：仅使用真实 SMC 库，不连接电机。
// 全部数值均为教学假设；U 是抽象命令单位，不是任何真实电机的默认值。
#include "ALG_SMC.hpp"
#include <cmath>
#include <cstdio>

namespace
{
constexpr float kPi = 3.14159265358979323846f;
constexpr float kDegToRad = kPi / 180.0f;

// ratio = 电机转子转角 / 所控制输出轴转角，必须由项目提供且 > 0。
float DjiOutputSpeed(float rotor_rpm, float ratio)
{
    return rotor_rpm * (2.0f * kPi / 60.0f) / ratio;
}

// VESC 的 electrical_rpm 是电转速；pole_pairs 是极对数，必须 > 0。
float VescOutputSpeed(float electrical_rpm, float pole_pairs, float ratio)
{
    return electrical_rpm * (2.0f * kPi / 60.0f) / (pole_pairs * ratio);
}

// 只适用于允许选择最短转向的轴，映射到 [-pi, pi)。
float WrapError(float error)
{
    float shifted = std::fmod(error + kPi, 2.0f * kPi);
    if (shifted < 0.0f) shifted += 2.0f * kPi;
    return shifted - kPi;
}

bool Near(float actual, float expected)
{
    return std::fabs(actual - expected) < 2.0e-5f;
}

SMC::PositionInput StationaryTarget(float measurement, float speed, float target)
{
    SMC::PositionInput input;
    input.measurement = measurement;  // rad
    input.measurement_rate = speed;  // rad/s
    input.target = target;           // rad
    input.target_rate = 0.0f;        // 本例明确使用静止目标
    input.target_acceleration = 0.0f;
    return input;
}
}

int main()
{
    // 单位手算：教学假设 ratio=2、极对数=7；不是某型号默认配置。
    if (!Near(DjiOutputSpeed(60.0f, 2.0f), kPi)) return 1;
    if (!Near(VescOutputSpeed(420.0f, 7.0f, 2.0f), kPi)) return 2;
    const float dm_raw_rad_s = 1.0f;
    const float dm_processed_deg_s = dm_raw_rad_s / kDegToRad;
    if (!Near(dm_processed_deg_s * kDegToRad, dm_raw_rad_s)) return 3;
    if (!Near(WrapError((359.0f - 1.0f) * kDegToRad), -2.0f * kDegToRad)) return 4;

    // 教学对象：角加速度 = 2*u，rad/s^2；输出限制为 [-3, 3] U。
    SMC::PositionConfig ordinary;
    ordinary.input_gain = 2.0f;
    ordinary.surface_gain = 4.0f;
    ordinary.reaching_gain = 6.0f;
    ordinary.switching_gain = 2.0f;
    ordinary.boundary_width = 0.25f;
    const float dt = 0.001f; // 教学采样间隔；实际工程应使用本拍控制间隔。

    // Yaw 普通位置；实例放在循环外，Init 只在配置阶段执行。
    SMC::Position yaw;
    if (!yaw.Init(ordinary, -3.0f, 3.0f)) return 5;
    const SMC::PositionInput yaw_input = StationaryTarget(0.0f, 0.0f, 0.1f);
    float yaw_command = 0.0f;
    if (!yaw.Calc(yaw_input, yaw_command) || !Near(yaw_command, 2.2f)) return 6;

    // Yaw 的两个独立比较方案；实机一次只选择一个方案给同一轴发命令。
    SMC::PowerPositionConfig power;
    power.input_gain = ordinary.input_gain;
    power.surface_gain = ordinary.surface_gain;
    power.reaching_gain = ordinary.reaching_gain;
    power.power_gain = 2.0f;
    power.exponent = 0.5f;
    power.boundary_width = ordinary.boundary_width;
    SMC::PowerPosition yaw_power;
    float power_command = 0.0f;
    if (!yaw_power.Init(power, -3.0f, 3.0f) ||
        !yaw_power.Calc(yaw_input, power_command)) return 7;

    SMC::TerminalPositionConfig terminal;
    terminal.input_gain = ordinary.input_gain;
    terminal.linear_surface_gain = 4.0f;
    terminal.terminal_gain = 2.0f;
    terminal.exponent = 0.5f;
    terminal.reaching_gain = ordinary.reaching_gain;
    terminal.switching_gain = ordinary.switching_gain;
    terminal.boundary_width = ordinary.boundary_width;
    terminal.transition_width = 0.25f;
    SMC::TerminalPosition yaw_terminal;
    float terminal_command = 0.0f;
    if (!yaw_terminal.Init(terminal, -3.0f, 3.0f) ||
        !yaw_terminal.Calc(yaw_input, terminal_command)) return 8;

    // Pitch 和拨弹定位：各自有独立的误差累计状态。
    SMC::IntegralPositionConfig integral;
    integral.input_gain = ordinary.input_gain;
    integral.surface_gain = ordinary.surface_gain;
    integral.integral_gain = 2.0f;
    integral.reaching_gain = ordinary.reaching_gain;
    integral.switching_gain = ordinary.switching_gain;
    integral.boundary_width = ordinary.boundary_width;
    SMC::IntegralPosition pitch, feeder;
    if (!pitch.Init(integral, -3.0f, 3.0f) || !feeder.Init(integral, -3.0f, 3.0f)) return 9;
    float pitch_command = 0.0f, feeder_command = 0.0f;
    if (!pitch.Calc(yaw_input, dt, pitch_command) || !Near(pitch_command, 2.3006f)) return 10;
    if (!feeder.Calc(StationaryTarget(0.0f, 0.0f, 0.3f), dt, feeder_command)) return 11;
    if (!Near(pitch.GetErrorIntegral(), -0.0001f) ||
        !Near(feeder.GetErrorIntegral(), -0.0003f)) return 12;

    // 摩擦轮和底盘轮速：目标、反馈单位都是 rad/s。
    SMC::VelocityConfig velocity;
    velocity.input_gain = ordinary.input_gain;
    velocity.surface_gain = ordinary.surface_gain;
    velocity.reaching_gain = ordinary.reaching_gain;
    velocity.switching_gain = ordinary.switching_gain;
    velocity.boundary_width = ordinary.boundary_width;
    SMC::Velocity friction, chassis;
    if (!friction.Init(velocity, -3.0f, 3.0f) || !chassis.Init(velocity, -3.0f, 3.0f)) return 13;
    SMC::VelocityInput speed_input;
    speed_input.target = 1.0f;
    speed_input.target_acceleration = 0.0f;
    speed_input.measurement = 0.0f;
    speed_input.dt = dt;
    float friction_command = 0.0f, chassis_command = 0.0f;
    if (!friction.Calc(speed_input, friction_command) || !Near(friction_command, 3.0f)) return 14;
    speed_input.target = -1.0f;
    if (!chassis.Calc(speed_input, chassis_command) || !Near(chassis_command, -3.0f)) return 15;

    // 停机时调用方还必须发送停止命令；Reset 自身不会修改外部命令。
    if (!friction.Reset() || !Near(friction.GetErrorIntegral(), 0.0f) ||
        !Near(friction_command, 3.0f)) return 16;
    friction_command = 0.0f; // 本主机示例没有驱动，实机须落实到驱动发送。

    std::printf("HOST ONLY: units/wrap/5 controller types/separate states/reset PASS\n");
    std::printf("teaching U: yaw=%.6f power=%.6f terminal=%.6f pitch=%.6f feeder=%.6f chassis=%.6f\n",
                yaw_command, power_command, terminal_command, pitch_command, feeder_command, chassis_command);
    return 0;
}
