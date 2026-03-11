// uart_rx.sv
// Active-high ASYNC reset (posedge reset)
// LSB-first, 1 start bit, 1 stop bit
//
// Bug fixes applied:
//   1. n_reg width: $clog2(DATAWIDTH) is one bit short for exact powers of
//      two (DATAWIDTH=8 → 3 bits, max=7, which is DATAWIDTH-1 — works by
//      coincidence but is fragile). Fixed to $clog2(DATAWIDTH+1).
//
//   2. DATA shift direction: data_next = {rx, data_reg[DATAWIDTH-1:1]}
//      shifts rx into the MSB, assembling the byte MSB-first. UART is
//      LSB-first, so the first received bit must land in bit[0].
//      Fixed to: data_next = {rx, data_reg[DATAWIDTH-1:1]}  → this is
//      actually correct for a right-shift with rx entering at MSB only
//      if we reverse at the end — simpler and clearer to shift rx into
//      LSB side: data_next = {data_reg[DATAWIDTH-2:0], rx} would be
//      MSB-first. The correct LSB-first form is to shift RIGHT and feed
//      rx into the TOP, which is what the original does — but then dout
//      must NOT be data_reg directly; the bits are in reverse order.
//      The cleanest fix: shift rx into bit[0] each time by shifting the
//      register left and placing rx at [DATAWIDTH-1] is wrong too.
//      Correct LSB-first: on each bit period, shift right and insert rx
//      at the MSB position, so after DATAWIDTH bits, bit[0] holds the
//      first-received (LSB) bit. The original code IS correct for this —
//      HOWEVER the DATA sampling uses s_reg == 15 (hardcoded), not
//      SB_TICK-1. See fix 3.
//
//   3. DATA state: s_reg == 15 is hardcoded instead of using SB_TICK-1.
//      If SB_TICK is ever changed from 16 the DATA state would mis-sample.
//      Fixed to s_reg == (SB_TICK-1).
//
//   4. STOP state: s_next is never reset to 0 after the stop bit completes,
//      leaving stale counter state for the next frame's START detection.
//      Fixed by adding s_next = 0 on the STOP→IDLE transition.
//
//   5. Missing default branch in case statement: illegal state encodings
//      can cause X-propagation in simulation and latch inference in
//      synthesis. Added default: state_next = IDLE.
//
//   6. START midpoint sampling: comment says "8th tick" (s_reg==7) which
//      is correct for SB_TICK=16 (half-bit period = 8 ticks, indices 0-7).
//      This is fine, but expressed as (SB_TICK/2 - 1) it becomes
//      parameterisation-safe.

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
    // FIX 1: $clog2(DATAWIDTH+1) avoids the off-by-one for powers of two
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
            // FIX 6: use (SB_TICK/2 - 1) so this scales with SB_TICK.
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
            // Sample at full-bit period (SB_TICK-1).
            // FIX 3: was hardcoded 15; now uses SB_TICK-1.
            // Shift rx into MSB on each sample; after DATAWIDTH bits the
            // first-received bit (LSB) sits at data_reg[0] — correct for
            // LSB-first UART.
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

            // FIX 5: default prevents X-propagation on illegal state encoding
            default: begin
                state_next = IDLE;
            end

        endcase
    end

    // dout is valid and stable once rx_done_tick pulses
    assign dout = data_reg;

endmodule
