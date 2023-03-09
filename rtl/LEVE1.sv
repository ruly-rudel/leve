
`include "defs.vh"
`include "AXI.sv"
`include "PC.sv"
`include "HS.sv"

`include "TRACE.sv"

module LEVE1
(
	input			CLK,
	input			RSTn,
	AXIR.init		RII	// read initiator: instruction
);
	AXIR			axiri;
	PC			pc;
	HS #(.WIDTH(32))	inst;

	logic [1:0]		op;
	logic [6:0]		opcode;
	logic [4:0]		rd;
	logic [2:0]		funct3;
	logic [4:0]		rs1;
	logic [4:0]		rs2;
	logic [4:0]		rs3;
	logic [6:0]		funct7;
	logic [4:0]		funct5;
	logic [1:0]		funct2;
	logic			aq;
	logic			rl;
	logic [2:0]		rm;
	logic [`XLEN-1:0]	imm_i;
	logic [`XLEN-1:0]	imm_s;
	logic [`XLEN-1:0]	imm_b;
	logic [`XLEN-1:0]	imm_u;
	logic [`XLEN-1:0]	imm_j;

	logic [`XLEN-1:0]	uimm_w;

	logic [12-1:0]		csr;
	logic [6-1:0]		shamt;


	logic			jal;
	logic [2:0]		rs2ext;

	logic			rs_d_valid;
	logic [`XLEN-1:0]	rs1_d;
	logic [`XLEN-1:0]	rs2_d;

	logic			alu_out_valid;
	logic [`XLEN-1:0]	alu_out;

	TRACE			trace = new;

	// PC + Branch prediction
	LEVE_BRP		LEVE_BRP
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.PC		(pc),

		.IMM_J		(imm_j),
		.JAL		(jal),
		.PC_BR		(1'b0),
		.ALU_OUT	({64{1'b0}}),
		.PCp4		()

	);

	// instruction burst buffer
	LEVE_IBB		LEVE_IBB
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.RII		(axiri),
		.PC		(pc),
		.INST		(inst)
	);

	always_comb begin
		RII.ARVALID	= axiri.ARVALID;
		axiri.ARREADY	= RII.ARREADY;
		RII.ARADDR	= axiri.ARADDR;
		RII.ARBURST	= axiri.ARBURST;
		RII.ARLEN	= axiri.ARLEN;

		axiri.RVALID	= RII.RVALID;
		RII.RREADY	= axiri.RREADY;
		axiri.RDATA	= RII.RDATA;
		axiri.RLAST	= RII.RLAST;
	end

	// decode
	always_comb begin
		op		= inst.PAYLOAD[1:0];
		opcode		= inst.PAYLOAD[6:0];
		rd		= inst.PAYLOAD[11:7];
		funct3		= inst.PAYLOAD[14:12];
		rs1		= inst.PAYLOAD[19:15];
		rs2		= inst.PAYLOAD[24:20];
		rs3		= inst.PAYLOAD[31:27];
		funct7		= inst.PAYLOAD[31:25];
		funct5		= inst.PAYLOAD[31:27];
		funct2		= inst.PAYLOAD[26:25];
		aq		= inst.PAYLOAD[26];
		rl		= inst.PAYLOAD[25];
		rm		= inst.PAYLOAD[14:12];

		imm_i		= {{20+32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31:20]};
		imm_s		= {{20+32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31:25], inst.PAYLOAD[11:7]};
		imm_b		= {{19+32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31], inst.PAYLOAD[7], inst.PAYLOAD[30:25], inst.PAYLOAD[11:8], 1'b0};
		imm_u		= {{   32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31:12], 12'h000};
		imm_j		= {{11+32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31], inst.PAYLOAD[19:12], inst.PAYLOAD[20], inst.PAYLOAD[30:21], 1'b0};

		uimm_w		= {{`XLEN-5{1'b0}}, rs1};

		csr		= inst.PAYLOAD[31:20];
		shamt		= imm_i[5:0];

		jal		= opcode == 7'b11_011_11 ? 1'b1 : 1'b0;	// JAL
		rs2ext		= opcode == 7'b00_100_11 ? `IRF_IMM_I :	// OP-IMM
							   `IRF_REG;
	end

	// register fils
	LEVE_IRF		LEVE_IRF
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RS1_VALID	(inst.VALID),
		.RS1		(rs1),
		.RS2_VALID	(inst.VALID),
		.RS2		(rs2),
		.RS2EXT		(rs2ext),

		.IMM_I		(imm_i),

		.RS_D_VALID	(rs_d_valid),
		.RS1_D		(rs1_d),
		.RS2_D		(rs2_d),

		.RD_WE		(alu_out_valid),
		.RD		(rd),
		.ALU_OUT	(alu_out)
	);


	// ALU
	LEVE_ALU		LEVE_ALU
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RS_D_VALID	(rs_d_valid),
		.RS1_D		(rs1_d),
		.RS2_D		(rs2_d),

		.ALU_OUT_VALID	(alu_out_valid),
		.ALU_OUT	(alu_out)
	);


	always_comb begin
		inst.READY	= 1'b1;
	end


	// TRACE output
	always @(posedge CLK) begin
		if(inst.est()) begin
			trace.print(pc.PC, inst.PAYLOAD);
		end
	end

	always_comb begin
		inst.READY	= 1'b1;
	end

endmodule
