
#include <ios>
#include <iostream>
#include <string>
#include <fstream>
#include <cassert>
#include <mutex>
#include <queue>
#include <thread>

#include <elf.h>
#include <unistd.h>
#include <termios.h>

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vtop.h"
#include "Vtop__Dpi.h"
#include "Vtop_top.h"

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

u32 dpi_bootrom_size;
u8* dpi_bootrom_array;

std::ofstream stdout_file;
std::ostream* stdout_file_ptr = &std::cout;
std::ostream& sf() {
    return *(stdout_file_ptr);
}

std::ofstream prof_file;
std::ostream* prof_file_ptr = &std::cout;
std::ostream& pf() {
    return *(prof_file_ptr);
}

std::ofstream trace_file;

Vtop *dut;
u64 sim_time = 0;

bool is_term_it = false;
std::mutex serial_buff_mtx;
std::queue<u8> serial_buff;

void terminal_io_thread() {
    // Config non-block, no echo, 1 char blocking terminal
    struct termios attr;
    tcgetattr(STDIN_FILENO, &attr);
    attr.c_lflag &= ~(ICANON | ECHO);
    attr.c_cc[VMIN] = 1;
    tcsetattr(STDIN_FILENO, TCSANOW, &attr);

    u8 term_buff[20];

    while(1) {
        i32 bytes_read = read(STDIN_FILENO, term_buff, 20);

        for (i32 i = 0; i < bytes_read; i++) {
            u8 c = term_buff[i];

            // This is to ignore scape secuence characters
            if (c == 0x1B) break;

            serial_buff_mtx.lock();
            serial_buff.push(c);
            serial_buff_mtx.unlock();
        }
    }
}

u8 pop_serial_buff() {
    if (serial_buff.empty()) return 0;

    u8 r = serial_buff.front();

    serial_buff_mtx.lock();
    serial_buff.pop();
    serial_buff_mtx.unlock();

    return r;
}

void simulation_exit(i32 exit_code) {

    #ifdef TRACE_WAVE
        m_trace->close();
    #endif

    pf() << '\n';
    pf() << "exit_status: " << exit_code << '\n';
    pf() << "sim_ticks: " << sim_time << '\n';

    if(stdout_file.is_open()) stdout_file.close();
    if(prof_file.is_open()) prof_file.close();

    exit(exit_code);
}

// Simulate peripherals

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
    load_elf_segment(f, phdr, dpi_bootrom_size, dpi_bootrom_array);

    // The same but with ram section
    f.seekg(ehdr->e_phoff + 2 * sizeof(*phdr));
    f.read(reinterpret_cast<char*>(phdr.get()), sizeof(*phdr));
    load_elf_segment(f, phdr, dpi_mem_size, dpi_mem_array);

    f.close();
}

void load_bin(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);

    if (!file.is_open()) {
        std::cerr << "ERROR: Could not open binary file: " << filename << std::endl;
        exit(-1);
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    dpi_mem_size = 5 * 1024 * 1024; // 5 MB size
    if (size > dpi_mem_size) {
        std::cerr << "ERROR: Binary file " << filename << " (" << size << " bytes) exceeds memory size (" << dpi_mem_size << " bytes)" << std::endl;
        exit(-1);
    }

    dpi_mem_array = new u8[dpi_mem_size];

    file.read(reinterpret_cast<char*>(dpi_mem_array), size);
    file.close();
}


void icb_dpi_slv_posedge(i32 addr, i32 data, i32 op, i32 wstrbs) {
    bool is_store = (op == 1);
    u32 uaddr = u32(addr);
    u32 udata = u32(data);

    if (is_store) {
        if (uaddr == EXIT_STATUS_ADDR) {
            simulation_exit(data);
        }
        else if (uaddr == SERIAL_TX_DATA_ADDR) {
            sf() << char(data & 0xFF);
        }
        else if ((uaddr & 0x80000000) == DRAM_START_ADDR) {
            uaddr -= DRAM_START_ADDR; // Align to 0
            uaddr = (uaddr >> 2) << 2; // Align to 4B
            for (int i = 0; i < 4; i++) {
                if ((wstrbs >> i) & 1) dpi_mem_array[uaddr + i] = u8((udata >> (8 * i)) & 0xFF);
            }
        }
    }
}

