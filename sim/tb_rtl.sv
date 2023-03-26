
`include "defs.vh"
`include "ISS.sv"

module tb_rtl
(
	input		CLK,
	input		RSTn
);

	wire			pc_en;
	wire [`XLEN-1:0]	pc;
	logic [`XLEN-1:0]	pc_iss;
	logic [`XLEN-1:0]	next_pc;
	logic			tohost_we;
	logic [32-1:0]		tohost;
	string			init_file;

	// ISS
	ISS			iss = new;

	AXIR	axiri;		// AXI read: instruction
	AXIR	axird;		// AXI read: data
	AXIW	axiwd;		// AXI write: data


	LEVE1	LEVE1
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.PC_EN		(pc_en),
		.PC_CNT		(pc),
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
		if(!RSTn) begin
			iss.init(init_file);
			pc_iss = iss.get_entry_point();
			tohost_we = 1'b0;
		end else if(pc_en) begin
			tohost_we = 1'b0;
			iss.exec(pc_iss, next_pc, tohost_we, tohost);
			if(pc_iss != pc) begin
				$display ("[TESTBENCH] [FAIL] PC missmatch at %h", pc_iss);
				$finish;
			end
			pc_iss = next_pc;

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
