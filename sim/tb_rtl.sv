
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

	AXIR	axiri();		// AXI read: instruction
	AXIR	axird();		// AXI read: data
	AXIW	axiwd();		// AXI write: data

	LEVE1	LEVE1
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.PC_EN		(pc_en),
		.PC		(pc),
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

	always_ff @(negedge CLK or negedge RSTn)
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

			for(integer i = 0; i < `NUM_REG; i++) begin
				if(LEVE1.LEVE1_ID.reg_file[i] != iss.read_reg_file(i)) begin
					$display ("[TESTBENCH] [FAIL] REG %d missmatch: %h, expect %h",
						i,
						LEVE1.LEVE1_ID.reg_file[i],
						iss.read_reg_file(i)
					);
					$finish;
				end
			end

			for(integer i = 0; i < 12'hc00; i++) begin
				if(LEVE1.LEVE1_ID.LEVE1_CSR.read_csr(i[11:0]) != iss.csr_c.read(i[11:0])) begin
					$display ("[TESTBENCH] [FAIL] CSR %h missmatch: %h, expect %h",
						i[11:0],
						LEVE1.LEVE1_ID.LEVE1_CSR.read_csr(i[11:0]),
						iss.csr_c.read(i[11:0])
					);
					$finish;
				end
			end
			// exclude counter
			for(integer i = 'hf00; i < 12'hfff; i++) begin
				if(LEVE1.LEVE1_ID.LEVE1_CSR.read_csr(i[11:0]) != iss.csr_c.read(i[11:0])) begin
					$display ("[TESTBENCH] [FAIL] CSR %h missmatch: %h, expect %h",
						i[11:0],
						LEVE1.LEVE1_ID.LEVE1_CSR.read_csr(i[11:0]),
						iss.csr_c.read(i[11:0])
					);
					$finish;
				end
			end

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
