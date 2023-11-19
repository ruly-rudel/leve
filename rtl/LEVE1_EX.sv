
`include "defs.vh"

function [`XLEN-1:0] s32to64(input logic [31:0] in);
	return {{32{in[31]}}, in};
endfunction

module LEVE1_EX
(
	input				CLK,
	input		 		RSTn,

	input				IVALID,
	input [`XLEN-1:0]		IPC,
	input [31:0]			IINSTR,
	input [`XLEN-1:0]		IRS1,
	input [`XLEN-1:0]		IRS2,
	input [`XLEN-1:0]		ICSR,

	output logic [`XLEN-1:0]	ID_RD,
	output logic [`XLEN-1:0]	ID_CSRD,

	output logic			OVALID,
	output logic [`XLEN-1:0]	OPC,
	output logic [31:0]		OINSTR,

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
	logic [1:0]		op;
	logic [6:0]		opcode;
	logic [2:0]		funct3;
	logic [1:0]		csr_cmd;

	always_comb begin
		op	= IINSTR[1:0];
		opcode	= IINSTR[6:0];
		funct3	= IINSTR[14:12];
		imm_i	= {{20+32{IINSTR[31]}}, IINSTR[31:20]};
		imm_s	= {{20+32{IINSTR[31]}}, IINSTR[31:25], IINSTR[11:7]};
		imm_b	= {{19+32{IINSTR[31]}}, IINSTR[31], IINSTR[7], IINSTR[30:25], IINSTR[11:8], 1'b0};
		imm_u	= {{   32{IINSTR[31]}}, IINSTR[31:12], 12'h000};
		uimm_w	= {{`XLEN-5{1'b0}}, IINSTR[19:15]};

		csr_cmd	= opcode == 7'b11_100_11 ? funct3[1:0] : `CSR_NONE;
	end

	logic id_we;
	always_comb begin
		case(op)
		2'b11: begin
			case (opcode)
			7'b00_100_11: begin	// OP-IMM
				case (funct3)
				3'b000: begin								// ADDI
						id_we	= IVALID;
						ID_RD	= IRS1 + imm_i;
				end
				default:	id_we	= 1'b0;
				endcase
			end

			7'b11_100_11: begin	// SYSTEM
				case (funct3)
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
						id_we	= IVALID;
						ID_RD	= ICSR;
						ID_CSRD	= IRS1;
				end
				3'b010: begin		// CSRRS
						id_we	= IVALID;
						ID_RD	= ICSR;
						ID_CSRD	= IRS1;
				end
				3'b011: begin		// CSRRC
						id_we	= IVALID;
						ID_RD	= ICSR;
						ID_CSRD	= IRS1;
				end
				3'b101: begin		// CSRRWI
						id_we	= IVALID;
						ID_RD	= ICSR;
						ID_CSRD	= uimm_w;
				end
				3'b110: begin		// CSRRSI
						id_we	= IVALID;
						ID_RD	= ICSR;
						ID_CSRD	= uimm_w;
				end
				3'b111: begin		// CSRRCI
						id_we	= IVALID;
						ID_RD	= ICSR;
						ID_CSRD	= uimm_w;
				end
				default:	id_we	= 1'b0;
				endcase
			end

			7'b00_101_11: begin	// AUIPC
						id_we	= IVALID;
						ID_RD	= IPC + imm_u;
			end

			7'b00_110_11: begin	// OP-IMM-32
				case (funct3)
				3'b000: begin			// ADDIW
						id_we	= IVALID;
						ID_RD	= s32to64(IRS1[31:0] + imm_i[31:0]);
				end
				/*
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLIW
						rf.write32s(rd0, rs1_d[31:0] << shamt[4:0]);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLIW
						rf.write32s(rd0, rs1_d[31:0] >> shamt[4:0]);
						next_pc = pc + 'h4;
					end
					7'b0100000: begin	// SRAIW
						rf.write32s(rd0, $signed(rs1_d[31:0]) >>> shamt[4:0]);
						next_pc = pc + 'h4;
					end
					default: next_pc = raise_illegal_instruction(pc, inst);
					endcase
				end
				*/
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
			WB_RD	<= ID_RD;
			WB_CSRD	<= ID_CSRD;
		end
	end

endmodule
