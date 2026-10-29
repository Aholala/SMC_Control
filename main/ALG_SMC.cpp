#include "ALG_SMC.hpp"

#include <cmath>

namespace
{
    bool ValidConfig(const SMC::PositionConfig& c)
    {
        return std::isfinite(c.input_gain) && c.input_gain != 0.0f &&
               std::isfinite(c.surface_gain) && c.surface_gain > 0.0f &&
               std::isfinite(c.reaching_gain) && c.reaching_gain >= 0.0f &&
               std::isfinite(c.switching_gain) && c.switching_gain >= 0.0f &&
               (c.reaching_gain > 0.0f || c.switching_gain > 0.0f) &&
               std::isfinite(c.boundary_width) && c.boundary_width > 0.0f;
    }

    bool ValidLimits(float lower, float upper)
    {
        return std::isfinite(lower) && std::isfinite(upper) && lower <= upper;
    }

    bool ValidConfig(const SMC::VelocityConfig& c)
    {
        return std::isfinite(c.input_gain) && c.input_gain != 0.0f &&
               std::isfinite(c.surface_gain) && c.surface_gain > 0.0f &&
               std::isfinite(c.reaching_gain) && c.reaching_gain >= 0.0f &&
               std::isfinite(c.switching_gain) && c.switching_gain >= 0.0f &&
               (c.reaching_gain > 0.0f || c.switching_gain > 0.0f) &&
               std::isfinite(c.boundary_width) && c.boundary_width > 0.0f;
    }

}

namespace SMC
{
    void Velocity::ClearResult()
    {
        result_ = VelocityResult();
        has_result_ = false;
    }

    bool Velocity::Init(const VelocityConfig& config, float output_min, float output_max)
    {
        if (!ValidConfig(config) || !ValidLimits(output_min, output_max))
            return false;
        config_ = config;
        output_min_ = output_min;
        output_max_ = output_max;
        error_integral_ = 0.0f;
        initialized_ = true;
        ClearResult();
        return true;
    }

    bool Velocity::SetParameters(const VelocityConfig& config)
    {
        if (!initialized_ || !ValidConfig(config)) return false;
        config_ = config;
        ClearResult();
        return true;
    }

    bool Velocity::SetLimits(float output_min, float output_max)
    {
        if (!initialized_ || !ValidLimits(output_min, output_max)) return false;
        output_min_ = output_min;
        output_max_ = output_max;
        ClearResult();
        return true;
    }

    bool Velocity::Reset()
    {
        if (!initialized_) return false;
        error_integral_ = 0.0f;
        ClearResult();
        return true;
    }

    bool Velocity::Calc(const VelocityInput& input, float& command)
    {
        if (!initialized_ || !(input.dt > 0.0f))
            return false;
        VelocityResult next;
        next.error = input.measurement - input.target;
        next.error_integral = error_integral_ + next.error * input.dt;
        next.sliding_variable = next.error + config_.surface_gain * next.error_integral;
        float saturation;
        if (next.sliding_variable >= config_.boundary_width) saturation = 1.0f;
        else if (next.sliding_variable <= -config_.boundary_width) saturation = -1.0f;
        else saturation = next.sliding_variable / config_.boundary_width;
        const float error_term = config_.surface_gain * next.error;
        const float reaching_term = config_.reaching_gain * next.sliding_variable;
        const float switching_term = config_.switching_gain * saturation;
        float acceleration = input.target_acceleration - error_term;
        acceleration -= reaching_term;
        acceleration -= switching_term;
        next.requested_output = acceleration / config_.input_gain;
        if (!std::isfinite(next.requested_output) || !std::isfinite(next.error_integral)) return false;
        next.output = next.requested_output;
        if (next.output < output_min_) next.output = output_min_;
        else if (next.output > output_max_) next.output = output_max_;
        next.limited = next.output != next.requested_output;
        // 结果检查后一起提交累计和诊断。
        error_integral_ = next.error_integral;
        result_ = next;
        has_result_ = true;
        command = next.output;
        return true;
    }
}

namespace SMC
{
    void Position::ClearResult()
    {
        result_ = PositionResult();
        has_result_ = false;
    }

    bool Position::Init(const PositionConfig& config, float output_min, float output_max)
    {
        if (!ValidConfig(config) || !ValidLimits(output_min, output_max))
            return false;
        config_ = config;
        output_min_ = output_min;
        output_max_ = output_max;
        initialized_ = true;
        ClearResult();
        return true;
    }

    bool Position::SetParameters(const PositionConfig& config)
    {
        if (!initialized_ || !ValidConfig(config))
            return false;
        config_ = config;
        ClearResult();
        return true;
    }

    bool Position::SetLimits(float output_min, float output_max)
    {
        if (!initialized_ || !ValidLimits(output_min, output_max))
            return false;
        output_min_ = output_min;
        output_max_ = output_max;
        ClearResult();
        return true;
    }

    bool Position::Reset()
    {
        if (!initialized_)
            return false;
        ClearResult();
        return true;
    }

