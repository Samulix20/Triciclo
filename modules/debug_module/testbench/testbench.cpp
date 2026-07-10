#include <verilated.h>
#include "Vdebug_module.h"
#include "Vdebug_module_debug_module.h"
#include <gtest/gtest.h>

#include <cstdint>
#include <cstdio>
#include <array>
#include <string>

// Bit layout
namespace bits {

// dbg_write_request_t (41 bits): DM_write_id[40:33] DM_write_data[32:1] DM_write[0]
inline uint64_t pack_write_req(uint8_t id, uint32_t data, bool we) {
    return (uint64_t(id) << 33) | (uint64_t(data) << 1) | (we ? 1u : 0u);
}

// dbg_core_status_t (35 bits): reg_read[34:3] running[2] halted[1] resumeACK[0]
inline uint64_t pack_core_status(uint32_t reg_read, bool running, bool halted, bool resumeACK) {
    return (uint64_t(reg_read) << 3) | (running ? 4u : 0u) | (halted ? 2u : 0u) | (resumeACK ? 1u : 0u);
}

// dbg_core_control_t (48 bits):
//   write_request[47:10] { write_enable[47] id[46:42] data[41:10] }
//   read_request[9:5] pb_exec[4] halt_request[3] hart_reset[2] reset_request[1] resume_request[0]
struct CoreControl {
    bool     write_enable;
    uint8_t  write_id;
    uint32_t write_data;
    uint8_t  read_request;
    bool     pb_exec, halt_request, hart_reset, reset_request, resume_request;
};
inline CoreControl unpack_core_control(uint64_t v) {
    CoreControl c;
    c.write_enable   = (v >> 47) & 0x1;
    c.write_id       = (v >> 42) & 0x1F;
    c.write_data     = (uint32_t)((v >> 10) & 0xFFFFFFFFull);
    c.read_request    = (v >> 5) & 0x1F;
    c.pb_exec         = (v >> 4) & 0x1;
    c.halt_request    = (v >> 3) & 0x1;
    c.hart_reset      = (v >> 2) & 0x1;
    c.reset_request   = (v >> 1) & 0x1;
    c.resume_request  = (v >> 0) & 0x1;
    return c;
}

// dmcontrol_t
inline uint32_t pack_dmcontrol(bool haltreq, bool resumereq, bool hartreset,
                                bool ackhavereset, bool ndmreset, bool dmactive) {
    uint32_t v = 0;
    v |= (haltreq      ? 1u : 0u) << 31;
    v |= (resumereq    ? 1u : 0u) << 30;
    v |= (hartreset    ? 1u : 0u) << 29;
    v |= (ackhavereset ? 1u : 0u) << 28;
    v |= (ndmreset     ? 1u : 0u) << 1;
    v |= (dmactive     ? 1u : 0u) << 0;
    return v;
}

struct DmStatusView {
    bool allhavereset, anyhavereset, allrunning, anyrunning, allhalted, anyhalted, allresumeack, anyresumeack;
    uint8_t version;
};

inline DmStatusView unpack_dmstatus(uint32_t v) {
    DmStatusView s;
    s.allhavereset = (v >> 19) & 1;
    s.anyhavereset = (v >> 18) & 1;
    s.allresumeack = (v >> 17) & 1;
    s.anyresumeack = (v >> 16) & 1;
    s.allrunning   = (v >> 11) & 1;
    s.anyrunning   = (v >> 10) & 1;
    s.allhalted    = (v >> 9) & 1;
    s.anyhalted    = (v >> 8) & 1;
    s.version      = v & 0xF;
    return s;
}

struct AbstractcsView {
    uint8_t progbufsize;
    bool    busy;
    uint8_t cmderr;
    uint8_t datacount;
};

inline AbstractcsView unpack_abstractcs(uint32_t v) {
    AbstractcsView a;
    a.progbufsize = (v >> 24) & 0x1F;
    a.busy        = (v >> 12) & 0x1;
    a.cmderr      = (v >> 8) & 0x7;
    a.datacount   = v & 0xF;
    return a;
}

// command_t (32 bits): cmdtype[31:24] aarsize[22:20] aarpostincrement[19]
//                       postexec[18] transfer[17] write[16] regno[15:0]
inline uint32_t pack_command(uint8_t cmdtype, uint8_t aarsize, bool aarpostinc,
                              bool postexec, bool transfer, bool write, uint16_t regno) {
    uint32_t v = 0;
    v |= uint32_t(cmdtype) << 24;
    v |= uint32_t(aarsize & 0x7) << 20;
    v |= (aarpostinc ? 1u : 0u) << 19;
    v |= (postexec   ? 1u : 0u) << 18;
    v |= (transfer   ? 1u : 0u) << 17;
    v |= (write      ? 1u : 0u) << 16;
    v |= regno;
    return v;
}

}

