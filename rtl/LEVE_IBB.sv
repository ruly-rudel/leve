
`include "defs.vh"
`include "AXI.sv"
`include "PC.sv"
`include "HS.sv"

module LEVE_IBB
(
	input logic			CLK,
	input logic			RSTn,

	AXIR.init			RII,
	PC.target			PC,
	HS.init				INST
);

	always_comb begin
		RII.ARVALID	= PC.VALID;
		PC.READY	= RII.ARREADY;
		RII.ARADDR	= PC.PC[31:0];
		RII.ARBURST	= `AXI_BURST_WRAP;
		RII.ARLEN	= 8'd3;

		RII.RREADY	= 1'b1;
	end


	always @(posedge CLK) begin
		if(RII.r_est()) begin
			$display("[INFO] RDATA = %h", RII.RDATA);
		end
	end

endmodule : LEVE_IBB
