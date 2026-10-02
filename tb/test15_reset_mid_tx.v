`timescale 1ns/1ps
module test15_reset_mid_tx;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    // Starts a frame, lets it run for `cycles_in` clk cycles, then asserts
    // synchronous reset for one cycle and checks the DUT returns safely to
    // idle, then verifies a fresh frame can be sent correctly afterward.
    task automatic check_reset_mid_frame;
        input [7:0] data;
        input [15:0] div;
        input integer cycles_in;
        integer i;
        begin
            load_byte(data, 1'b0, 1'b0, div);
            repeat (cycles_in) @(negedge clk);

            rst = 1'b1;
            @(negedge clk);
            rst = 1'b0;

            check(tx === 1'b1, "tx forced back to idle-high immediately after reset");
            check(busy === 1'b0, "busy cleared immediately after reset");
            check(ready === 1'b1, "ready asserted immediately after reset");
            check(done === 1'b0, "done not spuriously asserted by reset");

            // Confirm idle holds for a few more cycles (no leftover state glitches)
            repeat (5) begin
                @(negedge clk);
                check(tx === 1'b1 && busy === 1'b0, "idle holds cleanly after reset, no residual FSM activity");
            end

            // Confirm the DUT can transmit a brand-new, correct frame afterward
            send_and_check_frame(8'h69, 1'b0, 1'b0, div);
            wait_bits(div, 2);
        end
    endtask

    initial begin
        $dumpfile("test15_reset_mid_tx.vcd"); $dumpvars(0, test15_reset_mid_tx);
        clk = 0;
        $display("===== TEST 15: Reset During Active Transmission =====");
        do_reset;

        // Directed: reset during the START bit
        check_reset_mid_frame(8'hA5, 16'd6, 2);

        // Directed: reset during the DATA bits (mid-byte)
        check_reset_mid_frame(8'hA5, 16'd6, 6 + 3*6); // start + 3 data bits in

        // Directed: reset during the STOP bit
        check_reset_mid_frame(8'hA5, 16'd6, 6 + 8*6 + 2);

        // Random: reset at a random point within the frame
        begin : rnd
            integer k, rc;
            reg [7:0] rb;
            for (k = 0; k < 5; k = k + 1) begin
                rb = $random;
                rc = ($random % 50);
                if (rc < 0) rc = -rc;
                if (rc < 1) rc = 1;
                check_reset_mid_frame(rb, 16'd4, rc);
            end
        end

        // Corner: reset asserted on the very first cycle after load (start bit
        // barely begun)
        check_reset_mid_frame(8'hFF, 16'd4, 1);

        // Corner: reset asserted right at the very last cycle of the frame
        // (just before DONE would occur)
        check_reset_mid_frame(8'h00, 16'd4, 10*4 - 1);

        // Corner: reset with no transmission in progress at all (idle reset)
        rst = 1'b1; @(negedge clk); rst = 1'b0;
        check(tx === 1'b1 && busy === 1'b0 && ready === 1'b1,
              "CORNER: reset while already idle has no adverse effect");

        report; $finish;
    end
endmodule