// Direcciones DMI
namespace addr {
constexpr uint8_t ABS_DATA_0  = 0x04;
constexpr uint8_t DM_CONTROL  = 0x10;
constexpr uint8_t DM_STATUS   = 0x11;
constexpr uint8_t ABS_CONTROL = 0x16;
constexpr uint8_t ABS_COMMAND = 0x17;
constexpr uint8_t PROGBUF0    = 0x20;
constexpr uint8_t PROGBUF15   = 0x2f;
}

// Regno de GPR x0..x31
inline uint16_t gpr_regno(uint8_t n) { return 0x1000 + n; }

// cmdtype de Access Register
constexpr uint8_t CMDTYPE_ACCESS_REG = 0x00;
constexpr uint8_t AARSIZE_32 = 2;

// Estados DM
inline const char* dm_state_name(uint8_t s) {
    switch (s) {
        case 0: return "RUNNING ";
        case 1: return "HALTING ";
        case 2: return "HALTED  ";
        case 3: return "RESUMING";
        case 4: return "EXEC_PB ";
        default: return "???     ";
    }
}

//----------------------------------------------------------------------
// Core dummy
//----------------------------------------------------------------------
class MockCore {
public:
    enum State { M_RUNNING, M_HALTING, M_HALTED, M_RESUMING, M_RESUME_PB, M_EXEC_PB };

    // Latencias 
    int halt_latency   = 2;
    int resume_latency = 2;
    int pbexec_latency = 3;

    State state = M_RUNNING;
    std::array<uint32_t, 32> regfile{};

    // Salida al DM
    bool running_o = true, halted_o = false, resumeack_o = true;

    void recompute_outputs() {
        running_o = false; halted_o = false; resumeack_o = false;
        switch (state) {
            case M_RUNNING:   running_o = true; resumeack_o = true; break;
            case M_HALTING:   running_o = true; break;
            case M_HALTED:    halted_o = true; break;
            case M_RESUMING:  break;
            case M_RESUME_PB: break;
            case M_EXEC_PB:   running_o = true; break;
        }
    }

    uint32_t reg_read(uint8_t idx) const { return regfile[idx & 0x1F]; }

    // Flanco de reloj
    void clock(const bits::CoreControl& c) {
        bool rst = c.hart_reset || c.reset_request;
        State next = state;
        switch (state) {
            case M_RUNNING:
                if (!rst && c.halt_request)      { next = M_HALTING;  cnt_ = halt_latency; }
                else if (rst && !c.halt_request)  next = M_RUNNING;
                else if (rst && c.halt_request)   next = M_HALTED;
                break;
            case M_HALTING:
                if (--cnt_ <= 0) next = M_HALTED;
                break;
            case M_HALTED:
                if (c.resume_request)             { next = M_RESUMING; cnt_ = resume_latency; }
                else if (rst && !c.halt_request)  next = M_RUNNING;
                else if (rst && c.halt_request)   next = M_HALTED;
                else if (c.pb_exec)               { next = M_RESUME_PB; cnt_ = 1; }
                break;
            case M_RESUME_PB:
                if (--cnt_ <= 0) { next = M_EXEC_PB; cnt_ = pbexec_latency; }
                break;
            case M_RESUMING:
                if (--cnt_ <= 0) next = M_RUNNING;
                break;
            case M_EXEC_PB:
                if (--cnt_ <= 0) next = M_HALTED;
                break;
        }
        state = next;

        // Banco de registros
        if (rst) {
            regfile.fill(0);
        } else if (c.write_enable) {
            regfile[c.write_id & 0x1F] = c.write_data;
        }

        recompute_outputs();
    }

private:
    int cnt_ = 0;
};


