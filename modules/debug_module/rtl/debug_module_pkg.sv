package debug_module_pkg;
import triciclo_pkg::*;

typedef struct packed {
    logic [6:0] reserved1;       // [31:25]
    logic ndmresetpending;       // [24]
    logic stickyunavail;         // [23]
    logic impebreak;             // [22]
    logic [1:0] reserved0;       // [21:20]
    logic allhavereset;          // [19]
    logic anyhavereset;          // [18]
    logic allresumeack;          // [17]
    logic anyresumeack;          // [16]
    logic allnonexistent;        // [15]
    logic anynonexistent;        // [14]
    logic allunavail;            // [13]
    logic anyunavail;            // [12]
    logic allrunning;            // [11]
    logic anyrunning;            // [10]
    logic allhalted;             // [9]
    logic anyhalted;             // [8]
    logic authenticated;         // [7]     
    logic authbusy;              // [6]     
    logic hasresethaltreq;       // [5]     
    logic confstrptrvalid;       // [4]     
    logic [3:0] version;         // [3:0]
} dmstatus_t /*verilator public*/;

typedef struct packed {
    logic haltreq;              // [31]
    logic resumereq;            // [30]
    logic hartreset;            // [29]
    logic ackhavereset;         // [28]
    logic ackunavail;           // [27]
    logic hasel;                // [26]
    logic [9:0] hartselhi;      // [25:16]
    logic [9:0] hartsello;      // [15:6]
    logic setkeepalive;         // [5]
    logic clrkeepalive;         // [4]
    logic setresethaltreq;      // [3]
    logic clrresethaltreq;      // [2]
    logic ndmreset;             // [1]
    logic dmactive;             // [0]
} dmcontrol_t /*verilator public*/;


typedef struct packed {
    logic [2:0] reserved3;   // [31:29]
    logic [4:0] progbufsize; // [28:24]
    logic [10:0] reserved2;  // [23:13]
    logic busy;              // [12]
    logic reserved1;         // [11]
    logic [2:0] cmderr;      // [10:8]
    logic [3:0] reserved0;   // [7:4]
    logic [3:0] datacount;   // [3:0]
} abstractcs_t /*verilator public*/;

typedef enum logic [2:0] {
    AARSIZE_8   = 3'd0,
    AARSIZE_16  = 3'd1,
    AARSIZE_32  = 3'd2,
    AARSIZE_64  = 3'd3,
    AARSIZE_128 = 3'd4
} aarsize_t /*verilator public*/;

localparam aarsize_t AARSIZE_XLEN = AARSIZE_32;

// cmdtype soportado (solo Access Register)
localparam logic [7:0] CMDTYPE_ACCESS_REG = 8'h00;

typedef struct packed {
    logic [7:0]  cmdtype;          // [31:24]
    logic        reserved0;        // [23]
    aarsize_t    aarsize;          // [22:20]
    logic        aarpostincrement; // [19]
    logic        postexec;         // [18]
    logic        transfer;         // [17]
    logic        write;            // [16]
    logic [15:0] regno;            // [15:0]
} command_t /*verilator public*/;



// Lista de registros del depurador
typedef enum logic [7:0] {
    ABS_DATA_0 = 'h04,
    // ABS_DATA_1 = 'h05,
    // ABS_DATA_2 = 'h06,
    // ABS_DATA_3 = 'h07,
    // ABS_DATA_4 = 'h08,
    // ABS_DATA_5 = 'h09,
    // ABS_DATA_6 = 'h0a,
    // ABS_DATA_7 = 'h0b,
    // ABS_DATA_8 = 'h0c,
    // ABS_DATA_9 = 'h0d,
    // ABS_DATA_10 = 'h0e,
    // ABS_DATA_11 = 'h0f,
    DM_CONTROL = 'h10,
    DM_STATUS = 'h11,
    // HART_INFO = 'h12,
    // HALT_SUM_1 = 'h13,
    // HART_ARR_WINSEL = 'h14,   // Es 0 porque solo hay 1 hart
    // HART_ARR_WIN = 'h15,      // Es 0 porque solo hay 1 hart
    ABS_CONTROL = 'h16,
    ABS_COMMAND = 'h17,
    // ABS_AUTOEXEC = 'h18,
    CONF_STR_PTR_1 = 'h19,
    CONF_STR_PTR_2 = 'h1a,
    CONF_STR_PTR_3 = 'h1b,
    CONF_STR_PTR_4 = 'h1c
    // NEXT_DM = 'h1d,
    // CUSTOM = 'h1f,
    // PROG_BUFF_0 = 'h20,
    // PROG_BUFF_1 = 'h21,
    // PROG_BUFF_2 = 'h22,
    // PROG_BUFF_3 = 'h23,
    // PROG_BUFF_4 = 'h24,
    // PROG_BUFF_5 = 'h25,
    // PROG_BUFF_6 = 'h26,
    // PROG_BUFF_7 = 'h27,
    // PROG_BUFF_8 = 'h28,
    // PROG_BUFF_9 = 'h29,
    // PROG_BUFF_10 = 'h2a,
    // PROG_BUFF_11 = 'h2b,
    // PROG_BUFF_12 = 'h2c,
    // PROG_BUFF_13 = 'h2d,
    // PROG_BUFF_14 = 'h2e,
    // PROG_BUFF_15 = 'h2f,
    // AUTH_DATA = 'h30,
    // DM_CTRL_STATUS_2 = 'h32,
    // HALT_SUM_2 = 'h34,
    // HALT_SUM_3 = 'h35,
    // SB_ADDR_3 = 'h37,
    // SB_CTRL_STATUS = 'h38,
    // SB_ADDR_0 = 'h39,
    // SB_ADDR_1 = 'h3a,
    // SB_ADDR_2 = 'h3b,
    // SB_DATA_0 = 'h3c,
    // SB_DATA_1 = 'h3d,
    // SB_DATA_2 = 'h3e,
    // SB_DATA_3 = 'h3f,*/
    // HALT_SUM_0 = 'h40,
    // CUSTOM_0 = 'h70,
    // CUSTOM_1 = 'h72,
    // CUSTOM_2 = 'h72,
    // CUSTOM_3 = 'h73,
    // CUSTOM_4 = 'h74,
    // CUSTOM_5 = 'h75,
    // CUSTOM_6 = 'h76,
    // CUSTOM_7 = 'h77,
    // CUSTOM_8 = 'h78,
    // CUSTOM_9 = 'h79,
    // CUSTOM_10 = 'h7a,
    // CUSTOM_11 = 'h7b,
    // CUSTOM_12 = 'h7c,
    // CUSTOM_13 = 'h7d,
    // CUSTOM_14 = 'h7e,
    // CUSTOM_15 = 'h7f
} dm_reg_code /*verilator public*/;

endpackage
