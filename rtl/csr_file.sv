/* verilator lint_off UNUSEDSIGNAL */

module csr_file
import triciclo_pkg::*;
(
    input logic clk, resetn, enable,

    input rv_csr_id_t read_id,
    output l32 read_csr,

    input csr_write_request_t csr_write_req,
    output trap_config_t trap_conf,
    input flush_bus_t flush_bus,

    input logic instr_ret
);

priv_mode_t current_mode;
mstatus_t mstatus;
mie_t mie;
l32 mscratch, mcause, mtval, mtvec, mepc;

/* verilator public_on */
dcsr_t dcsr;
l32 dpc;
/* verilator public_off */

/* verilator public_on */
l64 mcycle, minstret;
/* verilator public_off */

always_comb begin
    trap_conf.current_mode = current_mode;
    trap_conf.mstatus = mstatus;
    trap_conf.mie = mie;
    trap_conf.mtvec = mtvec;
    trap_conf.mepc = mepc;
    trap_conf.dcsr = dcsr;
    trap_conf.dpc = dpc;
end

always_comb begin 
    // Default all bits to 0
    read_csr = 0;
    case (read_id)
        CSR_MISA: begin 
            read_csr[31:30] = 1; // XLEN = 32 bit
            read_csr[0] = 1;     // A
            read_csr[8] = 1;     // RVI Base
            read_csr[12] = 1;    // M
        end
        CSR_MSTATUS: begin 
            read_csr[10:9] = mstatus.mpp;
            read_csr[8] = mstatus.spp;
            read_csr[7] = mstatus.mpie;
            read_csr[5] = mstatus.spie;
            read_csr[3] = mstatus.mie;
            read_csr[1] = mstatus.sie;
        end
        CSR_MIE: begin 
            read_csr[11] = mie.meie;
            read_csr[7] = mie.mtie;
            read_csr[3] = mie.msie;
        end
        CSR_MTVAL: read_csr = mtval;
        CSR_MTVEC: read_csr = mtvec;
        CSR_MCAUSE: read_csr = mcause;
        CSR_MEPC: read_csr = mepc;
        CSR_MSCRATCH: read_csr = mscratch;
        CSR_MCYCLE: read_csr = mcycle[0];
        CSR_MCYCLEH: read_csr = mcycle[1];
        CSR_DCSR: begin
            read_csr[31:28] = dcsr.xdebugver;
            read_csr[15]    = dcsr.ebreakm;
            read_csr[12]    = dcsr.ebreaku;
            read_csr[11]    = dcsr.stepie;
            read_csr[10]    = dcsr.stopcount;
            read_csr[9]     = dcsr.stoptime;
            read_csr[8:6]   = dcsr.cause;   // read-only
            read_csr[4]     = dcsr.mprven;
            read_csr[3]     = dcsr.nmip;
            read_csr[2]     = dcsr.step;
            read_csr[1:0]   = dcsr.prv;
        end
        CSR_DPC:       read_csr = dpc;
        default: begin end
    endcase
end

always_ff @(posedge clk) begin 
    if (!resetn) begin 
        mie <= 0;
        current_mode <= MODE_MACHINE;
        // Mstatus reset values
        mstatus.mie <= 0;
        mstatus.mpp <= MODE_MACHINE;
        mstatus.mpie <= 1;
        // Counters
        mcycle <= 0;
        minstret <= 0;
        // Debug
        dcsr <= '0;
        dcsr.xdebugver <= 4'd4;
        dpc <= '0;
    end
    else begin 
        if (enable) begin
            // Cycle counter
            mcycle <= mcycle + 1;
            // Retired counter
            if (instr_ret) minstret <= minstret + 1;
        end
        
        // Trap return instruction
        if (flush_bus.op == FLUSH_MRET) begin 
            mstatus.mie <= mstatus.mpie;
            mstatus.mpie <= 1;
            current_mode <= mstatus.mpp;
            //$display("MRET to %x", mepc);
        end
        // Trap
        else if (flush_bus.op == FLUSH_TRAP) begin
            mepc <= flush_bus.from;
            mcause <= flush_bus.cause;
            mtval <= flush_bus.value;
            mstatus.mpie <= mstatus.mie;
            mstatus.mie <= 0;
            mstatus.mpp <= current_mode;
            current_mode <= MODE_MACHINE;
            //$display("TRAP FROM %x CAUSE %x", flush_bus.from, flush_bus.cause);
        end
        // Debug mode entry 
        else if (flush_bus.op == FLUSH_DEBUG_ENTRY) begin
            dcsr.cause <= flush_bus.cause[2:0];
            dpc <= flush_bus.from;
            current_mode <= MODE_DEBUG;
            dcsr.prv <= current_mode;
        end

        // Debug mode exit
        else if (flush_bus.op == FLUSH_DEBUG_RETURN) begin
            current_mode <= priv_mode_t'(dcsr.prv);
        end
        // Resume without mode change (for program buffer execution)
        else if (flush_bus.op == FLUSH_DEBUG_PB_RETURN) begin
            current_mode <= MODE_DEBUG;
        end

        else if (csr_write_req.write_enable) begin
            case (csr_write_req.id)
                CSR_MSTATUS: begin 
                    mstatus.mpp <= priv_mode_t'(csr_write_req.data[10:9]);
                    mstatus.spp <= csr_write_req.data[8];
                    mstatus.mpie <= csr_write_req.data[7];
                    mstatus.spie <= csr_write_req.data[5];
                    mstatus.mie <= csr_write_req.data[3];
                    mstatus.sie <= csr_write_req.data[1];
                end
                CSR_MIE: begin 
                    mie.meie <= csr_write_req.data[11];
                    mie.mtie <= csr_write_req.data[7];
                    mie.msie <= csr_write_req.data[3];
                end
                CSR_MTVAL: mtval <= csr_write_req.data;
                CSR_MTVEC: mtvec <= csr_write_req.data;
                CSR_MEPC: mepc <= csr_write_req.data;
                CSR_MCAUSE: mcause <= csr_write_req.data;
                CSR_MSCRATCH: mscratch <= csr_write_req.data;
                CSR_MCYCLE: mcycle[0] <= csr_write_req.data;
                CSR_MCYCLEH: mcycle[1]  <= csr_write_req.data;
                CSR_DCSR: begin
                    dcsr.ebreakm  <= csr_write_req.data[15];
                    dcsr.ebreaku  <= csr_write_req.data[12];
                    dcsr.stepie   <= csr_write_req.data[11];
                    dcsr.stopcount <= csr_write_req.data[10];
                    dcsr.stoptime  <= csr_write_req.data[9];
                    // dcsr.cause [8:6] read-only
                    dcsr.mprven   <= csr_write_req.data[4];
                    dcsr.step     <= csr_write_req.data[2];
                    dcsr.prv      <= priv_mode_t'(csr_write_req.data[1:0]);
                end
                CSR_DPC:       dpc        <= csr_write_req.data;
                default: begin end
            endcase
        end
    end
end

endmodule

