#pragma once
extern Vtop* dut;
extern u64 sim_time;
extern u8* dpi_mem_array;

//-----------------------------------------------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------------------------------------------
// DM resgister address
constexpr u8 DMI_DM_CONTROL = 0x10;
constexpr u8 DMI_DM_STATUS  = 0x11;
constexpr u8 DMI_ABS_DATA0   = 0x04;
constexpr u8 DMI_ABS_CONTROL = 0x16;
constexpr u8 DMI_ABS_COMMAND = 0x17;
constexpr u8 DMI_PROGBUF0    = 0x20;

constexpr u32 ABSTRACTCS_BUSY_BIT = (1u << 12);

// Dmcontrol bits
constexpr u32 DMCTRL_HALTREQ   = (1u << 31);
constexpr u32 DMCTRL_RESUMEREQ = (1u << 30);
constexpr u32 DMCTRL_DMACTIVE  = (1u << 0);

// Dmstatus bits
constexpr u32 DMSTATUS_ALLRESUMEACK = (1u << 17);
constexpr u32 DMSTATUS_ALLRUNNING   = (1u << 11);
constexpr u32 DMSTATUS_ALLHALTED    = (1u << 9);


// DCSR 
constexpr u16 CSR_DCSR = 0x7b0;
constexpr u16 CSR_DPC  = 0x7b1;

constexpr u32 DCSR_STEP_BIT    = (1u << 2);
constexpr u32 DCSR_EBREAKM_BIT = (1u << 15);
constexpr u32 DCSR_CAUSE_SHIFT = 6;
constexpr u32 DCSR_CAUSE_MASK  = 0x7u;
constexpr u32 DCSR_CAUSE_STEP  = 4u;


constexpr u8 CMDTYPE_ACCESS_REG = 0x00;
constexpr u8 AARSIZE_32 = 2;



//-----------------------------------------------------------------------------------------------------------------
// DMI Functios
//-----------------------------------------------------------------------------------------------------------------
void dmi_write(Vtop* dut, u8 addr, u32 data) {
    u64 raw = (u64(addr) << 33) | (u64(data) << 1) | u64(1);
    dut->DMI_write_req = raw;
}

void dmi_idle(Vtop* dut) {
    dut->DMI_write_req = 0;
}

void dmi_set_read_addr(Vtop* dut, u8 addr) {
    dut->DMI_read_id = addr;
}

u32 dmi_read_value(Vtop* dut) {
    return u32(dut->DMI_read_value);
}


void dbg_tick() {
    dut->clk = 0;
    dut->resetn = u8(!(sim_time <= 4));
    dut->eval();
    sim_time++;

    dut->clk = 1;
    dut->resetn = u8(!(sim_time <= 4));
    dut->eval();
    sim_time++;
}

void dmi_write_pulse(u8 addr, u32 data) {
    dmi_write(dut, addr, data);
    dbg_tick();
    dmi_idle(dut);
}

u32 dmi_read(u8 addr) {
    dmi_set_read_addr(dut, addr);
    dut->eval();
    return dmi_read_value(dut);
}


//-----------------------------------------------------------------------------------------------------------------
// Abstract command & Program buffer functions
//-----------------------------------------------------------------------------------------------------------------
// Codifies abstract commands
u32 pack_command(u8 cmdtype, u8 aarsize, bool aarpostinc, bool postexec,
                  bool transfer, bool write, u16 regno) {
    u32 v = 0;
    v |= u32(cmdtype) << 24;
    v |= u32(aarsize & 0x7) << 20;
    v |= (aarpostinc ? 1u : 0u) << 19;
    v |= (postexec   ? 1u : 0u) << 18;
    v |= (transfer   ? 1u : 0u) << 17;
    v |= (write      ? 1u : 0u) << 16;
    v |= regno;
    return v;
}

inline u16 gpr_regno(u8 n) { return 0x1000 + n; }

bool abs_busy()       { return (dmi_read(DMI_ABS_CONTROL) & ABSTRACTCS_BUSY_BIT) != 0; }
u8   abs_cmderr()     { return (dmi_read(DMI_ABS_CONTROL) >> 8) & 0x7; }


