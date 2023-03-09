
`include "defs.vh"


module LEVE_BRP
(
	input logic			CLK,
	input logic			RSTn,

	PC.init				PC,

	input logic [`XLEN-1:0]		IMM_J,
	input logic 			JAL,
	input logic 			PC_BR,
	input logic [`XLEN-1:0]		ALU_OUT,

	output logic [`XLEN-1:0]	PCp4
);
	logic [`XLEN-1:0]		add_j;

	always_comb begin
		PC.VALID		= 1'b1;

		PCp4			= PC.PC + 'h4;
		add_j			= PC.PC + IMM_J;
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			PC.PC		<= 64'h0000_0000_8000_0000;
		end else if(pc.est()) begin
			if(PC_BR) begin
				PC.PC	<= `TPD ALU_OUT;
			end else if(JAL) begin
				PC.PC	<= `TPD add_j;
			end else begin
				PC.PC	<= `TPD PCp4;
			end
		end
	end

endmodule
