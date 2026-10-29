// 第21讲：每个 block 使用同一个实例，输入序列来自共享 CSV。
#include "../main/ALG_SMC.hpp"
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

int main(int argc, char** argv)
{
    try
    {
        if (argc!=2) throw std::runtime_error("Expected input CSV");
        std::ifstream source(argv[1]);
        if (!source.good()) throw std::runtime_error("Cannot open input CSV");
        std::string line;
        if (!std::getline(source,line)) throw std::runtime_error("Missing header");
        SMC::Position axis;
        std::vector<float> previous;
        int previous_block=-1, rows=0;
        std::cout << std::setprecision(17) << "row,block,success,error,error_rate,s,request,output,limited\n";
        while (std::getline(source,line))
        {
            if (line.empty()) continue;
            std::stringstream stream(line);
            std::string field;
            std::vector<float> v;
            while (std::getline(stream,field,',')) v.push_back(std::stof(field));
            if (v.size()!=13) throw std::runtime_error("Expected 13 fields");
            const int block=static_cast<int>(v[0]);
            if (v[0]!=block) throw std::runtime_error("Noninteger block");
            if (block!=previous_block)
            {
                SMC::PositionConfig c;
                c.input_gain=v[1]; c.surface_gain=v[2]; c.reaching_gain=v[3];
                c.switching_gain=v[4]; c.boundary_width=v[5];
                if (!axis.Init(c,v[6],v[7])) throw std::runtime_error("Init failed");
                previous=v; previous_block=block;
            }
            for (int j=1; j<=7; ++j)
                if (previous[j]!=v[j]) throw std::runtime_error("Configuration changed inside block");
            SMC::PositionInput in;
            in.target=v[8]; in.target_rate=v[9]; in.target_acceleration=v[10];
            in.measurement=v[11]; in.measurement_rate=v[12];
            float command=0;
            if (!axis.Calc(in,command)) throw std::runtime_error("Calc failed");
            const SMC::PositionResult& r=axis.GetResult();
            std::cout << ++rows << ',' << block << ",1," << r.error << ',' << r.error_rate
                      << ',' << r.sliding_variable << ',' << r.requested_output
                      << ',' << command << ',' << r.limited << '\n';
        }
        if (!source.eof() || rows==0 || !std::cout.good()) throw std::runtime_error("CSV read/write failure");
        return 0;
    }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
