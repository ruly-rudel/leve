
`include "defs.vh"

module tb_iss
(
	input		CLK,
	input		RSTn
);

	wire		tohost_we;
	wire [32-1:0]	tohost;

	RISCV64G_ISS	RISCV64G_ISS_0
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.tohost_we	(tohost_we),
		.tohost		(tohost)
	);

	always_ff @(posedge CLK or negedge RSTn)
	begin
		if(RSTn)
		begin
			if(tohost_we) begin
				if(tohost == 32'h0000_0001) begin
					$display ("[TESTBENCH] [PASS] exit code %08H.", tohost);
				end else begin
					$display ("[TESTBENCH] [FAIL] exit code %08H, test number %2d fails", tohost, tohost >> 1);
				end
				$finish;
			end
		end
	end

endmodule
