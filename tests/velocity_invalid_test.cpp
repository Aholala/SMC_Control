#include "velocity_test_support.hpp"
#include <limits>

static void Rejected(SMC::Velocity& p,const SMC::VelocityInput& input)
{
    const SMC::Velocity saved=p;
    float command=31;
    CHECK(!p.Calc(input,command) && command==31);
    SameVelocity(p,saved);
}

int main()
{
    const float nan=std::numeric_limits<float>::quiet_NaN();
    const float inf=std::numeric_limits<float>::infinity();
    const float maximum=std::numeric_limits<float>::max();
    SMC::Velocity p;
    CHECK(p.Init(VelocityConfig(),-5,6));
    SMC::VelocityInput in; in.dt=.125f; in.measurement=.5f;
    float u=0; CHECK(p.Calc(in,u)); const SMC::Velocity saved=p;
    float SMC::VelocityConfig::* const configs[]={&SMC::VelocityConfig::input_gain,&SMC::VelocityConfig::surface_gain,
        &SMC::VelocityConfig::reaching_gain,&SMC::VelocityConfig::switching_gain,&SMC::VelocityConfig::boundary_width};
    for (auto field:configs)
        for (float value:{nan,inf,-inf})
        {
            SMC::VelocityConfig c=VelocityConfig(); c.*field=value;
            CHECK(!p.SetParameters(c) && !p.Init(c,-5,6)); SameVelocity(p,saved);
        }
    for (auto field:configs)
    {
        SMC::VelocityConfig c=VelocityConfig(); c.*field=-1;
        if (field!=&SMC::VelocityConfig::input_gain) CHECK(!p.SetParameters(c));
    }
    for (auto field:{&SMC::VelocityConfig::input_gain,&SMC::VelocityConfig::surface_gain,&SMC::VelocityConfig::boundary_width})
    { SMC::VelocityConfig c=VelocityConfig(); c.*field=0; CHECK(!p.SetParameters(c)); }
    SMC::VelocityConfig c=VelocityConfig(); c.reaching_gain=c.switching_gain=0;
    CHECK(!p.SetParameters(c));
    for (float value:{nan,inf,-inf})
    {
        CHECK(!p.SetLimits(value,6) && !p.SetLimits(-5,value));
        SameVelocity(p,saved);
    }
    float SMC::VelocityInput::* const fields[]={&SMC::VelocityInput::target,&SMC::VelocityInput::target_acceleration,
        &SMC::VelocityInput::measurement,&SMC::VelocityInput::dt};
    for (auto field:fields)
        for (float value:{nan,inf,-inf})
        { SMC::VelocityInput bad=in; bad.*field=value; Rejected(p,bad); }
    SMC::VelocityInput bad=in;
    bad.dt=0; Rejected(p,bad); bad.dt=-.1f; Rejected(p,bad);
    bad=in; bad.target=-maximum; bad.measurement=maximum; Rejected(p,bad); // error溢出。
    bad=in; bad.measurement=maximum/2; bad.dt=4; Rejected(p,bad); // 累计增量溢出，最终结果检查拒绝提交。
    c=VelocityConfig(); c.input_gain=1e-30f;
    CHECK(p.SetParameters(c)); bad=in; bad.target_acceleration=maximum/2; Rejected(p,bad);
    c=VelocityConfig(); c.surface_gain=maximum;
    CHECK(p.SetParameters(c)); bad=in; bad.measurement=2; Rejected(p,bad);
    // 累计候选和s自身也可能溢出；失败不推进已存在的累计值。
    c=VelocityConfig(); c.surface_gain=.5f; c.reaching_gain=0; c.switching_gain=1;
    CHECK(p.Init(c,-5,6));
    bad=SMC::VelocityInput(); bad.dt=1; bad.measurement=maximum*.5f;
    CHECK(p.Calc(bad,u)); bad.dt=2; Rejected(p,bad); // 增量本身有限，旧累计+增量溢出。
    c.surface_gain=1; CHECK(p.Init(c,-5,6));
    bad.dt=.5f; bad.measurement=maximum*.75f; Rejected(p,bad); // e与c*z都有限，相加得到的s溢出。
}
