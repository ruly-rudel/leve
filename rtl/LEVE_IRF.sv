
`include "defs.vh"


module LEVE_IRF		// integer register files
(
	input logic			CLK,
	input				RSTn,

	input logic			RS1_VALID,
	input logic [4:0]		RS1,
	input logic			RS2_VALID,
	input logic [4:0]		RS2,
	input logic [2:0]		RS2EXT,

	input logic [`XLEN-1:0]		IMM_I,

	output logic			RS_D_VALID,
	output logic [`XLEN-1:0]	RS1_D,
	output logic [`XLEN-1:0]	RS2_D,

	input logic			RD_WE,
	input logic [4:0]		RD,
	input logic [`XLEN-1:0]		ALU_OUT

);

	logic [`XLEN-1:0]	reg_file[1:`NUM_REG-1];

	always @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			RS1_D		<= {`XLEN{1'b0}};
		end else if(RS1_VALID) begin
			RS1_D		<= `TPD RS1 == 5'h00 ? {`XLEN{1'b0}} : reg_file[RS1];
		end
	end

	always @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			RS2_D		<= {`XLEN{1'b0}};
		end else if(RS2_VALID) begin
			case (RS2EXT)
			3'h0: RS2_D	<= `TPD RS2 == 5'h00 ? {`XLEN{1'b0}} : reg_file[RS2];
			3'h1: RS2_D	<= `TPD IMM_I;
			default: ;
			endcase
		end
	end

	always @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			RS_D_VALID	<= 1'b0;
		end else begin
			RS_D_VALID	<= `TPD RS1_VALID | RS2_VALID;
		end
	end

	always @(posedge CLK or negedge RSTn) begin
		if(RSTn && RD_WE) begin
			if(RD != 5'h00) begin
				reg_file[RD] <= `TPD ALU_OUT;
			end
		end
	end

endmodule : LEVE_IRF
