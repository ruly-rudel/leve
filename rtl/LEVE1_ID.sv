
`include "defs.vh"

module LEVE1_ID
(
	input				CLK,
	input		 		RSTn,

	input				IF_VALID,
	output				IF_READY,
	input [`XLEN-1:0]		IF_PC,
	input [31:0]			IF_INSTR,

	input				IFLASH,

	output logic			ID_VALID,
	output logic [`XLEN-1:0]	ID_PC,
	output logic [31:0]		ID_INSTR,
	output logic [`XLEN-1:0]	ID_RS1,
	output logic [`XLEN-1:0]	ID_RS2,
	CSRIF.init			ID_CSR,

	//
	input [`XLEN-1:0]		FWD_RD,
	input [`XLEN-1:0]		FWD_CSRD,
	// todo: add CSRIF for forwarding MSTATUS etc...

	input				EX_VALID,
	input [`XLEN-1:0]		EX_PC,
	input 				EX_WE,
	input [31:0]			EX_INSTR,
	input [`XLEN-1:0]		EX_RD,
	input [`XLEN-1:0]		EX_CSRD,

	output logic			WB_VALID,
	output logic [`XLEN-1:0]	WB_PC

);
	INST	inst_id(.INSTR(IF_INSTR));
	INST	inst_ex(.INSTR(ID_INSTR));
	INST	inst_wb(.INSTR(EX_INSTR));

	// stage 2
	logic			ex_valid;

	logic [1:0]		csr_wcmd;
	logic [12-1:0]		csr_ra;
	logic [12-1:0]		csr_wa;

	always_comb begin
		ex_valid	= ID_VALID;
		csr_ra		= inst_id.mret() ? 12'h300 : inst_id.csr();
		csr_wa		= inst_wb.mret() ? 12'h300 : inst_wb.csr();
		csr_wcmd	= inst_wb.mret() ? `CSR_WRITE :
				  EX_VALID && inst_wb.opcode() == 7'b11_100_11 ? inst_wb.funct3_1_0() : `CSR_NONE;
	end

	assign IF_READY = 1'b1;

	LEVE1_CSR	LEVE1_CSR
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.CSR_RA		(csr_ra),
		.OCSR		(ID_CSR),

		.CSR_WCMD	(csr_wcmd),
		.CSR_WA		(csr_wa),
		.CSR_WD		(EX_CSRD),

		.RETIRE		(1'b1)
	);

	logic [`XLEN-1:0]	reg_file[1:`NUM_REG-1];
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			ID_VALID	<= 1'b0;
		end else begin
			ID_VALID	<= IF_VALID && IF_READY && !IFLASH;
			ID_PC		<= IF_PC;
			ID_INSTR	<= IF_INSTR;
			ID_RS1	<= inst_id.rs1() == 5'h00 ? '0 :
				   ex_valid && inst_id.rs1() == inst_ex.rd0() ? FWD_RD :
				   EX_WE   && inst_id.rs1() == inst_wb.rd0() ? EX_RD :
				   reg_file[inst_id.rs1()];
			ID_RS2	<= inst_id.rs2() == 5'h00 ? '0 :
				   ex_valid && inst_id.rs2() == inst_ex.rd0() ? FWD_RD :
				   EX_WE   && inst_id.rs2() == inst_wb.rd0() ? EX_RD :
				   reg_file[inst_id.rs2()];
		end
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(RSTn && EX_WE) begin
			if(inst_wb.rd0() != 5'h00) begin
				reg_file[inst_wb.rd0()] <= EX_RD;
			end
		end
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			WB_VALID	<= 1'b0;
		end else begin
			WB_VALID	<= EX_VALID;
			WB_PC		<= EX_PC;
		end
	end

`ifdef DEBUG
	wire [4:0]	inst_wb_rs1, inst_wb_rs2, inst_wb_rd0;
	assign inst_wb_rs1 = inst_wb.rs1();
	assign inst_wb_rs2 = inst_wb.rs2();
	assign inst_wb_rd0 = inst_wb.rd0();
`endif

endmodule
