module debug_module
import triciclo_pkg::*;
import debug_module_pkg::*;
(
	input logic 				clk,

	// Lectura/escritura desde el DMI
	input dbg_write_request_t 	DMI_write_req,
    input logic [7:0] 			DMI_read_id,
    output l32          		DMI_read_value,

	// Interfaz con el core
	input dbg_core_status_t 	core_status,
	output dbg_core_control_t 	core_control,

	// Interfaz con el Program Buffer
	output dbg_write_request_t	PB_write_req,
	output logic [7:0]			PB_read_id,
	input  l32					PB_read_data
);




// Variables de los registros
l32          abs_data_0 /*verilator public*/, next_abs_data_0;
dmcontrol_t  dmcontrol   /*verilator public*/, next_dmcontrol;
dmstatus_t   dmstatus    /*verilator public*/, next_dmstatus;
abstractcs_t abstractcs  /*verilator public*/, next_abstractcs;
command_t    command     /*verilator public*/, next_command;

`define PROGBUF_SIZE 16
`define absdata0_default    32'h00000000
`define dmcontrol_default   32'h00000000
`define dmstatus_default    32'h00000c83
`define abstractcs_default  ((`PROGBUF_SIZE << 24) | 32'd1)
`define command_default     32'h00000000

// Direcciones del Program Buffer
localparam logic [7:0] PROGBUF0_ADDR  = 8'h20;
localparam logic [7:0] PROGBUF15_ADDR = 8'h2f;


// Estado para la fsm
typedef enum logic [3:0]{
	RUNNING         = 'h0,
	HALTING         = 'h1,
	HALTED          = 'h2,
	RESUMING        = 'h3,
	EXEC_PB			= 'h4
} state;

state next_state, curr_state /*verilator public*/;


// Errores de los comandos
logic [2:0] cmd_errcode;


// Bloque inicial
initial begin
    curr_state = RUNNING;
    abs_data_0 = `absdata0_default;
    dmcontrol  = `dmcontrol_default;
    dmstatus   = `dmstatus_default;
    abstractcs = `abstractcs_default;
    command    = `command_default;
end


