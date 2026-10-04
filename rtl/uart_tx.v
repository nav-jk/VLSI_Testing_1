module uart_tx (
    input  wire        clk,
    input  wire        rst,          // synchronous active-high reset
    input  wire [15:0] baud_div,     // clock cycles per bit period (>=2)
    input  wire        parity_en,    // 1 = send parity bit
    input  wire        parity_odd,   // 1 = odd parity, 0 = even parity
    input  wire        load,         // pulse to load tx_data and start frame
    input  wire [7:0]  tx_data,      // byte to transmit
    output reg         tx,           // serial output line
    output reg         busy,         // high while frame in progress
    output reg         done,         // 1-cycle pulse when frame completes
    output wire        ready         // high when a new byte can be loaded
);

    localparam [2:0]
        ST_IDLE   = 3'd0,
        ST_START  = 3'd1,
        ST_DATA   = 3'd2,
        ST_PARITY = 3'd3,
        ST_STOP   = 3'd4,
        ST_DONE   = 3'd5;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;
    reg        parity_bit;

    assign ready = (state == ST_IDLE);

    // Safe divisor: avoid lock-up if baud_div is 0 or 1
    wire [15:0] div_safe = (baud_div < 16'd2) ? 16'd2 : baud_div;

    always @(posedge clk) begin
        if (rst) begin
            state      <= ST_IDLE;
            tx         <= 1'b1;
            busy       <= 1'b0;
            done       <= 1'b0;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            shift_reg  <= 8'd0;
            parity_bit <= 1'b0;
        end else begin
            done <= 1'b0; // default: deassert, pulse only in ST_DONE

            case (state)-
                ST_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (load) begin
                        shift_reg <= tx_data;
                        // compute parity over data bits
                        parity_bit <= parity_odd ? ~(^tx_data) : (^tx_data);
                        busy       <= 1'b1;
                        tx         <= 1'b0;      // start bit begins immediately
                        clk_cnt    <= 16'd0;     // consistent with other states: count from 0
                        bit_idx    <= 3'd0;
                        state      <= ST_START;
                    end
                end

                ST_START: begin
                    tx <= 1'b0;
                    if (clk_cnt >= div_safe - 1) begin
                        clk_cnt   <= 16'd0;
                        tx        <= shift_reg[0];
                        state     <= ST_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                ST_DATA: begin
                    tx <= shift_reg[0];
                    if (clk_cnt >= div_safe - 1) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            if (parity_en) begin
                                tx    <= parity_bit;
                                state <= ST_PARITY;
                            end else begin
                                tx    <= 1'b1;
                                state <= ST_STOP;
                            end
                        end else begin
                            shift_reg <= shift_reg >> 1;
                            bit_idx   <= bit_idx + 3'd1;
                            tx <= shift_reg[1];
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                ST_PARITY: begin
                    tx <= parity_bit;
                    if (clk_cnt >= div_safe - 1) begin
                        clk_cnt <= 16'd0;
                        tx      <= 1'b1;
                        state   <= ST_STOP;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                ST_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt >= div_safe - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= ST_DONE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                // -----------------------------------------------------------
                ST_DONE: begin
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
