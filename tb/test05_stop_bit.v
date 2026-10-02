`timescale 1ns/1ps
module test05_stop_bit;
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
        $dumpfile("test05_stop_bit.vcd"); $dumpvars(0, test05_stop_bit);
        clk = 0;
        $display("===== TEST 5: Stop Bit Generation =====");
        do_reset;

        // Directed: full frame checks include stop bit already; confirm explicitly for 0xFF and 0x00
        send_and_check_frame(8'hFF, 1'b0, 1'b0, 16'd4); wait_bits(16'd4,2);
        send_and_check_frame(8'h00, 1'b0, 1'b0, 16'd4); wait_bits(16'd4,2);

        // Directed: stop bit duration held for full `div` cycles (sample mid and near-end)
        load_byte(8'hAA, 1'b0, 1'b0, 16'd8);
        wait_bits(16'd8, 9); // start + 8 data bits -> now at stop bit edge
        check(tx === 1'b1, "DIRECTED: stop bit high right at start of stop period");
        repeat (4) @(negedge clk);
        check(tx === 1'b1, "DIRECTED: stop bit remains high mid-period");
        wait_bits(16'd8, 1);

        // Random: random data + random div, stop bit must be 1
        begin : rnd
            integer k; reg [7:0] rb; reg [3:0] rdv;
            for (k=0;k<6;k=k+1) begin
                rb = $random;
                rdv = ($random % 6); if (rdv<3) rdv = rdv+3;
                load_byte(rb, 1'b0, 1'b0, {12'd0,rdv});
                wait_bits({12'd0,rdv}, 9);
                check(tx === 1'b1, "RANDOM: stop bit =1 for random data/baud");
                wait_bits({12'd0,rdv}, 1);
            end
        end

        // Corner: minimum baud_div=2
        load_byte(8'h3C, 1'b0, 1'b0, 16'd2);
        wait_bits(16'd2, 9);
        check(tx === 1'b1, "CORNER: stop bit correct at minimum baud_div=2");
        wait_bits(16'd2,1);

        report; $finish;
    end
endmodule
