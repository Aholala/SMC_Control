# ECF27 电机滑模控制接入教程

本教程根据 2026-10-30 实际读取的 `D:/ACE/ACE_ECF_27` 电机源码编写，对接当前 SMC 库。目标是让你从“控制哪个量”走到“取哪个反馈、调用哪个控制器、怎样下发命令”。

教程和主机示例保存在 SMC 仓库；本轮未修改 ECF27 驱动、实际电机配置或 SMC 生产算法。详细函数、版本及限制见[接口核查记录](ECF27电机接口核查记录.md)。当前读到的是电机库，不能据此确定你实车上每个部位的型号和参数。

建议第一次按第1～4节读，随后只选一个实际部位阅读第5节，再对照第6节的电机接口。先建立一台电机的完整输入输出关系，再扩展到其他电机。

## 1. 先分清控制任务和电机型号

**位置控制**是让机构到达并保持指定位置，例如把云台转到某个角度，或让拨弹轮转过一格。**速度控制**是让机构保持指定运动速度，例如摩擦轮持续旋转。

**反馈**是传感器实际测得、返回给控制器的量。位置控制在这里使用实际角度和实际角速度；速度控制使用实际角速度。两者都还需要目标、参数和输出范围。

Yaw 指云台水平转向轴；Pitch 指云台俯仰轴。它们是机构部位，不是电机型号。M3508、M2006、GM6020、DM4310 等才是电机类型。同一型号用于不同机构时，目标和负载不同，控制参数也会不同。

例如：同一台 M2006，要求“转过一格停住”是位置控制；要求“一直以某转速旋转”是速度控制。不能只看 M2006 这个名字选择算法。

## 2. 你列的五种名称怎样对应当前库

**误差**是实际值与目标值之差。这里统一取“实际减目标”。**误差累计**是把每拍误差乘以经过的时间，再逐次相加。

