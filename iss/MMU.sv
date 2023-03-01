`ifndef _mmu_sv_
`define _mmu_sv_

`include "CSR.sv"
`include "PMA.sv"
`include "ELF.sv"
`include "FRAG_MEMORY.sv"

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
	PMA		pma = new;
	FRAG_MEMORY	mem;
	CSR		csr;

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

	function new (input CSR c, input FRAG_MEMORY fm);
		csr = c;
		mem = fm;
	endfunction

	task virtual_address_translation(input [`XLEN-1:0] va, input [`XLEN-1:0] va_fault, input [3:0] acc, input [`XLEN-1:0] pc, output vat_t pa);
		if(csr.get_satp_mode() == 4'h00) begin
			pa.is_success  = 1'b1;
			pa.result.addr = va;
			return;
		end else if(csr.get_satp_mode() == 4'd08) begin	// Sv39
			bit [1:0] ldst_mode = csr.get_ldst_mode();
			if((acc[`PTE_RB] || acc[`PTE_WB]) && (ldst_mode == `MODE_S || ldst_mode == `MODE_U) ||
			    acc[`PTE_XB] && (csr.get_mode() == `MODE_S || csr.get_mode() == `MODE_U)) begin
				// 1. read satp
				bit [`XLEN-1:0]	a = {8'h00, csr.get_satp_ppn(), 12'h000};
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
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
					return;
				end
//				$display("[INFO] a: %16h", a);

				// 2. 1st page table entry address
				pte_a = a + va_vpn2 * 8;
//				$display("[INFO] pte_a: %16h", pte_a);
				if(~pma.is_readable(pte_a)) begin
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, `PTE_R, pc);
					return;
				end

				// 1st page table entry
				pte = mem.read64(pte_a);
//				$display("[INFO] 1st pte: %16h:%16h", pte_a, pte);
				// 3. pte check
				if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
					return;
				end

				// 4. leaf check
				if(~pte[`PTE_RB] && ~pte[`PTE_XB]) begin	// not leaf
					i = 1;
					a = {8'h00, pte[53:10], 12'h000};
					// 2. 2nd page table entry address
					pte_a = a + va_vpn1 * 8;
					if(~pma.is_readable(pte_a)) begin
						pa.is_success = 1'b0;
						pa.result.trap_pc = raise_page_fault(va_fault, `PTE_R, pc);
						return;
					end

					// 2nd page table entry
					pte = mem.read64(pte_a);
//					$display("[INFO] 2nd pte: %16h:%16h", pte_a, pte);
					// 3. pte check
					if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
						pa.is_success = 1'b0;
						pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
						return;
					end
					// 4. leaf check
					if(~pte[`PTE_RB] && ~pte[`PTE_XB]) begin	// not leaf
						i = 0;
						a = {8'h00, pte[53:10], 12'h000};
						// 2. 3rd page table entry address
						pte_a = a + va_vpn0 * 8;
						if(~pma.is_readable(pte_a)) begin
							pa.is_success = 1'b0;
							pa.result.trap_pc = raise_page_fault(va_fault, `PTE_R, pc);
							return;
						end

						// 3rd page table entry
						pte = mem.read64(pte_a);
