
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
	// stage 2
	logic [4:0]		rs1;
	logic [4:0]		rs2;
	logic [4:0]		rs3;
	logic [`XLEN-1:0]	imm_i;
	logic [`XLEN-1:0]	imm_s;
	logic [`XLEN-1:0]	imm_b;
	logic [`XLEN-1:0]	imm_u;
	logic [`XLEN-1:0]	uimm_w;
	logic			mret;
	logic [6:0]		opcode;
	logic [2:0]		funct3;
	logic [6:0]		funct7;

	logic			ex_valid;
	logic [4:0]		ex_rd0;

	logic [1:0]		csr_wcmd;
	logic [12-1:0]		csr_ra;
	logic [`XLEN-1:0]	csr_rd;
	logic [12-1:0]		csr_wa;
	logic [6:0]		w_opcode;
	logic [2:0]		w_funct3;
	logic [6:0]		w_funct7;
	logic [4:0]		w_rs2;
	logic [4:0]		w_rd0;
	logic			w_mret;

	always_comb begin

		opcode	= IINSTR[6:0];
		funct3	= IINSTR[14:12];
		funct7	= IINSTR[31:25];
		rs1     = IINSTR[19:15];
		rs2     = IINSTR[24:20];
		imm_i	= {{20+32{IINSTR[31]}}, IINSTR[31:20]};
		imm_s	= {{20+32{IINSTR[31]}}, IINSTR[31:25], IINSTR[11:7]};
		imm_b	= {{19+32{IINSTR[31]}}, IINSTR[31], IINSTR[7], IINSTR[30:25], IINSTR[11:8], 1'b0};
		imm_u	= {{   32{IINSTR[31]}}, IINSTR[31:12], 12'h000};
		uimm_w	= {{`XLEN-5{1'b0}}, rs1};

		mret	= opcode == 7'b11_100_11 && funct3 == 3'b000 && funct7 == 7'b0011000 && rs2 == 5'b00010;
		csr_ra	= mret ? 12'h300 : IINSTR[31:20];

		ex_valid	= OVALID;
		ex_rd0		= OINSTR[11:7];

		w_opcode	= WB_IINSTR[6:0];
		w_funct3	= WB_IINSTR[14:12];
		w_funct7	= WB_IINSTR[31:25];
		w_rd0		= WB_IINSTR[11:7];
		w_rs2		= WB_IINSTR[24:20];
		w_mret		= w_opcode == 7'b11_100_11 && w_funct3 == 3'b000 && w_funct7 == 7'b0011000 && w_rs2 == 5'b00010;
		csr_wcmd	= w_mret ? `CSR_WRITE :
				  WB_IVALID && w_opcode == 7'b11_100_11 ? w_funct3[1:0] : `CSR_NONE;
		csr_wa		= w_mret ? 12'h300 : WB_IINSTR[31:20];

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
			RS1	<= rs1 == 5'h00 ? '0 :
				   ex_valid && rs1 == ex_rd0 ? FWD_RD :
				   WB_IWE && rs1 == w_rd0 ? WB_IRD :
				   reg_file[rs1];
			RS2	<= rs2 == 5'h00 ? '0 :
				   ex_valid && rs2 == ex_rd0 ? FWD_RD :
				   WB_IWE && rs2 == w_rd0 ? WB_IRD :
				   reg_file[rs2];
		end
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(RSTn && WB_IWE) begin
			if(w_rd0 != 5'h00) begin
				reg_file[w_rd0] <= WB_IRD;
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
