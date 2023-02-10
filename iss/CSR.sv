`ifndef _csr_sv_
`define _csr_sv_

`include "defs.vh"


`define MODE_M	2'b11
`define MODE_S	2'b01
`define MODE_U	2'b00

`define MXL_32	2'h1
`define MXL_64	2'h2
`define MXL_128	2'h3

class CSR;
	logic [`XLEN-1:0]		csr_reg[0:`NUM_CSR-1];

	logic [1:0]		mode;

	logic [4:0]		fflags;
	logic [2:0]		frm;
	logic [`XLEN-1:0]	cycle;
	logic [`XLEN-1:0]	csr_time;
	logic [`XLEN-1:0]	instret;
	// mstatus
	logic			m_sie;
	logic			m_mie;
	logic			m_spie;
	logic			m_ube;
	logic			m_mpie;
	logic			m_spp;
	logic [1:0]		m_vs;
	logic [1:0]		m_mpp;
	logic [1:0]		m_fs;
	logic [1:0]		m_xs;
	logic			m_mprv;
	logic			m_sum;
	logic			m_mxr;
	logic			m_tvm;
	logic			m_tw;
	logic			m_tsr;
	logic [1:0]		m_uxl = `MXL_64;
	logic [1:0]		m_sxl = `MXL_64;
	logic			m_sbe;
	logic			m_mbe;
	logic			m_sd;

	logic [`MXLEN-1:0]	mepc;
	logic [`MXLEN-1:0]	mcause;
	logic [`MXLEN-1:0]	mtvec;
	logic [`MXLEN-1:0]	mtval;

	// sstatus
	logic			s_sie;
	logic			s_spie;
	logic			s_ube;
	logic			s_spp;
	logic [1:0]		s_vs;
	logic [1:0]		s_fs;
	logic [1:0]		s_xs;
	logic			s_sum;
	logic			s_mxr;
	logic [1:0]		s_uxl = `MXL_64;
	logic			s_sd;

	logic [`MXLEN-1:0]	sepc;
	logic [`MXLEN-1:0]	scause;
	logic [`MXLEN-1:0]	stvec;

	logic [43:0]		satp_ppn;
	logic [15:0]		satp_asid;
	logic [3:0]		satp_mode;

	function void init();
		for(integer i = 0; i < `NUM_CSR; i = i + 1) begin
			csr_reg[i] = {`XLEN{1'b0}};
		end
		mode		= `MODE_M;

		fflags		= 5'h00;
		frm		= 3'h0;
		cycle		= {`XLEN{1'b0}};
		csr_time	= {`XLEN{1'b0}};
		instret		= {`XLEN{1'b0}};
		// mstatus
		m_sie		= 1'b0;
		m_mie		= 1'b0;
		m_spie		= 1'b0;
		m_ube		= 1'b0;
		m_mpie		= 1'b0;
		m_spp		= 1'b0;
		m_vs		= 2'h0;
		m_mpp		= `MODE_M;
		m_fs		= 2'h0;		// must be fiexd
		m_xs		= 2'h0;
		m_mprv		= 1'b0;
		m_sum		= 1'b0;
		m_mxr		= 1'b0;
		m_tvm		= 1'b0;
		m_tw		= 1'b0;
		m_tsr		= 1'b0;
		m_uxl		= `MXL_64;
		m_sxl		= `MXL_64;
		m_sbe		= 1'b0;
		m_mbe		= 1'b0;
		m_sd		= 1'b0;		// must be fixed

		mtvec		= {`MXLEN{1'b0}};

		mepc		= {`MXLEN{1'b0}};
		mcause		= {`MXLEN{1'b0}};
		mtval		= {`MXLEN{1'b0}};

		// sstatus
		s_sie		= 1'b0;
		s_spie		= 1'b0;
		s_ube		= 1'b0;
		s_spp		= 1'b0;
		s_vs		= 2'h0;
		s_fs		= 2'h0;
		s_xs		= 2'h0;
		s_sum		= 1'b0;
		s_mxr		= 1'b0;
		s_uxl		= `MXL_64;
		s_sd		= 1'b0;

		stvec		= {`MXLEN{1'b0}};

		sepc		= {`MXLEN{1'b0}};
		scause		= {`MXLEN{1'b0}};

		satp_ppn	= {44{1'b0}};
		satp_asid	= {16{1'b0}};
		satp_mode	= {4{1'b0}};
	endfunction

	function void tick ();
		cycle = cycle + 'b1;
		csr_time = csr_time + 'b1;	// real time clock, fix it
	endfunction

	function void retire ();
		instret = instret + 'b1;
	endfunction

	function void write (input [12-1:0] addr, input [`XLEN-1:0] data);
		case (addr)
			12'h001: fflags = data[4:0];
			12'h002: frm = data[2:0];
			12'h003: begin	// fcsr
				fflags = data[4:0];
				frm    = data[7:5];
			end
			12'h100: begin			// sstatus
				s_sie		= data[1];
				s_spie		= data[5];
				s_ube		= data[6];
				s_spp		= data[8];
//				s_vs		= data[10:9];
				s_fs		= data[14:13];
//				s_xs		= data[16:15];
				s_sum		= data[18];
				s_mxr		= data[19];
//				s_uxl		= data[33:32];
//				s_sd		= data[63];
				$display("[INFO] set sstatus, sie:%b, spie:%b, ube:%b, spp:%b, fs:%02b, sum:%b, mxr:%b",
					s_sie, s_spie, s_ube, s_spp, s_fs, s_sum, s_mxr);
			end
			12'h180: begin			// satp
				satp_ppn	= data[43:0];
				satp_asid	= data[59:44];
				satp_mode	= data[63:60];
				if(satp_mode == 8) begin
					$display("[INFO] set satp, MODE:Sv39(%d), ASID:%d, PPN:%08h",
						satp_mode, satp_asid, satp_ppn);
				end else begin
					$display("[INFO] set satp, MODE:%d, ASID:%d, PPN:%08h",
						satp_mode, satp_asid, satp_ppn);
				end
			end
			12'h300: begin			// mstatus
				m_sie	= data[1];
				m_mie	= data[3];
				m_spie	= data[5];
//				m_ube	= data[6];
				m_mpie	= data[7];
				m_spp	= data[8];
//				m_vs	= data[10:9];
				m_mpp	= data[12:11];
				m_fs	= data[14:13];
//				m_xs	= data[16:15];
				m_mprv	= data[17];
				m_sum	= data[18];
				m_mxr	= data[19];
				m_tvm	= data[20];
				m_tw	= data[21];
				m_tsr	= data[22];
//				m_uxl	= data[33:32];
//				m_sxl	= data[35:34];
//				m_sbe	= data[36];
//				m_mbe	= data[37];
//				m_sd	= data[63];
				$display("[INFO] set mstatus, sie:%b, mie:%b, spie:%b, mpie:%b, spp:%b, mpp:%02b, fs:%02b, mprv:%b, sum:%b, mxr:%b, tvm:%b, tw:%b, tsr:%b",
					 m_sie, m_mie, m_spie, m_mpie, m_spp, m_mpp, m_fs, m_mprv, m_sum, m_mxr, m_tvm, m_tw, m_tsr);
			end
			12'h305: mtvec	= data;
			12'h341: mepc	= {data[`XLEN-1:1], 1'b0};
			12'h342: mcause	= data;
			12'h343: mtval	= data;
			12'h105: stvec	= data;
			12'h141: sepc	= {data[`XLEN-1:1], 1'b0};
			12'h142: scause	= data;
			default: csr_reg[addr] = data;
		endcase
	endfunction

	function [`XLEN-1:0] read (input [12-1:0] addr);
		case (addr)
			12'h001: return {{`XLEN-5{1'b0}}, fflags};
			12'h002: return {{`XLEN-3{1'b0}}, frm};
			12'h003: return {{`XLEN-5-3{1'b0}}, frm, fflags};
			12'hc00: return cycle;
			12'hc01: return csr_time;
			12'hc02: return instret;
			12'hf11: return {`XLEN{1'b0}};	// mvenderid
			12'hf12: return {`XLEN{1'b0}};	// marchid
			12'hf13: return {`XLEN{1'b0}};	// mimpid
			12'hf14: return {`XLEN{1'b0}};	// mhartid
			12'hf15: return {`XLEN{1'b0}};	// mconfigptr
			12'h180: begin			// satp
				return {satp_mode, satp_asid, satp_ppn};
			end
			12'h300: begin			// mstatus
				return {m_sd, 25'h00_0000, m_mbe, m_sbe, m_sxl, m_uxl,
					9'h000, m_tsr, m_tw, m_tvm, m_mxr, m_sum,
					m_mprv, m_xs, m_fs, m_mpp, m_vs, m_spp, m_mpie,
					m_ube, m_spie, 1'b0, m_mie, 1'b0, m_sie, 1'b0};
			end
			12'h305: return mtvec;
			12'h341: return {mepc[`XLEN-1:2], 2'h0};
			12'h342: return mcause;
			12'h343: return mtval;
			12'h100: begin
				return {s_sd, 29'h0000_0000, s_uxl, 12'h000, s_mxr, s_sum, 1'b0,
					s_xs, s_fs, 2'h0, s_vs, s_spp, 1'b0, s_ube, s_spie, 3'h0, s_sie, 1'b0};
			end
			12'h105: return stvec;
			12'h141: return {sepc[`XLEN-1:2], 2'h0};
			12'h142: return scause;
			default: return csr_reg[addr];
		endcase
	endfunction

