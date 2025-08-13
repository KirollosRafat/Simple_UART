// uart_tx.sv
// Active-high ASYNC reset (posedge reset)
// LSB-first, 1 start bit, 1 stop bit
module uart_tx #(
    parameter int DATAWIDTH = 8,
    parameter int SB_TICK   = 16
)(
    input  logic clk,
    input  logic reset,       // active-high async
    input  logic tx_start,    // trigger send
    input  logic [DATAWIDTH-1:0] din,
    input  logic s_tick,      // 16x oversample tick
    output logic tx,          // serial out
    output logic tx_done_tick // one cycle at end of stop bit
);
    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;
    state_t state, state_n;

    logic [$clog2(SB_TICK)-1:0] s_reg, s_n;
    logic [$clog2(DATAWIDTH)-1:0] n_reg, n_n;
    logic [DATAWIDTH-1:0] b_reg, b_n;
    logic tx_n;
    logic tx_done_n;

    // state regs
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            s_reg       <= '0;
            n_reg       <= '0;
            b_reg       <= '0;
            tx          <= 1'b1; // idle high
            tx_done_tick<= 1'b0;
        end else begin
            state       <= state_n;
            s_reg       <= s_n;
            n_reg       <= n_n;
            b_reg       <= b_n;
            tx          <= tx_n;
            tx_done_tick<= tx_done_n;
        end
    end

    // next state logic
    always_comb begin
        state_n     = state;
        s_n         = s_reg;
        n_n         = n_reg;
        b_n         = b_reg;
        tx_n        = tx;
        tx_done_n   = 1'b0;

        unique case (state)
            IDLE: begin
                tx_n = 1'b1;
                if (tx_start) begin
                    b_n     = din;
                    s_n     = '0;
                    state_n = START;
                end
            end

            START: begin
                tx_n = 1'b0; // start bit low
                if (s_tick) begin
                    if (s_reg == SB_TICK-1) begin
                        s_n     = '0;
                        n_n     = '0;
                        state_n = DATA;
                    end else begin
                        s_n = s_reg + 1'b1;
                    end
                end
            end

            DATA: begin
                tx_n = b_reg[n_reg];
                if (s_tick) begin
                    if (s_reg == SB_TICK-1) begin
                        s_n = '0;
                        if (n_reg == DATAWIDTH-1) begin
                            state_n = STOP;
                        end else begin
                            n_n = n_reg + 1'b1;
                        end
                    end else begin
                        s_n = s_reg + 1'b1;
                    end
                end
            end

            STOP: begin
                tx_n = 1'b1; // stop bit high
                if (s_tick) begin
                    if (s_reg == SB_TICK-1) begin
                        state_n   = IDLE;
                        tx_done_n = 1'b1;
                        s_n       = '0;
                    end else begin
                        s_n = s_reg + 1'b1;
                    end
                end
            end
        endcase
    end
endmodule
