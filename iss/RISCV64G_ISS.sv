
`include "defs.vh"

`include "MISC.sv"
`include "CSR.sv"
`include "REG_FILE.sv"
`include "REG_FILE_FP.sv"
`include "ELF.sv"
`include "PMA.sv"
`include "FLOAT.sv"
`include "FCVT.sv"

`include "TRACE.sv"

module RISCV64G_ISS (
	input			CLK,
	input			RSTn,

	output reg		tohost_we,
	output reg [32-1:0]	tohost
);
	// TRACE
	TRACE			trace = new;

	// memory
	ELF			mem;
	initial begin
		string		init_file;
		if($value$plusargs("ELF=%s", init_file))
		begin
			$display ("[ARG] +ELF=%s", init_file);
			mem = new(init_file);
		end
	end

	// PMA
	PMA			pma = new;

	// FLOAT
	FLOAT			flt = new;
	FCVT			fcvt = new;

	// PC
	reg  [`XLEN-1:0]	pc;

	logic [32-1:0]		inst;
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

	logic [`XLEN-1:0]	rs1_d;
	logic [`XLEN-1:0]	rs2_d;
	logic [`FLEN-1:0]	fp_rs1_d;
	logic [`FLEN-1:0]	fp_rs2_d;
	logic [`FLEN-1:0]	fp_rs3_d;


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


`define PTE_VB	0
`define PTE_RB	1
`define PTE_WB	2
`define PTE_XB	3
`define PTE_UB	4
`define PTE_GB	5
`define PTE_AB	6
`define PTE_DB	7

//`define PTE_V	4'h1
`define PTE_R	4'h2
`define PTE_W	4'h4
`define PTE_X	4'h8
`define PTE_X	4'h8