// Program Buffer
class ProgBuf {
public:
    std::array<uint32_t, 16> mem{};

    uint32_t read(uint8_t dmi_addr) const {
        if (dmi_addr < addr::PROGBUF0 || dmi_addr > addr::PROGBUF15) return 0;
        return mem[dmi_addr - addr::PROGBUF0];
    }
    void clock(bool we, uint8_t dmi_addr, uint32_t data) {
        if (we && dmi_addr >= addr::PROGBUF0 && dmi_addr <= addr::PROGBUF15)
            mem[dmi_addr - addr::PROGBUF0] = data;
    }
};



class DmSim : public ::testing::Test {
protected:
    Vdebug_module* dut = nullptr;
    MockCore core;
    ProgBuf progbuf;
    uint64_t cycle = 0;
    bool verbose = true;
    
    bool     dmi_we = false;
    uint8_t  dmi_wid = 0;
    uint32_t dmi_wdata = 0;
    uint8_t  dmi_rid = 0;

    void SetUp() override {
        dut = new Vdebug_module;
        dut->clk = 0;
        dut->DMI_write_req = 0;
        dut->DMI_read_id = 0;
        dut->core_status = bits::pack_core_status(0, core.running_o, core.halted_o, core.resumeack_o);
        dut->PB_read_data = 0;
        dut->eval();
        print_header();
    }
    void TearDown() override {
        dut->final();
        delete dut;
    }

    // Escritura DMI
    void dmi_write(uint8_t id, uint32_t data) { dmi_we = true; dmi_wid = id; dmi_wdata = data; }
    void dmi_no_write() { dmi_we = false; dmi_wid = 0; dmi_wdata = 0; }
    void dmi_read(uint8_t id) { dmi_rid = id; }
    void dmi_write_cycle(uint8_t id, uint32_t data) { dmi_write(id, data); tick(); dmi_no_write(); }

    // Bucle principal
    void tick() {
        // Entradas al DM
        dut->DMI_write_req = bits::pack_write_req(dmi_wid, dmi_wdata, dmi_we);
        dut->DMI_read_id = dmi_rid;
        dut->core_status = bits::pack_core_status(0, core.running_o, core.halted_o, core.resumeack_o);
        dut->eval();
        bits::CoreControl ctrl = bits::unpack_core_control(dut->core_control);

        dut->core_status = bits::pack_core_status(core.reg_read(ctrl.read_request),
                                                    core.running_o, core.halted_o, core.resumeack_o);
        dut->eval();

        // Program buffer
        dut->PB_read_data = progbuf.read(dut->PB_read_id);
        dut->eval();
        ctrl = bits::unpack_core_control(dut->core_control); // por si algo cambiara al resolver PB_read_data

        // Capturar salidas del DM
        bool pb_we = (dut->PB_write_req) & 0x1;
        uint8_t pb_wid = (dut->PB_write_req >> 33) & 0xFF;
        uint32_t pb_wdata = (uint32_t)((dut->PB_write_req >> 1) & 0xFFFFFFFFull);

        if (verbose) print_row(ctrl, pb_we, pb_wid, pb_wdata);

        // Flanco de reloj
        dut->clk = 0; dut->eval();
        dut->clk = 1; dut->eval();

        core.clock(ctrl);
        progbuf.clock(pb_we, pb_wid, pb_wdata);
        last_ctrl_ = ctrl;

        cycle++;
    }

    // Avanza N ciclos
    void run_idle(int n) {
        dmi_no_write();
        for (int i = 0; i < n; i++) tick();
    }

    uint32_t dmcontrol()  const { return dut->debug_module->dmcontrol; }
    uint32_t dmstatus()   const { return dut->debug_module->dmstatus; }
    uint32_t abstractcs() const { return dut->debug_module->abstractcs; }
    uint32_t command_reg()const { return dut->debug_module->command; }
    uint32_t abs_data0()  const { return dut->debug_module->abs_data_0; }
    uint8_t  dm_state()   const { return dut->debug_module->curr_state; }