bool wait_abs_done(int max_cycles = 200) {
    int guard = 0;
    while (abs_busy() && guard < max_cycles) { dbg_tick(); guard++; }
    return !abs_busy();
}


bool abs_write_gpr(u8 n, u32 value) {
    dmi_write_pulse(DMI_ABS_DATA0, value);
    u32 cmd = pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, true, gpr_regno(n));
    dmi_write_pulse(DMI_ABS_COMMAND, cmd);
    if (!wait_abs_done()) return false;
    return abs_cmderr() == 0;
}

bool abs_read_gpr(u8 n, u32* out) {
    u32 cmd = pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, false, gpr_regno(n));
    dmi_write_pulse(DMI_ABS_COMMAND, cmd);
    if (!wait_abs_done()) return false;
    if (abs_cmderr() != 0) return false;
    *out = dmi_read(DMI_ABS_DATA0);
    return true;
}

bool abs_write_csr(u16 csr_addr, u32 value) {
    dmi_write_pulse(DMI_ABS_DATA0, value);
    u32 cmd = pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, true, csr_addr);
    dmi_write_pulse(DMI_ABS_COMMAND, cmd);
    if (!wait_abs_done()) return false;
    return abs_cmderr() == 0;
}

bool abs_read_csr(u16 csr_addr, u32* out) {
    u32 cmd = pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, false, csr_addr);
    dmi_write_pulse(DMI_ABS_COMMAND, cmd);
    if (!wait_abs_done()) return false;
    if (abs_cmderr() != 0) return false;
    *out = dmi_read(DMI_ABS_DATA0);
    return true;
}

void pb_write(u8 idx, u32 instr) { dmi_write_pulse(DMI_PROGBUF0 + idx, instr); }
u32  pb_read(u8 idx)             { return dmi_read(DMI_PROGBUF0 + idx); }




//-----------------------------------------------------------------------------------------------------------------
// DM Functions
//-----------------------------------------------------------------------------------------------------------------

namespace rv32 {
    constexpr u32 OPC_OP_IMM = 0x13;
    constexpr u32 OPC_OP     = 0x33;

    inline u32 addi(u8 rd, u8 rs1, i32 imm12) {
        u32 imm = u32(imm12) & 0xFFF;
        return (imm << 20) | (u32(rs1) << 15) | (u32(rd) << 7) | OPC_OP_IMM;
    }
    inline u32 add(u8 rd, u8 rs1, u8 rs2) {
        return (u32(rs2) << 20) | (u32(rs1) << 15) | (u32(rd) << 7) | OPC_OP;
    }
    constexpr u32 ebreak_instr = 0x00100073;
    constexpr u32 nop_instr    = 0x00000013;
}


// Writes a word directly in main memory
void mem_write_word(u32 addr, u32 data) {
    u32 uaddr = addr - DRAM_START_ADDR;
    ((u32*) dpi_mem_array)[uaddr >> 2] = data;
}

void dbg_activate() {
    dmi_write_pulse(DMI_DM_CONTROL, DMCTRL_DMACTIVE);
}

bool dbg_halt_and_wait(int max_cycles = 200) {
    dmi_write_pulse(DMI_DM_CONTROL, DMCTRL_DMACTIVE | DMCTRL_HALTREQ);
    int guard = 0;
    while (!(dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLHALTED) && guard < max_cycles) { dbg_tick(); guard++; }
    return (dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLHALTED) != 0;
}
bool dbg_resume_and_wait(int max_cycles = 200) {
    dmi_write_pulse(DMI_DM_CONTROL, DMCTRL_DMACTIVE | DMCTRL_RESUMEREQ);
    int guard = 0;
    while (!(dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLRESUMEACK) && guard < max_cycles) { dbg_tick(); guard++; }
    return (dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLRESUMEACK) != 0;
}
bool dbg_step_and_wait(int max_cycles = 200) {
    dmi_write_pulse(DMI_DM_CONTROL, DMCTRL_DMACTIVE | DMCTRL_RESUMEREQ);
    int guard = 0;
    while (!(dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLHALTED) && guard < max_cycles) { dbg_tick(); guard++; }
    return (dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLHALTED) != 0;
}
// del Program Buffer ya cargado.
bool abs_exec_progbuf() {
    u32 cmd = pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, /*postexec*/true, /*transfer*/false, false, gpr_regno(0));
    dmi_write_pulse(DMI_ABS_COMMAND, cmd);
    if (!wait_abs_done(300)) return false;
    return abs_cmderr() == 0;
}