    bool Position::Calc(const PositionInput& input, float& command)
    {
        if (!initialized_)
            return false;

        PositionResult next;
        next.error = input.measurement - input.target;
        next.error_rate = input.measurement_rate - input.target_rate;
        const float position_term = config_.surface_gain * next.error;
        next.sliding_variable = next.error_rate + position_term;
        // 先比较再除，避免非常小的 phi 使 s/phi 溢出。
        float saturation;
        if (next.sliding_variable >= config_.boundary_width)
            saturation = 1.0f;
        else if (next.sliding_variable <= -config_.boundary_width)
            saturation = -1.0f;
        else
            saturation = next.sliding_variable / config_.boundary_width;

        const float rate_term = config_.surface_gain * next.error_rate;
        const float reaching_term = config_.reaching_gain * next.sliding_variable;
        const float switching_term = config_.switching_gain * saturation;
        float acceleration = input.target_acceleration - rate_term;
        acceleration -= reaching_term;
        acceleration -= switching_term;

        next.requested_output = acceleration / config_.input_gain;
        if (!std::isfinite(next.requested_output))
            return false;

        next.output = next.requested_output;
        if (next.output < output_min_)
            next.output = output_min_;
        else if (next.output > output_max_)
            next.output = output_max_;
        next.limited = next.output != next.requested_output;

        result_ = next;
        has_result_ = true;
        command = next.output;
        return true;
    }
}

namespace
{
    bool ValidConfig(const SMC::IntegralPositionConfig& c)
    {
        return std::isfinite(c.input_gain) && c.input_gain != 0 &&
               std::isfinite(c.surface_gain) && c.surface_gain > 0 &&
               std::isfinite(c.integral_gain) && c.integral_gain >= 0 &&
               std::isfinite(c.reaching_gain) && c.reaching_gain >= 0 &&
               std::isfinite(c.switching_gain) && c.switching_gain >= 0 &&
               (c.reaching_gain > 0 || c.switching_gain > 0) &&
               std::isfinite(c.boundary_width) && c.boundary_width > 0;
    }
    bool ValidConfig(const SMC::PowerPositionConfig& c)
    {
        return std::isfinite(c.input_gain) && c.input_gain != 0 &&
               std::isfinite(c.surface_gain) && c.surface_gain > 0 &&
               std::isfinite(c.reaching_gain) && c.reaching_gain >= 0 &&
               std::isfinite(c.power_gain) && c.power_gain >= 0 &&
               (c.reaching_gain > 0 || c.power_gain > 0) &&
               std::isfinite(c.exponent) && c.exponent > 0 &&
               std::isfinite(c.boundary_width) && c.boundary_width > 0;
    }
    bool ValidConfig(const SMC::TerminalPositionConfig& c)
    {
        return std::isfinite(c.input_gain) && c.input_gain != 0 &&
               std::isfinite(c.linear_surface_gain) && c.linear_surface_gain > 0 &&
               std::isfinite(c.terminal_gain) && c.terminal_gain > 0 &&
               std::isfinite(c.exponent) && c.exponent > 0 && c.exponent < 1 &&
               std::isfinite(c.reaching_gain) && c.reaching_gain >= 0 &&
               std::isfinite(c.switching_gain) && c.switching_gain >= 0 &&
               (c.reaching_gain > 0 || c.switching_gain > 0) &&
               std::isfinite(c.boundary_width) && c.boundary_width > 0 &&
               std::isfinite(c.transition_width) && c.transition_width > 0;
    }
    float ExtensionSat(float s, float width)
    {
        if (s >= width) return 1;
        if (s <= -width) return -1;
        return s / width;
    }
    float ExtensionLimit(float value, float lower, float upper)
    {
        if (value < lower) return lower;
        if (value > upper) return upper;
        return value;
    }
}
namespace SMC
{

    void IntegralPosition::ClearResult() { result_ = IntegralPositionResult(); has_result_ = false; }
    bool IntegralPosition::Init(const IntegralPositionConfig& config, float lower, float upper)
    {
        if (!ValidConfig(config) || !ValidLimits(lower, upper)) return false;
        config_ = config; output_min_ = lower; output_max_ = upper;
        error_integral_ = 0;
        initialized_ = true; ClearResult(); return true;
    }
    bool IntegralPosition::SetParameters(const IntegralPositionConfig& config)
    {
        if (!initialized_ || !ValidConfig(config)) return false;
        config_ = config; ClearResult(); return true;
    }
    bool IntegralPosition::SetLimits(float lower, float upper)
    {
        if (!initialized_ || !ValidLimits(lower, upper)) return false;
        output_min_ = lower; output_max_ = upper; ClearResult(); return true;
    }
    bool IntegralPosition::Reset()
    {
        if (!initialized_) return false;
        error_integral_ = 0;
        ClearResult(); return true;
    }

