`timescale 1ns/1ps
module test02_start_bit;
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
        $dumpfile("test02_start_bit.vcd"); $dumpvars(0, test02_start_bit);
        clk = 0;
        $display("===== TEST 2: Start Bit Generation =====");
        do_reset;

        // Directed: start bit = 0 for exactly `div` cycles, regardless of data value
        load_byte(8'hFF, 1'b0, 1'b0, 16'd6);
        check(tx === 1'b0, "DIRECTED: TX goes low the cycle load is serviced");
        wait_bits(16'd6, 1);
        check(tx === 1'b1, "DIRECTED: transitions to data bit0 (=1) after exactly div cycles");
        wait_bits(16'd6, 8); wait_bits(16'd6,1);

        // Directed: start bit held low even with all-ones data
        load_byte(8'h00, 1'b0, 1'b0, 16'd6);
        check(tx === 1'b0, "DIRECTED: TX low at start even for data=0x00");
        wait_bits(16'd6, 10);

        // Random: random data, random (small) baud div, start bit must be 0
        begin : rnd
            integer k; reg [7:0] rb; reg [3:0] rdv;
            for (k=0;k<6;k=k+1) begin
                rb = $random;
                rdv = ($random % 6); if (rdv < 3) rdv = rdv + 3; // keep div in [3..8]
                load_byte(rb, 1'b0, 1'b0, {12'd0,rdv});
                check(tx === 1'b0, "RANDOM: start bit low for random data/baud_div");
                wait_bits({12'd0,rdv}, 10);
            end
        end

        // Corner: minimum legal divisor (2)
        load_byte(8'hAA, 1'b0, 1'b0, 16'd2);
        check(tx === 1'b0, "CORNER: start bit low with minimum baud_div=2");
        wait_bits(16'd2, 10);

        // Corner: divisor given as 0/1 (DUT clamps internally) must still produce a start bit
        load_byte(8'h5A, 1'b0, 1'b0, 16'd0);
        check(tx === 1'b0, "CORNER: start bit low even when baud_div=0 (clamped internally)");
        wait_bits(16'd2, 10);

        report; $finish;
    end
endmodule
