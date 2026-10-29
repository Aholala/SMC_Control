// 第24～27讲共用的主机调用工具；不把对象、参数或文件操作带入生产库。
#include "ALG_SMC.hpp"
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

static void Require(bool value,const char* message) { if (!value) throw std::runtime_error(message); }
struct Values { float e,edot,z,s,request,output; bool limited,terminal; };
template<class R> static Values Convert(const R& r,float z=0,bool terminal=false)
{ return Values{r.error,r.error_rate,z,r.sliding_variable,r.requested_output,r.output,r.limited,terminal}; }

struct Axis
{
    int kind=0;
    SMC::Position ordinary;
    SMC::IntegralPosition integral;
    SMC::PowerPosition power;
    SMC::TerminalPosition terminal;
    void Init(const std::vector<float>& v)
    {
        kind=static_cast<int>(v[0]); bool ok=false;
        if (kind==0)
        { SMC::PositionConfig c; c.input_gain=v[2]; c.surface_gain=v[3]; c.reaching_gain=v[6]; c.switching_gain=v[7]; c.boundary_width=v[8]; ok=ordinary.Init(c,v[10],v[11]); }
        if (kind==1)
        { SMC::IntegralPositionConfig c; c.input_gain=v[2]; c.surface_gain=v[3]; c.integral_gain=v[4]; c.reaching_gain=v[6]; c.switching_gain=v[7]; c.boundary_width=v[8]; ok=integral.Init(c,v[10],v[11]); }
        if (kind==2)
        { SMC::PowerPositionConfig c; c.input_gain=v[2]; c.surface_gain=v[3]; c.power_gain=v[4]; c.exponent=v[5]; c.reaching_gain=v[6]; c.boundary_width=v[8]; ok=power.Init(c,v[10],v[11]); }
        if (kind==3)
        { SMC::TerminalPositionConfig c; c.input_gain=v[2]; c.linear_surface_gain=v[3]; c.terminal_gain=v[4]; c.exponent=v[5]; c.reaching_gain=v[6]; c.switching_gain=v[7]; c.boundary_width=v[8]; c.transition_width=v[9]; ok=terminal.Init(c,v[10],v[11]); }
        Require(ok,"Axis init failed");
    }
    void Reset()
    { Require(kind==0 ? ordinary.Reset() : kind==1 ? integral.Reset() : kind==2 ? power.Reset() : terminal.Reset(),"Reset failed"); }
    void Calc(const SMC::PositionInput& in,float dt,float& command)
    { Require(kind==0 ? ordinary.Calc(in,command) : kind==1 ? integral.Calc(in,dt,command) : kind==2 ? power.Calc(in,command) : terminal.Calc(in,command),"Calc failed"); }
    bool HasResult() const
    { return kind==0 ? ordinary.HasResult() : kind==1 ? integral.HasResult() : kind==2 ? power.HasResult() : terminal.HasResult(); }
    Values Result() const
    {
        if (kind==0) return Convert(ordinary.GetResult());
        if (kind==1) return Convert(integral.GetResult(),integral.GetErrorIntegral());
        if (kind==2) return Convert(power.GetResult());
        return Convert(terminal.GetResult(),0,terminal.GetResult().terminal_branch);
    }
};
static void Emit(std::ostream& out,const Values& r)
{ out << r.e << ',' << r.edot << ',' << r.z << ',' << r.s << ',' << r.request << ',' << r.output << ',' << r.limited << ',' << r.terminal; }

