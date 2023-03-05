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

interface AXI
#(
	parameter ARADDR_W	= 32,
	parameter RDATA_W	= 128,
	parameter AWADDR_W	= 32,
	parameter WDATA_W	= 128,
	parameter WSTRB_W	= 16
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

	modport	r_init
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
		input		RLAST
	);

	modport r_target
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
		output		RLAST
	);

	modport w_init
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
		output		BRESP
	);

	modport w_target
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
		output		BRESP
	);

endinterface

`endif // _axi_sv_
