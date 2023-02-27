`ifndef _mmu_sv_
`define _mmu_sv_

`include "CSR.sv"
`include "PMA.sv"
`include "ELF.sv"

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

class MMU;
	CSR	csr_c;
	PMA	pma;
	ELF	mem;

	typedef struct packed {
		bit			is_success;
		bit [`XLEN-1:0]		addr;
	} vat_t;

	typedef struct packed {
		bit			is_success;
		bit [`XLEN-1:0]		data;
	} vread_t;

	function new (input CSR csr, PMA p, ELF elf);
		csr_c = csr;
		pma = p;
		mem = elf;
	endfunction

	task virtual_address_translation(input [`XLEN-1:0] va, input [3:0] acc, input [`XLEN-1:0] pc, output [`XLEN-1:0] pa, output [`XLEN-1:0] trap_pc);
		trap_pc = {`XLEN{1'b0}};
		if(csr_c.get_satp_mode() == 4'h00) begin
			pa = va;
			return;
		end else if(csr_c.get_satp_mode() == 4'd08) begin	// Sv39
			bit [1:0] ldst_mode = csr_c.get_ldst_mode();
			if((acc[`PTE_RB] || acc[`PTE_WB]) && (ldst_mode == `MODE_S || ldst_mode == `MODE_U) ||
			    acc[`PTE_XB] && (csr_c.get_mode() == `MODE_S || csr_c.get_mode() == `MODE_U)) begin
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

//				$display("[INFO] Sv39 translate on: %16h", va);

				// virtual address check
				if((~va[38] | ~&va[63:39]) & (va[38] | |va[63:39])) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return;
				end
//				$display("[INFO] a: %16h", a);

				// 2. 1st page table entry address
				pte_a = a + va_vpn2 * 8;
//				$display("[INFO] pte_a: %16h", pte_a);
				if(~pma.is_readable(pte_a)) begin
					trap_pc = raise_page_fault(va, `PTE_R, pc);
					pa = {64{1'b0}};
					return;
				end

				// 1st page table entry
				pte = mem.read(pte_a);
//				$display("[INFO] 1st pte: %16h:%16h", pte_a, pte);
				// 3. pte check
				if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return;
				end

				// 4. leaf check
				if(~pte[`PTE_RB] && ~pte[`PTE_XB]) begin	// not leaf
					i = 1;
					a = {8'h00, pte[53:10], 12'h000};
					// 2. 2nd page table entry address
					pte_a = a + va_vpn1 * 8;
					if(~pma.is_readable(pte_a)) begin
						trap_pc = raise_page_fault(va, `PTE_R, pc);
						pa = {64{1'b0}};
						return;
					end

					// 2nd page table entry
					pte = mem.read(pte_a);
//					$display("[INFO] 2nd pte: %16h:%16h", pte_a, pte);
					// 3. pte check
					if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
						trap_pc = raise_page_fault(va, acc, pc);
						pa = {64{1'b0}};
						return;
					end
					// 4. leaf check
					if(~pte[`PTE_RB] && ~pte[`PTE_XB]) begin	// not leaf
						i = 0;
						a = {8'h00, pte[53:10], 12'h000};
						// 2. 3rd page table entry address
						pte_a = a + va_vpn0 * 8;
						if(~pma.is_readable(pte_a)) begin
							trap_pc = raise_page_fault(va, `PTE_R, pc);
							pa = {64{1'b0}};
							return;
						end

						// 3rd page table entry
						pte = mem.read(pte_a);
//						$display("[INFO] 3rd pte: %16h:%16h, a:%8h, va_vpn0 = %8h", pte_a, pte, a, va_vpn0);
						// 3. pte check
						if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
							trap_pc = raise_page_fault(va, acc, pc);
							pa = {64{1'b0}};
							return;
						end
						// 4. leaf check
						if(~pte[`PTE_RB] && ~pte[`PTE_XB]) begin	// not leaf
							$display("[INFO] 3rd pte is not leaf.");
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
					acc[`PTE_XB] && ~pte[`PTE_XB] ||
				        acc[`PTE_XB] && ~pte[`PTE_RB] && csr_c.get_mxr()
				) begin
					$display("[INFO] access type check fails: acc %b", acc);
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
				end

				// current privilege mode check
				if(~(csr_c.get_ldst_mode() == `MODE_M && ~pte[`PTE_UB] ||
				     csr_c.get_ldst_mode() == `MODE_U &&  pte[`PTE_UB] ||
				     csr_c.get_ldst_mode() == `MODE_S && ~pte[`PTE_UB] ||
				     csr_c.get_ldst_mode() == `MODE_S &&  pte[`PTE_UB] && csr_c.get_sum())) begin
					$display("[INFO] current privilege mode: %d check fails.", csr_c.get_mode());
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
				end

				// 6. misaligned superpage
				if(i == 2 && (|pte_ppn1 || |pte_ppn0) ||
				   i == 1 &&               |pte_ppn0) begin
					$display("[INFO] misaligned superpage.");
					trap_pc = raise_page_fault(va, acc, pc);
					pa = {64{1'b0}};
					return ;
				end

				// 7. pte.a == 0, or store access and pte.d ==0
				if(~pte[`PTE_AB] || acc[`PTE_WB] && ~pte[`PTE_DB]) begin
					$display("[INFO] pte.a == 0 or pte.d == 0 at store.");
					trap_pc = raise_page_fault(va, acc, pc);
					$display("[INFO] trap_pc = %16h", trap_pc);
					pa = {64{1'b0}};
					return ;
				end

				va_vpn = i == 2 ? va_vpn2 : i == 1 ? va_vpn1 : va_vpn0;
				pte_cmp_a = a + va_vpn * 8;
				pte_cmp = mem.read(pte_cmp_a);
				if(pte == pte_cmp) begin
					pte = pte | {{56{1'b0}}, `PTE_A};
					if(acc[`PTE_WB]) begin
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

//				$display("[INFO] va -> pa: %16h -> %16h", va, {8'h00, pa_ppn2, pa_ppn1, pa_ppn0, va_ofs});
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
		if(acc[`PTE_WB]) begin
			return csr_c.raise_exception(`EX_SPFAULT, pc, va);
		end else if(acc[`PTE_RB]) begin
			return csr_c.raise_exception(`EX_LPFAULT, pc, va);
		end else if(acc[`PTE_XB]) begin
			return csr_c.raise_exception(`EX_IPFAULT, pc, va);
		end else begin
			return {`XLEN{1'b0}};
		end
	endfunction

	task vat_facc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_X, pc, out.addr, trap_pc);
		if(out.addr != {64{1'b0}}) begin
			if(pma.is_readable(out.addr)) begin
				out.is_success = 1'b1;
			end else begin
				out.is_success = 1'b0;
				out.addr = csr_c.raise_exception(`EX_IAFAULT, pc, out.addr);
			end
		end else begin
			out.is_success = 1'b0;
			out.addr = trap_pc;
		end
	endtask

	task vat_racc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_R, pc, out.addr, trap_pc);
		if(out.addr != {64{1'b0}}) begin
			if(pma.is_readable(out.addr)) begin
				out.is_success = 1'b1;
			end else begin
				out.is_success = 1'b0;
				out.addr = csr_c.raise_exception(`EX_LAFAULT, pc, out.addr);
			end
		end else begin
			out.is_success = 1'b0;
			out.addr = trap_pc;
		end
	endtask

	task vat_wacc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_W, pc, out.addr, trap_pc);
		if(out.addr != {64{1'b0}}) begin
			if(pma.is_writeable(out.addr)) begin
				out.is_success = 1'b1;
			end else begin
				out.is_success = 1'b0;
				out.addr = csr_c.raise_exception(`EX_SAFAULT, pc, out.addr);
			end
		end else begin
			out.is_success = 1'b0;
			out.addr = trap_pc;
		end
	endtask

	task vat_rwacc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_R | `PTE_W, pc, out.addr, trap_pc);
		if(out.addr != {64{1'b0}}) begin
			if(!pma.is_readable(out.addr)) begin
				out.is_success = 1'b0;
				out.addr = csr_c.raise_exception(`EX_LAFAULT, pc, out.addr);
			end else if(!pma.is_writeable(out.addr)) begin
				out.is_success = 1'b0;
				out.addr = csr_c.raise_exception(`EX_SAFAULT, pc, out.addr);
			end else begin
				out.is_success = 1'b1;
			end
		end else begin
			out.is_success = 1'b0;
			out.addr = trap_pc;
		end
	endtask

	task vat_read64(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vread_t out);
		vat_t	vat;
		vat_racc(va, pc, vat);
		if(vat.is_success) begin
			out.is_success = 1'b1;
			out.data = mem.read(vat.addr);
		end else begin
			out.is_success = 1'b0;
			out.data = vat.addr;
		end
	endtask

	task vat_read32u(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vread_t out);
		vat_t	vat;
		vat_racc(va, pc, vat);
		if(vat.is_success) begin
			out.is_success = 1'b1;
			out.data = {{`XLEN-32{1'b0}}, mem.read32(vat.addr)};
		end else begin
			out.is_success = 1'b0;
			out.data = vat.addr;
		end
	endtask

	task vat_read32s(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vread_t out);
		vat_t	vat;
		bit [31:0] od;
		vat_racc(va, pc, vat);
		if(vat.is_success) begin
			out.is_success = 1'b1;
			od = mem.read32(vat.addr);
			out.data = {{`XLEN-32{od[31]}}, od};
		end else begin
			out.is_success = 1'b0;
			out.data = vat.addr;
		end
	endtask

endclass : MMU;

`endif	// _mmu_sv_
