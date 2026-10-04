`timescale 1ns/1ps
module test08_busy_flag;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    // Checks busy stays high for exactly the full frame length (10 bit periods: start+8data+stop)
    task automatic check_busy_window;
        input [7:0] data;
        input [15:0] div;
        integer total_bits, i;
        begin
            total_bits = 10; // start + 8 data + stop (no parity here)
            check(busy === 1'b0, "busy low before load");
            load_byte(data, 1'b0, 1'b0, div);
            // busy is high for the whole frame PLUS one extra cycle (the FSM's
            // internal DONE state, which runs for 1 cycle before returning to IDLE)
            for (i = 0; i < total_bits*div; i = i + 1) begin
                check(busy === 1'b1, "busy stays high throughout the frame");
                @(negedge clk);
            end
            check(busy === 1'b1, "busy still high during the 1-cycle DONE state");
            @(negedge clk);
            check(busy === 1'b0, "busy deasserts exactly after frame completes");
        end
    endtask

    initial begin
        $dumpfile("test08_busy_flag.vcd"); $dumpvars(0, test08_busy_flag);
        clk = 0;
        $display(" TEST 8: Busy/TX-Active Flag ");
        do_reset;

        // Directed
        check_busy_window(8'h3C, 16'd4);
        wait_bits(16'd4, 1);

        // Random
        begin : rnd
            integer k; reg [3:0] rdv;
            for (k=0;k<4;k=k+1) begin
                rdv = ($random % 5); if (rdv<2) rdv=rdv+2;
                check_busy_window($random, {12'd0,rdv});
                wait_bits({12'd0,rdv}, 1);
            end
        end

        // Corner: minimum divisor
        check_busy_window(8'hFF, 16'd2);
        wait_bits(16'd2,1);

        // Corner: data = 0x00 (no bit transitions during data phase, easy to accidentally
        // mis-detect busy if logic depended on tx toggling)
        check_busy_window(8'h00, 16'd3);

        report; $finish;
    end
endmodule