    // Lectura DMI
    uint32_t dmi_read_value(uint8_t id) {
        dmi_read(id);
        dut->DMI_read_id = id;
        dut->eval();
        dut->PB_read_data = progbuf.read(dut->PB_read_id); // por si la dirección cae en el program buffer
        dut->eval();
        return dut->DMI_read_value;
    }

    // Escribe dmcontrol y espera 1 ciclo
    void write_dmcontrol_and_settle(uint32_t val) {
        dmi_write_cycle(addr::DM_CONTROL, val);
        tick();
    }

    // Activa el DM
    void activate_dm() {
        dmi_write_cycle(addr::DM_CONTROL, bits::pack_dmcontrol(false, false, false, false, false, true));
    }

    // Para el core
    void halt_and_wait() {
        dmi_write_cycle(addr::DM_CONTROL, bits::pack_dmcontrol(true, false, false, false, false, true));
        while (dm_state() != /*HALTED*/2) tick();
    }

    // Reanuda el core
    void resume_and_wait() {
        dmi_write_cycle(addr::DM_CONTROL, bits::pack_dmcontrol(false, true, false, false, false, true));
        while (dm_state() != /*RUNNING*/0) tick();
    }

private:
    bits::CoreControl last_ctrl_{};

    void print_header() {
        std::printf(
            "\n==== %s ====\n",
            ::testing::UnitTest::GetInstance()->current_test_info()->name());
        std::printf("%-4s %-8s | %-8s %-8s %-8s %-8s %-8s | %-22s %-6s %-8s | %-4s %-4s %-4s %-4s %-4s %-9s %-4s | %-12s %-9s\n",
            "cyc", "estado",
            "dmctrl", "dmstat", "abscs", "cmd", "data0",
            "DMI_wr(id,we,data)", "DMI_rd", "DMI_rval",
            "hlt", "res", "hrst", "rrst", "pbex", "wr(en,id,dt)", "rdid",
            "core_status", "PB_wr");
    }

    void print_row(const bits::CoreControl& ctrl, bool pb_we, uint8_t pb_wid, uint32_t pb_wdata) {
        char dmi_w[32];
        std::snprintf(dmi_w, sizeof(dmi_w), "%02x,%d,%08x", dmi_wid, dmi_we ? 1 : 0, dmi_wdata);
        char wr[24];
        std::snprintf(wr, sizeof(wr), "%d,%02x,%08x", ctrl.write_enable ? 1 : 0, ctrl.write_id, ctrl.write_data);
        char cst[40];
        std::snprintf(cst, sizeof(cst), "r%d h%d a%d rd=%08x",
                      core.running_o, core.halted_o, core.resumeack_o,
                      core.reg_read(ctrl.read_request));
        char pbw[24];
        std::snprintf(pbw, sizeof(pbw), "%d,%02x,%08x", pb_we ? 1 : 0, pb_wid, pb_wdata);

        std::printf("%-4llu %-8s | %08x %08x %08x %08x %08x | %-22s %-602x %08x | %-4d %-4d %-4d %-4d %-4d %-9s %-4d | %-12s %-9s\n",
            (unsigned long long)cycle, dm_state_name(dm_state()),
            dmcontrol(), dmstatus(), abstractcs(), command_reg(), abs_data0(),
            dmi_w, dmi_rid, dut->DMI_read_value,
            ctrl.halt_request, ctrl.resume_request, ctrl.hart_reset, ctrl.reset_request, ctrl.pb_exec,
            wr, ctrl.read_request,
            cst, pbw);
    }
};

//-------------------------------------------------------------------------------------------------------------------------------------
// Tests
//-------------------------------------------------------------------------------------------------------------------------------------

// ---- Activación del DM (dmcontrol.dmactive) ----
TEST_F(DmSim, ActivateDM) {
    // Antes de activar, dmactive debe leer 0
    EXPECT_EQ(dmcontrol() & 1, 0u);
    activate_dm();
    EXPECT_EQ(dmcontrol() & 1, 1u) << "dmactive debería quedar a 1 tras escribirlo";
    EXPECT_EQ(dm_state(), 0 /*RUNNING*/);
}

