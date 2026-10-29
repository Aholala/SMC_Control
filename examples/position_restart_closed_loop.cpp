// 第22讲主机对象；参数和积分方式沿用既有 verification_runner 教学假设。
// 新增的暂停/重启属于本示例的调用方操作，不进入生产库。
#include "../main/ALG_SMC.hpp"
#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>

int main()
{
    try
    {
        const double dt=.001;
        std::cout << std::setprecision(17)
                  << "scenario,time,target,target_rate,target_acc,position,rate,measurement,measurement_rate,"
                     "error,error_rate,s,request,caller_command,applied_command,limited,enabled,calc_called,calc_success,reset_event,has_result\n";
        for (int scenario=1; scenario<=4; ++scenario)
        {
            SMC::PositionConfig c;
            c.input_gain=scenario==2 ? -3.0f : 3.0f;
            c.surface_gain=4; c.reaching_gain=6; c.switching_gain=2; c.boundary_width=.25f;
            const float bound=scenario==3 ? 1.0f : 4.0f;
            SMC::Position axis;
            if (!axis.Init(c,-bound,bound)) throw std::runtime_error("Init failed");
            double position=-.2, rate=0;
            float caller_command=0;
            for (int i=0; i<8000; ++i)
            {
                const bool enabled=!(scenario==4 && i>=1000 && i<1500);
                const bool reset_event=scenario==4 && i==1000;
                const double target=scenario==4 && i>=1500 ? -.3 : .5;
                if (reset_event && !axis.Reset()) throw std::runtime_error("Reset failed");
                SMC::PositionInput in;
                in.target=static_cast<float>(target);
                in.measurement=static_cast<float>(position);
                in.measurement_rate=static_cast<float>(rate);
                bool success=false;
                if (enabled) success=axis.Calc(in,caller_command);
                if (enabled && !success) throw std::runtime_error("Calc failed");
                const float applied_command=enabled ? caller_command : 0.0f;
                const SMC::PositionResult& r=axis.GetResult();
                std::cout << scenario << ',' << i*dt << ',' << target << ",0,0,"
                          << position << ',' << rate << ',' << position << ',' << rate << ','
                          << r.error << ',' << r.error_rate << ',' << r.sliding_variable << ','
                          << r.requested_output << ',' << caller_command << ',' << applied_command << ','
                          << r.limited << ',' << enabled << ',' << enabled << ',' << success << ','
                          << reset_event << ',' << axis.HasResult() << '\n';
                const double acceleration=double(c.input_gain)*applied_command;
                position+=rate*dt+.5*acceleration*dt*dt;
                rate+=acceleration*dt;
                if (!std::isfinite(position) || !std::isfinite(rate)) throw std::runtime_error("Nonfinite plant");
            }
        }
        return std::cout.good() ? 0 : 1;
    }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
