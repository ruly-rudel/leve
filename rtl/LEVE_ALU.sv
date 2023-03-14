
`include "defs.vh"


module LEVE_ALU
(
	input logic			CLK,
	input logic			RSTn,

	input logic			RS_D_VALID,
	input logic [`XLEN-1:0]		RS1_D,
	input logic [`XLEN-1:0]		RS2_D,

	output logic			RD_WE,
	output logic [`XLEN-1:0]	RD_D,
	output logic			PC_BR,
	output logic [`XLEN-1:0]	ALU_OUT
);


	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			RD_WE		<= `TPD 1'b0;
		end else begin
			RD_WE		<= `TPD RS_D_VALID;
			RD_D		<= `TPD RS1_D + RS2_D;

			PC_BR		<= `TPD 1'b0;
		end
	end

endmodule : LEVE_ALU
