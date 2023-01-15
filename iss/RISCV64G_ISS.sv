
`include "defs.vh"

module RISCV64G_ISS (
	input			CLK,
	input			RSTn,

	output reg		tohost_we,
	output [32-1:0]		tohost
);
	//reg [31:0]	mem[0:1024*1024*16-1];
	reg  [32-1:0]	mem[0:1024*1024-1];

	// PC
	reg  [`XLEN-1:0]	pc;
	logic [`XLEN-1:0]	pc_nxt;

	wire [32-1:0]		inst;
	wire [6:0]		opcode;
	wire [4:0]		rd0;
	wire [2:0]		funct3;
	wire [4:0]		rs1;
	wire [4:0]		rs2;
	wire [6:0]		funct7;
	wire [32-1:0]		imm_i;
	wire [32-1:0]		imm_s;
	wire [32-1:0]		imm_b;
	wire [32-1:0]		imm_u;
	wire [32-1:0]		imm_j;

	wire [`XLEN-1:0]	imm_iw;
	wire [`XLEN-1:0]	imm_sw;
	wire [`XLEN-1:0]	imm_bw;
	wire [`XLEN-1:0]	imm_uw;
	wire [`XLEN-1:0]	imm_jw;

	wire [`XLEN-1:0]	uimm_w;
	
	wire [12-1:0]		csr;
	wire [6-1:0]		shamt;

	wire [`XLEN-1:0]	rs1_d;
	wire [`XLEN-1:0]	rs2_d;

	logic [`XLEN-1:0]	tmp;
	logic [32-1:0]		tmp32;

	assign tohost  = mem[tmp[22-1:2]];

	// registers
	reg [`XLEN-1:0]		reg_file[0:`NUM_REG-1];

	// 1. instruction fetch
	assign inst   = mem[pc[22-1:2]];
	
	assign opcode = inst[6:0];
	assign rd0    = inst[11:7];
	assign funct3 = inst[14:12];
	assign rs1    = inst[19:15];
	assign rs2    = inst[24:20];
	assign funct7 = inst[31:25];
	
	assign imm_i  = {{20{inst[31]}}, inst[31:20]};
	assign imm_s  = {{20{inst[31]}}, inst[31:25], inst[11:7]};
	assign imm_b  = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
	assign imm_u  = {inst[31:12], 12'h000};
	assign imm_j  = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

	assign imm_iw = {{32{imm_i[31]}}, imm_i};
	assign imm_sw = {{32{imm_s[31]}}, imm_s};
	assign imm_bw = {{32{imm_b[31]}}, imm_b};
	assign imm_uw = {{32{imm_u[31]}}, imm_u};
	assign imm_jw = {{32{imm_j[31]}}, imm_j};

	assign uimm_w = {{`XLEN-5{1'b0}}, rs1};

	assign csr    = inst[31:20];
	assign shamt  = imm_i[5:0];

	// 2. register fetch
	assign	rs1_d = reg_file[rs1];
	assign	rs2_d = reg_file[rs2];

	// CSR
	reg			csr_we;
	wire  [`XLEN-1:0]	csr_rd;
	logic [`XLEN-1:0]	csr_wd;

	wire [`XLEN-1:0]	mtvec;
	wire [`XLEN-1:0]	mepc;
	logic			trap;
	RISCV64G_ISS_CSR	RISCV64G_ISS_CSR
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.WE		(csr_we),
		.A		(csr),
		.RD		(csr_rd),
		.WD		(csr_wd),

		.mtvec		(mtvec),
		.mepc		(mepc),

		.trap		(trap)
	);

	// main loop
	always_ff @(posedge CLK or negedge RSTn)
	begin
		if(!RSTn) begin
			integer i;
			// pc
			pc <= 64'h0000_0000_8000_0000;

			csr_we = 1'b0;
			trap = 1'b0;
			tohost_we = 1'b0;
		end else begin
			// reset csr_we
			csr_we = 1'b0;
			trap = 1'b0;
			tohost_we = 1'b0;

			// execute and write back
			case (opcode)
			7'b00_000_11: begin	// LOAD: I type
				case (funct3)
				3'b000: begin			// LB
						tmp = rs1_d + imm_iw;
						tmp32 = mem[tmp[22-1:2]];
						case (tmp[1:0])
						2'h0 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{tmp32[7]}}, tmp32[7:0]};
						2'h1 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{tmp32[15]}}, tmp32[15:8]};
						2'h2 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{tmp32[23]}}, tmp32[23:16]};
						2'h3 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{tmp32[31]}}, tmp32[31:24]};
						endcase
				end
				3'b001: begin			// LH
						tmp = rs1_d + imm_iw;
						tmp32 = mem[tmp[22-1:2]];
						case (tmp[1])
						1'b0 : if(rd0 != 5'h00) reg_file[rd0] <= {{48{tmp32[15]}}, tmp32[15:0]};
						1'b1 : if(rd0 != 5'h00) reg_file[rd0] <= {{48{tmp32[31]}}, tmp32[31:16]};
						endcase
				end
				3'b010: begin			// LW
						tmp = rs1_d + imm_iw;
						tmp32 = mem[tmp[22-1:2]];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
				end
				3'b011: begin			// LD
						tmp = rs1_d + imm_iw;
						if(rd0 != 5'h00) reg_file[rd0] <= {mem[tmp[22-1:2] + 'b1], mem[tmp[22-1:2]]};
				end
				3'b100: begin			// LBU
						tmp = rs1_d + imm_iw;
						tmp32 = mem[tmp[22-1:2]];
						case (tmp[1:0])
						2'h0 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{1'b0}}, tmp32[7:0]};
						2'h1 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{1'b0}}, tmp32[15:8]};
						2'h2 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{1'b0}}, tmp32[23:16]};
						2'h3 : if(rd0 != 5'h00) reg_file[rd0] <= {{56{1'b0}}, tmp32[31:24]};
						endcase
				end
				3'b101: begin			// LHU
						tmp = rs1_d + imm_iw;
						tmp32 = mem[tmp[22-1:2]];
						case (tmp[1])
						1'b0 : if(rd0 != 5'h00) reg_file[rd0] <= {{48{1'b0}}, tmp32[15:0]};
						1'b1 : if(rd0 != 5'h00) reg_file[rd0] <= {{48{1'b0}}, tmp32[31:16]};
						endcase
				end
				3'b110: begin			// LWU
						tmp = rs1_d + imm_iw;
						tmp32 = mem[tmp[22-1:2]];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{1'b0}}, tmp32};
				end
				default: ;
				endcase
			end

			7'b01_000_11: begin	// STORE: S type
				case (funct3)
				3'b000: begin			// SB
						tmp = rs1_d + imm_sw;
						tmp32 = mem[tmp[22-1:2]];
						case (tmp[1:0])
						2'h0 : mem[tmp[22-1:2]]	= {tmp32[31:8], rs2_d[7:0]};
						2'h1 : mem[tmp[22-1:2]]	= {tmp32[31:16], rs2_d[7:0], tmp32[7:0]};
						2'h2 : mem[tmp[22-1:2]]	= {tmp32[31:24], rs2_d[7:0], tmp32[15:0]};
						2'h3 : mem[tmp[22-1:2]]	= {rs2_d[7:0], tmp32[23:0]};
						endcase
				end
				3'b001: begin			// SH
						tmp = rs1_d + imm_sw;
						tmp32 = mem[tmp[22-1:2]];
						case (tmp[1])
						1'b0 : mem[tmp[22-1:2]]	= {tmp32[31:16], rs2_d[15:0]};
						1'b1 : mem[tmp[22-1:2]]	= {rs2_d[15:0], tmp32[15:0]};
						endcase
				end
				3'b010: begin			// SW
						tmp = rs1_d + imm_sw;
						mem[tmp[22-1:2]]	= rs2_d[31:0];
						tohost_we  = pc == 64'h0000_0000_8000_0040 ? 1'b1 : 1'b0;	// for testbench hack
				end
				3'b011: begin			// SD
						tmp = rs1_d + imm_sw;
						mem[tmp[22-1:2]]	= rs2_d[31:0];
						mem[tmp[22-1:2] + 'b1]	= rs2_d[63:32];
				end
				default: ;
				endcase
			end

			7'b10_000_11: begin	// MADD
			end

			// 7'b11_000_11:	// BRANCH

			7'b00_001_11: begin	// LOAD-FP
			end

			7'b01_001_11: begin	// STORE-FP
			end

			7'b10_001_11: begin	// MSUB
			end

			7'b11_001_11: begin	// JALR
				case (funct3)
				3'b000: begin
						if(rd0 != 5'h00) reg_file[rd0] <= pc + 'h4;
				end
				default: ;
				endcase
			end

			7'b01_010_11: begin	// NMSUB
			end

			// 7'b00_011_11:	// MISC-MEM

			7'b01_011_11: begin	// AMO
			end

			7'b10_011_11: begin	// NMADD
			end

			7'b11_011_11: begin	// JAL
						if(rd0 != 5'h00) reg_file[rd0] <= pc + 'h4;
			end

			7'b00_100_11: begin	// OP-IMM
				case (funct3)
				3'b000: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d + imm_iw;	// ADDI
				3'b001: begin
					case (funct7[6:1])
					6'b000000: begin						// SLLI
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d << shamt;
					end
					default: ;
					endcase
				end
				3'b010: 	if(rd0 != 5'h00) reg_file[rd0] <= $signed(rs1_d) < $signed(imm_iw) ? 64'h0000_0000_0000_0001 : {64{1'b0}};	// SLTI
				3'b011: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d < imm_iw ? 64'h0000_0000_0000_0001 : {64{1'b0}};	// SLTIU
				3'b100: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d ^ imm_iw;	// XORI
				3'b101: begin
					case (funct7[6:1])
					6'b000000: begin						// SRLI
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d >> shamt;
					end
					6'b010000: begin						// SRAI
					 	if(rd0 != 5'h00) reg_file[rd0] <= $signed(rs1_d) >>> shamt;
					end
					default: ;
					endcase
				end
				3'b110: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d | imm_iw;	// ORI
				3'b111: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d & imm_iw;	// ANDI
				default: ;
				endcase
			end

			7'b01_100_11: begin	// OP
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: begin	// ADD
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d + rs2_d;
					end
					7'b0100000: begin	// SUB
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d - rs2_d;
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLL
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d << rs2_d[5:0];
					end
					default: ;
					endcase
				end
				3'b010: begin
					case (funct7)
					7'b0000000: begin	// SLT
						if(rd0 != 5'h00) reg_file[rd0] <= $signed(rs1_d) < $signed(rs2_d) ? 64'h0000_0000_0000_0001 : {64{1'b0}};
					end
					default: ;
					endcase
				end
				3'b011: begin
					case (funct7)
					7'b0000000: begin	// SLTU
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d < rs2_d ? 64'h0000_0000_0000_0001 : {64{1'b0}};
					end
					default: ;
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b0000000: begin	// XOR
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d ^ rs2_d;
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRL
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d >> rs2_d[5:0];
					end
					7'b0100000: begin	// SRA
						if(rd0 != 5'h00) reg_file[rd0] <= $signed(rs1_d) >>> rs2_d[5:0];
					end
					default: ;
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b0000000: begin	// OR
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d | rs2_d;
					end
					default: ;
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000000: begin	// AND
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d & rs2_d;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b10_100_11: begin	// OP-FP
			end

			7'b11_100_11: begin	// SYSTEM
				case (funct3)
				3'b001: begin		// CSRRW
					csr_we = 1'b1;
					csr_wd = rs1_d;
					if(rd0 != 5'h00) reg_file[rd0] <= csr_rd;
				end
				3'b010: begin		// CSRRS
					csr_we = rs1 == 5'h00 ? 1'b0 : 1'b1;
					csr_wd = csr_rd | rs1_d;
					if(rd0 != 5'h00) reg_file[rd0] <= csr_rd;
				end
				3'b011: begin		// CSRRC
					csr_we = rs1 == 5'h00 ? 1'b0 : 1'b1;
					csr_wd = csr_rd & ~rs1_d;
					if(rd0 != 5'h00) reg_file[rd0] <= csr_rd;
				end
				3'b101: begin		// CSRRWI
					csr_we = 1'b1;
					csr_wd = uimm_w;
					if(rd0 != 5'h00) reg_file[rd0] <= csr_rd;
				end
				3'b110: begin		// CSRRSI
					csr_we = 1'b1;
					csr_wd = csr_rd | uimm_w;
					if(rd0 != 5'h00) reg_file[rd0] <= csr_rd;
				end
				3'b111: begin		// CSRRCI
					csr_we = 1'b1;
					csr_wd = csr_rd & ~uimm_w;
					if(rd0 != 5'h00) reg_file[rd0] <= csr_rd;
				end
				default: ;
				endcase
			end

			7'b00_101_11: begin	// AUIPC
						if(rd0 != 5'h00) reg_file[rd0] <= pc + imm_uw;
			end

			7'b01_101_11: begin	// LUI
						if(rd0 != 5'h00) reg_file[rd0] <= imm_uw;
			end

			7'b00_110_11: begin	// OP-IMM-32
				case (funct3)
				3'b000: begin			// ADDIW
						tmp32 = rs1_d[31:0] + imm_iw[31:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLIW
						tmp32 = rs1_d[31:0] << shamt[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLIW
						tmp32 = rs1_d[31:0] >> shamt[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					7'b0100000: begin	// SRAIW
						tmp32 = $signed(rs1_d[31:0]) >>> shamt[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b01_110_11: begin	// OP-32
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: begin	// ADDW
						tmp32 = rs1_d[31:0] + rs2_d[31:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					7'b0100000: begin	// SUBW
						tmp32 = rs1_d[31:0] - rs2_d[31:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLW
						tmp32 = rs1_d[31:0] << rs2_d[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLW
						tmp32 = rs1_d[31:0] >> rs2_d[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					7'b0100000: begin	// SRAW
						tmp32 = $signed(rs1_d[31:0]) >>> rs2_d[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end
			default: ;
			endcase

			// pc update
			case (opcode)
			7'b1101111: begin	// JAL
					pc <= pc + imm_jw;
			end
			7'b1100111: begin	// JALR
				case (funct3)
				3'b000: begin
					pc <= rs1_d + imm_iw;
				end
				default:pc <= pc + 'h4;
				endcase
			end
			7'b1100011: begin	// BRANCH
				case (funct3)
				3'b000:	pc <= rs1_d == rs2_d ? pc + imm_bw : pc + 'h4;	// BEQ
				3'b001:	pc <= rs1_d != rs2_d ? pc + imm_bw : pc + 'h4;	// BNE
				3'b100:	pc <= $signed(rs1_d) <  $signed(rs2_d) ? pc + imm_bw : pc + 'h4;	// BLT
				3'b101:	pc <= $signed(rs1_d) >= $signed(rs2_d) ? pc + imm_bw : pc + 'h4;	// BGE
				3'b110:	pc <= rs1_d <  rs2_d ? pc + imm_bw : pc + 'h4;	// BLTU
				3'b111:	pc <= rs1_d >= rs2_d ? pc + imm_bw : pc + 'h4;	// BGEU
				default:pc <= pc + 'h4;
				endcase
			end
			7'b1110011: begin	// SYSTEM
				case (funct3)
				3'b000: begin
					case ({funct7, rs2})
					12'b0000000_00000: begin	// ECALL
						trap = 1'b1;
						pc <= mtvec;
					end
					12'b0000000_00001: begin	// EBREAK
					end
					12'b0001000_00010: begin	// SRET
					end
					12'b0011000_00010: begin	// MRET
						pc <= mepc;
					end
					default: ;
					endcase
				end
				default:pc <= pc + 'h4;
				endcase
			end
			default:	pc <= pc + 'h4;
			endcase
		end
	end


	// trace output
	always @(posedge CLK)
	begin
		if(RSTn) begin
			case (opcode)
			7'b00_000_11: begin	// LOAD: I type
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LB,     rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LH,     rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LW,     rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LD,     rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LBU,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b101: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LHU,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b110: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, LWU,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				endcase
			end
			7'b01_000_11: begin	// STORE: S type
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SB,     rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SH,     rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SW,     rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
				3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SD,     rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
				endcase
			end
			7'b10_000_11: begin	// MADD
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b11_000_11: begin	// BRANCH: B type
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, BEQ,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, BNE,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				3'b100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, BLT,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				3'b101: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, BGE,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				3'b110: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, BLTU,   rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				3'b111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, BGEU,   rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_b );
				endcase
			end

			7'b00_001_11: begin	// LOAD-FP
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b01_001_11: begin	// STORE-FP
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b10_001_11: begin	// MSUB
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b11_001_11: begin	// JALR
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, JALR,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i ); // I type
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				endcase
			end

			7'b10_010_11: begin	// NMSUB
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end

			7'b00_011_11: begin	// MISC-MEM
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, FENCE,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				default: $display("pc=%016H: %08H, opcode = %07B, fucnt3 = %03B, ??? ", pc, inst, opcode, funct3 );
				endcase
			end
			7'b01_011_11: begin	// AMO
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b10_011_11: begin	// NMADD
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b11_011_11: begin	// JAL: J type
				$display("pc=%016H: %08H, opcode = %07B, JAL,   rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_j );
			end


			7'b00_100_11: begin	// OP-IMM: I type or R type
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ADDI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b001: begin
					case (funct7[6:1])
					6'b000000: begin						// SLLI
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, SLLI,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
					end
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, ???,   rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
					endcase
				end
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SLTI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SLTIU,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, XORI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b101: begin
					case (funct7[6:1])
					6'b000000: begin						// SRLI
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, SRLI,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
					end
					6'b010000: begin						// SRAI
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, SRAI,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
					end
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, ???,   rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
					endcase
				end
				3'b110: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ORI,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ANDI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				endcase
			end
			7'b01_100_11: begin	// OP: R type
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ADD,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, MUL,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SUB,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLL,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, MULH, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b010: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLT,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, MULHSU, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b011: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLTU, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, MULHU,rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, XOR,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, DIV,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRL,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, DIVU, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRA,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, OR,   rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, REM,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, AND,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, REMU, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				endcase
			end
			7'b10_100_11: begin	// OP-FP
				$display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			end
			7'b11_100_11: begin	// SYSTEM: I type
				case (funct3)
				3'b000: begin
					case ({funct7, rs2})
					12'b0000000_00000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, ECALL", pc, inst, opcode, funct3, funct7, rs2);
					12'b0000000_00001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, EBREAK", pc, inst, opcode, funct3, funct7, rs2);
					12'b0001000_00010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, SRET", pc, inst, opcode, funct3, funct7, rs2);
					12'b0011000_00010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, MRET", pc, inst, opcode, funct3, funct7, rs2);
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, ?????", pc, inst, opcode, funct3, funct7, rs2);
					endcase
				end
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, CSRRW,  rd0 = x%d, rs1 = x%d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, CSRRS,  rd0 = x%d, rs1 = x%d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, CSRRC,  rd0 = x%d, rs1 = x%d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				3'b101: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, CSRRWI, rd0 = x%d, uimm = %d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				3'b110: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, CSRRSI, rd0 = x%d, uimm = %d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				3'b111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, CSRRCI, rd0 = x%d, uimm = %d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, uimm = %d, csr = %08H", pc, inst, opcode, funct3, rd0, rs1, csr );
				endcase
			end

			7'b00_101_11: begin	// AUIPC: U type
				$display("pc=%016H: %08H, opcode = %07B, AUIPC, rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_u );
			end
			7'b01_101_11: begin	// LUI: U type
				$display("pc=%016H: %08H, opcode = %07B, LUI,   rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_u );
			end


			7'b00_110_11: begin	// OP-IMM-32
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ADDIW,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLLIW,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
				3'b101: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRLIW,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRAIW,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
					endcase
				end
				default:  $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				endcase
			end
			7'b01_110_11: begin	// OP-32: R type
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ADDW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, MULW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SUBW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLLW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, DIVW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRLW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, DIVUW,rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRAW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, REMW, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, REMUW,rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				endcase
			end
			default: $display("pc=%016H: %08H, opcode = %07B", pc, inst, opcode );
			endcase	
		end
	end
	

endmodule
