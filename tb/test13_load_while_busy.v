`timescale 1ns/1ps
module test13_load_while_busy;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    // Loads `first`, then mid-frame attempts to load `second` (should be ignored
    // since the DUT only samples `load` while in IDLE). Checks the ORIGINAL byte
    // is transmitted intact on the current line, unaffected by the second attempt,
    // and that the second byte's load has no side effects on shift_reg state.
    task automatic check_load_ignored_while_busy;
        input [7:0] first;
        input [7:0] second;
        input [15:0] div;
        integer i;
        begin
            baud_div = div; parity_en = 1'b0; parity_odd = 1'b0;
            tx_data = first;
            @(negedge clk); load = 1'b1; @(negedge clk); load = 1'b0;

            check(tx === 1'b0, "frame started correctly with first byte");
            wait_bits(div, 2); // now exactly at the boundary of bit index 1

            // Attempt an illegal load of a second byte while busy (consumes 2
            // clk cycles: one to assert load, one to deassert it)
            tx_data = second;
            @(negedge clk); load = 1'b1; @(negedge clk); load = 1'b0;
            check(busy === 1'b1, "still busy with first frame (second load had no effect on state)");
            check(tx === first[1], "DATA bit 1 still matches ORIGINAL byte right after spurious load");

            // Bridge the 2 cycles already consumed by the spurious load so we
            // land back exactly on the next bit boundary (bit index 2).
            repeat (div - 2) @(negedge clk);

            for (i = 2; i < 8; i = i + 1) begin
                check(tx === first[i], "remaining DATA bits still match the ORIGINAL byte");
                wait_bits(div, 1);
            end
            check(tx === 1'b1, "STOP bit correct, frame completed using original byte only");
            wait_bits(div, 1);
            check(busy === 1'b1, "busy still high during 1-cycle DONE state (frame not yet corrupted)");
            @(negedge clk); // extra cycle: FSM's DONE state before busy/ready update
            check(busy === 1'b0, "busy clears normally after the (unaffected) frame");
            check(ready === 1'b1, "ready restored after frame");
        end
    endtask

    initial begin
        $dumpfile("test13_load_while_busy.vcd"); $dumpvars(0, test13_load_while_busy);
        clk = 0;
        $display(" TEST 13: Load New Data While Busy (should be ignored) ");
        do_reset;

        // Directed
        check_load_ignored_while_busy(8'hA5, 8'h5A, 16'd6);
        wait_bits(16'd6, 2);

        // Random
        begin : rnd
            integer k; reg [7:0] a, b; reg [3:0] rdv;
            for (k=0;k<5;k=k+1) begin
                a = $random; b = $random;
                rdv = ($random % 6); if (rdv<4) rdv = rdv+4;
                check_load_ignored_while_busy(a, b, {12'd0,rdv});
                wait_bits({12'd0,rdv}, 2);
            end
        end

        // Corner: second byte is the bitwise complement of the first (maximizes
        // chance of detecting any accidental corruption)
        check_load_ignored_while_busy(8'h00, 8'hFF, 16'd4);
        wait_bits(16'd4, 2);
        check_load_ignored_while_busy(8'hFF, 8'h00, 16'd4);

        report; $finish;
    end
endmodule
