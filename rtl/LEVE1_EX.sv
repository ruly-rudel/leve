
`include "defs.vh"

function [`XLEN-1:0] s32to64(input logic [31:0] in);
	return {{32{in[31]}}, in};
endfunction

typedef union packed
{
	logic [`XLEN-1:0]	word;
	struct packed
	{
		logic			sd;
		logic [24:0]		reserved1;
		logic			mbe;
		logic			sbe;
		logic [1:0]		sxl;
		logic [1:0]		uxl;
		logic [8:0]		reserved2;
		logic			tsr;
		logic			tw;
		logic			tvm;
		logic			mxr;
		logic			sum;
		logic			mprv;
		logic [1:0]		xs;
		logic [1:0]		fs;
		logic [1:0]		mpp;
		logic [1:0]		vs;
		logic			spp;
		logic			mpie;
		logic			ube;
		logic			spie;
		logic			reserved3;
		logic			mie;
		logic			reserved4;
		logic			sie;
		logic			reserved5;
	} member;
} mstatus_t;


module LEVE1_EX
(
	input				CLK,
	input		 		RSTn,

	input				IF_VALID,
	input				IF_READY,
	input [`XLEN-1:0]		IF_PC,

	input				ID_VALID,
	input [`XLEN-1:0]		ID_PC,
	input [31:0]			ID_INSTR,
	input [`XLEN-1:0]		ID_RS1,
	input [`XLEN-1:0]		ID_RS2,
	CSRIF.target			ID_CSR,

	output logic [`XLEN-1:0]	FWD_RD,
	output logic [`XLEN-1:0]	FWD_CSRD,

	output logic			EX_VALID,
	output logic [`XLEN-1:0]	EX_PC,
	output logic [31:0]		EX_INSTR,

	output logic			EX_PC_WE,
	output logic [`XLEN-1:0]	EX_NEXT_PC,
	output logic			OFLASH,

	output logic			WB_WE,
	output logic [`XLEN-1:0]	WB_RD,
	output logic [`XLEN-1:0]	WB_CSRD
);
	// stage 2
	logic [4:0]		rs1;
	logic [4:0]		rs2;
	logic [`XLEN-1:0]	imm_i;
	logic [`XLEN-1:0]	imm_b;
	logic [`XLEN-1:0]	imm_u;
	logic [`XLEN-1:0]	uimm_w;
	logic [6-1:0]		shamt;
	logic [1:0]		op;
	logic [6:0]		opcode;
	logic [2:0]		funct3;
	logic [6:0]		funct7;
	logic [1:0]		csr_cmd;
	logic			mret;
	
	logic [`XLEN-1:0]	next_pc;

	// mstatus
	logic			sie;
	logic			mie;
	logic			spie;
	logic			ube;
	logic			mpie;
	logic			spp;
	logic [1:0]		vs;
	logic [1:0]		mpp;
	logic [1:0]		fs;
	logic [1:0]		xs;
	logic			mprv;
	logic			sum;
	logic			mxr;
	logic			tvm;
	logic			tw;
	logic			tsr;
	logic [1:0]		uxl;
	logic [1:0]		sxl;
	logic			sbe;
	logic			mbe;
	logic			sd;

	INST inst(.INSTR(ID_INSTR));

	always_comb begin
		op	= ID_INSTR[1:0];
		imm_i	= {{20+32{ID_INSTR[31]}}, ID_INSTR[31:20]};
		imm_b	= {{19+32{ID_INSTR[31]}}, ID_INSTR[31], ID_INSTR[7], ID_INSTR[30:25], ID_INSTR[11:8], 1'b0};
		imm_u	= {{   32{ID_INSTR[31]}}, ID_INSTR[31:12], 12'h000};
		uimm_w	= {{`XLEN-5{1'b0}}, ID_INSTR[19:15]};
		shamt	= imm_i[5:0];

		csr_cmd	= inst.mret() ? `CSR_WRITE : 
			  inst.opcode() == 7'b11_100_11 ? inst.funct3_1_0() : `CSR_NONE;

		sie	= ID_CSR.sie();
		mie	= ID_CSR.mie();
		spie	= ID_CSR.spie();
		ube	= ID_CSR.ube();
		mpie	= ID_CSR.mpie();
		spp	= ID_CSR.spp();
		vs	= ID_CSR.vs();
		mpp	= ID_CSR.mpp();
		fs	= ID_CSR.fs();
		xs	= ID_CSR.xs();
		mprv	= ID_CSR.mprv();
		sum	= ID_CSR.sum();
		mxr	= ID_CSR.mxr();
		tvm	= ID_CSR.tvm();
		tw	= ID_CSR.tw();
		tsr	= ID_CSR.tsr();
		uxl	= ID_CSR.uxl();
		sxl	= ID_CSR.sxl();
		sbe	= ID_CSR.sbe();
		mbe	= ID_CSR.mbe();
		sd	= ID_CSR.sd();
	end

	logic id_we;
	logic taken;
	logic [127:0] tmp128;
	always_comb begin
						next_pc = ID_PC + 'h4;
						id_we	= ID_VALID;
						taken	= 1'b0;
		case(op)
		2'b11: begin
			case (inst.opcode())
			7'b00_100_11: begin	// OP-IMM
				case (inst.funct3())
				3'b000: 	FWD_RD	= ID_RS1 + imm_i;
				3'b001: case (inst.funct7_6_1())
					6'b000000:
						FWD_RD	= ID_RS1 << shamt;
					default:id_we	= 1'b0;
					endcase
				3'b010:		FWD_RD	= $signed(ID_RS1) < $signed(imm_i) ? 'b1 : '0;
				3'b011:		FWD_RD	= ID_RS1 < imm_i ? 'b1 : '0;
				3'b100:		FWD_RD	= ID_RS1 ^ imm_i;
				3'b101: case (inst.funct7_6_1())
					6'b000000:
						FWD_RD	= ID_RS1 >> shamt;
					6'b010000:
					       	FWD_RD	= $signed(ID_RS1) >>> shamt;
					default:id_we	= 0;
					endcase
				3'b110:		FWD_RD	= ID_RS1 | imm_i;
				3'b111:		FWD_RD	= ID_RS1 & imm_i;
				default:	id_we	= 0;
				endcase
			end

			7'b11_000_11: begin	// BRANCH
						id_we	= '0;
				case (inst.funct3())
				3'b000: begin
					taken   = ID_RS1 == ID_RS2;
					next_pc = taken ? ID_PC + imm_b : ID_PC + 'h4;	// BEQ
				end
				3'b001: begin
					taken   = ID_RS1 != ID_RS2;
					next_pc = taken ? ID_PC + imm_b : ID_PC + 'h4;
				end
				3'b100: begin
					taken   = $signed(ID_RS1) < $signed(ID_RS2);
					next_pc = taken ? ID_PC + imm_b : ID_PC + 'h4;	// BLT
				end
				3'b101: begin
					taken   = $signed(ID_RS1) >= $signed(ID_RS2);
					next_pc = taken ? ID_PC + imm_b : ID_PC + 'h4;	// BGE
				end
				3'b110:begin
					taken   = ID_RS1 < ID_RS2;
					next_pc = taken ? ID_PC + imm_b : ID_PC + 'h4;	// BLTU
				end
				3'b111: begin
					taken   = ID_RS1 >= ID_RS2;
					next_pc = taken ? ID_PC + imm_b : ID_PC + 'h4;	// BGEU
				end
				default: next_pc = ID_PC + 'h4;
				endcase
			end

			7'b11_100_11: begin	// SYSTEM
						id_we	= ID_VALID;
				case (inst.funct3())
				3'b000: begin
					case (inst.funct7())
					7'b0011000: begin
						case(inst.rs2())
						5'b00010: begin		// MRET
							id_we	= 1'b0;
							FWD_CSRD	= 
								{sd, 25'h00_0000, mbe, sbe, sxl, uxl,
								 9'h000, tsr, tw, tvm, mxr, sum,
								 mprv, xs, fs, `MODE_U, vs, spp, 1'b1,
								 ube, spie, 1'b0, mpie, 1'b0, sie, 1'b0};
						//	mode = mpp;
						//	next_pc = csr_c.mret();	// mepc
						end
						default:
							next_pc = ID_PC + 'h4;
						endcase
					end
					default:	next_pc = ID_PC + 'h4;
					endcase
				end
				/*
				3'b000: begin
					case (inst.funct7())
					7'b0000000: begin
						case(inst.rs2())
						5'b00000: begin		// ECALL
							tmp = csr_c.ecall(pc);
							if(tmp == {`XLEN{1'b1}}) begin
								next_pc = pc + 'h4;
							end else begin
								next_pc = tmp;
							end
						end
						5'b00001: begin		// EBREAK
								next_pc = csr_c.raise_exception(`EX_BREAK, pc, pc);
						end
						default: next_pc = raise_illegal_instruction(pc, inst);
						endcase
					end
					7'b0001000: begin
						case(inst.rs2())
						5'b00010: begin		// SRET
								next_pc = csr_c.sret();	// sepc
						end
						5'b00101: begin		// WFI
							if(rd0 == 5'h00) begin
								next_pc = pc + 'h4;
							end else begin
								next_pc = raise_illegal_instruction(pc, inst);
							end
						end
						default: next_pc = raise_illegal_instruction(pc, inst);
						endcase
					end
					7'b0011000: begin
						case(inst.rs2())
						5'b00010: begin		// MRET
								next_pc = csr_c.mret();	// mepc
						end
						default: next_pc = raise_illegal_instruction(pc, inst);
						endcase
					end
					7'b0001001: begin
						case(rd0)
						5'h00: begin		// SFENCE.VMA
								next_pc = pc + 'h4;
						end
						default: next_pc = raise_illegal_instruction(pc, inst);
						endcase
					end
					7'b0001011: begin
						case(rd0)
						5'b00000: begin		// SINVAL.VMA
								next_pc = pc + 'h4;
						end
						default: next_pc = raise_illegal_instruction(pc, inst);
						endcase
					end
					7'b0001100: begin
						case(rd0)
						5'b00000: begin
							case (inst.rs2())
							5'b00000: begin	// SFENCE.W.INVAL
								next_pc = pc + 'h4;
							end
							5'b00001: begin	// SFENCE.INVAL.IR
								next_pc = pc + 'h4;
							end
							default: next_pc = raise_illegal_instruction(pc, inst);
							endcase
						end
						default: next_pc = raise_illegal_instruction(pc, inst);
						endcase
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				*/
				3'b001: begin		// CSRRW
						FWD_RD		= ID_CSR.RCSR;
						FWD_CSRD	= ID_RS1;
				end
				3'b010: begin		// CSRRS
						FWD_RD		= ID_CSR.RCSR;
						FWD_CSRD	= ID_CSR.RCSR | ID_RS1;
				end
				3'b011: begin		// CSRRC
						FWD_RD		= ID_CSR.RCSR;
						FWD_CSRD	= ID_CSR.RCSR & ~ID_RS1;
				end
				3'b101: begin		// CSRRWI
						FWD_RD		= ID_CSR.RCSR;
						FWD_CSRD	= uimm_w;
				end
				3'b110: begin		// CSRRSI
						FWD_RD		= ID_CSR.RCSR;
						FWD_CSRD	= ID_CSR.RCSR | uimm_w;
				end
				3'b111: begin		// CSRRCI
						FWD_RD		= ID_CSR.RCSR;
						FWD_CSRD	= ID_CSR.RCSR & ~uimm_w;
				end
				default:	id_we	= 1'b0;
				endcase
			end

			7'b00_101_11: begin	// AUID_PC
						id_we	= ID_VALID;
						FWD_RD	= ID_PC + imm_u;
			end

			7'b01_101_11: begin	// LUI
						id_we	= ID_VALID;
						FWD_RD  = imm_u;
			end

			7'b00_110_11: begin	// OP-IMM-32
						id_we	= ID_VALID;
				case (inst.funct3())
				3'b000: FWD_RD	= s32to64(ID_RS1[31:0] + imm_i[31:0]);	// ADDIW
				3'b001: begin
					case (inst.funct7())
					7'b0000000:
						FWD_RD	= s32to64(ID_RS1[31:0] << shamt[4:0]); // SLLIW
					default:id_we	= 1'b0;
					endcase
				end
				3'b101: begin
					case (inst.funct7())
					7'b0000000:
						FWD_RD	= s32to64(ID_RS1[31:0] >> shamt[4:0]); // SRLIW
					7'b0100000:
						FWD_RD	= s32to64($signed(ID_RS1[31:0]) >>> shamt[4:0]); // SRAIW
					default:id_we	= 1'b0;
					endcase
				end
				default:	id_we	= 1'b0;
				endcase
			end

			default:		id_we	= 1'b0;

			7'b01_100_11: begin	// OP
						id_we	= ID_VALID;
				case (inst.funct3())
				3'b000: begin
					case (inst.funct7())
					7'b0000000: 
						FWD_RD	= ID_RS1 + ID_RS2;	// ADD
					7'b0000001:
						FWD_RD	= $bits(FWD_RD)'(ID_RS1 * ID_RS2);	// MUL
					7'b0100000:
						FWD_RD	= ID_RS1 - ID_RS2;	// SUB
					default: id_we	= 1'b0;
					endcase
				end
				3'b001: begin
					case (inst.funct7())
					7'b0000000:
						FWD_RD	= ID_RS1 << ID_RS2[5:0];	// SLL
					7'b0000001: begin
						tmp128	= $signed(ID_RS1) * $signed(ID_RS2);	// MULH
						FWD_RD	= tmp128[`XLEN*2-1:`XLEN];
					end
					default: id_we	= 1'b0;
					endcase
				end
				/*
				3'b010: begin
					case (inst.funct7())
					7'b0000000: begin	// SLT
						rf.write(rd0, $signed(rs1_d) < $signed(inst.rs2()_d) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
						next_pc = pc + 'h4;
					end
					7'b0000001: begin	// MULHSU
						tmp128 = absXLEN(rs1_d) * inst.rs2()_d;
						tmp128 = twoscompXLENx2(rs1_d[`XLEN-1], tmp128);
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				3'b011: begin
					case (inst.funct7())
					7'b0000000: begin	// SLTU
						rf.write(rd0, rs1_d < inst.rs2()_d ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
						next_pc = pc + 'h4;
					end
					7'b0000001: begin	// MULHU
						tmp128 = rs1_d * inst.rs2()_d;
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				3'b100: begin
					case (inst.funct7())
					7'b0000000: begin	// XOR
					 	rf.write(rd0, rs1_d ^ inst.rs2()_d);
						next_pc = pc + 'h4;
					end
					7'b0000001: begin	// DIV
						tmp = absXLEN(rs1_d) / absXLEN(inst.rs2()_d);
						tmp = twoscompXLEN(rs1_d[`XLEN-1] ^ inst.rs2()_d[`XLEN-1], tmp);
						rf.write(rd0, inst.rs2()_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : tmp);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				3'b101: begin
					case (inst.funct7())
					7'b0000000: begin	// SRL
						rf.write(rd0, rs1_d >> inst.rs2()_d[5:0]);
						next_pc = pc + 'h4;
					end
					7'b0000001: begin	// DIVU
						rf.write(rd0, inst.rs2()_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : rs1_d / rs2_d);
						next_pc = pc + 'h4;
					end
					7'b0100000: begin	// SRA
						rf.write(rd0, $signed(rs1_d) >>> inst.rs2()_d[5:0]);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				3'b110: begin
					case (inst.funct7())
					7'b0000000: begin	// OR
						rf.write(rd0, rs1_d | inst.rs2()_d);
						next_pc = pc + 'h4;
					end
					7'b0000001: begin	// REM
						tmp = absXLEN(rs1_d) % absXLEN(inst.rs2()_d);
						tmp = twoscompXLEN(rs1_d[`XLEN/2-1], tmp);
						rf.write(rd0, inst.rs2()_d == {`XLEN{1'b0}} ? rs1_d : tmp);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				3'b111: begin
					case (inst.funct7())
					7'b0000000: begin	// AND
						rf.write(rd0, rs1_d & inst.rs2()_d);
						next_pc = pc + 'h4;
					end
					7'b0000001: begin	// REMU
						rf.write(rd0, inst.rs2()_d == {`XLEN{1'b0}} ? rs1_d : rs1_d % rs2_d);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				*/
				default:	id_we	= 1'b0;
				endcase
			end
			endcase
		end
		default:			id_we	= 1'b0;
		endcase
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			EX_VALID	<= 1'b0;
		end else begin
			EX_VALID	<= ID_VALID;
			EX_PC		<= ID_PC;
			EX_INSTR	<= ID_INSTR;

			WB_WE	<= id_we;
			WB_RD	<= FWD_RD;
			WB_CSRD	<= FWD_CSRD;
		end
	end
	always_comb begin
			EX_NEXT_PC= next_pc;
		if(ID_VALID && taken) begin
			EX_PC_WE  = 1'b1;
			OFLASH  = 1'b1;
		end else begin
			EX_PC_WE  = 1'b0;
			OFLASH  = 1'b0;
		end
	end

endmodule
