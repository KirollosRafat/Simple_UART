module uart_rx #(
    parameter DATAWIDTH = 8,
    parameter SB_TICK = 16
) (
    input logic clk,
    input logic reset,
    input logic rx,
    input logic s_tick,
    output logic [DATAWIDTH-1:0] dout,
    output logic rx_done_tick
);

typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state_reg, state_next;
logic [DATAWIDTH-1:0] data_reg, data_next;
logic [$clog2(DATAWIDTH)-1:0] n_reg, n_next;
logic [$clog2(SB_TICK)-1:0] s_reg, s_next;



always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        state_reg <= IDLE;
        data_reg <= 0;
        n_reg <= 0;
        s_reg <= 0;
    end else begin
        state_reg <= state_next;
        data_reg <= data_next;
        n_reg <= n_next;
        s_reg <= s_next;
    end
end

always_comb begin
    state_next = state_reg;
    data_next = data_reg;
    n_next = n_reg;
    s_next = s_reg;
    rx_done_tick = 1'b0;
    
    case (state_reg)
        IDLE: begin
            if (~rx) begin
                state_next = START;
                s_next = 0;
            end
        end

        START: begin
            if (s_tick) begin
                if (s_reg == 7) begin  // Sample at midpoint (8th tick)
                    state_next = DATA;
                    s_next = 0;
                    n_next = 0;
                end else begin
                    s_next = s_reg + 1;
                end
            end
        end

        DATA: begin
            if (s_tick) begin
                if (s_reg == 15) begin  
                    data_next = {rx, data_reg[DATAWIDTH-1:1]};
                    s_next = 0;
                    if (n_reg == (DATAWIDTH-1)) begin
                        state_next = STOP;
                    end else begin
                        n_next = n_reg + 1;
                    end
                end else begin
                    s_next = s_reg + 1;
                end
            end
        end

        STOP: begin
            if (s_tick) begin
                if (s_reg == (SB_TICK-1)) begin
                    state_next = IDLE;
                    rx_done_tick = 1'b1;
                end else begin
                    s_next = s_reg + 1;
                end
            end
        end
    endcase
end

assign dout = data_reg;

endmodule