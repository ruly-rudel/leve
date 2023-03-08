`ifndef _hs_sv_
`define _hs_sv_

`include "defs.vh"

interface HS	// hand shake
#(
	parameter WIDTH		= `XLEN
);
	logic			VALID;
	logic			READY;
	logic	[WIDTH-1:0]	PAYLOAD;

	modport	init
	(
		output		VALID,
		input		READY,
		output		PAYLOAD,

		import		est
	);

	modport target
	(
		input		VALID,
		output		READY,
		input		PAYLOAD,

		import		est
	);

	modport peek
	(
		input		VALID,
		input		READY,
		input		PAYLOAD,

		import		est
	);

	function logic est();
		return VALID && READY ? 1'b1 : 1'b0;
	endfunction
endinterface


`endif // _hs_sv_
