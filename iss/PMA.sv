`ifndef _pma_sv_
`define _pma_sv_

`include "defs.vh"


class PMA;
	function logic is_readable(input [`XLEN-1:0] addr);
			return 1'b1;
	endfunction

	function logic is_writeable(input [`XLEN-1:0] addr);
			return 1'b1;
	endfunction

	function logic is_executable(input [`XLEN-1:0] addr);
			return 1'b1;
	endfunction
endclass : PMA;

`endif	// _pma_sv_