`define PTE_U	8'h10
`define PTE_G	8'h20
`define PTE_A	8'h40
`define PTE_D	8'h80

	function [`XLEN-1:0] virtual_address_translation(input [`XLEN-1:0] va, input [3:0] acc);
		if(csr_c.get_satp_mode() == 4'h00) begin
			return va;
		end else if(csr_c.get_satp_mode() == 4'd08) begin	// Sv39
			if(csr_c.get_mode() == `MODE_M && csr_c.get_m_sum() && csr_c.get_mprv() && csr_c.get_mpp() == `MODE_S && (acc[`PTE_RB] || acc[`PTE_WB])
				|| csr_c.get_mode() == `MODE_S && csr_c.get_s_sum()
			       	|| csr_c.get_mode() == `MODE_U) begin
				// 1. read satp
				logic [`XLEN-1:0]	a = {8'h00, csr_c.get_satp_ppn(), 12'h000};
				logic [8:0]		va_vpn2 = va[38:30];
				logic [8:0]		va_vpn1 = va[29:21];
				logic [8:0]		va_vpn0 = va[20:12];
				logic [8:0]		va_vpn;
				logic [11:0]		va_ofs  = va[11:0];
				logic [`XLEN-1:0]	pte;
				logic [`XLEN-1:0]	pte_cmp;
				logic [`XLEN-1:0]	pte_cmp_a;
				logic [`XLEN-1:0]	pte_a;
				logic [25:0]		pte_ppn2;
				logic [8:0]		pte_ppn1;
				logic [8:0]		pte_ppn0;
				logic [25:0]		pa_ppn2;
				logic [8:0]		pa_ppn1;
				logic [8:0]		pa_ppn0;
				integer			i = 2;

				$display("[INFO] Sv39 translate on: %16h", va);

				// virtual address check
				if((~va[38] | ~&va[63:39]) & (va[38] | |va[63:39])) begin
					raise_page_fault(va, acc);
					return {64{1'b0}};
				end
				$display("[INFO] a: %16h", a);

				// 2. 1st page table entry address
				pte_a = a + va_vpn2 * 8;
				if(~pma.is_readable(pte_a)) begin
					raise_page_fault(va, `PTE_R);
					return {64{1'b0}};
				end
				$display("[INFO] pte_a: %16h", pte_a);

				// 1st page table entry
				pte = mem.read(pte_a);
				// 3. pte check
				if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
					raise_page_fault(va, acc);
					return {64{1'b0}};
				end
				$display("[INFO] 1st pte: %16h", pte);

				// 4. leaf check
				if(~pte[`PTE_RB] && ~pte[`PTE_WB]) begin	// not leaf
					i = 1;
					a = {8'h00, pte[53:10], 12'h000};
					// 2. 1st page table entry address
					pte_a = a + va_vpn1 * 8;
					if(~pma.is_readable(pte_a)) begin
						raise_page_fault(va, `PTE_R);
						return {64{1'b0}};
					end

					// 2nd page table entry
					pte = mem.read(pte_a);
					// 3. pte check
					if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
						raise_page_fault(va, acc);
						return {64{1'b0}};
					end
					$display("[INFO] 2nd pte: %16h", pte);
					// 4. leaf check
					if(~pte[`PTE_RB] && ~pte[`PTE_WB]) begin	// not leaf
						i = 0;
						a = {8'h00, pte[53:10], 12'h000};
						// 2. 1st page table entry address
						pte_a = a + va_vpn0 * 8;
						if(~pma.is_readable(pte_a)) begin
							raise_page_fault(va, `PTE_R);
							return {64{1'b0}};
						end

						// 3rd page table entry
						pte = mem.read(pte_a);
						// 3. pte check
						if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
							raise_page_fault(va, acc);
							return {64{1'b0}};
						end
						$display("[INFO] 3rd pte: %16h", pte);
						// 4. leaf check
						if(~pte[`PTE_RB] && ~pte[`PTE_WB]) begin	// not leaf
							raise_page_fault(va, acc);
							return {64{1'b0}};
						end
					end
				end 

				// 5. leaf pte is found
				pte_ppn2 = pte[53:28];
				pte_ppn1 = pte[27:19];
				pte_ppn0 = pte[18:10];

				// access type check
				if(
					acc[`PTE_RB] && ~pte[`PTE_RB] ||
					acc[`PTE_WB] && ~pte[`PTE_WB] ||
					acc[`PTE_XB] && ~pte[`PTE_XB] 
				) begin
					raise_page_fault(va, acc);
					return {64{1'b0}};
				end

				// current privilege mode check
				if(csr_c.get_mode() == `MODE_U && ~pte[`PTE_UB] ||
				   csr_c.get_mode() == `MODE_S &&  pte[`PTE_UB] && csr_c.get_m_sum()) begin
					raise_page_fault(va, acc);
					return {64{1'b0}};
				end

				// 6. misaligned sperpage
				if(i == 2 && (|pte_ppn1 || |pte_ppn0) ||
				   i == 1 &&               |pte_ppn0) begin
					raise_page_fault(va, acc);
					return {64{1'b0}};
				end

				// 7. pte.a == 0, or store access and pte.d ==0
				if(~pte[`PTE_AB] || acc[`PTE_WB] && ~pte[`PTE_DB]) begin
					raise_page_fault(va, acc);
					return {64{1'b0}};
				end

				va_vpn = i == 2 ? va_vpn2 : i == 1 ? va_vpn1 : va_vpn0;
				pte_cmp_a = a + va_vpn * 8;
				pte_cmp = mem.read(pte_cmp_a);
				if(pte == pte_cmp) begin
					pte = pte | {{56{1'b0}}, `PTE_A};
					if(acc == `PTE_W) begin
						pte = pte | {{56{1'b0}}, `PTE_D};
					end
					if(!pma.is_writeable(pte_a)) begin
						raise_page_fault(pte_a, `PTE_W);
						return {64{1'b0}};
					end else begin
						mem.write(pte_a, pte);
					end
				end else begin
					$display("[ERROR] virtual address translation internal error.");
					$finish;
				end

				// 8. translation is successful
				if(i == 0) begin
					pa_ppn2 = pte_ppn2;
					pa_ppn1 = pte_ppn1;
					pa_ppn0 = pte_ppn0;
				end else if(i == 1) begin
					pa_ppn2 = pte_ppn2;
					pa_ppn1 = pte_ppn1;
					pa_ppn0 = va_vpn0;
				end else begin	// i == 2
					pa_ppn2 = pte_ppn2;
					pa_ppn1 = va_vpn1;
					pa_ppn0 = va_vpn0;
				end

				$display("[INFO] va -> pa: %16h -> %16h", va, {8'h00, pa_ppn2, pa_ppn1, pa_ppn0, va_ofs});
				return {8'h00, pa_ppn2, pa_ppn1, pa_ppn0, va_ofs};

			end else begin	// no addresds translation
				return va;
			end
		end else begin	// not implemented yet.
			return va;
		end
	endfunction

	function void raise_page_fault(input [`XLEN-1:0] va, input [3:0] acc);
		if(acc[`PTE_RB]) begin
			pc = csr_c.raise_exception(`EX_LPFAULT, pc, va);
		end else if(acc[`PTE_WB])begin
			pc = csr_c.raise_exception(`EX_SPFAULT, pc, va);
		end else if(acc[`PTE_XB])begin
			pc = csr_c.raise_exception(`EX_IPFAULT, pc, va);
		end
	endfunction


	// main loop
	always_ff @(posedge CLK or negedge RSTn)
	begin
		logic [`XLEN-1:0]	tmp;
		logic [32-1:0]		tmp32;
		logic [`XLEN*2-1:0]	tmp128;

		if(!RSTn) begin
			csr_c.init();

			// pc
			pc = mem.get_entry_point();

			lrsc_valid <= 1'b0;

			tohost_we = 1'b0;

			inst = {32{1'b0}};
		end else begin
			csr_c.tick();

			tohost_we = 1'b0;


			// 1. instruction fetch
			inst   = mem.read32(virtual_address_translation(pc, `PTE_X));
			trace.print(pc, inst);	// trace output

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

			// 2. register fetch
			rs1_d    = rf.read(rs1);
			rs2_d    = rf.read(rs2);
			fp_rs1_d = fp.read(rs1);
			fp_rs2_d = fp.read(rs2);
			fp_rs3_d = fp.read(rs3);

			// trace output

			// execute and write back
			case (opcode)
			7'b00_000_11: begin	// LOAD: I type
				case (funct3)
				3'b000: begin			// LB
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write8s(rd0, mem.read8(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				3'b001: begin			// LH
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write16s(rd0, mem.read16(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				3'b010: begin			// LW
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write32s(rd0, mem.read32(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				3'b011: begin			// LD
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write(rd0, mem.read(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				3'b100: begin			// LBU
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write8u(rd0, mem.read8(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				3'b101: begin			// LHU
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write16u(rd0, mem.read16(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				3'b110: begin			// LWU
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							rf.write32u(rd0, mem.read32(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				default: ;
				endcase
			end

			7'b01_000_11: begin	// STORE: S type
				case (funct3)
				3'b000: begin			// SB
					tmp = virtual_address_translation(rs1_d + imm_sw, `PTE_W);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_writeable(tmp)) begin
							mem.write8(rs1_d + imm_sw, rs2_d[7:0]);
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
						end
					end
				end
				3'b001: begin			// SH
					tmp = virtual_address_translation(rs1_d + imm_sw, `PTE_W);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_writeable(tmp)) begin
							mem.write16(tmp, rs2_d[15:0]);
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
						end
					end
				end
				3'b010: begin			// SW
					tmp = virtual_address_translation(rs1_d + imm_sw, `PTE_W);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_writeable(tmp)) begin
							mem.write32(tmp, rs2_d[31:0]);
							pc = pc + 'h4;
							tohost_we  = rs1_d + imm_sw == mem.get_tohost() ? 1'b1 : 1'b0;	// for testbench hack
							tohost     = rs2_d[31:0];
						end else begin
							pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
						end
					end
				end
				3'b011: begin			// SD
					tmp = virtual_address_translation(rs1_d + imm_sw, `PTE_W);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_writeable(tmp)) begin
							mem.write(tmp, rs2_d);
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
						end
					end
				end
				default: ;
				endcase
			end

			7'b10_000_11: begin	// MADD
						pc = pc + 'h4;
			end

			7'b11_000_11: begin	// BRANCH
				case (funct3)
				3'b000:	pc = rs1_d == rs2_d ? pc + imm_bw : pc + 'h4;	// BEQ
				3'b001:	pc = rs1_d != rs2_d ? pc + imm_bw : pc + 'h4;	// BNE
				3'b100:	pc = $signed(rs1_d) <  $signed(rs2_d) ? pc + imm_bw : pc + 'h4;	// BLT
				3'b101:	pc = $signed(rs1_d) >= $signed(rs2_d) ? pc + imm_bw : pc + 'h4;	// BGE
				3'b110:	pc = rs1_d <  rs2_d ? pc + imm_bw : pc + 'h4;	// BLTU
				3'b111:	pc = rs1_d >= rs2_d ? pc + imm_bw : pc + 'h4;	// BGEU
				default: ;
				endcase
			end

			7'b00_001_11: begin	// LOAD-FP
				case (funct3)
				3'b010: begin			// FLW
					tmp = virtual_address_translation(rs1_d + imm_iw, `PTE_R);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_readable(tmp)) begin
							fp.write32u(rd0, mem.read32(tmp));
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
						end
					end
				end
				default: ;
				endcase
			end

			7'b01_001_11: begin	// STORE-FP
				case (funct3)
				3'b010: begin			// FSW
					tmp = virtual_address_translation(rs1_d + imm_sw, `PTE_W);
					if(tmp != {64{1'b0}}) begin
						if(pma.is_writeable(tmp)) begin
							mem.write32(tmp, fp_rs2_d[31:0]);
							pc = pc + 'h4;
						end else begin
							pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
						end
					end
				end
				default: ;
				endcase
			end

			7'b10_001_11: begin	// MSUB
						pc = pc + 'h4;
			end

			7'b11_001_11: begin	// JALR
				case (funct3)
				3'b000: begin
						rf.write(rd0, pc + 'h4);
						pc = rs1_d + imm_iw;
				end
				default: ;
				endcase
			end

			7'b01_010_11: begin	// NMSUB
						pc = pc + 'h4;
			end

			7'b00_011_11: begin	// MISC-MEM
				case (funct3)
				3'b000: begin	// FENCE
						pc = pc + 'h4;
				end
				3'b001: begin	// FENCE.I
						pc = pc + 'h4;
				end
				default: ;
				endcase
			end

			7'b01_011_11: begin	// AMO
				case (funct3)
				3'b010: begin
					case (funct5)
					5'b00010: begin		// LR.W
						lrsc_valid <= 1'b1;
						lrsc_addr  <= rs1_d;
						rf.write32s(rd0, mem.read32(rs1_d));
						pc = pc + 'h4;
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
						pc = pc + 'h4;
					end
					5'b00001: begin		// AMOSWAP.W
						rf.write32s(rd0, mem.read32(rs1_d));
						mem.write32(rs1_d, rs2_d[31:0]);
						pc = pc + 'h4;
					end
					5'b00000: begin		// AMOADD.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] + tmp32);
						pc = pc + 'h4;
					end
					5'b00100: begin		// AMOXOR.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] ^ tmp32);
						pc = pc + 'h4;
					end
					5'b01100: begin		// AMOAND.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] & tmp32);
						pc = pc + 'h4;
					end
					5'b01000: begin		// AMOOR.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] | tmp32);
						pc = pc + 'h4;
					end
					5'b10000: begin		// AMOMIN.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, $signed(rs2_d[31:0]) < $signed(tmp32) ? rs2_d[31:0] : tmp32);
						pc = pc + 'h4;
					end
					5'b10100: begin		// AMOMAX.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, $signed(rs2_d[31:0]) > $signed(tmp32) ? rs2_d[31:0] : tmp32);
						pc = pc + 'h4;
					end
					5'b11000: begin		// AMOMINU.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] < tmp32 ? rs2_d[31:0] : tmp32);
						pc = pc + 'h4;
					end
					5'b11100: begin		// AMOMAXU.W
						tmp32 = mem.read32(rs1_d);
						rf.write32s(rd0, tmp32);
						mem.write32(rs1_d, rs2_d[31:0] > tmp32 ? rs2_d[31:0] : tmp32);
						pc = pc + 'h4;
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
						pc = pc + 'h4;
					end
					5'b00000: begin		// AMOADD.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						mem.write(rs1_d, rs2_d + tmp);
						pc = pc + 'h4;
					end
					5'b00100: begin		// AMOXOR.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d ^ tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					5'b01100: begin		// AMOAND.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d & tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					5'b01000: begin		// AMOOR.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d | tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					5'b10000: begin		// AMOMIN.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = $signed(rs2_d) < $signed(tmp) ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					5'b10100: begin		// AMOMAX.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = $signed(rs2_d) > $signed(tmp) ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					5'b11000: begin		// AMOMINU.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d < tmp ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					5'b11100: begin		// AMOMAXU.D
						tmp = mem.read(rs1_d);
						rf.write(rd0, tmp);
						tmp = rs2_d > tmp ? rs2_d : tmp;
						mem.write(rs1_d, tmp);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b10_011_11: begin	// NMADD
						pc = pc + 'h4;
			end

			7'b11_011_11: begin	// JAL
						rf.write(rd0, pc + 'h4);
						pc = pc + imm_jw;
			end

			7'b00_100_11: begin	// OP-IMM
				case (funct3)
				3'b000: begin								// ADDI
						rf.write(rd0, rs1_d + imm_iw);
						pc = pc + 'h4;
				end
				3'b001: begin
					case (funct7[6:1])
					6'b000000: begin						// SLLI
						rf.write(rd0, rs1_d << shamt);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b010: begin								// SLTI
						rf.write(rd0, $signed(rs1_d) < $signed(imm_iw) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
						pc = pc + 'h4;
				end
				3'b011: begin								// SLTIU
						rf.write(rd0, rs1_d < imm_iw ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
						pc = pc + 'h4;
				end
				3'b100: begin								// XORI
						rf.write(rd0, rs1_d ^ imm_iw);
						pc = pc + 'h4;
				end
				3'b101: begin
					case (funct7[6:1])
					6'b000000: begin						// SRLI
						rf.write(rd0, rs1_d >> shamt);
						pc = pc + 'h4;
					end
					6'b010000: begin						// SRAI
						rf.write(rd0, $signed(rs1_d) >>> shamt);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b110: begin								// ORI
						rf.write(rd0, rs1_d | imm_iw);
						pc = pc + 'h4;
				end
				3'b111: begin								// ANDI
						rf.write(rd0, rs1_d & imm_iw);
						pc = pc + 'h4;
				end
				default: ;
				endcase
			end

			7'b01_100_11: begin	// OP
				case (funct3)
				3'b000: begin
					case (funct7)
					7'b0000000: begin	// ADD
						rf.write(rd0, rs1_d + rs2_d);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// MUL
						tmp128 = rs1_d * rs2_d;
						rf.write(rd0, tmp128[`XLEN-1:0]);
						pc = pc + 'h4;
					end
					7'b0100000: begin	// SUB
						rf.write(rd0, rs1_d - rs2_d);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLL
						rf.write(rd0, rs1_d << rs2_d[5:0]);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// MULH
						tmp128 = $signed(rs1_d) * $signed(rs2_d);
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b010: begin
					case (funct7)
					7'b0000000: begin	// SLT
						rf.write(rd0, $signed(rs1_d) < $signed(rs2_d) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
						pc = pc + 'h4;
					end
					7'b0000001: begin	// MULHSU
						tmp128 = absXLEN(rs1_d) * rs2_d;
						tmp128 = twoscompXLENx2(rs1_d[`XLEN-1], tmp128);
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b011: begin
					case (funct7)
					7'b0000000: begin	// SLTU
						rf.write(rd0, rs1_d < rs2_d ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
						pc = pc + 'h4;
					end
					7'b0000001: begin	// MULHU
						tmp128 = rs1_d * rs2_d;
						rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b100: begin
					case (funct7)
					7'b0000000: begin	// XOR
					 	rf.write(rd0, rs1_d ^ rs2_d);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// DIV
						tmp = absXLEN(rs1_d) / absXLEN(rs2_d);
						tmp = twoscompXLEN(rs1_d[`XLEN-1] ^ rs2_d[`XLEN-1], tmp);
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : tmp);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRL
						rf.write(rd0, rs1_d >> rs2_d[5:0]);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// DIVU
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : rs1_d / rs2_d);
						pc = pc + 'h4;
					end
					7'b0100000: begin	// SRA
						rf.write(rd0, $signed(rs1_d) >>> rs2_d[5:0]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b110: begin
					case (funct7)
					7'b0000000: begin	// OR
						rf.write(rd0, rs1_d | rs2_d);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// REM
						tmp = absXLEN(rs1_d) % absXLEN(rs2_d);
						tmp = twoscompXLEN(rs1_d[`XLEN/2-1], tmp);
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d : tmp);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000000: begin	// AND
						rf.write(rd0, rs1_d & rs2_d);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// REMU
						rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d : rs1_d % rs2_d);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end

			7'b10_100_11: begin	// OP-FP: R type
				float_t out;
				word_t wout;
				long_t lout;

				case(funct7)
				7'b00000_00: begin		// FADD.S
						flt.fadd(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						pc = pc + 'h4;
				end
				7'b00001_00: begin		// FSUB.S
						flt.fsub(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						pc = pc + 'h4;
				end
				7'b00010_00: begin		// FMUL.S
						flt.fmul(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						pc = pc + 'h4;
				end
				7'b00011_00: begin		// FDIV.S
						pc = pc + 'h4;
				end
				7'b01011_00: begin
					case (rs2)
					5'b00000: begin		// FSQRT.S
						pc = pc + 'h4;
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
						pc = pc + 'h4;
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
						pc = pc + 'h4;
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
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				7'b00101_00: begin
					case (funct3)
					3'b000: begin		// FMIN.S
						flt.fmin(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						pc = pc + 'h4;
					end
					3'b001: begin		// FMAX.S
						flt.fmax(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				7'b11000_00: begin
					case (rs2)
					5'b00000: begin		// FCVT.W.S
							fcvt.word_from_real(fp_rs1_d[31:0], wout);
							rf.write32s(rd0, wout.val);
							csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
							pc = pc + 'h4;
					end
					5'b00001: begin		// FCVT.WU.S
							fcvt.uword_from_real(fp_rs1_d[31:0], wout);
							rf.write32s(rd0, wout.val);
							csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
							pc = pc + 'h4;
					end
					5'b00010: begin		// FCVT.L.S
							fcvt.long_from_real(fp_rs1_d[31:0], lout);
							rf.write(rd0, lout.val);
							csr_c.set_fflags({lout.invalid, 3'h0, lout.inexact});
							pc = pc + 'h4;
					end
					5'b00011: begin		// FCVT.LU.S
							fcvt.ulong_from_real(fp_rs1_d[31:0], lout);
							rf.write(rd0, lout.val);
							csr_c.set_fflags({lout.invalid, 3'h0, lout.inexact});
							pc = pc + 'h4;
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
							pc = pc + 'h4;
						end
						3'b001: begin	// FCLASS.W
							rf.write32u(rd0, flt.fclass(fp_rs1_d[31:0]));
							pc = pc + 'h4;
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
							flt.feq(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
							rf.write(rd0, {{32{1'b0}}, out.val});
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
					end
					3'b001: begin 		// FLT.S
							flt.flt(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
							rf.write(rd0, {{32{1'b0}}, out.val});
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
					end
					3'b000: begin		// FLE.S
							flt.fle(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
							rf.write(rd0, {{32{1'b0}}, out.val});
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				7'b11010_00: begin
					case (rs2)
					5'b00000: begin		// FCVT.S.W
							fcvt.real_from_word(rs1_d[31:0], out);
							fp.write32u(rd0, out.val);
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
					end
					5'b00001: begin		// FCVT.S.WU
							fcvt.real_from_uword(rs1_d[31:0], out);
							fp.write32u(rd0, out.val);
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
					end
					5'b00010: begin		// FCVT.S.L
							fcvt.real_from_long(rs1_d, out);
							fp.write32u(rd0, out.val);
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
					end
					5'b00011: begin		// FCVT.S.LU
							fcvt.real_from_ulong(rs1_d, out);
							fp.write32u(rd0, out.val);
							csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
							pc = pc + 'h4;
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
							pc = pc + 'h4;
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
				3'b000: begin
					case (funct7)
					7'b0000000: begin
						case(rs2)
						5'b00000: begin		// ECALL
							tmp = csr_c.ecall(pc);
							if(tmp == {`XLEN{1'b1}}) begin
								pc = pc + 'h4;
							end else begin
								pc = tmp;
							end
						end
						5'b00001: begin		// EBREAK
								pc = pc + 'h4;
						end
						default: ;
						endcase
					end
					7'b0001000: begin
						case(rs2)
						5'b00010: begin		// SRET
								pc = csr_c.sret();	// sepc
						end
						default: ;
						endcase
					end
					7'b0011000: begin
						case(rs2)
						5'b00010: begin		// MRET
								pc = csr_c.mret();	// mepc
						end
						default: ;
						endcase
					end
					7'b0001001: begin
						case(rd0)
						5'h00: begin		// SFENCE.VMA
								pc = pc + 'h4;
						end
						default: ;
						endcase
					end
					7'b0001011: begin
						case(rd0)
						5'b00000: begin		// SINVAL.VMA
								pc = pc + 'h4;
						end
						default: ;
						endcase
					end
					7'b0001100: begin
						case(rd0)
						5'b00000: begin
							case (rs2)
							5'b00000: begin	// SFENCE.W.INVAL
								pc = pc + 'h4;
							end
							5'b00001: begin	// SFENCE.INVAL.IR
								pc = pc + 'h4;
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
				3'b001: begin		// CSRRW
					rf.write(rd0, csr_c.read(csr));
					csr_c.write(csr, rs1_d);
					pc = pc + 'h4;
				end
				3'b010: begin		// CSRRS
					rf.write(rd0, csr_c.read(csr));
					if(rs1 != 5'h00) begin
						csr_c.set(csr, rs1_d);
					end
					pc = pc + 'h4;
				end
				3'b011: begin		// CSRRC
					rf.write(rd0, csr_c.read(csr));
					if(rs1 != 5'h00) begin
						csr_c.clear(csr, rs1_d);
					end
					pc = pc + 'h4;
				end
				3'b101: begin		// CSRRWI
					rf.write(rd0, csr_c.read(csr));
					csr_c.write(csr, uimm_w);
					pc = pc + 'h4;
				end
				3'b110: begin		// CSRRSI
					rf.write(rd0, csr_c.read(csr));
					csr_c.set(csr, uimm_w);
					pc = pc + 'h4;
				end
				3'b111: begin		// CSRRCI
					rf.write(rd0, csr_c.read(csr));
					csr_c.clear(csr, uimm_w);
					pc = pc + 'h4;
				end
				default: ;
				endcase
			end

			7'b00_101_11: begin	// AUIPC
						rf.write(rd0, pc + imm_uw);
						pc = pc + 'h4;
			end

			7'b01_101_11: begin	// LUI
						rf.write(rd0, imm_uw);
						pc = pc + 'h4;
			end

			7'b00_110_11: begin	// OP-IMM-32
				case (funct3)
				3'b000: begin			// ADDIW
						rf.write32s(rd0, rs1_d[31:0] + imm_iw[31:0]);
						pc = pc + 'h4;
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLIW
						rf.write32s(rd0, rs1_d[31:0] << shamt[4:0]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLIW
						rf.write32s(rd0, rs1_d[31:0] >> shamt[4:0]);
						pc = pc + 'h4;
					end
					7'b0100000: begin	// SRAIW
						rf.write32s(rd0, $signed(rs1_d[31:0]) >>> shamt[4:0]);
						pc = pc + 'h4;
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
						pc = pc + 'h4;
					end
					7'b0000001: begin	// MULW
						tmp32 = rs1_d[31:0] * rs2_d[31:0];
						rf.write32s(rd0, tmp32);
						pc = pc + 'h4;
					end
					7'b0100000: begin	// SUBW
						rf.write32s(rd0, rs1_d[31:0] - rs2_d[31:0]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b001: begin
					case (funct7)
					7'b0000000: begin	// SLLW
						rf.write32s(rd0, rs1_d[31:0] << rs2_d[4:0]);
						pc = pc + 'h4;
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
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b101: begin
					case (funct7)
					7'b0000000: begin	// SRLW
						rf.write32s(rd0, rs1_d[31:0] >> rs2_d[4:0]);
						pc = pc + 'h4;
					end
					7'b0000001: begin	// DIVUW
						rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? {32{1'b1}} : rs1_d[31:0] / rs2_d[31:0]);
						pc = pc + 'h4;
					end
					7'b0100000: begin	// SRAW
						rf.write32s(rd0, $signed(rs1_d[31:0]) >>> rs2_d[4:0]);
						pc = pc + 'h4;
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
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				3'b111: begin
					case (funct7)
					7'b0000001: begin	// REMUW
						rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d[`XLEN/2-1:0] : rs1_d[31:0] % rs2_d[31:0]);
						pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end
			default: ;
			endcase

			// retire
			csr_c.retire();

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

endmodule
