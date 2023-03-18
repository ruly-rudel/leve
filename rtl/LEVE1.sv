
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

	logic [6:0]		opcode_s2;
	logic [2:0]		funct3_s2;
	logic [`XLEN-1:0]	imm_j_s2;
	logic			jal_s2;
	logic [2:0]		rs2ext_s2;
	logic [2:0]		rs3ext_s2;
	logic [pc.WIDTH-1:0]	pcp4_s2;

	logic			valid_s3;
	logic [inst.WIDTH-1:0]	inst_s3;
	logic [pc.WIDTH-1:0]	pc_s3;
	logic [pc.WIDTH-1:0]	pcp4_s3;
	logic [2:0]		rs2ext_s3;
	logic [2:0]		rs3ext_s3;

	logic [4:0]		rs2_s3;
	logic [4:0]		rs3_s3;
	logic [`XLEN-1:0]	imm_i_s3;
	logic [`XLEN-1:0]	imm_s_s3;
	logic [`XLEN-1:0]	imm_b_s3;
	logic [`XLEN-1:0]	imm_u_s3;
	logic [`XLEN-1:0]	uimm_w_s3;
	logic [6:0]		opcode_s3;
	logic [2:0]		funct3_s3;
	logic [1:0]		csr_cmd_s3;

	logic			valid_s4;
	logic [inst.WIDTH-1:0]	inst_s4;
	logic [`XLEN-1:0]	rs2_d_s4;
	logic [`XLEN-1:0]	rs3_d_s4;
	logic [pc.WIDTH-1:0]	pc_s4;
	logic [pc.WIDTH-1:0]	pcp4_s4;

	logic [1:0]		csr_cmd_s4;
	logic [11:0]		csr_s4;

	logic			valid_s5;
	logic			pc_br_s5;
	logic [`XLEN-1:0]	alu_out_s5;
	logic			rd_we_s5;
	logic [4:0]		rd_s5;
	logic [`XLEN-1:0]	rd_d_s5;

	logic			csr_we_s5;
	logic [`MXLEN-1:0]	csr_d_s5;

	TRACE			trace = new;

	//////////////////////////////////////////////////////////////////////////////
	// STAGE 1: Instruction Fetch

	// PC + Branch prediction
	LEVE_BRP		LEVE_BRP
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.PC		(pc),

		.IMM_J		(imm_j_s2),
		.JAL		(jal_s2),
		.PC_BR		(pc_br_s5),
		.ALU_OUT	(alu_out_s5),
		.PCp4		(pcp4_s2)

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
		opcode_s2	= inst.PAYLOAD[6:0];
		funct3_s2	= inst.PAYLOAD[14:12];
		imm_j_s2	= {{11+32{inst.PAYLOAD[31]}}, inst.PAYLOAD[31], inst.PAYLOAD[19:12], inst.PAYLOAD[20], inst.PAYLOAD[30:21], 1'b0};

		jal_s2		= opcode_s2 == 7'b11_011_11 ? 1'b1 : 1'b0;	// JAL
		rs2ext_s2	= opcode_s2 == 7'b11_100_11 && funct3_s2 != 3'b000 && funct3_s2 != 3'b100 ? `IRF_IMM_W :
				  `IRF_REG;
		rs3ext_s2	= opcode_s2 == 7'b00_100_11 ? `IRF_IMM_I :	// OP-IMM
							      `IRF_REG;
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			valid_s3	<= 1'b0;
		end else begin
			valid_s3	<= `TPD inst.VALID;
			inst_s3		<= `TPD inst.PAYLOAD;
			pc_s3		<= `TPD pc.PC;
			pcp4_s3		<= `TPD pcp4_s2;
			rs2ext_s3	<= `TPD rs2ext_s2;
			rs3ext_s3	<= `TPD rs3ext_s2;
		end
	end

	//////////////////////////////////////////////////////////////////////////////
	// STAGE 3: Register File Read
	// STAGE 6-n: Register Writeback

	always_comb begin
		opcode_s3	= inst_s3[6:0];
		funct3_s3	= inst_s3[14:12];
		rs2_s3		= inst_s3[19:15];
		rs3_s3		= inst_s3[24:20];
		imm_i_s3	= {{20+32{inst_s3[31]}}, inst_s3[31:20]};
		imm_s_s3	= {{20+32{inst_s3[31]}}, inst_s3[31:25], inst_s3[11:7]};
		imm_b_s3	= {{19+32{inst_s3[31]}}, inst_s3[31], inst_s3[7], inst_s3[30:25], inst_s3[11:8], 1'b0};
		imm_u_s3	= {{   32{inst_s3[31]}}, inst_s3[31:12], 12'h000};
		uimm_w_s3	= {{`XLEN-5{1'b0}}, rs2_s3};

		csr_cmd_s3	= opcode_s3 == 7'b11_100_11 ? funct3_s3[1:0] : `CSR_NONE;
	end

	// register fils
	LEVE_IRF		LEVE_IRF
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RS1_VALID	(valid_s3),
		.RS1		(rs2_s3),
		.RS1EXT		(rs2ext_s3),
		.RS2_VALID	(valid_s3),
		.RS2		(rs3_s3),
		.RS2EXT		(rs3ext_s3),

		.IMM_I		(imm_i_s3),
		.IMM_W		(uimm_w_s3),

		.RS1_D		(rs2_d_s4),
		.RS2_D		(rs3_d_s4),

		.RD_WE		(rd_we_s5),
		.RD		(rd_s5),
		.RD_D		(rd_d_s5),

		.CSR_WE		(csr_we_s5),
		.CSR_D		(csr_d_s5)
	);

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			valid_s4	<= 1'b0;
		end else begin
			valid_s4	<= `TPD valid_s3;
			pc_s4		<= `TPD pc_s3;
			pcp4_s4		<= `TPD pcp4_s3;
			inst_s4		<= `TPD inst_s3;
			csr_cmd_s4	<= `TPD csr_cmd_s3;
		end
	end

	//////////////////////////////////////////////////////////////////////////////
	// STAGE 4: Execute

	// ALU
	LEVE_ALU		LEVE_ALU
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.RS_D_VALID	(valid_s4),
		.RS1_D		(rs2_d_s4),
		.RS2_D		(rs3_d_s4),

		.RD_WE		(rd_we_s5),
		.RD_D		(rd_d_s5),

		.PC_BR		(pc_br_s5),
		.ALU_OUT	(alu_out_s5)
	);

	// CSR regs
	LEVE_CSR		LEVE_CSR
	(
		.CLK		(CLK),
		.RSTn		(RSTn),

		.CMD		(csr_cmd_s4),
		.CSR		(csr_s4),
		.CSR_WD		(rs2_d_s4),
		.CSR_RD		(csr_d_s5),

		.RETIRE		(rd_we_s5 | pc_br_s5)
	);

	always_comb begin
		csr_s4		= inst_s4[31:20];
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			valid_s5	<= 1'b0;
		end else begin
			valid_s5	<= `TPD valid_s4;
			rd_s5		<= `TPD inst_s4[11:7];
			csr_we_s5	<= `TPD |csr_cmd_s4;
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
		rs2		= inst.PAYLOAD[19:15];
		rs3		= inst.PAYLOAD[24:20];
		rs4		= inst.PAYLOAD[31:27];
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

		uimm_w		= {{`XLEN-5{1'b0}}, rs2};

		csr		= inst.PAYLOAD[31:20];
		shamt		= imm_i[5:0];
		*/

	/*
	logic [1:0]		op;
	logic [6:0]		opcode;
	logic [4:0]		rd;
	logic [2:0]		funct3;
	logic [4:0]		rs2;
	logic [4:0]		rs3;
	logic [4:0]		rs4;
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
