
`include "defs.vh"
`include "AXI.sv"
`include "PC.sv"
`include "HS.sv"

module LEVE1
(
	input			CLK,
	input			RSTn,
	AXIR.init		RII	// read initiator: instruction
);
	AXIR			axiri;
	PC			pc;
	HS #(.WIDTH(32))	inst;

	LEVE_IBB		LEVE_IBB
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.RII		(axiri),
		.PC		(pc),
		.INST		(inst)
	);

	always_comb begin
		RII.ARVALID	= axiri.ARVALID;
		axiri.ARREADY	= RII.ARREADY;
		RII.ARADDR	= axiri.ARADDR;
		RII.ARBURST	= axiri.ARBURST;
		RII.ARLEN	= axiri.ARLEN;

		axiri.RVALID	= RII.RVALID;
		RII.RREADY	= axiri.RREADY;
		axiri.RDATA	= RII.RDATA;
		axiri.RLAST	= RII.RLAST;

		inst.READY	= 1'b1;
	end

	always_comb begin
		pc.VALID	= 1'b1;
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			pc.PC <= 64'h0000_0000_8000_0000;
		end else if(pc.est()) begin
			pc.PC <= `TPD pc.PC + 'h4;
		end
	end

	always @(posedge CLK) begin
		if(inst.est()) begin
			$display("[INFO] PC:INST = %h:%h", pc.PC, inst.PAYLOAD);
		end
	end

endmodule
