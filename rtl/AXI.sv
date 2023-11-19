`ifndef _axi_sv_
`define _axi_sv_

`include "defs.vh"


`define AXI_BURST_FIXED		2'h0
`define AXI_BURST_INCR		2'h1
`define AXI_BURST_WRAP		2'h2

`define	AXI_LOCK_NORMAL		1'b0
`define	AXI_LOCK_EXCLUSIVE	1'b1

`define AXI_RESP_OKAY		2'h0
`define AXI_RESP_EXOKAY		2'h1
`define AXI_RESP_SLVERR		2'h2
`define AXI_RESP_DECERR		2'h3

interface AXIR
#(
	parameter ARADDR_W	= 32,
	parameter RDATA_W	= 128
);
	logic			ARVALID;
	logic			ARREADY;
	logic	[ARADDR_W-1:0]	ARADDR;
	logic 	[1:0]		ARBURST;
	logic 	[7:0]		ARLEN;

	logic			RVALID;
	logic			RREADY;
	logic	[RDATA_W-1:0]	RDATA;
	logic	[1:0]		RRESP;
	logic			RLAST;

	modport	init
	(
		output		ARVALID,
		input		ARREADY,
		output		ARADDR,
		output 		ARBURST,
		output 		ARLEN,
	
		input		RVALID,
		output		RREADY,
		input		RDATA,
		input		RRESP,
		input		RLAST,
		import		ar_est,
		import		r_est,
		import		r_last
	);

	modport target
	(
		input		ARVALID,
		output		ARREADY,
		input		ARADDR,
		input 		ARBURST,
		input 		ARLEN,
	
		output		RVALID,
		input		RREADY,
		output		RDATA,
		output		RRESP,
		output		RLAST,
		import		ar_est,
		import		r_est,
		import		r_last
	);

	function logic ar_est();
		return ARVALID && ARREADY ? 1'b1 : 1'b0;
	endfunction

	function logic r_est();
		return RVALID && RREADY ? 1'b1 : 1'b0;
	endfunction

	function logic r_last();
		return RVALID && RREADY && RLAST ? 1'b1 : 1'b0;
	endfunction
endinterface

interface AXIW
#(
	parameter AWADDR_W	= 32,
	parameter WDATA_W	= 128,
	parameter WSTRB_W	= 16
);
	logic			AWVALID;
	logic			AWREADY;
	logic	[AWADDR_W-1:0]	AWADDR;
	logic 	[1:0]		AWBURST;
	logic 	[7:0]		AWLEN;

	logic			WVALID;
	logic			WREADY;
	logic	[WDATA_W-1:0]	WDATA;
	logic	[WSTRB_W-1:0]	WSTRB;

	logic			BVALID;
	logic			BREADY;
	logic	[1:0]		BRESP;

	modport init
	(
		input		AWVALID,
		output		AWREADY,
		input		AWADDR,
		input 		AWBURST,
		input 		AWLEN,
	
		input		WVALID,
		output		WREADY,
		input		WDATA,
		input		WSTRB,
	
		output		BVALID,
		input		BREADY,
		output		BRESP,

		import		aw_est,
		import		w_est,
		import		b_est
	);

	modport target
	(
		input		AWVALID,
		output		AWREADY,
		input		AWADDR,
		input 		AWBURST,
		input 		AWLEN,
	
		input		WVALID,
		output		WREADY,
		input		WDATA,
		input		WSTRB,
	
		output		BVALID,
		input		BREADY,
		output		BRESP,

		import		aw_est,
		import		w_est,
		import		b_est
	);

	function logic aw_est();
		return AWVALID && AWREADY ? 1'b1 : 1'b0;
	endfunction

	function logic w_est();
		return WVALID && WREADY ? 1'b1 : 1'b0;
	endfunction

	function logic b_est();
		return BVALID && BREADY ? 1'b1 : 1'b0;
	endfunction
endinterface

`endif // _axi_sv_
