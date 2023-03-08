`ifndef _pc_sv_
`define _pc_sv_

`include "defs.vh"

interface PC
#(
	parameter WIDTH		= `XLEN
);
	logic			VALID;
	logic			READY;
	logic	[WIDTH-1:0]	PC;

	modport	init
	(
		output		VALID,
		input		READY,
		output		PC,

		import		est
	);

	modport target
	(
		input		VALID,
		output		READY,
		input		PC,

		import		est
	);

	modport peek
	(
		input		VALID,
		input		READY,
		input		PC,

		import		est
	);

	function logic est();
		return VALID && READY ? 1'b1 : 1'b0;
	endfunction
endinterface


`endif // _pc_sv_
