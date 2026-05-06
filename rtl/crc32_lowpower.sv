`timescale 1ns/1ps

module crc32_lowpower(
    input logic     clk,
    input logic     rst_n,
    input logic     valid_in,
    input logic     is_last,
    input logic     [7:0] data_in,

    output logic     valid_out,
    output logic     [31:0] crc_out

);

logic   [31:0] crc_reg;
logic   [7:0] data_reg;
logic   crc_enable;

typedef enum logic [1:0] {
    IDLE = 2'b00,
    CALC = 2'b01,
    DONE = 2'b10
} state_t;

state_t current_state, next_state;
assign crc_enable = (current_state == CALC);


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

always_comb begin
    next_state = IDLE;
    case (current_state)
        IDLE: if (valid_in) next_state = CALC;
        CALC: if (is_last) next_state = DONE;
        DONE: next_state = IDLE;
    endcase
end

always_comb begin
    valid_out = 0;
    crc_out   = 0;
    case (current_state)
        DONE: begin
         valid_out = 1;
         crc_out = crc_reg;
         end
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        crc_reg  <= 32'hFFFFFFFF;
        data_reg <= 8'h00;
    end else if (crc_enable) begin
        data_reg <= data_in;
        begin : datapath
            logic [31:0] crc_next;
            crc_next = crc_reg;
            for (int i = 7; i >= 0; i--) begin
                if (crc_next[31] ^ data_in[i])
                    crc_next = (crc_next << 1) ^ 32'h04C11DB7;
                else
                    crc_next = (crc_next << 1);
            end
            crc_reg <= crc_next;
        end
    end
end
endmodule