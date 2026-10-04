// Functionality 4: Data pattern integrity - 0x00, 0xFF, 0xAA, 0x55 and random bytes
`timescale 1ns/1ps

module test04_data_pattern;

    reg         clk, rst, load, parity_en, parity_odd;
    reg  [7:0]  tx_data;
    reg  [15:0] baud_div;
    wire        tx, busy, done, ready;

    uart_tx dut (
        .clk(clk), .rst(rst), .baud_div(baud_div),
        .parity_en(parity_en), .parity_odd(parity_odd),
        .load(load), .tx_data(tx_data),
        .tx(tx), .busy(busy), .done(done), .ready(ready)
    );

    always #5 clk = ~clk;

    `include "uart_common.vh"

    initial begin
        $dumpfile("test04_data_pattern.vcd");
        $dumpvars(0, test04_data_pattern);
        clk = 0;
        $display(" TEST 4: Data Pattern Integrity ");

        do_reset;

        //  Directed 
        send_and_check_frame(8'h00, 1'b0, 1'b0, 16'd4); wait_bits(16'd4, 2);
        send_and_check_frame(8'hFF, 1'b0, 1'b0, 16'd4); wait_bits(16'd4, 2);
        send_and_check_frame(8'hAA, 1'b0, 1'b0, 16'd4); wait_bits(16'd4, 2);
        send_and_check_frame(8'h55, 1'b0, 1'b0, 16'd4); wait_bits(16'd4, 2);

        //  Random 
        begin : rnd
            integer k;
            reg [7:0] rb;
            for (k = 0; k < 8; k = k + 1) begin
                rb = $random;
                send_and_check_frame(rb, 1'b0, 1'b0, 16'd4);
                wait_bits(16'd4, 2);
            end
        end

        //  Corner cases: boundary single-bit patterns 
        send_and_check_frame(8'h01, 1'b0, 1'b0, 16'd4); wait_bits(16'd4, 2); // only LSB set
        send_and_check_frame(8'h80, 1'b0, 1'b0, 16'd4); wait_bits(16'd4, 2); // only MSB set

        report;
        $finish;
    end

endmodule
