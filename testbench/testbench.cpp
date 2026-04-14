
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
std::ofstream spike_file;

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

void mux_addr(u32& addr, u8*& mem_arr, u32& mem_size) {
    // Bootrom
    if (addr < DRAM_START_ADDR) {
        mem_arr = dpi_bootrom_array;
        mem_size = dpi_bootrom_size;
        addr -= BOOTROM_START_ADDR;
    }
    // DRAM
    else {
        mem_arr = dpi_mem_array;
        mem_size = dpi_mem_size;
        addr -= DRAM_START_ADDR;
    }
}

void dpi_mem_store_byte(int addr, int idx, int data) {
    
    u8* mem_arr;
    u32 mem_size;
    u32 maddr = addr;
    mux_addr(maddr, mem_arr, mem_size);
    
    if (maddr < mem_size) {
        u32 aligned_addr = (maddr >> 2) << 2;
        mem_arr[aligned_addr + idx] = u8(data);
    }
}

int dpi_mem_load(int addr) {

    u8* mem_arr;
    u32 mem_size;
    u32 maddr = addr;
    mux_addr(maddr, mem_arr, mem_size);

    if (maddr < mem_size) {
        return ((u32*) mem_arr)[maddr >> 2];
    }
    else return 0;
}

#ifdef RTL_CACHE

// Simulate cache memory controller

#include "Vtop_cache_wrap__D0.h"
#include "Vtop_cache_wrap__D1.h"

void request_mux(u32& addr, u32*& wmem, u32& wmem_size) {
    
    // Word to byte level addr
    addr *= 4;
    
    // Bootrom
    if (addr < DRAM_START_ADDR) {
        wmem = (u32*) dpi_bootrom_array;
        wmem_size = dpi_bootrom_size / 4;
        // Go back to word level at 0
        addr = (addr - BOOTROM_START_ADDR) / 4;
    }
    // RAM
    else {
        wmem = (u32*) dpi_mem_array;
        wmem_size = dpi_mem_size / 4;
        addr = (addr - DRAM_START_ADDR) / 4;
    }
}

void dpi_write_mem_block(i32) {

    u32 nwords = dut->top->dcache->BLK_WORDS;
    u32 addr = dut->top->dcache->o_cm_addr * nwords;

    u32* word_mem;
    u32 word_mem_size;
    request_mux(addr, word_mem, word_mem_size);

    for (u32 i = 0; i < nwords; i++) {
        if (addr + i < word_mem_size) {
            word_mem[addr + i] = dut->top->dcache->dpi_write_blk[i];
        }
    }
}

void dpi_read_mem_block(i32 dpi_id) {
    u32* word_mem;
    u32 word_mem_size;

    if (dpi_id == 0) {
        u32 nwords = dut->top->dcache->BLK_WORDS;
        u32 addr = dut->top->dcache->o_cm_addr * nwords;
        request_mux(addr, word_mem, word_mem_size);

        for (u32 i = 0; i < nwords; i++) {
            if (addr + i < word_mem_size) {
                dut->top->dcache->dpi_read_blk[i] = word_mem[addr + i];
            }
        }
    }
    else if (dpi_id == 1) {
        u32 nwords = dut->top->icache->BLK_WORDS;
        u32 addr = dut->top->icache->o_cm_addr * nwords;
        request_mux(addr, word_mem, word_mem_size);

        for (u32 i = 0; i < nwords; i++) {
            if (addr + i < word_mem_size) {
                dut->top->icache->dpi_read_blk[i] = word_mem[addr + i];
            }
        }
    }
    
}

#endif

// Simulate peripherals

int dpi_mmio(int addr, int data, int op) {

    u32 regdata = data;
    u32 uaddr = addr;
    bool is_load = (op == 1);
    bool is_store = !is_load;

    switch (uaddr) {

        case EXIT_STATUS_ADDR:
            if (is_store) simulation_exit(data);
        break;

        case SERIAL_TX_STATUS_ADDR:
            // Its ready by default
            if (is_load) return 1; 
        break;

        case SERIAL_TX_DATA_ADDR:
            if (is_store) {
                // sf() << char(regdata & 0xFF);
                // if (is_term_it) sf().flush();
            }
        break;

        case SERIAL_RX_STATUS_ADDR:
            if (is_load) return serial_buff.size();
        break;

        case SERIAL_RX_DATA_ADDR:
            if (is_load) return pop_serial_buff();
        break;

        default:
        break;

    }

    return 0;
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
    load_elf_segment(f, phdr, dpi_bootrom_size, dpi_bootrom_array);

    // The same but with ram section
    f.seekg(ehdr->e_phoff + 2 * sizeof(*phdr));
    f.read(reinterpret_cast<char*>(phdr.get()), sizeof(*phdr));
    load_elf_segment(f, phdr, dpi_mem_size, dpi_mem_array);

    f.close();
}

int main(int argc, char** argv) {
    // Evaluate Verilator comand args
    Verilated::commandArgs(argc, argv);

    std::string elf_path;
    u64 max_sim_time = 0;

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
        else if (arg == "--trace-spike") {
            i++;
            if (i == argc) break;
            spike_file.open(argv[i]);
        }
        
    }

    dut = new Vtop;
    load_elf(elf_path);

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
