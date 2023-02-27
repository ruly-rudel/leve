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
		union packed {
			bit [`XLEN-1:0]	addr;
			bit [`XLEN-1:0]	trap_pc;
		} result;
	} vat_t;

	typedef struct packed {
		bit			is_success;
		union packed {
			bit [`XLEN-1:0]	data;
			bit [`XLEN-1:0]	trap_pc;
		} result;
	} vret_t;

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
		virtual_address_translation(va, `PTE_X, pc, out.result.addr, trap_pc);
		if(out.result.addr != {64{1'b0}}) begin
			if(pma.is_readable(out.result.addr)) begin
				out.is_success = 1'b1;
			end else begin
				out.is_success = 1'b0;
				out.result.trap_pc = csr_c.raise_exception(`EX_IAFAULT, pc, out.result.addr);
			end
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = trap_pc;
		end
	endtask

	task vat_racc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_R, pc, out.result.addr, trap_pc);
		if(out.result.addr != {64{1'b0}}) begin
			if(pma.is_readable(out.result.addr)) begin
				out.is_success = 1'b1;
			end else begin
				out.is_success = 1'b0;
				out.result.trap_pc = csr_c.raise_exception(`EX_LAFAULT, pc, out.result.addr);
			end
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = trap_pc;
		end
	endtask

	task vat_wacc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_W, pc, out.result.addr, trap_pc);
		if(out.result.addr != {64{1'b0}}) begin
			if(pma.is_writeable(out.result.addr)) begin
				out.is_success = 1'b1;
			end else begin
				out.is_success = 1'b0;
				out.result.trap_pc = csr_c.raise_exception(`EX_SAFAULT, pc, out.result.addr);
			end
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = trap_pc;
		end
	endtask

	task vat_rwacc(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vat_t out);
		bit [`XLEN-1:0]	trap_pc;
		virtual_address_translation(va, `PTE_R | `PTE_W, pc, out.result.addr, trap_pc);
		if(out.result.addr != {64{1'b0}}) begin
			if(!pma.is_readable(out.result.addr)) begin
				out.is_success = 1'b0;
				out.result.trap_pc = csr_c.raise_exception(`EX_LAFAULT, pc, out.result.addr);
			end else if(!pma.is_writeable(out.result.addr)) begin
				out.is_success = 1'b0;
				out.result.trap_pc = csr_c.raise_exception(`EX_SAFAULT, pc, out.result.addr);
			end else begin
				out.is_success = 1'b1;
			end
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = trap_pc;
		end
	endtask

	task vat_write64(input [`XLEN-1:0] va, input [`XLEN-1:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_write32(va, data[31:0], pc, vat1);
		if(vat1.is_success) begin
			vat_write32(va + 'h4, data[63:32], pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {`XLEN{1'b0}};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_write32(input [`XLEN-1:0] va, input [31:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_write16(va, data[15:0], pc, vat1);
		if(vat1.is_success) begin
			vat_write16(va + 'h2, data[31:16], pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {`XLEN{1'b0}};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_write16(input [`XLEN-1:0] va, input [15:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_write8(va, data[7:0], pc, vat1);
		if(vat1.is_success) begin
			vat_write8(va + 'b1, data[15:8], pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {`XLEN{1'b0}};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_write8(input [`XLEN-1:0] va, input [7:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		bit [7:0] od;
		vat_wacc(va, pc, vat);
		if(vat.is_success) begin
			out.is_success = 1'b1;
			mem.write8(vat.result.addr, data);
			out.result.data = {`XLEN{1'b0}};
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

	task vat_read64(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_read32(va, pc, vat1);
		if(vat1.is_success) begin
			vat_read32(va + 'h4, pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {vat2.result.data[31:0], vat1.result.data[31:0]};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_read32(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_read16(va, pc, vat1);
		if(vat1.is_success) begin
			vat_read16(va + 'h2, pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {{`XLEN-32{1'b0}}, vat2.result.data[15:0], vat1.result.data[15:0]};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_read16(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_read8(va, pc, vat1);
		if(vat1.is_success) begin
			vat_read8(va + 'b1, pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {{`XLEN-16{1'b0}}, vat2.result.data[7:0], vat1.result.data[7:0]};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_read8(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		bit [7:0] od;
		vat_racc(va, pc, vat);
		if(vat.is_success) begin
			out.is_success = 1'b1;
			od = mem.read8(vat.result.addr);
			out.result.data = {{`XLEN-8{1'b0}}, od};
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

	task vat_fetch32(input [`XLEN-1:0] pc, output vret_t out);
		vret_t	vat1, vat2;
		vat_fetch16(pc, pc, vat1);
		if(vat1.is_success) begin
			vat_fetch16(pc + 'h2, pc, vat2);
			if(vat2.is_success) begin
				out.is_success = 1'b1;
				out.result.data = {{`XLEN-32{1'b0}}, vat2.result.data[15:0], vat1.result.data[15:0]};
			end else begin
				out = vat2;
			end
		end else begin
			out = vat1;
		end
	endtask

	task vat_fetch16(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		bit [15:0] od;
		vat_facc(va, pc, vat);
		if(vat.is_success) begin
			out.is_success = 1'b1;
			od = mem.read16(vat.result.addr);
			out.result.data = {{`XLEN-16{1'b0}}, od};
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

endclass : MMU;

`endif	// _mmu_sv_
