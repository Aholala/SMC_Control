# ECF27 电机接口核查记录

核查日期：2026-10-30。教程入口：[ECF27 电机滑模控制教程](ECF27电机滑模控制教程.md)。

本次只读取 `D:/ACE/ACE_ECF_27`，不修改电机驱动。该仓库分支为 `Develop`，提交为 `6ccedeaecc59d2ea8f5d109f3f65f6fe8a232ebf`，核查开始时工作区干净。SMC 起始提交为 `9e24b7524eb3c2d8b9f88dd3f8dd43ca15bb9d1d`。这些是版本定位，不能代表其他消费工程已经使用同一版本。

本页“确认”指源码中直接可见的行为；“推导”指从执行式得到的结果；“待确认”指缺少实机配置或运行证据。当前文件行号以后可能变化，应同时按函数名定位。

## 1. 当前驱动范围

非 `motor_old` 目录有 DJI、DM、Cybergear、VESC 和 C615。DJI 构造函数区分 GM6020、M3508、M3508NEW、M2006；DM 头文件区分 DM4310、DM4340、DM6220、DM8009、DM10010、DM2325、DM3519。

这是库支持的类型，不是已安装在某辆机器人上的电机清单。当前没有据此确定 Yaw/Pitch 的实际型号、CAN ID、减速比、安装方向或输出限值。旧目录的 Unitree、LK 等驱动不纳入本教程的直接接入结论。

## 2. 接入依据

| 结论 | 直接依据 | 对教程的影响 |
| --- | --- | --- |
| DJI 默认角度反馈指针指向累计编码值，速度指针指向原始 rpm | [构造函数，第234～236行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:234) | 原 PID 的目标数值不能直接照搬为 rad 或 rad/s |
| DJI 总角度按编码值、分辨率、配置齿比换算 | [ParseCANData，第785行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:785) | `total_angle` 是度，已除配置齿比；再乘 π/180，不再除同一个齿比 |
| DJI 固定输出接口把输入力矩换算为原始命令 | [SetMotorOutputFix，第660～675行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:660) | M3508 等走该路径时 SMC 的 U 应为 N·m，不是 A 或原始电流计数 |
| GM6020 在固定输出接口中直接置零并返回 | [同函数，第667～671行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:667) | GM6020 使用教程的 OPEN_LOOP 原始命令路径，不能复制力矩示例 |
| DJI 固定输出模式跳过 PID，但仍需要装填分组和统一发送 | [DjiMotorControl，第505行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:505)、[set_GiveCurrent，第517行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:517)、[MotorTransmit，第544行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:544) | 保留工程唯一的 DJI 发送入口；每周期完整装填后发送 |
| DJI OPEN_LOOP 的参考值最终直接作为原始命令 | [DjiMotorSetRef，第448行](D:/ACE/ACE_ECF_27/Module/motor/DJI/dji_driver.cpp:448)、[MotorPIDCalculate，第399～402行](D:/ACE/ACE_ECF_27/Module/motor/motor_base_def.hpp:399) | `set_torque_` 变量名不代表该执行路径真的进行了力矩换算 |
| OPEN_LOOP 分支重新取原 SetVal，覆盖此前的电机反向处理 | [MotorPIDCalculate，第373、402行](D:/ACE/ACE_ECF_27/Module/motor/motor_base_def.hpp:368) | 原始命令路径由外部适配明确处理方向，不能依赖原 PID 的反向标志 |
| DM 原始位置/速度为 rad、rad/s，处理后为度、度每秒 | [ParseCANData，第149～166行](D:/ACE/ACE_ECF_27/Module/motor/DM/dm_driver.cpp:149) | 可用原始速度，或处理速度乘 π/180；两条路径选一条 |
| DM 固定输出设置 kp=kd=0，并在接口内发送 | [SetMotorOutputFix，第41～70行](D:/ACE/ACE_ECF_27/Module/motor/DM/dm_driver.cpp:41) | 不要再追加一次普通 Transmit 作为必要步骤 |
| DM 普通 Transmit 在固定输出状态下抑制发送 | [Transmit，第110～111行](D:/ACE/ACE_ECF_27/Module/motor/DM/dm_driver.cpp:110) | 不把“SetMITData 后 Transmit”与固定输出路径随意混搭 |
| Cybergear 回调将位置解码到 ±720、速度到 ±30，未更新 processed 字段 | [宏定义](D:/ACE/ACE_ECF_27/Module/motor/Cybergear/cybergear_driver.hpp:50)、[反馈回调，第499～503行](D:/ACE/ACE_ECF_27/Module/motor/Cybergear/cybergear_driver.cpp:499) | 当前反馈位置按度使用、速度按 rad/s 使用，需在实机确认位置尺度；不能假设 processed 数据持续更新 |
| Cybergear 运控发送位置按 ±12.5 编码、速度按 ±30 编码 | [发送常量](D:/ACE/ACE_ECF_27/Module/motor/Cybergear/cybergear_driver.hpp:38)、[MiMotorControlMode](D:/ACE/ACE_ECF_27/Module/motor/Cybergear/cybergear_driver.cpp:237) | 发送位置与当前接收位置不是同一数值尺度，不能原样转发；纯力矩示例把位置/速度/kp/kd设0 |
| VESC 存储 erpm，Set_Current 的实参乘1000编码 | [反馈解析](D:/ACE/ACE_ECF_27/Module/motor/VESC/vesc_driver.cpp:135)、[Set_Current](D:/ACE/ACE_ECF_27/Module/motor/VESC/vesc_driver.cpp:358) | 电转速需要极对数换算；函数实参是 A，反馈 `current` 却保存0.1 A计数 |
| C615 只有百分比输出，没有速度反馈接口 | [头文件](D:/ACE/ACE_ECF_27/Module/motor/C615/c615_driver.hpp:32)、[实现](D:/ACE/ACE_ECF_27/Module/motor/C615/c615_driver.cpp:48) | 加外部测速后才能建立速度反馈控制；`SetSpeed(0)`会直接返回，停止应调用 Disable |
| 电机 dt_ 是反馈回调间隔 | [Online](D:/ACE/ACE_ECF_27/Module/motor/motor_base_def.hpp:941) | SMC 的 dt 使用控制调用间隔，不能反复积分同一个反馈间隔 |
| 当前构建模板使用 USER_ADD_DIR | [template/CMakeLists.txt](D:/ACE/ACE_ECF_27/template/CMakeLists.txt:57) | 教程按当前模板说明，不假定已有 SMC 模块或某个 ADD_MODULE 开关 |

