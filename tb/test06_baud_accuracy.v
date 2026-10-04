`timescale 1ns/1ps
module test06_baud_accuracy;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    // Measures start-bit width precisely by counting cycles to the exact
    // boundary (not by polling tx, since data bit0 can also be 0 and would
    // be indistinguishable from an extended start bit).
    task automatic measure_start_bit_width;
        input [7:0] data;
        input [15:0] div;
        integer i;
        reg ok;
        begin
            load_byte(data, 1'b0, 1'b0, div);
            ok = 1'b1;
            if (tx !== 1'b0) ok = 1'b0;
            for (i = 0; i < div - 1; i = i + 1) begin
                @(negedge clk);
                if (tx !== 1'b0) ok = 1'b0; // must still be in start bit
            end
            @(negedge clk); // this is the div-th transition -> should now be data bit0
            if (tx !== data[0]) ok = 1'b0;
            check(ok, "measured start-bit width equals programmed baud_div");
            wait_bits(div, 9); // drain rest of frame
        end
    endtask

    initial begin
        $dumpfile("test06_baud_accuracy.vcd"); $dumpvars(0, test06_baud_accuracy);
        clk = 0;
        $display(" TEST 6: Baud Rate Accuracy ");
        do_reset;

        // Directed: a spread of common divisor values
        measure_start_bit_width(8'h55, 16'd4);
        measure_start_bit_width(8'h55, 16'd8);
        measure_start_bit_width(8'h55, 16'd16);

        // Random: random divisor in a safe range
        begin : rnd
            integer k; reg [4:0] rdv;
            for (k=0;k<6;k=k+1) begin
                rdv = ($random % 28); if (rdv<2) rdv = rdv+2; // keep in [2..29]
                measure_start_bit_width($random, {11'd0,rdv});
            end
        end

        // Corner: minimum divisor (2) and a larger boundary divisor (64)
        measure_start_bit_width(8'hF0, 16'd2);
        measure_start_bit_width(8'hF0, 16'd64);

        report; $finish;
    end
endmodule
