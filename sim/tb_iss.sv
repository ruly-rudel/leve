
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


	initial begin
		$readmemh("rv64ui-p.hex", RISCV64G_ISS_0.mem);
	end

	always_ff @(posedge CLK or negedge RSTn)
	begin
		if(RSTn)
		begin
			if(tohost_we) begin
				$display ("[TESTBENCH] exit code %08H.", tohost);
				$finish;
			end
		end
	end

endmodule
