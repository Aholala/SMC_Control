// 第20讲：只调用生产库，记录每个操作后两个对象的完整可观察状态。
#include "../main/ALG_SMC.hpp"
#include <iomanip>
#include <iostream>
#include <limits>

static SMC::PositionConfig Config(int variant)
{
    SMC::PositionConfig c;
    if (variant == 0) return c;
    c.input_gain = variant == 2 ? -2.0f : 2.0f;
    c.surface_gain = 2; c.reaching_gain = 3;
    c.switching_gain = 4; c.boundary_width = 2;
    return c;
}

static void Emit(const SMC::Position& p, float command)
{
    const SMC::PositionConfig& c = p.GetConfig();
    const SMC::PositionResult& r = p.GetResult();
    std::cout << ',' << p.IsInitialized() << ',' << p.HasResult() << ',' << command
              << ',' << c.input_gain << ',' << c.surface_gain << ',' << c.reaching_gain
              << ',' << c.switching_gain << ',' << c.boundary_width
              << ',' << p.GetOutputMin() << ',' << p.GetOutputMax()
              << ',' << r.error << ',' << r.error_rate << ',' << r.sliding_variable
              << ',' << r.requested_output << ',' << r.output << ',' << r.limited;
}

int main()
{
    // 操作：1 Init，2 Calc，3 Reset，4 SetParameters，5 SetLimits。
    // 每行依次为对象编号、操作、变体；完整变体定义见本讲讲义。
    const int events[][3] = {
        {1,2,1},{1,3,0},{1,4,1},{1,5,1},{1,1,0},{1,1,1},{2,1,2},
        {1,2,1},{2,2,1},{1,2,3},{2,2,6},{1,2,4},{1,2,5},
        {1,4,0},{1,5,0},{1,1,0},{1,3,0},{2,2,1},{1,2,1},
        {1,4,2},{1,2,1},{1,5,1},{1,2,1},{1,5,2},{1,2,2},
        {2,3,0},{1,2,7},{1,1,1},{1,2,1}
    };
    SMC::Position axes[2];
    float commands[2] = {17,23}; // 观察标记，不发送给设备。
    std::cout << std::setprecision(17) << "step,axis,operation,variant,success";
    for (int id=1; id<=2; ++id)
        for (const char* field : {"initialized","has_result","command","b","c","k","epsilon","phi",
                                 "minimum","maximum","error","error_rate","s","request","output","limited"})
            std::cout << ",axis" << id << '_' << field;
    std::cout << '\n';
    for (unsigned i=0; i<sizeof(events)/sizeof(events[0]); ++i)
    {
        const int id=events[i][0]-1, op=events[i][1], v=events[i][2];
        SMC::Position& p=axes[id];
        bool ok=false;
        if (op==1) ok=p.Init(Config(v), v==2 ? -1.0f : -3.0f, v==2 ? 2.0f : 3.0f);
        else if (op==3) ok=p.Reset();
        else if (op==4) ok=p.SetParameters(Config(v));
        else if (op==5) ok=p.SetLimits(v==0 ? 2.0f : (v==1 ? -1.0f : 2.0f),
                                     v==0 ? -2.0f : (v==1 ? 1.0f : 2.0f));
        else if (op==2)
        {
            SMC::PositionInput in;
            if (v==1) in.measurement=.5f;
            if (v==2) in.target_acceleration=6;
            if (v==3) in.target=std::numeric_limits<float>::quiet_NaN();
            if (v==4) in.measurement_rate=std::numeric_limits<float>::infinity();
            if (v==5) { in.target=-std::numeric_limits<float>::max(); in.measurement=std::numeric_limits<float>::max(); }
            if (v==6) in.target_rate=-std::numeric_limits<float>::infinity();
            if (v==7) { in.target_acceleration=1; in.measurement=1; in.measurement_rate=-2; }
            ok=p.Calc(in,commands[id]);
        }
        std::cout << i+1 << ',' << id+1 << ',' << op << ',' << v << ',' << ok;
        Emit(axes[0],commands[0]); Emit(axes[1],commands[1]); std::cout << '\n';
    }
    return std::cout.good() ? 0 : 1;
}