// dmstatus default
TEST_F(DmSim, DmStatusDefaultValue) {
    activate_dm();
    uint32_t v = dmi_read_value(addr::DM_STATUS);
    auto s = bits::unpack_dmstatus(v);
    EXPECT_EQ(s.version, 3) << "version debe codificar 1.0-stable";
    EXPECT_TRUE(s.allrunning);
    EXPECT_TRUE(s.anyrunning);
    EXPECT_FALSE(s.allhalted);
}

// Halt
TEST_F(DmSim, HaltRequestFromRunning) {
    activate_dm();
    write_dmcontrol_and_settle(bits::pack_dmcontrol(/*halt*/true, false, false, false, false, true));
    EXPECT_EQ(dm_state(), 1 /*HALTING*/)
        << "un ciclo después de que dmcontrol.haltreq quede escrito, la FSM debe pasar a HALTING";
        
    int guard = 0;
    while (dm_state() != 2 /*HALTED*/ && guard < 20) { tick(); guard++; }
    ASSERT_EQ(dm_state(), 2 /*HALTED*/) << "el DM debe alcanzar HALTED";

    uint32_t v = dmi_read_value(addr::DM_STATUS);
    auto s = bits::unpack_dmstatus(v);
    EXPECT_TRUE(s.allhalted);
    EXPECT_TRUE(s.anyhalted);
    EXPECT_FALSE(s.allrunning);
}

// Reanudar desde halted
TEST_F(DmSim, ResumeRequestFromHalted) {
    activate_dm();
    halt_and_wait();

    dmi_write_cycle(addr::DM_CONTROL, bits::pack_dmcontrol(false, /*resume*/true, false, false, false, true));
    tick();
    EXPECT_EQ(dm_state(), 3 /*RESUMING*/);

    int guard = 0;
    while (dm_state() != 0 /*RUNNING*/ && guard < 20) { tick(); guard++; }
    ASSERT_EQ(dm_state(), 0 /*RUNNING*/);

    uint32_t v = dmi_read_value(addr::DM_STATUS);
    auto s = bits::unpack_dmstatus(v);
    EXPECT_TRUE(s.allresumeack);
    EXPECT_TRUE(s.allrunning);
}

// Leer GPR
TEST_F(DmSim, AbstractCommandReadRegister) {
    activate_dm();
    halt_and_wait();
    core.regfile[5] = 0xDEADBEEF;

    uint32_t cmd = bits::pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false,
                                       /*transfer*/true, /*write*/false, gpr_regno(5));
    dmi_write_cycle(addr::ABS_COMMAND, cmd);

    
    int guard = 0;
    while (bits::unpack_abstractcs(abstractcs()).busy && guard < 10) { tick(); guard++; }

    auto acs = bits::unpack_abstractcs(abstractcs());
    EXPECT_FALSE(acs.busy);
    EXPECT_EQ(acs.cmderr, 0);
    EXPECT_EQ(dmi_read_value(addr::ABS_DATA_0), 0xDEADBEEFu)
        << "data0 debe reflejar el valor leído de x5";
}

// Escribir GPR
TEST_F(DmSim, AbstractCommandWriteRegister) {
    activate_dm();
    halt_and_wait();

    dmi_write_cycle(addr::ABS_DATA_0, 0x12345678);

    uint32_t cmd = bits::pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false,
                                       /*transfer*/true, /*write*/true, gpr_regno(3));
    dmi_write_cycle(addr::ABS_COMMAND, cmd);

    int guard = 0;
    while (bits::unpack_abstractcs(abstractcs()).busy && guard < 10) { tick(); guard++; }

    auto acs = bits::unpack_abstractcs(abstractcs());
    EXPECT_FALSE(acs.busy);
    EXPECT_EQ(acs.cmderr, 0);
    EXPECT_EQ(core.regfile[3], 0x12345678u) << "x3 debe recibir el valor escrito por el DM";
}

// Ejecutar program buffer
TEST_F(DmSim, AbstractCommandPostexecProgramBuffer) {
    activate_dm();
    halt_and_wait();

    uint32_t cmd = bits::pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false,
                                       /*postexec*/true, /*transfer*/false, false, gpr_regno(0));
    dmi_write_cycle(addr::ABS_COMMAND, cmd);
    tick();te

    ASSERT_EQ(dm_state(), 4 /*EXEC_PB*/) << "postexec debe llevar a el DM a EXEC_PB";
    EXPECT_TRUE(bits::unpack_abstractcs(abstractcs()).busy)
        << "busy debe seguir activo mientras se ejecuta el program buffer";

    int guard = 0;
    while (dm_state() != 2 /*HALTED*/ && guard < 20) { tick(); guard++; }
    ASSERT_EQ(dm_state(), 2 /*HALTED*/) << "al terminar el pb, el DM vuelve a HALTED";
    EXPECT_FALSE(bits::unpack_abstractcs(abstractcs()).busy);
}

