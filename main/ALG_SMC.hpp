#ifndef ALG_SMC_HPP
#define ALG_SMC_HPP

namespace SMC
{
    /**
     * 普通位置滑模参数。时间单位为 s；Q 为角度单位，U 为输出单位。
     * 模型：position_ddot = input_gain * command + acceleration_disturbance。
     * 参数无机器人默认值，默认配置无效，须由调用方填写。
     */
    struct PositionConfig
    {
        float input_gain = 0.0f;      // Q/(s^2*U)，有限且非零，允许负值。
        float surface_gain = 0.0f;    // 1/s，有限且 > 0。
        float reaching_gain = 0.0f;   // 1/s，有限且 >= 0。
        float switching_gain = 0.0f;  // Q/s^2，有限且 >= 0；两个趋近增益不能同时为零。
        float boundary_width = 0.0f;  // Q/s，有限且 > 0，独立于 switching_gain。
    };

    /** 当前同一时刻的数据。变化率须由调用方提供，不从目标历史推测。 */
    struct PositionInput
    {
        float target = 0.0f;               // Q。
        float target_rate = 0.0f;          // Q/s；0 表示调用方指定为零，不是自动估计。
        float target_acceleration = 0.0f;  // Q/s^2；同上。
        float measurement = 0.0f;          // Q；角度表示/跨圈由调用方处理。
        float measurement_rate = 0.0f;     // Q/s。
    };

    /** 最近一次成功计算的诊断结果；只有 HasResult() 为 true 时有效。 */
    struct PositionResult
    {
        float error = 0.0f;             // measurement - target，Q。
        float error_rate = 0.0f;        // measurement_rate - target_rate，Q/s。
        float sliding_variable = 0.0f;  // error_rate + surface_gain * error，Q/s。
        float requested_output = 0.0f;  // 限幅前请求，U。
        float output = 0.0f;            // 按调用方范围限幅后的输出，U。
        bool limited = false;          // 请求是否确实被限幅。
    };

    /**
     * 无 HAL、RTOS、通信、时钟、动态内存依赖的普通位置控制器。
     * 无差分/积分历史；每个实例独立保存配置和最近一次成功的诊断结果。
     * 同一实例串行调用。不能据连续时间公式保证任意采样周期下稳定。
     */
    class Position
    {
    public:
        Position() = default;

        // 范围须为有限数且 min <= max；允许不对称或固定输出范围。
        // 成功清除旧诊断；失败保持对象。禁止用非法配置隐式停机。
        bool Init(const PositionConfig& config, float output_min, float output_max);
        // 仅用于已初始化对象；成功保留输出范围、清除旧诊断。
        bool SetParameters(const PositionConfig& config);
        // 仅用于已初始化对象；成功保留参数、清除旧诊断。
        bool SetLimits(float output_min, float output_max);
        // 保留配置和限制，仅使旧诊断失效。没有需要重新建立的采样历史。
        bool Reset();

        /**
         * u = (target_acceleration - c*error_rate - k*s
         *      - epsilon*sat(s/phi)) / input_gain。
         * 所有输入与所需中间量须有限。先完整计算检查，再提交结果。
         * 失败返回 false，command、配置、最近一次成功结果均保持不变。
         * 调用方必须检查返回值，失败后不能把旧 command 当作本拍新命令。
         */
        bool Calc(const PositionInput& input, float& command);

        bool IsInitialized() const { return initialized_; }
        bool HasResult() const { return has_result_; }
        const PositionConfig& GetConfig() const { return config_; }
        const PositionResult& GetResult() const { return result_; }
        float GetOutputMin() const { return output_min_; }
        float GetOutputMax() const { return output_max_; }

    private:
        PositionConfig config_;
        PositionResult result_;
        float output_min_ = 0.0f;
        float output_max_ = 0.0f;
        bool initialized_ = false;
        bool has_result_ = false;

        void ClearResult();
    };
}

#endif