//						$display("[INFO] 3rd pte: %16h:%16h, a:%8h, va_vpn0 = %8h", pte_a, pte, a, va_vpn0);
						// 3. pte check
						if(~pte[`PTE_VB] || ~pte[`PTE_RB] & pte[`PTE_WB] || pte[9:8] != 2'h0 || |pte[63:54]) begin
							pa.is_success = 1'b0;
							pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
							return;
						end
						// 4. leaf check
						if(~pte[`PTE_RB] && ~pte[`PTE_XB]) begin	// not leaf
							$display("[INFO] 3rd pte is not leaf.");
							pa.is_success = 1'b0;
							pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
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
				        acc[`PTE_XB] && ~pte[`PTE_RB] && csr.get_mxr()
				) begin
					$display("[INFO] access type check fails: acc %b", acc);
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
					return ;
				end

				// current privilege mode check
				if(~(csr.get_ldst_mode() == `MODE_M && ~pte[`PTE_UB] ||
				     csr.get_ldst_mode() == `MODE_U &&  pte[`PTE_UB] ||
				     csr.get_ldst_mode() == `MODE_S && ~pte[`PTE_UB] ||
				     csr.get_ldst_mode() == `MODE_S &&  pte[`PTE_UB] && csr.get_sum())) begin
					$display("[INFO] current privilege mode: %d check fails.", csr.get_mode());
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
					return ;
				end

				// 6. misaligned superpage
				if(i == 2 && (|pte_ppn1 || |pte_ppn0) ||
				   i == 1 &&               |pte_ppn0) begin
					$display("[INFO] misaligned superpage.");
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
					return ;
				end

				// 7. pte.a == 0, or store access and pte.d ==0
				if(~pte[`PTE_AB] || acc[`PTE_WB] && ~pte[`PTE_DB]) begin
					$display("[INFO] pte.a == 0 or pte.d == 0 at store.");
					pa.is_success = 1'b0;
					pa.result.trap_pc = raise_page_fault(va_fault, acc, pc);
					$display("[INFO] trap_pc = %16h", pa.result.trap_pc);
					return ;
				end

				va_vpn = i == 2 ? va_vpn2 : i == 1 ? va_vpn1 : va_vpn0;
				pte_cmp_a = a + va_vpn * 8;
				pte_cmp = mem.read64(pte_cmp_a);
				if(pte == pte_cmp) begin
					pte = pte | {{56{1'b0}}, `PTE_A};
					if(acc[`PTE_WB]) begin
						pte = pte | {{56{1'b0}}, `PTE_D};
					end
					if(!pma.is_writeable(pte_a)) begin
						pa.is_success = 1'b0;
						pa.result.trap_pc = raise_page_fault(va_fault, `PTE_W, pc);
						return ;
					end else begin
						mem.write64(pte_a, pte);
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
				pa.is_success  = 1'b1;
				pa.result.addr = {8'h00, pa_ppn2, pa_ppn1, pa_ppn0, va_ofs};
				return ;

			end else begin	// no addresds translation
				pa.is_success  = 1'b1;
				pa.result.addr = va;
				return ;
			end
		end else begin	// not implemented yet.
			pa.is_success  = 1'b1;
			pa.result.addr = va;
			return;
		end
	endtask

	function [`XLEN-1:0] raise_page_fault(input [`XLEN-1:0] va, input [3:0] acc, input [`XLEN-1:0] pc);
		if(acc[`PTE_WB]) begin
			return csr.raise_exception(`EX_SPFAULT, pc, va);
		end else if(acc[`PTE_RB]) begin
			return csr.raise_exception(`EX_LPFAULT, pc, va);
		end else if(acc[`PTE_XB]) begin
			return csr.raise_exception(`EX_IPFAULT, pc, va);
		end else begin
			return {`XLEN{1'b0}};
		end
	endfunction

	task vat_acc(input [`XLEN-1:0] va, input [`XLEN-1:0] va_fault, input [`XLEN-1:0] pc, input [3:0] acc, input [3:0] fault, output vat_t out);
		virtual_address_translation(va, va_fault, acc, pc, out);
		if(out.is_success) begin
			if(!pma.is_accessable(out.result.addr, acc)) begin
				out.is_success = 1'b0;
				out.result.trap_pc = csr.raise_exception(fault, pc, out.result.addr);
			end
		end
	endtask

	task vat_racc(input [`XLEN-1:0] va, input [`XLEN-1:0] va_fault, input [`XLEN-1:0] pc, output vat_t out);
		vat_acc(va, va_fault, pc, `PTE_R, `EX_LAFAULT, out);
	endtask

	task vat_wacc(input [`XLEN-1:0] va, input [`XLEN-1:0] va_fault, input [`XLEN-1:0] pc, output vat_t out);
		vat_acc(va, va_fault, pc, `PTE_W, `EX_SAFAULT, out);
	endtask

	task vat_rwacc(input [`XLEN-1:0] va, input [`XLEN-1:0] va_fault, input [`XLEN-1:0] pc, output vat_t out);
		vat_acc(va, va_fault, pc, `PTE_R | `PTE_W, `EX_SAFAULT, out);
	endtask

	task vat_facc(input [`XLEN-1:0] va, input [`XLEN-1:0] va_fault, input [`XLEN-1:0] pc, output vat_t out);
		vat_acc(va, va_fault, pc, `PTE_X, `EX_IAFAULT, out);
	endtask

	task vat_write64(input [`XLEN-1:0] va, input [`XLEN-1:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vat_t		vat1, vat2, vat3;
		bit [32*2-1:0]	rdata;

		vat_wacc(va, va, pc, vat1);
		if(!vat1.is_success) begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat1.result.trap_pc;
			return ;
		end

		vat_wacc(va + 'h4, va, pc, vat2);
		if(!vat2.is_success) begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat2.result.trap_pc;
			return ;
		end


		if(va[1:0] == 2'h0) begin
			out.is_success = 1'b1;
			out.result.data = vat1.result.addr;	// for testbench hack
			mem.write32(vat1.result.addr, data[31:0]);
			mem.write32(vat2.result.addr, data[63:32]);
			return ;
		end

		vat_racc(va + 'h8, va, pc, vat3);
		if(!vat3.is_success) begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat3.result.trap_pc;
			return ;
		end

		rdata[31:0] = mem.read32(vat1.result.addr);
		rdata[63:32] = mem.read32(vat3.result.addr);

		out.is_success = 1'b1;
		out.result.data = vat1.result.addr;	// for testbench hack
		case(va[1:0])
		2'h0: ;
		2'h1: begin
			mem.write32(vat1.result.addr, {data[23:0], rdata[7:0]});
			mem.write32(vat2.result.addr,  data[32+24-1:24]);
			mem.write32(vat3.result.addr, {rdata[63:32+8], data[63:32+24]});
		end
		2'h2: begin
			mem.write32(vat1.result.addr, {data[15:0], rdata[15:0]});
			mem.write32(vat2.result.addr,  data[32+16-1:16]);
			mem.write32(vat3.result.addr, {rdata[63:32+16], data[63:32+16]});
		end
		2'h3: begin
			mem.write32(vat1.result.addr, {data[7:0], rdata[23:0]});
			mem.write32(vat2.result.addr,  data[32+8-1:8]);
			mem.write32(vat3.result.addr, {rdata[63:32+24], data[63:32+8]});
		end
		endcase
	endtask

	task vat_write32(input [`XLEN-1:0] va, input [31:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat, vat2;
		vat_wacc(va, va, pc, vat);
		if(vat.is_success) begin
			if(va[1:0] == 2'h0) begin
				out.is_success = 1'b1;
				out.result.data = vat.result.addr;		// for testbench hack
				mem.write32(vat.result.addr, data);
			end else begin
				bit [63:0] rdata;
				rdata[31:0] = mem.read32(vat.result.addr);

				vat_wacc(va + 'h4, va, pc, vat2);
				if(vat2.is_success) begin
					out.is_success = 1'b1;
					out.result.data = vat.result.addr;	// for testbench hack
					rdata[63:32] = mem.read32(vat2.result.addr);
					case(va[1:0])
					2'h0: ;		// not selected
					2'h1: begin
						mem.write32(vat.result.addr,  {data[23:0], rdata[7:0]});
						mem.write32(vat2.result.addr, {rdata[63:40], data[31:24]});
					end
					2'h2: begin
						mem.write32(vat.result.addr,  { data[15:0],  rdata[15:0]});
						mem.write32(vat2.result.addr, {rdata[63:48],  data[31:16]});
					end
					2'h3: begin
						mem.write32(vat.result.addr,  { data[7:0],  rdata[23:0]});
						mem.write32(vat2.result.addr, {rdata[63:56], data[31:8]});
					end
					endcase
				end else begin
					out.is_success = 1'b0;
					out.result.trap_pc = vat2.result.trap_pc;
				end
			end
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

	task vat_write16(input [`XLEN-1:0] va, input [15:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat, vat2;
		vat_wacc(va, va, pc, vat);
		if(vat.is_success) begin
			case(va[1:0])
			2'h0: begin
				out.is_success = 1'b1;
				mem.write16(vat.result.addr, data);
			end
			2'h1: begin
				bit [31:0] rdata;
				out.is_success = 1'b1;
				rdata = mem.read32(vat.result.addr);
				mem.write32(vat.result.addr, {rdata[31:24], data, rdata[7:0]});
			end
			2'h2: begin
				out.is_success = 1'b1;
				mem.write16(vat.result.addr, data);
			end
			2'h3: begin
				vat_wacc(va + 'b1, va, pc, vat2);
				if(vat2.is_success) begin
					out.is_success = 1'b1;
					mem.write8(vat.result.addr,  data[7:0]);
					mem.write8(vat2.result.addr, data[15:8]);
				end else begin
					out.is_success = 1'b0;
					out.result.trap_pc = vat2.result.trap_pc;
				end
			end
			endcase
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

	task vat_write8(input [`XLEN-1:0] va, input [7:0] data, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		bit [7:0] od;
		vat_wacc(va, va, pc, vat);
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
		vat_t		vat;
		bit [32*3-1:0]	data;

		vat_racc(va, va, pc, vat);
		if(!vat.is_success) begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
			return ;
		end
		data[31:0] = mem.read32(vat.result.addr);

		vat_racc(va + 'h4, va, pc, vat);
		if(!vat.is_success) begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
			return ;
		end
		data[63:32] = mem.read32(vat.result.addr);

		if(va[1:0] == 2'h0) begin
			out.is_success = 1'b1;
			out.result.data = data[63:0];
			return ;
		end

		vat_racc(va + 'h8, va, pc, vat);
		if(!vat.is_success) begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
			return ;
		end
		data[95:64] = mem.read32(vat.result.addr);

		out.is_success = 1'b1;
		case(va[1:0])
		2'h0: out.result.data = data[63:0];
		2'h1: out.result.data = data[63+8:8];
		2'h2: out.result.data = data[63+16:16];
		2'h3: out.result.data = data[63+24:24];
		endcase
	endtask

	task vat_read32(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		vat_racc(va, va, pc, vat);
		if(vat.is_success) begin
			if(va[1:0] == 2'h0) begin
				out.is_success = 1'b1;
				out.result.data = {{`XLEN-32{1'b0}}, mem.read32(vat.result.addr)};
			end else begin
				bit [63:0] data;
				data[31:0] = mem.read32(vat.result.addr);

				vat_racc(va + 'h4, va, pc, vat);
				if(vat.is_success) begin
					out.is_success = 1'b1;
					data[63:32] = mem.read32(vat.result.addr);
					case(va[1:0])
					2'h0: out.result.data = {{`XLEN-32{1'b0}}, data[31:0]};		// not selected
					2'h1: out.result.data = {{`XLEN-32{1'b0}}, data[39:8]};
					2'h2: out.result.data = {{`XLEN-32{1'b0}}, data[47:16]};
					2'h3: out.result.data = {{`XLEN-32{1'b0}}, data[55:24]};
					endcase
				end else begin
					out.is_success = 1'b0;
					out.result.trap_pc = vat.result.trap_pc;
				end
			end
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

	task vat_read16(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		vat_racc(va, va, pc, vat);
		if(vat.is_success) begin
			case(va[1:0])
			2'h0: begin
				out.is_success = 1'b1;
				out.result.data = {{`XLEN-16{1'b0}}, mem.read16(vat.result.addr)};
			end
			2'h1: begin
				bit [31:0] data;
				out.is_success = 1'b1;
				data = mem.read32(vat.result.addr);
				out.result.data = {{`XLEN-16{1'b0}}, data[23:8]};
			end
			2'h2: begin
				out.is_success = 1'b1;
				out.result.data = {{`XLEN-16{1'b0}}, mem.read16(vat.result.addr)};
			end
			2'h3: begin
				bit [15:0] od;
				od[7:0] = mem.read8(vat.result.addr);
				vat_racc(va + 'b1, va, pc, vat);
				if(vat.is_success) begin
					out.is_success = 1'b1;
					od[15:8] = mem.read8(vat.result.addr);
					out.result.data = {{`XLEN-16{1'b0}}, od};
				end else begin
					out.is_success = 1'b0;
					out.result.trap_pc = vat.result.trap_pc;
				end
			end
			endcase
		end else begin
			out.is_success = 1'b0;
			out.result.trap_pc = vat.result.trap_pc;
		end
	endtask

	task vat_read8(input [`XLEN-1:0] va, input [`XLEN-1:0] pc, output vret_t out);
		vat_t	vat;
		bit [7:0] od;
		vat_racc(va, va, pc, vat);
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
		vat_facc(va, va, pc, vat);
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
