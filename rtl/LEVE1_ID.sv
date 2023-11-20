
`include "defs.vh"

module LEVE1_ID
(
	input				CLK,
	input		 		RSTn,

	input				IVALID,
	output				IREADY,
	input [`XLEN-1:0]		IPC,
	input [31:0]			IINSTR,

	input				IFLASH,

	output logic			OVALID,
	output logic [`XLEN-1:0]	OPC,
	output logic [31:0]		OINSTR,
	output logic [`XLEN-1:0]	RS1,
	output logic [`XLEN-1:0]	RS2,
	output logic [`XLEN-1:0]	RCSR,

	//
	input [`XLEN-1:0]		FWD_RD,
	input [`XLEN-1:0]		FWD_CSRD,

	input				WB_IVALID,
	input [`XLEN-1:0]		WB_IPC,
	input 				WB_IWE,
	input [31:0]			WB_IINSTR,
	input [`XLEN-1:0]		WB_IRD,
	input [`XLEN-1:0]		WB_ICSRD,

	output logic			WB_OVALID,
	output logic [`XLEN-1:0]	WB_OPC

);
	INST	inst_id(.INSTR(IINSTR));
	INST	inst_ex(.INSTR(OINSTR));
	INST	inst_wb(.INSTR(WB_IINSTR));

	// stage 2
	logic			ex_valid;

	logic [1:0]		csr_wcmd;
	logic [12-1:0]		csr_ra;
	logic [12-1:0]		csr_wa;

	always_comb begin
		ex_valid	= OVALID;
		csr_ra		= inst_id.mret() ? 12'h300 : inst_id.csr();
		csr_wa		= inst_wb.mret() ? 12'h300 : inst_wb.csr();
		csr_wcmd	= inst_wb.mret() ? `CSR_WRITE :
				  WB_IVALID && inst_wb.opcode() == 7'b11_100_11 ? inst_wb.funct3_1_0() : `CSR_NONE;
	end

	assign IREADY = 1'b1;

	LEVE1_CSR	LEVE1_CSR
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.CSR_RA		(csr_ra),
		.CSR_RD		(RCSR),

		.CSR_WCMD	(csr_wcmd),
		.CSR_WA		(csr_wa),
		.CSR_WD		(WB_ICSRD),

		.RETIRE		(1'b1)
	);

	logic [`XLEN-1:0]	reg_file[1:`NUM_REG-1];
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			OVALID	<= 1'b0;
		end else begin
			OVALID	<= IVALID && IREADY && !IFLASH;
			OPC	<= IPC;
			OINSTR	<= IINSTR;
			RS1	<= inst_id.rs1() == 5'h00 ? '0 :
				   ex_valid && inst_id.rs1() == inst_ex.rd0() ? FWD_RD :
				   WB_IWE   && inst_id.rs1() == inst_wb.rd0() ? WB_IRD :
				   reg_file[inst_id.rs1()];
			RS2	<= inst_id.rs2() == 5'h00 ? '0 :
				   ex_valid && inst_id.rs2() == inst_ex.rd0() ? FWD_RD :
				   WB_IWE   && inst_id.rs2() == inst_wb.rd0() ? WB_IRD :
				   reg_file[inst_id.rs2()];
		end
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(RSTn && WB_IWE) begin
			if(inst_wb.rd0() != 5'h00) begin
				reg_file[inst_wb.rd0()] <= WB_IRD;
			end
		end
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			WB_OVALID	<= 1'b0;
		end else begin
			WB_OVALID	<= WB_IVALID;
			WB_OPC		<= WB_IPC;
		end
	end

endmodule
