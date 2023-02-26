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
	bit [`XLEN-1:0]		csr_reg[0:`NUM_CSR-1];

	bit [1:0]		mode;

	bit [4:0]		fflags;
	bit [2:0]		frm;
	bit [`XLEN-1:0]	cycle;
	bit [`XLEN-1:0]	csr_time;
	bit [`XLEN-1:0]	instret;
	// mstatus
	bit			sie;
	bit			mie;
	bit			spie;
	bit			ube;
	bit			mpie;
	bit			spp;
	bit [1:0]		vs;
	bit [1:0]		mpp;
	bit [1:0]		fs;
	bit [1:0]		xs;
	bit			mprv;
	bit			sum;
	bit			mxr;
	bit			tvm;
	bit			tw;
	bit			tsr;
	bit [1:0]		uxl = `MXL_64;
	bit [1:0]		sxl = `MXL_64;
	bit			sbe;
	bit			mbe;
	bit			sd;

	bit [`MXLEN-1:0]	medeleg;

	bit [`MXLEN-1:0]	mepc;
	bit [`MXLEN-1:0]	mcause;
	bit [`MXLEN-1:0]	mtvec;
	bit [`MXLEN-1:0]	mtval;

	bit [`MXLEN-1:0]	stvec;
	bit [`MXLEN-1:0]	sepc;
	bit [`MXLEN-1:0]	scause;
	bit [`MXLEN-1:0]	stval;

	bit [43:0]		satp_ppn;
	bit [15:0]		satp_asid;
	bit [3:0]		satp_mode;

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
		sie		= 1'b0;
		mie		= 1'b0;
		spie		= 1'b0;
		ube		= 1'b0;
		mpie		= 1'b0;
		spp		= 1'b0;
		vs		= 2'h0;
		mpp		= `MODE_M;
		fs		= 2'h0;		// must be fiexd
		xs		= 2'h0;
		mprv		= 1'b0;
		sum		= 1'b0;
		mxr		= 1'b0;
		tvm		= 1'b0;
		tw		= 1'b0;
		tsr		= 1'b0;
		uxl		= `MXL_64;
		sxl		= `MXL_64;
		sbe		= 1'b0;
		mbe		= 1'b0;
		sd		= 1'b0;		// must be fixed

		medeleg		= {`MXLEN{1'b0}};

		mtvec		= {`MXLEN{1'b0}};

		mepc		= {`MXLEN{1'b0}};
		mcause		= {`MXLEN{1'b0}};
		mtval		= {`MXLEN{1'b0}};

		stvec		= {`MXLEN{1'b0}};

		sepc		= {`MXLEN{1'b0}};
		scause		= {`MXLEN{1'b0}};
		stval		= {`MXLEN{1'b0}};

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
				sie		= data[1];
				spie		= data[5];
				ube		= data[6];
				spp		= data[8];
//				vs		= data[10:9];
				fs		= data[14:13];
//				xs		= data[16:15];
				sum		= data[18];
				mxr		= data[19];
//				uxl		= data[33:32];
//				s_sd		= data[63];
				$display("[INFO] set sstatus, sie:%b, spie:%b, ube:%b, spp:%b, fs:%02b, sum:%b, mxr:%b",
					sie, spie, ube, spp, fs, sum, mxr);
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
				sie	= data[1];
				mie	= data[3];
				spie	= data[5];
//				ube	= data[6];
				mpie	= data[7];
				spp	= data[8];
//				vs	= data[10:9];
				mpp	= data[12:11];
				fs	= data[14:13];
//				xs	= data[16:15];
				mprv	= data[17];
				sum	= data[18];
				mxr	= data[19];
				tvm	= data[20];
				tw	= data[21];
				tsr	= data[22];
//				uxl	= data[33:32];
//				sxl	= data[35:34];
//				sbe	= data[36];
//				mbe	= data[37];
//				sd	= data[63];
				$display("[INFO] set mstatus, sie:%b, mie:%b, spie:%b, mpie:%b, spp:%b, mpp:%02b, fs:%02b, mprv:%b, sum:%b, mxr:%b, tvm:%b, tw:%b, tsr:%b",
					 sie, mie, spie, mpie, spp, mpp, fs, mprv, sum, mxr, tvm, tw, tsr);
			end
			12'h302: medeleg= data;
			12'h305: mtvec	= data;
			12'h341: mepc	= {data[`XLEN-1:1], 1'b0};
			12'h342: mcause	= data;
			12'h343: mtval	= data;
			12'h105: stvec	= data;
			12'h141: sepc	= {data[`XLEN-1:1], 1'b0};
			12'h142: scause	= data;
			12'h143: stval	= data;
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
				return {sd, 25'h00_0000, mbe, sbe, sxl, uxl,
					9'h000, tsr, tw, tvm, mxr, sum,
					mprv, xs, fs, mpp, vs, spp, mpie,
					ube, spie, 1'b0, mie, 1'b0, sie, 1'b0};
			end
			12'h302: return medeleg;
			12'h305: return mtvec;
			12'h341: return {mepc[`XLEN-1:1], 1'b0};
			12'h342: return mcause;
			12'h343: return mtval;
			12'h100: begin
				return {sd, 29'h0000_0000, uxl, 12'h000, mxr, sum, 1'b0,
					xs, fs, 2'h0, vs, spp, 1'b0, ube, spie, 3'h0, sie, 1'b0};
			end
			12'h105: return stvec;
			12'h141: return {sepc[`XLEN-1:1], 1'b0};
			12'h142: return scause;
			12'h143: return stval;
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
		$display("[INFO] EXCEPTION cause %d, mode = %d at %08h", cause, mode, epc);
		if((medeleg & (1 << cause)) != 64'h0) begin
			spie	= sie;
			sie	= 1'b0;
			spp	= mode[0];
			mode    = `MODE_S;
			sepc	= {epc[`XLEN-1:1], 1'b0};
			scause	= {1'b0, {`MXLEN-5{1'b0}}, cause};
			stval	= tval;

			return stvec[1:0] == 2'h1 ? {stvec[`MXLEN-1:2], 2'h0} + cause * 4 : {stvec[`MXLEN-1:2], 2'h0};
			$display("[INFO] entering S-MODE.");
		end else begin
			mpie	= mie;
			mie	= 1'b0;
			mpp	= mode;
			mode    = `MODE_M;
			mepc	= {epc[`XLEN-1:1], 1'b0};
			mcause	= {1'b0, {`MXLEN-5{1'b0}}, cause};
			mtval	= tval;

			return mtvec[1:0] == 2'h1 ? {mtvec[`MXLEN-1:2], 2'h0} + cause * 4 : {mtvec[`MXLEN-1:2], 2'h0};
			$display("[INFO] entering M-MODE.");
		end
	endfunction

	function [`MXLEN-1:0] mret();
		mie = mpie;
		mpie = 1'b1;
		mode = mpp;
		mpp = `MODE_U;
		print_mode();
		return {mepc[`MXLEN-1:1], 1'b0};
	endfunction

	function [`MXLEN-1:0] sret();
		sie = spie;
		spie = 1'b1;
		mode = {1'b0, spp};
		spp = 1'b0;	// mode U
		print_mode();
		return {sepc[`MXLEN-1:1], 1'b0};
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

	function bit [1:0] read_mode();
		return mode;
	endfunction

	function bit read_mie();
		return mie;
	endfunction

	function bit read_sie();
		return sie;
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

	function [1:0] get_ldst_mode();
		if(mprv == 1'b0) begin
			return mode;
		end else begin
			return mpp;
		end
		return mode;
	endfunction

	function get_sum();
		return sum;
	endfunction

	function [43:0] get_satp_ppn();
		return satp_ppn;
	endfunction
	
	function get_mxr();
		return mxr;
	endfunction

endclass : CSR;

`endif // _csr_sv_