    void PowerPosition::ClearResult() { result_ = PositionResult(); has_result_ = false; }
    bool PowerPosition::Init(const PowerPositionConfig& config, float lower, float upper)
    {
        if (!ValidConfig(config) || !ValidLimits(lower, upper)) return false;
        config_ = config; output_min_ = lower; output_max_ = upper;

        initialized_ = true; ClearResult(); return true;
    }
    bool PowerPosition::SetParameters(const PowerPositionConfig& config)
    {
        if (!initialized_ || !ValidConfig(config)) return false;
        config_ = config; ClearResult(); return true;
    }
    bool PowerPosition::SetLimits(float lower, float upper)
    {
        if (!initialized_ || !ValidLimits(lower, upper)) return false;
        output_min_ = lower; output_max_ = upper; ClearResult(); return true;
    }
    bool PowerPosition::Reset()
    {
        if (!initialized_) return false;

        ClearResult(); return true;
    }

    void TerminalPosition::ClearResult() { result_ = TerminalPositionResult(); has_result_ = false; }
    bool TerminalPosition::Init(const TerminalPositionConfig& config, float lower, float upper)
    {
        if (!ValidConfig(config) || !ValidLimits(lower, upper)) return false;
        config_ = config; output_min_ = lower; output_max_ = upper;

        initialized_ = true; ClearResult(); return true;
    }
    bool TerminalPosition::SetParameters(const TerminalPositionConfig& config)
    {
        if (!initialized_ || !ValidConfig(config)) return false;
        config_ = config; ClearResult(); return true;
    }
    bool TerminalPosition::SetLimits(float lower, float upper)
    {
        if (!initialized_ || !ValidLimits(lower, upper)) return false;
        output_min_ = lower; output_max_ = upper; ClearResult(); return true;
    }
    bool TerminalPosition::Reset()
    {
        if (!initialized_) return false;

        ClearResult(); return true;
    }

    bool IntegralPosition::Calc(const PositionInput& input, float dt, float& command)
    {
        if (!initialized_ || !(dt > 0)) return false;
        IntegralPositionResult next;
        next.error = input.measurement - input.target;
        next.error_rate = input.measurement_rate - input.target_rate;
        next.error_integral = error_integral_ + next.error * dt;
        next.sliding_variable = next.error_rate + config_.surface_gain * next.error
                                + config_.integral_gain * next.error_integral;
        float acceleration = input.target_acceleration - config_.surface_gain * next.error_rate;
        acceleration -= config_.integral_gain * next.error;
        acceleration -= config_.reaching_gain * next.sliding_variable;
        acceleration -= config_.switching_gain * ExtensionSat(next.sliding_variable, config_.boundary_width);
        next.requested_output = acceleration / config_.input_gain;
        if (!std::isfinite(next.requested_output) || !std::isfinite(next.error_integral)) return false;
        next.output = ExtensionLimit(next.requested_output, output_min_, output_max_);
        next.limited = next.output != next.requested_output;
        error_integral_ = next.error_integral; result_ = next; has_result_ = true; command = next.output;
        return true;
    }
    bool PowerPosition::Calc(const PositionInput& input, float& command)
    {
        if (!initialized_) return false;
        PositionResult next;
        next.error = input.measurement - input.target;
        next.error_rate = input.measurement_rate - input.target_rate;
        next.sliding_variable = next.error_rate + config_.surface_gain * next.error;
        const float power = std::pow(std::fabs(next.sliding_variable), config_.exponent);
        float acceleration = input.target_acceleration - config_.surface_gain * next.error_rate;
        acceleration -= config_.reaching_gain * next.sliding_variable;
        acceleration -= config_.power_gain * power * ExtensionSat(next.sliding_variable, config_.boundary_width);
        next.requested_output = acceleration / config_.input_gain;
        if (!std::isfinite(next.requested_output)) return false;
        next.output = ExtensionLimit(next.requested_output, output_min_, output_max_);
        next.limited = next.output != next.requested_output;
        result_ = next; has_result_ = true; command = next.output; return true;
    }
    bool TerminalPosition::Calc(const PositionInput& input, float& command)
    {
        if (!initialized_) return false;
        TerminalPositionResult next;
        next.error = input.measurement - input.target;
        next.error_rate = input.measurement_rate - input.target_rate;
        const float magnitude = std::fabs(next.error);
        float surface_term, derivative;
        // 先选分支：内区根本不计算|e|^(a-1)或1/e，等于阈值走终端分支。
        next.terminal_branch = !(magnitude < config_.transition_width);
        if (next.terminal_branch)
        {
            surface_term = config_.terminal_gain * std::pow(magnitude, config_.exponent);
            if (next.error < 0) surface_term = -surface_term;
            derivative = config_.terminal_gain * config_.exponent * std::pow(magnitude, config_.exponent - 1.0f);
        }
        else
        {
            surface_term = config_.linear_surface_gain * next.error;
            derivative = config_.linear_surface_gain;
        }
        next.sliding_variable = next.error_rate + surface_term;
        float acceleration = input.target_acceleration - derivative * next.error_rate;
        acceleration -= config_.reaching_gain * next.sliding_variable;
        acceleration -= config_.switching_gain * ExtensionSat(next.sliding_variable, config_.boundary_width);
        next.requested_output = acceleration / config_.input_gain;
        if (!std::isfinite(next.requested_output)) return false;
        next.output = ExtensionLimit(next.requested_output, output_min_, output_max_);
        next.limited = next.output != next.requested_output;
        result_ = next; has_result_ = true; command = next.output; return true;
    }
}
