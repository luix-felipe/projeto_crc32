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

typedef enum logic [1:0] {
    IDLE = 2'b00,
    CALC = 2'b01,
    DONE = 2'b10
} state_t;

state_t current_state, next_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end