// Leer & Escribir program buffer
TEST_F(DmSim, ProgramBufferReadWrite) {
    activate_dm();

    dmi_write_cycle(addr::PROGBUF0, 0x00000013);      // nop
    dmi_write_cycle(addr::PROGBUF0 + 1, 0x00100073);  // ebreak

    EXPECT_EQ(dmi_read_value(addr::PROGBUF0), 0x00000013u);
    EXPECT_EQ(dmi_read_value(addr::PROGBUF0 + 1), 0x00100073u);
}

// abstract command erroneo
TEST_F(DmSim, AbstractCommandErrors) {
    activate_dm();

    // Hart no parado
    uint32_t cmd_ok = bits::pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, false, gpr_regno(1));
    dmi_write_cycle(addr::ABS_COMMAND, cmd_ok);
    tick();
    EXPECT_EQ(bits::unpack_abstractcs(abstractcs()).cmderr, 4)
        << "emitir un comando con el hart corriendo debe dar cmderr=4";

    // Limpiar cmderr escribiendo en abstractcs
    dmi_write_cycle(addr::ABS_CONTROL, 0);
    EXPECT_EQ(bits::unpack_abstractcs(abstractcs()).cmderr, 0);

    halt_and_wait();

    // cmdtype no soportado
    uint32_t cmd_badtype = bits::pack_command(0x01, AARSIZE_32, false, false, true, false, gpr_regno(1));
    dmi_write_cycle(addr::ABS_COMMAND, cmd_badtype);
    tick();
    EXPECT_EQ(bits::unpack_abstractcs(abstractcs()).cmderr, 2) << "cmdtype no soportado -> cmderr=2";
    dmi_write_cycle(addr::ABS_CONTROL, 0);

    // aarsize distinto de 32 bits
    uint32_t cmd_badsize = bits::pack_command(CMDTYPE_ACCESS_REG, /*aarsize*/1, false, false, true, false, gpr_regno(1));
    dmi_write_cycle(addr::ABS_COMMAND, cmd_badsize);
    tick();
    EXPECT_EQ(bits::unpack_abstractcs(abstractcs()).cmderr, 2) << "aarsize != XLEN -> cmderr=2";
    dmi_write_cycle(addr::ABS_CONTROL, 0);

    // regno fuera del rango de GPR
    uint32_t cmd_badregno = bits::pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, false, true, false, 0x0000 /* CSR 0, no GPR */);
    dmi_write_cycle(addr::ABS_COMMAND, cmd_badregno);
    tick();
    EXPECT_EQ(bits::unpack_abstractcs(abstractcs()).cmderr, 2) << "regno fuera de GPR -> cmderr=2";
    dmi_write_cycle(addr::ABS_CONTROL, 0);

    // busy=1
    uint32_t cmd_pb = bits::pack_command(CMDTYPE_ACCESS_REG, AARSIZE_32, false, true, false, false, gpr_regno(0));
    dmi_write_cycle(addr::ABS_COMMAND, cmd_pb);
    ASSERT_TRUE(bits::unpack_abstractcs(abstractcs()).busy);
    dmi_write_cycle(addr::ABS_COMMAND, cmd_ok);
    EXPECT_EQ(bits::unpack_abstractcs(abstractcs()).cmderr, 1)
        << "un comando recibido mientras busy=1 debe dar cmderr=1";
        
    int guard = 0;
    while (dm_state() != 2 /*HALTED*/ && guard < 20) { tick(); guard++; }
}


