
module baudrate_gen 
#(
parameter BAUDRATE = 9600,  // Default baudrate
parameter CLK_FREQ = 100_000_000 // 100 MHz default clock frequency
)
(
input logic clk, 
input logic reset,
output logic tick
);
// Ceiling to avoid fractions
parameter FINAL_TICK = $ceil((CLK_FREQ/(16*BAUDRATE))); 

logic [15:0] DIVISOR;
logic [15:0] counter;
 
assign DIVISOR = FINAL_TICK;

always_ff@(posedge clk, posedge reset)begin
	if(reset) begin
		tick <= 0;
		counter <= 0;
	end
	else if(counter == (DIVISOR - 1)) begin
		counter <= 0;
		tick <= 1;	
	end else begin
		counter <= counter + 1;
		tick <= 0;
	end
end


endmodule 