**滑模变量 s**是把误差及其变化、累计等按权重组合成的数。**滑模面**是满足 `s=0` 的关系。**趋近律**规定 s 怎样向0靠近；它与选取哪一种滑模面是两个独立的设计部分。指数趋近律和幂次趋近律的常见定义可对照 [MathWorks 的说明](https://www.mathworks.com/help/slcontrol/ug/design-sliding-mode-control-reaching-law.html)。

下表中 e 是位置误差，v 是实际角速度减目标角速度，z 是位置误差累计，c、c1、c2 是组合权重。速度一行另用 ev、zv 表示速度误差及其累计。

| 参考名称 | 当前库类名 | 关系与准确说法 | 部位使用起点 |
| --- | --- | --- | --- |
| EXPONENT | `SMC::Position` | `s=v+c*e`；指数趋近律 | Yaw 普通位置控制的对照起点 |
| POWER | `SMC::PowerPosition` | 同一线性滑模面；线性项与幂次项混合趋近 | 在同一 Yaw 上与普通形式比较 |
| EISMC | `SMC::IntegralPosition` | `s=v+c1*e+c2*z`；指数趋近律；还包含速度差，不只有比例和积分 | Pitch、按转角拨弹 |
| TFSMC | `SMC::TerminalPosition`，为调整后的对应形式 | 大误差用带符号分数幂，小误差切回普通关系 | 理解零附近及切换行为后再比较 |
| VELSMC | `SMC::Velocity` | `s=ev+c*zv`；指数趋近律 | 摩擦轮、底盘轮速、连续拨弹速度 |

这里的**带符号分数幂**是保留误差正负号再对绝对值求分数次幂，例如 `sign(e)*sqrt(abs(e))`；sign 在正数时为1、负数时为−1、0时为0。**终端滑模**通过这样的非线性误差关系研究理想条件下的有限时间收敛。当前类采用分段关系，不能直接称为已经保证全程有限时间收敛的“快速终端滑模”。详见[第26讲](26_有限时间面内关系.md)、[第27讲](27_零附近与分段切换.md)。

你列的部位分配可以作为参考项目的经验起点，但“Yaw 推荐/较推荐/较不推荐”不是跨机器人通用排名。本教程建议先在同一机构上建立普通形式的记录，再比较其他形式；没有实车比较结果时，不预先宣布某种形式更好。

## 3. 从控制器到电机，中间究竟连接什么

**控制命令 u**是算法计算后交给驱动的数。它可能表示力矩、电流或协议原始命令值，取决于最后接哪个接口。**力矩**是使轴旋转的作用量，单位 N·m；电流单位 A，两者不能直接当作同一个数。

**闭环**是测量影响下一次命令的控制过程。下面的反馈路径闭合后，外部 SMC 就已经构成位置或速度闭环。

```mermaid
flowchart LR
    T[目标与目标变化率] --> C[SMC 计算]
    F[同一坐标下的角度与速度] --> C
    C --> U[明确单位的命令]
    U --> A[方向与电机接口适配]
    A --> M[驱动发送与电机运动]
    M --> S[反馈采集及单位换算]
    S --> F
```

原框架的 **PID** 是把误差、误差累计和误差变化组合计算输出的另一种反馈控制方法；其位置、速度控制可能前后串联计算，这称为串级控制。

当前 SMC 位置类计算的是使角度运动改变的驱动命令，不是“下一层的目标速度”。因此本教程采用：SMC 替代原软件的位置/速度计算，直接给力矩、电流或原始命令接口。驱动里的电流调节可以保留；不要把位置 SMC 的力矩结果直接写入仍在运行的速度 PID 目标。

GM6020 示例中的 `OPEN_LOOP` 只表示框架内不再算软件 PID；外部 SMC 仍通过测量形成闭环。

### 3.1 input_gain 是什么，为什么不能统一写成1

**输入增益 b**是单位命令引起多大角加速度。当前算法用的简化运动关系是：

```text
角加速度 = b*u + d
```

d 表示外力、摩擦及其他未单独计算影响折算出的角加速度。角度使用 rad、时间使用 s；U 代表选定的输出单位，因此 b 的单位是 `rad/(s²·U)`。

**等效转动惯量 J**表示所控制轴及其带动负载对加速的阻碍程度。当 u 是同一轴上的力矩、关系可近似写成 `J*角加速度=u+外力矩` 时，才有 `b=1/J`。当 u 是电流时，还需要电流到该轴力矩的换算；当 u 是 GM6020 原始命令时，b 是该原始命令到角加速度的有效增益，不能直接填1/J。

每个实例的 b 都应对应“本教程适配后实际发送的整条路径”。真实值通过已有模型或测量取得，本教程不提供机器人默认值。尤其 GM6020 原始电压命令的有效运动关系可能随转速、供电和负载变化，静态 b 只是近似，需在实际工作范围验证。

## 4. 先把反馈变成一致的单位和坐标

**弧度 rad**是角度单位，一圈为2π rad、也就是360°；**rpm**表示每分钟转数。因此度乘π/180变成rad，rpm乘2π/60变成rad/s。

**减速比 N**在本教程定义为“电机转子转角 ÷ 所控制轴转角”，取正值；它不替代安装方向。若反馈已经是所控制轴的数据，就不再除同一减速比。

### 4.1 各驱动的实际反馈

| 驱动 | 可用字段 | 进入本教程 SMC 前的处理 |
| --- | --- | --- |
| DJI | `motor_raw_data.feedback_speed` | 原始rpm，`速度 = rpm*2*pi/60/N` |
| DJI | `motor_processed_data.total_angle` | 度，源码已除配置ratio；乘π/180得到配置输出轴的累计角度 |
| DM | `motor_raw_data.feedback_speed` | 已是rad/s，协议轴一致时直接用 |
| DM | `motor_processed_data.speed` | 度每秒，乘π/180；不要与上一行重复换算 |
| DM | `motor_processed_data.total_angle` | 度，乘π/180；适合需要跨圈累计的位置 |
| Cybergear | `motor_raw_data.position`、`feedback_speed` | 当前回调位置按±720的度尺度解码、速度为rad/s；位置乘π/180，并先确认实机尺度及零点 |
| VESC | `data().erpm` | 先按极对数及外部减速比换算，见下文 |
| C615 | 无转速测量字段 | 需要额外测速设备，不能只凭百分比指令形成速度闭环 |

表中字段前缀是 `motor.motor_data_.`，VESC 除外。**累计角度**是跨过一圈后继续增减、不会每圈回到0的角度。

DJI 当前 `motor_processed_data.speed` 的执行式会把旧滤波值再次除以ratio；单圈相对角度字段也有重复除ratio的路径。本教程避免依赖这些字段，使用原始rpm换算速度、使用总角度定位，原因及式子见[核查记录第3节](ECF27电机接口核查记录.md#3-dji-反馈中需要特别区分的执行式)。

DM 的上述反馈是协议报告轴的数据，解析时不按 `motor_fixed_param.ratio` 再除一次。内置减速是否已经包含在协议量中，按对应电机和驱动配置确认；只有协议轴之外确实另加了传动，才另外换算。

**电转速 ERPM**表示电机磁场周期的转速；**极对数 p**是转子磁极的成对数量。机械转速是ERPM/p，再除外部减速比N，得到所控制轴转速：

```text
VESC输出轴角速度 = erpm / p / N * 2*pi/60
```

例如仅为手算，假设p=7、N=2，ERPM=420，那么输出轴为30rpm，即π rad/s。p和N必须来自你的电机配置。可对照 [VESC Tool 官方源码](https://github.com/vedderb/vesc_tool/blob/master/vescinterface.cpp) 的极数与机械量换算。

### 4.2 角度与速度必须描述同一种运动

**坐标**在这里指角度从哪里算零、朝哪里算正，以及相对谁测量。机械编码器通常描述轴相对底座的位置；**惯性测量单元 IMU**提供传感器姿态和转动测量，可用于描述云台相对外部空间的运动。

Yaw 要保持“相对底盘的角度”时，角度和速度应对应相对运动；要保持“相对外部空间的方向”时，两者应对应空间方向变化。不能只把角度换成IMU读数，却继续把电机相对底座速度当成同一角度的变化率。

IMU 的传感器轴速度也不一定直接等于所选 Yaw/Pitch 角度的变化率，具体还取决于安装和姿态定义。本教程不猜你的IMU轴映射，由使用项目提供一致的 `measurement` 和 `measurement_rate`。

### 4.3 零点、方向和跨圈

固定零点偏移可以写成 `实际角度 = 方向符号*(换算角度-标定零点)`；方向符号取+1或−1。速度应用相同坐标方向。输出方向也需要适配，并与所识别的b一致；不要一边在适配中反向，又重复把b反向以抵消同一次转换。

**最短角度误差**是允许两种方向旋转时，把角度差折回半圈以内。例如实际359°、目标1°，误差可表示为−2°，而不是358°。当前SMC不自动折回；允许最短转向的Yaw可在调用前处理：

```cpp
// WrapError 见完整主机示例，返回 [-pi, pi)。
input.target = target_angle_rad;
input.measurement = target_angle_rad + WrapError(actual_angle_rad - target_angle_rad);
```

这里只改变传给控制器的等价角度，速度仍使用同坐标的真实变化率。恰好半圈、绕线限制和可选转向由机构逻辑决定。Pitch 有机械行程时，以及拨弹轮需要累计转过多格时，使用允许范围内的累计目标，不套最短路径折回。

## 5. 按部位一步一步接

**初始化 Init**是给实例设置参数和输出范围。**实例**是一个独立控制器对象；它保存自己的配置和累计状态。每个独立电机/控制轴使用独立实例，放在周期循环外，不能每拍重新构造或Init。

以下片段中的 `*_config`、上下限、目标与测量都由项目提供；不是省略了库里的默认值。真实可编译的教学数值见[主机示例](../examples/ecf27_smc_example.cpp)。

### 5.1 Yaw：先接 Position

先选定上一节的角度坐标，再准备以下数据。**目标变化率**指目标角度每秒变化多少；**目标加速度**指目标角速度每秒变化多少。

```cpp
SMC::Position yaw;  // 长期存在，每个轴一个实例
bool configured = yaw.Init(yaw_config, yaw_output_min, yaw_output_max);

// 以下放在周期控制函数中；只在 configured 且允许控制时执行。
SMC::PositionInput input;
input.target = target_angle_rad;
input.target_rate = target_rate_rad_s;
input.target_acceleration = target_acc_rad_s2;
input.measurement = actual_angle_rad;
input.measurement_rate = actual_rate_rad_s;
float command = 0.0f;
if (yaw.Calc(input, command)) {
    // 按第6节选择一个驱动出口，把 command 发送出去。
} else {
    // 本拍不发送旧 command；进入项目已有停止分支。
}
```

初次实验可以选静止目标，明确给 `target_rate=0`、`target_acceleration=0`。这表示静止段的目标，不表示阶跃跳变瞬间在数学上也没有变化率。连续运动目标的两个变化率应与目标一起生成，不能把摇杆跳变盲目连续差分后当可靠加速度。

先检查小幅正负目标的反馈方向、最终误差和输出是否符合预期，再扩大工作范围。SMC位置输出应直接接第6节选定的命令接口。

### 5.2 Yaw：再比较 PowerPosition

**幂次趋近项**是让趋近作用按 `abs(s)` 的指定次方变化，而不是只与s成正比。当前类同时保留线性趋近项。

```cpp
SMC::PowerPosition yaw_power;
bool configured = yaw_power.Init(power_config, yaw_output_min, yaw_output_max);
// 周期中使用与普通Yaw完全一致的PositionInput：
bool ok = yaw_power.Calc(input, command);
```

比较时固定坐标、目标轨迹、输出单位、最终限值和采样方式，记录误差及输出。a=`exponent`、G=`power_gain`需要独立设置；不能把原参考的epsilon直接复制到当前 `switching_gain`。当前幂次类没有该字段。

一次只让一个控制器驱动同一Yaw；其他方案可以单独记录计算结果，但不要同时下发或将多个输出相加。

### 5.3 Pitch：IntegralPosition

Pitch 常受到随姿态变化的重力作用。这里的**位置误差累计**让持续存在的小误差参与后续输出，适合与普通位置形式比较持续外力下的表现；它不自动知道重力大小，也不能保证所有外力和限幅条件下都消除误差。

```cpp
SMC::IntegralPosition pitch;
bool configured = pitch.Init(pitch_config, pitch_output_min, pitch_output_max);
// 周期中：PositionInput 的角度、速度仍来自同一个Pitch坐标。
bool ok = pitch.Calc(input, control_dt_s, command);
```

`control_dt_s` 是本次控制累计代表的秒数。配置 `integral_gain=0` 可先对照不含累计作用的输出关系，再比较非零值。机械允许的目标范围由Pitch任务处理，库不会替你决定行程。

若已有重力补偿，即根据姿态预先给出抵消重力的命令，可以在同一输出单位下明确与SMC命令相加；须给最终总命令设置相同接口允许的范围，并在记录里区分两部分。初次接入不必同时引入这项，避免把改善来源混在一起。

### 5.4 拨弹轮：先决定定位还是连续转速

定位拨弹是把“发一发”变成“拨盘转过一格”的目标，再用位置控制到达目标。假设一个均匀分格拨盘有m个格，每格在拨盘轴上的角度是 `2*pi/m`；m和传动比来自实际机构，不能默认是某个常见格数。

可选 `IntegralPosition`，也可先以 `Position` 建立对照。使用拨盘累计角度与累计目标，每次正常拨弹给目标增加一格。误差累计是控制器内部状态，不等于“发了多少发”或“当前拨到第几格”。

连续拨弹速度模式则选 `Velocity`。定位模式和连续速度模式的切换、反转退弹、发射许可及停火，仍由拨弹任务决定；控制器不能仅凭角度或速度误差判断这些业务条件。切换时明确新目标与累计状态，不自动复用上一模式的累计值。

### 5.5 摩擦轮：Velocity

摩擦轮需要保持的是转速，所以用速度类。左右轮各有自己的实例；方向由各自安装决定。

```cpp
SMC::Velocity friction_left; // 右轮另建一个实例
bool configured = friction_left.Init(speed_config, output_min, output_max);

SMC::VelocityInput input;
input.target = target_speed_rad_s;
input.target_acceleration = target_speed_change_rad_s2;
input.measurement = actual_speed_rad_s;
input.dt = control_dt_s;
float command = 0.0f;
bool ok = friction_left.Calc(input, command);
```

这里 `target_acceleration` 是目标速度的变化率，不是实际速度差，也不是 `speed_difference`。恒定目标速度的维持阶段可明确设0。原PID若使用rpm作目标，先把目标与反馈都换成rad/s，再谈调参。

发射后观察转速下降及恢复过程，再与同一电机原PID的记录比较。摩擦轮“已达到可发射转速”的判定仍由发射任务给出。

### 5.6 底盘：Velocity 控制每个轮子的转速

**底盘运动分配**是把整车前后、侧向和旋转要求换成每个轮子的速度目标。SMC轮速控制位于这一步之后，不直接把整车 m/s 数值当rad/s传入。

```text
整车运动目标 → 各轮速度目标rad/s → 各轮独立Velocity → 各轮命令
```

如果后级功率控制接收力矩，则SMC选择N·m输出，经过功率控制得到最终力矩，再接驱动。功率控制是限制各轮总耗能或功率的分配环节，可能把SMC请求进一步缩小；应同时记录请求与实际采用命令，不能继续假定完全实现了原公式。

轮腿机构中，保持身体平衡和计算关节作用力是其他控制任务，不能用“给所有电机加Velocity”替代。这里的范围只到单个轮子的速度跟踪。

### 5.7 TerminalPosition：作为单独比较分支

```cpp
SMC::TerminalPosition yaw_terminal;
bool configured = yaw_terminal.Init(terminal_config, output_min, output_max);
bool ok = yaw_terminal.Calc(input, command); // input是PositionInput
```

`transition_width` 是从终端关系切回普通关系的误差阈值，单位rad；`boundary_width` 是滑模变量零附近处理的宽度，单位rad/s。这两个量不是同一个阈值。

当前实现先选分支，避免在零误差处计算负次幂，但阈值处的输出仍可能跳变。原“较不推荐”可以理解为原项目经验；本教程把它留在普通位置形式之后学习和比较，不据此认定所有Yaw都不适用。

## 6. 最后一步：按电机接口下发

**适配**是把统一的控制量按具体电机的单位、方向和调用顺序变成报文。本节假设电机已经完成原有构造、总线绑定、反馈接收及必要使能，真实输出范围已由使用项目设置。`command_sign` 是+1或−1的方向配置，并已计入整个输入增益的约定。

### 6.1 DJI M3508、M3508NEW、M2006：力矩出口

当前这几个类型可使用 `SetMotorOutputFix()`。它接收N·m，在内部用 `torque_constant` 和 `current_resolution` 换成发送计数。

```cpp
// command的单位必须为N·m，方向转换之后仍应在驱动允许范围内。
motor.SetMotorOutputFix(command_sign * command);

// 全部DJI实例本拍的目标/命令准备好后，由原工程唯一发送处执行：
Motor_n::DjiMotor_n::DjiMotorControl();
Motor_n::DjiMotor_n::set_GiveCurrent();
Motor_n::DjiMotor_n::MotorTransmit();
```

固定输出模式会跳过本电机PID计算，其他DJI实例可以继续原PID。不要在固定输出之后又调用 `Enable()`，它会改回普通工作状态，下一次全局控制可能覆盖你的输出。模式进入、退出和重新使能由任务集中处理。

由源码，`raw = torque / torque_constant / current_resolution`。因此先根据项目原始命令上下限换算允许的力矩范围，再设置SMC输出范围；传给接口前就要满足范围。该接口先转int16，后面的限幅不能替代这一步。

这里使用的力矩轴必须与库里 `torque_constant` 的定义相同；再有额外传动时，需要同时换算反馈轴、命令力矩和模型b。不能把电机内部减速、外部齿轮和负载轴减速重复算一遍。

### 6.2 DJI GM6020：原始命令出口

**协议原始命令值**是CAN报文中编码的整数，不直接等于A、V或N·m。当前库的GM6020固定力矩接口直接输出0，因此在当前驱动上用 OPEN_LOOP 参考路径传原始命令。

先在进入这一控制模式时配置该实例：

```cpp
namespace MB = Motor_n::MotorBaseDef_n;
motor.motor_controller_.motor_setting.SetCloseLoopType(MB::OPEN_LOOP);
motor.motor_controller_.motor_setting.feedforward_flag = MB::FEEDFORWARD_NONE;
motor.motor_controller_.current_go_for_goal_shot_ptr = nullptr;
motor.Enable(); // 模式进入时执行；随后每拍由外部SMC提供新命令。
```

周期中由SMC计算原始命令，检查返回成功后：

```cpp
motor.DjiMotorSetRef(command_sign * command); // 此时command是协议原始命令单位。
// 所有电机准备完后，执行原来的统一发送链：
Motor_n::DjiMotor_n::DjiMotorControl();
Motor_n::DjiMotor_n::set_GiveCurrent();
Motor_n::DjiMotor_n::MotorTransmit();
```

该路径不做力矩到电流换算。虽然目标存储变量叫 `set_torque_`，执行结果仍是原始命令。库里的 `CURRENT_DRIVE` 枚举名也不能证明GM6020在实机上采用了电流协议。

SMC输出范围、控制器 `max_output/min_output` 和电机 `motor_max_output_/motor_min_output_` 都应采用同一原始命令单位，并符合实际GM6020固件协议。当前教程没有假定你的固件支持哪种电流扩展模式。方向由上述外部适配处理，因为OPEN_LOOP分支会覆盖PID路径前面做的反向处理。

### 6.3 DM：MIT格式的纯力矩出口

**MIT格式**在此指同时携带目标位置、目标速度、位置/速度作用系数和力矩的一种驱动报文。把位置/速度作用系数kp、kd都设0时，本教程只采用其中的力矩命令。

```cpp
motor.SetMotorOutputFix(command_sign * command); // command为N·m，接口内立即发送。
```

当前方法已经执行 `SetMITData(0,0,0,0,output)`、编码并发送，正常控制分支每拍调用一次即可。不要把SMC结果当rad/s传给目标速度，也不要同时保留另一套非零kp/kd位置保持作用，却仍把模型当成纯力矩输入。

`DM_ModePrame_s` 的p/v/t范围及kp/kd范围必须与驱动工具设置一致，SMC的力矩限制还须符合机构允许值。当前解析没有自动把协议轴变成你的额外传动轴。

### 6.4 Cybergear：先核对反馈尺度，再选一个出口

当前驱动有两个可对接出口；两者输出单位不同，不能共用一套未经换算的b和限值。

```cpp
// 方案A：运控格式，纯力矩；command为N·m。
motor.MiMotorControlMode(command_sign * command, 0.0f, 0.0f, 0.0f, 0.0f);

// 或方案B：电流模式；command为A，模型b也对应电流。
motor.MiCurrentModeSetCurrent(command_sign * command);
```

一次只选一个方案。当前接收位置按±720解码，而发送运控位置按±12.5编码，单位尺度不对称；纯力矩例子不转发接收位置。接入位置SMC前先确认实际转动一圈的反馈变化、零点和连续角度处理，不能把 raw.position 直接当rad。

该驱动的发送方法包含自动使能逻辑。上层已经停机时不要继续调用它们，再期待 `MiMotorStop()` 永久压住后续正常控制调用。

### 6.5 VESC：电流出口

```cpp
motor.Set_Current(command_sign * command); // command为A，立即发送。
```

实际速度按第4节从ERPM换算。`Set_Current()`函数参数是A，内部乘1000编码；`data().current`则保存0.1A计数，两者数值尺度不同。当前速度SMC算出A时，不应再传入 `Set_ERPM()`；后者接收的是速度目标，会改成另一种控制结构。

本教程选择电流出口时，若要接收N·m的功率控制模块，应先根据确认的轴侧力矩常数在两侧转换，不能把A直接当N·m交给它。

### 6.6 C615/Snail：需要外部测速后另行适配

当前C615只有PWM百分比命令；**PWM**是通过脉冲宽度或占空比传送控制要求的方法。`SetSpeed()`是函数名，不代表实际转速反馈或精确转速设定。

取得外部测速，并建立百分比命令到运动变化的关系后，才可研究对应的速度SMC。该接口仅接受约0～100的正百分比，不能套用双向±力矩示例；停止使用 `Disable()`，因为 `SetSpeed(0)`在当前实现中会直接返回而保留此前输出。

## 7. 一个周期怎么组织，停止时怎么办

**控制周期 dt**是两次算法更新之间的时间，单位秒。当前电机对象的 `dt_` 是两次反馈回调之间的时间，两者不一定相等。

周期顺序为：获取同一时刻含义的反馈快照 → 换算单位和坐标 → 获取本拍目标及其变化率 → 每实例计算一次 → 对成功结果完成输出适配 → 执行发送。

同一个反馈可能在几个控制周期内保持不变；这不等于每次都应该用上一次电机报文的dt重复积分。控制调用间隔用任务自己的计时；数据是否仍可用由原工程的反馈有效性判断负责。中断更新的数据在读出角度和速度期间也应保持一致，沿用工程现有快照方式。

| 情况 | 调用方动作 |
| --- | --- |
| 正常运行 | 每个实例每周期调用一次Calc，只发送本拍成功结果 |
| Calc返回false | 进入已有停止处理，不能重发遗留command冒充新结果 |
| 停机/失去运行条件 | 退出正常控制分支，清累计状态并执行驱动停止；后续周期不继续Calc累计 |
| 重新进入控制 | 确认反馈与目标有效，Reset，提供当前模式的新目标，再允许正常输出 |

`Reset()`仅重置算法内部状态；它不改外部command、不发送报文。DJI的 `Disable()`需要后续统一装填发送链实际送出0；DM使用 `Disable()`，Cybergear用 `MiMotorStop()`，VESC按原工程的停机策略发送零电流等命令，C615用 `Disable()`。这些动作的机械含义不同，不意味着零电流就能把有重力的机构保持在当前位置。

`IntegralPosition`、`Velocity`直接累计误差，没有累计截断或冻结。持续限幅下累计可能增长，第24讲强限幅实验已经出现未收敛。教程沿用当前精简策略；不在算法库中新增业务保护，但使用方仍需落实正常的模式进入、退出及停止动作。

## 8. 参数从哪里来，怎样逐项检查

**参数调整**是改变模型和控制作用系数，以适合当前对象的过程。先确认单位和接口，再调整数值，否则同一个数值改变可能只是在掩盖单位错误。

| 字段 | 含义与当前检查 |
| --- | --- |
| `input_gain` | 命令到角加速度的有效增益；非零，可正可负；与最终发送路径一致 |
| `surface_gain` | 普通位置中决定e与速度差的组合；速度类中决定累计的权重；必须正 |
| `reaching_gain` | 趋近律中的线性项系数；非负 |
| `switching_gain` | 指数趋近律中方向性作用的大小；非负，与reaching_gain不能同时为0 |
| `boundary_width` | s在零附近采用平滑处理的范围；正，当前角度单位下为rad/s |
| `integral_gain` | 位置误差累计的权重；非负，仅IntegralPosition |
| `power_gain`、`exponent` | 幂次项系数和指数；详见位置扩展规格，各参数不能按名称直接复制参考值 |
| `transition_width` | 终端与普通关系的误差切换阈值；正，单位rad，仅TerminalPosition |

这里的**平滑处理**是将原来在正负两侧突变的方向作用，在零附近改成连续变化；当前使用 `sat(s/phi)`：s大于phi时为1，小于−phi时为−1，中间为s/phi。phi对应boundary_width。它减小零附近输出切换，也改变了理想公式的到零性质，不能据连续形式直接保证有限时间精确到零。

先用已确认的模型b及机构允许范围，核对正负方向、静止反馈和小幅运动；在普通形式工作记录基础上，再分别考察累计、幂次或终端分段的影响。不同电机、不同坐标单位、不同接口下不要整套复制数值。配置要求及单位完整定义见[位置规格](普通位置滑模数学规格.md)、[速度规格](速度控制数学规格与接入说明.md)、[扩展规格](位置扩展数学规格与接入说明.md)。

建议记录目标、实际量、e、s、请求输出、SMC限幅输出、最终驱动采用输出，以及累计值。限幅标志只表示SMC内部那次限幅，不能代表下游驱动、功率控制已经全部执行到位。

## 9. 放进工程前的练习与构建

### 9.1 主机练习

完整文件：[ecf27_smc_example.cpp](../examples/ecf27_smc_example.cpp)。主机是开发电脑；主机运行用于检查调用和数值，不会控制板上的电机。

从SMC仓库运行下面的PowerShell命令：

```powershell
New-Item -ItemType Directory -Force 'build/ecf27_tutorial' | Out-Null
$smcTutorialSavedPath = $env:Path
try {
    # MSYS2编译器的子进程也需要找到同目录中的运行库。
    $env:Path = 'D:/msys64/ucrt64/bin;' + $env:Path
    & 'D:/msys64/ucrt64/bin/g++.exe' -std=c++11 -Wall -Wextra -Wpedantic -Werror -ffp-contract=off -fno-fast-math -static -I main main/ALG_SMC.cpp examples/ecf27_smc_example.cpp -o build/ecf27_tutorial/ecf27_smc_example.exe
    if ($LASTEXITCODE -ne 0) { throw '编译失败' }
    & './build/ecf27_tutorial/ecf27_smc_example.exe'
    if ($LASTEXITCODE -ne 0) { throw '示例核对失败' }
} finally {
    $env:Path = $smcTutorialSavedPath
}
```

文件使用明确标注的教学假设，不包含真实电机调参值。它调用真实的五种SMC类，验证速度换算、最短角度误差、独立累计和Reset行为；驱动接口调用片段没有在这个程序中编译。

### 9.2 加入STM32消费工程

**消费工程**是实际包含主控、任务和电机配置、最终生成固件的项目。只需将 `main/ALG_SMC.hpp`、`main/ALG_SMC.cpp` 作为独立算法源加入它，保持没有HAL或RTOS依赖；HAL是芯片外设访问库，RTOS是管理实时任务的系统。

假设在消费工程内明确选定 `ControlLib/SMC` 作为这两个文件的放置目录，可在创建目标之后添加：

```cmake
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    "${CMAKE_SOURCE_DIR}/ControlLib/SMC/ALG_SMC.cpp")
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    "${CMAKE_SOURCE_DIR}/ControlLib/SMC")
```

这里的目录是接入示例，需要实际创建，不表示ECF27已有该目录。当前ECF27模板用 `USER_ADD_DIR`收集源文件，没有现成的SMC启用开关。不要把主机示例的main或整个教学目录加入固件。

电机实例、总线、ID和硬件初始化留在使用项目；单位/方向/反馈适配放在设备与任务之间的连接代码；目标、模式、发射许可和整车运动逻辑放在应用任务。无需为了加SMC而改写所有驱动的PID结构。

### 9.3 一台电机开始前填写这些信息

| 信息 | 你工程中的值 |
| --- | --- |
| 部位及本次控制量：位置或速度 | 待填 |
| 电机型号、驱动版本、CAN通道与ID | 待填 |
| 实际控制轴、反馈轴及传动比 | 待填 |
| 零点、正方向及角度是否允许跨圈/最短转向 | 待填 |
| 目标及反馈的原单位、转成rad/rad/s的方法 | 待填 |
| 输出接口及U：N·m、A或原始命令 | 待填 |
| b的来源、各系数及最终允许范围 | 待填 |
| 控制间隔、反馈更新方式、模式进入退出方式 | 待填 |

## 10. 本次交付与证据

本教程完成了源码核查与主机调用练习，不等同于实机接入完成。当前主机示例已用g++ 16.1.0编译、真实链接SMC并运行通过；运行报告见 `build/ecf27_tutorial/verification.json`。ECF27驱动调用是静态核对，没有完成这些驱动片段的固件编译、整机链接、CAN收发、电机调参或整车验证。

阅读后的自检：为什么同一M2006既可做位置控制又可做速度控制？为什么GM6020和M3508不能照搬同一个SetMotorOutputFix片段？为什么SMC的Reset不能当作停机指令？能把其中一个部位的数据表填完整，再进入该电机的实际接入。