`define EX_IAMIS	4'h0
`define EX_IAFAULT	4'h1
`define EX_ILLEGINST	4'h2
`define EX_BREAK	4'h3
`define EX_LAMIS	4'h4
`define EX_LAFAULT	4'h5
`define EX_SAMIS	4'h6
`define EX_SAFAULT	4'h7
`define EX_ECALL_U	4'h8
`define EX_ECALL_S	4'h9
`define EX_ECALL_M	4'hb
`define EX_IPFAULT	4'hc
`define EX_LPFAULT	4'hd
`define EX_SPFAULT	4'hf

	function [`MXLEN-1:0] ecall(input[`XLEN-1:0] epc);
		case(mode)
			`MODE_M: return raise_exception(`EX_ECALL_M, epc, {`XLEN{1'b0}});
			`MODE_S: return raise_exception(`EX_ECALL_S, epc, {`XLEN{1'b0}});
			`MODE_U: return raise_exception(`EX_ECALL_U, epc, {`XLEN{1'b0}});
			default: begin
				$display("[ERROR] mode errror.");
				$finish();
			end
		endcase
	endfunction

	function [`MXLEN-1:0] raise_exception(input [3:0] cause, input[`XLEN-1:0] epc, input[`XLEN-1:0] tval);
		$display("[INFO] EXCEPTION cause %d, mode = %d.", cause, mode);
			m_mpie	= m_mie;
			m_mie	= 1'b0;
			m_mpp	= mode;
			mode    = `MODE_M;
			mepc	= {epc[`XLEN-1:1], 1'b0};
			mcause	= {1'b0, {`MXLEN-5{1'b0}}, cause};
			mtval	= tval;

			return mtvec[1:0] == 2'h1 ? {mtvec[`MXLEN-1:2], 2'h0} + cause * 4 : {mtvec[`MXLEN-1:2], 2'h0};
			$display("[INFO] entering M-MODE.");
			/*
		if(mode == `MODE_M) begin
		end else if(mode == `MODE_U) begin
			mpie	= mie;
			mie     = 1'b0;
			mpp     = `MODE_U;
			mode    = `MODE_M;
			mepc	= {epc[`XLEN-1:1], 1'b0};
			mcause	= {1'b0, {`MXLEN-5{1'b0}}, cause};

			return mtvec[1:0] == 2'h1 ? {mtvec[`MXLEN-1:2], 2'h0} + cause * 4 : {mtvec[`MXLEN-1:2], 2'h0};
		end else begin
			return {`MXLEN{1'b1}};	// do not traped.
		end
		*/
	endfunction

	function [`MXLEN-1:0] mret();
		m_mie = m_mpie;
		m_mpie = 1'b1;
		mode = m_mpp;
		m_mpp = `MODE_U;
		print_mode();
		return {mepc[`MXLEN-1:1], 1'b0};
	endfunction

	function [`MXLEN-1:0] sret();
		s_sie = s_spie;
		s_spie = 1'b1;
		mode = {1'b0, s_spp};
		s_spp = 1'b0;	// mode U
		print_mode();
		return {sepc[`MXLEN-1:2], 2'h0};
	endfunction

	function void print_mode();
		case(mode)
			`MODE_M: $display("[INFO] Entering M-MODE");
			`MODE_S: $display("[INFO] Entering S-MODE");
			`MODE_U: $display("[INFO] Entering U-MODE");
			default: begin
				$display("[ERROR] mode errror.");
				$finish();
			end
		endcase
	endfunction

	function logic [1:0] read_mode();
		return mode;
	endfunction

	function logic read_m_mie();
		return m_mie;
	endfunction

	function logic read_m_sie();
		return m_sie;
	endfunction

	function void set (input [12-1:0] addr, input [`XLEN-1:0] data);
		write(addr, read(addr) | data);
	endfunction

	function void clear (input [12-1:0] addr, input [`XLEN-1:0] data);
		write(addr, read(addr) & ~data);
	endfunction

	function void set_fflags(input [4:0] fflags_in);
		fflags = fflags_in;
	endfunction


	function [3:0] get_satp_mode();
		return satp_mode;
	endfunction

	function [1:0] get_mode();
		return mode;
	endfunction

	function get_m_sum();
		return m_sum;
	endfunction

	function get_s_sum();
		return s_sum;
	endfunction

	function [43:0] get_satp_ppn();
		return satp_ppn;
	endfunction
	
	function get_mprv();
		return m_mprv;
	endfunction

	function [1:0] get_mpp();
		return m_mpp;
	endfunction
endclass : CSR;

`endif // _csr_sv_
