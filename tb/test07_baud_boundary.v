`timescale 1ns/1ps
module test07_baud_boundary;
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
        $dumpfile("test07_baud_boundary.vcd"); $dumpvars(0, test07_baud_boundary);
        clk = 0;
        $display(" TEST 7: Boundary Baud Divisor Values ");
        do_reset;

        // Directed: minimum legal divisor (2) - full frame must still be correct
        send_and_check_frame(8'h3C, 1'b0, 1'b0, 16'd2); wait_bits(16'd2, 2);

        // Directed: a large divisor (max 16-bit value is impractical for sim time,
        // use a representative "large" value instead)
        send_and_check_frame(8'h3C, 1'b0, 1'b0, 16'd100); wait_bits(16'd100, 2);

        // Corner: divisor = 0 (should be clamped internally to 2 by the DUT, not hang)
        send_and_check_frame(8'hA5, 1'b0, 1'b0, 16'd0); wait_bits(16'd2, 2);

        // Corner: divisor = 1 (also clamped to 2 internally)
        send_and_check_frame(8'hA5, 1'b0, 1'b0, 16'd1); wait_bits(16'd2, 2);

        // Random: divisor values spanning small-to-moderate range
        begin : rnd
            integer k; reg [6:0] rdv;
            for (k=0;k<4;k=k+1) begin
                rdv = ($random % 60); if (rdv<2) rdv = rdv+2;
                send_and_check_frame($random, 1'b0, 1'b0, {9'd0,rdv});
                wait_bits({9'd0,rdv}, 2);
            end
        end

        report; $finish;
    end
endmodule
