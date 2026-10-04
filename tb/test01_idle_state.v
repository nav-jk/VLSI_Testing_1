// Functionality 1: Idle state - TX line held high, no start bit without load,
// ready asserted, busy deasserted.
`timescale 1ns/1ps

module test01_idle_state;

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
        $dumpfile("test01_idle_state.vcd");
        $dumpvars(0, test01_idle_state);

        clk = 0;
        $display(" TEST 1: Idle State ");

        // Directed: after reset, must be idle 
        do_reset;
        check(tx    === 1'b1, "DIRECTED: TX high immediately after reset");
        check(busy  === 1'b0, "DIRECTED: BUSY low after reset");
        check(ready === 1'b1, "DIRECTED: READY high after reset");
        check(done  === 1'b0, "DIRECTED: DONE low after reset");

        //  Directed: stays idle over many cycles with no load 
        wait_bits(16'd10, 5);
        check(tx === 1'b1 && busy === 1'b0 && ready === 1'b1,
              "DIRECTED: remains idle with load=0 for extended time");

        // Random: idle-hold for a pseudo-random number of cycles 
        begin : rand_idle
            integer k, cycles;
            for (k = 0; k < 5; k = k + 1) begin
                cycles = ($random % 20);
                if (cycles < 0) cycles = -cycles;
                repeat (cycles) @(negedge clk);
                check(tx === 1'b1 && busy === 1'b0,
                      "RANDOM: idle holds TX=1/BUSY=0 for random wait");
            end
        end

        // Corner case: load pulses exactly at time 0 of a fresh reset 
        do_reset;
        load_byte(8'h00, 1'b0, 1'b0, 16'd4);
        check(busy === 1'b1, "CORNER: busy goes high same cycle load is serviced (no idle leak)");
        // drain the frame so sim ends cleanly
        wait_bits(16'd4, 10);

        report;
        $finish;
    end

endmodule
