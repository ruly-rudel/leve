
`include "defs.vh"

module LEVE1
(
	input			CLK,
	input			RSTn,

	output			PC_EN,	// for debug
	output [`XLEN-1:0]	PC,

	AXIR.init		RII	// read initiator: instruction
);
	logic			if_valid;
	logic			if_ready;
	logic [`XLEN-1:0]	if_pc;
	logic [31:0]		if_instr;

	logic			pc_we;
	logic [`XLEN-1:0]	next_pc;
	logic			flash;
	LEVE1_IF	LEVE1_IF
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.IPC_WE		(pc_we),
		.INEXT_PC	(next_pc),

		.IF_VALID	(if_valid),
		.IF_READY	(if_ready),
		.IF_PC		(if_pc),
		.IF_INSTR	(if_instr),

		.RII		(RII)
	);

	logic			id_valid;
	logic [`XLEN-1:0]	id_pc;
	logic [31:0]		id_instr;
	logic [`XLEN-1:0]	id_rs1;
	logic [`XLEN-1:0]	id_rs2;
	CSRIF			id_csr();

	logic			ex_valid;
	logic [`XLEN-1:0]	ex_pc;
	logic [31:0]		ex_instr;
	logic [`XLEN-1:0]	fwd_rd;
	logic [`XLEN-1:0]	fwd_csrd;
	logic 			ex_we;
	logic [`XLEN-1:0]	ex_rd;
	logic 			wb_valid;
	logic [`XLEN-1:0]	wb_pc;
	logic [`XLEN-1:0]	ex_csrd;
	LEVE1_ID	LEVE1_ID
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.IF_VALID	(if_valid),
		.IF_READY	(if_ready),
		.IF_PC		(if_pc),
		.IF_INSTR	(if_instr),

		.IFLASH		(flash),

		.ID_VALID	(id_valid),
		.ID_PC		(id_pc),
		.ID_INSTR	(id_instr),
		.ID_CSR		(id_csr),
		.ID_RS1		(id_rs1),
		.ID_RS2		(id_rs2),

		.FWD_RD		(fwd_rd),
		.FWD_CSRD	(fwd_csrd),

		.EX_VALID	(ex_valid),
		.EX_PC		(ex_pc),
		.EX_INSTR	(ex_instr),
		.EX_WE		(ex_we),
		.EX_RD		(ex_rd),
		.EX_CSRD	(ex_csrd),

		.WB_VALID	(wb_valid),
		.WB_PC		(wb_pc)
	);

	LEVE1_EX	LEVE1_EX
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.IF_VALID	(if_valid),
		.IF_READY	(if_ready),
		.IF_PC		(if_pc),

		.ID_VALID	(id_valid),
		.ID_PC		(id_pc),
		.ID_INSTR	(id_instr),
		.ID_RS1		(id_rs1),
		.ID_RS2		(id_rs2),
		.ID_CSR		(id_csr),

		.FWD_RD		(fwd_rd),
		.FWD_CSRD	(fwd_csrd),

		.EX_VALID	(ex_valid),
		.EX_PC		(ex_pc),
		.EX_INSTR	(ex_instr),

		.EX_PC_WE	(pc_we),
		.EX_NEXT_PC	(next_pc),
		.OFLASH		(flash),

		.EX_WE		(ex_we),
		.EX_RD		(ex_rd),
		.EX_CSRD	(ex_csrd)
	);

	assign PC_EN	= wb_valid;
	assign PC	= wb_pc;

endmodule
