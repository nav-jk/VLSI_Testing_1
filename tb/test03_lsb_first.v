`timescale 1ns/1ps
module test03_lsb_first;
    reg clk, rst, load, parity_en, parity_odd;
    reg [7:0] tx_data;
    reg [15:0] baud_div;
    wire tx, busy, done, ready;

    uart_tx dut (.clk(clk), .rst(rst), .baud_div(baud_div), .parity_en(parity_en),
        .parity_odd(parity_odd), .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready));

    always #5 clk = ~clk;
    `include "uart_common.vh"

    task automatic check_order;
        input [7:0] data;
        input [15:0] div;
        integer i;
        begin
            load_byte(data, 1'b0, 1'b0, div);
            wait_bits(div, 1); // past start bit, now at bit0
            for (i = 0; i < 8; i = i + 1) begin
                check(tx === data[i], "bit order: data[i] appears i-th on the line");
                wait_bits(div, 1);
            end
            wait_bits(div, 1); // consume stop bit
            @(negedge clk);    // extra cycle: FSM's DONE state before returning to IDLE
        end
    endtask

    initial begin
        $dumpfile("test03_lsb_first.vcd"); $dumpvars(0, test03_lsb_first);
        clk = 0;
        $display(" TEST 3: LSB-First Bit Ordering ");
        do_reset;

        // Directed: a single 1 walking through each bit position
        check_order(8'b00000001, 16'd4); // only bit0 set -> first bit out should be 1, rest 0
        check_order(8'b10000000, 16'd4); // only bit7 set -> first bit out should be 0, last bit 1

        // Random
        begin : rnd
            integer k; reg [7:0] rb;
            for (k=0;k<6;k=k+1) begin
                rb = $random;
                check_order(rb, 16'd4);
            end
        end

        // Corner: alternating patterns most likely to expose ordering bugs
        check_order(8'b10101010, 16'd4);
        check_order(8'b01010101, 16'd4);

        report; $finish;
    end
endmodule
