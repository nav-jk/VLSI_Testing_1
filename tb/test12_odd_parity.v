`timescale 1ns/1ps
module test12_odd_parity;
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
        $dumpfile("test12_odd_parity.vcd"); $dumpvars(0, test12_odd_parity);
        clk = 0;
        $display("===== TEST 12: Odd Parity Correctness =====");
        do_reset;

        // Directed
        send_and_check_frame(8'h00, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // 0 ones -> odd parity=1
        send_and_check_frame(8'h01, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // 1 one  -> odd parity=0
        send_and_check_frame(8'h03, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // 2 ones -> odd parity=1
        send_and_check_frame(8'hFF, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // 8 ones -> odd parity=1

        // Random
        begin : rnd
            integer k; reg [7:0] rb;
            for (k=0;k<8;k=k+1) begin
                rb = $random;
                send_and_check_frame(rb, 1'b1, 1'b1, 16'd4);
                wait_bits(16'd4,2);
            end
        end

        // Corner
        send_and_check_frame(8'h80, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // MSB only -> odd parity=0
        send_and_check_frame(8'h7F, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // 7 ones -> odd parity=0

        // Corner: toggling parity_en/parity_odd between consecutive frames
        send_and_check_frame(8'hA5, 1'b0, 1'b0, 16'd4); wait_bits(16'd4,2); // parity disabled
        send_and_check_frame(8'hA5, 1'b1, 1'b1, 16'd4); wait_bits(16'd4,2); // parity enabled, odd

        report; $finish;
    end
endmodule
