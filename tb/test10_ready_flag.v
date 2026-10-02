`timescale 1ns/1ps
module test10_ready_flag;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    task automatic check_ready_window;
        input [7:0] data;
        input [15:0] div;
        integer total_bits, i;
        begin
            total_bits = 10;
            check(ready === 1'b1, "ready high before load (idle)");
            load_byte(data, 1'b0, 1'b0, div);
            for (i = 0; i < total_bits*div; i = i + 1) begin
                check(ready === 1'b0, "ready stays low (not accepting) while busy");
                @(negedge clk);
            end
            check(ready === 1'b0, "ready still low during 1-cycle DONE state");
            @(negedge clk);
            check(ready === 1'b1, "ready returns high once frame fully completes");
        end
    endtask

    initial begin
        $dumpfile("test10_ready_flag.vcd"); $dumpvars(0, test10_ready_flag);
        clk = 0;
        $display("===== TEST 10: Ready-to-Load Flag =====");
        do_reset;
        check(ready === 1'b1, "DIRECTED: ready high immediately after reset");

        // Directed
        check_ready_window(8'hAA, 16'd4);

        // Random
        begin : rnd
            integer k; reg [3:0] rdv;
            for (k=0;k<5;k=k+1) begin
                rdv = ($random % 5); if (rdv<2) rdv=rdv+2;
                check_ready_window($random, {12'd0,rdv});
            end
        end

        // Corner: minimum divisor
        check_ready_window(8'h00, 16'd2);

        // Corner: attempt to load while ready=0 (mid previous frame) must not
        // be accepted - verified in detail in test13, here just confirm ready
        // itself never glitches high mid-frame.
        load_byte(8'h5A, 1'b0, 1'b0, 16'd6);
        wait_bits(16'd6, 3);
        check(ready === 1'b0, "CORNER: ready stays low mid-frame even after several bit periods");
        wait_bits(16'd6, 7);

        report; $finish;
    end
endmodule
