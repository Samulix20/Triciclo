
#include <iostream>
#include <string>
#include <fstream>
#include <cassert>

#include <elf.h>
#include <unistd.h>
#include <termios.h>

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vfpga_top.h"
#include "Vfpga_top_csr_file.h"
#include "Vfpga_top_fpga_top.h"
#include "Vfpga_top_triciclo.h"

#include "rvtarget.h"

// Short typenames
using i64 = int64_t;
using u64 = uint64_t;
using i32 = int32_t;
using u32 = uint32_t;
using i8 = int8_t;
using u8 = uint8_t;

// Simulation context globals

#ifdef TRACE_WAVE
    VerilatedVcdC* m_trace;
#endif

u32 dpi_mem_size;
u8* dpi_mem_array;

Vfpga_top *dut;
u64 sim_time = 0;

void bit_set(u32& r, u32 b) {
    r |= 1 << b;
}

void bit_clear(u32& r, u32 b) {
    r &= ~(1 << b);
}

bool bit_get(u32 r, u32 b) {
    return (r >> b) & 1;
}

void simulation_exit(i32 exit_code) {

    #ifdef TRACE_WAVE
        m_trace->close();
    #endif

    u64 cycles = dut->fpga_top->core->csr_file->mcycle;
    u64 instr = dut->fpga_top->core->csr_file->minstret;
    std::cout << "[DEBUG] Instret " << instr << " Cycles " << cycles << "\n";
    std::cout << "[DEBUG] IPC " << float(instr) / cycles << "\n";

    exit(exit_code);
}

void load_elf_segment(std::ifstream& f, std::unique_ptr<Elf32_Phdr>& phdr, u32& size, u8*& arr) {
    // Make sure its loadable
    assert(phdr->p_type == PT_LOAD);

    // Alloc array
    size =  phdr->p_memsz;
    arr = new u8[size];

    // Go to the segment data and read
    f.seekg(phdr->p_offset);
    // Copy only the data present in the ELF file
    f.read((char*) arr, phdr->p_filesz);
}

void load_elf(const std::string filename) {
    std::ifstream f(filename, std::ios::binary);
    // Check file is open
    assert(f.is_open());

    // Read header
    std::unique_ptr<Elf32_Ehdr> ehdr(new Elf32_Ehdr);
    f.read(reinterpret_cast<char*>(ehdr.get()), sizeof(*ehdr));

    // Check is a 32 bit elf file
    assert(ehdr->e_ident[4] == 1);
    // Check is for RISC-V
    assert(ehdr->e_machine == EM_RISCV); 

    std::unique_ptr<Elf32_Phdr> phdr(new Elf32_Phdr);

    // Set fd to read program header
    // Seek and read segment 1 cause segment 0 is used for RV attributes
    f.seekg(ehdr->e_phoff + 1 * sizeof(*phdr));
    f.read(reinterpret_cast<char*>(phdr.get()), sizeof(*phdr));
    load_elf_segment(f, phdr, dpi_mem_size, dpi_mem_array);

    f.close();
}


int main(int argc, char** argv) {
    // Evaluate Verilator comand args
    Verilated::commandArgs(argc, argv);

    std::string elf_path;
    u64 max_sim_time = 0;
    u32 nwrites = 0;
    bool first_write = true;

    // Evaluate our command args
    for(i32 i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "-e") {
            i++;
            if (i == argc) break;
            elf_path = argv[i];
        }
        else if (arg == "--max-time") {
            i++;
            if (i == argc) break;
            max_sim_time = std::stoi(argv[i]);
        }
    }

    dut = new Vfpga_top;
    load_elf(elf_path);

    std::cout << "[DEBUG] Bin ELF loaded, size " << dpi_mem_size / 1024 << " kiB\n";

    #ifdef TRACE_WAVE
        // trace signals 5 levels under dut
        Verilated::traceEverOn(true);
        m_trace = new VerilatedVcdC;
        dut->trace(m_trace, 100);
        m_trace->open("waveform.vcd");
    #endif

    // Default values
    dut->fpga_ctrl_reg = 0;
    dut->fpga_mem_addr = 0;
    dut->fpga_mem_data = 0;

    while (max_sim_time == 0 || sim_time < max_sim_time) {
        
        // Clk Toggle
        dut->clk ^= 1;
        // Reset signal
        bool reset_on = sim_time <= 4;
        dut->resetn = u8(!reset_on);

        if (!reset_on && dut->clk && bit_get(dut->fpga_ctrl_reg, 4)) {
            std::cout << "[DEBUG] Core exit called, status: " << i32(dut->core_data_reg >> 8) << "\n";
            simulation_exit(0);
        }

        if (!reset_on && dut->clk && dut->core_exit) {
            bit_set(dut->fpga_ctrl_reg, 4);
        }

        // Set inputs is over
        if (nwrites * 4 < dpi_mem_size) {
            if (!reset_on && dut->clk) {
                bit_clear(dut->fpga_ctrl_reg, 1);
                bit_set(dut->fpga_ctrl_reg, 2);
                dut->fpga_mem_data = ((u32*) dpi_mem_array)[nwrites];
                dut->fpga_mem_addr = nwrites * 4;
                nwrites++;
            }
        }
        // Print outputs
        else {
            if (first_write) {
                first_write = false;
                std::cout << "[DEBUG] RAM loaded, took " <<  sim_time / 2 << " cycles\n";
                std::cout << "[DEBUG] RISC-V core output:\n";
            }

            dut->fpga_mem_addr = 0;
            dut->fpga_mem_data = 0;
            
            // Enable
            bit_set(dut->fpga_ctrl_reg, 0);
            bit_clear(dut->fpga_ctrl_reg, 1);

            if (!reset_on && dut->clk) {
                if (bit_get(dut->fpga_ctrl_reg, 2)) {
                    bit_clear(dut->fpga_ctrl_reg, 2);
                    std::cout << char(dut->core_data_reg);
                }
            }
        }

        // Set data
        if (dut->clk && dut->core_data_write) {
            bit_set(dut->fpga_ctrl_reg, 2);
        }

        // Simulation
        dut->eval();
        
        #ifdef TRACE_WAVE
            // Trace signals
            m_trace->dump(sim_time);
        #endif

        sim_time++;
    }

    simulation_exit(-1);

}
