`timescale 1ns/1ps
module test09_done_pulse;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    // Checks `done` is 0 throughout the frame, pulses high for exactly 1 cycle
    // right as the frame completes, then returns to 0.
    task automatic check_done_pulse;
        input [7:0] data;
        input [15:0] div;
        integer total_bits, i;
        begin
            total_bits = 10;
            check(done === 1'b0, "done low before load");
            load_byte(data, 1'b0, 1'b0, div);
            for (i = 0; i < total_bits*div; i = i + 1) begin
                check(done === 1'b0, "done stays low throughout frame transmission");
                @(negedge clk);
            end
            check(done === 1'b0, "done still low during the cycle FSM enters its DONE state");
            @(negedge clk); // one extra cycle: done pulses the cycle AFTER entering DONE state
            check(done === 1'b1, "done pulses high exactly when frame completes");
            @(negedge clk);
            check(done === 1'b0, "done returns low the cycle after the pulse");
            @(negedge clk);
            check(done === 1'b0, "done remains low afterward (single-cycle pulse only)");
        end
    endtask

    initial begin
        $dumpfile("test09_done_pulse.vcd"); $dumpvars(0, test09_done_pulse);
        clk = 0;
        $display("===== TEST 9: Done/TX-Complete Pulse =====");
        do_reset;

        // Directed
        check_done_pulse(8'h3C, 16'd4);

        // Random
        begin : rnd
            integer k; reg [3:0] rdv;
            for (k=0;k<5;k=k+1) begin
                rdv = ($random % 5); if (rdv<2) rdv=rdv+2;
                check_done_pulse($random, {12'd0,rdv});
            end
        end

        // Corner: minimum divisor
        check_done_pulse(8'hFF, 16'd2);

        // Corner: data = 0x00
        check_done_pulse(8'h00, 16'd3);

        report; $finish;
    end
endmodule
