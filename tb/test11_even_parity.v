`timescale 1ns/1ps
module test11_even_parity;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    initial begin
        $dumpfile("test11_even_parity.vcd"); $dumpvars(0, test11_even_parity);
        clk = 0;
        $display(" TEST 11: Even Parity Correctness ");
        do_reset;

        // Directed: known even/odd-popcount bytes
        send_and_check_frame(8'h00, 1'b1, 1'b0, 16'd4); wait_bits(16'd4,2); // 0 ones -> parity=0
        send_and_check_frame(8'h01, 1'b1, 1'b0, 16'd4); wait_bits(16'd4,2); // 1 one  -> parity=1
        send_and_check_frame(8'h03, 1'b1, 1'b0, 16'd4); wait_bits(16'd4,2); // 2 ones -> parity=0
        send_and_check_frame(8'hFF, 1'b1, 1'b0, 16'd4); wait_bits(16'd4,2); // 8 ones -> parity=0

        // Random
        begin : rnd
            integer k; reg [7:0] rb;
            for (k=0;k<8;k=k+1) begin
                rb = $random;
                send_and_check_frame(rb, 1'b1, 1'b0, 16'd4);
                wait_bits(16'd4,2);
            end
        end

        // Corner: single bit set at each extreme position
        send_and_check_frame(8'h80, 1'b1, 1'b0, 16'd4); wait_bits(16'd4,2); // MSB only -> parity=1
        send_and_check_frame(8'h7F, 1'b1, 1'b0, 16'd4); wait_bits(16'd4,2); // 7 ones -> parity=1

        report; $finish;
    end
endmodule