// ndmreset sin haltreq (HALTED)
TEST_F(DmSim, ResetFromHalted_NdmresetOnly) {
    activate_dm();
    halt_and_wait();

    write_dmcontrol_and_settle(bits::pack_dmcontrol(false, false, false, false, /*ndmreset*/true, true));
    EXPECT_EQ(dm_state(), 0 /*RUNNING*/) << "ndmreset sin haltreq desde HALTED debe ir a RUNNING";

    uint32_t v = dmi_read_value(addr::DM_STATUS);
    auto s = bits::unpack_dmstatus(v);
    EXPECT_TRUE(s.allhavereset);
    EXPECT_TRUE(s.anyhavereset);
    EXPECT_EQ(core.regfile[3], 0u) << "el mock core limpia el regfile al recibir reset_request";

    // Limpiar havereset (ackhavereset)
    write_dmcontrol_and_settle(bits::pack_dmcontrol(false, false, false, /*ack*/true, false, true));
    s = bits::unpack_dmstatus(dmi_read_value(addr::DM_STATUS));
    EXPECT_FALSE(s.allhavereset);
    EXPECT_FALSE(s.anyhavereset);
}

// ndmreset + haltreq (HALTED)
TEST_F(DmSim, ResetFromHalted_NdmresetAndHalt) {
    activate_dm();
    halt_and_wait();

    write_dmcontrol_and_settle(bits::pack_dmcontrol(true, false, false, false, /*ndmreset*/true, true));
    EXPECT_EQ(dm_state(), 2 /*HALTED*/) << "ndmreset+haltreq desde HALTED se mantiene en HALTED";
    auto s = bits::unpack_dmstatus(dmi_read_value(addr::DM_STATUS));
    EXPECT_TRUE(s.allhavereset);
}

// hartreset sin haltreq (HALTED)
TEST_F(DmSim, ResetFromHalted_HartresetOnly) {
    activate_dm();
    halt_and_wait();

    write_dmcontrol_and_settle(bits::pack_dmcontrol(false, false, /*hartreset*/true, false, false, true));
    EXPECT_EQ(dm_state(), 0 /*RUNNING*/);
    auto s = bits::unpack_dmstatus(dmi_read_value(addr::DM_STATUS));
    EXPECT_TRUE(s.allhavereset);
}

// ndmreset sin haltreq (RUNNING)
TEST_F(DmSim, ResetFromRunning_NdmresetOnly) {
    activate_dm();
    ASSERT_EQ(dm_state(), 0 /*RUNNING*/);

    write_dmcontrol_and_settle(bits::pack_dmcontrol(false, false, false, false, /*ndmreset*/true, true));
    EXPECT_EQ(dm_state(), 0 /*RUNNING*/) << "ndmreset sin haltreq desde RUNNING permanece en RUNNING";
    auto s = bits::unpack_dmstatus(dmi_read_value(addr::DM_STATUS));
    EXPECT_TRUE(s.allhavereset);
}

// ndmreset + haltreq (RUNNING)
TEST_F(DmSim, ResetFromRunning_NdmresetAndHalt) {
    activate_dm();
    ASSERT_EQ(dm_state(), 0 /*RUNNING*/);

    write_dmcontrol_and_settle(bits::pack_dmcontrol(true, false, false, false, /*ndmreset*/true, true));
    EXPECT_EQ(dm_state(), 2 /*HALTED*/)
        << "ndmreset+haltreq desde RUNNING salta directamente a HALTED (sin pasar por HALTING)";
    auto s = bits::unpack_dmstatus(dmi_read_value(addr::DM_STATUS));
    EXPECT_TRUE(s.allhavereset);
}

// Reset emitido durante RESUMING
TEST_F(DmSim, ResetDuringResuming) {
    activate_dm();
    halt_and_wait();

    dmi_write_cycle(addr::DM_CONTROL, bits::pack_dmcontrol(false, /*resume*/true, false, false, false, true));
    tick();
    ASSERT_EQ(dm_state(), 3 /*RESUMING*/);

    // hartreset+halt
    dmi_write_cycle(addr::DM_CONTROL, bits::pack_dmcontrol(true, false, /*hartreset*/true, false, false, true));
    tick();

    int guard = 0;
    while (dm_state() != 2 /*HALTED*/ && dm_state() != 0 /*RUNNING*/ && guard < 20) { tick(); guard++; }
    SUCCEED() << "Estado final tras reset durante RESUMING: " << dm_state_name(dm_state());
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
