// 验证/教学对象及CSV读写不进入生产库。
#include "ALG_SMC.hpp"
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

static void Require(bool value,const char* message)
{ if (!value) throw std::runtime_error(message); }

static void Points(const std::string& input,const std::string& output)
{
    std::ifstream source(input.c_str()); std::ofstream out(output.c_str());
    Require(source.good() && out.good(),"Cannot open points CSV");
    std::string line; Require(bool(std::getline(source,line)),"Missing input header");
    out << std::setprecision(17) << "row,block,error,integral,s,request,output,limited\n";
    SMC::Velocity axis; std::vector<float> previous;
    int last=-1,count=0;
    while (std::getline(source,line))
    {
        if (line.empty()) continue;
        std::stringstream stream(line); std::string field; std::vector<float> v;
        while (std::getline(stream,field,',')) v.push_back(std::stof(field));
        Require(v.size()==12,"Expected block/config/limits/input: 12 fields");
        const int block=static_cast<int>(v[0]); Require(v[0]==block,"Noninteger block");
        if (block!=last)
        {
            SMC::VelocityConfig c;
            c.input_gain=v[1]; c.surface_gain=v[2]; c.reaching_gain=v[3]; c.switching_gain=v[4]; c.boundary_width=v[5];
            Require(axis.Init(c,v[6],v[7]),"Point init failed");
            last=block; previous=v;
        }
        for (int j=1;j<=7;++j) Require(v[j]==previous[j],"Config changed inside block");
        SMC::VelocityInput in;
        in.target=v[8]; in.target_acceleration=v[9]; in.measurement=v[10]; in.dt=v[11];
        float u=0; Require(axis.Calc(in,u),"Point Calc failed");
        const SMC::VelocityResult& r=axis.GetResult();
        out << ++count << ',' << block << ',' << r.error << ',' << r.error_integral << ',' << r.sliding_variable
            << ',' << r.requested_output << ',' << u << ',' << r.limited << '\n';
    }
    Require(source.eof() && out.good() && count>0,"Point read/write failed");
    std::cout << "velocity_points=" << count << '\n';
}

static void Simulate(const std::string& directory,int selected)
{
    const double dt=.001;
    for (int scenario=1;scenario<=6;++scenario)
    {
        if (selected && scenario!=selected) continue;
        const float b=scenario==3 ? -3.0f : 3.0f;
        const float bound=scenario==4 ? .25f : 4.0f;
        SMC::VelocityConfig c;
        c.input_gain=b; c.surface_gain=4; c.reaching_gain=6; c.switching_gain=2; c.boundary_width=.25f;
        SMC::Velocity axis; Require(axis.Init(c,-bound,bound),"Case init failed");
        std::ostringstream name; name << directory << "/velocity0" << scenario << ".csv";
        std::ofstream out(name.str().c_str()); Require(out.good(),"Cannot open case output");
        out << std::setprecision(17)
            << "time,target,target_acc,position,rate,error,integral,s,request,caller,applied,limited,enabled,calc_called,reset_event,has_result,disturbance\n";
        double position=0,rate=0; float caller=0;
        for (int i=0;i<8000;++i)
        {
            const double t=i*dt;
            double target=2,target_acc=0;
            if (scenario==2)
            {
                target=.8*std::sin(.8*t)+.5*std::cos(.45*t);
                target_acc=.64*std::cos(.8*t)-.225*std::sin(.45*t);
            }
            if (scenario==5 && i>=1500) target=-1;
            const bool enabled=!(scenario==5 && i>=1000 && i<1500);
            const bool reset=scenario==5 && i==1000;
            if (reset) Require(axis.Reset(),"Reset failed");
            SMC::VelocityInput in;
            in.target=static_cast<float>(target); in.target_acceleration=static_cast<float>(target_acc);
            in.measurement=static_cast<float>(rate); in.dt=static_cast<float>(dt);
            if (enabled) Require(axis.Calc(in,caller),"Case Calc failed");
            const float applied=enabled ? caller : 0;
            const double disturbance=scenario==6 && i>=2000 ? .4 : 0;
            const SMC::VelocityResult& r=axis.GetResult();
            out << t << ',' << target << ',' << target_acc << ',' << position << ',' << rate << ','
                << r.error << ',' << r.error_integral << ',' << r.sliding_variable << ',' << r.requested_output
                << ',' << caller << ',' << applied << ',' << r.limited
                << ',' << enabled << ',' << enabled << ',' << reset << ',' << axis.HasResult() << ',' << disturbance << '\n';
            const double acceleration=double(b)*applied+disturbance;
            position+=rate*dt+.5*acceleration*dt*dt; rate+=acceleration*dt;
            Require(std::isfinite(position) && std::isfinite(rate),"Nonfinite plant state");
        }
        Require(out.good(),"Case output failed"); std::cout << "velocity_case=" << scenario << " rows=8000\n";
    }
}

int main(int argc,char** argv)
{
    try
    {
        if (argc==4 && std::string(argv[1])=="points") Points(argv[2],argv[3]);
        else if ((argc==3 || argc==4) && std::string(argv[1])=="simulate")
        {
            const int selected=argc==4 ? std::stoi(argv[3]) : 0;
            Require(selected>=0 && selected<=6,"Scenario must be 0..6"); Simulate(argv[2],selected);
        }
        else throw std::runtime_error("Usage: points input.csv output.csv | simulate directory [1..6]");
        return 0;
    }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
