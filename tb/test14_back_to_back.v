`timescale 1ns/1ps
module test14_back_to_back;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    // Loads a byte the instant `ready` is observed high after the previous
    // frame (i.e. load is issued as soon as legally possible), verifying no
    // glitch/garbage appears on tx between frames.
    task automatic check_back_to_back;
        input [7:0] a;
        input [7:0] b;
        input [15:0] div;
        begin
            // First frame
            send_and_check_frame(a, 1'b0, 1'b0, div);
            check(ready === 1'b1, "ready is high immediately after first frame -> can load again now");

            // Second frame loaded back-to-back with no idle gap
            send_and_check_frame(b, 1'b0, 1'b0, div);
            check(ready === 1'b1, "ready high again after the back-to-back second frame");
        end
    endtask

    initial begin
        $dumpfile("test14_back_to_back.vcd"); $dumpvars(0, test14_back_to_back);
        clk = 0;
        $display("===== TEST 14: Back-to-Back Transmission =====");
        do_reset;

        // Directed
        check_back_to_back(8'hA5, 8'h5A, 16'd4);

        // Random: chain of several back-to-back frames
        begin : rnd
            integer k; reg [7:0] rb;
            for (k = 0; k < 6; k = k + 1) begin
                rb = $random;
                send_and_check_frame(rb, 1'b0, 1'b0, 16'd4);
                // no inter-frame wait_bits buffer here on purpose: load the very
                // next frame as soon as the task returns (ready already high)
            end
        end

        // Corner: three frames back-to-back with no gap, minimum divisor
        check_back_to_back(8'h00, 8'hFF, 16'd2);
        send_and_check_frame(8'hAA, 1'b0, 1'b0, 16'd2); // third, immediately chained

        // Corner: verify tx line never floats/glitches between two chained
        // frames by sampling exactly at the boundary negedge
        send_and_check_frame(8'h3C, 1'b0, 1'b0, 16'd6);
        check(tx === 1'b1, "tx sits at idle-high level the instant before next load");
        load_byte(8'hC3, 1'b0, 1'b0, 16'd6);
        check(tx === 1'b0, "tx transitions straight to new start bit with no glitch cycle");
        wait_bits(16'd6, 10);

        report; $finish;
    end
endmodule