void icb_dpi_slv_comb(i32 addr, i32 data, i32 op, i32 wstrbs, i32* resp_data, u8* err) {
    bool is_load = (op == 0);
    u32 uaddr = u32(addr);
    u32 udata = u32(data);

    *err = 0;
    *resp_data = 0;
    
    if (is_load) {
    
        if (uaddr == SERIAL_TX_STATUS_ADDR) {
            *resp_data = 1;
        }
        else if (uaddr == SERIAL_RX_STATUS_ADDR) {
            *resp_data = serial_buff.size();
        }   
        else if (uaddr == SERIAL_RX_DATA_ADDR) {
            *resp_data = pop_serial_buff();
        }
        else if ((uaddr & 0x80000000) == DRAM_START_ADDR) {
            uaddr -= DRAM_START_ADDR; // Align to 0

            if (uaddr > dpi_mem_size) {
                std::cout << "Slv Comb, Out of bounds addr " << uaddr << "/" << dpi_mem_size << "\n";
                simulation_exit(-1);
            }

            *resp_data = ((u32*) dpi_mem_array)[uaddr >> 2];
        }
    }

}

int dpi_read_word(i32 addr) {
    u32 uaddr = u32(addr);
    if (uaddr >= DRAM_START_ADDR) {
        uaddr -= DRAM_START_ADDR;

        if (uaddr > dpi_mem_size) {
            std::cout << "Read, Out of bounds addr " << uaddr << "/" << dpi_mem_size << "\n";
            simulation_exit(-1);
        }

        return ((u32*) dpi_mem_array)[uaddr >> 2];
    } 
    else {
        return 0;
    }
}

void dpi_write_byte(i32 addr, i32 i, i32 data) {
    u32 uaddr = u32(addr);
    u32 udata = u32(data);
    if (uaddr >= DRAM_START_ADDR) {
        uaddr -= DRAM_START_ADDR; // Align to 0
        uaddr = (uaddr >> 2) << 2; // Align to 4B
        uaddr += i;

        if (uaddr > dpi_mem_size) {
            std::cout << "Write, Out of bounds addr " << uaddr << "/" << dpi_mem_size << "\n";
            simulation_exit(-1);
        }

        dpi_mem_array[uaddr] = u8((udata >> (8 * i)) & 0xFF);
    } 
}

int main(int argc, char** argv) {
    // Evaluate Verilator comand args
    Verilated::commandArgs(argc, argv);

    u64 max_sim_time = 0;

    // Evaluate our command args
    for(i32 i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "-e") {
            i++;
            if (i == argc) break;
            load_elf(argv[i]);
        }
        else if (arg == "-b") {
            i++;
            if (i == argc) break;
            load_bin(argv[i]);
        }
        else if (arg == "--max-time") {
            i++;
            if (i == argc) break;
            max_sim_time = std::stoi(argv[i]);
        }
        else if (arg == "--out") {
            i++;
            if (i == argc) break;
            stdout_file.open(argv[i]);
            stdout_file_ptr = &stdout_file;
        }
        else if (arg == "--prof") {
            i++; 
            if (i == argc) break;
            prof_file.open(argv[i]);
            prof_file_ptr = &prof_file;
        }
        else if (arg == "--it") {
            // Create thread that handles io
            is_term_it = true;
            std::thread t(terminal_io_thread);
            t.detach();
        }
        
    }

    dut = new Vtop;

    #ifdef TRACE_WAVE
        // trace signals 5 levels under dut
        Verilated::traceEverOn(true);
        m_trace = new VerilatedVcdC;
        dut->trace(m_trace, 100);
        m_trace->open("waveform.vcd");
    #endif

    while (max_sim_time == 0 || sim_time < max_sim_time) {
        
        dut->top->meip_irq = (serial_buff.size() > 0);
        
        // Clk Toggle
        dut->clk ^= 1;
        // Reset signal
        bool reset_on = sim_time <= 4;
        dut->resetn = u8(!reset_on);

        // Simulation (2 eval to sync DPI better)
        dut->eval();
        dut->eval();
        
        #ifdef TRACE_WAVE
            // Trace signals
            m_trace->dump(sim_time);
        #endif

        sim_time++;
    }

    simulation_exit(-1);

}