//-----------------------------------------------------------------------------------------------------------------
// Debug Tests
//-----------------------------------------------------------------------------------------------------------------

// Halt and resume
bool test_halt_resume() {
    std::cout << "[TEST] halt_resume... ";
    dbg_activate();
    u32 dmstatus_after_activate = dmi_read(DMI_DM_STATUS);
    bool success = dbg_halt_and_wait();
    u32 dmstatus_after_halt = dmi_read(DMI_DM_STATUS);
    success &= dbg_resume_and_wait();

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) {
        std::cout << " (dmstatus tras activar=0x" << std::hex << dmstatus_after_activate
                   << ", dmstatus tras pedir halt=0x" << dmstatus_after_halt << std::dec << ")";
    }
    std::cout << "\n";
    return success;
}

// Read & write from gpr via abstract command
bool test_abs_gpr_rw() {
    std::cout << "[TEST] abs_gpr_rw... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    u32 v = 0;
    success &= abs_write_gpr(5, 0x12345678u);
    success &= abs_read_gpr(5, &v);
    success &= (v == 0x12345678u);

    success &= abs_write_gpr(10, 0xCAFEBABEu);
    success &= abs_read_gpr(10, &v);
    success &= (v == 0xCAFEBABEu);

    std::cout << (success ? "PASS" : "FAIL") << "\n";
    return success;
}

// Test incorrect command
bool test_abs_command_error_running() {
    std::cout << "[TEST] abs_command_error_running... ";
    dbg_activate();

    u32 cmd = pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, false, gpr_regno(1));
    dmi_write_pulse(DMI_ABS_COMMAND, cmd);
    bool success = (abs_cmderr() == 4); 

    dmi_write_pulse(DMI_ABS_CONTROL, 0); // flush cmderr
    std::cout << (success ? "PASS" : "FAIL") << "\n";
    return success;
}

// Test write & read from pb via abstract command
bool test_pb_write_read() {
    std::cout << "[TEST] pb_write_read... ";
    dbg_activate();
    u32 dmcontrol_readback = dmi_read(DMI_DM_CONTROL);
    pb_write(0, rv32::nop_instr);
    pb_write(1, rv32::ebreak_instr);
    u32 v0 = pb_read(0);
    u32 v1 = pb_read(1);
    bool success = (v0 == rv32::nop_instr) && (v1 == rv32::ebreak_instr);

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) {
        std::cout << " (dmcontrol tras activar=0x" << std::hex << dmcontrol_readback
                   << ", progbuf0=0x" << v0 << " expected 0x" << rv32::nop_instr
                   << ", progbuf1=0x" << v1 << " expected 0x" << rv32::ebreak_instr << std::dec << ")";
    }
    std::cout << "\n";
    return success;
}

// Test execute program buffer with 1 instruction
bool test_pb_exec_single_instr() {
    std::cout << "[TEST] pb_exec_single_instr... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    success &= abs_write_gpr(1, 10);
    pb_write(0, rv32::addi(1, 1, 5)); // x1 = x1 + 5
    pb_write(1, rv32::ebreak_instr);
    success &= abs_exec_progbuf();

    u32 v = 0;
    success &= abs_read_gpr(1, &v);
    success &= (v == 15u);

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) std::cout << " (x1=" << v << ", expected 15)";
    std::cout << "\n";
    return success;
}

