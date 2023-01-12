
`include "defs.vh"

module RISCV64G_ISS (
	input			CLK,
	input			RSTn
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
	RISCV64G_ISS_CSR	RISCV64G_ISS_CSR
	(
		.CLK		(CLK),
		.RSTn		(RSTn),
		.WE		(csr_we),
		.A		(csr),
		.RD		(csr_rd),
		.WD		(csr_wd),

		.mtvec		(mtvec),
		.mepc		(mepc)
	);

	// main loop
	always_ff @(posedge CLK or negedge RSTn)
	begin
		if(!RSTn) begin
			integer i;
			// pc
			pc <= 64'h0000_0000_8000_0000;

			csr_we = 1'b0;
		end else begin
			// reset csr_we
			csr_we = 1'b0;

			// execute and write back
			case (opcode)
			7'b0110111: begin	// LUI
						if(rd0 != 5'h00) reg_file[rd0] <= imm_uw;
			end
			7'b0010111: begin	// AUIPC
						if(rd0 != 5'h00) reg_file[rd0] <= pc + imm_uw;
			end
			7'b0010011: begin	// OP-IMM
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
				3'b010: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d < imm_iw ? 64'h0000_0000_0000_0001 : {64{1'b0}};	// SLTI ************* FIX IT
				3'b011: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d < imm_iw ? 64'h0000_0000_0000_0001 : {64{1'b0}};	// SLTIU
				3'b100: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d ^ imm_iw;	// XORI
				3'b101: begin
					case (funct7[6:1])
					6'b000000: begin						// SRLI
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d >> shamt;
					end
					6'b010000: begin						// SRAI
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d >>> shamt;
					end
					default: ;
					endcase
				end
				3'b110: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d | imm_iw;	// ORI
				3'b111: 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d & imm_iw;	// ANDI
				default: ;
				endcase
			end
			7'b0011011: begin	// OP-IMM-32
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
						tmp32 = rs1_d[31:0] >>> shamt[4:0];
						if(rd0 != 5'h00) reg_file[rd0] <= {{32{tmp32[31]}}, tmp32};
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end
			7'b0110011: begin	// OP
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: begin	// ADD
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d + rs2_d;
					end
					7'b0100000: begin	// SUB
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs2_d - rs1_d;
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b000000: begin	// SLL
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d << rs2_d[5:0];
					end
					default: ;
					endcase
				end
				3'b010: begin
					case (funct7)
					7'b000000: begin	// SLT
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d < rs2_d ? 64'h0000_0000_0000_0001 : {64{1'b0}};	// ************* FIX IT
					end
					default: ;
					endcase
				end
				3'b011: begin
					case (funct7)
					7'b000000: begin	// SLTU
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d < rs2_d ? 64'h0000_0000_0000_0001 : {64{1'b0}};
					end
					default: ;
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b000000: begin	// XOR
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d ^ rs2_d;
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b000000: begin	// SRL
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d >> rs2_d[5:0];
					end
					7'b010000: begin	// SRA
						if(rd0 != 5'h00) reg_file[rd0] <= rs1_d >>> rs2_d[5:0];
					end
					default: ;
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b000000: begin	// OR
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d | rs2_d;
					end
					default: ;
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b000000: begin	// AND
					 	if(rd0 != 5'h00) reg_file[rd0] <= rs1_d & rs2_d;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end
			7'b1110011: begin	// SYSTEM
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
			default: ;
			endcase

			// pc update
			case (opcode)
			7'b1101111: begin	// JAL
					pc <= pc + imm_jw;
			end
			7'b1100011: begin	// BRANCH
				case (funct3)
				3'b000:	pc <= rs1_d == rs2_d ? pc + imm_bw : pc + 'h4;	// BEQ
				3'b001:	pc <= rs1_d != rs2_d ? pc + imm_bw : pc + 'h4;	// BNE
				3'b100:	pc <= rs1_d <  rs2_d ? pc + imm_bw : pc + 'h4;	// BLT	FIX IT**************
				3'b101:	pc <= rs1_d >  rs2_d ? pc + imm_bw : pc + 'h4;	// BGE	FIX IT**************
				3'b110:	pc <= rs1_d <  rs2_d ? pc + imm_bw : pc + 'h4;	// BLTU
				3'b111:	pc <= rs1_d >  rs2_d ? pc + imm_bw : pc + 'h4;	// BGEU
				default:pc <= pc + 'h4;
				endcase
			end
			7'b1110011: begin	// SYSTEM
				case (funct3)
				3'b000: begin
					case ({funct7, rs2})
					12'b0000000_00000: begin	// ECALL
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
			7'b0110111: $display("pc=%016H: %08H, opcode = %07B, LUI,   rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_u ); // U type
			7'b0010111: $display("pc=%016H: %08H, opcode = %07B, AUIPC, rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_u ); // U type
			7'b1101111: $display("pc=%016H: %08H, opcode = %07B, JAL,   rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_j ); // J type
			7'b1100111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, JALR,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i ); // I type
			7'b0010011: begin	// I type or R type
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ADDI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLLI,  rd0 = x%d, rs1 = x%d, shamt = %02H", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SLTI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SLTIU,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, XORI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b110: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ORI,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				3'b111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ANDI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
				endcase
			end
			7'b0110011: begin	// R type
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ADD,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SUB,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLL,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLT,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLTU, rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				3'b100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, XOR,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				3'b101: begin
					case (funct7)
					7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRL,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRA,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
					endcase
				end
				3'b110: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, OR,   rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				3'b111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, AND,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct3, funct7, rd0, rs1, rs2 );
				endcase
			end
			7'b1100011: begin	// B type
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
			7'b1110011: begin	// I type
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
			7'b0001111: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, FENCE,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			7'b0100011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SD,     rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );// S type
			7'b0011011: begin	// 
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
			default: $display("pc=%016H: %08H, opcode = %07B", pc, inst, opcode );
			endcase	
		end
	end
	

endmodule
