
`include "defs.vh"

function [`XLEN-1:0] s32to64(input logic [31:0] in);
	return {{32{in[31]}}, in};
endfunction

module LEVE1_EX
(
	input				CLK,
	input		 		RSTn,

	input				IF_VALID,
	input				IF_READY,
	input [`XLEN-1:0]		IF_PC,

	input				IVALID,
	input [`XLEN-1:0]		IPC,
	input [31:0]			IINSTR,
	input [`XLEN-1:0]		IRS1,
	input [`XLEN-1:0]		IRS2,
	input [`XLEN-1:0]		ICSR,

	output logic [`XLEN-1:0]	FWD_RD,
	output logic [`XLEN-1:0]	FWD_CSRD,

	output logic			OVALID,
	output logic [`XLEN-1:0]	OPC,
	output logic [31:0]		OINSTR,

	output logic			OPC_WE,
	output logic [`XLEN-1:0]	ONEXT_PC,
	output logic			OFLASH,

	output logic			WB_WE,
	output logic [`XLEN-1:0]	WB_RD,
	output logic [`XLEN-1:0]	WB_CSRD
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

	always_comb begin
		op	= IINSTR[1:0];
		opcode	= IINSTR[6:0];
		funct3	= IINSTR[14:12];
		funct7	= IINSTR[31:25];
		rs1	= IINSTR[19:15];
		rs2	= IINSTR[24:20];
		imm_i	= {{20+32{IINSTR[31]}}, IINSTR[31:20]};
		imm_s	= {{20+32{IINSTR[31]}}, IINSTR[31:25], IINSTR[11:7]};
		imm_b	= {{19+32{IINSTR[31]}}, IINSTR[31], IINSTR[7], IINSTR[30:25], IINSTR[11:8], 1'b0};
		imm_u	= {{   32{IINSTR[31]}}, IINSTR[31:12], 12'h000};
		uimm_w	= {{`XLEN-5{1'b0}}, IINSTR[19:15]};
		shamt	= imm_i[5:0];

		mret	= opcode == 7'b11_100_11 && funct3 == 3'b000 && funct7 == 7'b0011000 && rs2 == 5'b00010;
		csr_cmd	= mret ? `CSR_WRITE : 
			  opcode == 7'b11_100_11 ? funct3[1:0] : `CSR_NONE;

		sie	= ICSR[1];
		mie	= ICSR[3];
		spie	= ICSR[5];
		ube	= ICSR[6];
		mpie	= ICSR[7];
		spp	= ICSR[8];
		vs	= ICSR[10:9];
		mpp	= ICSR[12:11];
		fs	= ICSR[14:13];
		xs	= ICSR[16:15];
		mprv	= ICSR[17];
		sum	= ICSR[18];
		mxr	= ICSR[19];
		tvm	= ICSR[20];
		tw	= ICSR[21];
		tsr	= ICSR[22];
		uxl	= ICSR[33:32];
		sxl	= ICSR[35:34];
		sbe	= ICSR[36];
		mbe	= ICSR[37];
		sd	= ICSR[63];
	end

	logic id_we;
	always_comb begin
						next_pc = IPC + 'h4;
						id_we	= IVALID;
		case(op)
		2'b11: begin
			case (opcode)
			7'b00_100_11: begin	// OP-IMM
				case (funct3)
				3'b000: 	FWD_RD	= IRS1 + imm_i;
				3'b001: case (funct7[6:1])
					6'b000000:
						FWD_RD	= IRS1 << shamt;
					default:id_we	= 1'b0;
					endcase
				3'b010:		FWD_RD	= $signed(IRS1) < $signed(imm_i) ? '1 : '0;
				3'b011:		FWD_RD	= IRS1 < imm_i ? '1 : '0;
				3'b100:		FWD_RD	= IRS1 ^ imm_i;
				3'b101: case (funct7[6:1])
					6'b000000:
						FWD_RD	= IRS1 >> shamt;
					6'b010000:
					       	FWD_RD	= $signed(IRS1) >>> shamt;
					default:id_we	= 0;
					endcase
				3'b110:		FWD_RD	= IRS1 | imm_i;
				3'b111:		FWD_RD	= IRS1 & imm_i;
				default:	id_we	= 0;
				endcase
			end

			7'b11_000_11: begin	// BRANCH
						id_we	= '0;
				case (funct3)
				3'b000: next_pc = IRS1 == IRS2 ? IPC + imm_b : IPC + 'h4;	// BEQ
				3'b001: next_pc = IRS1 != IRS2 ? IPC + imm_b : IPC + 'h4;
				3'b100: next_pc = $signed(IRS1) < $signed(IRS2) ? IPC + imm_b : IPC + 'h4;	// BLT
				3'b101: next_pc = $signed(IRS1) >= $signed(IRS2) ? IPC + imm_b : IPC + 'h4;	// BGE
				3'b110: next_pc = IRS1 < IRS2 ? IPC + imm_b : IPC + 'h4;	// BLTU
				3'b111: next_pc = IRS1 >= IRS2 ? IPC + imm_b : IPC + 'h4;	// BGEU
				default: next_pc = IPC + 'h4;
				endcase
			end

			7'b11_100_11: begin	// SYSTEM
						id_we	= IVALID;
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0011000: begin
						case(rs2)
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
							next_pc = IPC + 'h4;
						endcase
					end
					default:	next_pc = IPC + 'h4;
					endcase
				end
				/*
				3'b000: begin
					case (funct7)
					7'b0000000: begin
						case(rs2)
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
						case(rs2)
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
						case(rs2)
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
							case (rs2)
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
						FWD_RD		= ICSR;
						FWD_CSRD	= IRS1;
				end
				3'b010: begin		// CSRRS
						FWD_RD		= ICSR;
						FWD_CSRD	= IRS1;
				end
				3'b011: begin		// CSRRC
						FWD_RD		= ICSR;
						FWD_CSRD	= IRS1;
				end
				3'b101: begin		// CSRRWI
						FWD_RD		= ICSR;
						FWD_CSRD	= uimm_w;
				end
				3'b110: begin		// CSRRSI
						FWD_RD		= ICSR;
						FWD_CSRD	= uimm_w;
				end
				3'b111: begin		// CSRRCI
						FWD_RD		= ICSR;
						FWD_CSRD	= uimm_w;
				end
				default:	id_we	= 1'b0;
				endcase
			end

			7'b00_101_11: begin	// AUIPC
						id_we	= IVALID;
						FWD_RD	= IPC + imm_u;
			end

			7'b00_110_11: begin	// OP-IMM-32
						id_we	= IVALID;
				case (funct3)
				3'b000: FWD_RD	= s32to64(IRS1[31:0] + imm_i[31:0]);	// ADDIW
				3'b001: begin
					case (funct7)
					7'b0000000:
						FWD_RD	= s32to64(IRS1[31:0] << shamt[4:0]); // SLLIW
					default:id_we	= 1'b0;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000:
						FWD_RD	= s32to64(IRS1[31:0] >> shamt[4:0]); // SRLIW
					7'b0100000:
						FWD_RD	= s32to64($signed(IRS1[31:0]) >>> shamt[4:0]); // SRAIW
					default:id_we	= 1'b0;
					endcase
				end
				default:	id_we	= 1'b0;
				endcase
			end

			default:		id_we	= 1'b0;
			endcase
		end
		default:			id_we	= 1'b0;
		endcase
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			OVALID	<= 1'b0;
		end else begin
			OVALID	<= IVALID;
			OPC	<= IPC;
			OINSTR	<= IINSTR;

			WB_WE	<= id_we;
			WB_RD	<= FWD_RD;
			WB_CSRD	<= FWD_CSRD;
		end
	end
	always_comb begin
			ONEXT_PC= next_pc;
		if(IF_VALID && IF_READY && IVALID && IF_PC != next_pc) begin
			OPC_WE  = 1'b1;
			OFLASH  = 1'b1;
		end else begin
			OPC_WE  = 1'b0;
			OFLASH  = 1'b0;
		end
	end

endmodule
