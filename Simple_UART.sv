`timescale 1ns/1ps

module uart_tb;

    localparam int CLK_FREQ  = 100_000_000;
    localparam int BAUDRATE  = 9600;
    localparam int SB_TICK   = 16;
    localparam int DATAWIDTH = 8;

    logic clk;
    logic reset;

    logic s_tick;
    logic tx;
    logic tx_start;
    logic tx_done_tick;
    logic [DATAWIDTH-1:0] tx_data;

    logic [DATAWIDTH-1:0] rx_data;
    logic rx_done_tick;

    // Clock gen: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk; // 10ns period

    // Baudrate generator
    baudrate_gen #(.BAUDRATE(BAUDRATE), .CLK_FREQ(CLK_FREQ))
        baud (.clk(clk), .reset(reset), .tick(s_tick));

    // TX
    uart_tx #(.DATAWIDTH(DATAWIDTH), .SB_TICK(SB_TICK)) 
        txu (.clk(clk), .reset(reset),
             .tx_start(tx_start), .din(tx_data),
             .s_tick(s_tick), .tx(tx), .tx_done_tick(tx_done_tick));

    // RX
    uart_rx #(.DATAWIDTH(DATAWIDTH), .SB_TICK(SB_TICK))
        rxu (.clk(clk), .reset(reset),
             .rx(tx), .s_tick(s_tick),
             .dout(rx_data), .rx_done_tick(rx_done_tick));

    initial begin
        // Init
        reset = 1;
        tx_data = 0;
        tx_start = 0;
        #50 reset = 0;

        // Wait a bit after reset
        #1000;

        // Send 0xA5
        tx_data = 8'hC1;
        @(negedge clk) tx_start = 1;
        @(negedge clk) tx_start = 0;

        // Wait for RX to complete
        wait (rx_done_tick);
	$display("TX sent: %02h", tx_data);
        $display("RX received: %02h", rx_data);

        if (rx_data == 8'hC1)
            $display("PASS: Successful Communiaction\n");
        else
            $display("FAIL: Expected Recieved Byte 0xA5\n");

        #2000 $finish;
    end
endmodule

