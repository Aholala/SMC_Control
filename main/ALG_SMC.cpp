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
        if (!initialized_ || !std::isfinite(input.target) ||
            !std::isfinite(input.target_rate) || !std::isfinite(input.target_acceleration) ||
            !std::isfinite(input.measurement) || !std::isfinite(input.measurement_rate))
            return false;

        PositionResult next;
        next.error = input.measurement - input.target;
        next.error_rate = input.measurement_rate - input.target_rate;
        if (!std::isfinite(next.error) || !std::isfinite(next.error_rate))
            return false;

        const float position_term = config_.surface_gain * next.error;
        next.sliding_variable = next.error_rate + position_term;
        if (!std::isfinite(position_term) || !std::isfinite(next.sliding_variable))
            return false;

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
        if (!std::isfinite(rate_term) || !std::isfinite(reaching_term) ||
            !std::isfinite(switching_term))
            return false;

        float acceleration = input.target_acceleration - rate_term;
        if (!std::isfinite(acceleration))
            return false;
        acceleration -= reaching_term;
        if (!std::isfinite(acceleration))
            return false;
        acceleration -= switching_term;
        if (!std::isfinite(acceleration))
            return false;

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