static void Points(const std::string& source_path,const std::string& output_path)
{
    std::ifstream source(source_path.c_str()); std::ofstream out(output_path.c_str());
    Require(source.good() && out.good(),"Cannot open points CSV"); std::string line;
    Require(bool(std::getline(source,line)),"Missing header");
    out << std::setprecision(17) << "row,kind,block,error,error_rate,integral,s,request,output,limited,terminal_branch\n";
    Axis axis; int previous_block=-1,previous_kind=-1,count=0; std::vector<float> previous;
    while (std::getline(source,line))
    {
        if (line.empty()) continue;
        std::stringstream stream(line); std::string field; std::vector<float> v;
        while (std::getline(stream,field,',')) v.push_back(std::stof(field));
        Require(v.size()==19,"Expected 19 fields"); const int kind=static_cast<int>(v[0]), block=static_cast<int>(v[1]);
        Require(kind==v[0] && block==v[1],"Noninteger kind/block");
        if (block!=previous_block || kind!=previous_kind)
        { axis.Init(v); previous=v; previous_block=block; previous_kind=kind; }
        for (int j=2;j<=11;++j) Require(v[j]==previous[j],"Parameters changed inside block");
        if (v[18]==1) axis.Reset(); else Require(v[18]==0,"Unknown operation");
        SMC::PositionInput in;
        in.target=v[12]; in.target_rate=v[13]; in.target_acceleration=v[14]; in.measurement=v[15]; in.measurement_rate=v[16];
        float command=0; axis.Calc(in,v[17],command);
        out << ++count << ',' << kind << ',' << block << ','; Emit(out,axis.Result()); out << '\n';
    }
    Require(source.eof() && out.good() && count>0,"Point read/write failed");
    std::cout << "extension_points=" << count << '\n';
}
static void Simulate(const std::string& directory,int selected)
{
    const double dt=.001;
    for (int scenario=1;scenario<=8;++scenario)
    {
        if (selected && scenario!=selected) continue;
        const int kind=(scenario>=2 && scenario<=4) ? 1 : scenario==5 ? 2 : scenario>=7 ? 3 : 0;
        const float b=scenario==8 ? -3.0f : 3.0f, bound=scenario==3 ? .2f : 4.0f;
        // [kind,block,b,c,extra,a,K,epsilon,phi,delta,min,max,...]
        std::vector<float> v={float(kind),0,b,4,kind==1 ? 4.0f : 2.0f,.5f,6,2,.25f,.25f,-bound,bound};
        Axis axis; axis.Init(v);
        std::ostringstream name; name << directory << "/extension0" << scenario << ".csv";
        std::ofstream out(name.str().c_str()); Require(out.good(),"Cannot open case output");
        out << std::setprecision(17) << "time,target,target_rate,target_acc,position,rate,error,error_rate,integral,s,request,caller,applied,limited,terminal_branch,enabled,called,reset,has_result,disturbance\n";
        double position=-.2, rate=0; float caller=0;
        for (int i=0;i<8000;++i)
        {
            const bool enabled=!(scenario==4 && i>=1000 && i<1500), reset=scenario==4 && i==1000;
            if (reset) axis.Reset();
            const double target=scenario==4 && i>=1500 ? -.3 : .5;
            SMC::PositionInput in; in.target=static_cast<float>(target); in.measurement=static_cast<float>(position); in.measurement_rate=static_cast<float>(rate);
            if (enabled) axis.Calc(in,static_cast<float>(dt),caller);
            const float applied=enabled ? caller : 0;
            const double disturbance=scenario<=3 && i>=2000 ? .4 : 0;
            const Values r=axis.Result();
            out << i*dt << ',' << target << ",0,0," << position << ',' << rate << ','
                << r.e << ',' << r.edot << ',' << r.z << ',' << r.s << ',' << r.request << ','
                << caller << ',' << applied << ',' << r.limited << ',' << r.terminal << ','
                << enabled << ',' << enabled << ',' << reset << ',' << axis.HasResult() << ',' << disturbance << '\n';
            const double acceleration=double(b)*applied+disturbance;
            position+=rate*dt+.5*acceleration*dt*dt; rate+=acceleration*dt;
            Require(std::isfinite(position) && std::isfinite(rate),"Nonfinite plant state");
        }
        Require(out.good(),"Case output failed"); std::cout << "extension_case=" << scenario << " rows=8000\n";
    }
}
int main(int argc,char** argv)
{
    try
    {
        if (argc==4 && std::string(argv[1])=="points") Points(argv[2],argv[3]);
        else if ((argc==3 || argc==4) && std::string(argv[1])=="simulate")
        { const int selected=argc==4 ? std::stoi(argv[3]) : 0; Require(selected>=0 && selected<=8,"Scenario must be 0..8"); Simulate(argv[2],selected); }
        else throw std::runtime_error("Usage: points input.csv output.csv | simulate directory [1..8]");
        return 0;
    }
    catch(const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
