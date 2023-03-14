
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

	logic [6:0]		opcode_s1;
	logic [2:0]		funct3_s1;
	logic [`XLEN-1:0]	imm_j_s1;
	logic			jal_s1;
	logic [2:0]		rs1ext_s1;
	logic [2:0]		rs2ext_s1;
	logic [pc.WIDTH-1:0]	pcp4_s1;

	logic			valid_s2;
	logic [inst.WIDTH-1:0]	inst_s2;
	logic [pc.WIDTH-1:0]	pc_s2;
	logic [pc.WIDTH-1:0]	pcp4_s2;
	logic [2:0]		rs1ext_s2;
	logic [2:0]		rs2ext_s2;

	logic [4:0]		rs1_s2;
	logic [4:0]		rs2_s2;
	logic [`XLEN-1:0]	imm_i_s2;
	logic [`XLEN-1:0]	imm_s_s2;
	logic [`XLEN-1:0]	imm_b_s2;
	logic [`XLEN-1:0]	imm_u_s2;
	logic [`XLEN-1:0]	uimm_w_s2;
	logic [6:0]		opcode_s2;
	logic [2:0]		funct3_s2;
	logic [1:0]		csr_cmd_s2;

	logic			valid_s3;
	logic [inst.WIDTH-1:0]	inst_s3;
	logic [`XLEN-1:0]	rs1_d_s3;
	logic [`XLEN-1:0]	rs2_d_s3;
	logic [pc.WIDTH-1:0]	pc_s3;
	logic [pc.WIDTH-1:0]	pcp4_s3;

	logic [1:0]		csr_cmd_s3;
	logic [11:0]		csr_s3;

	logic			valid_s4;
	logic			pc_br_s4;
	logic [`XLEN-1:0]	alu_out_s4;
	logic			rd_we_s4;
	logic [4:0]		rd_s4;
	logic [`XLEN-1:0]	rd_d_s4;

	logic			csr_we_s4;
	logic [`MXLEN-1:0]	csr_d_s4;

	TRACE			trace = new;

	//////////////////////////////////////////////////////////////////////////////
	// STAGE 1: Instruction Fetch & Decode

	// PC + Branch prediction
	LEVE_BRP		LEVE_BRP
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.PC		(pc),

		.IMM_J		(imm_j_s1),
		.JAL		(jal_s1),
		.PC_BR		(pc_br_s4),
		.ALU_OUT	(alu_out_s4),
		.PCp4		(pcp4_s1)

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

	always_comb begin
		inst.READY	= 1'b1;
	end

	// decode
	always_comb begin
		opcode_s1	= inst.PAYLOAD[6:0];
		funct3_s1	= inst.PAYLOAD[14:12];
		imm_j_s1	= {{11+32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31], inst.PAYLOAD[19:12], inst.PAYLOAD[20], inst.PAYLOAD[30:21], 1'b0};

		jal_s1		= opcode_s1 == 7'b11_011_11 ? 1'b1 : 1'b0;	// JAL
		rs1ext_s1	= opcode_s1 == 7'b11_100_11 && funct3_s1 != 3'b000 && funct3_s1 != 3'b100 ? `IRF_IMM_W :
				  `IRF_REG;
		rs2ext_s1	= opcode_s1 == 7'b00_100_11 ? `IRF_IMM_I :	// OP-IMM
							      `IRF_REG;
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			valid_s2	<= 1'b0;
		end else begin
			valid_s2	<= `TPD inst.VALID;
			inst_s2		<= `TPD inst.PAYLOAD;
			pc_s2		<= `TPD pc.PC;
			pcp4_s2		<= `TPD pcp4_s1;
			rs1ext_s2	<= `TPD rs1ext_s1;
			rs2ext_s2	<= `TPD rs2ext_s1;
		end
	end

	//////////////////////////////////////////////////////////////////////////////
	// STAGE 2: Register File Read
	// STAGE 4-n: Register Writeback

	always_comb begin
		opcode_s2	= inst_s2[6:0];
		funct3_s2	= inst_s2[14:12];
		rs1_s2		= inst_s2[19:15];
		rs2_s2		= inst_s2[24:20];
		imm_i_s2	= {{20+32{inst_s2[31]}}, inst_s2[31:20]};
		imm_s_s2	= {{20+32{inst_s2[31]}}, inst_s2[31:25], inst_s2[11:7]};
		imm_b_s2	= {{19+32{inst_s2[31]}}, inst_s2[31], inst_s2[7], inst_s2[30:25], inst_s2[11:8], 1'b0};
		imm_u_s2	= {{   32{inst_s2[31]}}, inst_s2[31:12], 12'h000};
		uimm_w_s2	= {{`XLEN-5{1'b0}}, rs1_s2};

		csr_cmd_s2	= opcode_s2 == 7'b11_100_11 ? funct3_s2[1:0] : `CSR_NONE;
	end

	// register fils
	LEVE_IRF		LEVE_IRF
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RS1_VALID	(valid_s2),
		.RS1		(rs1_s2),
		.RS1EXT		(rs1ext_s2),
		.RS2_VALID	(valid_s2),
		.RS2		(rs2_s2),
		.RS2EXT		(rs2ext_s2),

		.IMM_I		(imm_i_s2),
		.IMM_W		(uimm_w_s2),

		.RS1_D		(rs1_d_s3),
		.RS2_D		(rs2_d_s3),

		.RD_WE		(rd_we_s4),
		.RD		(rd_s4),
		.RD_D		(rd_d_s4),

		.CSR_WE		(csr_we_s4),
		.CSR_D		(csr_d_s4)
	);

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			valid_s3	<= 1'b0;
		end else begin
			valid_s3	<= `TPD valid_s2;
			pc_s3		<= `TPD pc_s2;
			pcp4_s3		<= `TPD pcp4_s2;
			inst_s3		<= `TPD inst_s2;
			csr_cmd_s3	<= `TPD csr_cmd_s2;
		end
	end

	//////////////////////////////////////////////////////////////////////////////
	// STAGE 3: Execute

	// ALU
	LEVE_ALU		LEVE_ALU
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RS_D_VALID	(valid_s3),
		.RS1_D		(rs1_d_s3),
		.RS2_D		(rs2_d_s3),

		.RD_WE		(rd_we_s4),
		.RD_D		(rd_d_s4),

		.PC_BR		(pc_br_s4),
		.ALU_OUT	(alu_out_s4)
	);

	// CSR regs
	LEVE_CSR		LEVE_CSR
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.CMD		(csr_cmd_s3),
		.CSR		(csr_s3),
		.CSR_WD		(rs1_d_s3),
		.CSR_RD		(csr_d_s4),

		.RETIRE		(rd_we_s4 | pc_br_s4)
	);

	always_comb begin
		csr_s3		= inst_s3[31:20];
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			valid_s4	<= 1'b0;
		end else begin
			valid_s4	<= `TPD valid_s3;
			rd_s4		<= `TPD inst_s3[11:7];
			csr_we_s4	<= `TPD |csr_cmd_s3;
		end
	end


	// TRACE output
	always @(posedge CLK) begin
		if(inst.est()) begin
			trace.print(pc.PC, inst.PAYLOAD);
		end
	end

endmodule



		/*
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
		*/

	/*
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
	*/
