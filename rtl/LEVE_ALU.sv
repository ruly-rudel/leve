
`include "defs.vh"


module LEVE_ALU
(
	input logic			CLK,
	input logic			RSTn,

	input logic			RS_D_VALID,
	input logic [`XLEN-1:0]		RS1_D,
	input logic [`XLEN-1:0]		RS2_D,

	output logic			ALU_OUT_VALID,
	output logic [`XLEN-1:0]	ALU_OUT
);


	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			ALU_OUT_VALID	<= `TPD 1'b0;
		end else begin
			ALU_OUT_VALID	<= `TPD RS_D_VALID;
			ALU_OUT		<= `TPD RS1_D + RS2_D;
		end
	end

endmodule : LEVE_ALU
