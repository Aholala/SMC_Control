#include "../SMC_Controller/SMC/slidingmodec.h"
#include <iomanip>
#include <iostream>

// 静态存储保证构造前先零初始化；避免依赖原构造函数没有设置的历史成员。
// 三个对象分别回放不同间隔，不复制对象，不修改原参考。
static SMC reference_001(0.5f, 1.0f, 0.0f, 0.0f, 1000.0f, 0.2f, 2.0f);
static SMC reference_010(0.5f, 1.0f, 0.0f, 0.0f, 1000.0f, 0.2f, 2.0f);
static SMC reference_100(0.5f, 1.0f, 0.0f, 0.0f, 1000.0f, 0.2f, 2.0f);

int main()
{
    SMC* controllers[] = {&reference_001, &reference_010, &reference_100};
    const double intervals[] = {0.01, 0.1, 1.0};
    std::cout << std::setprecision(17);
    std::cout << "case_number,sample_number,interval_s,time_s,target_deg,measurement_deg,measurement_rate_deg_s,raw_cpp_output_value\n";
    for (int scenario = 0; scenario < 3; ++scenario)
    {
        SMC& controller = *controllers[scenario];
        for (int sample = 0; sample < 3; ++sample)
        {
            // r(t)=t² °，第三次调用都在 t=1 s；前两次只建立相邻目标历史。
            const double time = 1.0 - (2 - sample) * intervals[scenario];
            const float target = static_cast<float>(time * time);
            const float measurement = target + 1.0f;
            const float measurement_rate = static_cast<float>(2.0 * time);
            controller.ref = target;
            controller.SMC_Tick(measurement, measurement_rate);
            std::cout << scenario + 1 << ',' << sample + 1 << ',' << intervals[scenario] << ','
                      << time << ',' << target << ',' << measurement << ',' << measurement_rate << ','
                      << controller.u << '\n';
        }
    }
    return 0;
}
