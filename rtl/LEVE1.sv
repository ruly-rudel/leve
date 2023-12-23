
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
	logic 			wb_we;
	logic [`XLEN-1:0]	wb_rd;
	logic 			wb_valid;
	logic [`XLEN-1:0]	wb_pc;
	logic [`XLEN-1:0]	wb_csrd;
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

		.WB_IVALID	(ex_valid),
		.WB_IPC		(ex_pc),
		.WB_IINSTR	(ex_instr),
		.WB_IWE		(wb_we),
		.WB_IRD		(wb_rd),
		.WB_ICSRD	(wb_csrd),

		.WB_OVALID	(wb_valid),
		.WB_OPC		(wb_pc)
	);

	LEVE1_EX	LEVE1_EX
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.IF_VALID	(if_valid),
		.IF_READY	(if_ready),
		.IF_PC		(if_pc),

		.IVALID		(id_valid),
		.IPC		(id_pc),
		.IINSTR		(id_instr),
		.IRS1		(id_rs1),
		.IRS2		(id_rs2),
		.ICSR		(id_csr),

		.FWD_RD		(fwd_rd),
		.FWD_CSRD	(fwd_csrd),

		.OVALID		(ex_valid),
		.OPC		(ex_pc),
		.OINSTR		(ex_instr),

		.OPC_WE		(pc_we),
		.ONEXT_PC	(next_pc),
		.OFLASH		(flash),

		.WB_WE		(wb_we),
		.WB_RD		(wb_rd),
		.WB_CSRD	(wb_csrd)
	);

	assign PC_EN	= wb_valid;
	assign PC	= wb_pc;

endmodule
