`ifndef _iss_sv_
`define _iss_sv_

`include "defs.vh"

`include "MISC.sv"
`include "CSR.sv"
`include "REG_FILE.sv"
`include "REG_FILE_FP.sv"
`include "ELF.sv"
`include "PMA.sv"
`include "FLOAT.sv"
`include "FCVT.sv"
`include "FCVT_W_D.sv"
`include "FCVT_S_D.sv"

class ISS;
	// memory
	ELF			mem;

	// PMA
	PMA			pma = new;

	// FLOAT
	FLOAT #(
		.T		(float_t),
		.F_WIDTH	(32),
		.F_EXP		(8),
		.F_FLAC		(23)
		)
				float = new;
	FLOAT #(
		.T		(double_t),
		.F_WIDTH	(64),
		.F_EXP		(11),
		.F_FLAC		(52)
		)
				double = new;
	FCVT #(
		.T		(float_t),
		.F_WIDTH	(32),
		.F_EXP		(8),
		.F_FLAC		(23),
		.S		(long_t),
		.I_WIDTH	(64)
		)
				fcvt_l_s = new;
	FCVT #(
		.T		(float_t),
		.F_WIDTH	(32),
		.F_EXP		(8),
		.F_FLAC		(23),
		.S		(word_t),
		.I_WIDTH	(32)
		)
				fcvt_w_s = new;
	FCVT #(
		.T		(double_t),
		.F_WIDTH	(64),
		.F_EXP		(11),
		.F_FLAC		(52),
		.S		(long_t),
		.I_WIDTH	(64)
		)
				fcvt_l_d = new;
	FCVT_W_D #(
		.T		(double_t),
		.F_WIDTH	(64),
		.F_EXP		(11),
		.F_FLAC		(52),
		.S		(word_t),
		.I_WIDTH	(32)
		)
				fcvt_w_d = new;
	FCVT_S_D 		fcvt_s_d = new;


	// registers
	REG_FILE	rf = new();
	REG_FILE_FP	fp = new();
	CSR		csr_c = new();

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

	task virtual_address_translation(input [`XLEN-1:0] va, input [3:0] acc, input [`XLEN-1:0] pc, output [`XLEN-1:0] pa, output [`XLEN-1:0] trap_pc);
		trap_pc = {`XLEN{1'b0}};
		if(csr_c.get_satp_mode() == 4'h00) begin
			pa = va;
			return;
		end else if(csr_c.get_satp_mode() == 4'd08) begin	// Sv39
			if(csr_c.get_mode() == `MODE_M && csr_c.get_m_sum() && csr_c.get_mprv() && csr_c.get_mpp() == `MODE_S && (acc[`PTE_RB] || acc[`PTE_WB])
				|| csr_c.get_mode() == `MODE_S && csr_c.get_s_sum()
			       	|| csr_c.get_mode() == `MODE_U) begin
				// 1. read satp
				bit [`XLEN-1:0]	a = {8'h00, csr_c.get_satp_ppn(), 12'h000};
				bit [8:0]		va_vpn2 = va[38:30];
				bit [8:0]		va_vpn1 = va[29:21];
				bit [8:0]		va_vpn0 = va[20:12];
				bit [8:0]		va_vpn;
				bit [11:0]		va_ofs  = va[11:0];
				bit [`XLEN-1:0]	pte;
				bit [`XLEN-1:0]	pte_cmp;
				bit [`XLEN-1:0]	pte_cmp_a;
				bit [`XLEN-1:0]	pte_a;
				bit [25:0]		pte_ppn2;
				bit [8:0]		pte_ppn1;
				bit [8:0]		pte_ppn0;
				bit [25:0]		pa_ppn2;
				bit [8:0]		pa_ppn1;
				bit [8:0]		pa_ppn0;
				integer			i = 2;

				$display("[INFO] Sv39 translate on: %16h", va);

				// virtual address check
				if((~va[38] | ~&va[63:39]) & (va[38] | |va[63:39])) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return;
				end
				$display("[INFO] a: %16h", a);

				// 2. 1st page table entry address
				pte_a = a + va_vpn2 * 8;
				if(~pma.is_readable(pte_a)) begin
					trap_pc = raise_page_fault(va, `PTE_R, pc);
					pa = {64{1'b0}};
					return;
				end
				$display("[INFO] pte_a: %16h", pte_a);

				// 1st page table entry
				pte = mem.read(pte_a);
				// 3. pte check
				if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return;
				end
				$display("[INFO] 1st pte: %16h", pte);

				// 4. leaf check
				if(~pte[`PTE_RB] && ~pte[`PTE_WB]) begin	// not leaf
					i = 1;
					a = {8'h00, pte[53:10], 12'h000};
					// 2. 1st page table entry address
					pte_a = a + va_vpn1 * 8;
					if(~pma.is_readable(pte_a)) begin
						trap_pc = raise_page_fault(va, `PTE_R, pc);
						pa = {64{1'b0}};
						return;
					end

					// 2nd page table entry
					pte = mem.read(pte_a);
					// 3. pte check
					if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
						trap_pc = raise_page_fault(va, acc, pc);
						pa = {64{1'b0}};
						return;
					end
					$display("[INFO] 2nd pte: %16h", pte);
					// 4. leaf check
					if(~pte[`PTE_RB] && ~pte[`PTE_WB]) begin	// not leaf
						i = 0;
						a = {8'h00, pte[53:10], 12'h000};
						// 2. 1st page table entry address
						pte_a = a + va_vpn0 * 8;
						if(~pma.is_readable(pte_a)) begin
							trap_pc = raise_page_fault(va, `PTE_R, pc);
							pa = {64{1'b0}};
							return;
						end

						// 3rd page table entry
						pte = mem.read(pte_a);
						// 3. pte check
						if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
							trap_pc = raise_page_fault(va, acc, pc);
							pa = {64{1'b0}};
							return;
						end
						$display("[INFO] 3rd pte: %16h", pte);
						// 4. leaf check
						if(~pte[`PTE_RB] && ~pte[`PTE_WB]) begin	// not leaf
							trap_pc = raise_page_fault(va, acc, pc);
							pa = {64{1'b0}};
							return;
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
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
				end

				// current privilege mode check
				if(csr_c.get_mode() == `MODE_U && ~pte[`PTE_UB] ||
				   csr_c.get_mode() == `MODE_S &&  pte[`PTE_UB] && csr_c.get_m_sum()) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
				end

				// 6. misaligned sperpage
				if(i == 2 && (|pte_ppn1 || |pte_ppn0) ||
				   i == 1 &&               |pte_ppn0) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
				end

				// 7. pte.a == 0, or store access and pte.d ==0
				if(~pte[`PTE_AB] || acc[`PTE_WB] && ~pte[`PTE_DB]) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
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
						trap_pc = raise_page_fault(pte_a, `PTE_W, pc);
						pa = {64{1'b0}};
						return ;
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
				pa = {8'h00, pa_ppn2, pa_ppn1, pa_ppn0, va_ofs};
				return ;

			end else begin	// no addresds translation
				pa = va;
				return ;
			end
		end else begin	// not implemented yet.
			pa = va;
			return;
		end
	endtask

	function [`XLEN-1:0] raise_page_fault(input [`XLEN-1:0] va, input [3:0] acc, input [`XLEN-1:0] pc);
		if(acc[`PTE_RB]) begin
			return csr_c.raise_exception(`EX_LPFAULT, pc, va);
		end else if(acc[`PTE_WB]) begin
			return csr_c.raise_exception(`EX_SPFAULT, pc, va);
		end else if(acc[`PTE_XB]) begin
			return csr_c.raise_exception(`EX_IPFAULT, pc, va);
		end else begin
			return {`XLEN{1'b0}};
		end
	endfunction


	function [`XLEN-1:0] get_entry_point();
		return mem.get_entry_point();
	endfunction

	function [31:0] get_instruction(input [`XLEN-1:0] pc);
		bit [`XLEN-1:0]	tmp;
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(pc, `PTE_X, pc, tmp, trap_pc);
		if(tmp != {64{1'b0}}) begin
			return mem.read32(tmp);
		end else begin
			return 32'h0000_0000;
		end
	endfunction

	function void init(string init_file);
			mem = new(init_file);
			csr_c.init();
			lrsc_valid = 1'b0;
	endfunction

	task exec(input [`XLEN-1:0] pc, output bit [`XLEN-1:0] next_pc, output bit tohost_we, output bit [31:0] tohost);
		bit [`XLEN-1:0]		tmp;
		bit [`XLEN-1:0]		trap_pc;
		bit [32-1:0]		tmp32;
		bit [`XLEN*2-1:0]	tmp128;

		bit [32-1:0]		inst;
		bit [6:0]		opcode;
		bit [4:0]		rd0;
		bit [2:0]		funct3;
		bit [4:0]		rs1;
		bit [4:0]		rs2;
		bit [4:0]		rs3;
		bit [6:0]		funct7;
		bit [4:0]		funct5;
		bit [1:0]		funct2;
		bit			aq;
		bit			rl;
		bit [2:0]		rm;
		bit [32-1:0]		imm_i;
		bit [32-1:0]		imm_s;
		bit [32-1:0]		imm_b;
		bit [32-1:0]		imm_u;
		bit [32-1:0]		imm_j;
	
		bit [`XLEN-1:0]		imm_iw;
		bit [`XLEN-1:0]		imm_sw;
		bit [`XLEN-1:0]		imm_bw;
		bit [`XLEN-1:0]		imm_uw;
		bit [`XLEN-1:0]		imm_jw;
	
		bit [`XLEN-1:0]		uimm_w;
		
		bit [12-1:0]		csr;
		bit [6-1:0]		shamt;
	
		bit [`XLEN-1:0]		rs1_d;
		bit [`XLEN-1:0]		rs2_d;
		bit [`FLEN-1:0]		fp_rs1_d;
		bit [`FLEN-1:0]		fp_rs2_d;
		bit [`FLEN-1:0]		fp_rs3_d;

		csr_c.tick();

		tohost_we = 1'b0;


		// 1. instruction fetch
		virtual_address_translation(pc, `PTE_X, pc, tmp, trap_pc);
		if(tmp != {64{1'b0}}) begin
			inst   = mem.read32(tmp);
		end else begin
			inst   = 32'h0000_0000;
		end


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
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write8s(rd0, mem.read8(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b001: begin			// LH
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write16s(rd0, mem.read16(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b010: begin			// LW
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write32s(rd0, mem.read32(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b011: begin			// LD
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write(rd0, mem.read(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b100: begin			// LBU
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write8u(rd0, mem.read8(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b101: begin			// LHU
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write16u(rd0, mem.read16(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b110: begin			// LWU
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						rf.write32u(rd0, mem.read32(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			default: ;
			endcase
		end

		7'b01_000_11: begin	// STORE: S type
			case (funct3)
			3'b000: begin			// SB
				virtual_address_translation(rs1_d + imm_sw, `PTE_W, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_writeable(tmp)) begin
						mem.write8(rs1_d + imm_sw, rs2_d[7:0]);
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b001: begin			// SH
				virtual_address_translation(rs1_d + imm_sw, `PTE_W, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_writeable(tmp)) begin
						mem.write16(tmp, rs2_d[15:0]);
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b010: begin			// SW
				virtual_address_translation(rs1_d + imm_sw, `PTE_W, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_writeable(tmp)) begin
						mem.write32(tmp, rs2_d[31:0]);
						next_pc = pc + 'h4;
						tohost_we  = rs1_d + imm_sw == mem.get_tohost() ? 1'b1 : 1'b0;	// for testbench hack
						tohost     = rs2_d[31:0];
					end else begin
						next_pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b011: begin			// SD
				virtual_address_translation(rs1_d + imm_sw, `PTE_W, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_writeable(tmp)) begin
						mem.write(tmp, rs2_d);
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			default: ;
			endcase
		end

		7'b10_000_11: begin	// MADD
					next_pc = pc + 'h4;
		end

		7'b11_000_11: begin	// BRANCH
			case (funct3)
			3'b000:	next_pc = rs1_d == rs2_d ? pc + imm_bw : pc + 'h4;	// BEQ
			3'b001:	begin 			// BNE
				$display("[INFO] BNE %16h == %16h or not.", rs1_d, rs2_d);
				next_pc = rs1_d != rs2_d ? pc + imm_bw : pc + 'h4;
			end
			3'b100:	next_pc = $signed(rs1_d) <  $signed(rs2_d) ? pc + imm_bw : pc + 'h4;	// BLT
			3'b101:	next_pc = $signed(rs1_d) >= $signed(rs2_d) ? pc + imm_bw : pc + 'h4;	// BGE
			3'b110:	next_pc = rs1_d <  rs2_d ? pc + imm_bw : pc + 'h4;	// BLTU
			3'b111:	next_pc = rs1_d >= rs2_d ? pc + imm_bw : pc + 'h4;	// BGEU
			default: ;
			endcase
		end

		7'b00_001_11: begin	// LOAD-FP
			case (funct3)
			3'b010: begin			// FLW
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						fp.write32u(rd0, mem.read32(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b011: begin			// FLD
				virtual_address_translation(rs1_d + imm_iw, `PTE_R, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_readable(tmp)) begin
						fp.write(rd0, mem.read(tmp));
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_LAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			default: ;
			endcase
		end

		7'b01_001_11: begin	// STORE-FP
			case (funct3)
			3'b010: begin			// FSW
				virtual_address_translation(rs1_d + imm_sw, `PTE_W, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_writeable(tmp)) begin
						mem.write32(tmp, fp_rs2_d[31:0]);
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			3'b011: begin			// FSD
				virtual_address_translation(rs1_d + imm_sw, `PTE_W, pc, tmp, trap_pc);
				if(tmp != {64{1'b0}}) begin
					if(pma.is_writeable(tmp)) begin
						mem.write(tmp, fp_rs2_d);
						next_pc = pc + 'h4;
					end else begin
						next_pc = csr_c.raise_exception(`EX_SAFAULT, pc, tmp);
					end
				end else begin
					next_pc = trap_pc;
				end
			end
			default: ;
			endcase
		end

		7'b10_001_11: begin	// MSUB
					next_pc = pc + 'h4;
		end

		7'b11_001_11: begin	// JALR
			case (funct3)
			3'b000: begin
					rf.write(rd0, pc + 'h4);
					next_pc = rs1_d + imm_iw;
			end
			default: ;
			endcase
		end

		7'b01_010_11: begin	// NMSUB
					next_pc = pc + 'h4;
		end

		7'b00_011_11: begin	// MISC-MEM
			case (funct3)
			3'b000: begin	// FENCE
					next_pc = pc + 'h4;
			end
			3'b001: begin	// FENCE.I
					next_pc = pc + 'h4;
			end
			default: ;
			endcase
		end

		7'b01_011_11: begin	// AMO
			case (funct3)
			3'b010: begin
				case (funct5)
				5'b00010: begin		// LR.W
					lrsc_valid = 1'b1;
					lrsc_addr  = rs1_d;
					rf.write32s(rd0, mem.read32(rs1_d));
					next_pc = pc + 'h4;
				end
				5'b00011: begin		// SC.W
					if(lrsc_valid && lrsc_addr == rs1_d) begin
						lrsc_valid = 1'b0;
						tmp32 = mem.read32(rs1_d);
						rf.write(rd0, {`XLEN{1'b0}});
						mem.write32(rs1_d, rs2_d[31:0]);
					end else begin
						rf.write(rd0, {{`XLEN-1{1'b0}}, 1'b1});
					end
					next_pc = pc + 'h4;
				end
				5'b00001: begin		// AMOSWAP.W
					rf.write32s(rd0, mem.read32(rs1_d));
					mem.write32(rs1_d, rs2_d[31:0]);
					next_pc = pc + 'h4;
				end
				5'b00000: begin		// AMOADD.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, rs2_d[31:0] + tmp32);
					next_pc = pc + 'h4;
				end
				5'b00100: begin		// AMOXOR.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, rs2_d[31:0] ^ tmp32);
					next_pc = pc + 'h4;
				end
				5'b01100: begin		// AMOAND.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, rs2_d[31:0] & tmp32);
					next_pc = pc + 'h4;
				end
				5'b01000: begin		// AMOOR.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, rs2_d[31:0] | tmp32);
					next_pc = pc + 'h4;
				end
				5'b10000: begin		// AMOMIN.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, $signed(rs2_d[31:0]) < $signed(tmp32) ? rs2_d[31:0] : tmp32);
					next_pc = pc + 'h4;
				end
				5'b10100: begin		// AMOMAX.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, $signed(rs2_d[31:0]) > $signed(tmp32) ? rs2_d[31:0] : tmp32);
					next_pc = pc + 'h4;
				end
				5'b11000: begin		// AMOMINU.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, rs2_d[31:0] < tmp32 ? rs2_d[31:0] : tmp32);
					next_pc = pc + 'h4;
				end
				5'b11100: begin		// AMOMAXU.W
					tmp32 = mem.read32(rs1_d);
					rf.write32s(rd0, tmp32);
					mem.write32(rs1_d, rs2_d[31:0] > tmp32 ? rs2_d[31:0] : tmp32);
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
				end
				5'b00000: begin		// AMOADD.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					mem.write(rs1_d, rs2_d + tmp);
					next_pc = pc + 'h4;
				end
				5'b00100: begin		// AMOXOR.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = rs2_d ^ tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				5'b01100: begin		// AMOAND.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = rs2_d & tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				5'b01000: begin		// AMOOR.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = rs2_d | tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				5'b10000: begin		// AMOMIN.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = $signed(rs2_d) < $signed(tmp) ? rs2_d : tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				5'b10100: begin		// AMOMAX.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = $signed(rs2_d) > $signed(tmp) ? rs2_d : tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				5'b11000: begin		// AMOMINU.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = rs2_d < tmp ? rs2_d : tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				5'b11100: begin		// AMOMAXU.D
					tmp = mem.read(rs1_d);
					rf.write(rd0, tmp);
					tmp = rs2_d > tmp ? rs2_d : tmp;
					mem.write(rs1_d, tmp);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			default: ;
			endcase
		end

		7'b10_011_11: begin	// NMADD
					next_pc = pc + 'h4;
		end

		7'b11_011_11: begin	// JAL
					rf.write(rd0, pc + 'h4);
					next_pc = pc + imm_jw;
		end

		7'b00_100_11: begin	// OP-IMM
			case (funct3)
			3'b000: begin								// ADDI
					rf.write(rd0, rs1_d + imm_iw);
					next_pc = pc + 'h4;
			end
			3'b001: begin
				case (funct7[6:1])
				6'b000000: begin						// SLLI
					rf.write(rd0, rs1_d << shamt);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b010: begin								// SLTI
					rf.write(rd0, $signed(rs1_d) < $signed(imm_iw) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
					next_pc = pc + 'h4;
			end
			3'b011: begin								// SLTIU
					rf.write(rd0, rs1_d < imm_iw ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
					next_pc = pc + 'h4;
			end
			3'b100: begin								// XORI
					rf.write(rd0, rs1_d ^ imm_iw);
					next_pc = pc + 'h4;
			end
			3'b101: begin
				case (funct7[6:1])
				6'b000000: begin						// SRLI
					rf.write(rd0, rs1_d >> shamt);
					next_pc = pc + 'h4;
				end
				6'b010000: begin						// SRAI
					rf.write(rd0, $signed(rs1_d) >>> shamt);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b110: begin								// ORI
					rf.write(rd0, rs1_d | imm_iw);
					next_pc = pc + 'h4;
			end
			3'b111: begin								// ANDI
					rf.write(rd0, rs1_d & imm_iw);
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// MUL
					tmp128 = rs1_d * rs2_d;
					rf.write(rd0, tmp128[`XLEN-1:0]);
					next_pc = pc + 'h4;
				end
				7'b0100000: begin	// SUB
					rf.write(rd0, rs1_d - rs2_d);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b001: begin
				case (funct7)
				7'b0000000: begin	// SLL
					rf.write(rd0, rs1_d << rs2_d[5:0]);
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// MULH
					tmp128 = $signed(rs1_d) * $signed(rs2_d);
					rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b010: begin
				case (funct7)
				7'b0000000: begin	// SLT
					rf.write(rd0, $signed(rs1_d) < $signed(rs2_d) ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// MULHSU
					tmp128 = absXLEN(rs1_d) * rs2_d;
					tmp128 = twoscompXLENx2(rs1_d[`XLEN-1], tmp128);
					rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b011: begin
				case (funct7)
				7'b0000000: begin	// SLTU
					rf.write(rd0, rs1_d < rs2_d ? {{63{1'b0}}, 1'b1} : {64{1'b0}});
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// MULHU
					tmp128 = rs1_d * rs2_d;
					rf.write(rd0, tmp128[`XLEN*2-1:`XLEN]);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b100: begin
				case (funct7)
				7'b0000000: begin	// XOR
				 	rf.write(rd0, rs1_d ^ rs2_d);
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// DIV
					tmp = absXLEN(rs1_d) / absXLEN(rs2_d);
					tmp = twoscompXLEN(rs1_d[`XLEN-1] ^ rs2_d[`XLEN-1], tmp);
					rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : tmp);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b101: begin
				case (funct7)
				7'b0000000: begin	// SRL
					rf.write(rd0, rs1_d >> rs2_d[5:0]);
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// DIVU
					rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? {`XLEN{1'b1}} : rs1_d / rs2_d);
					next_pc = pc + 'h4;
				end
				7'b0100000: begin	// SRA
					rf.write(rd0, $signed(rs1_d) >>> rs2_d[5:0]);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b110: begin
				case (funct7)
				7'b0000000: begin	// OR
					rf.write(rd0, rs1_d | rs2_d);
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// REM
					tmp = absXLEN(rs1_d) % absXLEN(rs2_d);
					tmp = twoscompXLEN(rs1_d[`XLEN/2-1], tmp);
					rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d : tmp);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b111: begin
				case (funct7)
				7'b0000000: begin	// AND
					rf.write(rd0, rs1_d & rs2_d);
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// REMU
					rf.write(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d : rs1_d % rs2_d);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			default: ;
			endcase
		end

		7'b10_100_11: begin	// OP-FP: R type
			float_t out;
			double_t dout;
			word_t wout;
			long_t lout;

			case(funct7)
			7'b00000_00: begin		// FADD.S
					float.fadd(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
					fp.write32u(rd0, out.val);
					csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
					next_pc = pc + 'h4;
			end
			7'b00001_00: begin		// FSUB.S
					float.fsub(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
					fp.write32u(rd0, out.val);
					csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
					next_pc = pc + 'h4;
			end
			7'b00010_00: begin		// FMUL.S
					float.fmul(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
					fp.write32u(rd0, out.val);
					csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
					next_pc = pc + 'h4;
			end
			7'b00011_00: begin		// FDIV.S
					next_pc = pc + 'h4;
			end
			7'b01011_00: begin
				case (rs2)
				5'b00000: begin		// FSQRT.S
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b00101_00: begin
				case (funct3)
				3'b000: begin		// FMIN.S
					float.fmin(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
					fp.write32u(rd0, out.val);
					csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
					next_pc = pc + 'h4;
				end
				3'b001: begin		// FMAX.S
					float.fmax(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
					fp.write32u(rd0, out.val);
					csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b01000_00: begin
				case (rs2)
				5'b00001: begin		// FCVT.S.D
						fcvt_s_d.float_from_double(fp_rs1_d, out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b11000_00: begin
				case (rs2)
				5'b00000: begin		// FCVT.W.S
						fcvt_w_s.int_from_real(fp_rs1_d[31:0], wout);
						rf.write32s(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00001: begin		// FCVT.WU.S
						fcvt_w_s.uint_from_real(fp_rs1_d[31:0], wout);
						rf.write32s(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00010: begin		// FCVT.L.S
						fcvt_l_s.int_from_real(fp_rs1_d[31:0], lout);
						rf.write(rd0, lout.val);
						csr_c.set_fflags({lout.invalid, 3'h0, lout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00011: begin		// FCVT.LU.S
						fcvt_l_s.uint_from_real(fp_rs1_d[31:0], lout);
						rf.write(rd0, lout.val);
						csr_c.set_fflags({lout.invalid, 3'h0, lout.inexact});
						next_pc = pc + 'h4;
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
						next_pc = pc + 'h4;
					end
					3'b001: begin	// FCLASS.W
						rf.write32u(rd0, float.fclass(fp_rs1_d[31:0]));
						next_pc = pc + 'h4;
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
						float.feq(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						rf.write(rd0, {{32{1'b0}}, out.val});
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				3'b001: begin 		// FLT.S
						float.flt(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						rf.write(rd0, {{32{1'b0}}, out.val});
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				3'b000: begin		// FLE.S
						float.fle(fp_rs1_d[31:0], fp_rs2_d[31:0], out);
						rf.write(rd0, {{32{1'b0}}, out.val});
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b11010_00: begin
				case (rs2)
				5'b00000: begin		// FCVT.S.W
						fcvt_w_s.real_from_int(rs1_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				5'b00001: begin		// FCVT.S.WU
						fcvt_w_s.real_from_uint(rs1_d[31:0], out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				5'b00010: begin		// FCVT.S.L
						fcvt_l_s.real_from_int(rs1_d, out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
				end
				5'b00011: begin		// FCVT.S.LU
						fcvt_l_s.real_from_uint(rs1_d, out);
						fp.write32u(rd0, out.val);
						csr_c.set_fflags({out.invalid, 3'h0, out.inexact});
						next_pc = pc + 'h4;
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
						next_pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end


			7'b00000_01: begin		// FADD.D
					double.fadd(fp_rs1_d, fp_rs2_d, dout);
					fp.write(rd0, dout.val);
					csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
					next_pc = pc + 'h4;
			end
			7'b00001_01: begin		// FSUB.D
					double.fsub(fp_rs1_d, fp_rs2_d, dout);
					fp.write(rd0, dout.val);
					csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
					next_pc = pc + 'h4;
			end
			7'b00010_01: begin		// FMUL.D
					double.fmul(fp_rs1_d, fp_rs2_d, dout);
					fp.write(rd0, dout.val);
					csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
					next_pc = pc + 'h4;
			end
			7'b00011_01: begin		// FDIV.D
					next_pc = pc + 'h4;
			end
			7'b01011_01: begin
				case (rs2)
				5'b00000: begin		// FSQRT.D
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b00100_01: begin
				case (funct3)
				3'b000: begin		// FSGNJ.D
					tmp = fp.read(rs2);
					if(tmp[63]) begin
						tmp = fp.read(rs1);
						fp.write(rd0, {1'b1, tmp[62:0]});
					end else begin
						tmp = fp.read(rs1);
						fp.write(rd0, {1'b0, tmp[62:0]});
					end
					next_pc = pc + 'h4;
				end
				3'b001: begin		// FSGNJN.D
					tmp = fp.read(rs2);
					if(tmp[63]) begin
						tmp = fp.read(rs1);
						fp.write(rd0, {1'b0, tmp[62:0]});
					end else begin
						tmp = fp.read(rs1);
						fp.write(rd0, {1'b1, tmp[62:0]});
					end
					next_pc = pc + 'h4;
				end
				3'b010: begin		// FSGNJX.D
					tmp = fp.read(rs2);
					if(tmp[63]) begin
						tmp = fp.read(rs1);
						fp.write(rd0, {1'b1 ^ tmp[63], tmp[62:0]});
					end else begin
						tmp = fp.read(rs1);
						fp.write(rd0, {1'b0 ^ tmp[63], tmp[62:0]});
					end
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b00101_01: begin
				case (funct3)
				3'b000: begin		// FMIN.D
					double.fmin(fp_rs1_d, fp_rs2_d, dout);
					fp.write(rd0, dout.val);
					csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
					next_pc = pc + 'h4;
				end
				3'b001: begin		// FMAX.D
					double.fmax(fp_rs1_d, fp_rs2_d, dout);
					fp.write(rd0, dout.val);
					csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b01000_01: begin
				case (rs2)
				5'b00000: begin		// FCVT.D.S
						fcvt_s_d.double_from_float(fp_rs1_d[31:0], dout);
						fp.write(rd0, dout.val);
						csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
						next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b11000_01: begin
				case (rs2)
				5'b00000: begin		// FCVT.W.D
						fcvt_w_d.int_from_real(fp_rs1_d, wout);
						rf.write32s(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00001: begin		// FCVT.WU.D
						fcvt_w_d.uint_from_real(fp_rs1_d, wout);
						rf.write32s(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00010: begin		// FCVT.L.D
						fcvt_l_d.int_from_real(fp_rs1_d, lout);
						rf.write(rd0, lout.val);
						csr_c.set_fflags({lout.invalid, 3'h0, lout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00011: begin		// FCVT.LU.D
						fcvt_l_d.uint_from_real(fp_rs1_d, lout);
						rf.write(rd0, lout.val);
						csr_c.set_fflags({lout.invalid, 3'h0, lout.inexact});
						next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b11100_01: begin
				case (rs2)
				5'b00000: begin
					case (funct3)
					3'b000: begin	// FMV.X.D
						rf.write(rd0, fp_rs1_d);
						next_pc = pc + 'h4;
					end
					3'b001: begin	// FCLASS.D
						rf.write32u(rd0, double.fclass(fp_rs1_d));
						next_pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				default: ;
				endcase
			end
			7'b10100_01: begin
				case (funct3)
				3'b010: begin 		// FEQ.D
						double.feq(fp_rs1_d, fp_rs2_d, wout);
						rf.write32u(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				3'b001: begin 		// FLT.D
						double.flt(fp_rs1_d, fp_rs2_d, wout);
						rf.write32u(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				3'b000: begin		// FLE.D
						double.fle(fp_rs1_d, fp_rs2_d, wout);
						rf.write32u(rd0, wout.val);
						csr_c.set_fflags({wout.invalid, 3'h0, wout.inexact});
						next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b11010_01: begin
				case (rs2)
				5'b00000: begin		// FCVT.D.W
						fcvt_w_d.real_from_int(rs1_d[31:0], dout);
						fp.write(rd0, dout.val);
						csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00001: begin		// FCVT.D.WU
						fcvt_w_d.real_from_uint(rs1_d[31:0], dout);
						fp.write(rd0, dout.val);
						csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00010: begin		// FCVT.D.L
						fcvt_l_d.real_from_int(rs1_d, dout);
						fp.write(rd0, dout.val);
						csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
						next_pc = pc + 'h4;
				end
				5'b00011: begin		// FCVT.D.LU
						fcvt_l_d.real_from_uint(rs1_d, dout);
						fp.write(rd0, dout.val);
						csr_c.set_fflags({dout.invalid, 3'h0, dout.inexact});
						next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			7'b11110_01: begin
				case (rs2)
				5'b00000: begin
					case (funct3)
					3'b000: begin	// FMV.D.X
						fp.write(rd0, rs1_d);
						next_pc = pc + 'h4;
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
							next_pc = pc + 'h4;
						end else begin
							next_pc = tmp;
						end
					end
					5'b00001: begin		// EBREAK
							next_pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				7'b0001000: begin
					case(rs2)
					5'b00010: begin		// SRET
							next_pc = csr_c.sret();	// sepc
					end
					default: ;
					endcase
				end
				7'b0011000: begin
					case(rs2)
					5'b00010: begin		// MRET
							next_pc = csr_c.mret();	// mepc
					end
					default: ;
					endcase
				end
				7'b0001001: begin
					case(rd0)
					5'h00: begin		// SFENCE.VMA
							next_pc = pc + 'h4;
					end
					default: ;
					endcase
				end
				7'b0001011: begin
					case(rd0)
					5'b00000: begin		// SINVAL.VMA
							next_pc = pc + 'h4;
					end
					default: ;
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
				next_pc = pc + 'h4;
			end
			3'b010: begin		// CSRRS
				rf.write(rd0, csr_c.read(csr));
				if(rs1 != 5'h00) begin
					csr_c.set(csr, rs1_d);
				end
				next_pc = pc + 'h4;
			end
			3'b011: begin		// CSRRC
				rf.write(rd0, csr_c.read(csr));
				if(rs1 != 5'h00) begin
					csr_c.clear(csr, rs1_d);
				end
				next_pc = pc + 'h4;
			end
			3'b101: begin		// CSRRWI
				rf.write(rd0, csr_c.read(csr));
				csr_c.write(csr, uimm_w);
				next_pc = pc + 'h4;
			end
			3'b110: begin		// CSRRSI
				rf.write(rd0, csr_c.read(csr));
				csr_c.set(csr, uimm_w);
				next_pc = pc + 'h4;
			end
			3'b111: begin		// CSRRCI
				rf.write(rd0, csr_c.read(csr));
				csr_c.clear(csr, uimm_w);
				next_pc = pc + 'h4;
			end
			default: ;
			endcase
		end

		7'b00_101_11: begin	// AUIPC
					rf.write(rd0, pc + imm_uw);
					next_pc = pc + 'h4;
		end

		7'b01_101_11: begin	// LUI
					rf.write(rd0, imm_uw);
					next_pc = pc + 'h4;
		end

		7'b00_110_11: begin	// OP-IMM-32
			case (funct3)
			3'b000: begin			// ADDIW
					rf.write32s(rd0, rs1_d[31:0] + imm_iw[31:0]);
					next_pc = pc + 'h4;
			end
			3'b001: begin
				case (funct7)
				7'b0000000: begin	// SLLIW
					rf.write32s(rd0, rs1_d[31:0] << shamt[4:0]);
					next_pc = pc + 'h4;
				end
				default: ;
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
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// MULW
					tmp32 = rs1_d[31:0] * rs2_d[31:0];
					rf.write32s(rd0, tmp32);
					next_pc = pc + 'h4;
				end
				7'b0100000: begin	// SUBW
					rf.write32s(rd0, rs1_d[31:0] - rs2_d[31:0]);
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b001: begin
				case (funct7)
				7'b0000000: begin	// SLLW
					rf.write32s(rd0, rs1_d[31:0] << rs2_d[4:0]);
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b101: begin
				case (funct7)
				7'b0000000: begin	// SRLW
					rf.write32s(rd0, rs1_d[31:0] >> rs2_d[4:0]);
					next_pc = pc + 'h4;
				end
				7'b0000001: begin	// DIVUW
					rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? {32{1'b1}} : rs1_d[31:0] / rs2_d[31:0]);
					next_pc = pc + 'h4;
				end
				7'b0100000: begin	// SRAW
					rf.write32s(rd0, $signed(rs1_d[31:0]) >>> rs2_d[4:0]);
					next_pc = pc + 'h4;
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
					next_pc = pc + 'h4;
				end
				default: ;
				endcase
			end
			3'b111: begin
				case (funct7)
				7'b0000001: begin	// REMUW
					rf.write32s(rd0, rs2_d == {`XLEN{1'b0}} ? rs1_d[`XLEN/2-1:0] : rs1_d[31:0] % rs2_d[31:0]);
					next_pc = pc + 'h4;
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

	endtask

endclass: ISS;

`endif	// _iss_sv_