always_comb begin

	// Valores por defecto
	next_state = curr_state;

	core_control.pb_exec = 0;
    core_control.halt_request = 0;
    core_control.hart_reset = 0;
    core_control.reset_request = 0;
    core_control.resume_request = 0; 
    core_control.write_request = '0; 
    core_control.read_request = '0; 
    core_control.csr_write_request = '0;
    core_control.csr_read_request = '0;

	next_abs_data_0 = abs_data_0;
	next_dmcontrol = dmcontrol;

	next_dmstatus = dmstatus;

	next_dmstatus.allhalted = !core_status.running;
	next_dmstatus.anyhalted = !core_status.running;

	next_dmstatus.allrunning = core_status.running;
	next_dmstatus.anyrunning = core_status.running;

	next_dmstatus.allresumeack = dmstatus.allresumeack;
	next_dmstatus.anyresumeack = dmstatus.anyresumeack;

	next_abstractcs = abstractcs;
	next_command = command;

	// Program Buffer
	PB_write_req.DM_write = 1'b0;
	PB_write_req.DM_write_id    = '0;
	PB_write_req.DM_write_data = '0;
	PB_read_id = DMI_read_id;
	

    cmd_errcode = 3'd0;

    DMI_read_value = 0;

	// Lectura desde el DMI
	if (DMI_read_id inside {[PROGBUF0_ADDR:PROGBUF15_ADDR]}) begin
		DMI_read_value = PB_read_data;
	end else begin
	    case (DMI_read_id)
	        ABS_DATA_0:  DMI_read_value = abs_data_0;
	        DM_CONTROL:  DMI_read_value = dmcontrol;
	        DM_STATUS:   DMI_read_value = dmstatus;
	        ABS_CONTROL: DMI_read_value = abstractcs;
	        ABS_COMMAND: DMI_read_value = command;
	        default:     DMI_read_value = 0;
	    endcase
	end

	// Aceptar/rechazar escrituras
	if (dmcontrol.dmactive) begin
		if (DMI_write_req.DM_write && ((DMI_write_req.DM_write_id) == ABS_COMMAND)) begin
			if (abstractcs.busy) begin
				// Ya se está ejecutando un comando 
				if (abstractcs.cmderr == 3'd0)
					next_abstractcs.cmderr = 3'd1;
			end else if (curr_state != HALTED) begin
				// El hart no está parado
				if (abstractcs.cmderr == 3'd0)
					next_abstractcs.cmderr = 3'd4;
			end else begin
				// Comando aceptado
				next_command         = DMI_write_req.DM_write_data;
				next_abstractcs.busy = 1'b1;
			end
		end else if (DMI_write_req.DM_write && ((DMI_write_req.DM_write_id) == ABS_CONTROL)) begin
			// Escribir en abstractcs limpia cmderr (ningún otro campo escribible)
			next_abstractcs.cmderr = 3'd0;
		end else if (DMI_write_req.DM_write && ((DMI_write_req.DM_write_id) == ABS_DATA_0)) begin
			// data0: igual que command/progbuf, ignorado mientras busy=1
			if (abstractcs.busy) begin
				if (abstractcs.cmderr == 3'd0)
					next_abstractcs.cmderr = 3'd1;
			end else begin
				next_abs_data_0 = DMI_write_req.DM_write_data;
			end
		end else if (DMI_write_req.DM_write && (DMI_write_req.DM_write_id inside {[PROGBUF0_ADDR:PROGBUF15_ADDR]})) begin
			// Escritura al Program Buffer: ignorada mientras busy=1
			if (abstractcs.busy) begin
				if (abstractcs.cmderr == 3'd0)
					next_abstractcs.cmderr = 3'd1;
			end else begin
				PB_write_req.DM_write = 1'b1;
				PB_write_req.DM_write_id    = DMI_write_req.DM_write_id;
				PB_write_req.DM_write_data = DMI_write_req.DM_write_data;
			end
		end
	end




	case (curr_state)
		RUNNING: begin
			if (core_status.halted) begin
				// Si el core se para solo (fin de step), pasa a halted
				next_state = HALTED;
			end else if (dmcontrol.ackhavereset) begin
				// Ackhavereset borra el bit havereset de dmstatus
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
				next_dmstatus.anyhavereset = 0;
				next_dmstatus.allhavereset = 0;
				
			end else if (dmcontrol.ndmreset && !dmcontrol.haltreq) begin
				// non debug module reset
				next_state = RUNNING;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.reset_request = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.ndmreset && dmcontrol.haltreq) begin
				// non debug module reset & halt
				next_state = HALTED;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.reset_request = 1;
    			core_control.halt_request = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.hartreset && !dmcontrol.haltreq) begin
				// hart reset
				next_state = RUNNING;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.hart_reset = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.hartreset && dmcontrol.haltreq) begin
				// hart reset & halt
				next_state = HALTED;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.hart_reset = 1;
    			core_control.halt_request = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.haltreq && !dmcontrol.ndmreset && !dmcontrol.hartreset) begin
				// halting
				next_state = HALTING;
    			core_control.halt_request = 1;

			end
			
		end
		HALTING: begin
			if (core_status.halted && !core_status.running) begin
				// Si el core para, pasa a halted
				next_state = HALTED;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
			end else begin
				// Si no para, mantiene la petición
    			core_control.halt_request = 1;
			end
			
		end
		HALTED: begin
			if (dmcontrol.ackhavereset) begin
				// Ackhavereset borra el bit havereset de dmstatus
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
				next_dmstatus.anyhavereset = 0;
				next_dmstatus.allhavereset = 0;
				
			end else if (dmcontrol.ndmreset && !dmcontrol.haltreq) begin
				// non debug module reset
				next_state = RUNNING;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.reset_request = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.ndmreset && dmcontrol.haltreq) begin
				// non debug module reset & halt
				next_state = HALTED;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.reset_request = 1;
    			core_control.halt_request = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.hartreset && !dmcontrol.haltreq) begin
				// hart reset
				next_state = RUNNING;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.hart_reset = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.hartreset && dmcontrol.haltreq) begin
				// hart reset & halt
				next_state = HALTED;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
    			core_control.hart_reset = 1;
    			core_control.halt_request = 1;
				next_dmstatus.allhavereset = 1;
				next_dmstatus.anyhavereset = 1;

			end else if (dmcontrol.resumereq) begin
				// Resume request
				next_state = RESUMING;
				core_control.resume_request = 1;
				// El resume aún no se ha confirmado
				next_dmstatus.allresumeack = 1'b0;
				next_dmstatus.anyresumeack = 1'b0;
			end else if (abstractcs.busy) begin // Abstract command

				// Gestión de errores (comandos incorrectos)
				if (command.cmdtype != CMDTYPE_ACCESS_REG) begin
					// Único cmdtype soportado: Access Register
					cmd_errcode = 3'd2;
				end else if (command.aarsize != AARSIZE_XLEN) begin
					cmd_errcode = 3'd2;
				end else if (command.aarpostincrement) begin
					cmd_errcode = 3'd2;
				end else if (command.transfer && !((command.regno[15:5] == 11'h080) || (command.regno[15:12] == 4'h0))) begin
					// regno válido: 0x1000-0x101f (GPR) o 0x0000-0x0fff (CSR)
					cmd_errcode = 3'd2;
				end

				if (cmd_errcode != 3'd0) begin // Comando abortado
					if (abstractcs.cmderr == 3'd0)
						next_abstractcs.cmderr = cmd_errcode;
					next_abstractcs.busy = 1'b0; // busy siempre se libera, aunque cmderr ya estuviera fijado
				end else begin	// Comando válido
					// 
					if (command.postexec) begin
						// Ejecuta el pb
						next_state = EXEC_PB;
						core_control.pb_exec = 1;
					end else begin
						// Termina y vuelve a halted
						next_abstractcs.busy = 0;
					end

					// Comportamiento del comando
					if (command.transfer) begin
						if (command.regno[15:12] == 4'h0) begin
							// Acceso a CSR: regno es directamente la dirección del CSR
							if (command.write) begin
								core_control.csr_write_request.write_enable = 1;
								core_control.csr_write_request.id = rv_csr_id_t'(command.regno[11:0]);
								core_control.csr_write_request.data = abs_data_0;
							end else begin
								core_control.csr_read_request = rv_csr_id_t'(command.regno[11:0]);
								next_abs_data_0 = core_status.csr_read;
							end
						end else begin
							// Acceso a GPR: regno = 0x1000-0x101f -> x0-x31
							if (command.write) begin
								// Escritura
								core_control.write_request.write_enable = 1;
								core_control.write_request.id = command.regno[4:0];
								core_control.write_request.data = abs_data_0;
							end else begin
								// Lectura
								core_control.read_request = command.regno[4:0];
								next_abs_data_0 = core_status.reg_read;
							end
						end
					end
				end
			end
			
		end
		RESUMING: begin
			if (core_status.resumeACK) begin
				// Si el core reanuda, pasa a running
				next_state = RUNNING;
				next_dmcontrol.haltreq = 1'b0;
				next_dmcontrol.resumereq = 1'b0;
				next_dmcontrol.hartreset = 1'b0;
				next_dmcontrol.ackhavereset = 1'b0;
				next_dmcontrol.ndmreset = 1'b0;
				next_dmstatus.allresumeack = 1'b1;
				next_dmstatus.anyresumeack = 1'b1;
			end else begin
				// Si no para, mantiene la petición
				core_control.resume_request = 1;
			end
		end
		EXEC_PB: begin
			if (core_status.halted) begin
				next_state = HALTED;
            	next_abstractcs.busy = 0;
			end else begin
				next_state = EXEC_PB;
				core_control.pb_exec = 1;
			end
			
		end

		default: ;
	endcase
end




// Parte síncrona
always @ (posedge clk) begin
	if (!dmcontrol.dmactive) begin
        curr_state <= RUNNING;
        abs_data_0 <= `absdata0_default;
        dmstatus   <= `dmstatus_default;
        abstractcs <= `abstractcs_default;
        command    <= `command_default;
        dmcontrol <= (DMI_write_req.DM_write && ((DMI_write_req.DM_write_id) == DM_CONTROL))
                     ? DMI_write_req.DM_write_data // único registro escribible mientras dmactive=0 (para poder activarlo)
                     : `dmcontrol_default;
	end else begin
		curr_state <= next_state;

		// Escritura de registros
		// abs_data_0 y command ya se resuelven en el bloque comb
		abs_data_0 <= next_abs_data_0;
		dmcontrol <= (DMI_write_req.DM_write && ((DMI_write_req.DM_write_id) == DM_CONTROL)) 
              ? DMI_write_req.DM_write_data 
              : next_dmcontrol;
		abstractcs <= next_abstractcs;	// Solo cmderr escribible, ver bloque comb
		command <= next_command;	// Se gestiona la escritura en el bloque comb.
        dmstatus <= next_dmstatus;	// No escribible desde dmi
	end
end


endmodule
