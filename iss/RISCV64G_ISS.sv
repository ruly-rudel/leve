
`include "defs.vh"

function [`XLEN-1:0]	twoscompXLEN(input sign, input [`XLEN-1:0] i);
begin
	if(sign) begin
		twoscompXLEN = ~i + 'b1;
	end else begin
		twoscompXLEN = i;
	end
end
endfunction

function [`XLEN/2-1:0]	twoscompXLENh(input sign, input [`XLEN/2-1:0] i);
begin
	if(sign) begin
		twoscompXLENh = ~i + 'b1;
	end else begin
		twoscompXLENh = i;
	end
end
endfunction

function [`XLEN*2-1:0]	twoscompXLENx2(input sign, input [`XLEN*2-1:0] i);
begin
	if(sign) begin
		twoscompXLENx2 = ~i + 'b1;
	end else begin
		twoscompXLENx2 = i;
	end
end

endfunction

function [`XLEN-1:0]	absXLEN(input [`XLEN-1:0] i);
begin
	absXLEN = twoscompXLEN(i[`XLEN-1], i);
end
endfunction

function [`XLEN/2-1:0]	absXLENh(input [`XLEN/2-1:0] i);
begin
	absXLENh = twoscompXLENh(i[`XLEN/2-1], i);
end
endfunction

class CSR;
	logic [`XLEN-1:0]		csr_reg[0:`NUM_CSR-1];

	function void init();
		for(integer i = 0; i < `NUM_CSR; i = i + 1) begin
			csr_reg[i] = {`XLEN{1'b0}};
		end
	endfunction

	function void write (input [12-1:0] addr, input [`XLEN-1:0] data);
		case (addr)
			12'h001: begin	// fflags
				csr_reg[12'h001] = {csr_reg[12'h001][`XLEN-1:5], data[4:0]};
				csr_reg[12'h003] = {csr_reg[12'h003][`XLEN-1:5], data[4:0]};
			end
			12'h002: begin	// frm
				csr_reg[12'h002] = {csr_reg[12'h002][`XLEN-1:3], data[2:0]};
				csr_reg[12'h003] = {csr_reg[12'h003][`XLEN-1:8], data[2:0], csr_reg[12'h003][4:0]};
			end
			12'h003: begin	// fcsr
				csr_reg[12'h001] = {csr_reg[12'h001][`XLEN-1:5], data[4:0]};
				csr_reg[12'h002] = {csr_reg[12'h002][`XLEN-1:3], data[7:5]};
				csr_reg[12'h003] = {csr_reg[12'h003][`XLEN-1:8], data[7:0]};
			end
			default: csr_reg[addr] = data;
		endcase
	endfunction

	function [`XLEN-1:0] read (input [12-1:0] addr);
		return csr_reg[addr];
	endfunction

	function void set (input [12-1:0] addr, input [`XLEN-1:0] data);
		write(addr, read(addr) | data);
	endfunction

	function void clear (input [12-1:0] addr, input [`XLEN-1:0] data);
		write(addr, read(addr) & ~data);
	endfunction

	function void set_fflags(input [4:0] fflags);
		csr_reg[12'h001] = {csr_reg[12'h001][`XLEN-1:5], fflags};
		csr_reg[12'h003] = {csr_reg[12'h003][`XLEN-1:5], fflags};
	endfunction

endclass : CSR;

