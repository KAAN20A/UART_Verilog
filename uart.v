module baudrate_generator(
    input clk,
    input reset,
    input [1:0] baud_sel, 
    output reg baud_tick
);
  
    localparam DIV_9600   = 833;   // 8MHz/9600
    localparam DIV_19200  = 417;   // 8MHz/19200
    localparam DIV_38400  = 208;   // 8MHz/38400
    localparam DIV_115200 = 69;    // 8MHz/115200

    reg [15:0] counter;
    reg [15:0] limit;

    
    always @(*) begin
        case (baud_sel)
            2'b00: limit = DIV_9600;
            2'b01: limit = DIV_19200;
            2'b10: limit = DIV_38400;
            2'b11: limit = DIV_115200;
            default: limit = DIV_9600;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            baud_tick <= 0;
        end else if (counter >= limit) begin
            counter <= 0;
            baud_tick <= 1;
        end else begin
            counter <= counter + 1;
            baud_tick <= 0;
        end
    end
endmodule


module uart_rx(
    input clk, reset,
    input baud_tick,
    input rx,
    output reg [7:0] rx_data,
    output reg rx_done
);
    localparam IDLE = 3'd0, START = 3'd1, DATA = 3'd2, STOP = 3'd3;
    reg [2:0] state;
    reg [3:0] bit_idx;
    reg [7:0] shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            bit_idx <= 0;
            rx_done <= 0;
        end else begin
            rx_done <= 0;
            case(state)
                IDLE: if (~rx) state <= START;
                START: if (baud_tick) state <= DATA;
                DATA: if (baud_tick) begin
                    shift[bit_idx] <= rx;
                    if (bit_idx < 7) bit_idx <= bit_idx + 1;
                    else begin
                        bit_idx <= 0;
                        state <= STOP;
                    end
                end
                STOP: if (baud_tick) begin
                    rx_data <= shift;
                    rx_done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


module uart_tx(
    input clk, reset,
    input baud_tick,
    input tx_start,
    input [7:0] tx_data,
    output reg tx,
    output reg tx_busy,
    output reg tx_done
);
    localparam IDLE = 3'd0, START = 3'd1, DATA = 3'd2, STOP = 3'd3, CLEAN = 3'd4;
    reg [2:0] state;
    reg [3:0] bit_idx;
    reg [7:0] shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx <= 1;
            tx_busy <= 0;
            tx_done <= 0;
            bit_idx <= 0;
        end else begin
            tx_done <= 0;
            case(state)
                IDLE: begin
                    tx <= 1;
                    if (tx_start) begin
                        shift <= tx_data;
                        tx_busy <= 1;
                        state <= START;
                    end
                end
                START: if (baud_tick) begin
                    tx <= 0;
                    state <= DATA;
                end
                DATA: if (baud_tick) begin
                    tx <= shift[bit_idx];
                    if (bit_idx < 7) bit_idx <= bit_idx + 1;
                    else begin
                        bit_idx <= 0;
                        state <= STOP;
                    end
                end
                STOP: if (baud_tick) begin
                    tx <= 1;
                    state <= CLEAN;
                end
                CLEAN: begin
                    tx_busy <= 0;
                    tx_done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module uart_top(
    input clk, reset,
    input [1:0] baud_select,
    input rx,
    input tx_start,
    input [7:0] tx_data,
    output tx,
    output [7:0] rx_data,
    output tx_done,
    output rx_done
);
    wire baud_tick;

    baudrate_mux brg(
        .clk(clk),
        .reset(reset),
        .sel(baud_select),
        .baud_tick(baud_tick)
    );

    uart_tx tx0(
        .clk(clk), .reset(reset),
        .baud_tick(baud_tick),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx), .tx_busy(), .tx_done(tx_done)
    );

    uart_rx rx0(
        .clk(clk), .reset(reset),
        .baud_tick(baud_tick),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );
endmodule
