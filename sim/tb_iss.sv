



module tb_iss
(
	input		CLK,
	input		RSTn
);


	RISCV64G_ISS	RISCV64G_ISS_0
	(
		.CLK		(CLK),
		.RSTn		(RSTn)
	);


	initial begin
		$readmemh("rv64ui-p.hex", RISCV64G_ISS_0.mem);
	end

endmodule
