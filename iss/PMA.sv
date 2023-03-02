`ifndef _pma_sv_
`define _pma_sv_

`include "defs.vh"

class PMA;
	function bit is_readable(input [`XLEN-1:0] addr);
		return is_accessable(addr, `PTE_R);
	endfunction

	function bit is_writeable(input [`XLEN-1:0] addr);
		return is_accessable(addr, `PTE_W);
	endfunction

	function bit is_executable(input [`XLEN-1:0] addr);
		return is_accessable(addr, `PTE_X);
	endfunction

	function bit is_accessable(input [`XLEN-1:0] addr, input [3:0] acc);
		if(addr > 64'h0000_0010_8000_0000) begin
			return 1'b0;
		end else begin
			return 1'b1;
		end
	endfunction
endclass : PMA;

`endif	// _pma_sv_
