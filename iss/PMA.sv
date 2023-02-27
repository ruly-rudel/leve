`ifndef _pma_sv_
`define _pma_sv_

`include "defs.vh"


class PMA;
	function bit is_readable(input [`XLEN-1:0] addr);
			return 1'b1;
	endfunction

	function bit is_writeable(input [`XLEN-1:0] addr);
			return 1'b1;
	endfunction

	function bit is_executable(input [`XLEN-1:0] addr);
			return 1'b1;
	endfunction

	function bit is_accessable(input [`XLEN-1:0] addr, input [3:0] acc);
			return 1'b1;
	endfunction
endclass : PMA;

`endif	// _pma_sv_
