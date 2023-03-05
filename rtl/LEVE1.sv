
`include "defs.vh"
`include "AXI.sv"

module LEVE1
(
	input			CLK,
	input			RSTn,
	AXI.r_init		RII
);


	reg [31:0]	cnt;
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			cnt <= 32'h8000_0000;
		end else if(RII.ARVALID && RII.ARREADY) begin
			cnt <= cnt + 'h10;
		end
	end

	// read address
	assign RII.ARADDR = cnt;
	assign RII.ARVALID = 1'b1;


	assign RII.RREADY = 1'b1;

	always @(posedge CLK) begin
		if(RII.RVALID && RII.RREADY) begin
			$display("[INFO] RDATA = %h", RII.RDATA);
		end
	end

endmodule
