package triciclo_pkg;
// Versión mínima de triciclo_pkg para el testbench del debug module
typedef logic [4:0] rv_reg_id_t;
typedef logic [11:0] rv_csr_id_t;
typedef logic [31:0] l32;


typedef struct packed {
    logic write_enable;
    rv_csr_id_t id;
    l32 data;
} csr_write_request_t /*verilator public*/;

typedef struct packed {
    logic write_enable;
    rv_reg_id_t id;
    l32 data;
} rf_write_request_t;


typedef struct packed {
    l32     reg_read;
    l32     csr_read;
    logic   running;    // [2]
    logic   halted;     // [1]
    logic   resumeACK;  // [0]
} dbg_core_status_t /*verilator public*/;


typedef struct packed {
    rf_write_request_t write_request;
    rv_reg_id_t read_request;
    csr_write_request_t csr_write_request;
    rv_csr_id_t csr_read_request;
    logic   pb_exec;        // [4]
    logic   halt_request;   // [3]
    logic   hart_reset;     // [2]
    logic   reset_request;  // [1]
    logic   resume_request;      // [0]
} dbg_core_control_t /*verilator public*/;


typedef struct packed {
    logic [7:0] DM_write_id;
    l32 DM_write_data;
    logic DM_write;
} dbg_write_request_t;
endpackage
