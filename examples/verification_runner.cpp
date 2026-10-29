// 主机验证工具。对象模型、文件 I/O 和假设参数都不进入生产库。
#include "ALG_SMC.hpp"
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace
{
    void Require(bool ok, const char* message)
    {
        if (!ok)
            throw std::runtime_error(message);
    }

    SMC::PositionConfig Config(float input_gain)
    {
        SMC::PositionConfig c;
        c.input_gain = input_gain;
        c.surface_gain = 4.0f;
        c.reaching_gain = 6.0f;
        c.switching_gain = 2.0f;
        c.boundary_width = 0.25f;
        return c;
    }

    void Points(const std::string& input_path, const std::string& output_path)
    {
        std::ifstream source(input_path.c_str());
        std::ofstream output(output_path.c_str());
        Require(source.good() && output.good(), "Cannot open points CSV");
        output << "success,error,error_rate,s,request,output,limited\n" << std::setprecision(9);
        std::string line;
        Require(bool(std::getline(source, line)), "Empty points file"); // Header.
        int rows = 0;
        while (std::getline(source, line))
        {
            if (line.empty())
                continue;
            std::stringstream row(line);
            std::string field;
            std::vector<float> values;
            while (std::getline(row, field, ','))
                values.push_back(std::stof(field));
            Require(values.size() == 12, "Expected 12 input columns");
            SMC::PositionConfig c;
            c.input_gain = values[0]; c.surface_gain = values[1];
            c.reaching_gain = values[2]; c.switching_gain = values[3];
            c.boundary_width = values[4];
            SMC::Position p;
            Require(p.Init(c, values[5], values[6]), "Invalid point parameters");
            SMC::PositionInput in;
            in.target = values[7]; in.target_rate = values[8];
            in.target_acceleration = values[9];
            in.measurement = values[10]; in.measurement_rate = values[11];
            float u = 0;
            Require(p.Calc(in, u), "Point calculation failed");
            const SMC::PositionResult& r = p.GetResult();
            output << "1," << r.error << ',' << r.error_rate << ',' << r.sliding_variable
                   << ',' << r.requested_output << ',' << u << ',' << r.limited << '\n';
            ++rows;
        }
        Require(source.eof() && output.good() && rows > 0, "Points CSV read/write failure");
        std::cout << "points_rows=" << rows << '\n';
    }

    void Simulate(const std::string& directory, int selected = 0)
    {
        // 假设对象：瞬时电流执行；每区间加速度恒定，无摩擦/驱动器动态。
        // 使用独立于库的 double 对象积分；控制器输入显式转为 float。
        const double dt = 0.001;
        const int intervals = 8000;
        for (int scenario = 1; scenario <= 5; ++scenario)
        {
            if (selected != 0 && scenario != selected)
                continue;
            const float b = scenario == 4 ? -3.0f : 3.0f;
            const float bound = scenario == 5 ? 1.0f : 4.0f;
            SMC::Position controller;
            Require(controller.Init(Config(b), -bound, bound), "Scenario init failed");
            std::ostringstream name;
            name << directory << "/case0" << scenario << ".csv";
            std::ofstream out(name.str().c_str());
            Require(out.good(), "Cannot create scenario file");
            out << "time,target,target_rate,target_acc,position,rate,measurement,measurement_rate,"
                   "error,error_rate,s,request,output,limited,disturbance\n"
                << std::setprecision(17);
            double position = -0.2;
            double rate = 0.0;
            for (int i = 0; i < intervals; ++i)
            {
                const double time = i * dt;
                double target = 0.5, target_rate = 0, target_acc = 0;
                if (scenario == 2 || scenario == 5)
                {
                    target = 0.25 * std::sin(0.8 * time) + 0.15 * std::cos(0.45 * time);
                    target_rate = 0.2 * std::cos(0.8 * time) - 0.0675 * std::sin(0.45 * time);
                    target_acc = -0.16 * std::sin(0.8 * time) - 0.030375 * std::cos(0.45 * time);
                }
                const double disturbance = scenario == 3 && i >= 2000 ? 0.4 : 0.0;
                const double measurement = position + (scenario == 5 ? 0.001*std::sin(71*time) : 0);
                const double measurement_rate = rate + (scenario == 5 ? 0.01*std::cos(53*time) : 0);
                SMC::PositionInput in;
                in.target = static_cast<float>(target);
                in.target_rate = static_cast<float>(target_rate);
                in.target_acceleration = static_cast<float>(target_acc);
                in.measurement = static_cast<float>(measurement);
                in.measurement_rate = static_cast<float>(measurement_rate);
                float u = 0;
                Require(controller.Calc(in, u), "Scenario calculation failed");
                const SMC::PositionResult& r = controller.GetResult();
                out << time << ',' << target << ',' << target_rate << ',' << target_acc << ','
                    << position << ',' << rate << ',' << measurement << ',' << measurement_rate << ','
                    << r.error << ',' << r.error_rate << ',' << r.sliding_variable << ','
                    << r.requested_output << ',' << u << ',' << r.limited << ',' << disturbance << '\n';
                const double acceleration = double(b) * u + disturbance;
                position += rate * dt + 0.5 * acceleration * dt * dt;
                rate += acceleration * dt;
                Require(std::isfinite(position) && std::isfinite(rate), "Nonfinite plant state");
            }
            Require(out.good(), "Scenario write failure");
            std::cout << "scenario=" << scenario << " intervals=" << intervals << '\n';
        }
    }
}

int main(int argc, char** argv)
{
    try
    {
        if (argc == 4 && std::string(argv[1]) == "points")
            Points(argv[2], argv[3]);
        else if (argc == 3 && std::string(argv[1]) == "simulate")
            Simulate(argv[2]);
        else if (argc == 4 && std::string(argv[1]) == "simulate")
        {
            const int selected = std::stoi(argv[3]);
            Require(selected >= 1 && selected <= 5, "Scenario must be 1..5");
            Simulate(argv[2], selected);
        }
        else
            throw std::runtime_error("Usage: verification_runner points input.csv output.csv | simulate directory [1..5]");
        return 0;
    }
    catch (const std::exception& e)
    {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
