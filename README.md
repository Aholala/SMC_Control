# SMC_Control
独立 C++11 滑模控制库，生产文件为 `main/ALG_SMC.hpp` 与 `main/ALG_SMC.cpp`。

- `SMC::Position`：位置控制，让实际角度跟随目标角度。
- `SMC::Velocity`：速度控制，让实际角速度跟随目标角速度，按显式时间间隔累计速度误差。
- `SMC::IntegralPosition`：把位置误差累计加入滑模变量。
- `SMC::PowerPosition`：保留线性趋近项，另用带指数的项改变趋近规律。
- `SMC::TerminalPosition`：大误差区使用带符号幂，小误差区使用普通位置关系；不承诺全程有限时间到零。

接入见[位置说明](docs/库接入与验证说明.md)与[速度数学规格及接入说明](docs/速度控制数学规格与接入说明.md)。各实例参数和输出范围由使用项目提供；速度误差直接累计，无额外累计限幅。

三个位置扩展的公式、单位、阈值与接口见[位置扩展规格](docs/位置扩展数学规格与接入说明.md)。累计形式继续直接累计，不添加截断或冻结；终端分段阈值显式提供。

MATLAB 总验证入口为 `matlab/验证/run_checks.m`，速度单独验证为 `matlab/验证/run_velocity_checks.m`。`start.m` 默认教学；应用编号1为位置、2为速度。主机验证运行 `tests/verify_host.ps1`，STM32目标编译运行 `tests/verify_arm.ps1`。

当前源码已通过13项主机测试、MATLAB独立计算与教学对象实验，以及M4/M7编译；尚未完成消费工程完整固件链接、上板或整车验证。教学和个人理解进度见[学习路线](docs/学习路线与MATLAB索引.md)。