## 3. DJI 反馈中需要特别区分的执行式

当前 `ParseCANData()` 第748～749行把速度更新写成：

```text
w_new = ((1-alpha)*w_old + 6*alpha*rotor_rpm) / ratio
```

这里 alpha 是每拍速度滤波权重，ratio 是配置齿比。**滤波**是把新旧测量加权，以减小测量波动的方法。该执行式把已经保存的旧速度再次除以齿比；因此 ratio 不为1时，不能直接当作通常的“输出轴速度滤波”。

推导：恒定 rpm 下，其稳定值是 `6*alpha*rpm/(ratio-1+alpha)`，通常不等于 `6*rpm/ratio`。所以本教程从原始 rpm 换算速度；如需滤波，在完成单位与齿比换算后单独维护滤波状态：

```text
w_sample = rotor_rpm * 2*pi / 60 / ratio
w_filtered_new = (1-alpha)*w_filtered_old + alpha*w_sample
```

此外，第744～746行的绝对、相对角度换算在不同阶段重复使用 ratio；本教程的累计定位使用 `total_angle`，不将这些单圈字段直接作为减速轴的通用反馈。`speed_difference` 是相邻速度之差，没有除以时间，不是角加速度。

这些是当前源码的接入限制，本轮未修改驱动。是否调整驱动属于后续单独的代码工作。

## 4. 输出与停止的边界

DJI `SetMotorOutputFix()` 在最终分组限幅之前先转 `int16_t`，所以调用前给出的力矩范围必须先换算确认，不能依赖事后的分组限幅阻止超范围转换。

DM/Cybergear 的直接发送接口不会替调用方判断 SMC 是否应当继续运行；Cybergear 部分发送方法还会周期性使能。上层停机后必须退出正常控制分支，不能在 Disable/Stop 后继续调用这些输出接口。`SMC::Reset()`只清算法状态，不发停止报文；`Calc()`失败保持旧命令，不能把旧命令当本拍新输出。

通用基类同名接口没有统一的物理单位和发送语义。不能只拿一个 `MotorBase_c*` 就对所有电机执行同一条 SetMotorOutputFix。

## 5. 证据范围

本轮主机示例真实链接当前 SMC 生产文件，检查单位手算、最短角度误差、五种类接口、实例间累计独立及 Reset 行为。驱动调用片段是对上述源文件的静态核对，没有编译或链接 ECF27 驱动，也没有运行 CAN、真实电机或整车。

原始源码快照和当前文件 SHA256 保存在 `build/ecf27_tutorial/source_snapshot.json`；主机运行与当前哈希复核见同目录 `verification.json`。这些构建产物不替代本页的验证边界。
