module byte_access 
import triciclo_pkg::*;
(
    input cbr_req_t request,
    output logic [3:0][7:0] data,
    output logic [3:0] we
);

// Handle byte level access from request
always_comb begin

    // Default setup
    data[0] = request.data[7:0];
    data[1] = request.data[15:8];
    data[2] = request.data[23:16];
    data[3] = request.data[31:24];

    case(request.op)
        CBR_SB: begin
            case(request.addr[1:0])
                2'b00: we = 4'b0001;
                2'b01: begin
                    we = 4'b0010;
                    data[1] = data[0];
                end
                2'b10: begin
                    we = 4'b0100;
                    data[2] = data[0];
                end
                2'b11: begin
                    we = 4'b1000;
                    data[3] = data[0];
                end
                default: we = 0; // Unreacheable
            endcase
        end
        CBR_SH: begin
            case(request.addr[1:0])
                2'b00: we = 4'b0011;
                2'b10: begin
                    we = 4'b1100;
                    data[2] = data[0];
                    data[3] = data[1];
                end
                default: we = 0; // Dont write aligment error
            endcase
        end
        CBR_SW: we = 4'b1111; // Write all banks
        default: we = 0; // Dont write
    endcase
end

endmodule;
