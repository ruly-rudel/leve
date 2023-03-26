
`include "defs.vh"

module LEVE_CSR
(
	input logic			CLK,
	input logic			RSTn,

	input [1:0]			CMD,
	input [11:0]			CSR_A,
	input [`XLEN-1:0]		CSR_WD,
	output [`XLEN-1:0]		CSR_RD,

	input				RETIRE
);
	logic [1:0]		mode;

	logic [4:0]		fflags;
	logic [2:0]		frm;
	logic [`XLEN-1:0]	cycle;
	logic [`XLEN-1:0]	csr_time;
	logic [`XLEN-1:0]	instret;
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

	logic [`MXLEN-1:0]	medeleg;

	logic [`MXLEN-1:0]	mepc;
	logic [`MXLEN-1:0]	mcause;
	logic [`MXLEN-1:0]	mtvec;
	logic [`MXLEN-1:0]	mtval;

	logic [`MXLEN-1:0]	stvec;
	logic [`MXLEN-1:0]	sepc;
	logic [`MXLEN-1:0]	scause;
	logic [`MXLEN-1:0]	stval;

	logic [43:0]		satp_ppn;
	logic [15:0]		satp_asid;
	logic [3:0]		satp_mode;


	logic [`MXLEN-1:0]	csr_rd;
	logic [`MXLEN-1:0]	csr_wd;

	always_comb begin
		case (CSR_A)
			12'h001: csr_rd = {{`XLEN-5{1'b0}}, fflags};
			12'h002: csr_rd = {{`XLEN-3{1'b0}}, frm};
			12'h003: csr_rd = {{`XLEN-5-3{1'b0}}, frm, fflags};
			12'hc00: csr_rd = cycle;
			12'hc01: csr_rd = csr_time;
			12'hc02: csr_rd = instret;
			12'hf11: csr_rd = {`XLEN{1'b0}};	// mvenderid
			12'hf12: csr_rd = {`XLEN{1'b0}};	// marchid
			12'hf13: csr_rd = {`XLEN{1'b0}};	// mimpid
			12'hf14: csr_rd = {`XLEN{1'b0}};	// mhartid
			12'hf15: csr_rd = {`XLEN{1'b0}};	// mconfigptr
			12'h180: begin			// satp
				csr_rd = {satp_mode, satp_asid, satp_ppn};
			end
			12'h300: begin			// mstatus
				csr_rd = {sd, 25'h00_0000, mbe, sbe, sxl, uxl,
					9'h000, tsr, tw, tvm, mxr, sum,
					mprv, xs, fs, mpp, vs, spp, mpie,
					ube, spie, 1'b0, mie, 1'b0, sie, 1'b0};
			end
			12'h302: csr_rd = medeleg;
			12'h305: csr_rd = mtvec;
			12'h341: csr_rd = {mepc[`XLEN-1:1], 1'b0};
			12'h342: csr_rd = mcause;
			12'h343: csr_rd = mtval;
			12'h100: begin
				csr_rd = {sd, 29'h0000_0000, uxl, 12'h000, mxr, sum, 1'b0,
					xs, fs, 2'h0, vs, spp, 1'b0, ube, spie, 3'h0, sie, 1'b0};
			end
			12'h105: csr_rd = stvec;
			12'h141: csr_rd = {sepc[`XLEN-1:1], 1'b0};
			12'h142: csr_rd = scause;
			12'h143: csr_rd = stval;
			default: csr_rd = {`MXLEN{1'b0}};
		endcase
	end

	always_comb begin
		case(CMD)
		`CSR_NONE:	csr_wd = {`MXLEN{1'b0}};
		`CSR_SET:	csr_wd = csr_rd |  CSR_WD;
		`CSR_CLEAR:	csr_wd = csr_rd & ~CSR_WD;
		`CSR_WRITE:	csr_wd = CSR_WD;
		endcase
	end

	assign	CSR_RD = csr_rd;

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			mode		= `MODE_M;
	
			fflags		= 5'h00;
			frm		= 3'h0;
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
		end else if(CMD != `CSR_NONE) begin
			case (CSR_A)
			12'h001: fflags = csr_wd[4:0];
			12'h002: frm = csr_wd[2:0];
			12'h003: begin	// fcsr
				fflags = csr_wd[4:0];
				frm    = csr_wd[7:5];
			end
			12'h100: begin			// sstatus
				sie		= csr_wd[1];
				spie		= csr_wd[5];
				ube		= csr_wd[6];
				spp		= csr_wd[8];
//				vs		= csr_wd[10:9];
				fs		= csr_wd[14:13];
//				xs		= csr_wd[16:15];
				sum		= csr_wd[18];
				mxr		= csr_wd[19];
//				uxl		= csr_wd[33:32];
//				s_sd		= csr_wd[63];
				$display("[INFO] set sstatus, sie:%b, spie:%b, ube:%b, spp:%b, fs:%02b, sum:%b, mxr:%b",
					sie, spie, ube, spp, fs, sum, mxr);
			end
			12'h180: begin			// satp
				satp_ppn	= csr_wd[43:0];
				satp_asid	= csr_wd[59:44];
				satp_mode	= csr_wd[63:60];
				if(satp_mode == 8) begin
					$display("[INFO] set satp, MODE:Sv39(%d), ASID:%d, PPN:%08h",
						satp_mode, satp_asid, satp_ppn);
				end else begin
					$display("[INFO] set satp, MODE:%d, ASID:%d, PPN:%08h",
						satp_mode, satp_asid, satp_ppn);
				end
			end
			12'h300: begin			// mstatus
				sie	= csr_wd[1];
				mie	= csr_wd[3];
				spie	= csr_wd[5];
//				ube	= csr_wd[6];
				mpie	= csr_wd[7];
				spp	= csr_wd[8];
//				vs	= csr_wd[10:9];
				mpp	= csr_wd[12:11];
				fs	= csr_wd[14:13];
//				xs	= csr_wd[16:15];
				mprv	= csr_wd[17];
				sum	= csr_wd[18];
				mxr	= csr_wd[19];
				tvm	= csr_wd[20];
				tw	= csr_wd[21];
				tsr	= csr_wd[22];
//				uxl	= csr_wd[33:32];
//				sxl	= csr_wd[35:34];
//				sbe	= csr_wd[36];
//				mbe	= csr_wd[37];
//				sd	= csr_wd[63];
				$display("[INFO] set mstatus, sie:%b, mie:%b, spie:%b, mpie:%b, spp:%b, mpp:%02b, fs:%02b, mprv:%b, sum:%b, mxr:%b, tvm:%b, tw:%b, tsr:%b",
					 sie, mie, spie, mpie, spp, mpp, fs, mprv, sum, mxr, tvm, tw, tsr);
			end
			12'h302: medeleg= csr_wd;
			12'h305: mtvec	= csr_wd;
			12'h341: mepc	= {csr_wd[`XLEN-1:1], 1'b0};
			12'h342: mcause	= csr_wd;
			12'h343: mtval	= csr_wd;
			12'h105: stvec	= csr_wd;
			12'h141: sepc	= {csr_wd[`XLEN-1:1], 1'b0};
			12'h142: scause	= csr_wd;
			12'h143: stval	= csr_wd;
			default: ;
			endcase
		end
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			cycle		<= {`MXLEN{1'b0}};
			csr_time	<= {`MXLEN{1'b0}};
			instret		<= {`MXLEN{1'b0}};
		end else begin
			cycle		<= `TPD cycle + 'b1;
			csr_time	<= `TPD csr_time + 'b1;
			if(RETIRE) begin
				instret	<= `TPD instret + 'b1;
			end
		end
	end

endmodule : LEVE_CSR
