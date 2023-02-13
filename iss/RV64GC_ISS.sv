
`include "defs.vh"

`include "ISS.sv"
`include "TRACE.sv"

module RV64GC_ISS (
	input			CLK,
	input			RSTn,

	input string		init_file,

	output reg		tohost_we,
	output reg [32-1:0]	tohost
);
	// ISS
	ISS			iss = new;
	TRACE			trace = new;

	// PC
	logic  [`XLEN-1:0]	pc;
	logic  [`XLEN-1:0]	next_pc;

	// main loop
	always_ff @(posedge CLK or negedge RSTn)
	begin
		logic [`XLEN-1:0]	tmp;
		logic [`XLEN-1:0]	trap_pc;
		logic [`XLEN-1:0]	next_pc;
		logic [32-1:0]		inst;

		if(!RSTn) begin
			iss.init(init_file);
			pc = iss.get_entry_point();
			tohost_we = 1'b0;
		end else begin
			tohost_we = 1'b0;
			trace.print(pc, iss.get_instruction(pc));
			iss.exec(pc, next_pc, tohost_we, tohost);
			pc = next_pc;
		end
	end

endmodule