class REG_FILE;
	logic [`XLEN-1:0]		reg_file[0:`NUM_REG-1];

	function void write (input [4:0] addr, input [`XLEN-1:0] data);
		if(addr != 5'h00) reg_file[addr] = data;
	endfunction

	function void write32u (input [4:0] addr, input [32-1:0] data);
		if(addr != 5'h00) reg_file[addr] = {{32{1'b0}}, data};
	endfunction

	function void write32s (input [4:0] addr, input [32-1:0] data);
		if(addr != 5'h00) reg_file[addr] = {{32{data[31]}}, data};
	endfunction

	function void write16u (input [4:0] addr, input [16-1:0] data);
		reg_file[addr] = {{48{1'b0}}, data};
	endfunction

	function void write16s (input [4:0] addr, input [16-1:0] data);
		reg_file[addr] = {{48{data[15]}}, data};
	endfunction

	function void write8u (input [4:0] addr, input [8-1:0] data);
		reg_file[addr] = {{56{1'b0}}, data};
	endfunction

	function void write8s (input [4:0] addr, input [8-1:0] data);
		reg_file[addr] = {{56{data[7]}}, data};
	endfunction

	function [`XLEN-1:0] read (input [4:0] addr);
		return reg_file[addr];
	endfunction

	function [32-1:0] read32 (input [4:0] addr);
		return reg_file[addr][31:0];
	endfunction
endclass : REG_FILE;

class REG_FILE_FP;
	logic [`FLEN-1:0]		reg_file[0:`FP_NUM_REG-1];

	function void write (input [4:0] addr, input [`XLEN-1:0] data);
		reg_file[addr] = data;
	endfunction

	function void write32u (input [4:0] addr, input [32-1:0] data);
		reg_file[addr] = {{32{1'b0}}, data};
	endfunction

	function [`XLEN-1:0] read (input [4:0] addr);
		return reg_file[addr];
	endfunction

	function [32-1:0] read32 (input [4:0] addr);
		return reg_file[addr][31:0];
	endfunction
endclass : REG_FILE_FP;


class MEMORY;
	logic [32-1:0]			mem[] = new [1024*1024*4];

	function new(string filename);
		integer fd;
		integer ret;
		integer i = 0;
		string str;
		$display("[MEMORY] read %s", filename);
		fd = $fopen(filename, "r");
		if(fd == 0) begin
			$display("[MEMORY] file open fails: %s", filename);
			$finish;
		end

		while (!$feof(fd)) begin
			ret = $fgets(str, fd);
			if(ret == 0) begin
				$display("[MEMORY] file read fails: %s, line %d", filename, i);
			end else begin
				mem[i++] = str.atohex();
			end
		end

		$fclose(fd);
		$display("[MEMORY] read finish.");

	endfunction

	function void write (input [`XLEN-1:0] addr, input [`XLEN-1:0] data);
		mem[addr[24-1:2]] = data[31:0];
		mem[addr[24-1:2] + 22'h1] = data[63:32];
	endfunction

	function void write32 (input [`XLEN-1:0] addr, input [32-1:0] data);
		mem[addr[24-1:2]] = data;
	endfunction

	function void write16 (input [`XLEN-1:0] addr, input [16-1:0] data);
		logic [31:0]	tmp32;
		tmp32 = mem[addr[22-1:2]];
		case (addr[1])
			1'b0 : mem[addr[24-1:2]] = {tmp32[31:16], data};
			1'b1 : mem[addr[24-1:2]] = {data[15:0], tmp32[15:0]};
		endcase
	endfunction

	function void write8 (input [`XLEN-1:0] addr, input [8-1:0] data);
		logic [31:0]	tmp32;
		tmp32 = mem[addr[24-1:2]];
		case (addr[1:0])
			2'h0 : mem[addr[24-1:2]] = {tmp32[31:8], data};
			2'h1 : mem[addr[24-1:2]] = {tmp32[31:16], data, tmp32[7:0]};
			2'h2 : mem[addr[24-1:2]] = {tmp32[31:24], data, tmp32[15:0]};
			2'h3 : mem[addr[24-1:2]] = {data, tmp32[23:0]};
		endcase
	endfunction

	function [`XLEN-1:0] read (input [`XLEN-1:0] addr);
		return {mem[addr[24-1:2] + 22'h1], mem[addr[22-1:2]]};
	endfunction

	function [32-1:0] read32 (input [`XLEN-1:0] addr);
		return mem[addr[24-1:2]];
	endfunction

	function [16-1:0] read16 (input [`XLEN-1:0] addr);
		case(addr[1])
			1'h0 : return mem[addr[24-1:2]][15:0];
			1'h1 : return mem[addr[24-1:2]][31:16];
		endcase
	endfunction

	function [8-1:0] read8 (input [`XLEN-1:0] addr);
		case(addr[1:0])
			2'h0 : return mem[addr[24-1:2]][7:0];
			2'h1 : return mem[addr[24-1:2]][15:8];
			2'h2 : return mem[addr[24-1:2]][23:16];
			2'h3 : return mem[addr[24-1:2]][31:24];
		endcase
	endfunction

endclass : MEMORY;




module RISCV64G_ISS (
	input			CLK,
	input			RSTn,

	input string		init_file,
	output reg		tohost_we,
	output reg [32-1:0]	tohost
);
	MEMORY			mem = new(init_file);

	// PC
	reg  [`XLEN-1:0]	pc;

	wire [32-1:0]		inst;
	wire [6:0]		opcode;
	wire [4:0]		rd0;
	wire [2:0]		funct3;
	wire [4:0]		rs1;
	wire [4:0]		rs2;
	wire [4:0]		rs3;
	wire [6:0]		funct7;
	wire [4:0]		funct5;
	wire [1:0]		funct2;
	wire			aq;
	wire			rl;
	wire [2:0]		rm;
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
	wire [`FLEN-1:0]	fp_rs1_d;
	wire [`FLEN-1:0]	fp_rs2_d;
	wire [`FLEN-1:0]	fp_rs3_d;

	wire [31:0]		fadd_f_d;
	wire [31:0]		fsub_f_d;
	wire [31:0]		fmul_f_d;
	wire [31:0]		fclass_f_d;
	wire [31:0]		fcvt_w_s_d;
	wire [31:0]		fcvt_wu_s_d;
	wire [63:0]		fcvt_l_s_d;
	wire [63:0]		fcvt_lu_s_d;
	wire [31:0]		fcvt_s_w_d;
	wire [31:0]		fcvt_s_wu_d;
	wire [31:0]		fcvt_s_l_d;
	wire [31:0]		fcvt_s_lu_d;
	wire [31:0]		fmin_f_d;
	wire [31:0]		fmax_f_d;

	wire			fcmp_f_eq;
	wire			fcmp_f_lt;
	wire			fcmp_f_le;

	wire			fadd_f_inexact;
	wire			fsub_f_inexact;
	wire			fmul_f_inexact;
	wire			fcvt_w_s_inexact;
	wire			fcvt_wu_s_inexact;
	wire			fcvt_l_s_inexact;
	wire			fcvt_lu_s_inexact;
	wire			fcvt_s_w_inexact;
	wire			fcvt_s_wu_inexact;
	wire			fcvt_s_l_inexact;
	wire			fcvt_s_lu_inexact;

	wire			fadd_f_invalid;
	wire			fsub_f_invalid;
	wire			fmul_f_invalid;
	wire			fcmp_f_eq_invalid;
	wire			fcmp_f_lt_invalid;
	wire			fcvt_w_s_invalid;
	wire			fcvt_wu_s_invalid;
	wire			fcvt_l_s_invalid;
	wire			fcvt_lu_s_invalid;
	wire			fmin_f_invalid;
	wire			fmax_f_invalid;



	// registers
	REG_FILE	rf = new();
	REG_FILE_FP	fp = new();
	CSR		csr_c = new();

	logic [`XLEN-1:0]	rf_1_ra;
	logic [`XLEN-1:0]	rf_2_sp;
	logic [`XLEN-1:0]	rf_3_gp;
	logic [`XLEN-1:0]	rf_4_tp;
	logic [`XLEN-1:0]	rf_5_t0;
	logic [`XLEN-1:0]	rf_6_t1;
	logic [`XLEN-1:0]	rf_7_t2;
	logic [`XLEN-1:0]	rf_8_s0;
	logic [`XLEN-1:0]	rf_9_s1;
	logic [`XLEN-1:0]	rf_10_a0;
	logic [`XLEN-1:0]	rf_11_a1;
	logic [`XLEN-1:0]	rf_12_a2;
	logic [`XLEN-1:0]	rf_13_a3;
	logic [`XLEN-1:0]	rf_14_a4;
	logic [`XLEN-1:0]	rf_15_a5;
	logic [`XLEN-1:0]	rf_16_a6;
	logic [`XLEN-1:0]	rf_17_a7;
	logic [`XLEN-1:0]	rf_18_s2;
	logic [`XLEN-1:0]	rf_19_s3;
	logic [`XLEN-1:0]	rf_20_s4;
	logic [`XLEN-1:0]	rf_21_s5;
	logic [`XLEN-1:0]	rf_22_s6;
	logic [`XLEN-1:0]	rf_23_s7;
	logic [`XLEN-1:0]	rf_24_s8;
	logic [`XLEN-1:0]	rf_25_s9;
	logic [`XLEN-1:0]	rf_26_s10;
	logic [`XLEN-1:0]	rf_27_s11;
	logic [`XLEN-1:0]	rf_28_t3;
	logic [`XLEN-1:0]	rf_29_t4;
	logic [`XLEN-1:0]	rf_30_t5;
	logic [`XLEN-1:0]	rf_31_t6;

	logic [`FLEN-1:0]	fp_0;
	logic [`FLEN-1:0]	fp_1;
	logic [`FLEN-1:0]	fp_2;
	logic [`FLEN-1:0]	fp_3;
	logic [`FLEN-1:0]	fp_4;
	logic [`FLEN-1:0]	fp_5;
	logic [`FLEN-1:0]	fp_6;
	logic [`FLEN-1:0]	fp_7;
	logic [`FLEN-1:0]	fp_8;
	logic [`FLEN-1:0]	fp_9;
	logic [`FLEN-1:0]	fp_10;
	logic [`FLEN-1:0]	fp_11;
	logic [`FLEN-1:0]	fp_12;
	logic [`FLEN-1:0]	fp_13;
	logic [`FLEN-1:0]	fp_14;
	logic [`FLEN-1:0]	fp_15;
	logic [`FLEN-1:0]	fp_16;
	logic [`FLEN-1:0]	fp_17;
	logic [`FLEN-1:0]	fp_18;
	logic [`FLEN-1:0]	fp_19;
	logic [`FLEN-1:0]	fp_20;
	logic [`FLEN-1:0]	fp_21;
	logic [`FLEN-1:0]	fp_22;
	logic [`FLEN-1:0]	fp_23;
	logic [`FLEN-1:0]	fp_24;
	logic [`FLEN-1:0]	fp_25;
	logic [`FLEN-1:0]	fp_26;
	logic [`FLEN-1:0]	fp_27;
	logic [`FLEN-1:0]	fp_28;
	logic [`FLEN-1:0]	fp_29;
	logic [`FLEN-1:0]	fp_30;
	logic [`FLEN-1:0]	fp_31;

	// LR/WC register
	reg 			lrsc_valid;
	reg [`XLEN-1:0]		lrsc_addr;

	// 1. instruction fetch
	//assign inst   = mem[pc[22-1:2]];
	assign inst   = mem.read32(pc);
	
	assign opcode = inst[6:0];
	assign rd0    = inst[11:7];
	assign funct3 = inst[14:12];
	assign rs1    = inst[19:15];
	assign rs2    = inst[24:20];
	assign rs3    = inst[31:27];
	assign funct7 = inst[31:25];
	assign funct5 = inst[31:27];
	assign funct2 = inst[26:25];
	assign aq     = inst[26];
	assign rl     = inst[25];
	assign rm     = inst[14:12];
	
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
	assign	rs1_d    = rf.read(rs1);
	assign	rs2_d    = rf.read(rs2);
	assign	fp_rs1_d = fp.read(rs1);
	assign	fp_rs2_d = fp.read(rs2);
	assign	fp_rs3_d = fp.read(rs3);


	// floating point arithmetics
	FADD_F	FADD_F
	(
		.in1		(fp_rs1_d[31:0]),
		.in2		(fp_rs2_d[31:0]),
		.out		(fadd_f_d),
		.inexact	(fadd_f_inexact),
		.invalid	(fadd_f_invalid)
	);

	FADD_F	FSUB_F
	(
		.in1		(fp_rs1_d[31:0]),
		.in2		({~fp_rs2_d[31], fp_rs2_d[30:0]}),
		.out		(fsub_f_d),
		.inexact	(fsub_f_inexact),
		.invalid	(fsub_f_invalid)
	);
	
	FMUL_F	FMUL_F
	(
		.in1		(fp_rs1_d[31:0]),
		.in2		(fp_rs2_d[31:0]),
		.out		(fmul_f_d),
		.inexact	(fmul_f_inexact),
		.invalid	(fsub_f_invalid)
	);

	FCLASS_F	FCLASS_F
	(
		.in1		(fp_rs1_d[31:0]),
		.out		(fclass_f_d)
	);

	FCMP_F		FCMP_F
	(
		.in1		(fp_rs1_d[31:0]),
		.in2		(fp_rs2_d[31:0]),

		.eq		(fcmp_f_eq),
		.lt		(fcmp_f_lt),
		.le		(fcmp_f_le),

		.eq_invalid	(fcmp_f_eq_invalid),
		.lt_invalid	(fcmp_f_lt_invalid)
	);

	FCVT_W_S	FCVT_W_S
	(
		.in1		(fp_rs1_d[31:0]),
		.out1		(fcvt_w_s_d),
		.inexact	(fcvt_w_s_inexact),
		.invalid	(fcvt_w_s_invalid)
	);

	FCVT_WU_S	FCVT_WU_S
	(
		.in1		(fp_rs1_d[31:0]),
		.out1		(fcvt_wu_s_d),
		.inexact	(fcvt_wu_s_inexact),
		.invalid	(fcvt_wu_s_invalid)
	);

	FCVT_W_S
	#(
		.I_WIDTH	(64)
	)
	FCVT_L_S
	(
		.in1		(fp_rs1_d[31:0]),
		.out1		(fcvt_l_s_d),
		.inexact	(fcvt_l_s_inexact),
		.invalid	(fcvt_l_s_invalid)
	);

	FCVT_WU_S
	#(
		.I_WIDTH	(64)
	)
	FCVT_LU_S
	(
		.in1		(fp_rs1_d[31:0]),
		.out1		(fcvt_lu_s_d),
		.inexact	(fcvt_lu_s_inexact),
		.invalid	(fcvt_lu_s_invalid)
	);

	FCVT_S_W	FCVT_S_W
	(
		.in1		(rs1_d[31:0]),
		.out1		(fcvt_s_w_d),
		.inexact	(fcvt_s_w_inexact)
	);

	FCVT_S_WU	FCVT_S_WU
	(
		.in1		(rs1_d[31:0]),
		.out1		(fcvt_s_wu_d),
		.inexact	(fcvt_s_wu_inexact)
	);

	FCVT_S_L	FCVT_S_L
	(
		.in1		(rs1_d),
		.out1		(fcvt_s_l_d),
		.inexact	(fcvt_s_l_inexact)
	);

	FCVT_S_LU	FCVT_S_LU
	(
		.in1		(rs1_d),
		.out1		(fcvt_s_lu_d),
		.inexact	(fcvt_s_lu_inexact)
	);

	FMIN_F	FMIN_F
	(
		.in1		(fp_rs1_d[31:0]),
		.in2		(fp_rs2_d[31:0]),
		.min		(fmin_f_d),
		.invalid	(fmin_f_invalid)
	);

	FMAX_F	FMAX_F
	(
		.in1		(fp_rs1_d[31:0]),
		.in2		(fp_rs2_d[31:0]),
		.max		(fmax_f_d),
		.invalid	(fmax_f_invalid)
	);


	// main loop
	always_ff @(posedge CLK or negedge RSTn)
	begin
		logic [`XLEN-1:0]	tmp;
		logic [32-1:0]		tmp32;
		logic [`XLEN*2-1:0]	tmp128;

		if(!RSTn) begin
			csr_c.init();

			// pc
			pc <= 64'h0000_0000_8000_0000;

			lrsc_valid <= 1'b0;

			tohost_we = 1'b0;
		end else begin
			// reset csr_we
			tohost_we = 1'b0;

			// execute and write back
			case (opcode)
			7'b00_000_11: begin	// LOAD: I type
				case (funct3)
				3'b000: begin			// LB
						rf.write8s(rd0, mem.read8(rs1_d + imm_iw));
				end
				3'b001: begin			// LH
						rf.write16s(rd0, mem.read16(rs1_d + imm_iw));
				end
				3'b010: begin			// LW
						rf.write32s(rd0, mem.read32(rs1_d + imm_iw));
				end
				3'b011: begin			// LD
						rf.write(rd0, mem.read(rs1_d + imm_iw));
				end
				3'b100: begin			// LBU
						rf.write8u(rd0, mem.read8(rs1_d + imm_iw));
				end
				3'b101: begin			// LHU
						rf.write16u(rd0, mem.read16(rs1_d + imm_iw));
				end
				3'b110: begin			// LWU
						rf.write32u(rd0, mem.read32(rs1_d + imm_iw));
				end
				default: ;
				endcase
			end

			7'b01_000_11: begin	// STORE: S type
				case (funct3)
				3'b000: begin			// SB
						mem.write8(rs1_d + imm_sw, rs2_d[7:0]);
				end
				3'b001: begin			// SH
						mem.write16(rs1_d + imm_sw, rs2_d[15:0]);
				end
				3'b010: begin			// SW
						mem.write32(rs1_d + imm_sw, rs2_d[31:0]);
						tohost_we  = pc == 64'h0000_0000_8000_0040 ? 1'b1 : 1'b0;	// for testbench hack
						tohost     = rs2_d[31:0];
				end
				3'b011: begin			// SD
						mem.write(rs1_d + imm_sw, rs2_d);
				end
				default: ;
				endcase
			end

			7'b10_000_11: begin	// MADD
			end

			// 7'b11_000_11:	// BRANCH

			7'b00_001_11: begin	// LOAD-FP
				case (funct3)
				3'b010: begin			// FLW
						fp.write32u(rd0, mem.read32(rs1_d + imm_iw));
				end
				default: ;
				endcase
			end

			7'b01_001_11: begin	// STORE-FP
				case (funct3)
				3'b010: begin			// FSW
						mem.write32(rs1_d + imm_sw, fp_rs2_d[31:0]);
				end
				default: ;
				endcase
			end

			7'b10_001_11: begin	// MSUB
			end

			7'b11_001_11: begin	// JALR
				case (funct3)
				3'b000: begin
						rf.write(rd0, pc + 'h4);
				end
				default: ;
				endcase
			end

			7'b01_010_11: begin	// NMSUB
			end

			// 7'b00_011_11:	// MISC-MEM

			7'b01_011_11: begin	// AMO
				case (funct3)
				3'b010: begin
					case (funct5)
					5'b00010: begin		// LR.W
						lrsc_valid <= 1'b1;
						lrsc_addr  <= rs1_d;
						rf.write32s(rd0, mem.read32(rs1_d));
					end
					5'b00011: begin		// SC.W
						if(lrsc_valid && lrsc_addr == rs1_d) begin
							lrsc_valid <= 1'b0;
							tmp32 = mem.read32(rs1_d);
							rf.write(rd0, {`XLEN{1'b0}});
							mem.write32(rs1_d, rs2_d[31:0]);
						end else begin
							rf.write(rd0, {{`XLEN-1{1'b0}}, 1'b1});
						end
					end
					5'b00001: begin		// AMOSWAP.W
						rf.write32s(rd0, mem.read32(rs1_d));
						mem.write32(rs1_d, rs2_d[31:0]);
					end
					5'b00000: begin		// AMOADD.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] + tmp32);
					end
					5'b00100: begin		// AMOXOR.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] ^ tmp32);
					end
					5'b01100: begin		// AMOAND.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] & tmp32);
					end
					5'b01000: begin		// AMOOR.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] | tmp32);
					end
					5'b10000: begin		// AMOMIN.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, $signed(rs2_d[31:0]) < $signed(tmp32) ? rs2_d[31:0] : tmp32);
					end
					5'b10100: begin		// AMOMAX.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, $signed(rs2_d[31:0]) > $signed(tmp32) ? rs2_d[31:0] : tmp32);
					end
					5'b11000: begin		// AMOMINU.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] < tmp32 ? rs2_d[31:0] : tmp32);
					end
					5'b11100: begin		// AMOMAXU.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] > tmp32 ? rs2_d[31:0] : tmp32);
					end
					default: ;
					endcase
				end
				3'b011: begin
					case (funct5)
					5'b00010: begin		// LR.D
					end
					5'b00011: begin		// SC.D
					end
					5'b00001: begin		// AMOSWAP.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						mem.write(rs1_d, rs2_d);
					end
					5'b00000: begin		// AMOADD.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						mem.write(rs1_d, rs2_d + tmp);
					end
					5'b00100: begin		// AMOXOR.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d ^ tmp;
						mem.write(rs1_d, tmp);
					end
					5'b01100: begin		// AMOAND.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d & tmp;
						mem.write(rs1_d, tmp);
					end
					5'b01000: begin		// AMOOR.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d | tmp;
						mem.write(rs1_d, tmp);
					end
					5'b10000: begin		// AMOMIN.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = $signed(rs2_d) < $signed(tmp) ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
					end
					5'b10100: begin		// AMOMAX.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = $signed(rs2_d) > $signed(tmp) ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
					end
					5'b11000: begin		// AMOMINU.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d < tmp ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
					end
					5'b11100: begin		// AMOMAXU.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d > tmp ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b10_011_11: begin	// NMADD
			end

			7'b11_011_11: begin	// JAL
						rf.write(rd0, pc + 'h4);
			end

			7'b00_100_11: begin	// OP-IMM
				case (funct3)
				3'b000: begin								// ADDI
						rf.write(rd0, rs1_d + imm_iw);
				end
				3'b001: begin
					case (funct7[6:1])
					6'b000000: begin						// SLLI
						rf.write(rd0, rs1_d << shamt);
					end
					default: ;
					endcase
				end
				3'b010: 	rf.write(rd0, $signed(rs1_d) < $signed(imm_iw) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});	// SLTI
				3'b011: 	rf.write(rd0, rs1_d < imm_iw ? {{63{1'b0}}, 1'b1} : {64{1'b0}});	// SLTIU
				3'b100: 	rf.write(rd0, rs1_d ^ imm_iw);				// XORI
				3'b101: begin
					case (funct7[6:1])
					6'b000000: begin						// SRLI
						rf.write(rd0, rs1_d >> shamt);
					end
					6'b010000: begin						// SRAI
						rf.write(rd0, $signed(rs1_d) >>> shamt);
					end
					default: ;
					endcase
				end
				3'b110: 	rf.write(rd0, rs1_d | imm_iw);				// ORI
				3'b111: 	rf.write(rd0, rs1_d & imm_iw);				// ANDI
				default: ;
				endcase
			end

			7'b01_100_11: begin	// OP
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: begin	// ADD
						rf.write(rd0, rs1_d + rs2_d);
					end
					7'b0000001: begin	// MUL
						tmp128 = rs1_d * rs2_d;
						rf.write(rd0, tmp128[`XLEN-1:0]);
					end
					7'b0100000: begin	// SUB
						rf.write(rd0, rs1_d - rs2_d);
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLL
						rf.write(rd0, rs1_d << rs2_d[5:0]);
					end
					7'b0000001: begin	// MULH
						tmp128 = $signed(rs1_d) * $signed(rs2_d);
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
					end
					default: ;
					endcase
				end
				3'b010: begin
					case (funct7)
					7'b0000000: begin	// SLT
						rf.write(rd0, $signed(rs1_d) < $signed(rs2_d) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
					end
					7'b0000001: begin	// MULHSU
						tmp128 = absXLEN(rs1_d) * rs2_d;
						tmp128 = twoscompXLENx2(rs1_d[`XLEN-1], tmp128);
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
					end
					default: ;
					endcase
				end
				3'b011: begin
					case (funct7)
					7'b0000000: begin	// SLTU
						rf.write(rd0, rs1_d < rs2_d ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
					end
					7'b0000001: begin	// MULHU
						tmp128 = rs1_d * rs2_d;
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
					end
					default: ;
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b0000000: begin	// XOR
					 	rf.write(rd0, rs1_d ^ rs2_d);
					end
					7'b0000001: begin	// DIV
						tmp = absXLEN(rs1_d) / absXLEN(rs2_d);
						tmp = twoscompXLEN(rs1_d[`XLEN-1] ^ rs2_d[`XLEN-1], tmp);
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : tmp);
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRL
						rf.write(rd0, rs1_d >> rs2_d[5:0]);
					end
					7'b0000001: begin	// DIVU
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : rs1_d / rs2_d);
					end
					7'b0100000: begin	// SRA
						rf.write(rd0, $signed(rs1_d) >>> rs2_d[5:0]);
					end
					default: ;
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b0000000: begin	// OR
						rf.write(rd0, rs1_d | rs2_d);
					end
					7'b0000001: begin	// REM
						tmp = absXLEN(rs1_d) % absXLEN(rs2_d);
						tmp = twoscompXLEN(rs1_d[`XLEN/2-1], tmp);
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d : tmp);
					end
					default: ;
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000000: begin	// AND
						rf.write(rd0, rs1_d & rs2_d);
					end
					7'b0000001: begin	// REMU
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d : rs1_d % rs2_d);
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b10_100_11: begin	// OP-FP: R type
				case(funct7)
				7'b00000_00: begin		// FADD.S
						fp.write32u(rd0, fadd_f_d);
						csr_c.set_fflags({fadd_f_invalid, 3'h0, fadd_f_inexact});
				end
				7'b00001_00: begin		// FSUB.S
						fp.write32u(rd0, fsub_f_d);
						csr_c.set_fflags({fsub_f_invalid, 3'h0, fsub_f_inexact});
				end
				7'b00010_00: begin		// FMUL.S
						fp.write32u(rd0, fmul_f_d);
						csr_c.set_fflags({fmul_f_invalid, 3'h0, fmul_f_inexact});
				end
				7'b00011_00: begin		// FDIV.S
				end
				7'b01011_00: begin
					case (rs2)
					5'b00000: begin		// FSQRT.S
					end
					default: ;
					endcase
				end
				7'b00100_00: begin
					case (funct3)
					3'b000: begin		// FSGNJ.S
						tmp32 = fp.read32(rs2);
						if(tmp32[31]) begin
							tmp32 = fp.read32(rs1);
							fp.write32u(rd0, {1'b1, tmp32[30:0]});
						end else begin
							tmp32 = fp.read32(rs1);
							fp.write32u(rd0, {1'b0, tmp32[30:0]});
						end
					end
					3'b001: begin		// FSGNJN.S
						tmp32 = fp.read32(rs2);
						if(tmp32[31]) begin
							tmp32 = fp.read32(rs1);
							fp.write32u(rd0, {1'b0, tmp32[30:0]});
						end else begin
							tmp32 = fp.read32(rs1);
							fp.write32u(rd0, {1'b1, tmp32[30:0]});
						end
					end
					3'b010: begin		// FSGNJX.S
						tmp32 = fp.read32(rs2);
						if(tmp32[31]) begin
							tmp32 = fp.read32(rs1);
							fp.write32u(rd0, {1'b1 ^ tmp32[31], tmp32[30:0]});
						end else begin
							tmp32 = fp.read32(rs1);
							fp.write32u(rd0, {1'b0 ^ tmp32[31], tmp32[30:0]});
						end
					end
					default: ;
					endcase
				end
				7'b00101_00: begin
					case (funct3)
					3'b000: begin		// FMIN.S
						fp.write32u(rd0, fmin_f_d);
						csr_c.set_fflags({fmin_f_invalid, 4'h0});
					end
					3'b001: begin		// FMAX.S
						fp.write32u(rd0, fmax_f_d);
						csr_c.set_fflags({fmax_f_invalid, 4'h0});
					end
					default: ;
					endcase
				end
				7'b11000_00: begin
					case (rs2)
					5'b00000: begin		// FCVT.W.S
							rf.write32s(rd0, fcvt_w_s_d[31:0]);
							csr_c.set_fflags({fcvt_w_s_invalid, 3'h0, fcvt_w_s_inexact});
					end
					5'b00001: begin		// FCVT.WU.S
							rf.write32s(rd0, fcvt_wu_s_d[31:0]);
							csr_c.set_fflags({fcvt_wu_s_invalid, 3'h0, fcvt_wu_s_inexact});
					end
					5'b00010: begin		// FCVT.L.S
							rf.write(rd0, fcvt_l_s_d);
							csr_c.set_fflags({fcvt_l_s_invalid, 3'h0, fcvt_l_s_inexact});
					end
					5'b00011: begin		// FCVT.LU.S
							rf.write(rd0, fcvt_lu_s_d);
							csr_c.set_fflags({fcvt_lu_s_invalid, 3'h0, fcvt_lu_s_inexact});
					end
					default: ;
					endcase
				end
				7'b11100_00: begin
					case (rs2)
					5'b00000: begin
						case (funct3)
						3'b000: begin	// FMV.X.W
							rf.write32s(rd0, fp_rs1_d[31:0]);
						end
						3'b001: begin	// FCLASS.W
							rf.write32u(rd0, fclass_f_d);
						end
						default: ;
						endcase
					end
					default: ;
					endcase
				end
				7'b10100_00: begin
					case (funct3)
					3'b010: begin 		// FEQ.S
							rf.write(rd0, {{63{1'b0}}, fcmp_f_eq});
							csr_c.set_fflags({fcmp_f_eq_invalid, 4'h0});
					end
					3'b001: begin 		// FLT.S
							rf.write(rd0, {{63{1'b0}}, fcmp_f_lt});
							csr_c.set_fflags({fcmp_f_lt_invalid, 4'h0});
					end
					3'b000: begin		// FLE.S
							rf.write(rd0, {{63{1'b0}}, fcmp_f_le});
							csr_c.set_fflags({fcmp_f_lt_invalid, 4'h0});
					end
					default: ;
					endcase
				end
				7'b11010_00: begin
					case (rs2)
					5'b00000: begin		// FCVT.S.W
							fp.write32u(rd0, fcvt_s_w_d);
							csr_c.set_fflags({4'h0, fcvt_s_w_inexact});
					end
					5'b00001: begin		// FCVT.S.WU
							fp.write32u(rd0, fcvt_s_wu_d);
							csr_c.set_fflags({4'h0, fcvt_s_wu_inexact});
					end
					5'b00010: begin		// FCVT.S.L
							fp.write32u(rd0, fcvt_s_l_d);
							csr_c.set_fflags({4'h0, fcvt_s_l_inexact});
					end
					5'b00011: begin		// FCVT.S.LU
							fp.write32u(rd0, fcvt_s_lu_d);
							csr_c.set_fflags({4'h0, fcvt_s_lu_inexact});
					end
					default: ;
					endcase
				end
				7'b11110_00: begin
					case (rs2)
					5'b00000: begin
						case (funct3)
						3'b000: begin	// FMV.W.X
							fp.write(rd0, rs1_d);
						end
						default: ;
						endcase
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b11_100_11: begin	// SYSTEM
				case (funct3)
				3'b001: begin		// CSRRW
					rf.write(rd0, csr_c.read(csr));
					csr_c.write(csr, rs1_d);
				end
				3'b010: begin		// CSRRS
					rf.write(rd0, csr_c.read(csr));
					if(rs1 != 5'h00) begin
						csr_c.set(csr, rs1_d);
					end
				end
				3'b011: begin		// CSRRC
					rf.write(rd0, csr_c.read(csr));
					if(rs1 != 5'h00) begin
						csr_c.clear(csr, rs1_d);
					end
				end
				3'b101: begin		// CSRRWI
					rf.write(rd0, csr_c.read(csr));
					csr_c.write(csr, uimm_w);
				end
				3'b110: begin		// CSRRSI
					rf.write(rd0, csr_c.read(csr));
					csr_c.set(csr, uimm_w);
				end
				3'b111: begin		// CSRRCI
					rf.write(rd0, csr_c.read(csr));
					csr_c.clear(csr, uimm_w);
				end
				default: ;
				endcase
			end

			7'b00_101_11: begin	// AUIPC
						rf.write(rd0, pc + imm_uw);
			end

			7'b01_101_11: begin	// LUI
						rf.write(rd0, imm_uw);
			end

			7'b00_110_11: begin	// OP-IMM-32
				case (funct3)
				3'b000: begin			// ADDIW
						rf.write32s(rd0, rs1_d[31:0] + imm_iw[31:0]);
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLIW
						rf.write32s(rd0, rs1_d[31:0] << shamt[4:0]);
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLIW
						rf.write32s(rd0, rs1_d[31:0] >> shamt[4:0]);
					end
					7'b0100000: begin	// SRAIW
						rf.write32s(rd0, $signed(rs1_d[31:0]) >>> shamt[4:0]);
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
						rf.write32s(rd0, rs1_d[31:0] + rs2_d[31:0]);
					end
					7'b0000001: begin	// MULW
						tmp32 = rs1_d[31:0] * rs2_d[31:0];
						rf.write32s(rd0, tmp32);
					end
					7'b0100000: begin	// SUBW
						rf.write32s(rd0, rs1_d[31:0] - rs2_d[31:0]);
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLW
						rf.write32s(rd0, rs1_d[31:0] << rs2_d[4:0]);
					end
					default: ;
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b0000001: begin	// DIVW
						tmp32 = absXLENh(rs1_d[`XLEN/2-1:0]) / absXLENh(rs2_d[`XLEN/2-1:0]);
						tmp32 = twoscompXLENh(rs1_d[`XLEN/2-1] ^ rs2_d[`XLEN/2-1], tmp32);
						rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? {32{1'b1}} : tmp32);
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLW
						rf.write32s(rd0, rs1_d[31:0] >> rs2_d[4:0]);
					end
					7'b0000001: begin	// DIVUW
						rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? {32{1'b1}} : rs1_d[31:0] / rs2_d[31:0]);
					end
					7'b0100000: begin	// SRAW
						rf.write32s(rd0, $signed(rs1_d[31:0]) >>> rs2_d[4:0]);
					end
					default: ;
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b0000001: begin	// REMW
						tmp32 = absXLENh(rs1_d[`XLEN/2-1:0]) % absXLENh(rs2_d[`XLEN/2-1:0]);
						tmp32 = twoscompXLENh(rs1_d[`XLEN/2-1], tmp32);
						rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d[31:0] : tmp32);
					end
					default: ;
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000001: begin	// REMUW
						rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d[`XLEN/2-1:0] : rs1_d[31:0] % rs2_d[31:0]);
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
						csr_c.write(12'h342, 64'h0000_0000_0000_000b);	// mcause
						pc <= csr_c.read(12'h305);	// mtvec

					end
					12'b0000000_00001: begin	// EBREAK
					end
					12'b0001000_00010: begin	// SRET
					end
					12'b0011000_00010: begin	// MRET
						pc <= csr_c.read(12'h341);	// mepc
					end
					default:pc <= pc + 'h4;
					endcase
				end
				default:pc <= pc + 'h4;
				endcase
			end
			default:	pc <= pc + 'h4;
			endcase


			// debug outputs
			rf_1_ra = rf.read('d1);
			rf_2_sp = rf.read('d2);
			rf_3_gp = rf.read('d3);
			rf_4_tp = rf.read('d4);
			rf_5_t0 = rf.read('d5);
			rf_6_t1 = rf.read('d6);
			rf_7_t2 = rf.read('d7);
			rf_8_s0 = rf.read('d8);
			rf_9_s1 = rf.read('d9);
			rf_10_a0 = rf.read('d10);
			rf_11_a1 = rf.read('d11);
			rf_12_a2 = rf.read('d12);
			rf_13_a3 = rf.read('d13);
			rf_14_a4 = rf.read('d14);
			rf_15_a5 = rf.read('d15);
			rf_16_a6 = rf.read('d16);
			rf_17_a7 = rf.read('d17);
			rf_18_s2 = rf.read('d18);
			rf_19_s3 = rf.read('d19);
			rf_20_s4 = rf.read('d20);
			rf_21_s5 = rf.read('d21);
			rf_22_s6 = rf.read('d22);
			rf_23_s7 = rf.read('d23);
			rf_24_s8 = rf.read('d24);
			rf_25_s9 = rf.read('d25);
			rf_26_s10 = rf.read('d26);
			rf_27_s11 = rf.read('d27);
			rf_28_t3 = rf.read('d28);
			rf_29_t4 = rf.read('d29);
			rf_30_t5 = rf.read('d30);
			rf_31_t6 = rf.read('d31);

			fp_0 = fp.read('d0);
			fp_1 = fp.read('d1);
			fp_2 = fp.read('d2);
			fp_3 = fp.read('d3);
			fp_4 = fp.read('d4);
			fp_5 = fp.read('d5);
			fp_6 = fp.read('d6);
			fp_7 = fp.read('d7);
			fp_8 = fp.read('d8);
			fp_9 = fp.read('d9);
			fp_10 = fp.read('d10);
			fp_11 = fp.read('d11);
			fp_12 = fp.read('d12);
			fp_13 = fp.read('d13);
			fp_14 = fp.read('d14);
			fp_15 = fp.read('d15);
			fp_16 = fp.read('d16);
			fp_17 = fp.read('d17);
			fp_18 = fp.read('d18);
			fp_19 = fp.read('d19);
			fp_20 = fp.read('d20);
			fp_21 = fp.read('d21);
			fp_22 = fp.read('d22);
			fp_23 = fp.read('d23);
			fp_24 = fp.read('d24);
			fp_25 = fp.read('d25);
			fp_26 = fp.read('d26);
			fp_27 = fp.read('d27);
			fp_28 = fp.read('d28);
			fp_29 = fp.read('d29);
			fp_30 = fp.read('d30);
			fp_31 = fp.read('d31);
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