// Test execute program buffer with >1 instruction
bool test_pb_exec_multi_instr() {
    std::cout << "[TEST] pb_exec_multi_instr... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    success &= abs_write_gpr(1, 4);
    success &= abs_write_gpr(2, 7);
    pb_write(0, rv32::add(3, 1, 2));   // x3 = x1 + x2
    pb_write(1, rv32::addi(3, 3, 1));  // x3 = x3 + 1
    pb_write(2, rv32::ebreak_instr);
    success &= abs_exec_progbuf();

    u32 v = 0;
    success &= abs_read_gpr(3, &v);
    success &= (v == 12u);

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) std::cout << " (x3=" << v << ", expected 12)";
    std::cout << "\n";
    return success;
}

// Test write & read from csr & dcsr
bool test_csr_dpc_dcsr_rw_sanity() {
    std::cout << "[TEST] csr_dpc_dcsr_rw_sanity... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    bool w1 = abs_write_csr(CSR_DPC, 0xdeadbeef);
    u8 cmderr_w1 = abs_cmderr();
    u32 dpc_rb = 0;
    bool r1 = abs_read_csr(CSR_DPC, &dpc_rb);
    u8 cmderr_r1 = abs_cmderr();

    bool w2 = abs_write_csr(CSR_DCSR, 0x00000004);
    u8 cmderr_w2 = abs_cmderr();
    u32 dcsr_rb = 0;
    bool r2 = abs_read_csr(CSR_DCSR, &dcsr_rb);
    u8 cmderr_r2 = abs_cmderr();

    success &= w1 && r1 && w2 && r2;
    success &= (dpc_rb == 0xdeadbeefu);
    success &= (dcsr_rb == 0x400000c4);

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) {
        std::cout << std::hex
                   << " (dpc: write_success=" << w1 << " cmderr_w=" << int(cmderr_w1)
                   << " read_success=" << r1 << " cmderr_r=" << int(cmderr_r1)
                   << " value=0x" << dpc_rb << " expected 0xdeadbeef"
                   << " | dcsr: write_success=" << w2 << " cmderr_w=" << int(cmderr_w2)
                   << " read_success=" << r2 << " cmderr_r=" << int(cmderr_r2)
                   << " value=0x" << dcsr_rb << " expected 0x4)"
                   << std::dec;
    }
    std::cout << "\n";
    return success;
}

// Test step 
bool test_step_single_instruction() {
    std::cout << "[TEST] step_single_instruction... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    u32 base = DRAM_START_ADDR + 0x100;
    mem_write_word(base + 0, rv32::addi(5, 0, 10));  // x5 = 10
    mem_write_word(base + 4, rv32::addi(5, 5, 7));   // x5 = x5 + 7 = 17 (must not execute)
    mem_write_word(base + 8, rv32::ebreak_instr);    // failsafe ebreak

    success &= abs_write_gpr(5, 0);
    success &= abs_write_csr(CSR_DPC, base);

    u32 dcsr_val = 0;
    success &= abs_read_csr(CSR_DCSR, &dcsr_val);
    success &= abs_write_csr(CSR_DCSR, dcsr_val | DCSR_STEP_BIT);

    success &= dbg_step_and_wait(); // un único step
    bool step_completed = success;

    u32 x5 = 0, dpc_after = 0, dcsr_after = 0;
    success &= abs_read_gpr(5, &x5);
    success &= abs_read_csr(CSR_DPC, &dpc_after);
    success &= abs_read_csr(CSR_DCSR, &dcsr_after);

    success &= (x5 == 10u);
    success &= (dpc_after == base + 4);
    success &= (((dcsr_after >> DCSR_CAUSE_SHIFT) & DCSR_CAUSE_MASK) == DCSR_CAUSE_STEP);

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) {
        std::cout << " (step_completed=" << step_completed
                   << ", x5=" << x5 << " expected 10, dpc=0x" << std::hex << dpc_after
                   << " expected 0x" << (base + 4) << ", dcsr=0x" << dcsr_after << std::dec << ")";
    }
    std::cout << "\n";
    return success;
}

