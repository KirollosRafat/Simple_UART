// uart_rx.sv
// Active-high ASYNC reset (posedge reset)
// LSB-first, 1 start bit, 1 stop bit
//

module uart_rx #(
    parameter int DATAWIDTH = 8,
    parameter int SB_TICK   = 16
) (
    input  logic                  clk,
    input  logic                  reset,       // active-high async
    input  logic                  rx,
    input  logic                  s_tick,      // 16x oversample tick
    output logic [DATAWIDTH-1:0]  dout,
    output logic                  rx_done_tick
);

    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;
    state_t state_reg, state_next;

    logic [DATAWIDTH-1:0]            data_reg,  data_next;
    logic [$clog2(DATAWIDTH+1)-1:0]  n_reg,     n_next;
    logic [$clog2(SB_TICK)-1:0]      s_reg,     s_next;

    // ---------- state registers ----------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            data_reg  <= '0;
            n_reg     <= '0;
            s_reg     <= '0;
        end else begin
            state_reg <= state_next;
            data_reg  <= data_next;
            n_reg     <= n_next;
            s_reg     <= s_next;
        end
    end

    // ---------- next-state / output logic ----------
    always_comb begin
        state_next   = state_reg;
        data_next    = data_reg;
        n_next       = n_reg;
        s_next       = s_reg;
        rx_done_tick = 1'b0;

        case (state_reg)

            // ---- IDLE ----
            IDLE: begin
                if (~rx) begin          // falling edge → start bit detected
                    state_next = START;
                    s_next     = '0;
                end
            end

            // ---- START ----
            // Wait SB_TICK/2 ticks to sample at the centre of the start bit.
            START: begin
                if (s_tick) begin
                    if (s_reg == (SB_TICK/2 - 1)) begin
                        state_next = DATA;
                        s_next     = '0;
                        n_next     = '0;
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            // ---- DATA ----
            DATA: begin
                if (s_tick) begin
                    if (s_reg == (SB_TICK-1)) begin
                        // FIX 3: SB_TICK-1 instead of hardcoded 15
                        data_next = {rx, data_reg[DATAWIDTH-1:1]};
                        s_next    = '0;
                        if (n_reg == (DATAWIDTH-1)) begin
                            state_next = STOP;
                        end else begin
                            n_next = n_reg + 1'b1;
                        end
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            // ---- STOP ----
            // Wait a full bit period, assert rx_done_tick, return to IDLE.
            // FIX 4: added s_next = '0 on transition so next frame starts clean.
            STOP: begin
                if (s_tick) begin
                    if (s_reg == (SB_TICK-1)) begin
                        state_next   = IDLE;
                        rx_done_tick = 1'b1;
                        s_next       = '0;   // FIX 4
                    end else begin
                        s_next = s_reg + 1'b1;
                    end
                end
            end

            default: begin
                state_next = IDLE;
            end

        endcase
    end

    // dout is valid and stable once rx_done_tick pulses
    assign dout = data_reg;

endmodule

