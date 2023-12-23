`include "defs.vh"


interface CSRIF;
	logic [`XLEN-1:0]	RCSR;
	logic [`XLEN-1:0]	MSTATUS;

	modport	init
	(
		output 		RCSR,
		output 		MSTATUS
	);

	modport target
	(
		input 		RCSR,
		input 		MSTATUS,
		import sie,
		import mie,
		import spie,
		import ube,
		import mpie,
		import spp,
		import vs,
		import mpp,
		import fs,
		import xs,
		import mprv,
		import sum,
		import mxr,
		import tvm,
		import tw,
		import tsr,
		import uxl,
		import sxl,
		import sbe,
		import mbe,
		import sd
	);


	function sie();
		return MSTATUS[1];
	endfunction

	function mie();
		return MSTATUS[3];
	endfunction

	function spie();
		return MSTATUS[5];
	endfunction

	function ube();
		return MSTATUS[6];
	endfunction

	function mpie();
		return MSTATUS[7];
	endfunction

	function spp();
		return MSTATUS[8];
	endfunction

	function [1:0] vs();
		return MSTATUS[10:9];
	endfunction

	function [1:0] mpp();
		return MSTATUS[12:11];
	endfunction

	function [1:0] fs();
		return MSTATUS[14:13];
	endfunction

	function [1:0] xs();
		return MSTATUS[16:15];
	endfunction

	function mprv();
		return MSTATUS[17];
	endfunction

	function sum();
		return MSTATUS[18];
	endfunction

	function mxr();
		return MSTATUS[19];
	endfunction

	function tvm();
		return MSTATUS[20];
	endfunction

	function tw();
		return MSTATUS[21];
	endfunction

	function tsr();
		return MSTATUS[22];
	endfunction

	function [1:0] uxl();
		return MSTATUS[33:32];
	endfunction

	function [1:0] sxl();
		return MSTATUS[35:34];
	endfunction

	function sbe();
		return MSTATUS[36];
	endfunction

	function mbe();
		return MSTATUS[37];
	endfunction

	function sd();
		return MSTATUS[63];
	endfunction


endinterface
