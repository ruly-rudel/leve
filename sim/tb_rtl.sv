
`include "defs.vh"

module tb_rtl
(
	input		CLK,
	input		RSTn
);

	wire		tohost_we;
	wire [32-1:0]	tohost;
	string		init_file;

	AXIR	axiri;		// AXI read: instruction
	AXIR	axird;		// AXI read: data
	AXIW	axiwd;		// AXI write: data


	LEVE1	LEVE1
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RII		(axiri)
	);

	TB_RAM	TB_RAM
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RT		(axiri),
		.WT		(axiwd),
		.init_file	(init_file)
	);

	initial begin
		if($value$plusargs("ELF=%s", init_file))
		begin
			$display ("[ARG] +ELF=%s", init_file);
		end
	end

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