// Test multiple consecutive steps
bool test_step_multiple_instructions() {
    std::cout << "[TEST] step_multiple_instructions... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    u32 base = DRAM_START_ADDR + 0x140;
    mem_write_word(base + 0,  rv32::addi(6, 0, 1));  // x6 = 1
    mem_write_word(base + 4,  rv32::addi(6, 6, 2));  // x6 = 3
    mem_write_word(base + 8,  rv32::addi(6, 6, 4));  // x6 = 7
    mem_write_word(base + 12, rv32::ebreak_instr);

    success &= abs_write_gpr(6, 0);
    success &= abs_write_csr(CSR_DPC, base);

    u32 dcsr_val = 0;
    success &= abs_read_csr(CSR_DCSR, &dcsr_val);
    success &= abs_write_csr(CSR_DCSR, dcsr_val | DCSR_STEP_BIT);

    const u32 expected[3] = {1u, 3u, 7u};
    for (int i = 0; i < 3 && success; i++) {
        success &= dbg_step_and_wait();
        u32 x6 = 0;
        success &= abs_read_gpr(6, &x6);
        success &= (x6 == expected[i]);
        if (!success) std::cout << "(paso " << i << ": x6=" << x6 << " expected " << expected[i] << ") ";
    }

    u32 dpc_after = 0;
    success &= abs_read_csr(CSR_DPC, &dpc_after);
    success &= (dpc_after == base + 12);

    std::cout << (success ? "PASS" : "FAIL") << "\n";
    return success;
}

// Test halt & resume without step
bool test_step_disabled_runs_freely() {
    std::cout << "[TEST] step_disabled_runs_freely... ";
    dbg_activate();
    bool success = dbg_halt_and_wait();

    u32 base = DRAM_START_ADDR + 0x180;
    mem_write_word(base + 0, rv32::addi(7, 0, 1));  // x7 = 1
    mem_write_word(base + 4, rv32::addi(7, 7, 1));  // x7 = 2
    mem_write_word(base + 8, rv32::ebreak_instr);   // must halt here

    success &= abs_write_gpr(7, 0);
    success &= abs_write_csr(CSR_DPC, base);

    u32 dcsr_val = 0;
    success &= abs_read_csr(CSR_DCSR, &dcsr_val);
    success &= abs_write_csr(CSR_DCSR, (dcsr_val & ~DCSR_STEP_BIT) | DCSR_EBREAKM_BIT);

    success &= dbg_resume_and_wait();
    int guard = 0;
    while (!(dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLHALTED) && guard < 200) { dbg_tick(); guard++; }
    success &= ((dmi_read(DMI_DM_STATUS) & DMSTATUS_ALLHALTED) != 0);
    
    u32 x7 = 0;
    success &= abs_read_gpr(7, &x7);
    success &= (x7 == 2u);

    std::cout << (success ? "PASS" : "FAIL");
    if (!success) std::cout << " (x7=" << x7 << " expected 2)";
    std::cout << "\n";
    return success;
}


bool run_dbg_tests(const std::string& name) {
    if (name == "all") {
        bool success = true;
        success &= test_halt_resume();
        success &= test_abs_gpr_rw();
        success &= test_abs_command_error_running();
        success &= test_pb_write_read();
        success &= test_pb_exec_single_instr();
        success &= test_pb_exec_multi_instr();
        success &= test_csr_dpc_dcsr_rw_sanity();
        success &= test_step_single_instruction();
        success &= test_step_multiple_instructions();
        success &= test_step_disabled_runs_freely();
        return success;
    }
    if (name == "halt_resume")               return test_halt_resume();
    if (name == "abs_gpr_rw")                return test_abs_gpr_rw();
    if (name == "abs_command_error_running") return test_abs_command_error_running();
    if (name == "pb_write_read")             return test_pb_write_read();
    if (name == "pb_exec_single_instr")       return test_pb_exec_single_instr();
    if (name == "pb_exec_multi_instr")        return test_pb_exec_multi_instr();
    if (name == "csr_dpc_dcsr_rw_sanity")     return test_csr_dpc_dcsr_rw_sanity();
    if (name == "step_single_instruction")    return test_step_single_instruction();
    if (name == "step_multiple_instructions") return test_step_multiple_instructions();
    if (name == "step_disabled_runs_freely")  return test_step_disabled_runs_freely();

    std::cerr << "Unknown --dbg-test name: " << name << "\n";
    return false;
}