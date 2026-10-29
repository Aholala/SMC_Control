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
         * 参数在初始化/更新时检查，计算末尾检查请求结果后提交。
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
    /** 速度滑模参数；Q为角度单位，U为输出单位，时间单位s。无实机默认值。 */
    struct VelocityConfig
    {
        float input_gain = 0.0f;      // Q/(s^2*U)，有限非零，允许负值。
        float surface_gain = 0.0f;    // 1/s，有限且>0，乘速度误差累计值。
        float reaching_gain = 0.0f;   // 1/s，有限且>=0。
        float switching_gain = 0.0f;  // Q/s^2，有限且>=0；两个趋近增益不能同时为零。
        float boundary_width = 0.0f;  // Q/s，有限且>0。
    };

    struct VelocityInput
    {
        float target = 0.0f;               // 目标角速度，Q/s。
        float target_acceleration = 0.0f;  // 目标角速度的一次变化率，Q/s^2；调用方显式提供。
        float measurement = 0.0f;          // 实际角速度，Q/s；与目标对应同一时刻。
        float dt = 0.0f;                   // 本次累计代表的时间间隔s，有限且>0。
    };

    /** 最近一次成功计算的诊断；只有HasResult()==true时有效。 */
    struct VelocityResult
    {
        float error = 0.0f;             // 实际速度-目标速度，Q/s。
        float error_integral = 0.0f;    // 本次速度误差累计状态，Q。
        float sliding_variable = 0.0f;  // error + c*error_integral，Q/s。
        float requested_output = 0.0f;  // 限幅前请求，U。
        float output = 0.0f;            // 最终输出，U。
        bool limited = false;          // 输出请求是否确实被改变。
    };

    /**
     * s=e+c*z；u=(target_acceleration-c*e-k*s-epsilon*sat(s/phi))/b。
     * 每次成功Calc先累计z+e*dt，再计算s与输出；调用一次推进一次。
     * 核心不读取时钟、不发送设备命令。同一实例串行调用，不同实例状态独立。
     */
    class Velocity
    {
    public:
        Velocity() = default;
        // 输出范围有限且min<=max；初始累计为0，不附加累计限幅策略。
        bool Init(const VelocityConfig& config, float output_min, float output_max);
        // 成功改参/输出范围保留累计状态、清除诊断。
        bool SetParameters(const VelocityConfig& config);
        bool SetLimits(float output_min, float output_max);
        // 保留配置与输出范围，累计清零、诊断失效，不改外部command。
        bool Reset();
        // 只检查初始化、正dt及最终请求/累计；失败保持状态和command。
        bool Calc(const VelocityInput& input, float& command);

        bool IsInitialized() const { return initialized_; }
        bool HasResult() const { return has_result_; }
        const VelocityConfig& GetConfig() const { return config_; }
        const VelocityResult& GetResult() const { return result_; }
        float GetErrorIntegral() const { return error_integral_; }
        float GetOutputMin() const { return output_min_; }
        float GetOutputMax() const { return output_max_; }

    private:
        VelocityConfig config_;
        VelocityResult result_;
        float error_integral_ = 0.0f;
        float output_min_ = 0.0f;
        float output_max_ = 0.0f;
        bool initialized_ = false;
        bool has_result_ = false;
        void ClearResult();
    };
    /** 位置误差累计：z单位Q*s，c1单位1/s，c2单位1/s^2。 */
    struct IntegralPositionConfig
    {
        float input_gain = 0.0f;
        float surface_gain = 0.0f;     // c1>0。
        float integral_gain = 0.0f;    // c2>=0；为0时输出公式退化为普通位置。
        float reaching_gain = 0.0f;
        float switching_gain = 0.0f;
        float boundary_width = 0.0f;
    };
    struct IntegralPositionResult
    {
        float error = 0.0f;
        float error_rate = 0.0f;
        float error_integral = 0.0f;
        float sliding_variable = 0.0f;
        float requested_output = 0.0f;
        float output = 0.0f;
        bool limited = false;
    };
    class IntegralPosition
    {
    public:
        bool Init(const IntegralPositionConfig& config, float output_min, float output_max);
        bool SetParameters(const IntegralPositionConfig& config);
        bool SetLimits(float output_min, float output_max);
        bool Reset();
        // 先z+=e*dt；无累计限幅/冻结。失败保持状态与command。
        bool Calc(const PositionInput& input, float dt, float& command);
        bool IsInitialized() const { return initialized_; }
        bool HasResult() const { return has_result_; }
        const IntegralPositionConfig& GetConfig() const { return config_; }
        const IntegralPositionResult& GetResult() const { return result_; }
        float GetErrorIntegral() const { return error_integral_; }
        float GetOutputMin() const { return output_min_; }
        float GetOutputMax() const { return output_max_; }
    private:
        IntegralPositionConfig config_;
        IntegralPositionResult result_;
        float error_integral_ = 0.0f;
        float output_min_ = 0.0f, output_max_ = 0.0f;
        bool initialized_ = false, has_result_ = false;
        void ClearResult();
    };

    /** 混合趋近：-K*s - G*|s|^a*sat(s/phi)，不把两项共用同一系数。 */
    struct PowerPositionConfig
    {
        float input_gain = 0.0f;
        float surface_gain = 0.0f;    // c>0，1/s。
        float reaching_gain = 0.0f;   // K>=0，1/s。
        float power_gain = 0.0f;      // G>=0，Q^(1-a)/s^(2-a)；K和G不能同时为0。
        float exponent = 0.0f;        // a>0；仅在G>0、0<a<1等理想条件下讨论有限到达。
        float boundary_width = 0.0f;  // phi>0，Q/s。
    };
    class PowerPosition
    {
    public:
        bool Init(const PowerPositionConfig& config, float output_min, float output_max);
        bool SetParameters(const PowerPositionConfig& config);
        bool SetLimits(float output_min, float output_max);
        bool Reset();
        bool Calc(const PositionInput& input, float& command);
        bool IsInitialized() const { return initialized_; }
        bool HasResult() const { return has_result_; }
        const PowerPositionConfig& GetConfig() const { return config_; }
        const PositionResult& GetResult() const { return result_; }
        float GetOutputMin() const { return output_min_; }
        float GetOutputMax() const { return output_max_; }
    private:
        PowerPositionConfig config_;
        PositionResult result_;
        float output_min_ = 0.0f, output_max_ = 0.0f;
        bool initialized_ = false, has_result_ = false;
        void ClearResult();
    };

    /** 终端/普通分段：|e|<transition_width先进入普通分支，避免计算零处负幂。
     * 系数和阈值均由使用项目提供；分段控制不承诺全程有限时间到零。
     */
    struct TerminalPositionConfig
    {
        float input_gain = 0.0f;
        float linear_surface_gain = 0.0f; // c>0，1/s，内区普通位置系数。
        float terminal_gain = 0.0f;       // beta>0，Q^(1-a)/s。
        float exponent = 0.0f;            // 0<a<1。
        float reaching_gain = 0.0f;
        float switching_gain = 0.0f;
        float boundary_width = 0.0f;
        float transition_width = 0.0f;    // delta>0，Q；等于阈值时使用终端分支。
    };
    struct TerminalPositionResult
    {
        float error = 0.0f;
        float error_rate = 0.0f;
        float sliding_variable = 0.0f;
        float requested_output = 0.0f;
        float output = 0.0f;
        bool limited = false;
        bool terminal_branch = false;
    };
    class TerminalPosition
    {
    public:
        bool Init(const TerminalPositionConfig& config, float output_min, float output_max);
        bool SetParameters(const TerminalPositionConfig& config);
        bool SetLimits(float output_min, float output_max);
        bool Reset();
        bool Calc(const PositionInput& input, float& command);
        bool IsInitialized() const { return initialized_; }
        bool HasResult() const { return has_result_; }
        const TerminalPositionConfig& GetConfig() const { return config_; }
        const TerminalPositionResult& GetResult() const { return result_; }
        float GetOutputMin() const { return output_min_; }
        float GetOutputMax() const { return output_max_; }
    private:
        TerminalPositionConfig config_;
        TerminalPositionResult result_;
        float output_min_ = 0.0f, output_max_ = 0.0f;
        bool initialized_ = false, has_result_ = false;
        void ClearResult();
    };

}

#endif
