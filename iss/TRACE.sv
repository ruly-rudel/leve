
class TRACE;
	function void print(input [63:0] pc, input [31:0] inst);
		logic [6:0]		opcode;
		logic [4:0]		rd0;
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
		logic [32-1:0]		imm_i;
		logic [32-1:0]		imm_s;
		logic [32-1:0]		imm_b;
		logic [32-1:0]		imm_u;
		logic [32-1:0]		imm_j;
	
		logic [`XLEN-1:0]	imm_iw;
		logic [`XLEN-1:0]	imm_sw;
		logic [`XLEN-1:0]	imm_bw;
		logic [`XLEN-1:0]	imm_uw;
		logic [`XLEN-1:0]	imm_jw;
	
		logic [`XLEN-1:0]	uimm_w;
		
		logic [12-1:0]		csr;
		logic [6-1:0]		shamt;

		opcode = inst[6:0];
		rd0    = inst[11:7];
		funct3 = inst[14:12];
		rs1    = inst[19:15];
		rs2    = inst[24:20];
		rs3    = inst[31:27];
		funct7 = inst[31:25];
		funct5 = inst[31:27];
		funct2 = inst[26:25];
		aq     = inst[26];
		rl     = inst[25];
		rm     = inst[14:12];

		imm_i  = {{20{inst[31]}}, inst[31:20]};
		imm_s  = {{20{inst[31]}}, inst[31:25], inst[11:7]};
		imm_b  = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
		imm_u  = {inst[31:12], 12'h000};
		imm_j  = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

		imm_iw = {{32{imm_i[31]}}, imm_i};
		imm_sw = {{32{imm_s[31]}}, imm_s};
		imm_bw = {{32{imm_b[31]}}, imm_b};
		imm_uw = {{32{imm_u[31]}}, imm_u};
		imm_jw = {{32{imm_j[31]}}, imm_j};

		uimm_w = {{`XLEN-5{1'b0}}, rs1};

		csr    = inst[31:20];
		shamt  = imm_i[5:0];

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
		7'b10_000_11: begin	// MADD: R4 type
			case (funct2)
			2'b00: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, FMADD.S, rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			default: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, ???,    rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			endcase
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

		7'b00_001_11: begin	// LOAD-FP: I type
			case (funct3)
			3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, FLW,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			endcase
		end
		7'b01_001_11: begin	// STORE-FP: S type
			case (funct3)
			3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, FSW,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
			default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rs1 = x%d, rs2 = x%d, imm = %08H", pc, inst, opcode, funct3, rs1, rs2, imm_s );
			endcase
		end
		7'b10_001_11: begin	// MSUB: R4 type
			case (funct2)
			2'b00: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, FMSUB.S, rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			default: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, ???,     rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			endcase
		end
		7'b11_001_11: begin	// JALR
			case (funct3)
			3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, JALR,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i ); // I type
			default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ???,    rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			endcase
		end

		7'b10_010_11: begin	// NMSUB
			case (funct2)
			2'b00: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, FNMSUB.S, rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			default: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, ???,      rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			endcase
		end

		7'b00_011_11: begin	// MISC-MEM
			case (funct3)
			3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, FENCE,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, FENCE.I,rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			default: $display("pc=%016H: %08H, opcode = %07B, fucnt3 = %03B, ??? ", pc, inst, opcode, funct3 );
			endcase
		end
		7'b01_011_11: begin	// AMO
			case (funct3)
			3'b010: begin
				case (funct5)
				5'b00010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, LR.W,  rd0 = x%d, rs1 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, aq, rl);
				5'b00011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, SC.W,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b00001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOSWAP.W, rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b00000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOADD.W,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b00100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOXOR.W,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b01100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOAND.W,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b01000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOOR.W,   rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b10000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMIN.W,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b10100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMAX.W,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b11000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMINU.W, rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b11100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMAXU.W, rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				endcase
			end
			3'b011: begin
				case (funct5)
				5'b00010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, LR.D,  rd0 = x%d, rs1 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, aq, rl);
				5'b00011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, SC.D,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b00001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOSWAP.D, rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b00000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOADD.D,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b00100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOXOR.D,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b01100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOAND.D,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b01000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOOR.D,   rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b10000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMIN.D,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b10100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMAX.D,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b11000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMINU.D, rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				5'b11100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, AMOMAXU.D, rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
				endcase
			end
			default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct5 = %05B, ???,  rd0 = x%d, rs1 = x%d, rs2 = x%d, aq = %1B, rl = %1B", pc, inst, opcode, funct3, funct5, rd0, rs1, rs2, aq, rl );
			endcase
		end
		7'b10_011_11: begin	// NMADD
			case (funct2)
			2'b00: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, FNMADD.S, rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			default: $display("pc=%016H: %08H, opcode = %07B, funct2 = %02B, ???,     rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d, rs3 = x%d", pc, inst, opcode, funct2, rm, rd0, rs1, rs2, rs3 );
			endcase
		end
		7'b11_011_11: begin	// JAL: J type
			$display("pc=%016H: %08H, opcode = %07B,               JAL,    rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_j );
		end


		7'b00_100_11: begin	// OP-IMM: I type or R type
			case (funct3)
			3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ADDI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			3'b001: begin
				case (funct7[6:1])
				6'b000000: begin						// SLLI
					$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, SLLI,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
				end
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, ???,   rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
				endcase
			end
			3'b010: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SLTI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			3'b011: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, SLTIU,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			3'b100: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, XORI,   rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			3'b101: begin
				case (funct7[6:1])
				6'b000000: begin						// SRLI
					$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, SRLI,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
				end
				6'b010000: begin						// SRAI
					$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, SRAI,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
				end
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7[6:1] = %06B, ???,   rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7[6:1], rd0, rs1, shamt );
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
		7'b10_100_11: begin	// OP-FP: R type
			case(funct7)
			7'b00000_00: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, FADD.S,    rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, rm, rd0, rs1, rs2);
			7'b00001_00: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, FSUB.S,    rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, rm, rd0, rs1, rs2);
			7'b00010_00: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, FMUL.S,    rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, rm, rd0, rs1, rs2);
			7'b00011_00: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, FDIV.S,    rm = %03B,  rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, rm, rd0, rs1, rs2);
			7'b01011_00: begin
				case (rs2)
				5'b00000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FSQRT.S,   rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, ???,       rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				endcase
			end
			7'b00100_00: begin
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FSGNJ.S,    rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FSGNJN.S,   rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FSGNJX.S,   rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, ???,        rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				endcase
			end
			7'b00101_00: begin
				case (funct3)
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FMIN.S,     rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FMAX.S,     rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, ???,        rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				endcase
			end
			7'b11000_00: begin
				case (rs2)
				5'b00000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.W.S,  rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				5'b00001: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.WU.S, rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				5'b00010: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.L.S,  rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				5'b00011: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.LU.S, rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, ???,       rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				endcase
			end
			7'b11100_00: begin
				case (rs2)
				5'b00000: begin
					case (funct3)
					3'b000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, FMV.X.W,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
					3'b001: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, FCLASS.W, rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
					default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, ???,      rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
					endcase
				end
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, ???,      rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
				endcase
			end
			7'b10100_00: begin
				case (funct3)
				3'b010: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FEQ.S,      rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				3'b001: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FLT.S,      rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				3'b000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, FLE.S,      rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, funct3 = %03B, ???,        rd = x%d, rs1 = x%d, rs2 = x%d", pc, inst, opcode, funct7, funct3, rd0, rs1, rs2);
				endcase
			end
			7'b11010_00: begin
				case (rs2)
				5'b00000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.S.W,  rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				5'b00001: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.S.WU, rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				5'b00010: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.S.L,  rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				5'b00011: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, FCVT.S.LU, rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, ???,       rm = %03B,  rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, rm, rd0, rs1);
				endcase
			end
			7'b11110_00: begin
				case (rs2)
				5'b00000: begin
					case (funct3)
					3'b000: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, FMV.W.X,    rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
					default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, ???,        rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
					endcase
				end
				default: $display("pc=%016H: %08H, opcode = %07B, funct7 = %02B, rs2 = %05B, funct3 = %03B, ???,        rd = x%d, rs1 = x%d", pc, inst, opcode, funct7, rs2, funct3, rd0, rs1);
				endcase
			end
			default: $display("pc=%016H: %08H, opcode = %07B, ??? ", pc, inst, opcode );
			endcase
		end
		7'b11_100_11: begin	// SYSTEM: I type
			case (funct3)
			3'b000: begin
				case ({funct7})
				7'b0000000: begin
					if(rs2 == 5'b00000 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, ECALL", pc, inst, opcode, funct3, funct7, rs2);
					end else if(rs2 == 5'b00001 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, EBREAK", pc, inst, opcode, funct3, funct7, rs2);
					end else begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, ?????", pc, inst, opcode, funct3, funct7, rs2);
					end
				end
				7'b0001000: begin
					if(rs2 == 5'b00010 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, SRET", pc, inst, opcode, funct3, funct7, rs2);
					end else if(rs2 == 5'b00101 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, WFI", pc, inst, opcode, funct3, funct7, rs2);
					end else begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, ?????", pc, inst, opcode, funct3, funct7, rs2);
					end
				end
				7'b0011000: begin
					if(rs2 == 5'b00010 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, MRET", pc, inst, opcode, funct3, funct7, rs2);
					end else begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, rs2 = %05B, ?????", pc, inst, opcode, funct3, funct7, rs2);
					end
				end
				7'b0001001: begin
					if(rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SFENCE.VMA, rs1 = x%d, rs2= x%d", pc, inst, opcode, funct3, funct7, rs1, rs2);
					end else begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,        rs1 = x%d, rs2= x%d", pc, inst, opcode, funct3, funct7, rs1, rs2);
					end
				end
				7'b0001011: begin
					if(rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SINVAL.VMA, rs1 = x%d, rs2= x%d", pc, inst, opcode, funct3, funct7, rs1, rs2);
					end else begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,        rs1 = x%d, rs2= x%d", pc, inst, opcode, funct3, funct7, rs1, rs2);
					end
				end
				7'b0001100: begin
					if(rs2 == 5'b00000 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SFENCE.W.INVAL", pc, inst, opcode, funct3, funct7);
					end else if(rs2 == 5'b00001 && rd0 == 5'h00) begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SFENCE.INVAL.IR", pc, inst, opcode, funct3, funct7);
					end else begin
						$display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???", pc, inst, opcode, funct3, funct7);
					end
				end
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
			$display("pc=%016H: %08H, opcode = %07B,               AUIPC,  rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_u );
		end
		7'b01_101_11: begin	// LUI: U type
			$display("pc=%016H: %08H, opcode = %07B,               LUI,    rd0 = x%d, imm = %08H", pc, inst, opcode, rd0, imm_u );
		end


		7'b00_110_11: begin	// OP-IMM-32
			case (funct3)
			3'b000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, ADDIW,  rd0 = x%d, rs1 = x%d, imm = %08H", pc, inst, opcode, funct3, rd0, rs1, imm_i );
			3'b001: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SLLIW,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
			3'b101: begin
				case (funct7)
				7'b0000000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRLIW,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
				7'b0100000: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, SRAIW,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
				default: $display("pc=%016H: %08H, opcode = %07B, funct3 = %03B, funct7 = %07B, ???,  rd0 = x%d, rs1 = x%d, shamt = %d", pc, inst, opcode, funct3, funct7, rd0, rs1, shamt );
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
	endfunction
endclass : TRACE;
