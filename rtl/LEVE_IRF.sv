
`include "defs.vh"


module LEVE_IRF		// integer register files
(
	input logic			CLK,
	input				RSTn,

	input logic			RS1_VALID,
	input logic [4:0]		RS1,
	input logic [2:0]		RS1EXT,
	input logic			RS2_VALID,
	input logic [4:0]		RS2,
	input logic [2:0]		RS2EXT,

	input logic [`XLEN-1:0]		IMM_I,
	input logic [`XLEN-1:0]		IMM_W,

	output logic [`XLEN-1:0]	RS1_D,
	output logic [`XLEN-1:0]	RS2_D,

	input logic			RD_WE,
	input logic [4:0]		RD,
	input logic [`XLEN-1:0]		RD_D,

	input logic			CSR_WE,
	input logic [`XLEN-1:0]		CSR_D

);

	logic [`XLEN-1:0]	reg_file[1:`NUM_REG-1];

	always @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			RS1_D		<= {`XLEN{1'b0}};
		end else if(RS1_VALID) begin
			case (RS1EXT)
			`IRF_REG:	RS1_D	<= `TPD RS1 == 5'h00 ? {`XLEN{1'b0}} : reg_file[RS1];
			`IRF_IMM_I:	RS1_D	<= `TPD IMM_I;
			`IRF_IMM_W:	RS1_D	<= `TPD IMM_W;
			default: ;
			endcase
		end
	end

	always @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			RS2_D		<= {`XLEN{1'b0}};
		end else if(RS2_VALID) begin
			case (RS2EXT)
			`IRF_REG:	RS2_D	<= `TPD RS2 == 5'h00 ? {`XLEN{1'b0}} : reg_file[RS2];
			`IRF_IMM_I:	RS2_D	<= `TPD IMM_I;
			`IRF_IMM_W:	RS2_D	<= `TPD IMM_W;
			default: ;
			endcase
		end
	end

	always @(posedge CLK or negedge RSTn) begin
		if(RSTn && RD_WE) begin
			if(RD != 5'h00) begin
				reg_file[RD] <= `TPD CSR_WE ? CSR_D : RD_D;
			end
		end
	end

endmodule : LEVE_IRF
